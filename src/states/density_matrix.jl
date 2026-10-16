"""
    DensityMatrix(data; copy=false)
    DensityMatrix(state::DensityMatrix; copy=false)

Construct a dense mixed state. Compatible vector or matrix storage is reused by
default; `copy=true` guarantees independent backing storage. `copy=false` permits
reuse but type or layout conversion can still allocate. Converting a pure state
to a density matrix always creates new storage. `storage(state)` is a mutable
matrix sharing the state's vectorized backing storage.
"""
struct DensityMatrix{T <: Number} <: AbstractQuantumState
	data::Vector{T}
	nqubits::Int

function DensityMatrix{T}(data::AbstractVector{<:Number}, nqubits::Int; copy::Bool=false) where {T <: Number}
	(length(data) == 2^(2*nqubits)) || throw(DimensionMismatch())
	converted = convert(Vector{T}, data)
	new{T}(copy ? Base.copy(converted) : converted, nqubits)
end

end

function DensityMatrix{T}(m::AbstractMatrix{<:Number}, nqubits::Int; copy::Bool=false) where {T <: Number}
	(size(m, 1) == size(m, 2) == 2^nqubits) || throw(DimensionMismatch())
	return DensityMatrix{T}(reshape(m, length(m)), nqubits; copy=copy)
end
function DensityMatrix{T}(m::AbstractVector{<:Number}; copy::Bool=false) where {T <: Number}
	n = _nqubits(m)
	return DensityMatrix{T}(m, div(n, 2); copy=copy)
end
DensityMatrix{T}(m::AbstractMatrix{<:Number}; copy::Bool=false) where {T <: Number} = DensityMatrix{T}(reshape(m, length(m)); copy=copy)

DensityMatrix(data::Union{AbstractVector, AbstractMatrix}, nqubits::Int; copy::Bool=false) = DensityMatrix{eltype(data)}(data, nqubits; copy=copy)
DensityMatrix(data::AbstractVector; copy::Bool=false) = DensityMatrix(data, div(_nqubits(data), 2); copy=copy)
DensityMatrix(data::AbstractMatrix; copy::Bool=false) = DensityMatrix(reshape(data, length(data)); copy=copy)
function DensityMatrix{T}(nqubits::Int) where {T<:Number}
	 v = zeros(T, 2^(2*nqubits))
	 v[1,1] = 1
	 return DensityMatrix{T}(v, nqubits)
end
DensityMatrix(::Type{T}, nqubits::Int) where {T<:Number} = DensityMatrix{T}(nqubits)
DensityMatrix(nqubits::Int) = DensityMatrix(ComplexF64, nqubits)
DensityMatrix(x::DensityMatrix; copy::Bool=false) = DensityMatrix(x.data, nqubits(x); copy=copy)
DensityMatrix(x::StateVector; copy::Bool=false) = (x_data = storage(x); DensityMatrix(kron(conj(x_data), x_data), nqubits(x)))


storage(x::DensityMatrix) = (L = 2^(nqubits(x)); reshape(x.data, L, L))
QuantumCircuits.nqubits(x::DensityMatrix) = x.nqubits

Base.eltype(::Type{DensityMatrix{T}}) where T = T
Base.eltype(x::DensityMatrix) = eltype(typeof(x))
Base.getindex(x::DensityMatrix, j::Int...) = getindex(storage(x), j...)
Base.setindex!(x::DensityMatrix, v, j::Int...) = setindex!(storage(x), v, j...)

Base.convert(::Type{DensityMatrix{T}}, x::DensityMatrix) where {T<:Number} = DensityMatrix(convert(Vector{T}, x.data), nqubits(x))
Base.copy(x::DensityMatrix) = DensityMatrix(copy(x.data), nqubits(x))


Base.cat(v::DensityMatrix) = v
function Base.cat(v::DensityMatrix...)
    a, b = _qcat_util(storage.(v)...)
    return DensityMatrix(kron(a, b))
end

Base.isapprox(x::DensityMatrix, y::DensityMatrix; kwargs...) = isapprox(x.data, y.data; kwargs...)
Base.:(==)(x::DensityMatrix, y::DensityMatrix) = x.data == y.data

Base.:+(x::DensityMatrix, y::DensityMatrix) = DensityMatrix(x.data + y.data, nqubits(x))
Base.:-(x::DensityMatrix, y::DensityMatrix) = DensityMatrix(x.data - y.data, nqubits(x))
Base.:*(x::DensityMatrix, y::Number) = DensityMatrix(x.data * y, nqubits(x))
Base.:*(x::Number, y::DensityMatrix) = y * x
Base.:/(x::DensityMatrix, y::Number) = DensityMatrix(x.data / y, nqubits(x))


LinearAlgebra.tr(x::DensityMatrix) = tr(storage(x))
LinearAlgebra.dot(x::DensityMatrix, y::DensityMatrix) = dot(storage(x), storage(y))
LinearAlgebra.normalize!(x::DensityMatrix) = (x.data ./= tr(x); x)
LinearAlgebra.normalize(x::DensityMatrix) = normalize!(copy(x))
LinearAlgebra.ishermitian(x::DensityMatrix) = ishermitian(storage(x))
LinearAlgebra.isposdef(x::DensityMatrix) = isposdef(storage(x))

function _fidelity_psd_sqrt(matrix::AbstractMatrix)
    values, vectors = eigen(Hermitian(matrix))
    tolerance = length(values) * eps(eltype(values)) * maximum(abs, values)
    minimum(values) >= -tolerance || throw(DomainError(minimum(values), "density matrix must be positive semidefinite."))
    # Rank-deficient states can acquire eigenvalues of either sign from rounding.
    roots = map(value -> value > tolerance ? sqrt(value) : zero(value), values)
    return vectors * Diagonal(roots) * vectors'
end

function fidelity(x::DensityMatrix, y::DensityMatrix)
    nqubits(x) == nqubits(y) || throw(DimensionMismatch("states must have the same number of qubits."))
    # The trace norm gives Uhlmann fidelity for noncommuting states as well.
    product = _fidelity_psd_sqrt(storage(x)) * _fidelity_psd_sqrt(storage(y))
    return sum(svdvals(product))^2
end
fidelity(x::DensityMatrix, y::StateVector) = real(dot(storage(y), storage(x), storage(y)))
fidelity(x::StateVector, y::DensityMatrix) = fidelity(y, x)
distance2(x::DensityMatrix, y::DensityMatrix) = _distance2(x, y)
distance(x::DensityMatrix, y::DensityMatrix) = _distance(x, y)
schmidt_numbers(x::DensityMatrix) = eigvals(Hermitian(storage(x)))
renyi_entropy(x::DensityMatrix; kwargs...) = renyi_entropy(schmidt_numbers(x); kwargs...)

function rand_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int) where {T <: Number}
    (n >= 1) || error("number of qubits must be positive.")
    L = 2^n
    v = randn(rng, T, L, L)
    v = v' * v
    return normalize!(DensityMatrix(v' * v, n))
end
rand_densitymatrix(::Type{T}, n::Int) where {T<:Number} = rand_densitymatrix(Random.default_rng(), T, n)
rand_densitymatrix(rng::Random.AbstractRNG, n::Int) = rand_densitymatrix(rng, ComplexF64, n)
rand_densitymatrix(n::Int) = rand_densitymatrix(ComplexF64, n)

function QuantumCircuits.permute(x::DensityMatrix, newindex::Vector{Int})
	n = nqubits(x)
	L = length(x.data)
	return DensityMatrix(reshape(permute(reshape(x.data, ntuple(i->2, 2*n)), vcat(newindex, newindex .+ n)), L), n)
end 



