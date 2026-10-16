# MOSSDemoGates

This independent test package defines `DemoRotation <: MOSS.ParametricGate{1}`.
Its immutable fields are `wire`, `angle`, and `trainable`. It implements only
public MOSS methods, including positions and matrices, parameter readers,
replacement-aware reset and activation, and the existing CPU derivative convention.

From the MOSS repository root, run it with Julia 1.10 or 1.13:

```bash
julia --project=test/fixtures/MOSSDemoGates --startup-file=no -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.test()'
```

MOSS is the only runtime dependency. Zygote and FiniteDifferences belong to the
test target. After developing this fixture into an environment that also has
Zygote, its training workflow is:

```julia
import MOSS, Zygote
using MOSSDemoGates

template = MOSS.QCircuit([DemoRotation(1, 0.0)])
initial = MOSS.qstate(1)
observable = MOSS.QubitsTerm(1 => "Z")
loss(values) = real(MOSS.expectation(observable,
    MOSS.bind_parameters(template, values) * initial))

theta = [0.4]
gradient = Zygote.gradient(loss, theta)[1]
updated = theta - 0.2 .* gradient
@assert loss(updated) < loss(theta)
```

The tests check analytic and finite-difference gradients, one descent step,
nested and repeated gate occurrences, frozen parameters, adjoint wrappers,
input independence, fixed CPU noise, and unsupported gradient paths. They never
access a state's storage or MOSS's private reset hooks.
The execution and reverse pass in this example use MOSS's dense CPU states.
General backend gradients, batch gradients, trainable noise, and stochastic AD
remain outside this fixture's contract.
