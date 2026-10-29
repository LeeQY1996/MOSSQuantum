# MOSSQuantum core foundation roadmap

The foundation work establishes maintainable source ownership, consistent physical definitions, and public interfaces for companion packages. Directory migration, numerical changes, optional integrations, and external-package verification are reviewed independently.

## Supported Julia versions

MOSSQuantum requires Julia 1.10 or later. Julia 1.13 is the primary development and acceptance version, with Julia 1.10 covering the minimum supported version. Every supported version uses native package extensions. The Requires bridge has been removed. Local acceptance for this version-policy migration passed on Julia 1.13.1 and Julia 1.10.10; historical Julia 1.12 results are retained separately below.

## Stages and acceptance criteria

| Stage | Scope | Current status | Acceptance criteria |
| --- | --- | --- | --- |
| 1 Baseline | Namespaces, exports, conventions, tests, benchmarks | Verified | Standard package loading; compatibility snapshot; documented conventions and repeatable benchmark entrypoints |
| 2 Directories | Source/test layout, filenames, include entrypoints | Verified | Includes resolve; all existing assertions pass; namespace and binding identity are preserved |
| 3 Responsibilities | Descriptions, execution, kernels, observables, reverse passes, utility imports | Verified locally | Explicit dependency direction; a single owner for public functions; Utilities and optional AD registrations separated |
| 4 Numerical semantics | Squared Uhlmann fidelity and two-sided mixed-state evolution | Verified locally | Analytic, representation-equivalence, noncommuting, rank-deficient, trace, Hermiticity, and positivity checks |
| 5 Extension contracts | Instructions, states, backend capabilities, binding, results, RNG | Verified locally | External types use public entrypoints; unsupported capabilities fail clearly; ownership, parameter order, readout axes, and RNG are tested |
| 6 Optional integrations | Native AD/plotting extensions and test-only dependencies | Verified locally on Julia 1.10/1.13 | Minimal and optional-integration environments load and native extension loading orders pass on the minimum and primary versions |
| 7 Independent extension and release preparation | Separate fixture package, CI, documentation, migration notes | Local acceptance verified; CI configured for Julia 1.10/1.13 | Fixture resolves independently, imports MOSSQuantum normally, executes and observes without private kernels; Julia 1.10/1.13 final results are recorded |

No release or publication is implied by these statuses. A benchmark harness is not a measured performance baseline. Julia compatibility declarations do not substitute for testing the declared versions.

## Implemented foundation

Source responsibilities now live in `api/`, `quantum_circuits/`, `states/`, `execution/`, `backends/cpu/`, `observables/`, `differentiation/`, `utilities/`, and `utils/`. Existing module names and re-exported function identities remain intact. Tests are grouped by purpose and use normal package loading.

Physical corrections establish squared Uhlmann fidelity across pure and mixed representations and `exp(tH)ρexp(conj(t)H)` for mixed-state evolution. The existing exponential-coefficient convention is retained; physical time requires `t=-im*τ`. Real-coefficient imaginary-time evolution is explicitly unnormalized. Ownership of existing constructors remains documented rather than silently changed.

The public foundation includes `AbstractInstruction`, `AbstractQuantumState`, backend selection and capability queries, backend execution/observation, `bind_parameters` with explicit `ParameterMap` sharing and gradient accumulation, terminal probabilities/samples/counts, explicit execution RNGs, and single-trajectory simulation results with intermediate records. The independent `MOSSQuantumDemoBackend` fixture demonstrates an implicit state and a custom instruction without dense storage assumptions.

Zygote registrations and plotting integration have moved into optional extensions. The core retains its existing deterministic reverse-pass algorithms. All supported Julia releases use native package extensions; the Requires bridge is removed under the Julia 1.10 minimum policy. FiniteDifferences remains test-only.

## Operator and finite-shot measurement foundation

The [operator and finite-shot measurement foundation](operators-and-measurement.md)
adds scalar/zero operator semantics, tensor-product algebra, exact term
simplification, repeated circuit execution with explicit post-selection
acceptance, and Pauli-group expectation estimates with standard errors.
Molecular chemistry will be implemented subsequently as a separate
`MOSSQuantumChemistry` companion, reusing these core interfaces.

## Gate-level noise simulation

