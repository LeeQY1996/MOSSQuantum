"""
    DensityMatrix(data; copy=false, preserve_storage=false)
    DensityMatrix(state::DensityMatrix; copy=false)

Construct a dense mixed state. `preserve_storage=true` retains the array family
instead of materializing CPU storage. Compatible vector or matrix storage is reused by
default; `copy=true` guarantees independent backing storage. `copy=false` permits
reuse but type or layout conversion can still allocate. Converting a pure state
to a density matrix always creates new storage. `storage(state)` is a mutable
matrix sharing the state's vectorized backing storage.
"""
struct DensityMatrix{T<:Number,A<:AbstractVector{T}} <: AbstractQuantumState
    data::A
    nqubits::Int

    function DensityMatrix{T,A}(data::A, n::Int) where {T<:Number,A<:AbstractVector{T}}
        dimension = _state_density_dimension(n)
        Base.require_one_based_indexing(data)
        length(data) == dimension^2 || throw(DimensionMismatch("density length must equal 4^n"))
        return new{T,A}(data, n)
    end
end

function DensityMatrix{T}(data::AbstractVector{<:Number}, n::Int;
                           copy::Bool=false, preserve_storage::Bool=false) where {T<:Number}
    dimension = _state_density_dimension(n)
    Base.require_one_based_indexing(data)
    length(data) == dimension^2 || throw(DimensionMismatch("density length must equal 4^n"))
    converted = _state_storage(data, T; copy=copy, preserve_storage=preserve_storage)
    return DensityMatrix{T,typeof(converted)}(converted, n)
end

function DensityMatrix{T}(data::AbstractMatrix{<:Number}, n::Int;
                           copy::Bool=false, preserve_storage::Bool=false) where {T<:Number}
    dimension = _state_density_dimension(n)
    Base.require_one_based_indexing(data)
    size(data) == (dimension, dimension) || throw(DimensionMismatch("density dimensions must equal 2^n"))
    return DensityMatrix{T}(reshape(data, length(data)), n; copy=copy, preserve_storage=preserve_storage)
end
function DensityMatrix{T}(data::AbstractVector{<:Number}; kwargs...) where {T<:Number}
    bits = _nqubits(data)
    iseven(bits) || throw(DimensionMismatch("vectorized density length must be a power of four"))
    return DensityMatrix{T}(data, div(bits, 2); kwargs...)
end
function DensityMatrix{T}(data::AbstractMatrix{<:Number}; kwargs...) where {T<:Number}
    Base.require_one_based_indexing(data)
    size(data, 1) == size(data, 2) || throw(DimensionMismatch("density matrices must be square"))
    ispow2(size(data, 1)) || throw(ArgumentError("density dimension must be a positive power of two"))
    return DensityMatrix{T}(data, trailing_zeros(size(data, 1)); kwargs...)
end
DensityMatrix(data::Union{AbstractVector{T},AbstractMatrix{T}}, n::Int; kwargs...) where {T<:Number} =
    DensityMatrix{T}(data, n; kwargs...)
DensityMatrix(data::Union{AbstractVector{T},AbstractMatrix{T}}; kwargs...) where {T<:Number} =
    DensityMatrix{T}(data; kwargs...)
function DensityMatrix{T}(nqubits::Int) where {T<:Number}
	 v = zeros(T, _state_density_dimension(nqubits)^2)
	 v[1,1] = 1
	 return DensityMatrix{T}(v, nqubits)
end
DensityMatrix(::Type{T}, nqubits::Int) where {T<:Number} = DensityMatrix{T}(nqubits)
DensityMatrix(nqubits::Int) = DensityMatrix(ComplexF64, nqubits)
DensityMatrix(x::DensityMatrix; copy::Bool=false) = DensityMatrix(x.data, nqubits(x); copy=copy, preserve_storage=true)
DensityMatrix{T}(x::DensityMatrix; copy::Bool=false) where {T<:Number} =
    DensityMatrix{T}(x.data, nqubits(x); copy=copy, preserve_storage=true)
function DensityMatrix(x::StateVector; copy::Bool=false)
    source = storage(x)
    dimension = length(source)
    data = _state_similar(source, eltype(x), (dimension, dimension))
    data .= reshape(source, dimension, 1) .* conj.(reshape(source, 1, dimension))
    return DensityMatrix(data, nqubits(x); preserve_storage=true)
end


storage(x::DensityMatrix) = (L = 2^(nqubits(x)); reshape(x.data, L, L))
QuantumCircuits.nqubits(x::DensityMatrix) = x.nqubits

Base.eltype(::Type{<:DensityMatrix{T}}) where T = T
Base.eltype(x::DensityMatrix) = eltype(typeof(x))
Base.getindex(x::DensityMatrix, j::Int...) = getindex(storage(x), j...)
Base.setindex!(x::DensityMatrix, v, j::Int...) = setindex!(storage(x), v, j...)

Base.convert(::Type{DensityMatrix{T}}, x::DensityMatrix) where {T<:Number} = DensityMatrix{T}(x.data, nqubits(x); preserve_storage=true)
Base.copy(x::DensityMatrix) = DensityMatrix(x; copy=true)


Base.cat(v::DensityMatrix) = v
function Base.cat(v::DensityMatrix...)
    for state in v
        _require_cpu_storage(state, cat)
    end
    a, b = _qcat_util(storage.(v)...)
    return DensityMatrix(kron(a, b); preserve_storage=true)
end

Base.isapprox(x::DensityMatrix, y::DensityMatrix; kwargs...) = isapprox(x.data, y.data; kwargs...)
Base.:(==)(x::DensityMatrix, y::DensityMatrix) = x.data == y.data

Base.:+(x::DensityMatrix, y::DensityMatrix) = DensityMatrix(_state_broadcast(+, x.data, y.data), nqubits(x); preserve_storage=true)
Base.:-(x::DensityMatrix, y::DensityMatrix) = DensityMatrix(_state_broadcast(-, x.data, y.data), nqubits(x); preserve_storage=true)
Base.:*(x::DensityMatrix, y::Number) = DensityMatrix(_state_broadcast(*, x.data, y), nqubits(x); preserve_storage=true)
Base.:*(x::Number, y::DensityMatrix) = y * x
Base.:/(x::DensityMatrix, y::Number) = DensityMatrix(_state_broadcast(/, x.data, y), nqubits(x); preserve_storage=true)


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
    _require_cpu_storage(x, fidelity)
    _require_cpu_storage(y, fidelity)
    nqubits(x) == nqubits(y) || throw(DimensionMismatch("states must have the same number of qubits."))
    # The trace norm gives Uhlmann fidelity for noncommuting states as well.
    product = _fidelity_psd_sqrt(storage(x)) * _fidelity_psd_sqrt(storage(y))
    return sum(svdvals(product))^2
end
fidelity(x::DensityMatrix, y::StateVector) = real(dot(storage(y), storage(x), storage(y)))
fidelity(x::StateVector, y::DensityMatrix) = fidelity(y, x)
distance2(x::DensityMatrix, y::DensityMatrix) = _distance2(x, y)
distance(x::DensityMatrix, y::DensityMatrix) = _distance(x, y)
schmidt_numbers(x::DensityMatrix) = (_require_cpu_storage(x, schmidt_numbers); eigvals(Hermitian(storage(x))))
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
    _require_cpu_storage(x, QuantumCircuits.permute)
	n = nqubits(x)
	L = length(x.data)
	return DensityMatrix(reshape(permute(reshape(x.data, ntuple(i->2, 2*n)), vcat(newindex, newindex .+ n)), L), n; preserve_storage=true)
end 



