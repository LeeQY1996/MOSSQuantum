"""
    BatchDensityMatrix(data; copy=false, preserve_storage=false)
    BatchDensityMatrix(state::BatchDensityMatrix; copy=true)
    BatchDensityMatrix(state::DensityMatrix; copy=false)
    BatchDensityMatrix(state::Union{StateVector,BatchStateVector})

Array constructors materialize CPU storage unless `preserve_storage=true` is
requested. Copies and state conversions retain the array family.

A batch of independent dense density matrices with mutable storage of shape
`(2^n, 2^n, B)`. The last axis always identifies samples, including when `B=1`.
Zero-qubit registers and empty batches are supported. Array and single-density
inputs may share compatible storage; `copy=true` guarantees independent storage.
Pure-state conversions and lists always allocate each sample's outer product or
copy. Constructors validate shape, without requiring positivity or unit trace.
"""
struct BatchDensityMatrix{T<:Number,A<:AbstractArray{T,3}} <: AbstractQuantumState
    data::A
    nqubits::Int
    batch_size::Int

    function BatchDensityMatrix{T,A}(data::A, n::Int, B::Int) where {T<:Number,A<:AbstractArray{T,3}}
        dimension = _batch_density_dimension(n, B)
        Base.require_one_based_indexing(data)
        size(data) == (dimension, dimension, B) || throw(DimensionMismatch("density batch shape must equal (2^n, 2^n, B)"))
        return new{T,A}(data, n, B)
    end
end

function BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}, n::Int, B::Int;
                                copy::Bool=false, preserve_storage::Bool=false) where {T<:Number}
    dimension = _batch_density_dimension(n, B)
    Base.require_one_based_indexing(data)
    size(data) == (dimension, dimension, B) || throw(DimensionMismatch("density batch shape must equal (2^n, 2^n, B)"))
    converted = _state_storage(data, T; copy=copy, preserve_storage=preserve_storage)
    return BatchDensityMatrix{T,typeof(converted)}(converted, n, B)
end

function _batch_density_dimension(n::Int, B::Int)
    dimension = _batch_dimension(n)
    n <= div(8sizeof(Int) - 2, 2) ||
        throw(ArgumentError("the vectorized density dimension must fit Int"))
    B >= 0 || throw(ArgumentError("batch size must be nonnegative"))
    B <= div(typemax(Int), dimension * dimension) ||
        throw(ArgumentError("the density batch length must fit Int"))
    return dimension
end

function _batch_density_nqubits(data::AbstractArray{<:Number,3})
    Base.require_one_based_indexing(data)
    dimension = size(data, 1)
    dimension == size(data, 2) || throw(DimensionMismatch("density sample matrices must be square"))
    ispow2(dimension) || throw(ArgumentError("density sample dimension must be a positive power of two"))
    return trailing_zeros(dimension)
end

BatchDensityMatrix(data::AbstractArray{T,3}, n::Int, B::Int; kwargs...) where {T<:Number} =
    BatchDensityMatrix{T}(data, n, B; kwargs...)
BatchDensityMatrix(data::AbstractArray{T,3}, n::Int; kwargs...) where {T<:Number} =
    BatchDensityMatrix{T}(data, n, size(data, 3); kwargs...)
BatchDensityMatrix(data::AbstractArray{T,3}; kwargs...) where {T<:Number} =
    BatchDensityMatrix{T}(data, _batch_density_nqubits(data), size(data, 3); kwargs...)
BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}, n::Int; kwargs...) where {T<:Number} =
    BatchDensityMatrix{T}(data, n, size(data, 3); kwargs...)
BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}; kwargs...) where {T<:Number} =
    BatchDensityMatrix{T}(data, _batch_density_nqubits(data), size(data, 3); kwargs...)

function BatchDensityMatrix{T}(n::Int, B::Int) where {T<:Number}
    dimension = _batch_density_dimension(n, B)
    data = zeros(T, dimension, dimension, B)
    data[1, 1, :] .= one(T)
    return BatchDensityMatrix{T}(data, n, B)
