# Generic storage: CPU allocation regression check

This check accompanies the four-container generic storage and backend-routing
milestone on 2026-10-20. It verifies numerical workloads and records allocation
changes against the previous optimized CPU implementation. It establishes no
GPU execution support or general elapsed-time improvement.

## Sources and environment

The baseline is commit `bbffd9a`, with 107 source files and source snapshot
`89688ba280c9626a0d022947eea8db973aabaee0bf18b3963acbb35b04eead33`.
The updated implementation has 108 source files and snapshot
`dc01e4bc7396eca05f3f330d0bf59613631eba405627f39188706fd88076ed16`.
The [validation record](generic-storage-2026-10-20/validation.json) and
[source hashes](generic-storage-2026-10-20/source-file-sha256.json) identify the
actual tested code independently of the working-tree status at collection.

Both allocation runs use Julia 1.13.1, one Julia thread, one BLAS thread,
ComplexF64 states, Float64 parameters, six qubits, two layers, and B=1/16.
Scripts, random seed, parameters, and resolved benchmark environment match.
The unchanged benchmark Manifest has SHA-256
`854ac94cf145f208e670e144c26abc0c94f538bb5335b4b628fe81b7869a048d` and is
[already archived](cpu-batch-2026-10-20/Manifest.toml) with its
[Project](cpu-batch-2026-10-20/Project.toml).

The frozen entrypoint verifies gate/channel outputs, per-sample expectations,
shared-parameter gradients against explicit sample loops, a finite-difference
coordinate, repeated pullbacks, and input ownership outside measured regions.
Each mutating sample starts from a private copy made outside its measurement.

## Allocation observations

The [before table](generic-storage-2026-10-20/before.tsv) and
[after table](generic-storage-2026-10-20/after.tsv) retain 60 corresponding
warmed summaries each. Their sidecar metadata records exact commands, file
hashes, and loaded optional packages. The complete
[allocation comparison](generic-storage-2026-10-20/allocation-comparison.json)
includes every operation, with no selection by result.

Selected B=16 results, in allocated bytes:

| Case | Operation | Before | After |
| --- | --- | ---: | ---: |
| Pure unitary | Evaluate | 153,544 | 198,328 |
| Mixed unitary | Evaluate | 1,452,616 | 1,498,536 |
| Pure fixed noise | Evaluate | 2,423,648 | 1,427,008 |
| Mixed fixed noise | Evaluate | 1,490,456 | 1,544,248 |
| Pure unitary | Complete gradient | 2,522,456 | 2,530,632 |
| Mixed unitary | Complete gradient | 10,841,104 | 10,849,312 |
| Pure fixed noise | Complete gradient | 35,751,016 | 35,758,296 |
| Mixed fixed noise | Complete gradient | 38,791,288 | 38,814,696 |
| Pure fixed noise | One channel application | 2,099,768 | 1,049,880 |

All eight prepared-pullback application cases retain exactly their previous
allocation bytes and counts. In particular, the mixed unitary B=16 pullback
still allocates 8,099,920 bytes, retaining the earlier density-workspace savings.
All eight gate-application cases also retain their allocation bytes and counts.

Backend selection and preflight add allocation overhead to several complete
forward evaluations: the pure unitary B=16 case adds 44,784 bytes (29.17%).
Complete gradients add approximately 0.02–0.32% in these B=16 workloads.
Pure-state channel promotion benefits from constructing its fresh density
storage once through the array interface, reducing that channel's allocation
by about half. These observations do not imply that every workload improves.

Trials use `--seconds 0.01` and run alongside compatibility tests. Their time
columns are retained for provenance and make no throughput or latency claim.
Reproduce the allocation workload in each checkout using the archived Manifest
in `benchmark/Manifest.toml`:

```bash
julia --startup-file=no --threads=1 --project=benchmark benchmark/batch_execution.jl --steady-only --with-zygote --seconds 0.01 --qubits 6 --depth 2 --batches 1,16 --output result.tsv
```

## Compatibility acceptance

Standard full suites passed 7,635 assertions across 78 top-level testsets on
Julia 1.13.1 with four threads and Julia 1.10.10 with one thread. Each includes
eight fresh-process optional-extension loading scenarios. The minimum-version
environment resolves separately from the root Julia 1.13 Manifest.

Independent `Pkg.test` passed on both versions: `MOSSDemoArrayBackend` 401,
`MOSSDemoBackend` 9, `MOSSDemoGates` 185, and `MOSSDemoDifferentiation` 235
assertions per version. Fourteen fresh benchmark compatibility processes also
passed, covering scalar, pure-batch, and pure/mixed-batch core/AD modes plus the
new harness's core first-call mode. Core processes load neither AD package.

The 1,245 new main-suite assertions cover storage/ownership (744), backend
routing and rejection (143), and optional AD domains/views/foreign cotangents
(358). The latter includes 182 boundary checks across circuit, observation,
encoding, postselection, constructor projection, and sample-scatter pullbacks;
foreign scalar reads, writes, copies, and host transfers remain zero.

Source, tests, root Project/Manifest, and benchmark Project/Manifest remain
unchanged during final acceptance. Documentation examples pass on both
versions. CI includes the new independent array-backend fixture; remote CI has
not been run. The [checksums](generic-storage-2026-10-20/SHA256SUMS) cover all
retained machine-readable artifacts. Previous performance reports and their
artifacts remain unchanged.
