# Repeated evaluation and adjoint preparation

Measured locally on 2026-10-19. This report covers the explicit scalar objective
interfaces, not the entire dense-kernel benchmark suite.

## Workloads and environment

The independent [entrypoint](../../benchmark/repeated_evaluation.jl) measures
`evaluate`, `value_and_gradient`, `value_and_pullback` preparation, and calls to
an already prepared `back(1.0)`. It uses pure states, genuinely mixed density
matrices, mixed states with fixed amplitude-damping channels, and pure-state
circuits sharing parameters across layers. Each circuit has two layers of Ry,
Rz, and CNOT gates and a two-term Hermitian observable. The six-qubit cases have
24 active slots; the eight-qubit cases have 32. Sharing reduces the independent
parameter count to 12 and 16 respectively.

Measurements use Julia 1.13.1 on Linux x86_64, an AMD RYZEN AI MAX+ 395 with
32 logical CPU threads, one Julia thread, one OpenBLAS thread, ComplexF64 states,
Float64 parameters, and seed 20261019. Trials use BenchmarkTools 1.8.0 with one
evaluation per sample. No other validation jobs ran during these measurements.
Neither Zygote nor ChainRulesCore was loaded. Metadata records memory, BLAS
configuration, source and environment hashes, samples, and the exact commands.

The baseline is `e132ca0188487291b990c8b554876a29d9c4bfe3`; the measured
optimized revision is `642cab7`. Only
`src/differentiation/objectives.jl` changes between the measured source snapshots.
The benchmark script, Project, and resolved Manifest are identical across each
before/after comparison. Documentation, test, and CI edits do not affect the
recorded source snapshots.

## The measured change

The CPU objective adapter copied its initial state before calling
`_circuit_adjoint`. That helper already copies its input in both paths: unitary
circuits use `circuit * state`, and circuits with channels create an independent
forward state before saving checkpoints. Passing the objective's initial state
directly removes the redundant copy. Each prepared pullback still owns its
forward state and checkpoints.

