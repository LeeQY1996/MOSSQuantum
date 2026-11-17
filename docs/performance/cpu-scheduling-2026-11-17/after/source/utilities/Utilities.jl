module Utilities

using ..MOSSQuantum: StateVector, DensityMatrix, storage, qstate, rand_state
using ..MOSSQuantum: apply!, expectation, onehot_encoding, amplitude, amplitudes
using ..MOSSQuantum: norm, dot, normalize!, normalize, partial_tr, permute
using ..MOSSQuantum: ishermitian
using ..QuantumCircuits, ..QuantumCircuits.Gates

export heisenberg_1d, heisenberg_2d, ising_1d, ising_2d, ground_state, time_evolution
export trotter_propagator, fuse_gates

# quantum algorithms
export variational_circuit_1d, real_variational_circuit_1d

include("models/spin_hamiltonians.jl")
include("evolution/krylov.jl")

include("evolution/trotter.jl")
include("algorithms/gate_fusion.jl")


include("algorithms/variational_circuit.jl")


end
