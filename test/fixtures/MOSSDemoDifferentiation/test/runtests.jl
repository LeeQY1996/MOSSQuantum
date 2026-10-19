using Test
using MOSSDemoDifferentiation
import MOSS

include("core_only.jl")
include("contract_checks.jl")
DemoDifferentiationContractChecks.run_chainrules(MOSSDemoDifferentiation)

@testset "ChainRules fixture works without Zygote" begin
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test "ChainRulesCore" in loaded
    @test !("Zygote" in loaded)
    @test Base.get_extension(MOSS, :MOSSChainRulesCoreExt) !== nothing
    @test Base.get_extension(MOSS, :MOSSZygoteExt) === nothing
end

import Zygote
DemoDifferentiationContractChecks.run_zygote(MOSSDemoDifferentiation, Zygote)
