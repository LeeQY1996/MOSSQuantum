module DemoDifferentiationContractChecks

using Test
import MOSS
import ChainRulesCore

include("core_checks.jl")
run_core(fixture::Module) = DemoDifferentiationCoreChecks.run(fixture)

function run_chainrules(fixture::Module)
    @testset "external scalar ChainRules adapter" begin
        @test Base.get_extension(MOSS, :MOSSChainRulesCoreExt) !== nothing
        expected = [1.3, -2.1]
        for Executor in (fixture.DirectExecutor, fixture.ExpandedExecutor),
            Method in (fixture.CoordinateGradient, fixture.ExpandedGradient)
            objective = fixture.ScalarObjective(Executor())
            method = Method()
            theta = [0.7, -0.1]
            value, back = ChainRulesCore.rrule(MOSS.differentiable_value, method, objective, theta)
            @test value ≈ 1.11
            @test method.calls == 1
            @test objective.executor.evaluations == 1
            method.scratch .= 100
            theta .= -100
            first = back(2.5)
            @test length(first) == 4
            @test all(tangent -> tangent isa ChainRulesCore.NoTangent, first[1:3])
            @test first[4] ≈ 2.5 .* expected
            @test back(ChainRulesCore.Thunk(() -> -2.0))[4] ≈ -2 .* expected
            @test back(0.0)[4] == zeros(2)
            @test back(ChainRulesCore.ZeroTangent())[4] isa ChainRulesCore.AbstractZero
            @test back(ChainRulesCore.NoTangent())[4] isa ChainRulesCore.AbstractZero
            first[4] .= 0
            @test back(1.0)[4] ≈ expected
            @test method.calls == 1
            @test objective.executor.evaluations == 1
        end

        objective = fixture.ScalarObjective(fixture.DirectExecutor())
        value, back = ChainRulesCore.rrule(MOSS.differentiable_value,
            fixture.CoordinateGradient(), objective, Float32[0.7, -0.1])
        @test value ≈ 1.11
        @test back(1.0)[4] isa Vector{Float32}
        @test back(1.0)[4] ≈ Float32.(expected)
        backing = [10.0, 0.7, -0.1, 20.0]
        _, view_back = ChainRulesCore.rrule(MOSS.differentiable_value,
            fixture.ExpandedGradient(), objective, view(backing, 2:3))
        @test view_back(1.0)[4] ≈ expected
        @test backing == [10.0, 0.7, -0.1, 20.0]

        unsupported = DemoDifferentiationCoreChecks.UnsupportedMethod()
        @test_throws MOSS.UnsupportedGradient ChainRulesCore.rrule(MOSS.differentiable_value,
            unsupported, objective, [0.7, -0.1])
        for kind in (:vector_value, :complex_value, :complex_gradient, :matrix_gradient,
                     :any_gradient, :zero_based)
            method = DemoDifferentiationCoreChecks.MalformedMethod(kind)
            @test_throws ArgumentError ChainRulesCore.rrule(MOSS.differentiable_value,
                method, objective, [0.7, -0.1])
        end
        @test_throws DimensionMismatch ChainRulesCore.rrule(MOSS.differentiable_value,
            DemoDifferentiationCoreChecks.MalformedMethod(:short_gradient), objective, [0.7, -0.1])
    end
end

function run_zygote(fixture::Module, ad::Module)
    @testset "external method selected by Zygote" begin
        @test Base.get_extension(MOSS, :MOSSChainRulesCoreExt) !== nothing
        theta = [0.7, -0.1]
        for Executor in (fixture.DirectExecutor, fixture.ExpandedExecutor)
            objective = fixture.ScalarObjective(Executor())
            first_method = fixture.CoordinateGradient()
            second_method = fixture.ExpandedGradient()
            first_loss(values) = MOSS.differentiable_value(first_method, objective, values)
            second_loss(values) = MOSS.differentiable_value(second_method, objective, values)
            @test first_loss(theta) ≈ 1.11
            @test first_method.calls == 0
            @test second_method.calls == 0
            first_gradient = only(ad.gradient(first_loss, theta))
            @test first_gradient ≈ [1.3, -2.1]
            @test first_method.calls == 1
            @test second_method.calls == 0
            @test objective.executor.evaluations == 2
            second_gradient = only(ad.gradient(second_loss, theta))
            @test second_gradient ≈ first_gradient
            @test first_method.calls == 1
            @test second_method.calls == 1
            @test objective.executor.evaluations == 3
            @test only(ad.gradient(values -> 2.5 * second_loss(values), theta)) ≈ 2.5 .* first_gradient
            @test second_method.calls == 2
            @test theta == [0.7, -0.1]
            @test second_loss(theta - 0.1 .* second_gradient) < second_loss(theta)
        end

        objective = fixture.ScalarObjective(fixture.DirectExecutor())
        method = fixture.CoordinateGradient()
        _, back = ad.pullback(values -> MOSS.differentiable_value(method, objective, values), theta)
        @test method.calls == 1
        @test objective.executor.evaluations == 1
        first = only(back(1.0))
        @test first ≈ [1.3, -2.1]
        first .= 0
        method.scratch .= 0
        @test only(back(-2.0)) ≈ [-2.6, 4.2]
        @test method.calls == 1
        @test objective.executor.evaluations == 1
        float_gradient = only(ad.gradient(Float32[0.7, -0.1]) do values
            MOSS.differentiable_value(fixture.ExpandedGradient(), objective, values)
        end)
        @test float_gradient isa Vector{Float32}
        @test float_gradient ≈ Float32[1.3, -2.1]
        unsupported = DemoDifferentiationCoreChecks.UnsupportedMethod()
        @test_throws MOSS.UnsupportedGradient ad.gradient(theta) do values
            MOSS.differentiable_value(unsupported, objective, values)
        end
    end
end

function run(fixture::Module, ad::Module)
    run_core(fixture)
    run_chainrules(fixture)
    run_zygote(fixture, ad)
end

end
