using Test, MOSSQuantum, Random, LinearAlgebra

module BatchNumericalGradientFixtures
import MOSSQuantum
const FORWARDS = Ref(0)
struct LimitedRotation <: MOSSQuantum.ParametricGate{1}
    angle::Float64
end
MOSSQuantum.positions(::LimitedRotation) = (1,)
MOSSQuantum.parameters(gate::LimitedRotation) = [gate.angle]
MOSSQuantum.active_parameters(gate::LimitedRotation) = [gate.angle]
MOSSQuantum.reset_parameters!(::LimitedRotation, values::AbstractVector{<:Real}) = LimitedRotation(only(values))
MOSSQuantum.mat(gate::LimitedRotation) = gate.angle > 0.5 ? ones(3, 3) :
    [cos(gate.angle / 2) -sin(gate.angle / 2); sin(gate.angle / 2) cos(gate.angle / 2)]
MOSSQuantum.parameter_shift_rule(::LimitedRotation, ::Integer) = [(0.5, pi / 2), (-0.5, -pi / 2)]
function MOSSQuantum.apply!(gate::LimitedRotation, state::MOSSQuantum.BatchStateVector)
    FORWARDS[] += 1
    return MOSSQuantum.apply!(MOSSQuantum.QuantumGate(1, MOSSQuantum.mat(gate)), state)
end
struct ForwardBackend <: MOSSQuantum.AbstractBackend end
MOSSQuantum.supports(::ForwardBackend, operation, state::MOSSQuantum.BatchStateVector; action::Symbol=:apply) =
    MOSSQuantum.supports(MOSSQuantum.CPUBackend(), operation, state; action)
MOSSQuantum.supports(::ForwardBackend, operation::MOSSQuantum.QCircuit, state::MOSSQuantum.BatchStateVector; action::Symbol=:apply) =
    MOSSQuantum.supports(MOSSQuantum.CPUBackend(), operation, state; action)
MOSSQuantum.apply!(::ForwardBackend, circuit::MOSSQuantum.QCircuit, state::MOSSQuantum.BatchStateVector) =
    MOSSQuantum.apply!(MOSSQuantum.CPUBackend(), circuit, state)
MOSSQuantum.expectation(::ForwardBackend, observable, state::MOSSQuantum.BatchStateVector) =
    MOSSQuantum.expectation(MOSSQuantum.CPUBackend(), observable, state)
end

