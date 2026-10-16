include("support/finite_differences.jl")

using Test
using Random
using Zygote, LinearAlgebra

using MOSS
using MOSS.Utilities
using MOSS: apply_serial!
using MOSS.QuantumCircuits: n_qubits_mat_from_external
using MOSS.QuantumCircuits.Gates

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


@testset "test quantum algorithm" begin
    include("integration/algorithms.jl")
end

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
