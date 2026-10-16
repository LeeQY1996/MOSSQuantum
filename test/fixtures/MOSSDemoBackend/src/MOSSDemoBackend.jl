module MOSSDemoBackend

import MOSS

export DemoBackend, DemoState, DemoFlip

"""A small backend for computational-basis product states."""
struct DemoBackend <: MOSS.AbstractBackend end

"""An implicit product state requiring one bit, rather than two amplitudes, per qubit."""
struct DemoState <: MOSS.AbstractQuantumState
    bits::BitVector
end

DemoState(n::Integer) = DemoState(falses(n))
Base.copy(state::DemoState) = DemoState(copy(state.bits))
MOSS.nqubits(state::DemoState) = length(state.bits)
MOSS.backend(::DemoState) = DemoBackend()

"""An example instruction outside the built-in gate and channel hierarchies."""
struct DemoFlip{N} <: MOSS.AbstractInstruction
    positions::NTuple{N,Int}
end

DemoFlip(position::Int) = DemoFlip((position,))
MOSS.positions(operation::DemoFlip) = operation.positions
MOSS.change_positions(operation::DemoFlip, mapping::AbstractDict) =
    DemoFlip(map(position -> mapping[position], operation.positions))

MOSS.supports(::DemoBackend, ::Union{DemoFlip,MOSS.XGate}, ::DemoState; action::Symbol=:apply) =
    action === :apply

MOSS.supports(::DemoBackend, ::MOSS.ZGate, ::DemoState; action::Symbol=:apply) =
    action === :expectation

function MOSS.apply!(b::DemoBackend, operation::Union{DemoFlip,MOSS.XGate}, state::DemoState)
    MOSS.supports(b, operation, state) || throw(MOSS.UnsupportedOperation(b, operation, state, :apply))
    MOSS.validate_positions(operation, MOSS.nqubits(state))
    for position in MOSS.positions(operation)
        state.bits[position] = !state.bits[position]
    end
    return state
end

function MOSS.expectation(::DemoBackend, observable::MOSS.ZGate, state::DemoState)
    MOSS.validate_positions(observable, MOSS.nqubits(state))
    return state.bits[first(MOSS.positions(observable))] ? -1.0 : 1.0
end

end
