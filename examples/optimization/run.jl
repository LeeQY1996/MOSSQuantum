using MOSSQuantum, Random
using MOSSQuantum.Optimization

# A two-qubit variational energy with fixed noise and actual finite shots.
# Shared classical/quantum execution interfaces also allow feedback circuits.
hamiltonian = QubitsTerm(1=>Z) + QubitsTerm(2=>Z) + 0.2QubitsTerm(1=>X,2=>X)
circuit = QCircuit([RyGate(1,0.;isparas=true),RyGate(2,0.;isparas=true),
                    CNOTGate(1,2),Depolarizing(1;p=.02),Depolarizing(2;p=.02)])
objective = ShotExpectationObjective(circuit,hamiltonian,StateVector(2);shots=2000)
result = minimize(objective,[.4,.6];iterations=60,learning_rate=.12,rng=Xoshiro(42))
println("Final parameters: ",result.parameters)
println("Energy: ",result.estimate.value," ± ",result.estimate.stderr," (sampling stderr)")
println("Total shots: ",result.shots,"; objective evaluations: ",result.evaluations)
