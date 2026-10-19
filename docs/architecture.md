# MOSS architecture

MOSS owns circuit descriptions, dense quantum states, the CPU simulator, observables, and public interfaces for companion simulators and application packages. These interfaces now allow an external instruction and an implicit state to execute without exposing dense amplitudes. The existing `MOSS`, `MOSS.QuantumCircuits`, `MOSS.QuantumCircuits.Gates`, and `MOSS.Utilities` namespaces remain the compatibility boundary.

## Source ownership

Directories group responsibilities; they do not each introduce a Julia module.

| Path | Responsibility | Owning namespace |
| --- | --- | --- |
| `src/MOSS.jl` | Dependency loading and package assembly | `MOSS` |
| `src/api/` | Exports, state/backend contracts, parameter binding, objectives, and gradient-method protocols | `MOSS` |
| `src/quantum_circuits/` | Instructions, gates, channels, circuits, and observable descriptions | `MOSS.QuantumCircuits` |
| `src/quantum_circuits/gates/Gates.jl` | Elementary matrices and matrix constructors | `MOSS.QuantumCircuits.Gates` |
| `src/states/` | Dense states, batches, initialization, and encoding | `MOSS` |
| `src/execution/` | Execution, measurement, post-selection, probabilities, sampling, and results | `MOSS` |
| `src/backends/cpu/` | Dense gate, channel, operator, and expectation kernels | `MOSS` |
| `src/observables/` | Expectation interfaces, partial trace, and state diagnostics | `MOSS` |
| `src/differentiation/` | Numerical single/batch circuit reverse passes and expectation/encoding derivatives | `MOSS` |
| `src/utilities/` | Model builders, evolution helpers, and algorithms | `MOSS.Utilities` |
| `src/utils/` | Internal indexing, tensor, distance, and parallel helpers | `MOSS` |
| `ext/` | Optional ChainRulesCore/Zygote registrations and plotting integration | Extension modules |

Each type and generic function has one owning module. Re-exports such as `MOSS.nqubits` and `MOSS.QuantumCircuits.nqubits` refer to the same function object. File relocation does not redefine a type under a new module.

## Dependency direction

```text
instruction and observable descriptions
                  ↓
      state contracts and CPU execution
                  ↓
       observables and reverse passes
                  ↓
       Utilities and companion packages
```

Operation descriptions do not depend on concrete state types, CPU kernels, or AD frameworks. `AbstractInstruction` distinguishes executable circuit elements from the broader operation hierarchy: Hamiltonian terms are observables and cannot be inserted as circuit instructions. `AbstractQuantumState` imposes no dense storage requirement. Backend methods connect these descriptions to a representation.

The CPU simulator implements the public execution interfaces while retaining existing dense entrypoints. Utilities imports the MOSS functions it uses explicitly. The core retains reverse-pass algorithms; Zygote method registration lives in its optional extension. Companion packages use documented public methods rather than files under `src/backends/`, `.data` fields, or private helper functions.

## Public interfaces

| Capability | Representative entrypoints |
| --- | --- |
| Instructions | `AbstractInstruction`, `Gate`, `ParametricGate`, `QuantumGate`, `positions`, `mat`, `validate_positions`, `copy_instruction` |
| Parameters | `parameters`, `active_parameters`, `nparameters`, activation methods, `reset_parameters!`, `bind_parameters`, `ParameterMap`, `parameter_indices`, `accumulate_parameter_gradients`, `differentiate` |
| Numerical differentiation | `ExpectationObjective`, `BatchExpectationObjective`, `evaluate`, `evaluate_batch`, `AbstractGradientMethod`, `AdjointGradient`, `supports_gradient`, `value_and_gradient`, `value_and_pullback`, `differentiable_value` |
| Circuits | `QCircuit`, `push!`, `append!`, `shift`, `change_positions`, adjoint, circuit multiplication |
| Channels | `QuantumMap`, `kraus_matrices`, `ordered_supermat`, `is_tp`, built-in noise constructors |
| States | `AbstractQuantumState`, `nqubits`, `copy`, `StateVector`, `DensityMatrix`, `BatchStateVector`, `BatchDensityMatrix`; optional dense `storage` |
| Backend selection | `AbstractBackend`, `CPUBackend`, `backend`, `supports`, `UnsupportedOperation` |
| Execution | `apply!(backend, instruction, state)`, `apply!`, `circuit * state`, `simulate` |
| Readout | `probabilities`, `sample`, `counts`, `measure`, `measure!`, `post_select`, `post_select!` |
| Results | `SimulationResult`, `BatchSimulationResult`, result `state`/`measurements`, `MeasurementRecord` |
| Observables | `QubitsTerm`, `QubitsOperator`, `expectation(backend, observable, state)`, `fidelity`, `partial_tr`, entropy helpers |

