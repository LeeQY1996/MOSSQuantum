using Test
using MOSSQuantumDemoDifferentiation
import MOSSQuantum

include("core_only.jl")
include("contract_checks.jl")
DemoDifferentiationContractChecks.run_chainrules(MOSSQuantumDemoDifferentiation)

@testset "ChainRules fixture works without Zygote" begin
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test "ChainRulesCore" in loaded
    @test !("Zygote" in loaded)
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) !== nothing
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumZygoteExt) === nothing
end

import Zygote
DemoDifferentiationContractChecks.run_zygote(MOSSQuantumDemoDifferentiation, Zygote)
