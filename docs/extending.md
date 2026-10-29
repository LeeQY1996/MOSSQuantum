# Extending MOSSQuantum

A companion package can add instructions, implicit states, execution backends, and observations through public methods. An external state need not expose dense amplitudes or follow MOSSQuantum's current vector/matrix storage layout.

## Use existing dense operation types

For a matrix-defined gate, no new type is needed:

```julia
using MOSSQuantum

phase = ComplexF64[1 0; 0 cis(0.2)]
circuit = QCircuit([QuantumGate(1, phase)])
state = apply!(circuit, qstate(2))
```

The first gate position is the least significant local matrix bit. `QuantumGate` does not validate unitarity, so the caller is responsible for the intended operation. `QuantumMap` accepts Kraus matrices; applying it to a state vector returns a density matrix, and applying it to `BatchStateVector` returns `BatchDensityMatrix`. Current CPU generic channels support at most two physical qubits because their superoperators act on twice as many density indices. Batch samples undergo the same channel independently.

Physical noise constructors validate CPTP maps; general `QuantumMap` retains an
explicit `check_tp` switch for non-trace-preserving low-level applications.
Kraus constructor inputs are copied, and exposed Kraus/supermatrix arrays must
be treated as read-only. Reconstruct the map to change it. Stochastic execution
requires physical channels and rejects inconsistent cached representations.
Explicit CPU `KrausTrajectory()` preserves pure states per noise realization;
it does not imply that an external backend supports trajectories. See the
[noise guide](noise-simulation.md) for method, record and readout contracts.

A custom matrix gate can subtype `MOSSQuantum.Gate{N}` and implement `MOSSQuantum.positions`, `MOSSQuantum.mat`, and `MOSSQuantum.change_positions`. It then uses the existing CPU gate dispatcher, subject to its arity limits. A fixed gate angle does not become trainable automatically. Trainable gates add the public parameter and derivative methods described below, without adopting the built-in gate fields.

## Instruction and state contracts

| Interface | Companion implementation |
| --- | --- |
| `AbstractInstruction` | Subtype it for a new executable instruction; implement `positions` and its backend execution |
| `positions(instruction)` | Return its quantum register positions; parameterless instructions may use an empty collection |
| `change_positions(instruction, mapping)` | Implement when remapping or shifting should be supported |
| `AbstractQuantumState` | Subtype it for a state representation |
| `nqubits(state)` | Return its register size |
| `copy(state)` | Return an independently mutable state |
| `backend(state)` | Return an `AbstractBackend` implementation |

`QCircuit` accepts external `AbstractInstruction` subtypes, including instructions outside the gate/channel hierarchy. Observable descriptions such as `QubitsOperator` are not instructions. Instructions are parameterless by default. `storage` is optional for external states, and neither `.data` nor MOSSQuantum private helpers belong to the extension contract.

The dense state containers keep single and batch representation separate:
`StateVector` has one vector, while `BatchStateVector` has one sample
per matrix column. `DensityMatrix` has one matrix; `BatchDensityMatrix` has axes
`(2^n, 2^n, B)`, with one independent matrix per final-axis slice. Reuse public
operation names when adding batch capabilities;
preserve sample order and batch axes even for one sample. A batch shares its
circuit and circuit parameters. Both batch types support B=0 and zero qubits.
The [pure batch guide](batching.md) and [density batch guide](batch-density-matrices.md)
describe supported CPU operations, ownership, and differentiation boundaries.

Density-batch gate execution applies `UρU†`; observable multiplication remains
the algebraic left action. Preserve floating state component precision during
dense gate and channel execution, including promotion from real `T` to
`Complex{T}`. Density normalization uses trace, rather than matrix norm.

## Preserve array storage

