module SQDExample

using LinearAlgebra
using Random
using SparseArrays
using KrylovKit: eigsolve
using MOSSQuantum

export sampled_basis, particle_sector, projected_hamiltonian, solve_subspace,
       SpinHamiltonian, toy_hamiltonian, initial_parameters, preparation_circuit,
       variational_energy, optimize_parameters, demo

"""
    sampled_basis(samples; particles)

Filter shots by excitation count and return unique, sorted zero-based indices.
Column q is qubit q, the bit with weight 2^(q-1), in MOSSQuantum order.
"""
function sampled_basis(samples::AbstractMatrix; particles::Integer)
    n = size(samples, 2)
    0 <= n < 8sizeof(Int) - 1 || throw(ArgumentError("too many qubits for Int basis indices"))
    0 <= particles <= n || throw(ArgumentError("particles must be between 0 and the number of qubits"))
    all(x -> x == 0 || x == 1, samples) || throw(ArgumentError("samples must contain only 0 and 1"))
    indices = Int[]
    for row in axes(samples, 1)
        count = 0
        index = 0
        for (q, col) in enumerate(axes(samples, 2))
            bit = Int(samples[row, col])
            count += bit
            index |= bit << (q - 1)
        end
        count == particles && push!(indices, index)
    end
    return sort!(unique!(indices))
end

"""Enumerate a fixed-excitation sector, for the small reference calculation."""
function particle_sector(nqubits::Integer, particles::Integer)
    0 <= nqubits <= 20 || throw(ArgumentError("reference enumeration supports 0–20 qubits"))
    0 <= particles <= nqubits || throw(ArgumentError("invalid particle count"))
    return [i for i in 0:((1 << nqubits) - 1) if count_ones(i) == particles]
end

"""A number-conserving spin Hamiltonian on n qubits.

Each edge (i,j,t) contributes V*n_i*n_j + t*(σ⁺ᵢσ⁻ⱼ+σ⁻ᵢσ⁺ⱼ).
"""
struct SpinHamiltonian
    nqubits::Int
    onsite::Vector{Float64}
    edges::Vector{Tuple{Int, Int, Float64}}
    interaction::Float64
end

"""The 12-site model used in the example, with periodic boundary conditions."""
function toy_hamiltonian()
    n = 12
    onsite = [-0.55 + 0.10 * (q - 1) + 0.04 * sin(q) for q in 1:n]
    edges = [(q, mod1(q + 1, n), 0.6 + 0.15 * cos(q)) for q in 1:n]
    return SpinHamiltonian(n, onsite, edges, 0.25)
end

function check_basis(basis, dim)
    isempty(basis) && throw(ArgumentError("cannot diagonalize an empty sampled subspace"))
    all(i -> 0 <= i < dim, basis) || throw(ArgumentError("basis index outside Hamiltonian"))
    length(unique(basis)) == length(basis) || throw(ArgumentError("basis indices must be unique"))
end

"""Project a small Hermitian full matrix, using zero-based computational indices."""
function projected_hamiltonian(basis::AbstractVector{<:Integer}, hamiltonian::AbstractMatrix)
    dim = size(hamiltonian, 1)
    dim > 0 && size(hamiltonian, 2) == dim && ispow2(dim) ||
        throw(ArgumentError("Hamiltonian must be a nonempty square matrix with power-of-two dimension"))
    ishermitian(hamiltonian) || throw(ArgumentError("Hamiltonian must be Hermitian"))
    check_basis(basis, dim)
    indices = Int.(basis) .+ 1
    return hamiltonian[indices, indices]
end

