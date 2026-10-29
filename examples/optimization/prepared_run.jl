using MOSSQuantum, Random
using MOSSQuantum.Optimization

circuit = QCircuit([RyGate(1,0.;isparas=true),Depolarizing(1;p=.02)])
hamiltonian = QubitsTerm(1=>Z) + .2QubitsTerm(1=>X)
initial = StateVector(1)
plan = prepare_estimation(circuit,hamiltonian,initial)
points = reshape(collect(range(.2,3.;length=12)),1,:)
scan = run_sweep(plan,points;shots=1000,parallel=true,rng=Xoshiro(42),budget=ShotBudget(12_000))
println("Sweep: ",scan.evaluations," parameter points, ",scan.shots," shots")

objective = ShotExpectationObjective(circuit,hamiltonian,initial;
    shots=1000,allocation=VarianceAllocation(pilot_shots=16))
result = minimize(objective,[.4];iterations=100,learning_rate=.12,
    max_shots=100_000,rng=Xoshiro(43))
@assert result.shots<=100_000
println("Optimization: ",result.status,", ",length(result.history)," updates, ",result.shots," shots")
println("Fresh final energy: ",result.estimate.value," ± ",result.estimate.stderr)
