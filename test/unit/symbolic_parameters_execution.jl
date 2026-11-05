using Random, LinearAlgebra

module SymbolicExecutionFixtures
import MOSSQuantum as MQ

# Its prototype deliberately has an invalid angle. Structural preparation must
# never query the matrix before an actual value has been bound.
struct PositiveAngleGate <: MQ.ParametricGate{1}
    pos::Tuple{Int}
    angle::Float64
    active::Bool
end
MQ.parameters(g::PositiveAngleGate) = [g.angle]
MQ.active_parameters(g::PositiveAngleGate) = g.active ? [g.angle] : Float64[]
MQ.nparameters(g::PositiveAngleGate) = Int(g.active)
MQ.copy_instruction(g::PositiveAngleGate) = g
MQ.change_positions(g::PositiveAngleGate,m::AbstractDict) = PositiveAngleGate((m[g.pos[1]],),g.angle,g.active)
function MQ.reset_parameters!(g::PositiveAngleGate,values::AbstractVector{<:Real})
    length(values)==Int(g.active) || throw(DimensionMismatch())
    return g.active ? PositiveAngleGate(g.pos,Float64(only(values)),true) : g
end
function MQ.materialize_parameters(g::PositiveAngleGate,values::AbstractVector{<:Real},mask::AbstractVector{Bool})
    length(values)==length(mask)==1 || throw(DimensionMismatch())
    return PositiveAngleGate(g.pos,Float64(only(values)),only(mask))
end
function MQ.mat(g::PositiveAngleGate)
    g.angle>0 || throw(DomainError(g.angle,"the bound angle must be positive"))
    return MQ.Ry(g.angle)
end
MQ.differentiate(g::PositiveAngleGate) = MQ.differentiate(MQ.RyGate(g.pos[1],g.angle;isparas=g.active))
MQ.parameter_shift_rule(g::PositiveAngleGate,i::Integer) =
    i==1 && g.active ? [(0.5,pi/2),(-0.5,-pi/2)] : nothing
end

@testset "Affine independent coordinates and gate-occurrence shifts" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    z = QubitsTerm(1=>Z)
    shared = QCircuit([RyGate(1,θ),RyGate(1,θ)])
    objective = ExpectationObjective(shared,z,StateVector(1))
    x = [.43]
    for method in (AdjointGradient(),ParameterShift(),FiniteDifference(step=1e-5),SPSAGradient(step=1e-5,directions=4))
        value,g = method isa AdjointGradient ? value_and_gradient(method,objective,x) :
            value_and_gradient(method,objective,x;rng=Xoshiro(10))
        @test value ≈ cos(2x[1])
        @test g ≈ [-2sin(2x[1])] atol=1e-8
    end
    @test estimate_gradient(ParameterShift(),objective,x).evaluations==5

    c = QCircuit([RyGate(1,2θ+φ+pi/7)])
    point = [.2,.31]
    angle = 2point[1]+point[2]+pi/7
    exact = ExpectationObjective(c,z,StateVector(1);parameter_order=[θ,φ])
    for method in (AdjointGradient(),ParameterShift(),FiniteDifference(step=1e-5))
        value,g = method isa AdjointGradient ? value_and_gradient(method,exact,point) :
            value_and_gradient(method,exact,point;rng=Xoshiro(1))
        @test value ≈ cos(angle)
        @test g ≈ -sin(angle).*[2,1] atol=1e-8
    end
    reversed = ExpectationObjective(c,z,StateVector(1);parameter_order=[φ,θ])
    @test parameter_order(reversed)==[φ,θ]
    @test last(value_and_gradient(ParameterShift(),reversed,reverse(point))) ≈ -sin(angle).*[1,2]

    frozen = ExpectationObjective(c,z,StateVector(1);fixed=Dict(θ=>point[1]))
    @test trainable_parameters(frozen)==[φ]
    @test last(value_and_gradient(ParameterShift(),frozen,[point[2]])) ≈ [-sin(angle)]
    allfixed = ExpectationObjective(c,z,StateVector(1);fixed=Dict(θ=>point[1],φ=>point[2]))
    for method in (ParameterShift(),FiniteDifference(),SPSAGradient())
        result = estimate_gradient(method,allfixed,Float64[])
        @test isempty(result.gradient)
        @test result.value ≈ cos(angle)
        @test result.evaluations==1
    end
end

@testset "Affine finite-shot covariance and budgets" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    c = QCircuit([RyGate(1,2θ+φ)])
    objective = ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=1600)
    @test parameter_order(objective)==[θ,φ]
    @test required_shots(ParameterShift(),objective,[.2,.31])==4800
    result = estimate_gradient(ParameterShift(),objective,[.2,.31];rng=Xoshiro(52))
    @test result.evaluations==3 && result.shots==4800
    @test result.gradient[1]==2result.gradient[2]
    @test result.sampling_covariance[1,1]≈4result.sampling_covariance[2,2]
    @test result.sampling_covariance[1,2]≈2result.sampling_covariance[2,2]
    @test result.sampling_covariance[1,2]==result.sampling_covariance[2,1]
    @test result.sampling_covariance[2,2]>0
    @test abs(result.gradient[2]+sin(.71))<6result.stderr[2]

    shared = ShotExpectationObjective(QCircuit([RyGate(1,θ),RyGate(1,θ)]),
        QubitsTerm(1=>Z),StateVector(1);shots=600)
    result = estimate_gradient(ParameterShift(),shared,[.4];rng=Xoshiro(31))
    @test result.evaluations==5 && result.shots==3000
    @test abs(result.gradient[1]+2sin(.8))<6result.stderr[1]

    rng = Xoshiro(4); untouched = copy(rng)
    @test_throws ShotBudgetExceeded estimate_gradient(ParameterShift(),objective,[.2,.31];
        rng,budget=ShotBudget(4799))
    @test rand(rng)==rand(untouched)

    frozen = ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=100,fixed=Dict(θ=>.2,φ=>.31))
    @test required_shots(ParameterShift(),frozen,Float64[])==100
    result = estimate_gradient(ParameterShift(),frozen,Float64[];rng=Xoshiro(6))
    @test result.shots==100 && result.evaluations==1
    @test size(result.covariance)==(0,0)
    @test isempty(result.gradient)

    unsupported = parameterize(FSIMGate(1,2,zeros(5);isparas=[true,true,false,false,false]),[θ,φ])
    bad = ShotExpectationObjective(QCircuit([unsupported]),QubitsTerm(1=>Z),StateVector(2);shots=100)
    rng = Xoshiro(9); untouched = copy(rng)
    @test_throws UnsupportedGradient estimate_gradient(ParameterShift(),bad,[.2,.31];rng)
    @test rand(rng)==rand(untouched)
