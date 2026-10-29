using Test
using MOSSQuantum

@testset "BatchStateVector basic construction" begin
    # Test basic constructor
    batch = BatchStateVector(3, 4)  # 3 qubits, batch size 4
    @test nqubits(batch) == 3
    @test batch_size(batch) == 4
    @test size(storage(batch)) == (8, 4)
    @test eltype(batch) == ComplexF64

    # Test that all states are |000⟩
    for i in 1:4
        @test storage(batch)[1, i] == 1.0 + 0.0im
        for j in 2:8
            @test storage(batch)[j, i] == 0.0 + 0.0im
        end
    end

    # Test with specific data
    data = randn(ComplexF64, 8, 5)
    batch2 = BatchStateVector(data, 3, 5)
    @test nqubits(batch2) == 3
    @test batch_size(batch2) == 5
    @test storage(batch2) == data

    # Test automatic batch size detection
    batch3 = BatchStateVector(data, 3)
    @test batch_size(batch3) == 5
    @test storage(batch3) == data

    # Test automatic nqubits detection
    batch4 = BatchStateVector(data)
    @test nqubits(batch4) == 3
    @test batch_size(batch4) == 5
end

@testset "BatchStateVector conversion functions" begin
    # Single StateVector to BatchStateVector
    sv = StateVector(3)
    batch = BatchStateVector(sv)
    @test nqubits(batch) == 3
    @test batch_size(batch) == 1
    @test storage(batch)[:, 1] == storage(sv)

    # Extract StateVector from batch
    sv2 = StateVector(batch, 1)
    @test isapprox(sv, sv2)

    # Vector of StateVectors to BatchStateVector
    svs = [StateVector(2) for _ in 1:3]
    batch2 = BatchStateVector(svs)
    @test nqubits(batch2) == 2
    @test batch_size(batch2) == 3
    for i in 1:3
        @test storage(batch2)[:, i] == storage(svs[i])
    end

    # Type conversion
    batch_cf32 = BatchStateVector(ComplexF32, 2, 3)
    @test eltype(batch_cf32) == ComplexF32
    batch_cf64 = convert(BatchStateVector{ComplexF64}, batch_cf32)
    @test eltype(batch_cf64) == ComplexF64
end

@testset "BatchStateVector basic operations" begin
    batch1 = BatchStateVector(2, 3)
    batch2 = copy(batch1)

    # Test copy
    @test batch1 == batch2
    storage(batch2)[1, 1] = 0.5
    @test batch1 != batch2

    # Test getindex and setindex
    batch = BatchStateVector(2, 2)
    @test batch[1, 1] == 1.0 + 0.0im
    batch[2, 1] = 0.5 + 0.5im
    @test batch[2, 1] == 0.5 + 0.5im

    # Test arithmetic operations
    data1 = randn(ComplexF64, 4, 3)
    data2 = randn(ComplexF64, 4, 3)
    b1 = BatchStateVector(data1, 2, 3)
    b2 = BatchStateVector(data2, 2, 3)

    b_sum = b1 + b2
    @test isapprox(storage(b_sum), data1 + data2)

    b_diff = b1 - b2
    @test isapprox(storage(b_diff), data1 - data2)

    b_scaled = b1 * 2.0
    @test isapprox(storage(b_scaled), data1 * 2.0)

    b_scaled2 = 2.0 * b1
    @test isapprox(storage(b_scaled2), data1 * 2.0)

    b_div = b1 / 2.0
    @test isapprox(storage(b_div), data1 / 2.0)
end

@testset "BatchStateVector linear algebra" begin
    # Create a batch with normalized states
    data = randn(ComplexF64, 8, 4)
    for i in 1:4
        col = view(data, :, i)
        col ./= norm(col)
    end
    batch = BatchStateVector(data, 3, 4)

    # Test norm
    norms = norm(batch)
    @test length(norms) == 4
    for i in 1:4
        @test isapprox(norms[i], 1.0, atol=1e-10)
    end

    # Test normalize!
    data2 = randn(ComplexF64, 8, 3)
    batch2 = BatchStateVector(data2, 3, 3)
    batch2_norm = normalize!(copy(batch2))
    norms2 = norm(batch2_norm)
    for n in norms2
        @test isapprox(n, 1.0, atol=1e-10)
    end

    # Test dot product
    data3 = randn(ComplexF64, 8, 3)
    data4 = randn(ComplexF64, 8, 3)
    b3 = BatchStateVector(data3, 3, 3)
    b4 = BatchStateVector(data4, 3, 3)

    dots = dot(b3, b4)
    @test length(dots) == 3
    for i in 1:3
        @test isapprox(dots[i], dot(view(data3, :, i), view(data4, :, i)))
    end

    # Test dot with weights
    weights = randn(3)
    dots_weighted = dot(b3, weights, b4)
    for i in 1:3
        expected = dot(view(data3, :, i), weights[i], view(data4, :, i))
        @test isapprox(dots_weighted[i], expected)
    end
