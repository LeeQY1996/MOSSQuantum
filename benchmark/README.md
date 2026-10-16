# MOSS benchmarks

This independent environment measures the existing dense CPU simulator. BenchmarkTools is a development dependency here and is not added to the main package environment.

## Prepare the environment

From the repository root, run the following once. Package resolution may need network access.

```bash
julia --project=benchmark -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
```

The generated `benchmark/Manifest.toml` records the resolved dependencies for a particular benchmark run. Keep it with performance reports when exact reproduction is needed.

## Run the workloads

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
