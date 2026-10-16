using Test
import MOSS
using MOSSDemoBackend

@testset "independent backend package" begin
    state = DemoState(3)
    circuit = MOSS.QCircuit([DemoFlip(1), MOSS.XGate(3)])
    @test MOSS.supports(MOSS.backend(state), circuit, state)
    @test MOSS.apply!(circuit, state) === state
    @test state.bits == [true, false, true]
    @test MOSS.expectation(MOSS.ZGate(1), state) == -1
    wide = DemoState(6)
    @test MOSS.apply!(DemoFlip((1, 2, 3, 4, 5, 6)), wide).bits == trues(6)
    @test !hasmethod(MOSS.storage, Tuple{DemoState})
    @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.HGate(1), state)
    @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.AmplitudeDamping(1; γ=0.1), state)
    @test_throws MOSS.UnsupportedOperation MOSS.expectation(MOSS.XGate(1), state)
end
