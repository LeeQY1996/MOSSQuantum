# Batch density matrices

`DensityMatrix` represents one mixed state; `BatchDensityMatrix` represents
independent mixed states sharing a register size. Its mutable `storage` has shape
`(D, D, B)`, where `D=2^n`. Slice `[:, :, b]` is sample `b`. A batch of one keeps
all three axes. Empty batches and zero-qubit registers are supported.

Both pure and mixed batches share circuit, observation, readout, scalar objective,
and simulation APIs. They remain separate state types: a pure batch has storage
`(D, B)`, and applying a Kraus channel returns a mixed batch `(D, D, B)`.
The batch dimension always identifies independent samples, rather than terms of
an ensemble average.

## Construction and ownership

```julia
using MOSS, Random, LinearAlgebra

pure = rand_batch(MersenneTwister(12), 2, 3)
mixed = BatchDensityMatrix(pure)
zeros_batch = BatchDensityMatrix(2, 3)  # three |00⟩⟨00| samples
one_sample = BatchDensityMatrix(DensityMatrix(2))
from_list = BatchDensityMatrix([DensityMatrix(StateVector(pure, 1))])
```

For pure batches, extract a pure state before constructing a single density
matrix: `DensityMatrix(StateVector(pure, 1))`. For mixed batches, use
`DensityMatrix(mixed, 1)`. A list constructor accepts ordinary density matrices
and promotes their scalar types into new independent batch storage.

```julia
sample_density = DensityMatrix(mixed, 1)
from_list = BatchDensityMatrix([sample_density, DensityMatrix(StateVector(pure, 2))])
array_input = copy(storage(mixed))
independent = BatchDensityMatrix(array_input; copy=true)
converted = BatchDensityMatrix{ComplexF32}(array_input)
```

Three-dimensional array constructors accept optional explicit qubit and sample
counts and validate both matrix dimensions. Array and single-density-matrix
constructors default to `copy=false`, permitting compatible storage reuse.
Batch-to-batch construction defaults to `copy=true`. Explicit `copy=true` always
guarantees independent storage; views and scalar conversions can allocate with
`copy=false`. Extracting `DensityMatrix(batch, b)` always materializes independent
vector storage under the current single-density representation, including with
`copy=false`.

Converting a pure sample forms `psi * psi'`; converting a pure batch does this
separately for each column and always allocates. Samples are never averaged.
Constructors validate shape without performing an eigendecomposition or requiring
unit trace: the same representation also supports linear algebra and cotangents.

`BatchDensityMatrix(0, B)` has shape `(1, 1, B)`.
`BatchDensityMatrix(n, 0)` has shape `(2^n, 2^n, 0)`. An empty list needs explicit
register and batch dimensions. Invalid registers and operator shapes are rejected
even when `B=0`.

## Execution and precision

```julia
template = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(2; γ=0.2)])
bound = bind_parameters(template, [0.3])
output = bound * pure                # BatchDensityMatrix, input unchanged
output_from_mixed = bound * mixed
working = apply!(bound, copy(mixed))  # retain the returned state
```

Gate execution applies `U * rho_b * U'` to each sample. A fixed Kraus channel
applies `sum(K * rho_b * K' for K in kraus_matrices(channel))`. CPU gate kernels
support one through five acted-on qubits; generic channels support one or two
physical qubits. Nested circuits track pure-to-mixed transitions. Native batch
circuit execution checks gate/channel positions and matrix layouts before
executing its first instruction.

Floating state storage retains its component precision during execution, matching
the existing single-density policy. A complex operation can replace real storage
with complex storage of that precision. This preserves the appropriate probability
tolerance for Float32 states after earlier rounding. Explicit typed constructors
and `convert` select another precision. Channels preserve the input trace rather
than automatically normalizing it.

The baseline reuses existing dense kernels on each contiguous density slice.
It introduces no GPU storage, compiled execution plan, or batch throughput claim.

## Observations, normalization, and partial trace

| Operation | Result |
| --- | --- |
| `expectation(observable, batch)` | Vector of `tr(observable * rho_b)` in sample order |
| `observable * batch` | Left multiplication of every sample, for full matrices and `QubitsTerm`/`QubitsOperator` |
| `tr(batch)`, `norm(batch)` | Per-sample traces or Frobenius norms |
| `normalize!(batch)` | Divide every sample by its trace after validating all traces |
| `dot`, `fidelity`, `distance` | Per-sample results for matching batches |
| `probabilities(batch; qubits=...)` | Shape `(2^length(qubits), B)` |
| `sample(batch, shots; qubits=...)` | Shape `(shots, length(qubits), B)` |
| `counts(batch, shots)` | One count dictionary per sample |
| `partial_tr(batch, sites)` | Partial reductions return `BatchDensityMatrix`; full traces of nonzero registers return sample trace vectors |

