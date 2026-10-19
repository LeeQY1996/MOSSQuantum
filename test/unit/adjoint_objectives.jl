using Test
using LinearAlgebra
using MOSS

module AdjointObjectiveFixtures
import MOSS

const FORWARDS = Ref(0)
const REVERSES = Ref(0)

struct Rotation <: MOSS.ParametricGate{1}
    wire::Int
    angle::Float64
    rule::Symbol
end
MOSS.positions(gate::Rotation) = (gate.wire,)
MOSS.parameters(gate::Rotation) = [gate.angle]
MOSS.active_parameters(gate::Rotation) = [gate.angle]
MOSS.mat(gate::Rotation) = [cos(gate.angle / 2) -sin(gate.angle / 2); sin(gate.angle / 2) cos(gate.angle / 2)]
function MOSS.reset_parameters!(gate::Rotation, values::AbstractVector{<:Real})
    length(values) == 1 || throw(DimensionMismatch())
    all(isfinite, values) || throw(ArgumentError("parameters must be finite"))
    return Rotation(gate.wire, only(values), gate.rule)
end

struct BadMatrix <: MOSS.Gate{1} end
MOSS.positions(::BadMatrix) = (1,)
MOSS.mat(::BadMatrix) = ones(3, 3)

function MOSS.differentiate(gate::Rotation)
    gate.rule === :missing && throw(ArgumentError("implement differentiate"))
    gate.rule === :length && return MOSS.Gate[]
    gate.rule === :type && return [nothing]
    gate.rule === :shape && return [BadMatrix()]
    wire = gate.rule === :positions ? gate.wire + 1 : gate.wire
    return [MOSS.QuantumGate(wire, [0.0 0.5; -0.5 0.0])]
end

for State in (MOSS.StateVector, MOSS.DensityMatrix)
    @eval function MOSS.apply!(gate::Rotation, state::$State)
        FORWARDS[] += 1
        return MOSS.apply!(MOSS.QuantumGate(MOSS.positions(gate), MOSS.mat(gate)), state)
    end
    @eval function MOSS.apply!(gate::MOSS.AdjointQuantumGate{1,G}, state::$State) where {G<:Rotation}
        REVERSES[] += 1
        return MOSS.apply!(MOSS.QuantumGate(MOSS.positions(gate), MOSS.mat(gate)), state)
    end
end

struct ForwardBackend <: MOSS.AbstractBackend end
MOSS.apply!(::ForwardBackend, circuit::MOSS.QCircuit, state::MOSS.StateVector) =
    MOSS.apply!(MOSS.CPUBackend(), circuit, state)
MOSS.expectation(::ForwardBackend, observable, state::MOSS.StateVector) =
    MOSS.expectation(MOSS.CPUBackend(), observable, state)

struct UnknownInstruction <: MOSS.AbstractInstruction end
MOSS.positions(::UnknownInstruction) = ()

struct TrainableChannel <: MOSS.AbstractQuantumMap{1} end
MOSS.positions(::TrainableChannel) = (1,)
MOSS.nparameters(::TrainableChannel) = 1
MOSS.active_parameters(::TrainableChannel) = [0.1]
end

function _objective_finite_difference(objective, values; step=1e-6)
    result = zeros(Float64, length(values))
    for index in eachindex(values)
        plus, minus = copy(values), copy(values)
        plus[index] += step
        minus[index] -= step
        result[index] = (evaluate(objective, plus) - evaluate(objective, minus)) / (2step)
    end
    return result
end

