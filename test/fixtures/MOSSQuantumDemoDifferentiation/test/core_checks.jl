module DemoDifferentiationCoreChecks

using Test
import MOSSQuantum

struct UnsupportedMethod <: MOSSQuantum.AbstractGradientMethod end

# These deliberately invalid implementations exercise the public adapter boundary.
struct MalformedMethod <: MOSSQuantum.AbstractGradientMethod
    kind::Symbol
end
MOSSQuantum.supports_gradient(::MalformedMethod, objective) = true

struct ZeroBasedVector{T} <: AbstractVector{T}
    data::Vector{T}
end
Base.size(values::ZeroBasedVector) = size(values.data)
Base.axes(values::ZeroBasedVector) = (0:(length(values.data) - 1),)
Base.getindex(values::ZeroBasedVector, index::Int) = values.data[index + 1]

function MOSSQuantum.value_and_gradient(method::MalformedMethod, objective,
                                 values::AbstractVector{<:Real})
    kind = method.kind
    kind == :vector_value && return [1.0], zeros(2)
    kind == :complex_value && return 1.0im, zeros(2)
    kind == :complex_gradient && return 1.0, zeros(ComplexF64, 2)
    kind == :matrix_gradient && return 1.0, zeros(2, 1)
    kind == :any_gradient && return 1.0, Any[1.0, 2.0]
    kind == :short_gradient && return 1.0, zeros(1)
    kind == :long_gradient && return 1.0, zeros(3)
    kind == :zero_based && return 1.0, ZeroBasedVector(zeros(2))
    kind == :nonfinite && return 1.0, [NaN, Inf]
    error("unknown malformed demo method")
end

function run(fixture::Module)
    @testset "external scalar differentiation core" begin
        theta = [0.7, -0.1]
        original = copy(theta)
        expected_value, expected_gradient = 1.11, [1.3, -2.1]
        for Executor in (fixture.DirectExecutor, fixture.ExpandedExecutor),
            Method in (fixture.CoordinateGradient, fixture.ExpandedGradient)
            executor = Executor()
            objective = fixture.ScalarObjective(executor)
            method = Method()
            @test !(objective isa MOSSQuantum.AbstractQuantumState)
            @test !any(name -> hasproperty(objective, name), (:state, :backend, :storage))
            @test MOSSQuantum.supports_gradient(method, objective)
            @test MOSSQuantum.evaluate(objective, theta) ≈ expected_value
            @test executor.evaluations == 1
            @test MOSSQuantum.differentiable_value(method, objective, theta) ≈ expected_value
            @test executor.evaluations == 2
            @test method.calls == 0
            value, gradient = MOSSQuantum.value_and_gradient(method, objective, theta)
            @test value ≈ expected_value
            @test gradient ≈ expected_gradient
            @test method.calls == 1
            @test executor.evaluations == 3
            value, back = MOSSQuantum.value_and_pullback(method, objective, theta)
            @test value ≈ expected_value
            @test method.calls == 2
            @test executor.evaluations == 4
            method.scratch .= 99
            first = back(1.0)
            @test first ≈ expected_gradient
            @test back(-2.0) ≈ -2 .* expected_gradient
            first .= 0
            @test back(1.0) ≈ expected_gradient
            @test method.calls == 2
            @test executor.evaluations == 4
            @test theta == original
            @test MOSSQuantum.evaluate(objective, theta - 0.1 .* expected_gradient) < value
        end

        objective = fixture.ScalarObjective(fixture.DirectExecutor())
        unsupported = UnsupportedMethod()
        @test !MOSSQuantum.supports_gradient(unsupported, objective)
        @test !MOSSQuantum.supports_gradient(MOSSQuantum.AdjointGradient(), objective)
        @test !MOSSQuantum.supports_gradient(fixture.CoordinateGradient(), :unknown_objective)
        @test MOSSQuantum.differentiable_value(unsupported, objective, theta) ≈ expected_value
        @test_throws MOSSQuantum.UnsupportedGradient MOSSQuantum.value_and_gradient(unsupported, objective, theta)
        @test_throws MOSSQuantum.UnsupportedGradient MOSSQuantum.value_and_pullback(unsupported, objective, theta)
        @test_throws MOSSQuantum.UnsupportedGradient MOSSQuantum.value_and_pullback(MOSSQuantum.AdjointGradient(), objective, theta)
        for invalid in (Float64[], [0.1], [0.1, 0.2, 0.3])
            @test_throws DimensionMismatch MOSSQuantum.evaluate(objective, invalid)
            @test_throws DimensionMismatch MOSSQuantum.value_and_pullback(fixture.CoordinateGradient(), objective, invalid)
        end
        for invalid in ([NaN, 0.1], [Inf, 0.1], [-Inf, 0.1])
            @test_throws ArgumentError MOSSQuantum.evaluate(objective, invalid)
            @test_throws ArgumentError MOSSQuantum.differentiable_value(unsupported, objective, invalid)
            @test_throws ArgumentError MOSSQuantum.value_and_pullback(fixture.CoordinateGradient(), objective, invalid)
        end
        @test_throws ArgumentError MOSSQuantum.value_and_pullback(fixture.CoordinateGradient(), objective,
                                                          ZeroBasedVector(copy(theta)))
        for kind in (:vector_value, :complex_value, :complex_gradient, :matrix_gradient,
                     :any_gradient, :zero_based)
            @test_throws ArgumentError MOSSQuantum.value_and_pullback(MalformedMethod(kind), objective, theta)
        end
        for kind in (:short_gradient, :long_gradient)
            @test_throws DimensionMismatch MOSSQuantum.value_and_pullback(MalformedMethod(kind), objective, theta)
        end
        _, nonfinite_back = MOSSQuantum.value_and_pullback(MalformedMethod(:nonfinite), objective, theta)
        @test isnan(nonfinite_back(1.0)[1])
        @test isinf(nonfinite_back(1.0)[2])
    end
end

end
