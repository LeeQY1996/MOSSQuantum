# MOSSDemoDifferentiation

This independent package demonstrates MOSS's public scalar differentiation
protocol. Its objective returns a scalar from an interchangeable executor and
exposes no quantum state, storage, or MOSS backend. It is a protocol fixture,
not a hardware driver.

`DirectExecutor` and `ExpandedExecutor` evaluate the same quadratic using
different expressions. `CoordinateGradient` and `ExpandedGradient` are two
independent closed-form implementations of `AbstractGradientMethod`. Their
counters verify that the requested method runs. They do not implement a
numerical gradient estimator.

MOSS is the only runtime dependency. After developing the fixture into an
environment, forward execution and explicit gradients work without an AD package:

```julia
import MOSS
using MOSSDemoDifferentiation

objective = ScalarObjective(DirectExecutor())
theta = [0.7, -0.1]
value = MOSS.evaluate(objective, theta)
method = CoordinateGradient()
value, gradient = MOSS.value_and_gradient(method, objective, theta)
updated = theta - 0.1 .* gradient
@assert MOSS.evaluate(objective, updated) < value

# Execution and differentiation can be replaced independently.
replacement = ScalarObjective(ExpandedExecutor())
@assert MOSS.evaluate(replacement, theta) ≈ value
@assert MOSS.value_and_gradient(ExpandedGradient(), replacement, theta)[2] ≈ gradient
```

With Zygote installed in the calling environment, the scalar adapter selects the
same public numerical method. An ordinary `differentiable_value` call only
evaluates the objective; its reverse rule dispatches through `value_and_pullback`.
The method and objective are fixed configuration; only the explicit values
receive a cotangent.

```julia
import Zygote
loss(values) = MOSS.differentiable_value(method, objective, values)
@assert only(Zygote.gradient(loss, theta)) ≈ gradient
```

From the MOSS repository root, run the independent package tests with Julia 1.10
or 1.13:

```bash
julia --project=test/fixtures/MOSSDemoDifferentiation --startup-file=no -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.test()'
julia --project=test/fixtures/MOSSDemoDifferentiation --startup-file=no test/fixtures/MOSSDemoDifferentiation/test/core_only.jl
```

The test target adds Test, ChainRulesCore, and Zygote. Tests first run the core
protocol with neither AD package loaded, then call the ChainRules rule without
Zygote, and finally check Zygote's selection of each external method. They cover
cached and repeatable pullbacks, zero and thunk cotangents, independent returned
vectors, input precision, executor replacement, and rejected unsupported or
malformed gradient implementations. They make no claim that every MOSS backend
supports gradients.
