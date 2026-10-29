module MOSSQuantumDemoBackend

import MOSSQuantum

export DemoBackend, DemoState, DemoFlip

"""A small backend for computational-basis product states."""
struct DemoBackend <: MOSSQuantum.AbstractBackend end

"""An implicit product state requiring one bit, rather than two amplitudes, per qubit."""
struct DemoState <: MOSSQuantum.AbstractQuantumState
    bits::BitVector
end

DemoState(n::Integer) = DemoState(falses(n))
Base.copy(state::DemoState) = DemoState(copy(state.bits))
MOSSQuantum.nqubits(state::DemoState) = length(state.bits)
MOSSQuantum.backend(::DemoState) = DemoBackend()

"""An example instruction outside the built-in gate and channel hierarchies."""
struct DemoFlip{N} <: MOSSQuantum.AbstractInstruction
    positions::NTuple{N,Int}
end

DemoFlip(position::Int) = DemoFlip((position,))
MOSSQuantum.positions(operation::DemoFlip) = operation.positions
MOSSQuantum.change_positions(operation::DemoFlip, mapping::AbstractDict) =
    DemoFlip(map(position -> mapping[position], operation.positions))

MOSSQuantum.supports(::DemoBackend, ::Union{DemoFlip,MOSSQuantum.XGate}, ::DemoState; action::Symbol=:apply) =
    action === :apply

MOSSQuantum.supports(::DemoBackend, ::MOSSQuantum.ZGate, ::DemoState; action::Symbol=:apply) =
    action === :expectation

function MOSSQuantum.apply!(b::DemoBackend, operation::Union{DemoFlip,MOSSQuantum.XGate}, state::DemoState)
    MOSSQuantum.supports(b, operation, state) || throw(MOSSQuantum.UnsupportedOperation(b, operation, state, :apply))
    MOSSQuantum.validate_positions(operation, MOSSQuantum.nqubits(state))
    for position in MOSSQuantum.positions(operation)
        state.bits[position] = !state.bits[position]
    end
    return state
end

function MOSSQuantum.expectation(::DemoBackend, observable::MOSSQuantum.ZGate, state::DemoState)
    MOSSQuantum.validate_positions(observable, MOSSQuantum.nqubits(state))
    return state.bits[first(MOSSQuantum.positions(observable))] ? -1.0 : 1.0
end

end
