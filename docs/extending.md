# Extending MOSS

MOSS currently supports customization within its existing dense simulator, especially matrix-defined gates, parameterized gates, and Kraus channels. A general backend and state protocol is planned. This guide describes the available entrypoints and the boundaries that the core foundation work must establish before companion packages can rely on them.

## Use existing operation types first

A custom dense matrix can use `QuantumGate` without defining a new operation type:

```julia
using MOSS

phase = ComplexF64[1 0; 0 cis(0.2)]
operation = QuantumGate(1, phase)
circuit = QCircuit()
push!(circuit, operation)
state = apply!(circuit, qstate(2))
```

The matrix uses MOSS local bit ordering: the first gate position is the least significant local bit. `QuantumGate` does not validate unitarity, so the caller is responsible for the intended physical operation. See the [conventions](conventions.md) before importing matrices from another framework.

Existing `QuantumMap` constructors accept Kraus matrices. Dense channel application returns a density matrix, including when its input is a state vector. A channel's physical qubit count is not its superoperator kernel arity; current generic CPU kernels restrict channels to at most two physical qubits.

## Define a custom gate within the current simulator

A companion package can subtype the existing public `Gate{N}` and extend the generic functions it owns:

```julia
module ExampleGatePackage

import MOSS

struct ExamplePhase <: MOSS.Gate{1}
    position::Int
    angle::Float64
end

MOSS.positions(g::ExamplePhase) = (g.position,)
MOSS.mat(g::ExamplePhase) = ComplexF64[1 0; 0 cis(g.angle)]
MOSS.change_positions(g::ExamplePhase, mapping::AbstractDict) =
    ExamplePhase(mapping[g.position], g.angle)

end
```

This gate is accepted by the existing `QCircuit` element union and uses the generic dense gate dispatcher. It is a fixed gate: its angle is not exposed as an active trainable parameter. Independent execution and expectation checks should compare it against the equivalent `QuantumGate`.

Trainable gate types additionally need parameter storage and activation behavior, derivative gates in active-parameter order, and validation against analytic or finite-difference results. Existing parameter defaults rely on fields such as `paras` and `isparas`; a field-independent public parameter protocol is part of the planned work.

## Current extension limits

- `QCircuit` stores a closed union of circuits, gates, channels, measurement, and post-selection. A new subtype of the broader internal `QuantumOperation` hierarchy is not automatically accepted as a circuit instruction. Operator objects also live in that hierarchy, so accepting every operation indiscriminately would be incorrect.
- Dense states have concrete `Vector` or `Matrix` fields. Passing a GPU array to a constructor currently converts it to CPU storage; adding an array type does not supply GPU execution kernels.
- Execution, observables, and AD registrations dispatch on the concrete dense state types. Implementing an arbitrary state representation requires more than providing `storage` and `nqubits`.
- CPU gate execution supports up to five acted-on qubits. Batch support covers gates and expectations; it does not establish batch support for every operation or for gradients.
- Zygote registrations and the reverse-pass implementation remain in the main package. There is no selectable AD or simulator backend object yet.
- A circuit run currently returns the final state and loses individual measurement records. There is no unified shots, counts, result, or explicit RNG interface.

The current source layout makes these implementation boundaries easier to change. It does not make those planned APIs available.

## Planned public contracts

The following contracts are design targets rather than API names or signatures to import:

| Contract | Required behavior |
| --- | --- |
| Executable instruction | Circuit admission, positions, remapping, validation, parameters when relevant, and a clear separation from observable-only operations |
| State | Qubit count, element and precision information when meaningful, independent copying, and supported execution or observation capabilities without mandatory dense amplitudes |
| Execution | Dispatch to an implementation, retain replacement states, declare supported instructions, and report unsupported capabilities clearly |
| Observation | Compute expectations and requested measurement information without forcing all representations to materialize dense storage |
| Parameters | Stable order, independent binding, active parameter selection, shared parameter identity, and gradient accumulation |
| Results and randomness | Explicit RNG routing, bit ordering, measurement records, probabilities, shots, counts, and uncertainty information where applicable |
| Differentiation | Reusable reverse algorithms with explicit support limits and separate AD framework registrations |

Position and dimension validity must be checked independently of backend capabilities. An operation representation should be able to describe a gate even if the dense CPU backend cannot execute it. Unsupported differentiation should fail explicitly rather than silently returning an incorrect gradient.

## Independent package acceptance

Before declaring the extension contracts stable, a fixture package must have its own `Project.toml`, depend on MOSS, and use `import MOSS` through normal package loading. It must define an external instruction or state, execute it through a documented public entrypoint, and compute an expectation.

The fixture must verify independent state ownership and applicable numerical invariants. It must also exercise unsupported capabilities, such as noise or gradients, and obtain clear errors. It must not `include` MOSS source files, access `.data`, or invoke underscore-prefixed kernel functions.

That fixture is planned for the final foundation stage. The example custom gate above demonstrates the existing gate customization path; it is not a substitute for an independent backend fixture.