The four built-in dense containers carry both an element type and a concrete
array type: `StateVector{T,A}`, `DensityMatrix{T,A}`, `BatchStateVector{T,A}`,
and `BatchDensityMatrix{T,A}`. They can hold another array family without a new
state hierarchy. `DensityMatrix` retains a vectorized backing array; its public
`storage` is a reshape to `(2^n, 2^n)` in the same family.

Array inputs opt in explicitly:

```julia
using MOSSQuantum

amplitude_data = ComplexF64[1, 0, 0, 0]
input = view(amplitude_data, 1:4)
state = StateVector(input; preserve_storage=true)
@assert storage(state) === input
@assert backend(state) isa CPUBackend
independent = copy(state)
@assert !Base.mightalias(storage(independent), input)
```

Ordinary array constructors still materialize compatible CPU arrays, including
when `copy=false`. `preserve_storage=true` retains an input with the same element
type unless copying is requested. State-to-state construction, `copy(state)`,
scalar-type conversion, and pure-to-mixed conversion retain the selected family.
An owned copy of a view can use an owning array of its parent's family. Sample
extraction remains independent even with `copy=false`. Shape, register, and
one-based-axis checks precede payload conversion or copying.

An array implementation supplies metadata, `similar`, `copyto!`, and `reshape`;
views and broadcast are needed for sample extraction, arithmetic, and outer
products. Independent allocations must not alias the input. Unsupported
same-family allocation is rejected rather than materializing an unknown array
through `Array`. Device transfers and device-specific array operations belong
to the companion package.

Storage construction, execution, and differentiation are separate capabilities.
CPU execution accepts ordinary arrays and a conservative set of contiguous,
one-based views rooted in them, including supported reshapes. Stepped or
permuted layouts and unknown wrappers do not gain CPU execution merely by
implementing `AbstractArray`. Register `backend(state)` and the operations below
for another storage family. Without a registered backend, backend selection
raises `ArgumentError`; explicit unsupported CPU execution raises
`UnsupportedOperation` before touching the payload. No path implicitly copies
such a state to the host to execute it.

Code that tested an exact old type must account for `A`. Prefer
`state isa StateVector{ComplexF64}` and inspect `typeof(storage(state))` when
layout matters. `StateVector{T}` remains a valid constructor and dispatch family,
but is now a partially specified type; it is not the exact concrete type of an
instance. The same applies to the other three containers.

## Backend and observation contracts

Implement these methods for the combinations the backend supports:

```julia
MOSSQuantum.supports(my_backend, instruction, state; action=:apply)
MOSSQuantum.apply!(my_backend, instruction, state)
MOSSQuantum.supports(my_backend, observable, state; action=:expectation)
MOSSQuantum.expectation(my_backend, observable, state)
# Nonmutating observable action, used by observable * state:
MOSSQuantum.supports(my_backend, observable, state; action=:apply)
MOSSQuantum.apply(my_backend, observable, state)
# Computational-basis readout:
MOSSQuantum.supports(my_backend, MOSSQuantum.probabilities, state; action=:probabilities)
MOSSQuantum.probabilities(my_backend, state; qubits=1:MOSSQuantum.nqubits(state))
```

`supports` returns a Boolean and defaults to `false` for unknown capabilities. Check register bounds with `MOSSQuantum.validate_positions(instruction, MOSSQuantum.nqubits(state))` separately. Instruction application returns the resulting state and may replace it with another representation. Unsupported execution or observation should raise `MOSSQuantum.UnsupportedOperation(backend, operation, state, action)`.

For circuit-level diagnostics, a backend may specialize `validate_backend_execution(backend, circuit, state; mode=:apply)`. The default does nothing. The hook receives the original circuit and `mode` is `:apply`, `:simulate`, or `:execute`; it can throw a detailed error before execution and must not mutate the circuit, state, or random-number generator. This preflight supplements the capability and position checks, and preserves the distinction between forced post-selection in `simulate` and rejection sampling in `execute`. A backend that specializes circuit-level `apply!` must call the hook itself.

