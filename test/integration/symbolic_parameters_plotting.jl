using Plots, LaTeXStrings

@testset "Named parameter circuit diagrams" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    circuit = QCircuit([RyGate(1, θ), CRzGate(1, 3, -θ/2 + φ),
                        Conditional(:m, RzGate(3, θ))])
    extension = Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt)
    drawing = extension.QuantumCircuitsPlotting
    summary = drawing._instruction_summary(circuit)
    @test occursin("θ", summary)
    @test occursin("φ", summary)
    @test occursin("RyGate", summary)
    @test MOSSQuantum.QuantumCircuits.plot(circuit) isa Plots.Plot
    @test MOSSQuantum.QuantumCircuits.plot(circuit; show_parameters=false) isa Plots.Plot
    @test !occursin("θ", drawing._instruction_summary(circuit; show_parameters=false))
end
