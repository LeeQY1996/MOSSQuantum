# Named circuit parameters

`Parameter` gives a circuit variable a stable identity. `ParameterExpr` describes
real affine combinations of these variables, including shared angles, scales
and constant offsets. Bind a template to numeric gates before executing it, or
pass the template directly to an objective or prepared plan.

```julia
using MOSSQuantum

θ = Parameter(:θ)
φ = Parameter(:φ)
circuit = QCircuit([RyGate(1, θ), RzGate(2, -θ/2 + φ + π/4),
                    CNOTGate(1, 2), RyGate(2, θ)])

independent_parameters(circuit) # [θ, φ]
nparameters(circuit)            # 3 gate slots, 2 independent variables
bound = bind_parameters(circuit, Dict(θ => 0.4, φ => 0.1))
state = simulate(bound, StateVector(2)).state
```

Reusing `θ` shares a variable. Constructing another `Parameter(:θ)` creates a
different identity with the same display name. Copies preserve identity;
joining circuits does not merge variables by name. Binding by symbol or string
is convenient when every name is unique; otherwise use parameter objects as
keys. Unknown and missing bindings are errors.

Expressions support addition, subtraction, multiplication by real constants and
division by nonzero real constants. They are immutable and do not hold a mutable
current value. `θ-θ` removes the variable exactly, while small nonzero
coefficients remain. Products of variables and nonlinear symbolic functions are
outside the affine interface.

## Mixing named and numeric parameters

The three existing gate declarations can appear in the same circuit:

```julia
θ = Parameter(:θ)
mixed = QCircuit([
    RyGate(1, rand(); isparas=true), # anonymous trainable slot
    RyGate(1, θ),                  # named trainable variable
    RzGate(1, rand()),              # fixed numeric angle
    RyGate(1, 2θ + 0.1),            # shares θ
])
compiled = compile_parameters(mixed)
objective = ExpectationObjective(compiled, QubitsTerm(1 => "Z"), StateVector(1))
x0 = initial_parameters(objective; values=Dict(θ => 0.3))
value, gradient = value_and_gradient(AdjointGradient(), objective, x0)
```

The compiler automatically assigns an anonymous `Parameter` to each numeric
active slot. Its default initial value is the numeric value already stored in
the gate; compilation and initialization do not draw another random number.
The default input order in this example is `[anonymous, θ]`. Traversal
interleaves numeric slots with the first occurrence of each named identity.
Repeating the same numeric gate object creates separate occurrence inputs;
reuse an explicit `Parameter` to share a variable.

`initial_parameters` returns a complete vector in `parameter_order` order.
Named variables require explicit initial values. Missing or conflicting defaults,
unknown keys, nonfinite values and assignments to fixed inputs are errors.
For pure numeric circuits, the helper uses existing active angles and integer
map IDs. Shared integer-map slots with different initial values require an
explicit value by ID.

Initialization does not save the optimizer's current values. After updating
`x`, pass the full updated vector to binding, evaluation and gradient functions;
these calls do not restore captured defaults. To inspect handles, defaults,
fixed status, current input indices and original slot sources, use
`parameter_info(compiled)` or the same query on an objective or prepared plan.

```julia
a = first(parameter_order(compiled))
bound = bind_parameters(compiled, Dict(a => 0.2, θ => 0.3))
reordered = compile_parameters(compiled; parameter_order=[θ, a])
frozen = compile_parameters(compiled; fixed=Dict(a => 0.2))
```

Complete dictionary binding requires every trainable variable. Anonymous
variables are addressed by their handles; generated labels are for display.
Symbol and string keys resolve explicit named variables only. Use either
handles or names throughout one dictionary. For partial initial assignments,
call `initial_parameters` explicitly.

Reuse the full compiled context to retain anonymous identities, defaults and
sources. Independently compiling the raw circuit creates new anonymous
identities with the same numeric order and behavior. Raw mixed circuits do not
invent temporary identities for `parameter_order` or `independent_parameters`;
query the compiled result or an objective. Custom ordering of mixed inputs must
also use the complete handles from a compiled context.

## Parameter order and objectives

Default variable order follows first occurrence in the circuit and its
expressions. Nested circuits retain traversal order; conditions discover both
branches, then before else. Capture an explicit order for vector input:

