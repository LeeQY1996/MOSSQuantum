# MOSSQuantum benchmarks

This independent environment measures the existing dense CPU simulator. BenchmarkTools is a development dependency here and is not added to the main package environment.

## Prepare the environment

The package requires Julia 1.10 or later. Use Julia 1.13 for primary development and acceptance measurements; use Julia 1.10 when checking the minimum version. The `julia` commands below should select the intended runtime. Optional Zygote support uses native package extensions on both versions.

From the repository root, run the following once. Package resolution may need network access.

```bash
julia --project=benchmark -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
```

The generated `benchmark/Manifest.toml` records the resolved dependencies for a particular benchmark run. Keep it with performance reports when exact reproduction is needed.

## Run the workloads

### Repeated scalar objectives and replaceable gradients

`repeated_evaluation.jl` measures the public execution/gradient interfaces in an
independent entrypoint. It loads MOSSQuantum and BenchmarkTools without loading Zygote
or ChainRulesCore. For comparable before/after measurements, use the same Julia
version, resolved benchmark environment, thread counts, sizes, and trial duration:

```bash
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --latency-only --qubits 6 --depth 2 --output /tmp/mossquantum-before-first.tsv
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --steady-only --seconds 1 --qubits 6 --depth 2 --output /tmp/mossquantum-before-steady.tsv
```

After the change, rerun the same commands with `after` output names. Use a fresh
process for each command. The default is one BLAS thread; `--blas-threads N`
changes that setting explicitly. `--qubits` must be at least two, and `--depth`
must be positive. A shorter `--seconds 0.05 --qubits 2 --depth 1` run checks the
harness but is not the standard performance baseline. With neither mode flag,
the entrypoint records first calls and then warmed trials in one process.

The four cases are a random pure state, a genuinely mixed density matrix,
the mixed state with fixed amplitude-damping channels in every layer, and a
pure-state circuit with gate parameters shared across layers. All use a seeded
input, ComplexF64 states, a two-term Hermitian observable, and the explicit
`AdjointGradient` method. Shared and ordinary circuits have the same number of
parameter slots; shared parameters reduce the independent vector length.

Each case measures `evaluate`, `value_and_gradient`, `value_and_pullback`
preparation, and repeated `back(1.0)` calls. Preparation is outside the
`pullback_apply` trial: this row measures the reverse work and output allocation
of an already prepared, reusable pullback. The other rows include every cost
inside their public call, including defensive copies and validation. Objective
construction and correctness checks are excluded. Checks compare scalar values,
explicit and pullback gradients, a finite-difference coordinate, preservation of
the input/state, and pullback independence after interleaved evaluations.

To additionally measure the optional Zygote adapter, opt in explicitly:

```bash
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --steady-only --with-zygote --seconds 1 --output /tmp/mossquantum-adapter.tsv
```

Only that invocation loads Zygote. It adds a `zygote_gradient` row for gradients
of `differentiable_value(method, objective, values)` and compares its result with
the selected explicit method. Compare adapter-enabled and core runs separately;
loading extensions can change compilation and first-call measurements.

The TSV contains the phase, case, operation, parameter-slot and independent
parameter counts, elapsed nanoseconds, allocated bytes, allocation count, GC
nanoseconds, sample count, and evaluations per sample. `steady_median` rows use
the median BenchmarkTools estimate with `evals=1`. First-call rows use `@timed`
and include compilation that occurs after package loading and case construction;
later cases may reuse prior compilation, so they do not represent isolated cold
startup. In particular, pullback application follows its measured preparation.

Each `--output PATH` also writes `PATH.metadata.toml` with the Julia and machine
details, Julia/BLAS thread counts, revision and working-tree state, environment
and script hashes, individual `src`/`ext` file hashes and a combined source
snapshot hash, sizes, seed, selected method, AD-loading status, and a
reproduction command. Retain the generated `benchmark/Manifest.toml` alongside
reports. Compare matching TSV keys and metadata before attributing a difference
to the implementation. With no output path the table is printed to stdout.

The [2026-10-19 report](../docs/performance/repeated-evaluation-2026-10-19.md)
retains measured six- and eight-qubit comparisons, their resolved environment,
and the source patch. CI runs small core and optional AD harness checks on Julia
1.10 and 1.13; those checks have no timing or allocation thresholds.

### Shared-parameter pure-state batches

`batch_evaluation.jl` measures `BatchExpectationObjective` on CPU pure-state
batches of size 1, 4, and 16. Every sample shares the circuit, observable, and
parameter vector; each layer also reuses the same per-qubit Ry/Rz parameters.
The scalar objective is the mean of the sample expectations. Use a fresh process
for each thread configuration:

```bash
julia --project=benchmark --threads=1 benchmark/batch_evaluation.jl --steady-only --qubits 6 --depth 2 --seconds 1 --output /tmp/mossquantum-batch-threads1.tsv
julia --project=benchmark --threads=4 benchmark/batch_evaluation.jl --steady-only --qubits 6 --depth 2 --seconds 1 --output /tmp/mossquantum-batch-threads4.tsv
```

