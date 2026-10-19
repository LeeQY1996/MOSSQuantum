using Test, MOSS, LinearAlgebra, Random

function _workspace_objective_difference(objective, values; step=1e-6)
    return map(eachindex(values)) do i
        plus, minus = copy(values), copy(values)
        plus[i] += step
        minus[i] -= step
        (evaluate(objective, plus) - evaluate(objective, minus)) / (2step)
    end
end

@testset "Density reverse workspaces remain private to each call" begin
    rng = MersenneTwister(20261020)
    method = AdjointGradient()
    for n in (2, 3), noisy in (false, true)
        nested = QCircuit([FSIMGate((n, 1), zeros(5); isparas=fill(true, 5)),
            RzGate(n, 0.0; isparas=true)])
        prefix = QCircuit([RyGate(1, 0.0; isparas=true)])
        if noisy
            push!(prefix, AmplitudeDamping(1; γ=1.0))
            push!(nested, PhaseDamping(n; γ=0.3))
        end
        circuit = QCircuit([prefix, nested, RxGate(1, 0.17), RyGate(1, 0.0; isparas=true)])
        map = ParameterMap(circuit, [1, 2, 3, 4, 5, 6, 7, 1])
        values = [0.21, -0.3, 0.16, -0.11, 0.32, -0.27, 0.4]
        observed = QubitsTerm(1 => "Y"; coeff=0.3) + QubitsTerm(n => "Z"; coeff=-0.7)
        initial = rand_batch_densitymatrix(rng, n, 3)
        objective = BatchExpectationObjective(circuit, observed, initial;
            parameter_map=map, reduction=:weighted_sum, weights=[0.3, -0.7, 1.2])
        expected = _workspace_objective_difference(objective, values)
        value, back = value_and_pullback(method, objective, values)
        @test value ≈ evaluate(objective, values)
        @test back(1.0) ≈ expected atol=2e-7
        @test back(-0.5) ≈ -0.5 .* expected atol=2e-7
        @test back(0.0) == zeros(length(values))
        returned = back(1.0)
        returned .= 99
        @test back(1.0) ≈ expected atol=2e-7

        # A different point and pullback must not overwrite the earlier one.
        other_values = values .+ 0.07
        other_expected = _workspace_objective_difference(objective, other_values)
        _, other_back = value_and_pullback(method, objective, other_values)
        @test other_back(1.0) ≈ other_expected atol=2e-7
        @test back(1.0) ≈ expected atol=2e-7
        jobs = [Threads.@spawn begin
            yield()
            (scale, back(scale), other_back(scale))
        end for scale in (1.0, -2.0, 0.5)]
        results = fetch.(jobs)
        for (scale, gradient, other_gradient) in results
            @test gradient ≈ scale .* expected atol=5e-7
            @test other_gradient ≈ scale .* other_expected atol=5e-7
        end
        @test !Base.mightalias(results[1][2], results[2][2])
        @test !Base.mightalias(results[1][2], results[1][3])
        values .= 8
        storage(objective.initial_state) .= 0
        objective.template[1] = XGate(1)
        empty!(objective.observable.data)
        @test back(1.0) ≈ expected atol=2e-7
        @test other_back(-2.0) ≈ -2.0 .* other_expected atol=5e-7

        # Single-density adapters use the same scratch path, with independently
        # allocated workspaces on every numerical pullback application.
        single = ExpectationObjective(circuit, observed, DensityMatrix(initial, 1);
            parameter_map=map)
        single_values = [0.21, -0.3, 0.16, -0.11, 0.32, -0.27, 0.4]
        single_expected = _workspace_objective_difference(single, single_values)
        _, single_back = value_and_pullback(method, single, single_values)
        @test single_back(1.0) ≈ single_expected atol=2e-7
        @test single_back(-2.0) ≈ -2.0 .* single_expected atol=5e-7
    end

    @testset "Channel checkpoints restore an earlier arithmetic domain" begin
        circuit = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=0.2),
            RzGate(1, 0.0; isparas=true), RyGate(1, 0.0; isparas=true)])
        observed = QubitsTerm(1 => "X"; coeff=0.7) + QubitsTerm(1 => "Z"; coeff=-0.2)
        values = [0.2, -0.4, 0.3]
        for T in (Float32, Float64, ComplexF64)
            initial = DensityMatrix(reshape(T[0.7, 0.1, 0.1, 0.3], 2, 2))
            objective = ExpectationObjective(circuit, observed, initial)
            step = T === Float32 ? 1e-3 : 1e-6
            expected = _workspace_objective_difference(objective, values; step=step)
            _, back = value_and_pullback(method, objective, values)
            tolerance = T === Float32 ? 1e-4 : 1e-8
            @test back(1.0) ≈ expected atol=tolerance
            @test back(-2.0) ≈ -2.0 .* expected atol=2tolerance
            @test back(1.0) ≈ expected atol=tolerance
        end
    end
end
