# CPU backend capabilities

This page describes the current local packages `MOSSQuantum`,
`MOSSQuantumMPS`, and `MOSSQuantumStabilizer`. A backend capability depends on
the **state representation, instruction, execution entry point, and options**.
A supported primitive does not by itself guarantee every experiment combination.
Use the detailed package documentation and the configuration query below for
the actual program. There is no implicit backend or representation fallback.

## Representations and operations

| State | Backend | Gates and observations | Channels and recorded execution |
| --- | --- | --- | --- |
| `StateVector` | `CPUBackend` | Local gates, Pauli terms/operators and readout | Dense channel application may promote to `DensityMatrix`; recorded measurements, feedback and shots |
| `DensityMatrix` | `CPUBackend` | Local gates, Pauli terms/operators and readout | Dense channels, recorded measurements, feedback and shots |
| `BatchStateVector` | `CPUBackend` | Dense batch gate, observation and readout operations | Channels may promote to `BatchDensityMatrix`; batch execution uses a shot budget per member |
| `BatchDensityMatrix` | `CPUBackend` | Dense batch gate, observation and readout operations | Channels and recorded measurements; batch execution uses a shot budget per member |
| `MPS` | `MatrixProductBackend` | Local gates, Pauli terms/operators and readout | Kraus application may promote to `DensityOperatorMPS`; measurement and selected recorded workflows |
| `DensityOperatorMPS` | `MatrixProductBackend` | Local gates, Pauli terms/operators and readout | Kraus maps, measurements and selected recorded workflows |
| `StabilizerState` | `StabilizerBackend` | Supported Clifford gates, Pauli terms/operators and readout | Measurement, reset, classical feedback and rejection sampling; Pauli stochastic trajectories are a separate method |

Dense gate execution supports local gates on up to five qubits; dense channel
execution supports one or two local qubits. The stabilizer representation does
not implement arbitrary non-Clifford gates or arbitrary Kraus channels. MPS
backends retain their selected truncation policy; readout requires normalized
states. See [MPS boundaries](https://github.com/LeeQY1996/MOSSQuantumMPS#supported-operations-and-boundaries)
and [stabilizer boundaries](https://github.com/LeeQY1996/MOSSQuantumStabilizer#readme) for operation-level
details and examples.

`simulate` returns one state and records; `execute` performs attempted shots.
For `execute`, `QSelect` measures and rejects failed attempts; not all backends
support the distinct forced selection semantics of `simulate`. Classical
conditions may be supported by recorded execution even when the older
`supports(...; action=:apply)` query does not accept `Conditional` itself.
Tests for MPS and stabilizer cover representative feedback and selection flows;
this is not a claim that every option and operation combination is supported.

| Execution feature | Dense CPU | MPS | Stabilizer |
| --- | --- | --- | --- |
| `simulate`, `execute`, and state sampling | Supported within operation limits | Representative workflows tested | Representative Clifford workflows tested |
| Finite-shot Pauli estimation | Supported | Representative workflows tested; check the selected configuration | Representative Clifford workflows tested; check the selected configuration |
| Deterministic Kraus application | Supported | Supported | Unsupported |
| `KrausTrajectory` | Pure-state CPU and CPU batches | Unsupported | Unsupported |
| `PauliTrajectory` | Unsupported | Unsupported | One- or two-qubit proportional-Pauli Kraus branches; stochastic shots |
| Prepared execution and estimation | Single dense CPU state | Unsupported | Unsupported |
| Batch state containers | Supported | Not established | Not established |
| Analytic/finite-shot gradient methods | Dense supported domains; query `supports_gradient` | Pure-state scalar objectives tested with `ParameterShift`, `FiniteDifference` and `NoTruncation`; native adjoint not established | Not established |

Prebuilt plans and batch or gradient APIs should not be inferred from basic
gate support. Individual operations may reject invalid positions, unsupported
states, or incompatible options even if their general category is supported.
The cross-backend contract test below covers the common subset. Companion
integration coverage is maintained in `MOSSQuantumMPS/test/moss_integration.jl` and
`MOSSQuantumStabilizer/test/runtests.jl`; dense execution, estimation, noise and
capability coverage is in `MOSSQuantum/test/unit/`.

## Query a particular circuit

```julia
using MOSSQuantum

initial = StateVector(2)
circuit = QCircuit([HGate(1), CNOTGate(1, 2)])
report = execution_capability(CPUBackend(), circuit, initial; mode=:execute)
report.status            # :supported, :unsupported, or :unknown
report.issues            # reasons and nested instruction paths
report.final_state_types # possible types if statically known
```

[`examples/backend_selection.jl`](../examples/backend_selection.jl) runs the
same circuit using the three CPU backend families in one environment.

Modes are `:apply`, `:simulate`, `:execute`, and `:estimate`; the estimation
mode also takes `observable` and `shots`. A query examines circuit
structure, supported state transitions and execution options without evolving
the state or consuming random numbers. It checks both conditional branches.
It does not certify data-dependent conditions such as normalization or a
nonzero post-selection probability. An unexpanded `noise_model` is reported
as unknown without running its factories. Existing `supports`, `supports_gradient`,
and `validate_backend_execution` retain their original contracts.

External backends may declare the mode and state transitions using
`execution_capability_backend` and `execution_capability_step`. An undeclared
capability is `:unknown`; this does not change the execution behavior of an
existing extension. The hooks and terminal-sampling extension points are
documented in their Julia docstrings.

## Cross-backend contract checks

The optional test `test/cross_backend/runtests.jl` exercises the shared dense,
MPS and stabilizer subset, including state ownership, requested bit order,
seeded execution, measurements, feedback, rejection and readout. Run it in an
environment where all three local packages have been developed, for example:

```julia
using Pkg
Pkg.activate("/path/to/backend-test-env")
Pkg.develop([
    PackageSpec(path="/path/to/MOSSQuantum"),
    PackageSpec(path="/path/to/MOSSQuantumMPS"),
    PackageSpec(path="/path/to/MOSSQuantumStabilizer"),
])
include("/path/to/MOSSQuantum/test/cross_backend/runtests.jl")
```

Each companion also owns tests for its individual capabilities and rejection
boundaries. Cross-backend tests establish implementation contracts on small
examples; they are not runtime approximation diagnostics.
