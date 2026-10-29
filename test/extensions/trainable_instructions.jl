# The main suite loads the external fixture module directly; separate package
# verification develops MOSSQuantum into the fixture's own independent environment.
include(joinpath(@__DIR__, "..", "fixtures", "MOSSQuantumDemoGates", "src", "MOSSQuantumDemoGates.jl"))
include(joinpath(@__DIR__, "..", "fixtures", "MOSSQuantumDemoGates", "test", "contract_checks.jl"))
DemoGateContractChecks.run(MOSSQuantumDemoGates.DemoRotation)
