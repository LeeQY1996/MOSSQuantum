"""
    AbstractGradientMethod

A replaceable numerical differentiation strategy. Execution is a separate
`evaluate(objective, values)` operation. External objectives need not subtype a
MOSS type or expose quantum states, and external strategies implement public
`supports_gradient` and `value_and_gradient` methods. A strategy may additionally
specialize `value_and_pullback` to reuse a forward execution.

The current interface differentiates real scalar objectives with respect to an
explicit real parameter vector. It does not prescribe an AD framework, backend,
or a particular gradient algorithm.
"""
abstract type AbstractGradientMethod end

"""The existing deterministic dense CPU circuit reverse pass."""
struct AdjointGradient <: AbstractGradientMethod end

"""A gradient strategy does not support this objective."""
struct UnsupportedGradient <: Exception
    method_type::Type
    objective_type::Type
end
UnsupportedGradient(method::AbstractGradientMethod, objective) =
    UnsupportedGradient(typeof(method), typeof(objective))

function Base.showerror(io::IO, error::UnsupportedGradient)
    print(io, error.method_type, " does not support parameter gradients for ", error.objective_type)
end

"""
    evaluate(objective, values::AbstractVector{<:Real}) -> Real

Execute a scalar objective without selecting or invoking a gradient method.
Implement this public operation for an external objective; it need not expose
an `AbstractQuantumState`, dense storage, or AD rules. Implementations preserve
the caller's parameter vector. Function objectives can be passed directly.
"""
function evaluate(objective, values::AbstractVector{<:Real})
    throw(ArgumentError("$(typeof(objective)) must implement evaluate(objective, values)."))
end
evaluate(objective::Function, values::AbstractVector{<:Real}) = objective(values)

"""
    supports_gradient(method::AbstractGradientMethod, objective) -> Bool

Query support for derivatives of the objective's explicit parameter vector.
Unknown combinations return `false`. Forward execution support is separate;
successful evaluation does not imply any differentiation capability.
"""
supports_gradient(::AbstractGradientMethod, objective) = false

function _require_gradient_support(method::AbstractGradientMethod, objective)
    supports_gradient(method, objective) || throw(UnsupportedGradient(method, objective))
    return nothing
end

function _check_gradient_input(values::AbstractVector{<:Real})
    Base.require_one_based_indexing(values)
    all(isfinite, values) || throw(ArgumentError("parameter values must be finite."))
    return values
end

function _check_objective_value(value)
    value isa Real || throw(ArgumentError("a differentiable objective must return a real scalar."))
    return value
end

function _check_parameter_gradient(gradient, values::AbstractVector{<:Real})
    gradient isa AbstractVector{<:Real} ||
        throw(ArgumentError("a parameter gradient must be a real vector."))
    length(gradient) == length(values) ||
        throw(DimensionMismatch("expected $(length(values)) parameter gradients, received $(length(gradient))."))
    Base.require_one_based_indexing(gradient)
    return gradient
end

"""
    value_and_gradient(method::AbstractGradientMethod, objective, values) -> (value, gradient)

Compute a real scalar value and its gradient in the independent parameter order
of `values`. External methods implement this public hook and declare support
with `supports_gradient`. The default throws `UnsupportedGradient` and never
selects another algorithm. No AD package is required to call this operation.

Inputs remain unchanged. Gradients are real vectors with one entry per input;
their numerical precision is chosen by the strategy. Nonfinite gradients may
propagate. AD adapters separately project cotangents to the input domain.
"""
function value_and_gradient(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
    throw(UnsupportedGradient(method, objective))
end

"""
    value_and_pullback(method::AbstractGradientMethod, objective, values) -> (value, back)

Prepare a numerical scalar pullback: `back(seed::Real)` returns only the
parameter gradient multiplied by `seed`, not an AD framework's cotangent tuple.
Repeated calls must be independent and must not consume saved state.

The fallback calls `value_and_gradient` once, validates the result, and caches a
private copy of its gradient. It is eager; methods may specialize this operation
to defer the reverse pass and reuse forward work. There is no recursion between
the default gradient and pullback hooks. External methods implementing only the
gradient hook can therefore use the optional AD adapter unchanged.
"""
function value_and_pullback(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
    _require_gradient_support(method, objective)
    _check_gradient_input(values)
    value, gradient = value_and_gradient(method, objective, values)
    _check_objective_value(value)
    saved = copy(_check_parameter_gradient(gradient, values))
    return value, (seed::Real) -> seed .* saved
end

"""
    differentiable_value(method::AbstractGradientMethod, objective, values) -> Real

Evaluate an objective with an explicit differentiation policy for optional AD
adapters. An ordinary call only invokes `evaluate`, even if the method does not
support differentiation. With ChainRulesCore loaded, the reverse rule dispatches
to the public `value_and_pullback` hook. Only `values` is differentiable through
this entrypoint; the method and objective are fixed configuration.

Use `evaluate` for execution alone, or `value_and_gradient` for explicit numerical
derivatives without an AD framework. None of these choices modifies execution
backends or the existing circuit APIs.
"""
function differentiable_value(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
    _check_gradient_input(values)
    return _check_objective_value(evaluate(objective, values))
end
