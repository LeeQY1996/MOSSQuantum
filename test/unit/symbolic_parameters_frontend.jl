using Test, Random
import MOSSQuantum
const QSymbolicFrontend = MOSSQuantum.QuantumCircuits

struct SymbolicFrontendImmutableGate <: QSymbolicFrontend.Gate{1}
    pos::Tuple{Int}
    angle::Float64
end
QSymbolicFrontend.parameters(x::SymbolicFrontendImmutableGate) = [x.angle]
QSymbolicFrontend.active_parameters(x::SymbolicFrontendImmutableGate) = [x.angle]
QSymbolicFrontend.reset_parameters!(x::SymbolicFrontendImmutableGate, values::AbstractVector{<:Real}) =
    length(values) == 1 ? SymbolicFrontendImmutableGate(x.pos, only(values)) : throw(DimensionMismatch("one parameter required"))

@testset "Symbolic parameter identity and affine expressions" begin
    Q = QSymbolicFrontend
    Random.seed!(4921)
    expected = rand()
    Random.seed!(4921)
    θ, φ = Q.Parameter(:θ), Q.Parameter("φ")
    @test rand() == expected
    @test θ != Q.Parameter(:θ)
    @test copy(θ) === θ
    @test deepcopy(θ) == θ
    @test_throws ArgumentError Q.Parameter("")

    e = 2θ + φ + π/4
    @test e.terms == (θ => 2., φ => 1.)
    @test e.constant == π/4
    @test e == φ + 2θ + π/4
    @test hash(e) == hash(φ + 2θ + π/4)
    @test θ - θ == 0
    @test hash(θ - θ) == hash(0)
    @test 0θ == 0
    @test length((1e-100 * θ).terms) == 1
    @test θ / 2 == 0.5θ
    @test 1 - θ == -θ + 1
    @test sprint(show,e) == "2.0*θ + φ + 0.7853981633974483"
    @test_throws ArgumentError Q.ParameterExpr(true)
    @test_throws ArgumentError Q.ParameterExpr(Inf)
    @test_throws ArgumentError true * θ
    @test_throws ArgumentError θ / 0
    @test_throws ArgumentError θ * φ
    @test_throws ArgumentError θ / φ
    @test_throws ArgumentError θ + Inf

    @test Q._resolve_parameter_assignments([θ,φ],Dict(θ=>0.2,φ=>0.3)) == Dict(θ=>.2,φ=>.3)
    @test Q._resolve_parameter_assignments([θ,φ],Dict(:θ=>0.2,"φ"=>0.3)) == Dict(θ=>.2,φ=>.3)
    @test_throws ArgumentError Q._resolve_parameter_assignments([θ,Q.Parameter(:θ)],Dict(:θ=>.2))
    @test_throws ArgumentError Q._resolve_parameter_assignments([θ],Dict(:other=>.2))
    @test_throws ArgumentError Q._resolve_parameter_assignments([θ,φ],Dict(θ=>.2,:φ=>.3))
    @test_throws ArgumentError Q._resolve_parameter_assignments([θ,φ],Dict(θ=>.2))
    @test_throws ArgumentError Q._resolve_parameter_assignments([θ],Dict(θ=>true))
end

