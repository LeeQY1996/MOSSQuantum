"""
    ShotResult

Result of `execute`. `shots` is the number of attempted circuit executions.
`accepted` has one entry per attempt; `measurements` records every attempt,
including the first failed post-selection. Rows of `samples` correspond to
`findall(accepted)`, and columns follow `qubits`. `counts` contains accepted
terminal outcomes only, so its total is `count(accepted)`, not necessarily `shots`.
No final state is retained for each shot.
"""
struct ShotResult
    shots::Int
    qubits::Vector{Int}
    samples::Matrix{Int}
    counts::Dict{String,Int}
    measurements::Vector{Vector{MeasurementRecord}}
    accepted::BitVector
    classical::Vector{ClassicalRegister}
end
ShotResult(shots,qubits,samples,counts,records,accepted) =
    ShotResult(shots,qubits,samples,counts,records,accepted,ClassicalRegister[classical_register(r) for r in records])

function _execution_shots(shots::Integer)
    shots isa Bool && throw(ArgumentError("shots must be a nonnegative integer, not Bool"))
    0 <= shots <= typemax(Int) || throw(ArgumentError("shots must fit a nonnegative Int"))
    return Int(shots)
end

# Shot execution implements post-selection as an actual measurement followed by
# rejection. The single-trajectory simulate API keeps its conditional semantics.
function _shot_validation_circuit(circuit::QCircuit, state, chosen_backend)
    operations = AbstractInstruction[]
    for instruction in circuit
        if instruction isa QCircuit
            push!(operations, _shot_validation_circuit(instruction, state, chosen_backend))
        elseif instruction isa Conditional
            append!(operations,_shot_validation_circuit(instruction.then_branch,state,chosen_backend).operations)
            append!(operations,_shot_validation_circuit(instruction.else_branch,state,chosen_backend).operations)
        elseif instruction isa QSelect
            push!(operations, QMeasure(instruction.position; auto_reset=false))
        else
            instruction isa QMeasure && !instruction.keep &&
                throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
            push!(operations, instruction)
        end
    end
    return QCircuit(operations)
end

_shot_deterministic(instruction::AbstractInstruction) = instruction isa Union{Gate,QuantumMap,Delay}
_shot_deterministic(circuit::QCircuit) = all(_shot_deterministic, circuit)
_has_postselection(instruction::AbstractInstruction) = instruction isa QSelect
_has_postselection(circuit::QCircuit) = any(_has_postselection, circuit)
_has_postselection(x::Conditional) = _has_postselection(x.then_branch) || _has_postselection(x.else_branch)

function _check_shot_execution(circuit::QCircuit, state::AbstractQuantumState, chosen_backend, qubits; classical=nothing, mode::Symbol=:execute)
    validate_backend_execution(chosen_backend, circuit, state; mode=mode)
    _validate_classical_flow(circuit,_initial_classical(classical))
    indices = _readout_qubits(state, qubits)
    validate_positions(circuit, nqubits(state))
    checked = _shot_validation_circuit(circuit, state, chosen_backend)
    supports(chosen_backend, checked, state) ||
        throw(UnsupportedOperation(chosen_backend, circuit, state, :apply))
    # Validate normalization and readout support even for zero shots. Ask for the
    # requested marginal through the selected backend, never a CPU fallback.
    probabilities(chosen_backend, state; qubits=indices)
    return indices
end

function _shot_distribution(state, chosen_backend, indices)
    distribution = probabilities(chosen_backend, state; qubits=indices)
    distribution isa AbstractVector{<:Real} ||
        throw(ArgumentError("terminal probabilities must be a real vector"))
    Base.require_one_based_indexing(distribution)
    length(distribution) == _state_dimension(length(indices)) ||
        throw(DimensionMismatch("terminal probabilities must match the selected qubits"))
    return distribution
end

function _shot_samples(rng, state, chosen_backend, shots, indices)
    distribution = _shot_distribution(state,chosen_backend,indices)
    output = Matrix{Int}(undef, shots, length(indices))
    return _draw_samples!(output, rng, distribution, shots, length(indices))
end

function _shot_record(position, outcome, probability, kind)
    outcome isa Integer && outcome in (0, 1) ||
        throw(ArgumentError("measurement outcomes must be zero or one"))
    probability isa Real && isfinite(probability) ||
        throw(ArgumentError("measurement probabilities must be finite real values"))
    tolerance = _probability_tolerance(typeof(probability))
    0 <= probability <= 1 + tolerance ||
        throw(DomainError(probability, "measurement probabilities must lie between zero and one"))
    return MeasurementRecord(position, Int(outcome), clamp(Float64(probability), 0, 1), kind)
end

function _execute_shot!(circuit::QCircuit, state, chosen_backend, rng, records, register_size)
    for instruction in circuit
        if instruction isa QCircuit
            state, accepted = _execute_shot!(instruction, state, chosen_backend, rng, records, register_size)
            accepted || return state, false
        elseif instruction isa Union{QMeasure,QSelect}
            reset = instruction isa QMeasure && instruction.auto_reset
            outcome, probability = measure!(chosen_backend, state, instruction.position;
                                             auto_reset=reset, rng=rng)
            kind = instruction isa QSelect ? :postselection : :measurement
            push!(records, _shot_record(instruction.position, outcome, probability, kind))
            instruction isa QSelect && outcome != instruction.state && return state, false
        else
            state = apply!(chosen_backend, instruction, state)
        end
        state isa AbstractQuantumState ||
            throw(ArgumentError("shot execution must return an AbstractQuantumState"))
        nqubits(state) == register_size ||
            throw(DimensionMismatch("shot execution must preserve the register size"))
    end
    return state, true
end

