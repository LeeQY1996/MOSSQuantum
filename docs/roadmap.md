# MOSS core foundation roadmap

The foundation work establishes maintainable source ownership, consistent physical definitions, and public interfaces for companion packages. Directory migration, numerical changes, optional integrations, and external-package verification are reviewed independently.

## Supported Julia versions

MOSS requires Julia 1.10 or later. Julia 1.13 is the primary development and acceptance version, with Julia 1.10 covering the minimum supported version. Every supported version uses native package extensions. The Requires bridge has been removed. Local acceptance for this version-policy migration passed on Julia 1.13.1 and Julia 1.10.10; historical Julia 1.12 results are retained separately below.

## Stages and acceptance criteria

| Stage | Scope | Current status | Acceptance criteria |
| --- | --- | --- | --- |
| 1 Baseline | Namespaces, exports, conventions, tests, benchmarks | Verified | Standard package loading; compatibility snapshot; documented conventions and repeatable benchmark entrypoints |
| 2 Directories | Source/test layout, filenames, include entrypoints | Verified | Includes resolve; all existing assertions pass; namespace and binding identity are preserved |
| 3 Responsibilities | Descriptions, execution, kernels, observables, reverse passes, utility imports | Verified locally | Explicit dependency direction; a single owner for public functions; Utilities and optional AD registrations separated |
| 4 Numerical semantics | Squared Uhlmann fidelity and two-sided mixed-state evolution | Verified locally | Analytic, representation-equivalence, noncommuting, rank-deficient, trace, Hermiticity, and positivity checks |
| 5 Extension contracts | Instructions, states, backend capabilities, binding, results, RNG | Verified locally | External types use public entrypoints; unsupported capabilities fail clearly; ownership, parameter order, readout axes, and RNG are tested |
| 6 Optional integrations | Native AD/plotting extensions and test-only dependencies | Verified locally on Julia 1.10/1.13 | Minimal and optional-integration environments load and native extension loading orders pass on the minimum and primary versions |
| 7 Independent extension and release preparation | Separate fixture package, CI, documentation, migration notes | Local acceptance verified; CI configured for Julia 1.10/1.13 | Fixture resolves independently, imports MOSS normally, executes and observes without private kernels; Julia 1.10/1.13 final results are recorded |

No release or publication is implied by these statuses. A benchmark harness is not a measured performance baseline. Julia compatibility declarations do not substitute for testing the declared versions.

## Implemented foundation

Source responsibilities now live in `api/`, `quantum_circuits/`, `states/`, `execution/`, `backends/cpu/`, `observables/`, `differentiation/`, `utilities/`, and `utils/`. Existing module names and re-exported function identities remain intact. Tests are grouped by purpose and use normal package loading.

Physical corrections establish squared Uhlmann fidelity across pure and mixed representations and `exp(tH)ρexp(conj(t)H)` for mixed-state evolution. The existing exponential-coefficient convention is retained; physical time requires `t=-im*τ`. Real-coefficient imaginary-time evolution is explicitly unnormalized. Ownership of existing constructors remains documented rather than silently changed.

The public foundation includes `AbstractInstruction`, `AbstractQuantumState`, backend selection and capability queries, backend execution/observation, `bind_parameters`, terminal probabilities/samples/counts, explicit execution RNGs, and single-trajectory simulation results with intermediate records. The independent `MOSSDemoBackend` fixture demonstrates an implicit state and a custom instruction without dense storage assumptions.

Zygote registrations and plotting integration have moved into optional extensions. The core retains its existing deterministic reverse-pass algorithms. All supported Julia releases use native package extensions; the Requires bridge is removed under the Julia 1.10 minimum policy. FiniteDifferences remains test-only.

## Follow-up work

The following features remain distinct follow-up changes:

1. Uniform constructor ownership and any additional mutation-return cleanup, with migration guidance.
2. A field-independent custom trainable-instruction protocol, shared symbolic parameter identity, and gradient accumulation for shared identities.
3. ChainRules registration, complete batch gradients, parameterized noise, and explicit differentiation capabilities for external backends.
4. Array-generic state storage, GPU kernels, reusable execution plans, and measured allocation/performance improvements.
5. Kraus trajectories, classical control, and richer experiment statistics when their concrete use cases are implemented.

The main package should keep the common contracts and CPU implementation. MPS, stabilizer simulation, continuous open-system solvers, algorithm workflows, error correction, chemistry, and external framework interoperability can consume those contracts from companion packages. Empty companion packages are not required to complete the core foundation.

## Verification record

### Current version-policy migration

Local acceptance completed on 2026-10-16:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 1816 reported assertions across 30 testsets. MOSS and both optional integration extensions precompiled normally; compiled modules were enabled. A separate core-only loading check also passed without loading the optional frameworks.
- Julia 1.10.10, one thread: a fresh environment developed the checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with all 1816 reported assertions across 30 testsets. Dependencies were resolved for Julia 1.10 independently of the development Manifest. Initially missing public test dependencies were installed before this successful run.
- Both full runs passed six fresh-process scenarios: the core alone, Zygote before/after MOSS, Plots before/after MOSS, and LaTeXStrings before MOSS and Plots. These exercise native extension activation and confirm that loading the core does not load the optional frameworks.
- The independent `MOSSDemoBackend` fixture resolved against the real checkout and passed standard `Pkg.test` with 9 assertions on each of Julia 1.10.10 and Julia 1.13.1, using normal precompilation.

The checked-in development Manifest was regenerated by Julia 1.13.1. Both CI jobs explicitly test Julia 1.10 and Julia 1.13; the main suite uses one and four threads respectively. The remote CI workflow has not been executed as part of this local acceptance.

### Historical foundation acceptance

The following results predate the Julia 1.10 minimum / Julia 1.13 primary policy and are retained as history.

The directory baseline passed `Pkg.test(; allow_reresolve=false)` on Julia 1.12.5 with four threads: 1169 existing assertions plus 349 public API compatibility assertions. The 1020 top-level source expressions were checked for equivalence across the move.

The earlier foundation acceptance completed locally on 2026-10-16:

- Julia 1.12.5, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 1816 reported assertions across 30 testsets. This includes the existing suite and API snapshot, 64 physical-semantics assertions, 33 binding assertions, 104 RNG/readout/simulation assertions, 70 backend/independent-state assertions, 21 optional-integration/AD-capability assertions, and six fresh-process loading checks.
- The six loading scenarios cover the core alone, Zygote before/after MOSS, Plots before/after MOSS, and LaTeXStrings before MOSS and Plots. The core-only check confirms that AD, plotting, and finite-difference frameworks are not loaded.
- Julia 1.12.5, one thread: 266 focused physical-semantics, binding, readout/simulation, and backend assertions passed. The five additional accumulated-drift assertions were added afterward and passed in the final four-thread suite.
- The independent `MOSSDemoBackend` package resolved against the checkout and passed standard `Pkg.test` with 9 assertions each on Julia 1.10.10 and 1.12.5. On Julia 1.13.1 it resolved and passed the same 9 assertions with `--compiled-modules=no`; normal native precompilation could not complete because LLVM reported `No space left on device` in the local environment.

The current version-policy results are recorded above. These older checks document the foundation before the minimum-version change.

BenchmarkTools workloads are supplied in a separate environment. Warmed performance measurements have not yet been recorded. Compare concrete workloads with the same Julia version, dependencies, hardware, thread count, and inputs; do not count dependency downloads or package precompilation as warmed execution time.