Expectation supports `QubitsTerm`, `QubitsOperator`, local gates, and full register
matrices. Observable multiplication is a left action; gate execution is two-sided.
Normalization uses positive finite trace, allowing small imaginary rounding error;
it does not use a Frobenius norm or combine samples. Paired operations require
matching registers and sample counts.

Tracing every site of a nonzero register returns the vector of traces. Empty
`sites` copies the batch. Existing `partial_tr(::BatchStateVector, sites)` keeps
its established vector-of-density-matrices return convention; wrap those partial
reductions in `BatchDensityMatrix` when a batch representation is desired.

## Measurement and recorded simulation

```julia
outcomes, weights = measure!(copy(output), 1;
    auto_reset=false, rng=MersenneTwister(13))
reduced, outcomes, weights = measure(output, 1; rng=MersenneTwister(13))
selected, weights = post_select(output, 1, 0; keep=true)
reduced_density = partial_tr(output, [2])

experiment = QCircuit([HGate(1), AmplitudeDamping(1; γ=0.2),
                       QMeasure(1; auto_reset=false)])
result = simulate(experiment, pure; rng=MersenneTwister(14))
result.state                 # BatchDensityMatrix
result.measurements[2]       # records for sample 2
```

In-place measurement retains the qubit. Standalone `measure` removes it without
changing the input; other qubits keep their relative order. Post-selection retains
the qubit in place or with `keep=true`, and otherwise removes it. Both sides of
the density matrix are projected, and conditional states are normalized by the
selected probability. Automatic reset moves the selected block to outcome zero.

Readout validates each density diagonal before constructing marginals. Measurement
requires normalized samples and checks the full batch before any draw or state
mutation. Post-selection accepts unnormalized trace weights, requires every
selected weight to be positive and finite, and fails atomically on an impossible
sample. This validation does not establish positivity of every off-diagonal block.

`BatchSimulationResult` accepts pure or mixed final states and keeps one record
list per sample. Intermediate measurements in recorded circuits retain qubits.
Draws occur in instruction order, then sample order, including nested circuits.
Terminal sampling of a result does not reexecute earlier intermediate outcomes.

## Scalar objectives and gradients

```julia
observable = QubitsTerm(2 => "Z")
objective = BatchExpectationObjective(template, observable, mixed;
    reduction=:weighted_sum, weights=[1.0, -0.5, 2.0])
theta = [0.3]
sample_values = evaluate_batch(objective, theta)
value = evaluate(objective, theta)
value, gradient = value_and_gradient(AdjointGradient(), objective, theta)
value, back = value_and_pullback(AdjointGradient(), objective, theta)
scaled_gradient = back(-2.0)
```

The same scalar adapter accepts pure or mixed batches and preserves the existing
`:mean`, `:sum`, and `:weighted_sum` contracts. Weights are fixed finite real
values, can be negative, and are not normalized. Objectives snapshot their
template, observable, initial batch, and weights. Only the explicit circuit
parameter vector is differentiated by this adapter. `ParameterMap` accumulates
shared circuit slots after sample contributions have been reduced.

CPU `AdjointGradient` supports unitary gates with valid active-parameter derivative
rules, fixed Kraus maps, and Hermitian `QubitsTerm`/`QubitsOperator` observables.
Unitary paths use one batch forward with per-sample reverse reconstruction.
Paths containing channels reuse the single-state checkpoint reverse pass for each
sample, including singular channels such as complete damping; they require no
inverse channel. Prepared pullbacks own private data and can be reused independently.

Core evaluation and explicit gradients load no AD framework. Optional AD uses the
selected numerical method through the existing adapter:

```julia
using Zygote
loss(theta) = differentiable_value(AdjointGradient(), objective, theta)
ad_gradient = Zygote.gradient(loss, theta)[1]
```

Legacy Zygote rules also cover batch mixed circuit application and supported
expectations, density constructors, copies, conversion, sample extraction, and
pure-to-mixed conversion. Observable and channel configuration stay fixed.
Measurement, post-selection, sampling, and recorded stochastic simulation have
no new AD contract. Additional gradient estimators remain separate implementations
of the [replaceable gradient protocol](extending.md#execution-and-replaceable-differentiation).