"""
    execute(circuit, initial_state; shots, qubits=1:nqubits(initial_state), rng, backend)

Run a circuit for a fixed number of attempted shots without modifying its input.
Each shot replays intermediate measurements from a fresh state. `QSelect` is a
physical measurement and rejection: failed attempts consume a shot and contribute
no terminal sample. This differs from `simulate`'s forced conditional selection.
Measurement auto-reset behavior is taken from each `QMeasure` instruction.

For deterministic gate/Kraus circuits, evolve once and sample the final
distribution. For batches, return one `ShotResult` per member, with the full
`shots` budget for each member and a shared RNG consumed in member order.
This API has no automatic differentiation contract.
"""
function execute(circuit::QCircuit, initial_state::AbstractQuantumState;
                 shots::Integer, qubits=1:nqubits(initial_state),
                 rng::Random.AbstractRNG=Random.default_rng(), backend=MOSSQuantum.backend(initial_state),
                 noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(),
                 result::Symbol=:full, parallel::Bool=false, chunk_size::Integer=256, classical=nothing)
    chunk_size > 0 && !(chunk_size isa Bool) || throw(ArgumentError("chunk_size must be positive"))
    if _has_classical(circuit) || !isnothing(classical) || !isnothing(noise_model) || readout isa ReadoutError || !isempty(readout) ||
       !(method isa DensityMatrixEvolution) || result !== :full || parallel
        return _execute_noisy(circuit,initial_state; shots,qubits,rng,backend,noise_model,
                              readout,method,result,parallel,chunk_size,classical)
    end
    count_shots = _execution_shots(shots)
    indices = _check_shot_execution(circuit, initial_state, backend, qubits)
    _noise_preflight!(Any[],circuit,initial_state,backend,method)
    records = [MeasurementRecord[] for _ in 1:count_shots]
    accepted = falses(count_shots)
    output = Matrix{Int}(undef, count_shots, length(indices))
    if count_shots == 0
        return ShotResult(0, indices, output, Dict{String,Int}(), records, accepted)
    elseif _shot_deterministic(circuit)
        final_state = simulate(circuit, initial_state; backend=backend, rng=rng).state
        nqubits(final_state) == nqubits(initial_state) ||
            throw(DimensionMismatch("shot execution must preserve the register size"))
        output = _shot_samples(rng, final_state, backend, count_shots, indices)
        fill!(accepted, true)
    else
        row = 0
        for shot in 1:count_shots
            state, kept = _execute_shot!(circuit, copy(initial_state), backend, rng,
                                         records[shot], nqubits(initial_state))
            accepted[shot] = kept
            if kept
                row += 1
                output[row, :] .= vec(_shot_samples(rng, state, backend, 1, indices))
            end
        end
        output = output[1:row, :]
    end
    return ShotResult(count_shots, indices, output, _sample_counts(output), records, accepted)
end

_shot_member(state::BatchStateVector, member::Int) = StateVector(state, member)
_shot_member(state::BatchDensityMatrix, member::Int) = DensityMatrix(state, member)

function execute(circuit::QCircuit, initial_state::Union{BatchStateVector,BatchDensityMatrix};
                 shots::Integer, qubits=1:nqubits(initial_state),
                 rng::Random.AbstractRNG=Random.default_rng(), backend=MOSSQuantum.backend(initial_state),
                 noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(),
                 result::Symbol=:full, parallel::Bool=false, chunk_size::Integer=256, classical=nothing)
    _execution_shots(shots)
    result in (:full,:counts) || throw(ArgumentError("result must be :full or :counts"))
    chunk_size > 0 && !(chunk_size isa Bool) || throw(ArgumentError("chunk_size must be positive"))
    parallel && !(method isa KrausTrajectory) && throw(ArgumentError("parallel requires KrausTrajectory"))
    circuit,errors = _noise_configuration(circuit,noise_model,readout)
    indices = _readout_qubits(initial_state,qubits)
    _check_noise_execution(circuit,initial_state,backend,method,indices,errors;classical=classical)
    R = result === :full ? ShotResult : CountsResult
    return R[execute(circuit,_shot_member(initial_state,member); shots=shots,qubits=indices,
        rng=rng,backend=backend,readout=errors,method=method,result=result,parallel=parallel,
        chunk_size=chunk_size,classical=classical) for member in 1:batch_size(initial_state)]
end

"""Circuit-level samples; a batch returns a vector of accepted-shot matrices."""
function sample(rng::Random.AbstractRNG, circuit::Union{QCircuit,NoisyCircuit}, state::AbstractQuantumState,
                shots::Integer; kwargs...)
    result = execute(circuit, state; shots=shots, rng=rng, kwargs...)
    (result isa CountsResult || result isa Vector{CountsResult}) && throw(ArgumentError("sample requires result=:full"))
    return result isa ShotResult ? result.samples : [item.samples for item in result]
end
sample(circuit::Union{QCircuit,NoisyCircuit}, state::AbstractQuantumState, shots::Integer;
       rng::Random.AbstractRNG=Random.default_rng(), kwargs...) = sample(rng, circuit, state, shots; kwargs...)

"""Circuit-level counts; failed post-selections are excluded from the histogram."""
function counts(rng::Random.AbstractRNG, circuit::Union{QCircuit,NoisyCircuit}, state::AbstractQuantumState,
                shots::Integer; kwargs...)
    result = execute(circuit, state; shots=shots, rng=rng, kwargs...)
    return result isa Union{ShotResult,CountsResult} ? result.counts : [item.counts for item in result]
end
counts(circuit::Union{QCircuit,NoisyCircuit}, state::AbstractQuantumState, shots::Integer;
       rng::Random.AbstractRNG=Random.default_rng(), kwargs...) = counts(rng, circuit, state, shots; kwargs...)
