
"""
	QuantumMap(positions, kraus; check_tp=false, atol=nothing)

Snapshot a Kraus representation. General CP maps may be non-trace-preserving;
use `check_tp=true` for physical noise. Returned matrix accessors are borrowed,
read-only data. Construct a new map to change its Kraus representation.
"""
struct QuantumMap{N, T<:Number} <: AbstractQuantumMap{N}
	pos::NTuple{N, Int}
	kraus::Vector{Matrix{T}}
	ordered_pos::NTuple{N, Int}
	ordered_data::Matrix{T}

end
function QuantumMap(pos::NTuple{N, Int}, mr::Vector{<:AbstractMatrix{T}}; check_tp::Bool=false, atol=nothing) where {N, T}
    N > 0 || throw(ArgumentError("a channel needs at least one position"))
    all(>(0), pos) && length(unique(pos)) == N ||
        throw(ArgumentError("channel positions must be positive and distinct"))
    isempty(mr) && throw(ArgumentError("a channel needs at least one Kraus matrix"))
    for k in mr
        size(k) == (2^N, 2^N) || throw(DimensionMismatch("Kraus dimensions must match the register"))
        all(isfinite, k) || throw(ArgumentError("Kraus matrices must be finite"))
    end
    tolerance = _channel_tolerance(T, atol)
    check_tp && !_is_tp(mr; atol=tolerance) && throw(ArgumentError("noise must be trace preserving"))
    mr = [copy(k) for k in mr]
	shapes = ntuple(i->2, 2*N)
	m = [reshape(mj, shapes) for mj in mr]
	ordered_pos, ordered_ops = _get_norm_order_list(pos, m)
	L = 2^N
	kraus = [convert(Matrix{T}, reshape(mj, L, L)) for mj in m]
	ordered_kraus = [convert(Matrix{T}, reshape(mj, L, L)) for mj in ordered_ops]
	ordered_data = convert(Matrix{T}, _compute_supermat(ordered_kraus))
	QuantumMap(pos, kraus, ordered_pos, ordered_data)
end


QuantumMap(pos::Vector{Int}, m::Vector{<:AbstractMatrix}; kwargs...) = QuantumMap(Tuple(pos), m; kwargs...)
QuantumMap(pos::Int, m::Vector{<:AbstractMatrix}; kwargs...) = QuantumMap((pos,), m; kwargs...)

positions(x::QuantumMap) = x.pos
Base.eltype(::Type{QuantumMap{N, T}}) where {N, T} = T
Base.eltype(x::QuantumMap) = eltype(typeof(x))
kraus_matrices(x::QuantumMap) = x.kraus
ordered_positions(x::QuantumMap) = x.ordered_pos
ordered_supermat(x::QuantumMap) = x.ordered_data
change_positions(x::QuantumMap{N}, m::AbstractDict) where N = QuantumMap(ntuple(i->m[x.pos[i]], N), kraus_matrices(x))



function _get_norm_order_list(key::NTuple{N, Int}, p::Vector{<:AbstractArray}) where N
	seq = sortperm([key...])
	perm = (seq..., [s + N for s in seq]...)
	return key[seq], [permute(item, perm) for item in p]
end


function _compute_supermat(p::Vector{<:AbstractMatrix})
	isempty(p) && error("no kraus operators.")
	d = size(p[1], 1)
	@tensor m[1,3,2,4] := p[1][1,2] * conj(p[1][3,4])
	for i in 2:length(p)
		@tensor m[1,3,2,4] += p[i][1,2] * conj(p[i][3,4])
	end
	return reshape(m, d^2, d^2)
end


function _validate_channel_data(x::QuantumMap; check_tp=false)
    pos = positions(x)
    n = nqubits(x)
    all(>(0), pos) && length(unique(pos)) == n ||
        throw(ArgumentError("channel positions must be positive and distinct"))
    ordered_positions(x) == Tuple(sort(collect(pos))) ||
        throw(ArgumentError("ordered channel positions disagree"))
    ks = kraus_matrices(x)
    isempty(ks) && throw(ArgumentError("a channel needs Kraus matrices"))
    d = 2^n
    for k in ks
        size(k) == (d, d) || throw(DimensionMismatch("invalid Kraus dimensions"))
        all(isfinite, k) || throw(ArgumentError("Kraus matrices must be finite"))
    end
    cached = ordered_supermat(x)
    size(cached) == (d*d, d*d) || throw(DimensionMismatch("invalid supermatrix dimensions"))
    all(isfinite, cached) || throw(ArgumentError("supermatrix must be finite"))
    _, ordered = _get_norm_order_list(pos, [reshape(k, ntuple(_ -> 2, 2n)) for k in ks])
    expected = _compute_supermat([reshape(k, d, d) for k in ordered])
    isapprox(cached, expected; atol=_channel_tolerance(eltype(x), nothing), rtol=0) ||
        throw(ArgumentError("channel data were mutated; construct a new QuantumMap instead"))
    check_tp && !is_tp(x) && throw(ArgumentError("stochastic noise must be trace preserving"))
    return nothing
end
