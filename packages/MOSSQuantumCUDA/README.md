# MOSSQuantumCUDA

An independent NVIDIA CUDA execution companion for MOSSQuantum. It attaches
`CUDABackend` to `StateVector` backed by an ordinary device-memory `CuVector`.
The package is loadable without a GPU. Execution requires a functional NVIDIA
GPU and driver; there is no automatic CPU fallback.

This is the first single-pure-state implementation. **Real GPU acceptance is
still pending** in the development environment, which has no visible GPU.
Host arithmetic tests and package loading do not establish device compilation,
hardware correctness, or performance. Use the strict acceptance command below
on the target GPU before relying on the backend.

## Install from this repository

Use a separate environment so MOSSQuantum's core dependencies stay independent:

```julia
using Pkg
Pkg.activate("cuda-environment")
Pkg.develop(path="/absolute/path/to/MOSSQuantum")
Pkg.develop(path="/absolute/path/to/MOSSQuantum/packages/MOSSQuantumCUDA")
Pkg.add("CUDA") # expose CUDA's configuration and array API in this environment
```

The companion targets Julia 1.10+ and CUDA.jl 6.x (minimum 6.4). CUDA.jl supplies the CUDA
toolchain; the machine must provide a compatible NVIDIA driver. See the
[CUDA installation guide](https://cuda.juliagpu.org/stable/installation/overview/).

## Device arrays and execution

```julia
using MOSSQuantum, MOSSQuantumCUDA, CUDA, Random
CUDA.allowscalar(false)

initial = gpu_state(3; T=ComplexF32)  # initialize directly in device memory
backend(initial)                   # CUDABackend()
storage(initial)                   # CuVector{ComplexF32}

circuit = QCircuit([HGate(1), CNOTGate(1, 3), RyGate(2, 0.3)])
result = simulate(circuit, initial)
expectation(QubitsTerm(3 => "Z"), result.state)  # host scalar, GPU computation
probabilities(result.state; qubits=(3, 1))      # host distribution, GPU marginal
sample(MersenneTwister(42), result.state, 100)   # terminal readout, host RNG

uploaded = to_gpu(StateVector(3))  # explicit host-to-device copy
downloaded = to_cpu(result.state) # explicit device-to-host copy

# Existing device allocations can be wrapped without copying or transferring.
data = CUDA.CuArray(ComplexF64[1, 0, 0, 0])
state = StateVector(data; preserve_storage=true)
@assert storage(state) === data
owned = copy(state)               # independent CuArray allocation
```

Use `preserve_storage=true` for array inputs. MOSSQuantum's ordinary array constructor
retains its historical host-materialization behavior. State-to-state
construction, `copy`, scalar-type conversion and pure-to-density conversion use
the existing same-family storage contracts. Density conversion can allocate on
the device, but this companion does not execute density states yet.

Execution accepts contiguous device-memory `CuVector` storage with Float32,
Float64, ComplexF32 or ComplexF64 elements. Contiguous views represented by CUDA
as `CuArray` also work. Other wrappers, noncontiguous views, unified/host CUDA
memory, integer states, batches and density execution are outside this initial
capability set. Select the state's CUDA device before executing; the backend
does not switch devices or move states between devices automatically.

## Supported operations

| Operation | Support |
| --- | --- |
| Gates | Public `Gate` matrices on 1–5 distinct qubits, arbitrary position order; built-in parameterized and adjoint gates |
| Circuits | Nested, gate-only circuits; complete host preflight before the first write |
| Expectations | Gates, tensor-product `QubitsTerm`, sums in `QubitsOperator`; complex/non-Hermitian expectations are allowed |
| Readout | Normalized computational-basis probabilities and arbitrary ordered marginals; terminal `sample`/`counts` |
| Objectives | `ExpectationObjective`, parameter binding and shared `ParameterMap`, through `evaluate` |
| Simulation | Gate-only `simulate`, copying the input and returning a `SimulationResult` with empty records |

Local gate matrices are small host instruction metadata and are uploaded for
each operation. Register-sized amplitudes remain on the GPU during execution
and observation. Expectation reduction returns a host scalar; probability
readout returns only the requested host distribution. Sampling uses that
distribution and the caller's CPU RNG. No full state is downloaded to compute
an expectation or a marginal.

Gate execution preserves the state's component precision, promoting real
storage to the corresponding complex type when needed. Always retain the
returned state, as in `state = apply!(gate, state)`. Observable calculation
promotes supported scalar types with the observable to preserve its precision.

Each gate uses an output buffer, then copies back when the scalar type is
unchanged. Gate execution synchronizes before returning. No persistent workspace is
shared between calls. This establishes a correctness-first implementation;
kernel fusion, reusable plans, scheduling and throughput optimization require
measurements on the target hardware.

Channels, mid-circuit measurement, post-selection, full-register matrix action,
batch/density execution and GPU gradients are not implemented. Unsupported
operations throw `UnsupportedOperation`; an invalid or unsupported gate-only
circuit is rejected before changing the input state. The native CPU
`AdjointGradient` does not claim GPU support. Forward objectives work without
an AD package and do not select a gradient method.

## Verification

In the environment containing both developed packages:

```julia
using Pkg
Pkg.test("MOSSQuantumCUDA") # host checks + device tests if a GPU is available
Pkg.test("MOSSQuantumCUDA"; test_args=["--require-gpu"]) # fails if no functional GPU
```

Host checks compare the exact kernel arithmetic helper against independent
CPU kernels/dense references, including unsorted 1–5-qubit gates, real/complex
precision, observable factors, and preflight contracts. The device suite runs
with `CUDA.allowscalar(false)` and additionally verifies real CuArray storage,
ownership, conversions, actual kernel execution, readout, shared-parameter
objectives, unsupported-operation atomicity and independent tasks.

GPU CI is a manual workflow requiring a configured self-hosted runner labelled
`gpu`. Hosted CPU CI reports device tests as skipped, never as GPU acceptance.

An optional [PTX compilation diagnostic](test/compile_ptx.jl) can check the gate
kernel without a GPU. It uses CUDA.jl compiler internals, tested with 6.4.2, and
needs a selected CUDA compiler toolkit. In a **separate diagnostic environment**,
run `CUDA.set_runtime_version!(v"13.3")`, restart Julia, install the selected
artifacts, then run:

```bash
julia --project=diagnostic-environment packages/MOSSQuantumCUDA/test/compile_ptx.jl sm_80
```

It covers 45 arity/scalar combinations, including real-to-complex and wider
observation precision. PTX generation does not execute a kernel or replace the
strict GPU suite. See [local validation](VALIDATION.md) for recorded results.

## Benchmark on the target GPU

```bash
julia --project=cuda-environment packages/MOSSQuantumCUDA/benchmark/run.jl 18 10
```

The arguments are qubits and repetitions. The script fails without a GPU,
checks numerical agreement, warms both implementations, and reports synchronized
CPU/GPU execution separately from explicit transfers and readout. These results
are workload-specific; no speedup is claimed before hardware measurements.
