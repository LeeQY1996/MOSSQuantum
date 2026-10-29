# MOSSQuantumDemoBackend

This independent fixture package uses only public MOSSQuantum interfaces. It supplies
an implicit product state, a custom instruction, an execution backend, and an
observable implementation. Its state does not expose `storage` or `.data`.

The fixture follows MOSSQuantum's Julia 1.10 minimum, with Julia 1.13 as the primary development and acceptance version. Optional MOSSQuantum integrations use native package extensions. Independent package tests passed on Julia 1.10.10 and Julia 1.13.1; see the [verification record](../../../docs/roadmap.md#verification-record).

For a quick example from the active MOSSQuantum repository environment:

```julia
import MOSSQuantum
include("test/fixtures/MOSSQuantumDemoBackend/src/MOSSQuantumDemoBackend.jl")
using .MOSSQuantumDemoBackend
state = DemoState(3)
MOSSQuantum.apply!(MOSSQuantum.QCircuit([DemoFlip(1), MOSSQuantum.XGate(3)]), state)
MOSSQuantum.expectation(MOSSQuantum.ZGate(1), state) # -1.0
```

To test it as an independently resolved package, copy this directory to a
temporary location, develop the MOSSQuantum checkout into that environment with
`Pkg.develop(path="/absolute/path/to/MOSSQuantum")`, then run `Pkg.test()` there.
