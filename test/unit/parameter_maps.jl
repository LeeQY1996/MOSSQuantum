using Test
using MOSS

module ParameterMapFixtures
import MOSS

"""An immutable instruction that stores active values without legacy fields."""
struct ImmutablePair{T<:Real} <: MOSS.AbstractInstruction
    angles::NTuple{2,T}
end
MOSS.parameters(x::ImmutablePair) = collect(x.angles)
MOSS.active_parameters(x::ImmutablePair) = collect(x.angles)
function MOSS.reset_parameters!(x::ImmutablePair{T}, values::AbstractVector{<:Real}) where T
    length(values) == 2 || throw(DimensionMismatch())
    all(isfinite, values) || throw(ArgumentError("parameters must be finite"))
    return ImmutablePair((convert(T, values[1]), convert(T, values[2])))
end
end

@testset "Explicit parameter maps" begin
    @testset "Identity, sharing, immutable snapshots, and equality" begin
        indices = [1, 2, 1]
        map = ParameterMap(indices)
        @test length(map) == 3
        @test nparameters(map) == 2
        @test parameter_indices(map) == [1, 2, 1]
        @test parameter_indices(map) isa Vector{Int}
        indices .= 1
        @test parameter_indices(map) == [1, 2, 1]
        exposed = parameter_indices(map)
        exposed[1] = 2
        @test parameter_indices(map) == [1, 2, 1]
        @test parameter_indices(copy(map)) == [1, 2, 1]
        @test copy(map) === map
        @test map == ParameterMap((1, 2, 1))
        @test hash(map) == hash(ParameterMap((1, 2, 1)))
        @test map != ParameterMap([1, 1, 2])
        @test parameter_indices(ParameterMap(UInt8[1, 2, 1])) == [1, 2, 1]
        @test parameter_indices(ParameterMap(BigInt[2, 1, 2])) == [2, 1, 2]

        template = QCircuit([RxGate(1, 0.1; isparas=true), RzGate(1, 0.2),
            QCircuit([RyGate(1, 0.3; isparas=true)])])
        identity = ParameterMap(template)
        @test parameter_indices(identity) == [1, 2]
        @test length(identity) == nparameters(template) == nparameters(identity)
        @test ParameterMap(template, [1, 1]) == ParameterMap([1, 1])
        @test_throws DimensionMismatch ParameterMap(template, [1])
        @test_throws DimensionMismatch ParameterMap(template, [1, 2, 1])
    end

    @testset "Shared binding preserves inactive values and owned storage" begin
        shared = RxGate(1, 0.1; isparas=true)
        inactive = RzGate(2, 0.6)
        template = QCircuit([shared, inactive,
            QCircuit([RyGate(2, 0.2; isparas=true), shared']), shared])
        map = ParameterMap(template, [1, 2, 1, 1])
        values = [0.4, -0.3]
        bound = bind_parameters(template, values, map)
        @test bound !== template
        @test bound[3] !== template[3]
        @test active_parameters(bound) == [0.4, -0.3, 0.4, 0.4]
        @test active_parameters(template) == [0.1, 0.2, 0.1, 0.1]
        @test parameters(bound[2]) == [0.6]
        @test parameters(bound[2]) !== parameters(inactive)
        @test parameters(bound[1]) !== parameters(bound[3][2])
        @test parameters(bound[1]) !== parameters(bound[4])
        @test parameter_indices(map) == [1, 2, 1, 1]
        values .= 9
        @test active_parameters(bound) == [0.4, -0.3, 0.4, 0.4]
        parameters(bound[1])[1] = 0.8
        @test active_parameters(bound) == [0.8, -0.3, 0.4, 0.4]
        @test parameters(shared) == [0.1]

        independent = bind_parameters(template, [0.2, 0.3, 0.4, 0.5])
        @test active_parameters(independent) == [0.2, 0.3, 0.4, 0.5]
        @test active_parameters(bind_parameters(template, [0.2, 0.3, 0.4, 0.5], ParameterMap(template))) ==
            active_parameters(independent)
        reset_parameters!(QCircuit([shared, shared]), [0.2, 0.3])
        @test parameters(shared) == [0.3]
    end

    @testset "Abstract real vectors and immutable instructions" begin
        instruction = ParameterMapFixtures.ImmutablePair((Float32(0.1), Float32(0.2)))
        map = ParameterMap(instruction, (1, 1))
        bound = bind_parameters(instruction, Float32[0.75], map)
        @test parameters(bound) == Float32[0.75, 0.75]
        @test eltype(active_parameters(bound)) === Float32
        @test parameters(instruction) == Float32[0.1, 0.2]
        identity = ParameterMap(instruction)
        @test parameters(bind_parameters(instruction, view(Float32[0.3, 99, 0.4], 1:2:3), identity)) == Float32[0.3, 0.4]
        @test parameters(bind_parameters(instruction, Real[0.5f0, 0.75], identity)) == Float32[0.5, 0.75]
        @test parameters(bind_parameters(instruction, 1:2, identity)) == Float32[1, 2]
        @test parameters(bind_parameters(instruction, BigFloat[0.25, 0.5], identity)) == Float32[0.25, 0.5]

        nested = QCircuit([instruction, QCircuit([instruction])])
        shared_map = ParameterMap(nested, [1, 2, 2, 1])
        @test active_parameters(bind_parameters(nested, Float32[0.6, 0.7], shared_map)) == Float32[0.6, 0.7, 0.7, 0.6]
    end

    @testset "Empty and changed active-slot layouts" begin
        for map in (ParameterMap(Int[]), ParameterMap(()), ParameterMap(QCircuit()))
            @test length(map) == 0
            @test nparameters(map) == 0
            @test parameter_indices(map) == Int[]
            @test isempty(accumulate_parameter_gradients(map, Float32[]))
            @test eltype(accumulate_parameter_gradients(map, Float32[])) === Float32
            @test isempty(bind_parameters(QCircuit(), Float64[], map))
            frozen = QCircuit([RzGate(1, 0.4)])
            bound = bind_parameters(frozen, Real[], map)
            @test parameters(bound[1]) == [0.4]
            @test parameters(bound[1]) !== parameters(frozen[1])
        end

        template = QCircuit([RxGate(1, 0.1; isparas=true), RyGate(1, 0.2)])
        map = ParameterMap(template)
        activate_parameter!(template, 2)
        @test_throws DimensionMismatch bind_parameters(template, [0.3], map)
        deactivate_parameter!(template, 1)
        # Equal slot counts cannot identify a changed layout: the map is
        # positional metadata and now addresses the currently active Ry slot.
        bound = bind_parameters(template, [0.3], map)
        @test parameters(bound[1]) == [0.1]
        @test active_parameters(bound) == [0.3]
        @test parameter_indices(map) == [1]
    end

    @testset "Gradient accumulation, dtype, and input preservation" begin
        map = ParameterMap([1, 2, 1])
        gradients = Float32[1, 2, 3]
        result = accumulate_parameter_gradients(map, gradients)
        @test result == Float32[4, 2]
        @test eltype(result) === Float32
        @test gradients == Float32[1, 2, 3]
        result[1] = 0
        @test gradients == Float32[1, 2, 3]
        @test accumulate_parameter_gradients(map, 1:3) == [4, 2]
        @test accumulate_parameter_gradients(map, view([1.0, 99, 2, 99, 3], 1:2:5)) == [4, 2]
        @test accumulate_parameter_gradients(map, Rational{Int}[1//3, 2//3, 1//3]) == [2//3, 2//3]
        @test eltype(accumulate_parameter_gradients(map, BigFloat[1, 2, 3])) === BigFloat
        @test accumulate_parameter_gradients(map, BigFloat[1, 2, 3]) == BigFloat[4, 2]
        @test accumulate_parameter_gradients(map, Real[1f0, 2.0, 3]) == [4, 2]
        @test accumulate_parameter_gradients(map, Bool[true, true, true]) == [2, 1]
        @test eltype(accumulate_parameter_gradients(map, Bool[true, true, true])) === Int
        nonfinite = accumulate_parameter_gradients(map, [Inf, 1, -Inf])
        @test isnan(nonfinite[1])
        @test nonfinite[2] == 1
        @test isnan(accumulate_parameter_gradients(map, [NaN, 1, 2])[1])
        @test parameter_indices(map) == [1, 2, 1]
        @test_throws DimensionMismatch accumulate_parameter_gradients(map, [1, 2])
        @test_throws DimensionMismatch accumulate_parameter_gradients(map, [1, 2, 3, 4])
    end

    @testset "Invalid identities and binding inputs" begin
        for indices in ([0], [-1], [1, 0], [2], [1, 3], [2, 2], [true],
                        (1, true), [1.0], ["1"], [BigInt(typemax(Int)) + 1])
            @test_throws ArgumentError ParameterMap(indices)
        end
        template = QCircuit([RyGate(1, 0.1; isparas=true), RyGate(1, 0.2; isparas=true)])
        map = ParameterMap(template, [1, 1])
        @test_throws DimensionMismatch bind_parameters(template, Float64[], map)
        @test_throws DimensionMismatch bind_parameters(template, [0.3, 0.4], map)
        @test_throws DimensionMismatch bind_parameters(template, [0.3], ParameterMap([1]))
        @test_throws ArgumentError bind_parameters(template, [NaN], map)
        @test_throws ArgumentError bind_parameters(template, [Inf], map)
        @test_throws ArgumentError bind_parameters(template, [-Inf], map)
        @test_throws ArgumentError bind_parameters(template, BigFloat[big"1e1000"], map)
        @test active_parameters(template) == [0.1, 0.2]
        @test parameter_indices(map) == [1, 1]
    end
end
