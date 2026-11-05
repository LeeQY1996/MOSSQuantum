using Test, Zygote, ChainRulesCore

@testset "Named parameters through optional AD" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    template = QCircuit([RyGate(1,θ), RyGate(1,θ+φ)])
    observable = QubitsTerm(1=>"Z")
    state = StateVector(1)
    x = [.3,.2]
    expected = -sin(.8)*[2.,1.]
    obj = ExpectationObjective(template,observable,state)
    @test Zygote.gradient(v -> differentiable_value(AdjointGradient(),obj,v),x)[1] ≈ expected
    @test Zygote.gradient(v -> real(expectation(observable,bind_parameters(template,v)*state)),x)[1] ≈ expected
    compiled = compile_parameters(template)
    @test Zygote.gradient(v -> real(expectation(observable,
        bind_parameters(compiled.template,v,compiled.parameter_map)*state)),x)[1] ≈ expected
    value, pullback = ChainRulesCore.rrule(differentiable_value,AdjointGradient(),obj,x)
    @test value ≈ cos(.8)
    @test pullback(2.)[4] ≈ 2expected
end
