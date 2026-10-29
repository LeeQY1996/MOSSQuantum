using Test, Random, MOSSQuantum

@testset "Finite-shot circuit expectations" begin
    z = QubitsTerm(1 => "Z")
    initial = StateVector(1)
    rotation = QCircuit([RyGate(1, 0.4)])
    prepared = rotation * initial
    from_state = estimate(z, prepared; shots=1000, rng=MersenneTwister(61))
    from_circuit = estimate(z, rotation, initial; shots=1000, rng=MersenneTwister(61))
    @test from_circuit.value == from_state.value
    @test from_circuit.variance == from_state.variance
    @test initial == StateVector(1)
    noisy = QCircuit([XGate(1), AmplitudeDamping(1; γ=1)])
    @test estimate(z, noisy, initial; shots=17).value == 1

    # The last Z measurement must average over independent intermediate
    # measurements, rather than sample one already collapsed trajectory.
    measured = QCircuit([HGate(1), QMeasure(1; auto_reset=false)])
    result = estimate(z, measured, initial; shots=1024, rng=MersenneTwister(62))
    shots = execute(measured, initial; shots=1024, rng=MersenneTwister(62))
    energies = 1 .- 2 .* shots.samples[:, 1]
    mean = sum(energies) / length(energies)
    variance = sum(abs2(value - mean) for value in energies) / (length(energies) - 1)
    @test result.value ≈ mean
    @test result.variance ≈ variance / 1024
    @test -1 < result.value < 1
    @test result.stderr > 0
    @test result.shots == 1024
    @test estimate(z, QCircuit([HGate(1), QMeasure(1)]), initial; shots=17).value == 1

    mixed = DensityMatrix(ComplexF64[0.5 0; 0 0.5])
    result = estimate(z, measured, mixed; shots=1024, rng=MersenneTwister(63))
    @test abs(result.value) < 0.12
    @test result.variance > 0
    @test_throws ArgumentError estimate(z, QCircuit([QSelect(1, 0)]), initial; shots=10)
    @test_throws ArgumentError estimate(z, QCircuit([XGate(2)]), initial; shots=10)
    constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 3.0)
    @test estimate(constant, measured, initial; shots=0).value == 3
    @test estimate(constant, measured, initial; shots=0).shots == 0
    @test_throws ArgumentError estimate(constant, measured, 2 * initial; shots=0)

    batch = BatchStateVector([onehot_encoding([0]), onehot_encoding([1])])
    for inputs in (batch, BatchDensityMatrix(batch))
        values = estimate(z, QCircuit([XGate(1)]), inputs; shots=11)
        @test getproperty.(values, :value) == [-1, 1]
        @test getproperty.(values, :shots) == [11, 11]
    end
    @test isempty(estimate(z, QCircuit(), BatchStateVector(1, 0); shots=2))
    @test_throws ArgumentError estimate(z, QCircuit(), BatchStateVector(1, 0); shots=1)
end
