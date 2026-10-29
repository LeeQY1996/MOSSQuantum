# CPU noise measurements, 2026-10-28

This record measures the new noise execution implementation before and after
trajectory workspace reuse. It is not a comparison with a previous released
MOSSQuantum version or another simulator. The before run is an intermediate
implementation snapshot, not a complete release baseline.

- Julia 1.13.1, AMD RYZEN AI MAX+ 395, 4 Julia threads, 1 BLAS thread.
- `benchmark/noise_execution.jl`: 24 cases, three warmed repetitions per case.
- Raw reports record source hashes and timestamps: [before](before-workspaces.toml)
  and [after](after-workspaces.toml).
- The before run overlapped validation work. Consequently the before/after
  comparison below uses allocation counts, not a claimed timing speedup. The
  after run was performed after those validation processes completed.

## Allocation changes

All entries use an 8-qubit circuit with 1,000 independent shots. Pauli circuits
apply H then depolarizing noise on each qubit; damping circuits apply H then
amplitude damping. Both use error parameter 0.05.

| Trajectory path | Before bytes allocated | After bytes allocated | Reduction |
| --- | ---: | ---: | ---: |
| Pauli, full records | 18,994,864 | 10,667,296 | 43.8% |
| Pauli, streaming counts | 18,682,520 | 10,354,952 | 44.6% |
| Damping, full records | 19,583,664 | 10,616,080 | 45.8% |
| Damping, streaming counts | 19,271,320 | 10,303,736 | 46.5% |

Workspace reuse avoids repeatedly allocating the pure state, branch candidate
state, and branch weights. Parallel execution owns a workspace per worker task;
no workspace is shared across concurrent shots. The final full-record density
path also includes additional preflight validation, increasing allocations by
about 1.5–2.5% in these small cases; no density-kernel speedup is claimed.
Mixed-unitary recognition also
avoids evaluating every Kraus branch of Pauli noise.

## Final warmed timings

These are medians for the final implementation on the same 8-qubit/1,000-shot
cases. Sampling budgets are equal, but this is not a convergence study at equal
observable error; the two methods simulate noise differently.

| Noise | Density, counts | Trajectory, serial counts | Trajectory, 4-thread counts |
| --- | ---: | ---: | ---: |
| Pauli | 2.21 ms | 13.60 ms | 5.70 ms |
| Damping | 1.63 ms | 20.57 ms | 6.27 ms |

For these small registers exact density evolution is faster. The trajectory
method's primary benefit is its O(2^n) state storage per worker, compared with
O(4^n) for a density matrix, with shot-dependent runtime and statistical error.
There is no automatic method selection or general acceleration claim.

## Streaming result size

An 8-qubit circuit with 100,000 terminal shots retains 9,634,440 bytes in the
full `ShotResult` versus 21,752 bytes in `CountsResult`, a 99.8% reduction in
**retained result storage**. Both histograms cover 256 observed outcomes.
Cumulative allocations are respectively 88,860,248 and 79,310,128 bytes; streaming
does not eliminate temporary sampling and histogram allocations.

Process peak RSS was 755,843,072 bytes before and 717,975,552 bytes after. These
figures include Julia compilation and every case in the process. They are not
per-case peaks and do not isolate the effect of workspace reuse. Retained result
size, cumulative allocations, and peak RSS are distinct measurements.

To reproduce, run from the repository root:

```sh
OPENBLAS_NUM_THREADS=1 JULIA_NUM_THREADS=4 julia --project=. \
  benchmark/noise_execution.jl /tmp/noise.toml
```

The benchmark covers registers 4/8, Pauli/damping channels, density/trajectory
methods, full/counts results, serial/threaded execution, 1,000/100,000 shots and
batch sizes 1/4. Noise model insertion, thermal parameter conversion and custom
Kraus physics are covered by correctness tests; this report does not establish
performance bounds for every supported model.
