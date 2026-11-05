using Test, Random, LinearAlgebra

struct MixedPartialGate <: Gate{1}
    pos::Tuple{Int}
    values::Vector{Float64}
    activity::Vector{Bool}
end
MOSSQuantum.QuantumCircuits.parameters(g::MixedPartialGate) = g.values
MOSSQuantum.QuantumCircuits.active_parameters(g::MixedPartialGate) = g.values[g.activity]
MOSSQuantum.QuantumCircuits.is_parameters(g::MixedPartialGate) = g.activity
MOSSQuantum.QuantumCircuits.reset_parameters!(g::MixedPartialGate,x::AbstractVector{<:Real}) = begin
    values=copy(g.values); values[g.activity]=x
    MixedPartialGate(g.pos,values,copy(g.activity))
end
struct MixedActiveInstruction <: AbstractInstruction
    pos::Tuple{Int}
    values::Vector{Float64}
end
MOSSQuantum.QuantumCircuits.positions(g::MixedActiveInstruction) = g.pos
MOSSQuantum.QuantumCircuits.parameters(g::MixedActiveInstruction) = g.values
MOSSQuantum.QuantumCircuits.active_parameters(g::MixedActiveInstruction) = g.values
MOSSQuantum.QuantumCircuits.reset_parameters!(g::MixedActiveInstruction,x::AbstractVector{<:Real}) = MixedActiveInstruction(g.pos,collect(x))
struct MixedMalformedSlots <: AbstractInstruction
    pos::Tuple{Int}
    values::Vector{Float64}
    slots
end
MOSSQuantum.QuantumCircuits.parameters(g::MixedMalformedSlots) = g.values
MOSSQuantum.QuantumCircuits.active_parameters(g::MixedMalformedSlots) = g.values
MOSSQuantum.QuantumCircuits.parameter_slots(g::MixedMalformedSlots) = g.slots

@testset "Automatic mixed parameter compilation" begin
    θ,φ=Parameter(:θ),Parameter(:φ)
    gate=RxGate(1,.2;isparas=true)
    c=QCircuit([gate,RyGate(1,2θ+φ+.1),RxGate(1,.7),gate,RzGate(1,θ)])
    ctx=compile_parameters(c)
    a,_,_,b=parameter_order(ctx)
    @test parameter_order(ctx)==[a,θ,φ,b]
    @test a!=b && a.name!=θ.name
    @test nparameters(ctx.parameter_map)==4
    @test length(ctx.parameter_map)==nparameters(ctx.template)==4
    @test expand_parameters(ctx.parameter_map,[.3,.4,.5,.6])≈[.3,1.4,.6,.4]
    @test accumulate_parameter_gradients(ctx.parameter_map,[1.,2.,3.,4.])==[1.,8.,2.,3.]
    x=[.3,.4,.5,.6]
    bound=bind_parameters(ctx,x)
    @test active_parameters(bound)≈[.3,1.4,.6,.4]
    @test parameters(bound[3])==[.7]
    @test active_parameters(c[1])==[.2]
    @test active_parameters(c[4])==[.2]
    @test bound[1]!==bound[4]
    @test active_parameters(bind_parameters(c,x))≈active_parameters(bound)
    @test active_parameters(bind_parameters(ctx,Dict(a=>.3,θ=>.4,φ=>.5,b=>.6)))≈active_parameters(bound)
    @test_throws ArgumentError bind_parameters(ctx,Dict(θ=>.4,φ=>.5))
    @test_throws ArgumentError bind_parameters(ctx,Dict(:θ=>.4,:φ=>.5))
    @test_throws ArgumentError compile_parameters(c;parameter_map=ParameterMap([1,2,3,4]))
    @test_throws ArgumentError compile_parameters(c;parameter_order=[a,θ,φ,b])
    @test_throws ArgumentError compile_parameters(ctx;parameter_order=[a,θ,φ,Parameter(:other)])
    @test_throws ArgumentError compile_parameters(ctx;parameter_order=[a,θ,φ,a])
    for clone in (copy(ctx),deepcopy(ctx),compile_parameters(ctx))
        @test parameter_order(clone)==parameter_order(ctx)
        @test active_parameters(bind_parameters(clone,x))≈active_parameters(bound)
        @test clone.template!==ctx.template
    end
    fresh=compile_parameters(c)
    @test parameter_order(fresh)[1]!=a
    @test parameter_order(fresh)[2]==θ
    @test_throws ArgumentError bind_parameters(fresh,Dict(a=>.3,θ=>.4,φ=>.5,b=>.6))
    reset_parameters!(gate,[.9])
    @test initial_parameters(ctx;values=Dict(θ=>.4,φ=>.5))==[.2,.4,.5,.2]
    @test initial_parameters(compile_parameters(c);values=Dict(θ=>.4,φ=>.5))==[.9,.4,.5,.9]
end

