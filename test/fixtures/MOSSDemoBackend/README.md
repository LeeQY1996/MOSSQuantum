# MOSSDemoBackend

This independent fixture package uses only public MOSS interfaces. It supplies
an implicit product state, a custom instruction, an execution backend, and an
observable implementation. Its state does not expose `storage` or `.data`.

The fixture follows MOSS's Julia 1.10 minimum, with Julia 1.13 as the primary development and acceptance version. Optional MOSS integrations use native package extensions. Independent package tests passed on Julia 1.10.10 and Julia 1.13.1; see the [verification record](../../../docs/roadmap.md#verification-record).

For a quick example from the active MOSS repository environment:

```julia
import MOSS
include("test/fixtures/MOSSDemoBackend/src/MOSSDemoBackend.jl")
using .MOSSDemoBackend
state = DemoState(3)
MOSS.apply!(MOSS.QCircuit([DemoFlip(1), MOSS.XGate(3)]), state)
MOSS.expectation(MOSS.ZGate(1), state) # -1.0
```

To test it as an independently resolved package, copy this directory to a
temporary location, develop the MOSS checkout into that environment with
`Pkg.develop(path="/absolute/path/to/MOSS")`, then run `Pkg.test()` there.