The [noise simulation guide](noise-simulation.md) describes physical channel
validation, common one/two-qubit noise, explicit `NoiseModel` expansion, classical
readout errors, and CPU `KrausTrajectory` execution through `simulate`, `execute`
and `estimate`. Density-matrix evolution remains the default. Classical reported
outcomes are separate from physical collapse and post-selection acceptance.

| Stage | Delivered scope | Verification |
| --- | --- | --- |
| P0 Contracts | Physical parameter checks, optional TP check for general maps, owned Kraus inputs, stale-cache rejection | Constructor, precision, ownership and malformed-input tests |
| P1 Channels | Flip/Pauli, 1–2 qubit depolarizing, generalized damping, thermal relaxation, reset, mixed unitary | Analytic decay, equilibrium, positivity, position-order and batch references |
| P2 Readout | Non-symmetric one-qubit errors, correlated two-qubit terminal errors, physical/reported records | Exact distributions, correlated marginals, reset/selection semantics |
| P3 Configuration | Ordered before/after rules, preparation/terminal stages, explicit idle durations, inspectable expansion | Hand-written circuit equivalence, no implicit re-expansion |
| P4 Trajectories | CPU pure states/batches, independent shot paths, recorded execution and noisy estimates | Multiple-seed statistics, empirical estimator variance, RNG and backend boundaries |
| P5 Performance | Mixed-unitary branch shortcut, reusable trajectory buffers, threaded shots, streaming counts/statistics | [24-case CPU measurements](performance/noise-2026-10-28/README.md) |

Local acceptance on Julia 1.13.1 with four Julia threads passed standard
`Pkg.test(; test_args=["--load-orders"])`: **9,409 assertions in 107 reported
testsets**, including **419 new noise assertions** and eight fresh-process
optional-integration loading checks. The four fixture packages independently
passed **830 assertions**. All three Julia examples in the noise guide ran.
`git diff --check` passed. Julia 1.10 and remote CI were not rerun for this
milestone; GPU noise is neither implemented nor claimed by these CPU results.

Kraus trajectories require explicit method selection. Density input trajectories,
GPU noise, continuous-time Lindblad/non-Markovian dynamics,
leakage and trainable noise remain separate work. Measurement basis rotations
inside the estimator are ideal; classical readout errors are included afterward.

## CUDA device arrays and single-state execution

The first real-device companion is [MOSSQuantumCUDA](../packages/MOSSQuantumCUDA/README.md),
developed independently under `packages/MOSSQuantumCUDA`. It combines actual CUDA
device-memory arrays with an executor selected through the existing backend
protocol. The implementation targets NVIDIA CUDA; quantum hardware integration
is a separate direction.

| Step | Scope | Status |
| --- | --- | --- |
| Device storage | Explicit upload/download, direct zero-state allocation, CuVector routing, owned copies and precision conversions | Implemented; hardware acceptance pending |
| Single pure-state execution | Local 1–5-qubit gates, arbitrary position order, nested gate-only circuits, complete host preflight | Implemented; hardware acceptance pending |
| Observation and readout | Gate/term/operator expectations, GPU marginals with host distributions, terminal sampling and scalar objectives | Implemented; hardware acceptance pending |
| Verification | Independent host arithmetic tests, device suite with scalar access forbidden, strict `--require-gpu`, manual GPU workflow | Julia 1.10/1.13 host checks and offline PTX checks passed; hardware acceptance pending |
| Performance | Warmed CPU/GPU comparison separating execution, readout and explicit transfers | Harness provided; no measurements or speedup claims |

The companion synchronizes its CUDA work and owns scratch per invocation.
It does not introduce shared workspaces, persistent execution plans or an
automatic CPU fallback. Capability checks reject unsupported batch/density,
noise, measurement and gradient execution. Existing four-container storage
conversions remain distinct from execution capabilities.

Local verification on 2026-10-22 passed 154 companion host assertions on each
supported Julia version, 887 existing storage/backend assertions with the
companion loaded, and 45 offline gate-kernel PTX compilation configurations.
No GPU was available. The [validation record](../packages/MOSSQuantumCUDA/VALIDATION.md)
separates these checks from pending hardware execution and performance tests.

## Completed milestone: generic array containers and backend routing