`supports(b, operation, state; action=:apply)` and `supports(b, observable, state; action=:expectation)` describe separate capabilities. Register bounds are checked through `validate_positions`. Declaring one capability does not imply noise, sampling, or differentiation support. The [extension guide](extending.md) gives implementation requirements and the [conventions](conventions.md) define ordering, ownership, and results.

Public parameter writers may return replacement instructions. Circuit traversal and adjoint wrappers retain these results, so an immutable external gate can use its own fields. Independent binding uses `copy_instruction` per occurrence; ordinary circuit `copy` remains a shallow container copy. The copy hook is owned by `QuantumCircuits` and re-exported by MOSS; `bind_parameters` remains owned by MOSS.

`ParameterMap` is owned by MOSS and keeps integer slot-to-value assignments separate from circuit types. Binding gathers independent values into recursive active-slot order, and `accumulate_parameter_gradients` sums slot gradients back into independent-value order. These operations belong in the main package because they use the public parameter protocol without depending on a simulator or AD framework. Bound circuits retain independent instruction storage and do not carry the map. Maps validate slot counts; callers must rebuild or review them after changing activation or slot order.

## Pure and mixed batches

`StateVector` and `DensityMatrix` remain single-state representations.
`BatchStateVector` stores independent pure samples in `(2^n, B)`;
`BatchDensityMatrix` stores independent mixed samples in `(2^n, 2^n, B)`.
Both retain the sample axis for B=1 and support empty batches and zero-qubit
registers. Public operations dispatch on these types while sharing their names.
Samples share a circuit and parameter vector, with no coupling between samples.

The CPU backend supports gates, fixed Kraus channels, operators, expectations,
readout, measurement, post-selection, and recorded simulation. A channel changes
a pure batch into a density batch. `BatchSimulationResult` accepts either final
representation and stores one record list per sample. Gates act on both density
indices as `UρU†`; algebraic observable multiplication remains a left action.
Partial reductions of a density batch return an independent `BatchDensityMatrix`;
tracing all sites of a nonzero register returns the sample trace vector.
the existing pure-batch API still returns individual `DensityMatrix` values for
partial reductions. See the [pure batch guide](batching.md) and
[density batch guide](batch-density-matrices.md) for exact contracts.

## Replaceable differentiation

`evaluate(objective, values)` is a forward-only public protocol independent of gradient methods. `ExpectationObjective` snapshots a circuit, observable, and single initial state and retains its execution backend. `BatchExpectationObjective` additionally preserves a sample axis and explicitly reduces sample expectations by mean, sum, or weighted sum. External objectives can implement the protocol without state or storage inheritance. `AbstractGradientMethod`, `supports_gradient`, `value_and_gradient`, and `value_and_pullback` define numerical parameter differentiation independently of AD frameworks. The CPU `AdjointGradient` implementation reuses the numerical reverse passes and shared-value reduction.

`differentiable_value(method, objective, values)` explicitly carries the selected numerical method. Ordinary execution calls `evaluate`; the optional ChainRulesCore extension delegates differentiation to the public pullback hook. Only the explicit parameter vector is differentiated by this scalar entrypoint. This avoids imposing a new circuit tangent representation on the legacy Zygote interfaces or coupling a future numerical gradient strategy to the forward executor.

