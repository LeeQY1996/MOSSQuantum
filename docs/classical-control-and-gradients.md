# Classical feedback and finite-shot optimization

These interfaces use the CPU execution engine and explicit RNGs. No optional AD
package is needed. Classical control is supported by `simulate`, `execute`, and
circuit `estimate`; use these recorded execution APIs for dynamic circuits.

## Named measurements and feedback

```julia
using MOSSQuantum, Random
circuit = QCircuit([
    HGate(1),
    QMeasure(1; key=:syndrome, auto_reset=false),
    Conditional(:syndrome, XGate(1)),
])
result = execute(circuit, StateVector(1); shots=1000, rng=Xoshiro(42))
@assert result.counts == Dict("0" => 1000)
classical_counts(result, :syndrome) # histogram of reported intermediate bits
register = classical_register(result)[1] # independent copy for the first attempt
register[:syndrome]
result.measurements[1][1].key
```

`QMeasure(...; key=:name)` writes a classical bit. Symbols and nonempty strings
are accepted. Repeated keys overwrite the register's latest value; measurement
records retain the entire history. Unnamed measurements retain their existing
behavior. `ClassicalRegister(Dict(:flag=>1))`, or the dictionary itself, can be
passed as `classical=` to initialize every execution independently.

`Conditional(key, instruction; value=1, otherwise=QCircuit())` executes one
branch. A branch may itself be a circuit containing measurements, gates, channels,
or nested conditions. For several bits use
`Conditional(ClassicalCondition((:a, :b), 2), XGate(1))`: the first key is the
least significant bit, so this tests `a=0, b=1`. Conditions use equality; loops
and classical arithmetic are not provided. Active parameter order visits the
then branch followed by the else branch, including untaken branches.

Feedback reads **reported** bits by default, including intermediate
`ReadoutError(...; scope=:measurement)` or `scope=:all`. Physical measurement
outcomes are retained separately in `register.physical` and records' `outcome`.
`source=:physical` on a condition is an ideal diagnostic option. Automatic
measurement reset remains ideal; use `auto_reset=false` followed by a conditional
X gate to model reset through an imperfect classical report.

Static validation requires a key to be defined on every preceding path before
reading it. Both branches are checked for valid registers and supported
instructions before sampling, including when requesting zero shots. Noise rules
are expanded inside each branch and only execute when that branch is taken.

A `SimulationResult` has one `.classical` register. A `BatchSimulationResult`
has one per batch member. `ShotResult.classical` and `.measurements` have one entry
per **attempt**, whereas `.samples` contains accepted shots only. Registers are
independent snapshots. `classical_counts(result, keys; accepted_only=true)` filters
rejected attempts; the default includes them. It throws if a requested key is
absent in an included attempt. Histogram characters follow the requested key
order (first key on the left), just as terminal quantum count strings follow
qubit order. `source=:physical` selects physical bits for this histogram.
`result=:counts` retains only terminal counts, without classical histories.

Density evolution and `KrausTrajectory()` support feedback; trajectory shots also
support threaded execution. A batch with different branch-dependent state types
is returned as a density-matrix batch if any member becomes mixed. Dynamic or
trajectory `simulate` rejects `QSelect`: use `execute` for physical rejection.
Circuit expectation estimation continues to reject post-selection.

## Finite-shot objectives and gradients

```julia
using MOSSQuantum, Random
circuit = QCircuit([RyGate(1, 0.; isparas=true), Depolarizing(1; p=.02)])
objective = ShotExpectationObjective(circuit, QubitsTerm(1=>Z), StateVector(1);
                                     shots=2000)
g = estimate_gradient(ParameterShift(), objective, [.4]; rng=Xoshiro(42))
@assert g.shots == 6000
@assert g.evaluations == 3
(g.value, g.gradient, g.stderr)
value, gradient = value_and_gradient(ParameterShift(), objective, [.4];
                                     rng=Xoshiro(42))
```

`ShotExpectationObjective` snapshots the circuit, observable, state, and initial
classical register. `parameter_map=ParameterMap(...)` supports shared parameters.
`method=KrausTrajectory()`, `noise_model=`, `readout=`, and `classical=` select
execution behavior. Noise rules are expanded **once at construction** and frozen,
including factories that inspect gate angles. Trainable noise is not part of
this objective. For parameter-dependent noise, explicitly construct/evaluate it
inside a function and use a numerical method; generic functions do not supply
measurement variance or shot accounting automatically.

`shots` is the budget for **each objective evaluation**, distributed across Pauli
measurement groups. It is not the total gradient budget. Each nonconstant group
needs at least two shots. Constant-only observables consume zero actual shots.
`estimate(objective, parameters; rng)` returns an `ExpectationEstimate`, and
`evaluate(objective, parameters; rng)` returns its scalar value.

| Gradient method | Evaluations, including a fresh value | Interpretation |
| --- | --- | --- |
| `ParameterShift()` | 1 plus recipe terms for every active gate occurrence | Exact shift identity with statistical measurement error |
| `FiniteDifference(step=.01)` | `1 + 2n` | Central difference; finite-step bias, noise amplified by small steps |
| `SPSAGradient(step=.1, directions=8)` | `1 + 2directions` for nonempty parameters | Averaged simultaneous random perturbations, independent of parameter count |

Parameter shift supports Rx/Ry/Rz, phase, controlled phase, doubly controlled
phase, controlled rotations, and their adjoints. Controlled rotations use four
terms because their generator has two nonzero frequency gaps. Shared gate slots
are shifted **separately**, then summed into the independent parameter gradient.
Unknown active gate families are rejected rather than assigned an invalid rule.
An external gate can implement `parameter_shift_rule(gate, active_index)` returning
`(coefficient, shift)` pairs; this is a mathematical contract for its whole gate
family. Use `supports_gradient(method, objective)` to query support.

`GradientEstimate` reports an independent value and its variance, gradient,
`sampling_covariance`, `covariance`, `stderr`, actual total `shots`, and
`evaluations`. Evaluations use independent sampling. For parameter shift and
central differences, covariance propagates measurement variance. For SPSA,
`sampling_covariance` includes correlations caused by shared perturbed evaluations;
`covariance` estimates both shot and random-direction variation from repeated
directions. With only one direction, `covariance` and `stderr` are `nothing`.
Finite-step bias, physical noise bias, and finite-sample error guarantees are not
included. Near-deterministic finite samples can underestimate uncertainty.

These explicit stochastic gradient methods do not make random draws differentiable
through Zygote. Deterministic `ExpectationObjective` also supports these methods;
finite differences and SPSA additionally accept scalar functions through the
existing `evaluate` protocol. Batch objectives require an explicit reduction.

## Optimization workflow

The [optimization example](../examples/optimization/README.md) provides SGD
and Adam updates, SPSA perturbation decay, seeded execution, callbacks, history,
and total shot accounting. The reusable optimizer lives in `MOSSQuantum.Optimization`; the core package also owns
the objective and gradient interfaces.

Concept references: [Cirq classical controls](https://quantumai.google/cirq/build/classical_control),
[PennyLane parameter shift](https://docs.pennylane.ai/en/stable/code/api/pennylane.gradients.param_shift.html),
and [Qiskit SPSA](https://qiskit-community.github.io/qiskit-algorithms/stubs/qiskit_algorithms.optimizers.SPSA.html).

Prepared execution now backs CPU shot objectives. For reusable plans, parameter
sweeps, adaptive allocation and a total optimization shot cap, see
[prepared experiments](prepared-experiments.md).
