using Test
using MOSSQuantum

include("../support/public_api_baseline.jl")

@testset "Public API compatibility" begin
    namespaces = Dict(
        "MOSSQuantum" => MOSSQuantum,
        "QuantumCircuits" => MOSSQuantum.QuantumCircuits,
        "Gates" => MOSSQuantum.QuantumCircuits.Gates,
        "Utilities" => MOSSQuantum.Utilities,
    )

    @testset "Legacy namespaces" begin
        @test nameof(MOSSQuantum) === :MOSSQuantum
        @test parentmodule(MOSSQuantum.QuantumCircuits) === MOSSQuantum
        @test parentmodule(MOSSQuantum.QuantumCircuits.Gates) === MOSSQuantum.QuantumCircuits
        @test parentmodule(MOSSQuantum.Utilities) === MOSSQuantum
        @test MOSSQuantum.Gates === MOSSQuantum.QuantumCircuits.Gates
    end

    @testset "Exports of $namespace" for namespace in sort!(collect(keys(namespaces)))
        mod = namespaces[namespace]
        expected = Symbol.(PUBLIC_API_BASELINE[namespace])
        # Additions are compatible; removing or unexporting an existing name is not.
        @test issubset(Set(expected), Set(names(mod)))
        for name in expected
            @test isdefined(mod, name)
        end
    end

    @testset "Re-exported bindings of $namespace" for namespace in ("QuantumCircuits", "Gates", "Utilities")
        mod = namespaces[namespace]
        shared = intersect(PUBLIC_API_BASELINE["MOSSQuantum"], PUBLIC_API_BASELINE[namespace])
        for name in Symbol.(shared)
            @test getfield(MOSSQuantum, name) === getfield(mod, name)
        end
    end

    @testset "State type ownership" begin
        for state in (MOSSQuantum.StateVector, MOSSQuantum.DensityMatrix, MOSSQuantum.BatchStateVector)
            @test parentmodule(state) === MOSSQuantum
        end
    end

    @testset "Circuit type ownership" begin
        # Re-exported constructors must retain their original type identity.
        for name in Symbol.(PUBLIC_API_BASELINE["QuantumCircuits"])
            value = getfield(MOSSQuantum.QuantumCircuits, name)
            if value isa Type
                @test parentmodule(value) === MOSSQuantum.QuantumCircuits
            end
        end
    end
end