@testset "Batch parameter-shift and finite-difference gradients" begin
    rng = MersenneTwister(821)
    parameters = [0.23, -0.37]
    circuit = QCircuit([RyGate(1, 0.0; isparas=true), CNOTGate(1, 2),
        QCircuit([RzGate(2, 0.0; isparas=true), RxGate(1, 0.0; isparas=true)])])
    noisy = QCircuit([circuit, AmplitudeDamping(1; γ=0.31), PhaseDamping(2; γ=1.0)])
    observable = 0.7QubitsTerm(1 => "Y") - 0.2QubitsTerm(2 => "Z") + 0.13
    parameter_map = ParameterMap([1, 2, 1])
    for T in (Float32, Float64, ComplexF32, ComplexF64), B in (1, 3)
        pure = rand_batch(rng, T, 2, B)
        mixed = BatchDensityMatrix(pure)
        tolerance = T in (Float32, ComplexF32) ? 2e-4 : 1e-8
        step = T in (Float32, ComplexF32) ? 1e-2 : 1e-5
        for initial in (pure, mixed), program in (circuit, noisy),
                reduction in (:mean, :sum, :weighted_sum)
            weights = reduction === :weighted_sum ? [(-1)^b * (b - 1) for b in 1:B] : nothing
            objective = BatchExpectationObjective(program, observable, initial;
                parameter_map, reduction, weights)
            saved = copy(initial)
            coefficients = reduction === :mean ? fill(1 / B, B) : reduction === :sum ? ones(B) : weights
            reference = [value_and_gradient(AdjointGradient(), ExpectationObjective(program, observable,
                initial isa BatchStateVector ? StateVector(initial, b) : DensityMatrix(initial, b);
                parameter_map), parameters) for b in 1:B]
            expected_value = dot(coefficients, first.(reference))
            expected_gradient = sum(coefficients[b] .* reference[b][2] for b in 1:B)
            for method in (ParameterShift(), FiniteDifference(; step))
                @test supports_gradient(method, objective)
                @test supports_gradient(method, objective, parameters)
                value, gradient = value_and_gradient(method, objective, parameters)
                @test value ≈ expected_value atol=tolerance
                @test gradient ≈ expected_gradient atol=tolerance
                @test parameters == [0.23, -0.37]
                @test initial == saved
                @test objective.initial_state == saved
                @test active_parameters(objective.template) == zeros(3)
                result = estimate_gradient(method, objective, parameters)
                @test result.shots == required_shots(method, objective, parameters) == 0
                @test result.evaluations == (method isa ParameterShift ? 7 : 5)
                @test result.value_variance == 0
                @test result.sampling_covariance == zeros(2, 2)
            end
        end
    end

    @testset "Shared occurrences and symbolic affine parameters" begin
        theta, phi = Parameter(:theta), Parameter(:phi)
        symbolic = QCircuit([RyGate(1, 2theta + phi + pi / 7),
            QCircuit([RyGate(1, theta - phi)])])
        batch = BatchStateVector([StateVector(1), StateVector(ComplexF64[0, 1]),
            StateVector(normalize(ComplexF64[1, 1]))])
        for options in ((;), (; parameter_order=[phi, theta]), (; fixed=Dict(theta => 0.2)),
                (; fixed=Dict(theta => 0.2, phi => 0.3)))
            objective = BatchExpectationObjective(symbolic, QubitsTerm(1 => "Z"), batch;
                reduction=:weighted_sum, weights=[2.0, 0.0, -0.5], options...)
            values = haskey(options, :fixed) ? length(options.fixed) == 2 ? Float64[] : [0.3] :
                haskey(options, :parameter_order) ? [0.3, 0.2] : [0.2, 0.3]
            expected = value_and_gradient(AdjointGradient(), objective, values)
            for method in (ParameterShift(), FiniteDifference(step=1e-5))
                @test supports_gradient(method, objective)
                @test supports_gradient(method, objective, values)
                value, gradient = value_and_gradient(method, objective, values)
                @test value ≈ expected[1] atol=1e-10
                @test gradient ≈ expected[2] atol=1e-8
            end
        end
    end

    @testset "Singular channels, constants and reusable pullbacks" begin
        for initial in (BatchStateVector(1, 3), BatchDensityMatrix(1, 3)), damping in (0.2, 1.0),
                method in (ParameterShift(), FiniteDifference(step=1e-5))
            program = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=damping)])
            objective = BatchExpectationObjective(program, QubitsTerm(1 => "Z"), initial)
            values = [0.41]
            value, back = value_and_pullback(method, objective, values)
            expected = [-(1 - damping) * sin(0.41)]
            @test value ≈ damping + (1 - damping) * cos(0.41)
            @test back(1.0) ≈ expected atol=1e-8
            @test back(-2.0) ≈ -2 .* expected atol=1e-8
            @test back(0) == [0.0]
            returned = back(1.0)
            returned .= 99
            values .= 8
            storage(objective.initial_state) .= 0
            objective.template[1] = XGate(1)
            @test back(1.0) ≈ expected atol=1e-8
            tasks = [Threads.@spawn back(seed) for seed in (-2.0, 0.0, 1.0)]
            @test all(isapprox(fetch(task), seed .* expected; atol=1e-8)
                for (task, seed) in zip(tasks, (-2.0, 0.0, 1.0)))
        end
        constant = QubitsTerm(Int[], Matrix{Float64}[], 2.5)
        for initial in (BatchStateVector(0, 2), BatchDensityMatrix(0, 2)),
                method in (ParameterShift(), FiniteDifference())
            objective = BatchExpectationObjective(QCircuit(), constant, initial)
            @test value_and_gradient(method, objective, Float64[]) == (2.5, Float64[])
            @test estimate_gradient(method, objective, Float64[]).evaluations == 1
        end
    end

    @testset "Forward-only backend and real parts of observables" begin
        program = QCircuit([RyGate(1, 0.0; isparas=true)])
        pure = BatchStateVector(1, 2)
        for initial in (pure, BatchDensityMatrix(pure)),
                observation in (QubitsTerm(1 => "+"), [0.0 1.0; 0.0 0.0]),
                method in (ParameterShift(), FiniteDifference(step=1e-5))
            objective = BatchExpectationObjective(program, observation, initial)
            @test supports_gradient(method, objective, [0.3])
            value, gradient = value_and_gradient(method, objective, [0.3])
            @test value ≈ sin(0.3) / 2 atol=1e-10
            @test gradient ≈ [cos(0.3) / 2] atol=1e-8
        end
        foreign = BatchExpectationObjective(program, QubitsTerm(1 => "Z"), pure;
            backend=BatchNumericalGradientFixtures.ForwardBackend())
        for method in (ParameterShift(), FiniteDifference(step=1e-5))
            @test supports_gradient(method, foreign, [0.3])
            value, gradient = value_and_gradient(method, foreign, [0.3])
            @test value ≈ cos(0.3) atol=1e-10
            @test gradient ≈ [-sin(0.3)] atol=1e-8
        end
    end

    @testset "Validation, unsupported recipes and early rejection" begin
        initial = BatchStateVector(2, 3)
        for operation in (QMeasure(1), QSelect(1)), method in (ParameterShift(), FiniteDifference())
            objective = BatchExpectationObjective(QCircuit([operation]), QubitsTerm(1 => "Z"), initial)
            @test !supports_gradient(method, objective)
            @test !supports_gradient(method, objective, Float64[])
            @test_throws UnsupportedGradient value_and_gradient(method, objective, Float64[])
        end
        objective = BatchExpectationObjective(circuit, observable, initial; parameter_map)
        for method in (ParameterShift(), FiniteDifference())
            @test !supports_gradient(method, objective, [NaN, 0.0])
            @test !supports_gradient(method, objective, [0.2])
            @test_throws ArgumentError value_and_gradient(method, objective, [Inf, 0.0])
            @test_throws DimensionMismatch value_and_gradient(method, objective, [0.2])
        end
        @test !supports_gradient(SPSAGradient(), objective)
        @test !supports_gradient(SPSAGradient(), objective, parameters)
        @test_throws UnsupportedGradient value_and_gradient(SPSAGradient(), objective, parameters)
        unknown = QCircuit([FSIMGate(2, 1, [0.0, 0.2, -0.1, 0.3, -0.2];
            isparas=[true, false, false, false, false])])
        unshiftable = BatchExpectationObjective(unknown, observable, initial)
        @test !supports_gradient(ParameterShift(), unshiftable)
        @test !supports_gradient(ParameterShift(), unshiftable, [0.3])
        @test supports_gradient(FiniteDifference(), unshiftable, [0.3])
        @test value_and_gradient(FiniteDifference(step=1e-5), unshiftable, [0.3])[2] ≈
            value_and_gradient(AdjointGradient(), unshiftable, [0.3])[2] atol=1e-8

        F = BatchNumericalGradientFixtures
        limited = BatchExpectationObjective(QCircuit([F.LimitedRotation(0.0)]),
            QubitsTerm(1 => "Z"), BatchStateVector(1, 2))
        F.FORWARDS[] = 0
        @test_throws DimensionMismatch value_and_gradient(ParameterShift(), limited, [0.2])
        @test F.FORWARDS[] == 0
        @test_throws DimensionMismatch value_and_gradient(FiniteDifference(step=0.4), limited, [0.2])
        @test F.FORWARDS[] == 0
        @test limited.initial_state == BatchStateVector(1, 2)
    end
end
