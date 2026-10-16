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

The public foundation includes `AbstractInstruction`, `AbstractQuantumState`, backend selection and capability queries, backend execution/observation, `bind_parameters` with explicit `ParameterMap` sharing and gradient accumulation, terminal probabilities/samples/counts, explicit execution RNGs, and single-trajectory simulation results with intermediate records. The independent `MOSSDemoBackend` fixture demonstrates an implicit state and a custom instruction without dense storage assumptions.

Zygote registrations and plotting integration have moved into optional extensions. The core retains its existing deterministic reverse-pass algorithms. All supported Julia releases use native package extensions; the Requires bridge is removed under the Julia 1.10 minimum policy. FiniteDifferences remains test-only.

## Current milestone: shared parameter maps and gradient accumulation

This milestone adds explicit shared-value semantics to the public parameter foundation. The implementation stays in the main package so companion packages can use the same slot ordering and gradient reduction. All four implementation and acceptance steps are complete:

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Parameter identity | An immutable `ParameterMap` assigns each active slot an explicit integer identity | Stable index order, independent input ownership, empty/identity maps, and clear invalid-identity errors | Verified locally |
| 2 Shared binding | `bind_parameters(template, values, map)` expands independent values into active slots through existing public writers | Nested/frozen/adjoint/immutable instructions work; templates and inputs remain independent; legacy default binding and reset semantics pass unchanged | Verified locally |
| 3 Gradient accumulation | Public slot-gradient reduction and optional Zygote binding rules sum each shared identity's contributions | Analytic, finite-difference, per-slot, mixed-state, fixed-channel, and input-projection checks agree | Verified locally |
| 4 Independent extension acceptance | The external trainable-gate fixture performs a shared-parameter optimization update | Standalone fixture tests and full Julia 1.10/1.13 suites, including fresh-process loading checks, pass | Verified locally |

Maps are separate metadata rather than changes to the circuit representation. `[1, 2, 1]` binds two independent values into three active slots; repeated identities share values while mutable gate storage stays independent. Map indices follow the current `active_parameters` traversal. Binding validates the slot count, but changes to activation or instruction order with the same count require the caller to rebuild or review the map.

This milestone covers explicit integer identities and the existing deterministic dense CPU gradient path. Symbolic expressions, automatic identity tracking through circuit edits, new AD frameworks, batch gradients, trainable noise, and arbitrary-backend differentiation remain separate work. Final local acceptance results are recorded below.

## Completed milestone: API ownership and trainable extensions

This milestone makes the existing core contracts usable by a trainable companion package. Work proceeds through three independently reviewable steps:

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Ownership and containers | Add explicit constructor copy controls while retaining historical defaults; make circuit container mutators return the circuit | Aliasing and mutation-propagation checks across dense states and circuits; invalid appends leave the circuit unchanged; existing numerical behavior passes | Verified locally |
| 2 Public parameter protocol | Public instruction reset and independent copy hooks; bind and recursively retain replacement instructions, including immutable instructions and adjoint wrappers | No private reset hooks required by an extension; nested/repeated/frozen parameters, finite-value and dimension validation, independent source and result | Verified locally |
| 3 Trainable companion acceptance | An independent fixture defines its own parameterized unitary gate and completes a CPU training step through public methods | Binding, execution, expectation, and optional Zygote gradients agree with analytic and finite-difference results; standalone package tests and full Julia 1.10/1.13 tests pass | Verified locally |

Legacy constructor sharing remains the default; explicit copy controls document when conversion can still allocate. Mutable built-in parameter reset continues to update existing gate objects. Reset, activation, and deactivation methods may return a replacement instruction; callers retain that result, as they already do for state execution. The independently bound result has separate mutable data for each instruction occurrence.

