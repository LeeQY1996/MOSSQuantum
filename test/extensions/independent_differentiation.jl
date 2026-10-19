# Load the companion's own source and public contract checks. Its separate
# package acceptance resolves MOSS normally and verifies the core-only phase.
include(joinpath(@__DIR__, "..", "fixtures", "MOSSDemoDifferentiation", "src", "MOSSDemoDifferentiation.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "MOSSDemoDifferentiation", "test", "contract_checks.jl"))
DemoDifferentiationContractChecks.run(MOSSDemoDifferentiation, Zygote)
