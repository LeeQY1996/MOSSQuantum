using Test, MOSSQuantum, LinearAlgebra, Random

function _batch_density_objective_difference(objective, values; step=1e-6)
    return map(eachindex(values)) do index
        plus, minus = copy(values), copy(values)
        plus[index] += step
        minus[index] -= step
        (evaluate(objective, plus) - evaluate(objective, minus)) / (2step)
    end
end

@testset "Batch mixed-state objectives and fixed channels" begin
    rng = MersenneTwister(195)
    pure = rand_batch(rng, 2, 3)
    mixed = rand_batch_densitymatrix(rng, 2, 3)
    method = AdjointGradient()
    parameters = [0.23, -0.37]
    observable = QubitsTerm(1 => "Y"; coeff=0.7) + QubitsTerm(2 => "Z"; coeff=-0.2)
    unitary = QCircuit([RyGate(1, 0.0; isparas=true),
        QCircuit([RzGate(2, 0.0; isparas=true), CNOTGate(1, 2)]),
        RxGate(1, 0.0; isparas=true)])
    noisy = QCircuit([RyGate(1, 0.0; isparas=true),
        QCircuit([AmplitudeDamping(1; γ=0.31), RzGate(2, 0.0; isparas=true),
            CNOTGate(1, 2), PhaseDamping(2; γ=1.0)]), RxGate(1, 0.0; isparas=true)])
    map = ParameterMap([1, 2, 1])
    weights = [0.3, 0.0, -0.8]
    for initial in (pure, mixed), circuit in (unitary, noisy),
            reduction in (:sum, :mean, :weighted_sum)
        supplied = reduction === :weighted_sum ? weights : nothing
        objective = BatchExpectationObjective(circuit, observable, initial;
            parameter_map=map, reduction=reduction, weights=supplied)
        @test supports_gradient(method, objective)
        coefficients = reduction === :mean ? fill(1 / 3, 3) : reduction === :sum ? ones(3) : weights
        reference = [value_and_gradient(method, ExpectationObjective(circuit, observable,
            initial isa BatchStateVector ? StateVector(initial, b) : DensityMatrix(initial, b);
            parameter_map=map), parameters) for b in 1:3]
        value, gradient = value_and_gradient(method, objective, parameters)
        @test evaluate_batch(objective, parameters) ≈ first.(reference)
        @test evaluate(objective, parameters) ≈ value
        @test value ≈ dot(coefficients, first.(reference))
        @test gradient ≈ sum(coefficients[b] .* reference[b][2] for b in 1:3)
        @test gradient ≈ _batch_density_objective_difference(objective, parameters) atol=1e-7
        @test initial ≈ (initial isa BatchStateVector ? pure : mixed)
    end

    @testset "Singular noise and analytic derivative" begin
        for initial in (BatchStateVector(1, 2), BatchDensityMatrix(1, 2)), damping in (0.2, 1.0)
            circuit = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=damping)])
            objective = BatchExpectationObjective(circuit, QubitsTerm(1 => "Z"), initial)
            value, gradient = value_and_gradient(method, objective, [0.41])
            @test value ≈ damping + (1 - damping) * cos(0.41)
            @test gradient ≈ [-(1 - damping) * sin(0.41)] atol=1e-10
            @test supports_gradient(method, objective)
        end
        initial = BatchDensityMatrix(reshape([0.7 0.1; 0.1 0.3], 2, 2, 1))
        objective = BatchExpectationObjective(QCircuit([RxGate(1, 0.0; isparas=true)]),
            QubitsTerm(1 => "Y"), initial)
        @test value_and_gradient(method, objective, [0.19])[2] ≈
            _batch_density_objective_difference(objective, [0.19]) atol=1e-8
    end

    @testset "Prepared noisy pullbacks own their snapshots" begin
        for initial in (pure, mixed)
            objective = BatchExpectationObjective(noisy, observable, initial;
                parameter_map=map, reduction=:weighted_sum, weights=weights)
            values = copy(parameters)
            value, back = value_and_pullback(method, objective, values)
            expected = back(1.0)
            _, other = value_and_pullback(method, objective, [-0.17, 0.32])
            @test other(1.0) ≈ value_and_gradient(method, objective, [-0.17, 0.32])[2]
            @test back(0.0) == zeros(2)
            @test back(-2.0) ≈ -2 .* expected
            returned = back(1.0)
            returned .= 99
            values .= 8
            storage(objective.initial_state) .= 0
            objective.template[1] = XGate(1)
            for (_, terms) in objective.observable.data, (operators, _) in terms, operator in operators
                operator .= 0
            end
            @test back(1.0) ≈ expected
            @test back(-2.0) ≈ -2 .* expected
            @test value isa Real
        end
    end

    @testset "Empty parameters, zero qubits, and gradient limits" begin
        constant = QubitsTerm(Int[], Matrix{Float64}[], 2.5)
        objective = BatchExpectationObjective(QCircuit(), constant, BatchDensityMatrix(0, 2))
        @test evaluate_batch(objective, Float64[]) == [2.5, 2.5]
        @test value_and_gradient(method, objective, Float64[]) == (2.5, Float64[])
        @test_throws ArgumentError BatchExpectationObjective(QCircuit(), constant, BatchDensityMatrix(0, 0))
        for operation in (QMeasure(1), QSelect(1)), state in (pure, mixed)
            objective = BatchExpectationObjective(QCircuit([operation]), QubitsTerm(1 => "Z"), state)
            @test !supports_gradient(method, objective)
            @test_throws UnsupportedGradient value_and_gradient(method, objective, Float64[])
        end
        nonhermitian = BatchExpectationObjective(noisy, QubitsTerm(1 => "+"), mixed; parameter_map=map)
        @test evaluate(nonhermitian, parameters) isa Real
        @test !supports_gradient(method, nonhermitian)
        matrix_objective = BatchExpectationObjective(noisy, matrix(2, observable), pure; parameter_map=map)
        @test evaluate_batch(matrix_objective, parameters) ≈ evaluate_batch(
            BatchExpectationObjective(noisy, observable, pure; parameter_map=map), parameters)
        @test !supports_gradient(method, matrix_objective)
    end
end
