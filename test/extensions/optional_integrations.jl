# Included after the regular gradient and plotting suites have loaded their
# optional packages. Fresh-process loading checks live in load_order.jl.
@testset "optional integrations" begin
    if isdefined(Base, :get_extension)
        @test Base.get_extension(MOSS, :MOSSZygoteExt) !== nothing
        @test Base.get_extension(MOSS, :MOSSPlotsExt) !== nothing
        @test !isdefined(MOSS, :Requires)
    else
        @test isdefined(MOSS, :MOSSZygoteExt)
        @test isdefined(MOSS, :MOSSPlotsExt)
    end
    @test !isdefined(MOSS, :Zygote) || !isdefined(Base, :get_extension)

    template = QCircuit()
    shared_gate = RyGate(1, 0.1; isparas=true)
    push!(template, shared_gate)
    push!(template, shared_gate)
    angles = Float32[0.2, 0.3]
    observable = QubitsTerm(1 => "Z")
    initial = qstate(1)
    loss(values) = real(expectation(observable, bind_parameters(template, values) * initial))
    gradient = Zygote.gradient(loss, angles)[1]
    @test gradient ≈ fill(-sin(sum(angles)), 2)
    @test eltype(gradient) == Float32
    @test active_parameters(template) == [0.1, 0.1]
    template_gradient, value_gradient = Zygote.gradient(template, angles) do circuit, values
        real(expectation(observable, bind_parameters(circuit, values) * initial))
    end
    @test template_gradient === nothing
    @test value_gradient ≈ gradient
end
