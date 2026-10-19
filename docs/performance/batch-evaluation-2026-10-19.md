# Pure-state batch evaluation baseline

Measured locally on 2026-10-19 with the completed pure-state batch interfaces.
This compares batch execution with explicit loops over single-state objectives;
it is not a comparison with an earlier batch implementation.

## Workload and environment

The [entrypoint](../../benchmark/batch_evaluation.jl) uses six qubits, two layers
of Ry/Rz/CNOT gates, a two-term Hermitian observable, and mean reduction.
`B=1,4,16` use prefixes of the same seeded random initial batch. All samples
share 12 independent Float64 parameters; `ParameterMap` shares those values
across 24 active circuit slots. States use ComplexF64.

Reference objectives are constructed before timing and contain exactly the same
samples, circuit, observable, and map. Reference values and gradients are averaged
explicitly. Before warmed measurements, the harness checks sample order/values,
complete gradients against the loop, one finite-difference coordinate, and
repeated pullback ownership.

Measurements use Julia 1.13.1, BenchmarkTools 1.8.0, Linux x86_64, an AMD RYZEN AI
MAX+ 395, one OpenBLAS thread, and seed 20261019. One-thread and four-thread
processes ran sequentially without other Julia validation jobs. Each warmed
trial uses one evaluation per sample and a one-second budget. Neither Zygote
nor ChainRulesCore was loaded. This source uses one batch forward and per-column
reverse reconstruction; explicit gradients and optional AD share numerical helpers.

## Results

Warmed median time in microseconds, with allocated bytes per invocation:

| Julia threads | B | Batch forward μs | Loop forward μs | Batch gradient μs | Loop gradient μs | Batch gradient bytes | Loop gradient bytes |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 93.47 | 59.05 | 380.91 | 318.62 | 477,504 | 404,448 |
| 1 | 4 | 96.62 | 245.42 | 658.79 | 1,374.39 | 861,528 | 1,616,688 |
| 1 | 16 | 190.26 | 1,013.05 | 1,906.58 | 5,725.53 | 2,480,984 | 6,465,648 |
| 4 | 1 | 92.79 | 62.55 | 391.19 | 321.83 | 477,504 | 404,448 |
| 4 | 4 | 98.31 | 242.30 | 654.74 | 1,321.87 | 861,528 | 1,616,688 |
| 4 | 16 | 315.39 | 1,018.63 | 1,910.91 | 5,461.70 | 2,521,240 | 6,465,648 |

Batch execution reduces repeated objective overhead for B=4/16 in this workload.
A one-column batch costs more than its single-state reference. Four Julia
threads do not consistently improve these small cases. These measurements do
not imply a general speedup across register sizes, gate families, or hardware.

The tables also retain separate pullback preparation and application rows.
Preparation includes binding, validation, forward execution, and private
snapshots; application includes reverse reconstruction and gradient allocation.
There is no persistent objective cache. Batch and scalar adapters have different
validation and snapshot paths, so the loop comparison includes their respective
public API overhead rather than isolating a kernel.

## Reproduction and raw records

Prepare the independent environment using the [benchmark guide](../../benchmark/README.md).
The resolved Manifest is retained in the [record directory](batch-evaluation-2026-10-19/).
Use revision `6017410` for these historical measurements; subsequent density-batch
work changes the execution and validation paths. Restore that Manifest to
`benchmark/Manifest.toml` to reproduce package versions:

```bash
julia --project=benchmark --threads=1 benchmark/batch_evaluation.jl --seconds 1 --qubits 6 --depth 2 --output /tmp/moss-batch-threads1.tsv
julia --project=benchmark --threads=4 benchmark/batch_evaluation.jl --steady-only --seconds 1 --qubits 6 --depth 2 --output /tmp/moss-batch-threads4.tsv
```

The one-thread table has 18 first-call and 18 warmed summaries; the four-thread
table has 18 warmed summaries. First calls include compilation after loading and
objective construction; later cases reuse earlier compilation. They do not
measure process startup. Individual BenchmarkTools sample arrays were not saved.
All raw TSV and metadata files were copied unchanged from the original output
paths recorded in metadata.

Both runs have source snapshot SHA-256
`5774ee2e694a831b3dabe6960ed994758856b7f56023534e1d2cf84d11fb1734`.
Metadata includes every `src/` and `ext/` file hash, both benchmark script
hashes, the benchmark Project and Manifest hashes, exact commands, thread
settings, sample counts, and AD loading status. Git metadata identifies the
parent revision and a dirty tree because these measurements preceded the
implementation commit; the file hashes identify the measured source.

The independent batch harness is also exercised by CI in small core and optional
AD processes on Julia 1.10 and 1.13. CI has no timing or allocation thresholds;
the minimum-version compatibility runs are not additional performance baselines.
