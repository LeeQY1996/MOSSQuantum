using Test, MOSS, Random, LinearAlgebra

module BatchContractFixtures
import MOSS
struct MalformedGate <: MOSS.Gate{1} end
MOSS.positions(::MalformedGate) = (1,)
MOSS.mat(::MalformedGate) = ones(3, 3)
end

@testset "Pure-state batch shape, ownership, and input contracts" begin
    data = [1.0 0.0; 0.0 1.0]
    single = StateVector(data[:, 1])
    one = BatchStateVector(single)
    @test single isa StateVector
    @test one isa BatchStateVector
    @test size(storage(one)) == (2, 1)
    @test expectation(QubitsTerm(1 => "Z"), one) == [1.0]
    for make in (x -> BatchStateVector{Float32}(x), x -> BatchStateVector{Float32}(x, 1))
        batch = make(data)
        @test size(storage(batch)) == (2, 2)
        @test eltype(batch) == Float32
        @test storage(batch) == data
        @test !Base.mightalias(storage(batch), data)
    end
    mixed_types = [StateVector([1.0, 0.0]), StateVector(ComplexF64[0, im])]
    joined = BatchStateVector(mixed_types)
    @test eltype(joined) == ComplexF64
    @test storage(joined) == ComplexF64[1 0; 0 im]
    storage(mixed_types[1])[1] = 3
    @test storage(joined)[1, 1] == 1

    @test_throws ArgumentError BatchStateVector(-1, 2)
    @test_throws ArgumentError BatchStateVector(2, -1)
    @test_throws ArgumentError BatchStateVector(zeros(0, 2))
    @test_throws ArgumentError BatchStateVector(zeros(3, 2))
    @test_throws DimensionMismatch BatchStateVector(zeros(4, 2), 1, 2)
    @test_throws DimensionMismatch BatchStateVector(zeros(2, 2), 1, 3)
    @test_throws ArgumentError BatchStateVector(StateVector[])
    @test_throws DimensionMismatch BatchStateVector([StateVector(1), StateVector(2)])
    @test_throws BoundsError StateVector(one, 0)
    @test_throws BoundsError StateVector(one, 2)

    empty = BatchStateVector(2, 0)
    @test size(storage(empty)) == (4, 0)
    @test isempty(norm(empty))
    @test normalize!(empty) === empty
    @test isempty(dot(empty, empty))
    @test isempty(fidelity(empty, empty))
    @test isempty(expectation(QubitsTerm(1 => "Z"), empty))
    @test permute(empty, [2, 1]) == empty
    @test_throws ArgumentError permute(empty, [1, 1])
    @test_throws ArgumentError permute(empty, [1])
    zero_register = BatchStateVector(0, 3)
    @test storage(zero_register) == ones(1, 3)
    @test amplitude(zero_register, Int[], 2) == 1
    @test permute(zero_register, Int[]) == zero_register
    @test size(storage(rand_batch(MersenneTwister(17), 0, 2))) == (1, 2)
    @test norm(rand_batch(MersenneTwister(17), 0, 2)) ≈ ones(2)

    for invalid in ([2.0 0.0; 0.0 0.0], [2.0 NaN; 0.0 0.0], [2.0 Inf; 0.0 0.0])
        batch = BatchStateVector(copy(invalid))
        before = copy(storage(batch))
        @test_throws ArgumentError normalize!(batch)
        @test isequal(storage(batch), before)
    end
    left, wrong_register, wrong_count = BatchStateVector(1, 2), BatchStateVector(2, 2), BatchStateVector(1, 3)
    for right in (wrong_register, wrong_count), operation in (+, -, dot, fidelity, distance)
        @test_throws DimensionMismatch operation(left, right)
    end
    @test_throws DimensionMismatch dot(left, [1.0], left)
    @test_throws DimensionMismatch ones(3, 2) * left

    inputs = [0.2 0.3; -0.4 0.1]
    @test batch_qubit_encoding(view(inputs, :, :)) ≈ batch_qubit_encoding(inputs)
    @test size(storage(batch_qubit_encoding(zeros(0, 3)))) == (1, 3)
    @test storage(batch_onehot_encoding([Int[], Int[]])) == ones(1, 2)
    @test reset_onehot!(empty, Vector{Int}[]) === empty
    @test reset_qubit!(zero_register, zeros(0, 3)) === zero_register
    basis = BatchStateVector(1, 2)
    before = copy(basis)
    @test_throws ArgumentError reset_onehot!(basis, [[0], [2]])
    @test basis == before
    @test_throws DimensionMismatch reset_onehot!(basis, [[0], [0, 1]])
    @test basis == before
    @test_throws ArgumentError reset_qubit!(basis, [0.2 NaN])
    @test basis == before
    @test_throws ArgumentError batch_qubit_encoding([NaN 0.2])
    aliased = BatchStateVector([0.1 0.3; 0.4 0.5])
    angles = view(storage(aliased), 1:1, [2, 1])
    expected = batch_qubit_encoding(Float64, copy(angles))
    @test reset_qubit!(aliased, angles) === aliased
    @test aliased ≈ expected
    amplitudes_input = [1.0 0.0; 0.0 1.0; 0.0 0.0]
    encoded = batch_amplitude_encoding(view(amplitudes_input, :, :))
    @test size(storage(encoded)) == (4, 2)
    @test storage(encoded)[1:3, :] == amplitudes_input
    @test norm(encoded) == ones(2)
    @test_throws ArgumentError batch_amplitude_encoding(zeros(0, 1))
    @test_throws ArgumentError batch_amplitude_encoding(zeros(2, 1))
