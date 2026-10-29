include("sqd.jl")
using .SQDExample
using Random

length(ARGS) <= 2 || error("Usage: julia --project=. algorithm_zoo/sqd/run.jl [shots] [iterations]")
shots = isempty(ARGS) ? 32768 : parse(Int, ARGS[1])
iterations = length(ARGS) < 2 ? 350 : parse(Int, ARGS[2])
result = demo(; shots=shots, iterations=iterations, rng=MersenneTwister(42))
println("Qubits: 12; excitations: 6; shots: ", shots)
println("Training: ", length(result.optimization.parameters), " angles, ",
    iterations, " Adam steps, ", result.optimization.evaluations, " circuit evaluations")
println("Initial / optimized variational energy: ", result.optimization.initial_energy,
    " / ", result.optimization.final_energy)
println("Energy history (iteration => energy): ",
    [(i => result.optimization.energy_history[i + 1])
     for i in 0:iterations if i % 50 == 0 || i == iterations])
println("Initial SQD energy: ", result.initial_sampled.energy,
    " (subspace ", length(result.initial_sampled.basis), ")")
println("First sampled configurations (q1 first): ",
    [join((index >> (q - 1)) & 1 for q in 1:12) for index in result.sampled.basis[1:min(8, end)]])
println("Sampled subspace dimension: ", length(result.sampled.basis), " / ", length(result.exact.basis))
println("SQD energy: ", result.sampled.energy, " (residual ", result.sampled.residual, ")")
println("Full-sector reference energy: ", result.exact.energy, " (residual ", result.exact.residual, ")")
println("Energy difference: ", result.sampled.energy - result.exact.energy)