Repeated CPU evaluations keep their mutable execution state local to each call. A prepared adjoint owns its bound circuit, output, observation snapshot, and any fixed-channel checkpoints. There is no persistent cache on `ExpectationObjective`, and support and bound-parameter validation remain part of each gradient preparation. Reuse of a prepared pullback does not require a new execution-plan interface from other backends. The [ownership conventions](conventions.md#repeated-evaluation-and-pullback-ownership) define interleaving and concurrency.

The batch scalar objective and legacy batch Zygote rules share numerical helpers
in `src/differentiation/batch.jl`: sample observation seeds and per-sample reverse
passes. Unitary-only circuits use one batch forward and reverse reconstruction;
circuits with fixed noise retain per-sample checkpoints, including singular
channels such as complete amplitude damping. Slot gradients are reduced through
`ParameterMap` after sample contributions are accumulated. Explicit gradient calls
therefore do not depend on an AD framework, while optional AD uses the same
numerical implementation. Legacy rules also support batch qubit encoding and
selected state constructors; stochastic simulation, measurement, and post-selection
are outside the batch derivative contract.

## Optional integrations

MOSS requires Julia 1.10 or later, with Julia 1.13 as the primary development and acceptance version. ChainRulesCore, Zygote, Plots, and LaTeXStrings are weak dependencies. Native package extensions activate after their trigger dependencies load on every supported Julia version. `MOSSChainRulesCoreExt` registers the explicit-method scalar rule independently of Zygote; `MOSSZygoteExt` retains the legacy Zygote adjoints; `MOSSPlotsExt` requires both Plots and LaTeXStrings. The Requires bridge and support for Julia versions below 1.10 have been removed.

FiniteDifferences is a test dependency. The minimal simulator can load without installing an AD or plotting framework. Final version-specific loading results belong in the [verification record](roadmap.md#verification-record); a compatibility declaration alone does not establish a tested Julia version.

## Tests and performance

`test/runtests.jl` uses normal package loading. Test groups are `unit/`, `integration/`, `regression/`, `extensions/`, and `support/`. Public API snapshots protect existing exports and namespace identities while allowing new exports.

`test/fixtures/MOSSDemoBackend` is a separate package with its own `Project.toml` and `import MOSS`. It provides an implicit product state, a custom instruction, a backend, and expectation evaluation through public interfaces. It requires neither dense `storage` nor private MOSS kernels. Independent package resolution and final suite results are recorded separately from its implementation.

`test/fixtures/MOSSDemoGates` separately defines an immutable trainable gate using public parameter readers, writers, activation controls, and `differentiate`. Its tests complete a dense CPU training step, compare gradients with analytic and finite-difference results, and verify pure/mixed batch circuit gradients with fixed noise.

`test/fixtures/MOSSDemoDifferentiation` defines an external scalar objective, replaceable executors, and replaceable numerical gradient methods through public hooks. It verifies core-only execution, direct ChainRules without Zygote, and AD selection of the external method without a quantum-state representation. CI resolves and tests all three fixtures independently on Julia 1.10 and Julia 1.13.

The independent `benchmark/` environment keeps BenchmarkTools out of runtime dependencies. Its [instructions](../benchmark/README.md) distinguish first invocation latency from repeated execution. `batch_evaluation.jl` compares batch objectives of size 1/4/16 with explicit single-state loops, including gradients and optional AD. The [repeated-evaluation report](performance/repeated-evaluation-2026-10-19.md) records measured single-state scalar-objective comparisons, trial summaries, environment metadata, and the first CPU allocation reduction. Those measurements do not establish a baseline for every dense-kernel workload. CI exercises benchmark harnesses without timing thresholds.

## Compatibility and remaining work

The directory migration preserves existing namespaces, exported names, signatures, and execution order. Two intentional numerical changes follow it: squared Uhlmann fidelity replaces the former inconsistent mixed-state expression, and density-matrix evolution now applies the propagator on both sides. The [conventions](conventions.md#physical-quantities-and-migration-notes) describe the migration.

The ownership and parameter milestone preserves existing constructor-sharing defaults, adds explicit copy controls, and makes circuit `push!`, `append!`, and `empty!` return the circuit. Callers of parameter reset and activation retain the returned instruction when it may be replaced. The [ownership conventions](conventions.md#copying-and-storage-ownership) explain these changes.

Explicit shared-value maps add reuse of independent parameter values and gradient accumulation on the existing supported dense CPU circuit path. They preserve two-argument binding and mutating reset, and introduce no symbolic algebra or general backend differentiation contract. The [parameter conventions](conventions.md#explicit-shared-parameter-maps) define their validation and lifecycle.

Dense state fields still use concrete CPU vectors, matrices, and three-dimensional arrays. Array-generic storage, GPU kernels, per-sample circuit parameter vectors, trainable noise parameters, symbolic parameter expressions, and broader legacy ChainRules migration remain future work. The method protocol provides an extension boundary for additional gradient algorithms; no additional estimators are implemented in this milestone. Existing Zygote support does not provide automatic derivatives of stochastic `simulate`, `sample`, or `counts`, or every operation supported by forward batching.
