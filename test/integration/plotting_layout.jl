# Structural assertions catch semantic errors that a Plot return type cannot.
@testset "Circuit drawing layout" begin
    plotting = Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt).QuantumCircuitsPlotting
    h = HGate(1)
    cx = CNOTGate(1, 2)
    x = XGate(2)
    circuit = QCircuit([h, cx, x])
    depth, nqubits, layout = plotting.compute_circuit_layout(circuit)
    columns = Dict(gate => time for ((time, _), (gate, _)) in layout)
    @test (columns[h], columns[cx], columns[x]) == (1, 2, 3)
    @test (depth, nqubits) == (3, 2)

    # Independent gates may share a column, but a sequential view may not.
    parallel = QCircuit([XGate(1), XGate(3), HGate(1)])
    depth, _, layout = plotting.compute_circuit_layout(parallel)
    @test depth == 2
    @test plotting._plot_qubits(parallel) == [1, 3]
    labels = [annotation[3].str for annotation in plotting.plot(parallel).subplots[1][:annotations]]
    @test "q₁" in labels && "q₃" in labels && !("q₂" in labels)
    sequential = plotting.compute_sequential_layout(parallel)
    @test sort([time for ((time, _), _) in sequential]) == [1, 2, 3]
    @test plotting.plot(parallel; layout_algorithm=:sequential).attr[:size][1] == 240
    @test plotting.plot(parallel; layout_algorithm=:compact).attr[:size][1] == 180
    @test_throws ArgumentError plotting.plot(parallel; layout_algorithm=:unknown)
    @test_throws ArgumentError plotting.plot(parallel; qubit_names=["one"])

    # Recursion follows execution order and does not require a drawable subcircuit block.
    nested = QCircuit([QCircuit([h, cx]), x, QCircuit()])
    @test plotting.compute_circuit_layout(nested)[1] == 3
    @test length(plotting.compute_circuit_layout(nested)[3]) == 3
    @test plotting.compute_circuit_layout(QCircuit())[1:2] == (0, 0)

    # A classical dependency can cross disjoint quantum wires.
    dynamic = QCircuit([HGate(1), QMeasure(1; key=:m), Conditional(:m, XGate(2)), HGate(1)])
    _, _, dynamic_layout = plotting.compute_circuit_layout(dynamic)
    @test sort([time for ((time, _), _) in dynamic_layout]) == [1, 2, 3, 4]
    empty_if = Conditional(:m, QCircuit())
    classical_only = QCircuit([QMeasure(1; key=:m), empty_if, XGate(1)])
    depth, _, classical_layout = plotting.compute_circuit_layout(classical_only)
    @test depth == 3
    @test classical_layout[(2, 0)] == (empty_if, Int[])
    @test plotting.plot(classical_only) isa Plots.Plot
end
