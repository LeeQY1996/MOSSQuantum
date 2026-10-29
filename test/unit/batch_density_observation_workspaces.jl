using Test, MOSSQuantum, Random, LinearAlgebra

function _batch_density_observation_dense(observable, n, ::Type{T}) where {T}
    if observable isa QubitsTerm && isempty(observable)
        return coeff(observable) .* Matrix{T}(I, 2^n, 2^n)
    elseif observable isa QubitsOperator && isempty(observable.data)
        return zeros(T, 2^n, 2^n)
    end
    return Matrix(matrix(n, observable))
end

function _batch_density_observation_promoted(observable::QubitsTerm, ::Type{T}) where {T}
    return QubitsTerm(copy(positions(observable)),
        [Matrix{T}(factor) for factor in oplist(observable)], T(coeff(observable)))
end

function _batch_density_observation_promoted(observable::QubitsOperator, ::Type{T}) where {T}
    result = QubitsOperator()
    for (register, terms) in observable.data, (factors, coefficient) in terms
        result += QubitsTerm(collect(register), [Matrix{T}(factor) for factor in factors], T(coefficient))
    end
    return result
end

@testset "Batch density observation workspaces preserve contracts" begin
    rng = MersenneTwister(620)

    @testset "Promoted short trace contractions read input views" begin
        n, B = 5, 3
        real_factor = Float32[0.2 0.7; -0.4 0.9]
        complex_factor = ComplexF32[0.3im 0.8; -0.2im -0.5]
        observations = (
            QubitsTerm(4 => real_factor; coeff=0.3f0),
            QubitsTerm(1 => complex_factor, 5 => real_factor; coeff=0.2f0 + 0.1f0im),
            QubitsTerm(1 => real_factor, 3 => complex_factor, 5 => real_factor; coeff=-0.4f0),
            QubitsTerm(4 => real_factor; coeff=0.3f0) +
                QubitsTerm(1 => complex_factor, 5 => real_factor; coeff=0.2f0 + 0.1f0im),
            QubitsTerm(Int[], Matrix{Float32}[], 0.2f0 + 0.7f0im),
            QubitsOperator())
        for T in (Float32, Float64, ComplexF32, ComplexF64)
            data = randn(rng, T, 2^n, 2^n, B)
            batch = BatchDensityMatrix(data)
            before = copy(data)
            for observed in observations
                dense = _batch_density_observation_dense(observed, n, T)
                expected = [tr(dense * view(data, :, :, b)) for b in 1:B]
                values = expectation(observed, batch)
                # Dense embedding inserts Float64 identity factors before
                # multiplying an observable's Float32 factors. The existing
                # local contraction forms that small matrix in Float32 first.
                # Check the independent dense reference at component precision,
                # and preserve the previous promoted single-state result too.
                reference_rtol = max(sqrt(eps(typeof(float(real(zero(eltype(values))))))),
                    8eps(typeof(float(real(zero(eltype(observed)))))))
                baseline = [expectation(observed, DensityMatrix(Matrix{eltype(values)}(
                    view(data, :, :, b)), n)) for b in 1:B]
                @test isapprox(values, expected; rtol=reference_rtol)
                @test values ≈ baseline
                @test eltype(values) === promote_type(eltype(observed), T)
                @test data == before
                values .= 99
                @test isapprox(expectation(observed, batch), expected; rtol=reference_rtol)
                empty_values = expectation(observed, BatchDensityMatrix(T, n, 0))
                @test size(empty_values) == (0,)
                @test eltype(empty_values) === promote_type(eltype(observed), T)
            end
        end
        # A complex Float64 observable promotes the trace accumulation even
        # when the original samples use Float32 storage.
        diagonal = zeros(Float32, 4, 4, 1)
        diagonal[1, 1, 1], diagonal[2, 2, 1], diagonal[3, 3, 1] = 1f8, 1f0, -1f8
        constant = QubitsTerm(Int[], Matrix{Float64}[], 0.0 + 1.0im)
        @test expectation(constant, BatchDensityMatrix(diagonal)) == [1.0im]
    end

    @testset "Density expectation pullbacks own an independent shared basis" begin
        for n in (0, 2, 6)
            B = 3
            constant = QubitsTerm(Int[], Matrix{Float64}[], 0.7 + 0.3im)
            observations = n == 0 ? (constant, QubitsOperator()) : (
                QubitsTerm(1 => "+"; coeff=0.2 + 0.4im),
                QubitsTerm((q => "X" for q in 1:n)...; coeff=0.3im),
                QubitsTerm(1 => "Y") + QubitsTerm(n => "+"; coeff=-0.4im),
                constant, QubitsOperator())
            for source_observed in observations, T in (Float64, ComplexF64)
                observed = deepcopy(source_observed)
                data = randn(rng, T, 2^n, 2^n, B)
                state = BatchDensityMatrix(copy(data))
                saved_observed = deepcopy(observed)
                dense = _batch_density_observation_dense(observed, n, T)
                values, back = MOSSQuantum._batch_expectation_adjoint(observed, state)
                @test values ≈ [tr(dense * view(data, :, :, b)) for b in 1:B]
                seeds = [0.2 + 0.3im, -0.4im, 0.0im]
                expected = cat((seeds[b] .* dense' for b in 1:B)...; dims=3)
                gradient = back(seeds)[2]
                @test storage(gradient) ≈ expected
                @test eltype(gradient) === promote_type(T, eltype(observed), eltype(seeds))
                @test !Base.mightalias(storage(gradient), storage(state))
                @test !Base.mightalias(storage(gradient), seeds)

                # A prepared pullback must no longer depend on mutable inputs,
                # returned observation values, or a previously returned gradient.
                storage(state) .= 0
                values .= 99
                storage(gradient) .= 99
                if observed isa QubitsTerm
                    for factor in oplist(observed)
                        factor .= 0
                    end
                else
                    empty!(observed.data)
                end
                @test storage(back(seeds)[2]) ≈ expected
                @test storage(back(-2 .* seeds)[2]) ≈ -2 .* expected
                @test iszero(norm(storage(back(nothing)[2])))
                @test size(storage(back(nothing)[2])) == size(data)
                @test_throws DimensionMismatch back([1.0])
                @test_throws ArgumentError back(1.0)
                @test_throws ArgumentError back(["seed", "seed", "seed"])

                # Simultaneous calls share only a read-only private operator;
                # every result has its own gradient array.
                tasks = [Threads.@spawn back(scale .* seeds)[2] for scale in (1.0, -2.0, 0.5)]
                results = fetch.(tasks)
                for (result, scale) in zip(results, (1.0, -2.0, 0.5))
                    @test storage(result) ≈ scale .* expected
                end
                @test !Base.mightalias(storage(results[1]), storage(results[2]))
                storage(results[1]) .= 22
                @test storage(results[2]) ≈ -2 .* expected

                empty_state = BatchDensityMatrix(T, n, 0)
                empty_values, empty_back = MOSSQuantum._batch_expectation_adjoint(saved_observed, empty_state)
                @test isempty(empty_values)
                @test size(storage(empty_back(ComplexF64[])[2])) == (2^n, 2^n, 0)
                @test size(storage(empty_back(nothing)[2])) == (2^n, 2^n, 0)
                @test_throws DimensionMismatch empty_back([1.0])
            end
        end
    end

    @testset "Seed domains and multiplication order" begin
        n, B = 2, 4
        factor = Float32[0.2 0.7; -0.4 0.9]
        complex_factor = ComplexF32[0.3im 0.8; -0.2im -0.5]
        observations = (
            QubitsTerm(1 => factor; coeff=0.3f0),
            QubitsTerm(1 => complex_factor, 2 => factor; coeff=0.2f0 + 0.1f0im),
            QubitsTerm(1 => factor; coeff=0.3f0) +
                QubitsTerm(2 => complex_factor; coeff=-0.4f0))
        # Equal adjacent seeds exercise shared actions; changed and repeated
        # nonadjacent values must still use their own mathematical cotangent.
        for T in (Float32, ComplexF32), observed in observations,
                seeds in (Float64[0.3, 0.3, -0.7, 0.3],
                          ComplexF64[0.2 + 0.3im, 0.2 + 0.3im, -0.4im, 0.2 + 0.3im])
            data = randn(rng, T, 2^n, 2^n, B)
            state = BatchDensityMatrix(data)
            _, back = MOSSQuantum._batch_expectation_adjoint(observed, state)
            CT = promote_type(T, eltype(observed), eltype(seeds))
            promoted = _batch_density_observation_promoted(observed, CT)
            dense = _batch_density_observation_dense(promoted, n, CT)
            expected = cat((seeds[b] .* dense' for b in 1:B)...; dims=3)
            legacy = cat((storage(MOSSQuantum._batch_single_expectation_pullback(observed,
                DensityMatrix(Matrix{CT}(view(data, :, :, b)), n))[2](seeds[b])[2])
                for b in 1:B)...; dims=3)
            gradient = back(seeds)[2]
            @test isapprox(storage(gradient), expected; rtol=1e-12, atol=1e-14)
            @test storage(gradient) ≈ legacy
            @test eltype(gradient) === CT
            @test storage(back(seeds)[2]) ≈ legacy
        end

        # Scaling the operator before applying its factors can recover a
        # representable derivative that an unseeded cached matrix would erase.
        for T in (Float32, Float64)
            coefficient = T === Float32 ? 1f-25 : 1e-200
            small = T === Float32 ? 1f-25 : 1e-200
            scale = T === Float32 ? 1f30 : 1e200
            observed = QubitsTerm(1 => T[small 0; 0 0]; coeff=coefficient)
            _, back = MOSSQuantum._batch_expectation_adjoint(observed, BatchDensityMatrix(T, 1, 3))
            seeds = T[scale, scale, -scale]
            expected = zeros(T, 2, 2, 3)
            expected[1, 1, :] .= (seeds .* coefficient) .* small
            @test all(!iszero, expected[1, 1, :])
            @test storage(back(seeds)[2]) == expected
        end
        tiny = nextfloat(0f0)
        observed = QubitsTerm(1 => Float32[0.25 0; 0 0]; coeff=tiny)
        _, back = MOSSQuantum._batch_expectation_adjoint(observed, BatchDensityMatrix(Float32, 1, 3))
        seeds = Float64[2.0^100, 2.0^100, -2.0^100]
        expected = zeros(Float64, 2, 2, 3)
        expected[1, 1, :] .= [2.0^-51, 2.0^-51, -2.0^-51]
        @test storage(back(seeds)[2]) == expected
    end
end