end

@testset "Named prepared execution, estimation and sweeps" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    c = QCircuit([RyGate(1,θ),CNOTGate(1,2),RzGate(2,φ/2),Depolarizing(1;p=.1)])
    for method in (DensityMatrixEvolution(),KrausTrajectory())
        plan = prepare_execution(c,StateVector(2);parameter_order=[φ,θ],fixed=Dict(φ=>.3),method,qubits=[2,1])
        @test parameter_order(plan)==[θ]
        @test independent_parameters(plan)==[φ,θ]
        @test trainable_parameters(plan)==[θ]
        actual = execute(plan,[.4];shots=300,result=:counts,rng=Xoshiro(15))
        bound = bind_parameters(c,Dict(θ=>.4,φ=>.3))
        expected = execute(bound,StateVector(2);shots=300,result=:counts,method,qubits=[2,1],rng=Xoshiro(15))
        @test actual.counts==expected.counts
        @test actual.accepted==expected.accepted
        xs = reshape([.1,.4,.8],1,:)
        a = run_sweep(plan,xs;shots=100,rng=Xoshiro(8))
        b = run_sweep(plan,xs;shots=100,rng=Xoshiro(8),parallel=true)
        @test [r.counts for r in a.results]==[r.counts for r in b.results]
        @test a.shots==300 && a.evaluations==3
        @test_throws DimensionMismatch run_sweep(plan,zeros(2,1);shots=10)
        @test_throws ArgumentError run_sweep(plan,trues(1,1);shots=10)
        @test_throws ArgumentError bind_execution(plan,[true])
    end

    h = QubitsTerm(1=>Z)+.3QubitsTerm(2=>X)
    plan = prepare_estimation(c,h,StateVector(2);fixed=Dict(φ=>.3))
    @test parameter_order(plan)==[θ]
    objective = ShotExpectationObjective(c,h,StateVector(2);shots=1000,fixed=Dict(φ=>.3))
    @test estimate(plan,[.4];shots=1000,rng=Xoshiro(7)).value ==
          estimate(objective,[.4];rng=Xoshiro(7)).value
    @test abs(estimate(plan,[.4];shots=1000,rng=Xoshiro(7)).value-.9cos(.4))<.1
    frozen = prepare_execution(c,StateVector(2);fixed=Dict(θ=>.4,φ=>.3))
    @test isempty(parameter_order(frozen))
    @test execute(frozen;shots=10).shots==10
    @test length(run_sweep(frozen,zeros(0,2);shots=10).results)==2

    source = copy_instruction(c)
    fixed = Dict(φ=>.3)
    snapshot = prepare_execution(source,StateVector(2);fixed)
    before = execute(snapshot,[.4];shots=100,result=:counts,rng=Xoshiro(17))
    fixed[φ]=2.1
    push!(source,XGate(1))
    @test execute(snapshot,[.4];shots=100,result=:counts,rng=Xoshiro(17)).counts==before.counts
end

@testset "Prepared symbolic feedback and real-point external gates" begin
    θ = Parameter(:θ)
    c = QCircuit([HGate(1),QMeasure(1;key=:m,auto_reset=false),
        Conditional(:m,RyGate(2,θ);otherwise=RyGate(2,-θ/2)),QSelect(2,0)])
    plan = prepare_execution(c,StateVector(2))
    actual = execute(plan,[.7];shots=300,rng=Xoshiro(25))
    expected = execute(bind_parameters(c,Dict(θ=>.7)),StateVector(2);shots=300,rng=Xoshiro(25))
    @test actual.counts==expected.counts
    @test actual.accepted==expected.accepted
    @test actual.classical==expected.classical

    gate = parameterize(SymbolicExecutionFixtures.PositiveAngleGate((1,),0.,true),[θ])
    c = QCircuit([gate])
    objective = ExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1))
    @test !supports_gradient(ParameterShift(),objective)
    @test supports_gradient(ParameterShift(),objective,[2.])
    @test !supports_gradient(ParameterShift(),objective,[-2.])
    @test last(value_and_gradient(ParameterShift(),objective,[2.])) ≈ [-sin(2.)]
    plan = prepare_execution(c,StateVector(1))
    @test bind_execution(plan,[2.]).distribution ≈ [cos(1.)^2,sin(1.)^2]
    shot = ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=300)
    @test abs(estimate(shot,[2.];rng=Xoshiro(6)).value-cos(2.))<.15
    rng = Xoshiro(7); untouched=copy(rng)
    @test_throws DomainError execute(plan,[-2.];shots=10,rng)
    @test rand(rng)==rand(untouched)
end