end
BatchDensityMatrix(::Type{T}, n::Int, B::Int) where {T<:Number} = BatchDensityMatrix{T}(n, B)
BatchDensityMatrix(n::Int, B::Int) = BatchDensityMatrix(ComplexF64, n, B)

BatchDensityMatrix(x::BatchDensityMatrix; copy::Bool=true) =
    BatchDensityMatrix(storage(x), nqubits(x), batch_size(x); copy=copy, preserve_storage=true)
BatchDensityMatrix{T}(x::BatchDensityMatrix; copy::Bool=true) where {T<:Number} =
    BatchDensityMatrix{T}(storage(x), nqubits(x), batch_size(x); copy=copy, preserve_storage=true)

function BatchDensityMatrix(x::DensityMatrix; copy::Bool=false)
    dimension = _batch_density_dimension(nqubits(x), 1)
    return BatchDensityMatrix(reshape(x.data, dimension, dimension, 1), nqubits(x), 1; copy=copy, preserve_storage=true)
end
BatchDensityMatrix{T}(x::DensityMatrix; copy::Bool=false) where {T<:Number} =
    BatchDensityMatrix{T}(reshape(x.data, size(storage(x))..., 1), nqubits(x), 1; copy=copy, preserve_storage=true)

function BatchDensityMatrix(states::AbstractVector{<:DensityMatrix}; copy::Bool=false)
    isempty(states) && throw(ArgumentError("an empty density list needs explicit qubit and batch dimensions"))
    Base.require_one_based_indexing(states)
    n, B = nqubits(first(states)), length(states)
    dimension = _batch_density_dimension(n, B)
    all(state -> nqubits(state) == n, states) ||
        throw(DimensionMismatch("all density samples must have the same qubit count"))
    T = foldl(promote_type, (eltype(state) for state in states))
    data = _state_similar(storage(first(states)), T, (dimension, dimension, B))
    for b in 1:B
        copyto!(view(data, :, :, b), storage(states[b]))
    end
    return BatchDensityMatrix(data, n, B; preserve_storage=true)
end

function BatchDensityMatrix(x::BatchStateVector; copy::Bool=false)
    dimension = _batch_density_dimension(nqubits(x), batch_size(x))
    count = batch_size(x)
    source = storage(x)
    data = _state_similar(source, eltype(x), (dimension, dimension, count))
    data .= reshape(source, dimension, 1, count) .* conj.(reshape(source, 1, dimension, count))
    return BatchDensityMatrix(data, nqubits(x), count; preserve_storage=true)
end
BatchDensityMatrix(x::StateVector; copy::Bool=false) = BatchDensityMatrix(BatchStateVector(x))
BatchDensityMatrix{T}(x::Union{StateVector,BatchStateVector}; copy::Bool=false) where {T<:Number} =
    convert(BatchDensityMatrix{T}, BatchDensityMatrix(x))

"""
    DensityMatrix(batch::BatchDensityMatrix, sample; copy=true)

Extract a density matrix with independent storage in the batch array family.
Extraction remains independent even with `copy=false`.
"""
function DensityMatrix(x::BatchDensityMatrix, sample::Int; copy::Bool=true)
    1 <= sample <= batch_size(x) || throw(BoundsError(x, (:, :, sample)))
    return DensityMatrix(_copy_state_storage_as(view(storage(x), :, :, sample), eltype(x)), nqubits(x); preserve_storage=true)
end

storage(x::BatchDensityMatrix) = x.data
QuantumCircuits.nqubits(x::BatchDensityMatrix) = x.nqubits
batch_size(x::BatchDensityMatrix) = x.batch_size
Base.eltype(::Type{<:BatchDensityMatrix{T}}) where {T} = T
Base.eltype(x::BatchDensityMatrix) = eltype(typeof(x))
Base.getindex(x::BatchDensityMatrix, indices::Int...) = getindex(storage(x), indices...)
Base.setindex!(x::BatchDensityMatrix, value, indices::Int...) = setindex!(storage(x), value, indices...)
Base.copy(x::BatchDensityMatrix) = BatchDensityMatrix(x; copy=true)
Base.convert(::Type{BatchDensityMatrix{T}}, x::BatchDensityMatrix) where {T<:Number} =
    BatchDensityMatrix{T}(storage(x), nqubits(x), batch_size(x); preserve_storage=true)

