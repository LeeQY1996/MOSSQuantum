using Test, MOSS, ChainRulesCore, Zygote

module DifferentiationRuleFixtures
import MOSS

mutable struct CountingGradient <: MOSS.AbstractGradientMethod
    calls::Int
end
MOSS.supports_gradient(::CountingGradient, ::MOSS.ExpectationObjective) = true
function MOSS.value_and_gradient(method::CountingGradient, objective::MOSS.ExpectationObjective,
                                 values::AbstractVector{<:Real})
    method.calls += 1
    return MOSS.evaluate(objective, values), -sin.(values)
end

mutable struct CountingPullback <: MOSS.AbstractGradientMethod
    forward_calls::Int
    pullback_calls::Int
end
MOSS.supports_gradient(::CountingPullback, ::MOSS.ExpectationObjective) = true
function MOSS.value_and_pullback(method::CountingPullback, objective::MOSS.ExpectationObjective,
                                 values::AbstractVector{<:Real})
    method.forward_calls += 1
    value = MOSS.evaluate(objective, values)
    gradient = -sin.(values)
    function pullback(seed::Real)
        method.pullback_calls += 1
        return seed .* gradient
    end
    return value, pullback
end

struct MissingGradient <: MOSS.AbstractGradientMethod end

struct ScalarObjective
    scale::Float64
end
MOSS.evaluate(objective::ScalarObjective, values::AbstractVector{<:Real}) =
    objective.scale * sum(abs2, values)

mutable struct ScalarGradient <: MOSS.AbstractGradientMethod
    calls::Int
end
MOSS.supports_gradient(::ScalarGradient, ::ScalarObjective) = true
function MOSS.value_and_gradient(method::ScalarGradient, objective::ScalarObjective,
                                 values::AbstractVector{<:Real})
    method.calls += 1
    return MOSS.evaluate(objective, values), 2 .* objective.scale .* values
end

struct InvalidGradient <: MOSS.AbstractGradientMethod
    kind::Symbol
end
MOSS.supports_gradient(::InvalidGradient, ::MOSS.ExpectationObjective) = true
function MOSS.value_and_gradient(method::InvalidGradient, objective::MOSS.ExpectationObjective,
                                 values::AbstractVector{<:Real})
    value = MOSS.evaluate(objective, values)
    method.kind === :length && return value, zeros(length(values) + 1)
    method.kind === :complex && return value, complex.(-sin.(values))
    method.kind === :scalar && return value, 1.0
    method.kind === :value && return complex(value), -sin.(values)
    error("unknown fixture mode")
end

struct InvalidPullback <: MOSS.AbstractGradientMethod
    kind::Symbol
end
MOSS.supports_gradient(::InvalidPullback, ::MOSS.ExpectationObjective) = true
function MOSS.value_and_pullback(method::InvalidPullback, objective::MOSS.ExpectationObjective,
                                 values::AbstractVector{<:Real})
    value = MOSS.evaluate(objective, values)
    method.kind === :value && return complex(value), (seed::Real) -> -seed .* sin.(values)
    function pullback(seed::Real)
        method.kind === :length && return zeros(length(values) + 1)
        method.kind === :complex && return complex.(-seed .* sin.(values))
        method.kind === :scalar && return 1.0
        error("unknown fixture mode")
    end
    return value, pullback
end
end