The four existing dense state types now carry a concrete storage parameter.
Array inputs opt in through `preserve_storage=true`; ordinary constructors keep
historical CPU materialization and copy defaults. State-to-state construction,
owned copies, scalar-type conversion, and pure-to-mixed conversion retain the
selected family. This establishes a storage and dispatch foundation without
adding a hardware execution dependency.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Containers | Generic vector/matrix/three-dimensional backing arrays; vectorized single-density storage retained | One-based metadata checks, shape and batch boundaries, opt-in aliasing, owned copies, conversion, and extraction | Verified locally |
| 2 Execution boundary | Select a backend from storage; reject unsupported CPU layouts; route linear action and probabilities through backend hooks | No scalar indexing or implicit host transfer before rejection; representation transitions stay in the selected family | Verified locally |
| 3 Differentiation boundary | Keep optional constructor/copy rules and restrict native adjoints to supported CPU storage | Existing CPU gradients and input projection retained; external execution does not select a gradient method | Verified locally |
| 4 Companion proof | `MOSSQuantumDemoArrayBackend` uses the four containers and an array that forbids scalar access and host materialization | Independent package loading, gate/channel execution, observation, readout, objectives, and separately selected analytic method | Verified locally |
| 5 Compatibility | Full minimum/primary suites, independent packages, documentation, and CPU regression checks | Stable source, unchanged environments/scripts, all loading orders, and recorded allocation costs | Verified locally |

