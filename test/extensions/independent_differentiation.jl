# Load the companion's own source and public contract checks. Its separate
# package acceptance resolves MOSSQuantum normally and verifies the core-only phase.
include(joinpath(@__DIR__, "..", "fixtures", "MOSSQuantumDemoDifferentiation", "src", "MOSSQuantumDemoDifferentiation.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "MOSSQuantumDemoDifferentiation", "test", "contract_checks.jl"))
DemoDifferentiationContractChecks.run(MOSSQuantumDemoDifferentiation, Zygote)
