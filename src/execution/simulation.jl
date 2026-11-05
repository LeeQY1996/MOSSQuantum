"""One recorded measurement or post-selection, before any automatic reset."""
struct MeasurementRecord
    position::Int
    outcome::Int
    probability::Float64
    kind::Symbol
    reported_outcome::Int
    key::Union{Nothing,Symbol}
end
MeasurementRecord(position::Integer, outcome::Integer, probability::Real, kind::Symbol) =
    MeasurementRecord(Int(position),Int(outcome),Float64(probability),kind,Int(outcome),nothing)
MeasurementRecord(position::Integer,outcome::Integer,probability::Real,kind::Symbol,reported::Integer) =
    MeasurementRecord(Int(position),Int(outcome),Float64(probability),kind,Int(reported),nothing)

"""
Result of one circuit execution. `state` is the final state; `measurements`
preserves intermediate outcomes in execution order, including nested circuits.
Use `sample(result.state, shots)` for terminal sampling. Reexecute `simulate`
from the initial state for independent intermediate-measurement trajectories.
"""
struct SimulationResult{S}
    state::S
    measurements::Vector{MeasurementRecord}
    classical::ClassicalRegister
end
SimulationResult(state,records::Vector{MeasurementRecord}) = SimulationResult(state,records,classical_register(records))

"""
Result of a batch circuit execution. `state` contains one final pure or mixed
state per sample, and `measurements[column]` contains that sample's intermediate records
in execution order, including nested circuits. Random draws are made in circuit
instruction order and then batch column order. An empty batch has no records.
"""
struct BatchSimulationResult{S<:Union{BatchStateVector,BatchDensityMatrix}}
    state::S
    measurements::Vector{Vector{MeasurementRecord}}
    classical::Vector{ClassicalRegister}
end
BatchSimulationResult(state,records::Vector{Vector{MeasurementRecord}}) =
    BatchSimulationResult(state,records,ClassicalRegister[classical_register(r) for r in records])

