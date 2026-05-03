module MOSS

using Zygote
using Zygote: @adjoint

using LinearAlgebra, StaticArrays
using SparseArrays, TensorOperations
using Requires

# ============================================================================
# QuantumCircuits 子模块
# ============================================================================

include("QuantumCircuits/QuantumCircuits.jl")

# 导入 QuantumCircuits 子模块
using .QuantumCircuits
using .QuantumCircuits.Gates
using .QuantumCircuits: permute, _kron_ops, _get_op, get_largest_pos, QOP_DATA_VALUE_TYPE

# ============================================================================
# Re-export QuantumCircuits 的公共 API
# ============================================================================

# gates
export nqubits, positions, mat, ordered_positions, ordered_mat, change_positions, shift, differentiate
export parameters, nparameters, active_parameters, activate_parameter!, activate_parameters!
export deactivate_parameter!, deactivate_parameters!, reset_parameters!
export Gate, ParametricGate, QuantumGate, AdjointQuantumGate, gate
export XGate, YGate, ZGate, SGate, HGate, TGate, sqrtXGate, sqrtYGate
export SWAPGate, iSWAPGate, CZGate, CNOTGate, CONTROLGate
export TOFFOLIGate, FREDKINGate, CONTROLCONTROLGate
# parametric gates
export RxGate, RyGate, RzGate, PHASEGate
export CRxGate, CRyGate, CRzGate, CPHASEGate, FSIMGate
export CCPHASEGate
# quantum channel
export AbstractQuantumMap, QuantumMap, ordered_supermat, kraus_matrices, is_tp
export AmplitudeDamping, PhaseDamping, Depolarizing
# circuit
export QMeasure, QSelect, QCircuit
# hamiltonian
export QubitsTerm, oplist, coeff, QubitsOperator, matrix, simplify
# Gate 构造函数
export H, X, Y, Z, S, T, CNOT, CZ, SWAP, Rx, Ry, Rz

# ============================================================================
# MOSS 特有功能（原 VQC）
# ============================================================================

# state
export StateVector, DensityMatrix, distance, distance2, onehot_encoding, qubit_encoding, qstate, amplitude_encoding
export reset!, amplitude, amplitudes, rand_state, rand_densitymatrix, fidelity
export tr, dot, norm, normalize!, normalize, ishermitian
export reset_qubit!, reset_onehot!, storage
export schmidt_numbers, renyi_entropy
export permute
# batch statevector
export BatchStateVector, batch_size, batch_onehot_encoding, batch_qubit_encoding, batch_amplitude_encoding, rand_batch

# utility functions
export variational_circuit_1d, real_variational_circuit_1d

# gate operations
export apply!

# measurement
export measure, measure!

# hamiltonian
export expectation

# AD for post selection may be removed in the future
export post_select, post_select!

# partial trace
export partial_tr

# ============================================================================
# include 原 VQC 源文件
# ============================================================================

# auxiliary
include("auxiliary/distance.jl")
include("auxiliary/parallel_for.jl")
include("auxiliary/sampling.jl")
include("auxiliary/tensorops.jl")
include("auxiliary/indexop.jl")

# state representations
include("statevector.jl")
include("batchstatevector.jl")
include("densitymatrix.jl")

# quantum gate operations
include("applygates/applygates.jl")

# measurement and postselection
include("measure.jl")
include("postselect.jl")

# hamiltonian expectation
include("hamiltonian/util.jl")
include("hamiltonian/apply_qterms/apply_qterms.jl")
include("hamiltonian/expecs/expecs.jl")
include("hamiltonian/expecs_dm/expecs_dm.jl")

# differentiation
include("circuitdiff.jl")
include("expecdiff.jl")
include("additional_adjoints.jl")

# partial trace
include("ptrace.jl")

# utility functions
include("utility/utility.jl")

# Import functions from Utilities module after it's defined
import .Utilities: variational_circuit_1d, real_variational_circuit_1d

end
