@testset "Variational circuits and dense ground states" begin
    for make_circuit in (variational_circuit_1d, real_variational_circuit_1d)
        circuit = make_circuit(3, 2)
        state = circuit * StateVector(3)
        @test norm(state) ≈ 1
        @test nparameters(circuit) > 0
    end
    h = ising_1d(3; J=0.7, hz=0.4)
    energy, state = ground_state(h; tol=1e-12)
    @test energy ≈ eigmin(Hermitian(Matrix(matrix(3, h)))) atol=1e-9
    @test expectation(h, state) ≈ energy atol=1e-9
end
