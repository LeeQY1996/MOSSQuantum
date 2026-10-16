# MOSS core foundation roadmap

The core foundation work makes MOSS easier to maintain and prepares public interfaces for additional simulators and application packages. Changes proceed in reviewable stages: directory moves preserve behavior, numerical fixes establish physical contracts, and extension protocols are added only when independent implementations can exercise them.

## Stages and acceptance criteria

| Stage | Scope | Status | Acceptance criteria |
| --- | --- | --- | --- |
| 1 Baseline | Public namespaces, API conventions, existing tests, and benchmark workloads | Verified | Normal package loading passes the existing suite; compatibility checks cover namespace identity and representative entrypoints; conventions and repeatable benchmark instructions exist |
| 2 Directories | Source and test folders, filenames, and include entrypoints | Verified | All includes resolve; existing tests pass after moves; signatures, algorithms, and dependencies retain their existing behavior |
| 3 Responsibilities | Description, execution, CPU kernels, observables, differentiation, and explicit utility imports | In progress | Function ownership is clear; operation descriptions do not require state or backend types; lower layers do not depend on Utilities; remaining coupling is recorded |
| 4 Numerical semantics | Fidelity, mixed-state evolution, ownership, parameter ordering, and mutation returns | Planned | Analytic examples and physical invariants pass; intentional behavior changes have migration notes |
| 5 Extension contracts | Executable operations, states, backend capabilities, parameter binding, results, and RNG | Planned | An external type executes through public entrypoints; unsupported capabilities fail clearly; protocol behavior is documented and tested |
| 6 Optional integrations | Plotting and AD integration boundaries; test-only dependencies | Planned | Minimum Julia version is decided explicitly; minimal and extension environments each load and pass their checks |
| 7 Independent extension and release | An external fixture package, reusable protocol checks, CI, and migration documentation | Planned | The fixture has its own `Project.toml`, imports MOSS normally, and executes and computes expectations without modifying MOSS sources or calling private kernels |

Completion status is updated after verification. A benchmark harness is not a recorded performance baseline until it has run on a documented environment. Existing Julia compatibility declarations are not evidence that every listed version has been tested.

## Current implementation scope

The first implementation batch covers stages 1 and 2 and the mechanical parts of stage 3: compatibility checks, source and test directory organization, package assembly, explicit dependency ownership, architecture documentation, and benchmark entrypoints.

The reorganization preserves the `MOSS`, `MOSS.QuantumCircuits`, `MOSS.QuantumCircuits.Gates`, and `MOSS.Utilities` namespaces. It does not introduce new simulation backends or change physical definitions.

## Numerical semantics work

The next stage prioritizes two known correctness problems:

1. Define fidelity consistently across pure and mixed representations, including noncommuting mixed states and rank-deficient inputs.
2. Define the time-evolution coefficient and physical-time convention, and implement physical density-matrix evolution on both sides.

Follow with explicit ownership rules, consistent mutation returns, parameter ordering tests, and normalization and dimension validation. Trace preservation, Hermiticity, positive semidefiniteness, state norm, and equivalent-representation checks belong in these tests when they are physical invariants of the operation.

## Extension contract work

Extension contracts should be small enough for an external implementation to satisfy without inheriting dense storage assumptions. The [extension guide](extending.md) separates current customization options from the planned protocols.

Implementation order:

1. Separate valid circuit instructions from the broader operation hierarchy and replace the closed instruction set with a tested extensibility mechanism.
2. Specify the minimum state and execution contracts, including ownership of returned states and backend capability errors.
3. Add independent parameter binding and define shared parameter identity and gradient accumulation.
4. Add an execution result, explicit RNG routing, probabilities, sampling, and counts with clear bit ordering.
5. Expose reverse-pass algorithms independently of AD registration, then add reusable protocol checks and the external fixture.

Batch gradients, trainable noise, quantum trajectories, GPU kernels, and execution-plan reuse can build on those contracts in subsequent scoped changes. They should not delay establishing the first usable extension boundary.

## Package boundaries

The main package retains operation descriptions, core state and execution contracts, the existing dense CPU implementation, observables, and core parameter and differentiation interfaces. GPU array support and plotting or training integrations can use optional integrations once the supported Julia version and loading mechanism are settled.

MPS, stabilizer simulation, continuous open-system solvers, specialized algorithm workflows, error correction, chemistry, and external framework formats have independent dependencies and semantics. They should consume MOSS interfaces from companion packages when concrete implementations justify the split. Creating empty companion packages is not a prerequisite for the core foundation work.

## Verification record

Run functional checks through the package entrypoint, keep plotting checks headless, and record the Julia version, thread count, test totals, and any environment restrictions with each implementation batch. Compare performance using the same Julia version, dependency environment, hardware, thread count, and benchmark inputs.

The benchmark harness deliberately has a separate environment. Package resolution, downloads, and first invocation latency must not be reported as warmed execution time. A performance regression should trigger investigation of a concrete workload before changing numerical kernels.

The directory baseline passed `Pkg.test(; allow_reresolve=false)` on Julia 1.12.5 with four threads: 1169 existing assertions and 349 public API compatibility assertions. The 1020 top-level source expressions were also checked for equivalence across the move. BenchmarkTools workloads are provided; warmed performance measurements have not yet been recorded.
