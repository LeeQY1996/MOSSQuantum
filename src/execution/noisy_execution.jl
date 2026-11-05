abstract type AbstractNoiseMethod end
"""Exact Kraus sum on density matrices (the default execution method)."""
struct DensityMatrixEvolution <: AbstractNoiseMethod end
"""Independent pure-state Kraus trajectories; CPU pure states and batches only."""
struct KrausTrajectory <: AbstractNoiseMethod end

# Companion backends can supply their own stochastic evolution method without
# treating a single trajectory as an ensemble density matrix.
_stochastic_noise_method(::AbstractNoiseMethod) = false
_stochastic_noise_method(::KrausTrajectory) = true
abstract type _CompiledStochasticChannel end
_compile_stochastic_channel(method::AbstractNoiseMethod, backend, channel, state) =
    throw(UnsupportedOperation(backend, channel, state, :apply))
_apply_stochastic_channel!(channel::_CompiledStochasticChannel, backend, state, rng, workspace) =
    throw(UnsupportedOperation(backend, channel, state, :apply))

"""Streaming counts: `shots` counts attempts and `accepted` counts successful attempts."""
struct CountsResult
    shots::Int
    accepted::Int
    qubits::Vector{Int}
    counts::Dict{String,Int}
end

# Trajectory capability is distinct from deterministic channel application.
# This implementation is deliberately restricted to the CPU backend.
supports(::CPUBackend, ::DensityMatrixEvolution, state::AbstractQuantumState; action::Symbol=:apply) =
    action === :apply && state isa _DenseCPUState && _cpu_storage_supported(state.data)
supports(::CPUBackend, ::KrausTrajectory, state::AbstractQuantumState; action::Symbol=:apply) =
    action === :apply && state isa Union{StateVector,BatchStateVector} && _cpu_storage_supported(state.data)

struct _CompiledConditional
    condition::ClassicalCondition
    then_branch::Vector{Any}
    else_branch::Vector{Any}
end

struct _TrajectoryChannel <: _CompiledStochasticChannel
    gates::Vector{QuantumGate}
    weights::Union{Nothing,Vector{Float64}}
end

