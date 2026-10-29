using Test, Random, LinearAlgebra, MOSSQuantum
using SparseArrays: sparse, spzeros

include(joinpath(@__DIR__, "..", "..", "algorithm_zoo", "sqd", "sqd.jl"))

@testset "Sample-based quantum diagonalization example" begin
    # Qubit 1 is the least significant bit; repeated shots do not enlarge
    # the subspace, and shots outside the requested symmetry sector are dropped.
    shots = [1 0 0 1; 0 1 1 0; 1 0 0 1; 1 0 0 0; 0 0 0 0]
    @test SQDExample.sampled_basis(shots; particles=2) == [6, 9]
    @test SQDExample.sampled_basis([1 0 0 0; 0 1 0 0]; particles=1) == [1, 2]
    @test SQDExample.particle_sector(4, 2) == [3, 5, 6, 9, 10, 12]
    @test SQDExample.particle_sector(3, 0) == [0]
    sector = SQDExample.particle_sector(12, 6)
    @test length(sector) == binomial(12, 6) == 924
    @test all(i -> count_ones(i) == 6, sector)

    # A non-real off-diagonal element detects transposed or conjugated projection.
    h = ComplexF64[2 0 0 1im; 0 4 0 0; 0 0 5 0; -1im 0 0 -1]
    projected = SQDExample.projected_hamiltonian([0, 3], h)
    expected = ComplexF64[2 1im; -1im -1]
    @test projected == expected
    solution = SQDExample.solve_subspace([0, 3], h)
    @test solution.basis == [0, 3]
    @test solution.energy ≈ eigmin(Hermitian(expected))
    @test norm(solution.coefficients) ≈ 1
    @test expected * solution.coefficients ≈ solution.energy * solution.coefficients
    @test SQDExample.solve_subspace([0], h).energy ≈ 2
    @test_throws ArgumentError SQDExample.projected_hamiltonian(Int[], h)
    @test_throws ArgumentError SQDExample.projected_hamiltonian([0, 0], h)
    @test_throws ArgumentError SQDExample.projected_hamiltonian([4], h)
    @test_throws ArgumentError SQDExample.projected_hamiltonian([0], [1.0 1; 0 1])
    @test_throws ArgumentError SQDExample.sampled_basis([0 2]; particles=1)
    @test_throws ArgumentError SQDExample.demo(shots=0)

    # Independent sparse tensor-product construction of the 12-qubit spin
    # Hamiltonian. Factors run from qubit 12 to qubit 1, the least significant.
    id = sparse([1.0 0.0; 0.0 1.0])
    number = sparse([0.0 0.0; 0.0 1.0])
    lowering = sparse([0.0 1.0; 0.0 0.0])
    raising = sparse(transpose(lowering))
    local_operator(ops) = reduce(kron, [get(ops, q, id) for q in 12:-1:1])
    reference_h = spzeros(Float64, 2^12, 2^12)
    for q in 1:12
        reference_h += (-0.55 + 0.10 * (q - 1) + 0.04 * sin(q)) * local_operator(Dict(q => number))
        j = mod(q, 12) + 1
        coupling = 0.6 + 0.15 * cos(q)
        reference_h += 0.25 * local_operator(Dict(q => number, j => number))
        reference_h += coupling * (local_operator(Dict(q => raising, j => lowering)) +
                                   local_operator(Dict(q => lowering, j => raising)))
    end
    hamiltonian = SQDExample.toy_hamiltonian()
    sector_h = reference_h[sector .+ 1, sector .+ 1]
    @test SQDExample.projected_hamiltonian(sector, hamiltonian) ≈ sector_h
    @test_throws ArgumentError SQDExample.preparation_circuit(zeros(43))
    @test_throws ArgumentError SQDExample.optimize_parameters(hamiltonian; iterations=-1)
    @test_throws ArgumentError SQDExample.optimize_parameters(hamiltonian; difference_step=0)
    @test_throws ArgumentError SQDExample.optimize_parameters(hamiltonian; checkpoint_interval=0)
    starting_angles = SQDExample.initial_parameters()
    zero_steps = SQDExample.optimize_parameters(hamiltonian; iterations=0, initial=starting_angles)
    @test zero_steps.parameters == starting_angles
    @test zero_steps.final_energy == zero_steps.initial_energy
    @test length(zero_steps.energy_history) == 1
    checkpointed = SQDExample.optimize_parameters(hamiltonian; iterations=3, checkpoint_interval=2)
    @test getproperty.(checkpointed.checkpoints, :iteration) == [0, 2, 3]
    @test checkpointed.checkpoints[1].parameters == starting_angles
    @test checkpointed.checkpoints[end].parameters == checkpointed.parameters
    @test checkpointed.checkpoints[end].energy == checkpointed.final_energy
    @test checkpointed.checkpoints[2].energy ≈ minimum(checkpointed.energy_history[1:3])
    @test checkpointed.checkpoints[1].parameters !== checkpointed.checkpoints[end].parameters

    # Compare optimized and starting circuits with identical shots and RNG
    # seeds. The sector reference is built independently above, not used as
    # an optimization objective.
    shots = 32768
    first_run = SQDExample.demo(shots=shots, iterations=350, rng=MersenneTwister(42))
    @test size(first_run.samples) == (shots, 12)
    @test all(vec(sum(first_run.samples; dims=2)) .== 6)
    initial_state = SQDExample.preparation_circuit(SQDExample.initial_parameters()) * StateVector(12)
    final_state = SQDExample.preparation_circuit(first_run.optimization.parameters) * StateVector(12)
    @test first_run.samples == sample(MersenneTwister(42), final_state, shots)
    initial_samples = sample(MersenneTwister(42), initial_state, shots)
    @test first_run.initial_sampled.basis == SQDExample.sampled_basis(initial_samples; particles=6)
    # Evaluate circuit states against the independently assembled Hamiltonian.
    initial_vector = amplitudes(initial_state)
    final_vector = amplitudes(final_state)
    initial_energy = real(dot(initial_vector, reference_h * initial_vector))
    final_energy = real(dot(final_vector, reference_h * final_vector))
    @test first_run.optimization.initial_energy ≈ initial_energy atol=1e-8
    @test first_run.optimization.final_energy ≈ final_energy atol=1e-8
    @test first_run.optimization.final_energy ≈ minimum(first_run.optimization.energy_history)
    @test length(first_run.optimization.energy_history) == 351
    @test final_energy < initial_energy - 0.1
    @test first_run.sampled.basis == SQDExample.sampled_basis(first_run.samples; particles=6)
    @test !isempty(first_run.sampled.basis)
    @test length(first_run.sampled.basis) <= shots
    @test first_run.exact.basis == sector
    @test first_run.sampled.energy >= first_run.exact.energy - 1e-8
    @test first_run.sampled.energy < first_run.initial_sampled.energy
    @test first_run.sampled.energy - first_run.exact.energy < 0.02
    # Finite-shot quality can fluctuate; exercise two further fixed streams
    # without rerunning the optimizer.
    for seed in (1, 2026)
        draws = sample(MersenneTwister(seed), final_state, shots)
        basis = SQDExample.sampled_basis(draws; particles=6)
        estimate = SQDExample.solve_subspace(basis, hamiltonian).energy
        @test first_run.exact.energy - 1e-8 <= estimate < first_run.exact.energy + 0.02
    end

    # Test eigenpairs against the independently assembled matrix, not the
    # projected-matrix builder used by the implementation itself.
    sampled = first_run.sampled
    sampled_h = reference_h[sampled.basis .+ 1, sampled.basis .+ 1]
    @test sampled.energy ≈ eigmin(Hermitian(Matrix(sampled_h))) atol=1e-8
    @test first_run.exact.energy ≈ eigmin(Hermitian(Matrix(sector_h))) atol=1e-8
    @test norm(sampled_h * sampled.coefficients - sampled.energy * sampled.coefficients) < 1e-7
    @test norm(sector_h * first_run.exact.coefficients - first_run.exact.energy * first_run.exact.coefficients) < 1e-7
    @test norm(first_run.exact.coefficients) ≈ 1
end
