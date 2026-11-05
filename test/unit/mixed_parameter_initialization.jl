using Test, Random

struct InitialPartialInstruction <: AbstractInstruction
    pos::Tuple{Int}
    values::Vector{Float64}
    activity::Vector{Bool}
end
MOSSQuantum.QuantumCircuits.parameters(x::InitialPartialInstruction) = x.values
MOSSQuantum.QuantumCircuits.active_parameters(x::InitialPartialInstruction) = x.values[x.activity]

@testset "Mixed parameter metadata and initialization" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    circuit = QCircuit([
        RxGate(1, .25; isparas=true),
        RyGate(2, θ),
        RzGate(1, .8),
        CPHASEGate(1, 2, 2θ + φ),
    ])
    compiled = compile_parameters(circuit)
    anonymous = parameter_order(compiled)[1]
    info = parameter_info(compiled)
    @test info isa Tuple
    @test length(info) == 3
    @test [entry.parameter for entry in info] == [anonymous, θ, φ]
    @test [entry.kind for entry in info] == [:anonymous, :named, :named]
    @test [entry.input_index for entry in info] == [1, 2, 3]
    @test all(isnothing(entry.fixed) for entry in info)
    @test info[1].initial == .25
    @test ismissing(info[2].initial)
    @test ismissing(info[3].initial)
    @test info[1].sources == ((;path=(1,), slot=1, active_index=1),)
    @test info[2].sources == ((;path=(2,), slot=1, active_index=1), (;path=(4,), slot=1, active_index=1))
    @test info[3].sources == ((;path=(4,), slot=1, active_index=1),)
    @test isequal(parameter_info(compiled.parameter_map), info)
    @test initial_parameters(compiled;values=Dict(θ=>.3,φ=>.4)) == [.25,.3,.4]
    @test initial_parameters(compiled;values=Dict(:θ=>.3,:φ=>.4)) == [.25,.3,.4]
    @test initial_parameters(compiled;values=Dict("θ"=>.3,"φ"=>.4)) == [.25,.3,.4]
    @test initial_parameters(compiled.parameter_map;values=Dict(anonymous=>.7,θ=>.3,φ=>.4)) == [.7,.3,.4]
    @test initial_parameters(compiled;values=Dict(θ=>.6,φ=>.9)) == [.25,.6,.9]
    @test_throws ArgumentError initial_parameters(compiled)
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>.3))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>.3,φ=>.4,:other=>.2))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(:θ=>.3,:φ=>.4,info[1].label=>.7))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>NaN,φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>Inf,φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>true,φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>.3im,φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>.3,:φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(:θ=>.3,"θ"=>.7,:φ=>.4))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(Parameter(:θ)=>.3,φ=>.4))
    @test_throws ArgumentError MOSSQuantum._resolve_context_values(compiled.parameter_map, Dict(θ=>.3);require_all=true)
    @test MOSSQuantum._resolve_context_values(compiled.parameter_map, Dict(θ=>.3);require_all=false) == Dict(θ=>.3)

    reordered = compile_parameters(compiled;parameter_order=[φ,anonymous,θ])
    @test initial_parameters(reordered;values=Dict(θ=>.3,φ=>.4)) == [.4,.25,.3]
    @test [entry.input_index for entry in parameter_info(reordered)] == [2,3,1]
    frozen = compile_parameters(compiled;fixed=Dict(anonymous=>.7,θ=>.3))
    frozen_info = parameter_info(frozen)
    @test [entry.parameter for entry in frozen_info] == [anonymous,θ,φ]
    @test frozen_info[1].initial == .25
    @test frozen_info[1].fixed == .7
    @test frozen_info[2].fixed == .3
    @test frozen_info[3].fixed === nothing
    @test [entry.input_index for entry in frozen_info] == [nothing,nothing,1]
    @test initial_parameters(frozen;values=Dict(φ=>.4)) == [.4]
    @test_throws ArgumentError initial_parameters(frozen;values=Dict(anonymous=>.7,φ=>.4))
    @test_throws ArgumentError initial_parameters(frozen;values=Dict(:θ=>.3,:φ=>.4))
    @test MOSSQuantum._resolve_context_values(frozen.parameter_map, Dict(anonymous=>.8);require_all=false,scope=:variables) == Dict(anonymous=>.8)
    allfixed = compile_parameters(frozen;fixed=Dict(φ=>.4))
    @test initial_parameters(allfixed) == Float64[]
    @test_throws ArgumentError initial_parameters(allfixed;values=Dict(φ=>.4))

    other_context = compile_parameters(circuit)
    @test_throws ArgumentError initial_parameters(other_context;values=Dict(anonymous=>.7,θ=>.3,φ=>.4))
    duplicate_name = compile_parameters(QCircuit([RyGate(1,Parameter(:same)),RzGate(1,Parameter(:same))]))
    @test_throws ArgumentError initial_parameters(duplicate_name;values=Dict(:same=>.1))
    duplicate_parameters = parameter_order(duplicate_name)
    @test initial_parameters(duplicate_name;values=Dict(duplicate_parameters[1]=>.1,duplicate_parameters[2]=>.2)) == [.1,.2]
    colliding_name = Parameter(info[1].label)
    collision = compile_parameters(QCircuit([RxGate(1,.2;isparas=true),RyGate(1,colliding_name)]))
    @test parameter_info(collision)[1].label == colliding_name.name
    @test initial_parameters(collision;values=Dict(colliding_name.name=>.4)) == [.2,.4]