end

@testset "Shared batch operator action and expectation dimensions" begin
    rng = MersenneTwister(414)
    batch = rand_batch(rng, 2, 3)
    before = copy(batch)
    term = QubitsTerm(1 => "Y", 2 => "X"; coeff=0.3im)
    operator = term + QubitsTerm(2 => "Z"; coeff=-0.2)
    constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 2im)
    real_batch = BatchStateVector([1.0 0.0; 0.0 1.0])
    for observable in (QubitsTerm(1 => "Y"), QubitsOperator(QubitsTerm(1 => "Y")))
        result = observable * real_batch
        @test eltype(result) <: Complex
        @test storage(result) ≈ Matrix(matrix(1, observable)) * storage(real_batch)
        @test storage(real_batch) == [1.0 0.0; 0.0 1.0]
    end
    for observable in (term, operator, constant)
        result = observable * batch
        reference = observable === constant ? 2im .* storage(batch) :
            Matrix(matrix(2, observable)) * storage(batch)
        @test storage(result) ≈ reference
        @test observable(batch) ≈ result
        @test !Base.mightalias(storage(result), storage(batch))
        @test expectation(observable, batch) ≈
            [dot(storage(batch)[:, column], reference[:, column]) for column in 1:3]
    end
    @test batch == before
    long_term = QubitsTerm((wire => "X" for wire in 1:6)...; coeff=0.2im)
    long_batch = rand_batch(rng, 6, 2)
    @test storage(long_term * long_batch) ≈ Matrix(matrix(6, long_term)) * storage(long_batch)
    @test size(storage(long_term * BatchStateVector(6, 0))) == (64, 0)
    @test_throws DimensionMismatch expectation(ones(3, 3), BatchStateVector(1, 0))
    @test_throws DimensionMismatch expectation(BatchStateVector(1, 2), QubitsTerm(1 => "Z"), BatchStateVector(2, 2))
    @test_throws DimensionMismatch expectation(BatchStateVector(1, 2), QubitsTerm(1 => "Z"), BatchStateVector(1, 3))
    @test_throws ArgumentError expectation(QubitsTerm(3 => "Z"), batch)
    @test_throws ArgumentError QubitsTerm(3 => "Z") * batch
    malformed = BatchContractFixtures.MalformedGate()
    @test_throws DimensionMismatch apply!(malformed, batch)
    @test batch == before
    @test_throws DimensionMismatch expectation(malformed, batch)
end

@testset "Per-sample reduced density matrices" begin
    bell = StateVector(ComplexF64[1, 0, 0, 1] / sqrt(2))
    basis = onehot_encoding([1, 0])
    batch = BatchStateVector([bell, basis])
    before = copy(batch)
    reductions = partial_tr(batch, [2])
    @test reductions isa Vector{DensityMatrix}
    @test length(reductions) == 2
    @test storage(reductions[1]) ≈ Matrix{ComplexF64}(I, 2, 2) / 2
    @test storage(reductions[2]) ≈ ComplexF64[0 0; 0 1]
    for column in 1:2
        @test reductions[column] ≈ partial_tr(StateVector(batch, column), [2])
        @test tr(reductions[column]) ≈ 1
    end
    storage(reductions[1])[1] = 99
    @test batch == before
    @test reductions[2] ≈ partial_tr(basis, [2])
    @test partial_tr(batch, [1, 2]) ≈ ones(2)
    @test all(isapprox.(partial_tr(batch, Int[]), [DensityMatrix(bell), DensityMatrix(basis)]))
    @test isempty(partial_tr(BatchStateVector(2, 0), [1]))
    @test_throws ArgumentError partial_tr(batch, [1, 1])
    @test_throws ArgumentError partial_tr(batch, [3])
end
