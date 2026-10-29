module DemoGateContractChecks

using Test
import MOSSQuantum
import Zygote
import FiniteDifferences

struct UnimplementedInstruction <: MOSSQuantum.AbstractInstruction end
MOSSQuantum.positions(::UnimplementedInstruction) = (2,)

function run(::Type{GateType}) where {GateType}
    @testset "external immutable trainable gate" begin
        source = GateType(2, 0.13)
        frozen = GateType(2, 0.2; trainable=false)
        @test MOSSQuantum.positions(source) == (2,)
        @test MOSSQuantum.nqubits(source) == 1
        @test MOSSQuantum.parameters(source) == [0.13]
        @test MOSSQuantum.active_parameters(source) == [0.13]
        @test MOSSQuantum.nparameters(source) == 1
        @test MOSSQuantum.parameters(frozen) == [0.2]
        @test isempty(MOSSQuantum.active_parameters(frozen))
        @test MOSSQuantum.nparameters(frozen) == 0
        @test MOSSQuantum.differentiate(frozen) === nothing
        derivative = only(MOSSQuantum.differentiate(source))
        @test MOSSQuantum.positions(derivative) == (2,)
        @test MOSSQuantum.mat(derivative) ≈ [0.0 0.5; -0.5 0.0]
        moved = MOSSQuantum.change_positions(source, Dict(2 => 1))
        @test MOSSQuantum.positions(moved) == (1,)
        @test MOSSQuantum.mat(moved) == MOSSQuantum.mat(source)

        replacement = MOSSQuantum.reset_parameters!(source, [0.4])
        @test replacement isa GateType
        @test MOSSQuantum.parameters(replacement) == [0.4]
        @test MOSSQuantum.parameters(source) == [0.13]
        @test MOSSQuantum.parameters(MOSSQuantum.reset_parameters!(frozen, Float64[])) == [0.2]
        @test_throws DimensionMismatch MOSSQuantum.reset_parameters!(source, Float64[])
        @test_throws ArgumentError MOSSQuantum.reset_parameters!(source, [NaN])
        @test_throws BoundsError MOSSQuantum.activate_parameter!(source, 2)
        @test_throws BoundsError MOSSQuantum.deactivate_parameter!(source, 0)

        activated = MOSSQuantum.activate_parameter!(frozen, 1)
        @test MOSSQuantum.active_parameters(activated) == [0.2]
        @test isempty(MOSSQuantum.active_parameters(frozen))
        @test isempty(MOSSQuantum.active_parameters(MOSSQuantum.deactivate_parameter!(activated, 1)))
        @test isempty(MOSSQuantum.active_parameters(MOSSQuantum.deactivate_parameters!(source)))

        # All controls retain replacement objects, including an adjoint's parent.
        frozen_adjoint = frozen'
        active_adjoint = MOSSQuantum.activate_parameters!(frozen_adjoint)
        @test MOSSQuantum.active_parameters(active_adjoint) == [0.2]
        @test isempty(MOSSQuantum.active_parameters(frozen_adjoint))
        reset_adjoint = MOSSQuantum.reset_parameters!(active_adjoint, [0.6])
        @test MOSSQuantum.active_parameters(reset_adjoint) == [0.6]
        @test MOSSQuantum.mat(reset_adjoint) ≈ MOSSQuantum.mat(GateType(2, 0.6))'
        @test isempty(MOSSQuantum.active_parameters(MOSSQuantum.deactivate_parameters!(active_adjoint)))

        single_bound = MOSSQuantum.bind_parameters(source, [0.45])
        @test single_bound isa GateType
        @test MOSSQuantum.parameters(single_bound) == [0.45]
        @test MOSSQuantum.parameters(source) == [0.13]
        @test MOSSQuantum.parameters(MOSSQuantum.bind_parameters(frozen, Float64[])) == [0.2]
        @test MOSSQuantum.parameters(MOSSQuantum.copy_instruction(source)) == MOSSQuantum.parameters(source)
        @test_throws DimensionMismatch MOSSQuantum.bind_parameters(source, Float64[])
        @test_throws DimensionMismatch MOSSQuantum.bind_parameters(source, [0.1, 0.2])
        @test_throws ArgumentError MOSSQuantum.bind_parameters(source, [NaN])
        @test_throws ArgumentError MOSSQuantum.bind_parameters(source, [Inf])

        nested = MOSSQuantum.QCircuit([source, frozen])
        template = MOSSQuantum.QCircuit([source, nested, GateType(2, 0.09)'])
        @test MOSSQuantum.active_parameters(template) == [0.13, 0.13, 0.09]
        @test MOSSQuantum.nparameters(template) == 3
        theta = [0.37, -0.21, 0.16]
        bound = MOSSQuantum.bind_parameters(template, theta)
        @test MOSSQuantum.active_parameters(bound) == theta
        @test MOSSQuantum.parameters(bound) == [theta[1], theta[2], 0.2, theta[3]]
        @test MOSSQuantum.active_parameters(template) == [0.13, 0.13, 0.09]
        @test MOSSQuantum.active_parameters(nested) == [0.13]
        @test bound !== template
        @test bound[2] !== nested
        theta[1] = 0.4
        @test MOSSQuantum.active_parameters(bound) == [0.37, -0.21, 0.16]
        @test MOSSQuantum.reset_parameters!(bound, [0.11, 0.12, 0.14]) === bound
        @test MOSSQuantum.active_parameters(bound) == [0.11, 0.12, 0.14]
        @test MOSSQuantum.parameters(bound) == [0.11, 0.12, 0.2, 0.14]
        @test MOSSQuantum.active_parameters(template) == [0.13, 0.13, 0.09]
        @test theta == [0.4, -0.21, 0.16]
        @test_throws DimensionMismatch MOSSQuantum.bind_parameters(template, [0.1])
        @test_throws ArgumentError MOSSQuantum.bind_parameters(template, [NaN, 0.1, 0.2])

        controls = MOSSQuantum.copy_instruction(template)
        @test MOSSQuantum.deactivate_parameters!(controls) === controls
        @test MOSSQuantum.nparameters(controls) == 0
        @test MOSSQuantum.activate_parameters!(controls) === controls
        @test MOSSQuantum.nparameters(controls) == 4
        @test MOSSQuantum.deactivate_parameter!(controls, 2) === controls
        @test MOSSQuantum.nparameters(controls) == 2
        @test MOSSQuantum.activate_parameter!(controls, 2) === controls
        @test MOSSQuantum.nparameters(controls) == 4
        @test MOSSQuantum.nparameters(template) == 3

        initial = MOSSQuantum.qstate(2)
        initial_copy = copy(initial)
        observable = MOSSQuantum.QubitsTerm(2 => "Z")
        @test MOSSQuantum.backend(initial) isa MOSSQuantum.CPUBackend
        @test MOSSQuantum.supports(MOSSQuantum.backend(initial), source, initial)
        @test !MOSSQuantum.supports(MOSSQuantum.backend(initial), source, initial; action=:gradient)
        loss(values) = real(MOSSQuantum.expectation(observable, MOSSQuantum.bind_parameters(template, values) * initial))
        theta = [0.37, -0.21, 0.16]
        total_angle = theta[1] + theta[2] + 0.2 - theta[3]
        analytic = sin(total_angle) .* [-1.0, -1.0, 1.0]
        @test loss(theta) ≈ cos(total_angle)
        gradient = Zygote.gradient(loss, theta)[1]
        finite_difference = FiniteDifferences.grad(FiniteDifferences.central_fdm(5, 1), loss, theta)[1]
        @test gradient ≈ analytic atol=1e-10
        @test gradient ≈ finite_difference atol=1e-8
        @test loss(theta - 0.2 .* gradient) < loss(theta)
        @test MOSSQuantum.active_parameters(template) == [0.13, 0.13, 0.09]
        @test theta == [0.37, -0.21, 0.16]
        @test initial == initial_copy

        # The same public gate derivative works with fixed CPU Kraus channels.
        noisy_template = MOSSQuantum.copy_instruction(template)
        push!(noisy_template, MOSSQuantum.Depolarizing(2; p=0.2))
        noisy_loss(values) = real(MOSSQuantum.expectation(observable, MOSSQuantum.bind_parameters(noisy_template, values) * initial))
        @test noisy_loss(theta) ≈ 0.8 * cos(total_angle)
        @test Zygote.gradient(noisy_loss, theta)[1] ≈ 0.8 .* analytic atol=1e-10

        # These CPU circuit rules do not promise gradients for every operation,
        # stochastic execution or external backend.
        for instruction in (UnimplementedInstruction(), MOSSQuantum.QMeasure(2), MOSSQuantum.QSelect(2),
                            MOSSQuantum.QuantumGate(2, [1.0 0; 0 0.5]))
            unsupported = MOSSQuantum.QCircuit([source, MOSSQuantum.QCircuit([instruction])])
            rejected_loss(values) = real(MOSSQuantum.expectation(observable, MOSSQuantum.bind_parameters(unsupported, values) * initial))
            @test_throws ArgumentError Zygote.gradient(rejected_loss, [0.3])
        end
        batch = MOSSQuantum.BatchStateVector(2, 2)
        batch_loss(values) = real(sum(MOSSQuantum.expectation(observable, MOSSQuantum.bind_parameters(template, values) * batch)))
        @test Zygote.gradient(batch_loss, theta)[1] ≈ 2 .* analytic atol=1e-10
        for batch_initial in (batch, MOSSQuantum.BatchDensityMatrix(batch))
            mixed_batch_loss(values) = real(sum(MOSSQuantum.expectation(observable,
                MOSSQuantum.bind_parameters(noisy_template, values) * batch_initial)))
            @test mixed_batch_loss(theta) ≈ 1.6 * cos(total_angle)
            @test Zygote.gradient(mixed_batch_loss, theta)[1] ≈ 1.6 .* analytic atol=1e-10
        end
    end

    @testset "explicit shared parameter identities" begin
        source = GateType(2, 0.13)
        frozen_angle = 0.2
        frozen = GateType(2, frozen_angle; trainable=false)
        nested = MOSSQuantum.QCircuit([frozen, MOSSQuantum.RzGate(2, -0.11; isparas=true)])
        template = MOSSQuantum.QCircuit([source, nested, source'])
        source_values = [0.13, -0.11, 0.13]
        initial = MOSSQuantum.qstate(2)
        initial_copy = copy(initial)
        observable = MOSSQuantum.QubitsTerm(2 => "Z")

        # The first map shares an external rotation with its adjoint. The
        # second shares a value between external Ry and built-in Rz gates.
        for slots in ([1, 2, 1], [1, 1, 2])
            @testset "parameter identities $slots" begin
                constructor_indices = copy(slots)
                parameter_map = MOSSQuantum.ParameterMap(constructor_indices)
                @test MOSSQuantum.nparameters(parameter_map) == 2
                @test MOSSQuantum.parameter_indices(parameter_map) isa Vector{Int}
                @test MOSSQuantum.parameter_indices(parameter_map) == slots
                constructor_indices .= 1
                @test MOSSQuantum.parameter_indices(parameter_map) == slots
                exposed_indices = MOSSQuantum.parameter_indices(parameter_map)
                exposed_indices .= 1
                @test MOSSQuantum.parameter_indices(parameter_map) == slots

                values = [0.37, 0.63]
                original_values = copy(values)
                flat_values = values[slots]
                supplied_values = copy(values)
                bound = MOSSQuantum.bind_parameters(template, supplied_values, parameter_map)
                @test MOSSQuantum.nparameters(bound) == 3
                @test MOSSQuantum.active_parameters(bound) == flat_values
                @test MOSSQuantum.parameters(bound) == [flat_values[1], frozen_angle, flat_values[2], flat_values[3]]
                @test MOSSQuantum.active_parameters(template) == source_values
                @test MOSSQuantum.parameters(source) == [0.13]
                @test MOSSQuantum.parameters(frozen) == [frozen_angle]
                @test bound[2] !== nested
                supplied_values .= -0.7
                @test MOSSQuantum.active_parameters(bound) == flat_values
                @test values == original_values

                reused = MOSSQuantum.bind_parameters(MOSSQuantum.copy_instruction(template), values, parameter_map)
                @test MOSSQuantum.active_parameters(reused) == flat_values
                @test reused * initial ≈ bound * initial

                # Binding expands identities into independently owned slots.
                # A later ordinary reset has no persistent tying semantics.
                reset_values = [0.19, -0.28, 0.43]
                @test MOSSQuantum.reset_parameters!(bound, reset_values) === bound
                @test MOSSQuantum.active_parameters(bound) == reset_values
                @test MOSSQuantum.active_parameters(reused) == flat_values
                @test MOSSQuantum.active_parameters(template) == source_values
                @test MOSSQuantum.parameter_indices(parameter_map) == slots

                shared_loss = independent -> real(MOSSQuantum.expectation(observable,
                    MOSSQuantum.bind_parameters(template, independent, parameter_map) * initial))
                slot_loss = flat -> real(MOSSQuantum.expectation(observable,
                    MOSSQuantum.bind_parameters(template, flat) * initial))
                alpha = flat_values[1] + frozen_angle
                beta = flat_values[2]
                gamma = flat_values[3]
                analytic_loss = cos(alpha) * cos(gamma) + sin(alpha) * sin(gamma) * cos(beta)
                analytic_slots = [
                    -sin(alpha) * cos(gamma) + cos(alpha) * sin(gamma) * cos(beta),
                    -sin(alpha) * sin(gamma) * sin(beta),
                    -cos(alpha) * sin(gamma) + sin(alpha) * cos(gamma) * cos(beta),
                ]
                a, b = values
                analytic_shared = if slots == [1, 2, 1]
                    [(cos(b) - 1) * sin(2a + frozen_angle),
                     -sin(a + frozen_angle) * sin(a) * sin(b)]
                else
                    [-sin(a + frozen_angle) * cos(b) + cos(a + frozen_angle) * sin(b) * cos(a) -
                     sin(a + frozen_angle) * sin(b) * sin(a),
                     -cos(a + frozen_angle) * sin(b) + sin(a + frozen_angle) * cos(b) * cos(a)]
                end
                @test shared_loss(values) ≈ analytic_loss
                @test slot_loss(flat_values) ≈ analytic_loss
                shared_gradient = Zygote.gradient(shared_loss, values)[1]
                slot_gradient = Zygote.gradient(slot_loss, flat_values)[1]
                finite_difference = FiniteDifferences.grad(
                    FiniteDifferences.central_fdm(5, 1), shared_loss, values)[1]
                @test slot_gradient ≈ analytic_slots atol=1e-10
                @test shared_gradient ≈ analytic_shared atol=1e-10
                @test shared_gradient ≈ finite_difference atol=1e-8
                saved_slot_gradient = copy(slot_gradient)
                accumulated = MOSSQuantum.accumulate_parameter_gradients(parameter_map, slot_gradient)
                @test accumulated ≈ shared_gradient atol=1e-10
                @test slot_gradient == saved_slot_gradient
                accumulated[1] += 1
                @test slot_gradient == saved_slot_gradient
                @test shared_loss(values - 0.2 .* shared_gradient) < shared_loss(values)
                @test values == original_values
                @test MOSSQuantum.active_parameters(template) == source_values
                @test MOSSQuantum.parameter_indices(parameter_map) == slots
                @test initial == initial_copy

                noisy_template = MOSSQuantum.copy_instruction(template)
                push!(noisy_template, MOSSQuantum.Depolarizing(2; p=0.2))
                noisy_shared_loss = independent -> real(MOSSQuantum.expectation(observable,
                    MOSSQuantum.bind_parameters(noisy_template, independent, parameter_map) * initial))
                noisy_slot_loss = flat -> real(MOSSQuantum.expectation(observable,
                    MOSSQuantum.bind_parameters(noisy_template, flat) * initial))
                @test MOSSQuantum.bind_parameters(noisy_template, values, parameter_map) * initial isa MOSSQuantum.DensityMatrix
                @test noisy_shared_loss(values) ≈ 0.8 * analytic_loss
                noisy_shared_gradient = Zygote.gradient(noisy_shared_loss, values)[1]
                noisy_slot_gradient = Zygote.gradient(noisy_slot_loss, flat_values)[1]
                noisy_finite_difference = FiniteDifferences.grad(
                    FiniteDifferences.central_fdm(5, 1), noisy_shared_loss, values)[1]
                @test noisy_shared_gradient ≈ 0.8 .* analytic_shared atol=1e-10
                @test noisy_shared_gradient ≈ noisy_finite_difference atol=1e-8
                @test noisy_shared_gradient ≈ MOSSQuantum.accumulate_parameter_gradients(parameter_map, noisy_slot_gradient) atol=1e-10
                @test MOSSQuantum.active_parameters(noisy_template) == source_values
                @test values == original_values

                @test_throws DimensionMismatch MOSSQuantum.bind_parameters(template, [0.2], parameter_map)
                @test_throws DimensionMismatch MOSSQuantum.bind_parameters(template, [0.2, 0.3, 0.4], parameter_map)
                @test_throws DimensionMismatch MOSSQuantum.bind_parameters(MOSSQuantum.QCircuit([source]), values, parameter_map)
                @test_throws DimensionMismatch MOSSQuantum.bind_parameters(template, values, MOSSQuantum.ParameterMap([1, 2]))
                @test_throws DimensionMismatch MOSSQuantum.accumulate_parameter_gradients(parameter_map, [0.1, 0.2])
                @test_throws ArgumentError MOSSQuantum.bind_parameters(template, [NaN, 0.3], parameter_map)
                @test_throws ArgumentError MOSSQuantum.bind_parameters(template, [0.2, Inf], parameter_map)
                @test MOSSQuantum.active_parameters(template) == source_values
                @test MOSSQuantum.parameter_indices(parameter_map) == slots
            end
        end
    end
end

end
