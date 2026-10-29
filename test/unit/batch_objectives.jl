using Test, LinearAlgebra, Random, MOSSQuantum
using MOSSQuantum: BatchExpectationObjective, evaluate_batch

module BatchObjectiveFixtures
import MOSSQuantum

const FORWARDS = Ref(0)
const BATCH_FORWARDS = Ref(0)
const REVERSES = Ref(0)

struct Rotation <: MOSSQuantum.ParametricGate{1}
    angle::Float64
    failure::Symbol
end
MOSSQuantum.positions(::Rotation) = (1,)
MOSSQuantum.parameters(gate::Rotation) = [gate.angle]
MOSSQuantum.active_parameters(gate::Rotation) = [gate.angle]
MOSSQuantum.reset_parameters!(gate::Rotation, values::AbstractVector{<:Real}) = Rotation(only(values), gate.failure)
function MOSSQuantum.mat(gate::Rotation)
    gate.angle > 0.5 && gate.failure === :shape && return ones(3, 3)
    gate.angle > 0.5 && gate.failure === :nonunitary && return [1.0 0.0; 0.0 2.0]
    return [cos(gate.angle / 2) -sin(gate.angle / 2); sin(gate.angle / 2) cos(gate.angle / 2)]
end
function MOSSQuantum.differentiate(gate::Rotation)
    gate.angle > 0.5 && gate.failure === :derivative && return [MOSSQuantum.QuantumGate(1, ones(3, 3))]
    return [MOSSQuantum.QuantumGate(1, [0.0 0.5; -0.5 0.0])]
end
function MOSSQuantum.apply!(gate::Rotation, state::MOSSQuantum.StateVector)
    FORWARDS[] += 1
    return MOSSQuantum.apply!(MOSSQuantum.QuantumGate(1, MOSSQuantum.mat(gate)), state)
end
function MOSSQuantum.apply!(gate::Rotation, state::MOSSQuantum.BatchStateVector)
    BATCH_FORWARDS[] += 1
    return MOSSQuantum.apply!(MOSSQuantum.QuantumGate(1, MOSSQuantum.mat(gate)), state)
end
function MOSSQuantum.apply!(gate::MOSSQuantum.AdjointQuantumGate{1,G}, state::MOSSQuantum.StateVector) where {G<:Rotation}
    REVERSES[] += 1
    return MOSSQuantum.apply!(MOSSQuantum.QuantumGate(1, MOSSQuantum.mat(gate)), state)
end

struct ForwardBackend <: MOSSQuantum.AbstractBackend end
MOSSQuantum.supports(::ForwardBackend, operation, state::MOSSQuantum.BatchStateVector; action::Symbol=:apply) =
    MOSSQuantum.supports(MOSSQuantum.CPUBackend(), operation, state; action=action)
MOSSQuantum.supports(::ForwardBackend, operation::MOSSQuantum.QCircuit, state::MOSSQuantum.BatchStateVector; action::Symbol=:apply) =
    MOSSQuantum.supports(MOSSQuantum.CPUBackend(), operation, state; action=action)
MOSSQuantum.apply!(::ForwardBackend, circuit::MOSSQuantum.QCircuit, state::MOSSQuantum.BatchStateVector) =
    MOSSQuantum.apply!(MOSSQuantum.CPUBackend(), circuit, state)
MOSSQuantum.expectation(::ForwardBackend, observable, state::MOSSQuantum.BatchStateVector) =
    MOSSQuantum.expectation(MOSSQuantum.CPUBackend(), observable, state)
struct NoGradient <: MOSSQuantum.AbstractGradientMethod end
end

function _batch_objective_difference(objective, values; step=1e-6)
    return map(eachindex(values)) do index
        plus, minus = copy(values), copy(values)
        plus[index] += step
        minus[index] -= step
        (evaluate(objective, plus) - evaluate(objective, minus)) / (2step)
    end
end

