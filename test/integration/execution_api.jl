using Test
using LinearAlgebra
using Random
using MOSS

@testset "Explicit RNG initialization" begin
    @test rand_state(MersenneTwister(42), 3) == rand_state(MersenneTwister(42), 3)
    @test rand_state(MersenneTwister(42), Float64, 3) == rand_state(MersenneTwister(42), Float64, 3)
    @test rand_densitymatrix(MersenneTwister(42), 2) == rand_densitymatrix(MersenneTwister(42), 2)
    @test rand_batch(MersenneTwister(42), 2, 3) == rand_batch(MersenneTwister(42), 2, 3)
end

@testset "Readout tolerates accumulated floating-point drift" begin
    state = StateVector(ComplexF64[sqrt(1 + 1e-12), 0])
    @test probabilities(state) == [1, 0]
    @test measure!(copy(state), 1; rng=MersenneTwister(42)) == (0, 1.0)
    reduced, outcome, probability = measure(state, 1; rng=MersenneTwister(42))
    @test outcome == 0
    @test probability == 1
    @test norm(reduced) ≈ 1
end

@testset "Terminal readout API" begin
    bell = StateVector(ComplexF64[1, 0, 0, 1] / sqrt(2))
    rho = DensityMatrix(bell)
    original_bell, original_rho = copy(bell), copy(rho)

    @testset "Born probabilities and requested qubit order" begin
        @test probabilities(bell) ≈ [0.5, 0.0, 0.0, 0.5]
        @test probabilities(rho) ≈ probabilities(bell)
        @test probabilities(bell; qubits=[1]) ≈ [0.5, 0.5]
        @test probabilities(rho; qubits=[2]) ≈ [0.5, 0.5]

        asymmetric = StateVector(sqrt.([0.1, 0.2, 0.3, 0.4]))
        @test probabilities(asymmetric) ≈ [0.1, 0.2, 0.3, 0.4]
        @test probabilities(asymmetric; qubits=[1]) ≈ [0.4, 0.6]
        @test probabilities(asymmetric; qubits=[2]) ≈ [0.3, 0.7]
        @test probabilities(asymmetric; qubits=[2, 1]) ≈ [0.1, 0.3, 0.2, 0.4]
        @test probabilities(DensityMatrix(asymmetric); qubits=[2, 1]) ≈ [0.1, 0.3, 0.2, 0.4]
        @test probabilities(bell; qubits=Int[]) ≈ [1.0]
    end

    @testset "Seeded sampling and counts" begin
        draws = sample(MersenneTwister(91), bell, 64)
        @test size(draws) == (64, 2)
        @test draws[:, 1] == draws[:, 2]
        @test all(bit -> bit in (0, 1), draws)
        @test draws == sample(MersenneTwister(91), bell, 64)
        @test draws == sample(bell, 64; rng=MersenneTwister(91))
        @test draws == sample(MersenneTwister(91), rho, 64)
        expected_counts = Dict("00" => count(==(0), draws[:, 1]),
            "11" => count(==(1), draws[:, 1]))
        @test counts(MersenneTwister(91), bell, 64) == expected_counts
        @test counts(bell, 64; rng=MersenneTwister(91)) == expected_counts
        @test counts(MersenneTwister(91), rho, 64) == expected_counts
        @test sum(values(expected_counts)) == 64

        basis = onehot_encoding([1, 0])
        @test sample(MersenneTwister(4), basis, 3) == [1 0; 1 0; 1 0]
        @test sample(MersenneTwister(4), basis, 3; qubits=[2, 1]) == [0 1; 0 1; 0 1]
        @test counts(MersenneTwister(4), basis, 3) == Dict("10" => 3)
        @test counts(MersenneTwister(4), basis, 3; qubits=[2, 1]) == Dict("01" => 3)
        @test size(sample(MersenneTwister(4), bell, 0)) == (0, 2)
        @test isempty(counts(MersenneTwister(4), bell, 0))
        @test size(sample(MersenneTwister(4), bell, 3; qubits=Int[])) == (3, 0)
        @test counts(MersenneTwister(4), bell, 3; qubits=Int[]) == Dict("" => 3)
        @test bell == original_bell
        @test rho == original_rho
    end

    @testset "Validation" begin
        for qubits in ([0], [3], [1, 1])
            @test_throws ArgumentError probabilities(bell; qubits=qubits)
            @test_throws ArgumentError sample(MersenneTwister(1), bell, 2; qubits=qubits)
        end
        @test_throws ArgumentError sample(MersenneTwister(1), bell, -1)
        @test_throws ArgumentError counts(MersenneTwister(1), bell, -1)
        @test_throws ArgumentError probabilities(StateVector([2.0, 0.0]))
        @test_throws ArgumentError sample(MersenneTwister(1), StateVector([2.0, 0.0]), 0)
        @test_throws ArgumentError probabilities(DensityMatrix([0.8 0.0; 0.0 0.8]))
        @test_throws ArgumentError probabilities(DensityMatrix(ComplexF64[0.5im 0; 0 1]))
        @test_throws DomainError probabilities(DensityMatrix([1.1 0.0; 0.0 -0.1]))
    end

    @testset "Batch dimensions and column distributions" begin
        basis = onehot_encoding([1, 0])
        batch = BatchStateVector(hcat(storage(bell), storage(basis)), 2)
        original = copy(batch)
        @test size(probabilities(batch)) == (4, 2)
        @test probabilities(batch)[:, 1] ≈ probabilities(bell)
        @test probabilities(batch)[:, 2] ≈ [0.0, 1.0, 0.0, 0.0]
        @test probabilities(batch; qubits=[2, 1])[:, 2] ≈ [0.0, 0.0, 1.0, 0.0]
        @test size(probabilities(batch; qubits=[2])) == (2, 2)
        draws = sample(MersenneTwister(11), batch, 16)
        @test size(draws) == (16, 2, 2)
        @test draws[:, 1, 1] == draws[:, 2, 1]
        @test draws[:, 1, 2] == ones(Int, 16)
        @test draws[:, 2, 2] == zeros(Int, 16)
        @test draws == sample(MersenneTwister(11), batch, 16)
        histograms = counts(MersenneTwister(11), batch, 16)
        @test length(histograms) == 2
        @test sum(values(histograms[1])) == 16
        @test histograms[2] == Dict("10" => 16)
        @test size(sample(MersenneTwister(11), batch, 0)) == (0, 2, 2)
        @test all(isempty, counts(MersenneTwister(11), batch, 0))
        @test storage(batch) == storage(original)
        invalid = BatchStateVector(hcat(storage(bell), 2storage(basis)), 2)
        @test_throws ArgumentError probabilities(invalid)
    end
