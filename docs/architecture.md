# MOSS architecture

MOSS provides dense quantum circuit simulation and differentiation. The core package owns operation descriptions, dense states, CPU execution, observables, and the interfaces that future simulation and application packages will use. The directory reorganization preserves existing namespaces and public behavior; changes to numerical semantics and extension protocols are tracked separately in the [roadmap](roadmap.md).

## Namespaces and source layout

Directories group responsibilities. They do not each introduce a Julia module. The existing `MOSS`, `MOSS.QuantumCircuits`, `MOSS.QuantumCircuits.Gates`, and `MOSS.Utilities` namespaces remain the compatibility boundary.

| Path | Responsibility | Julia namespace |
| --- | --- | --- |
| `src/MOSS.jl` | Load dependencies and assemble the package | `MOSS` |
| `src/api/` | Public exports | `MOSS` |
| `src/quantum_circuits/` | Gates, channels, circuit descriptions, and qubit operators | `MOSS.QuantumCircuits` |
| `src/quantum_circuits/gates/` | Gate types, matrices, parameters, and matrix derivatives | `MOSS.QuantumCircuits` and its existing `Gates` matrix module |
| `src/states/` | State vectors, density matrices, batches, initialization, and encoding | `MOSS` |
| `src/execution/` | Circuit execution, measurement, and post-selection entrypoints | `MOSS` |
| `src/backends/cpu/` | Dense gate, channel, operator, and expectation kernels | `MOSS` |
| `src/observables/` | Expectation interfaces, partial trace, and state diagnostics | `MOSS` |
| `src/differentiation/` | Circuit reverse passes, expectation derivatives, and AD registrations | `MOSS` |
| `src/utilities/` | Existing model builders, evolution helpers, and algorithms | `MOSS.Utilities` |
| `src/utils/` | Internal indexing, tensor, distance, and parallel helpers | `MOSS` |

Circuit plotting remains associated with `QuantumCircuits`; its implementation is loaded through the existing `Requires` integration. Its eventual dependency split is a separate task.

Each type and generic function has one owning module. Re-exports, including `MOSS.nqubits` and `MOSS.QuantumCircuits.nqubits`, must refer to the same function object. Moving a file must not redefine a type under a new module.

## Dependency direction

The intended dependency direction is:

```text
operation descriptions and internal helpers
                  ↓
          states and execution
                  ↓
      observables and differentiation
                  ↓
       Utilities and external packages
```

Operation descriptions should be usable without depending on a concrete state, CPU kernel, or AD framework. CPU kernels implement execution for dense states. Observables expose physical quantities while selecting the appropriate implementation. Differentiation uses execution and observables; AD framework registration should be separable from the reverse-pass algorithm.

These boundaries describe ownership and the direction of subsequent work. File moves alone do not establish a backend protocol or remove the current hard dependency on Zygote. Remaining coupling must be removed in focused changes with compatibility tests.

## Current public entrypoints

The existing API falls into these groups:

| Capability | Representative entrypoints |
| --- | --- |
| Operation structure | `Gate`, `ParametricGate`, `QuantumGate`, `positions`, `nqubits`, `mat`, `ordered_positions`, `ordered_mat` |
| Parameters | `parameters`, `nparameters`, `active_parameters`, `activate_parameter!`, `deactivate_parameter!`, `reset_parameters!`, `differentiate` |
| Circuit construction | `QCircuit`, `push!`, `append!`, `shift`, `change_positions`, adjoint and circuit multiplication |
| Channels | `QuantumMap`, `kraus_matrices`, `ordered_supermat`, `is_tp`, built-in noise constructors |
| State representation | `StateVector`, `DensityMatrix`, `BatchStateVector`, `storage`, `copy`, `qstate`, encoding and reset functions |
| Execution | `apply!`, `circuit * state`, `measure`, `measure!`, `post_select`, `post_select!` |
| Observables | `QubitsTerm`, `QubitsOperator`, `expectation`, `fidelity`, `partial_tr`, entropy helpers |
| Existing utilities | `MOSS.Utilities` model, evolution, ansatz, and algorithm builders |

The complete export surface is assembled in `src/api/`. A public name does not imply every operation supports every state representation. In particular, batch gate execution does not imply batch noise, measurement, or reverse-mode support.

## Tests and performance

`test/runtests.jl` loads MOSS with `using MOSS` and assembles the suite. Tests are grouped by purpose:

- `unit/` checks local behavior of states, operations, parameters, and kernels.
- `integration/` checks circuit workflows, differentiation, utilities, plotting, and public imports.
- `regression/` preserves concrete correctness fixes.
- `support/` contains test-only helpers.

The independent `benchmark/` environment measures performance without making BenchmarkTools a runtime dependency. [Benchmark instructions](../benchmark/README.md) distinguish first invocation latency from repeated execution.

## Compatibility policy for this work

Directory moves preserve module identities, exports, signatures, parameter ordering, execution order, and numerical behavior. Existing internal file paths are implementation details and change during the move. Downstream code should load the package rather than `include` its source files.

Behavior fixes require their own tests and release notes. The [conventions](conventions.md) record current semantics and distinguish the known fidelity and mixed-state evolution problems from intended physical definitions.
