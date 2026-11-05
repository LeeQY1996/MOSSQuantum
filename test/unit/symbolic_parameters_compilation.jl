using Test, Random, LinearAlgebra

struct NamedDomainGate <: Gate{1}
    pos::Tuple{Int}
    angle::Float64
    active::Bool
end
MOSSQuantum.QuantumCircuits.parameters(g::NamedDomainGate) = [g.angle]
MOSSQuantum.QuantumCircuits.active_parameters(g::NamedDomainGate) = g.active ? [g.angle] : Float64[]
MOSSQuantum.QuantumCircuits.reset_parameters!(g::NamedDomainGate, values::AbstractVector{<:Real}) =
    length(values) == Int(g.active) ? NamedDomainGate(g.pos, g.active ? only(values) : g.angle, g.active) : throw(DimensionMismatch("wrong domain gate slots"))
MOSSQuantum.QuantumCircuits.deactivate_parameter!(g::NamedDomainGate, ::Int) = NamedDomainGate(g.pos, g.angle, false)
function MOSSQuantum.QuantumCircuits.mat(g::NamedDomainGate)
    g.angle > 0 || throw(ArgumentError("angle must be positive; placeholder matrices must not be evaluated"))
    return mat(RyGate(only(g.pos), g.angle))
end
MOSSQuantum.QuantumCircuits.differentiate(g::NamedDomainGate) =
    g.active ? [QuantumGate(g.pos, (im/2) * mat(YGate(only(g.pos))))] : nothing

@testset "Named parameter compilation and ownership" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    circuit = QCircuit([RyGate(1, θ), RzGate(2, -θ/2 + φ + π/4), RxGate(1, θ)])
    compiled = compile_parameters(circuit)
    map = compiled.parameter_map
    @test map isa AbstractParameterMap
    @test length(map) == 3
    @test nparameters(map) == 2
    @test parameter_order(map) == [θ, φ]
    @test expand_parameters(map, [.4,.1]) ≈ [.4, π/4-.1, .4]
    @test accumulate_parameter_gradients(map, [2.,3.,5.]) == [5.5,3.]
    @test active_parameters(bind_parameters(circuit, Dict(θ=>.4,φ=>.1))) ≈ [.4,π/4-.1,.4]
    @test active_parameters(bind_parameters(circuit, [.1,.4];parameter_order=[φ,θ])) ≈ [.4,π/4-.1,.4]
    @test active_parameters(bind_parameters(circuit, Dict(:θ=>.4,:φ=>.1))) ≈ [.4,π/4-.1,.4]
    @test_throws ArgumentError bind_parameters(circuit, Dict(θ=>.4))
    @test_throws ArgumentError bind_parameters(circuit, Dict(θ=>.4,φ=>.1,:other=>.3))
    @test_throws ArgumentError bind_parameters(circuit, [true,false])
    @test_throws DimensionMismatch bind_parameters(circuit, [.4])
    @test_throws ArgumentError compile_parameters(circuit;parameter_order=[θ,θ])
    @test_throws ArgumentError compile_parameters(circuit;fixed=Dict(Parameter(:other)=>.2))
    @test_throws ArgumentError compile_parameters(circuit;parameter_map=ParameterMap([1,2,1]))
    @test_throws ArgumentError ParameterMap(circuit)
    @test nparameters(compile_parameters(QCircuit([RyGate(1,θ), RxGate(1,.2;isparas=true)])).parameter_map) == 2
    @test_throws ArgumentError compile_parameters(QCircuit([RyGate(1,.2;isparas=true)]);fixed=Dict())
    swapped = QCircuit([circuit[3],circuit[2],circuit[1]])
    @test_throws ArgumentError bind_parameters(swapped,[.4,.1],map)
    allfixed = substitute_parameters(circuit, Dict(θ=>.4,φ=>.1))
    @test isempty(independent_parameters(allfixed))
    @test nparameters(bind_parameters(allfixed, Dict())) == 0
    empty = compile_parameters(QCircuit())
    @test expand_parameters(empty.parameter_map,Float64[]) == Float64[]
    @test isempty(bind_parameters(empty.template,Float64[],empty.parameter_map))
    @test expand_parameters(ParameterMap([1,2,1]),[.2,.3]) == [.2,.3,.2]
    integer_template = QCircuit([RyGate(1,2θ)])
    @test_throws ArgumentError bind_parameters(integer_template,Dict(θ=>typemax(Int)))
    @test_throws ArgumentError substitute_parameters(integer_template,Dict(θ=>typemax(Int)))
    large = compile_parameters(QCircuit([RyGate(1,typemax(Int)*θ)]))
    @test_throws ArgumentError accumulate_parameter_gradients(large.parameter_map,[2])
    @test accumulate_parameter_gradients(large.parameter_map,[big(2)]) == [2big(typemax(Int))]
    repeated = compile_parameters(QCircuit([RyGate(1,θ),RyGate(1,θ)]))
    @test_throws ArgumentError accumulate_parameter_gradients(repeated.parameter_map,[typemax(Int),1])
    extreme = ParameterExpr((θ=>typemin(Int),),typemin(Int))
    magnitude = -big(typemin(Int))
    @test sprint(show,extreme) == "-$(magnitude)*θ - $(magnitude)"
end