The [array extension guide](extending.md#preserve-array-storage) and
[ownership conventions](conventions.md#array-storage-and-execution-eligibility)
describe the public contracts and exact-type migration. The independent
[array fixture](../test/fixtures/MOSSQuantumDemoArrayBackend/README.md) demonstrates a
storage family and its executor through public methods. It is a CPU-backed
contract example; device kernels and actual GPU acceptance belong to subsequent
companion work. Final broad acceptance and allocation costs are retained in the
[regression report](performance/generic-storage-2026-10-20.md).

## Completed milestone: measured CPU batch allocation improvements

This milestone measures pure and mixed batch execution and reduces CPU
observation and reverse-pass allocations. Additional numerical gradient
estimators are deferred. It retains the existing execution, gradient-selection,
validation, ownership, and concurrency contracts.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Baseline | An independent pure/mixed/unitary/fixed-noise harness for B=1/4/16/64 | Matched source/environment metadata; separate gate, channel, observation, objective, gradient, and pullback measurements on one/four threads | Verified locally |
| 2 Allocation analysis | Inspect full gradient and pullback allocations before selecting changes | Attribute avoidable payload copies to concrete source locations | Verified locally |
| 3 Internal workspaces | Reuse density derivative scratch within one reverse invocation; reuse equal-seed observation actions and read short traces directly | Numerical/type/domain behavior unchanged; no retained mutable workspace or mandatory backend API | Verified locally |
| 4 Final comparison | Matched before/after trials, independent repeat, full suites and companion checks | Minimum/primary tests and source/provenance review pass; reported claims distinguish allocations from timings | Verified locally |

The [CPU batch report](performance/cpu-batch-2026-10-20.md) retains 884 warmed
summaries: 416 matched before/after pairs plus 26 independently confirmed pairs.
The baseline source is `cd127e6`; only three CPU observation/reverse-pass files
change. In the six-qubit, B=16, one-thread mixed unitary case, complete gradients
allocate 10,841,104 rather than 64,526,424 bytes (83.20% less), and a prepared
pullback allocates 8,099,920 rather than 59,667,152 bytes (86.42% less).

Two derivative buffers are reused within each reverse invocation. Short density
observables read sample views, and density observation pullbacks reuse a seeded
operator action for consecutive equal seeds within one call. Seeding occurs
before operator products to preserve precision and underflow behavior. Each
invocation owns its mutable buffers; execution and gradient-selection protocols
remain independent, with no new public workspace requirement. Gate/channel
kernels and scheduling retain their existing implementation. Timing results and
unchanged controls are recorded separately from allocation improvements.

## Completed milestone: dense batch density matrices

This milestone extends the separate-type design to `BatchDensityMatrix` in the
main package. Storage has axes `(2^n, 2^n, B)` and each sample remains independent.
The existing `BatchExpectationObjective` and `BatchSimulationResult` support both
pure and mixed batches; no second objective or result hierarchy is introduced.

| Step | Change | Acceptance | Status |
| --- | --- | --- | --- |
| 1 Representation | Batch density type, initialization, typed/view constructors, copy controls, and sample/pure conversions | B=0/1, zero-qubit registers, dimensions, scalar domains, and independent ownership | Verified locally |
| 2 Execution | Two-sided gate action, Kraus channels, pure-batch promotion, and whole-circuit preflight | Explicit dense gate/Kraus references, unsorted 1–5-qubit gates, fixed 1–2-qubit channels, and precision-preserving execution | Verified locally |
| 3 Observation and results | Expectations, readout, measurements, selection, partial trace, and mixed recorded trajectories | Per-sample shapes, projectors, RNG order, invalid-input atomicity, and external-backend result contracts | Verified locally |
| 4 Differentiation | Mixed and noisy batch scalar objectives plus optional circuit/state rules | Finite-difference/analytic/loop agreement, shared weights/parameters, complex cotangents, singular channels, and independent reusable pullbacks | Verified locally |
| 5 Compatibility | Full minimum/primary suites, independent companions, loading orders, examples, and existing benchmark harnesses | Julia 1.10/1.13 local acceptance and documentation/source review | Verified locally |

Floating execution keeps the state's component precision, matching existing
single-density behavior; explicit conversion chooses another precision. Unitary
gradients use one batch forward, while paths with fixed channels use per-sample
checkpoint reverse passes and require no inverse channel. Forward evaluation is
independent of AD packages and of the selected gradient method. The
[batch density guide](batch-density-matrices.md) documents the public contracts.

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

The next implementation step is a separate `MOSSQuantumChemistry` companion,
building molecular Hamiltonians on the operator and measurement interfaces above.
Chemistry engines and fermionic mappings remain outside the main package.

For the CUDA companion, complete strict acceptance on a real NVIDIA GPU,
including transfer policy, unsupported
operations and numerical agreement, before claiming hardware support or
performance. Then extend GPU execution to pure-state batches and a separately
selected GPU gradient method; density matrices and fixed noise follow the
validated pure-state path. Generic storage and host arithmetic tests alone do
not establish device execution correctness.

Other follow-up work remains separate:

1. Measured device allocation and execution improvements. Reusable dense CPU execution plans are implemented in the prepared-experiment milestone below.
2. Richer experiment statistics and classical loops/arithmetic; basic named registers and conditional feedback are implemented in the classical-control milestone below.
3. Companion frontends for symbolic parameter expressions and names, consuming the explicit parameter-map contracts.
4. Broader ChainRules coverage and migration of legacy circuit/state derivative entrypoints after their tangent contracts are defined.
5. Trainable noise parameters remain deferred. Parameter-shift, central-difference and SPSA estimators are implemented in the sampled-gradient milestone below.

The main package should keep the common contracts and CPU implementation. MPS, stabilizer simulation, continuous open-system solvers, algorithm workflows, error correction, chemistry, and external framework interoperability can consume those contracts from companion packages. Empty companion packages are not required to complete the core foundation.

## Verification record

### Operator and measurement acceptance, 2026-10-28

On Julia 1.13.1 with four threads, standard
`Pkg.test(; test_args=["--load-orders"])` passed 8,990 assertions across 97
reported testsets, including 1,300 new operator and measurement assertions and
eight fresh-process optional-integration loading checks. This covers constant
and zero operators, scalar gates, analytic gradients, operator algebra,
finite-shot execution, post-selection acceptance, grouped estimates and batches.

The four independent fixture packages also passed standard `Pkg.test()` in
isolated temporary copies: Backend 9, Gates 185, Differentiation 235 and
ArrayBackend 401 assertions (830 total). All three Julia examples in the
[operator and measurement guide](operators-and-measurement.md) executed
successfully. This acceptance used cached dependencies; Julia 1.10 and remote CI
were not rerun for this change.

### Earlier verification

The records below predate the rename from MOSS to MOSSQuantum. Package names,
commands, assertion counts, and source hashes are retained as historical evidence.

### Generic array storage and backend routing

Local acceptance completed on 2026-10-20:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed 7635 assertions across 78 top-level testsets, including all eight fresh-process loading scenarios.
- Julia 1.10.10, one thread: an independently resolved environment developed the actual checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with the same 7635 assertions, 78 ordered testsets, and eight loading scenarios. Source, tests, and root/benchmark Project/Manifest hashes remain unchanged during both runs.
- The 1245 new assertions cover generic storage and ownership (744), backend routing and unsupported-operation atomicity (143), and optional AD domains, views, and foreign cotangents (358). The latter includes 182 boundary checks confirming rejection before foreign scalar access, copying, or host transfer.
- Independent standard fixture `Pkg.test` passed on both versions: `MOSSDemoArrayBackend` 401, `MOSSDemoBackend` 9, `MOSSDemoGates` 185, and `MOSSDemoDifferentiation` 235 assertions each. The array fixture uses all four public containers and a separately selected analytic gradient without an AD dependency or private numerical kernel.
- Fourteen fresh benchmark compatibility processes passed: per version, scalar core/AD 16/20 warmed rows, pure-batch 18/21, pure/mixed batch 52/60, and 26 core first-call rows. Documentation examples also passed on both versions.
- The [regression report](performance/generic-storage-2026-10-20.md) retains 60 before/after allocation pairs against `bbffd9a`, exact source/environment hashes, and final acceptance records. All eight prepared-pullback and gate cases retain allocation bytes and counts. Several forward evaluations incur extra preflight allocations; pure-state channel promotion allocates about half as much. No elapsed-time improvement is claimed.

The final 108-file source snapshot is `dc01e4bc7396eca05f3f330d0bf59613631eba405627f39188706fd88076ed16`. Runtime dependencies, root and benchmark environments, benchmark entrypoints, and historical performance artifacts are unchanged. CI now includes all four independent fixtures on both versions; remote CI has not been run. Device execution, additional numerical gradient algorithms, and trainable noise remain subsequent or deferred work.

### CPU batch allocation improvements

Local acceptance completed on 2026-10-20:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed 6390 assertions across 71 top-level testsets, including all eight fresh-process loading scenarios (92.8 seconds).
- Julia 1.10.10, one thread: an independently resolved environment developed the actual checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with the same 6390 assertions, 71 ordered testsets, and eight loading scenarios (76.9 seconds). Source, tests, and root Project/Manifest hashes remain unchanged during both runs.
- The 811 additional assertions cover promoted short density contractions (including Float32/ComplexF32), complex and wider-domain cotangents, representable derivatives recovered by seeding before operator products, empty/zero-qubit batches, independent saved snapshots, repeated and concurrent pullbacks, nested unsorted multi-parameter gates with shared values, singular channels, and scalar-domain restoration across checkpoints.
- Independent standard fixture `Pkg.test` passed on both versions: `MOSSDemoBackend` 9, `MOSSDemoGates` 185, and `MOSSDemoDifferentiation` 235 assertions each. Fourteen fresh benchmark compatibility processes passed: each version checks scalar core/AD 16/20 warmed rows, pure-batch 18/21, new pure/mixed batch 52/60, and 26 new core first-call rows. Core processes confirm that neither AD package is loaded.
- The [CPU batch report](performance/cpu-batch-2026-10-20.md) retains 884 formal summaries and the resolved environment, frozen scripts, source patch, diagnostic profile, comparisons, and checksums. Independent review reproduces all 107 optimized source hashes by applying the exact three-file patch to `cd127e6`, verifies every paired control and reported value, and confirms that all 26 independent confirmation operations reproduce allocation bytes/counts for both implementations.

Runtime dependencies, the root Project/Manifest, benchmark environment, older benchmark entrypoints, and public execution/gradient interfaces remain unchanged. CPU allocation work stays internal. At that milestone, new numerical gradient algorithms, trainable noise, generic array storage, and GPU execution remained separate work; the storage/backend milestone above subsequently adds generic containers.

### Dense batch density matrices

Local acceptance completed on 2026-10-19:

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])` passed 5579 assertions across 69 top-level testsets. All eight fresh-process loading scenarios passed, including core-only mixed/noisy evaluation, direct ChainRules loading before/after MOSS, and optional Zygote mixed/noisy batch gradients (99.0 seconds for that group).
- Julia 1.10.10, one thread: a new independent environment developed the checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`, with 5579 assertions across 69 top-level testsets and all eight loading scenarios (88.0 seconds). Every top-level testset name and assertion count matches the primary-version run.
- The new density groups contain 1212 assertions: representation/algebra/execution (205), observations and partial trace (92), readout/measurement/post-selection/recorded simulation (543), scalar objectives (124), and optional circuit/state gradients (248). Coverage includes explicit complex dense gate and Kraus references, unsorted 1–5-qubit gate registers, floating precision, trace normalization, B=0/1 and zero-qubit states, conditional projector formulas, RNG and mutation atomicity, raw/typed/view constructors, complex cotangents, shared weights/parameters, singular channels, and reusable private snapshots.
- Existing extension contracts add four positive noisy batch checks and remove two obsolete noise-rejection assertions, giving a net increase of 1214 assertions over the pure-batch stage. Independent standard fixture `Pkg.test` passed on both versions: `MOSSDemoBackend` 9, `MOSSDemoGates` 185, and `MOSSDemoDifferentiation` 235. The external trainable gate now trains pure-to-mixed and mixed-initial batches with fixed channels through public APIs.
- README computation examples and all batch-density guide examples ran in four independent processes: Julia 1.10/1.13, each in core and optional AD mode. Core examples confirmed no ChainRulesCore or Zygote loading. Package installation commands and unrelated plotting examples were outside this example check; plotting and loading remain covered by the full suite.
- Eight small existing benchmark harness checks passed: both Julia versions, scalar/pure-batch entrypoints, and separate core/optional AD modes. Two-qubit, one-layer, 0.01-second cases produced 32/40 scalar summary rows and 18/21 pure-batch rows with correct version and AD-loading metadata. These are compatibility checks, not new performance measurements. Historical pure-batch reproduction now explicitly selects revision `6017410`.
- Source and public-interface review, local Markdown links/anchors/fences, TOML files, and whitespace checks passed. The existing CI main/independent-extension matrix covers the new tests on both versions; remote CI has not been run.

