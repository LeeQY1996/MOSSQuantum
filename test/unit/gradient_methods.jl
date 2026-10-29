using Test, MOSSQuantum

module GradientProtocolFixtures
import MOSSQuantum
struct Objective
    forward_calls::Base.RefValue{Int}
end
struct AnalyticMethod <: MOSSQuantum.AbstractGradientMethod
    calls::Base.RefValue{Int}
    scratch::Vector{Float64}
end
struct UnsupportedMethod <: MOSSQuantum.AbstractGradientMethod end
struct MissingMethod <: MOSSQuantum.AbstractGradientMethod end
struct MalformedMethod <: MOSSQuantum.AbstractGradientMethod
    value
    gradient
end
MOSSQuantum.evaluate(objective::Objective, values::AbstractVector{<:Real}) =
    (objective.forward_calls[] += 1; sum(abs2, values))
MOSSQuantum.supports_gradient(::AnalyticMethod, ::Objective) = true
MOSSQuantum.supports_gradient(::MissingMethod, ::Objective) = true
MOSSQuantum.supports_gradient(::MalformedMethod, ::Objective) = true
function MOSSQuantum.value_and_gradient(method::AnalyticMethod, ::Objective, values::AbstractVector{<:Real})
    method.calls[] += 1
    resize!(method.scratch, length(values))
    method.scratch .= 2 .* values
    return sum(abs2, values), method.scratch
end
MOSSQuantum.value_and_gradient(method::MalformedMethod, ::Objective, ::AbstractVector{<:Real}) =
    (method.value, method.gradient)
end

@testset "Replaceable numerical gradient protocol" begin
    F = GradientProtocolFixtures
    objective = F.Objective(Ref(0))
    method = F.AnalyticMethod(Ref(0), Float64[])
    values = [0.3, -0.4]
    @test evaluate(objective, values) ≈ 0.25
    @test evaluate(x -> sum(abs2, x), values) ≈ 0.25
    @test method.calls[] == 0
    @test supports_gradient(method, objective)
    @test !supports_gradient(AdjointGradient(), objective)
    @test !supports_gradient(F.UnsupportedMethod(), objective)
    @test differentiable_value(method, objective, values) ≈ 0.25
    @test method.calls[] == 0
    @test differentiable_value(F.UnsupportedMethod(), objective, values) ≈ 0.25
    @test objective.forward_calls[] == 3

    value, gradient = value_and_gradient(method, objective, values)
    @test value ≈ 0.25
    @test gradient ≈ [0.6, -0.8]
    @test method.calls[] == 1
    value, back = value_and_pullback(method, objective, values)
    @test value ≈ 0.25
    @test method.calls[] == 2
    @test objective.forward_calls[] == 3
    method.scratch .= 99
    values .= 7
    @test back(1.0) ≈ [0.6, -0.8]
    @test back(-2.0) ≈ [-1.2, 1.6]
    previous = back(1.0)
    previous .= 99
    @test back(1.0) ≈ [0.6, -0.8]
    @test method.calls[] == 2

    @test_throws UnsupportedGradient value_and_gradient(F.UnsupportedMethod(), objective, [0.2])
    @test_throws UnsupportedGradient value_and_pullback(F.UnsupportedMethod(), objective, [0.2])
    @test_throws UnsupportedGradient value_and_pullback(F.MissingMethod(), objective, [0.2])
    @test_throws ArgumentError evaluate(nothing, [0.2])
    error = UnsupportedGradient(F.UnsupportedMethod(), objective)
    @test occursin("parameter gradients", sprint(showerror, error))

    @test_throws ArgumentError value_and_pullback(method, objective, [NaN])
    @test_throws ArgumentError differentiable_value(method, objective, [Inf])
    for bad in (F.MalformedMethod(1im, [1.0]), F.MalformedMethod([1.0], [1.0]),
                F.MalformedMethod(1.0, 1.0), F.MalformedMethod(1.0, [1im]))
        @test_throws ArgumentError value_and_pullback(bad, objective, [0.2])
    end
    @test_throws DimensionMismatch value_and_pullback(F.MalformedMethod(1.0, [1.0, 2.0]), objective, [0.2])
    nonfinite = F.MalformedMethod(Inf, [NaN])
    value, back = value_and_pullback(nonfinite, objective, [0.2])
    @test isinf(value)
    @test isnan(only(back(1.0)))
    value, back = value_and_pullback(method, objective, Float64[])
    @test value == 0
    @test isempty(back(1.0))
end