function measure!(b::AbstractBackend, state::AbstractQuantumState, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    throw(UnsupportedOperation(b, QMeasure(position; auto_reset=auto_reset), state, :apply))
end

function measure!(b::CPUBackend, state::Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix}, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    _require_cpu_storage(state, QMeasure(position; auto_reset=auto_reset))
    return _cpu_apply!(QMeasure(position; auto_reset=auto_reset), state; rng=rng)
end

function _check_simulation_batch_state(state, count::Int, instruction)
    state isa Union{BatchStateVector,BatchDensityMatrix} ||
        throw(ArgumentError("batch apply! for $(typeof(instruction)) must return a BatchStateVector or BatchDensityMatrix"))
    batch_size(state) == count ||
        throw(DimensionMismatch("batch circuit execution must preserve the number of samples ($count)."))
    dimension = _batch_dimension(nqubits(state))
    expected = state isa BatchStateVector ? (dimension, count) : (dimension, dimension, count)
    size(storage(state)) == expected ||
        throw(DimensionMismatch("batch state storage must match its sample and register dimensions."))
    return state
end

function _check_batch_record_probabilities(probabilities, state::Union{BatchStateVector,BatchDensityMatrix})
    probabilities isa AbstractVector{<:Real} ||
        throw(ArgumentError("batch measurement probabilities must be a real vector."))
    Base.require_one_based_indexing(probabilities)
    length(probabilities) == batch_size(state) ||
        throw(DimensionMismatch("batch measurement probabilities must have one entry per sample."))
    # The state can carry less precision than the record's Float64 field. A
    # normalized Float32 post-selection can have squared norm just above one.
    tolerance = _probability_tolerance(eltype(state))
    for probability in probabilities
        isfinite(probability) && 0 <= probability <= 1 + tolerance ||
            throw(DomainError(probability, "batch measurement probabilities must be finite and between zero and one."))
    end
    return probabilities
end

function _check_batch_record_outcomes(outcomes, state::Union{BatchStateVector,BatchDensityMatrix})
    outcomes isa AbstractVector{<:Integer} ||
        throw(ArgumentError("batch measurement outcomes must be an integer vector."))
    Base.require_one_based_indexing(outcomes)
    length(outcomes) == batch_size(state) ||
        throw(DimensionMismatch("batch measurement outcomes must have one entry per sample."))
    all(outcome -> outcome == 0 || outcome == 1, outcomes) ||
        throw(ArgumentError("batch measurement outcomes must be zero or one."))
    return outcomes
end

_batch_record_probability(probability::Real) = clamp(probability, zero(probability), one(probability))

function _check_batch_recorded_instructions(circuit::QCircuit, chosen_backend, state::Union{BatchStateVector,BatchDensityMatrix})
    for instruction in circuit
        if instruction isa QCircuit
            _check_batch_recorded_instructions(instruction, chosen_backend, state)
        elseif instruction isa QMeasure && !instruction.keep
            # measure!(backend, state, position) returns metadata, not a new
            # smaller-register state, so this recorded path cannot remove qubits.
            throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
        end
    end
    return nothing
end

function _simulate!(circuit::QCircuit, state::Union{BatchStateVector,BatchDensityMatrix}, chosen_backend, rng,
                    records::Vector{Vector{MeasurementRecord}})
    count = length(records)
    _check_simulation_batch_state(state, count, circuit)
    for instruction in circuit
        if instruction isa QCircuit
            state = _simulate!(instruction, state, chosen_backend, rng, records)
        elseif instruction isa QMeasure
            supports(chosen_backend, instruction, state) ||
                throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
            metadata = measure!(chosen_backend, state, instruction.position;
                                auto_reset=instruction.auto_reset, rng=rng)
            metadata isa Tuple && length(metadata) == 2 ||
                throw(ArgumentError("batch measure! must return a tuple of outcomes and probabilities."))
            outcomes, probabilities = metadata
            _check_batch_record_outcomes(outcomes, state)
            _check_batch_record_probabilities(probabilities, state)
            for column in 1:batch_size(state)
                push!(records[column], MeasurementRecord(instruction.position, outcomes[column],
                                                        _batch_record_probability(probabilities[column]), :measurement))
            end
        elseif instruction isa QSelect
            supports(chosen_backend, instruction, state) ||
                throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
            probabilities = apply!(chosen_backend, instruction, state)
            _check_batch_record_probabilities(probabilities, state)
            for column in 1:batch_size(state)
                push!(records[column], MeasurementRecord(instruction.position, instruction.state,
                                                        _batch_record_probability(probabilities[column]), :postselection))
            end
        else
            state = apply!(chosen_backend, instruction, state)
        end
        _check_simulation_batch_state(state, count, instruction)
    end
    return state
end

function _simulate!(circuit::QCircuit, state, chosen_backend, rng, records)
    for instruction in circuit
        if instruction isa QCircuit
            state = _simulate!(instruction, state, chosen_backend, rng, records)
        elseif instruction isa QMeasure
            supports(chosen_backend, instruction, state) || throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
            outcome, probability = measure!(chosen_backend, state, instruction.position; auto_reset=instruction.auto_reset, rng=rng)
            push!(records, MeasurementRecord(instruction.position, outcome, probability, :measurement))
        elseif instruction isa QSelect
            supports(chosen_backend, instruction, state) || throw(UnsupportedOperation(chosen_backend, instruction, state, :apply))
            probability = apply!(chosen_backend, instruction, state)
            push!(records, MeasurementRecord(instruction.position, instruction.state, probability, :postselection))
        else
            state = apply!(chosen_backend, instruction, state)
            state isa AbstractQuantumState ||
                throw(ArgumentError("apply! for $(typeof(instruction)) must return an AbstractQuantumState"))
        end
    end
    return state
end

"""
    simulate(circuit, initial_state; backend=backend(initial_state), rng=Random.default_rng())

Execute a circuit on a copy of its initial state and retain measurement records.
Type promotion can replace the state wrapper. This stochastic execution API does
not define automatic derivatives; analytic circuit application remains available
through `circuit * state` and `expectation`.
"""
function simulate(circuit::QCircuit, state; backend=MOSSQuantum.backend(state), rng::Random.AbstractRNG=Random.default_rng(),
                  noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(), classical=nothing)
    QuantumCircuits._require_bound_parameters(circuit)
    checked = method isa AbstractNoiseMethod && _stochastic_noise_method(method) && !(method isa KrausTrajectory) ?
        _stochastic_validation_circuit(circuit) : circuit
    validate_backend_execution(backend, checked, state; mode=:simulate)
    if _has_classical(circuit) || !isnothing(classical) || !isnothing(noise_model) || readout isa ReadoutError || !isempty(readout) || !(method isa DensityMatrixEvolution)
        return _simulate_noisy(circuit,state;backend,rng,noise_model,readout,method,classical)
    end
    supports(backend, circuit, state) || throw(UnsupportedOperation(backend, circuit, state, :apply))
    validate_positions(circuit, nqubits(state))
    records = MeasurementRecord[]
    result = _simulate!(circuit, copy(state), backend, rng, records)
    return SimulationResult(result, records)
end

function simulate(circuit::QCircuit, state::Union{BatchStateVector,BatchDensityMatrix}; backend=MOSSQuantum.backend(state),
                  rng::Random.AbstractRNG=Random.default_rng(), noise_model=nothing,
                  readout=ReadoutError[], method=DensityMatrixEvolution(), classical=nothing)
    QuantumCircuits._require_bound_parameters(circuit)
    validate_backend_execution(backend, circuit, state; mode=:simulate)
    if _has_classical(circuit) || !isnothing(classical) || !isnothing(noise_model) || readout isa ReadoutError || !isempty(readout) || !(method isa DensityMatrixEvolution)
        circuit,errors = _noise_configuration(circuit,noise_model,readout)
        _check_noise_execution(circuit,state,backend,method,Int[],errors;classical=classical,mode=:simulate)
        (method isa KrausTrajectory || _has_classical(circuit) || !isnothing(classical)) &&
            _has_postselection(circuit) && throw(ArgumentError("use execute for trajectory/classical post-selection"))
        members = [_simulate_noisy(circuit,_shot_member(state,b);backend,rng,noise_model=nothing,readout=errors,method,classical)
                   for b in 1:batch_size(state)]
        if isempty(members)
            output = _empty_dynamic_batch(circuit,state,method)
        elseif all(r -> r.state isa StateVector,members)
            output = BatchStateVector(hcat([storage(r.state) for r in members]...))
        else
            output = BatchDensityMatrix(cat([storage(r.state isa StateVector ? DensityMatrix(r.state) : r.state) for r in members]...;dims=3))
        end
        return BatchSimulationResult(output,Vector{MeasurementRecord}[r.measurements for r in members],ClassicalRegister[r.classical for r in members])
    end
    supports(backend, circuit, state) || throw(UnsupportedOperation(backend, circuit, state, :apply))
    _check_batch_recorded_instructions(circuit, backend, state)
    validate_positions(circuit, nqubits(state))
    backend isa CPUBackend && _check_batch_cpu_instructions(circuit, state)
    records = [MeasurementRecord[] for _ in 1:batch_size(state)]
    result = _simulate!(circuit, copy(state), backend, rng, records)
    return BatchSimulationResult(result, records)
end
