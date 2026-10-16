# Extension tests

MOSS requires Julia 1.10 or later; Julia 1.13 is the primary development and acceptance version. These tests cover optional Zygote and plotting integrations through native package extensions, their loading orders, and backend/AD capability boundaries. The Requires compatibility bridge has been removed.

Plotting integration checks also run from `test/integration/plotting.jl`; Plots and LaTeXStrings are optional runtime dependencies supplied by the test environment.

Julia 1.10/1.13 local validation results are recorded in [the roadmap](../../docs/roadmap.md#verification-record).