The two-argument methods `apply!(instruction, state)` and `expectation(observable, state)` select `backend(state)`. Generic backend circuit execution visits nested instructions, retains replacement states, and rejects unsupported capabilities. A default circuit capability query checks each instruction against the supplied state. Backends that change representation should specialize that query to follow their state transitions; the dense CPU backend does so for pure-to-mixed channel application.

An explicit CPU instruction call uses the core CPU matrix implementation.
Specialized legacy two-argument instruction methods still participate in direct
calls and CPU circuit traversal. Put custom backend behavior in the
three-argument methods so explicitly selecting that backend selects its intended
implementation too.

The existing CPU measurement adapters retain metadata return values for `QMeasure` and `QSelect`. To support stochastic measurement through `simulate`, a custom backend implements `measure!(backend, state, position; auto_reset, rng)` returning `(outcome, probability)`, and advertises support for the corresponding `QMeasure`. Generic `simulate` records those outcomes; it does not invent a backend's measurement algorithm or AD rule.

For `BatchStateVector` or `BatchDensityMatrix`, those two metadata fields are
vectors in sample order.
`simulate` requires one valid outcome/probability per sample and preserves the
sample count after every instruction, allowing transitions between pure and
mixed batch representations. It returns `BatchSimulationResult`, whose
`measurements[column]` holds the individual records. Batch `QSelect` similarly
returns one probability per sample. Recorded batch measurements keep the register
size; separate nonmutating `measure`/`post_select` calls support qubit removal.

Sampling is a separate capability. For the four dense containers, implement `MOSSQuantum.probabilities(backend, state; qubits=...)`; the ordinary state call selects its backend. Implicit external state types can also implement their own state-level `probabilities`, `sample`, or `counts` methods. Preserve the documented readout ordering, normalization, RNG, and shape conventions. Implementing `apply!` alone does not establish readout or differentiation support.

`MOSSQuantum.apply(backend, observable, state)` is the qualified, nonmutating linear
action hook for matrix and operator multiplication. It returns independent
output storage; for density matrices this action is `Oρ`, while gate execution
through `apply!` is `UρU†`. Use `MOSSQuantum.apply` with its module qualification; it is
not exported. Observation continues to use `expectation`. Readout arrays may be
host metadata if that is the backend's documented convention; this does not
change the state's storage family.

## Independent array-backend example

The [array-backend fixture](../test/fixtures/MOSSQuantumDemoArrayBackend/README.md)
uses the four public state containers with `DemoArray`. That array rejects scalar
indexing, `Array(...)`, and `collect(...)`, so its tests detect accidental CPU
fallback. The example executor owns ordinary CPU arrays privately; it is a
contract demonstration, not a GPU implementation.

From this repository root, prepare its independent environment:

```bash
julia --project=test/fixtures/MOSSQuantumDemoArrayBackend --startup-file=no -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
```

Then run the following in that environment:

```julia
using MOSSQuantum, MOSSQuantumDemoArrayBackend

initial = StateVector(DemoArray(ComplexF64[1, 0]); preserve_storage=true)
@assert backend(initial) isa ArrayBackend
state = apply!(RyGate(1, 0.3), copy(initial))
@assert real(expectation(ZGate(1), state)) ≈ cos(0.3)
@assert probabilities(state) ≈ [cos(0.15)^2, sin(0.15)^2]

flipped = MOSSQuantum.apply(backend(state), ComplexF64[0 1; 1 0], state)
mixed = DensityMatrix(state)
@assert storage(flipped) isa DemoArray
@assert storage(mixed) isa DemoArray

objective = ExpectationObjective(QCircuit([RyGate(1, 0.0; isparas=true)]),
    ZGate(1), initial)
@assert evaluate(objective, [0.3]) ≈ cos(0.3)
@assert !supports_gradient(AdjointGradient(), objective)
```

