# Extension tests

MOSS requires Julia 1.10 or later; Julia 1.13 is the primary development and acceptance version. These tests cover optional Zygote and plotting integrations through native package extensions, their loading orders, and backend/AD capability boundaries. The Requires compatibility bridge has been removed.

Plotting integration checks also run from `test/integration/plotting.jl`; Plots and LaTeXStrings are optional runtime dependencies supplied by the test environment.

Constructor-gradient checks cover explicit copy controls, nested state wrappers, and state copying. The `MOSSDemoGates` fixture supplies the shared trainable-extension checks used here and in its own independent package tests; they exercise public binding, immutable replacements, CPU gradients, and one parameter update.

Shared-parameter gradient checks compare explicit maps with analytic and finite-difference results, including noncommuting gates, mixed inputs and fixed channels, value projections, and empty maps. The external fixture also trains shared values across its own immutable gate and a built-in gate.

Julia 1.10/1.13 local validation results are recorded in [the roadmap](../../docs/roadmap.md#verification-record).
