using LinearAlgebra, Random

module BatchDensityExecutionFixtures
using MOSSQuantum, LinearAlgebra
struct MalformedGate{N} <: Gate{N}
    pos::NTuple{N,Int}
    data::Matrix{ComplexF64}
end
MOSSQuantum.mat(gate::MalformedGate) = gate.data
MOSSQuantum.ordered_mat(gate::MalformedGate) = gate.data

# Expand a local matrix directly in the public little-endian qubit convention.
# This reference does not call the execution kernels being checked.
function embedded(data, positions, n)
    result = zeros(eltype(data), 2^n, 2^n)
    for column in 0:2^n-1, localrow in 0:2^length(positions)-1
        localcolumn = sum(((column >> (position - 1)) & 1) << (i - 1)
                          for (i, position) in enumerate(positions))
        row = column
        for (i, position) in enumerate(positions)
            row = (row & ~(1 << (position - 1))) |
                  (((localrow >> (i - 1)) & 1) << (position - 1))
        end
        result[row + 1, column + 1] = data[localrow + 1, localcolumn + 1]
    end
    return result
end
end

@testset "Batch density gates and noisy circuits" begin
    rng = MersenneTwister(840)
    initial = rand_batch_densitymatrix(rng, 3, 3)
    snapshot = copy(initial)
    unitary = Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q)
    gate = QuantumGate((3, 1), unitary)
    full = BatchDensityExecutionFixtures.embedded(unitary, positions(gate), 3)
    output = apply!(gate, copy(initial))
    @test output isa BatchDensityMatrix
    for b in 1:3
        @test storage(output)[:, :, b] ≈ full * storage(initial)[:, :, b] * full'
    end
    @test initial == snapshot
    @test apply!(gate', copy(output)) ≈ initial
    @test tr(output) ≈ ones(3)
    @test apply!(CPUBackend(), gate, copy(initial)) ≈ output

    real = BatchDensityMatrix(Float32, 1, 2)
    promoted = apply!(RyGate(1, 0.3), real)
    @test eltype(promoted) == Float32
    @test eltype(real) == Float32
    @test promoted === real
    complex = apply!(YGate(1), copy(real))
    @test eltype(complex) == ComplexF32
    expected_complex = ComplexF32.(mat(YGate(1))) * storage(real)[:, :, 1] * ComplexF32.(mat(YGate(1)))'
    @test storage(complex)[:, :, 1] ≈ expected_complex
    @test eltype(apply!(RyGate(1, 0.3), BatchDensityMatrix(Int, 1, 2))) == Float64
    lowprecision = rand_batch_densitymatrix(MersenneTwister(23), ComplexF32, 2, 3)
    lowprecision = QCircuit([RyGate(1, 0.3), RzGate(2, 0.6),
                            Depolarizing(1; p=0.15), AmplitudeDamping(2; γ=0.25)]) * lowprecision
    @test eltype(lowprecision) == ComplexF32
    @test tr(lowprecision) ≈ ones(Float32, 3)
    @test size(probabilities(lowprecision)) == (4, 3)
    @test sum(probabilities(lowprecision); dims=1) ≈ ones(Float32, 1, 3)
    @test apply!(XGate(1), BatchDensityMatrix(ComplexF64, 1, 2)) isa BatchDensityMatrix{ComplexF64}

    kraus = [sqrt(0.7) * Matrix{ComplexF64}(I, 4, 4), sqrt(0.3) * unitary]
    channel = QuantumMap((3, 1), kraus)
    fullkraus = [BatchDensityExecutionFixtures.embedded(k, positions(channel), 3) for k in kraus]
    noisy = apply!(channel, copy(initial))
    @test noisy isa BatchDensityMatrix
    for b in 1:3
        expected = sum(k * storage(initial)[:, :, b] * k' for k in fullkraus)
        @test storage(noisy)[:, :, b] ≈ expected
    end
    @test tr(noisy) ≈ ones(3)
    @test apply!(CPUBackend(), channel, copy(initial)) ≈ noisy
    cotangent = rand_batch_densitymatrix(rng, 3, 3)
    dual = MOSSQuantum.apply_dagger!(channel, copy(cotangent))
    @test dot(cotangent, noisy) ≈ dot(dual, initial)
    for b in 1:3
        @test storage(dual)[:, :, b] ≈ sum(k' * storage(cotangent)[:, :, b] * k for k in fullkraus)
    end

    pure = rand_batch(rng, 3, 3)
    puresnapshot = copy(pure)
    @test apply!(channel, pure) ≈ apply!(channel, BatchDensityMatrix(pure))
    @test pure == puresnapshot
    circuit = QCircuit([HGate(2), QCircuit([channel, RzGate(1, 0.3)]),
                        AmplitudeDamping(2; γ=0.2)])
    @test supports(CPUBackend(), circuit, pure)
    @test supports(CPUBackend(), circuit, initial)
    result = circuit * initial
    pure_result = circuit * pure
    @test pure_result isa BatchDensityMatrix
    for b in 1:3
        @test DensityMatrix(result, b) ≈ circuit * DensityMatrix(initial, b)
        @test DensityMatrix(pure_result, b) ≈ circuit * StateVector(pure, b)
    end
    @test initial == snapshot
    @test pure == puresnapshot
    @test apply!(CPUBackend(), circuit, copy(pure)) ≈ pure_result
    @test tr(pure_result) ≈ ones(3)

    for B in (0, 1)
        empty_or_single = BatchDensityMatrix(3, B)
        @test size(storage(apply!(gate, copy(empty_or_single)))) == (8, 8, B)
        @test size(storage(apply!(channel, copy(empty_or_single)))) == (8, 8, B)
        @test size(storage(apply!(channel, BatchStateVector(3, B)))) == (8, 8, B)
        @test size(storage(circuit * empty_or_single)) == (8, 8, B)
    end
    @test QCircuit() * BatchDensityMatrix(0, 2) == BatchDensityMatrix(0, 2)
end

@testset "Batch density gates through native five-qubit limit" begin
    rng = MersenneTwister(384)
    initial = rand_batch_densitymatrix(rng, 5, 1)
    for register in ((5, 3, 1), (5, 2, 4, 1), (5, 1, 4, 2, 3))
        localdimension = 2^length(register)
        unitary = Matrix(qr(randn(rng, ComplexF64, localdimension, localdimension)).Q)
        operation = QuantumGate(register, unitary)
        full = BatchDensityExecutionFixtures.embedded(unitary, register, 5)
        result = apply!(operation, copy(initial))
        @test storage(result)[:, :, 1] ≈ full * storage(initial)[:, :, 1] * full'
        @test apply!(operation', result) ≈ initial
    end
end

@testset "Batch density native execution preflight" begin
    fixture = BatchDensityExecutionFixtures
    for B in (0, 2)
        initial = BatchDensityMatrix(2, B)
        snapshot = copy(initial)
        @test_throws ArgumentError apply!(XGate(3), initial)
        @test_throws ArgumentError apply!(fixture.MalformedGate{2}((1, 1), Matrix{ComplexF64}(I, 4, 4)), initial)
        @test_throws DimensionMismatch apply!(fixture.MalformedGate{1}((1,), ones(3, 3)), initial)
        invalid = fixture.MalformedGate{1}((1,), ComplexF64[1 NaN; 0 1])
        @test_throws ArgumentError apply!(invalid, initial)
        @test initial == snapshot
        @test_throws UnsupportedOperation apply!(fixture.MalformedGate{6}((1, 2, 3, 4, 5, 6), ones(64, 64)), initial)
        channel = AmplitudeDamping(3; γ=0.2)
        @test_throws ArgumentError apply!(channel, initial)
        badkraus = QuantumMap(1, [Matrix{ComplexF64}(I, 2, 2)])
        kraus_matrices(badkraus)[1][1, 1] = NaN
        @test_throws ArgumentError apply!(badkraus, initial)
        badsuper = QuantumMap(1, [Matrix{ComplexF64}(I, 2, 2)])
        ordered_supermat(badsuper)[1, 1] = Inf
        @test_throws ArgumentError apply!(badsuper, initial)
        @test initial == snapshot
        duplicate = QuantumMap{2,Float64}((1, 1), [Matrix{Float64}(I, 4, 4)],
                                         (1, 1), Matrix{Float64}(I, 16, 16))
        @test_throws ArgumentError apply!(duplicate, initial)
        malformed = QuantumMap{1,Float64}((1,), [ones(3, 3)], (1,), Matrix{Float64}(I, 4, 4))
        @test_throws DimensionMismatch apply!(malformed, initial)
        malformed_super = QuantumMap{1,Float64}((1,), [Matrix{Float64}(I, 2, 2)], (1,), ones(3, 3))
        @test_throws DimensionMismatch apply!(malformed_super, initial)
        @test initial == snapshot
        @test_throws UnsupportedOperation apply!(QuantumMap((1, 2, 3), [Matrix{Float64}(I, 8, 8)]), initial)
    end
end