@testset "Unbound parameter writers are atomic" begin
    θ = Parameter(:θ)
    inactive = RyGate(1,.2)
    circuit = QCircuit([inactive,RzGate(1,θ)])
    @test_throws ArgumentError activate_parameters!(circuit)
    @test nparameters(inactive) == 0
    @test_throws ArgumentError activate_parameter!(circuit,1)
    @test nparameters(inactive) == 0
    active = RyGate(1,.3;isparas=true)
    circuit = QCircuit([active,RzGate(1,θ)])
    @test_throws ArgumentError deactivate_parameters!(circuit)
    @test nparameters(active) == 1
    @test_throws ArgumentError deactivate_parameter!(circuit,1)
    @test nparameters(active) == 1
    @test_throws ArgumentError reset_parameters!(circuit,[.8,.9])
    @test active_parameters(active) == [.3]
    conditional = Conditional(:flag,RyGate(1,.2);otherwise=RzGate(1,θ))
    @test_throws ArgumentError activate_parameters!(conditional)
    @test nparameters(conditional.then_branch) == 0
end

@testset "Named deterministic objectives and freezing" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    observable = QubitsTerm(1=>"Z")
    state = StateVector(1)
    for initial in (state,DensityMatrix(state))
        circuit = QCircuit([RyGate(1, θ), RyGate(1, θ)])
        obj = ExpectationObjective(circuit,observable,initial)
        x = [.31]
        value, gradient = value_and_gradient(AdjointGradient(),obj,x)
        @test value ≈ cos(2x[1])
        @test gradient ≈ [-2sin(2x[1])]
        @test supports_gradient(AdjointGradient(),obj)
        @test supports_gradient(AdjointGradient(),obj,x)
        @test parameter_order(obj) == [θ]
        @test independent_parameters(obj) == [θ]
        @test trainable_parameters(obj) == [θ]
        value2, back = value_and_pullback(AdjointGradient(),obj,x)
        x[1] = 2.
        @test value2 ≈ value
        @test back(2.) ≈ 2gradient
        @test back(0.) == [0.]
        affine = ExpectationObjective(QCircuit([RyGate(1,2θ+φ+.2)]),observable,initial)
        v,g = value_and_gradient(AdjointGradient(),affine,[.3,.1])
        @test v ≈ cos(.9)
        @test g ≈ -sin(.9)*[2.,1.]
        fixed_values = Dict(θ=>.3)
        frozen = ExpectationObjective(QCircuit([RyGate(1,2θ+φ+.2)]),observable,initial;fixed=fixed_values)
        fixed_values[θ] = 10.
        @test parameter_order(frozen) == [φ]
        @test independent_parameters(frozen) == [θ,φ]
        @test value_and_gradient(AdjointGradient(),frozen,[.1])[2] ≈ [-sin(.9)]
        constant = ExpectationObjective(QCircuit([RyGate(1,θ-θ+.2)]),observable,initial)
        @test value_and_gradient(AdjointGradient(),constant,Float64[])[1] ≈ cos(.2)
        @test isempty(value_and_gradient(AdjointGradient(),constant,Float64[])[2])
    end
    circuit = QCircuit([RyGate(1, θ), AmplitudeDamping(1;γ=.23)])
    noisy = ExpectationObjective(circuit, observable, DensityMatrix(state))
    @test value_and_gradient(AdjointGradient(),noisy,[.3])[2] ≈ [-(1-.23)*sin(.3)]
    numeric = RxGate(1,.7)
    snapshot = ExpectationObjective(QCircuit([numeric,RyGate(1,θ)]),observable,state)
    original = evaluate(snapshot,[.3])
    numeric.paras[1] = 2.
    @test evaluate(snapshot,[.3]) == original
end

@testset "Named batch objectives" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    circuit = QCircuit([RyGate(1,2θ+φ)])
    initial = BatchStateVector(hcat(ComplexF64[1,0],ComplexF64[1,0]),1)
    for batch in (initial,BatchDensityMatrix(initial))
        obj = BatchExpectationObjective(circuit,QubitsTerm(1=>"Z"),batch;fixed=Dict(φ=>.1))
        value, gradient = value_and_gradient(AdjointGradient(),obj,[.3])
        @test value ≈ cos(.7)
        @test gradient ≈ [-2sin(.7)]
        @test evaluate_batch(obj,[.3]) ≈ fill(cos(.7),2)
        @test trainable_parameters(obj) == [θ]
    end
end

@testset "Value-dependent external named gates" begin
    θ = Parameter(:θ)
    gate = NamedDomainGate((1,),0.,true)
    template = QCircuit([parameterize(gate,[θ])])
    obj = ExpectationObjective(template,QubitsTerm(1=>"Z"),StateVector(1))
    @test !supports_gradient(AdjointGradient(),obj)
    @test supports_gradient(AdjointGradient(),obj,[.6])
    @test !supports_gradient(AdjointGradient(),obj,[-.6])
    value, gradient = value_and_gradient(AdjointGradient(),obj,[.6])
    @test value ≈ cos(.6)
    @test gradient ≈ [-sin(.6)]
    @test_throws ArgumentError evaluate(obj,[-.6])
    fixed = ExpectationObjective(template,QubitsTerm(1=>"Z"),StateVector(1);fixed=Dict(θ=>.6))
    @test value_and_gradient(AdjointGradient(),fixed,Float64[])[1] ≈ cos(.6)
    @test isempty(value_and_gradient(AdjointGradient(),fixed,Float64[])[2])
end
