# Develop MOSSQuantum, MOSSQuantumMPS and MOSSQuantumStabilizer in one Julia environment.
using MOSSQuantum, Random
using MOSSQuantumMPS: zero_state_mps, MatrixProductBackend, NoTruncation
using MOSSQuantumStabilizer: StabilizerState, StabilizerBackend

circuit = QCircuit([HGate(1), CNOTGate(1, 2)])
observable = QubitsTerm(1=>"Z", 2=>"Z")
choices = (
    ("dense", StateVector(2), CPUBackend()),
    ("MPS", zero_state_mps(2), MatrixProductBackend(trunc=NoTruncation())),
    ("stabilizer", StabilizerState(2), StabilizerBackend()),
)

for (name, initial, chosen) in choices
    report = execution_capability(chosen, circuit, initial; mode=:execute)
    report.status === :supported || error("$name cannot run this example: $(report.issues)")
    state = simulate(circuit, initial; backend=chosen).state
    result = execute(circuit, initial; backend=chosen, shots=100, rng=MersenneTwister(42))
    println((backend=name, expectation=expectation(chosen, observable, state), counts=result.counts))
end
