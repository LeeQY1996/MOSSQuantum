using Test
using MOSSQuantum

module ParameterProtocolFixtures
import MOSSQuantum

"""An immutable parameterized instruction with one frozen angle."""
struct AnglePair{T<:Real} <: MOSSQuantum.AbstractInstruction
    angles::NTuple{2,T}
    enabled::NTuple{2,Bool}
end
MOSSQuantum.positions(::AnglePair) = ()
MOSSQuantum.parameters(x::AnglePair) = collect(x.angles)
MOSSQuantum.active_parameters(x::AnglePair) = [angle for (angle, enabled) in zip(x.angles, x.enabled) if enabled]
function MOSSQuantum.reset_parameters!(x::AnglePair{T}, values::AbstractVector{<:Real}) where T
    length(values) == MOSSQuantum.nparameters(x) || throw(DimensionMismatch())
    all(isfinite, values) || throw(ArgumentError("parameters must be finite"))
    angles = collect(x.angles)
    angles[collect(x.enabled)] .= values
    return AnglePair(Tuple(angles), x.enabled)
end
MOSSQuantum.activate_parameter!(x::AnglePair, j::Int) = AnglePair(x.angles, ntuple(i -> i == j || x.enabled[i], 2))
MOSSQuantum.activate_parameters!(x::AnglePair) = AnglePair(x.angles, (true, true))
MOSSQuantum.deactivate_parameter!(x::AnglePair, j::Int) = AnglePair(x.angles, ntuple(i -> i != j && x.enabled[i], 2))
MOSSQuantum.deactivate_parameters!(x::AnglePair) = AnglePair(x.angles, (false, false))

"""No legacy fields; a custom copy hook is observable without shared counters."""
struct PublicAngle{T<:Real} <: MOSSQuantum.ParametricGate{1}
    angle::T
    enabled::Bool
    copied::Bool
end
MOSSQuantum.parameters(x::PublicAngle) = [x.angle]
MOSSQuantum.active_parameters(x::PublicAngle{T}) where T = x.enabled ? [x.angle] : T[]
MOSSQuantum.copy_instruction(x::PublicAngle) = PublicAngle(x.angle, x.enabled, true)
function MOSSQuantum.reset_parameters!(x::PublicAngle{T}, values::AbstractVector{<:Real}) where T
    length(values) == MOSSQuantum.nparameters(x) || throw(DimensionMismatch())
    all(isfinite, values) || throw(ArgumentError("parameters must be finite"))
    return PublicAngle(x.enabled ? convert(T, only(values)) : x.angle, x.enabled, x.copied)
end
MOSSQuantum.activate_parameter!(x::PublicAngle, ::Int) = PublicAngle(x.angle, true, x.copied)
MOSSQuantum.activate_parameters!(x::PublicAngle) = PublicAngle(x.angle, true, x.copied)
MOSSQuantum.deactivate_parameter!(x::PublicAngle, ::Int) = PublicAngle(x.angle, false, x.copied)
MOSSQuantum.deactivate_parameters!(x::PublicAngle) = PublicAngle(x.angle, false, x.copied)

struct MissingWriter <: MOSSQuantum.AbstractInstruction end
struct MissingGateWriter <: MOSSQuantum.ParametricGate{1} end
for type in (MissingWriter, MissingGateWriter)
    @eval MOSSQuantum.parameters(::$type) = [0.1]
    @eval MOSSQuantum.active_parameters(::$type) = [0.1]
end

struct InvalidWriter <: MOSSQuantum.AbstractInstruction end
MOSSQuantum.active_parameters(::InvalidWriter) = [0.1]
MOSSQuantum.reset_parameters!(::InvalidWriter, ::AbstractVector{<:Real}) = nothing

struct NonfiniteWriter <: MOSSQuantum.AbstractInstruction
    angle::Float64
end
MOSSQuantum.active_parameters(x::NonfiniteWriter) = [x.angle]
MOSSQuantum.reset_parameters!(::NonfiniteWriter, ::AbstractVector{<:Real}) = NonfiniteWriter(Inf)

