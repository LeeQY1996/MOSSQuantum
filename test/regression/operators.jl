using Test
using LinearAlgebra
using MOSSQuantum
using MOSSQuantum.Utilities

@testset "channel targets and Kraus ordering" begin
    for channel in (AmplitudeDamping(2; γ=1.0), PhaseDamping(2; γ=1.0), Depolarizing(2; p=1.0))
        @test positions(channel) == (2,)
    end
    excited = DensityMatrix(onehot_encoding([0, 1]))
    @test apply!(AmplitudeDamping(2; γ=1.0), excited) ≈ DensityMatrix(2)
    dephased = apply!(PhaseDamping(2; γ=1.0), DensityMatrix(qstate([0.0, 0.5])))
    mixed_target = Diagonal([0.5, 0.0, 0.5, 0.0])
    @test storage(dephased) ≈ mixed_target
    @test storage(apply!(Depolarizing(2; p=1.0), DensityMatrix(2))) ≈ mixed_target

    state = normalize(StateVector(ComplexF64[1, 2im, 3, 4im]))
    channel = QuantumMap((2, 1), [CNOT])
    rho = DensityMatrix(state)
    @test apply!(channel, copy(rho)) ≈ apply!(CNOTGate(2, 1), copy(rho))
    @test kraus_matrices(channel) == [CNOT]

    phase_channel = QuantumMap(1, [S])
    real_rho = DensityMatrix([0.5 0.5; 0.5 0.5])
    @test eltype(phase_channel) == ComplexF64
    @test eltype(typeof(phase_channel)) == ComplexF64
    @test storage(apply!(phase_channel, copy(real_rho))) ≈ S * storage(real_rho) * S'
    @test storage(MOSSQuantum.apply_dagger!(phase_channel, copy(real_rho))) ≈ S' * storage(real_rho) * S
    @test storage(MOSSQuantum.apply_inverse!(phase_channel, copy(real_rho))) ≈ S' * storage(real_rho) * S
end

@testset "parameter management and remapping of non-gate operations" begin
    circuit = QCircuit([RyGate(1, 0.1; isparas=true), Depolarizing(1; p=0.1), QMeasure(1), QSelect(1)])
    @test parameters(circuit) == [0.1]
    @test active_parameters(circuit) == [0.1]
    @test reset_parameters!(circuit, [0.2]) === circuit
    @test parameters(circuit) == [0.2]
    @test deactivate_parameters!(circuit) === circuit
    @test nparameters(circuit) == 0
    @test activate_parameters!(circuit) === circuit
    @test nparameters(circuit) == 1
    for operation in circuit.operations[2:end]
        @test activate_parameter!(operation, 1) === operation
        @test deactivate_parameter!(operation, 1) === operation
    end

    measurement = QMeasure(2; auto_reset=false, keep=false)
    selection = QSelect(4, 1)
    moved = shift(QCircuit([measurement, QCircuit([selection])]), 5)
    @test positions(moved) == [7, 9]
    @test moved[1].auto_reset == false
    @test moved[1].keep == false
    @test moved[2][1].state == 1
    @test positions(measurement) == [2]
    @test positions(shift(selection, 2)) == [6]
    @test positions(change_positions(measurement, Dict(2 => 8))) == [8]
end

@testset "operator addition preserves operands" begin
    a = QubitsOperator(QubitsTerm(1 => "Z"))
    b = QubitsOperator(QubitsTerm(1 => "X"))
    a_matrix, b_matrix = matrix(1, a), matrix(1, b)
    @test matrix(1, a + QubitsTerm(1 => "X")) ≈ a_matrix + X
    @test matrix(1, a) == a_matrix
    @test matrix(1, a + b) ≈ a_matrix + b_matrix
    @test matrix(1, a) == a_matrix
    @test matrix(1, b) == b_matrix
    @test matrix(1, a + a) ≈ 2 * a_matrix
    @test matrix(1, a) == a_matrix
    copied = copy(a)
    MOSSQuantum.QuantumCircuits.add!(copied, QubitsTerm(1 => "Y"))
    @test matrix(1, a) == a_matrix