"""Build only the selected sparse matrix elements, without a full 2^n matrix."""
function projected_hamiltonian(basis::AbstractVector{<:Integer}, h::SpinHamiltonian)
    check_basis(basis, 1 << h.nqubits)
    positions = Dict(index => k for (k, index) in enumerate(basis))
    rows, cols, values = Int[], Int[], Float64[]
    for (col, index) in enumerate(basis)
        occupied(q) = (index >> (q - 1)) & 1
        diagonal = sum(h.onsite[q] * occupied(q) for q in 1:h.nqubits) +
                   h.interaction * sum(occupied(i) * occupied(j) for (i, j, _) in h.edges)
        push!(rows, col); push!(cols, col); push!(values, diagonal)
        for (i, j, t) in h.edges
            if occupied(i) != occupied(j)
                target = index ⊻ (1 << (i - 1)) ⊻ (1 << (j - 1))
                row = get(positions, target, 0)
                if row != 0
                    push!(rows, row); push!(cols, col); push!(values, t)
                end
            end
        end
    end
    return sparse(rows, cols, values, length(basis), length(basis))
end

"""Return the lowest eigenpair and its residual norm, in sampled basis order.

For larger sparse problems use a converged Hermitian Krylov solve; small
projections use dense diagonalization. The coefficients are not sample counts.
"""
function solve_subspace(basis::AbstractVector{<:Integer}, hamiltonian)
    matrix = projected_hamiltonian(basis, hamiltonian)
    if size(matrix, 1) <= 128
        solution = eigen(Hermitian(Matrix(matrix)))
        energy, coefficients = solution.values[1], solution.vectors[:, 1]
    else
        start = [sin(0.73 * k) + cos(0.41 * k) for k in 1:size(matrix, 1)]
        values, vectors, info = eigsolve(matrix, start, 1, :SR;
            ishermitian=true, tol=1e-11, maxiter=500, krylovdim=40)
        info.converged >= 1 || error("subspace eigensolver failed to converge (residual $(info.normres))")
        energy, coefficients = real(values[1]), vectors[1]
    end
    residual = norm(matrix * coefficients - energy * coefficients)
    residual <= 1e-8 * max(1, abs(energy)) || error("subspace eigenpair residual too large: $residual")
    return (; energy, basis=Int.(basis), coefficients, residual)
end

"""Deterministic initial angles for the 44 independent exchange gates."""
initial_parameters() = [0.1 * sin(1.3 * k) for k in 1:44]

"""Prepare six excitations with eight layers of parameterized exchange gates.

Each gate acts only on the one-excitation subspace of a neighboring pair, so
the complete circuit preserves excitation number. The 44 angles are ordered
by layer and then by ascending qubit position.
"""
function preparation_circuit(parameters::AbstractVector=initial_parameters())
    length(parameters) == 44 || throw(ArgumentError("expected 44 exchange angles"))
    all(isfinite, parameters) || throw(ArgumentError("exchange angles must be finite"))
    circuit = QCircuit()
    for q in 1:2:12
        push!(circuit, HGate(q))
        push!(circuit, CNOTGate(q, q + 1))
        push!(circuit, XGate(q + 1))
        push!(circuit, ZGate(q))
    end
    k = 1
    for layer in 1:8
        edges = isodd(layer) ? (2:2:10) : (1:2:11)
        for q in edges
            c, s = cos(parameters[k]), sin(parameters[k])
            exchange = [1.0 0 0 0; 0 c -s 0; 0 s c 0; 0 0 0 1]
            push!(circuit, QuantumGate((q, q + 1), exchange))
            k += 1
        end
    end
    return circuit
end

"""Compute the ideal simulator expectation using the Hamiltonian, not its ground state.

The small example uses all state amplitudes and a matrix in the full fixed
excitation sector. On quantum hardware this objective would require measurement
of the Hamiltonian's terms instead.
"""
function variational_energy(parameters::AbstractVector, sector, sector_hamiltonian)
    state = preparation_circuit(parameters) * StateVector(12)
    vector = storage(state)[sector .+ 1]
    return real(dot(vector, sector_hamiltonian * vector))
end

