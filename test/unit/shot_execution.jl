using Test, Random, MOSSQuantum

module ShotExecutionBackendFixture
using MOSSQuantum
struct ProbeBackend <: AbstractBackend
    reads::Base.RefValue{Int}
    malformed::Symbol
end
MOSSQuantum.supports(::ProbeBackend, ::QCircuit, ::StateVector; action=:apply) = action === :apply
function MOSSQuantum.probabilities(b::ProbeBackend, state::StateVector; qubits=1:nqubits(state))
    b.reads[] += 1
    b.malformed === :complex && return ComplexF64[1, 0]
    b.malformed === :shape && return [0.5, 0.25, 0.25]
    return probabilities(CPUBackend(), state; qubits=qubits)
end
end

@testset "Circuit shots and terminal readout" begin
    bell = QCircuit([HGate(1), CNOTGate(1, 2)])
    initial = StateVector(2)
    before = copy(initial)
    result = execute(bell, initial; shots=128, rng=MersenneTwister(51))
    @test result.shots == 128
    @test result.qubits == [1, 2]
    @test all(result.accepted)
    @test all(isempty, result.measurements)
    @test result.samples[:, 1] == result.samples[:, 2]
    @test sum(values(result.counts)) == 128
    @test result.samples == sample(MersenneTwister(51), bell * initial, 128)
    @test result.samples == sample(MersenneTwister(51), bell, initial, 128)
    @test result.counts == counts(bell, initial, 128; rng=MersenneTwister(51))
    @test initial == before
    @test execute(QCircuit(), onehot_encoding([1, 0]); shots=4, qubits=[2, 1]).counts == Dict("01" => 4)
    @test execute(bell, DensityMatrix(initial); shots=128, rng=MersenneTwister(51)).samples == result.samples
    noisy = QCircuit([XGate(1), AmplitudeDamping(1; γ=1)])
    @test execute(noisy, StateVector(1); shots=32).counts == Dict("0" => 32)
end

@testset "Shot execution respects selected backend and register contract" begin
    fixture = ShotExecutionBackendFixture
    chosen = fixture.ProbeBackend(Ref(0), :none)
    @test execute(QCircuit(), StateVector(1); shots=4, backend=chosen).counts == Dict("0" => 4)
    @test chosen.reads[] == 2
    # The backend claims circuit support, but the shot protocol itself cannot
    # preserve its output columns if a measurement removes a qubit.
    @test_throws UnsupportedOperation execute(QCircuit([QCircuit([QMeasure(1; keep=false)])]),
        StateVector(1); shots=4, backend=chosen)
    @test_throws ArgumentError execute(QCircuit(), StateVector(1); shots=4,
        backend=fixture.ProbeBackend(Ref(0), :complex))
    @test_throws DimensionMismatch execute(QCircuit(), StateVector(1); shots=4,
        backend=fixture.ProbeBackend(Ref(0), :shape))
end

@testset "Each shot replays intermediate measurements" begin
    inner = QCircuit([HGate(1), QMeasure(1; auto_reset=false)])
    circuit = QCircuit([inner, XGate(1), QMeasure(1; auto_reset=false)])
    initial = StateVector(1)
    before = copy(initial)
    result = execute(circuit, initial; shots=256, rng=MersenneTwister(72))
    @test length(result.measurements) == 256
    first_outcomes = [records[1].outcome for records in result.measurements]
    @test Set(first_outcomes) == Set([0, 1])
    @test all(length(records) == 2 for records in result.measurements)
    @test all(records[2].outcome == 1 - records[1].outcome for records in result.measurements)
    @test result.samples[:, 1] == 1 .- first_outcomes
    @test all(records[1].probability ≈ 0.5 for records in result.measurements)
    @test all(records[2].probability ≈ 1 for records in result.measurements)
    @test result.samples == execute(circuit, initial; shots=256, rng=MersenneTwister(72)).samples
    @test initial == before
    reset_circuit = QCircuit([HGate(1), QMeasure(1; auto_reset=true)])
    reset_result = execute(reset_circuit, initial; shots=256, rng=MersenneTwister(21))
    @test reset_result.counts == Dict("0" => 256)
    @test Set(records[1].outcome for records in reset_result.measurements) == Set([0, 1])
end

@testset "Post-selection consumes attempted shots" begin
    selection = QCircuit([HGate(1), CNOTGate(1, 2),
                          QCircuit([QSelect(1, 1), XGate(2)]),
                          QMeasure(2; auto_reset=false)])
    for initial in (StateVector(2), DensityMatrix(2))
        before = copy(initial)
        result = execute(selection, initial; shots=256, rng=MersenneTwister(83))
        accepted = count(result.accepted)
        @test 0 < accepted < result.shots == 256
        @test size(result.samples) == (accepted, 2)
        @test result.counts == Dict("10" => accepted)
        @test length(result.measurements) == 256
        @test all(result.accepted[i] == (records[1].outcome == 1)
                  for (i, records) in enumerate(result.measurements))
        @test all(length(records) == (result.accepted[i] ? 2 : 1)
                  for (i, records) in enumerate(result.measurements))
        @test all(records[1].kind == :postselection for records in result.measurements)
        @test initial == before
    end
    impossible = execute(QCircuit([QSelect(1, 1)]), StateVector(1); shots=10)
    @test !any(impossible.accepted)
    @test size(impossible.samples) == (0, 1)
    @test isempty(impossible.counts)
end

@testset "Shot boundaries and batches" begin
    @test execute(QCircuit(), StateVector(0); shots=3).counts == Dict("" => 3)
    empty = execute(QCircuit(), StateVector(2); shots=0)
    @test size(empty.samples) == (0, 2)
    @test isempty(empty.measurements)
    @test isempty(empty.accepted)
    @test isempty(empty.counts)
    @test_throws ArgumentError execute(QCircuit(), StateVector(1); shots=-1)
    @test_throws ArgumentError execute(QCircuit(), StateVector(1); shots=true)
    @test_throws ArgumentError execute(QCircuit(), StateVector([2.0, 0]); shots=0)
    @test_throws ArgumentError execute(QCircuit(), StateVector(1); shots=1, qubits=[1, 1])
    @test_throws ArgumentError execute(QCircuit([XGate(2)]), StateVector(1); shots=1)
    @test_throws UnsupportedOperation execute(QCircuit([QMeasure(1; keep=false)]), StateVector(1); shots=1)
    pure = BatchStateVector([onehot_encoding([0]), onehot_encoding([1])])
    for batch in (pure, BatchDensityMatrix(pure))
        results = execute(QCircuit(), batch; shots=4)
        @test length(results) == 2
        @test results[1].counts == Dict("0" => 4)
        @test results[2].counts == Dict("1" => 4)
        @test counts(QCircuit(), batch, 4) == [Dict("0" => 4), Dict("1" => 4)]
    end
    @test isempty(execute(QCircuit(), BatchStateVector(1, 0); shots=2))
    @test_throws ArgumentError execute(QCircuit(), BatchStateVector(1, 0); shots=-1)
end
