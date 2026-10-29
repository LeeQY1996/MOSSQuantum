# Prepared execution, parameter sweeps and shot budgets

Prepared plans reuse CPU circuit validation, expanded fixed noise, measurement
metadata and compiled Kraus channels. Binding changes active gate values; it does
not rerun noise factories. Existing `execute(circuit, state)` and
`estimate(H, circuit, state)` remain available.

## Prepare, bind, execute

```julia
using MOSSQuantum, Random
circuit = QCircuit([
    RyGate(1, 0.; isparas=true), CNOTGate(1, 2),
    AmplitudeDamping(1; γ=.08),
])
plan = prepare_execution(circuit, StateVector(2); method=KrausTrajectory())
bound = bind_execution(plan, [.4])
workspace = ExecutionWorkspace(bound)
result = execute(bound; shots=1000, result=:counts,
                 workspace=workspace, rng=Xoshiro(42))
@assert result.shots == 1000
@assert sum(values(result.counts)) == 1000
```

`prepare_execution` accepts `parameter_map`, `method`, `noise_model`, `readout`,
`classical`, and `qubits`. It snapshots its inputs and checks the circuit's
positions, capabilities, physical channels and definite classical assignment.
The current implementation accepts one dense CPU `StateVector` or `DensityMatrix`;
trajectory evolution requires a pure state. State batches and device execution
are not silently routed through this API.

`bind_execution(plan, values)` uses independent parameter order from the map.
It binds and validates active gates, including gates inside conditional branches.
Fixed instructions and compiled channels are reused. Parameters on custom
non-gate instructions are explicitly unsupported. A parameterless plan accepts
`bind_execution(plan)`; a parameterized plan requires values. Shared maps such
as `ParameterMap([1, 1])` are supported.

For deterministic density evolution, binding prepares the state and terminal
probability distribution once. Repeated execution samples that distribution.
Dynamic circuits and trajectories still rerun the circuit for every shot.
The shorter `execute(plan, values; shots, ...)` binds on each call; explicitly
retain a bound plan when repeatedly using the same parameters.

Plans are immutable containers with owned arrays: **treat all fields as
read-only**. Rebuild them to change circuit structure, state, measurement
selection, backend/method, or noise. Mutating the original inputs does not change
a plan. Noise factories that depend on gate angles are evaluated at preparation
and frozen; updating angles does not update those channels. Prepared plans are
not an automatic cache that tracks mutations to external objects.

Every execution has independent states, records and classical registers.
`ExecutionWorkspace(bound)` optionally retains trajectory state/scratch/weight
buffers across calls and is tied to that exact bound plan. Using it with a
different binding is an error. Concurrent use of one workspace is serialized;
separate workspaces allow independent concurrent calls. Threaded trajectory
shots use worker-local buffers. RNG ownership remains the caller's responsibility:
do not concurrently mutate the same RNG.

## Repeated expectations and parameter sweeps

```julia
using MOSSQuantum, Random
ansatz = QCircuit([RyGate(1, 0.; isparas=true), Depolarizing(1; p=.03)])
hamiltonian = QubitsTerm(1=>Z) + .2QubitsTerm(1=>X)
energy_plan = prepare_estimation(ansatz, hamiltonian, StateVector(1))
parameters = reshape(collect(range(.1, 1.; length=8)), 1, :)
experiment = run_sweep(energy_plan, parameters; shots=1000,
                       parallel=true, rng=Xoshiro(42))
@assert experiment.shots == 8000
@assert experiment.evaluations == 8
energies = [r.value for r in experiment.results]
errors = [r.stderr for r in experiment.results]
```

`prepare_estimation` adds reusable Pauli grouping and basis rotations to the
execution configuration. It accepts `grouping`, `atol`, `max_terms`, and the
execution options except `qubits` (chosen by each measurement group). As in the
existing estimator, basis rotations are ideal and readout errors are applied
subsequently. Post-selection is rejected.

`estimate(energy_plan, values; shots, rng)` binds and estimates once;
`estimate(bind_execution(energy_plan, values); shots, rng)` reuses a binding.
A deterministic base state is evolved once per binding and copied for each
measurement basis. Dynamic circuits are rerun independently for every group and
shot. Group statistics include covariance between terms measured together.

`run_sweep` accepts either an execution plan or an estimation plan. Parameter
**columns** are points, rows are independent parameters. `shots` is per point;
`ExperimentResult.parameters` snapshots the matrix, `.results` preserves column
order, `.shots` totals actual charged shots, and `.evaluations` counts points.
Execution sweeps return `CountsResult` by default or `ShotResult` with
`result=:full`; expectation sweeps return `ExpectationEstimate` or
`AdaptiveEstimate`. Empty sweeps return typed empty results and consume no RNG.