```julia
observable = QubitsTerm(1 => "Z") + 0.3 * QubitsTerm(2 => "X")
objective = ExpectationObjective(circuit, observable, StateVector(2);
    parameter_order=[θ, φ])
value, gradient = value_and_gradient(AdjointGradient(), objective, [0.4, 0.1])
parameter_order(objective) # [θ, φ], also the gradient order
```

The objective snapshots the parameter layout and retains the sharing relation.
A fully bound numeric circuit does not retain this symbolic map; constructing a
legacy objective from `bound` treats its active numeric slots independently.

The compiler expands active angles as `α = A*x + b`. Adjoint and parameter-shift
methods return input derivatives through `A' * gα`. Parameter shifts act on each
gate occurrence separately. Finite differences and SPSA perturb the independent
input variables. Finite-shot parameter-shift covariance includes correlations
between variables that influence the same gate slot.

`supports_gradient(method, objective, values)` checks a concrete binding. This is
useful for external gates whose validity depends on their numeric angles; the
two-argument query can conservatively reject an unbound template. Existing
numeric objectives retain their support checks before binding unsupported paths.

## Fixing and replacing variables

Fix variables in a particular objective without changing its source template:

```julia
fixed_objective = ExpectationObjective(circuit, observable, StateVector(2);
    parameter_order=[θ, φ], fixed=Dict(φ => 0.1))
trainable_parameters(fixed_objective) # [θ]
value, gradient = value_and_gradient(AdjointGradient(), fixed_objective, [0.4])
```

The fixed value is captured by the objective. Its optimizer input and output
gradient both contain only the remaining trainable variables. Fixing θ in
`2θ+φ` still leaves φ trainable. An existing compiled context can append fixed
variables through `compile_parameters(compiled; fixed=...)`. Changing or removing
an existing fixed value requires rebuilding from the source template.

Use `substitute_parameters(circuit, Dict(φ => 0.1))` to create a new template with
φ replaced permanently. Replacements may also be parameters or affine
expressions, enabling intentional sharing and renaming. All replacements apply
simultaneously once. Bind remaining variables to materialize numeric gates;
when none remain, use `bind_parameters(template, Dict())`.

## Prepared execution and fixed noise

Prepared interfaces use the same variable order and fixed-value configuration:

```julia
plan = prepare_execution(circuit, StateVector(2);
    parameter_order=[θ, φ], fixed=Dict(φ => 0.1))
result = execute(plan, [0.4]; shots=1000)
```

`prepare_estimation`, finite-shot objectives and parameter sweeps use the same
input convention. `compile_parameters` exposes the compiled template and map
for extensions that need `expand_parameters` and
`accumulate_parameter_gradients`; the map owns the variable order and scaling.
The compiled template can still contain symbolic wrappers, including fixed
expressions. Compilation does not materialize placeholder gates. Bind through
the returned map to obtain an executable numeric circuit:

```julia
compiled = compile_parameters(circuit; parameter_order=[θ, φ])
bound = bind_parameters(compiled, [0.4, 0.1])
plan = prepare_execution(compiled, StateVector(2))
```

On an unbound template, noise rules can match an instruction type and insert a
fixed `QuantumMap`, for example
`NoiseRule(RyGate, BitFlip(1; p=0.01))`. Matching uses the original gate family,
even while it is wrapped by the parameter front end. Predicates and callable
noise factories require numeric binding first, because they may inspect an
angle. Fixed noise does not become trainable through a gate parameter map.

Pass the raw circuit together with `noise_model` when preparing a circuit whose
noise rules insert instructions. Expansion then happens before its one parameter
compilation. A noise expansion that changes an existing compiled context's layout
is rejected; it cannot silently reuse old anonymous source coordinates.
Readout-only configuration preserves the context's identities.

## External gates

`parameterize(prototype, expressions)` maps expressions to the prototype's
current active slots. An extension whose public writers cannot set the requested
activity mask can implement `materialize_parameters`. Specialize both the gate
and the vector arguments to avoid ambiguity with the default method. For example,
an immutable one-angle gate can own its numeric value and activity flag:

