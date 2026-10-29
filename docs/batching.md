# Pure-state batches

`StateVector` represents one pure state with storage shape `(2^n,)`.
`BatchStateVector` represents independent pure states with shape `(2^n, B)`,
one sample per column. The types share operation names through dispatch. A
one-column batch remains a batch: expectation values and measurement outcomes
retain their sample axis. MOSSQuantum already uses the name `BatchStateVector`; there
is no second `StateVectorBatch` type.

Mixed states have their own `BatchDensityMatrix` with shape `(2^n, 2^n, B)`.
Both batch types share operation names, scalar objectives, and recorded results.
The [batch density guide](batch-density-matrices.md) describes mixed-state storage,
Kraus execution, conditional measurements, and deterministic gradients.

All samples in this implementation share their qubit count, circuit, parameter
vector, and observable. A different circuit parameter vector per sample is outside this
API. Ordinary construction uses dense CPU `Matrix` storage. Array inputs can
retain another matrix family with `preserve_storage=true`; execution capabilities
come from that family's backend. See the
[array extension guide](extending.md#preserve-array-storage).

## Constructing and owning states

```julia
using MOSSQuantum, Random, LinearAlgebra

batch = BatchStateVector(3, 4)                 # four copies of |000⟩
random_batch = rand_batch(MersenneTwister(8), 3, 4)
encoded = batch_qubit_encoding([0.2 0.4; -0.1 0.3]) # two qubits, two samples
one_sample = BatchStateVector(qstate(3))
sample_state = StateVector(batch, 2)
```

Array and single-state constructors permit storage reuse by default;
`copy=true` guarantees independent storage. Batch-to-batch construction retains
its historical `copy=true` default. Converting a matrix view or scalar type can
allocate even with `copy=false`. Extracting `StateVector(batch, i)` currently
allocates an independent vector in the batch array family, including with
`copy=false`. Constructing from a list of states owns a new matrix in the first
sample's family and promotes their scalar types.
`storage(batch)` exposes the mutable matrix. See the
[ownership conventions](conventions.md#copying-and-storage-ownership).

Row counts must be positive powers of two; explicit qubit counts and sample
counts must match storage. Zero qubits and empty batches are valid, for example
`BatchStateVector(0, 3)` has shape `(1, 3)` and
`BatchStateVector(3, 0)` has shape `(8, 0)`. Operations still validate registers
and shapes for an empty batch. Scalar training objectives require `B > 0`.

`normalize!` validates all column norms before updating the batch. Zero or
nonfinite norms fail without changing any column. Basis and qubit-encoding
reset functions likewise check their inputs before modification. Encoding
accepts matrix views; `reset_qubit!` also handles views overlapping its output.

## Operations and axes

| Operation | Batch behavior |
| --- | --- |
| `circuit * batch` | Independent output batch; the same gates act on every column |
| `batch = apply!(gate, batch)` | Apply one gate to every column, retaining the returned state |
| `batch = apply!(circuit, batch)` | In-place execution; retain the returned state after type promotion |
| `observable * batch`, `observable(batch)` | `QubitsTerm`/`QubitsOperator` act on every sample |
| `matrix * batch` | Apply a full register matrix to every sample |
| `apply!(channel, batch)` | Return a `BatchDensityMatrix`, one mixed state per input column |
| `expectation(observable, batch)` | Vector of length `B`, without automatic averaging |
| `expectation(left, observable, right)` | One bilinear value per corresponding pair of columns |
| `norm`, `dot`, `fidelity`, `distance` | One value per sample or corresponding sample pair |
| `probabilities(batch)` | Shape `(2^n, B)`; marginal readout retains the sample axis |
| `sample(batch, shots)` | Shape `(shots, n, B)` with shots, qubits, samples as separate axes |
| `counts(batch, shots)` | One count dictionary per sample |
| `partial_tr(batch, sites)` | One ordinary `DensityMatrix` per sample; tracing every qubit of a nonzero register returns a vector of squared norms |

CPU gate kernels support one through five acted-on qubits, including within
nested circuits. Register validation runs before kernel execution. Paired batch
operations require matching registers and sample counts. Readout follows
[qubit and basis ordering](conventions.md#qubit-and-basis-ordering).

Partial trace on a pure batch retains its established vector of independently
owned ordinary density matrices. Wrap those results in `BatchDensityMatrix`
when a mixed batch is desired. Applying a supported Kraus channel to a pure
batch directly returns `BatchDensityMatrix`; retain the returned state rather
than assuming its type or storage rank remains the same. A channel computes a
mixed state for each sample without randomly choosing one Kraus branch.

## Measurement and recorded execution

```julia
batch = rand_batch(MersenneTwister(8), 3, 4)
outcomes, probabilities = measure!(copy(batch), 2;
    auto_reset=false, rng=MersenneTwister(9))
smaller, outcomes, probabilities = measure(batch, 2; rng=MersenneTwister(9))
selected, probabilities = post_select(batch, 2, 0; keep=true)

circuit = QCircuit([HGate(1), QMeasure(1; auto_reset=false)])
result = simulate(circuit, batch; rng=MersenneTwister(10))
result.state                    # BatchStateVector
result.measurements[2]          # records for sample 2, in execution order
```

In-place measurement retains the measured qubit and returns vectors of
outcomes and probabilities. `measure(batch, position)` leaves the input intact
and removes the measured qubit. Remaining qubits retain their relative order.
`post_select!` retains the qubit; `post_select` removes it unless `keep=true`.
Post-selection returns one squared-norm weight per column and requires every
selected column to have finite positive weight. An impossible sample fails
before any column changes. Measurement requires normalized samples and checks
every column before mutation or consuming randomness.

`simulate` copies the initial batch and returns `BatchSimulationResult`.
Records are indexed first by sample, then by executed measurement, including
nested circuits. Its circuit measurement path retains qubits; use standalone
`measure` to remove one. Each sample represents one trajectory. Terminal
sampling of `result.state` does not reexecute intermediate measurements.

For a fixed seed, draws occur in instruction order, then column order. This is
reproducible but can differ from executing an entire circuit for sample 1,
then an entire circuit for sample 2 with the same RNG. Execution and gradient
capabilities are separate: stochastic execution does not imply AD support.

## Scalar objectives and replaceable gradients

```julia
template = QCircuit([RyGate(1, 0.0; isparas=true)])
initial = BatchStateVector(1, 4)
observable = QubitsTerm(1 => "Z")
objective = BatchExpectationObjective(template, observable, initial;
    reduction=:mean)
theta = [0.3]

evaluate_batch(objective, theta)             # four real expectations
evaluate(objective, theta)                   # mean expectation
value, gradient = value_and_gradient(AdjointGradient(), objective, theta)
value, back = value_and_pullback(AdjointGradient(), objective, theta)
gradient = back(1.0)
```

Construction snapshots the template, observable, initial batch, and weights.
`:mean` is the default reduction; `:sum` sums all samples. `:weighted_sum`
requires `weights=[...]`, one finite real weight per sample. Negative weights
are allowed and weights are not normalized. Other reductions reject weights.
The parameter gradient uses the same reduction and has one entry per
independent parameter. `ParameterMap` can additionally share values between
circuit slots; sample contributions are summed before slot identities are
accumulated.

`evaluate` and `evaluate_batch` require no AD package and select no gradient
method. CPU `AdjointGradient` supports shared unitary gates, fixed Kraus channels,
and Hermitian `QubitsTerm`/`QubitsOperator` observables on pure or mixed batches,
with valid `differentiate` rules for active gate parameters. Unitary circuits
execute one batch forward and reconstruct each sample during the reverse pass.
Channel circuits use per-sample checkpoints, including for singular channels.
It rejects measurement and post-selection. Query `supports_gradient` separately
from backend execution capabilities. Other gradient methods can implement the
[public protocol](extending.md#execution-and-replaceable-differentiation); no fallback is
silently chosen.

With optional Zygote installed, the explicit scalar adapter also works:

```julia
using Zygote
loss(theta) = differentiable_value(AdjointGradient(), objective, theta)
gradient = Zygote.gradient(loss, theta)[1]
```

Legacy Zygote circuit/state entrypoints support shared unitary gates and fixed channels,
batch `QubitsTerm`/`QubitsOperator` expectations, state construction and copying,
and `batch_qubit_encoding`/`batch_qstate` angle inputs, including pure-to-mixed
conversion. They sum shared circuit
parameter contributions and retain per-column state cotangents. Observable
configuration is fixed. This is a defined set of derivative rules, rather than
an AD guarantee for every batch function; readout, stochastic measurement,
post-selection, general operator transformations, and partial trace do not gain
new derivative contracts from this work.

The [batch benchmark](../benchmark/README.md#shared-parameter-pure-state-batches)
compares the public batch objective against prebuilt single-state objectives
for `B=1,4,16`. It records forward, complete gradient, pullback preparation and
application separately. Batch semantics alone do not promise faster execution.
