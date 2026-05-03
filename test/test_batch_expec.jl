using Test
using MOSS
using LinearAlgebra
using Random

Random.seed!(123)

function random_unitary(n::Int)
    L = 2^n
    m = randn(ComplexF64, L, L)
    return exp(im * (m + m'))
end

@testset "Batch expectation value computations" begin

    @testset "Matrix expectation for batch" begin
        println("Testing matrix expectation for batch...")

        nq = 3
        bs = 5
        batch = rand_batch(ComplexF64, nq, bs)

        # Random Hermitian matrix
        L = 2^nq
        m = randn(ComplexF64, L, L)
        m = m + m'  # Make it Hermitian

        # Batch computation
        batch_results = expectation(m, batch)

        # Loop computation
        loop_results = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results[i] = expectation(m, sv)
        end

        @test length(batch_results) == bs
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        println("✓ Matrix expectation for batch passed")
    end

    @testset "Gate expectation for batch" begin
        println("Testing gate expectation for batch...")

        nq = 4
        bs = 6
        batch = rand_batch(ComplexF64, nq, bs)

        # Test single-qubit gate expectation
        pos = 2  # Apply to qubit 2
        gate = QuantumGate(pos, random_unitary(1))

        batch_results = expectation(gate, batch)
        loop_results = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results[i] = expectation(gate, sv)
        end

        @test length(batch_results) == bs
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        # Test two-qubit gate expectation
        pos = (1, 3)
        gate2 = QuantumGate(pos, random_unitary(2))

        batch_results2 = expectation(gate2, batch)
        loop_results2 = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results2[i] = expectation(gate2, sv)
        end

        @test all(isapprox.(batch_results2, loop_results2, atol=1e-10))

        println("✓ Gate expectation for batch passed")
    end

    @testset "QubitsTerm expectation for batch" begin
        println("Testing QubitsTerm expectation for batch...")

        nq = 3
        bs = 4
        batch = rand_batch(ComplexF64, nq, bs)

        # Single-qubit term
        pos = 2
        mat = random_unitary(1)
        term = QubitsTerm(pos => mat)

        batch_results = expectation(term, batch)
        loop_results = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results[i] = expectation(term, sv)
        end

        @test length(batch_results) == bs
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        # Two-qubit term
        pos1 = 1
        pos2 = 3
        mat1 = random_unitary(1)
        mat2 = random_unitary(1)
        term2 = QubitsTerm(pos1 => mat1, pos2 => mat2)

        batch_results2 = expectation(term2, batch)
        loop_results2 = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results2[i] = expectation(term2, sv)
        end

        @test all(isapprox.(batch_results2, loop_results2, atol=1e-10))

        # Three-qubit term
        if nq >= 3
            pos1 = 1
            pos2 = 2
            pos3 = 3
            mat1 = random_unitary(1)
            mat2 = random_unitary(1)
            mat3 = random_unitary(1)
            term3 = QubitsTerm(pos1 => mat1, pos2 => mat2, pos3 => mat3)

            batch_results3 = expectation(term3, batch)
            loop_results3 = zeros(ComplexF64, bs)
            for i in 1:bs
                sv = StateVector(batch, i)
                loop_results3[i] = expectation(term3, sv)
            end

            @test all(isapprox.(batch_results3, loop_results3, atol=1e-10))
        end

        println("✓ QubitsTerm expectation for batch passed")
    end

    @testset "QubitsOperator expectation for batch" begin
        println("Testing QubitsOperator expectation for batch...")

        nq = 3
        bs = 5
        batch = rand_batch(ComplexF64, nq, bs)

        # Create a simple operator with multiple terms
        op = QubitsOperator()

        # Add single-qubit terms
        for i in 1:nq
            mat = random_unitary(1)
            term = QubitsTerm(i => mat)
            op += term
        end

        # Add a two-qubit term
        # Note: QubitsTerm expects pairs like 1 => matrix, 2 => matrix
        mat1 = random_unitary(1)
        mat2 = random_unitary(1)
        term12 = QubitsTerm(1 => mat1, 2 => mat2)
        op += term12

        batch_results = expectation(op, batch)
        loop_results = zeros(ComplexF64, bs)
        for i in 1:bs
            sv = StateVector(batch, i)
            loop_results[i] = expectation(op, sv)
        end

        @test length(batch_results) == bs
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        println("✓ QubitsOperator expectation for batch passed")
    end

    @testset "Two-state batch expectation" begin
        println("Testing two-state batch expectation...")

        nq = 3
        bs = 4
        batch1 = rand_batch(ComplexF64, nq, bs)
        batch2 = rand_batch(ComplexF64, nq, bs)

        # Test with matrix
        L = 2^nq
        m = randn(ComplexF64, L, L)

        batch_results = expectation(batch1, m, batch2)
        loop_results = zeros(ComplexF64, bs)
        for i in 1:bs
            sv1 = StateVector(batch1, i)
            sv2 = StateVector(batch2, i)
            loop_results[i] = expectation(sv1, m, sv2)
        end

        @test length(batch_results) == bs
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        # Test with single-qubit gate
        pos = 2
        gate = QuantumGate(pos, random_unitary(1))

        batch_results2 = expectation(batch1, gate, batch2)
        loop_results2 = zeros(ComplexF64, bs)
        for i in 1:bs
            sv1 = StateVector(batch1, i)
            sv2 = StateVector(batch2, i)
            loop_results2[i] = expectation(sv1, gate, sv2)
        end

        @test all(isapprox.(batch_results2, loop_results2, atol=1e-10))

        println("✓ Two-state batch expectation passed")
    end


    @testset "Performance comparison" begin
        println("Testing performance comparison...")

        nq = 4
        bs = 100
        batch = rand_batch(ComplexF64, nq, bs)
        mat = random_unitary(1)
        gate = QuantumGate(2, mat)  # Create a gate for expectation calculation

        println("Computing expectation for batch size $bs, nqubits=$nq")

        # Batch version timing
        batch_time = @elapsed begin
            batch_results = expectation(gate, batch)
        end

        # Loop version timing
        loop_time = @elapsed begin
            loop_results = zeros(ComplexF64, bs)
            for i in 1:bs
                sv = StateVector(batch, i)
                loop_results[i] = expectation(gate, sv)
            end
        end

        println("Batch time: $batch_time seconds")
        println("Loop time: $loop_time seconds")
        println("Speedup: $(loop_time/batch_time)x")

        # Verify correctness
        @test all(isapprox.(batch_results, loop_results, atol=1e-10))

        println("✓ Performance comparison completed")
    end

    println("\nAll batch expectation tests passed!")

end