using Test, Random, LinearAlgebra
using MOSSQuantum

@testset "Constant and zero operators across CPU states" begin
    rng = MersenneTwister(2718)
    for n in (0, 2, 5), T in (Float64, ComplexF64)
        dimension = 1 << n
        amplitudes = randn(rng, T, dimension)
        pure = StateVector(amplitudes, n)
        mixed = DensityMatrix(amplitudes * amplitudes', n)
        pure_batch = BatchStateVector(hcat(amplitudes, 2amplitudes), n)
        mixed_batch = BatchDensityMatrix(cat(storage(mixed), 3storage(mixed); dims=3), n)
        for coefficient in (0.0, 2.3, -0.7 + 0.2im)
            term = QubitsTerm(Int[], Matrix{ComplexF64}[], coefficient)
            for observable in (term, QubitsOperator(term))
                for state in (pure, mixed, pure_batch, mixed_batch)
                    before = copy(storage(state))
                    result = observable * state
                    @test storage(result) ≈ coefficient .* before
                    @test !Base.mightalias(storage(result), storage(state))
                    @test storage(state) == before
                    expected = state isa StateVector ? coefficient * dot(amplitudes, amplitudes) :
                        state isa DensityMatrix ? coefficient * tr(before) :
                        state isa BatchStateVector ? coefficient .* [dot(c, c) for c in eachcol(before)] :
                        coefficient .* [tr(before[:, :, b]) for b in axes(before, 3)]
                    @test expectation(observable, state) ≈ expected
                end
                bra = StateVector((1 + 0.4im) .* amplitudes, n)
                @test expectation(bra, observable, pure) ≈ coefficient * dot(storage(bra), amplitudes)
                bra_batch = BatchStateVector(hcat(storage(bra), 3storage(bra)), n)
                @test expectation(bra_batch, observable, pure_batch) ≈
                    coefficient .* [dot(storage(bra_batch)[:, b], storage(pure_batch)[:, b]) for b in 1:2]
            end
        end
        zero_operator = QubitsOperator()
        for state in (pure, mixed, pure_batch, mixed_batch)
            @test iszero(storage(zero_operator * state))
            @test iszero(expectation(zero_operator, state))
        end
    end

    # Scalar terms must also coexist with local terms in each kernel route.
    for n in (2, 5, 6)
        v = randn(rng, 1 << n)
        constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 1.25)
        local_term = QubitsTerm(1 => "Y"; coeff=-0.4im)
        long_term = QubitsTerm((q => "X" for q in 1:n)...; coeff=0.3)
        for term in (local_term, long_term)
            observable = constant + term
            reference = 1.25 .* Matrix{ComplexF64}(I, length(v), length(v)) + Matrix(matrix(n, term))
            pure = StateVector(v, n)
            mixed = DensityMatrix(v * v', n)
            pure_batch = BatchStateVector(hcat(v, 2v), n)
            mixed_batch = BatchDensityMatrix(cat(storage(mixed), 2storage(mixed); dims=3), n)
            @test storage(observable * pure) ≈ reference * v
            @test expectation(observable, pure) ≈ dot(v, reference, v)
            @test storage(observable * mixed) ≈ reference * storage(mixed)
            @test expectation(observable, mixed) ≈ tr(reference * storage(mixed))
            @test storage(observable * pure_batch) ≈ reference * storage(pure_batch)
            @test expectation(observable, pure_batch) ≈ [dot(c, reference, c) for c in eachcol(storage(pure_batch))]
            @test expectation(observable, mixed_batch) ≈
                [tr(reference * storage(mixed_batch)[:, :, b]) for b in 1:2]
        end
    end

    for n in (0, 2)
        constant = QubitsOperator(QubitsTerm(Int[], Matrix{ComplexF64}[], 2.0))
        for empty_batch in (BatchStateVector(n, 0), BatchDensityMatrix(n, 0))
            @test isempty(expectation(constant, empty_batch))
            @test size(storage(constant * empty_batch)) == size(storage(empty_batch))
        end
    end
end

@testset "Scalar gates preserve phase and density scaling" begin
    rng = MersenneTwister(1618)
    for n in (0, 2, 5), coefficient in (exp(0.37im), 0.7 + 0.2im)
        scalar_gate = QuantumGate((), reshape([coefficient], 1, 1))
        v = randn(rng, 1 << n)
        pure = StateVector(v, n)
        mixed = DensityMatrix(v * v', n)
        for state in (pure, mixed, BatchStateVector(hcat(v, 2v), n),
                      BatchDensityMatrix(cat(storage(mixed), 2storage(mixed); dims=3), n))
            factor = state isa Union{DensityMatrix,BatchDensityMatrix} ? abs2(coefficient) : coefficient
            before = copy(storage(state))
            @test supports(CPUBackend(), scalar_gate, state)
            result = QCircuit([scalar_gate]) * state
            @test storage(result) ≈ factor .* before
            @test storage(state) == before
        end
        @test expectation(scalar_gate, pure) ≈ coefficient * dot(v, v)
        @test expectation(scalar_gate, BatchStateVector(hcat(v, 2v), n)) ≈
            coefficient .* [dot(v, v), 4dot(v, v)]
    end
end

@testset "Constant offsets retain analytic circuit gradients" begin
    template = QCircuit([RyGate(1, 0.0; isparas=true)])
    phase = QuantumGate((), reshape([exp(0.27im)], 1, 1))
    phased_template = QCircuit([phase, template])
    constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 1.7)
    values = [0.41]
    for initial in (StateVector(1), DensityMatrix(StateVector(1)))
        for observable in (constant, QubitsOperator(constant), QubitsOperator())
            objective = ExpectationObjective(phased_template, observable, initial)
            @test supports_gradient(AdjointGradient(), objective)
            value, gradient = value_and_gradient(AdjointGradient(), objective, values)
            @test value ≈ (observable isa QubitsOperator && isempty(observable.data) ? 0.0 : 1.7)
            @test gradient ≈ [0.0] atol=1e-12
        end
        objective = ExpectationObjective(phased_template, constant + QubitsTerm(1 => "Z"), initial)
        value, gradient = value_and_gradient(AdjointGradient(), objective, values)
        @test value ≈ 1.7 + cos(values[1])
        @test gradient ≈ [-sin(values[1])]
    end
    for initial in (BatchStateVector(1, 3), BatchDensityMatrix(1, 3))
        objective = BatchExpectationObjective(phased_template,
            constant + QubitsTerm(1 => "Z"), initial)
        value, gradient = value_and_gradient(AdjointGradient(), objective, values)
        @test value ≈ 1.7 + cos(values[1])
        @test gradient ≈ [-sin(values[1])]
    end
end