Runtime dependencies, the main development Manifest, and the existing benchmark scripts/environment are unchanged. Density batches remain a separate representation in the main package; scalar reductions, result records, execution selection, and replaceable gradient methods retain their public interfaces. Fixed channels are supported without inverse-map assumptions. At that stage, trainable noise, stochastic derivatives, array-generic storage, and new numerical gradient estimators remained separate work; generic storage is implemented in the later milestone above.

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

## Classical control and finite-shot gradients

Implemented named measurement bits, independent classical registers, conditional
branches, readout-aware feedback, static definite-assignment checks, and batch/
trajectory execution. Implemented shot objectives, occurrence-wise parameter
shift with shared parameters, central differences, SPSA, covariance and budget
reporting. The algorithm zoo supplies Adam/SGD workflows with independent final
energy estimates. See the [guide](classical-control-and-gradients.md).

Classical loops/arithmetic, differentiable noise parameters, and implicit batch
gradient reductions remain outside this increment.

Local acceptance on 2026-10-28, Julia 1.13.1, four Julia threads and one BLAS
thread: standard `Pkg.test(; test_args=["--load-orders"])` passed 9,665 assertions
across 116 reported testsets, including 256 new classical/gradient/optimization
assertions and eight optional-integration loading assertions. All four standalone
fixture packages passed another 830 assertions. Both executable guide blocks and
the two-qubit optimization script ran successfully; the latter used 602,000 shots
across 301 objective evaluations. Julia 1.10 and remote CI were not rerun locally
for this increment. No new runtime dependencies were introduced.

