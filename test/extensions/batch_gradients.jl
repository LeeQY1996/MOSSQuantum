using Test, MOSSQuantum, Zygote, LinearAlgebra, Random

function _batch_gradient_finite_difference(loss, values; step=1e-6)
    gradient = similar(values, promote_type(eltype(values), Float64))
    for index in eachindex(values)
        plus, minus = copy(values), copy(values)
        plus[index] += step
        minus[index] -= step
        re = (loss(plus) - loss(minus)) / (2step)
        if eltype(values) <: Complex
            plus, minus = copy(values), copy(values)
            plus[index] += im * step
            minus[index] -= im * step
            im_part = (loss(plus) - loss(minus)) / (2step)
            gradient[index] = re + im * im_part
        else
            gradient[index] = re
        end
    end
    return gradient
end

@testset "Legacy batch pure-state differentiation" begin
    rng = MersenneTwister(47)
    initial = rand_batch(rng, 2, 3)
    z_observable = QubitsTerm(1 => "Z")
    observable = z_observable + 0.4 * QubitsTerm(2 => "X")
    template = QCircuit([RyGate(1, 0.12; isparas=true),
        QCircuit([RzGate(2, -0.2; isparas=true), CNOTGate(1, 2)]),
        RxGate(1, 0.31; isparas=true)])
    weights = [0.4, -0.8, 1.7]

    @testset "Shared circuit slots and mapped parameters" begin
        loss(circuit) = real(sum(weights .* expectation(observable, circuit * initial)))
        expected = sum(weights[column] .* Zygote.gradient(
            circuit -> real(expectation(observable, circuit * StateVector(initial, column))), template)[1]
            for column in 1:batch_size(initial))
        @test Zygote.gradient(loss, template)[1] ≈ expected
        mutation_loss(circuit) = real(sum(weights .* expectation(observable, apply!(circuit, copy(initial)))))
        @test Zygote.gradient(mutation_loss, template)[1] ≈ expected
        @test batch_size(initial) == 3
        original = copy(initial)
        parameter_map = ParameterMap([1, 2, 1])
        values = [0.34, -0.18]
        mapped_loss(values) = loss(bind_parameters(template, values, parameter_map))
        @test Zygote.gradient(mapped_loss, values)[1] ≈
            _batch_gradient_finite_difference(mapped_loss, values) atol=1e-7
        @test initial == original
        @test active_parameters(template) == [0.12, -0.2, 0.31]
    end

    @testset "State and expectation cotangents" begin
        for data in (Float32[0.6 0.8; 0.8 -0.6], ComplexF64[0.6 0.2im; 0.8im 0.9])
            for observed in (QubitsTerm(1 => "Z"),
                             (1 + 0.4im) * QubitsTerm(1 => "Y"),
                             QubitsTerm(1 => "+") + (0.2im) * QubitsTerm(1 => "Z"),
                             QubitsTerm(Int[], Matrix{Float64}[], 1 + 0.3im))
                loss(values) = real(sum([0.7 + 0.2im, -0.9im] .*
                    expectation(observed, BatchStateVector(values))))
                original = copy(data)
                gradient = Zygote.gradient(loss, data)[1]
                @test gradient ≈ _batch_gradient_finite_difference(loss, data;
                    step=eltype(data) === Float32 ? 1e-3 : 1e-6) atol=3e-4
                @test eltype(gradient) === eltype(data)
                @test size(gradient) == size(data)
                @test data == original
            end
        end
        data = copy(storage(initial))
        state_loss(values) = real(sum(weights .* expectation(observable, template * BatchStateVector(values))))
        @test Zygote.gradient(state_loss, data)[1] ≈
            _batch_gradient_finite_difference(state_loss, data) atol=1e-7
        @test Zygote.gradient(state_loss, data)[1] ≈ hcat((weights[column] .* Zygote.gradient(
            values -> real(expectation(observable, template * StateVector(values))), data[:, column])[1]
            for column in 1:batch_size(initial))...)

        high_data = randn(rng, ComplexF64, 64, 2)
        high_observable = QubitsTerm((position => "Z" for position in 1:6)...)
        high_operator = high_observable + (0.2im) * QubitsTerm(1 => "X")
        for observed in (high_observable, high_operator)
            seeds = [0.7 + 0.2im, -0.9im]
            high_loss(values) = real(sum(seeds .* expectation(observed, BatchStateVector(values))))
            operator = matrix(6, observed)
            expected = hcat((seeds[column] .* (operator * high_data[:, column]) +
                conj(seeds[column]) .* (operator' * high_data[:, column]) for column in 1:2)...)
            @test Zygote.gradient(high_loss, high_data)[1] ≈ expected
        end
    end

    @testset "Constructor ownership controls and projection" begin
        constructors = (
            (values, owned) -> BatchStateVector(values; copy=owned),
            (values, owned) -> BatchStateVector(values, 1; copy=owned),
            (values, owned) -> BatchStateVector(values, 1, 2; copy=owned),
            (values, owned) -> BatchStateVector{ComplexF64}(values, 1, 2; copy=owned),
            (values, owned) -> BatchStateVector{ComplexF64}(values, 1; copy=owned),
            (values, owned) -> BatchStateVector{ComplexF64}(values; copy=owned),
        )
        for data in (Float32[0.6 0.8; 0.8 -0.6], ComplexF64[0.6 0.2im; 0.8im 0.9])
            for constructor in constructors, owned in (false, true)
                loss(values) = real(sum(expectation(z_observable, constructor(values, owned))))
                gradient = Zygote.gradient(loss, data)[1]
                @test gradient ≈ 2 .* [1, -1] .* data
                @test eltype(gradient) === eltype(data)
                @test size(gradient) == size(data)
            end
            for wrap in (identity, Base.copy, state -> BatchStateVector(state),
                         state -> BatchStateVector(state; copy=false),
                         state -> BatchStateVector(state; copy=true),
                         state -> convert(BatchStateVector{ComplexF64}, state))
                loss(values) = real(sum(expectation(z_observable, wrap(BatchStateVector(values)))))
                @test Zygote.gradient(loss, data)[1] ≈ 2 .* [1, -1] .* data
                @test eltype(Zygote.gradient(loss, data)[1]) === eltype(data)
            end
            # Batch extraction returns a cotangent only in the selected column.
            extraction(values) = real(expectation(z_observable, StateVector(BatchStateVector(values), 2)))
            @test Zygote.gradient(extraction, data)[1] ≈ hcat(zeros(eltype(data), 2), 2 .* [1, -1] .* data[:, 2])
            single_loss(values) = real(sum(expectation(z_observable, BatchStateVector(StateVector(values)))))
            @test Zygote.gradient(single_loss, data[:, 1])[1] ≈ 2 .* [1, -1] .* data[:, 1]
            storage_loss(values) = sum(abs2, storage(BatchStateVector(values)))
            @test Zygote.gradient(storage_loss, data)[1] ≈ 2 .* data
        end
    end

    @testset "Product-state batch encoding gradients" begin
        observed = QubitsTerm(1 => "Z") + 0.4 * QubitsTerm(2 => "X")
        weights = [0.3, -0.7, 1.2]
        angles = [0.12 0.24 -0.31; -0.21 0.42 0.18]
        for values in (angles, Float32.(angles), view(Float32.(angles), :, :))
            for encode in (batch_qubit_encoding,
                           values -> batch_qubit_encoding(Float64, values),
                           values -> batch_qubit_encoding(ComplexF32, values))
                original = copy(values)
                loss(values) = real(sum(weights .* expectation(observed, encode(values))))
                gradient = Zygote.gradient(loss, values)[1]
                expected = vcat(reshape(-pi .* sin.(pi .* values[1, :]) .* weights, 1, :),
                    reshape(0.4pi .* cos.(pi .* values[2, :]) .* weights, 1, :))
                @test gradient ≈ expected atol=2e-6
                @test eltype(gradient) === eltype(values)
                @test size(gradient) == size(values)
                @test values == original
                if eltype(values) === Float64
                    @test gradient ≈ _batch_gradient_finite_difference(loss, values;
                        step=encode === batch_qubit_encoding ? 1e-6 : 1e-3) atol=2e-4
                end
            end
        end

        values = copy(angles)
        output, back = MOSSQuantum._batch_qubit_encoding_adjoint(ComplexF64, values)
        @test output ≈ batch_qubit_encoding(values)
        seed = randn(rng, ComplexF64, size(storage(output)))
        expected = back(seed)
        values .= 5
        storage(output) .= 7
        @test back(seed) ≈ expected
        @test back(2 .* seed) ≈ 2 .* expected
        gradient = back(seed)
        gradient .= 9
        @test back(seed) ≈ expected
        @test back(nothing) == zeros(size(values))
        @test_throws DimensionMismatch back(zeros(4, 2))
        @test_throws ArgumentError back(ones(4))

        for dims in ((2, 0), (0, 3), (0, 0))
            values = zeros(Float32, dims)
            loss(values) = sum(abs2, storage(batch_qubit_encoding(ComplexF32, values)))
            gradient = Zygote.gradient(loss, values)[1]
            @test size(gradient) == dims
            @test eltype(gradient) === Float32
            @test gradient == zeros(Float32, dims)
            @test size(storage(batch_qubit_encoding(values))) == (2^dims[1], dims[2])
        end
        @test_throws ArgumentError MOSSQuantum._batch_qubit_encoding_adjoint(ComplexF64, fill(Inf, 1, 1))

        # The batch rule reuses this single-sample reverse pass. Its retained
        # forward state must survive more than one invocation as well.
        _, single_back = MOSSQuantum._qubit_encoding_adjoint(ComplexF64, [0.12, -0.21])
        single_seed = randn(rng, ComplexF64, 4)
        single_gradient = single_back(single_seed)[2]
        @test single_back(single_seed)[2] ≈ single_gradient
        @test single_back(2 .* single_seed)[2] ≈ 2 .* single_gradient
    end

    @testset "Prepared pullbacks retain independent snapshots" begin
        circuit = copy_instruction(template)
        batch = copy(initial)
        output, back = MOSSQuantum._batch_circuit_adjoint(circuit, batch)
        seed = randn(rng, ComplexF64, size(storage(output)))
        first_parameters, first_state = back(seed)
        @test back(2 .* seed)[1] ≈ 2 .* first_parameters
        @test storage(back(2 .* seed)[2]) ≈ 2 .* storage(first_state)
        storage(batch) .= 0
        storage(output) .= 0
        reset_parameters!(circuit, [1.0, 2.0, 3.0])
        @test back(seed)[1] ≈ first_parameters
        @test back(seed)[2] ≈ first_state
        first_parameters .= 9
        storage(first_state) .= 7
        @test back(seed)[1] != first_parameters
        @test back(seed)[2] != first_state
        @test back(nothing)[1] == zeros(3)
        @test iszero(norm(storage(back(nothing)[2])))
        @test_throws DimensionMismatch back(zeros(4, 2))
        @test_throws ArgumentError back(zeros(4))

        observed = QubitsTerm(1 => [1.0 0; 0 -1])
        batch = BatchStateVector(1, 2)
        values, expectation_back = MOSSQuantum._batch_expectation_adjoint(observed, batch)
        expected = copy(expectation_back([0.2, -0.7])[2])
        storage(batch) .= 0
        values .= 99
        oplist(observed)[1] .= 0
        @test expectation_back([0.2, -0.7])[2] ≈ expected
        gradient = expectation_back([0.2, -0.7])[2]
        storage(gradient) .= 9
        @test expectation_back([0.2, -0.7])[2] ≈ expected
        @test_throws DimensionMismatch expectation_back([1.0])
        @test_throws ArgumentError expectation_back(1.0)
        @test iszero(norm(storage(expectation_back(nothing)[2])))
    end

    @testset "Empty batches, zero-qubit states and explicit limits" begin
        circuit = QCircuit([RyGate(1, 0.2; isparas=true)])
        empty = BatchStateVector(1, 0)
        loss(circuit) = real(sum(expectation(z_observable, circuit * empty)))
        @test Zygote.gradient(loss, circuit)[1] == [0.0]
        empty_loss(values) = real(sum(expectation(z_observable, BatchStateVector(values))))
        @test size(Zygote.gradient(empty_loss, zeros(ComplexF64, 2, 0))[1]) == (2, 0)
        zero_qubit = BatchStateVector(zeros(ComplexF64, 1, 2), 0)
        output, back = MOSSQuantum._batch_circuit_adjoint(QCircuit(), zero_qubit)
        @test output == zero_qubit
        @test isempty(back(ones(1, 2))[1])
        @test storage(back(ones(1, 2))[2]) == ones(1, 2)
        for instruction in (QMeasure(1), QSelect(1),
                            QuantumGate(1, [1.0 0; 0 0.5]))
            for rejected in (QCircuit([instruction]), QCircuit([QCircuit([instruction])]))
                @test_throws ArgumentError MOSSQuantum._batch_circuit_adjoint(rejected, BatchStateVector(1, 2))
            end
        end
    end
end
