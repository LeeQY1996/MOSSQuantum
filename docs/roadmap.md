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

## Completed milestone: dense pure-state batch workflows

Single states and batches retain separate types, `StateVector` and the existing
`BatchStateVector`, with common operation names. A batch of one retains its
sample axis. This milestone completes pure-state workflows before designing a
batch density-matrix representation.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Container contracts | Explicit dimensions, empty/zero-qubit batches, scalar promotion, input views, and mutation/ownership checks | Invalid inputs fail before changing data; sample axes remain stable | Verified locally |
| 2 Pure-state execution | Shared operator action, measurement, post-selection, recorded batch simulation, and per-sample partial trace | Dense references, seeded trajectories, nested circuits, readout axes, backend results, and independent reduced states | Verified locally |
| 3 Replaceable differentiation | Reduced `BatchExpectationObjective`, native CPU adjoint, optional legacy batch state/circuit/encoding rules | Analytic and finite-difference agreement, shared-parameter sums, weighted reductions, independent repeated pullbacks; execution remains usable without AD | Verified locally |
| 4 Compatibility and measurement | Minimum/primary full suites, independent companions, fresh-process loading, and a batch benchmark | Julia 1.10/1.13 acceptance and reproducible batch-versus-loop timing/allocation records | Verified locally |

The [batch guide](batching.md) documents axes, ownership, scalar reductions,
measurement records, and gradient boundaries. CPU batch unitary execution and
reverse passes share numerical helpers across explicit and optional AD APIs.
Forward capabilities and gradient capabilities remain independent. This stage
does not add channels on batches, stochastic derivatives, per-sample circuit
parameters, or batch density matrices. Partial trace returns a vector of ordinary
density matrices.

## Completed milestone: repeated evaluation and first measured optimization

This milestone measures the new scalar interfaces before extending execution machinery. It retains independent execution and gradient selection, and leaves additional gradient algorithms for later work.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Performance baseline | An independent core-only benchmark entrypoint, with optional AD workloads and separate preparation/application measurements | Pure, mixed, fixed-channel, and shared-parameter cases; time, allocation, first-call/warmed phases, reproducible environment and source metadata | Verified locally |
| 2 Execution ownership | Document per-call state/checkpoints, repeated pullbacks, independent tasks, and bound-parameter revalidation | Interleaved points and objective edits preserve earlier pullbacks; invalid bound gates fail before execution | Verified locally |
| 3 First CPU optimization | Remove the duplicate initial-state copy before the existing adjoint helper | Identical numerical behavior and unchanged validation; matched before/after allocation reductions with controls and a paired repetition | Verified locally |
| 4 Compatibility | Full minimum/primary-version suites, independent fixtures, and core/AD benchmark smoke checks | Julia 1.10/1.13 pass; CI checks the harness without performance thresholds | Verified locally |

The [measurement report](performance/repeated-evaluation-2026-10-19.md) retains every trial table, source and environment hashes, the resolved benchmark Manifest, and the source patch. Eight-qubit mixed-state pullback preparation allocates 1,405,832 bytes instead of 2,454,480 bytes, a 42.72% reduction. Complete explicit gradients save the same 1,048,648 bytes. Unchanged operations exhibit elapsed-time drift; the report makes no general throughput claim.

The result needs no persistent objective cache or new public execution-plan interface. Each prepared pullback keeps its own bound circuit and saved state, while current template and bound-value checks remain intact. Dedicated backend workspaces and compilation can be designed after measurements identify another concrete need.

## Completed milestone: replaceable differentiation and optional AD

This milestone implements the existing automatic-differentiation path while keeping execution independent of the selected gradient method. Additional finite-difference, parameter-shift, and stochastic estimators will be designed separately; no such algorithms are introduced here.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Independent objectives | Public `evaluate` and a snapshot-owning `ExpectationObjective` adapter | Forward evaluation runs without AD packages or a gradient method, including explicit backend selection | Verified locally |
| 2 Numerical gradient protocol | Replaceable `AbstractGradientMethod`, capability queries, value/gradient and pullback hooks, and the existing CPU `AdjointGradient` | Public hooks work without an AD framework; scalar, parameter-order, ownership, and unsupported-capability contracts are tested | Verified locally |
| 3 Optional AD adapter | A ChainRulesCore extension for explicit-method `differentiable_value` | Correct zero/thunk/domain/type handling, selected-method dispatch, and coexistence with legacy Zygote rules | Verified locally |
| 4 Independent companion acceptance | A separate package replaces its executor and numerical gradient method | No state/storage inheritance required; core-only, direct ChainRules, Zygote, and full Julia 1.10/1.13 acceptance pass | Verified locally |

