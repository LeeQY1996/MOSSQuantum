using Test
import MOSSQuantum
const QMixedFrontend = MOSSQuantum.QuantumCircuits

struct MixedFrontendAllActiveGate <: QMixedFrontend.Gate{1}
    pos::Tuple{Int}
    values::Vector{Float64}
end
QMixedFrontend.parameters(g::MixedFrontendAllActiveGate) = g.values
QMixedFrontend.active_parameters(g::MixedFrontendAllActiveGate) = g.values

struct MixedFrontendPartialGate <: QMixedFrontend.Gate{1}
    pos::Tuple{Int}
    values::Vector{Float64}
end
QMixedFrontend.parameters(g::MixedFrontendPartialGate) = g.values
QMixedFrontend.active_parameters(g::MixedFrontendPartialGate) = g.values[2:2]

struct MixedFrontendKeyedGate <: QMixedFrontend.Gate{1}
    pos::Tuple{Int}
    values::Vector{Float64}
end
QMixedFrontend.parameters(g::MixedFrontendKeyedGate) = g.values
QMixedFrontend.active_parameters(g::MixedFrontendKeyedGate) = g.values[2:2]
QMixedFrontend.parameter_slots(::MixedFrontendKeyedGate) = (:angle,)

struct MixedFrontendInstruction <: QMixedFrontend.AbstractInstruction
    values::Vector{Float64}
end
QMixedFrontend.parameters(g::MixedFrontendInstruction) = g.values
QMixedFrontend.active_parameters(g::MixedFrontendInstruction) = g.values

struct MixedFrontendBadResetGate <: QMixedFrontend.Gate{1}
    pos::Tuple{Int}
    angle::Float64
end
QMixedFrontend.parameters(g::MixedFrontendBadResetGate) = [g.angle]
QMixedFrontend.active_parameters(g::MixedFrontendBadResetGate) = [g.angle]
QMixedFrontend.reset_parameters!(::MixedFrontendBadResetGate, ::AbstractVector{<:Real}) = nothing

@testset "Physical parameter slot keys" begin
    Q = QMixedFrontend
    @test Q.parameter_slots(Q.HGate(1)) == ()
    @test Q.parameter_slots(Q.RxGate(1, .2)) == ()
    @test Q.parameter_slots(Q.RxGate(1, .2; isparas=true)) == (1,)
    prototype = Q.FSIMGate(1, 2, [.1,.2,.3,.4,.5]; isparas=[true,false,true,false,true])
    @test Q.parameter_slots(prototype) == (1,3,5)
    @test Q.parameter_slots(prototype') == (1,3,5)
    θ, φ = Q.Parameter(:θ), Q.Parameter(:φ)
    symbolic = Q.parameterize(prototype, (θ, .6, φ))
    @test Q.parameter_slots(symbolic) == (1,5)
    @test Q.parameter_slots(symbolic') == (1,5)
    @test Q.parameter_slots(Q.substitute_parameters(symbolic, Dict(θ=>.8))) == (5,)
    @test Q.parameter_slots(Q.substitute_parameters(symbolic, Dict(θ=>.8,φ=>.9))) == ()
    # Equal active counts do not imply equal physical layouts.
    Q.deactivate_parameter!(prototype, 1)
    Q.activate_parameter!(prototype, 2)
    @test Q.parameter_slots(prototype) == (2,3,5)
    @test Q.parameter_slots(symbolic) == (1,5)

    @test Q.parameter_slots(MixedFrontendAllActiveGate((1,), [.2,.3])) == (1,2)
    @test Q.parameter_slots(MixedFrontendInstruction([.2,.3])) == (1,2)
    @test Q.parameter_slots(MixedFrontendInstruction(Float64[])) == ()
    partial = MixedFrontendPartialGate((1,), [.2,.3])
    error = try Q.parameter_slots(partial) catch e; e end
    @test error isa ArgumentError
    @test occursin("parameter_slots", sprint(showerror, error))
    keyed = MixedFrontendKeyedGate((1,), [.2,.3])
    @test Q.parameter_slots(keyed) == (:angle,)
    @test Q.parameter_slots(keyed') == (:angle,)
    @test Q.parameter_slots(Q.parameterize(keyed, (θ,))) == (:angle,)
end

@testset "Raw mixed discovery and named substitution" begin
    Q = QMixedFrontend
    θ, φ = Q.Parameter(:θ), Q.Parameter(:φ)
    numeric = Q.RxGate(1, .2; isparas=true)
    circuit = Q.QCircuit([numeric, Q.Conditional(:flag, Q.RyGate(1,θ); otherwise=Q.RzGate(1,φ))])
    @test Q._has_anonymous_parameters(numeric)
    @test Q._has_anonymous_parameters(circuit)
    @test !Q._has_anonymous_parameters(Q.RyGate(1,θ))
    @test !Q._has_anonymous_parameters(Q.QCircuit([Q.RyGate(1,θ),Q.HGate(1)]))
    @test Q._named_parameters(circuit) == [θ,φ]
    @test_throws ArgumentError Q.independent_parameters(circuit)
    @test_throws ArgumentError Q.parameter_order(circuit)
    @test Q.independent_parameters(Q.QCircuit([numeric])) == Q.Parameter[]
    @test Q.parameter_order(Q.QCircuit([Q.RyGate(1,θ)])) == [θ]
    error = try Q._require_bound_parameters(circuit) catch e; e end
    @test error isa Q.UnboundParameterError
    @test error.path == (2,:then,1)
    @test error.parameters == (θ,)
    substituted = Q.substitute_parameters(circuit, Dict(θ=>φ,φ=>.5))
    @test Q._named_parameters(substituted) == [φ]
    @test Q.active_parameters(substituted[1]) == [.2]
    @test substituted[1] !== numeric
    Q.reset_parameters!(substituted[1], [.7])
    @test Q.active_parameters(numeric) == [.2]
    @test_throws ArgumentError Q.substitute_parameters(circuit, Dict(:unknown=>.1))
end

@testset "Materialization replaces active placeholders" begin
    Q = QMixedFrontend
    prototype = Q.FSIMGate(1,2,[Inf,.2,NaN,.4,-Inf]; isparas=[true,false,true,false,true])
    result = Q.materialize_parameters(prototype, [.6,.7,.8], [false,true,false])
    @test Q.parameters(result) == [.6,.2,.7,.4,.8]
    @test Q.active_parameters(result) == [.7]
    @test Q.parameter_slots(result) == (3,)
    @test isequal(Q.parameters(prototype), [Inf,.2,NaN,.4,-Inf])
    @test Q.parameter_slots(prototype) == (1,3,5)
    frozen_bad = Q.FSIMGate(1,2,[.1,Inf,.3,.4,.5]; isparas=[true,false,true,false,true])
    @test_throws ArgumentError Q.materialize_parameters(frozen_bad, [.6,.7,.8], [true,true,true])
    @test Q.parameter_slots(Q.materialize_parameters(Q.RyGate(1,Inf;isparas=true), [.4], [false])) == ()
    @test_throws ArgumentError Q.materialize_parameters(Q.RyGate(1,Inf), Float64[], Bool[])
    @test_throws ArgumentError Q.materialize_parameters(MixedFrontendBadResetGate((1,),.2), [.4], [false])
end
