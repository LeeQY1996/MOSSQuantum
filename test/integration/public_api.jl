using Test
using MOSS

include("../support/public_api_baseline.jl")

@testset "Public API compatibility" begin
    namespaces = Dict(
        "MOSS" => MOSS,
        "QuantumCircuits" => MOSS.QuantumCircuits,
        "Gates" => MOSS.QuantumCircuits.Gates,
        "Utilities" => MOSS.Utilities,
    )

    @testset "Legacy namespaces" begin
        @test nameof(MOSS) === :MOSS
        @test parentmodule(MOSS.QuantumCircuits) === MOSS
        @test parentmodule(MOSS.QuantumCircuits.Gates) === MOSS.QuantumCircuits
        @test parentmodule(MOSS.Utilities) === MOSS
        @test MOSS.Gates === MOSS.QuantumCircuits.Gates
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
        shared = intersect(PUBLIC_API_BASELINE["MOSS"], PUBLIC_API_BASELINE[namespace])
        for name in Symbol.(shared)
            @test getfield(MOSS, name) === getfield(mod, name)
        end
    end

    @testset "State type ownership" begin
        for state in (MOSS.StateVector, MOSS.DensityMatrix, MOSS.BatchStateVector)
            @test parentmodule(state) === MOSS
        end
    end

    @testset "Circuit type ownership" begin
        # Re-exported constructors must retain their original type identity.
        for name in Symbol.(PUBLIC_API_BASELINE["QuantumCircuits"])
            value = getfield(MOSS.QuantumCircuits, name)
            if value isa Type
                @test parentmodule(value) === MOSS.QuantumCircuits
            end
        end
    end
end
