using Test, Random
using MOSSQuantum
using MOSSMPS: zero_state_mps, MatrixProductBackend, NoTruncation
using MOSSStabilizer: StabilizerState, StabilizerBackend

# Run in a separate environment that develops MOSSQuantum and both companions.
# Do not require the companion packages in the core package's test environment.
cases = (
    ("dense", () -> StateVector(2), CPUBackend()),
    ("mps", () -> zero_state_mps(2), MatrixProductBackend(trunc=NoTruncation())),
    ("stabilizer", () -> StabilizerState(2), StabilizerBackend()),
)

@testset "Common backend contract: $name" for (name, initial, chosen) in cases
    bell = QCircuit([HGate(1), CNOTGate(1, 2)])
    state = initial()
    result = simulate(bell, state; backend=chosen, rng=MersenneTwister(1))
    @test probabilities(chosen, result.state; qubits=[2,1]) ≈ [0.5, 0, 0, 0.5]
    @test expectation(chosen, QubitsTerm(1=>"X", 2=>"X"), result.state) ≈ 1
    @test probabilities(chosen, state; qubits=[1,2]) ≈ [1, 0, 0, 0]
    sampled = execute(bell, state; backend=chosen, shots=128, rng=MersenneTwister(2))
    @test all(sampled.accepted)
    @test all(k in ("00", "11") for k in keys(sampled.counts))
    @test sum(values(sampled.counts)) == 128
    @test sampled.samples == execute(bell, state; backend=chosen, shots=128,
                                     rng=MersenneTwister(2)).samples
    observable = QubitsTerm(1=>"X", 2=>"X")
    estimate_report = execution_capability(chosen, bell, state; mode=:estimate,
                                           observable=observable, shots=64)
    @test estimate_report.status === :supported
    @test estimate(observable, bell, state; backend=chosen, shots=64,
                   rng=MersenneTwister(2)).value ≈ 1
    feedback = QCircuit([HGate(1), QMeasure(1; key=:m, auto_reset=false),
                         Conditional(:m, XGate(2))])
    shots = execute(feedback, state; backend=chosen, shots=64, rng=MersenneTwister(3))
    @test all(k in ("00", "11") for k in keys(shots.counts))
    @test all(length(records) == 1 for records in shots.measurements)
    selected = execute(QCircuit([HGate(1), QSelect(1,1)]), state;
                       backend=chosen, shots=128, rng=MersenneTwister(4))
    @test 0 < count(selected.accepted) < selected.shots
    @test sum(values(selected.counts)) == count(selected.accepted)
    @test all(k[1] == '1' for k in keys(selected.counts))
    error = ReadoutError(2; p0_to_1=1, p1_to_0=1)
    @test execute(QCircuit(), state; backend=chosen, shots=8, qubits=[2,1],
                  readout=error).counts == Dict("10" => 8)
    @test probabilities(chosen, state; qubits=[1,2]) ≈ [1,0,0,0]
end
