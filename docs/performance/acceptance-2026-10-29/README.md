# CPU end-to-end acceptance and performance — 2026-10-29

This run validates the current working-tree source, including prepared execution,
classical feedback, finite-shot gradients, adaptive allocation and hard shot
budgets. It does not implement or validate a chemistry extension or a new backend.

## Results

All seven stages exited successfully. Source hashes were unchanged throughout the run.
The measured host uses Julia 1.13.1 on AMD RYZEN AI MAX+ 395 w/ Radeon 8060S,
with one BLAS thread and either one or four Julia threads.

| Acceptance stage | Result |
| --- | --- |
| Full package, integrations and loading orders | 9,873 passing assertions; 123 printed test summaries |
| Four independent fixture packages | 830 passing assertions; 16 printed test summaries |
| End-to-end workflow | 12 scan points / 12,000 shots; 33 optimizer updates / 100,000 shots including final estimate |

The optimizer stopped with `:shot_budget`; the fresh final estimate was
`-0.9272777273602296 ± 0.02407217396552329` (estimated standard error).
The full suite includes the adaptive final-result regression. Test helper method
redefinition warnings are retained in the logs; no failing tests were reported.

### Direct versus prepared execution

| Julia threads | Workload | Direct ms | Prepared ms | Direct / prepared | Allocation reduction |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1 | fixed_density | 0.664 | 0.450 | 1.47× | 18.6% |
| 1 | feedback_trajectory | 11.686 | 12.682 | 0.92× | 3.1% |
| 1 | parameter_scan | 0.709 | 0.264 | 2.69× | 44.9% |
| 1 | vqe_gradient | 3.438 | 1.552 | 2.21× | 42.1% |
| 4 | fixed_density | 0.710 | 0.446 | 1.59× | 18.6% |
| 4 | feedback_trajectory | 11.194 | 10.254 | 1.09× | 3.1% |
| 4 | parameter_scan | 0.633 | 0.302 | 2.10× | 44.9% |
| 4 | vqe_gradient | 3.856 | 1.721 | 2.24× | 42.1% |

Dynamic-feedback timing varies around parity (0.92–1.09× here); this run does
not establish a speedup for that workload. It still executes every trajectory.

| Julia threads | Sweep serial ms | Sweep threaded ms | Serial / threaded |
| ---: | ---: | ---: | ---: |
| 1 | 0.477 | 0.279 | 1.71× |
| 4 | 0.281 | 0.440 | 0.64× |

With one Julia thread, `parallel=true` cannot provide multi-core acceleration;
the small-workload ratio reflects execution/timing variation. The four-thread
sweep is slower for these tiny points, so threading is not a default performance
recommendation based on this workload.

### Noise sampling and retained result memory

These paired serial/threaded trajectory timings come from the four-thread
process, with 1,000 shots and counts-only results in each case.

| Qubits | Channel | Serial ms | Threaded ms | Serial / threaded |
| ---: | --- | ---: | ---: | ---: |
| 4 | pauli | 3.398 | 2.877 | 1.18× |
| 4 | damping | 3.957 | 2.606 | 1.52× |
| 8 | pauli | 13.636 | 5.371 | 2.54× |
| 8 | damping | 18.452 | 8.084 | 2.28× |

For 100,000 terminal shots on eight qubits, the retained result occupies 24,034,536 bytes in full mode versus 21,752 bytes in counts-only mode. Cumulative allocation falls from 114,461,024 to 79,310,864 bytes. These are different memory metrics; counts-only does not eliminate all per-shot work.

### Artifacts

- [Full test log](full-tests.log), [fixture log](fixtures.log), [workflow log](workflow.log).
- [Prepared / 1 thread](prepared-threads1.toml), [prepared / 4 threads](prepared-threads4.toml).
- [Noise / 1 thread](noise-threads1.toml), [noise / 4 threads](noise-threads4.toml).
- [Commands and source hashes](metadata.json), [host](host.json), [Project](Project.toml), [Manifest](Manifest.toml).

## Acceptance coverage

| Layer | Checks |
| --- | --- |
| Core and integration | Full `Pkg.test`, including operator algebra, measurement, noise channels, dynamic classical control, dense state and density-matrix execution, gradients and optional adapters |
| Prepared execution | Snapshot ownership, frozen noise factories, direct/prepared seeded equality, shared workspaces, postselection and readout |
| Parameter sweeps | Ordered columns, serial/threaded reproducibility, empty batches and invalid-input preflight |
| Shot statistics | Analytic gradient references, empirical covariance, independent pilot/production samples and adaptive allocation |
| Budget enforcement | Concurrent reservations, refusal without RNG consumption, whole-gradient costs and optimizer final-estimate reservation |
| External extension contract | Four independent fixture packages: backend, array backend, gates and differentiation |
| Workflow | Twelve noisy parameter points followed by adaptive finite-shot optimization and a fresh final estimate |

## Reproduction

From the repository root with the dependencies installed:

```sh
export OPENBLAS_NUM_THREADS=1 JULIA_NUM_THREADS=4 GKSwstype=100
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test(;test_args=["--load-orders"])'
julia --project=. --startup-file=no docs/performance/acceptance-2026-10-29/fixtures.jl
julia --project=. --startup-file=no algorithm_zoo/optimization/prepared_run.jl
```

Run performance commands separately after tests finish. Repeat each with
`JULIA_NUM_THREADS=1` and `JULIA_NUM_THREADS=4`, using distinct output paths:

```sh
julia --project=. --startup-file=no benchmark/prepared_execution.jl /tmp/prepared.toml
julia --project=. --startup-file=no benchmark/noise_execution.jl /tmp/noise.toml
```

The local run uses installed dependencies in offline mode. `fixtures.jl` resolves
the four fixtures into a temporary environment. The saved root Project/Manifest
and package-test logs record dependency versions. `metadata.json` records commands,
exit codes, elapsed process times and source hashes; `host.json` records the host.
The raw TOML files contain Julia/CPU/thread details and measurement rows.

## Interpretation and limits

Prepared benchmarks report medians of five warmed trials; noise benchmarks use
three warmed trials. Compilation is excluded from these timings. Preparation and
binding are separate rows for fixed circuits; parameter changes remain inside
scan and gradient workloads. Allocation is cumulative allocated bytes, not peak
memory. Noise reports separately retain result size and whole-process peak RSS;
the latter includes compilation and all workloads and is not per-case peak memory.

Ratios compare equal-shot workloads within the same run, not equal statistical
error or a universal speedup. The gradient reference returns fewer diagnostics
than the prepared gradient API. Small sweeps can be slower with threading. Timing
results are observations, not CI pass/fail thresholds. See the
[prepared workload definitions](../prepared-2026-10-29/README.md).

This local acceptance covers Julia 1.13 and dense CPU execution. Julia 1.10,
CUDA hardware execution, large-scale backends and remote CI are not validated by
this report. Optimizer budget termination does not establish convergence.