@testset "Shared-parameter batch scalar objectives" begin
    method = AdjointGradient()
    F = BatchObjectiveFixtures
    initial = BatchStateVector([StateVector(ComplexF64[1, 0]), StateVector(ComplexF64[0, 1]),
        StateVector(normalize(ComplexF64[1, 1]))])
    observable = QubitsTerm(1 => "Z")
    template = QCircuit([RyGate(1, 0.0; isparas=true)])

    @testset "Sample order and explicit scalar reductions" begin
        angle = 0.31
        expected_values = [cos(angle), -cos(angle), -sin(angle)]
        expected_gradients = [-sin(angle), sin(angle), -cos(angle)]
        weights = Real[2, -1.0, 1 // 2]
        for (reduction, supplied, coefficients) in ((:mean, nothing, fill(1 / 3, 3)),
                (:sum, nothing, ones(3)), (:weighted_sum, weights, weights))
            objective = BatchExpectationObjective(template, observable, initial;
                reduction=reduction, weights=supplied)
            @test evaluate_batch(objective, [angle]) ≈ expected_values
            @test evaluate(objective, [angle]) ≈ dot(coefficients, expected_values)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, [angle])
            @test value ≈ dot(coefficients, expected_values)
            @test gradient ≈ [dot(coefficients, expected_gradients)]
            @test gradient ≈ _batch_objective_difference(objective, [angle]) atol=1e-8
            @test differentiable_value(F.NoGradient(), objective, [angle]) ≈ value
            @test_throws UnsupportedGradient value_and_gradient(F.NoGradient(), objective, [angle])
            @test objective.initial_state == initial
        end
        single = BatchExpectationObjective(template, observable, BatchStateVector(StateVector(1)))
        @test evaluate_batch(single, [angle]) ≈ [cos(angle)]
        @test value_and_gradient(method, single, [angle])[2] ≈ [-sin(angle)]
    end

    @testset "Complex states, nested shared parameters, and reference sample loop" begin
        batch = rand_batch(MersenneTwister(907), 2, 4)
        circuit = QCircuit([RyGate(1, 0.0; isparas=true), CNOTGate(1, 2),
            QCircuit([RzGate(2, 0.0; isparas=true), RxGate(1, 0.0; isparas=true)])])
        parameter_map = ParameterMap(circuit, [1, 2, 1])
        operator = QubitsOperator(QubitsTerm(1 => "Y"; coeff=0.3),
            QubitsTerm(1 => "X", 2 => "Z"; coeff=-0.2), QubitsTerm(2 => "Z"; coeff=0.4))
        values = [0.24, -0.37]
        for observation in (QubitsTerm(1 => "Z"), operator),
                (reduction, weights) in ((:mean, nothing), (:sum, nothing), (:weighted_sum, [2.0, 0.0, -0.5, 1.0]))
            objective = BatchExpectationObjective(circuit, observation, batch;
                parameter_map=parameter_map, reduction=reduction, weights=weights)
            reference = [value_and_gradient(method,
                ExpectationObjective(circuit, observation, StateVector(batch, index); parameter_map=parameter_map), values)
                for index in 1:batch_size(batch)]
            coefficients = reduction === :mean ? fill(0.25, 4) : reduction === :sum ? ones(4) : weights
            expected_gradient = sum(coefficients[index] * last(reference[index]) for index in 1:4)
            value, gradient = value_and_gradient(method, objective, values)
            @test evaluate_batch(objective, values) ≈ first.(reference)
            @test value ≈ dot(coefficients, first.(reference))
            @test value ≈ evaluate(objective, values)
            @test gradient ≈ expected_gradient
            @test gradient ≈ _batch_objective_difference(objective, values) atol=1e-8
            @test active_parameters(circuit) == zeros(3)
        end
    end

    @testset "Configuration ownership and reusable pullback snapshots" begin
        circuit = QCircuit([F.Rotation(0.1, :valid)])
        observation = QubitsTerm(1 => [1.0 0.0; 0.0 -1.0])
        states = BatchStateVector(initial)
        weights = [2.0, -1.0, 0.5]
        objective = BatchExpectationObjective(circuit, observation, states; reduction=:weighted_sum, weights=weights)
        values = [0.3]
        expected_gradient = [-3sin(0.3) - 0.5cos(0.3)]
        F.FORWARDS[] = F.BATCH_FORWARDS[] = F.REVERSES[] = 0
        @test supports_gradient(method, objective)
        @test F.FORWARDS[] == F.BATCH_FORWARDS[] == F.REVERSES[] == 0
        value, back = value_and_pullback(method, objective, values)
        @test value ≈ 3cos(0.3) - 0.5sin(0.3)
        @test F.FORWARDS[] == 0 && F.BATCH_FORWARDS[] == 1
        @test F.REVERSES[] == 0
        @test back(0.0) == [0.0]
        @test F.REVERSES[] == 0
        @test back(1.0) ≈ expected_gradient
        @test back(-2.0) ≈ -2expected_gradient
        previous = back(1.0)
        previous .= 99
        @test back(1.0) ≈ expected_gradient
        @test F.FORWARDS[] == 0 && F.BATCH_FORWARDS[] == 1

        # Construction owns every input, and preparation owns the point even
        # when the objective's public mutable components are edited later.
        weights .= 9
        resize!(values, 2)
        values .= 9
        storage(states) .= 0
        oplist(observation)[1] .= 0
        circuit[1] = XGate(1)
        @test objective.weights == (2.0, -1.0, 0.5)
        @test objective.initial_state == initial
        @test evaluate(objective, [0.3]) ≈ value
        storage(objective.initial_state) .= 0
        oplist(objective.observable)[1] .= 0
        objective.template[1] = XGate(1)
        @test back(1.0) ≈ expected_gradient
        @test back(-2.0) ≈ -2expected_gradient
    end

    @testset "Interleaved evaluations and independent reverse workspaces" begin
        objective = BatchExpectationObjective(template, observable, initial; reduction=:sum)
        points = [[0.2], [-0.4], [0.7]]
        expected = [value_and_gradient(method, objective, point) for point in points]
        first_value, first_back = value_and_pullback(method, objective, points[1])
        @test evaluate(objective, points[2]) ≈ first(expected[2])
        last_value, last_back = value_and_pullback(method, objective, points[3])
        @test first_value ≈ first(expected[1])
        @test last_value ≈ first(expected[3])
        @test first_back(1.0) ≈ last(expected[1])
        @test last_back(-2.0) ≈ -2last(expected[3])
        @test first_back(-2.0) ≈ -2last(expected[1])
        tasks = map(points) do point
            Threads.@spawn begin
                value, back = value_and_pullback(method, objective, point)
                yield()
                gradient = back(1.0)
                gradient .= 99
                yield()
                (value, back(1.0), back(-2.0))
            end
        end
        for (index, task) in enumerate(tasks)
            value, gradient, scaled = fetch(task)
            @test value ≈ first(expected[index])
            @test gradient ≈ last(expected[index])
            @test scaled ≈ -2last(expected[index])
        end
        @test objective.initial_state == initial
    end

    @testset "Empty parameter vectors, constants, and input scalar domains" begin
        constant = QubitsTerm(Int[], Matrix{Float64}[], 2.0)
        for observation in (observable, constant)
            objective = BatchExpectationObjective(QCircuit(), observation, initial)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, Float64[])
            @test value ≈ evaluate(objective, Float64[])
            @test isempty(gradient)
            @test isempty(value_and_pullback(method, objective, Real[])[2](0))
        end
        objective = BatchExpectationObjective(template, observable, initial)
        for values in (Float32[0.2], Real[0.2], BigFloat[0.2], view([9.0, 0.2, 9.0], 2:2))
            saved = copy(values)
            value, gradient = value_and_gradient(method, objective, values)
            @test value isa Real
            @test gradient isa AbstractVector{<:Real}
            @test value ≈ -sin(Float64(only(values))) / 3
            @test gradient ≈ [-cos(Float64(only(values))) / 3]
            @test values == saved
        end
        @test_throws DimensionMismatch evaluate(objective, Float64[])
        @test_throws DimensionMismatch value_and_gradient(method, objective, Float64[])
        @test_throws ArgumentError evaluate_batch(objective, [NaN])
        @test_throws ArgumentError value_and_pullback(method, objective, [Inf])
    end

    @testset "Validation and forward support are independent of gradient support" begin
        @test_throws ArgumentError BatchExpectationObjective(template, observable, BatchStateVector(1, 0))
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial; reduction=:median)
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial; weights=ones(3))
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial; reduction=:weighted_sum)
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial;
            reduction=:weighted_sum, weights=ComplexF64[1, 1, 1])
        @test_throws DimensionMismatch BatchExpectationObjective(template, observable, initial;
            reduction=:weighted_sum, weights=ones(2))
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial;
            reduction=:weighted_sum, weights=[1.0, NaN, 1.0])
        @test_throws ArgumentError BatchExpectationObjective(template, observable, initial;
            reduction=:weighted_sum, weights=[1.0, Inf, 1.0])
        @test_throws DimensionMismatch BatchExpectationObjective(template, observable, initial;
            parameter_map=ParameterMap(Int[]))

        foreign = BatchExpectationObjective(template, observable, initial; backend=F.ForwardBackend())
        @test evaluate(foreign, [0.2]) ≈ -sin(0.2) / 3
        @test !supports_gradient(method, foreign)
        @test_throws UnsupportedGradient value_and_pullback(method, foreign, [0.2])
        matrix_observation = BatchExpectationObjective(template, [1.0 0.0; 0.0 -1.0], initial)
        @test evaluate(matrix_observation, [0.2]) ≈ -sin(0.2) / 3
        @test !supports_gradient(method, matrix_observation)
        nonunitary = BatchExpectationObjective(QCircuit([QuantumGate(1, [1.0 0.0; 0.0 2.0])]), observable, initial)
        @test evaluate(nonunitary, Float64[]) isa Real
        @test !supports_gradient(method, nonunitary)

        noisy = BatchExpectationObjective(QCircuit([AmplitudeDamping(1; γ=0.2)]), observable, initial)
        @test supports_gradient(method, noisy)
        @test isempty(value_and_gradient(method, noisy, Float64[])[2])
        nonhermitian_noise = BatchExpectationObjective(QCircuit([AmplitudeDamping(1; γ=0.2)]),
            QubitsTerm(1 => "+"), initial)
        @test !supports_gradient(method, nonhermitian_noise)
        @test_throws UnsupportedGradient value_and_gradient(method, nonhermitian_noise, Float64[])
        for circuit in (QCircuit([QMeasure(1)]), QCircuit([QSelect(1)])),
                observation in (observable, QubitsTerm(1 => "+"))
            objective = BatchExpectationObjective(circuit, observation, initial)
            @test !supports_gradient(method, objective)
            @test_throws UnsupportedGradient value_and_gradient(method, objective, Float64[])
        end
        @test !supports_gradient(method, ExpectationObjective(template, observable, initial))

        # Invalid late instructions or observables must fail before any forward.
        for failure in (:shape, :nonunitary, :derivative)
            circuit = QCircuit([F.Rotation(0.1, :valid), F.Rotation(0.1, failure)])
            objective = BatchExpectationObjective(circuit, observable, initial)
            F.FORWARDS[] = F.BATCH_FORWARDS[] = 0
            @test supports_gradient(method, objective)
            @test_throws UnsupportedGradient value_and_pullback(method, objective, [0.2, 0.8])
            @test F.FORWARDS[] == F.BATCH_FORWARDS[] == 0
            if failure === :shape
                @test_throws DimensionMismatch evaluate_batch(objective, [0.2, 0.8])
                @test F.BATCH_FORWARDS[] == 0
            end
        end
        F.BATCH_FORWARDS[] = 0
        invalid_observation = BatchExpectationObjective(QCircuit([F.Rotation(0.1, :valid)]), QubitsTerm(2 => "Z"), initial)
        @test_throws ArgumentError evaluate(invalid_observation, [0.2])
        @test F.BATCH_FORWARDS[] == 0
    end
end
