using Test, MOSS, Zygote, FiniteDifferences, Random

@testset "Shared circuit parameter gradients" begin
    @testset "Noncommuting analytic circuit" begin
        template = QCircuit([RyGate(1, 0.1; isparas=true),
            QCircuit([RzGate(1, 0.2; isparas=true)]), RyGate(1, 0.3; isparas=true)])
        map = ParameterMap(template, [1, 2, 1])
        initial = StateVector(1)
        observable = QubitsTerm(1 => "Z")
        values = [0.31, -0.42]
        θ, φ = values
        analytic_loss = cos(θ)^2 - sin(θ)^2 * cos(φ)
        analytic_gradient = [-sin(2θ) * (1 + cos(φ)), sin(θ)^2 * sin(φ)]
        loss(parameters) = real(expectation(observable,
            bind_parameters(template, parameters, map) * initial))
        @test loss(values) ≈ analytic_loss
        @test Zygote.gradient(loss, values)[1] ≈ analytic_gradient atol=1e-10
        @test Zygote.gradient(loss, values)[1] ≈
            FiniteDifferences.grad(FiniteDifferences.central_fdm(5, 1), loss, values)[1] atol=1e-8
        @test loss(values - 0.1 .* analytic_gradient) < loss(values)

        # A map supplied as an argument has no trainable cotangent. Value
        # contributions from separate bindings still accumulate through AD.
        mapped_loss(parameters, mapping) = real(expectation(observable,
            bind_parameters(template, parameters, mapping) * initial))
        value_gradient, map_gradient = Zygote.gradient(mapped_loss, values, map)
        @test value_gradient ≈ analytic_gradient
        @test map_gradient === nothing
        twice(parameters) = loss(parameters) + mapped_loss(parameters, map)
        @test Zygote.gradient(twice, values)[1] ≈ 2 .* analytic_gradient
        @test active_parameters(template) == [0.1, 0.2, 0.3]
        @test values == [0.31, -0.42]
    end

    @testset "Cancellation across an adjoint pair" begin
        gate = RyGate(1, 0.13; isparas=true)
        template = QCircuit([gate, gate'])
        map = ParameterMap([1, 1])
        observable = QubitsTerm(1 => "X")
        initial = StateVector(1)
        slot_loss(parameters) = real(expectation(observable,
            bind_parameters(template, parameters) * initial))
        loss(parameters) = real(expectation(observable,
            bind_parameters(template, parameters, map) * initial))
        @test Zygote.gradient(slot_loss, [0.3, 0.3])[1] ≈ [1.0, -1.0] atol=1e-10
        @test Zygote.gradient(loss, [0.3])[1] ≈ [0.0] atol=1e-10
        @test loss([0.3]) ≈ 0.0 atol=1e-10
    end

    @testset "Mixed states and noninvertible fixed channels" begin
        template = QCircuit([RyGate(1, 0.1; isparas=true),
            CRyGate(1, 2, 0.2; isparas=true), AmplitudeDamping(2; γ=0.27),
            QCircuit([RxGate(2, 0.3; isparas=true), RzGate(1, 0.4; isparas=true)'])])
        map = ParameterMap([2, 1, 2, 1])
        values = [0.43, -0.27]
        observable = QubitsTerm(1 => "X", 2 => "Y")
        pure = rand_state(MersenneTwister(402), 2)
        for initial in (pure, DensityMatrix(pure))
            original = copy(initial)
            loss(parameters) = real(expectation(observable,
                bind_parameters(template, parameters, map) * initial))
            slot_loss(parameters) = real(expectation(observable,
                bind_parameters(template, parameters) * initial))
            gradient = Zygote.gradient(loss, values)[1]
            expanded = values[parameter_indices(map)]
            slot_gradient = Zygote.gradient(slot_loss, expanded)[1]
            finite_difference = FiniteDifferences.grad(FiniteDifferences.central_fdm(5, 1), loss, values)[1]
            @test gradient ≈ accumulate_parameter_gradients(map, slot_gradient) atol=1e-10
            @test gradient ≈ finite_difference atol=1e-8
            @test all(isfinite, gradient)
            @test any(abs.(gradient) .> 1e-5)
            @test initial == original
        end
    end

    @testset "Value projections and empty maps" begin
        template = QCircuit([RyGate(1, 0.1; isparas=true), RyGate(1, 0.2; isparas=true)])
        map = ParameterMap([1, 1])
        observable = QubitsTerm(1 => "Z")
        loss(parameters) = real(expectation(observable,
            bind_parameters(template, parameters, map) * StateVector(1)))
        for values in (Float32[0.2], [0.2], view([0.2, 9.0], 1:2:1))
            original = copy(values)
            gradient = Zygote.gradient(loss, values)[1]
            @test gradient ≈ [-2sin(2values[1])]
            @test eltype(gradient) === eltype(values)
            @test size(gradient) == size(values)
            @test values == original
        end
        frozen = QCircuit([RyGate(1, 0.23)])
        empty_map = ParameterMap(frozen)
        frozen_loss(parameters) = real(expectation(observable,
            bind_parameters(frozen, parameters, empty_map) * StateVector(1)))
        for values in (Float32[], Float64[])
            gradient = Zygote.gradient(frozen_loss, values)[1]
            @test isempty(gradient)
            @test eltype(gradient) === eltype(values)
            @test frozen_loss(values) ≈ cos(0.23)
        end
    end
end
