"""One recorded measurement or post-selection, before any automatic reset."""
struct MeasurementRecord
    position::Int
    outcome::Int
    probability::Float64
    kind::Symbol
end

"""
Result of one circuit execution. `state` is the final state; `measurements`
preserves intermediate outcomes in execution order, including nested circuits.
Use `sample(result.state, shots)` for terminal sampling. Reexecute `simulate`
from the initial state for independent intermediate-measurement trajectories.
"""
struct SimulationResult{S}
    state::S
    measurements::Vector{MeasurementRecord}
end

"""
Result of a batch circuit execution. `state` contains one final pure state per
column, and `measurements[column]` contains that sample's intermediate records
in execution order, including nested circuits. Random draws are made in circuit
instruction order and then batch column order. An empty batch has no records.
"""
struct BatchSimulationResult{S<:BatchStateVector}
    state::S
    measurements::Vector{Vector{MeasurementRecord}}
end

function measure!(b::AbstractBackend, state::AbstractQuantumState, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    throw(UnsupportedOperation(b, QMeasure(position; auto_reset=auto_reset), state, :apply))
end

function measure!(b::CPUBackend, state::Union{StateVector,DensityMatrix,BatchStateVector}, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    return measure!(state, position; auto_reset=auto_reset, rng=rng)
end

function _check_simulation_batch_state(state, count::Int, instruction)
    state isa BatchStateVector ||
        throw(ArgumentError("batch apply! for $(typeof(instruction)) must return a BatchStateVector"))
    batch_size(state) == count ||
        throw(DimensionMismatch("batch circuit execution must preserve the number of samples ($count)."))
    size(storage(state)) == (2^nqubits(state), count) ||
        throw(DimensionMismatch("batch state storage must match its sample and register dimensions."))
    return state
end

function _check_batch_record_probabilities(probabilities, state::BatchStateVector)
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

function _check_batch_record_outcomes(outcomes, state::BatchStateVector)
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

function _check_batch_recorded_instructions(circuit::QCircuit, chosen_backend, state::BatchStateVector)
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

function _simulate!(circuit::QCircuit, state::BatchStateVector, chosen_backend, rng,
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
function simulate(circuit::QCircuit, state; backend=MOSS.backend(state), rng::Random.AbstractRNG=Random.default_rng())
    records = MeasurementRecord[]
    result = _simulate!(circuit, copy(state), backend, rng, records)
    return SimulationResult(result, records)
end

function simulate(circuit::QCircuit, state::BatchStateVector; backend=MOSS.backend(state),
                  rng::Random.AbstractRNG=Random.default_rng())
    supports(backend, circuit, state) || throw(UnsupportedOperation(backend, circuit, state, :apply))
    _check_batch_recorded_instructions(circuit, backend, state)
    validate_positions(circuit, nqubits(state))
    records = [MeasurementRecord[] for _ in 1:batch_size(state)]
    result = _simulate!(circuit, copy(state), backend, rng, records)
    return BatchSimulationResult(result, records)
end
