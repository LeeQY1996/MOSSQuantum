module Utilities

using ..MOSS: StateVector, DensityMatrix, storage, qstate, rand_state
using ..MOSS: apply!, expectation, onehot_encoding, amplitude, amplitudes
using ..MOSS: norm, dot, normalize!, normalize, partial_tr, permute
using ..MOSS: ishermitian
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
