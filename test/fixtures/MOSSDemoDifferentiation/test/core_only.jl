using Test
using MOSSDemoDifferentiation
import MOSS

include("core_checks.jl")
DemoDifferentiationCoreChecks.run(MOSSDemoDifferentiation)

@testset "core fixture has no AD dependency" begin
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test !("ChainRulesCore" in loaded)
    @test !("Zygote" in loaded)
    @test Base.get_extension(MOSS, :MOSSChainRulesCoreExt) === nothing
    @test Base.get_extension(MOSS, :MOSSZygoteExt) === nothing
end
