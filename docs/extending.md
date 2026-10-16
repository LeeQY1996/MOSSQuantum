# Extending MOSS

A companion package can add instructions, implicit states, execution backends, and observations through public methods. An external state need not expose dense amplitudes or follow MOSS's current vector/matrix storage layout.

## Use existing dense operation types

For a matrix-defined gate, no new type is needed:

```julia
using MOSS

phase = ComplexF64[1 0; 0 cis(0.2)]
circuit = QCircuit([QuantumGate(1, phase)])
state = apply!(circuit, qstate(2))
```

The first gate position is the least significant local matrix bit. `QuantumGate` does not validate unitarity, so the caller is responsible for the intended operation. `QuantumMap` accepts Kraus matrices; applying it to a state vector returns a density matrix. Current CPU generic channels support at most two physical qubits because their superoperators act on twice as many density indices.

A custom matrix gate can subtype `MOSS.Gate{N}` and implement `MOSS.positions`, `MOSS.mat`, and `MOSS.change_positions`. It then uses the existing CPU gate dispatcher, subject to its arity limits. A fixed gate angle does not become trainable automatically. Trainable gates add the public parameter and derivative methods described below, without adopting the built-in gate fields.

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

`QCircuit` accepts external `AbstractInstruction` subtypes, including instructions outside the gate/channel hierarchy. Observable descriptions such as `QubitsOperator` are not instructions. Instructions are parameterless by default. `storage` is optional for external states, and neither `.data` nor MOSS private helpers belong to the extension contract.

## Backend and observation contracts

Implement these methods for the combinations the backend supports:

```julia
MOSS.supports(my_backend, instruction, state; action=:apply)
MOSS.apply!(my_backend, instruction, state)
MOSS.supports(my_backend, observable, state; action=:expectation)
MOSS.expectation(my_backend, observable, state)
```

`supports` returns a Boolean and defaults to `false` for unknown capabilities. Check register bounds with `MOSS.validate_positions(instruction, MOSS.nqubits(state))` separately. Instruction application returns the resulting state and may replace it with another representation. Unsupported execution or observation should raise `MOSS.UnsupportedOperation(backend, operation, state, action)`.

The two-argument methods `apply!(instruction, state)` and `expectation(observable, state)` select `backend(state)`. Generic backend circuit execution visits nested instructions, retains replacement states, and rejects unsupported capabilities. A default circuit capability query checks each instruction against the supplied state. Backends that change representation should specialize that query to follow their state transitions; the dense CPU backend does so for pure-to-mixed channel application.

The existing CPU measurement adapters retain metadata return values for `QMeasure` and `QSelect`. To support stochastic measurement through `simulate`, a custom backend implements `measure!(backend, state, position; auto_reset, rng)` returning `(outcome, probability)`, and advertises support for the corresponding `QMeasure`. Generic `simulate` records those outcomes; it does not invent a backend's measurement algorithm or AD rule.

Sampling is a separate capability: external representations can implement `probabilities(state; qubits=...)`, or supply their own `sample` and `counts` methods. Preserve the documented readout ordering, normalization, RNG, and shape conventions. Implementing `apply!` alone does not establish readout or differentiation support.

## Independent backend example

[`test/fixtures/MOSSDemoBackend`](../test/fixtures/MOSSDemoBackend) is a real fixture package with its own `Project.toml` and `import MOSS`. It defines:

- `DemoState <: AbstractQuantumState`, storing one bit per qubit rather than dense amplitudes;
- `DemoFlip <: AbstractInstruction`, independent of the built-in gate hierarchy;
- `DemoBackend <: AbstractBackend`, implementing flip execution and Z expectation.

After developing the MOSS checkout into that package's environment and loading it normally:

```julia
import MOSS
using MOSSDemoBackend

state = DemoState(3)
circuit = MOSS.QCircuit([DemoFlip(1), MOSS.XGate(3)])
@assert MOSS.supports(MOSS.backend(state), circuit, state)
state = MOSS.apply!(circuit, state)
@assert MOSS.expectation(MOSS.ZGate(1), state) == -1
```

Its tests also exercise unsupported H-gate execution, noise, and X observation. They use only public MOSS methods and do not require `storage`, internal source includes, or underscore-prefixed kernels. The fixture is a minimal contract example, rather than a production stabilizer or tensor-network simulator.

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

