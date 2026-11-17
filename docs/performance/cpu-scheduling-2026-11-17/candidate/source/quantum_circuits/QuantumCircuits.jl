module QuantumCircuits

using SparseArrays, LinearAlgebra, TensorOperations
using UUIDs, Random

export Parameter, ParameterExpr, UnboundParameterError
export parameterize, materialize_parameters, parameter_slots, parameter_expressions, independent_parameters
export substitute_parameters, parameter_order, trainable_parameters

# gates
export nqubits, positions, mat, ordered_positions, ordered_mat, change_positions, shift, differentiate
export parameters, nparameters, active_parameters, activate_parameter!, activate_parameters!, deactivate_parameter!, deactivate_parameters!, reset_parameters!
export Gate, ParametricGate, QuantumGate, AdjointQuantumGate, gate, XGate, YGate, ZGate, SGate, HGate, TGate, sqrtXGate, sqrtYGate
export SWAPGate, iSWAPGate, CZGate, CNOTGate, CONTROLGate
export TOFFOLIGate, FREDKINGate, CONTROLCONTROLGate

# parametric gates
export RxGate, RyGate, RzGate, PHASEGate
export CRxGate, CRyGate, CRzGate, CPHASEGate, FSIMGate
export CCPHASEGate


# quantum channel
export AbstractQuantumMap, QuantumMap, ordered_supermat, kraus_matrices, is_tp
export AmplitudeDamping, PhaseDamping, Depolarizing
export BitFlip, PhaseFlip, BitPhaseFlip, PauliChannel, MixedUnitary
export GeneralizedAmplitudeDamping, ResetChannel, ThermalRelaxation


# circuit 
export QMeasure, QSelect, QCircuit
export ClassicalRegister, ClassicalCondition, Conditional

# hamiltonian
export QubitsTerm, oplist, coeff, QubitsOperator, matrix, simplify

abstract type QuantumOperation end

include("instructions.jl")
include("parameters/expressions.jl")

# auxiliary
include("utils/tensor_ops.jl")


# elementary gate matrices
include("gates/Gates.jl")

using .Gates


# gate operations
include("gates/abstract_gates.jl")
include("gates/quantum_gate.jl")
include("gates/parametric_gates.jl")
include("gates/one_qubit.jl")
include("gates/two_qubit.jl")
include("gates/three_qubit.jl")
include("gates/differentiation.jl")

# quantum channel
include("channels/abstract_maps.jl")
include("channels/quantum_map.jl")
include("channels/one_qubit.jl")

# circuit
include("circuits/circuit.jl")
include("circuits/classical_control.jl")
include("parameters/instructions.jl")

# qubit hamiltonian
include("operators/qubits_term.jl")
include("operators/qubits_operator.jl")

# Optional plotting methods dispatch through a separate function so extension
# precompilation never replaces a method defined by the parent package.
export plot, circuit_plot, draw_gate!, draw!, new_circuit_plot, save_circuit_plot
export set_default_color, get_default_color, available_gate_styles, register_gate_style

function _plotting_dispatch(::Val, args...; kwargs...)
    throw(ArgumentError("Circuit plotting requires Plots and LaTeXStrings. Load both packages to enable it."))
end

plot(circuit::QCircuit; kwargs...) = _plotting_dispatch(Val(:plot), circuit; kwargs...)
circuit_plot(circuit::QCircuit; kwargs...) = _plotting_dispatch(Val(:circuit_plot), circuit; kwargs...)
draw_gate!(plt, gate, step, qubit; kwargs...) = _plotting_dispatch(Val(:draw_gate!), plt, gate, step, qubit; kwargs...)
draw!(plt, gate, step, qubit; kwargs...) = _plotting_dispatch(Val(:draw!), plt, gate, step, qubit; kwargs...)
new_circuit_plot(args...; kwargs...) = _plotting_dispatch(Val(:new_circuit_plot), args...; kwargs...)
save_circuit_plot(args...; kwargs...) = _plotting_dispatch(Val(:save_circuit_plot), args...; kwargs...)
set_default_color(color) = _plotting_dispatch(Val(:set_default_color), color)
get_default_color() = _plotting_dispatch(Val(:get_default_color))
available_gate_styles() = _plotting_dispatch(Val(:available_gate_styles))
register_gate_style(args...; kwargs...) = _plotting_dispatch(Val(:register_gate_style), args...; kwargs...)

end
