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
export BitFlip, PhaseFlip, BitPhaseFlip, PauliChannel, MixedUnitary
export GeneralizedAmplitudeDamping, ResetChannel, ThermalRelaxation
# circuit
export QMeasure, QSelect, QCircuit
# hamiltonian
export QubitsTerm, oplist, coeff, QubitsOperator, matrix, simplify
# Gate 构造函数
export H, X, Y, Z, S, T, CNOT, CZ, SWAP, Rx, Ry, Rz

# ============================================================================
# MOSSQuantum 特有功能（原 VQC）
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
export BatchDensityMatrix, rand_batch_densitymatrix

# Variational circuit builders.
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
export AbstractInstruction, validate_positions, AbstractQuantumState
export AbstractBackend, CPUBackend, backend, supports, validate_backend_execution, UnsupportedOperation
export CapabilityIssue, CapabilityStep, ExecutionCapability, execution_capability, execution_capability_step, execution_capability_backend
export validate_terminal_sampling, prepare_terminal_sampling, draw_terminal_samples
export probabilities, sample, counts, simulate, SimulationResult, MeasurementRecord
export BatchSimulationResult
export execute, ShotResult
export measurement_plan, estimate, MeasurementPlan, MeasurementGroup, PauliMeasurementTerm
export ExpectationEstimate, GroupEstimate
export bind_parameters, copy_instruction
export Parameter, ParameterExpr, parameterize, materialize_parameters, parameter_slots, UnboundParameterError
export parameter_info, initial_parameters
export parameter_expressions, independent_parameters, trainable_parameters, parameter_order, substitute_parameters
export AbstractParameterMap, ParameterMap, parameter_indices, expand_parameters, accumulate_parameter_gradients, compile_parameters
export AbstractGradientMethod, AdjointGradient, UnsupportedGradient, ExpectationObjective
export BatchExpectationObjective, evaluate_batch
export evaluate, supports_gradient, value_and_gradient, value_and_pullback, differentiable_value

export ReadoutError, NoiseRule, NoiseModel, NoisyCircuit, with_noise, Delay, readout_probabilities
export DensityMatrixEvolution, KrausTrajectory, CountsResult

export ClassicalRegister, ClassicalCondition, Conditional, classical_register, classical_counts

export ShotExpectationObjective, ParameterShift, FiniteDifference, SPSAGradient
export parameter_shift_rule, estimate_gradient, GradientEstimate

export ExecutionPlan, BoundExecutionPlan, ExecutionWorkspace, prepare_execution, bind_execution
export EstimationPlan, BoundEstimationPlan, prepare_estimation, VarianceAllocation, AdaptiveEstimate
export ExperimentResult, run_sweep, ShotBudget, ShotBudgetExceeded, remaining_shots, required_shots