Only the explicit real parameter vector is differentiated by the new scalar entrypoint. The objective and method are fixed configuration. `evaluate` selects no derivative algorithm; external objectives and methods use public multiple dispatch rather than private CPU hooks. `ExpectationObjective` is one concrete adapter, not a required base type for future laboratory or hardware integrations.

The CPU method reuses existing deterministic unitary/fixed-channel reverse passes and shared-parameter accumulation. It does not call Zygote internally. ChainRulesCore remains optional, and existing Zygote circuit APIs remain available. All four steps passed local acceptance; final results are recorded below.

## Completed milestone: shared parameter maps and gradient accumulation

This milestone adds explicit shared-value semantics to the public parameter foundation. The implementation stays in the main package so companion packages can use the same slot ordering and gradient reduction. All four implementation and acceptance steps are complete:

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Parameter identity | An immutable `ParameterMap` assigns each active slot an explicit integer identity | Stable index order, independent input ownership, empty/identity maps, and clear invalid-identity errors | Verified locally |
| 2 Shared binding | `bind_parameters(template, values, map)` expands independent values into active slots through existing public writers | Nested/frozen/adjoint/immutable instructions work; templates and inputs remain independent; legacy default binding and reset semantics pass unchanged | Verified locally |
| 3 Gradient accumulation | Public slot-gradient reduction and optional Zygote binding rules sum each shared identity's contributions | Analytic, finite-difference, per-slot, mixed-state, fixed-channel, and input-projection checks agree | Verified locally |
| 4 Independent extension acceptance | The external trainable-gate fixture performs a shared-parameter optimization update | Standalone fixture tests and full Julia 1.10/1.13 suites, including fresh-process loading checks, pass | Verified locally |

Maps are separate metadata rather than changes to the circuit representation. `[1, 2, 1]` binds two independent values into three active slots; repeated identities share values while mutable gate storage stays independent. Map indices follow the current `active_parameters` traversal. Binding validates the slot count, but changes to activation or instruction order with the same count require the caller to rebuild or review the map.

This milestone covers explicit integer identities and the existing deterministic dense CPU gradient path. At that milestone, symbolic expressions, automatic identity tracking through circuit edits, new AD frameworks, batch gradients, trainable noise, and arbitrary-backend differentiation remained separate work; pure-state batch gradients are implemented in the later batch milestone above. Final local acceptance results are recorded below.

## Completed milestone: API ownership and trainable extensions

This milestone makes the existing core contracts usable by a trainable companion package. Work proceeds through three independently reviewable steps:

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Ownership and containers | Add explicit constructor copy controls while retaining historical defaults; make circuit container mutators return the circuit | Aliasing and mutation-propagation checks across dense states and circuits; invalid appends leave the circuit unchanged; existing numerical behavior passes | Verified locally |
| 2 Public parameter protocol | Public instruction reset and independent copy hooks; bind and recursively retain replacement instructions, including immutable instructions and adjoint wrappers | No private reset hooks required by an extension; nested/repeated/frozen parameters, finite-value and dimension validation, independent source and result | Verified locally |
| 3 Trainable companion acceptance | An independent fixture defines its own parameterized unitary gate and completes a CPU training step through public methods | Binding, execution, expectation, and optional Zygote gradients agree with analytic and finite-difference results; standalone package tests and full Julia 1.10/1.13 tests pass | Verified locally |

Legacy constructor sharing remains the default; explicit copy controls document when conversion can still allocate. Mutable built-in parameter reset continues to update existing gate objects. Reset, activation, and deactivation methods may return a replacement instruction; callers retain that result, as they already do for state execution. The independently bound result has separate mutable data for each instruction occurrence.

