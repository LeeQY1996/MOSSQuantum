# Extension tests

MOSS requires Julia 1.10 or later; Julia 1.13 is the primary development and acceptance version. These tests cover optional Zygote and plotting integrations through native package extensions, their loading orders, and backend/AD capability boundaries. The Requires compatibility bridge has been removed.

Plotting integration checks also run from `test/integration/plotting.jl`; Plots and LaTeXStrings are optional runtime dependencies supplied by the test environment.

Constructor-gradient checks cover explicit copy controls, nested state wrappers, and state copying. The `MOSSDemoGates` fixture supplies the shared trainable-extension checks used here and in its own independent package tests; they exercise public binding, immutable replacements, CPU gradients, and one parameter update.

Shared-parameter gradient checks compare explicit maps with analytic and finite-difference results, including noncommuting gates, mixed inputs and fixed channels, value projections, and empty maps. The external fixture also trains shared values across its own immutable gate and a built-in gate.

The explicit-method differentiation tests cover direct ChainRules pullbacks, zero/thunk/type/domain behavior, selected external methods, and coexistence with legacy Zygote rules. `MOSSDemoDifferentiation` verifies the same public protocol in a separate package, including core-only execution without any AD dependencies. Fresh-process scenarios now also load ChainRulesCore before and after MOSS without loading Zygote.

Batch tests cover shared unitary CPU circuits, sample expectation vectors and
seeds, qubit encoding, state constructors/copies, and scalar batch objectives
with mean, sum, or explicit weighted reductions. The scalar adapter differentiates
only the selected circuit parameter vector; legacy encoding rules separately
support per-sample encoding inputs. Numerical batch reverse helpers are shared
between explicit `AdjointGradient` calls and optional Zygote rules. Tests check
parameter sharing, real/complex domains, independent prepared pullbacks, and
rejection of unsupported batch noise and stochastic derivative paths. These
capabilities do not establish AD for every batch API. See the
[batch guide](../../docs/batching.md) for the supported boundaries.

Julia 1.10/1.13 local validation results are recorded in [the roadmap](../../docs/roadmap.md#verification-record).
