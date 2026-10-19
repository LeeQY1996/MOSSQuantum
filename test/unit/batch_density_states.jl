using LinearAlgebra, Random

@testset "Batch density shape, conversion, and ownership" begin
    data = zeros(ComplexF64, 4, 4, 3)
    data[1, 1, :] .= 1
    batch = BatchDensityMatrix(data)
    @test nqubits(batch) == 2
    @test batch_size(batch) == 3
    @test storage(batch) === data
    @test size(storage(BatchDensityMatrix(2, 1))) == (4, 4, 1)
    @test !(BatchDensityMatrix(2, 1) isa DensityMatrix)
    @test storage(BatchDensityMatrix(data; copy=true)) !== data
    @test storage(BatchDensityMatrix(batch)) !== data
    @test storage(BatchDensityMatrix(batch; copy=false)) === data
    @test storage(convert(BatchDensityMatrix{ComplexF64}, batch)) === data
    @test storage(copy(batch)) !== data
    @test BatchDensityMatrix(data, 2) == batch
    @test BatchDensityMatrix(data, 2, 3) == batch
    @test BatchDensityMatrix{ComplexF64}(data, 2) == batch
    @test BatchDensityMatrix{ComplexF64}(data) == batch
    @test eltype(BatchDensityMatrix{ComplexF32}(data)) == ComplexF32
    @test BatchDensityMatrix{ComplexF32}(batch) ≈ batch
    @test BatchDensityMatrix(Float64, 1, 2) == BatchDensityMatrix{Float64}(1, 2)
    @test storage(BatchDensityMatrix(view(data, :, :, 1:2))) isa Array{ComplexF64,3}
    @test_throws DimensionMismatch BatchDensityMatrix(zeros(4, 2, 1))
    @test_throws ArgumentError BatchDensityMatrix(zeros(3, 3, 1))
    @test_throws ArgumentError BatchDensityMatrix(zeros(0, 0, 1))
    @test_throws DimensionMismatch BatchDensityMatrix(data, 1)
    @test_throws DimensionMismatch BatchDensityMatrix(data, 2, 2)
    @test_throws ArgumentError BatchDensityMatrix(-1, 2)
    @test_throws ArgumentError BatchDensityMatrix(2, -1)
    @test_throws ArgumentError BatchDensityMatrix(8sizeof(Int), 0)
    @test_throws ArgumentError BatchDensityMatrix(div(8sizeof(Int), 2), 0)
    @test_throws ArgumentError BatchDensityMatrix(2, typemax(Int))
    @test_throws ArgumentError BatchDensityMatrix(DensityMatrix[])
    @test_throws DimensionMismatch BatchDensityMatrix([DensityMatrix(1), DensityMatrix(2)])

    density = DensityMatrix([0.6 0.1im; -0.1im 0.4])
    one = BatchDensityMatrix(density)
    @test size(storage(one)) == (2, 2, 1)
    one[1, 1, 1] = 0.7
    @test density[1, 1] == 0.7
    independent = BatchDensityMatrix(density; copy=true)
    independent[1, 1, 1] = 0.8
    @test density[1, 1] == 0.7
    extracted = DensityMatrix(batch, 1; copy=false)
    extracted[1, 1] = 2
    @test batch[1, 1, 1] == 1
    @test_throws BoundsError DensityMatrix(batch, 0)
    @test_throws BoundsError DensityMatrix(batch, 4)
    @test BatchDensityMatrix{ComplexF32}(density) ≈ BatchDensityMatrix(density)
    list = DensityMatrix[DensityMatrix(Float32[1 0; 0 0]), density]
    listed = BatchDensityMatrix(list)
    @test eltype(listed) == ComplexF64
    @test storage(listed)[:, :, 2] == storage(density)
    listed[1, 1, 1] = 9
    @test list[1][1, 1] == 1

    pure = BatchStateVector(ComplexF64[1 0; 0 1im])
    converted = BatchDensityMatrix(pure)
    @test tr(converted) == [1, 1]
    @test storage(converted)[:, :, 1] == ComplexF64[1 0; 0 0]
    @test storage(converted)[:, :, 2] == ComplexF64[0 0; 0 1]
    @test converted[1, 2, 1] == 0
    @test BatchDensityMatrix(StateVector(pure, 2)) == BatchDensityMatrix(DensityMatrix(StateVector(pure, 2)))
    @test eltype(BatchDensityMatrix{ComplexF32}(pure)) == ComplexF32
    storage(converted)[1, 1, 1] = 4
    @test storage(pure)[1, 1] == 1

    for n in (0, 2), B in (0, 1)
        state = BatchDensityMatrix(n, B)
        @test size(storage(state)) == (2^n, 2^n, B)
        @test length(tr(state)) == B
        @test normalize!(state) === state
        @test reset!(state) === state
        @test BatchDensityMatrix(BatchStateVector(n, B)) == state
        @test permute(state, collect(1:n)) == state
    end
