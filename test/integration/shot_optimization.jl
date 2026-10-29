using Test, Random, MOSSQuantum
using MOSSQuantum.Optimization
@testset "Finite-shot optimization workflows" begin
    c = QCircuit([RyGate(1,0.;isparas=true),Depolarizing(1;p=.02)])
    objective = ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=600)
    initial = [.4]
    result = minimize(objective,initial;iterations=45,learning_rate=.15,rng=Xoshiro(41))
    @test initial == [.4]
    @test result.estimate.value < -.9
    @test result.status == :iteration_limit
    @test result.shots == (45*3+1)*600
    @test result.evaluations == 45*3+1
    @test first(result.history).parameters == initial
    stopped = minimize(objective,initial;iterations=10,callback=step->false,rng=Xoshiro(1))
    @test stopped.status == :callback && stopped.parameters == initial
    @test length(stopped.history)==1
    spsa = minimize(objective,initial;method=SPSAGradient(step=.2,directions=2),optimizer=:sgd,
        iterations=80,learning_rate=.5,decay=.3,rng=Xoshiro(42))
    @test spsa.estimate.value < -.85
    @test spsa.shots == (80*5+1)*600
    empty = minimize(objective,initial;iterations=0,rng=Xoshiro(3))
    @test empty.parameters==initial && empty.shots==600
    @test_throws ArgumentError minimize(objective,initial;iterations=-1)
end
@testset "Optimizer shot budget" begin
    c=QCircuit([RyGate(1,0.;isparas=true)])
    o=ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=100)
    r=minimize(o,[.3];iterations=100,max_shots=750,rng=Xoshiro(4))
    @test r.status==:shot_budget && length(r.history)==2
    @test r.shots==700 && r.evaluations==7
    r=minimize(o,[.3];iterations=100,max_shots=100,rng=Xoshiro(4))
    @test isempty(r.history) && r.shots==100 && r.status==:shot_budget
    @test_throws ShotBudgetExceeded minimize(o,[.3];max_shots=99)
end

@testset "Adaptive optimizer final statistics" begin
    c=QCircuit([RyGate(1,0.;isparas=true)])
    o=ShotExpectationObjective(c,QubitsTerm(1=>Z)+.2QubitsTerm(1=>X),StateVector(1);
        shots=100,allocation=VarianceAllocation(pilot_shots=8))
    r=minimize(o,[.3];iterations=10,max_shots=750,rng=Xoshiro(9))
    @test r.estimate isa AdaptiveEstimate
    @test r.estimate.shots==100 && r.estimate.pilot_shots==16
    @test r.shots==700 && r.status==:shot_budget
    @test isfinite(r.estimate.value) && isfinite(r.estimate.variance)
end