@testset "Symbolic instructions and materialization" begin
    Q = QSymbolicFrontend
    θ, φ = Q.Parameter(:θ), Q.Parameter(:φ)
    gate = Q.RyGate(1, θ)
    @test gate isa Q.ParameterizedInstruction
    @test Q.nparameters(gate) == 1
    @test Q.nqubits(gate) == 1
    @test Q.positions(gate) == (1,)
    @test Q.independent_parameters(gate) == [θ]
    @test_throws Q.UnboundParameterError Q.mat(gate)
    @test_throws Q.UnboundParameterError Q.parameters(gate)
    @test_throws Q.UnboundParameterError Q.active_parameters(gate)
    @test_throws ArgumentError Q.deactivate_parameters!(gate)
    @test Q.positions(Q.shift(gate, 2)) == (3,)
    @test Q.independent_parameters(Q.shift(gate,2)) == [θ]
    @test Q.independent_parameters(Q.copy_instruction(gate)) == [θ]
    circuit = Q.QCircuit([gate, Q.Conditional(:m,Q.RzGate(2,φ);otherwise=Q.RxGate(2,θ+φ))])
    @test Q.independent_parameters(circuit) == [θ,φ]
    @test Q.nparameters(circuit) == 3
    @test length(Q.parameter_expressions(circuit)) == 3
    @test_throws Q.UnboundParameterError Q._require_bound_parameters(circuit)
    @test Q._require_bound_parameters(Q.QCircuit([Q.HGate(1)])) === nothing
    partial = Q.substitute_parameters(circuit,Dict(θ=>.2))
    @test Q.independent_parameters(partial) == [φ]
    @test Q.nparameters(partial) == 2
    @test length(Q.parameter_expressions(partial)) == 3
    @test Q.independent_parameters(circuit) == [θ,φ]
    swapped = Q.substitute_parameters(circuit,Dict(θ=>φ,φ=>θ))
    @test Q.independent_parameters(swapped) == [φ,θ]
    @test_throws ArgumentError Q.substitute_parameters(circuit,Dict(:other=>1))
    @test_throws Q.UnboundParameterError Q._require_bound_parameters(Q.substitute_parameters(gate,Dict(θ=>.2)))
    numeric = Q.materialize_parameters(gate.prototype,[.4],[true])
    @test Q.mat(numeric) ≈ Q.mat(Q.RyGate(1,.4))
    @test Q.nparameters(numeric) == 1
    frozen = Q.materialize_parameters(gate.prototype,[.4],[false])
    @test Q.mat(frozen) ≈ Q.mat(numeric)
    @test Q.nparameters(frozen) == 0
    @test Q.parameters(gate.prototype) == [0.]
    phase = Q.PHASEGate(1, θ)'
    materialized_adjoint = Q.materialize_parameters(phase.prototype,[.4],[true])
    @test Q.mat(materialized_adjoint) ≈ Q.mat(Q.PHASEGate(1,.4))'
    @test Q.mat(Q.materialize_parameters(Q.shift(phase,1).prototype,[.4],[true])) ≈ Q.mat(Q.PHASEGate(2,.4))'
    @test Q.independent_parameters(phase') == [θ]

    proto = Q.FSIMGate(1,2,[.1,.2,.3,.4,.5];isparas=[true,false,true,false,true])
    result = Q.materialize_parameters(proto,[.6,.7,.8],[false,true,false])
    @test Q.parameters(result) == [.6,.2,.7,.4,.8]
    @test Q.active_parameters(result) == [.7]
    @test Q.parameters(proto) == [.1,.2,.3,.4,.5]
    @test_throws DimensionMismatch Q.materialize_parameters(proto,[.6],[true])
    @test_throws ArgumentError Q.materialize_parameters(proto,[.6,Inf,.8],[true,true,true])
    immutable = SymbolicFrontendImmutableGate((1,),.2)
    @test Q.materialize_parameters(immutable,[.8],[true]).angle == .8
    @test immutable.angle == .2
    # An inherited no-op activity writer cannot silently freeze a custom gate.
    @test_throws ArgumentError Q.materialize_parameters(immutable,[.8],[false])

    for constructor in (Q.RxGate,Q.RyGate,Q.RzGate,Q.PHASEGate)
        @test constructor(1,θ) isa Q.ParameterizedInstruction
        @test constructor(1;θ=θ) isa Q.ParameterizedInstruction
        @test Q.nparameters(constructor(1;θ=.2)) == 0
    end
    for constructor in (Q.CRxGate,Q.CRyGate,Q.CRzGate,Q.CPHASEGate)
        @test constructor(1,2,θ) isa Q.ParameterizedInstruction
        @test constructor(;control=1,target=2,θ=θ) isa Q.ParameterizedInstruction
        @test Q.nparameters(constructor(;control=1,target=2,θ=.2)) == 0
    end
    @test Q.CCPHASEGate(1,2,3,θ) isa Q.ParameterizedInstruction
    @test Q.FSIMGate(1,2,[θ,0.,φ,0.,0.]) isa Q.ParameterizedInstruction
    @test Q.FSIMGate(;control=1,target=2,θs=[θ,0.,φ,0.,0.]) isa Q.ParameterizedInstruction
    @test_throws ArgumentError Q.RyGate(1,θ;isparas=false)
    @test_throws ArgumentError Q.CRxGate(1,2,θ;isparas=true)
    @test_throws ArgumentError Q.FSIMGate(1,2,[θ,0.,φ,0.,0.];isparas=fill(true,5))
end
