module Utilities

using MOSS
using ..QuantumCircuits, ..QuantumCircuits.Gates

export heisenberg_1d, heisenberg_2d, ising_1d, ising_2d, ground_state, time_evolution
export trotter_propagator, fuse_gates

# quantum algorithms
export QFT
export variational_circuit_1d, real_variational_circuit_1d
export order_finding

include("models/spin_hamiltonians.jl")
include("evolution/krylov.jl")

include("evolution/trotter.jl")
include("algorithms/gate_fusion.jl")


include("algorithms/qft.jl")
include("algorithms/variational_circuit.jl")
include("algorithms/shor/shor.jl")


end