Base.:(==)(x::BatchDensityMatrix, y::BatchDensityMatrix) =
    nqubits(x) == nqubits(y) && batch_size(x) == batch_size(y) && storage(x) == storage(y)
Base.isapprox(x::BatchDensityMatrix, y::BatchDensityMatrix; kwargs...) =
    size(storage(x)) == size(storage(y)) && isapprox(storage(x), storage(y); kwargs...)

function _check_batch_pair(x::BatchDensityMatrix, y::Union{BatchDensityMatrix,BatchStateVector})
    nqubits(x) == nqubits(y) && batch_size(x) == batch_size(y) ||
        throw(DimensionMismatch("batch registers and sample counts must match"))
    return nothing
end
_check_batch_pair(x::BatchStateVector, y::BatchDensityMatrix) = _check_batch_pair(y, x)

Base.:+(x::BatchDensityMatrix, y::BatchDensityMatrix) =
    (_check_batch_pair(x, y); BatchDensityMatrix(_state_broadcast(+, storage(x), storage(y)), nqubits(x), batch_size(x); preserve_storage=true))
Base.:-(x::BatchDensityMatrix, y::BatchDensityMatrix) =
    (_check_batch_pair(x, y); BatchDensityMatrix(_state_broadcast(-, storage(x), storage(y)), nqubits(x), batch_size(x); preserve_storage=true))
Base.:*(x::BatchDensityMatrix, value::Number) = BatchDensityMatrix(_state_broadcast(*, storage(x), value), nqubits(x), batch_size(x); preserve_storage=true)
Base.:*(value::Number, x::BatchDensityMatrix) = x * value
Base.:/(x::BatchDensityMatrix, value::Number) = BatchDensityMatrix(_state_broadcast(/, storage(x), value), nqubits(x), batch_size(x); preserve_storage=true)

LinearAlgebra.tr(x::BatchDensityMatrix) = [tr(view(storage(x), :, :, b)) for b in 1:batch_size(x)]
LinearAlgebra.norm(x::BatchDensityMatrix) = [norm(view(storage(x), :, :, b)) for b in 1:batch_size(x)]
LinearAlgebra.ishermitian(x::BatchDensityMatrix) = [ishermitian(view(storage(x), :, :, b)) for b in 1:batch_size(x)]
LinearAlgebra.isposdef(x::BatchDensityMatrix) = [isposdef(view(storage(x), :, :, b)) for b in 1:batch_size(x)]

function LinearAlgebra.dot(x::BatchDensityMatrix, y::BatchDensityMatrix)
    _check_batch_pair(x, y)
    return [dot(view(storage(x), :, :, b), view(storage(y), :, :, b)) for b in 1:batch_size(x)]
end

function LinearAlgebra.normalize!(x::BatchDensityMatrix)
    _require_cpu_storage(x, normalize!)
    traces = tr(x)
    all(value -> isfinite(value) && real(value) > 0 &&
                 isapprox(value, real(value); rtol=64eps(typeof(float(real(value)))), atol=0), traces) ||
        throw(ArgumentError("each density sample must have finite, positive real trace"))
    for b in 1:batch_size(x)
        view(storage(x), :, :, b) ./= traces[b]
    end
    return x
end
LinearAlgebra.normalize(x::BatchDensityMatrix) = normalize!(copy(x))

function fidelity(x::BatchDensityMatrix, y::BatchDensityMatrix)
    _require_cpu_storage(x, fidelity)
    _require_cpu_storage(y, fidelity)
    _check_batch_pair(x, y)
    return [fidelity(DensityMatrix(x, b), DensityMatrix(y, b)) for b in 1:batch_size(x)]