end

@testset "Batch density algebra, reset, and random samples" begin
    rng = MersenneTwister(631)
    batch = rand_batch_densitymatrix(rng, 2, 3)
    @test tr(batch) ≈ ones(3)
    @test all(ishermitian(batch))
    @test all(isposdef(batch))
    @test norm(batch) ≈ [norm(storage(DensityMatrix(batch, b))) for b in 1:3]
    @test dot(batch, batch) ≈ norm(batch).^2
    @test fidelity(batch, batch) ≈ ones(3)
    @test distance(batch, batch) ≈ zeros(3)
    @test distance2(batch, batch) ≈ zeros(3)
    @test (batch + batch) / 2 ≈ batch
    @test 2 * batch - batch ≈ batch
    @test batch * 2 ≈ 2 * batch
    @test normalize(batch * 3) ≈ batch
    @test permute(permute(batch, [2, 1]), [2, 1]) ≈ batch
    @test all(isapprox(storage(permute(batch, [2, 1]))[:, :, b],
                       storage(permute(DensityMatrix(batch, b), [2, 1]))) for b in 1:3)
    @test_throws ArgumentError permute(batch, [1, 1])
    @test_throws ArgumentError permute(batch, [1])
    mismatched = BatchDensityMatrix(2, 2)
    @test_throws DimensionMismatch batch + mismatched
    @test_throws DimensionMismatch batch - mismatched
    @test_throws DimensionMismatch dot(batch, mismatched)
    @test_throws DimensionMismatch fidelity(batch, mismatched)
    @test_throws DimensionMismatch distance(batch, BatchDensityMatrix(1, 3))
    pure = rand_batch(MersenneTwister(532), 2, 3)
    @test fidelity(BatchDensityMatrix(pure), pure) ≈ ones(3)
    @test fidelity(pure, BatchDensityMatrix(pure)) ≈ ones(3)
    @test_throws DimensionMismatch fidelity(batch, BatchStateVector(1, 3))

    invalid = copy(batch)
    storage(invalid)[:, :, 3] .= 0
    snapshot = copy(invalid)
    @test_throws ArgumentError normalize!(invalid)
    @test invalid == snapshot
    invalid[1, 1, 3] = NaN
    @test_throws ArgumentError normalize!(invalid)
    negative = BatchDensityMatrix(-storage(batch))
    @test_throws ArgumentError normalize!(negative)
    imaginary = BatchDensityMatrix(im .* storage(batch))
    @test_throws ArgumentError normalize!(imaginary)
    rounded = copy(batch)
    rounded[1, 1, 1] += 1e-16im
    @test tr(normalize!(rounded)) ≈ ones(3)

    reset = copy(batch)
    @test reset_onehot!(reset, [[1, 0], [0, 1], [1, 1]]) === reset
    reference = BatchDensityMatrix(batch_onehot_encoding([[1, 0], [0, 1], [1, 1]]))
    @test reset == reference
    @test_throws ArgumentError reset_onehot!(reset, [[1, 0], [0, 1], [1, 2]])
    @test reset == reference
    @test_throws DimensionMismatch reset_onehot!(reset, [[1, 0]])
    @test_throws DimensionMismatch reset_onehot!(reset, [[1], [0], [1]])
    parameters = [0.1 0.2 0.3; -0.2 0.5 -0.7]
    @test reset_qubit!(reset, view(parameters, :, :)) === reset
    @test reset ≈ BatchDensityMatrix(batch_qubit_encoding(parameters))
    snapshot = copy(reset)
    invalid_parameters = copy(parameters)
    invalid_parameters[2, 3] = Inf
    @test_throws ArgumentError reset_qubit!(reset, invalid_parameters)
    @test reset == snapshot
    @test_throws DimensionMismatch reset_qubit!(reset, zeros(1, 3))
    @test reset!(reset) == BatchDensityMatrix(2, 3)
    @test rand_batch_densitymatrix(MersenneTwister(33), Float32, 1, 2) ==
          rand_batch_densitymatrix(MersenneTwister(33), Float32, 1, 2)
    @test tr(rand_batch_densitymatrix(0, 2)) ≈ ones(2)
    @test size(storage(rand_batch_densitymatrix(2, 0))) == (4, 4, 0)
end