struct RetainedValues{V<:AbstractVector{<:Real}} <: MOSSQuantum.AbstractInstruction
    angles::V
end
MOSSQuantum.parameters(x::RetainedValues) = x.angles
MOSSQuantum.active_parameters(x::RetainedValues) = x.angles
MOSSQuantum.reset_parameters!(::RetainedValues, values::AbstractVector{<:Real}) = RetainedValues(values)

struct InvalidCopy <: MOSSQuantum.AbstractInstruction end
MOSSQuantum.copy_instruction(::InvalidCopy) = nothing

struct InvalidActivation <: MOSSQuantum.Gate{1} end
MOSSQuantum.activate_parameters!(::InvalidActivation) = nothing
MOSSQuantum.deactivate_parameters!(::InvalidActivation) = nothing

mutable struct LegacyInstruction <: MOSSQuantum.AbstractInstruction
    angles::Vector{Float64}
end
MOSSQuantum.parameters(x::LegacyInstruction) = x.angles
MOSSQuantum.active_parameters(x::LegacyInstruction) = x.angles
function MOSSQuantum.QuantumCircuits.reset_parameters_util!(x::LegacyInstruction, values::Vector{<:Real}, pos::Int)
    n = length(x.angles)
    x.angles .= view(values, pos+1:pos+n)
    return pos + n
end
end