The optional Zygote rules accept the new constructor keywords and preserve cotangents through state-to-state construction and `copy(state)`. Constructor gradients are checked across copy choices, real and complex domains, typed conversion, and vector/matrix density inputs. The external gate's `differentiate` implementation follows the existing `(∂U/∂θ)' * U` convention; no reverse-pass algorithm change is required.

The first differentiable extension uses the existing dense CPU reverse pass for deterministic unitary circuits. Shared symbolic parameters, new AD frameworks, batch gradients, trainable noise, and gradients for arbitrary backends were separate follow-up work at that stage; later milestones above add explicit parameter sharing and pure-state batch gradients.

All three steps passed local acceptance. [Ownership and migration conventions](conventions.md#copying-and-storage-ownership) and the [extension guide](extending.md#parameters-and-differentiation) describe the completed contracts. Final assertion counts and independent-package results are recorded below.

## Follow-up work

The following features remain distinct follow-up changes:

1. Design additional numerical gradient methods through the new protocol, including finite differences, parameter shift, and stochastic estimators.
2. Design batch density matrices and their noise/gradient contracts, then parameterized noise.
3. Array-generic state storage, GPU kernels, reusable execution plans, and measured allocation/performance improvements.
4. Kraus trajectories, classical control, and richer experiment statistics when their concrete use cases are implemented.
5. Companion frontends for symbolic parameter expressions and names, consuming the explicit parameter-map contracts.
6. Broader ChainRules coverage and migration of legacy circuit/state derivative entrypoints after their tangent contracts are explicitly defined.

The main package should keep the common contracts and CPU implementation. MPS, stabilizer simulation, continuous open-system solvers, algorithm workflows, error correction, chemistry, and external framework interoperability can consume those contracts from companion packages. Empty companion packages are not required to complete the core foundation.

## Verification record

### Dense pure-state batch workflows

Local acceptance completed on 2026-10-19:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed 4365 assertions across 56 top-level testsets, including all eight fresh-process loading scenarios (64.6 seconds for that group).
- Julia 1.10.10, one thread: an independently resolved environment developed the actual checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with 4365 assertions across 56 top-level testsets and all eight fresh-process loading scenarios (52.1 seconds for that group). Every testset name and assertion count matches the Julia 1.13 run.
- The 1008 additional assertions cover container/operator/partial-trace contracts (120), measurement/post-selection/recorded simulation (482), scalar batch objectives (171), legacy circuit/state/encoding gradients (233), and two additional capability checks. They include B=0/1, zero-qubit registers, aliased encoding views, atomic failure, sample order, complex domains, shared parameters, weighted reductions, explicit backend boundaries, and private reusable pullbacks.
- Independent standard fixture `Pkg.test` passed on both versions: `MOSSDemoBackend` 9 assertions, `MOSSDemoGates` 181, and `MOSSDemoDifferentiation` 235 per version. The external trainable gate now checks its shared pure-state batch circuit gradient against its analytic reference.
- README and batch-guide examples passed in four fresh processes: Julia 1.10/1.13, each in core and optional Zygote modes. Core examples confirmed that neither ChainRulesCore nor Zygote was loaded.
- The new batch benchmark passed depth-two small harness checks on both versions in separate core/optional AD processes, producing 18/21 warmed rows. These checks exercise 8 active slots sharing 4 independent parameters across B=1/4/16.
- The [batch measurement report](performance/batch-evaluation-2026-10-19.md) retains 54 first-call/warmed summaries from sequential one/four-thread six-qubit runs, unchanged raw tables/metadata, and the resolved benchmark Manifest. Every source/environment/script hash and reported table entry was checked independently. B=1 overhead and the lack of consistent thread scaling are recorded alongside B=4/16 loop comparisons.
- Markdown links, anchors and fences, TOML files, source/artifact hashes, and whitespace checks passed. CI now checks the new batch harness in small core/AD processes; remote CI has not been run.

Main-package dependencies and the development Manifest are unchanged. The existing `BatchStateVector` name and historical copy defaults are retained. Single states and batches remain separate types, and execution does not require an AD framework or select a gradient method. No batch density representation, batch channels, stochastic derivatives, or additional numerical estimators are introduced.

### Repeated evaluation and first CPU allocation optimization

Local acceptance completed on 2026-10-19:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed 3357 assertions across 45 top-level testsets, including all eight fresh-process loading scenarios (45.7 seconds for that group).
- Julia 1.10.10, one thread: an independent environment developed the actual checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with 3357 assertions across 45 top-level testsets and all eight fresh-process loading scenarios (48.8 seconds for that group).
- The 151 additional lifecycle assertions bring the CPU objective group to 310. They cover pure/mixed inputs with and without fixed channels, shared parameters, interleaved points, independent concurrent pullbacks, returned-gradient and initial-state ownership, objective edits, and parameter-dependent invalid matrices or derivatives rejected before execution.
- Standard independent fixture `Pkg.test` passed on both versions: `MOSSDemoBackend` 9 assertions, `MOSSDemoGates` 181, and `MOSSDemoDifferentiation` 235 per version.
- Both versions passed the new benchmark entrypoint in four isolated compatibility processes: core mode produced 32 first-call/warmed summary rows with neither AD package loaded; optional AD mode produced 40 rows and matched the explicit numerical gradient method. The two-qubit, two-layer cases exercise actual cross-layer parameter sharing.
- Six benchmark tables retain 128 first-call/warmed summaries from six/eight-qubit before/after runs and an additional paired eight-qubit repetition. The 48 paired warmed comparisons use identical scripts and resolved environments. Independent review matched baseline source hashes to `e132ca0`, optimized hashes to revision `642cab7`, and the sole source change to the archived patch. Allocation controls and both eight-qubit repetitions agree exactly; no general elapsed-time improvement is claimed.
- The [performance report](performance/repeated-evaluation-2026-10-19.md) retains the data and resolved benchmark Manifest. Documentation links, code fences, TOML metadata, and whitespace checks passed. CI now checks the independent benchmark harness on Julia 1.10 and 1.13 without timing thresholds; remote CI has not been run.

Main-package dependencies, its development Manifest, and public API signatures are unchanged. BenchmarkTools remains in the independent benchmark environment; only benchmark metadata stdlibs were added there. The optimization removes a redundant copy, keeps all parameter-dependent validation, and adds no persistent cache or mandatory backend interface.

### Replaceable differentiation and optional AD acceptance

Local acceptance completed on 2026-10-19 with normal compiled-module loading and precompilation:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed all 3206 reported assertions across 45 testsets.
- Julia 1.10.10, one thread: a new independent environment developed the checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with all 3206 reported assertions across 45 testsets. Dependencies were resolved separately from the development Manifest.
- The 556 added assertions cover the numerical protocol (36), CPU scalar objectives and adjoints (159), direct ChainRules and AD contracts (132), external objective/method contracts (227), and two additional parent loading checks. Coverage includes shared/nested/frozen parameters, pure/mixed states and fixed channels, repeated pullbacks, parameter-domain snapshots after caller resizing, zero/thunk cotangents, type/domain projection, and unsupported combinations.
- Each full run passed eight fresh-process scenarios: core only, ChainRulesCore before/after MOSS without Zygote, Zygote before/after MOSS, Plots before/after MOSS, and LaTeXStrings before MOSS and Plots. Legacy Zygote and the new scalar rule coexist.
- Independent fixture `Pkg.test` passed on both Julia versions: `MOSSDemoBackend` 9 assertions per version, `MOSSDemoGates` 181 per version, and `MOSSDemoDifferentiation` 235 per version. The new fixture's isolated phases confirm execution without AD dependencies and direct ChainRules use without Zygote, as well as replacing the executor and numerical method independently.
- The README's new examples ran in a fresh process: core evaluation and explicit numerical gradients first, with neither ChainRulesCore nor Zygote loaded, followed by the example's `using Zygote` and equivalent AD gradient. Documentation link targets, fences, and package TOML metadata were checked.

The core's hard dependencies did not change. ChainRulesCore 1.26 is an optional weak dependency and test extra; the development Manifest was refreshed only for the corresponding project hash and extension metadata. Explicit-backend `QubitsOperator` register validation is also covered by the CPU objective checks. CI now resolves all three fixtures independently on Julia 1.10/1.13. Remote CI has not been run as part of this local acceptance.

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

BenchmarkTools workloads are supplied in a separate environment. The repeated-evaluation report above records a measured allocation improvement; the older foundation stage supplied only a harness. Compare concrete workloads with the same Julia version, dependencies, hardware, thread count, and inputs; do not count dependency downloads or package precompilation as warmed execution time.
