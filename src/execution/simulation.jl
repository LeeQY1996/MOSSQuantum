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

function measure!(b::AbstractBackend, state::AbstractQuantumState, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    throw(UnsupportedOperation(b, QMeasure(position; auto_reset=auto_reset), state, :apply))
end

function measure!(b::CPUBackend, state::Union{StateVector,DensityMatrix}, position::Int;
                  auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    return measure!(state, position; auto_reset=auto_reset, rng=rng)
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
