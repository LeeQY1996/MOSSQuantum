using Test, Zygote, ChainRulesCore

@testset "Automatic mixed parameters through optional AD" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    template = QCircuit([RyGate(1,.17;isparas=true),RyGate(1,2θ+φ+.1),RyGate(1,θ),RyGate(1,.2)])
    observable = QubitsTerm(1=>"Z")
    state = StateVector(1)
    compiled = compile_parameters(template)
    a = first(parameter_order(compiled))
    point = [.31,.23,-.14]
    function expected(values)
        return -sin(values[1]+3values[2]+values[3]+.3).*[1,3,1]
    end
    objective = ExpectationObjective(compiled,observable,state)
    raw_loss(v) = real(expectation(observable,bind_parameters(template,v)*state))
    context_loss(v) = real(expectation(observable,bind_parameters(compiled,v)*state))
    mapped_loss(v) = real(expectation(observable,bind_parameters(compiled.template,v,compiled.parameter_map)*state))
    for x in (point,Float32.(point),view(vcat(point,9.),1:3))
        before = copy(x)
        for loss in (raw_loss,context_loss,mapped_loss)
            gradient = only(Zygote.gradient(loss,x))
            @test gradient ≈ expected(x) atol=1e-6
            @test eltype(gradient)===eltype(x)
            @test size(gradient)==size(x)
        end
        @test only(Zygote.gradient(v->differentiable_value(AdjointGradient(),objective,v),x)) ≈ expected(x) atol=1e-6
        @test x==before
    end
    _,back = ChainRulesCore.rrule(differentiable_value,AdjointGradient(),objective,point)
    @test back(2.)[4] ≈ 2expected(point)
    @test parameter_order(compiled)==[a,θ,φ]
    @test initial_parameters(compiled;values=Dict(θ=>point[2],φ=>point[3]))==[.17,point[2],point[3]]

    reordered = compile_parameters(compiled;parameter_order=[φ,a,θ])
    reordered_loss(v) = real(expectation(observable,bind_parameters(reordered,v)*state))
    @test only(Zygote.gradient(reordered_loss,point[[3,1,2]])) ≈ expected(point)[[3,1,2]]
    frozen = compile_parameters(compiled;fixed=Dict(a=>point[1],φ=>point[3]))
    frozen_loss(v) = real(expectation(observable,bind_parameters(frozen,v)*state))
    @test only(Zygote.gradient(frozen_loss,[point[2]])) ≈ [expected(point)[2]]
    all_fixed = compile_parameters(frozen;fixed=Dict(θ=>point[2]))
    all_fixed_loss(v) = real(expectation(observable,bind_parameters(all_fixed,v)*state))
    @test isempty(only(Zygote.gradient(all_fixed_loss,Float64[])))
end