"""Optimize ideal-state energy with Adam and central finite differences.

This is a simple demonstration optimizer, not a scalable training method.
The exact sector eigenpair is never used in this optimization. The best
observed iterate is retained, including the starting point.

Set `checkpoint_interval` to a positive integer to save independent copies of
the best parameters and their energy so far, at iteration 0, each interval,
and the last iteration. The default does not retain checkpoints.
"""
function optimize_parameters(hamiltonian::SpinHamiltonian;
        iterations::Integer=350, initial=initial_parameters(),
        learning_rate::Real=0.08, difference_step::Real=1e-4,
        checkpoint_interval::Union{Nothing,Integer}=nothing)
    hamiltonian.nqubits == 12 || throw(ArgumentError("the example circuit requires a 12-qubit Hamiltonian"))
    iterations >= 0 || throw(ArgumentError("iterations must be nonnegative"))
    isnothing(checkpoint_interval) || checkpoint_interval > 0 ||
        throw(ArgumentError("checkpoint interval must be positive"))
    isfinite(learning_rate) && learning_rate > 0 || throw(ArgumentError("learning rate must be positive and finite"))
    isfinite(difference_step) && difference_step > 0 || throw(ArgumentError("difference step must be positive and finite"))
    parameters = Float64.(initial)
    length(parameters) == 44 && all(isfinite, parameters) || throw(ArgumentError("expected 44 finite initial angles"))
    sector = particle_sector(12, 6)
    matrix = projected_hamiltonian(sector, hamiltonian)
    objective(values) = variational_energy(values, sector, matrix)
    initial_energy = objective(parameters)
    history = [initial_energy]
    best_energy, best_parameters = initial_energy, copy(parameters)
    checkpoints = NamedTuple{(:iteration, :parameters, :energy), Tuple{Int, Vector{Float64}, Float64}}[]
    if !isnothing(checkpoint_interval)
        push!(checkpoints, (iteration=0, parameters=copy(best_parameters), energy=best_energy))
    end
    moment, variance = zeros(length(parameters)), zeros(length(parameters))
    for iteration in 1:iterations
        gradient = similar(parameters)
        for k in eachindex(parameters)
            parameters[k] += difference_step
            plus = objective(parameters)
            parameters[k] -= 2difference_step
            minus = objective(parameters)
            parameters[k] += difference_step
            gradient[k] = (plus - minus) / (2difference_step)
        end
        moment .= 0.9 .* moment .+ 0.1 .* gradient
        variance .= 0.999 .* variance .+ 0.001 .* gradient.^2
        parameters .-= learning_rate .* (moment ./ (1 - 0.9^iteration)) ./
                      (sqrt.(variance ./ (1 - 0.999^iteration)) .+ 1e-8)
        energy = objective(parameters)
        push!(history, energy)
        if energy < best_energy
            best_energy, best_parameters = energy, copy(parameters)
        end
        if !isnothing(checkpoint_interval) &&
           (iteration % checkpoint_interval == 0 || iteration == iterations)
            push!(checkpoints, (iteration=iteration, parameters=copy(best_parameters), energy=best_energy))
        end
    end
    return (initial_energy=initial_energy, final_energy=best_energy,
            parameters=best_parameters, energy_history=history,
            iterations=iterations, evaluations=1 + iterations * (2length(parameters) + 1),
            checkpoints=checkpoints)
end

"""Optimize the circuit, compare finite-shot SQD, then compute a sector reference."""
function demo(; shots::Integer=32768, rng::AbstractRNG=MersenneTwister(42),
              iterations::Integer=350)
    shots > 0 || throw(ArgumentError("shots must be positive"))
    hamiltonian = toy_hamiltonian()
    optimization = optimize_parameters(hamiltonian; iterations=iterations)
    # Start the two samplers with the same random stream for a fair comparison.
    initial_state = preparation_circuit(initial_parameters()) * StateVector(12)
    initial_samples = sample(deepcopy(rng), initial_state, shots)
    initial_sampled = solve_subspace(sampled_basis(initial_samples; particles=6), hamiltonian)
    state = preparation_circuit(optimization.parameters) * StateVector(12)
    samples = sample(rng, state, shots)
    basis = sampled_basis(samples; particles=6)
    sampled = solve_subspace(basis, hamiltonian)
    exact = solve_subspace(particle_sector(12, 6), hamiltonian)
    return (; samples, initial_samples, hamiltonian, optimization, initial_sampled, sampled, exact)
end

end # module
