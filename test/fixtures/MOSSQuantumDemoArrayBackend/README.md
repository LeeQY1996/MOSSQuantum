# External backend for generic state storage

This independent package attaches an execution backend to MOSSQuantum's four public
state containers without replacing their types. `DemoArray{T,N}` owns a CPU
allocation but rejects scalar indexing, `Array(...)`, and `collect(...)`.
Views and reshapes retain the array family. Copies, typed allocation, explicit
copying, and broadcast run through this package's array interface.

This is a small contract example, rather than a GPU implementation. Its backend
uses its own private CPU parent arrays and public MOSSQuantum gate/channel information.
It never calls a private MOSSQuantum numerical kernel. The existing `MOSSQuantumDemoBackend`
fixture separately demonstrates an implicit state with no storage interface.

```julia
using MOSSQuantum, MOSSQuantumDemoArrayBackend

data = DemoArray(ComplexF64[1, 0])
state = StateVector(data; preserve_storage=true)
backend(state)                         # ArrayBackend()
apply!(RyGate(1, 0.3), state)          # implicit external-backend routing
expectation(ZGate(1), state)
copy(state)                           # another DemoArray allocation
convert(StateVector{ComplexF32}, state)
mixed = DensityMatrix(state)          # same array family, fresh outer product
```

`preserve_storage=true` is explicit for array inputs. Ordinary MOSSQuantum array
constructors keep their existing CPU default; this fixture rejects an attempted
implicit host conversion instead of silently performing it. State-to-state
construction, copying, scalar-type conversion, and pure-to-mixed conversion
retain the selected family. Execution capability is queried separately.

The backend implements X and Ry gates, fixed one-qubit Kraus channels, and Z
expectation values for single and batched pure/mixed containers. It supports
bound circuits and scalar/batch expectation objectives through the public
backend protocol. Full-matrix linear action and computational-basis probabilities
also use explicit backend hooks. Probability vectors are host readout metadata;
the state storage stays in its selected family. Unknown operations are rejected before circuit mutation;
selecting `CPUBackend()` explicitly cannot bypass the storage contract.

`DemoRyObjective` and `AnalyticRyGradient` also demonstrate a fixed cosine
objective evaluated by this backend with a separately selected closed-form
gradient. No numerical differentiation algorithm or AD dependency is added.
The dense CPU adjoint does not claim support for this external executor.

From the MOSSQuantum repository root, test against the local checkout:

```bash
julia --project=test/fixtures/MOSSQuantumDemoArrayBackend --startup-file=no -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.test()'
```

The only runtime dependencies are MOSSQuantum and Julia's LinearAlgebra standard
library. Tests require Test, and run independently on Julia 1.10 and 1.13.
