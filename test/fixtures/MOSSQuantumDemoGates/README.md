# MOSSQuantumDemoGates

This independent test package defines `DemoRotation <: MOSSQuantum.ParametricGate{1}`.
Its immutable fields are `wire`, `angle`, and `trainable`. It implements only
public MOSSQuantum methods, including positions and matrices, parameter readers,
replacement-aware reset and activation, and the existing CPU derivative convention.

From the MOSSQuantum repository root, run it with Julia 1.10 or 1.13:

```bash
julia --project=test/fixtures/MOSSQuantumDemoGates --startup-file=no -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.test()'
```

MOSSQuantum is the only runtime dependency. Zygote and FiniteDifferences belong to the
test target. After developing this fixture into an environment that also has
Zygote, its training workflow is:

```julia
import MOSSQuantum, Zygote
using MOSSQuantumDemoGates

template = MOSSQuantum.QCircuit([DemoRotation(1, 0.0)])
initial = MOSSQuantum.qstate(1)
observable = MOSSQuantum.QubitsTerm(1 => "Z")
loss(values) = real(MOSSQuantum.expectation(observable,
    MOSSQuantum.bind_parameters(template, values) * initial))

theta = [0.4]
gradient = Zygote.gradient(loss, theta)[1]
updated = theta - 0.2 .* gradient
@assert loss(updated) < loss(theta)
```

## Explicit shared parameters

A `ParameterMap` assigns independent values to the circuit's active parameter
slots in traversal order. For example, `[1, 2, 1]` uses the same first value for
the first and third slots:

```julia
template = MOSSQuantum.QCircuit([
    DemoRotation(1, 0.1),
    MOSSQuantum.QCircuit([MOSSQuantum.RzGate(1, 0.2; isparas=true)]),
    DemoRotation(1, 0.1)',
])
parameter_map = MOSSQuantum.ParameterMap([1, 2, 1])
theta = [0.4, 0.6]
loss(values) = real(MOSSQuantum.expectation(observable,
    MOSSQuantum.bind_parameters(template, values, parameter_map) * initial))

gradient = Zygote.gradient(loss, theta)[1]
bound = MOSSQuantum.bind_parameters(template, theta, parameter_map)
slot_gradient = Zygote.gradient(bound) do circuit
    real(MOSSQuantum.expectation(observable, circuit * initial))
end
@assert gradient ≈ MOSSQuantum.accumulate_parameter_gradients(parameter_map, slot_gradient[1])
@assert MOSSQuantum.nparameters(parameter_map) == 2
@assert MOSSQuantum.nparameters(bound) == 3
```

The map is separate from the circuit and can also bind `copy_instruction(template)`.
`parameter_indices(map)` returns a defensive `Vector{Int}`. Binding copies each
instruction occurrence and expands identities into independent parameter storage.
The resulting circuit has ordinary parameter slots: subsequent reset operations
can assign different values to previously shared slots. The map provides explicit
index identities and gradient summation; it does not attach symbolic expressions
or persistent sharing constraints to the circuit.

The tests check analytic and finite-difference gradients, one descent step,
nested and repeated gate occurrences, frozen parameters, adjoint wrappers,
input independence, single-state fixed CPU noise, pure/mixed batch circuit
gradients with fixed channels, and unsupported gradient paths. Shared
parameter tests compare closed-form derivatives, finite differences, and summed
slot gradients, including shared values across different gate types. They never
access a state's storage or MOSSQuantum's private reset hooks.
The execution and reverse pass in this example use MOSSQuantum's dense CPU states.
`BatchStateVector` and `BatchDensityMatrix` use the same public
circuit/binding/expectation entrypoints, preserving their sample axis even for
batch size one. Applying fixed noise to a pure batch returns a density batch.
The external gate's gradient contract works in both noisy pure-input batches and
mixed-input batches. Batch circuit gradients share parameters across samples;
`BatchExpectationObjective` additionally
provides explicit mean, sum, or weighted scalar reductions with replaceable
gradient methods. See the [pure batch guide](../../../docs/batching.md) and
[density batch guide](../../../docs/batch-density-matrices.md).
General backend gradients, trainable noise, and
stochastic AD remain outside this fixture's contract.