@testset "Scalar objective ChainRules interface" begin
    @test Base.get_extension(MOSS, :MOSSChainRulesCoreExt) !== nothing

    @testset "Mapped circuit values and scalar cotangents" begin
        template = QCircuit([RyGate(1, 0.1; isparas=true),
            QCircuit([RzGate(1, 0.2; isparas=true)]), RyGate(1, 0.3; isparas=true)])
        initial = StateVector(1)
        objective = ExpectationObjective(template, QubitsTerm(1 => "Z"), initial;
            parameter_map=ParameterMap([1, 2, 1]))
        values = [0.31, -0.42]
        theta, phi = values
        expected_value = cos(theta)^2 - sin(theta)^2 * cos(phi)
        expected_gradient = [-sin(2theta) * (1 + cos(phi)), sin(theta)^2 * sin(phi)]

        value, pullback = ChainRulesCore.rrule(differentiable_value,
            AdjointGradient(), objective, values)
        @test value ≈ expected_value
        result = pullback(1.0)
        @test length(result) == 4
        @test all(tangent -> tangent isa NoTangent, result[1:3])
        @test result[4] ≈ expected_gradient atol=1e-10
        @test pullback(2.5)[4] ≈ 2.5 .* expected_gradient
        @test pullback(0.0)[4] ≈ zeros(2)
        @test pullback(2 + 7im)[4] ≈ 2 .* expected_gradient
        @test pullback(@thunk(2.5))[4] ≈ 2.5 .* expected_gradient
        @test pullback(@thunk(2 + 7im))[4] ≈ 2 .* expected_gradient
        @test pullback(InplaceableThunk(_ -> nothing, @thunk(2.5)))[4] ≈
            2.5 .* expected_gradient

        first_gradient = pullback(1.0)[4]
        first_gradient .= 9
        @test pullback(1.0)[4] ≈ expected_gradient
        @test pullback(-1.0)[4] ≈ -expected_gradient
        @test active_parameters(template) == [0.1, 0.2, 0.3]
        @test values == [0.31, -0.42]
        @test initial == StateVector(1)
    end

    @testset "Projection respects parameter domains and shape" begin
        template = QCircuit([RyGate(1, 0.0; isparas=true)])
        objective = ExpectationObjective(template, QubitsTerm(1 => "Z"), StateVector(1))
        for values in (Float32[0.2], Float64[0.2], BigFloat[0.2],
                       view(Float32[0.2, 99], 1:2:1), view([0.2, 99], 1:2:1))
            original = copy(values)
            value, pullback = ChainRulesCore.rrule(differentiable_value,
                AdjointGradient(), objective, values)
            gradient = pullback(1.0)[4]
            @test value ≈ cos(values[1])
            @test gradient ≈ [-sin(values[1])] atol=1e-7
            # ProjectTo preserves hardware float precision. BigFloat uses the
            # broader Real tangent domain; the numerical method chooses precision.
            if eltype(values) === BigFloat
                @test gradient isa AbstractVector{<:Real}
            else
                @test eltype(gradient) === eltype(values)
            end
            @test axes(gradient) == axes(values)
            @test pullback(2 + 7im)[4] ≈ 2 .* gradient
            @test values == original
        end

        frozen = ExpectationObjective(QCircuit([RyGate(1, 0.23)]),
            QubitsTerm(1 => "Z"), StateVector(1))
        for values in (Float32[], Float64[], BigFloat[])
            value, pullback = ChainRulesCore.rrule(differentiable_value,
                AdjointGradient(), frozen, values)
            gradient = pullback(1.0)[4]
            @test value ≈ cos(0.23)
            @test isempty(gradient)
            if eltype(values) === BigFloat
                @test gradient isa AbstractVector{<:Real}
            else
                @test eltype(gradient) === eltype(values)
            end
        end
    end

    @testset "Zero cotangents do not invoke the core pullback" begin
        objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]),
            QubitsTerm(1 => "Z"), StateVector(1))
        method = DifferentiationRuleFixtures.CountingPullback(0, 0)
        value, pullback = ChainRulesCore.rrule(differentiable_value, method, objective, [0.2])
        @test value ≈ cos(0.2)
        @test method.forward_calls == 1
        @test method.pullback_calls == 0
        for seed in (ZeroTangent(), NoTangent(), @thunk(ZeroTangent()),
                     InplaceableThunk(_ -> nothing, @thunk(ZeroTangent())))
            result = pullback(seed)
            @test all(tangent -> tangent isa NoTangent, result[1:3])
            @test result[4] isa ZeroTangent
            @test method.pullback_calls == 0
        end
        @test pullback(@thunk(2.0))[4] ≈ [-2sin(0.2)]
        @test method.pullback_calls == 1
        @test method.forward_calls == 1
    end

    @testset "Forward execution and selected gradient methods" begin
        objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]),
            QubitsTerm(1 => "Z"), StateVector(1))
        values = [0.37]
        method = DifferentiationRuleFixtures.CountingGradient(0)
        @test differentiable_value(method, objective, values) ≈ cos(values[1])
        @test method.calls == 0
        missing = DifferentiationRuleFixtures.MissingGradient()
        @test !supports_gradient(missing, objective)
        @test differentiable_value(missing, objective, values) ≈ cos(values[1])

        value, pullback = ChainRulesCore.rrule(differentiable_value, method, objective, values)
        @test value ≈ cos(values[1])
        @test method.calls == 1
        @test pullback(1.0)[4] ≈ [-sin(values[1])]
        @test pullback(2.0)[4] ≈ [-2sin(values[1])]
        @test method.calls == 1

        loss(parameters) = (differentiable_value(method, objective, parameters) + 0.2)^2
        @test Zygote.gradient(loss, values)[1] ≈
            [-2(cos(values[1]) + 0.2) * sin(values[1])]
        @test method.calls == 2
        method_tangent, objective_tangent, parameter_tangent = Zygote.gradient(
            (selected, fixed, parameters) -> differentiable_value(selected, fixed, parameters),
            method, objective, values)
        @test method_tangent === nothing
        @test objective_tangent === nothing
        @test parameter_tangent ≈ [-sin(values[1])]
        @test method.calls == 3
        @test values == [0.37]
    end

    @testset "External objectives need no MOSS base type" begin
        objective = DifferentiationRuleFixtures.ScalarObjective(3.0)
        method = DifferentiationRuleFixtures.ScalarGradient(0)
        values = Float32[1, 2]
        @test differentiable_value(method, objective, values) == 15
        @test method.calls == 0
        value, pullback = ChainRulesCore.rrule(differentiable_value, method, objective, values)
        @test value == 15
        @test method.calls == 1
        @test pullback(1.0)[4] == Float32[6, 12]
        @test pullback(2 + 7im)[4] == Float32[12, 24]
        @test method.calls == 1
        @test Zygote.gradient(x -> differentiable_value(method, objective, x)^2, values)[1] ==
            Float32[180, 360]
        @test method.calls == 2
        @test values == Float32[1, 2]
    end

    @testset "Pullbacks retain the forward parameter domain" begin
        cpu_objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]),
            QubitsTerm(1 => "Z"), StateVector(1))
        external_objective = DifferentiationRuleFixtures.ScalarObjective(3.0)
        external_method = DifferentiationRuleFixtures.ScalarGradient(0)
        cases = ((AdjointGradient(), cpu_objective, [0.2], [-sin(0.2)]),
                 (external_method, external_objective, Float32[1, 2], Float32[6, 12]))
        for (method, objective, values, expected) in cases
            forward_length = length(values)
            _, pullback = ChainRulesCore.rrule(differentiable_value, method, objective, values)
            values .= -42
            @test pullback(1.0)[4] ≈ expected
            resize!(values, forward_length + 2)
            values .= 9
            first = pullback(1.0)[4]
            @test length(first) == forward_length
            @test first ≈ expected
            @test eltype(first) === eltype(expected)
            @test pullback(2.0)[4] ≈ 2 .* expected
            first .= 99
            @test pullback(1.0)[4] ≈ expected
            @test pullback(-2.0)[4] ≈ -2 .* expected
            @test length(pullback(1.0)[4]) == forward_length
        end
        @test external_method.calls == 1
    end

    @testset "Validation reaches the core protocol" begin
        objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]),
            QubitsTerm(1 => "Z"), StateVector(1))
        method = AdjointGradient()
        @test_throws DimensionMismatch ChainRulesCore.rrule(differentiable_value,
            method, objective, Float64[])
        @test_throws DimensionMismatch ChainRulesCore.rrule(differentiable_value,
            method, objective, [0.1, 0.2])
        for values in ([NaN], [Inf], [-Inf])
            @test_throws ArgumentError ChainRulesCore.rrule(differentiable_value,
                method, objective, values)
        end
        @test_throws UnsupportedGradient ChainRulesCore.rrule(differentiable_value,
            DifferentiationRuleFixtures.MissingGradient(), objective, [0.2])
        @test_throws DimensionMismatch ChainRulesCore.rrule(differentiable_value,
            DifferentiationRuleFixtures.InvalidGradient(:length), objective, [0.2])
        for mode in (:complex, :scalar, :value)
            @test_throws ArgumentError ChainRulesCore.rrule(differentiable_value,
                DifferentiationRuleFixtures.InvalidGradient(mode), objective, [0.2])
        end

        # Specialized external VJPs bypass the generic preparation helper.
        # The AD boundary still validates their values and returned gradients.
        counted = DifferentiationRuleFixtures.CountingPullback(0, 0)
        @test_throws ArgumentError ChainRulesCore.rrule(differentiable_value,
            counted, objective, [NaN])
        @test counted.forward_calls == 0
        @test_throws ArgumentError ChainRulesCore.rrule(differentiable_value,
            DifferentiationRuleFixtures.InvalidPullback(:value), objective, [0.2])
        _, wrong_length = ChainRulesCore.rrule(differentiable_value,
            DifferentiationRuleFixtures.InvalidPullback(:length), objective, [0.2])
        @test_throws DimensionMismatch wrong_length(1.0)
        for mode in (:complex, :scalar)
            _, invalid_gradient = ChainRulesCore.rrule(differentiable_value,
                DifferentiationRuleFixtures.InvalidPullback(mode), objective, [0.2])
            @test_throws ArgumentError invalid_gradient(1.0)
        end
    end
end