@testset "Public instruction parameter protocols" begin
    F = ParameterProtocolFixtures
    @test MOSSQuantum.copy_instruction === MOSSQuantum.QuantumCircuits.copy_instruction
    @test MOSSQuantum.reset_parameters! === MOSSQuantum.QuantumCircuits.reset_parameters!
    @test active_parameters(HGate(1)) === nothing
    @test nparameters(HGate(1)) == 0
    @test reset_parameters!(HGate(1), Float64[]) isa HGate
    @test differentiate(HGate(1)) === nothing

    @testset "Immutable instructions and numeric parameter storage" begin
        source = F.AnglePair((Float32(0.1), Float32(0.2)), (true, false))
        @test nparameters(source) == 1
        replacement = reset_parameters!(source, Float32[0.5])
        @test parameters(source) == Float32[0.1, 0.2]
        @test parameters(replacement) == Float32[0.5, 0.2]
        @test parameters(bind_parameters(source, Float32[0.75])) == Float32[0.75, 0.2]
        circuit = QCircuit([source, QCircuit([source])])
        values = Float32[0.3, 99, 0.4]
        @test reset_parameters!(circuit, view(values, 1:2:3)) === circuit
        @test active_parameters(circuit) == Float32[0.3, 0.4]
        @test eltype(active_parameters(circuit)) === Float32
        @test eltype(parameters(circuit)) === Float32
        with_empty_neighbors = QCircuit([source, QCircuit(), RzGate(1, 0.7)])
        @test active_parameters(with_empty_neighbors) == Float32[0.1]
        @test eltype(active_parameters(with_empty_neighbors)) === Float32
        @test eltype(active_parameters(QCircuit([QCircuit(), RzGate(1, 0.7)]))) === Float64
        @test parameters(source) == Float32[0.1, 0.2]
        @test parameters(circuit[2][1]) == Float32[0.4, 0.2]
        @test deactivate_parameters!(circuit) === circuit
        @test nparameters(circuit) == 0
        @test activate_parameter!(circuit, 2) === circuit
        @test nparameters(circuit) == 2
        @test deactivate_parameter!(circuit, 2) === circuit
        @test nparameters(circuit) == 0
        @test activate_parameters!(circuit) === circuit
        @test nparameters(circuit) == 4
    end

    @testset "Per-occurrence copies and adjoint replacement" begin
        gate = F.PublicAngle(0.1, true, false)
        circuit = QCircuit([gate, QCircuit([gate', gate])])
        copied = copy_instruction(circuit)
        @test copied !== circuit
        @test copied[2] !== circuit[2]
        @test copied[1].copied && copied[2][1].parent.copied && copied[2][2].copied
        bound = bind_parameters(circuit, [0.2, 0.3, 0.4])
        @test active_parameters(bound) == [0.2, 0.3, 0.4]
        @test active_parameters(circuit) == [0.1, 0.1, 0.1]
        @test bound[1].copied && bound[2][1].parent.copied && bound[2][2].copied
        @test parameters(bind_parameters(gate', [0.8])) == [0.8]
        inactive = deactivate_parameters!(gate')
        @test nparameters(inactive) == 0
        @test nparameters(gate') == 1
        @test nparameters(activate_parameters!(inactive)) == 1
        @test nparameters(deactivate_parameter!(gate', 1)) == 0
        @test nparameters(activate_parameter!(inactive, 1)) == 1
        @test bind_parameters(inactive, Float64[]).parent.copied
        @test_throws DimensionMismatch bind_parameters(gate, Float64[])
        @test_throws DimensionMismatch bind_parameters(gate, [0.2, 0.3])
        @test_throws ArgumentError bind_parameters(gate, [NaN])
        @test_throws ArgumentError bind_parameters(gate', [Inf])

        retained = F.RetainedValues([0.1])
        values = [0.6, 0.7]
        independent = bind_parameters(QCircuit([retained, retained]), values)
        values .= 1
        @test active_parameters(independent) == [0.6, 0.7]
        parameters(independent[1])[1] = 0.8
        @test active_parameters(independent) == [0.8, 0.7]
        @test parameters(retained) == [0.1]
    end

    @testset "Mutable reset aliases and legacy adapters remain supported" begin
        shared = RyGate(1, 0.1; isparas=true)
        circuit = QCircuit([shared, shared'])
        @test reset_parameters!(circuit, [0.2, 0.3]) === circuit
        @test active_parameters(circuit) == [0.3, 0.3]
        @test parameters(shared) == [0.3]
        @test parameters(bind_parameters(circuit, [0.4, 0.5])[1]) == [0.4]
        @test parameters(shared) == [0.3]
        legacy = F.LegacyInstruction([0.1, 0.2])
        @test reset_parameters!(legacy, view([0.3, 0.4], :)) === legacy
        @test active_parameters(legacy) == [0.3, 0.4]
        @test active_parameters(bind_parameters(legacy, [0.5, 0.6])) == [0.5, 0.6]
        @test active_parameters(legacy) == [0.3, 0.4]
    end

    @testset "Clear unsupported and invalid-extension errors" begin
        derivative_error = try
            differentiate(F.MissingGateWriter())
        catch caught
            caught
        end
        @test derivative_error isa ArgumentError
        @test occursin("differentiate", sprint(showerror, derivative_error))
        @test differentiate(F.PublicAngle(0.1, false, false)) === nothing
        for instruction in (F.MissingWriter(), F.MissingGateWriter())
            error = try
                bind_parameters(instruction, [0.2])
            catch caught
                caught
            end
            @test error isa ArgumentError
            @test occursin("reset_parameters!", sprint(showerror, error))
            @test_throws ArgumentError reset_parameters!(instruction, [0.2])
        end
        for instruction in (F.InvalidWriter(), F.NonfiniteWriter(0.1))
            @test_throws ArgumentError bind_parameters(instruction, [0.2])
            @test_throws ArgumentError reset_parameters!(QCircuit([instruction]), [0.2])
        end
        @test_throws ArgumentError bind_parameters(F.InvalidCopy(), Float64[])
        @test_throws ArgumentError activate_parameters!(QCircuit([F.InvalidActivation()]))
        @test_throws ArgumentError deactivate_parameters!(QCircuit([F.InvalidActivation()]))
        @test_throws ArgumentError activate_parameters!(F.InvalidActivation()')
        @test_throws ArgumentError deactivate_parameters!(F.InvalidActivation()')
        @test_throws DimensionMismatch reset_parameters!(QCircuit([RxGate(1, 0.1; isparas=true)]), Float64[])
        @test_throws ArgumentError reset_parameters!(QCircuit([RxGate(1, 0.1; isparas=true)]), [NaN])
    end
end