The optional Zygote rules accept the new constructor keywords and preserve cotangents through state-to-state construction and `copy(state)`. Constructor gradients are checked across copy choices, real and complex domains, typed conversion, and vector/matrix density inputs. The external gate's `differentiate` implementation follows the existing `(∂U/∂θ)' * U` convention; no reverse-pass algorithm change is required.

The first differentiable extension uses the existing dense CPU reverse pass for deterministic unitary circuits. Shared symbolic parameters, new AD frameworks, batch gradients, trainable noise, and gradients for arbitrary backends remain separate follow-up work.

All three steps passed local acceptance. [Ownership and migration conventions](conventions.md#copying-and-storage-ownership) and the [extension guide](extending.md#parameters-and-differentiation) describe the completed contracts. Final assertion counts and independent-package results are recorded below.

## Follow-up work

The following features remain distinct follow-up changes:

1. ChainRules registration and explicit differentiation capabilities for external backends.
2. Complete batch gradients and parameterized noise.
3. Array-generic state storage, GPU kernels, reusable execution plans, and measured allocation/performance improvements.
4. Kraus trajectories, classical control, and richer experiment statistics when their concrete use cases are implemented.
5. Companion frontends for symbolic parameter expressions and names, consuming the explicit parameter-map contracts.

The main package should keep the common contracts and CPU implementation. MPS, stabilizer simulation, continuous open-system solvers, algorithm workflows, error correction, chemistry, and external framework interoperability can consume those contracts from companion packages. Empty companion packages are not required to complete the core foundation.

## Verification record

### Shared parameter-map acceptance

Local acceptance completed on 2026-10-16 with normal compiled-module loading and precompilation:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 2650 reported assertions across 39 testsets.
- Julia 1.10.10, one thread: a new independent environment developed the checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with all 2650 reported assertions across 39 testsets. Dependencies were resolved without using the development Manifest.
- The 247 added assertions cover parameter-map contracts (107), shared circuit gradients (40), and shared identities in the external immutable-gate fixture (100). Checks include noncommuting analytic circuits, finite differences, adjoint cancellation, pure/mixed inputs, fixed channels, Float32 values, views, empty maps, and source/input independence.
- Each full run passed all six fresh-process native-extension loading scenarios. Existing default binding, mutable reset, execution, and numerical regressions also passed.
- New independent fixture environments resolved against the actual checkout and passed standard `Pkg.test` on each of Julia 1.10.10 and 1.13.1: `MOSSDemoBackend` passed 9 assertions per version; `MOSSDemoGates` passed 181 per version, comprising its original 81 checks and 100 explicit-sharing checks.
- The README mapping/gradient example and the extension guide's external-gate sharing example ran successfully in a separate Julia 1.13.1 environment. Local documentation links and package metadata were checked.

The existing CI matrix covers the new main-suite and fixture checks on Julia 1.10 and 1.13. Remote CI was not run during this local acceptance. Runtime dependencies and the checked-in development Manifest remain unchanged.

### API ownership and trainable-extension acceptance

Local acceptance completed on 2026-10-16 with normal compiled-module loading and precompilation:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 2403 reported assertions across 36 testsets.
- Julia 1.10.10, one thread: an independent environment developed the checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with all 2403 reported assertions across 36 testsets. Dependencies were resolved independently of the development Manifest.
- The 587 added assertions cover ownership/container behavior (154), public parameter protocols (76), constructor and state-copy gradients (276), and the external immutable trainable gate (81). Existing numerical, execution, public API, and optional-integration checks also passed.
- Each full run passed the six fresh-process native-extension loading scenarios: the core alone, Zygote before/after MOSS, Plots before/after MOSS, and LaTeXStrings before MOSS and Plots.
- Separate environments resolved each fixture against the real checkout and passed standard `Pkg.test` on both Julia versions: `MOSSDemoBackend` passed 9 assertions per version; `MOSSDemoGates` passed 81 per version. The latter validates analytic and finite-difference gradients, a loss-reducing parameter update, immutable replacements, and fixed-channel gradients without private MOSS hooks.

CI now tests both independent fixtures on Julia 1.10 and 1.13, in addition to the main one-thread/four-thread matrix. Remote CI was configured but has not been run as part of this local acceptance. Runtime dependencies and the checked-in development Manifest did not change in this milestone.

### Version-policy migration acceptance

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