end

@testset "simplification and Trotter preserve isolated local fields" begin
    single = QubitsOperator(QubitsTerm(1 => "Z"; coeff=0.3))
    @test matrix(1, simplify(single)) ≈ matrix(1, single)
    state = normalize(StateVector(ComplexF64[1, 2im]))
    t = -0.1im
    @test storage(trotter_propagator(single, t) * state) ≈ exp(Matrix(matrix(1, single)) * t) * storage(state)

    h = QubitsOperator(QubitsTerm(1 => "Z"; coeff=0.3),
        QubitsTerm(2 => "X", 3 => "X"; coeff=0.7),
        QubitsTerm(2 => "Z"; coeff=0.2), QubitsTerm(4 => "X"; coeff=0.4))
    h_matrix = Matrix(matrix(4, h))
    @test matrix(4, simplify(h)) ≈ h_matrix
    @test matrix(4, simplify(simplify(h))) ≈ h_matrix
    state4 = normalize(StateVector(collect(1.0:16.0)))
    @test storage(trotter_propagator(h, t) * state4) ≈ exp(h_matrix * t) * storage(state4)
    @test matrix(4, h) == h_matrix
end

@testset "two-parameter FSIM" begin
    fsim = MOSSQuantum.QuantumCircuits.Gates.FSIM
    @test fsim(0.3, 0.2) ≈ fsim(0.3, 0.2, 0.0, 0.0, 0.0)
    @test fsim(0.3, 0.2)' * fsim(0.3, 0.2) ≈ Matrix{ComplexF64}(I, 4, 4)
end

@testset "gate fusion preserves operation order and parameters" begin
    circuit = QCircuit([HGate(3), CNOTGate(3, 1), TGate(2), SWAPGate(2, 3), YGate(1)])
    state = normalize(StateVector(ComplexF64[1, 2im, 3, 4im, 5, 6im, 7, 8im]))
    fused = fuse_gates(circuit)
    @test length(fused) == 1
    @test length(circuit) == 5
    @test fused * state ≈ circuit * state
    @test fused * DensityMatrix(state) ≈ circuit * DensityMatrix(state)
    @test fuse_gates(circuit; max_qubits=2) * state ≈ circuit * state
    @test fuse_gates(circuit; max_qubits=1) * state ≈ circuit * state
    @test isempty(fuse_gates(QCircuit()))
    @test_throws ArgumentError fuse_gates(circuit; max_qubits=6)

    parameter_gate = RyGate(1, 0.2; isparas=true)
    noise = Depolarizing(1; p=0.1)
    noisy = QCircuit([HGate(1), XGate(1), parameter_gate, ZGate(1), XGate(1), noise, XGate(2), ZGate(2)])
    fused_noisy = fuse_gates(noisy)
    @test length(fused_noisy) == 5
    @test fused_noisy[2] === parameter_gate
    @test fused_noisy[4] === noise
    @test active_parameters(fused_noisy) == [0.2]
    @test fused_noisy * StateVector(2) ≈ noisy * StateVector(2)

    nested = QCircuit([QCircuit([XGate(1), ZGate(1)]), XGate(2), ZGate(2)])
    @test length(fuse_gates(nested)[1]) == 1
    @test fuse_gates(nested) * StateVector(2) ≈ nested * StateVector(2)
    measurement, selection = QMeasure(1), QSelect(1)
    boundaries = QCircuit([XGate(1), measurement, ZGate(1), selection, XGate(1)])
    @test fuse_gates(boundaries).operations == boundaries.operations

    wide = QCircuit([HGate(1), XGate(5), CNOTGate(5, 2), YGate(4), ZGate(3)])
    state5 = normalize(StateVector(ComplexF64.(1:32)))
    @test fuse_gates(wide) * state5 ≈ wide * state5
end
