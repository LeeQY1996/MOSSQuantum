# MOSS benchmarks

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
independent entrypoint. It loads MOSS and BenchmarkTools without loading Zygote
or ChainRulesCore. For comparable before/after measurements, use the same Julia
version, resolved benchmark environment, thread counts, sizes, and trial duration:

```bash
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --latency-only --qubits 6 --depth 2 --output /tmp/moss-before-first.tsv
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --steady-only --seconds 1 --qubits 6 --depth 2 --output /tmp/moss-before-steady.tsv
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
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --steady-only --with-zygote --seconds 1 --output /tmp/moss-adapter.tsv
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