The core run loads neither Zygote nor ChainRulesCore. The six operations per
batch size are native `evaluate`, `value_and_gradient`, `pullback_prepare`,
`pullback_apply`, and explicit per-sample `loop_evaluate` and
`loop_value_and_gradient` references. Objective construction is outside all
timings. The reference objectives use the same samples, circuit, parameter map,
and observable, and average scalar values and shared-parameter gradients. The
native batch adjoint uses one shared batch forward and reconstructs each sample
in the reverse pass. Optional AD and the explicit method reuse the same numerical
helpers. These measurements establish a baseline and do not imply a gradient
speedup.

The harness checks sample order and values against the explicit loop, native
gradients against loop gradients, a finite-difference coordinate, and reusable
pullback ownership. `--with-zygote` adds a seventh operation through the generic
`differentiable_value` adapter and compares it with the selected explicit method:

```bash
julia --project=benchmark --threads=1 benchmark/batch_evaluation.jl --steady-only --with-zygote --qubits 6 --depth 2 --seconds 1 --output /tmp/mossquantum-batch-adapter.tsv
```

The entrypoint accepts the same size, duration, BLAS-thread, and latency flags
as `repeated_evaluation.jl`. A `--steady-only --qubits 2 --depth 1 --seconds 0.01`
run checks the harness and is not a performance baseline. TSV rows additionally
record `batch_count`. Output metadata includes the batch sizes, mean reduction,
sharing semantics, reference setup, both benchmark script hashes, environment
hashes, source hashes, and AD-loading status. Batches use prefixes of one seeded
initial batch so the first sample is identical across all three sizes.

The [batch baseline report](../docs/performance/batch-evaluation-2026-10-19.md)
retains six-qubit one/four-thread measurements, both raw tables and metadata,
and the resolved environment. Its B=1 case also records the overhead of keeping
a one-column batch representation.

### Pure and mixed batch execution

`batch_execution.jl` independently measures both batch representations, including
pure-to-mixed transitions. It keeps the earlier entrypoints and dependency
environment unchanged. The default batch counts are 1, 4, 16, and 64; select
other positive, distinct counts with `--batches 1,8,32` (or `--batch-counts`).
Use the same frozen script, helper, environment, sizes, and thread counts for
before/after measurements:

```bash
julia --project=benchmark --threads=1 benchmark/batch_execution.jl --steady-only --qubits 6 --depth 2 --batches 1,4,16,64 --seconds 1 --output /tmp/mossquantum-batch-execution-before-threads1.tsv
julia --project=benchmark --threads=4 benchmark/batch_execution.jl --steady-only --qubits 6 --depth 2 --batches 1,4,16,64 --seconds 1 --output /tmp/mossquantum-batch-execution-before-threads4.tsv
```

Run each command in a fresh process without competing benchmark or test jobs.
After changing production code, repeat the commands using `after` output names.
The entrypoint also accepts `--latency-only`, `--blas-threads`, and
`--with-zygote` with the same meanings as `repeated_evaluation.jl`. With neither
phase flag, it records both first calls and warmed measurements. The default
BLAS thread count is one. `--qubits` must be at least two.

Four cases use shared circuits, parameters, observables, and mean reduction:

| Case | Input and circuit |
| --- | --- |
| `pure_unitary` | `BatchStateVector`, unitary circuit |
| `mixed_unitary` | Genuinely mixed `BatchDensityMatrix`, unitary circuit |
| `pure_fixed_noise` | Pure batch, amplitude damping in each circuit layer; output becomes mixed |
| `mixed_fixed_noise` | Mixed batch, the same fixed-noise circuit |

Inputs use seed `20261020` and ComplexF64 storage. All batch sizes use prefixes
of one random batch; mixed samples are `0.8|psi><psi| + 0.2I/D`, rather than
pure-state outer products alone. The independent parameter vector has one Ry/Rz
pair per qubit shared across circuit layers and all samples.

Every case measures `gate_apply` for one seeded general two-qubit unitary,
`expectation` on the initial batch, `evaluate`, `value_and_gradient`,
`pullback_prepare`, and `pullback_apply`. The two fixed-noise cases additionally
measure `channel_apply` for one amplitude-damping channel. Thus each batch count
produces 26 rows per phase, or 30 with the optional `zygote_gradient` adapter.
The four default counts produce 104 core rows per phase (120 with the adapter).

The mutating rows use `working=copy(initial)` in BenchmarkTools `setup` and
`evals=1`: reset/copy is outside the measured expression and each sample starts
from identical private storage. Public validation, internal temporaries, and
pure-to-mixed promotion remain inside `apply!`. First-call rows also exclude
the initial private copy. Scalar objective calls include their own defensive
copies, parameter binding, forward execution, and reduction. Reusable pullback
preparation stays outside the `pullback_apply` trial. Inputs and objective
construction are outside every timed expression.

Before warmed trials, checks compare gate/channel outputs, sample expectations,
objective values, and shared-parameter gradients against explicit per-sample
single-state loops. Checks also cover one finite-difference coordinate,
interleaved evaluations, repeated pullback seeds, returned-gradient ownership,
and preservation of input states. These references validate correctness and
are not timed loop speed comparisons.