## Prepared experiments and shot budgets

Implemented reusable dense CPU execution/estimation plans, parameter-only binding,
frozen noise compilation, cached deterministic distributions and optional reusable
trajectory workspaces. Ordered parameter sweeps return unified experiment results
and use point-indexed RNGs for serial/threaded reproducibility. Independent pilot
allocation and atomic hard budgets are integrated into sampled gradients and the
optimizer; capped optimization preserves a fresh final estimate.

The [guide](prepared-experiments.md) defines snapshot ownership, CPU-only scope,
concurrency and statistical semantics. [Measured workloads](performance/prepared-2026-10-29/README.md)
cover noisy repeated execution, feedback, parameter scans and variational gradients.
Large-scale MPS/stabilizer backends are explicitly deferred to a separate round.

Local acceptance on 2026-10-29, Julia 1.13.1, four Julia threads and one BLAS
thread: standard `Pkg.test(; test_args=["--load-orders"])` passed 9,860 assertions
across 121 reported testsets, including the initial 195 new plan/sweep/budget
assertions. A subsequently found adaptive-optimizer result-container mismatch was
fixed by accepting `AdaptiveEstimate`; the final optimizer/budget run passed 143
assertions, including four new regression assertions for that fix. All four
standalone fixture packages passed 830 assertions. Four executable documentation
blocks and the prepared/adaptive optimization script passed; the script completed
a separate 12,000-shot scan and a 100,000-shot optimization with 33 updates and a
fresh final estimate. Julia 1.10 and remote CI were not rerun for this increment.
Runtime dependencies are unchanged. Final performance measurements run separately
after the regression processes finish, with preparation/binding cost recorded.