```julia
import MOSSQuantum as MQ

struct ExampleAngleGate <: MQ.Gate{1}
    position::Int
    angle::Float64
    active::Bool
end
MQ.positions(g::ExampleAngleGate) = (g.position,)
MQ.parameters(g::ExampleAngleGate) = [g.angle]
MQ.active_parameters(g::ExampleAngleGate) = g.active ? [g.angle] : Float64[]
MQ.nparameters(g::ExampleAngleGate) = Int(g.active)
MQ.copy_instruction(g::ExampleAngleGate) = g

function MQ.materialize_parameters(g::ExampleAngleGate,
        values::AbstractVector{<:Real}, active_mask::AbstractVector{Bool})
    length(values) == length(active_mask) == MQ.nparameters(g) ||
        throw(DimensionMismatch("prototype active slots disagree"))
    isempty(values) && return g
    value = only(values)
    !(value isa Bool) && isfinite(value) && isfinite(Float64(value)) ||
        throw(ArgumentError("a finite numeric angle is required"))
    return ExampleAngleGate(g.position, Float64(value), only(active_mask))
end
```

Here `values` and the mask describe only the prototype's original active slots.
The hook preserves every original frozen parameter and returns independent
numeric storage; immutable values can return themselves. A gate's matrix,
backend execution, position-change and derivative methods remain its separate
extension protocols; this example defines only its parameter materialization.

Mixed compilation also records `parameter_slots(gate)`, the stable physical slot
keys corresponding to the current active parameters. Built-in gates derive
these keys from their activity masks. External instructions with all numeric
parameters active can use the default sequential keys; instructions with a
partial mask should define this protocol when the mask cannot be inferred.
Changing a partial activity mask invalidates an old affine map even when the
number of active slots stays the same.

## Legacy and backend boundaries

Existing numeric gate constructors, `isparas`, active-slot binding and integer
`ParameterMap` keep their behavior. A symbolic circuit may contain ordinary
numeric constant gates and numeric active gates. Active numeric slots are
integrated automatically when named expressions are present. A mixed circuit
cannot also supply a legacy integer `ParameterMap`; use named sharing or a
compiled affine context. The detailed contracts are described in the
[mixed parameter design](mixed-parameter-design.md).

Backends receive the original numeric gate types. Dense, MPS and stabilizer
capabilities continue to depend on the selected gates and gradient method;
binding an arbitrary rotation does not add it to the stabilizer gate set.
Unbound templates are rejected before circuit evolution or execution RNG use,
and capability queries report that numeric binding is required.

The runnable examples are [named_parameters.jl](../examples/named_parameters.jl)
and [mixed_parameters.jl](../examples/mixed_parameters.jl).
The detailed contracts and implementation stages are in the
[parameter design](parameter-design.md).

## Named-parameter baseline validation

Acceptance on 2026-10-30 passed the complete core suite on both supported
development targets. Julia 1.13.1 ran `Pkg.test(; test_args=["--load-orders"])`;
Julia 1.10.12 ran `Pkg.test()` in a fresh environment followed by the eight
independent-process loading scenarios.

| Scope | Passing assertions |
| --- | ---: |
| MOSSQuantum on Julia 1.13.1, including eight loading scenarios | 10,235 |
| MOSSQuantum on Julia 1.10.12 | 10,227 |
| Julia 1.10.12 independent loading scenarios | 8 |
| MPS backend integration | 186 |
| Stabilizer complete suite | 4,178 |
| Chemistry complete suite | 974 |

The core adds 336 assertions for named parameters, compilation, gradients,
execution, ownership, unsupported boundaries and plotting. The MPS checks use
`NoTruncation` for parameter-shift and finite-difference comparisons; this does
not establish a native MPS adjoint method.

## Automatic mixed-parameter validation

Acceptance on 2026-10-30 adds 321 assertions for automatic mixed compilation,
physical slot layouts, captured defaults, fixed and reordered inputs, prepared
execution, sampling covariance, finite differences, SPSA and optional AD.

| Scope | Passing assertions |
| --- | ---: |
| MOSSQuantum on Julia 1.13.1, including eight loading scenarios | 10,556 |
| MOSSQuantum on Julia 1.10.12, including eight loading scenarios | 10,556 |
| MPS backend integration | 197 |
| Stabilizer complete suite | 4,185 |
| Chemistry default complete suite | 974 |

The mixed-parameter example also executes completely. These checks preserve
existing backend and differentiation boundaries; the optional live PySCF suite
is not part of the Chemistry default acceptance.