Template checks, bound-parameter matrix and derivative checks, independent
binding, and observable snapshots are retained. There is no persistent cache,
new public execution-plan API, or new requirement on external backends. The
[ownership contract](../conventions.md#repeated-evaluation-and-pullback-ownership)
describes independent pullbacks and concurrent use of a read-only objective.

## Results

Allocated bytes per `value_and_pullback` preparation (warmed trials):

| Qubits | Case | Before | After | Saved | Reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| 6 | pure | 268,128 | 267,008 | 1,120 | 0.42% |
| 6 | mixed | 399,488 | 333,880 | 65,608 | 16.42% |
| 6 | fixed_noise | 1,213,904 | 1,148,296 | 65,608 | 5.40% |
| 6 | shared | 268,032 | 266,912 | 1,120 | 0.42% |
| 8 | pure | 362,368 | 358,200 | 4,168 | 1.15% |
| 8 | mixed | 2,454,480 | 1,405,832 | 1,048,648 | 42.72% |
| 8 | fixed_noise | 19,266,352 | 18,217,704 | 1,048,648 | 5.44% |
| 8 | shared | 362,240 | 358,072 | 4,168 | 1.15% |

Both eight-qubit paired runs produced exactly the same allocation counts and
bytes for every matching implementation/case/operation. The additional run used
two seconds per trial instead of one. Its elapsed preparation times are shown
alongside the original run below; the full gradient and control measurements
remain in [comparison.tsv](repeated-evaluation-2026-10-19/comparison.tsv).

| Eight-qubit case | Initial before → after (μs) | Repeat before → after (μs) |
| --- | ---: | ---: |
| pure | 321.07 → 506.65 | 310.61 → 321.08 |
| mixed | 8,639.76 → 8,088.55 | 7,638.96 → 8,103.28 |
| fixed_noise | 11,131.84 → 11,367.12 | 10,294.65 → 10,380.22 |
| shared | 344.86 → 357.97 | 359.98 → 409.50 |

Allocation reductions apply to both preparation and complete explicit gradients.
Forward evaluation and application of an already prepared pullback retain their
original allocation counts and bytes. The saved payload scales with the initial
state: 2^n complex elements for a pure state and 4^n for a density matrix, plus
the associated allocation overhead.

The tables retain first-call timings and warmed median summaries for every
operation, including controls and repetitions; individual BenchmarkTools sample
arrays were not serialized. Unchanged operations also show timing drift, so
these runs establish an allocation improvement rather than a general throughput or latency speedup.
First-call data includes compilation after package loading and construction;
later cases reuse earlier compilation. It does not measure process startup.

## Reproduction and raw records

From the repository root, prepare the independent environment as described in
the [benchmark guide](../../benchmark/README.md). The resolved environment used
here is retained as `repeated-evaluation-2026-10-19/benchmark.Manifest.toml`;
restore it to `benchmark/Manifest.toml` to use the same package versions.
Use revision `642cab7` for these historical measurements; later batch work
changes additional source files. Keep that revision's benchmark files when
measuring the baseline. On that optimized checkout, reverse only the saved source patch before the baseline
commands:

```bash
git apply -R docs/performance/repeated-evaluation-2026-10-19/optimization.patch
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --seconds 1 --qubits 6 --depth 2 --output /tmp/moss-repeat-before-n6.tsv
julia --project=benchmark --threads=1 benchmark/repeated_evaluation.jl --steady-only --seconds 1 --qubits 8 --depth 2 --output /tmp/moss-repeat-before-n8.tsv
git apply docs/performance/repeated-evaluation-2026-10-19/optimization.patch
```

Run the same commands with `after` names after applying the saved source patch.
The additional paired eight-qubit run uses `--seconds 2` and the `-repeat` output
suffix. Processes ran sequentially. The six-qubit command records first calls
and warmed trials separately in one table; the eight-qubit commands measure
warmed trials only. Correctness checks and prepared-pullback setup are outside
the relevant timed expressions.

The [record directory](repeated-evaluation-2026-10-19/) retains every TSV and its
metadata, the resolved Manifest, and the source patch. Output paths in metadata
are the original measurement paths; the files have been copied here without
changing their contents. The baseline source hash is
`0c48b5a2069a9196d27d922d50edc1b676fadfda883fe43cc7ce08566994e499`;
the optimized source hash is
`ad9af9d538c9c8641fa3dbb39bcb28b5356e363c38cf575b71a71120a5e170e2`.

## Correctness acceptance

- Julia 1.13.1, four threads: standard `Pkg.test(; test_args=["--load-orders"])`
  passed 3,357 assertions across 45 top-level testsets, including all eight
  fresh-process optional-integration loading scenarios.
- Julia 1.10.10, one thread: an independently resolved environment developed the
  actual checkout and passed standard `Pkg.test("MOSS"; test_args=["--load-orders"])`,
  with 3,357 assertions across 45 top-level testsets and all eight fresh-process
  loading scenarios.
- The 151 added lifecycle assertions cover interleaved and independently prepared
  concurrent pullbacks, state/template ownership, returned-gradient isolation,
  parameter-dependent invalid gates/derivatives, and objective edits. The CPU
  objective testset now passes 310 assertions on both versions.
- Independent `Pkg.test` on both versions passed `MOSSDemoBackend` (9),
  `MOSSDemoGates` (181), and `MOSSDemoDifferentiation` (235).
- Both versions passed the benchmark entrypoint in separate core and optional AD
  processes, with two qubits, two layers, first calls and warmed trials. Core
  mode produced 32 summary rows with neither AD package loaded; optional AD mode
  produced 40 rows and matched the selected explicit gradient method.
- All six measurement tables and metadata, all 48 paired warmed comparisons,
  baseline/current source hashes, and the saved patch were checked independently.
  Documentation links, code fences, and TOML files were also checked.

CI runs only small benchmark harness checks on Julia 1.10 and 1.13, with core
and optional AD workloads in separate processes. Those checks validate behavior
and loading, not performance thresholds. No remote CI run is included in this
local acceptance.