The fixture also supplies a separately selected analytic gradient method for a
small external objective. That illustrates the public gradient protocol without
adding numerical estimators or requiring an AD package. GPU kernels, device
allocation policy, transfers, and any device differentiation belong in companion
implementations; successful storage adaptation alone establishes none of them.

## Independent backend example

[`test/fixtures/MOSSQuantumDemoBackend`](../test/fixtures/MOSSQuantumDemoBackend) is a real fixture package with its own `Project.toml` and `import MOSSQuantum`. It defines:

- `DemoState <: AbstractQuantumState`, storing one bit per qubit rather than dense amplitudes;
- `DemoFlip <: AbstractInstruction`, independent of the built-in gate hierarchy;
- `DemoBackend <: AbstractBackend`, implementing flip execution and Z expectation.

After developing the MOSSQuantum checkout into that package's environment and loading it normally:

```julia
import MOSSQuantum
using MOSSQuantumDemoBackend

state = DemoState(3)
circuit = MOSSQuantum.QCircuit([DemoFlip(1), MOSSQuantum.XGate(3)])
@assert MOSSQuantum.supports(MOSSQuantum.backend(state), circuit, state)
state = MOSSQuantum.apply!(circuit, state)
@assert MOSSQuantum.expectation(MOSSQuantum.ZGate(1), state) == -1
```

Its tests also exercise unsupported H-gate execution, noise, and X observation. They use only public MOSSQuantum methods and do not require `storage`, internal source includes, or underscore-prefixed kernels. The fixture is a minimal contract example, rather than a production stabilizer or tensor-network simulator.

## Parameters and differentiation

An external trainable instruction implements these public methods; it does not need `.paras`, `.isparas`, or `reset_parameters_util!`:

| Method | Contract |
| --- | --- |
| `parameters(instruction)` | Return all stored real parameters, including frozen values |
| `active_parameters(instruction)` | Return the active real parameter vector in local order; parameterless defaults return `nothing` |
| `reset_parameters!(instruction, values::AbstractVector{<:Real})` | Validate length and finite values, preserve frozen parameters, and return the updated or replacement instruction |
| `nparameters(instruction)` | Defaults to the length of `active_parameters`, with `nothing` giving zero; may be specialized |
| `copy_instruction(instruction)` | Optional ownership hook; defaults to `deepcopy` |
| Activation and deactivation methods | Implement when needed; return the updated or replacement instruction |

Retain the return value of parameter reset, activation, and deactivation. An immutable gate can return a new gate using its own field layout. Circuit traversal and `AdjointQuantumGate` retain that replacement. At circuit level, `activate_parameter!(circuit, j)` still activates all parameters of instruction `j`; it does not address flattened parameter slot `j`.

`bind_parameters(instruction, values)` is the independent-binding entrypoint for a single instruction or a circuit. Circuit values follow recursive `active_parameters` traversal order; inactive values remain unchanged. Binding dispatches per instruction, copies parameterless instructions too, and provides owned parameter vectors to writers. Every occurrence is copied independently through `copy_instruction`, so repeated source references become separate parameter slots. The circuit copy hook follows the same per-occurrence rule. Immutable copies can remain `===`; mutable storage must be independent. Explicit parameter maps can coordinate the values of those slots without adding fields to an external instruction.

The existing mutating `reset_parameters!` preserves aliases: a repeated mutable gate is updated once per occurrence, and the last supplied value wins. `copy(circuit)` and `QCircuit(circuit; copy=true)` remain shallow container copies. Use `copy_instruction(circuit)` for independent mutable instruction data, or `bind_parameters` to copy and bind it. Legacy gate reset helpers remain adapted internally for existing implementations; new packages use the public writer.

To use a custom unitary `Gate` with the existing dense CPU circuit reverse pass, implement `differentiate(gate)` as one derivative gate per active parameter in active-parameter order. For matrix `U`, each derivative gate must store

```text
Dⱼ = (∂U/∂θⱼ)' * U
```