The TSV adds `kind` and `batch_count` to the timing, allocation, parameter, and
sample fields. Its companion metadata records operation definitions, input and
ownership semantics, both entrypoint/helper hashes, resolved environment hashes,
individual and combined production source hashes, Julia/BLAS thread counts,
and whether AD packages were loaded. Core runs assert that neither Zygote nor
ChainRulesCore was loaded. Preserve the resolved Manifest with reported results.

For a small harness check, use the following command; its timings are not a
performance baseline. Add `--with-zygote` separately to check the adapter.

```bash
julia --project=benchmark --threads=1 benchmark/batch_execution.jl --steady-only --qubits 2 --depth 1 --batches 1 --seconds 0.01 --output /tmp/mossquantum-batch-execution-smoke.tsv
```

CI checks this entrypoint on Julia 1.10 and 1.13 using two-qubit, two-layer
workloads with `--batches 1,4 --seconds 0.01`: a core process checks 52 rows,
and a separate optional-AD process checks 60 rows. These jobs verify the harness
and reference comparisons without enforcing timing or allocation thresholds.

The [CPU batch measurement report](../docs/performance/cpu-batch-2026-10-20.md)
retains matched four/six-qubit, one/four-thread before/after records, the frozen
environment and scripts, source patch, and an independent paired confirmation.
It reports density-gradient allocation savings separately from elapsed timings.

### Dense kernels and legacy differentiated circuits

Use separate processes for first invocation latency and warmed throughput:

```bash
julia --project=benchmark --threads=1 benchmark/benchmarks.jl --latency-only
julia --project=benchmark --threads=1 benchmark/benchmarks.jl --steady-only
julia --project=benchmark --threads=4 benchmark/benchmarks.jl --steady-only
```

With no flag, the script prints first invocation timings and then runs the warmed suite. `--steady-only --smoke` exercises every workload with one sample; it is a harness check, not a performance measurement. Four- and five-qubit StaticArrays kernels can take substantial time to compile, even in a smoke run.

The latency pass uses `@time`, so compilation is included where it occurs. Later cases can reuse earlier compilation. Package loading and suite construction occur before these measurements, so they do not measure full process startup. BenchmarkTools warms the timed expressions before collecting repeated execution trials. Run both modes when assessing a change to generated or specialized kernels.

## Workload coverage

| Group | Inputs and purpose |
| --- | --- |
| `gates` | Generic dense gates of arity 1–5 on a 12-qubit state, using adjacent and separated or high-index positions |
| `batch` | Arity 1–5 on batches of size 1, 4, and 16, covering single-state, small-batch, and column-threaded dispatch |
| `noise` | A Kraus channel and a two-layer noisy circuit on a six-qubit density matrix |
| `expectation` | A multi-term observable on a pure state, a density matrix, and a batch |
| `gradient` | Expectation gradients of two-layer six-qubit unitary and noisy circuits through the public Zygote path |

Inputs use a local seeded RNG and `ComplexF64`. Gate generation, state generation, and benchmark setup are excluded from the repeated timed expression. Every mutating execution workload copies a fixed input in `setup` and uses `evals=1`, so successive samples begin from the same state. Gradient workloads use `circuit * initial_state`; its internal copy is part of the public workflow being measured. Expectation workloads do not mutate their inputs.

To customize sizes or run a selected group interactively:

```julia
include("benchmark/benchmarks.jl")
suite, first_calls = build_suite(state_qubits=14, noise_qubits=6, gradient_qubits=6)
results = run(suite["gates"]; seconds=1)
```

Do not compare different sizes as if they were the same workload. The smoke mode and an unevaluated harness provide no performance baseline.

## Record a comparison

Record the revision, Julia version, CPU, memory, OS, Julia thread count, BLAS thread count, resolved environment, workload sizes, and command. Compare timings and allocations on the same machine and environment. Repeat only when a result is unstable or a concrete regression needs investigation; avoid treating noisy differences as improvements.

## CPU noise simulation

Run `julia --project=. benchmark/noise_execution.jl /tmp/noise.toml` from the
repository root. This standalone harness compares density and trajectory shots,
full and streaming results, serial/threaded trajectories and batch sizes. It
records warmed timings, cumulative allocations, retained result size, process
peak RSS and source hashes. Set `JULIA_NUM_THREADS` before starting Julia.

## Prepared execution and sweeps

Run `julia --project=. benchmark/prepared_execution.jl /tmp/prepared.toml` from the
repository root. This dependency-free comparison measures fixed noisy sampling,
classical feedback, parameter sweeps and finite-shot VQE gradients, with separate
preparation cases. See [the report](../docs/performance/prepared-2026-10-29/README.md)
for warm-up, allocation and amortization caveats.

## End-to-end acceptance snapshot

The [2026-10-29 acceptance report](../docs/performance/acceptance-2026-10-29/README.md)
records a fresh full-suite run, independent extension fixtures, the budgeted
optimization workflow, and isolated one/four-thread prepared/noise benchmarks.
It includes raw logs, source hashes, dependency snapshots and reproduction commands.
