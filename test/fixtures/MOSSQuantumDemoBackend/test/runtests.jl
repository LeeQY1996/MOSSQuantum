using Test
import MOSSQuantum
using MOSSQuantumDemoBackend

@testset "independent backend package" begin
    state = DemoState(3)
    circuit = MOSSQuantum.QCircuit([DemoFlip(1), MOSSQuantum.XGate(3)])
    @test MOSSQuantum.supports(MOSSQuantum.backend(state), circuit, state)
    @test MOSSQuantum.apply!(circuit, state) === state
    @test state.bits == [true, false, true]
    @test MOSSQuantum.expectation(MOSSQuantum.ZGate(1), state) == -1
    wide = DemoState(6)
    @test MOSSQuantum.apply!(DemoFlip((1, 2, 3, 4, 5, 6)), wide).bits == trues(6)
    @test !hasmethod(MOSSQuantum.storage, Tuple{DemoState})
    @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.HGate(1), state)
    @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.AmplitudeDamping(1; γ=0.1), state)
    @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.expectation(MOSSQuantum.XGate(1), state)
end
