module MOSSQuantumDemoDifferentiation

import MOSSQuantum

export ScalarObjective, DirectExecutor, ExpandedExecutor
export CoordinateGradient, ExpandedGradient

"""An executor returning only a scalar, with no quantum-state interface."""
mutable struct DirectExecutor
    evaluations::Int
end
DirectExecutor() = DirectExecutor(0)

"""An interchangeable executor using an expanded expression for the same scalar."""
mutable struct ExpandedExecutor
    evaluations::Int
end
ExpandedExecutor() = ExpandedExecutor(0)

"""A two-parameter scalar objective independent of MOSSQuantum state and backend types."""
struct ScalarObjective{E}
    executor::E
    center::NTuple{2,Float64}
end
ScalarObjective(executor; center=(-0.2, 0.4)) =
    ScalarObjective(executor, (Float64(center[1]), Float64(center[2])))

function checked_pair(values::AbstractVector{<:Real})
    Base.require_one_based_indexing(values)
    length(values) == 2 || throw(DimensionMismatch("the demo objective takes two values"))
    all(isfinite, values) || throw(ArgumentError("demo values must be finite"))
    return values[1], values[2]
end

function execute(executor::DirectExecutor, center, first, second)
    executor.evaluations += 1
    x, y = first - center[1], second - center[2]
    return x * x + 3 * y * y + x * y
end

function execute(executor::ExpandedExecutor, center, first, second)
    executor.evaluations += 1
    a, b = center
    return first * first + 3 * second * second + first * second -
        (2a + b) * first - (a + 6b) * second + a * a + 3b * b + a * b
end

function MOSSQuantum.evaluate(objective::ScalarObjective, values::AbstractVector{<:Real})
    first, second = checked_pair(values)
    return execute(objective.executor, objective.center, first, second)
end

"""A closed-form coordinate derivative; the scratch buffer is deliberately reused."""
mutable struct CoordinateGradient <: MOSSQuantum.AbstractGradientMethod
    calls::Int
    scratch::Vector{Float64}
end
CoordinateGradient() = CoordinateGradient(0, zeros(2))

"""An independent closed-form derivative of the expanded polynomial."""
mutable struct ExpandedGradient <: MOSSQuantum.AbstractGradientMethod
    calls::Int
    scratch::Vector{Float64}
end
ExpandedGradient() = ExpandedGradient(0, zeros(2))

MOSSQuantum.supports_gradient(::Union{CoordinateGradient,ExpandedGradient}, ::ScalarObjective) = true

function MOSSQuantum.value_and_gradient(method::CoordinateGradient, objective::ScalarObjective,
                                 values::AbstractVector{<:Real})
    first, second = checked_pair(values)
    value = MOSSQuantum.evaluate(objective, values)
    method.calls += 1
    x, y = first - objective.center[1], second - objective.center[2]
    method.scratch[1] = 2x + y
    method.scratch[2] = x + 6y
    return value, method.scratch
end

function MOSSQuantum.value_and_gradient(method::ExpandedGradient, objective::ScalarObjective,
                                 values::AbstractVector{<:Real})
    first, second = checked_pair(values)
    value = MOSSQuantum.evaluate(objective, values)
    method.calls += 1
    a, b = objective.center
    method.scratch[1] = 2first + second - (2a + b)
    method.scratch[2] = first + 6second - (a + 6b)
    return value, method.scratch
end

end