@testset "Mixed physical slots and fixed variables" begin
    θ=Parameter(:θ)
    g=FSIMGate((1,2),[.1,.2,.3,.4,.5];isparas=[true,false,true,false,true])
    ctx=compile_parameters(QCircuit([g,RyGate(1,θ)]))
    a,b,c,_=parameter_order(ctx)
    @test [only(info.sources).slot for info in parameter_info(ctx)[1:3]]==[1,3,5]
    fixed=compile_parameters(ctx;fixed=Dict(b=>.8,θ=>.7))
    @test parameter_order(fixed)==[a,c]
    @test independent_parameters(fixed)==[a,b,c,θ]
    bound=bind_parameters(fixed,[.6,.9])
    @test parameters(bound[1])≈[.6,.2,.8,.4,.9]
    @test MOSSQuantum.QuantumCircuits.is_parameters(bound[1])==[true,false,false,false,true]
    @test active_parameters(bound)≈[.6,.9]
    @test nparameters(bound[2])==0
    @test parameters(bound[2])==[.7]
    @test length(fixed.parameter_map)==nparameters(fixed.template)==2
    repeated=compile_parameters(fixed;fixed=Dict(b=>.8))
    @test parameter_order(repeated)==[a,c]
    @test_throws ArgumentError compile_parameters(fixed;fixed=Dict(b=>.1))
    @test_throws ArgumentError compile_parameters(fixed;fixed=Dict(Parameter(:b)=>.8))
    allfixed=compile_parameters(fixed;fixed=Dict(a=>.6,c=>.9))
    @test nparameters(allfixed.parameter_map)==nparameters(allfixed.template)==0
    @test parameters(bind_parameters(allfixed,Float64[])[1])≈parameters(bound[1])
    reordered=compile_parameters(fixed;parameter_order=[c,θ,b,a])
    @test parameter_order(reordered)==[c,a]
    @test active_parameters(bind_parameters(reordered,[.9,.6]))≈[.6,.9]
    changed=copy_instruction(ctx.template)
    deactivate_parameter!(changed[1],1)
    activate_parameter!(changed[1],2)
    @test nparameters(changed)==nparameters(ctx.template)
    @test_throws ArgumentError bind_parameters(changed,[.6,.8,.9,.7],ctx.parameter_map)

    cancel=compile_parameters(QCircuit([RyGate(1,θ-θ+.3),RxGate(1,.2;isparas=true)]))
    @test nparameters(cancel.parameter_map)==1
    @test initial_parameters(cancel)==[.2]
    @test parameters(bind_parameters(cancel,[.4])[1])==[.3]
    placeholder=compile_parameters(QCircuit([RyGate(1,θ),RxGate(1,NaN;isparas=true)]))
    anon=last(parameter_order(placeholder))
    frozen=compile_parameters(placeholder;fixed=Dict(anon=>.4))
    @test parameters(bind_parameters(frozen,[.2])[2])==[.4]
end

@testset "Mixed nested and external instruction layouts" begin
    θ=Parameter(:θ)
    ctx=compile_parameters(QCircuit([QCircuit([RxGate(1,.1;isparas=true),RyGate(1,θ)]),
        Conditional(:flag,RzGate(1,.2;isparas=true);otherwise=RxGate(1,.3;isparas=true))]))
    @test [entry.kind for entry in parameter_info(ctx)]==[:anonymous,:named,:anonymous,:anonymous]
    @test [only(entry.sources).path for entry in parameter_info(ctx)]==[(1,1),(1,2),(2,:then,1),(2,:else,1)]
    @test nparameters(bind_parameters(ctx,[.4,.5,.6,.7]))==4
    g=MixedPartialGate((1,),[.1,.2,.3],[false,true,false])
    ext=compile_parameters(QCircuit([g,RyGate(1,θ)]))
    @test only(parameter_info(ext)[1].sources).slot==2
    @test parameters(bind_parameters(ext,[.8,.7])[1])==[.1,.8,.3]
    for slots in ([1,2],(1,1),(true,2),(1,"other"))
        bad=MixedMalformedSlots((1,),[.1,.2],slots)
        @test_throws ArgumentError compile_parameters(QCircuit([bad,RyGate(1,θ)]))
    end
    @test_throws DimensionMismatch compile_parameters(QCircuit([MixedMalformedSlots((1,),[.1,.2],(1,)),RyGate(1,θ)]))
    external=compile_parameters(QCircuit([MixedActiveInstruction((1,),[.1,.2]),RyGate(1,θ)]))
    @test active_parameters(bind_parameters(external,[.4,.5,.6]))==[.4,.5,.6]
    @test_throws ArgumentError compile_parameters(external;fixed=Dict(first(parameter_order(external))=>.7))
    obj=ExpectationObjective(external,QubitsTerm(1=>Z),StateVector(1))
    @test_throws UnsupportedGradient value_and_gradient(AdjointGradient(),obj,[.4,.5,.6])
    Random.seed!(991); expected=rand()
    Random.seed!(991)
    compile_parameters(QCircuit([RxGate(1,.2;isparas=true),RyGate(1,θ)]))
    @test rand()==expected
end