on the same register positions as the original gate. This is the generator convention used by the reverse pass, rather than a list of raw `∂U/∂θⱼ` matrices. A gate with active parameters but no derivative implementation raises `ArgumentError`; a parameterless gate returns `nothing`. The reverse pass requires unitary gates and also supports fixed `QuantumMap` channels in single/batch pure and mixed workflows. Arbitrary `AbstractInstruction` subtypes, custom backends, and trainable noise parameters are outside that implementation. For the current Zygote training contract, bind the parameters of a `QCircuit` inside the loss; standalone instruction binding does not establish a general AD rule.

[`test/fixtures/MOSSQuantumDemoGates`](../test/fixtures/MOSSQuantumDemoGates) is an independent package showing the complete path. Its immutable `DemoRotation <: ParametricGate{1}` stores `wire`, `angle`, and `trainable`, implements only public MOSSQuantum methods, and needs no special reset or execution code in MOSSQuantum. Its contract tests cover nested and repeated binding, frozen parameters, adjoint wrappers, analytic and finite-difference gradients, one optimization update, and fixed-channel gradients. After developing both packages into the consumer environment:

```julia
using MOSSQuantum, MOSSQuantumDemoGates, Zygote

template = QCircuit([DemoRotation(1, 0.1)])
initial = StateVector(1)
observable = QubitsTerm(1 => "Z")
loss(values) = real(expectation(observable, bind_parameters(template, values) * initial))
gradient = Zygote.gradient(loss, [0.1])[1]  # approximately [-sin(0.1)]
```

### Share values across instruction occurrences

`ParameterMap` uses the same public active-slot order for built-in and external instructions. A companion gate needs no additional parameter-identity interface:

```julia
using MOSSQuantum, MOSSQuantumDemoGates, Zygote

template = QCircuit([DemoRotation(1, 0.0), DemoRotation(1, 0.0)])
parameter_map = ParameterMap(template, [1, 1])
initial = StateVector(1)
observable = QubitsTerm(1 => "Z")
loss(values) = real(expectation(observable,
    bind_parameters(template, values, parameter_map) * initial))
gradient = Zygote.gradient(loss, [0.1])[1] # approximately [-2sin(0.2)]
```

There are two active slots and one independent input value. Binding gathers that value into both slots; the existing CPU circuit reverse pass produces slot derivatives, and the map sums them back into the single input derivative. For a separately obtained slot gradient, call `accumulate_parameter_gradients(parameter_map, flat_gradient)` to perform the same sum. This path retains the existing gate and backend derivative requirements.

