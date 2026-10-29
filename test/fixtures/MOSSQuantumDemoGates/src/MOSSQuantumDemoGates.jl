module MOSSQuantumDemoGates

import MOSSQuantum

export DemoRotation

"""An immutable trainable Y rotation using only MOSSQuantum's public gate protocols."""
struct DemoRotation <: MOSSQuantum.ParametricGate{1}
    wire::Int
    angle::Float64
    trainable::Bool

    function DemoRotation(wire::Integer, angle::Real, trainable::Bool)
        wire >= 1 || throw(ArgumentError("the wire must be positive"))
        value = Float64(angle)
        isfinite(value) || throw(ArgumentError("the angle must be finite"))
        return new(Int(wire), value, trainable)
    end
end

DemoRotation(wire::Integer, angle::Real; trainable::Bool=true) =
    DemoRotation(wire, angle, trainable)

MOSSQuantum.positions(operation::DemoRotation) = (operation.wire,)

function MOSSQuantum.mat(operation::DemoRotation)
    sine, cosine = sincos(operation.angle / 2)
    return [cosine -sine; sine cosine]
end

MOSSQuantum.change_positions(operation::DemoRotation, mapping::AbstractDict) =
    DemoRotation(mapping[operation.wire], operation.angle, operation.trainable)

MOSSQuantum.parameters(operation::DemoRotation) = [operation.angle]
MOSSQuantum.active_parameters(operation::DemoRotation) =
    operation.trainable ? [operation.angle] : Float64[]

function MOSSQuantum.reset_parameters!(operation::DemoRotation, values::AbstractVector{<:Real})
    expected = operation.trainable ? 1 : 0
    length(values) == expected || throw(DimensionMismatch("expected $expected active parameters"))
    all(isfinite, values) || throw(ArgumentError("parameter values must be finite"))
    angle = operation.trainable ? only(values) : operation.angle
    return DemoRotation(operation.wire, angle, operation.trainable)
end

function MOSSQuantum.activate_parameter!(operation::DemoRotation, index::Int)
    index == 1 || throw(BoundsError(MOSSQuantum.parameters(operation), index))
    return MOSSQuantum.activate_parameters!(operation)
end

MOSSQuantum.activate_parameters!(operation::DemoRotation) =
    DemoRotation(operation.wire, operation.angle, true)

function MOSSQuantum.deactivate_parameter!(operation::DemoRotation, index::Int)
    index == 1 || throw(BoundsError(MOSSQuantum.parameters(operation), index))
    return MOSSQuantum.deactivate_parameters!(operation)
end

MOSSQuantum.deactivate_parameters!(operation::DemoRotation) =
    DemoRotation(operation.wire, operation.angle, false)

function MOSSQuantum.differentiate(operation::DemoRotation)
    operation.trainable || return nothing
    sine, cosine = sincos(operation.angle / 2)
    derivative = [-sine -cosine; cosine -sine] / 2
    # The public differentiation convention is (dU)' * U, in active order.
    return [MOSSQuantum.QuantumGate(MOSSQuantum.positions(operation), derivative' * MOSSQuantum.mat(operation))]
end

end
