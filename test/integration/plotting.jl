using Plots, LaTeXStrings

# Resolve the plot name shared by MOSS and Plots.
const qcplot = MOSS.QuantumCircuits.plot

@testset "QuantumCircuits plotting" begin

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
