using Test, MOSS, Zygote

struct UnsupportedAdjointInstruction <: MOSS.AbstractInstruction end
MOSS.positions(::UnsupportedAdjointInstruction) = (1,)

@testset "circuit differentiation capabilities" begin
    initial = qstate(1)
    observable = QubitsTerm(1 => "Z")
    objective(circuit) = real(expectation(observable, circuit * initial))

    for operation in (QMeasure(1), QSelect(1), QuantumGate(1, [1.0 0; 0 0.5]), UnsupportedAdjointInstruction())
        circuit = QCircuit()
        push!(circuit, operation)
        @test_throws ArgumentError Zygote.gradient(objective, circuit)
        nested = QCircuit()
        push!(nested, circuit)
        @test_throws ArgumentError Zygote.gradient(objective, nested)
    end

    circuit = QCircuit()
    push!(circuit, RyGate(1, 0.3; isparas=true))
    @test Zygote.gradient(objective, circuit)[1] ≈ [-sin(0.3)]

    # A singular channel is supported through saved channel inputs, without an
    # inverse superoperator. The output is independent of the rotation angle.
    push!(circuit, AmplitudeDamping(1; γ=1.0))
    @test Zygote.gradient(objective, circuit)[1] ≈ [0.0] atol=1e-14

    batch = BatchStateVector(1, 2)
    batch_loss(circuit) = real(sum(expectation(observable, circuit * batch)))
    @test isempty(Zygote.gradient(batch_loss, QCircuit())[1])
    @test Zygote.gradient(batch_loss, QCircuit([RyGate(1, 0.3; isparas=true)]))[1] ≈ [-2sin(0.3)]
    @test_throws ArgumentError Zygote.gradient(batch_loss, QCircuit([QMeasure(1)]))

    # Standalone post-selection retains its existing separate differentiation.
    selection_loss(values) = last(post_select(StateVector(values), 1, 0))
    @test Zygote.gradient(selection_loss, [0.6, 0.8])[1] ≈ [1.2, 0.0]
end
