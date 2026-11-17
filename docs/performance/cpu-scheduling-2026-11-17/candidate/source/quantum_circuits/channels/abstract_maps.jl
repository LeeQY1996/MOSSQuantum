abstract type AbstractQuantumMap{N} <: AbstractInstruction end


# interfaces for Quantum Channel

nqubits(x::AbstractQuantumMap{N}) where N = N

positions(x::AbstractQuantumMap) = x.pos

"""
	kraus_matrices(x::AbstractQuantumMap)
"""
kraus_matrices(x::AbstractQuantumMap) = error("kraus_matrices not implemented for map type $(typeof(x)).")


"""
	ordered_supermat(x::AbstractQuantumMap)
"""
ordered_supermat(x::AbstractQuantumMap) = error("ordered_supermat not implemented for map type $(typeof(x)).")

change_positions(x::AbstractQuantumMap, m::AbstractDict) = error("change_positions not implemented for map type $(typeof(x)).")

shift(x::AbstractQuantumMap, j::Int) = _shift_gate_util!(x, j, Dict{Int, Int}())

is_tp(x::AbstractQuantumMap; kwargs...) = _is_tp(kraus_matrices(x); kwargs...)


# QuantumMap can not contain parameters
nparameters(x::AbstractQuantumMap) = 0
parameters(x::AbstractQuantumMap) = nothing
active_parameters(x::AbstractQuantumMap) = nothing
activate_parameter!(x::AbstractQuantumMap, j::Int) = x
activate_parameters!(x::AbstractQuantumMap) = x
deactivate_parameter!(x::AbstractQuantumMap, j::Int) = x
deactivate_parameters!(x::AbstractQuantumMap) = x
reset_parameters_util!(x::AbstractQuantumMap, p::Vector{<:Real}, pos::Int) = pos

function _channel_tolerance(::Type{T}, atol) where T
    value = isnothing(atol) ? 100eps(typeof(float(real(zero(T))))) : atol
    value isa Real && isfinite(value) && value >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))
    return value
end

function _is_tp(m::Vector{<:AbstractMatrix}; atol=nothing)
    isempty(m) && return false
    tolerance = _channel_tolerance(eltype(first(m)), atol)
	out = m[1]' * m[1]
	for i in 2:length(m)
		out .+= m[i]' * m[i]
	end
	return isapprox(out, Matrix{eltype(out)}(I, size(out)...); atol=tolerance, rtol=0)
end

