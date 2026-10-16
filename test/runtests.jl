push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

include("util.jl")

using Test
using Random
using Zygote, LinearAlgebra

using MOSS
using MOSS.Utilities
using MOSS: apply_serial!
using MOSS.QuantumCircuits: n_qubits_mat_from_external
using MOSS.QuantumCircuits.Gates

# Resolve plot ambiguity: use MOSS.QuantumCircuits.plot for circuit plotting
const qcplot = MOSS.QuantumCircuits.plot

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
    include("check_gateop.jl")
    include("check_high_qubit_gate.jl")
end

@testset "test quantum state initialization" begin
    include("check_state_init.jl")
end

@testset "test batch state vector" begin
    include("test_batchstatevector.jl")
end

@testset "test batch gate operations" begin
    include("test_batch_gates.jl")
end

@testset "test batch expectation computations" begin
    include("test_batch_expec.jl")
end


@testset "test qubit hamiltonian operations" begin
    include("check_qubits_ham.jl")
end

@testset "test circuit parameters" begin
    include("parameter.jl")
end

@testset "test measure and select" begin
    include("check_measure.jl")
end


@testset "test quantum algorithm" begin
    include("algs.jl")
end

@testset "test utility" begin
    include("check_utility.jl")
end


@testset "test quantum circuit gradient" begin
    include("circuitgrad.jl")
    include("crxgategrad.jl")
end


@testset "test expectation value gradient" begin
    include("check_ham_expec_diff.jl")
end

@testset "test quantum state gradient (may not variable via a quantum computer)" begin
    include("stategrad.jl")
end


@testset "test density matrix operations" begin
    include("check_dm.jl")
end

@testset "test noisy quantum circuit" begin
    include("check_noisy_grad.jl")
end

@testset "correctness regressions" begin
    include("regression_measurements.jl")
    include("regression_kernels.jl")
    include("regression_operators.jl")
    include("regression_gradients.jl")
end


# ============================================================================
# 原 QuantumCircuits 绘图测试
# ============================================================================

@testset "QuantumCircuits plotting" begin

    using Plots, LaTeXStrings

    @testset "Single-qubit gates" begin
        c = QCircuit()
        push!(c, XGate(1))
        push!(c, YGate(2))
        push!(c, ZGate(1))
        push!(c, HGate(2))
        push!(c, SGate(1))
        push!(c, TGate(2))
        push!(c, sqrtXGate(1))
        push!(c, sqrtYGate(2))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Parametric gates" begin
        c = QCircuit()
        push!(c, RxGate(1, π/4))
        push!(c, RyGate(2, π/2))
        push!(c, RzGate(1, π))
        push!(c, PHASEGate(2, π/4))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Two-qubit gates" begin
        c = QCircuit()
        push!(c, CNOTGate(1, 2))
        push!(c, CZGate(2, 3))
        push!(c, SWAPGate(1, 3))
        push!(c, iSWAPGate(1, 2))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Controlled parametric gates" begin
        c = QCircuit()
        push!(c, CRxGate(1, 2, π/4))
        push!(c, CRyGate(2, 3, π/2))
        push!(c, CRzGate(1, 3, π))
        push!(c, CPHASEGate(1, 2, π/4))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Three-qubit gates" begin
        c = QCircuit()
        push!(c, TOFFOLIGate(1, 2, 3))
        push!(c, FREDKINGate(1, 2, 3))
        push!(c, CCPHASEGate(1, 2, 3, π/4))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Measurement and selection" begin
        c = QCircuit()
        push!(c, HGate(1))
        push!(c, CNOTGate(1, 2))
        push!(c, QMeasure(1))
        push!(c, QSelect(2, 0))
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Generic gate" begin
        c = QCircuit()
        push!(c, QuantumGate(1, [0 1; 1 0]))  # X gate as generic
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Custom options" begin
        c = QCircuit()
        push!(c, HGate(1))
        push!(c, CNOTGate(1, 2))
        plt = qcplot(c; qubit_names=["|0⟩", "|1⟩"], title="Test circuit", dpi=150)
        @test plt isa Plots.Plot
    end

    @testset "Empty circuit" begin
        c = QCircuit()
        plt = qcplot(c)
        @test plt isa Plots.Plot
    end

    @testset "Save circuit plot" begin
        c = QCircuit()
        push!(c, HGate(1))
        push!(c, CNOTGate(1, 2))
        plt = qcplot(c)
        tmpfile = tempname() * ".png"
        try
            MOSS.QuantumCircuits.save_circuit_plot(plt, tmpfile)
            @test isfile(tmpfile)
        finally
            isfile(tmpfile) && rm(tmpfile)
        end
    end
end