end

@testset "BatchStateVector encoding functions" begin
    # Test batch_onehot_encoding with batch size
    batch1 = batch_onehot_encoding(2, 3)  # 2 qubits, batch size 3
    @test nqubits(batch1) == 2
    @test batch_size(batch1) == 3
    for i in 1:3
        @test storage(batch1)[1, i] == 1.0 + 0.0im
        for j in 2:4
            @test storage(batch1)[j, i] == 0.0 + 0.0im
        end
    end

    # Test batch_onehot_encoding with indices
    indices = [[0, 0], [1, 0], [0, 1]]
    batch2 = batch_onehot_encoding(indices)
    @test nqubits(batch2) == 2
    @test batch_size(batch2) == 3
    @test storage(batch2)[1, 1] == 1.0 + 0.0im  # |00⟩
    @test storage(batch2)[2, 2] == 1.0 + 0.0im  # |01⟩ for [1,0]
    @test storage(batch2)[3, 3] == 1.0 + 0.0im  # |10⟩ for [0,1]

    # Test batch_qubit_encoding
    inputs = [0.0 0.5 1.0; 0.5 1.0 0.0]  # 2 qubits, 3 states
    batch3 = batch_qubit_encoding(inputs)
    @test nqubits(batch3) == 2
    @test batch_size(batch3) == 3
    for i in 1:3
        sv = qubit_encoding(inputs[:, i])
        @test isapprox(storage(batch3)[:, i], storage(sv))
    end

    # Test batch_amplitude_encoding
    amp_inputs = randn(4, 2)  # 4-dimensional vectors, batch size 2
    batch4 = batch_amplitude_encoding(amp_inputs, nqubits=2)
    @test nqubits(batch4) == 2
    @test batch_size(batch4) == 2
    for i in 1:2
        sv = amplitude_encoding(amp_inputs[:, i], nqubits=2)
        @test isapprox(storage(batch4)[:, i], storage(sv), atol=1e-10)
    end
end

@testset "BatchStateVector reset functions" begin
    batch = rand_batch(2, 3)

    # Test reset!
    batch_reset = copy(batch)
    reset!(batch_reset)
    for i in 1:3
        @test storage(batch_reset)[1, i] == 1.0 + 0.0im
        for j in 2:4
            @test storage(batch_reset)[j, i] == 0.0 + 0.0im
        end
    end

    # Test reset_onehot!
    batch2 = BatchStateVector(2, 2)
    indices = [[1, 0], [0, 1]]
    reset_onehot!(batch2, indices)
    @test storage(batch2)[2, 1] == 1.0 + 0.0im  # |01⟩ for [1,0]
    @test storage(batch2)[3, 2] == 1.0 + 0.0im  # |10⟩ for [0,1]

    # Test reset_qubit!
    batch3 = BatchStateVector(2, 2)
    inputs = [0.5 0.0; 0.0 1.0]
    reset_qubit!(batch3, inputs)
    for i in 1:2
        sv = qubit_encoding(inputs[:, i])
        @test isapprox(storage(batch3)[:, i], storage(sv))
    end
end

@testset "BatchStateVector random generation" begin
    batch = rand_batch(3, 5)
    @test nqubits(batch) == 3
    @test batch_size(batch) == 5

    # Check each state is normalized
    norms = norm(batch)
    for n in norms
        @test isapprox(n, 1.0, atol=1e-10)
    end

    # Check randomness (very basic)
    batch2 = rand_batch(3, 5)
    @test batch != batch2  # Very unlikely to be equal
end

@testset "BatchStateVector comparison and approximation" begin
    batch1 = BatchStateVector(2, 3)
    batch2 = BatchStateVector(2, 3)
    @test batch1 == batch2
    @test isapprox(batch1, batch2)

    batch3 = BatchStateVector(2, 2)
    @test batch1 != batch3  # Different batch size

    # Test with tolerance
    data1 = randn(ComplexF64, 4, 3)
    data2 = data1 .+ 1e-12 .* randn(ComplexF64, 4, 3)
    b1 = BatchStateVector(data1, 2, 3)
    b2 = BatchStateVector(data2, 2, 3)
    @test !(b1 == b2)
    @test isapprox(b1, b2, atol=1e-10)
end