Maps are immutable metadata kept separate from instructions and bound circuits. `ParameterMap(template)` creates an identity map; `ParameterMap(template, indices)` checks the current active-slot count. Each ID must be a positive non-Boolean integer, and all IDs in `1:k` must be used. `length(parameter_map)` counts slots, `nparameters(parameter_map)` counts independent values, and `parameter_indices(parameter_map)` returns a defensive `Vector{Int}`. Rebuild or review the map after changing activation or circuit order: matching slot counts do not establish matching slot meanings. See the [full mapping conventions](conventions.md#explicit-shared-parameter-maps).

Sharing a value does not share mutable gate storage. Existing independent binding, mutating reset, and shallow circuit copies retain their documented ownership rules. Parameter maps do not provide symbolic parameter expressions or a general derivative rule for external backends.

Zygote registrations are optional and loaded by `MOSSQuantumZygoteExt`. They connect existing reverse passes to supported deterministic dense-state circuit application and expectation APIs. New backends and instructions need their own derivative rules and validation; `supports(...; action=:apply)` or `:expectation` does not imply gradients. Stochastic `simulate`, `sample`, and `counts` do not define automatic derivatives.

The legacy circuit/state integration uses Zygote adjoints. Its batch rules cover
pure/mixed circuit application with unitary gates and fixed channels,
`QubitsTerm`/`QubitsOperator` expectations,
`batch_qubit_encoding` (including its `batch_qstate` alias), and supported state
constructors/copies, including pure-to-density conversion. They allow gradients of shared circuit parameters or
per-sample encoding inputs, without implying derivatives for every batch
operation. Batch measurement and post-selection remain forward capabilities.
The explicit parameter-vector interface below uses a separate optional
ChainRulesCore extension. Trainable noise parameters and broader migration of
legacy derivative entrypoints remain planned. Avoid claiming AD support for a
custom backend until its derivative behavior and error paths are tested. Optional
constructor rules accept `preserve_storage` and retain the input shape and scalar
domain on supported CPU arrays/views; they do not give every array family a
circuit derivative. The built-in dense adjoint checks CPU storage eligibility
before entering its numerical reverse pass.

## Execution and replaceable differentiation

Execution and the selected gradient method are separate public interfaces. An external objective can be any Julia type; it does not need to inherit from MOSSQuantum or provide `storage`, `backend`, or a quantum state. `ExpectationObjective` is the built-in adapter for a circuit, observable, and initial state:

```julia
objective = ExpectationObjective(template, observable, initial;
    parameter_map=ParameterMap(template), backend=MOSSQuantum.backend(initial))
value = evaluate(objective, values)
method = AdjointGradient()
supports_gradient(method, objective)
value, gradient = value_and_gradient(method, objective, values)
```

The constructor snapshots the instruction tree, observable, and initial state. The execution backend is retained as a resource. `evaluate` independently binds each occurrence, executes on a copy of the initial state, and returns the real part of the scalar expectation. It does not select a gradient method, and execution support does not imply differentiation support.

| Public hook | External implementation contract |
| --- | --- |
| `evaluate(objective, values)` | Return a scalar value without invoking a gradient method; preserve the caller's values |
| `AbstractGradientMethod` | Subtype it for a numerical differentiation strategy |
| `supports_gradient(method, objective)` | Declare support for gradients of the explicit parameter vector; unknown combinations default to `false` |
| `value_and_gradient(method, objective, values)` | Return `(value::Real, gradient::AbstractVector{<:Real})` in independent input order; preserve inputs |
| `value_and_pullback(method, objective, values)` | Optional specialized `(value, back)`; `back(seed::Real)` returns only the scaled parameter gradient and supports independent repeated calls |
| `differentiable_value(method, objective, values)` | Scalar AD entrypoint retaining the chosen method; ordinary calls invoke only `evaluate` |

The generic pullback fallback calls `value_and_gradient` once and caches a private copy of the gradient. This fallback is eager. Strategies can override the pullback to reuse a forward execution and defer their reverse work. The default gradient hook throws `UnsupportedGradient`; the two defaults never call each other recursively and never silently select another algorithm. Inputs use finite real values with one-based vector indexing. The value must be real and scalar; the gradient is a real vector with the same length. Nonfinite output gradients may propagate. Numerical gradient precision is chosen by the method; AD adapters project to the input domain.

`BatchExpectationObjective(template, observable, initial_batch; parameter_map,
backend, reduction=:mean, weights=nothing)` adapts a nonempty pure or mixed batch to
the same scalar protocol. `evaluate_batch` returns real sample expectations in
column order; `evaluate` applies `:mean`, `:sum`, or `:weighted_sum`. Weighted sums
require one finite real weight per sample, keep negative weights, and do not
normalize. The constructor snapshots weights alongside the instruction tree,
observable, and initial batch. Only the circuit parameter vector is differentiated
through the explicit scalar interface; encoding inputs are fixed configuration
there. External gradient methods can support this objective without changing its
forward execution or the optional AD adapter.

`AdjointGradient` specializes the numerical pullback using dense CPU reverse
passes without invoking Zygote. `ExpectationObjective` supports single pure/mixed
states, unitary gates, and fixed `QuantumMap` channels.
`BatchExpectationObjective` supports shared circuits on pure/mixed batches with
unitary gates and fixed `QuantumMap` channels.
Both require supported Hermitian `QubitsTerm`/`QubitsOperator` observables and valid
derivative rules for active parameters. Shared slots are accumulated through the
objective's `ParameterMap`, and batch contributions follow its scalar reduction.
The batch implementation reuses the numerical reverse helpers used by optional
Zygote rules. Unitary-only circuits use one batch forward and per-sample reverse
reconstruction. Noisy circuits retain per-sample forward checkpoints and apply
channel adjoints, allowing singular fixed noise such as complete amplitude
damping at `γ=1` without requiring an inverse channel.
Stochastic instructions, trainable channels, arbitrary backends, and
missing derivative rules are unsupported by this method. Querying another method
is independent of the execution backend's `supports` queries.

Loading ChainRulesCore activates `MOSSQuantumChainRulesCoreExt`. Its `rrule` is limited to `differentiable_value(method, objective, values)` and dispatches through the public numerical pullback. Only `values` receives a cotangent; the method and objective (including its template, observable, map, and initial state) are fixed configuration for this entrypoint. Zero cotangents skip the numerical pullback, thunks are unpacked, real scalar seeds are projected, and parameter cotangents are projected to the original vector domain. No rule is installed on the generic `evaluate` entrypoint. Existing Zygote circuit and state rules remain separate compatibility paths.

```julia
using Zygote
loss(values) = differentiable_value(method, objective, values)
gradient = Zygote.gradient(loss, values)[1]
```

The [`MOSSQuantumDemoDifferentiation` fixture](../test/fixtures/MOSSQuantumDemoDifferentiation) imports MOSSQuantum normally and defines its own scalar objective, two replaceable executors, and two public gradient methods without any quantum-state fields. It validates core-only numerical calls, direct ChainRules use without Zygote, and Zygote dispatch to the selected external method. This fixture proves the extension contract; it is not a hardware driver or a new finite-difference/stochastic gradient implementation. The core now supplies explicit parameter-shift, finite-difference and SPSA methods through these hooks; see the [sampled gradient guide](classical-control-and-gradients.md).

## Optional package integrations

MOSSQuantum requires Julia 1.10 or later and uses native `[weakdeps]` and `[extensions]` on every supported version. Julia 1.13 is the primary development and acceptance version. Zygote activates `MOSSQuantumZygoteExt`; Plots together with LaTeXStrings activates `MOSSQuantumPlotsExt`. The Requires bridge has been removed. Install and load trigger packages explicitly in the consumer environment:

```julia
using Pkg
Pkg.add("Zygote")                         # Only when gradients are needed
Pkg.add(["Plots", "LaTeXStrings"])       # Only when plotting is needed
```

Consumers can then `using MOSSQuantum, Zygote`, or `using MOSSQuantum, Plots, LaTeXStrings`. Core simulation has no mandatory AD or plotting framework. Compatibility and load-order verification are recorded in the [roadmap](roadmap.md#verification-record).

Plots also exports `backend`. When both packages are loaded with `using`, call `MOSSQuantum.backend(state)` explicitly, or import that binding with `import MOSSQuantum: backend`.

## Boundaries for future packages

The main package retains instruction descriptions, generic dense state containers, state/backend contracts, the CPU simulator, observables, parameter binding, and existing reverse passes. A device companion can reuse the four dense containers through `preserve_storage=true`, then implement its array operations, transfers, and executor through public hooks. Ordinary array constructors keep their CPU materialization default. Storage preservation does not implement device kernels or device gradients. A companion can also supply an implicit or compressed state with its own backend when a dense container is unsuitable.

MPS, stabilizer simulation, continuous open-system solvers, specialized algorithm workflows, error correction, chemistry, and framework interoperability can live in companion packages. Their dependencies and numerical assumptions can evolve while using the public contracts above. No companion package should rely on private CPU kernels as its public integration path.