end

@testset "Legacy integer defaults and sources" begin
    circuit = QCircuit([
        RxGate(1,.2;isparas=true),
        QCircuit([RyGate(2,.4;isparas=true)]),
        Conditional(:flag,RzGate(1,.2;isparas=true);otherwise=RxGate(2,.8;isparas=true)),
    ])
    compiled = compile_parameters(circuit)
    @test initial_parameters(compiled) == [.2,.4,.2,.8]
    @test initial_parameters(compiled;values=Dict(2=>.6)) == [.2,.6,.2,.8]
    info = parameter_info(compiled)
    @test [entry.parameter for entry in info] == [1,2,3,4]
    @test [entry.initial for entry in info] == [.2,.4,.2,.8]
    @test info[2].sources == ((;path=(2,1),slot=1,active_index=1),)
    @test info[3].sources == ((;path=(3,:then,1),slot=1,active_index=1),)
    @test info[4].sources == ((;path=(3,:else,1),slot=1,active_index=1),)
    shared = compile_parameters(circuit;parameter_map=ParameterMap([1,2,1,3]))
    @test initial_parameters(shared) == [.2,.4,.8]
    @test length(parameter_info(shared)[1].sources) == 2
    conflicting = compile_parameters(circuit;parameter_map=ParameterMap([1,1,2,3]))
    @test ismissing(parameter_info(conflicting)[1].initial)
    error = try
        initial_parameters(conflicting)
        nothing
    catch caught
        caught
    end
    @test error isa ArgumentError
    @test occursin("conflicting", sprint(showerror,error))
    @test occursin("path", sprint(showerror,error))
    @test initial_parameters(conflicting;values=Dict(1=>.7)) == [.7,.2,.8]
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(:parameter_1=>.7))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(5=>.7))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(true=>.7))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(1=>false))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(1=>Inf))
    map = compiled.parameter_map
    @test all(ismissing(entry.initial) && isempty(entry.sources) for entry in parameter_info(map))
    @test_throws ArgumentError initial_parameters(map)
    @test initial_parameters(map;values=Dict(1=>.1,2=>.2,3=>.3,4=>.4)) == [.1,.2,.3,.4]
    @test initial_parameters(compile_parameters(QCircuit())) == Float64[]

    external = compile_parameters(InitialPartialInstruction((1,),[.3,.7],[false,true]))
    @test initial_parameters(external) == [.7]
    @test isequal(parameter_info(external)[1].sources, ((;path=(),slot=missing,active_index=1),))
    multi = compile_parameters(FSIMGate((1,2), [.1,.2,.3,.4,.5];isparas=[true,false,true,false,true]))
    @test initial_parameters(multi) == [.1,.3,.5]
    @test [only(entry.sources).slot for entry in parameter_info(multi)] == [1,3,5]
end

@testset "Initial parameter placeholders and RNG isolation" begin
    θ = Parameter(:θ)
    placeholder = compile_parameters(QCircuit([RxGate(1,NaN;isparas=true),RyGate(1,θ)]))
    anonymous = first(parameter_order(placeholder))
    @test ismissing(parameter_info(placeholder)[1].initial)
    @test_throws ArgumentError initial_parameters(placeholder;values=Dict(θ=>.3))
    @test initial_parameters(placeholder;values=Dict(anonymous=>.2,θ=>.3)) == [.2,.3]
    legacy_placeholder = compile_parameters(RxGate(1,NaN;isparas=true))
    @test_throws ArgumentError initial_parameters(legacy_placeholder)
    @test initial_parameters(legacy_placeholder;values=Dict(1=>.2)) == [.2]

    Random.seed!(1007)
    expected = rand()
    Random.seed!(1007)
    circuit = QCircuit([RxGate(1,.2;isparas=true),RyGate(1,θ)])
    compiled = compile_parameters(circuit)
    parameter_info(compiled)
    initial_parameters(compiled;values=Dict(θ=>.3))
    @test_throws ArgumentError initial_parameters(compiled;values=Dict(θ=>Inf))
    @test rand() == expected
end
