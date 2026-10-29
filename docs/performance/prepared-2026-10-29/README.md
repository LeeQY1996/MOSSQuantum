# Prepared CPU experiments: 2026-10-29

This report compares the direct public execution APIs with prepared plans on
small, repeated CPU workloads. Run from the repository root:

```sh
OPENBLAS_NUM_THREADS=1 JULIA_NUM_THREADS=4 julia --project=. benchmark/prepared_execution.jl /tmp/prepared.toml
```

`comparison.toml` records Julia/CPU/thread metadata, source hashes, median wall
time and cumulative allocation over five warmed trials. Compilation and package
loading are excluded. Each prepared execution case reuses one bound plan and
workspace. Preparation and binding are reported separately, so the repeated-call
rows should not be interpreted as first-call speedups. Parameter-scan and VQE
rows include changing/binding parameters on every point. Allocation is cumulative
bytes, not peak or retained memory. Timings vary with machine load and small
workloads; these measurements are not CI performance thresholds.

`baseline.toml` is the initial three-case direct-API capture taken before the
implementation. The principal comparison uses the paired direct/prepared rows
from the final source version, rather than dividing timings from separate runs.

## Workloads

- **Fixed noisy sampling:** a four-qubit initial state, H/CNOT and amplitude
  damping, 12 calls of 200 shots. Density evolution caches its bound output.
- **Dynamic feedback:** H, a named measurement, a conditional X, and
  depolarization, 12 calls of 200 independent trajectory shots. Prepared plans
  reuse compilation/buffers; the circuit still runs for every shot.
- **Parameter scan:** 16 two-parameter points in a four-qubit register, a noisy
  Ry/Ry/CNOT ansatz, two Pauli groups, 200 shots per point. The direct and prepared
  rows use explicit loops; separate sweep rows measure the ordered serial and
  threaded experiment API. Tiny points may not amortize threading overhead.
- **VQE gradients:** the same 16 points, independent value plus four two-term
  parameter-shift evaluations per point, 200 shots per evaluation. The direct
  reference composes public circuit estimates; the prepared method also returns
  gradient uncertainty and budget metadata. This is a variational gradient
  workload, not a claim about optimizer convergence or ground-state accuracy.

Correctness is checked separately: direct/prepared seeded execution comparisons,
serial/threaded sweep equality, physical expectation references, and gradient
comparisons against analytic derivatives. Performance comparisons use equal shot
counts, not a guarantee of equal realized statistical error. Adaptive allocation
is tested statistically and is not substituted for uniform sampling to inflate
these timing comparisons.

Dense states still scale exponentially. Cached bound distributions can be large;
use parameter sweeps to materialize states per active worker rather than retaining
many bound states yourself. The current plans cover dense CPU states only.

## Final measured comparison

| Workload | Direct time (ms) | Prepared time (ms) | Direct bytes | Prepared bytes | Time ratio |
| --- | ---: | ---: | ---: | ---: | ---: |
| fixed_density | 0.602 | 0.423 | 1,250,016 | 1,017,024 | 1.42× |
| feedback_trajectory | 10.929 | 10.485 | 14,484,896 | 14,028,704 | 1.04× |
| parameter_scan | 0.698 | 0.315 | 811,728 | 447,440 | 2.22× |
| vqe_gradient | 3.616 | 1.588 | 4,032,448 | 2,333,152 | 2.28× |

Ratios compare direct time divided by prepared time in this run. They describe
the workloads above, not a universal simulator speedup. Full setup and sweep
measurements are included in [comparison.toml](comparison.toml).

| Preparation or sweep case | Time (ms) | Allocated bytes |
| --- | ---: | ---: |
| fixed_density/prepare | 0.016 | 15,616 |
| fixed_density/bind | 0.012 | 10,216 |
| feedback_trajectory/prepare | 0.040 | 40,576 |
| feedback_trajectory/bind | 0.000 | 528 |
| parameter_scan/sweep_serial | 0.276 | 452,856 |
| parameter_scan/sweep_threaded | 0.442 | 455,128 |
| parameter_scan/prepare | 0.026 | 33,552 |
