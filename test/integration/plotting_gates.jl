using Plots, LaTeXStrings, LinearAlgebra

@testset "Gate drawing semantics" begin
    drawing = Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt).QuantumCircuitsPlotting
    labels(plot) = [(a[1], a[2], string(a[3].str)) for a in plot.subplots[1][:annotations]]

    @testset "generic gate ports" begin
        gate = QuantumGate((3, 1), Matrix{ComplexF64}(I, 4, 4))
        plot = Plots.plot()
        drawing.draw_circuit_gate!(plot, gate, 1, (3, 1))
        @test (1, 3, "U[0]") in labels(plot)
        @test (1, 1, "U[1]") in labels(plot)
        @test length(plot.series_list) == 3 # connector and two boxes, no control marker

        adj = adjoint(gate)
        plot = Plots.plot()
        drawing.draw_circuit_gate!(plot, adj, 1, (3, 1))
        @test any(contains(text, "†[0]") && y == 3 for (_, y, text) in labels(plot))
    end

    @testset "parameter labels" begin
        gates = [RxGate(1, 0.37), RyGate(1, 0.37), RzGate(1, 0.37), PHASEGate(1, 0.37),
                 CRxGate(1, 2, 0.37), CRyGate(1, 2, 0.37), CRzGate(1, 2, 0.37),
                 CPHASEGate(1, 2, 0.37), CCPHASEGate(1, 2, 3, 0.37),
                 FSIMGate(1, 2, [0.37, 0.2, 0.3, 0.4, 0.5])]
        for gate in gates
            positions = MOSSQuantum.QuantumCircuits.positions(gate)
            rows = length(positions) == 1 ? only(positions) : Tuple(positions)
            shown, hidden = Plots.plot(), Plots.plot()
            drawing.draw_circuit_gate!(shown, gate, 1, rows; show_parameters=true)
            drawing.draw_circuit_gate!(hidden, gate, 1, rows; show_parameters=false)
            @test any(contains(text, "0.37") for (_, _, text) in labels(shown))
            @test all(!contains(text, "0.37") for (_, _, text) in labels(hidden))
        end
    end
end
