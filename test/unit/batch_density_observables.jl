using Test, MOSSQuantum, Random, LinearAlgebra

module BatchDensityObservableFixtures
import MOSSQuantum
struct OrderedBoundsGate <: MOSSQuantum.Gate{1} end
struct OrderedShapeGate <: MOSSQuantum.Gate{1} end
MOSSQuantum.positions(::Union{OrderedBoundsGate,OrderedShapeGate}) = (1,)
MOSSQuantum.mat(::Union{OrderedBoundsGate,OrderedShapeGate}) = [1.0 0.0; 0.0 1.0]
MOSSQuantum.ordered_positions(::OrderedBoundsGate) = (2,)
MOSSQuantum.ordered_positions(::OrderedShapeGate) = (1,)
MOSSQuantum.ordered_mat(::OrderedBoundsGate) = [1.0 0.0; 0.0 1.0]
MOSSQuantum.ordered_mat(::OrderedShapeGate) = ones(3, 3)
end

@testset "Independent batch density observables and operators" begin
    rng = MersenneTwister(613)
    n, count = 4, 3
    states = [rand_densitymatrix(rng, n) for _ in 1:count]
    batch = BatchDensityMatrix(states)
    before = copy(batch)
    term = QubitsTerm(1 => "Y", 4 => "X"; coeff=0.2im)
    long_term = QubitsTerm((wire => "X" for wire in 1:n)...; coeff=-0.3)
    operator = term + long_term + QubitsTerm(2 => "Z"; coeff=0.4)
    constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 2im)
    for observable in (term, long_term, operator, constant)
        dense = observable === constant ? 2im .* Matrix{ComplexF64}(I, 2^n, 2^n) : Matrix(matrix(n, observable))
        expected = [tr(dense * storage(state)) for state in states]
        @test expectation(observable, batch) ≈ expected
        @test expectation(CPUBackend(), observable, batch) ≈ expected
        @test expectation(dense, batch) ≈ expected
        @test expectation(CPUBackend(), dense, batch) ≈ expected
        result = observable * batch
        @test observable(batch) ≈ result
        @test dense * batch ≈ result
        @test !Base.mightalias(storage(result), storage(batch))
        for column in 1:count
            @test storage(result)[:, :, column] ≈ dense * storage(states[column])
        end
    end
    y = ComplexF64[0 -im; im 0]
    identity = Matrix{ComplexF64}(I, 2, 2)
    gate_observable = YGate(2)
    embedded = kron(identity, identity, y, identity)
    @test expectation(gate_observable, batch) ≈ [tr(embedded * storage(state)) for state in states]
    @test expectation(CPUBackend(), gate_observable, batch) ≈ expectation(gate_observable, batch)
    @test batch == before
    real_batch = BatchDensityMatrix(reshape([0.5, 0.2, 0.2, 0.5], 2, 2, 1))
    promoted = QubitsTerm(1 => "Y") * real_batch
    @test eltype(promoted) <: Complex
    @test storage(promoted)[:, :, 1] ≈ y * storage(real_batch)[:, :, 1]
    for observable in (term, operator, constant, gate_observable, Matrix{Float64}(I, 16, 16))
        @test isempty(expectation(observable, BatchDensityMatrix(n, 0)))
    end
    @test_throws ArgumentError expectation(QubitsTerm(5 => "Z"), batch)
    @test_throws DimensionMismatch expectation(ones(2, 2), batch)
    @test_throws DimensionMismatch expectation(ones(2, 2), BatchDensityMatrix(n, 0))
    @test_throws ArgumentError QubitsTerm(5 => "Z") * batch
    @test batch == before
    scalar = BatchDensityMatrix(reshape(ComplexF64[0.4, 0.7], 1, 1, 2))
    @test expectation(constant, scalar) ≈ [0.8im, 1.4im]
    @test expectation(fill(3.0, 1, 1), scalar) ≈ [1.2, 2.1]
    for state in (BatchDensityMatrix(1, 2), BatchDensityMatrix(1, 0),
                  BatchStateVector(1, 2), BatchStateVector(1, 0))
        @test_throws ArgumentError expectation(BatchDensityObservableFixtures.OrderedBoundsGate(), state)
        @test_throws DimensionMismatch expectation(BatchDensityObservableFixtures.OrderedShapeGate(), state)
    end
end

@testset "Batch density partial trace retains independent samples" begin
    bell = StateVector(ComplexF64[1, 0, 0, 1] / sqrt(2))
    pure = BatchStateVector([bell, onehot_encoding([1, 0])])
    batch = BatchDensityMatrix(pure)
    for sites in ([1], [2])
        reduced = partial_tr(batch, sites)
        @test reduced isa BatchDensityMatrix
        @test size(storage(reduced)) == (2, 2, 2)
        @test nqubits(reduced) == 1
        @test batch_size(reduced) == 2
        for column in 1:2
            @test DensityMatrix(reduced, column) ≈ partial_tr(DensityMatrix(batch, column), sites)
        end
        @test tr(reduced) ≈ ones(2)
        @test !Base.mightalias(storage(reduced), storage(batch))
    end
    @test storage(partial_tr(batch, [2]))[:, :, 1] ≈ Matrix{ComplexF64}(I, 2, 2) / 2
    @test partial_tr(batch, [1, 2]) ≈ ones(2)
    unchanged = partial_tr(batch, Int[])
    @test unchanged ≈ batch
    @test !Base.mightalias(storage(unchanged), storage(batch))
    @test size(storage(partial_tr(BatchDensityMatrix(3, 0), [2]))) == (4, 4, 0)
    @test isempty(partial_tr(BatchDensityMatrix(3, 0), [1, 2, 3]))
    @test size(storage(partial_tr(BatchDensityMatrix(0, 2), Int[]))) == (1, 1, 2)
    @test_throws ArgumentError partial_tr(batch, [1, 1])
    @test_throws ArgumentError partial_tr(batch, [3])
    # Keep the previously established pure-batch return type stable.
    @test partial_tr(pure, [1]) isa Vector{DensityMatrix}
    mixed = BatchDensityMatrix([rand_densitymatrix(MersenneTwister(19), 4)])
    @test DensityMatrix(partial_tr(mixed, [1, 3]), 1) ≈ partial_tr(DensityMatrix(mixed, 1), [1, 3])
end