`bind_parameters(instruction, values)` is the independent-binding entrypoint for a single instruction or a circuit. Circuit values follow recursive `active_parameters` traversal order; inactive values remain unchanged. Binding dispatches per instruction, copies parameterless instructions too, and provides owned parameter vectors to writers. Every occurrence is copied independently through `copy_instruction`, so repeated source references become separate parameter slots. The circuit copy hook follows the same per-occurrence rule. Immutable copies can remain `===`; mutable storage must be independent. Shared symbolic parameter identity is not implemented.

The existing mutating `reset_parameters!` preserves aliases: a repeated mutable gate is updated once per occurrence, and the last supplied value wins. `copy(circuit)` and `QCircuit(circuit; copy=true)` remain shallow container copies. Use `copy_instruction(circuit)` for independent mutable instruction data, or `bind_parameters` to copy and bind it. Legacy gate reset helpers remain adapted internally for existing implementations; new packages use the public writer.

To use a custom unitary `Gate` with the existing dense CPU circuit reverse pass, implement `differentiate(gate)` as one derivative gate per active parameter in active-parameter order. For matrix `U`, each derivative gate must store

```text
Dⱼ = (∂U/∂θⱼ)' * U
```

on the same register positions as the original gate. This is the generator convention used by the reverse pass, rather than a list of raw `∂U/∂θⱼ` matrices. A gate with active parameters but no derivative implementation raises `ArgumentError`; a parameterless gate returns `nothing`. The reverse pass requires unitary gates and supports the existing fixed `QuantumMap` channels. Arbitrary `AbstractInstruction` subtypes, custom backends, complete batch gradients, and trainable noise parameters are outside that implementation. For the current Zygote training contract, bind the parameters of a `QCircuit` inside the loss; standalone instruction binding does not establish a general AD rule.

[`test/fixtures/MOSSDemoGates`](../test/fixtures/MOSSDemoGates) is an independent package showing the complete path. Its immutable `DemoRotation <: ParametricGate{1}` stores `wire`, `angle`, and `trainable`, implements only public MOSS methods, and needs no special reset or execution code in MOSS. Its contract tests cover nested and repeated binding, frozen parameters, adjoint wrappers, analytic and finite-difference gradients, one optimization update, and fixed-channel gradients. After developing both packages into the consumer environment:

```julia
using MOSS, MOSSDemoGates, Zygote

template = QCircuit([DemoRotation(1, 0.1)])
initial = StateVector(1)
observable = QubitsTerm(1 => "Z")
loss(values) = real(expectation(observable, bind_parameters(template, values) * initial))
gradient = Zygote.gradient(loss, [0.1])[1]  # approximately [-sin(0.1)]
```

Zygote registrations are optional and loaded by `MOSSZygoteExt`. They connect existing reverse passes to supported deterministic dense-state circuit application and expectation APIs. New backends and instructions need their own derivative rules and validation; `supports(...; action=:apply)` or `:expectation` does not imply gradients. Stochastic `simulate`, `sample`, and `counts` do not define automatic derivatives.

The present extension uses Zygote adjoints. ChainRules integration, complete batch gradients, trainable noise parameters, and a general differentiation capability protocol remain planned. Avoid claiming AD support for a custom backend until its derivative behavior and error paths are tested.

## Optional package integrations

MOSS requires Julia 1.10 or later and uses native `[weakdeps]` and `[extensions]` on every supported version. Julia 1.13 is the primary development and acceptance version. Zygote activates `MOSSZygoteExt`; Plots together with LaTeXStrings activates `MOSSPlotsExt`. The Requires bridge has been removed. Install and load trigger packages explicitly in the consumer environment:

```julia
using Pkg
Pkg.add("Zygote")                         # Only when gradients are needed
Pkg.add(["Plots", "LaTeXStrings"])       # Only when plotting is needed
```

Consumers can then `using MOSS, Zygote`, or `using MOSS, Plots, LaTeXStrings`. Core simulation has no mandatory AD or plotting framework. Compatibility and load-order verification are recorded in the [roadmap](roadmap.md#verification-record).

Plots also exports `backend`. When both packages are loaded with `using`, call `MOSS.backend(state)` explicitly, or import that binding with `import MOSS: backend`.

## Boundaries for future packages

The main package retains instruction descriptions, state/backend contracts, the CPU simulator, observables, parameter binding, and existing reverse passes. GPU support that reuses the existing dense state types needs array-generic storage and device kernels; passing a GPU array to today's dense constructors converts it to CPU storage. A companion package can instead supply its own device-resident state and backend through the public contracts.

MPS, stabilizer simulation, continuous open-system solvers, specialized algorithm workflows, error correction, chemistry, and framework interoperability can live in companion packages. Their dependencies and numerical assumptions can evolve while using the public contracts above. No companion package should rely on private CPU kernels as its public integration path.
