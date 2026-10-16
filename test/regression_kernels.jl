using Test, LinearAlgebra, Random, MOSS

# Independent dense embedding using the public least-significant-qubit ordering.
function regression_embed_gate(n, positions, local_matrix)
    full = zeros(eltype(local_matrix), 2^n, 2^n)
    for input in 0:(2^n - 1)
        local_input = sum(((input >> (q - 1)) & 1) << (i - 1) for (i, q) in enumerate(positions))
        for local_output in 0:(2^length(positions) - 1)
            output = input
            for (i, q) in enumerate(positions)
                output = (output & ~(1 << (q - 1))) | (((local_output >> (i - 1)) & 1) << (q - 1))
            end
            full[output + 1, input + 1] = local_matrix[local_output + 1, local_input + 1]
        end
    end
    return full
end

@testset "Batch gate dispatch agrees with dense evolution" begin
    rng = MersenneTwister(479)
    positions_to_check = ((1,), (4,), (1,3), (1,4), (1,5), (4,5),
        (1,2,3), (1,2,4), (1,2,5), (1,3,4), (1,3,5), (1,4,5),
        (2,3,4), (2,3,5), (2,4,5), (3,4,5), (4,5,6),
        (1,2,3,4), (1,3,4,6), (1,2,3,4,5), (1,2,4,5,6))
    for positions in positions_to_check
        d = 2^length(positions)
        a = randn(rng, ComplexF64, d, d)
        u = exp(0.1im * (a + a'))
        gate = QuantumGate(positions, u)
        full = regression_embed_gate(6, positions, u)
        for bs in (1, 2, 4, 5)
            data = randn(rng, ComplexF64, 64, bs)
            batch = BatchStateVector(copy(data), 6, bs)
            result = apply!(gate, batch)
            @test storage(result) ≈ full * data atol=1e-11
        end
        if length(positions) == 5
            data = randn(rng, ComplexF64, 64, 2)
            batch = BatchStateVector(copy(data), 6, 2)
            @test storage(MOSS.apply_serial!(gate, batch)) ≈ full * data atol=1e-11
        end
    end
end

@testset "Batch four- and five-site expectation values" begin
    rng = MersenneTwister(480)
    for positions in ((1,2,3,4), (1,3,4,6), (1,2,3,4,5), (1,2,4,5,6))
        d = 2^length(positions)
        m = randn(rng, ComplexF64, d, d) # Non-Hermitian, so conjugation matters.
        gate = QuantumGate(positions, m)
        full = regression_embed_gate(6, positions, m)
        ket = BatchStateVector(randn(rng, Float64, 64, 3), 6)
        bra = BatchStateVector(randn(rng, ComplexF64, 64, 3), 6)
        expected = [dot(storage(ket)[:,i], full, storage(ket)[:,i]) for i in 1:3]
        transitions = [dot(storage(bra)[:,i], full, storage(ket)[:,i]) for i in 1:3]
        @test expectation(gate, ket) ≈ expected
        @test expectation(bra, gate, ket) ≈ transitions
    end
    h = QubitsTerm(1=>"Z", 2=>"Z", 3=>"Z", 4=>"Z"; coeff=2.)
    @test expectation(h, BatchStateVector(4,2)) ≈ [2., 2.]
    @test expectation(QubitsOperator(h), BatchStateVector(4,2)) ≈ [2., 2.]
    @test expectation(ComplexF64[im 0; 0 1], BatchStateVector(Float64,1,2)) ≈ [im, im]
    identity_term = QubitsTerm(Int[], Matrix{Float64}[], 2im)
    batch = BatchStateVector(Float64, 1, 2)
    @test expectation(identity_term, batch) ≈ [2im, 2im]
    @test expectation(batch, identity_term, batch) ≈ [2im, 2im]
    state = StateVector(Float64, 1)
    @test expectation(identity_term, state) ≈ 2im
    @test expectation(state, identity_term, state) ≈ 2im
end

@testset "Hamiltonian density matrix multiplication is H rho" begin
    rng = MersenneTwister(481)
    for n in (1, 2, 3, 4, 5, 6), T in (Float64, ComplexF64)
        a = randn(rng, T, 2^n, 2^n)
        rho_data = a * a'
        rho_data ./= tr(rho_data)
        rho = DensityMatrix(copy(rho_data), n)
        terms = [i => (i == 1 ? "Y" : "+") for i in 1:n]
        term = QubitsTerm(terms...; coeff=0.3 + 0.7im)
        operator = QubitsOperator(term, QubitsTerm(1=>"Z"; coeff=0.6))
        for h in (term, operator)
            dense = Matrix(matrix(n, h))
            @test storage(h * rho) ≈ dense * rho_data atol=1e-11
            @test expectation(h, rho) ≈ tr(dense * rho_data) atol=1e-11
            @test storage(rho) == rho_data
        end
    end
    h = QubitsTerm(1=>"Z", 2=>"Z", 3=>"Z", 4=>"Z"; coeff=2.)
    rho = DensityMatrix(4)
    @test expectation(h, rho) ≈ 2
    @test expectation(QubitsOperator(h), rho) ≈ 2
    @test expectation(QubitsTerm(Int[], Matrix{Float64}[], 2im), rho) ≈ 2im
end

@testset "Batch amplitude encoding validates capacity and normalization" begin
    @test_throws DimensionMismatch batch_amplitude_encoding(ones(4,1); nqubits=1)
    @test_throws ArgumentError batch_amplitude_encoding(ones(2,1); nqubits=-1)
    @test_throws ArgumentError batch_amplitude_encoding(zeros(2,1))
    @test_throws ArgumentError batch_amplitude_encoding(reshape([Inf,1.],2,1))
    inputs = [1. 2.; 2. 1.; 3. 4.]
    original = copy(inputs)
    batch = batch_amplitude_encoding(inputs; nqubits=2)
    expected = vcat(inputs ./ sqrt.(sum(abs2, inputs; dims=1)), zeros(1,2))
    @test storage(batch) ≈ expected
    @test norm(batch) ≈ [1.,1.]
    @test inputs == original
end