end

@testset "Single-trajectory simulation results" begin
    @testset "Nested measurement records and RNG" begin
        circuit = QCircuit([HGate(1), CNOTGate(1, 2),
            QCircuit([QMeasure(1; auto_reset=false), QMeasure(2; auto_reset=false)])])
        initial = StateVector(2)
        result = simulate(circuit, initial; rng=MersenneTwister(73))
        repeated = simulate(circuit, initial; rng=MersenneTwister(73))
        @test result isa SimulationResult
        @test result.state !== initial
        @test initial == StateVector(2)
        @test length(result.measurements) == 2
        first, second = result.measurements
        @test first isa MeasurementRecord
        @test first.position == 1
        @test second.position == 2
        @test first.kind === :measurement
        @test second.kind === :measurement
        @test first.outcome == second.outcome
        @test first.probability ≈ 0.5
        @test second.probability ≈ 1.0
        @test result.state ≈ onehot_encoding([first.outcome, second.outcome])
        @test repeated.state ≈ result.state
        @test getproperty.(repeated.measurements, :outcome) == getproperty.(result.measurements, :outcome)

        mixed = simulate(circuit, DensityMatrix(initial); rng=MersenneTwister(73))
        @test mixed.state ≈ DensityMatrix(result.state)
        @test getproperty.(mixed.measurements, :outcome) == getproperty.(result.measurements, :outcome)
    end

    @testset "Post-selection, reset metadata, and type promotion" begin
        selected = simulate(QCircuit([HGate(1), QCircuit([QSelect(1, 1)]),
            QMeasure(1; auto_reset=false)]), StateVector(1); rng=MersenneTwister(3))
        @test selected.state ≈ onehot_encoding([1])
        @test length(selected.measurements) == 2
        @test selected.measurements[1].kind === :postselection
        @test selected.measurements[1].outcome == 1
        @test selected.measurements[1].probability ≈ 0.5
        @test selected.measurements[2].kind === :measurement
        @test selected.measurements[2].outcome == 1
        @test selected.measurements[2].probability ≈ 1

        reset = simulate(QCircuit([XGate(1), QMeasure(1)]), StateVector(1); rng=MersenneTwister(3))
        @test reset.measurements[1].outcome == 1
        @test reset.state ≈ onehot_encoding([0])

        real_initial = StateVector(Float64[1, 0])
        promoted = simulate(QCircuit([HGate(1), TGate(1)]), real_initial)
        @test eltype(promoted.state) <: Complex
        @test promoted.state ≈ StateVector(ComplexF64[1, cis(pi / 4)] / sqrt(2))
        @test storage(real_initial) == [1, 0]
        @test isempty(promoted.measurements)

        noisy = simulate(QCircuit([XGate(1), AmplitudeDamping(1; γ=0.25)]), real_initial)
        @test noisy.state isa DensityMatrix
        @test storage(noisy.state) ≈ [0.25 0.0; 0.0 0.75]
        @test storage(real_initial) == [1, 0]
        @test isempty(noisy.measurements)
    end
end
