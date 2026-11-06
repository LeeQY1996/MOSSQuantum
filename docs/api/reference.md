# 完整公开 API 参考

[API 目录](../api.md) · [状态](states.md) · [门与算符](gates.md) · [参数](parameters.md) · [执行](execution.md) · [梯度](differentiation.md) · [实用工具](utilities.md)

本页由 `docs/generate_api_reference.jl` 根据源码导出清单和实际加载的方法生成。每项列出此包定义的方法签名；`where`、参数类型及关键字名按当前实现保留。关键字的默认值、参数/返回值说明和使用示例见对应主题页与原生帮助。只记录当前包的方法，不将 Julia 标准库的全部重载混入索引。

## MOSSQuantum

[`nqubits`](#api-MOSSQuantum-nqubits) · [`positions`](#api-MOSSQuantum-positions) · [`mat`](#api-MOSSQuantum-mat) · [`ordered_positions`](#api-MOSSQuantum-ordered_positions) · [`ordered_mat`](#api-MOSSQuantum-ordered_mat) · [`change_positions`](#api-MOSSQuantum-change_positions) · [`shift`](#api-MOSSQuantum-shift) · [`differentiate`](#api-MOSSQuantum-differentiate) · [`parameters`](#api-MOSSQuantum-parameters) · [`nparameters`](#api-MOSSQuantum-nparameters) · [`active_parameters`](#api-MOSSQuantum-active_parameters) · [`activate_parameter!`](#api-MOSSQuantum-activate_parameter!) · [`activate_parameters!`](#api-MOSSQuantum-activate_parameters!) · [`deactivate_parameter!`](#api-MOSSQuantum-deactivate_parameter!) · [`deactivate_parameters!`](#api-MOSSQuantum-deactivate_parameters!) · [`reset_parameters!`](#api-MOSSQuantum-reset_parameters!) · [`Gate`](#api-MOSSQuantum-Gate) · [`ParametricGate`](#api-MOSSQuantum-ParametricGate) · [`QuantumGate`](#api-MOSSQuantum-QuantumGate) · [`AdjointQuantumGate`](#api-MOSSQuantum-AdjointQuantumGate) · [`gate`](#api-MOSSQuantum-gate) · [`XGate`](#api-MOSSQuantum-XGate) · [`YGate`](#api-MOSSQuantum-YGate) · [`ZGate`](#api-MOSSQuantum-ZGate) · [`SGate`](#api-MOSSQuantum-SGate) · [`HGate`](#api-MOSSQuantum-HGate) · [`TGate`](#api-MOSSQuantum-TGate) · [`sqrtXGate`](#api-MOSSQuantum-sqrtXGate) · [`sqrtYGate`](#api-MOSSQuantum-sqrtYGate) · [`SWAPGate`](#api-MOSSQuantum-SWAPGate) · [`iSWAPGate`](#api-MOSSQuantum-iSWAPGate) · [`CZGate`](#api-MOSSQuantum-CZGate) · [`CNOTGate`](#api-MOSSQuantum-CNOTGate) · [`CONTROLGate`](#api-MOSSQuantum-CONTROLGate) · [`TOFFOLIGate`](#api-MOSSQuantum-TOFFOLIGate) · [`FREDKINGate`](#api-MOSSQuantum-FREDKINGate) · [`CONTROLCONTROLGate`](#api-MOSSQuantum-CONTROLCONTROLGate) · [`RxGate`](#api-MOSSQuantum-RxGate) · [`RyGate`](#api-MOSSQuantum-RyGate) · [`RzGate`](#api-MOSSQuantum-RzGate) · [`PHASEGate`](#api-MOSSQuantum-PHASEGate) · [`CRxGate`](#api-MOSSQuantum-CRxGate) · [`CRyGate`](#api-MOSSQuantum-CRyGate) · [`CRzGate`](#api-MOSSQuantum-CRzGate) · [`CPHASEGate`](#api-MOSSQuantum-CPHASEGate) · [`FSIMGate`](#api-MOSSQuantum-FSIMGate) · [`CCPHASEGate`](#api-MOSSQuantum-CCPHASEGate) · [`AbstractQuantumMap`](#api-MOSSQuantum-AbstractQuantumMap) · [`QuantumMap`](#api-MOSSQuantum-QuantumMap) · [`ordered_supermat`](#api-MOSSQuantum-ordered_supermat) · [`kraus_matrices`](#api-MOSSQuantum-kraus_matrices) · [`is_tp`](#api-MOSSQuantum-is_tp) · [`AmplitudeDamping`](#api-MOSSQuantum-AmplitudeDamping) · [`PhaseDamping`](#api-MOSSQuantum-PhaseDamping) · [`Depolarizing`](#api-MOSSQuantum-Depolarizing) · [`BitFlip`](#api-MOSSQuantum-BitFlip) · [`PhaseFlip`](#api-MOSSQuantum-PhaseFlip) · [`BitPhaseFlip`](#api-MOSSQuantum-BitPhaseFlip) · [`PauliChannel`](#api-MOSSQuantum-PauliChannel) · [`MixedUnitary`](#api-MOSSQuantum-MixedUnitary) · [`GeneralizedAmplitudeDamping`](#api-MOSSQuantum-GeneralizedAmplitudeDamping) · [`ResetChannel`](#api-MOSSQuantum-ResetChannel) · [`ThermalRelaxation`](#api-MOSSQuantum-ThermalRelaxation) · [`QMeasure`](#api-MOSSQuantum-QMeasure) · [`QSelect`](#api-MOSSQuantum-QSelect) · [`QCircuit`](#api-MOSSQuantum-QCircuit) · [`QubitsTerm`](#api-MOSSQuantum-QubitsTerm) · [`oplist`](#api-MOSSQuantum-oplist) · [`coeff`](#api-MOSSQuantum-coeff) · [`QubitsOperator`](#api-MOSSQuantum-QubitsOperator) · [`matrix`](#api-MOSSQuantum-matrix) · [`simplify`](#api-MOSSQuantum-simplify) · [`H`](#api-MOSSQuantum-H) · [`X`](#api-MOSSQuantum-X) · [`Y`](#api-MOSSQuantum-Y) · [`Z`](#api-MOSSQuantum-Z) · [`S`](#api-MOSSQuantum-S) · [`T`](#api-MOSSQuantum-T) · [`CNOT`](#api-MOSSQuantum-CNOT) · [`CZ`](#api-MOSSQuantum-CZ) · [`SWAP`](#api-MOSSQuantum-SWAP) · [`Rx`](#api-MOSSQuantum-Rx) · [`Ry`](#api-MOSSQuantum-Ry) · [`Rz`](#api-MOSSQuantum-Rz) · [`StateVector`](#api-MOSSQuantum-StateVector) · [`DensityMatrix`](#api-MOSSQuantum-DensityMatrix) · [`distance`](#api-MOSSQuantum-distance) · [`distance2`](#api-MOSSQuantum-distance2) · [`onehot_encoding`](#api-MOSSQuantum-onehot_encoding) · [`qubit_encoding`](#api-MOSSQuantum-qubit_encoding) · [`qstate`](#api-MOSSQuantum-qstate) · [`amplitude_encoding`](#api-MOSSQuantum-amplitude_encoding) · [`reset!`](#api-MOSSQuantum-reset!) · [`amplitude`](#api-MOSSQuantum-amplitude) · [`amplitudes`](#api-MOSSQuantum-amplitudes) · [`rand_state`](#api-MOSSQuantum-rand_state) · [`rand_densitymatrix`](#api-MOSSQuantum-rand_densitymatrix) · [`fidelity`](#api-MOSSQuantum-fidelity) · [`tr`](#api-MOSSQuantum-tr) · [`dot`](#api-MOSSQuantum-dot) · [`norm`](#api-MOSSQuantum-norm) · [`normalize!`](#api-MOSSQuantum-normalize!) · [`normalize`](#api-MOSSQuantum-normalize) · [`ishermitian`](#api-MOSSQuantum-ishermitian) · [`reset_qubit!`](#api-MOSSQuantum-reset_qubit!) · [`reset_onehot!`](#api-MOSSQuantum-reset_onehot!) · [`storage`](#api-MOSSQuantum-storage) · [`schmidt_numbers`](#api-MOSSQuantum-schmidt_numbers) · [`renyi_entropy`](#api-MOSSQuantum-renyi_entropy) · [`permute`](#api-MOSSQuantum-permute) · [`BatchStateVector`](#api-MOSSQuantum-BatchStateVector) · [`batch_size`](#api-MOSSQuantum-batch_size) · [`batch_onehot_encoding`](#api-MOSSQuantum-batch_onehot_encoding) · [`batch_qubit_encoding`](#api-MOSSQuantum-batch_qubit_encoding) · [`batch_amplitude_encoding`](#api-MOSSQuantum-batch_amplitude_encoding) · [`rand_batch`](#api-MOSSQuantum-rand_batch) · [`BatchDensityMatrix`](#api-MOSSQuantum-BatchDensityMatrix) · [`rand_batch_densitymatrix`](#api-MOSSQuantum-rand_batch_densitymatrix) · [`variational_circuit_1d`](#api-MOSSQuantum-variational_circuit_1d) · [`real_variational_circuit_1d`](#api-MOSSQuantum-real_variational_circuit_1d) · [`apply!`](#api-MOSSQuantum-apply!) · [`measure`](#api-MOSSQuantum-measure) · [`measure!`](#api-MOSSQuantum-measure!) · [`expectation`](#api-MOSSQuantum-expectation) · [`post_select`](#api-MOSSQuantum-post_select) · [`post_select!`](#api-MOSSQuantum-post_select!) · [`partial_tr`](#api-MOSSQuantum-partial_tr) · [`AbstractInstruction`](#api-MOSSQuantum-AbstractInstruction) · [`validate_positions`](#api-MOSSQuantum-validate_positions) · [`AbstractQuantumState`](#api-MOSSQuantum-AbstractQuantumState) · [`AbstractBackend`](#api-MOSSQuantum-AbstractBackend) · [`CPUBackend`](#api-MOSSQuantum-CPUBackend) · [`backend`](#api-MOSSQuantum-backend) · [`supports`](#api-MOSSQuantum-supports) · [`validate_backend_execution`](#api-MOSSQuantum-validate_backend_execution) · [`UnsupportedOperation`](#api-MOSSQuantum-UnsupportedOperation) · [`CapabilityIssue`](#api-MOSSQuantum-CapabilityIssue) · [`CapabilityStep`](#api-MOSSQuantum-CapabilityStep) · [`ExecutionCapability`](#api-MOSSQuantum-ExecutionCapability) · [`execution_capability`](#api-MOSSQuantum-execution_capability) · [`execution_capability_step`](#api-MOSSQuantum-execution_capability_step) · [`execution_capability_backend`](#api-MOSSQuantum-execution_capability_backend) · [`validate_terminal_sampling`](#api-MOSSQuantum-validate_terminal_sampling) · [`prepare_terminal_sampling`](#api-MOSSQuantum-prepare_terminal_sampling) · [`draw_terminal_samples`](#api-MOSSQuantum-draw_terminal_samples) · [`probabilities`](#api-MOSSQuantum-probabilities) · [`sample`](#api-MOSSQuantum-sample) · [`counts`](#api-MOSSQuantum-counts) · [`simulate`](#api-MOSSQuantum-simulate) · [`SimulationResult`](#api-MOSSQuantum-SimulationResult) · [`MeasurementRecord`](#api-MOSSQuantum-MeasurementRecord) · [`BatchSimulationResult`](#api-MOSSQuantum-BatchSimulationResult) · [`execute`](#api-MOSSQuantum-execute) · [`ShotResult`](#api-MOSSQuantum-ShotResult) · [`measurement_plan`](#api-MOSSQuantum-measurement_plan) · [`estimate`](#api-MOSSQuantum-estimate) · [`MeasurementPlan`](#api-MOSSQuantum-MeasurementPlan) · [`MeasurementGroup`](#api-MOSSQuantum-MeasurementGroup) · [`PauliMeasurementTerm`](#api-MOSSQuantum-PauliMeasurementTerm) · [`ExpectationEstimate`](#api-MOSSQuantum-ExpectationEstimate) · [`GroupEstimate`](#api-MOSSQuantum-GroupEstimate) · [`bind_parameters`](#api-MOSSQuantum-bind_parameters) · [`copy_instruction`](#api-MOSSQuantum-copy_instruction) · [`Parameter`](#api-MOSSQuantum-Parameter) · [`ParameterExpr`](#api-MOSSQuantum-ParameterExpr) · [`parameterize`](#api-MOSSQuantum-parameterize) · [`materialize_parameters`](#api-MOSSQuantum-materialize_parameters) · [`parameter_slots`](#api-MOSSQuantum-parameter_slots) · [`UnboundParameterError`](#api-MOSSQuantum-UnboundParameterError) · [`parameter_info`](#api-MOSSQuantum-parameter_info) · [`initial_parameters`](#api-MOSSQuantum-initial_parameters) · [`parameter_expressions`](#api-MOSSQuantum-parameter_expressions) · [`independent_parameters`](#api-MOSSQuantum-independent_parameters) · [`trainable_parameters`](#api-MOSSQuantum-trainable_parameters) · [`parameter_order`](#api-MOSSQuantum-parameter_order) · [`substitute_parameters`](#api-MOSSQuantum-substitute_parameters) · [`AbstractParameterMap`](#api-MOSSQuantum-AbstractParameterMap) · [`ParameterMap`](#api-MOSSQuantum-ParameterMap) · [`parameter_indices`](#api-MOSSQuantum-parameter_indices) · [`expand_parameters`](#api-MOSSQuantum-expand_parameters) · [`accumulate_parameter_gradients`](#api-MOSSQuantum-accumulate_parameter_gradients) · [`compile_parameters`](#api-MOSSQuantum-compile_parameters) · [`AbstractGradientMethod`](#api-MOSSQuantum-AbstractGradientMethod) · [`AdjointGradient`](#api-MOSSQuantum-AdjointGradient) · [`UnsupportedGradient`](#api-MOSSQuantum-UnsupportedGradient) · [`ExpectationObjective`](#api-MOSSQuantum-ExpectationObjective) · [`BatchExpectationObjective`](#api-MOSSQuantum-BatchExpectationObjective) · [`evaluate_batch`](#api-MOSSQuantum-evaluate_batch) · [`evaluate`](#api-MOSSQuantum-evaluate) · [`supports_gradient`](#api-MOSSQuantum-supports_gradient) · [`value_and_gradient`](#api-MOSSQuantum-value_and_gradient) · [`value_and_pullback`](#api-MOSSQuantum-value_and_pullback) · [`differentiable_value`](#api-MOSSQuantum-differentiable_value) · [`ReadoutError`](#api-MOSSQuantum-ReadoutError) · [`NoiseRule`](#api-MOSSQuantum-NoiseRule) · [`NoiseModel`](#api-MOSSQuantum-NoiseModel) · [`NoisyCircuit`](#api-MOSSQuantum-NoisyCircuit) · [`with_noise`](#api-MOSSQuantum-with_noise) · [`Delay`](#api-MOSSQuantum-Delay) · [`readout_probabilities`](#api-MOSSQuantum-readout_probabilities) · [`DensityMatrixEvolution`](#api-MOSSQuantum-DensityMatrixEvolution) · [`KrausTrajectory`](#api-MOSSQuantum-KrausTrajectory) · [`CountsResult`](#api-MOSSQuantum-CountsResult) · [`ClassicalRegister`](#api-MOSSQuantum-ClassicalRegister) · [`ClassicalCondition`](#api-MOSSQuantum-ClassicalCondition) · [`Conditional`](#api-MOSSQuantum-Conditional) · [`classical_register`](#api-MOSSQuantum-classical_register) · [`classical_counts`](#api-MOSSQuantum-classical_counts) · [`ShotExpectationObjective`](#api-MOSSQuantum-ShotExpectationObjective) · [`ParameterShift`](#api-MOSSQuantum-ParameterShift) · [`FiniteDifference`](#api-MOSSQuantum-FiniteDifference) · [`SPSAGradient`](#api-MOSSQuantum-SPSAGradient) · [`parameter_shift_rule`](#api-MOSSQuantum-parameter_shift_rule) · [`estimate_gradient`](#api-MOSSQuantum-estimate_gradient) · [`GradientEstimate`](#api-MOSSQuantum-GradientEstimate) · [`ExecutionPlan`](#api-MOSSQuantum-ExecutionPlan) · [`BoundExecutionPlan`](#api-MOSSQuantum-BoundExecutionPlan) · [`ExecutionWorkspace`](#api-MOSSQuantum-ExecutionWorkspace) · [`prepare_execution`](#api-MOSSQuantum-prepare_execution) · [`bind_execution`](#api-MOSSQuantum-bind_execution) · [`EstimationPlan`](#api-MOSSQuantum-EstimationPlan) · [`BoundEstimationPlan`](#api-MOSSQuantum-BoundEstimationPlan) · [`prepare_estimation`](#api-MOSSQuantum-prepare_estimation) · [`VarianceAllocation`](#api-MOSSQuantum-VarianceAllocation) · [`AdaptiveEstimate`](#api-MOSSQuantum-AdaptiveEstimate) · [`ExperimentResult`](#api-MOSSQuantum-ExperimentResult) · [`run_sweep`](#api-MOSSQuantum-run_sweep) · [`ShotBudget`](#api-MOSSQuantum-ShotBudget) · [`ShotBudgetExceeded`](#api-MOSSQuantum-ShotBudgetExceeded) · [`remaining_shots`](#api-MOSSQuantum-remaining_shots) · [`required_shots`](#api-MOSSQuantum-required_shots)

<a id="api-MOSSQuantum-nqubits"></a>

### `MOSSQuantum.nqubits`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
nqubits(x::QubitsOperator)
nqubits(::Delay)
nqubits(x::QubitsTerm)
nqubits(x::BatchDensityMatrix)
nqubits(x::BatchStateVector)
nqubits(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
nqubits(x::AbstractQuantumMap{N}) where N
nqubits(x::Gate{N}) where N
nqubits(x::DensityMatrix)
nqubits(x::StateVector)
```

源码：[src/quantum_circuits/operators/qubits_operator.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L43) · [src/execution/noise_models.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L44) · [src/quantum_circuits/operators/qubits_term.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L35) · [src/states/batch_density_matrix.jl:128](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L128) · [src/states/batch_state_vector.jl:73](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L73) · [src/quantum_circuits/parameters/instructions.jl:28](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L28) · [src/quantum_circuits/channels/abstract_maps.jl:6](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L6) · [src/quantum_circuits/gates/abstract_gates.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L27) · [src/states/density_matrix.jl:75](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L75) · [src/states/state_vector.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L48)

原生帮助：

```julia
nqubits(gate::Gate) -> Int
```

Return the number of qubits the gate acts on.

#### Arguments

  * `gate::Gate`: A quantum gate.

#### Returns

  * `Int`: Number of qubits.

#### Examples

```julia
gate = XGate(1)
n = nqubits(gate)  # Returns 1

gate2 = CNOTGate(1, 2)
n2 = nqubits(gate2)  # Returns 2
```


<a id="api-MOSSQuantum-positions"></a>

### `MOSSQuantum.positions`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
positions(x::Delay)
positions(x::Conditional)
positions(x::QSelect)
positions(x::QMeasure)
positions(x::QCircuit)
positions(x::QubitsTerm)
positions(x::QuantumGate)
positions(x::QuantumMap)
positions(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
positions(x::AbstractQuantumMap)
positions(x::AdjointQuantumGate)
positions(x::Gate)
```

源码：[src/execution/noise_models.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L43) · [src/quantum_circuits/circuits/classical_control.jl:70](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L70) · [src/quantum_circuits/circuits/circuit.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L37) · [src/quantum_circuits/circuits/circuit.jl:18](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L18) · [src/quantum_circuits/circuits/circuit.jl:203](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L203) · [src/quantum_circuits/operators/qubits_term.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L32) · [src/quantum_circuits/gates/quantum_gate.jl:24](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L24) · [src/quantum_circuits/channels/quantum_map.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L42) · [src/quantum_circuits/parameters/instructions.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L27) · [src/quantum_circuits/channels/abstract_maps.jl:8](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L8) · [src/quantum_circuits/gates/quantum_gate.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L36) · [src/quantum_circuits/gates/abstract_gates.jl:49](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L49)

<a id="api-MOSSQuantum-mat"></a>

### `MOSSQuantum.mat`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
mat(x::CRxGate)
mat(x::TGate)
mat(x::CCPHASEGate)
mat(x::RyGate)
mat(s::XGate)
mat(x::CZGate)
mat(x::RxGate)
mat(x::CRzGate)
mat(x::CPHASEGate)
mat(x::sqrtYGate)
mat(x::iSWAPGate)
mat(x::PHASEGate)
mat(x::TOFFOLIGate)
mat(x::SGate)
mat(x::CRyGate)
mat(x::FSIMGate)
mat(x::FREDKINGate)
mat(x::CNOTGate)
mat(x::RzGate)
mat(x::HGate)
mat(x::ZGate)
mat(x::SWAPGate)
mat(x::sqrtXGate)
mat(x::YGate)
mat(x::QuantumGate)
mat(x::CONTROLGate)
mat(x::CONTROLCONTROLGate)
mat(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
mat(x::AdjointQuantumGate)
mat(x::Gate)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:98](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L98) · [src/quantum_circuits/gates/one_qubit.jl:73](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L73) · [src/quantum_circuits/gates/three_qubit.jl:70](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L70) · [src/quantum_circuits/gates/one_qubit.jl:110](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L110) · [src/quantum_circuits/gates/one_qubit.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L9) · [src/quantum_circuits/gates/two_qubit.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L51) · [src/quantum_circuits/gates/one_qubit.jl:92](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L92) · [src/quantum_circuits/gates/two_qubit.jl:137](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L137) · [src/quantum_circuits/gates/two_qubit.jl:156](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L156) · [src/quantum_circuits/gates/one_qubit.jl:56](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L56) · [src/quantum_circuits/gates/two_qubit.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L27) · [src/quantum_circuits/gates/one_qubit.jl:146](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L146) · [src/quantum_circuits/gates/three_qubit.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L16) · [src/quantum_circuits/gates/one_qubit.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L38) · [src/quantum_circuits/gates/two_qubit.jl:118](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L118) · [src/quantum_circuits/gates/two_qubit.jl:181](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L181) · [src/quantum_circuits/gates/three_qubit.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L41) · [src/quantum_circuits/gates/two_qubit.jl:64](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L64) · [src/quantum_circuits/gates/one_qubit.jl:128](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L128) · [src/quantum_circuits/gates/one_qubit.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L65) · [src/quantum_circuits/gates/one_qubit.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L29) · [src/quantum_circuits/gates/two_qubit.jl:11](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L11) · [src/quantum_circuits/gates/one_qubit.jl:47](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L47) · [src/quantum_circuits/gates/one_qubit.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L20) · [src/quantum_circuits/gates/quantum_gate.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L25) · [src/quantum_circuits/gates/two_qubit.jl:77](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L77) · [src/quantum_circuits/gates/three_qubit.jl:55](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L55) · [src/quantum_circuits/parameters/instructions.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L157) · [src/quantum_circuits/gates/quantum_gate.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L37) · [src/quantum_circuits/gates/abstract_gates.jl:76](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L76)

原生帮助：

```julia
mat(gate::Gate) -> AbstractMatrix
```

Return the matrix representation of a quantum gate.

#### Arguments

  * `gate::Gate`: A quantum gate.

#### Returns

  * `AbstractMatrix`: Matrix representation of the gate (size 2ⁿ×2ⁿ where n = nqubits(gate)).

#### Examples

```julia
gate = XGate(1)
m = mat(gate)  # Returns [0 1; 1 0]

gate2 = HGate(1)
m2 = mat(gate2)  # Returns [1 1; 1 -1]/√2
```

#### Notes

  * For gates acting on specific qubit positions, the matrix is in the computational basis with qubits ordered as given by `positions(gate)`.
  * Concrete gate types must implement this method.


<a id="api-MOSSQuantum-ordered_positions"></a>

### `MOSSQuantum.ordered_positions`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ordered_positions(x::FREDKINGate)
ordered_positions(x::TOFFOLIGate)
ordered_positions(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
ordered_positions(x::QuantumMap)
ordered_positions(x::AdjointQuantumGate)
ordered_positions(x::QuantumGate)
ordered_positions(x::Gate)
```

源码：[src/quantum_circuits/gates/three_qubit.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L42) · [src/quantum_circuits/gates/three_qubit.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L17) · [src/quantum_circuits/parameters/instructions.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L29) · [src/quantum_circuits/channels/quantum_map.jl:46](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L46) · [src/quantum_circuits/gates/quantum_gate.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L38) · [src/quantum_circuits/gates/quantum_gate.jl:26](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L26) · [src/quantum_circuits/gates/abstract_gates.jl:88](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L88)

<a id="api-MOSSQuantum-ordered_mat"></a>

### `MOSSQuantum.ordered_mat`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ordered_mat(x::FREDKINGate)
ordered_mat(x::TOFFOLIGate)
ordered_mat(x::SWAPGate)
ordered_mat(x::iSWAPGate)
ordered_mat(x::CZGate)
ordered_mat(x::QuantumGate)
ordered_mat(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
ordered_mat(x::AdjointQuantumGate)
ordered_mat(x::Gate{N}) where N
```

源码：[src/quantum_circuits/gates/three_qubit.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L43) · [src/quantum_circuits/gates/three_qubit.jl:18](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L18) · [src/quantum_circuits/gates/two_qubit.jl:12](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L12) · [src/quantum_circuits/gates/two_qubit.jl:28](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L28) · [src/quantum_circuits/gates/two_qubit.jl:52](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L52) · [src/quantum_circuits/gates/quantum_gate.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L27) · [src/quantum_circuits/parameters/instructions.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L157) · [src/quantum_circuits/gates/quantum_gate.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L39) · [src/quantum_circuits/gates/abstract_gates.jl:112](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L112)

原生帮助：

```julia
ordered_mat(gate::Gate) -> AbstractMatrix
```

Return the matrix representation with qubits in canonical (sorted) order.

#### Arguments

  * `gate::Gate`: A quantum gate.

#### Returns

  * `AbstractMatrix`: Matrix representation with qubits ordered by their indices.

#### Examples

```julia
gate = CNOTGate(control=2, target=1)  # Positions [2, 1]
m_ordered = ordered_mat(gate)  # Qubits reordered as [1, 2]
```

#### See also

  * `mat`: Matrix without reordering.
  * `ordered_positions`: Get canonical position ordering.


<a id="api-MOSSQuantum-change_positions"></a>

### `MOSSQuantum.change_positions`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
change_positions(x::CRxGate, m::AbstractDict)
change_positions(s::TGate, m::AbstractDict)
change_positions(x::CCPHASEGate, m::AbstractDict)
change_positions(x::Conditional, m::AbstractDict)
change_positions(x::QSelect, m::AbstractDict)
change_positions(x::QubitsTerm, mapping::AbstractDict)
change_positions(s::RyGate, m::AbstractDict)
change_positions(s::XGate, m::AbstractDict)
change_positions(x::CZGate, m::AbstractDict)
change_positions(x::QubitsOperator, mapping::AbstractDict)
change_positions(s::RxGate, m::AbstractDict)
change_positions(x::CRzGate, m::AbstractDict)
change_positions(x::CPHASEGate, m::AbstractDict)
change_positions(s::sqrtYGate, m::AbstractDict)
change_positions(x::iSWAPGate, m::AbstractDict)
change_positions(s::PHASEGate, m::AbstractDict)
change_positions(x::QMeasure, m::AbstractDict)
change_positions(x::QCircuit, m::AbstractDict)
change_positions(x::Delay, mapping::AbstractDict)
change_positions(x::TOFFOLIGate, m::AbstractDict)
change_positions(s::SGate, m::AbstractDict)
change_positions(x::CRyGate, m::AbstractDict)
change_positions(x::FSIMGate, m::AbstractDict)
change_positions(x::FREDKINGate, m::AbstractDict)
change_positions(x::CNOTGate, m::AbstractDict)
change_positions(s::RzGate, m::AbstractDict)
change_positions(s::HGate, m::AbstractDict)
change_positions(s::ZGate, m::AbstractDict)
change_positions(x::SWAPGate, m::AbstractDict)
change_positions(s::sqrtXGate, m::AbstractDict)
change_positions(s::YGate, m::AbstractDict)
change_positions(x::QuantumGate{N}, m::AbstractDict) where N
change_positions(x::CONTROLGate, m::AbstractDict)
change_positions(x::CONTROLCONTROLGate, m::AbstractDict)
change_positions(x::QuantumMap{N}, m::AbstractDict) where N
change_positions(x::AbstractQuantumMap, m::AbstractDict)
change_positions(x::AdjointQuantumGate, m::AbstractDict)
change_positions(x::Gate, m::AbstractDict)
change_positions(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, mapping::AbstractDict)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:99](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L99) · [src/quantum_circuits/gates/one_qubit.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L74) · [src/quantum_circuits/gates/three_qubit.jl:71](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L71) · [src/quantum_circuits/circuits/classical_control.jl:87](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L87) · [src/quantum_circuits/circuits/circuit.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L40) · [src/quantum_circuits/operators/qubits_operator.jl:269](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L269) · [src/quantum_circuits/gates/one_qubit.jl:111](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L111) · [src/quantum_circuits/gates/one_qubit.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L10) · [src/quantum_circuits/gates/two_qubit.jl:53](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L53) · [src/quantum_circuits/operators/qubits_operator.jl:272](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L272) · [src/quantum_circuits/gates/one_qubit.jl:93](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L93) · [src/quantum_circuits/gates/two_qubit.jl:138](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L138) · [src/quantum_circuits/gates/two_qubit.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L157) · [src/quantum_circuits/gates/one_qubit.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L57) · [src/quantum_circuits/gates/two_qubit.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L29) · [src/quantum_circuits/gates/one_qubit.jl:147](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L147) · [src/quantum_circuits/circuits/circuit.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L21) · [src/quantum_circuits/circuits/circuit.jl:199](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L199) · [src/execution/noise_models.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L45) · [src/quantum_circuits/gates/three_qubit.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L19) · [src/quantum_circuits/gates/one_qubit.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L39) · [src/quantum_circuits/gates/two_qubit.jl:119](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L119) · [src/quantum_circuits/gates/two_qubit.jl:182](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L182) · [src/quantum_circuits/gates/three_qubit.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L44) · [src/quantum_circuits/gates/two_qubit.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L65) · [src/quantum_circuits/gates/one_qubit.jl:129](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L129) · [src/quantum_circuits/gates/one_qubit.jl:66](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L66) · [src/quantum_circuits/gates/one_qubit.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L30) · [src/quantum_circuits/gates/two_qubit.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L13) · [src/quantum_circuits/gates/one_qubit.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L48) · [src/quantum_circuits/gates/one_qubit.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L21) · [src/quantum_circuits/gates/quantum_gate.jl:28](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L28) · [src/quantum_circuits/gates/two_qubit.jl:79](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L79) · [src/quantum_circuits/gates/three_qubit.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L57) · [src/quantum_circuits/channels/quantum_map.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L48) · [src/quantum_circuits/channels/abstract_maps.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L21) · [src/quantum_circuits/gates/quantum_gate.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L40) · [src/quantum_circuits/gates/abstract_gates.jl:124](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L124) · [src/quantum_circuits/parameters/instructions.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L36)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.change_positions`.

`MOSSQuantum.QuantumCircuits.change_positions` is a `Function`.

```
# 39 methods for generic function "change_positions" from MOSSQuantum.QuantumCircuits:
  [1] change_positions(x::CRxGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:99
  [2] change_positions(s::TGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:74
  [3] change_positions(x::CCPHASEGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/three_qubit.jl:71
  [4] change_positions(x::Conditional, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:87
  [5] change_positions(x::QSelect, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:40
  [6] change_positions(x::QubitsTerm, mapping::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/operators/qubits_operator.jl:269
  [7] change_positions(s::RyGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:111
  [8] change_positions(s::XGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:10
  [9] change_positions(x::CZGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:53
 [10] change_positions(x::QubitsOperator, mapping::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/operators/qubits_operator.jl:272
 [11] change_positions(s::RxGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:93
 [12] change_positions(x::CRzGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:138
 [13] change_positions(x::CPHASEGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:157
 [14] change_positions(s::sqrtYGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:57
 [15] change_positions(x::iSWAPGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:29
 [16] change_positions(s::PHASEGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:147
 [17] change_positions(x::QMeasure, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:21
 [18] change_positions(x::QCircuit, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:199
 [19] change_positions(x::Delay, mapping::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/execution/noise_models.jl:45
 [20] change_positions(x::TOFFOLIGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/three_qubit.jl:19
 [21] change_positions(s::SGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:39
 [22] change_positions(x::CRyGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:119
 [23] change_positions(x::FSIMGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:182
 [24] change_positions(x::FREDKINGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/three_qubit.jl:44
 [25] change_positions(x::CNOTGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:65
 [26] change_positions(s::RzGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:129
 [27] change_positions(s::HGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:66
 [28] change_positions(s::ZGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:30
 [29] change_positions(x::SWAPGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:13
 [30] change_positions(s::sqrtXGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:48
 [31] change_positions(s::YGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/one_qubit.jl:21
 [32] change_positions(x::QuantumGate{N}, m::AbstractDict) where N
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/quantum_gate.jl:28
 [33] change_positions(x::CONTROLGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/two_qubit.jl:79
 [34] change_positions(x::CONTROLCONTROLGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/three_qubit.jl:57
 [35] change_positions(x::QuantumMap{N}, m::AbstractDict) where N
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/quantum_map.jl:48
 [36] change_positions(x::AbstractQuantumMap, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:21
 [37] change_positions(x::AdjointQuantumGate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/quantum_gate.jl:40
 [38] change_positions(x::Gate, m::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/abstract_gates.jl:124
 [39] change_positions(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, mapping::AbstractDict)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:36
```


<a id="api-MOSSQuantum-shift"></a>

### `MOSSQuantum.shift`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
shift(x::Conditional, j::Int64)
shift(x::QCircuit, j::Int64)
shift(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, offset::Int64)
shift(x::Union{QSelect, QMeasure}, j::Int64)
shift(x::AbstractQuantumMap, j::Int64)
shift(x::Gate, j::Int64)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:89](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L89) · [src/quantum_circuits/circuits/circuit.jl:201](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L201) · [src/quantum_circuits/parameters/instructions.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L37) · [src/quantum_circuits/circuits/circuit.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L48) · [src/quantum_circuits/channels/abstract_maps.jl:23](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L23) · [src/quantum_circuits/gates/abstract_gates.jl:150](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/abstract_gates.jl#L150)

原生帮助：

```julia
shift(gate::Gate, offset::Int) -> Gate
```

Shift the qubit positions of a gate by a constant offset.

#### Arguments

  * `gate::Gate`: A quantum gate.
  * `offset::Int`: Integer offset to add to all qubit positions.

#### Returns

  * `Gate`: A new gate with shifted positions.

#### Examples

```julia
gate = CNOTGate(control=1, target=2)
shifted_gate = shift(gate, 3)  # Positions become [4, 5]
```

#### Notes

  * Useful for embedding subcircuits into larger systems.
  * The gate type is preserved (e.g., `CNOTGate` remains `CNOTGate`).


<a id="api-MOSSQuantum-differentiate"></a>

### `MOSSQuantum.differentiate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
differentiate(x::FSIMGate)
differentiate(x::RyGate)
differentiate(x::CRyGate)
differentiate(x::RzGate)
differentiate(x::RxGate)
differentiate(x::CRzGate)
differentiate(x::CPHASEGate)
differentiate(x::CCPHASEGate)
differentiate(x::CRxGate)
differentiate(x::PHASEGate)
differentiate(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
differentiate(x::AdjointQuantumGate)
differentiate(x::Gate)
```

源码：[src/quantum_circuits/gates/differentiation.jl:83](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L83) · [src/quantum_circuits/gates/differentiation.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L21) · [src/quantum_circuits/gates/differentiation.jl:52](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L52) · [src/quantum_circuits/gates/differentiation.jl:28](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L28) · [src/quantum_circuits/gates/differentiation.jl:14](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L14) · [src/quantum_circuits/gates/differentiation.jl:59](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L59) · [src/quantum_circuits/gates/differentiation.jl:66](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L66) · [src/quantum_circuits/gates/differentiation.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L74) · [src/quantum_circuits/gates/differentiation.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L45) · [src/quantum_circuits/gates/differentiation.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L35) · [src/quantum_circuits/parameters/instructions.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L157) · [src/quantum_circuits/gates/differentiation.jl:4](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/differentiation.jl#L4) · [src/quantum_circuits/gates/parametric_gates.jl:88](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L88)

原生帮助：

```julia
differentiate(gate::Gate)
```

Return one derivative gate per active parameter, in `active_parameters(gate)` order, for the existing dense CPU circuit reverse pass. For a unitary matrix `U(θ)`, each returned gate stores `(∂U/∂θ)' * U`, not the raw derivative `∂U/∂θ`. The derivative gate has the same register positions as `gate`.

Gates with no active parameters return `nothing`. A trainable external gate must implement this public method to support the existing circuit reverse pass; parameter binding and execution alone do not establish differentiation support.


<a id="api-MOSSQuantum-parameters"></a>

### `MOSSQuantum.parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameters(x::Conditional)
parameters(x::QSelect)
parameters(x::QMeasure)
parameters(x::QCircuit)
parameters(x::ParametricGate)
parameters(x::AdjointQuantumGate)
parameters(x::Gate)
parameters(x::AbstractQuantumMap)
parameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
parameters(::AbstractInstruction)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:72](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L72) · [src/quantum_circuits/circuits/circuit.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L39) · [src/quantum_circuits/circuits/circuit.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L20) · [src/quantum_circuits/circuits/circuit.jl:238](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L238) · [src/quantum_circuits/gates/parametric_gates.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L10) · [src/quantum_circuits/gates/parametric_gates.jl:11](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L11) · [src/quantum_circuits/gates/parametric_gates.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L5) · [src/quantum_circuits/channels/abstract_maps.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L30) · [src/quantum_circuits/parameters/instructions.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L157) · [src/quantum_circuits/instructions.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L19)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.parameters`.

`MOSSQuantum.QuantumCircuits.parameters` is a `Function`.

```
# 10 methods for generic function "parameters" from MOSSQuantum.QuantumCircuits:
  [1] parameters(x::Conditional)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:72
  [2] parameters(x::QSelect)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:39
  [3] parameters(x::QMeasure)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:20
  [4] parameters(x::QCircuit)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:238
  [5] parameters(x::ParametricGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:10
  [6] parameters(x::AdjointQuantumGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:11
  [7] parameters(x::Gate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:5
  [8] parameters(x::AbstractQuantumMap)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:30
  [9] parameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:157
 [10] parameters(::AbstractInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:19
```


<a id="api-MOSSQuantum-nparameters"></a>

### `MOSSQuantum.nparameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
nparameters(x::Conditional)
nparameters(map::ParameterMap)
nparameters(x::QSelect)
nparameters(x::QMeasure)
nparameters(x::QCircuit)
nparameters(x::ParametricGate)
nparameters(x::AdjointQuantumGate)
nparameters(x::Gate)
nparameters(x::AbstractQuantumMap)
nparameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
nparameters(instruction::AbstractInstruction)
nparameters(map::MOSSQuantum.AffineParameterMap)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:71](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L71) · [src/api/parameter_map.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L61) · [src/quantum_circuits/circuits/circuit.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L38) · [src/quantum_circuits/circuits/circuit.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L19) · [src/quantum_circuits/circuits/circuit.jl:214](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L214) · [src/quantum_circuits/gates/parametric_gates.jl:14](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L14) · [src/quantum_circuits/gates/parametric_gates.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L17) · [src/quantum_circuits/gates/parametric_gates.jl:8](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L8) · [src/quantum_circuits/channels/abstract_maps.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L29) · [src/quantum_circuits/parameters/instructions.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L30) · [src/quantum_circuits/instructions.jl:15](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L15) · [src/api/symbolic_parameters.jl:14](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L14)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.nparameters`.

`MOSSQuantum.QuantumCircuits.nparameters` is a `Function`.

```
# 12 methods for generic function "nparameters" from MOSSQuantum.QuantumCircuits:
  [1] nparameters(x::Conditional)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:71
  [2] nparameters(map::ParameterMap)
     @ ~/Code/Quantum/MOSSQuantum/src/api/parameter_map.jl:61
  [3] nparameters(x::QSelect)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:38
  [4] nparameters(x::QMeasure)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:19
  [5] nparameters(x::QCircuit)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:214
  [6] nparameters(x::ParametricGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:14
  [7] nparameters(x::AdjointQuantumGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:17
  [8] nparameters(x::Gate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:8
  [9] nparameters(x::AbstractQuantumMap)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:29
 [10] nparameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:30
 [11] nparameters(instruction::AbstractInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:15
 [12] nparameters(map::MOSSQuantum.AffineParameterMap)
     @ ~/Code/Quantum/MOSSQuantum/src/api/symbolic_parameters.jl:14
```


<a id="api-MOSSQuantum-active_parameters"></a>

### `MOSSQuantum.active_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
active_parameters(x::Conditional)
active_parameters(x::QCircuit)
active_parameters(x::ParametricGate)
active_parameters(x::AdjointQuantumGate)
active_parameters(x::Gate)
active_parameters(x::AbstractQuantumMap)
active_parameters(x::Union{QSelect, QMeasure})
active_parameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
active_parameters(::AbstractInstruction)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:73](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L73) · [src/quantum_circuits/circuits/circuit.jl:239](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L239) · [src/quantum_circuits/gates/parametric_gates.jl:15](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L15) · [src/quantum_circuits/gates/parametric_gates.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L16) · [src/quantum_circuits/gates/parametric_gates.jl:7](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L7) · [src/quantum_circuits/channels/abstract_maps.jl:31](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L31) · [src/quantum_circuits/circuits/circuit.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L42) · [src/quantum_circuits/parameters/instructions.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L157) · [src/quantum_circuits/instructions.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L20)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.active_parameters`.

`MOSSQuantum.QuantumCircuits.active_parameters` is a `Function`.

```
# 9 methods for generic function "active_parameters" from MOSSQuantum.QuantumCircuits:
 [1] active_parameters(x::Conditional)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:73
 [2] active_parameters(x::QCircuit)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:239
 [3] active_parameters(x::ParametricGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:15
 [4] active_parameters(x::AdjointQuantumGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:16
 [5] active_parameters(x::Gate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:7
 [6] active_parameters(x::AbstractQuantumMap)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:31
 [7] active_parameters(x::Union{QSelect, QMeasure})
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:42
 [8] active_parameters(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:157
 [9] active_parameters(::AbstractInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:20
```


<a id="api-MOSSQuantum-activate_parameter!"></a>

### `MOSSQuantum.activate_parameter!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
activate_parameter!(x::Conditional, ::Int64)
activate_parameter!(x::QCircuit, j::Int64)
activate_parameter!(x::ParametricGate, j::Int64)
activate_parameter!(x::AdjointQuantumGate, j::Int64)
activate_parameter!(x::Gate, j::Int64)
activate_parameter!(x::AbstractQuantumMap, j::Int64)
activate_parameter!(x::Union{QSelect, QMeasure}, j::Int64)
activate_parameter!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, ::Int64)
activate_parameter!(x::AbstractInstruction, ::Int64)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:84](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L84) · [src/quantum_circuits/circuits/circuit.jl:241](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L241) · [src/quantum_circuits/gates/parametric_gates.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L32) · [src/quantum_circuits/gates/parametric_gates.jl:63](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L63) · [src/quantum_circuits/gates/parametric_gates.jl:18](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L18) · [src/quantum_circuits/channels/abstract_maps.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L32) · [src/quantum_circuits/circuits/circuit.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L43) · [src/quantum_circuits/parameters/instructions.jl:163](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L163) · [src/quantum_circuits/instructions.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L21)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.activate_parameter!`.

`MOSSQuantum.QuantumCircuits.activate_parameter!` is a `Function`.

```
# 9 methods for generic function "activate_parameter!" from MOSSQuantum.QuantumCircuits:
 [1] activate_parameter!(x::Conditional, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:84
 [2] activate_parameter!(x::QCircuit, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:241
 [3] activate_parameter!(x::ParametricGate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:32
 [4] activate_parameter!(x::AdjointQuantumGate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:63
 [5] activate_parameter!(x::Gate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:18
 [6] activate_parameter!(x::AbstractQuantumMap, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:32
 [7] activate_parameter!(x::Union{QSelect, QMeasure}, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:43
 [8] activate_parameter!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:163
 [9] activate_parameter!(x::AbstractInstruction, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:21
```


<a id="api-MOSSQuantum-activate_parameters!"></a>

### `MOSSQuantum.activate_parameters!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
activate_parameters!(x::Conditional)
activate_parameters!(x::QCircuit)
activate_parameters!(x::ParametricGate)
activate_parameters!(x::AdjointQuantumGate)
activate_parameters!(x::Gate)
activate_parameters!(x::AbstractQuantumMap)
activate_parameters!(x::Union{QSelect, QMeasure})
activate_parameters!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
activate_parameters!(x::AbstractInstruction)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:82](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L82) · [src/quantum_circuits/circuits/circuit.jl:246](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L246) · [src/quantum_circuits/gates/parametric_gates.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L36) · [src/quantum_circuits/gates/parametric_gates.jl:66](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L66) · [src/quantum_circuits/gates/parametric_gates.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L19) · [src/quantum_circuits/channels/abstract_maps.jl:33](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L33) · [src/quantum_circuits/circuits/circuit.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L44) · [src/quantum_circuits/parameters/instructions.jl:160](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L160) · [src/quantum_circuits/instructions.jl:22](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L22)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.activate_parameters!`.

`MOSSQuantum.QuantumCircuits.activate_parameters!` is a `Function`.

```
# 9 methods for generic function "activate_parameters!" from MOSSQuantum.QuantumCircuits:
 [1] activate_parameters!(x::Conditional)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:82
 [2] activate_parameters!(x::QCircuit)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:246
 [3] activate_parameters!(x::ParametricGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:36
 [4] activate_parameters!(x::AdjointQuantumGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:66
 [5] activate_parameters!(x::Gate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:19
 [6] activate_parameters!(x::AbstractQuantumMap)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:33
 [7] activate_parameters!(x::Union{QSelect, QMeasure})
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:44
 [8] activate_parameters!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:160
 [9] activate_parameters!(x::AbstractInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:22
```


<a id="api-MOSSQuantum-deactivate_parameter!"></a>

### `MOSSQuantum.deactivate_parameter!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
deactivate_parameter!(x::Conditional, ::Int64)
deactivate_parameter!(x::QCircuit, j::Int64)
deactivate_parameter!(x::ParametricGate, j::Int64)
deactivate_parameter!(x::AdjointQuantumGate, j::Int64)
deactivate_parameter!(x::Gate, j::Int64)
deactivate_parameter!(x::AbstractQuantumMap, j::Int64)
deactivate_parameter!(x::Union{QSelect, QMeasure}, j::Int64)
deactivate_parameter!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, ::Int64)
deactivate_parameter!(x::AbstractInstruction, ::Int64)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:85](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L85) · [src/quantum_circuits/circuits/circuit.jl:253](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L253) · [src/quantum_circuits/gates/parametric_gates.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L40) · [src/quantum_circuits/gates/parametric_gates.jl:69](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L69) · [src/quantum_circuits/gates/parametric_gates.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L20) · [src/quantum_circuits/channels/abstract_maps.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L34) · [src/quantum_circuits/circuits/circuit.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L45) · [src/quantum_circuits/parameters/instructions.jl:163](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L163) · [src/quantum_circuits/instructions.jl:23](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L23)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.deactivate_parameter!`.

`MOSSQuantum.QuantumCircuits.deactivate_parameter!` is a `Function`.

```
# 9 methods for generic function "deactivate_parameter!" from MOSSQuantum.QuantumCircuits:
 [1] deactivate_parameter!(x::Conditional, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:85
 [2] deactivate_parameter!(x::QCircuit, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:253
 [3] deactivate_parameter!(x::ParametricGate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:40
 [4] deactivate_parameter!(x::AdjointQuantumGate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:69
 [5] deactivate_parameter!(x::Gate, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:20
 [6] deactivate_parameter!(x::AbstractQuantumMap, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:34
 [7] deactivate_parameter!(x::Union{QSelect, QMeasure}, j::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:45
 [8] deactivate_parameter!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:163
 [9] deactivate_parameter!(x::AbstractInstruction, ::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:23
```


<a id="api-MOSSQuantum-deactivate_parameters!"></a>

### `MOSSQuantum.deactivate_parameters!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
deactivate_parameters!(x::Conditional)
deactivate_parameters!(x::QCircuit)
deactivate_parameters!(x::ParametricGate)
deactivate_parameters!(x::AdjointQuantumGate)
deactivate_parameters!(x::Gate)
deactivate_parameters!(x::AbstractQuantumMap)
deactivate_parameters!(x::Union{QSelect, QMeasure})
deactivate_parameters!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
deactivate_parameters!(x::AbstractInstruction)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:83](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L83) · [src/quantum_circuits/circuits/circuit.jl:258](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L258) · [src/quantum_circuits/gates/parametric_gates.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L44) · [src/quantum_circuits/gates/parametric_gates.jl:72](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L72) · [src/quantum_circuits/gates/parametric_gates.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L21) · [src/quantum_circuits/channels/abstract_maps.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L35) · [src/quantum_circuits/circuits/circuit.jl:46](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L46) · [src/quantum_circuits/parameters/instructions.jl:160](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L160) · [src/quantum_circuits/instructions.jl:24](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L24)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.deactivate_parameters!`.

`MOSSQuantum.QuantumCircuits.deactivate_parameters!` is a `Function`.

```
# 9 methods for generic function "deactivate_parameters!" from MOSSQuantum.QuantumCircuits:
 [1] deactivate_parameters!(x::Conditional)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/classical_control.jl:83
 [2] deactivate_parameters!(x::QCircuit)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:258
 [3] deactivate_parameters!(x::ParametricGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:44
 [4] deactivate_parameters!(x::AdjointQuantumGate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:72
 [5] deactivate_parameters!(x::Gate)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/parametric_gates.jl:21
 [6] deactivate_parameters!(x::AbstractQuantumMap)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:35
 [7] deactivate_parameters!(x::Union{QSelect, QMeasure})
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/circuits/circuit.jl:46
 [8] deactivate_parameters!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/parameters/instructions.jl:160
 [9] deactivate_parameters!(x::AbstractInstruction)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/instructions.jl:24
```


<a id="api-MOSSQuantum-reset_parameters!"></a>

### `MOSSQuantum.reset_parameters!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
reset_parameters!(::MOSSQuantum.QuantumCircuits.ParameterizedInstruction, ::AbstractVector{<:Real})
reset_parameters!(x::Conditional, values::AbstractVector{<:Real})
reset_parameters!(x::QCircuit, p::AbstractVector{<:Real})
reset_parameters!(x::AdjointQuantumGate, values::AbstractVector{<:Real})
reset_parameters!(instruction::AbstractInstruction, values::AbstractVector{<:Real})
```

源码：[src/quantum_circuits/parameters/instructions.jl:165](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L165) · [src/quantum_circuits/circuits/classical_control.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L74) · [src/quantum_circuits/circuits/circuit.jl:266](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L266) · [src/quantum_circuits/gates/parametric_gates.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L57) · [src/quantum_circuits/instructions.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L74)

原生帮助：

```julia
reset_parameters!(instruction::AbstractInstruction, values::AbstractVector{<:Real})
```

Replace the active parameters in `active_parameters(instruction)` order. Frozen parameters retain their values. Implement this public method for a trainable external instruction; no particular parameter fields or private helper methods are required. Mutable implementations may update and return `instruction`; immutable implementations return a replacement instruction. Always retain the return value. Values must be finite and have length `nparameters(instruction)`.

The fallback accepts parameterless instructions and preserves the legacy reset helper adapter for existing gate implementations.


<a id="api-MOSSQuantum-Gate"></a>

### `MOSSQuantum.Gate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gate`.

#### Summary

```
abstract type Gate{N}
```

#### Subtypes

```
AdjointQuantumGate{N, G<:Gate{N}}
CNOTGate
CONTROLCONTROLGate{M<:(AbstractMatrix)}
CONTROLGate{M<:(AbstractMatrix)}
CZGate
FREDKINGate
HGate
ParametricGate{N}
QuantumGate{N, T<:Number}
SGate
SWAPGate
TGate
TOFFOLIGate
XGate
YGate
ZGate
iSWAPGate
sqrtXGate
sqrtYGate
```

#### Supertype Hierarchy

```
Gate{N} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-ParametricGate"></a>

### `MOSSQuantum.ParametricGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.ParametricGate`.

#### Summary

```
abstract type ParametricGate{N}
```

#### Subtypes

```
CCPHASEGate
CPHASEGate
CRxGate
CRyGate
CRzGate
FSIMGate
PHASEGate
RxGate
RyGate
RzGate
```

#### Supertype Hierarchy

```
ParametricGate{N} <: Gate{N} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-QuantumGate"></a>

### `MOSSQuantum.QuantumGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QuantumGate(pos::Int64, m::AbstractMatrix)
QuantumGate(pos::Vector{Int64}, m::AbstractMatrix)
QuantumGate(pos::NTuple{N, Int64}, mr::AbstractMatrix{T}) where {N, T}
QuantumGate(pos::NTuple{N, Int64}, data::Matrix{T}, ordered_pos::NTuple{N, Int64}, ordered_data::Matrix{T}) where {N, T<:Number}
```

源码：[src/quantum_circuits/gates/quantum_gate.jl:22](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L22) · [src/quantum_circuits/gates/quantum_gate.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L21) · [src/quantum_circuits/gates/quantum_gate.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L13) · [src/quantum_circuits/gates/quantum_gate.jl:6](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L6)

原生帮助：

```julia
struct QuantumGate{N, T<:Number} <: Gate{N}
```


<a id="api-MOSSQuantum-AdjointQuantumGate"></a>

### `MOSSQuantum.AdjointQuantumGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
AdjointQuantumGate(parent::G) where {N, G<:Gate{N}}
```

源码：[src/quantum_circuits/gates/quantum_gate.jl:33](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L33)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.AdjointQuantumGate`.

#### Summary

```
struct AdjointQuantumGate{N, G<:Gate{N}}
```

#### Fields

```
parent :: G<:Gate{N}
```

#### Supertype Hierarchy

```
AdjointQuantumGate{N, G<:Gate{N}} <: Gate{N} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-gate"></a>

### `MOSSQuantum.gate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
gate(pos::Union{Int64, NTuple{N, T} where {N, T}, Vector}, m::AbstractMatrix)
```

源码：[src/quantum_circuits/gates/quantum_gate.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/quantum_gate.jl#L30)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.gate`.

`MOSSQuantum.QuantumCircuits.gate` is a `Function`.

```
# 1 method for generic function "gate" from MOSSQuantum.QuantumCircuits:
 [1] gate(pos::Union{Int64, NTuple{N, T} where {N, T}, Vector}, m::AbstractMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/quantum_gate.jl:30
```


<a id="api-MOSSQuantum-XGate"></a>

### `MOSSQuantum.XGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
XGate(pos::Int64)
XGate(pos::Tuple{Int64})
XGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:7](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L7) · [src/quantum_circuits/gates/one_qubit.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L5)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.XGate`.

#### Summary

```
struct XGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
XGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-YGate"></a>

### `MOSSQuantum.YGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
YGate(pos::Int64)
YGate(pos::Tuple{Int64})
YGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:18](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L18) · [src/quantum_circuits/gates/one_qubit.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L16)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.YGate`.

#### Summary

```
struct YGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
YGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-ZGate"></a>

### `MOSSQuantum.ZGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ZGate(pos::Int64)
ZGate(pos::Tuple{Int64})
ZGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L27) · [src/quantum_circuits/gates/one_qubit.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L25)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.ZGate`.

#### Summary

```
struct ZGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
ZGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-SGate"></a>

### `MOSSQuantum.SGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
SGate(pos::Int64)
SGate(pos::Tuple{Int64})
SGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L36) · [src/quantum_circuits/gates/one_qubit.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L34)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.SGate`.

#### Summary

```
struct SGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
SGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-HGate"></a>

### `MOSSQuantum.HGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
HGate(pos::Int64)
HGate(pos::Tuple{Int64})
HGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:63](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L63) · [src/quantum_circuits/gates/one_qubit.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L61)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.HGate`.

#### Summary

```
struct HGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
HGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-TGate"></a>

### `MOSSQuantum.TGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
TGate(pos::Int64)
TGate(pos::Tuple{Int64})
TGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:71](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L71) · [src/quantum_circuits/gates/one_qubit.jl:69](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L69)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.TGate`.

#### Summary

```
struct TGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
TGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-sqrtXGate"></a>

### `MOSSQuantum.sqrtXGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
sqrtXGate(pos::Int64)
sqrtXGate(pos::Tuple{Int64})
sqrtXGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L45) · [src/quantum_circuits/gates/one_qubit.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L43)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.sqrtXGate`.

#### Summary

```
struct sqrtXGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
sqrtXGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-sqrtYGate"></a>

### `MOSSQuantum.sqrtYGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
sqrtYGate(pos::Int64)
sqrtYGate(pos::Tuple{Int64})
sqrtYGate(pos)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:54](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L54) · [src/quantum_circuits/gates/one_qubit.jl:52](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L52)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.sqrtYGate`.

#### Summary

```
struct sqrtYGate
```

#### Fields

```
pos :: Tuple{Int64}
```

#### Supertype Hierarchy

```
sqrtYGate <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-SWAPGate"></a>

### `MOSSQuantum.SWAPGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
SWAPGate(c::Int64, t::Int64)
SWAPGate(key::Tuple{Int64, Int64})
```

源码：[src/quantum_circuits/gates/two_qubit.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L9) · [src/quantum_circuits/gates/two_qubit.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L5)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.SWAPGate`.

#### Summary

```
struct SWAPGate
```

#### Fields

```
pos :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
SWAPGate <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-iSWAPGate"></a>

### `MOSSQuantum.iSWAPGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
iSWAPGate(c::Int64, t::Int64)
iSWAPGate(key::Tuple{Int64, Int64})
```

源码：[src/quantum_circuits/gates/two_qubit.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L25) · [src/quantum_circuits/gates/two_qubit.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L21)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.iSWAPGate`.

#### Summary

```
struct iSWAPGate
```

#### Fields

```
pos :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
iSWAPGate <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CZGate"></a>

### `MOSSQuantum.CZGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CZGate(; control, target)
CZGate(c::Int64, t::Int64)
CZGate(key::Tuple{Int64, Int64})
```

源码：[src/quantum_circuits/gates/two_qubit.jl:49](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L49) · [src/quantum_circuits/gates/two_qubit.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L48) · [src/quantum_circuits/gates/two_qubit.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L44)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CZGate`.

#### Summary

```
struct CZGate
```

#### Fields

```
pos :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
CZGate <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CNOTGate"></a>

### `MOSSQuantum.CNOTGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CNOTGate(; control, target)
CNOTGate(c::Int64, t::Int64)
CNOTGate(pos::Tuple{Int64, Int64})
CNOTGate(pos)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:62](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L62) · [src/quantum_circuits/gates/two_qubit.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L61) · [src/quantum_circuits/gates/two_qubit.jl:59](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L59)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CNOTGate`.

#### Summary

```
struct CNOTGate
```

#### Fields

```
pos :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
CNOTGate <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CONTROLGate"></a>

### `MOSSQuantum.CONTROLGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CONTROLGate(m::AbstractMatrix; control, target)
CONTROLGate(a::Int64, b::Int64, target::AbstractMatrix)
CONTROLGate(pos::Tuple{Int64, Int64}, target::M) where M<:(AbstractMatrix)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:76](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L76) · [src/quantum_circuits/gates/two_qubit.jl:75](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L75) · [src/quantum_circuits/gates/two_qubit.jl:72](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L72)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CONTROLGate`.

#### Summary

```
struct CONTROLGate{M<:(AbstractMatrix)}
```

#### Fields

```
pos    :: Tuple{Int64, Int64}
target :: M<:(AbstractMatrix)
```

#### Supertype Hierarchy

```
CONTROLGate{M<:(AbstractMatrix)} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-TOFFOLIGate"></a>

### `MOSSQuantum.TOFFOLIGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
TOFFOLIGate(a::Int64, b::Int64, c::Int64)
TOFFOLIGate(pos::Tuple{Int64, Int64, Int64})
TOFFOLIGate(pos::Tuple{Int64, Int64, Int64}, ordered_pos::Tuple{Int64, Int64, Int64}, ordered_data::Matrix{Float64})
TOFFOLIGate(pos, ordered_pos, ordered_data)
```

源码：[src/quantum_circuits/gates/three_qubit.jl:14](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L14) · [src/quantum_circuits/gates/three_qubit.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L9) · [src/quantum_circuits/gates/three_qubit.jl:4](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L4)

字段：`pos::Tuple{Int64, Int64, Int64}`；`ordered_pos::Tuple{Int64, Int64, Int64}`；`ordered_data::Matrix{Float64}`。结果和计划应通过对应公共函数创建；把配置字段视为只读。

<a id="api-MOSSQuantum-FREDKINGate"></a>

### `MOSSQuantum.FREDKINGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
FREDKINGate(a::Int64, b::Int64, c::Int64)
FREDKINGate(pos::Tuple{Int64, Int64, Int64})
FREDKINGate(pos::Tuple{Int64, Int64, Int64}, ordered_pos::Tuple{Int64, Int64, Int64}, ordered_data::Matrix{Float64})
FREDKINGate(pos, ordered_pos, ordered_data)
```

源码：[src/quantum_circuits/gates/three_qubit.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L38) · [src/quantum_circuits/gates/three_qubit.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L32) · [src/quantum_circuits/gates/three_qubit.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L27)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.FREDKINGate`.

#### Summary

```
struct FREDKINGate
```

#### Fields

```
pos          :: Tuple{Int64, Int64, Int64}
ordered_pos  :: Tuple{Int64, Int64, Int64}
ordered_data :: Matrix{Float64}
```

#### Supertype Hierarchy

```
FREDKINGate <: Gate{3} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CONTROLCONTROLGate"></a>

### `MOSSQuantum.CONTROLCONTROLGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CONTROLCONTROLGate(a::Int64, b::Int64, c::Int64, m::AbstractMatrix)
CONTROLCONTROLGate(pos::Tuple{Int64, Int64, Int64}, target::M) where M<:(AbstractMatrix)
```

源码：[src/quantum_circuits/gates/three_qubit.jl:54](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L54) · [src/quantum_circuits/gates/three_qubit.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L51)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CONTROLCONTROLGate`.

#### Summary

```
struct CONTROLCONTROLGate{M<:(AbstractMatrix)}
```

#### Fields

```
pos    :: Tuple{Int64, Int64, Int64}
target :: M<:(AbstractMatrix)
```

#### Supertype Hierarchy

```
CONTROLCONTROLGate{M<:(AbstractMatrix)} <: Gate{3} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-RxGate"></a>

### `MOSSQuantum.RxGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
RxGate(pos::Int64; θ, isparas)
RxGate(pos::Tuple{Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
RxGate(pos, paras, isparas)
RxGate(pos::Int64, expression::Union{Parameter, ParameterExpr}; isparas)
RxGate(pos::Int64, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:84](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L84) · [src/quantum_circuits/gates/one_qubit.jl:79](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L79) · [src/quantum_circuits/parameters/instructions.jl:254](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L254) · [src/quantum_circuits/gates/one_qubit.jl:83](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L83)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.RxGate`.

#### Summary

```
struct RxGate
```

#### Fields

```
pos     :: Tuple{Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
RxGate <: ParametricGate{1} <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-RyGate"></a>

### `MOSSQuantum.RyGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
RyGate(pos::Int64; θ, isparas)
RyGate(pos::Tuple{Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
RyGate(pos, paras, isparas)
RyGate(pos::Int64, expression::Union{Parameter, ParameterExpr}; isparas)
RyGate(pos::Int64, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:102](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L102) · [src/quantum_circuits/gates/one_qubit.jl:97](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L97) · [src/quantum_circuits/parameters/instructions.jl:254](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L254) · [src/quantum_circuits/gates/one_qubit.jl:101](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L101)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.RyGate`.

#### Summary

```
struct RyGate
```

#### Fields

```
pos     :: Tuple{Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
RyGate <: ParametricGate{1} <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-RzGate"></a>

### `MOSSQuantum.RzGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
RzGate(pos::Int64; θ, isparas)
RzGate(pos::Tuple{Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
RzGate(pos, paras, isparas)
RzGate(pos::Int64, expression::Union{Parameter, ParameterExpr}; isparas)
RzGate(pos::Int64, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:120](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L120) · [src/quantum_circuits/gates/one_qubit.jl:115](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L115) · [src/quantum_circuits/parameters/instructions.jl:254](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L254) · [src/quantum_circuits/gates/one_qubit.jl:119](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L119)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.RzGate`.

#### Summary

```
struct RzGate
```

#### Fields

```
pos     :: Tuple{Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
RzGate <: ParametricGate{1} <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-PHASEGate"></a>

### `MOSSQuantum.PHASEGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
PHASEGate(pos::Int64; θ, isparas)
PHASEGate(pos::Tuple{Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
PHASEGate(pos, paras, isparas)
PHASEGate(pos::Int64, expression::Union{Parameter, ParameterExpr}; isparas)
PHASEGate(pos::Int64, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/one_qubit.jl:138](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L138) · [src/quantum_circuits/gates/one_qubit.jl:133](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L133) · [src/quantum_circuits/parameters/instructions.jl:254](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L254) · [src/quantum_circuits/gates/one_qubit.jl:137](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/one_qubit.jl#L137)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.PHASEGate`.

#### Summary

```
struct PHASEGate
```

#### Fields

```
pos     :: Tuple{Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
PHASEGate <: ParametricGate{1} <: Gate{1} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CRxGate"></a>

### `MOSSQuantum.CRxGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CRxGate(; control, target, θ, isparas)
CRxGate(pos::Tuple{Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
CRxGate(c::Int64, t::Int64, p::Real; isparas)
CRxGate(control::Int64, target::Int64, expression::Union{Parameter, ParameterExpr}; kwargs...)
CRxGate(pos, paras, isparas)
CRxGate(pos::Tuple{Int64, Int64}, expression::Union{Parameter, ParameterExpr}; isparas)
CRxGate(key::Tuple{Int64, Int64}, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:90](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L90) · [src/quantum_circuits/gates/two_qubit.jl:84](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L84) · [src/quantum_circuits/gates/two_qubit.jl:89](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L89) · [src/quantum_circuits/parameters/instructions.jl:265](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L265) · [src/quantum_circuits/parameters/instructions.jl:261](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L261) · [src/quantum_circuits/gates/two_qubit.jl:88](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L88)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CRxGate`.

#### Summary

```
struct CRxGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
CRxGate <: ParametricGate{2} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CRyGate"></a>

### `MOSSQuantum.CRyGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CRyGate(; control, target, θ, isparas)
CRyGate(pos::Tuple{Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
CRyGate(c::Int64, t::Int64, p::Real; isparas)
CRyGate(control::Int64, target::Int64, expression::Union{Parameter, ParameterExpr}; kwargs...)
CRyGate(pos, paras, isparas)
CRyGate(pos::Tuple{Int64, Int64}, expression::Union{Parameter, ParameterExpr}; isparas)
CRyGate(key::Tuple{Int64, Int64}, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:110](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L110) · [src/quantum_circuits/gates/two_qubit.jl:104](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L104) · [src/quantum_circuits/gates/two_qubit.jl:109](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L109) · [src/quantum_circuits/parameters/instructions.jl:265](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L265) · [src/quantum_circuits/parameters/instructions.jl:261](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L261) · [src/quantum_circuits/gates/two_qubit.jl:108](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L108)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CRyGate`.

#### Summary

```
struct CRyGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
CRyGate <: ParametricGate{2} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CRzGate"></a>

### `MOSSQuantum.CRzGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CRzGate(; control, target, θ, isparas)
CRzGate(pos::Tuple{Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
CRzGate(c::Int64, t::Int64, p::Real; isparas)
CRzGate(control::Int64, target::Int64, expression::Union{Parameter, ParameterExpr}; kwargs...)
CRzGate(pos, paras, isparas)
CRzGate(pos::Tuple{Int64, Int64}, expression::Union{Parameter, ParameterExpr}; isparas)
CRzGate(key::Tuple{Int64, Int64}, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:129](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L129) · [src/quantum_circuits/gates/two_qubit.jl:123](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L123) · [src/quantum_circuits/gates/two_qubit.jl:128](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L128) · [src/quantum_circuits/parameters/instructions.jl:265](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L265) · [src/quantum_circuits/parameters/instructions.jl:261](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L261) · [src/quantum_circuits/gates/two_qubit.jl:127](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L127)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CRzGate`.

#### Summary

```
struct CRzGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
CRzGate <: ParametricGate{2} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CPHASEGate"></a>

### `MOSSQuantum.CPHASEGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CPHASEGate(; control, target, θ, isparas)
CPHASEGate(pos::Tuple{Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
CPHASEGate(c::Int64, t::Int64, p::Real; isparas)
CPHASEGate(control::Int64, target::Int64, expression::Union{Parameter, ParameterExpr}; kwargs...)
CPHASEGate(pos, paras, isparas)
CPHASEGate(pos::Tuple{Int64, Int64}, expression::Union{Parameter, ParameterExpr}; isparas)
CPHASEGate(key::Tuple{Int64, Int64}, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:148](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L148) · [src/quantum_circuits/gates/two_qubit.jl:142](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L142) · [src/quantum_circuits/gates/two_qubit.jl:147](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L147) · [src/quantum_circuits/parameters/instructions.jl:265](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L265) · [src/quantum_circuits/parameters/instructions.jl:261](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L261) · [src/quantum_circuits/gates/two_qubit.jl:146](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L146)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CPHASEGate`.

#### Summary

```
struct CPHASEGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
CPHASEGate <: ParametricGate{2} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-FSIMGate"></a>

### `MOSSQuantum.FSIMGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
FSIMGate(; control, target, θs, isparas)
FSIMGate(pos::Tuple{Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
FSIMGate(c::Int64, t::Int64, p::Vector{<:Real}; isparas)
FSIMGate(c::Int64, t::Int64, expressions::AbstractVector; kwargs...)
FSIMGate(pos, paras, isparas)
FSIMGate(key::Tuple{Int64, Int64}, p::Vector{<:Real}; isparas)
FSIMGate(pos::Tuple{Int64, Int64}, expressions::AbstractVector; isparas)
```

源码：[src/quantum_circuits/gates/two_qubit.jl:172](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L172) · [src/quantum_circuits/gates/two_qubit.jl:163](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L163) · [src/quantum_circuits/gates/two_qubit.jl:171](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L171) · [src/quantum_circuits/parameters/instructions.jl:279](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L279) · [src/quantum_circuits/gates/two_qubit.jl:167](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/two_qubit.jl#L167) · [src/quantum_circuits/parameters/instructions.jl:273](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L273)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.FSIMGate`.

#### Summary

```
struct FSIMGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
FSIMGate <: ParametricGate{2} <: Gate{2} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-CCPHASEGate"></a>

### `MOSSQuantum.CCPHASEGate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CCPHASEGate(pos::Tuple{Int64, Int64, Int64}, paras::Vector{Float64}, isparas::Vector{Bool})
CCPHASEGate(pos, paras, isparas)
CCPHASEGate(a::Int64, b::Int64, c::Int64, expression::Union{Parameter, ParameterExpr}; kwargs...)
CCPHASEGate(pos::Tuple{Int64, Int64, Int64}, expression::Union{Parameter, ParameterExpr}; isparas)
CCPHASEGate(a::Int64, b::Int64, c::Int64, θ::Real, isparas::Bool)
CCPHASEGate(a::Int64, b::Int64, c::Int64, θ::Real)
CCPHASEGate(key::Tuple{Int64, Int64, Int64}, p::Real; isparas)
```

源码：[src/quantum_circuits/gates/three_qubit.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L61) · [src/quantum_circuits/parameters/instructions.jl:272](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L272) · [src/quantum_circuits/parameters/instructions.jl:268](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L268) · [src/quantum_circuits/gates/three_qubit.jl:67](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L67) · [src/quantum_circuits/gates/three_qubit.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/three_qubit.jl#L65)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.CCPHASEGate`.

#### Summary

```
struct CCPHASEGate
```

#### Fields

```
pos     :: Tuple{Int64, Int64, Int64}
paras   :: Vector{Float64}
isparas :: Vector{Bool}
```

#### Supertype Hierarchy

```
CCPHASEGate <: ParametricGate{3} <: Gate{3} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-AbstractQuantumMap"></a>

### `MOSSQuantum.AbstractQuantumMap`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.AbstractQuantumMap`.

#### Summary

```
abstract type AbstractQuantumMap{N}
```

#### Subtypes

```
QuantumMap{N, T<:Number}
```

#### Supertype Hierarchy

```
AbstractQuantumMap{N} <: AbstractInstruction <: MOSSQuantum.QuantumCircuits.QuantumOperation <: Any
```


<a id="api-MOSSQuantum-QuantumMap"></a>

### `MOSSQuantum.QuantumMap`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QuantumMap(pos::Int64, m::Vector{<:AbstractMatrix}; kwargs...)
QuantumMap(pos::Vector{Int64}, m::Vector{<:AbstractMatrix}; kwargs...)
QuantumMap(pos::NTuple{N, Int64}, mr::Vector{<:AbstractMatrix{T}}; check_tp, atol) where {N, T}
QuantumMap(pos::NTuple{N, Int64}, kraus::Array{Matrix{T}, 1}, ordered_pos::NTuple{N, Int64}, ordered_data::Matrix{T}) where {N, T<:Number}
```

源码：[src/quantum_circuits/channels/quantum_map.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L40) · [src/quantum_circuits/channels/quantum_map.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L39) · [src/quantum_circuits/channels/quantum_map.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L16) · [src/quantum_circuits/channels/quantum_map.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L10)

原生帮助：

```julia
QuantumMap(positions, kraus; check_tp=false, atol=nothing)
```

Snapshot a Kraus representation. General CP maps may be non-trace-preserving; use `check_tp=true` for physical noise. Returned matrix accessors are borrowed, read-only data. Construct a new map to change its Kraus representation.


<a id="api-MOSSQuantum-ordered_supermat"></a>

### `MOSSQuantum.ordered_supermat`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ordered_supermat(x::QuantumMap)
ordered_supermat(x::AbstractQuantumMap)
```

源码：[src/quantum_circuits/channels/quantum_map.jl:47](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L47) · [src/quantum_circuits/channels/abstract_maps.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L19)

原生帮助：

```julia
ordered_supermat(x::AbstractQuantumMap)
```


<a id="api-MOSSQuantum-kraus_matrices"></a>

### `MOSSQuantum.kraus_matrices`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
kraus_matrices(x::QuantumMap)
kraus_matrices(x::AbstractQuantumMap)
```

源码：[src/quantum_circuits/channels/quantum_map.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/quantum_map.jl#L45) · [src/quantum_circuits/channels/abstract_maps.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L13)

原生帮助：

```julia
kraus_matrices(x::AbstractQuantumMap)
```


<a id="api-MOSSQuantum-is_tp"></a>

### `MOSSQuantum.is_tp`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
is_tp(x::AbstractQuantumMap; kwargs...)
```

源码：[src/quantum_circuits/channels/abstract_maps.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/abstract_maps.jl#L25)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.is_tp`.

`MOSSQuantum.QuantumCircuits.is_tp` is a `Function`.

```
# 1 method for generic function "is_tp" from MOSSQuantum.QuantumCircuits:
 [1] is_tp(x::AbstractQuantumMap; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/abstract_maps.jl:25
```


<a id="api-MOSSQuantum-AmplitudeDamping"></a>

### `MOSSQuantum.AmplitudeDamping`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
AmplitudeDamping(pos::Int64; γ)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L9)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.AmplitudeDamping`.

`MOSSQuantum.QuantumCircuits.AmplitudeDamping` is a `Function`.

```
# 1 method for generic function "AmplitudeDamping" from MOSSQuantum.QuantumCircuits:
 [1] AmplitudeDamping(pos::Int64; γ)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/one_qubit.jl:9
```


<a id="api-MOSSQuantum-PhaseDamping"></a>

### `MOSSQuantum.PhaseDamping`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
PhaseDamping(pos::Int64; γ)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:15](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L15)

原生帮助：

Phase damping with off-diagonal multiplier `sqrt(1-γ)`.


<a id="api-MOSSQuantum-Depolarizing"></a>

### `MOSSQuantum.Depolarizing`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Depolarizing(pos; p)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:49](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L49)

原生帮助：

Depolarizing channel `(1-p)ρ + p*tr(ρ)*I/d`, for one or two qubits.


<a id="api-MOSSQuantum-BitFlip"></a>

### `MOSSQuantum.BitFlip`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BitFlip(pos::Int64; p)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L20)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.BitFlip`.

`MOSSQuantum.QuantumCircuits.BitFlip` is a `Function`.

```
# 1 method for generic function "BitFlip" from MOSSQuantum.QuantumCircuits:
 [1] BitFlip(pos::Int64; p)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/one_qubit.jl:20
```


<a id="api-MOSSQuantum-PhaseFlip"></a>

### `MOSSQuantum.PhaseFlip`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
PhaseFlip(pos::Int64; p)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L21)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.PhaseFlip`.

`MOSSQuantum.QuantumCircuits.PhaseFlip` is a `Function`.

```
# 1 method for generic function "PhaseFlip" from MOSSQuantum.QuantumCircuits:
 [1] PhaseFlip(pos::Int64; p)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/one_qubit.jl:21
```


<a id="api-MOSSQuantum-BitPhaseFlip"></a>

### `MOSSQuantum.BitPhaseFlip`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BitPhaseFlip(pos::Int64; p)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:22](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L22)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.BitPhaseFlip`.

`MOSSQuantum.QuantumCircuits.BitPhaseFlip` is a `Function`.

```
# 1 method for generic function "BitPhaseFlip" from MOSSQuantum.QuantumCircuits:
 [1] BitPhaseFlip(pos::Int64; p)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/channels/one_qubit.jl:22
```


<a id="api-MOSSQuantum-PauliChannel"></a>

### `MOSSQuantum.PauliChannel`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
PauliChannel(pos, words::AbstractVector{<:AbstractString}, probabilities::AbstractVector{<:Real})
```

源码：[src/quantum_circuits/channels/one_qubit.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L30)

原生帮助：

```julia
PauliChannel(positions, words, probabilities)
```

Mixture of Pauli words. The first character acts on the first supplied position (the least significant local bit). Probabilities must sum to one.


<a id="api-MOSSQuantum-MixedUnitary"></a>

### `MOSSQuantum.MixedUnitary`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MixedUnitary(pos, unitaries::AbstractVector{<:AbstractMatrix}, probabilities::AbstractVector{<:Real})
```

源码：[src/quantum_circuits/channels/one_qubit.jl:62](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L62)

原生帮助：

A mixture of unitary matrices with finite, nonnegative probabilities summing to one.


<a id="api-MOSSQuantum-GeneralizedAmplitudeDamping"></a>

### `MOSSQuantum.GeneralizedAmplitudeDamping`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
GeneralizedAmplitudeDamping(pos::Int64; γ, excited_population)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:79](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L79)

原生帮助：

Generalized amplitude damping; `excited_population` is the equilibrium |1⟩ population.


<a id="api-MOSSQuantum-ResetChannel"></a>

### `MOSSQuantum.ResetChannel`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ResetChannel(pos::Int64; state, p)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:89](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L89)

原生帮助：

With probability `p`, replace a qubit by `|state⟩`; otherwise leave it unchanged.


<a id="api-MOSSQuantum-ThermalRelaxation"></a>

### `MOSSQuantum.ThermalRelaxation`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ThermalRelaxation(pos::Int64; T1, T2, duration, excited_population)
```

源码：[src/quantum_circuits/channels/one_qubit.jl:103](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/channels/one_qubit.jl#L103)

原生帮助：

```julia
ThermalRelaxation(pos; T1, T2, duration, excited_population=0)
```

Relax population with T1 and coherence with T2, using a common time unit. Positive infinite lifetimes are supported; require T2 ≤ 2T1 and finite duration ≥ 0.


<a id="api-MOSSQuantum-QMeasure"></a>

### `MOSSQuantum.QMeasure`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QMeasure(position::Int64; auto_reset, keep, key)
```

源码：[src/quantum_circuits/circuits/circuit.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L13)

字段：`position::Int64`；`auto_reset::Bool`；`keep::Bool`；`key::Union{Nothing, Symbol}`。结果和计划应通过对应公共函数创建；把配置字段视为只读。

<a id="api-MOSSQuantum-QSelect"></a>

### `MOSSQuantum.QSelect`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QSelect(key::Int64, state::Int64)
QSelect(key::Int64)
```

源码：[src/quantum_circuits/circuits/circuit.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L32)

字段：`position::Int64`；`state::Int64`。结果和计划应通过对应公共函数创建；把配置字段视为只读。

<a id="api-MOSSQuantum-QCircuit"></a>

### `MOSSQuantum.QCircuit`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QCircuit(x::QCircuit; copy)
QCircuit()
QCircuit(operations::Vector{AbstractInstruction}; copy)
QCircuit(operations::AbstractVector; copy)
```

源码：[src/quantum_circuits/circuits/circuit.jl:113](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L113) · [src/quantum_circuits/circuits/circuit.jl:112](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L112) · [src/quantum_circuits/circuits/circuit.jl:101](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L101) · [src/quantum_circuits/circuits/circuit.jl:106](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L106)

原生帮助：

```julia
QCircuit <: QuantumCircuit
```

A quantum circuit representing a sequence of quantum operations (gates, channels, measurements, or subcircuits).

#### Fields

  * `operations::Vector{CircuitElement}`: Sequence of quantum operations.

#### Constructors

```julia
QCircuit()  # Create empty circuit
QCircuit(ops; copy=false)  # Reuse a compatible operation vector when possible
QCircuit(circuit::QCircuit; copy=true)  # Shallow-copy its operation vector
```

#### Examples

```julia
# Create empty circuit
circuit = QCircuit()

# Add operations
push!(circuit, HGate(1))
push!(circuit, CNOTGate(1, 2))
push!(circuit, AmplitudeDamping(1, γ=0.1))

# Create from array
ops = [XGate(1), YGate(2), ZGate(3)]
circuit2 = QCircuit(ops)
```

#### See also

  * `push!`: Add operation to circuit.
  * `append!`: Append operations to circuit.
  * `QMeasure`: Measurement operation.
  * `QSelect`: Post-selection operation.

#### Ownership

`copy=true` copies the operation vector, not its instructions. With `copy=false`, a `Vector{AbstractInstruction}` is stored directly; other vector types are converted to that representation and therefore receive a new container. `QCircuit(existing)` and `copy(existing)` shallow-copy the container by default. Nested circuits and mutable instruction parameters remain shared. Use `copy_instruction` for an independent instruction tree.


<a id="api-MOSSQuantum-QubitsTerm"></a>

### `MOSSQuantum.QubitsTerm`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QubitsTerm(items::Pair{Int64, <:Union{AbstractString, AbstractMatrix}}...; coeff)
QubitsTerm(x::AbstractDict{Int64}; coeff)
QubitsTerm(value::Number)
QubitsTerm(pos::Tuple, matrices::Vector, value::Number)
QubitsTerm(pos::Vector{Int64}, matrices::Vector, value::Number)
```

源码：[src/quantum_circuits/operators/qubits_term.jl:47](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L47) · [src/quantum_circuits/operators/qubits_term.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L41) · [src/quantum_circuits/operators/qubits_term.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L39) · [src/quantum_circuits/operators/qubits_term.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L38) · [src/quantum_circuits/operators/qubits_term.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L17)

原生帮助：

```julia
QubitsTerm(position => operator, ...; coeff=1)
QubitsTerm(value::Number)
```

A coefficient times a tensor product of local 2×2 matrices. Positions are positive, distinct, and sorted internally; qubit 1 is the least significant tensor factor. Inputs are copied, including their local matrices.

An empty support denotes the identity, so `QubitsTerm(2)` represents `2I` on any register. `isempty(term)` describes support, not whether the term is zero.


<a id="api-MOSSQuantum-oplist"></a>

### `MOSSQuantum.oplist`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
oplist(x::QubitsTerm)
```

源码：[src/quantum_circuits/operators/qubits_term.jl:33](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L33)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.oplist`.

`MOSSQuantum.QuantumCircuits.oplist` is a `Function`.

```
# 1 method for generic function "oplist" from MOSSQuantum.QuantumCircuits:
 [1] oplist(x::QubitsTerm)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/operators/qubits_term.jl:33
```


<a id="api-MOSSQuantum-coeff"></a>

### `MOSSQuantum.coeff`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
coeff(x::QubitsTerm)
```

源码：[src/quantum_circuits/operators/qubits_term.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_term.jl#L34)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.coeff`.

`MOSSQuantum.QuantumCircuits.coeff` is a `Function`.

```
# 1 method for generic function "coeff" from MOSSQuantum.QuantumCircuits:
 [1] coeff(x::QubitsTerm)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/operators/qubits_term.jl:34
```


<a id="api-MOSSQuantum-QubitsOperator"></a>

### `MOSSQuantum.QubitsOperator`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
QubitsOperator(first::QubitsTerm, others::QubitsTerm...)
QubitsOperator()
QubitsOperator(data::Dict{Tuple{Vararg{Int64}}, Vector{Tuple{Vector{AbstractMatrix}, Number}}})
QubitsOperator(value::Number)
QubitsOperator(data)
```

源码：[src/quantum_circuits/operators/qubits_operator.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L19) · [src/quantum_circuits/operators/qubits_operator.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L16) · [src/quantum_circuits/operators/qubits_operator.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L13) · [src/quantum_circuits/operators/qubits_operator.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L17)

原生帮助：

```julia
QubitsOperator(terms::QubitsTerm...)
QubitsOperator(value::Number)
```

A sum of tensor-product terms. The empty sum is the zero operator; a numeric argument is a scalar multiple of the identity. Arithmetic does not mutate its operands. Use `simplify` to combine identical terms and remove zero coefficients.


<a id="api-MOSSQuantum-matrix"></a>

### `MOSSQuantum.matrix`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
matrix(x::QubitsTerm)
matrix(n::Int64, x::QubitsTerm)
matrix(x::QubitsOperator)
matrix(n::Int64, x::QubitsOperator)
```

源码：[src/quantum_circuits/operators/qubits_operator.jl:241](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L241) · [src/quantum_circuits/operators/qubits_operator.jl:240](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L240) · [src/quantum_circuits/operators/qubits_operator.jl:239](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L239) · [src/quantum_circuits/operators/qubits_operator.jl:229](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L229)

原生帮助：

Return a sparse matrix on `n` qubits, including zero and scalar operators.


<a id="api-MOSSQuantum-simplify"></a>

### `MOSSQuantum.simplify`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
simplify(operator::QubitsOperator; atol)
simplify(term::QubitsTerm; atol)
```

源码：[src/quantum_circuits/operators/qubits_operator.jl:184](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L184) · [src/quantum_circuits/operators/qubits_operator.jl:162](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/operators/qubits_operator.jl#L162)

原生帮助：

```julia
simplify(term::QubitsTerm; atol=0)
simplify(operator::QubitsOperator; atol=0)
```

Normalize exact local scalar/Pauli factors, remove identity factors, combine identical tensor-product terms, and discard coefficients with `abs(c) <= atol`. The default removes exact zeros only. For sums the cutoff is applied **after** combining terms. Arbitrary 2×2 factors are retained without Pauli expansion or approximate matrix matching. The input and its matrices remain independent of the result. Unlike Trotter's internal grouping, this operation does not absorb single-site terms into larger supports.


<a id="api-MOSSQuantum-H"></a>

### `MOSSQuantum.H`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.H`.

`MOSSQuantum.QuantumCircuits.Gates.H` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-X"></a>

### `MOSSQuantum.X`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.X`.

`MOSSQuantum.QuantumCircuits.Gates.X` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-Y"></a>

### `MOSSQuantum.Y`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `ComplexF64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.Y`.

`MOSSQuantum.QuantumCircuits.Gates.Y` is of type `Matrix{ComplexF64}`.

#### Summary

```
mutable struct Matrix{ComplexF64}
```

#### Fields

```
ref  :: MemoryRef{ComplexF64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{ComplexF64} <: DenseMatrix{ComplexF64} <: AbstractMatrix{ComplexF64} <: Any
```


<a id="api-MOSSQuantum-Z"></a>

### `MOSSQuantum.Z`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.Z`.

`MOSSQuantum.QuantumCircuits.Gates.Z` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-S"></a>

### `MOSSQuantum.S`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `ComplexF64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.S`.

`MOSSQuantum.QuantumCircuits.Gates.S` is of type `Matrix{ComplexF64}`.

#### Summary

```
mutable struct Matrix{ComplexF64}
```

#### Fields

```
ref  :: MemoryRef{ComplexF64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{ComplexF64} <: DenseMatrix{ComplexF64} <: AbstractMatrix{ComplexF64} <: Any
```


<a id="api-MOSSQuantum-T"></a>

### `MOSSQuantum.T`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `ComplexF64`，形状 `(2, 2)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.T`.

`MOSSQuantum.QuantumCircuits.Gates.T` is of type `Matrix{ComplexF64}`.

#### Summary

```
mutable struct Matrix{ComplexF64}
```

#### Fields

```
ref  :: MemoryRef{ComplexF64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{ComplexF64} <: DenseMatrix{ComplexF64} <: AbstractMatrix{ComplexF64} <: Any
```


<a id="api-MOSSQuantum-CNOT"></a>

### `MOSSQuantum.CNOT`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(4, 4)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.CNOT`.

`MOSSQuantum.QuantumCircuits.Gates.CNOT` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-CZ"></a>

### `MOSSQuantum.CZ`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(4, 4)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.CZ`.

`MOSSQuantum.QuantumCircuits.Gates.CZ` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-SWAP"></a>

### `MOSSQuantum.SWAP`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

矩阵常量；元素类型 `Float64`，形状 `(4, 4)`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.SWAP`.

`MOSSQuantum.QuantumCircuits.Gates.SWAP` is of type `Matrix{Float64}`.

#### Summary

```
mutable struct Matrix{Float64}
```

#### Fields

```
ref  :: MemoryRef{Float64}
size :: Tuple{Int64, Int64}
```

#### Supertype Hierarchy

```
Matrix{Float64} <: DenseMatrix{Float64} <: AbstractMatrix{Float64} <: Any
```


<a id="api-MOSSQuantum-Rx"></a>

### `MOSSQuantum.Rx`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Rx(θ::Number)
```

源码：[src/quantum_circuits/gates/Gates.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/Gates.jl#L37)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.Rx`.

`MOSSQuantum.QuantumCircuits.Gates.Rx` is a `Function`.

```
# 1 method for generic function "Rx" from MOSSQuantum.QuantumCircuits.Gates:
 [1] Rx(θ::Number)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/Gates.jl:37
```


<a id="api-MOSSQuantum-Ry"></a>

### `MOSSQuantum.Ry`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Ry(θ::Number)
```

源码：[src/quantum_circuits/gates/Gates.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/Gates.jl#L39)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.Ry`.

`MOSSQuantum.QuantumCircuits.Gates.Ry` is a `Function`.

```
# 1 method for generic function "Ry" from MOSSQuantum.QuantumCircuits.Gates:
 [1] Ry(θ::Number)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/Gates.jl:39
```


<a id="api-MOSSQuantum-Rz"></a>

### `MOSSQuantum.Rz`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Rz(θ::Number)
```

源码：[src/quantum_circuits/gates/Gates.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/Gates.jl#L41)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.Gates.Rz`.

`MOSSQuantum.QuantumCircuits.Gates.Rz` is a `Function`.

```
# 1 method for generic function "Rz" from MOSSQuantum.QuantumCircuits.Gates:
 [1] Rz(θ::Number)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/gates/Gates.jl:41
```


<a id="api-MOSSQuantum-StateVector"></a>

### `MOSSQuantum.StateVector`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
StateVector(nqubits::Int64)
StateVector(::Type{T}, nqubits::Int64) where T<:Number
StateVector(batch::BatchStateVector, i::Int64; copy)
StateVector(data::AbstractVector{T}, n::Int64; kwargs...) where T<:Number
StateVector(data::AbstractVector{T}; kwargs...) where T<:Number
StateVector(x::StateVector; copy)
```

源码：[src/states/state_vector.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L42) · [src/states/state_vector.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L41) · [src/states/batch_state_vector.jl:100](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L100) · [src/states/state_vector.jl:33](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L33) · [src/states/state_vector.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L35) · [src/states/state_vector.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L43)

原生帮助：

```julia
StateVector(data; copy=false, preserve_storage=false)
StateVector(state::StateVector; copy=false)
```

Construct a dense pure state. Array inputs use compatible CPU storage by default. `preserve_storage=true` retains the input array family; execution support is queried separately through its backend. Use `copy=true` to obtain independent storage, or `Base.copy(state)` to copy an existing state. `copy=false` permits reuse; element-type or layout conversion can still allocate. `storage(state)` exposes the mutable backing array.

```julia
StateVector(batch::BatchStateVector, i; copy=true)
```

Extract a state with independent vector storage. The extracted sample remains independent even with `copy=false`. Its owned storage is allocated from the batch array family.


<a id="api-MOSSQuantum-DensityMatrix"></a>

### `MOSSQuantum.DensityMatrix`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
DensityMatrix(nqubits::Int64)
DensityMatrix(::Type{T}, nqubits::Int64) where T<:Number
DensityMatrix(x::BatchDensityMatrix, sample::Int64; copy)
DensityMatrix(data::AbstractVecOrMat{T}, n::Int64; kwargs...) where T<:Number
DensityMatrix(data::AbstractVecOrMat{T}; kwargs...) where T<:Number
DensityMatrix(x::DensityMatrix; copy)
DensityMatrix(x::StateVector; copy)
```

源码：[src/states/density_matrix.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L61) · [src/states/density_matrix.jl:60](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L60) · [src/states/batch_density_matrix.jl:122](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L122) · [src/states/density_matrix.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L51) · [src/states/density_matrix.jl:53](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L53) · [src/states/density_matrix.jl:62](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L62) · [src/states/density_matrix.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L65)

原生帮助：

```julia
DensityMatrix(data; copy=false, preserve_storage=false)
DensityMatrix(state::DensityMatrix; copy=false)
```

Construct a dense mixed state. `preserve_storage=true` retains the array family instead of materializing CPU storage. Compatible vector or matrix storage is reused by default; `copy=true` guarantees independent backing storage. `copy=false` permits reuse but type or layout conversion can still allocate. Converting a pure state to a density matrix always creates new storage. `storage(state)` is a mutable matrix sharing the state's vectorized backing storage.

```julia
DensityMatrix(batch::BatchDensityMatrix, sample; copy=true)
```

Extract a density matrix with independent storage in the batch array family. Extraction remains independent even with `copy=false`.


<a id="api-MOSSQuantum-distance"></a>

### `MOSSQuantum.distance`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
distance(x::BatchDensityMatrix, y::BatchDensityMatrix)
distance(x::DensityMatrix, y::DensityMatrix)
distance(x::BatchStateVector, y::BatchStateVector)
distance(x::StateVector, y::StateVector)
```

源码：[src/states/batch_density_matrix.jl:200](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L200) · [src/states/density_matrix.jl:132](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L132) · [src/states/batch_state_vector.jl:208](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L208) · [src/states/state_vector.jl:95](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L95)

原生帮助：

No documentation found for public binding `MOSSQuantum.distance`.

`MOSSQuantum.distance` is a `Function`.

```
# 4 methods for generic function "distance" from MOSSQuantum:
 [1] distance(x::BatchDensityMatrix, y::BatchDensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:200
 [2] distance(x::DensityMatrix, y::DensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:132
 [3] distance(x::BatchStateVector, y::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:208
 [4] distance(x::StateVector, y::StateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:95
```


<a id="api-MOSSQuantum-distance2"></a>

### `MOSSQuantum.distance2`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
distance2(x::BatchDensityMatrix, y::BatchDensityMatrix)
distance2(x::DensityMatrix, y::DensityMatrix)
distance2(x::BatchStateVector, y::BatchStateVector)
distance2(x::StateVector, y::StateVector)
```

源码：[src/states/batch_density_matrix.jl:196](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L196) · [src/states/density_matrix.jl:131](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L131) · [src/states/batch_state_vector.jl:200](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L200) · [src/states/state_vector.jl:94](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L94)

原生帮助：

No documentation found for public binding `MOSSQuantum.distance2`.

`MOSSQuantum.distance2` is a `Function`.

```
# 4 methods for generic function "distance2" from MOSSQuantum:
 [1] distance2(x::BatchDensityMatrix, y::BatchDensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:196
 [2] distance2(x::DensityMatrix, y::DensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:131
 [3] distance2(x::BatchStateVector, y::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:200
 [4] distance2(x::StateVector, y::StateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:94
```


<a id="api-MOSSQuantum-onehot_encoding"></a>

### `MOSSQuantum.onehot_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
onehot_encoding(n::Int64)
onehot_encoding(i::AbstractVector{Int64})
onehot_encoding(::Type{T}, i::AbstractVector{Int64}) where T<:Number
onehot_encoding(::Type{T}, n::Int64) where T<:Number
```

源码：[src/states/state_vector.jl:100](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L100) · [src/states/state_vector.jl:102](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L102) · [src/states/state_vector.jl:101](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L101) · [src/states/state_vector.jl:99](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L99)

原生帮助：

No documentation found for public binding `MOSSQuantum.onehot_encoding`.

`MOSSQuantum.onehot_encoding` is a `Function`.

```
# 4 methods for generic function "onehot_encoding" from MOSSQuantum:
 [1] onehot_encoding(n::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:100
 [2] onehot_encoding(i::AbstractVector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:102
 [3] onehot_encoding(::Type{T}, i::AbstractVector{Int64}) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:101
 [4] onehot_encoding(::Type{T}, n::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:99
```


<a id="api-MOSSQuantum-qubit_encoding"></a>

### `MOSSQuantum.qubit_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
qubit_encoding(mpsstr::AbstractVector{<:Real})
qubit_encoding(::Type{T}, i::AbstractVector{<:Real}) where T<:Number
```

源码：[src/states/state_vector.jl:130](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L130) · [src/states/state_vector.jl:123](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L123)

原生帮助：

```julia
qstate(::Type{T}, thetas::AbstractVector{<:Real}) where {T <: Number}
```

Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas]

Example: qstate(Complex{Float64}, [0.5, 0.7])


<a id="api-MOSSQuantum-qstate"></a>

### `MOSSQuantum.qstate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
qstate(n::Int64)
qstate(::Type{T}, n::Int64) where T<:Number
qstate(thetas::AbstractVector{<:Real})
qstate(::Type{T}, thetas::AbstractVector{<:Real}) where T<:Number
```

源码：[src/states/state_vector.jl:155](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L155) · [src/states/state_vector.jl:149](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L149) · [src/states/state_vector.jl:143](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L143) · [src/states/state_vector.jl:137](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L137)

原生帮助：

```julia
qstate(::Type{T}, thetas::AbstractVector{<:Real}) where {T <: Number}
```

Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas. Example: qstate(Complex{Float64}, [0.5, 0.7])

```julia
qstate(thetas::AbstractVector{<:Real})
```

Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas.

```julia
qstate(::Type{T}, n::Int) where {T <: Number}
```

Return a zero quantum state with n qubits.

```julia
qstate(n::Int)
```

Return a zero quantum state with n qubits.


<a id="api-MOSSQuantum-amplitude_encoding"></a>

### `MOSSQuantum.amplitude_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
amplitude_encoding(v::AbstractVector; kwargs...)
amplitude_encoding(::Type{T}, v::AbstractVector{<:Number}; nqubits) where T<:Number
```

源码：[src/states/state_vector.jl:166](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L166) · [src/states/state_vector.jl:157](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L157)

原生帮助：

No documentation found for public binding `MOSSQuantum.amplitude_encoding`.

`MOSSQuantum.amplitude_encoding` is a `Function`.

```
# 2 methods for generic function "amplitude_encoding" from MOSSQuantum:
 [1] amplitude_encoding(v::AbstractVector; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:166
 [2] amplitude_encoding(::Type{T}, v::AbstractVector{<:Number}; nqubits) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:157
```


<a id="api-MOSSQuantum-reset!"></a>

### `MOSSQuantum.reset!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
reset!(x::BatchDensityMatrix)
reset!(x::BatchStateVector)
reset!(x::StateVector)
```

源码：[src/states/batch_density_matrix.jl:202](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L202) · [src/states/batch_state_vector.jl:301](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L301) · [src/states/state_vector.jl:168](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L168)

原生帮助：

No documentation found for public binding `MOSSQuantum.reset!`.

`MOSSQuantum.reset!` is a `Function`.

```
# 3 methods for generic function "reset!" from MOSSQuantum:
 [1] reset!(x::BatchDensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:202
 [2] reset!(x::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:301
 [3] reset!(x::StateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:168
```


<a id="api-MOSSQuantum-amplitude"></a>

### `MOSSQuantum.amplitude`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
amplitude(batch::BatchStateVector, idx::AbstractVector{Int64}, i::Int64; scaling)
amplitude(s::StateVector, i::AbstractVector{Int64}; scaling)
```

源码：[src/states/batch_state_vector.jl:337](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L337) · [src/states/state_vector.jl:209](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L209)

原生帮助：

```julia
amplitude(s::StateVector, i::AbstractVector{Int}; scaling::Real=√2)
```

Return the amplitude of a quantum state at a specific computational basis state.

The `scaling` parameter is used to scale the amplitude by a factor of `scaling^nqubits(s)`.


<a id="api-MOSSQuantum-amplitudes"></a>

### `MOSSQuantum.amplitudes`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
amplitudes(batch::BatchStateVector)
amplitudes(s::StateVector)
```

源码：[src/states/batch_state_vector.jl:346](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L346) · [src/states/state_vector.jl:215](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L215)

原生帮助：

No documentation found for public binding `MOSSQuantum.amplitudes`.

`MOSSQuantum.amplitudes` is a `Function`.

```
# 2 methods for generic function "amplitudes" from MOSSQuantum:
 [1] amplitudes(batch::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:346
 [2] amplitudes(s::StateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:215
```


<a id="api-MOSSQuantum-rand_state"></a>

### `MOSSQuantum.rand_state`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
rand_state(n::Int64)
rand_state(rng::Random.AbstractRNG, n::Int64)
rand_state(::Type{T}, n::Int64) where T<:Number
rand_state(rng::Random.AbstractRNG, ::Type{T}, n::Int64) where T<:Number
```

源码：[src/states/state_vector.jl:225](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L225) · [src/states/state_vector.jl:224](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L224) · [src/states/state_vector.jl:223](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L223) · [src/states/state_vector.jl:217](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L217)

原生帮助：

No documentation found for public binding `MOSSQuantum.rand_state`.

`MOSSQuantum.rand_state` is a `Function`.

```
# 4 methods for generic function "rand_state" from MOSSQuantum:
 [1] rand_state(n::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:225
 [2] rand_state(rng::Random.AbstractRNG, n::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:224
 [3] rand_state(::Type{T}, n::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:223
 [4] rand_state(rng::Random.AbstractRNG, ::Type{T}, n::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:217
```


<a id="api-MOSSQuantum-rand_densitymatrix"></a>

### `MOSSQuantum.rand_densitymatrix`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
rand_densitymatrix(n::Int64)
rand_densitymatrix(rng::Random.AbstractRNG, n::Int64)
rand_densitymatrix(::Type{T}, n::Int64) where T<:Number
rand_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int64) where T<:Number
```

源码：[src/states/density_matrix.jl:145](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L145) · [src/states/density_matrix.jl:144](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L144) · [src/states/density_matrix.jl:143](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L143) · [src/states/density_matrix.jl:136](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L136)

原生帮助：

No documentation found for public binding `MOSSQuantum.rand_densitymatrix`.

`MOSSQuantum.rand_densitymatrix` is a `Function`.

```
# 4 methods for generic function "rand_densitymatrix" from MOSSQuantum:
 [1] rand_densitymatrix(n::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:145
 [2] rand_densitymatrix(rng::Random.AbstractRNG, n::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:144
 [3] rand_densitymatrix(::Type{T}, n::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:143
 [4] rand_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:136
```


<a id="api-MOSSQuantum-fidelity"></a>

### `MOSSQuantum.fidelity`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
fidelity(x::StateVector, y::StateVector)
fidelity(x::StateVector, y::DensityMatrix)
fidelity(x::BatchStateVector, y::BatchDensityMatrix)
fidelity(x::BatchStateVector, y::BatchStateVector)
fidelity(x::DensityMatrix, y::DensityMatrix)
fidelity(x::DensityMatrix, y::StateVector)
fidelity(x::BatchDensityMatrix, y::BatchDensityMatrix)
fidelity(x::BatchDensityMatrix, y::BatchStateVector)
```

源码：[src/states/state_vector.jl:93](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L93) · [src/states/density_matrix.jl:130](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L130) · [src/states/batch_density_matrix.jl:194](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L194) · [src/states/batch_state_vector.jl:194](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L194) · [src/states/density_matrix.jl:121](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L121) · [src/states/density_matrix.jl:129](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L129) · [src/states/batch_density_matrix.jl:181](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L181) · [src/states/batch_density_matrix.jl:187](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L187)

原生帮助：

```julia
fidelity(x, y)
```

Return the squared Uhlmann fidelity of normalized quantum states. For density matrices this is `(tr(sqrt(sqrt(x) * y * sqrt(x))))^2`; for pure states it is `abs2(dot(x, y))`, and for a pure state and a density matrix it is `⟨ψ|ρ|ψ⟩`. Converting a pure state to a density matrix preserves the result.


<a id="api-MOSSQuantum-tr"></a>

### `MOSSQuantum.tr`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
tr(x::DensityMatrix)
tr(x::BatchDensityMatrix)
```

源码：[src/states/density_matrix.jl:105](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L105) · [src/states/batch_density_matrix.jl:158](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L158)

原生帮助：

```julia
tr(M)
```

Matrix trace. Sums the diagonal elements of `M`.

#### Examples

```jldoctest
julia> A = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> tr(A)
5
```


<a id="api-MOSSQuantum-dot"></a>

### `MOSSQuantum.dot`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
dot(x::BatchStateVector, m::AbstractVector, y::BatchStateVector)
dot(x::BatchStateVector, y::BatchStateVector)
dot(x::StateVector, m::AbstractVector, y::StateVector)
dot(x::StateVector, y::StateVector)
dot(x::DensityMatrix, y::DensityMatrix)
dot(x::BatchDensityMatrix, y::BatchDensityMatrix)
```

源码：[src/states/batch_state_vector.jl:186](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L186) · [src/states/batch_state_vector.jl:180](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L180) · [src/states/state_vector.jl:81](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L81) · [src/states/state_vector.jl:80](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L80) · [src/states/density_matrix.jl:106](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L106) · [src/states/batch_density_matrix.jl:163](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L163)

原生帮助：

```julia
dot(x, y)
x ⋅ y
```

Compute the dot product between two vectors. For complex vectors, the first vector is conjugated.

`dot` also works on arbitrary iterable objects, including arrays of any dimension, as long as `dot` is defined on the elements.

`dot` is semantically equivalent to `sum(dot(vx,vy) for (vx,vy) in zip(x, y))`, with the added restriction that the arguments must have equal lengths.

`x ⋅ y` (where `⋅` can be typed by tab-completing `\cdot` in the REPL) is a synonym for `dot(x, y)`.

#### Examples

```jldoctest
julia> dot([1; 1], [2; 3])
5

julia> dot([im; im], [1; 1])
0 - 2im

julia> dot(1:5, 2:6)
70

julia> x = fill(2., (5,5));

julia> y = fill(3., (5,5));

julia> dot(x, y)
150.0
```

```julia
dot(x, A, y)
```

Compute the generalized dot product `dot(x, A*y)` between two vectors `x` and `y`, without storing the intermediate result of `A*y`. As for the two-argument `dot(_,_)`, this acts recursively. Moreover, for complex vectors, the first vector is conjugated.

!!! compat "Julia 1.4"
    Three-argument `dot` requires at least Julia 1.4.


#### Examples

```jldoctest
julia> dot([1; 1], [1 2; 3 4], [2; 3])
26

julia> dot(1:5, reshape(1:25, 5, 5), 2:6)
4850

julia> ⋅(1:5, reshape(1:25, 5, 5), 2:6) == dot(1:5, reshape(1:25, 5, 5), 2:6)
true
```


<a id="api-MOSSQuantum-norm"></a>

### `MOSSQuantum.norm`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
norm(x::BatchStateVector)
norm(x::BatchDensityMatrix)
norm(x::StateVector)
```

源码：[src/states/batch_state_vector.jl:163](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L163) · [src/states/batch_density_matrix.jl:159](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L159) · [src/states/state_vector.jl:79](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L79)

原生帮助：

```julia
norm(A, p::Real=2)
```

For any iterable container `A` (including arrays of any dimension) of numbers (or any element type for which `norm` is defined), compute the `p`-norm (defaulting to `p=2`) as if `A` were a vector of the corresponding length.

The `p`-norm is defined as

$$
\|A\|_p = \left( \sum_{i=1}^n | a_i | ^p \right)^{1/p}
$$

with $a_i$ the entries of $A$, $| a_i |$ the `norm` of $a_i$, and $n$ the length of $A$. Since the `p`-norm is computed using the `norm`s of the entries of `A`, the `p`-norm of a vector of vectors is not compatible with the interpretation of it as a block vector in general if `p != 2`.

`p` can assume any numeric value (even though not all values produce a mathematically valid vector norm). In particular, `norm(A, Inf)` returns the largest value in `abs.(A)`, whereas `norm(A, -Inf)` returns the smallest. If `A` is a matrix and `p=2`, then this is equivalent to the Frobenius norm.

The second argument `p` is not necessarily a part of the interface for `norm`, i.e. a custom type may only implement `norm(A)` without second argument.

Use `opnorm` to compute the operator norm of a matrix.

#### Examples

```jldoctest
julia> v = [3, -2, 6]
3-element Vector{Int64}:
  3
 -2
  6

julia> norm(v)
7.0

julia> norm(v, 1)
11.0

julia> norm(v, Inf)
6.0

julia> norm([1 2 3; 4 5 6; 7 8 9])
16.881943016134134

julia> norm([1 2 3 4 5 6 7 8 9])
16.881943016134134

julia> norm(1:9)
16.881943016134134

julia> norm(hcat(v,v), 1) == norm(vcat(v,v), 1) != norm([v,v], 1)
true

julia> norm(hcat(v,v), 2) == norm(vcat(v,v), 2) == norm([v,v], 2)
true

julia> norm(hcat(v,v), Inf) == norm(vcat(v,v), Inf) != norm([v,v], Inf)
true
```

```julia
norm(x::Number, p::Real=2)
```

For numbers, return $\left( |x|^p \right)^{1/p}$.

#### Examples

```jldoctest
julia> norm(2, 1)
2.0

julia> norm(-2, 1)
2.0

julia> norm(2, 2)
2.0

julia> norm(-2, 2)
2.0

julia> norm(2, Inf)
2.0

julia> norm(-2, Inf)
2.0
```


<a id="api-MOSSQuantum-normalize!"></a>

### `MOSSQuantum.normalize!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
normalize!(x::BatchDensityMatrix)
normalize!(x::BatchStateVector)
normalize!(x::DensityMatrix)
normalize!(x::StateVector)
```

源码：[src/states/batch_density_matrix.jl:168](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L168) · [src/states/batch_state_vector.jl:165](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L165) · [src/states/density_matrix.jl:107](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L107) · [src/states/state_vector.jl:82](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L82)

原生帮助：

```julia
normalize!(a::AbstractArray, p::Real=2)
```

Normalize the array `a` in-place so that its `p`-norm equals unity, i.e. `norm(a, p) == 1`. See also `normalize` and `norm`.


<a id="api-MOSSQuantum-normalize"></a>

### `MOSSQuantum.normalize`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
normalize(x::BatchDensityMatrix)
normalize(x::BatchStateVector)
normalize(x::DensityMatrix)
normalize(x::StateVector)
```

源码：[src/states/batch_density_matrix.jl:179](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L179) · [src/states/batch_state_vector.jl:177](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L177) · [src/states/density_matrix.jl:108](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L108) · [src/states/state_vector.jl:83](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L83)

原生帮助：

```julia
normalize(a, p::Real=2)
```

Normalize `a` so that its `p`-norm equals unity, i.e. `norm(a, p) == 1`. For scalars, this is similar to sign(a), except normalize(0) = NaN. See also `normalize!`, `norm`, and `sign`.

#### Examples

```jldoctest
julia> a = [1,2,4];

julia> b = normalize(a)
3-element Vector{Float64}:
 0.2182178902359924
 0.4364357804719848
 0.8728715609439696

julia> norm(b)
1.0

julia> c = normalize(a, 1)
3-element Vector{Float64}:
 0.14285714285714285
 0.2857142857142857
 0.5714285714285714

julia> norm(c, 1)
1.0

julia> a = [1 2 4 ; 1 2 4]
2×3 Matrix{Int64}:
 1  2  4
 1  2  4

julia> norm(a)
6.48074069840786

julia> normalize(a)
2×3 Matrix{Float64}:
 0.154303  0.308607  0.617213
 0.154303  0.308607  0.617213

julia> normalize(3, 1)
1.0

julia> normalize(-8, 1)
-1.0

julia> normalize(0, 1)
NaN
```


<a id="api-MOSSQuantum-ishermitian"></a>

### `MOSSQuantum.ishermitian`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ishermitian(x::QubitsOperator)
ishermitian(x::QubitsTerm)
ishermitian(x::DensityMatrix)
ishermitian(x::BatchDensityMatrix)
```

源码：[src/backends/cpu/operators/utils.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/backends/cpu/operators/utils.jl#L43) · [src/backends/cpu/operators/utils.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/backends/cpu/operators/utils.jl#L35) · [src/states/density_matrix.jl:109](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L109) · [src/states/batch_density_matrix.jl:160](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L160)

原生帮助：

```julia
ishermitian(A) -> Bool
```

Test whether a matrix is Hermitian.

#### Examples

```jldoctest
julia> a = [1 2; 2 -1]
2×2 Matrix{Int64}:
 1   2
 2  -1

julia> ishermitian(a)
true

julia> b = [1 im; -im 1]
2×2 Matrix{Complex{Int64}}:
 1+0im  0+1im
 0-1im  1+0im

julia> ishermitian(b)
true
```


<a id="api-MOSSQuantum-reset_qubit!"></a>

### `MOSSQuantum.reset_qubit!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
reset_qubit!(x::BatchDensityMatrix, inputs::AbstractMatrix{<:Real})
reset_qubit!(x::BatchStateVector, inputs::AbstractMatrix{<:Real})
reset_qubit!(x::StateVector, i::AbstractVector{<:Real})
```

源码：[src/states/batch_density_matrix.jl:220](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L220) · [src/states/batch_state_vector.jl:321](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L321) · [src/states/state_vector.jl:183](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L183)

原生帮助：

No documentation found for public binding `MOSSQuantum.reset_qubit!`.

`MOSSQuantum.reset_qubit!` is a `Function`.

```
# 3 methods for generic function "reset_qubit!" from MOSSQuantum:
 [1] reset_qubit!(x::BatchDensityMatrix, inputs::AbstractMatrix{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:220
 [2] reset_qubit!(x::BatchStateVector, inputs::AbstractMatrix{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:321
 [3] reset_qubit!(x::StateVector, i::AbstractVector{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:183
```


<a id="api-MOSSQuantum-reset_onehot!"></a>

### `MOSSQuantum.reset_onehot!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
reset_onehot!(x::BatchDensityMatrix, indices::Vector{Vector{Int64}})
reset_onehot!(x::BatchStateVector, indices::Vector{Vector{Int64}})
reset_onehot!(x::StateVector, i::AbstractVector{Int64})
```

源码：[src/states/batch_density_matrix.jl:208](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L208) · [src/states/batch_state_vector.jl:308](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L308) · [src/states/state_vector.jl:174](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L174)

原生帮助：

No documentation found for public binding `MOSSQuantum.reset_onehot!`.

`MOSSQuantum.reset_onehot!` is a `Function`.

```
# 3 methods for generic function "reset_onehot!" from MOSSQuantum:
 [1] reset_onehot!(x::BatchDensityMatrix, indices::Vector{Vector{Int64}})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:208
 [2] reset_onehot!(x::BatchStateVector, indices::Vector{Vector{Int64}})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:308
 [3] reset_onehot!(x::StateVector, i::AbstractVector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:174
```


<a id="api-MOSSQuantum-storage"></a>

### `MOSSQuantum.storage`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
storage(x::BatchDensityMatrix)
storage(x::DensityMatrix)
storage(x::BatchStateVector)
storage(x::StateVector)
```

源码：[src/states/batch_density_matrix.jl:127](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L127) · [src/states/density_matrix.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L74) · [src/states/batch_state_vector.jl:72](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L72) · [src/states/state_vector.jl:47](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L47)

原生帮助：

No documentation found for public binding `MOSSQuantum.storage`.

`MOSSQuantum.storage` is a `Function`.

```
# 4 methods for generic function "storage" from MOSSQuantum:
 [1] storage(x::BatchDensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:127
 [2] storage(x::DensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:74
 [3] storage(x::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:72
 [4] storage(x::StateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:47
```


<a id="api-MOSSQuantum-schmidt_numbers"></a>

### `MOSSQuantum.schmidt_numbers`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
schmidt_numbers(x::DensityMatrix)
```

源码：[src/states/density_matrix.jl:133](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L133)

原生帮助：

No documentation found for public binding `MOSSQuantum.schmidt_numbers`.

`MOSSQuantum.schmidt_numbers` is a `Function`.

```
# 1 method for generic function "schmidt_numbers" from MOSSQuantum:
 [1] schmidt_numbers(x::DensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:133
```


<a id="api-MOSSQuantum-renyi_entropy"></a>

### `MOSSQuantum.renyi_entropy`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
renyi_entropy(x::DensityMatrix; kwargs...)
renyi_entropy(v::AbstractVector{T}; α) where T
```

源码：[src/states/density_matrix.jl:134](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L134) · [src/utils/tensor_ops.jl:32](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utils/tensor_ops.jl#L32)

原生帮助：

No documentation found for public binding `MOSSQuantum.renyi_entropy`.

`MOSSQuantum.renyi_entropy` is a `Function`.

```
# 2 methods for generic function "renyi_entropy" from MOSSQuantum:
 [1] renyi_entropy(x::DensityMatrix; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:134
 [2] renyi_entropy(v::AbstractVector{T}; α) where T
     @ ~/Code/Quantum/MOSSQuantum/src/utils/tensor_ops.jl:32
```


<a id="api-MOSSQuantum-permute"></a>

### `MOSSQuantum.permute`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
permute(x::BatchDensityMatrix, order::Vector{Int64})
permute(x::DensityMatrix, newindex::Vector{Int64})
permute(x::BatchStateVector, newindex::Vector{Int64})
permute(x::StateVector, newindex::Vector{Int64})
permute(m::AbstractArray, perm)
```

源码：[src/states/batch_density_matrix.jl:228](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L228) · [src/states/density_matrix.jl:147](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/density_matrix.jl#L147) · [src/states/batch_state_vector.jl:362](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L362) · [src/states/state_vector.jl:227](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/state_vector.jl#L227) · [src/quantum_circuits/utils/tensor_ops.jl:4](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/utils/tensor_ops.jl#L4)

原生帮助：

No documentation found for private binding `MOSSQuantum.QuantumCircuits.permute`.

`MOSSQuantum.QuantumCircuits.permute` is a `Function`.

```
# 5 methods for generic function "permute" from MOSSQuantum.QuantumCircuits:
 [1] permute(x::BatchDensityMatrix, order::Vector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:228
 [2] permute(x::DensityMatrix, newindex::Vector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/density_matrix.jl:147
 [3] permute(x::BatchStateVector, newindex::Vector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:362
 [4] permute(x::StateVector, newindex::Vector{Int64})
     @ ~/Code/Quantum/MOSSQuantum/src/states/state_vector.jl:227
 [5] permute(m::AbstractArray, perm)
     @ ~/Code/Quantum/MOSSQuantum/src/quantum_circuits/utils/tensor_ops.jl:4
```


<a id="api-MOSSQuantum-BatchStateVector"></a>

### `MOSSQuantum.BatchStateVector`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BatchStateVector(nqubits::Int64, batch_size::Int64)
BatchStateVector(::Type{T}, nqubits::Int64, batch_size::Int64) where T<:Number
BatchStateVector(x::BatchStateVector; copy)
BatchStateVector(data::AbstractMatrix{T}, n::Int64; kwargs...) where T<:Number
BatchStateVector(data::AbstractMatrix{T}, n::Int64, B::Int64; kwargs...) where T<:Number
BatchStateVector(vec::AbstractVector{<:StateVector}; copy)
BatchStateVector(data::AbstractMatrix{T}; kwargs...) where T<:Number
BatchStateVector(sv::StateVector{T, A} where A<:AbstractVector{T}; copy) where T<:Number
```

源码：[src/states/batch_state_vector.jl:64](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L64) · [src/states/batch_state_vector.jl:63](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L63) · [src/states/batch_state_vector.jl:67](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L67) · [src/states/batch_state_vector.jl:46](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L46) · [src/states/batch_state_vector.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L44) · [src/states/batch_state_vector.jl:107](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L107) · [src/states/batch_state_vector.jl:48](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L48) · [src/states/batch_state_vector.jl:89](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L89)

原生帮助：

```julia
BatchStateVector(data; copy=false, preserve_storage=false)
BatchStateVector(state::BatchStateVector; copy=true)
BatchStateVector(state::StateVector; copy=false)
```

Construct a batch of dense pure states. `preserve_storage=true` on array inputs retains their array family; ordinary array constructors materialize CPU storage. Array inputs and single-state inputs reuse compatible storage by default. The batch-to-batch constructor retains its historical `copy=true` default. Explicit `copy=true` guarantees independent storage; `copy=false` permits reuse but conversions can still allocate. `storage(batch)` exposes the mutable backing matrix.

Columns are independent samples of the same qubit count. A one-column batch remains a batch; constructors never squeeze it into a `StateVector`. Empty batches and zero-qubit states are allowed when their dimensions are explicit.


<a id="api-MOSSQuantum-batch_size"></a>

### `MOSSQuantum.batch_size`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
batch_size(x::BatchDensityMatrix)
batch_size(x::BatchStateVector)
```

源码：[src/states/batch_density_matrix.jl:129](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L129) · [src/states/batch_state_vector.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L74)

原生帮助：

No documentation found for public binding `MOSSQuantum.batch_size`.

`MOSSQuantum.batch_size` is a `Function`.

```
# 2 methods for generic function "batch_size" from MOSSQuantum:
 [1] batch_size(x::BatchDensityMatrix)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:129
 [2] batch_size(x::BatchStateVector)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:74
```


<a id="api-MOSSQuantum-batch_onehot_encoding"></a>

### `MOSSQuantum.batch_onehot_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
batch_onehot_encoding(indices::Vector{Vector{Int64}})
batch_onehot_encoding(n::Int64, batch_size::Int64)
batch_onehot_encoding(::Type{T}, indices::Vector{Vector{Int64}}) where T<:Number
batch_onehot_encoding(::Type{T}, n::Int64, batch_size::Int64) where T<:Number
```

源码：[src/states/batch_state_vector.jl:242](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L242) · [src/states/batch_state_vector.jl:221](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L221) · [src/states/batch_state_vector.jl:228](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L228) · [src/states/batch_state_vector.jl:218](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L218)

原生帮助：

```julia
batch_onehot_encoding(::Type{T}, n::Int, batch_size::Int) where {T <: Number}
```

Create a batch of zero states |0...0⟩ with `n` qubits and `batch_size` states.

```julia
batch_onehot_encoding(::Type{T}, indices::Vector{Vector{Int}}) where {T <: Number}
```

Create a batch of computational basis states specified by `indices`. Each element of `indices` is a binary vector representing the basis state.


<a id="api-MOSSQuantum-batch_qubit_encoding"></a>

### `MOSSQuantum.batch_qubit_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
batch_qubit_encoding(inputs::AbstractMatrix{<:Real})
batch_qubit_encoding(::Type{T}, inputs::AbstractMatrix{<:Real}) where T<:Number
```

源码：[src/states/batch_state_vector.jl:262](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L262) · [src/states/batch_state_vector.jl:249](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L249)

原生帮助：

```julia
batch_qubit_encoding(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T <: Number}
```

Create a batch of product states using qubit encoding. Each column of `inputs` is a vector of parameters for one state.


<a id="api-MOSSQuantum-batch_amplitude_encoding"></a>

### `MOSSQuantum.batch_amplitude_encoding`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
batch_amplitude_encoding(inputs::AbstractMatrix{<:Number}; kwargs...)
batch_amplitude_encoding(::Type{T}, inputs::AbstractMatrix{<:Number}; nqubits) where T<:Number
```

源码：[src/states/batch_state_vector.jl:296](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L296) · [src/states/batch_state_vector.jl:270](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L270)

原生帮助：

```julia
batch_amplitude_encoding(::Type{T}, inputs::AbstractMatrix{<:Number}; nqubits::Int) where {T<:Number}
```

Create a batch of amplitude encoded states. Each column of `inputs` is a vector to encode as a quantum state. The default qubit count is the smallest register that holds all input rows.


<a id="api-MOSSQuantum-rand_batch"></a>

### `MOSSQuantum.rand_batch`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
rand_batch(n::Int64, batch_size::Int64)
rand_batch(rng::Random.AbstractRNG, n::Int64, batch_size::Int64)
rand_batch(::Type{T}, n::Int64, batch_size::Int64) where T<:Number
rand_batch(rng::Random.AbstractRNG, ::Type{T}, n::Int64, batch_size::Int64) where T<:Number
```

源码：[src/states/batch_state_vector.jl:359](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L359) · [src/states/batch_state_vector.jl:358](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L358) · [src/states/batch_state_vector.jl:357](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L357) · [src/states/batch_state_vector.jl:350](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_state_vector.jl#L350)

原生帮助：

No documentation found for public binding `MOSSQuantum.rand_batch`.

`MOSSQuantum.rand_batch` is a `Function`.

```
# 4 methods for generic function "rand_batch" from MOSSQuantum:
 [1] rand_batch(n::Int64, batch_size::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:359
 [2] rand_batch(rng::Random.AbstractRNG, n::Int64, batch_size::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:358
 [3] rand_batch(::Type{T}, n::Int64, batch_size::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:357
 [4] rand_batch(rng::Random.AbstractRNG, ::Type{T}, n::Int64, batch_size::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_state_vector.jl:350
```


<a id="api-MOSSQuantum-BatchDensityMatrix"></a>

### `MOSSQuantum.BatchDensityMatrix`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BatchDensityMatrix(n::Int64, B::Int64)
BatchDensityMatrix(::Type{T}, n::Int64, B::Int64) where T<:Number
BatchDensityMatrix(x::StateVector; copy)
BatchDensityMatrix(x::BatchStateVector; copy)
BatchDensityMatrix(data::AbstractArray{T, 3}, n::Int64; kwargs...) where T<:Number
BatchDensityMatrix(data::AbstractArray{T, 3}, n::Int64, B::Int64; kwargs...) where T<:Number
BatchDensityMatrix(states::AbstractVector{<:DensityMatrix}; copy)
BatchDensityMatrix(data::AbstractArray{T, 3}; kwargs...) where T<:Number
BatchDensityMatrix(x::DensityMatrix; copy)
BatchDensityMatrix(x::BatchDensityMatrix; copy)
```

源码：[src/states/batch_density_matrix.jl:75](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L75) · [src/states/batch_density_matrix.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L74) · [src/states/batch_density_matrix.jl:112](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L112) · [src/states/batch_density_matrix.jl:104](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L104) · [src/states/batch_density_matrix.jl:59](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L59) · [src/states/batch_density_matrix.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L57) · [src/states/batch_density_matrix.jl:89](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L89) · [src/states/batch_density_matrix.jl:61](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L61) · [src/states/batch_density_matrix.jl:82](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L82) · [src/states/batch_density_matrix.jl:77](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L77)

原生帮助：

```julia
BatchDensityMatrix(data; copy=false, preserve_storage=false)
BatchDensityMatrix(state::BatchDensityMatrix; copy=true)
BatchDensityMatrix(state::DensityMatrix; copy=false)
BatchDensityMatrix(state::Union{StateVector,BatchStateVector})
```

Array constructors materialize CPU storage unless `preserve_storage=true` is requested. Copies and state conversions retain the array family.

A batch of independent dense density matrices with mutable storage of shape `(2^n, 2^n, B)`. The last axis always identifies samples, including when `B=1`. Zero-qubit registers and empty batches are supported. Array and single-density inputs may share compatible storage; `copy=true` guarantees independent storage. Pure-state conversions and lists always allocate each sample's outer product or copy. Constructors validate shape, without requiring positivity or unit trace.


<a id="api-MOSSQuantum-rand_batch_densitymatrix"></a>

### `MOSSQuantum.rand_batch_densitymatrix`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
rand_batch_densitymatrix(n::Int64, B::Int64)
rand_batch_densitymatrix(rng::Random.AbstractRNG, n::Int64, B::Int64)
rand_batch_densitymatrix(::Type{T}, n::Int64, B::Int64) where T<:Number
rand_batch_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int64, B::Int64) where T<:Number
```

源码：[src/states/batch_density_matrix.jl:256](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L256) · [src/states/batch_density_matrix.jl:254](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L254) · [src/states/batch_density_matrix.jl:252](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L252) · [src/states/batch_density_matrix.jl:243](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/states/batch_density_matrix.jl#L243)

原生帮助：

No documentation found for public binding `MOSSQuantum.rand_batch_densitymatrix`.

`MOSSQuantum.rand_batch_densitymatrix` is a `Function`.

```
# 4 methods for generic function "rand_batch_densitymatrix" from MOSSQuantum:
 [1] rand_batch_densitymatrix(n::Int64, B::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:256
 [2] rand_batch_densitymatrix(rng::Random.AbstractRNG, n::Int64, B::Int64)
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:254
 [3] rand_batch_densitymatrix(::Type{T}, n::Int64, B::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:252
 [4] rand_batch_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int64, B::Int64) where T<:Number
     @ ~/Code/Quantum/MOSSQuantum/src/states/batch_density_matrix.jl:243
```


<a id="api-MOSSQuantum-variational_circuit_1d"></a>

### `MOSSQuantum.variational_circuit_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
variational_circuit_1d(L::Int64, depth::Int64; θs)
```

源码：[src/utilities/algorithms/variational_circuit.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/algorithms/variational_circuit.jl#L5)

原生帮助：

```julia
variational_circuit_1d(L::Int, depth::Int; θs::Vector{<:Real})
```

Return a variational quantum circuit given L qubis and d depth


<a id="api-MOSSQuantum-real_variational_circuit_1d"></a>

### `MOSSQuantum.real_variational_circuit_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
real_variational_circuit_1d(L::Int64, depth::Int64; θs)
```

源码：[src/utilities/algorithms/variational_circuit.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/algorithms/variational_circuit.jl#L41)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.real_variational_circuit_1d`.

`MOSSQuantum.Utilities.real_variational_circuit_1d` is a `Function`.

```
# 1 method for generic function "real_variational_circuit_1d" from MOSSQuantum.Utilities:
 [1] real_variational_circuit_1d(L::Int64, depth::Int64; θs)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/algorithms/variational_circuit.jl:41
```


<a id="api-MOSSQuantum-apply!"></a>

### `MOSSQuantum.apply!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
apply!(instruction::QMeasure, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; rng)
apply!(operation::AbstractInstruction, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; kwargs...)
apply!(operation::AbstractInstruction, state::AbstractQuantumState; kwargs...)
apply!(b::CPUBackend, circuit::QCircuit, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; rng)
apply!(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState)
apply!(b::CPUBackend, operation::AbstractInstruction, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; kwargs...)
apply!(b::AbstractBackend, operation, state::AbstractQuantumState; kwargs...)
```

源码：[src/api/backend_protocols.jl:326](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L326) · [src/api/backend_protocols.jl:235](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L235) · [src/api/backend_protocols.jl:233](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L233) · [src/api/backend_protocols.jl:222](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L222) · [src/api/backend_protocols.jl:218](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L218) · [src/api/backend_protocols.jl:194](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L194) · [src/api/backend_protocols.jl:189](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L189)

原生帮助：

```julia
apply!(backend, instruction, state)
```

Execute an instruction using an explicitly selected backend. CPU methods call internal implementations, retaining public instruction hooks within circuits and the existing measurement metadata return conventions. Unknown combinations throw `UnsupportedOperation`. Backend extensions validate positions before mutating their state and return the resulting state.


<a id="api-MOSSQuantum-measure"></a>

### `MOSSQuantum.measure`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
measure(batch::BatchDensityMatrix, position::Int64; rng)
measure(batch::BatchStateVector, position::Int64; rng)
measure(qstate::StateVector, pos::Int64; rng)
```

源码：[src/execution/batch_density_measurement.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/batch_density_measurement.jl#L34) · [src/execution/measurement.jl:92](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/measurement.jl#L92) · [src/execution/measurement.jl:55](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/measurement.jl#L55)

原生帮助：

```julia
measure(qstate::StateVector, i::Int)
```

Measure the i-th qubit of the quantum state, and return a 3-tuple including the collapsed quantum state, 

the measurement outcome, and the probability with which we get the outcome. The measured qubit is removed; the remaining qubits retain their relative order.

```julia
measure(batch::BatchStateVector, position; rng=Random.default_rng())
```

Measure each column independently and remove the measured qubit. Return `(collapsed_batch, outcomes, probabilities)` without modifying the input. The remaining qubits retain their relative order, including for the last qubit.

```julia
measure(batch::BatchDensityMatrix, position; rng=Random.default_rng())
```

Return `(collapsed_batch, outcomes, probabilities)` without changing the input. Remove the measured qubit and preserve the relative order of the remaining ones.


<a id="api-MOSSQuantum-measure!"></a>

### `MOSSQuantum.measure!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
measure!(b::CPUBackend, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}, position::Int64; auto_reset, rng)
measure!(b::AbstractBackend, state::AbstractQuantumState, position::Int64; auto_reset, rng)
measure!(batch::BatchDensityMatrix, position::Int64; auto_reset, rng)
measure!(batch::BatchStateVector, position::Int64; auto_reset, rng)
measure!(qstate::Union{DensityMatrix, StateVector}, pos::Int64; auto_reset, rng)
```

源码：[src/execution/simulation.jl:47](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L47) · [src/execution/simulation.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L42) · [src/execution/batch_density_measurement.jl:8](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/batch_density_measurement.jl#L8) · [src/execution/measurement.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/measurement.jl#L65) · [src/execution/measurement.jl:26](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/measurement.jl#L26)

原生帮助：

```julia
measure!(qstate::StateVector, pos::Int; auto_reset::Bool=true)
```

Measure the i-th qubit of the quantum state, and return a 2-tuple including the measurement outcome, 

and the probability with which we get the outcome. The quantum state is updated inplace. 

If auto_reset=true,the measured qubit is reset to 0, otherwise it will be the same as the measurement outcome.

```julia
measure!(batch::BatchStateVector, position; auto_reset=true, rng=Random.default_rng())
```

Measure each batch column independently, preserving the register size. Return `(outcomes, probabilities)` in column order. Each column is collapsed and, when `auto_reset=true`, its measured qubit is reset to zero. An empty batch returns empty vectors; `position` must still name an existing qubit.

```julia
measure!(batch::BatchDensityMatrix, position; auto_reset=true, rng=Random.default_rng())
```

Measure each density matrix independently, keeping the register size. Return `(outcomes, probabilities)` in sample order. Validate every sample before consuming randomness or changing storage.


<a id="api-MOSSQuantum-expectation"></a>

### `MOSSQuantum.expectation`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
expectation(b::CPUBackend, observable, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector})
expectation(b::CPUBackend, left::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}, observable, right::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector})
expectation(left::BatchStateVector, observable, right::BatchStateVector)
expectation(b::AbstractBackend, observable, state::AbstractQuantumState)
expectation(b::AbstractBackend, left::AbstractQuantumState, observable, right::AbstractQuantumState)
expectation(x::DensityMatrix, m::Gate, y::DensityMatrix)
expectation(left::StateVector, observable, right::StateVector)
expectation(observable, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector})
expectation(observable, state::AbstractQuantumState)
```

源码：[src/api/backend_protocols.jl:250](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L250) · [src/api/backend_protocols.jl:272](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L272) · [src/api/backend_protocols.jl:279](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L279) · [src/api/backend_protocols.jl:246](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L246) · [src/api/backend_protocols.jl:269](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L269) · [src/differentiation/circuit.jl:147](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/circuit.jl#L147) · [src/api/backend_protocols.jl:277](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L277) · [src/api/backend_protocols.jl:267](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L267) · [src/api/backend_protocols.jl:263](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L263)

原生帮助：

```julia
expectation(backend, observable, state)
```

Evaluate an observable with an explicit backend. This is separate from applying an instruction: Hamiltonian terms and operators are valid observables without being executable circuit elements. Unknown combinations throw `UnsupportedOperation`.


<a id="api-MOSSQuantum-post_select"></a>

### `MOSSQuantum.post_select`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
post_select(batch::BatchDensityMatrix, position::Int64, outcome::Int64; keep)
post_select(batch::BatchDensityMatrix, position::Int64; ...)
post_select(batch::BatchStateVector, position::Int64, outcome::Int64; keep)
post_select(batch::BatchStateVector, position::Int64; ...)
post_select(qstate::StateVector, key::Int64, state::Int64; keep)
post_select(qstate::StateVector, key::Int64; ...)
```

源码：[src/execution/batch_density_measurement.jl:100](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/batch_density_measurement.jl#L100) · [src/execution/post_selection.jl:78](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/post_selection.jl#L78) · [src/execution/post_selection.jl:31](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/post_selection.jl#L31)

原生帮助：

```julia
post_select(qstate::StateVector, key::Int, state::Int=0; keep::Bool=false)
```

Return the collapsed quantum state as well as the probability. If `keep=false`, remove the selected qubit and retain the relative order of the remaining qubits. If `keep=true`, preserve the original number of qubits.

```julia
post_select(batch::BatchStateVector, position, outcome=0; keep=false)
```

Return `(collapsed_batch, probabilities)` in column order without changing the input. Remove the selected qubit unless `keep=true`. Empty batches preserve their batch size and return an empty probability vector.

```julia
post_select(batch::BatchDensityMatrix, position, outcome=0; keep=false)
```

Return `(collapsed_batch, probabilities)` without changing the input. Remove the selected qubit unless `keep=true`; preserve the other qubits' order.


<a id="api-MOSSQuantum-post_select!"></a>

### `MOSSQuantum.post_select!`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
post_select!(batch::BatchDensityMatrix, position::Int64, outcome::Int64)
post_select!(batch::BatchDensityMatrix, position::Int64)
post_select!(batch::BatchStateVector, position::Int64, outcome::Int64)
post_select!(batch::BatchStateVector, position::Int64)
post_select!(qstate::StateVector, key::Int64, state::Int64)
post_select!(qstate::StateVector, key::Int64)
```

源码：[src/execution/batch_density_measurement.jl:82](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/batch_density_measurement.jl#L82) · [src/execution/post_selection.jl:59](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/post_selection.jl#L59) · [src/execution/post_selection.jl:23](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/post_selection.jl#L23)

原生帮助：

```julia
post_select!(qstate::StateVector, key::Int, state::Int=0)
```

Post-select the i-th qubit of the quantum state, and the quantum state is updated inplace, the probability is returned.

```julia
post_select!(batch::BatchStateVector, position, outcome=0)
```

Post-select the same outcome in every batch column, keeping the measured qubit. Return one probability per column. Every column must have a positive finite probability; all columns are checked before any state data is changed.

```julia
post_select!(batch::BatchDensityMatrix, position, outcome=0)
```

Keep and normalize the selected block of each sample. Return its raw trace weight per sample. Every weight must be positive and finite; failures leave the whole batch unchanged. Inputs need not have unit trace.


<a id="api-MOSSQuantum-partial_tr"></a>

### `MOSSQuantum.partial_tr`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
partial_tr(state::StateVector, sites::Vector{Int64})
partial_tr(state::DensityMatrix, sites::Vector{Int64})
partial_tr(batch::BatchStateVector, sites::Vector{Int64})
partial_tr(batch::BatchDensityMatrix, sites::Vector{Int64})
```

源码：[src/observables/partial_trace.jl:55](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/partial_trace.jl#L55) · [src/observables/partial_trace.jl:45](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/partial_trace.jl#L45) · [src/observables/partial_trace.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/partial_trace.jl#L34) · [src/observables/partial_trace.jl:11](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/partial_trace.jl#L11)

原生帮助：

```julia
partial_tr(batch::BatchDensityMatrix, sites::Vector{Int})
```

Trace out the same qubits in every sample. The result is an independently owned `BatchDensityMatrix` with the sample axis retained. Tracing every qubit of a nonzero register returns the vector of sample traces. Empty `sites` copies the batch; the existing pure-batch return convention remains unchanged.

```julia
partial_tr(batch::BatchStateVector, sites::Vector{Int})
```

Trace out `sites` independently for each pure-state sample. Return a vector of ordinary `DensityMatrix` results, or the vector of squared norms when all qubits of a nonzero register are traced out. This does not combine samples or introduce a batch density-matrix representation. Empty `sites` follows the single-state conversion convention. Results own independent storage.


<a id="api-MOSSQuantum-AbstractInstruction"></a>

### `MOSSQuantum.AbstractInstruction`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

```julia
AbstractInstruction <: QuantumOperation
```

An operation that can be stored in a `QCircuit`. Extend this type for a new instruction, and implement `positions` and the execution methods for its backend. Hamiltonian terms and operators are `QuantumOperation`s, but are not instructions.

Instructions have no parameters by default. Parameterized instructions must implement the parameter interface as well as their backend execution methods.


<a id="api-MOSSQuantum-validate_positions"></a>

### `MOSSQuantum.validate_positions`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
validate_positions(observable::QubitsOperator, n::Integer)
validate_positions(operation, n::Integer)
```

源码：[src/api/backend_protocols.jl:158](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L158) · [src/quantum_circuits/instructions.jl:96](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L96)

原生帮助：

```julia
validate_positions(operation, nqubits) -> nothing
```

Check that every position reported by an operation is an integer in `1:nqubits`. This checks register bounds only; each backend separately determines which instruction types and arities it implements. Empty position lists are valid, for example for an empty circuit or an instruction with no quantum inputs.


<a id="api-MOSSQuantum-AbstractQuantumState"></a>

### `MOSSQuantum.AbstractQuantumState`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

```julia
AbstractQuantumState
```

A quantum state accepted by the backend interface. A concrete state implements `nqubits`, `copy` and `backend`, plus the operations its backend advertises through `supports`. The representation may be dense, compressed, or implicit.

`storage` is an optional interface for dense representations. Implementing this abstract type does not require exposing a dense array or a `.data` field.

`copy(state)` must return a state whose mutable backing storage can be changed independently. Dense constructors additionally offer a `copy` keyword: `copy=true` guarantees independent storage, while `copy=false` allows reuse and can still allocate for type or layout conversions. Historical constructor defaults remain in effect; same-type `convert` can share storage. These constructor keywords are not required of external state representations.


<a id="api-MOSSQuantum-AbstractBackend"></a>

### `MOSSQuantum.AbstractBackend`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

```julia
AbstractBackend
```

An execution backend for quantum states. Extensions implement `backend(state)`, `supports(backend, operation, state; action=:apply)`, and the supported `apply!(backend, instruction, state)` or `expectation(backend, observable, state)` methods. An instruction method returns the resulting state; the legacy `QMeasure` and `QSelect` methods keep their measurement metadata return values.


<a id="api-MOSSQuantum-CPUBackend"></a>

### `MOSSQuantum.CPUBackend`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CPUBackend()
```

源码：[src/api/backend_protocols.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L13)

原生帮助：

The existing dense CPU implementation.


<a id="api-MOSSQuantum-backend"></a>

### `MOSSQuantum.backend`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
backend(state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector})
backend(state::AbstractQuantumState)
```

源码：[src/api/backend_protocols.jl:67](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L67) · [src/api/backend_protocols.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L44)

原生帮助：

```julia
backend(state) -> AbstractBackend
```

Return the default execution backend for a state. External state representations implement this method explicitly; there is no assumption about their storage.


<a id="api-MOSSQuantum-supports"></a>

### `MOSSQuantum.supports`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
supports(::CPUBackend, ::KrausTrajectory, state::AbstractQuantumState; action)
supports(::CPUBackend, ::DensityMatrixEvolution, state::AbstractQuantumState; action)
supports(::CPUBackend, circuit::QCircuit, state::AbstractQuantumState; action)
supports(::CPUBackend, operation, state::AbstractQuantumState; action)
supports(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState; action)
supports(::AbstractBackend, operation, ::AbstractQuantumState; action)
```

源码：[src/execution/noisy_execution.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L29) · [src/execution/noisy_execution.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L27) · [src/api/backend_protocols.jl:120](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L120) · [src/api/backend_protocols.jl:115](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L115) · [src/api/backend_protocols.jl:93](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L93) · [src/api/backend_protocols.jl:91](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L91)

原生帮助：

```julia
supports(backend, operation, state; action=:apply) -> Bool
```

Query whether a backend implements `:apply`, `:expectation`, or `:probabilities` for an operation and state. Readout support passes `probabilities` as the operation. Unknown capabilities return `false`. This query describes implemented capabilities; register bounds are checked separately by `validate_positions`.

The default circuit query requires support for every instruction. Backends whose instructions change the state representation must specialize that query to track those transitions. The CPU implementation tracks pure-to-mixed transitions.


<a id="api-MOSSQuantum-validate_backend_execution"></a>

### `MOSSQuantum.validate_backend_execution`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
validate_backend_execution(::AbstractBackend, circuit::QCircuit, ::AbstractQuantumState; mode)
```

源码：[src/api/backend_protocols.jl:109](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L109)

原生帮助：

```julia
validate_backend_execution(backend, circuit, state; mode=:apply)
```

Optional backend preflight for a circuit. The default rejects unbound parameter templates and otherwise performs no backend-specific checks; a backend may specialize it to reject unsupported input with a more specific diagnostic. It must not mutate the circuit, state, or RNG. `mode` is `:apply`, `:simulate`, or `:execute`, and the original circuit is supplied so that an extension can account for their different measurement and post-selection semantics. This hook supplements, rather than replaces, `supports` and position validation. Backend-specific circuit `apply!` implementations should call it themselves.


<a id="api-MOSSQuantum-UnsupportedOperation"></a>

### `MOSSQuantum.UnsupportedOperation`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
UnsupportedOperation(backend_type::Type, operation_type::Type, state_type::Type, action::Symbol)
UnsupportedOperation(b::AbstractBackend, operation, state::AbstractQuantumState, action::Symbol)
UnsupportedOperation(backend_type, operation_type, state_type, action)
```

源码：[src/api/backend_protocols.jl:24](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L24) · [src/api/backend_protocols.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L30)

原生帮助：

```julia
UnsupportedOperation
```

The requested backend does not implement an operation for this state and action. `action` identifies the requested API, such as `:apply`, `:expectation`, or `:probabilities`. The error records types rather than state data, so displaying it does not expand a large quantum state.


<a id="api-MOSSQuantum-CapabilityIssue"></a>

### `MOSSQuantum.CapabilityIssue`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CapabilityIssue(status::Symbol, path::Tuple, reason::String)
CapabilityIssue(status, path, reason)
```

源码：[src/api/execution_capability.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L3)

原生帮助：

A static capability finding. `path` identifies nested circuit indices and branches.


<a id="api-MOSSQuantum-CapabilityStep"></a>

### `MOSSQuantum.CapabilityStep`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CapabilityStep(status::Symbol; ...)
CapabilityStep(status::Symbol, state_types::Tuple; reason)
```

源码：[src/api/execution_capability.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L21)

原生帮助：

```julia
CapabilityStep(status, state_types=(); reason="")
```

A backend's static assessment of one instruction. `status` is `:supported`, `:unsupported`, or `:unknown`. A supported step must give every possible resulting state type, including representation changes; an unsupported or unknown step gives no state types. The assessment must not modify inputs or consume random numbers.


<a id="api-MOSSQuantum-ExecutionCapability"></a>

### `MOSSQuantum.ExecutionCapability`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExecutionCapability(status::Symbol, issues::Vector{CapabilityIssue}, final_state_types::Vector{Type})
ExecutionCapability(status, issues, final_state_types)
```

源码：[src/api/execution_capability.jl:73](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L73)

原生帮助：

Static assessment of a complete execution configuration.


<a id="api-MOSSQuantum-execution_capability"></a>

### `MOSSQuantum.execution_capability`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
execution_capability(program::NoisyCircuit, state::AbstractQuantumState; kwargs...)
execution_capability(b::AbstractBackend, program::NoisyCircuit, state::AbstractQuantumState; mode, noise_model, readout, kwargs...)
execution_capability(circuit::QCircuit, state::AbstractQuantumState; kwargs...)
execution_capability(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState; mode, method, qubits, readout, classical, noise_model, result, parallel, observable, grouping, atol, max_terms, shots)
```

源码：[src/api/execution_capability.jl:331](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L331) · [src/api/execution_capability.jl:318](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L318) · [src/api/execution_capability.jl:315](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L315) · [src/api/execution_capability.jl:160](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L160)

原生帮助：

```julia
execution_capability(backend, circuit, state; mode=:simulate, method=DensityMatrixEvolution(),
                     qubits=nothing, readout=ReadoutError[], classical=nothing,
                     noise_model=nothing, result=:full, parallel=false,
                     observable=nothing, grouping=:qwc, shots=nothing)
```

Statically inspect an execution request without evolving the state, expanding noise factories, or drawing random numbers. `qubits` is accepted only for `:execute`; `nothing` selects all qubits. `mode` is `:apply`, `:simulate`, `:execute`, or `:estimate`; the latter requires `observable`. The result status is `:supported`, `:unsupported`, or `:unknown`; `issues` includes nested instruction paths. A supported report concerns the capability and structural validity only: data-dependent properties such as state normalization and the probability of a post-selection are checked by execution.

External backends opt in by implementing `execution_capability_backend` and `execution_capability_step`. Reports are conservative if a backend or an option cannot be analyzed statically. Noise models with factories are not expanded by this query and are reported unknown; use an already expanded circuit to inspect its individual instructions.


<a id="api-MOSSQuantum-execution_capability_step"></a>

### `MOSSQuantum.execution_capability_step`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
execution_capability_step(::CPUBackend, op, ::Type{S}; mode, method) where S<:AbstractQuantumState
execution_capability_step(::AbstractBackend, instruction, ::Type{S}; mode, method) where S<:AbstractQuantumState
```

源码：[src/api/execution_capability.jl:60](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L60) · [src/api/execution_capability.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L40)

原生帮助：

```julia
execution_capability_step(backend, instruction, state_type; mode, method)
```

Extension hook for static capability analysis. Unknown backends return `:unknown` by default. Implementations must account for the selected execution mode and noise method, and return all possible output state types without executing the instruction. This hook supplements the existing `supports` and backend preflight protocols; it does not change them.


<a id="api-MOSSQuantum-execution_capability_backend"></a>

### `MOSSQuantum.execution_capability_backend`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
execution_capability_backend(::CPUBackend, state::AbstractQuantumState; mode, method)
execution_capability_backend(::AbstractBackend, ::AbstractQuantumState; mode, method)
```

源码：[src/api/execution_capability.jl:54](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L54) · [src/api/execution_capability.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/execution_capability.jl#L51)

原生帮助：

```julia
execution_capability_backend(backend, state; mode, method)
```

Backend extension hook for the selected state, mode and method. A supported result asserts that the backend implements the mode's required state, copying, measurement and terminal-readout protocols; instruction support is checked separately. Unknown backends must remain unknown, including for empty circuits.


<a id="api-MOSSQuantum-validate_terminal_sampling"></a>

### `MOSSQuantum.validate_terminal_sampling`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
validate_terminal_sampling(backend::AbstractBackend, state::AbstractQuantumState, qubits)
```

源码：[src/execution/shot_execution.jl:87](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L87)

原生帮助：

```julia
validate_terminal_sampling(backend, state, qubits)
```

Validate terminal sampling without consuming randomness or changing the state. Backends may specialize this independently of the sampler. The compatibility fallback validates the requested marginal with `probabilities`.


<a id="api-MOSSQuantum-prepare_terminal_sampling"></a>

### `MOSSQuantum.prepare_terminal_sampling`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
prepare_terminal_sampling(backend::AbstractBackend, state::AbstractQuantumState, qubits)
```

源码：[src/execution/shot_execution.jl:103](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L103)

原生帮助：

No documentation found for public binding `MOSSQuantum.prepare_terminal_sampling`.

`MOSSQuantum.prepare_terminal_sampling` is a `Function`.

```
# 1 method for generic function "prepare_terminal_sampling" from MOSSQuantum:
 [1] prepare_terminal_sampling(backend::AbstractBackend, state::AbstractQuantumState, qubits)
     @ ~/Code/Quantum/MOSSQuantum/src/execution/shot_execution.jl:103
```


<a id="api-MOSSQuantum-draw_terminal_samples"></a>

### `MOSSQuantum.draw_terminal_samples`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
draw_terminal_samples(rng::Random.AbstractRNG, sampler::MOSSQuantum._ProbabilityTerminalSampler, shots::Integer)
```

源码：[src/execution/shot_execution.jl:114](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L114)

原生帮助：

```julia
draw_terminal_samples(rng, sampler, shots)
```

Return a `shots × length(qubits)` matrix of computational-basis bits in the requested qubit order. Drawing does not change the source state. Backends implement this for sampler objects returned by `prepare_terminal_sampling`.


<a id="api-MOSSQuantum-probabilities"></a>

### `MOSSQuantum.probabilities`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
probabilities(state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; qubits)
probabilities(b::CPUBackend, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; qubits)
probabilities(b::AbstractBackend, state::AbstractQuantumState; qubits)
```

源码：[src/api/backend_protocols.jl:315](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L315) · [src/api/backend_protocols.jl:311](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L311) · [src/api/backend_protocols.jl:308](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/backend_protocols.jl#L308)

原生帮助：

No documentation found for public binding `MOSSQuantum.probabilities`.

`MOSSQuantum.probabilities` is a `Function`.

```
# 3 methods for generic function "probabilities" from MOSSQuantum:
 [1] probabilities(state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; qubits)
     @ ~/Code/Quantum/MOSSQuantum/src/api/backend_protocols.jl:315
 [2] probabilities(b::CPUBackend, state::Union{BatchDensityMatrix, BatchStateVector, DensityMatrix, StateVector}; qubits)
     @ ~/Code/Quantum/MOSSQuantum/src/api/backend_protocols.jl:311
 [3] probabilities(b::AbstractBackend, state::AbstractQuantumState; qubits)
     @ ~/Code/Quantum/MOSSQuantum/src/api/backend_protocols.jl:308
```


<a id="api-MOSSQuantum-sample"></a>

### `MOSSQuantum.sample`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
sample(circuit::Union{NoisyCircuit, QCircuit}, state::AbstractQuantumState, shots::Integer; rng, kwargs...)
sample(rng::Random.AbstractRNG, circuit::Union{NoisyCircuit, QCircuit}, state::AbstractQuantumState, shots::Integer; kwargs...)
sample(state, shots::Integer; rng, kwargs...)
sample(rng::Random.AbstractRNG, state::Union{BatchDensityMatrix, BatchStateVector}, shots::Integer; qubits, readout)
sample(rng::Random.AbstractRNG, state, shots::Integer; qubits, readout)
```

源码：[src/execution/shot_execution.jl:252](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L252) · [src/execution/shot_execution.jl:246](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L246) · [src/execution/probabilities.jl:158](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/probabilities.jl#L158) · [src/execution/probabilities.jl:138](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/probabilities.jl#L138) · [src/execution/probabilities.jl:130](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/probabilities.jl#L130)

原生帮助：

```julia
sample([rng], state, shots; qubits=1:nqubits(state))
```

Sample terminal readout without collapsing `state`. Rows are shots and columns follow `qubits` in the requested order. For a batch the third axis is the batch index. Reusing equally seeded RNGs reproduces draws in the same Julia environment.

Circuit-level samples; a batch returns a vector of accepted-shot matrices.


<a id="api-MOSSQuantum-counts"></a>

### `MOSSQuantum.counts`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
counts(circuit::Union{NoisyCircuit, QCircuit}, state::AbstractQuantumState, shots::Integer; rng, kwargs...)
counts(rng::Random.AbstractRNG, circuit::Union{NoisyCircuit, QCircuit}, state::AbstractQuantumState, shots::Integer; kwargs...)
counts(state, shots::Integer; rng, kwargs...)
counts(rng::Random.AbstractRNG, state, shots::Integer; kwargs...)
```

源码：[src/execution/shot_execution.jl:261](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L261) · [src/execution/shot_execution.jl:256](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L256) · [src/execution/probabilities.jl:181](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/probabilities.jl#L181) · [src/execution/probabilities.jl:175](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/probabilities.jl#L175)

原生帮助：

```julia
counts([rng], state, shots; qubits=1:nqubits(state))
```

Terminal-readout histogram. In each string the leftmost character is the first requested qubit. Batch input returns one histogram per batch element.

Circuit-level counts; failed post-selections are excluded from the histogram.


<a id="api-MOSSQuantum-simulate"></a>

### `MOSSQuantum.simulate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
simulate(program::NoisyCircuit, initial; noise_model, readout, kwargs...)
simulate(circuit::QCircuit, state::Union{BatchDensityMatrix, BatchStateVector}; backend, rng, noise_model, readout, method, classical)
simulate(circuit::QCircuit, state; backend, rng, noise_model, readout, method, classical)
```

源码：[src/execution/noisy_execution.jl:330](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L330) · [src/execution/simulation.jl:190](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L190) · [src/execution/simulation.jl:174](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L174)

原生帮助：

```julia
simulate(circuit, initial_state; backend=backend(initial_state), rng=Random.default_rng())
```

Execute a circuit on a copy of its initial state and retain measurement records. Type promotion can replace the state wrapper. This stochastic execution API does not define automatic derivatives; analytic circuit application remains available through `circuit * state` and `expectation`.


<a id="api-MOSSQuantum-SimulationResult"></a>

### `MOSSQuantum.SimulationResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
SimulationResult(state, records::Vector{MeasurementRecord})
SimulationResult(state::S, measurements::Vector{MeasurementRecord}, classical::ClassicalRegister) where S
```

源码：[src/execution/simulation.jl:26](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L26) · [src/execution/simulation.jl:22](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L22)

原生帮助：

Result of one circuit execution. `state` is the final state; `measurements` preserves intermediate outcomes in execution order, including nested circuits. Use `sample(result.state, shots)` for terminal sampling. Reexecute `simulate` from the initial state for independent intermediate-measurement trajectories.


<a id="api-MOSSQuantum-MeasurementRecord"></a>

### `MOSSQuantum.MeasurementRecord`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MeasurementRecord(position::Int64, outcome::Int64, probability::Float64, kind::Symbol, reported_outcome::Int64, key::Union{Nothing, Symbol})
MeasurementRecord(position, outcome, probability, kind, reported_outcome, key)
MeasurementRecord(position::Integer, outcome::Integer, probability::Real, kind::Symbol, reported::Integer)
MeasurementRecord(position::Integer, outcome::Integer, probability::Real, kind::Symbol)
```

源码：[src/execution/simulation.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L3) · [src/execution/simulation.jl:12](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L12) · [src/execution/simulation.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L10)

原生帮助：

One recorded measurement or post-selection, before any automatic reset.


<a id="api-MOSSQuantum-BatchSimulationResult"></a>

### `MOSSQuantum.BatchSimulationResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BatchSimulationResult(state, records::Vector{Vector{MeasurementRecord}})
BatchSimulationResult(state::S, measurements::Vector{Vector{MeasurementRecord}}, classical::Vector{ClassicalRegister}) where S<:Union{BatchDensityMatrix, BatchStateVector}
```

源码：[src/execution/simulation.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L39) · [src/execution/simulation.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/simulation.jl#L35)

原生帮助：

Result of a batch circuit execution. `state` contains one final pure or mixed state per sample, and `measurements[column]` contains that sample's intermediate records in execution order, including nested circuits. Random draws are made in circuit instruction order and then batch column order. An empty batch has no records.


<a id="api-MOSSQuantum-execute"></a>

### `MOSSQuantum.execute`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
execute(plan::ExecutionPlan, values::AbstractVector{<:Real}; kwargs...)
execute(plan::ExecutionPlan; ...)
execute(bound::BoundExecutionPlan; shots, rng, result, parallel, chunk_size, workspace, budget)
execute(program::NoisyCircuit, initial::AbstractQuantumState; noise_model, readout, kwargs...)
execute(circuit::QCircuit, initial_state::Union{BatchDensityMatrix, BatchStateVector}; shots, qubits, rng, backend, noise_model, readout, method, result, parallel, chunk_size, classical)
execute(circuit::QCircuit, initial_state::AbstractQuantumState; shots, qubits, rng, backend, noise_model, readout, method, result, parallel, chunk_size, classical)
```

源码：[src/execution/execution_plans.jl:240](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L240) · [src/execution/execution_plans.jl:223](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L223) · [src/execution/noisy_execution.jl:308](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L308) · [src/execution/shot_execution.jl:226](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L226) · [src/execution/shot_execution.jl:181](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L181)

原生帮助：

```julia
execute(circuit, initial_state; shots, qubits=1:nqubits(initial_state), rng, backend)
```

Run a circuit for a fixed number of attempted shots without modifying its input. Each shot replays intermediate measurements from a fresh state. `QSelect` is a physical measurement and rejection: failed attempts consume a shot and contribute no terminal sample. This differs from `simulate`'s forced conditional selection. Measurement auto-reset behavior is taken from each `QMeasure` instruction.

For deterministic gate/Kraus circuits, evolve once and sample the final distribution. For batches, return one `ShotResult` per member, with the full `shots` budget for each member and a shared RNG consumed in member order. This API has no automatic differentiation contract.


<a id="api-MOSSQuantum-ShotResult"></a>

### `MOSSQuantum.ShotResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ShotResult(shots, qubits, samples, counts, records, accepted)
ShotResult(shots::Int64, qubits::Vector{Int64}, samples::Matrix{Int64}, counts::Dict{String, Int64}, measurements::Vector{Vector{MeasurementRecord}}, accepted::BitVector, classical::Vector{ClassicalRegister})
ShotResult(shots, qubits, samples, counts, measurements, accepted, classical)
```

源码：[src/execution/shot_execution.jl:20](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L20) · [src/execution/shot_execution.jl:12](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_execution.jl#L12)

原生帮助：

```julia
ShotResult
```

Result of `execute`. `shots` is the number of attempted circuit executions. `accepted` has one entry per attempt; `measurements` records every attempt, including the first failed post-selection. Rows of `samples` correspond to `findall(accepted)`, and columns follow `qubits`. `counts` contains accepted terminal outcomes only, so its total is `count(accepted)`, not necessarily `shots`. No final state is retained for each shot.


<a id="api-MOSSQuantum-measurement_plan"></a>

### `MOSSQuantum.measurement_plan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
measurement_plan(observable::Union{QubitsOperator, QubitsTerm}; grouping, atol, max_terms)
```

源码：[src/observables/shot_estimation.jl:149](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L149)

原生帮助：

```julia
measurement_plan(observable; grouping=:qwc, atol=0, max_terms=100_000)
```

Expand a `QubitsTerm` or `QubitsOperator` into Pauli words, combine duplicate words, and group them for finite-shot measurement. Arbitrary local 2×2 matrices are expanded into I/X/Y/Z without building a full-register matrix. The resulting observable must be Hermitian (all combined Pauli coefficients real).

`:qwc` deterministically groups qubit-wise commuting words, which can share single-qubit basis rotations; `:none` measures each nonconstant word separately. The greedy grouping is not guaranteed minimal. `atol` is an explicit absolute coefficient tolerance: coefficients of magnitude at most `atol` are discarded and imaginary components of magnitude at most `atol` are accepted as roundoff. The default discards only exact zeros. Local expansion may grow exponentially; `max_terms` bounds both intermediate and combined word counts and never silently truncates an observable.


<a id="api-MOSSQuantum-estimate"></a>

### `MOSSQuantum.estimate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
estimate(plan::MeasurementPlan, state::Union{BatchDensityMatrix, BatchStateVector}; shots, rng, backend, readout)
estimate(plan::MeasurementPlan, state::AbstractQuantumState; shots, rng, backend, readout)
estimate(plan::MeasurementPlan, circuit::QCircuit, initial_state::Union{BatchDensityMatrix, BatchStateVector}; shots, rng, backend, noise_model, readout, method, parallel, chunk_size, classical)
estimate(plan::MeasurementPlan, circuit::QCircuit, initial_state::AbstractQuantumState; shots, rng, backend, noise_model, readout, method, parallel, chunk_size, classical)
estimate(plan::EstimationPlan, values::AbstractVector{<:Real}; kwargs...)
estimate(plan::EstimationPlan; ...)
estimate(bound::BoundEstimationPlan; shots, rng, allocation, budget, parallel, chunk_size)
estimate(objective::ShotExpectationObjective, values::AbstractVector{<:Real}; rng, budget)
estimate(observable::Union{QubitsOperator, QubitsTerm}, state::AbstractQuantumState; shots, rng, grouping, atol, max_terms, backend, readout)
estimate(observable::Union{QubitsOperator, QubitsTerm}, circuit::QCircuit, initial_state::AbstractQuantumState; shots, rng, grouping, atol, max_terms, backend, noise_model, readout, method, parallel, chunk_size, classical)
estimate(observable, program::NoisyCircuit, initial::AbstractQuantumState; noise_model, readout, kwargs...)
```

源码：[src/observables/shot_estimation.jl:296](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L296) · [src/observables/shot_estimation.jl:276](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L276) · [src/observables/circuit_estimation.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/circuit_estimation.jl#L65) · [src/observables/circuit_estimation.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/circuit_estimation.jl#L36) · [src/observables/estimation_plans.jl:136](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L136) · [src/observables/estimation_plans.jl:117](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L117) · [src/differentiation/sampled_gradients.jl:97](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L97) · [src/observables/shot_estimation.jl:268](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L268) · [src/observables/circuit_estimation.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/circuit_estimation.jl#L17) · [src/observables/circuit_estimation.jl:82](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/circuit_estimation.jl#L82)

原生帮助：

```julia
estimate(observable, state; shots, rng=Random.default_rng(), grouping=:qwc,
         atol=0, max_terms=100_000, backend=backend(state))
estimate(plan::MeasurementPlan, state; shots, rng=Random.default_rng(),
         backend=backend(state))
```

Estimate a Hermitian observable by actual finite-shot Pauli measurements. `shots` is the total budget across measurement groups, allocated as evenly as possible; earlier groups receive the remainder. Each nonconstant group requires at least two shots. Constant and zero observables consume none. Input states must be normalized. Inputs and reusable plans are not mutated.

Each group rotates an independent copy of the state into its measurement bases and samples computational-basis outcomes. Error estimates include within-group covariance. This is a statistical estimator, with no automatic differentiation contract; `expectation` remains the exact deterministic operation.

For a batch, return one `ExpectationEstimate` per member, using `shots` as the budget **per member** and consuming the supplied RNG in batch-column order.

```julia
estimate(observable, circuit, initial_state; shots, rng, grouping=:qwc, backend)
estimate(plan::MeasurementPlan, circuit, initial_state; shots, rng, backend)
```

Estimate the output observable of a circuit with a total finite-shot budget. Deterministic gate/Kraus circuits prepare a state once, then reuse independent copies for measurement groups. Circuits with intermediate `QMeasure` instructions replay those measurements for every shot in every group; sampling a single collapsed trajectory is not substituted for independent circuit executions.

`QSelect` is not supported by this estimator: attempted and accepted measurement budgets differ. Use `execute` to inspect post-selection acceptance explicitly, or estimate a separately prepared normalized conditional state. For batches, the budget is per member. Like the state estimator, this operation is stochastic and has no automatic differentiation contract.


<a id="api-MOSSQuantum-MeasurementPlan"></a>

### `MOSSQuantum.MeasurementPlan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MeasurementPlan(constant::Float64, groups::Vector{MeasurementGroup}, grouping::Symbol, nqubits::Int64)
MeasurementPlan(constant, groups, grouping, nqubits)
```

源码：[src/observables/shot_estimation.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L25)

原生帮助：

```julia
MeasurementPlan
```

A reusable Pauli measurement plan constructed by `measurement_plan`. `constant` is evaluated without shots; `groups` contains the measured terms. `nqubits` is the minimum register size required by the input observable. Planning and statistics use Float64 coefficients. Treat the arrays in a plan as read-only; planning owns its metadata independently of the observable.


<a id="api-MOSSQuantum-MeasurementGroup"></a>

### `MOSSQuantum.MeasurementGroup`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MeasurementGroup(qubits::Vector{Int64}, bases::Vector{Symbol}, terms::Vector{PauliMeasurementTerm})
MeasurementGroup(qubits, bases, terms)
```

源码：[src/observables/shot_estimation.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L10)

原生帮助：

Terms measured together in the single-qubit bases listed by `qubits`.


<a id="api-MOSSQuantum-PauliMeasurementTerm"></a>

### `MOSSQuantum.PauliMeasurementTerm`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
PauliMeasurementTerm(positions::Vector{Int64}, bases::Vector{Symbol}, coefficient::Float64)
PauliMeasurementTerm(positions, bases, coefficient)
```

源码：[src/observables/shot_estimation.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L3)

原生帮助：

One real coefficient times a Pauli word in a measurement plan.


<a id="api-MOSSQuantum-ExpectationEstimate"></a>

### `MOSSQuantum.ExpectationEstimate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExpectationEstimate(value::Float64, variance::Float64, stderr::Float64, shots::Int64, requested_shots::Int64, groups::Vector{GroupEstimate})
ExpectationEstimate(value, variance, stderr, shots, requested_shots, groups)
```

源码：[src/observables/shot_estimation.jl:58](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L58)

原生帮助：

```julia
ExpectationEstimate
```

Finite-shot expectation result. `value` estimates the observable expectation; `variance` estimates the variance of that mean, and `stderr = sqrt(variance)`. `shots` counts actual measurements, while `requested_shots` records the total budget. A constant or zero observable consumes zero shots. `groups` records the allocated shots, basis and statistics for each independent group.

The error estimate is a sampling standard error, not a deterministic bound or a confidence interval. In particular, a finite sample can have zero empirical variance even when the underlying distribution is not deterministic.


<a id="api-MOSSQuantum-GroupEstimate"></a>

### `MOSSQuantum.GroupEstimate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
GroupEstimate(group::MeasurementGroup, shots::Int64, value::Float64, sample_variance::Float64)
GroupEstimate(group, shots, value, sample_variance)
```

源码：[src/observables/shot_estimation.jl:38](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/shot_estimation.jl#L38)

原生帮助：

Statistics for one measurement group. `sample_variance` is the unbiased sample variance of the group's combined per-shot energy, including covariance between terms measured in the same shot. Its contribution to the variance of the estimated mean is `sample_variance / shots`.


<a id="api-MOSSQuantum-bind_parameters"></a>

### `MOSSQuantum.bind_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
bind_parameters(program::NoisyCircuit, values; kwargs...)
bind_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}, assignments::AbstractDict)
bind_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}, values::AbstractVector{<:Real})
bind_parameters(template::AbstractInstruction, assignments::AbstractDict)
bind_parameters(template::AbstractInstruction, values::AbstractVector{<:Real}, map::AbstractParameterMap)
bind_parameters(circuit::QCircuit, values::AbstractVector{<:Real}; parameter_order)
bind_parameters(instruction::AbstractInstruction, values::AbstractVector{<:Real}; parameter_order)
```

源码：[src/execution/noise_models.jl:116](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L116) · [src/api/symbolic_parameters.jl:324](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L324) · [src/api/symbolic_parameters.jl:321](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L321) · [src/api/symbolic_parameters.jl:317](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L317) · [src/api/parameter_binding.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_binding.jl#L57) · [src/api/parameter_binding.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_binding.jl#L29) · [src/api/parameter_binding.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_binding.jl#L19)

原生帮助：

```julia
bind_parameters(instruction::AbstractInstruction, values::AbstractVector{<:Real})
```

Return an independent instruction with its active parameters replaced by `values` in `active_parameters(instruction)` order. Frozen parameters retain their values. The default uses the public `copy_instruction` and `reset_parameters!` hooks; writers may return a replacement instruction, including an immutable one.

For circuits, nested instructions are visited in execution order and each occurrence is bound separately. Repeated source references become independent parameter slots rather than symbolic shared parameters. Parameterless instructions are copied as well. The source instruction and parameter vector are not modified. Values must be finite and match `nparameters(instruction)`.

```julia
bind_parameters(template::AbstractInstruction, values::AbstractVector{<:Real}, map::ParameterMap)
```

Bind independent `values` through an explicit active-slot map. For example, `ParameterMap([1, 2, 1])` binds `[θ, φ]` to the slots `[θ, φ, θ]`. The map must match `nparameters(template)` slots, and values must be finite and have length `nparameters(map)`. Frozen parameters retain their values.

The result owns independent mutable storage for every instruction occurrence, including occurrences assigned the same value. The map is separate metadata; the returned instruction does not retain it. Keep the map alongside the template for future binding and gradient accumulation. Rebuild or review it after changing the template's active-slot layout.

Bind the quantum template and retain an independent readout configuration.


<a id="api-MOSSQuantum-copy_instruction"></a>

### `MOSSQuantum.copy_instruction`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
copy_instruction(x::Conditional)
copy_instruction(x::QCircuit)
copy_instruction(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
copy_instruction(x::AdjointQuantumGate)
copy_instruction(instruction::AbstractInstruction)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:86](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L86) · [src/quantum_circuits/circuits/circuit.jl:286](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/circuit.jl#L286) · [src/quantum_circuits/parameters/instructions.jl:31](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L31) · [src/quantum_circuits/gates/parametric_gates.jl:54](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/gates/parametric_gates.jl#L54) · [src/quantum_circuits/instructions.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/instructions.jl#L35)

原生帮助：

```julia
copy_instruction(instruction::AbstractInstruction)
```

Return an independently mutable copy of an instruction. The default is `deepcopy`; extensions may specialize this hook for their own resource or storage ownership. Circuit copies visit each instruction occurrence separately, including repeated references and nested circuits. This differs from the shallow `copy(circuit)` container operation.


<a id="api-MOSSQuantum-Parameter"></a>

### `MOSSQuantum.Parameter`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Parameter(name::Union{AbstractString, Symbol})
```

源码：[src/quantum_circuits/parameters/expressions.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/expressions.jl#L5)

原生帮助：

A named variable with an immutable identity, independent of its display name.


<a id="api-MOSSQuantum-ParameterExpr"></a>

### `MOSSQuantum.ParameterExpr`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ParameterExpr(p::Parameter)
ParameterExpr(e::ParameterExpr)
ParameterExpr(value::Real)
ParameterExpr(terms::Tuple, constant::Real)
```

源码：[src/quantum_circuits/parameters/expressions.jl:69](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/expressions.jl#L69) · [src/quantum_circuits/parameters/expressions.jl:70](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/expressions.jl#L70) · [src/quantum_circuits/parameters/expressions.jl:68](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/expressions.jl#L68) · [src/quantum_circuits/parameters/expressions.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/expressions.jl#L41)

原生帮助：

An immutable real affine expression `constant + sum(coefficient * parameter)`.


<a id="api-MOSSQuantum-parameterize"></a>

### `MOSSQuantum.parameterize`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameterize(prototype::Gate, expression::Union{Parameter, ParameterExpr})
parameterize(prototype::Gate, expressions::Union{Tuple, AbstractVector})
```

源码：[src/quantum_circuits/parameters/instructions.jl:26](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L26) · [src/quantum_circuits/parameters/instructions.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L25)

原生帮助：

Name a gate's current active slots without modifying its numeric prototype.


<a id="api-MOSSQuantum-materialize_parameters"></a>

### `MOSSQuantum.materialize_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
materialize_parameters(prototype::Gate, values::AbstractVector{<:Real}, active_mask::AbstractVector{Bool})
```

源码：[src/quantum_circuits/parameters/instructions.jl:195](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L195)

原生帮助：

```julia
materialize_parameters(prototype, values, active_mask)
```

Bind the prototype's original active slots, retaining only the requested active slots. Frozen original values are preserved. Extensions may override this hook when their public activity writers cannot express the requested mask.


<a id="api-MOSSQuantum-parameter_slots"></a>

### `MOSSQuantum.parameter_slots`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_slots(x::MOSSQuantum.QuantumCircuits.ParameterizedInstruction)
parameter_slots(x::AdjointQuantumGate)
parameter_slots(x::Gate)
parameter_slots(x::AbstractInstruction)
```

源码：[src/quantum_circuits/parameters/instructions.jl:77](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L77) · [src/quantum_circuits/parameters/instructions.jl:76](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L76) · [src/quantum_circuits/parameters/instructions.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L65) · [src/quantum_circuits/parameters/instructions.jl:57](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L57)

原生帮助：

```julia
parameter_slots(instruction) -> Tuple
```

Return stable local keys for the instruction's current active parameters, in `active_parameters` order. Keys identify physical slots even when another slot is frozen. Built-in gates use their complete numerical parameter indices.

An extension may return distinct `Int` or `Symbol` keys. The default supports parameterless instructions and instructions whose complete parameter vector is fully active. Partially active extensions without the built-in activity mask must implement this hook to participate in named or mixed compilation. Existing pure numerical parameter writers do not require this hook.


<a id="api-MOSSQuantum-UnboundParameterError"></a>

### `MOSSQuantum.UnboundParameterError`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
UnboundParameterError(path::Tuple, parameters::Tuple)
UnboundParameterError(path, parameters)
```

源码：[src/quantum_circuits/parameters/instructions.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L3)

原生帮助：

An operation still needs named parameter binding before numerical use.


<a id="api-MOSSQuantum-parameter_info"></a>

### `MOSSQuantum.parameter_info`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_info(map::ParameterMap)
parameter_info(objective::ShotExpectationObjective)
parameter_info(plan::EstimationPlan)
parameter_info(plan::ExecutionPlan)
parameter_info(objective::Union{BatchExpectationObjective, ExpectationObjective})
parameter_info(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}})
parameter_info(map::MOSSQuantum.AffineParameterMap)
```

源码：[src/api/parameter_initialization.jl:119](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L119) · [src/differentiation/sampled_gradients.jl:94](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L94) · [src/observables/estimation_plans.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L36) · [src/execution/execution_plans.jl:203](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L203) · [src/api/objectives.jl:246](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L246) · [src/api/parameter_initialization.jl:120](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L120) · [src/api/parameter_initialization.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L27)

原生帮助：

```julia
parameter_info(compiled_or_map)
```

Return an independent tuple of parameter descriptions in original registration order. Each entry records its identity, display label, captured initial value (`missing` when unavailable), source slots, fixed value (`nothing` when trainable), and current input index (`nothing` when fixed). Anonymous labels are for display only; use the returned `parameter` handle for dictionary keys.

An integer `ParameterMap` alone has no template from which to recover initial values or source slots. Query its compiled context to include that information.


<a id="api-MOSSQuantum-initial_parameters"></a>

### `MOSSQuantum.initial_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
initial_parameters(map::ParameterMap; values)
initial_parameters(objective::ShotExpectationObjective; kwargs...)
initial_parameters(plan::EstimationPlan; kwargs...)
initial_parameters(plan::ExecutionPlan; kwargs...)
initial_parameters(objective::Union{BatchExpectationObjective, ExpectationObjective}; kwargs...)
initial_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}; values)
initial_parameters(map::MOSSQuantum.AffineParameterMap; values)
```

源码：[src/api/parameter_initialization.jl:218](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L218) · [src/differentiation/sampled_gradients.jl:95](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L95) · [src/observables/estimation_plans.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L37) · [src/execution/execution_plans.jl:204](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L204) · [src/api/objectives.jl:248](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L248) · [src/api/parameter_initialization.jl:222](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L222) · [src/api/parameter_initialization.jl:214](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_initialization.jl#L214)

原生帮助：

```julia
initial_parameters(compiled_or_map; values=Dict())
```

Build the complete finite real input vector in current `parameter_order`. Anonymous parameters use the numerical values captured at construction; named parameters need explicit values. Overrides use Parameter handles or unique explicit names, without mixing the two key forms. Anonymous display labels are not name aliases. Already fixed variables cannot receive training initial values.

For integer maps, override keys are integer IDs. Shared numerical slots provide a default only when every occurrence has exactly the same finite initial value. This helper never samples, binds instructions, or stores optimizer updates.


<a id="api-MOSSQuantum-parameter_expressions"></a>

### `MOSSQuantum.parameter_expressions`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_expressions(program::NoisyCircuit)
parameter_expressions(x::AbstractInstruction)
```

源码：[src/execution/noise_models.jl:120](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L120) · [src/quantum_circuits/parameters/instructions.jl:116](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L116)

原生帮助：

Return every symbolic expression slot, including constants, in occurrence order.


<a id="api-MOSSQuantum-independent_parameters"></a>

### `MOSSQuantum.independent_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
independent_parameters(program::NoisyCircuit)
independent_parameters(map::ParameterMap)
independent_parameters(map::MOSSQuantum.AffineParameterMap)
independent_parameters(objective::ShotExpectationObjective)
independent_parameters(plan::EstimationPlan)
independent_parameters(x::AbstractInstruction)
independent_parameters(plan::ExecutionPlan)
independent_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}})
independent_parameters(objective::Union{BatchExpectationObjective, ExpectationObjective})
```

源码：[src/execution/noise_models.jl:119](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L119) · [src/api/parameter_map.jl:73](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L73) · [src/api/symbolic_parameters.jl:16](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L16) · [src/differentiation/sampled_gradients.jl:93](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L93) · [src/observables/estimation_plans.jl:35](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L35) · [src/quantum_circuits/parameters/instructions.jl:135](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L135) · [src/execution/execution_plans.jl:202](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L202) · [src/api/symbolic_parameters.jl:274](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L274) · [src/api/objectives.jl:99](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L99)

原生帮助：

Return named free variables in deterministic first-occurrence order. Compile a template that mixes named variables and anonymous active numerical slots first; its compiled context also identifies the anonymous independent parameters.


<a id="api-MOSSQuantum-trainable_parameters"></a>

### `MOSSQuantum.trainable_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
trainable_parameters(map::ParameterMap)
trainable_parameters(objective::ShotExpectationObjective)
trainable_parameters(plan::EstimationPlan)
trainable_parameters(plan::ExecutionPlan)
trainable_parameters(objective::Union{BatchExpectationObjective, ExpectationObjective})
trainable_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}})
trainable_parameters(map::MOSSQuantum.AffineParameterMap)
```

源码：[src/api/parameter_map.jl:74](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L74) · [src/differentiation/sampled_gradients.jl:92](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L92) · [src/observables/estimation_plans.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L34) · [src/execution/execution_plans.jl:201](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L201) · [src/api/objectives.jl:100](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L100) · [src/api/symbolic_parameters.jl:275](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L275) · [src/api/symbolic_parameters.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L17)

原生帮助：

No documentation found for public binding `MOSSQuantum.QuantumCircuits.trainable_parameters`.

`MOSSQuantum.QuantumCircuits.trainable_parameters` is a `Function`.

```
# 7 methods for generic function "trainable_parameters" from MOSSQuantum.QuantumCircuits:
 [1] trainable_parameters(map::ParameterMap)
     @ ~/Code/Quantum/MOSSQuantum/src/api/parameter_map.jl:74
 [2] trainable_parameters(objective::ShotExpectationObjective)
     @ ~/Code/Quantum/MOSSQuantum/src/differentiation/sampled_gradients.jl:92
 [3] trainable_parameters(plan::EstimationPlan)
     @ ~/Code/Quantum/MOSSQuantum/src/observables/estimation_plans.jl:34
 [4] trainable_parameters(plan::ExecutionPlan)
     @ ~/Code/Quantum/MOSSQuantum/src/execution/execution_plans.jl:201
 [5] trainable_parameters(objective::Union{BatchExpectationObjective, ExpectationObjective})
     @ ~/Code/Quantum/MOSSQuantum/src/api/objectives.jl:100
 [6] trainable_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}})
     @ ~/Code/Quantum/MOSSQuantum/src/api/symbolic_parameters.jl:275
 [7] trainable_parameters(map::MOSSQuantum.AffineParameterMap)
     @ ~/Code/Quantum/MOSSQuantum/src/api/symbolic_parameters.jl:17
```


<a id="api-MOSSQuantum-parameter_order"></a>

### `MOSSQuantum.parameter_order`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_order(map::ParameterMap)
parameter_order(map::MOSSQuantum.AffineParameterMap)
parameter_order(objective::ShotExpectationObjective)
parameter_order(plan::EstimationPlan)
parameter_order(x::AbstractInstruction)
parameter_order(plan::ExecutionPlan)
parameter_order(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}})
parameter_order(objective::Union{BatchExpectationObjective, ExpectationObjective})
```

源码：[src/api/parameter_map.jl:72](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L72) · [src/api/symbolic_parameters.jl:15](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L15) · [src/differentiation/sampled_gradients.jl:91](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L91) · [src/observables/estimation_plans.jl:33](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L33) · [src/quantum_circuits/parameters/instructions.jl:140](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L140) · [src/execution/execution_plans.jl:200](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L200) · [src/api/symbolic_parameters.jl:273](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L273) · [src/api/objectives.jl:98](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L98)

原生帮助：

Return independent input IDs in vector-binding order.


<a id="api-MOSSQuantum-substitute_parameters"></a>

### `MOSSQuantum.substitute_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
substitute_parameters(program::NoisyCircuit, replacements)
substitute_parameters(x::AbstractInstruction, replacements::AbstractDict)
```

源码：[src/execution/noise_models.jl:121](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L121) · [src/quantum_circuits/parameters/instructions.jl:183](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/parameters/instructions.jl#L183)

原生帮助：

Simultaneously replace a subset of named variables by values or affine expressions.


<a id="api-MOSSQuantum-AbstractParameterMap"></a>

### `MOSSQuantum.AbstractParameterMap`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

A parameter map expands independent inputs into active instruction slots.


<a id="api-MOSSQuantum-ParameterMap"></a>

### `MOSSQuantum.ParameterMap`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ParameterMap(template::AbstractInstruction, indices)
ParameterMap(template::AbstractInstruction)
ParameterMap(indices::Union{Tuple{Vararg{Integer}}, AbstractVector{<:Integer}})
ParameterMap(indices::Union{Tuple, AbstractVector})
```

源码：[src/api/parameter_map.jl:55](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L55) · [src/api/parameter_map.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L51) · [src/api/parameter_map.jl:28](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L28) · [src/api/parameter_map.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L41)

原生帮助：

```julia
ParameterMap(indices)
ParameterMap(template::AbstractInstruction)
ParameterMap(template::AbstractInstruction, indices)
```

Map each active parameter slot, in `active_parameters(template)` order, to an independent parameter index. Indices must use every integer in `1:k`; repeated indices explicitly share a value. For example, `[1, 2, 1]` maps three slots to two independent values. An empty map has no slots or independent values.

The map is an immutable snapshot of its indices. `length(map)` counts slots and `nparameters(map)` counts independent values. `parameter_indices(map)` returns an independent vector. `ParameterMap(template)` creates an identity map; the two-argument constructor also checks the current number of active slots.

Maps are separate from circuits and do not imply shared mutable gate storage. After changing instruction order or activation, rebuild or review the map. Binding detects slot-count mismatches, but cannot detect a changed layout with the same number of slots.


<a id="api-MOSSQuantum-parameter_indices"></a>

### `MOSSQuantum.parameter_indices`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_indices(map::ParameterMap)
```

源码：[src/api/parameter_map.jl:69](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L69)

原生帮助：

```julia
parameter_indices(map::ParameterMap) -> Vector{Int}
```

Return an independent vector of the parameter identity for each active slot. Changing this vector does not change `map`.


<a id="api-MOSSQuantum-expand_parameters"></a>

### `MOSSQuantum.expand_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
expand_parameters(map::MOSSQuantum.AffineParameterMap, values::AbstractVector{<:Real})
expand_parameters(map::ParameterMap, values::AbstractVector{<:Real})
```

源码：[src/api/symbolic_parameters.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L27) · [src/api/parameter_map.jl:84](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L84)

原生帮助：

```julia
expand_parameters(map::AbstractParameterMap, values)
```

Expand independent inputs into active gate-slot order. Integer maps gather shared inputs; compiled affine maps also apply coefficients and offsets.


<a id="api-MOSSQuantum-accumulate_parameter_gradients"></a>

### `MOSSQuantum.accumulate_parameter_gradients`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
accumulate_parameter_gradients(map::MOSSQuantum.AffineParameterMap, gradients::AbstractVector{<:Real})
accumulate_parameter_gradients(map::ParameterMap, slot_gradients::AbstractVector{<:Real})
```

源码：[src/api/symbolic_parameters.jl:44](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L44) · [src/api/parameter_map.jl:102](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/parameter_map.jl#L102)

原生帮助：

```julia
accumulate_parameter_gradients(map::ParameterMap, slot_gradients::AbstractVector{<:Real})
```

Sum active-slot gradients into independent-parameter order. Each slot contributes to the identity given by `parameter_indices(map)`. The input must contain `length(map)` entries; the result has `nparameters(map)` entries. Neither input is modified. Nonfinite gradients propagate through the sums.

This reduction is independent of an AD framework or simulator backend. It does not establish derivative support for an instruction or backend by itself.


<a id="api-MOSSQuantum-compile_parameters"></a>

### `MOSSQuantum.compile_parameters`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
compile_parameters(context::NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}; parameter_order, fixed, parameter_map)
compile_parameters(template::AbstractInstruction; parameter_order, fixed, parameter_map)
```

源码：[src/api/symbolic_parameters.jl:252](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L252) · [src/api/symbolic_parameters.jl:236](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/symbolic_parameters.jl#L236)

原生帮助：

```julia
compile_parameters(template_or_context; parameter_order=nothing, fixed=nothing, parameter_map=nothing)
```

Own a reusable template snapshot and input-to-slot map. Named expressions and anonymous numerical active slots share a single affine input order. Plain numeric templates keep their integer map. Reuse the returned context to retain anonymous identities, reorder all handles, or append fixed variables. Compilation does not evaluate placeholder matrices or draw from the user's RNG.


<a id="api-MOSSQuantum-AbstractGradientMethod"></a>

### `MOSSQuantum.AbstractGradientMethod`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。

原生帮助：

```julia
AbstractGradientMethod
```

A replaceable numerical differentiation strategy. Execution is a separate `evaluate(objective, values)` operation. External objectives need not subtype a MOSSQuantum type or expose quantum states, and external strategies implement public `supports_gradient` and `value_and_gradient` methods. A strategy may additionally specialize `value_and_pullback` to reuse a forward execution.

The current interface differentiates real scalar objectives with respect to an explicit real parameter vector. It does not prescribe an AD framework, backend, or a particular gradient algorithm.


<a id="api-MOSSQuantum-AdjointGradient"></a>

### `MOSSQuantum.AdjointGradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
AdjointGradient()
```

源码：[src/api/gradient_methods.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L17)

原生帮助：

The existing deterministic dense CPU circuit reverse pass.


<a id="api-MOSSQuantum-UnsupportedGradient"></a>

### `MOSSQuantum.UnsupportedGradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
UnsupportedGradient(method_type::Type, objective_type::Type)
UnsupportedGradient(method::AbstractGradientMethod, objective)
UnsupportedGradient(method_type, objective_type)
```

源码：[src/api/gradient_methods.jl:21](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L21) · [src/api/gradient_methods.jl:24](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L24)

原生帮助：

A gradient strategy does not support this objective.


<a id="api-MOSSQuantum-ExpectationObjective"></a>

### `MOSSQuantum.ExpectationObjective`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExpectationObjective(template::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, observable, initial_state::AbstractQuantumState; parameter_map, parameter_order, fixed, backend)
```

源码：[src/api/objectives.jl:22](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L22)

原生帮助：

```julia
ExpectationObjective(template, observable, initial_state;
                     parameter_map=ParameterMap(template), backend=backend(initial_state))
```

A scalar objective evaluating the real part of an observable's expectation after executing a bound circuit. The parameter map defines the independent input order. Construction snapshots the instruction tree, observable, and initial state; the backend is retained as an execution resource. Evaluation copies the initial state and never modifies the template or input values.

This is an adapter for MOSSQuantum state/backends, not a required base type for external objectives. It carries no gradient method. `AdjointGradient` has narrower capabilities than forward evaluation, reported by `supports_gradient`.


<a id="api-MOSSQuantum-BatchExpectationObjective"></a>

### `MOSSQuantum.BatchExpectationObjective`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BatchExpectationObjective(template::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, observable, initial_state::Union{BatchDensityMatrix, BatchStateVector}; parameter_map, parameter_order, fixed, backend, reduction, weights)
```

源码：[src/api/objectives.jl:68](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L68)

原生帮助：

```julia
BatchExpectationObjective(template, observable, initial_state;
                          parameter_map=ParameterMap(template),
                          backend=backend(initial_state), reduction=:mean, weights=nothing)
```

A real scalar objective for a nonempty `BatchStateVector` or `BatchDensityMatrix` sharing one circuit, parameter vector, and observable. The last axis indexes samples. `evaluate_batch` returns the real expectation for each sample in input order; `evaluate` reduces these values using `:mean` (default), `:sum`, or `:weighted_sum`.

`:weighted_sum` requires a finite real weight for every sample. Weights may be negative and are not normalized. Other reductions reject `weights`. Construction snapshots the circuit, observable, states, and weights; the backend remains an execution resource. Forward execution does not select a gradient method.


<a id="api-MOSSQuantum-evaluate_batch"></a>

### `MOSSQuantum.evaluate_batch`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
evaluate_batch(objective::BatchExpectationObjective, values::AbstractVector{<:Real})
```

源码：[src/api/objectives.jl:215](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L215)

原生帮助：

```julia
evaluate_batch(objective::BatchExpectationObjective, values) -> AbstractVector{<:Real}
```

Execute a shared bound circuit and return one real expectation per sample, without reducing the sample axis or invoking a gradient method. Neither the initial batch nor the caller's parameter vector is modified.


<a id="api-MOSSQuantum-evaluate"></a>

### `MOSSQuantum.evaluate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
evaluate(objective::ShotExpectationObjective, values::AbstractVector{<:Real}; rng, budget)
evaluate(objective::BatchExpectationObjective, values::AbstractVector{<:Real})
evaluate(objective::ExpectationObjective, values::AbstractVector{<:Real})
evaluate(objective::Function, values::AbstractVector{<:Real})
evaluate(objective, values::AbstractVector{<:Real})
```

源码：[src/differentiation/sampled_gradients.jl:108](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L108) · [src/api/objectives.jl:237](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L237) · [src/api/objectives.jl:36](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/objectives.jl#L36) · [src/api/gradient_methods.jl:42](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L42) · [src/api/gradient_methods.jl:39](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L39)

原生帮助：

```julia
evaluate(objective, values::AbstractVector{<:Real}) -> Real
```

Execute a scalar objective without selecting or invoking a gradient method. Implement this public operation for an external objective; it need not expose an `AbstractQuantumState`, dense storage, or AD rules. Implementations preserve the caller's parameter vector. Function objectives can be passed directly.


<a id="api-MOSSQuantum-supports_gradient"></a>

### `MOSSQuantum.supports_gradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
supports_gradient(::AdjointGradient, objective::ExpectationObjective)
supports_gradient(::AdjointGradient, objective::ExpectationObjective, values::AbstractVector{<:Real})
supports_gradient(::AdjointGradient, objective::BatchExpectationObjective)
supports_gradient(::AdjointGradient, objective::BatchExpectationObjective, values::AbstractVector{<:Real})
supports_gradient(::ParameterShift, objective::Union{ExpectationObjective, ShotExpectationObjective})
supports_gradient(::Union{FiniteDifference, SPSAGradient}, ::Union{Function, ShotExpectationObjective})
supports_gradient(::Union{FiniteDifference, SPSAGradient}, objective::ExpectationObjective)
supports_gradient(::AbstractGradientMethod, objective)
supports_gradient(method::Union{ParameterShift, FiniteDifference, SPSAGradient}, objective::Union{ExpectationObjective, ShotExpectationObjective}, values::AbstractVector{<:Real})
supports_gradient(method::Union{FiniteDifference, SPSAGradient}, objective::Function, values::AbstractVector{<:Real})
supports_gradient(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
```

源码：[src/differentiation/objectives.jl:101](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L101) · [src/differentiation/objectives.jl:124](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L124) · [src/differentiation/objectives.jl:244](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L244) · [src/differentiation/objectives.jl:246](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L246) · [src/differentiation/sampled_gradients.jl:187](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L187) · [src/differentiation/sampled_gradients.jl:198](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L198) · [src/differentiation/sampled_gradients.jl:199](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L199) · [src/api/gradient_methods.jl:51](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L51) · [src/differentiation/sampled_gradients.jl:228](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L228) · [src/differentiation/sampled_gradients.jl:241](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L241) · [src/api/gradient_methods.jl:52](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L52)

原生帮助：

```julia
supports_gradient(method::AbstractGradientMethod, objective) -> Bool
```

Query support for derivatives of the objective's explicit parameter vector. Unknown combinations return `false`. Forward execution support is separate; successful evaluation does not imply any differentiation capability.


<a id="api-MOSSQuantum-value_and_gradient"></a>

### `MOSSQuantum.value_and_gradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
value_and_gradient(method::Union{ParameterShift, FiniteDifference, SPSAGradient}, objective, values::AbstractVector{<:Real}; rng, budget)
value_and_gradient(method::AdjointGradient, objective::BatchExpectationObjective, values::AbstractVector{<:Real})
value_and_gradient(method::AdjointGradient, objective::ExpectationObjective, values::AbstractVector{<:Real})
value_and_gradient(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
```

源码：[src/differentiation/sampled_gradients.jl:379](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L379) · [src/differentiation/objectives.jl:292](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L292) · [src/differentiation/objectives.jl:215](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L215) · [src/api/gradient_methods.jl:96](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L96)

原生帮助：

```julia
value_and_gradient(method::AbstractGradientMethod, objective, values) -> (value, gradient)
```

Compute a real scalar value and its gradient in the independent parameter order of `values`. External methods implement this public hook and declare support with `supports_gradient`. The default throws `UnsupportedGradient` and never selects another algorithm. No AD package is required to call this operation.

Inputs remain unchanged. Gradients are real vectors with one entry per input; their numerical precision is chosen by the strategy. Nonfinite gradients may propagate. AD adapters separately project cotangents to the input domain.


<a id="api-MOSSQuantum-value_and_pullback"></a>

### `MOSSQuantum.value_and_pullback`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
value_and_pullback(method::AdjointGradient, objective::BatchExpectationObjective, values::AbstractVector{<:Real})
value_and_pullback(method::AdjointGradient, objective::ExpectationObjective, values::AbstractVector{<:Real})
value_and_pullback(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
```

源码：[src/differentiation/objectives.jl:256](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L256) · [src/differentiation/objectives.jl:183](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/objectives.jl#L183) · [src/api/gradient_methods.jl:113](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L113)

原生帮助：

```julia
value_and_pullback(method::AbstractGradientMethod, objective, values) -> (value, back)
```

Prepare a numerical scalar pullback: `back(seed::Real)` returns only the parameter gradient multiplied by `seed`, not an AD framework's cotangent tuple. Repeated calls must be independent and must not consume saved state.

The fallback calls `value_and_gradient` once, validates the result, and caches a private copy of its gradient. It is eager; methods may specialize this operation to defer the reverse pass and reuse forward work. There is no recursion between the default gradient and pullback hooks. External methods implementing only the gradient hook can therefore use the optional AD adapter unchanged.


<a id="api-MOSSQuantum-differentiable_value"></a>

### `MOSSQuantum.differentiable_value`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
differentiable_value(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real})
```

源码：[src/api/gradient_methods.jl:135](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/api/gradient_methods.jl#L135)

原生帮助：

```julia
differentiable_value(method::AbstractGradientMethod, objective, values) -> Real
```

Evaluate an objective with an explicit differentiation policy for optional AD adapters. An ordinary call only invokes `evaluate`, even if the method does not support differentiation. With ChainRulesCore loaded, the reverse rule dispatches to the public `value_and_pullback` hook. Only `values` is differentiable through this entrypoint; the method and objective are fixed configuration.

Use `evaluate` for execution alone, or `value_and_gradient` for explicit numerical derivatives without an AD framework. None of these choices modifies execution backends or the existing circuit APIs.


<a id="api-MOSSQuantum-ReadoutError"></a>

### `MOSSQuantum.ReadoutError`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ReadoutError(qubit::Integer; p0_to_1, p1_to_0, scope)
ReadoutError(qubits, probabilities::AbstractMatrix{<:Real}; scope)
```

源码：[src/execution/noise_models.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L30) · [src/execution/noise_models.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L13)

原生帮助：

```julia
ReadoutError(qubits, probabilities; scope=:terminal)
```

Classical confusion matrix: row `true+1`, column `reported+1`. The first qubit is the least significant local bit. Rows sum to one. `scope` is `:terminal`, `:measurement`, or `:all`; intermediate errors currently require one qubit. Inputs are copied. Treat stored configuration as read-only.


<a id="api-MOSSQuantum-NoiseRule"></a>

### `MOSSQuantum.NoiseRule`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
NoiseRule(matcher, factory; when, qubits)
```

源码：[src/execution/noise_models.jl:62](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L62)

原生帮助：

```julia
NoiseRule(matcher, factory; when=:after, qubits=nothing)
```

Match an instruction type or predicate. Call `factory(instruction)` to produce one physical QuantumMap or a vector of maps. Rules run in registration order, only on original leaf instructions. `qubits` optionally matches the exact ordered register. Factory arguments are independent copies.


<a id="api-MOSSQuantum-NoiseModel"></a>

### `MOSSQuantum.NoiseModel`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
NoiseModel(; rules, readout, preparation, terminal)
```

源码：[src/execution/noise_models.jl:87](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L87)

原生帮助：

Noise configuration with explicit preparation, instruction, terminal, and classical readout stages.


<a id="api-MOSSQuantum-NoisyCircuit"></a>

### `MOSSQuantum.NoisyCircuit`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
NoisyCircuit(circuit::QCircuit, readout::Vector{ReadoutError})
NoisyCircuit(circuit, readout)
```

源码：[src/execution/noise_models.jl:111](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L111)

原生帮助：

An explicitly expanded noise program; inspect `.circuit` and `.readout`.


<a id="api-MOSSQuantum-with_noise"></a>

### `MOSSQuantum.with_noise`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
with_noise(::NoisyCircuit, ::NoiseModel)
with_noise(circuit::QCircuit, model::NoiseModel)
```

源码：[src/execution/noise_models.jl:169](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L169) · [src/execution/noise_models.jl:158](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L158)

原生帮助：

Expand noise once without mutating the source circuit. Re-expansion is rejected.


<a id="api-MOSSQuantum-Delay"></a>

### `MOSSQuantum.Delay`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Delay(position::Int64; duration)
```

源码：[src/execution/noise_models.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L37)

原生帮助：

An explicit idle interval, in the same time unit used by its noise rule.


<a id="api-MOSSQuantum-readout_probabilities"></a>

### `MOSSQuantum.readout_probabilities`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
readout_probabilities(state::Union{BatchDensityMatrix, BatchStateVector}, errors; qubits, backend)
readout_probabilities(state::AbstractQuantumState, errors; qubits, backend)
```

源码：[src/execution/noise_models.jl:248](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L248) · [src/execution/noise_models.jl:212](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noise_models.jl#L212)

原生帮助：

Classical readout distribution; ideal `probabilities` retains its existing meaning.


<a id="api-MOSSQuantum-DensityMatrixEvolution"></a>

### `MOSSQuantum.DensityMatrixEvolution`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
DensityMatrixEvolution()
```

源码：[src/execution/noisy_execution.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L3)

原生帮助：

Exact Kraus sum on density matrices (the default execution method).


<a id="api-MOSSQuantum-KrausTrajectory"></a>

### `MOSSQuantum.KrausTrajectory`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
KrausTrajectory()
```

源码：[src/execution/noisy_execution.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L5)

原生帮助：

Independent pure-state Kraus trajectories; CPU pure states and batches only.


<a id="api-MOSSQuantum-CountsResult"></a>

### `MOSSQuantum.CountsResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
CountsResult(shots::Int64, accepted::Int64, qubits::Vector{Int64}, counts::Dict{String, Int64})
CountsResult(shots, accepted, qubits, counts)
```

源码：[src/execution/noisy_execution.jl:19](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/noisy_execution.jl#L19)

原生帮助：

Streaming counts: `shots` counts attempts and `accepted` counts successful attempts.


<a id="api-MOSSQuantum-ClassicalRegister"></a>

### `MOSSQuantum.ClassicalRegister`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ClassicalRegister()
ClassicalRegister(values::Dict{Symbol, Int64}, physical::Dict{Symbol, Int64})
ClassicalRegister(values, physical)
ClassicalRegister(values::AbstractDict)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L9) · [src/quantum_circuits/circuits/classical_control.jl:6](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L6)

原生帮助：

Per-execution classical bits, with separate reported and physical values.


<a id="api-MOSSQuantum-ClassicalCondition"></a>

### `MOSSQuantum.ClassicalCondition`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ClassicalCondition(keys; ...)
ClassicalCondition(keys, value::Integer; source)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L41)

原生帮助：

```julia
ClassicalCondition(keys, value=1; source=:reported)
```

Compare the latest classical bits with an integer. The first key is the least significant bit. Feedback defaults to instrument reports; `source=:physical` is available for ideal diagnostic control.


<a id="api-MOSSQuantum-Conditional"></a>

### `MOSSQuantum.Conditional`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
Conditional(key::Union{AbstractString, Symbol}, instruction::AbstractInstruction; value, source, otherwise)
Conditional(condition::ClassicalCondition, instruction::AbstractInstruction; otherwise)
```

源码：[src/quantum_circuits/circuits/classical_control.jl:67](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L67) · [src/quantum_circuits/circuits/classical_control.jl:60](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/quantum_circuits/circuits/classical_control.jl#L60)

原生帮助：

Execute one branch according to classical bits. Branches are independent snapshots.


<a id="api-MOSSQuantum-classical_register"></a>

### `MOSSQuantum.classical_register`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
classical_register(result::Union{ShotResult, BatchSimulationResult})
classical_register(result::SimulationResult)
classical_register(records::AbstractVector{MeasurementRecord}; initial)
```

源码：[src/execution/classical_execution.jl:53](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/classical_execution.jl#L53) · [src/execution/classical_execution.jl:52](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/classical_execution.jl#L52) · [src/execution/classical_execution.jl:43](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/classical_execution.jl#L43)

原生帮助：

Reconstruct latest named bits from records, optionally starting with an initial register.


<a id="api-MOSSQuantum-classical_counts"></a>

### `MOSSQuantum.classical_counts`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
classical_counts(result::ShotResult, keys; source, accepted_only)
```

源码：[src/execution/classical_execution.jl:56](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/classical_execution.jl#L56)

原生帮助：

Histogram of final classical bits (all attempts by default, including rejected shots).


<a id="api-MOSSQuantum-ShotExpectationObjective"></a>

### `MOSSQuantum.ShotExpectationObjective`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ShotExpectationObjective(template::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, observable::Union{QubitsOperator, QubitsTerm}, initial::AbstractQuantumState; shots, parameter_map, parameter_order, fixed, backend, method, noise_model, readout, classical, grouping, atol, max_terms, allocation)
ShotExpectationObjective(template::QCircuit, plan::MeasurementPlan, initial_state::S, parameter_map::P, shots::Int64, backend::B, method::M, readout::Vector{ReadoutError}, classical::ClassicalRegister, prepared::Union{Nothing, EstimationPlan}, allocation::Union{VarianceAllocation, Symbol}) where {S<:AbstractQuantumState, B<:AbstractBackend, M, P<:AbstractParameterMap}
```

源码：[src/differentiation/sampled_gradients.jl:65](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L65) · [src/differentiation/sampled_gradients.jl:53](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L53)

原生帮助：

```julia
ShotExpectationObjective(template, observable, initial; shots, parameter_map,
                         backend, method, noise_model, readout, classical)
```

Snapshot a scalar finite-shot expectation. `shots` is the budget PER objective execution, shared across its Pauli groups; a gradient executes many objectives. Noise rules are expanded once at construction and frozen, including rules that inspect gate angles. Use an explicit function with finite differences for a parameter-dependent noise model. Batch objectives are not implicit reductions.


<a id="api-MOSSQuantum-ParameterShift"></a>

### `MOSSQuantum.ParameterShift`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ParameterShift()
```

源码：[src/differentiation/sampled_gradients.jl:2](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L2)

原生帮助：

Exact gate-occurrence parameter shifts; unknown gates need a `parameter_shift_rule`.


<a id="api-MOSSQuantum-FiniteDifference"></a>

### `MOSSQuantum.FiniteDifference`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
FiniteDifference(; step)
```

源码：[src/differentiation/sampled_gradients.jl:6](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L6)

原生帮助：

Central differences. Sampling variance grows as 1/step²; truncation bias is not a standard error.


<a id="api-MOSSQuantum-SPSAGradient"></a>

### `MOSSQuantum.SPSAGradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
SPSAGradient(; step, directions)
```

源码：[src/differentiation/sampled_gradients.jl:15](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L15)

原生帮助：

Average independent Rademacher simultaneous perturbations using central differences.


<a id="api-MOSSQuantum-parameter_shift_rule"></a>

### `MOSSQuantum.parameter_shift_rule`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
parameter_shift_rule(g::AdjointQuantumGate, i::Integer)
parameter_shift_rule(g::Union{CRxGate, CRyGate, CRzGate}, i::Integer)
parameter_shift_rule(g::Union{CCPHASEGate, CPHASEGate, PHASEGate, RxGate, RyGate, RzGate}, i::Integer)
parameter_shift_rule(::Gate, ::Integer)
```

源码：[src/differentiation/sampled_gradients.jl:40](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L40) · [src/differentiation/sampled_gradients.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L34) · [src/differentiation/sampled_gradients.jl:30](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L30) · [src/differentiation/sampled_gradients.jl:29](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L29)

原生帮助：

```julia
parameter_shift_rule(gate, active_index)
```

Return `(coefficient, shift)` pairs for the derivative of one active gate slot, or `nothing` if unsupported. A recipe is a contract of the gate family, not a rule inferred from its matrix at one angle. Shared slots are shifted separately.


<a id="api-MOSSQuantum-estimate_gradient"></a>

### `MOSSQuantum.estimate_gradient`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
estimate_gradient(method::Union{ParameterShift, FiniteDifference, SPSAGradient}, objective, values::AbstractVector{<:Real}; rng, budget)
estimate_gradient(method::AbstractGradientMethod, objective, values::AbstractVector{<:Real}; kwargs...)
```

源码：[src/differentiation/sampled_gradients.jl:399](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L399) · [src/differentiation/sampled_gradients.jl:295](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L295)

原生帮助：

Estimate a gradient with explicit RNG, statistical uncertainty and shot accounting.


<a id="api-MOSSQuantum-GradientEstimate"></a>

### `MOSSQuantum.GradientEstimate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
GradientEstimate(value::Float64, value_variance::Float64, gradient::Vector{Float64}, sampling_covariance::Matrix{Float64}, covariance::Union{Nothing, Matrix{Float64}}, stderr::Union{Nothing, Vector{Float64}}, shots::Int64, evaluations::Int64)
GradientEstimate(value, value_variance, gradient, sampling_covariance, covariance, stderr, shots, evaluations)
```

源码：[src/differentiation/sampled_gradients.jl:127](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L127)

原生帮助：

Gradient statistics. `shots` is the total actual measurement budget including an independent value estimate; `evaluations` counts objective calls. `sampling_covariance` propagates measurement error. `covariance` additionally estimates SPSA direction variability from independent directions; it is `nothing` for one SPSA direction. `stderr` follows `covariance`. Neither includes finite step bias, physical noise bias, or an error guarantee from a finite sample.


<a id="api-MOSSQuantum-ExecutionPlan"></a>

### `MOSSQuantum.ExecutionPlan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExecutionPlan(template::QCircuit, initial::S, parameter_map::P, operations::Vector{Any}, method::M, readout::Vector{ReadoutError}, classical::ClassicalRegister, qubits::Vector{Int64}, expanded::Vector{Int64}, deterministic::Bool) where {S, M, P<:AbstractParameterMap}
```

源码：[src/execution/execution_plans.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L13)

原生帮助：

A snapshot of a CPU circuit, state, fixed noise and validation. Treat fields as read-only.


<a id="api-MOSSQuantum-BoundExecutionPlan"></a>

### `MOSSQuantum.BoundExecutionPlan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BoundExecutionPlan(plan::P, operations::Vector{Any}, parameters::Vector{Float64}, prepared_state, distribution) where P
```

源码：[src/execution/execution_plans.jl:27](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L27)

原生帮助：

A bound execution snapshot. Repeated calls share no mutable execution buffers.


<a id="api-MOSSQuantum-ExecutionWorkspace"></a>

### `MOSSQuantum.ExecutionWorkspace`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExecutionWorkspace(bound::BoundExecutionPlan)
ExecutionWorkspace(owner::P, trajectory::W, lock::ReentrantLock) where {P, W}
```

源码：[src/execution/execution_plans.jl:212](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L212) · [src/execution/execution_plans.jl:208](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L208)

原生帮助：

Optional reusable buffers tied to one bound plan. Concurrent uses serialize on a lock.


<a id="api-MOSSQuantum-prepare_execution"></a>

### `MOSSQuantum.prepare_execution`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
prepare_execution(circuit::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, initial::AbstractQuantumState; parameter_map, parameter_order, fixed, method, noise_model, readout, classical, qubits)
```

源码：[src/execution/execution_plans.jl:98](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L98)

原生帮助：

```julia
prepare_execution(circuit_or_context, initial; parameter_map, method, noise_model,
                  readout, classical, qubits)
```

Snapshot and validate one dense CPU state (not a state batch). Noise factories are expanded once, then frozen. Compiled contexts retain their input identities; noise that changes their layout requires preparing the original circuit. `bind_execution(plan, values)` binds active gates and caches deterministic output distributions. Rebuild the plan to change state, structure, measurement or noise.


<a id="api-MOSSQuantum-bind_execution"></a>

### `MOSSQuantum.bind_execution`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
bind_execution(plan::EstimationPlan, values::AbstractVector{<:Real})
bind_execution(plan::EstimationPlan)
bind_execution(plan::ExecutionPlan, values::AbstractVector{<:Real})
bind_execution(plan::ExecutionPlan)
```

源码：[src/observables/estimation_plans.jl:26](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L26) · [src/execution/execution_plans.jl:198](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/execution_plans.jl#L198)

原生帮助：

No documentation found for public binding `MOSSQuantum.bind_execution`.

`MOSSQuantum.bind_execution` is a `Function`.

```
# 4 methods for generic function "bind_execution" from MOSSQuantum:
 [1] bind_execution(plan::EstimationPlan, values::AbstractVector{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/observables/estimation_plans.jl:26
 [2] bind_execution(plan::EstimationPlan)
     @ ~/Code/Quantum/MOSSQuantum/src/observables/estimation_plans.jl:26
 [3] bind_execution(plan::ExecutionPlan, values::AbstractVector{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/execution/execution_plans.jl:198
 [4] bind_execution(plan::ExecutionPlan)
     @ ~/Code/Quantum/MOSSQuantum/src/execution/execution_plans.jl:198
```


<a id="api-MOSSQuantum-EstimationPlan"></a>

### `MOSSQuantum.EstimationPlan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
EstimationPlan(execution::P, measurement::MeasurementPlan, rotations::Vector{Vector{Any}}, expanded::Vector{Vector{Int64}}) where P
```

源码：[src/observables/estimation_plans.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L3)

原生帮助：

Frozen measurement groups and CPU execution metadata for repeated expectations.


<a id="api-MOSSQuantum-BoundEstimationPlan"></a>

### `MOSSQuantum.BoundEstimationPlan`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
BoundEstimationPlan(plan::P, executions::Vector{BoundExecutionPlan}, parameters::Vector{Float64}) where P
```

源码：[src/observables/estimation_plans.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L9)

原生帮助：

No documentation found for public binding `MOSSQuantum.BoundEstimationPlan`.

#### Summary

```
struct BoundEstimationPlan{P}
```

#### Fields

```
plan       :: P
executions :: Vector{BoundExecutionPlan}
parameters :: Vector{Float64}
```


<a id="api-MOSSQuantum-prepare_estimation"></a>

### `MOSSQuantum.prepare_estimation`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
prepare_estimation(circuit::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, observable::Union{QubitsOperator, QubitsTerm}, initial::AbstractQuantumState; grouping, atol, max_terms, kwargs...)
```

源码：[src/observables/estimation_plans.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L13)

原生帮助：

No documentation found for public binding `MOSSQuantum.prepare_estimation`.

`MOSSQuantum.prepare_estimation` is a `Function`.

```
# 1 method for generic function "prepare_estimation" from MOSSQuantum:
 [1] prepare_estimation(circuit::Union{QCircuit, NamedTuple{(:template, :parameter_map), <:Tuple{AbstractInstruction, AbstractParameterMap}}}, observable::Union{QubitsOperator, QubitsTerm}, initial::AbstractQuantumState; grouping, atol, max_terms, kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/observables/estimation_plans.jl:13
```


<a id="api-MOSSQuantum-VarianceAllocation"></a>

### `MOSSQuantum.VarianceAllocation`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
VarianceAllocation(; pilot_shots)
```

源码：[src/observables/estimation_plans.jl:55](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L55)

原生帮助：

Independent pilot measurements choose production allocations; pilot data are not reused in means.


<a id="api-MOSSQuantum-AdaptiveEstimate"></a>

### `MOSSQuantum.AdaptiveEstimate`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
AdaptiveEstimate(value::Float64, variance::Float64, stderr::Float64, shots::Int64, requested_shots::Int64, groups::Vector{GroupEstimate}, pilot_groups::Vector{GroupEstimate}, pilot_shots::Int64, production_shots::Int64)
AdaptiveEstimate(value, variance, stderr, shots, requested_shots, groups, pilot_groups, pilot_shots, production_shots)
```

源码：[src/observables/estimation_plans.jl:62](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/observables/estimation_plans.jl#L62)

原生帮助：

No documentation found for public binding `MOSSQuantum.AdaptiveEstimate`.

#### Summary

```
struct AdaptiveEstimate
```

#### Fields

```
value            :: Float64
variance         :: Float64
stderr           :: Float64
shots            :: Int64
requested_shots  :: Int64
groups           :: Vector{GroupEstimate}
pilot_groups     :: Vector{GroupEstimate}
pilot_shots      :: Int64
production_shots :: Int64
```


<a id="api-MOSSQuantum-ExperimentResult"></a>

### `MOSSQuantum.ExperimentResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ExperimentResult(parameters::Matrix{Float64}, results::Vector{R}, shots::Int64, evaluations::Int64) where R
```

源码：[src/execution/experiments.jl:3](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/experiments.jl#L3)

原生帮助：

Ordered experiment results; columns of `parameters` identify rows of `results`.


<a id="api-MOSSQuantum-run_sweep"></a>

### `MOSSQuantum.run_sweep`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
run_sweep(plan::Union{EstimationPlan, ExecutionPlan}, parameters::AbstractMatrix{<:Real}; shots, rng, parallel, result, allocation, budget, chunk_size)
```

源码：[src/execution/experiments.jl:17](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/experiments.jl#L17)

原生帮助：

```julia
run_sweep(plan, parameters; shots, rng, parallel=false, budget, ...)
```

Execute columns of independent parameter values. Validate and bind every point before sampling; then assign one RNG seed per point in column order. Serial and threaded sweeps therefore agree in the same Julia environment. `shots` is per point. Parallelism here is across points, not nested shot parallelism.


<a id="api-MOSSQuantum-ShotBudget"></a>

### `MOSSQuantum.ShotBudget`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ShotBudget(limit::Integer)
```

源码：[src/execution/shot_budgets.jl:6](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_budgets.jl#L6)

原生帮助：

A thread-safe hard cap. Failed sampling calls retain their reserved charge.


<a id="api-MOSSQuantum-ShotBudgetExceeded"></a>

### `MOSSQuantum.ShotBudgetExceeded`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ShotBudgetExceeded(requested::Int64, remaining::Int64)
ShotBudgetExceeded(requested, remaining)
```

源码：[src/execution/shot_budgets.jl:9](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_budgets.jl#L9)

原生帮助：

No documentation found for public binding `MOSSQuantum.ShotBudgetExceeded`.

#### Summary

```
struct ShotBudgetExceeded
```

#### Fields

```
requested :: Int64
remaining :: Int64
```

#### Supertype Hierarchy

```
ShotBudgetExceeded <: Exception <: Any
```


<a id="api-MOSSQuantum-remaining_shots"></a>

### `MOSSQuantum.remaining_shots`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
remaining_shots(b::ShotBudget)
```

源码：[src/execution/shot_budgets.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/execution/shot_budgets.jl#L13)

原生帮助：

No documentation found for public binding `MOSSQuantum.remaining_shots`.

`MOSSQuantum.remaining_shots` is a `Function`.

```
# 1 method for generic function "remaining_shots" from MOSSQuantum:
 [1] remaining_shots(b::ShotBudget)
     @ ~/Code/Quantum/MOSSQuantum/src/execution/shot_budgets.jl:13
```


<a id="api-MOSSQuantum-required_shots"></a>

### `MOSSQuantum.required_shots`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
required_shots(method::Union{ParameterShift, FiniteDifference, SPSAGradient}, objective, values::AbstractVector{<:Real})
required_shots(objective::ShotExpectationObjective)
```

源码：[src/differentiation/sampled_gradients.jl:384](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L384) · [src/differentiation/sampled_gradients.jl:96](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/differentiation/sampled_gradients.jl#L96)

原生帮助：

No documentation found for public binding `MOSSQuantum.required_shots`.

`MOSSQuantum.required_shots` is a `Function`.

```
# 2 methods for generic function "required_shots" from MOSSQuantum:
 [1] required_shots(method::Union{ParameterShift, FiniteDifference, SPSAGradient}, objective, values::AbstractVector{<:Real})
     @ ~/Code/Quantum/MOSSQuantum/src/differentiation/sampled_gradients.jl:384
 [2] required_shots(objective::ShotExpectationObjective)
     @ ~/Code/Quantum/MOSSQuantum/src/differentiation/sampled_gradients.jl:96
```


## MOSSQuantum.Utilities

[`heisenberg_1d`](#api-MOSSQuantum-Utilities-heisenberg_1d) · [`heisenberg_2d`](#api-MOSSQuantum-Utilities-heisenberg_2d) · [`ising_1d`](#api-MOSSQuantum-Utilities-ising_1d) · [`ising_2d`](#api-MOSSQuantum-Utilities-ising_2d) · [`ground_state`](#api-MOSSQuantum-Utilities-ground_state) · [`time_evolution`](#api-MOSSQuantum-Utilities-time_evolution) · [`trotter_propagator`](#api-MOSSQuantum-Utilities-trotter_propagator) · [`fuse_gates`](#api-MOSSQuantum-Utilities-fuse_gates) · [`variational_circuit_1d`](#api-MOSSQuantum-Utilities-variational_circuit_1d) · [`real_variational_circuit_1d`](#api-MOSSQuantum-Utilities-real_variational_circuit_1d)

<a id="api-MOSSQuantum-Utilities-heisenberg_1d"></a>

### `MOSSQuantum.Utilities.heisenberg_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
heisenberg_1d(L::Int64; kwargs...)
```

源码：[src/utilities/models/spin_hamiltonians.jl:23](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L23)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.heisenberg_1d`.

`MOSSQuantum.Utilities.heisenberg_1d` is a `Function`.

```
# 1 method for generic function "heisenberg_1d" from MOSSQuantum.Utilities:
 [1] heisenberg_1d(L::Int64; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:23
```


<a id="api-MOSSQuantum-Utilities-heisenberg_2d"></a>

### `MOSSQuantum.Utilities.heisenberg_2d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
heisenberg_2d(shapes::Tuple{Int64, Int64}; kwargs...)
heisenberg_2d(m::Int64, n::Int64; J, Jzz, hz)
heisenberg_2d(m::Int64; ...)
```

源码：[src/utilities/models/spin_hamiltonians.jl:50](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L50) · [src/utilities/models/spin_hamiltonians.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L25)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.heisenberg_2d`.

`MOSSQuantum.Utilities.heisenberg_2d` is a `Function`.

```
# 3 methods for generic function "heisenberg_2d" from MOSSQuantum.Utilities:
 [1] heisenberg_2d(shapes::Tuple{Int64, Int64}; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:50
 [2] heisenberg_2d(m::Int64, n::Int64; J, Jzz, hz)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:25
 [3] heisenberg_2d(m::Int64; ...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:25
```


<a id="api-MOSSQuantum-Utilities-ising_1d"></a>

### `MOSSQuantum.Utilities.ising_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ising_1d(L::Int64; kwargs...)
```

源码：[src/utilities/models/spin_hamiltonians.jl:64](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L64)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.ising_1d`.

`MOSSQuantum.Utilities.ising_1d` is a `Function`.

```
# 1 method for generic function "ising_1d" from MOSSQuantum.Utilities:
 [1] ising_1d(L::Int64; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:64
```


<a id="api-MOSSQuantum-Utilities-ising_2d"></a>

### `MOSSQuantum.Utilities.ising_2d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ising_2d(shapes::Tuple{Int64, Int64}; kwargs...)
ising_2d(m::Int64, n::Int64; J, hz)
ising_2d(m::Int64; ...)
```

源码：[src/utilities/models/spin_hamiltonians.jl:85](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L85) · [src/utilities/models/spin_hamiltonians.jl:66](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/models/spin_hamiltonians.jl#L66)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.ising_2d`.

`MOSSQuantum.Utilities.ising_2d` is a `Function`.

```
# 3 methods for generic function "ising_2d" from MOSSQuantum.Utilities:
 [1] ising_2d(shapes::Tuple{Int64, Int64}; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:85
 [2] ising_2d(m::Int64, n::Int64; J, hz)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:66
 [3] ising_2d(m::Int64; ...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/models/spin_hamiltonians.jl:66
```


<a id="api-MOSSQuantum-Utilities-ground_state"></a>

### `MOSSQuantum.Utilities.ground_state`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
ground_state(h::QubitsOperator; kwargs...)
```

源码：[src/utilities/evolution/krylov.jl:4](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/evolution/krylov.jl#L4)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.ground_state`.

`MOSSQuantum.Utilities.ground_state` is a `Function`.

```
# 1 method for generic function "ground_state" from MOSSQuantum.Utilities:
 [1] ground_state(h::QubitsOperator; kwargs...)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/evolution/krylov.jl:4
```


<a id="api-MOSSQuantum-Utilities-time_evolution"></a>

### `MOSSQuantum.Utilities.time_evolution`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
time_evolution(h::QubitsOperator, t::Number, v::DensityMatrix; kwargs...)
time_evolution(h::QubitsOperator, t::Number, v::StateVector; kwargs...)
```

源码：[src/utilities/evolution/krylov.jl:37](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/evolution/krylov.jl#L37) · [src/utilities/evolution/krylov.jl:25](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/evolution/krylov.jl#L25)

原生帮助：

```julia
time_evolution(h::QubitsOperator, t::Number, state; kwargs...)
```

Apply `exp(t * h)` to a pure state, or `exp(t * h) * ρ * exp(conj(t) * h)` to a density matrix, using Krylov exponentiation for Hermitian `h`. For physical time `τ` with `ℏ = 1`, pass `t = -im * τ`. Real `t` describes an unnormalized imaginary-time map; the result is not automatically normalized. Additional keywords are passed to KrylovKit.


<a id="api-MOSSQuantum-Utilities-trotter_propagator"></a>

### `MOSSQuantum.Utilities.trotter_propagator`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
trotter_propagator(ham::QubitsOperator, tspan::Tuple{Number, Number}; order, stepsize)
trotter_propagator(ham::QubitsOperator, t::Number; order, stepsize)
```

源码：[src/utilities/evolution/trotter.jl:173](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/evolution/trotter.jl#L173) · [src/utilities/evolution/trotter.jl:171](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/evolution/trotter.jl#L171)

<a id="api-MOSSQuantum-Utilities-fuse_gates"></a>

### `MOSSQuantum.Utilities.fuse_gates`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
fuse_gates(circuit::QCircuit; max_qubits)
```

源码：[src/utilities/algorithms/gate_fusion.jl:10](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/algorithms/gate_fusion.jl#L10)

原生帮助：

```julia
fuse_gates(circuit::QCircuit; max_qubits::Int=5) -> QCircuit
```

Combine adjacent nonparameterized gates while their combined support contains at most `max_qubits` qubits. The returned circuit has the same operation order and leaves the input circuit unchanged. Parameterized gates, channels, measurements, and postselections separate fusion blocks; nested circuits are fused recursively. `max_qubits` must be between 1 and the simulator limit of 5.


<a id="api-MOSSQuantum-Utilities-variational_circuit_1d"></a>

### `MOSSQuantum.Utilities.variational_circuit_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
variational_circuit_1d(L::Int64, depth::Int64; θs)
```

源码：[src/utilities/algorithms/variational_circuit.jl:5](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/algorithms/variational_circuit.jl#L5)

原生帮助：

```julia
variational_circuit_1d(L::Int, depth::Int; θs::Vector{<:Real})
```

Return a variational quantum circuit given L qubis and d depth


<a id="api-MOSSQuantum-Utilities-real_variational_circuit_1d"></a>

### `MOSSQuantum.Utilities.real_variational_circuit_1d`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
real_variational_circuit_1d(L::Int64, depth::Int64; θs)
```

源码：[src/utilities/algorithms/variational_circuit.jl:41](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/utilities/algorithms/variational_circuit.jl#L41)

原生帮助：

No documentation found for public binding `MOSSQuantum.Utilities.real_variational_circuit_1d`.

`MOSSQuantum.Utilities.real_variational_circuit_1d` is a `Function`.

```
# 1 method for generic function "real_variational_circuit_1d" from MOSSQuantum.Utilities:
 [1] real_variational_circuit_1d(L::Int64, depth::Int64; θs)
     @ ~/Code/Quantum/MOSSQuantum/src/utilities/algorithms/variational_circuit.jl:41
```


## MOSSQuantum.Optimization

[`minimize`](#api-MOSSQuantum-Optimization-minimize) · [`OptimizationResult`](#api-MOSSQuantum-Optimization-OptimizationResult) · [`OptimizationStep`](#api-MOSSQuantum-Optimization-OptimizationStep)

<a id="api-MOSSQuantum-Optimization-minimize"></a>

### `MOSSQuantum.Optimization.minimize`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
minimize(objective::ShotExpectationObjective, initial::AbstractVector{<:Real}; method, optimizer, iterations, learning_rate, decay, perturbation_decay, rng, callback, max_shots)
```

源码：[src/optimization/Optimization.jl:34](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/optimization/Optimization.jl#L34)

原生帮助：

```julia
minimize(objective::ShotExpectationObjective, initial; method=ParameterShift(),
         optimizer=:adam, iterations=100, learning_rate=0.1, decay=0,
         perturbation_decay=0.101, rng, callback=nothing)
```

A small reproducible finite-shot optimization workflow. Choose `:adam` or `:sgd`. With SPSAGradient, step k uses `method.step/k^perturbation_decay`. The learning rate is `learning_rate/k^decay`; SPSA+SGD commonly uses decay=0.602. History stores the pre-update parameters corresponding to each gradient's value. Final parameters receive a fresh independent estimate; the result is not a noisy best-of-history selection. No convergence guarantee or automatic early stopping is inferred from shot noise. `callback(step) === false` stops before that update.


<a id="api-MOSSQuantum-Optimization-OptimizationResult"></a>

### `MOSSQuantum.Optimization.OptimizationResult`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MOSSQuantum.Optimization.OptimizationResult(parameters::Vector{Float64}, estimate::Union{AdaptiveEstimate, ExpectationEstimate}, history::Vector{MOSSQuantum.Optimization.OptimizationStep}, shots::Int64, evaluations::Int64, status::Symbol)
MOSSQuantum.Optimization.OptimizationResult(parameters, estimate, history, shots, evaluations, status)
```

源码：[src/optimization/Optimization.jl:13](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/optimization/Optimization.jl#L13)

原生帮助：

No documentation found for public binding `MOSSQuantum.Optimization.OptimizationResult`.

#### Summary

```
struct MOSSQuantum.Optimization.OptimizationResult
```

#### Fields

```
parameters  :: Vector{Float64}
estimate    :: Union{AdaptiveEstimate, ExpectationEstimate}
history     :: Vector{MOSSQuantum.Optimization.OptimizationStep}
shots       :: Int64
evaluations :: Int64
status      :: Symbol
```


<a id="api-MOSSQuantum-Optimization-OptimizationStep"></a>

### `MOSSQuantum.Optimization.OptimizationStep`

参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。

```julia
MOSSQuantum.Optimization.OptimizationStep(iteration::Int64, parameters::Vector{Float64}, estimate::GradientEstimate, learning_rate::Float64)
MOSSQuantum.Optimization.OptimizationStep(iteration, parameters, estimate, learning_rate)
```

源码：[src/optimization/Optimization.jl:7](https://github.com/LeeQY1996/MOSSQuantum/blob/main/src/optimization/Optimization.jl#L7)

原生帮助：

No documentation found for public binding `MOSSQuantum.Optimization.OptimizationStep`.

#### Summary

```
struct MOSSQuantum.Optimization.OptimizationStep
```

#### Fields

```
iteration     :: Int64
parameters    :: Vector{Float64}
estimate      :: GradientEstimate
learning_rate :: Float64
```


