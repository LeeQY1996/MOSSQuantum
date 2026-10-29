include("support/finite_differences.jl")

using Test
using Random
using Zygote, LinearAlgebra

using MOSSQuantum
using MOSSQuantum.Utilities
using MOSSQuantum: apply_serial!
using MOSSQuantum.QuantumCircuits: n_qubits_mat_from_external
using MOSSQuantum.QuantumCircuits.Gates

_check_unitary(m::AbstractMatrix) = isapprox(m' * m, LinearAlgebra.I)

function from_external(key::NTuple{N, Int}, m::AbstractMatrix; check_unitary::Bool=true) where N
    (size(m, 1) == 2^N) || error("wrong input matrix size.")
    if check_unitary
        _check_unitary(m) || error("input matrix is not unitary.")
    end
    return QuantumGate(key, n_qubits_mat_from_external(m))
end

function random_unitary(n::Int)
    L = 2^n
    m = randn(ComplexF64, L, L)
    return exp(im * (m + m'))
end


# ============================================================================
# 原 VQC 测试
# ============================================================================

@testset "test quantum gate operations" begin
    include("unit/gate_operations.jl")
    include("unit/high_qubit_gates.jl")
end

@testset "test quantum state initialization" begin
    include("unit/state_initialization.jl")
end

include("unit/ownership_and_containers.jl")
include("unit/operator_algebra.jl")
include("unit/constant_operators.jl")
include("unit/shot_execution.jl")
include("unit/shot_estimation.jl")
include("unit/circuit_estimation.jl")
include("unit/noise_channels.jl")
include("unit/noise_execution.jl")
include("unit/classical_control.jl")
include("unit/sampled_gradients.jl")
include("integration/shot_optimization.jl")
include("unit/execution_plans.jl")
include("unit/shot_budgets.jl")

@testset "test batch state vector" begin
    include("unit/batch_state_vector.jl")
end

@testset "test batch gate operations" begin
    include("unit/batch_gates.jl")
end

@testset "test batch expectation computations" begin
    include("unit/batch_expectations.jl")
end


@testset "test qubit hamiltonian operations" begin
    include("unit/qubit_operators.jl")
end

@testset "test circuit parameters" begin
    include("unit/parameters.jl")
end

@testset "test measure and select" begin
    include("unit/measurements.jl")
end


include("integration/simulation_utilities.jl")

@testset "test utility" begin
    include("integration/utilities.jl")
end


@testset "test quantum circuit gradient" begin
    include("integration/circuit_gradients.jl")
    include("integration/controlled_rotation_gradients.jl")
end


@testset "test expectation value gradient" begin
    include("integration/expectation_gradients.jl")
end

@testset "test quantum state gradient (may not variable via a quantum computer)" begin
    include("integration/state_gradients.jl")
end


@testset "test density matrix operations" begin
    include("unit/density_matrices.jl")
end

@testset "test noisy quantum circuit" begin
    include("integration/noisy_circuit_gradients.jl")
end

@testset "correctness regressions" begin
    include("regression/measurements.jl")
    include("regression/kernels.jl")
    include("regression/operators.jl")
    include("regression/gradients.jl")
end


include("integration/plotting.jl")

include("integration/public_api.jl")
include("regression/quantum_semantics.jl")
include("unit/parameter_binding.jl")
include("unit/parameter_protocols.jl")
include("unit/parameter_maps.jl")
include("unit/gradient_methods.jl")
include("unit/adjoint_objectives.jl")
include("unit/batch_contracts.jl")
include("unit/batch_measurements.jl")
include("unit/batch_objectives.jl")
include("unit/batch_density_states.jl")
include("unit/batch_density_execution.jl")
include("unit/batch_density_observables.jl")
include("unit/batch_density_measurements.jl")
include("unit/batch_density_objectives.jl")
include("unit/batch_density_observation_workspaces.jl")
include("unit/density_gradient_workspaces.jl")
include("unit/generic_array_storage.jl")
include("unit/storage_backend_routing.jl")
include("integration/execution_api.jl")
include("extensions/backend_protocols.jl")
include("extensions/optional_integrations.jl")
include("extensions/adjoint_capabilities.jl")
include("extensions/constructor_gradients.jl")
include("extensions/generic_storage_gradients.jl")
include("extensions/shared_parameter_gradients.jl")
include("extensions/differentiation_rules.jl")
include("extensions/batch_gradients.jl")
include("extensions/batch_density_gradients.jl")
include("extensions/trainable_instructions.jl")
include("extensions/independent_differentiation.jl")

if "--load-orders" in ARGS
    @testset "Fresh-process optional integration loading" begin
        project = dirname(Base.active_project())
        script = joinpath(@__DIR__, "extensions", "load_order.jl")
        for scenario in ("core", "chainrules_first", "mossquantum_first_chainrules",
                         "zygote_first", "mossquantum_first_zygote", "plots_first",
                         "mossquantum_first_plots", "latex_then_mossquantum_then_plots")
            @test success(`$(Base.julia_cmd()) --startup-file=no --project=$project $script $scenario`)
        end
    end
end