@testset "CPU adjoint scalar objectives" begin
    method = AdjointGradient()
    @testset "Analytic pure, mixed, and fixed-channel gradients" begin
        angle = 0.37
        template = QCircuit([RyGate(1, 0.0; isparas=true)])
        observable = QubitsTerm(1 => "Z")
        for initial in (StateVector(1), DensityMatrix(1))
            objective = ExpectationObjective(template, observable, initial)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, [angle])
            @test value ≈ cos(angle)
            @test value ≈ evaluate(objective, [angle])
            @test gradient ≈ [-sin(angle)]
            @test gradient ≈ _objective_finite_difference(objective, [angle]) atol=1e-8
            @test active_parameters(template) == [0.0]
        end
        for gamma in (0.23, 1.0), initial in (StateVector(1), DensityMatrix(1))
            noisy = QCircuit([template, AmplitudeDamping(1; γ=gamma)])
            objective = ExpectationObjective(noisy, observable, initial)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, [angle])
            @test value ≈ gamma + (1 - gamma) * cos(angle)
            @test gradient ≈ [-(1 - gamma) * sin(angle)] atol=1e-12
            @test gradient ≈ _objective_finite_difference(objective, [angle]) atol=1e-8
        end
        adjoint_objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)']), QubitsTerm(1 => "X"), StateVector(1))
        @test value_and_gradient(method, adjoint_objective, [angle])[1] ≈ -sin(angle)
        @test value_and_gradient(method, adjoint_objective, [angle])[2] ≈ [-cos(angle)]
    end

    @testset "Shared, nested, frozen, and operator observations" begin
        template = QCircuit([RyGate(1, 0.0; isparas=true), RxGate(2, 0.3),
            QCircuit([RzGate(1, 0.0; isparas=true), RyGate(1, 0.0; isparas=true)])])
        map = ParameterMap(template, [1, 2, 1])
        theta, phi = 0.35, -0.47
        expected = cos(theta)^2 - cos(phi) * sin(theta)^2
        expected_gradient = [-2sin(theta) * cos(theta) * (1 + cos(phi)), sin(phi) * sin(theta)^2]
        for observable in (QubitsTerm(1 => "Z"), QubitsOperator(QubitsTerm(1 => "Z")))
            objective = ExpectationObjective(template, observable, StateVector(2); parameter_map=map)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, [theta, phi])
            @test value ≈ expected
            @test value ≈ evaluate(objective, [theta, phi])
            @test gradient ≈ expected_gradient
            @test gradient ≈ _objective_finite_difference(objective, [theta, phi]) atol=1e-8
            @test parameters(objective.template[2]) == [0.3]
        end
    end

    @testset "Complex states and real observation workspaces" begin
        initial = StateVector(normalize(ComplexF64[1, 0.3im, -0.2 + 0.1im, 0.4]))
        template = QCircuit([RxGate(1, 0.0; isparas=true), CNOTGate(1, 2), RzGate(2, 0.0; isparas=true)])
        observable = QubitsOperator(QubitsTerm(1 => "Y"; coeff=0.4),
            QubitsTerm(1 => "X", 2 => "Z"; coeff=-0.3), QubitsTerm(2 => "Z"; coeff=0.2))
        values = [0.2, -0.4]
        for state in (initial, DensityMatrix(initial))
            objective = ExpectationObjective(template, observable, state)
            value, gradient = value_and_gradient(method, objective, values)
            @test supports_gradient(method, objective)
            @test value ≈ evaluate(objective, values)
            @test gradient ≈ _objective_finite_difference(objective, values) atol=1e-8
        end
        for observable in (QubitsTerm(1 => "Y"), QubitsOperator(QubitsTerm(1 => "Y")))
            objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]), observable, StateVector(Float64[1, 0]))
            value, gradient = value_and_gradient(method, objective, [0.4])
            @test iszero(value)
            @test gradient ≈ [0.0] atol=1e-12
        end
    end

    @testset "Immutable gate, one forward, and reusable pullback snapshots" begin
        F = AdjointObjectiveFixtures
        template = QCircuit([F.Rotation(1, 0.1, :valid)])
        observable = QubitsTerm(1 => [1.0 0.0; 0.0 -1.0])
        initial = StateVector(1)
        objective = ExpectationObjective(template, observable, initial)
        values = [0.3]
        F.FORWARDS[] = F.REVERSES[] = 0
        @test supports_gradient(method, objective)
        @test F.FORWARDS[] == F.REVERSES[] == 0
        value, back = value_and_pullback(method, objective, values)
        @test value ≈ cos(0.3)
        @test F.FORWARDS[] == 1
        @test F.REVERSES[] == 0
        @test back(0.0) == [0.0]
        @test F.REVERSES[] == 0
        @test back(1.0) ≈ [-sin(0.3)]
        @test back(-2.0) ≈ [2sin(0.3)]
        gradient = back(1.0)
        gradient[1] = 99
        @test back(1.0) ≈ [-sin(0.3)]
        @test F.FORWARDS[] == 1
        resize!(values, 2)
        values .= 9
        reset_parameters!(objective.template, [1.2])
        storage(objective.initial_state) .= ComplexF64[0, 1]
        oplist(objective.observable)[1] .= [1.0 0.0; 0.0 1.0]
        @test back(1.0) ≈ [-sin(0.3)]
        @test F.FORWARDS[] == 1
        @test parameters(template[1]) == [0.1]
        @test initial == StateVector(1)
        @test oplist(observable)[1] == [1.0 0.0; 0.0 -1.0]

        snapshot = ExpectationObjective(template, observable, initial)
        reset_parameters!(template, [0.9])
        storage(initial) .= ComplexF64[0, 1]
        oplist(observable)[1][1, 1] = 7
        @test parameters(snapshot.template[1]) == [0.1]
        @test snapshot.initial_state == StateVector(1)
        @test evaluate(snapshot, [0.4]) ≈ cos(0.4)
        @test value_and_gradient(method, snapshot, [0.4])[2] ≈ [-sin(0.4)]
    end

    @testset "Empty parameters, constant observations, and scalar types" begin
        empty = ExpectationObjective(QCircuit(), QubitsTerm(1 => "Z"), StateVector(1))
        @test supports_gradient(method, empty)
        @test value_and_gradient(method, empty, Float64[]) == (1.0, Float64[])
        @test isempty(value_and_pullback(method, empty, Real[])[2](0.0))
        constant = QubitsTerm(Int[], Matrix{Float64}[], 2.0)
        for state in (StateVector(1), DensityMatrix(1))
            objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]), constant, state)
            @test supports_gradient(method, objective)
            value, gradient = value_and_gradient(method, objective, [0.2])
            @test value ≈ 2
            @test gradient ≈ [0.0] atol=1e-12
        end
        objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]), QubitsTerm(1 => "Z"), StateVector(1))
        for values in (Float32[0.2], Real[0.2], BigFloat[0.2], view([9.0, 0.2, 9.0], 2:2))
            original = copy(values)
            value, gradient = value_and_gradient(method, objective, values)
            @test value isa Real
            @test gradient isa AbstractVector{<:Real}
            @test value ≈ cos(Float64(values[1]))
            @test gradient ≈ [-sin(Float64(values[1]))]
            @test values == original
        end
        @test_throws DimensionMismatch value_and_gradient(method, objective, Float64[])
        @test_throws ArgumentError value_and_pullback(method, objective, [NaN])
        @test_throws ArgumentError value_and_gradient(method, objective, [Inf])
    end

    @testset "Capability queries reject unsupported paths before execution" begin
        F = AdjointObjectiveFixtures
        state = StateVector(1)
        observable = QubitsTerm(1 => "Z")
        template = QCircuit([RyGate(1, 0.1; isparas=true)])
        backend = F.ForwardBackend()
        foreign = ExpectationObjective(template, observable, state; backend=backend)
        @test foreign.backend === backend
        @test evaluate(foreign, [0.3]) ≈ cos(0.3)
        @test !supports_gradient(method, foreign)
        @test_throws UnsupportedGradient value_and_gradient(method, foreign, [0.3])
        unsupported = Any[
            ExpectationObjective(template, observable, BatchStateVector(1, 2)),
            ExpectationObjective(template, QubitsTerm(1 => "+"), state),
            ExpectationObjective(template, QubitsOperator(QubitsTerm(1 => "+")), state),
            ExpectationObjective(template, QubitsTerm(2 => "Z"), state),
            ExpectationObjective(template, [1.0 0.0; 0.0 -1.0], state),
            ExpectationObjective(QCircuit([QMeasure(1)]), observable, state),
            ExpectationObjective(QCircuit([QSelect(1)]), observable, state),
            ExpectationObjective(QCircuit([F.UnknownInstruction()]), observable, state),
            ExpectationObjective(QCircuit([F.TrainableChannel()]), observable, state),
            ExpectationObjective(QCircuit([QuantumGate(1, [1.0 0.0; 0.0 2.0])]), observable, state),
            ExpectationObjective(QCircuit([XGate(2)]), observable, state),
        ]
        for rule in (:missing, :length, :type, :shape, :positions)
            push!(unsupported, ExpectationObjective(QCircuit([F.Rotation(1, 0.1, rule)]), observable, state))
        end
        F.FORWARDS[] = 0
        for objective in unsupported
            @test !supports_gradient(method, objective)
            values = zeros(nparameters(objective.parameter_map))
            @test_throws UnsupportedGradient value_and_gradient(method, objective, values)
            @test_throws UnsupportedGradient value_and_pullback(method, objective, values)
        end
        @test F.FORWARDS[] == 0
        @test !supports_gradient(method, values -> sum(values))
        @test_throws UnsupportedGradient value_and_gradient(method, values -> sum(values), [0.1])
    end
end
