using Test, MOSS, Zygote, LinearAlgebra, Random

function _batch_density_gradient_difference(loss, values; step=1e-6)
    result = similar(values, promote_type(eltype(values), Float64))
    for index in eachindex(values)
        plus, minus = copy(values), copy(values)
        plus[index] += step
        minus[index] -= step
        real_part = (loss(plus) - loss(minus)) / (2step)
        if eltype(values) <: Complex
            plus, minus = copy(values), copy(values)
            plus[index] += im * step
            minus[index] -= im * step
            result[index] = real_part + im * (loss(plus) - loss(minus)) / (2step)
        else
            result[index] = real_part
        end
    end
    return result
end

@testset "Legacy batch density and fixed-noise differentiation" begin
    rng = MersenneTwister(619)
    pure = rand_batch(rng, 2, 2)
    mixed = rand_batch_densitymatrix(rng, 2, 2)
    observable = QubitsTerm(1 => "Y"; coeff=0.7) + QubitsTerm(2 => "Z"; coeff=-0.2)
    unitary = QCircuit([RyGate(1, 0.1; isparas=true),
        QCircuit([CNOTGate(1, 2), RzGate(2, -0.2; isparas=true)])])
    noisy = QCircuit([RyGate(1, 0.1; isparas=true),
        QCircuit([AmplitudeDamping(1; γ=0.3), CNOTGate(1, 2),
            RzGate(2, -0.2; isparas=true), PhaseDamping(2; γ=1.0)])])
    weights = [0.7, -0.4]
    z_observed = QubitsTerm(1 => "Z")

    @testset "Shared parameters and optional objective adapter" begin
        for initial in (pure, mixed), circuit in (unitary, noisy)
            loss(circuit) = real(sum(weights .* expectation(observable, circuit * initial)))
            expected = sum(weights[b] .* Zygote.gradient(c -> real(expectation(observable,
                c * (initial isa BatchStateVector ? StateVector(initial, b) : DensityMatrix(initial, b)))),
                circuit)[1] for b in 1:2)
            @test Zygote.gradient(loss, circuit)[1] ≈ expected
            mutation_loss(circuit) = real(sum(weights .* expectation(observable, apply!(circuit, copy(initial)))))
            @test Zygote.gradient(mutation_loss, circuit)[1] ≈ expected
            parameter_map = ParameterMap([1, 1])
            values = [0.21]
            bound_loss(values) = loss(bind_parameters(circuit, values, parameter_map))
            @test Zygote.gradient(bound_loss, values)[1] ≈
                _batch_density_gradient_difference(bound_loss, values) atol=1e-7
            objective = BatchExpectationObjective(circuit, observable, initial;
                parameter_map=parameter_map, reduction=:weighted_sum, weights=weights)
            for parameters in (values, Float32.(values), view([0.21, 9.0], 1:1))
                adapter_loss(parameters) = differentiable_value(AdjointGradient(), objective, parameters)
                gradient = Zygote.gradient(adapter_loss, parameters)[1]
                @test gradient ≈ value_and_gradient(AdjointGradient(), objective, parameters)[2]
                @test eltype(gradient) === eltype(parameters)
                @test size(gradient) == size(parameters)
            end
        end
    end

    @testset "Expectation and constructor cotangents" begin
        constructors = (
            (data, owned) -> BatchDensityMatrix(data; copy=owned),
            (data, owned) -> BatchDensityMatrix(data, 1; copy=owned),
            (data, owned) -> BatchDensityMatrix(data, 1, 2; copy=owned),
            (data, owned) -> BatchDensityMatrix{ComplexF64}(data; copy=owned),
            (data, owned) -> BatchDensityMatrix{ComplexF64}(data, 1; copy=owned),
            (data, owned) -> BatchDensityMatrix{ComplexF64}(data, 1, 2; copy=owned))
        data = randn(rng, ComplexF64, 2, 2, 2)
        observations = (QubitsTerm(1 => "Y"), QubitsTerm(1 => "+"),
            (0.3 + 0.2im) * QubitsTerm(1 => "Z") + QubitsTerm(1 => "+"),
            QubitsTerm(Int[], Matrix{Float64}[], 0.7 + 0.3im))
        seeds = [0.3 + 0.7im, -0.4im]
        for observed in observations
            loss(values) = real(sum(seeds .* expectation(observed, BatchDensityMatrix(values))))
            @test Zygote.gradient(loss, data)[1] ≈
                _batch_density_gradient_difference(loss, data) atol=1e-7
        end
        observed = QubitsTerm(1 => "Z")
        for values in (data, Float32.(real.(data)), view(data, :, :, :)), constructor in constructors,
                owned in (false, true)
            loss(values) = real(sum(expectation(observed, constructor(values, owned))))
            gradient = Zygote.gradient(loss, values)[1]
            @test gradient ≈ repeat(reshape([1.0 0; 0 -1], 2, 2, 1), 1, 1, 2)
            @test eltype(gradient) === eltype(values)
            @test size(gradient) == size(values)
        end
        for wrap in (identity, copy, state -> BatchDensityMatrix(state),
                     state -> BatchDensityMatrix(state; copy=false),
                     state -> BatchDensityMatrix{ComplexF64}(state; copy=true),
                     state -> convert(BatchDensityMatrix{ComplexF64}, state))
            loss(values) = real(sum(expectation(observed, wrap(BatchDensityMatrix(values)))))
            @test Zygote.gradient(loss, data)[1] ≈ repeat(reshape([1.0 0; 0 -1], 2, 2, 1), 1, 1, 2)
        end
        extraction(values) = real(expectation(observed, DensityMatrix(BatchDensityMatrix(values), 2)))
        @test Zygote.gradient(extraction, data)[1] ≈ cat(zeros(2, 2), [1.0 0; 0 -1]; dims=3)
        for wrap in (state -> BatchDensityMatrix(state), state -> BatchDensityMatrix{ComplexF64}(state))
            single(values) = real(sum(expectation(observed, wrap(DensityMatrix(values)))))
            @test Zygote.gradient(single, data[:, :, 1])[1] ≈ [1.0 0; 0 -1]
        end
        samples = [DensityMatrix(data[:, :, b]) for b in 1:2]
        sample_loss(values) = real(sum(expectation(observed, BatchDensityMatrix(values))))
        sample_gradients = Zygote.gradient(sample_loss, samples)[1]
        @test all(storage(gradient) ≈ [1.0 0; 0 -1] for gradient in sample_gradients)
        output, list_back = Zygote.pullback(BatchDensityMatrix, samples)
        list_seed = ones(ComplexF64, size(storage(output)))
        expected_list = list_back(list_seed)[1]
        empty!(samples)
        @test all(isapprox.(list_back(list_seed)[1], expected_list))
        storage_loss(values) = sum(abs2, storage(BatchDensityMatrix(values)))
        @test Zygote.gradient(storage_loss, data)[1] ≈ 2 .* data
    end

    @testset "Pure-to-density arbitrary complex cotangents" begin
        data = randn(rng, ComplexF64, 2, 2)
        seed = randn(rng, ComplexF64, 2, 2, 2)
        for values in (data, Float32.(real.(data)), view(data, :, :)),
                convert_state in (state -> BatchDensityMatrix(state),
                                  state -> BatchDensityMatrix{ComplexF64}(state))
            loss(values) = real(sum(conj.(seed) .* storage(convert_state(BatchStateVector(values)))))
            expected = hcat(((seed[:, :, b] + seed[:, :, b]') * values[:, b] for b in 1:2)...)
            if eltype(values) <: Real
                expected = real.(expected)
            end
            @test Zygote.gradient(loss, values)[1] ≈ expected atol=1e-6
            @test eltype(Zygote.gradient(loss, values)[1]) === eltype(values)
            if eltype(values) === ComplexF64
                @test Zygote.gradient(loss, values)[1] ≈
                    _batch_density_gradient_difference(loss, values) atol=1e-7
            end
        end
        for convert_state in (state -> BatchDensityMatrix(state),
                              state -> BatchDensityMatrix{ComplexF64}(state))
            loss(values) = real(sum(conj.(seed[:, :, 1:1]) .* storage(convert_state(StateVector(values)))))
            @test Zygote.gradient(loss, data[:, 1])[1] ≈ (seed[:, :, 1] + seed[:, :, 1]') * data[:, 1]
        end
        initial = BatchStateVector(copy(data))
        result, back = Zygote.pullback(BatchDensityMatrix, initial)
        expected = back(seed)[1]
        storage(initial) .= 0
        storage(result) .= 0
        @test back(seed)[1] ≈ expected
        @test back(2 .* seed)[1] ≈ 2 * expected
    end

    @testset "State derivatives through fixed noise" begin
        for initial in (pure, mixed)
            data = copy(storage(initial))
            wrap = initial isa BatchStateVector ? BatchStateVector : BatchDensityMatrix
            loss(values) = real(sum(weights .* expectation(observable, noisy * wrap(values))))
            @test Zygote.gradient(loss, data)[1] ≈
                _batch_density_gradient_difference(loss, data) atol=1e-7
        end
        real_data = reshape([0.6, 0.8, 0.8, -0.6], 2, 2)
        real_observed = QubitsTerm(1 => "Y")
        real_circuit = QCircuit([RxGate(1, 0.2; isparas=true), AmplitudeDamping(1; γ=0.3)])
        real_loss(values) = real(sum(expectation(real_observed, real_circuit * BatchStateVector(values))))
        @test Zygote.gradient(real_loss, real_data)[1] ≈
            _batch_density_gradient_difference(real_loss, real_data) atol=1e-7
    end

    @testset "Private reconstruction points and empty domains" begin
        for initial in (pure, mixed), source in (unitary, noisy)
            circuit = copy_instruction(source)
            state = copy(initial)
            output, back = MOSS._batch_circuit_adjoint(circuit, state)
            seed = randn(rng, ComplexF64, size(storage(output)))
            parameter_gradient, state_gradient = back(seed)
            @test back(2 .* seed)[1] ≈ 2 .* parameter_gradient
            @test back(2 .* seed)[2] ≈ 2 * state_gradient
            storage(state) .= 0
            storage(output) .= 0
            circuit[1] = XGate(1)
            @test back(seed)[1] ≈ parameter_gradient
            @test back(seed)[2] ≈ state_gradient
            @test back(nothing)[1] == zeros(nparameters(source))
            @test size(storage(back(nothing)[2])) == size(storage(initial))
            @test iszero(norm(storage(back(nothing)[2])))
            storage(state_gradient) .= 99
            parameter_gradient .= 99
            @test back(seed)[1] != parameter_gradient
            @test back(seed)[2] != state_gradient
            @test_throws DimensionMismatch back(zeros(ntuple(_ -> 3, ndims(storage(output)))))
            @test_throws ArgumentError back(zeros(8))
        end
        for state in (BatchStateVector(1, 0), BatchDensityMatrix(1, 0))
            # Use a valid one-qubit circuit for the empty batch.
            source = QCircuit([RyGate(1, 0.2; isparas=true), AmplitudeDamping(1; γ=1.0)])
            loss(circuit) = real(sum(expectation(z_observed, circuit * state)))
            @test Zygote.gradient(loss, source)[1] == [0.0]
            values = copy(storage(state))
            wrap = state isa BatchStateVector ? BatchStateVector : BatchDensityMatrix
            state_loss(values) = real(sum(expectation(z_observed, source * wrap(values))))
            @test size(Zygote.gradient(state_loss, values)[1]) == size(values)
        end
        constant = QubitsTerm(Int[], Matrix{Float64}[], 0.7 + 0.3im)
        zero_data = randn(rng, ComplexF64, 1, 1, 2)
        empty_circuit = QCircuit()
        zero_loss(values) = real(sum((0.2 + 0.3im) .* expectation(constant, empty_circuit * BatchDensityMatrix(values))))
        @test Zygote.gradient(zero_loss, zero_data)[1] ≈
            _batch_density_gradient_difference(zero_loss, zero_data) atol=1e-7
        for operation in (QMeasure(1), QSelect(1)), state in (pure, mixed)
            @test_throws ArgumentError MOSS._batch_circuit_adjoint(QCircuit([operation]), state)
        end
    end
end
