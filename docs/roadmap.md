# MOSS core foundation roadmap

The foundation work establishes maintainable source ownership, consistent physical definitions, and public interfaces for companion packages. Directory migration, numerical changes, optional integrations, and external-package verification are reviewed independently.

## Stages and acceptance criteria

| Stage | Scope | Current status | Acceptance criteria |
| --- | --- | --- | --- |
| 1 Baseline | Namespaces, exports, conventions, tests, benchmarks | Verified | Standard package loading; compatibility snapshot; documented conventions and repeatable benchmark entrypoints |
| 2 Directories | Source/test layout, filenames, include entrypoints | Verified | Includes resolve; all existing assertions pass; namespace and binding identity are preserved |
| 3 Responsibilities | Descriptions, execution, kernels, observables, reverse passes, utility imports | Verified locally | Explicit dependency direction; a single owner for public functions; Utilities and optional AD registrations separated |
| 4 Numerical semantics | Squared Uhlmann fidelity and two-sided mixed-state evolution | Verified locally | Analytic, representation-equivalence, noncommuting, rank-deficient, trace, Hermiticity, and positivity checks |
| 5 Extension contracts | Instructions, states, backend capabilities, binding, results, RNG | Verified locally | External types use public entrypoints; unsupported capabilities fail clearly; ownership, parameter order, readout axes, and RNG are tested |
| 6 Optional integrations | AD/plotting extensions, legacy bridge, test-only dependencies | Native path verified; legacy bridge simulated | Minimal and optional-integration environments load; both native extensions and the older Requires path are exercised on recorded Julia versions |
| 7 Independent extension and release preparation | Separate fixture package, CI, documentation, migration notes | Local acceptance verified; CI configured | Fixture resolves independently, imports MOSS normally, executes and observes without private kernels; final test results are recorded |

No release or publication is implied by these statuses. A benchmark harness is not a measured performance baseline. Julia compatibility declarations do not substitute for testing the declared versions.

## Implemented foundation

Source responsibilities now live in `api/`, `quantum_circuits/`, `states/`, `execution/`, `backends/cpu/`, `observables/`, `differentiation/`, `utilities/`, and `utils/`. Existing module names and re-exported function identities remain intact. Tests are grouped by purpose and use normal package loading.

Physical corrections establish squared Uhlmann fidelity across pure and mixed representations and `exp(tH)ρexp(conj(t)H)` for mixed-state evolution. The existing exponential-coefficient convention is retained; physical time requires `t=-im*τ`. Real-coefficient imaginary-time evolution is explicitly unnormalized. Ownership of existing constructors remains documented rather than silently changed.

The public foundation includes `AbstractInstruction`, `AbstractQuantumState`, backend selection and capability queries, backend execution/observation, `bind_parameters`, terminal probabilities/samples/counts, explicit execution RNGs, and single-trajectory simulation results with intermediate records. The independent `MOSSDemoBackend` fixture demonstrates an implicit state and a custom instruction without dense storage assumptions.

Zygote registrations and plotting integration have moved into optional extensions. The core retains its existing deterministic reverse-pass algorithms. Julia releases with native extensions use them; earlier supported releases use a Requires bridge. FiniteDifferences remains test-only.

## Follow-up work

The following features remain distinct follow-up changes:

1. Uniform constructor ownership and any additional mutation-return cleanup, with migration guidance.
2. A field-independent custom trainable-instruction protocol, shared symbolic parameter identity, and gradient accumulation for shared identities.
3. ChainRules registration, complete batch gradients, parameterized noise, and explicit differentiation capabilities for external backends.
4. Array-generic state storage, GPU kernels, reusable execution plans, and measured allocation/performance improvements.
5. Kraus trajectories, classical control, and richer experiment statistics when their concrete use cases are implemented.

The main package should keep the common contracts and CPU implementation. MPS, stabilizer simulation, continuous open-system solvers, algorithm workflows, error correction, chemistry, and external framework interoperability can consume those contracts from companion packages. Empty companion packages are not required to complete the core foundation.

## Verification record

The directory baseline passed `Pkg.test(; allow_reresolve=false)` on Julia 1.12.5 with four threads: 1169 existing assertions plus 349 public API compatibility assertions. The 1020 top-level source expressions were checked for equivalence across the move.

Foundation acceptance completed locally on 2026-10-16:

- Julia 1.12.5, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 1816 reported assertions across 30 testsets. This includes the existing suite and API snapshot, 64 physical-semantics assertions, 33 binding assertions, 104 RNG/readout/simulation assertions, 70 backend/independent-state assertions, 21 optional-integration/AD-capability assertions, and six fresh-process loading checks.
- The six loading scenarios cover the core alone, Zygote before/after MOSS, Plots before/after MOSS, and LaTeXStrings before MOSS and Plots. The core-only check confirms that AD, plotting, and finite-difference frameworks are not loaded.
- Julia 1.12.5, one thread: 266 focused physical-semantics, binding, readout/simulation, and backend assertions passed. The five additional accumulated-drift assertions were added afterward and passed in the final four-thread suite.
- The independent `MOSSDemoBackend` package resolved against the checkout and passed standard `Pkg.test` with 9 assertions each on Julia 1.10.10 and 1.12.5. On Julia 1.13.1 it resolved and passed the same 9 assertions with `--compiled-modules=no`; normal native precompilation could not complete because LLVM reported `No space left on device` in the local environment.
- The Requires bridge was exercised in a compatibility snapshot with the legacy branch explicitly enabled under Julia 1.12.5, including optional loading orders and AD/plotting behavior. This is a bridge check, not an execution on Julia 1.6.

CI is configured for Julia 1.6 with one thread, Julia 1.10 and the latest stable Julia with four threads, core-only loading, optional loading orders, and independent extension resolution. Julia 1.6 has not been run locally, and the remote CI workflow has not been executed as part of this local acceptance.

BenchmarkTools workloads are supplied in a separate environment. Warmed performance measurements have not yet been recorded. Compare concrete workloads with the same Julia version, dependencies, hardware, thread count, and inputs; do not count dependency downloads or package precompilation as warmed execution time.