All parameter bindings are validated before RNG seeds are drawn. One seed is
assigned per column, so serial and threaded sweeps agree in the same Julia
environment. Sweep parallelism is across points, without nested shot threading.
`chunk_size` controls shot chunks inside each execution, not parameter columns.
Bound instruction trees are retained for the scan, but prepared quantum states
are materialized only for active workers; the scan does not retain a density
matrix for every parameter point. Full shot records can still be large.

The sampled expectation objective also uses prepared execution internally, so
`estimate_gradient` and the optimizer benefit without changing their call sites.
Fixed seeds reproduce a chosen API/algorithm within the same environment; an
optimized estimator need not reproduce the draw order of an older release or
of a differently grouped/direct API.

## Variance-based shot allocation

```julia
using MOSSQuantum, Random
allocation_plan = prepare_estimation(QCircuit(),
    QubitsTerm(1=>Z) + 100QubitsTerm(1=>X), StateVector(1))
adaptive = estimate(allocation_plan; shots=2000,
    allocation=VarianceAllocation(pilot_shots=16), rng=Xoshiro(42))
@assert adaptive.shots == 2000
@assert adaptive.pilot_shots == 32
@assert adaptive.production_shots == 1968
```

Uniform allocation remains the default. `VarianceAllocation` first samples
`pilot_shots` per group, then distributes the remaining production shots in
proportion to each group's estimated standard deviation, with at least two
production shots per group. Ties are resolved in group order. If all pilot
variances are zero, the remaining allocation is uniform. The total request must
cover both pilot and production minima; validation happens before sampling.

Pilot data choose the allocation and are **not reused in the reported mean**.
Production samples are independent of the pilot, so conditioning on the chosen
allocation preserves the mean's unbiasedness. The variance is the sum of
production group sample variances divided by their respective shot counts.
`AdaptiveEstimate.groups` contains production statistics, `.pilot_groups` records
pilot statistics, and `.shots` includes both. Constant-only observables consume
zero shots and need no pilot. Pilot error can choose a poor allocation; this
strategy is not a guaranteed improvement for every observable or budget.

`ShotExpectationObjective(...; allocation=VarianceAllocation(...))` applies this
policy to each value/shift evaluation. Each evaluation's `shots` includes its
pilot. Gradient uncertainty propagates the independent production variances.
The total objective/gradient budget still accounts for every pilot sample.

## Hard budgets and bounded optimization

```julia
using MOSSQuantum, Random
budget_circuit = QCircuit([RyGate(1, 0.; isparas=true)])
objective = ShotExpectationObjective(budget_circuit, QubitsTerm(1=>Z),
                                     StateVector(1); shots=100)
cap = ShotBudget(300)
@assert required_shots(ParameterShift(), objective, [.4]) == 300
gradient = estimate_gradient(ParameterShift(), objective, [.4];
                             budget=cap, rng=Xoshiro(42))
@assert gradient.shots == 300
@assert remaining_shots(cap) == 0
```

Pass `budget=ShotBudget(limit)` to prepared execution/estimation, `run_sweep`,
shot-objective `estimate`/`evaluate`, or the built-in explicit gradient methods.
A complete call reserves its required shots atomically. Insufficient budget
throws `ShotBudgetExceeded` before sampling and does not change the budget or
RNG. Concurrent calls cannot overspend. Zero-shot constant observables can still
execute on an exhausted budget. For execution/post-selection, a shot counts an
attempt, consistent with `execute`.

If an error occurs after reservation, the charge is retained conservatively:
work may already have sampled. Thus `.used` is a charged upper bound after a
failed call, not a claim that all reserved shots completed. Treat the budget's
fields as read-only and use `remaining_shots` to query it. Plans and bindings may
be prepared before a budget refusal; the cap concerns shots, not preparation
CPU time or memory.

The [optimization workflow](../algorithm_zoo/optimization/README.md) accepts
`max_shots`. It reserves room for one fresh final estimate, completes only whole
gradient/update steps that fit, and returns `status=:shot_budget` when the next
step cannot fit. A budget smaller than the final estimate is rejected. It never
silently lowers the requested precision per evaluation to fit another step.

## Validation and measured scope

Tests compare prepared execution with direct noisy execution, cover classical
feedback/post-selection, shared parameters, immutable inputs, repeated and
concurrent workspaces, serial/threaded scans, pilot variance accounting,
concurrent budget contention and capped optimization. Seeded multi-run checks
cover adaptive means and estimated variance.

The [performance report](performance/prepared-2026-10-29/README.md) records
construction cost, warmed execution time and cumulative allocations for repeated
sampling, dynamic feedback, parameter scans and noisy variational gradients.
Dense simulation remains exponential in the number of qubits; these changes
reduce repeated preparation overhead and do not change that scaling.
