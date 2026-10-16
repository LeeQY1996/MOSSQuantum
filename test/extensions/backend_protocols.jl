# Keep the normal test suite independent of package resolution. The same fixture
# is also tested with its own Project.toml in an isolated environment.
include(joinpath(@__DIR__, "..", "fixtures", "MOSSDemoBackend", "src", "MOSSDemoBackend.jl"))

module BackendContractFailures
import MOSS
import ..MOSSDemoBackend

struct BadReturn <: MOSS.AbstractInstruction end
MOSS.positions(::BadReturn) = ()
MOSS.supports(::MOSSDemoBackend.DemoBackend, ::BadReturn, ::MOSSDemoBackend.DemoState; action::Symbol=:apply) =
    action === :apply
MOSS.apply!(::MOSSDemoBackend.DemoBackend, ::BadReturn, ::MOSSDemoBackend.DemoState) = nothing
end

@testset "public backend and instruction protocols" begin
    cpu = CPUBackend()
    state = StateVector(3)
    @test state isa AbstractQuantumState
    @test DensityMatrix(1) isa AbstractQuantumState
    @test BatchStateVector(1, 2) isa AbstractQuantumState
    @test MOSS.backend(state) isa CPUBackend
    @test supports(cpu, HGate(1), state)
    @test supports(cpu, ZGate(1), state; action=:expectation)
    @test !supports(cpu, HGate(1), state; action=:gradient)
    @test apply!(cpu, XGate(2), state) === state
    @test expectation(cpu, ZGate(2), state) ≈ -1
    @test expectation(cpu, QubitsTerm(2 => "Z"), state) ≈ -1
    @test expectation(cpu, Matrix{Float64}(I, 8, 8), BatchStateVector(3, 2)) ≈ [1, 1]
    @test_throws ArgumentError apply!(cpu, XGate(4), state)
    @test_throws ArgumentError expectation(cpu, ZGate(4), state)
    @test_throws DimensionMismatch expectation(cpu, ones(2, 2), state)
    @test_throws UnsupportedOperation expectation(cpu, ZGate(1), DensityMatrix(1))
    @test_throws UnsupportedOperation apply!(cpu, QSelect(1), DensityMatrix(1))
    @test !supports(cpu, QMeasure(1; keep=false), state)

    @test apply!(cpu, QCircuit(), state) === state
    measured = StateVector(1)
    metadata = apply!(cpu, QMeasure(1; auto_reset=false), measured)
    @test metadata == (0, 1.0)
    @test apply!(cpu, QCircuit([QMeasure(1), XGate(1)]), measured) === measured
    @test expectation(cpu, ZGate(1), measured) ≈ -1

    noisy = QCircuit([HGate(1), AmplitudeDamping(1; γ=0.1)])
    @test supports(cpu, noisy, StateVector(1))
    @test apply!(cpu, noisy, StateVector(1)) isa DensityMatrix
    invalid_after_noise = QCircuit([AmplitudeDamping(1; γ=0.1), QSelect(1)])
    @test !supports(cpu, invalid_after_noise, StateVector(1))
    @test_throws UnsupportedOperation apply!(cpu, invalid_after_noise, StateVector(1))
    nested_invalid = QCircuit([QCircuit([AmplitudeDamping(1; γ=0.1)]), QSelect(1)])
    @test !supports(cpu, nested_invalid, StateVector(1))

    large_gate = QuantumGate((1, 2, 3, 4, 5, 6), Matrix{Float64}(I, 64, 64))
    @test validate_positions(large_gate, 6) === nothing
    @test !supports(cpu, large_gate, StateVector(6))
    @test_throws UnsupportedOperation apply!(cpu, large_gate, StateVector(6))
    large_channel = QuantumMap((1, 2, 3), [Matrix{Float64}(I, 8, 8)])
    @test validate_positions(large_channel, 3) === nothing
    @test !supports(cpu, large_channel, state)
    @test_throws UnsupportedOperation apply!(cpu, large_channel, state)

    term = QubitsTerm(1 => "Z")
    @test !(term isa AbstractInstruction)
    @test_throws ArgumentError QCircuit([term])
    @test_throws ArgumentError push!(QCircuit(), term)
    circuit = QCircuit([XGate(1)])
    @test_throws ArgumentError setindex!(circuit, term, 1)
    @test_throws ArgumentError append!(circuit, [HGate(1), term])
    @test length(circuit) == 1
end

@testset "external implicit-state backend" begin
    DemoState = MOSSDemoBackend.DemoState
    DemoBackend = MOSSDemoBackend.DemoBackend
    DemoFlip = MOSSDemoBackend.DemoFlip
    state = DemoState(6)
    @test state isa AbstractQuantumState
    @test DemoFlip(1) isa AbstractInstruction
    @test MOSS.backend(state) isa DemoBackend
    @test !hasmethod(storage, Tuple{DemoState})
    @test !hasfield(DemoState, :data)
    @test copy(state).bits == state.bits
    @test copy(state).bits !== state.bits
    wide_state = DemoState(6)
    wide_operation = DemoFlip((1, 2, 3, 4, 5, 6))
    @test supports(MOSS.backend(wide_state), wide_operation, wide_state)
    @test apply!(wide_operation, wide_state).bits == trues(6)
    circuit = QCircuit([DemoFlip(1), XGate(6), QCircuit([DemoFlip(3)])])
    @test nparameters(circuit) == 0
    @test parameters(circuit) == []
    @test supports(MOSS.backend(state), circuit, state)
    @test apply!(circuit, state) === state
    @test state.bits == [true, false, true, false, false, true]
    @test expectation(ZGate(1), state) == -1
    @test expectation(MOSS.backend(state), ZGate(2), state) == 1
    @test_throws ArgumentError apply!(DemoFlip(7), state)
    @test !supports(CPUBackend(), DemoFlip(1), StateVector(1))
    @test !supports(MOSS.backend(state), HGate(1), state)
    @test !supports(MOSS.backend(state), AmplitudeDamping(1; γ=0.1), state)
    @test !supports(MOSS.backend(state), ZGate(1), state; action=:gradient)
    @test_throws UnsupportedOperation apply!(HGate(1), state)
    @test_throws UnsupportedOperation apply!(AmplitudeDamping(1; γ=0.1), state)
    @test_throws UnsupportedOperation expectation(XGate(1), state)
    @test_throws UnsupportedOperation apply!(CPUBackend(), DemoFlip(1), StateVector(1))
    @test_throws UnsupportedOperation expectation(CPUBackend(), ZGate(1), state)
    bad_circuit = QCircuit([DemoFlip(2), HGate(1)])
    before = copy(state.bits)
    @test_throws UnsupportedOperation apply!(bad_circuit, state)
    @test state.bits == before
    error = try
        apply!(HGate(1), state)
    catch caught
        caught
    end
    @test occursin("DemoBackend", sprint(showerror, error))
    @test occursin("HGate", sprint(showerror, error))

    bad_return = QCircuit([BackendContractFailures.BadReturn()])
    @test_throws ArgumentError apply!(bad_return, DemoState(1))
    @test_throws ArgumentError simulate(bad_return, DemoState(1))
end
