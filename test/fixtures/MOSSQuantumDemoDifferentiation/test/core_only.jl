using Test
using MOSSQuantumDemoDifferentiation
import MOSSQuantum

include("core_checks.jl")
DemoDifferentiationCoreChecks.run(MOSSQuantumDemoDifferentiation)

@testset "core fixture has no AD dependency" begin
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test !("ChainRulesCore" in loaded)
    @test !("Zygote" in loaded)
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) === nothing
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumZygoteExt) === nothing
end
