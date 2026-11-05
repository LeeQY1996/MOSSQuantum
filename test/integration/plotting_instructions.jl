using Plots, LaTeXStrings

@testset "circuit instruction diagrams" begin
    qc = MOSSQuantum.QuantumCircuits
    ext = Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt)
    draw = ext.QuantumCircuitsPlotting

    feedback = QCircuit([
        QMeasure(2; key=:syndrome, auto_reset=false, keep=false),
        Conditional(ClassicalCondition((:syndrome, :flag), 2; source=:physical),
                    QCircuit([XGate(3), QMeasure(3; key=:flag)]);
                    otherwise=QCircuit([ZGate(1)])),
        AmplitudeDamping(3; γ=0.1),
        Delay(1; duration=2.5),
    ])
    _, _, positions = draw.compute_circuit_layout(feedback)
    notes = join([draw._instruction_summary(x) for (_, (x, _)) in positions], "\n")
    @test occursin("key=:syndrome", notes)
    @test occursin("auto_reset=false", notes)
    @test occursin("keep=false", notes)
    @test occursin("physical", notes)
    @test occursin("first key is least significant", notes)
    @test occursin("XGate q(3,)", notes)
    @test occursin("ZGate q(1,)", notes)
    @test occursin("Kraus", notes)
    @test occursin("duration=2.5", notes)
    @test qc.plot(feedback) isa Plots.Plot
    @test Plots.plot(feedback) isa Plots.Plot

    nested = Conditional(:a, Conditional(:b, XGate(1); otherwise=YGate(1)); otherwise=ZGate(1))
    nested_notes = draw._instruction_summary(nested)
    @test occursin("(:a,)", nested_notes)
    @test occursin("(:b,)", nested_notes)
    @test occursin("YGate", nested_notes)
    @test qc.plot(QCircuit([nested])) isa Plots.Plot
    empty_condition = QCircuit([HGate(1), Conditional(:a, QCircuit()), XGate(1)])
    @test qc.plot(empty_condition) isa Plots.Plot

    two_qubit = QCircuit([Depolarizing((3, 1); p=0.1)])
    @test qc.plot(two_qubit) isa Plots.Plot
    readout = ReadoutError(1; p0_to_1=0.1, p1_to_0=0.2, scope=:all)
    program = with_noise(QCircuit([HGate(1)]), NoiseModel(readout=[readout]))
    plt = qc.plot(program; title="Expanded")
    @test occursin("Expanded", plt[1][:title])
    @test occursin("Readout all", plt[1][:title])
    @test occursin("qubits=(1,)", plt[1][:title])
    @test occursin("0.2", plt[1][:title])
    @test qc.circuit_plot(program) isa Plots.Plot
    @test Plots.plot(program) isa Plots.Plot
end
