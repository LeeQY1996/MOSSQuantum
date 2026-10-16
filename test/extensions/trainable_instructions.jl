# The main suite loads the external fixture module directly; separate package
# verification develops MOSS into the fixture's own independent environment.
include(joinpath(@__DIR__, "..", "fixtures", "MOSSDemoGates", "src", "MOSSDemoGates.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "MOSSDemoGates", "test", "contract_checks.jl"))
DemoGateContractChecks.run(MOSSDemoGates.DemoRotation)