function _trajectory_channel(channel::QuantumMap)
    matrices = kraus_matrices(channel)
    d = size(first(matrices),1)
    weights = Float64[real(sum(abs2,k))/d for k in matrices]
    tolerance = QuantumCircuits._channel_tolerance(eltype(channel),nothing)
    mixture = all(isapprox(k'*k, p*Matrix{eltype(k)}(I,d,d); atol=tolerance*p,rtol=0)
                  for (k,p) in zip(matrices,weights))
    if mixture
        gates = QuantumGate[QuantumGate(positions(channel), k/sqrt(p))
                            for (k,p) in zip(matrices,weights) if p > 0]
        return _TrajectoryChannel(gates,filter(>(0),weights))
    end
    return _TrajectoryChannel(QuantumGate[QuantumGate(positions(channel),k) for k in matrices],nothing)
end

function _noise_preflight!(flat, circuit, state, chosen, method)
    for instruction in circuit
        if instruction isa QCircuit
            _noise_preflight!(flat,instruction,state,chosen,method)
        elseif instruction isa Conditional
            yes = _noise_preflight!(Any[],instruction.then_branch,state,chosen,method)
            no = _noise_preflight!(Any[],instruction.else_branch,state,chosen,method)
            push!(flat,_CompiledConditional(instruction.condition,yes,no))
        elseif instruction isa Delay
            validate_positions(instruction,nqubits(state))
        elseif instruction isa QuantumMap
            validate_positions(instruction,nqubits(state))
            QuantumCircuits._validate_channel_data(instruction; check_tp=true)
            if method isa KrausTrajectory
                supports(chosen,instruction,state) || throw(UnsupportedOperation(chosen,instruction,state,:apply))
                push!(flat,_trajectory_channel(instruction))
            elseif _stochastic_noise_method(method)
                push!(flat,_compile_stochastic_channel(method,chosen,instruction,state))
            else
                supports(chosen,instruction,state) || throw(UnsupportedOperation(chosen,instruction,state,:apply))
                push!(flat,instruction)
            end
        else
            method isa KrausTrajectory && !(instruction isa Union{Gate,QMeasure,QSelect}) &&
                throw(UnsupportedOperation(chosen,instruction,state,:apply))
            if method isa KrausTrajectory && instruction isa Gate
                _check_batch_objective_gate(instruction)
                u = mat(instruction)
                all(isfinite,u) && isapprox(u'*u,Matrix{eltype(u)}(I,size(u)...);
                    atol=QuantumCircuits._channel_tolerance(eltype(u),nothing),rtol=0) ||
                    throw(ArgumentError("trajectory gates must be finite and unitary"))
            end
            push!(flat,instruction)
        end
    end
    return flat
end

# Generic CPU gate kernels handle local nonunitary Kraus operators too. Reuse
# one candidate buffer for all branch probabilities, then apply only the draw.
function _trajectory_apply!(channel::_TrajectoryChannel, state::StateVector, rng, scratch, weight_storage)
    if !isnothing(channel.weights)
        j = discrete_sample(rng,channel.weights)
        state = apply!(CPUBackend(),channel.gates[j],state)
    else
        weights = view(weight_storage,1:length(channel.gates))
        for (j,g) in enumerate(channel.gates)
            copyto!(scratch,storage(state))
            apply_threaded!(g,scratch)
            weights[j] = sum(abs2,scratch)
        end
        j = discrete_sample(rng,weights)
        state = apply!(CPUBackend(),channel.gates[j],state)
        storage(state) ./= sqrt(weights[j])
    end
    return state
end

_apply_stochastic_channel!(channel::_TrajectoryChannel, backend, state, rng, workspace) =
    _trajectory_apply!(channel,state,rng,workspace.scratch,workspace.weights)

function _trajectory_workspace(initial,flat)
    T = typeof(float(real(zero(eltype(initial)))))
    state = StateVector{Complex{T}}(initial;copy=true)
    maxbranches = _max_kraus_branches(flat)
    return (state=state,scratch=similar(storage(state)),weights=zeros(Float64,maxbranches))
end

_branch_count(x) = 0
_branch_count(x::_TrajectoryChannel) = length(x.gates)
_branch_count(x::_CompiledConditional) = max(_max_kraus_branches(x.then_branch),_max_kraus_branches(x.else_branch))
_max_kraus_branches(flat) = maximum(_branch_count,flat;init=0)

function _noise_evolve(flat,state,chosen,rng,errors,records,register,keep_records,method,workspace,register_size)
    for instruction in flat
        if instruction isa _CompiledConditional
            branch = instruction.condition(register) ? instruction.then_branch : instruction.else_branch
            state,accepted = _noise_evolve(branch,state,chosen,rng,errors,records,register,
                keep_records,method,workspace,register_size)
            accepted || return state,false
        elseif instruction isa _CompiledStochasticChannel
            state = _apply_stochastic_channel!(instruction,chosen,state,rng,workspace)
        elseif instruction isa Union{QMeasure,QSelect}
            reset = instruction isa QMeasure && instruction.auto_reset
            outcome, probability = measure!(chosen,state,instruction.position;auto_reset=reset,rng=rng)
            record = _shot_record(instruction.position,outcome,probability,
                instruction isa QSelect ? :postselection : :measurement)
            reported = _reported_outcome(instruction.position,outcome,errors,rng)
            key = instruction isa QMeasure ? instruction.key : nothing
            instruction isa QMeasure && _write_classical!(register,instruction,outcome,reported)
            keep_records && push!(records,MeasurementRecord(record.position,record.outcome,
                record.probability,record.kind,reported,key))
            instruction isa QSelect && outcome != instruction.state && return state,false
        else
            state = apply!(chosen,instruction,state)
        end
        state isa AbstractQuantumState || throw(ArgumentError("noise execution must return a quantum state"))
        nqubits(state) == register_size || throw(DimensionMismatch("noise execution must preserve the register"))
        method isa KrausTrajectory && !(state isa StateVector) &&
            throw(ArgumentError("trajectory execution must preserve a pure state"))
    end
    return state,true
end

function _noise_attempt(flat,initial,chosen,rng,errors,expanded,keep_records,method;
                        final_state=false,workspace=nothing,classical=nothing)
    if method isa KrausTrajectory
        workspace = isnothing(workspace) ? _trajectory_workspace(initial,flat) : workspace
        state = workspace.state
        copyto!(storage(state),storage(initial))
    else
        state = copy(initial)
    end
    records = MeasurementRecord[]
    register = _initial_classical(classical)
    state,accepted = _noise_evolve(flat,state,chosen,rng,errors,records,register,
        keep_records,method,workspace,nqubits(initial))
    accepted || return nothing,records,register
    final_state && return state,records,register
    draws = _shot_samples(rng,state,chosen,1,expanded)
    _readout_samples!(draws,expanded,errors,rng)
    return vec(draws),records,register
end


function _noise_configuration(circuit, noise_model, readout)
    errors = readout isa ReadoutError ? [deepcopy(readout)] : deepcopy(ReadoutError[readout...])
    if !isnothing(noise_model)
        program = with_noise(circuit,noise_model)
        circuit = program.circuit
        append!(errors,program.readout)
    end
    return circuit,errors
end

# The ordinary backend capability check handles gates and measurements. A
# stochastic channel is separately checked and compiled in _noise_preflight!,
# because its deterministic apply! capability is deliberately different.
function _stochastic_validation_circuit(circuit::QCircuit)
    operations = AbstractInstruction[]
    for instruction in circuit
        if instruction isa QCircuit
            push!(operations,_stochastic_validation_circuit(instruction))
        elseif instruction isa Conditional
            push!(operations,Conditional(instruction.condition,
                _stochastic_validation_circuit(instruction.then_branch);
                otherwise=_stochastic_validation_circuit(instruction.else_branch)))
        elseif instruction isa QuantumMap
            push!(operations,QCircuit())
        else
            push!(operations,instruction)
        end
    end
    return QCircuit(operations)
end

function _check_noise_execution(circuit, initial, chosen, method, indices, errors; classical=nothing, mode::Symbol=:execute)
    method isa AbstractNoiseMethod || throw(ArgumentError("unsupported noise method"))
    if _stochastic_noise_method(method)
        supports(chosen,method,initial) || throw(UnsupportedOperation(chosen,method,initial,:apply))
    elseif !(method isa DensityMatrixEvolution)
        throw(UnsupportedOperation(chosen,method,initial,:apply))
    end
    expanded = _readout_register(errors,indices,nqubits(initial))
    flat = _noise_preflight!(Any[],circuit,initial,chosen,method)
    checked = _stochastic_noise_method(method) && !(method isa KrausTrajectory) ? _stochastic_validation_circuit(circuit) : circuit
    _check_shot_execution(checked,initial,chosen,expanded;classical=classical,mode=mode)
    return flat,expanded
end

function _execute_noisy(circuit, initial; shots, qubits, rng, backend, noise_model,
                        readout, method, result, parallel, chunk_size, classical=nothing)
    count_shots = _execution_shots(shots)
    result in (:full,:counts) || throw(ArgumentError("result must be :full or :counts"))
    chunk_size isa Integer && !(chunk_size isa Bool) && chunk_size > 0 || throw(ArgumentError("chunk_size must be a positive integer"))
    parallel && !(method isa KrausTrajectory) && throw(ArgumentError("parallel execution currently requires KrausTrajectory"))
    circuit,errors = _noise_configuration(circuit,noise_model,readout)
    indices = _readout_qubits(initial,qubits)
    flat,expanded = _check_noise_execution(circuit,initial,backend,method,indices,errors;classical=classical)
    deterministic = method isa DensityMatrixEvolution && _shot_deterministic(circuit)
    prepared = deterministic && count_shots > 0 ? simulate(circuit,initial; backend=backend,rng=rng).state : nothing
    distribution = isnothing(prepared) ? nothing : prepare_terminal_sampling(backend,prepared,expanded)
    workspace = method isa KrausTrajectory && !parallel ? _trajectory_workspace(initial,flat) : nothing
    return _execute_prepared(initial,backend,errors,method,indices,flat,expanded,deterministic,distribution,
        classical;count_shots,rng,result,parallel,chunk_size,workspace)
end

# Both ordinary execution and prepared plans use the same sampling/RNG kernel.
function _execute_prepared(initial,backend,errors,method,indices,flat,expanded,deterministic,distribution,
                           classical;count_shots,rng,result,parallel,chunk_size,workspace=nothing)
    records = result === :full ? [MeasurementRecord[] for _ in 1:count_shots] : Vector{MeasurementRecord}[]
    registers = result === :full ? Vector{ClassicalRegister}(undef,count_shots) : ClassicalRegister[]
    accepted = result === :full ? falses(count_shots) : falses(0)
    samples = Matrix{Int}(undef,result === :full ? count_shots : 0,length(indices))
    histogram = Dict{String,Int}()
    accepted_count = 0
    for firstshot in 1:chunk_size:count_shots
        count = min(chunk_size,count_shots-firstshot+1)
        if deterministic
            draws = _checked_terminal_samples(rng,distribution,count,length(expanded))
            _readout_samples!(draws,expanded,errors,rng)
            for j in 1:count
                row = view(draws,j,1:length(indices))
                key = join(row); histogram[key] = get(histogram,key,0)+1
                accepted_count += 1
                if result === :full
                    samples[accepted_count,:] .= row
                    accepted[firstshot+j-1] = true
                    registers[firstshot+j-1] = _initial_classical(classical)
                end
            end
        else
            # Shot-indexed RNGs make serial/threaded/chunk-size choices reproduce
            # the same draws in the same Julia environment.
            seeds = [rand(rng,UInt64) for _ in 1:count]
            outcomes = Vector{Any}(undef,count)
            run = (j,work) -> (outcomes[j] = _noise_attempt(flat,initial,backend,Random.Xoshiro(seeds[j]),
                errors,expanded,result === :full,method;workspace=work,classical=classical))
            if parallel
                workers = min(Threads.nthreads(),count)
                Threads.@threads for worker in 1:workers
                    work = _trajectory_workspace(initial,flat)
                    for j in worker:workers:count
                        run(j,work)
                    end
                end
            else
                for j in 1:count
                    run(j,workspace)
                end
            end
            for j in 1:count
                row, record, register = outcomes[j]
                result === :full && (registers[firstshot+j-1] = register)
                result === :full && (records[firstshot+j-1] = record)
                isnothing(row) && continue
                row = view(row,1:length(indices))
                key = join(row); histogram[key] = get(histogram,key,0)+1
                accepted_count += 1
                if result === :full
                    samples[accepted_count,:] .= row
                    accepted[firstshot+j-1] = true
                end
            end
        end
    end
    return result === :counts ? CountsResult(count_shots,accepted_count,indices,histogram) :
        ShotResult(count_shots,indices,samples[1:accepted_count,:],histogram,records,accepted,registers)
end

function execute(program::NoisyCircuit, initial::AbstractQuantumState; noise_model=nothing, readout=ReadoutError[], kwargs...)
    isnothing(noise_model) || throw(ArgumentError("noise is already expanded"))
    errors = readout isa ReadoutError ? [readout] : collect(readout)
    return execute(program.circuit,initial; readout=vcat(program.readout,errors),kwargs...)
end

function _simulate_noisy(circuit,initial; backend,rng,noise_model,readout,method,classical=nothing)
    circuit,errors = _noise_configuration(circuit,noise_model,readout)
    flat,expanded = _check_noise_execution(circuit,initial,backend,method,Int[],errors;classical=classical,mode=:simulate)
    if _stochastic_noise_method(method) || _has_classical(circuit) || !isnothing(classical)
        _has_postselection(circuit) && throw(ArgumentError(
            "trajectory/classical simulate does not force post-selection; use execute for physical rejection"))
        state,records,register = _noise_attempt(flat,initial,backend,rng,errors,expanded,true,method;final_state=true,classical=classical)
        return SimulationResult(state,records,register)
    end
    # Preserve simulate's historical forced-conditional post-selection contract.
    prepared = simulate(circuit,initial;backend=backend,rng=rng)
    records = [MeasurementRecord(r.position,r.outcome,r.probability,r.kind,
        _reported_outcome(r.position,r.outcome,errors,rng)) for r in prepared.measurements]
    return SimulationResult(prepared.state,records)
end

function simulate(program::NoisyCircuit,initial; noise_model=nothing,readout=ReadoutError[],kwargs...)
    isnothing(noise_model) || throw(ArgumentError("noise is already expanded"))
    errors = readout isa ReadoutError ? [readout] : collect(readout)
    return simulate(program.circuit,initial;readout=vcat(program.readout,errors),kwargs...)
end
