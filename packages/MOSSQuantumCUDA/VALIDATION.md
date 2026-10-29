# Local validation — 2026-10-22

This record predates the rename to MOSSQuantum and MOSSQuantumCUDA. Historical
package names, paths, source hashes, environment snapshots, and logs below are
retained as recorded; they describe the pre-rename sources.

The initial CUDA companion implements device-array storage helpers and
single-pure-state execution. **Hardware acceptance remains pending.** This
machine has no visible NVIDIA GPU or driver, and `CUDA.functional()` is false.
No GPU throughput, latency, memory usage, or speedup result is reported.

## Checks

| Check | Result |
| --- | --- |
| Standard `Pkg.test("MOSSCUDA")`, Julia 1.13.1 | 154 host assertions passed; hardware suite explicitly skipped |
| Standard `Pkg.test("MOSSCUDA")`, Julia 1.10.10 | 154 host assertions passed; hardware suite explicitly skipped |
| Existing MOSS storage/backend tests with MOSSCUDA loaded, Julia 1.13.1 | 887 assertions passed |
| Offline gate-kernel PTX compilation, Julia 1.13.1, CUDA.jl 6.4.2, CUDA compiler 13.3.73, `sm_80` | 45 scalar/arity combinations compiled |
| Strict `--require-gpu` test entrypoint | Exits nonzero with an explicit hardware-unavailable error |
| Benchmark without a GPU | Exits nonzero before measuring anything |
| Repository checks | Package TOML and workflow YAML parse; `git diff --check` passes |

The host suite contains 102 gate arithmetic comparisons, 40 preflight/precision
checks, and 12 observable checks. It compares the kernel's numerical helper
against MOSS CPU kernels and independent dense references. It does not launch
CUDA kernels. The existing storage/backend subset contains 656 family/ownership,
56 view/sample, 32 metadata-validation, and 143 backend-routing assertions.

PTX compilation covers 1–5-qubit gates for every supported input/output scalar
combination, including real-to-complex and wider observable precision. It checks
device compilation for the selected target without allocating device arrays or
running kernels. It cannot establish device runtime behavior or GPU numerical
agreement. The diagnostic uses CUDA.jl compiler internals only in its test
script; the companion's runtime uses public CUDA APIs.

The MOSS core source, extensions, existing tests, and root Project/Manifest were
not modified. The full historical MOSS suite was not rerun for this companion;
the targeted storage/backend regressions above were rerun with it loaded.
Neither the new hosted CI job nor the manual GPU workflow has run remotely.

Machine-readable results, source hashes, environment snapshots and retained
logs are in [the validation directory](validation/2026-10-22/summary.json).

## Remaining hardware acceptance

Run `Pkg.test("MOSSQuantumCUDA"; test_args=["--require-gpu"])` on the target NVIDIA
GPU. The suite disables scalar indexing and exercises real device allocations,
all four containers' storage/copy/conversion contracts, single-state kernel
execution, observations, ordered probability marginals, terminal samples,
shared-parameter forward objectives, rejection before state mutation, and
independent task execution. Batch/density execution and GPU gradients are
explicitly unsupported in this milestone.

Only after this suite passes should the synchronized benchmark be run to
measure execution, expectations, readout and explicit transfers. The manual
workflow requires an operator-provided GPU runner; it does not provision one.
