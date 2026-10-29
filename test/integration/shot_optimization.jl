include("../../algorithm_zoo/optimization/optimization.jl")
using .MOSSQuantumOptimization
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
