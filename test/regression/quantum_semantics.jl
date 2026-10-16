using Test
using LinearAlgebra
using MOSS
using MOSS.Utilities

@testset "Squared Uhlmann fidelity" begin
    zero_state = onehot_encoding([0])
    one_state = onehot_encoding([1])
    maximally_mixed = DensityMatrix(Matrix{ComplexF64}(I, 2, 2) / 2)
    @test fidelity(zero_state, one_state) == 0
    @test fidelity(DensityMatrix(zero_state), DensityMatrix(one_state)) == 0
    @test fidelity(zero_state, maximally_mixed) ≈ 0.5
    @test fidelity(maximally_mixed, zero_state) ≈ 0.5
    @test fidelity(DensityMatrix(zero_state), maximally_mixed) ≈ 0.5
    @test fidelity(maximally_mixed, maximally_mixed) ≈ 1

    @testset "Pure-state representation invariance" begin
        for (a, b) in (
            (ComplexF64[1, 2im], ComplexF64[2 + im, -1]),
            (ComplexF64[1, 2im, -3, 4 - im], ComplexF64[2im, -1, 4 + im, 3]),
        )
            x, y = StateVector(normalize(a)), StateVector(normalize(b))
            expected = abs2(dot(normalize(a), normalize(b)))
            rho, sigma = DensityMatrix(x), DensityMatrix(y)
            @test fidelity(x, y) ≈ expected atol=1e-12
            @test fidelity(x, sigma) ≈ expected atol=1e-12
            @test fidelity(rho, y) ≈ expected atol=1e-12
            @test fidelity(rho, sigma) ≈ expected atol=1e-12
            @test fidelity(sigma, rho) ≈ expected atol=1e-12
            @test fidelity(rho, rho) ≈ 1 atol=1e-12
        end
    end

    @testset "Commuting and noncommuting mixed states" begin
        rho = DensityMatrix([0.8 0.0; 0.0 0.2])
        diagonal = DensityMatrix([0.3 0.0; 0.0 0.7])
        @test fidelity(rho, diagonal) ≈ (sqrt(0.8 * 0.3) + sqrt(0.2 * 0.7))^2

        sigma = DensityMatrix(ComplexF64[0.5 0.2im; -0.2im 0.5])
        @test !isapprox(storage(rho) * storage(sigma), storage(sigma) * storage(rho))
        # Independent closed form for the squared fidelity of two qubit states.
        expected = real(tr(storage(rho) * storage(sigma))) +
            2sqrt(real(det(storage(rho)) * det(storage(sigma))))
        @test fidelity(rho, sigma) ≈ expected atol=1e-12
        @test fidelity(sigma, rho) ≈ expected atol=1e-12
        @test fidelity(sigma, sigma) ≈ 1 atol=1e-12
        @test fidelity(cat(rho, rho), cat(sigma, sigma)) ≈ expected^2 atol=1e-12

        rho32 = DensityMatrix(Float32[0.8 0.0; 0.0 0.2])
        sigma32 = DensityMatrix(ComplexF32[0.5 0.2im; -0.2im 0.5])
        @test fidelity(rho32, sigma32) ≈ expected atol=2e-6
        @test_throws DimensionMismatch fidelity(rho, DensityMatrix(2))
        @test_throws DomainError fidelity(DensityMatrix([1.1 0.0; 0.0 -0.1]), sigma)
    end
end

@testset "Two-sided density-matrix time evolution" begin
    h = QubitsOperator(QubitsTerm(1 => "Z"))
    psi = StateVector(normalize(ComplexF64[1, 2im]))
    rho = DensityMatrix(psi)
    original_psi, original_rho = copy(psi), copy(rho)

    @testset "Analytic Z evolution and pure-state consistency" begin
        for time in (0.0, 0.37, -0.29)
            coefficient = -im * time
            unitary = Diagonal(ComplexF64[cis(-time), cis(time)])
            evolved_psi = time_evolution(h, coefficient, psi; tol=1e-12)
            evolved_rho = time_evolution(h, coefficient, rho; tol=1e-12)
            expected = unitary * storage(rho) * unitary'
            @test storage(evolved_psi) ≈ unitary * storage(psi) atol=1e-12
            @test storage(evolved_rho) ≈ expected atol=1e-12
            @test evolved_rho ≈ DensityMatrix(evolved_psi) atol=1e-12
            @test tr(evolved_rho) ≈ 1 atol=1e-12
            @test storage(evolved_rho) ≈ storage(evolved_rho)' atol=1e-12
            @test minimum(eigvals(Hermitian(storage(evolved_rho)))) >= -1e-12
        end
        @test psi == original_psi
        @test rho == original_rho
    end

    @testset "Mixed-state complex and imaginary-time coefficients" begin
        mixed = DensityMatrix(ComplexF64[0.6 0.12 + 0.18im; 0.12 - 0.18im 0.4])
        original = copy(mixed)
        for coefficient in (-0.23im, 0.2, 0.12 - 0.19im)
            propagator = Diagonal(exp.(coefficient .* [1, -1]))
            expected = propagator * storage(mixed) * propagator'
            evolved = time_evolution(h, coefficient, mixed; tol=1e-12)
            @test storage(evolved) ≈ expected atol=1e-12
            @test storage(evolved) ≈ storage(evolved)' atol=1e-12
            @test minimum(eigvals(Hermitian(storage(evolved)))) >= -1e-12
        end
        imaginary_time = time_evolution(h, 0.2, mixed; tol=1e-12)
        @test tr(imaginary_time) ≈ 0.6exp(0.4) + 0.4exp(-0.4) atol=1e-12
        @test !isapprox(tr(imaginary_time), 1)
        @test mixed == original
    end

    @testset "Multi-qubit threaded operator path" begin
        # Three-qubit density storage exceeds the threaded kernel threshold.
        # A Y term also makes an accidental transpose observable in this test.
        h3 = QubitsOperator(QubitsTerm(1 => "Y"; coeff=0.31),
            QubitsTerm(3 => "Z"; coeff=-0.24),
            QubitsTerm(1 => "X", 2 => "Z"; coeff=0.17))
        a = ComplexF64[sin(i) + im * cos(2i) for i in 1:8]
        b = ComplexF64[cos(3i) - im * sin(2i) for i in 1:8]
        mixed = 0.65 * DensityMatrix(StateVector(normalize(a))) +
            0.35 * DensityMatrix(StateVector(normalize(b)))
        propagator = exp(-0.21im * Matrix(matrix(3, h3)))
        expected = propagator * storage(mixed) * propagator'
        evolved = time_evolution(h3, -0.21im, mixed; tol=1e-12)
        @test storage(evolved) ≈ expected atol=1e-11
        @test tr(evolved) ≈ 1 atol=1e-11
        @test storage(evolved) ≈ storage(evolved)' atol=1e-11
        @test minimum(eigvals(Hermitian(storage(evolved)))) >= -1e-11
        @test time_evolution(h3, 0.21im, evolved; tol=1e-12) ≈ mixed atol=1e-11
    end
end