end
function fidelity(x::BatchDensityMatrix, y::BatchStateVector)
    _require_cpu_storage(x, fidelity)
    _require_cpu_storage(y, fidelity)
    _check_batch_pair(x, y)
    return [real(dot(view(storage(y), :, b), view(storage(x), :, :, b), view(storage(y), :, b)))
            for b in 1:batch_size(x)]
end
fidelity(x::BatchStateVector, y::BatchDensityMatrix) = fidelity(y, x)

function distance2(x::BatchDensityMatrix, y::BatchDensityMatrix)
    _check_batch_pair(x, y)
    return abs.(real.(dot(x, x)) .+ real.(dot(y, y)) .- 2 .* real.(dot(x, y)))
end
distance(x::BatchDensityMatrix, y::BatchDensityMatrix) = sqrt.(distance2(x, y))

function reset!(x::BatchDensityMatrix)
    _require_cpu_storage(x, reset!)
    fill!(storage(x), zero(eltype(x)))
    storage(x)[1, 1, :] .= one(eltype(x))
    return x
end
function reset_onehot!(x::BatchDensityMatrix, indices::Vector{Vector{Int}})
    _require_cpu_storage(x, reset_onehot!)
    batch_size(x) == length(indices) || throw(DimensionMismatch("one basis input is required per sample"))
    all(bits -> length(bits) == nqubits(x), indices) || throw(DimensionMismatch("basis inputs must match the register"))
    all(_is_valid_indices, indices) || throw(ArgumentError("basis entries must be zero or one"))
    fill!(storage(x), zero(eltype(x)))
    for (b, bits) in enumerate(indices)
        position = isempty(bits) ? 1 : _sub2ind(bits) + 1
        storage(x)[position, position, b] = one(eltype(x))
    end
    return x
end
function reset_qubit!(x::BatchDensityMatrix, inputs::AbstractMatrix{<:Real})
    _require_cpu_storage(x, reset_qubit!)
    size(inputs) == (nqubits(x), batch_size(x)) || throw(DimensionMismatch("encoding shape must match the batch"))
    state = BatchDensityMatrix(batch_qubit_encoding(eltype(x), inputs))
    copyto!(storage(x), storage(state))
    return x
end

function QuantumCircuits.permute(x::BatchDensityMatrix, order::Vector{Int})
    _require_cpu_storage(x, QuantumCircuits.permute)
    n = nqubits(x)
    sort(order) == collect(1:n) || throw(ArgumentError("qubit order must be a permutation of 1:$n"))
    n == 0 && return copy(x)
    result = similar(storage(x))
    axes_order = vcat(order, order .+ n)
    dimension = size(storage(x), 1)
    for b in 1:batch_size(x)
        tensor = reshape(view(storage(x), :, :, b), ntuple(_ -> 2, 2n))
        result[:, :, b] = reshape(QuantumCircuits.permute(tensor, axes_order), dimension, dimension)
    end
    return BatchDensityMatrix(result, n, batch_size(x); preserve_storage=true)
end

function rand_batch_densitymatrix(rng::Random.AbstractRNG, ::Type{T}, n::Int, B::Int) where {T<:Number}
    dimension = _batch_density_dimension(n, B)
    data = Array{T,3}(undef, dimension, dimension, B)
    for b in 1:B
        factor = randn(rng, T, dimension, dimension)
        data[:, :, b] = factor * factor'
    end
    return normalize!(BatchDensityMatrix(data, n, B))
end
rand_batch_densitymatrix(::Type{T}, n::Int, B::Int) where {T<:Number} =
    rand_batch_densitymatrix(Random.default_rng(), T, n, B)
rand_batch_densitymatrix(rng::Random.AbstractRNG, n::Int, B::Int) =
    rand_batch_densitymatrix(rng, ComplexF64, n, B)
rand_batch_densitymatrix(n::Int, B::Int) = rand_batch_densitymatrix(ComplexF64, n, B)
