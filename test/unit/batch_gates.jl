using Test
using MOSSQuantum

@testset "BatchStateVector gate application" begin
    # Test single-qubit gate on batch
    batch = BatchStateVector(2, 3)  # 2 qubits, batch size 3

    # Apply X gate to qubit 1
    x_gate = QuantumGate(1, [0 1; 1 0])
    apply!(x_gate, batch)

    # Check that each state is now |01⟩ (X on qubit 1, the LSB)
    for i in 1:3
        @test isapprox(storage(batch)[1, i], 0.0 + 0.0im)  # |00⟩ amplitude
        @test isapprox(storage(batch)[2, i], 1.0 + 0.0im)  # |01⟩ amplitude (qubit 1 flipped)
    end

    # Reset batch
    reset!(batch)

    # Test Hadamard gate
    h_gate = QuantumGate(1, [1 1; 1 -1]/√2)
    apply!(h_gate, batch)

    # Check H|0⟩ = (|0⟩ + |1⟩)/√2
    # For 2 qubits, H on qubit 1 (LSB): |00⟩ → (|00⟩ + |01⟩)/√2
    # Index mapping: 1=|00⟩, 2=|01⟩, 3=|10⟩, 4=|11⟩
    for i in 1:3
        @test isapprox(storage(batch)[1, i], 1/√2 + 0.0im)  # |00⟩ amplitude
        @test isapprox(storage(batch)[2, i], 1/√2 + 0.0im)  # |01⟩ amplitude
        @test isapprox(storage(batch)[3, i], 0.0 + 0.0im)   # |10⟩ amplitude
        @test isapprox(storage(batch)[4, i], 0.0 + 0.0im)   # |11⟩ amplitude
    end

    # Test CNOT gate
    batch2 = BatchStateVector(2, 2)
    # Prepare |10⟩ state in first batch element
    storage(batch2)[3, 1] = 1.0 + 0.0im
    storage(batch2)[1, 1] = 0.0 + 0.0im
    # Prepare |11⟩ state in second batch element
    storage(batch2)[4, 2] = 1.0 + 0.0im
    storage(batch2)[1, 2] = 0.0 + 0.0im

    cnot_gate = QuantumGate((1, 2), [1 0 0 0; 0 1 0 0; 0 0 0 1; 0 0 1 0])
    apply!(cnot_gate, batch2)

    # |10⟩ should become |11⟩ after CNOT
    @test isapprox(storage(batch2)[4, 1], 1.0 + 0.0im)
    # |11⟩ should become |10⟩ after CNOT
    @test isapprox(storage(batch2)[3, 2], 1.0 + 0.0im)
end

@testset "BatchStateVector circuit application" begin
    # Create a simple circuit
    h_gate = QuantumGate(1, [1 1; 1 -1]/√2)
    cnot_gate = QuantumGate((1, 2), [1 0 0 0; 0 1 0 0; 0 0 0 1; 0 0 1 0])
    circuit = QCircuit([h_gate, cnot_gate])

    # Create batch of |00⟩ states
    batch = BatchStateVector(2, 4)

    # Apply circuit
    apply!(circuit, batch)

    # Check that each state is now (|00⟩ + |01⟩)/√2
    # Note: CNOT(1,2) has control=qubit2, target=qubit1 based on current implementation
    for i in 1:4
        @test isapprox(storage(batch)[1, i], 1/√2 + 0.0im)  # |00⟩ amplitude
        @test isapprox(storage(batch)[2, i], 1/√2 + 0.0im)  # |01⟩ amplitude
        @test isapprox(storage(batch)[3, i], 0.0 + 0.0im)   # |10⟩ amplitude
        @test isapprox(storage(batch)[4, i], 0.0 + 0.0im)   # |11⟩ amplitude
    end
end

function random_unitary(n::Int)
    L = 2^n
    m = randn(ComplexF64, L, L)
    return exp(im * (m + m'))
end

@testset "BatchStateVector comparison with single states" begin
    # Test that applying gate to batch gives same result as applying to each state individually
    nq = 3
    bs = 5

    # Create random batch
    batch = rand_batch(nq, bs)
    batch_copy = copy(batch)

    # Create individual states from batch
    single_states = [StateVector(batch_copy, i) for i in 1:bs]

    # Apply random single-qubit gate to qubit 2
    gate = QuantumGate(2, random_unitary(1))

    # Apply to batch
    apply!(gate, batch)

    # Apply to each single state
    for i in 1:bs
        apply!(gate, single_states[i])
    end

    # Compare results
    for i in 1:bs
        sv_from_batch = StateVector(batch, i)
        @test isapprox(sv_from_batch, single_states[i], atol=1e-10)
    end

    # Test with two-qubit gate
    batch2 = rand_batch(3, 3)
    batch2_copy = copy(batch2)

    single_states2 = [StateVector(batch2_copy, i) for i in 1:3]

    two_qubit_gate = QuantumGate((1, 3), random_unitary(2))
    apply!(two_qubit_gate, batch2)

    for i in 1:3
        apply!(two_qubit_gate, single_states2[i])
        sv_from_batch2 = StateVector(batch2, i)
        @test isapprox(sv_from_batch2, single_states2[i], atol=1e-10)
    end
end