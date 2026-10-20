"""
    BatchStateVector(data; copy=false, preserve_storage=false)
    BatchStateVector(state::BatchStateVector; copy=true)
    BatchStateVector(state::StateVector; copy=false)

Construct a batch of dense pure states. `preserve_storage=true` on array inputs
retains their array family; ordinary array constructors materialize CPU storage.
Array inputs and single-state inputs
reuse compatible storage by default. The batch-to-batch constructor retains its
historical `copy=true` default. Explicit `copy=true` guarantees independent
storage; `copy=false` permits reuse but conversions can still allocate.
`storage(batch)` exposes the mutable backing matrix.

Columns are independent samples of the same qubit count. A one-column batch
remains a batch; constructors never squeeze it into a `StateVector`. Empty
batches and zero-qubit states are allowed when their dimensions are explicit.
"""
struct BatchStateVector{T<:Number,A<:AbstractMatrix{T}} <: AbstractQuantumState
    data::A
    nqubits::Int
    batch_size::Int

    function BatchStateVector{T,A}(data::A, n::Int, B::Int) where {T<:Number,A<:AbstractMatrix{T}}
        dimension = _batch_dimension(n)
        Base.require_one_based_indexing(data)
        B >= 0 || throw(ArgumentError("batch size must be nonnegative"))
        size(data) == (dimension, B) || throw(DimensionMismatch("batch shape must equal (2^n, B)"))
        return new{T,A}(data, n, B)
    end
end

_batch_dimension(n::Int) = _state_dimension(n)

function BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int, B::Int;
                              copy::Bool=false, preserve_storage::Bool=false) where {T<:Number}
    dimension = _batch_dimension(n)
    Base.require_one_based_indexing(data)
    B >= 0 || throw(ArgumentError("batch size must be nonnegative"))
    size(data) == (dimension, B) || throw(DimensionMismatch("batch shape must equal (2^n, B)"))
    converted = _state_storage(data, T; copy=copy, preserve_storage=preserve_storage)
    return BatchStateVector{T,typeof(converted)}(converted, n, B)
end

BatchStateVector(data::AbstractMatrix{T}, n::Int, B::Int; kwargs...) where {T<:Number} =
    BatchStateVector{T}(data, n, B; kwargs...)
BatchStateVector(data::AbstractMatrix{T}, n::Int; kwargs...) where {T<:Number} =
    BatchStateVector{T}(data, n, size(data, 2); kwargs...)
BatchStateVector(data::AbstractMatrix{T}; kwargs...) where {T<:Number} =
    BatchStateVector{T}(data, _nqubits(data), size(data, 2); kwargs...)
BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int; kwargs...) where {T<:Number} =
    BatchStateVector{T}(data, n, size(data, 2); kwargs...)
BatchStateVector{T}(data::AbstractMatrix{<:Number}; kwargs...) where {T<:Number} =
    BatchStateVector{T}(data, _nqubits(data), size(data, 2); kwargs...)

function BatchStateVector{T}(nqubits::Int, batch_size::Int) where {T <: Number}
    dimension = _batch_dimension(nqubits)
    batch_size >= 0 || throw(ArgumentError("batch size must be nonnegative"))
    data = zeros(T, dimension, batch_size)
    data[1, :] .= one(T)
    return BatchStateVector{T}(data, nqubits, batch_size)
end

BatchStateVector(::Type{T}, nqubits::Int, batch_size::Int) where {T<:Number} = BatchStateVector{T}(nqubits, batch_size)
BatchStateVector(nqubits::Int, batch_size::Int) = BatchStateVector(ComplexF64, nqubits, batch_size)

# Copy constructor
BatchStateVector(x::BatchStateVector; copy::Bool=true) = BatchStateVector(x.data, x.nqubits, x.batch_size; copy=copy, preserve_storage=true)
BatchStateVector{T}(x::BatchStateVector; copy::Bool=true) where {T<:Number} =
    BatchStateVector{T}(x.data, x.nqubits, x.batch_size; copy=copy, preserve_storage=true)

# Basic accessors
storage(x::BatchStateVector) = x.data
QuantumCircuits.nqubits(x::BatchStateVector) = x.nqubits
batch_size(x::BatchStateVector) = x.batch_size

Base.eltype(::Type{<:BatchStateVector{T}}) where T = T
Base.eltype(x::BatchStateVector) = eltype(typeof(x))

Base.getindex(x::BatchStateVector, i::Int, j::Int) = getindex(storage(x), i, j)
Base.setindex!(x::BatchStateVector, v, i::Int, j::Int) = setindex!(storage(x), v, i, j)

# Convert between types
Base.convert(::Type{BatchStateVector{T}}, x::BatchStateVector) where {T<:Number} =
    BatchStateVector{T}(storage(x), nqubits(x), batch_size(x); preserve_storage=true)

Base.copy(x::BatchStateVector) = BatchStateVector(x; copy=true)

# Convert from StateVector to BatchStateVector (single state batch)
function BatchStateVector(sv::StateVector{T}; copy::Bool=false) where {T <: Number}
    data = reshape(storage(sv), length(storage(sv)), 1)
    return BatchStateVector(data, nqubits(sv), 1; copy=copy, preserve_storage=true)
end

"""
    StateVector(batch::BatchStateVector, i; copy=true)

Extract a state with independent vector storage. The extracted sample remains independent even with `copy=false`. Its owned
storage is allocated from the batch array family.
"""
function StateVector(batch::BatchStateVector, i::Int; copy::Bool=true)
    1 <= i <= batch_size(batch) || throw(BoundsError(batch, (:, i)))
    data = reshape(view(storage(batch), :, i), size(storage(batch), 1))
    return StateVector(_copy_state_storage_as(data, eltype(batch)), nqubits(batch); preserve_storage=true)
end

# Convert a vector of StateVectors to BatchStateVector
function BatchStateVector(vec::AbstractVector{<:StateVector}; copy::Bool=false)
    isempty(vec) && throw(ArgumentError("an empty state list needs explicit qubit and scalar dimensions"))
    Base.require_one_based_indexing(vec)
    nq = nqubits(vec[1])
    bs = length(vec)
    for sv in vec
        nqubits(sv) == nq || throw(DimensionMismatch("all samples must have the same qubit count"))
    end
    T = foldl(promote_type, (eltype(sv) for sv in vec))
    data = _state_similar(storage(first(vec)), T, (2^nq, bs))
    for i in 1:bs
        copyto!(view(data, :, i), storage(vec[i]))
    end
    return BatchStateVector(data, nq, bs; preserve_storage=true)
end

# Helper function to compute nqubits from matrix rows
function _nqubits(m::AbstractMatrix)
    Base.require_one_based_indexing(m)
    dimension = size(m, 1)
    ispow2(dimension) || throw(ArgumentError("the batch row count must be a positive power of two"))
    return trailing_zeros(dimension)
end

# Comparison
Base.isapprox(x::BatchStateVector, y::BatchStateVector; kwargs...) =
    size(x.data) == size(y.data) && isapprox(x.data, y.data; kwargs...)

Base.:(==)(x::BatchStateVector, y::BatchStateVector) =
    x.nqubits == y.nqubits && x.batch_size == y.batch_size && x.data == y.data

# Basic arithmetic operations
Base.:+(x::BatchStateVector, y::BatchStateVector) =
    (_check_batch_pair(x, y); BatchStateVector(_state_broadcast(+, storage(x), storage(y)), nqubits(x), batch_size(x); preserve_storage=true))

Base.:-(x::BatchStateVector, y::BatchStateVector) =
    (_check_batch_pair(x, y); BatchStateVector(_state_broadcast(-, storage(x), storage(y)), nqubits(x), batch_size(x); preserve_storage=true))

Base.:*(x::BatchStateVector, y::Number) =
    BatchStateVector(_state_broadcast(*, storage(x), y), nqubits(x), batch_size(x); preserve_storage=true)

Base.:*(x::Number, y::BatchStateVector) = y * x

Base.:/(x::BatchStateVector, y::Number) =
    BatchStateVector(_state_broadcast(/, storage(x), y), nqubits(x), batch_size(x); preserve_storage=true)

# Matrix multiplication (applies same matrix to each state in batch)
Base.:*(m::AbstractMatrix, x::BatchStateVector) = apply(backend(x), m, x)

function _check_batch_pair(x::BatchStateVector, y::BatchStateVector)
    size(storage(x)) == size(storage(y)) ||
        throw(DimensionMismatch("batch registers and sample counts must match"))
    return nothing
end

# Linear algebra operations
LinearAlgebra.norm(x::BatchStateVector) = [norm(view(storage(x), :, i)) for i in 1:batch_size(x)]

function LinearAlgebra.normalize!(x::BatchStateVector)
    _require_cpu_storage(x, normalize!)
    norms = norm(x)
    all(value -> isfinite(value) && value > 0, norms) ||
        throw(ArgumentError("every sample must have finite, nonzero norm"))
    for i in 1:batch_size(x)
        col = view(storage(x), :, i)
        col ./= norms[i]
    end
    return x
end

LinearAlgebra.normalize(x::BatchStateVector) = normalize!(copy(x))

# Dot product between two batches (element-wise)
function LinearAlgebra.dot(x::BatchStateVector, y::BatchStateVector)
    _check_batch_pair(x, y)
    return [dot(view(storage(x), :, i), view(storage(y), :, i)) for i in 1:batch_size(x)]
end

# Dot product with weight vector m (element-wise)
function LinearAlgebra.dot(x::BatchStateVector, m::AbstractVector, y::BatchStateVector)
    _check_batch_pair(x, y)
    length(m) == batch_size(x) || throw(DimensionMismatch("one weight is required per sample"))
    Base.require_one_based_indexing(m)
    return [dot(view(storage(x), :, i), m[i], view(storage(y), :, i)) for i in 1:batch_size(x)]
end

# Fidelity for each pair
function fidelity(x::BatchStateVector, y::BatchStateVector)
    _check_batch_pair(x, y)
    return abs2.(dot(x, y))
end

# Distance functions for batch
function distance2(x::BatchStateVector, y::BatchStateVector)
    _check_batch_pair(x, y)
    dots_xx = dot(x, x)
    dots_yy = dot(y, y)
    dots_xy = dot(x, y)
    return abs.(real.(dots_xx) .+ real.(dots_yy) .- 2 .* real.(dots_xy))
end

function distance(x::BatchStateVector, y::BatchStateVector)
    return sqrt.(distance2(x, y))
end

# Encoding functions for batch initialization

"""
    batch_onehot_encoding(::Type{T}, n::Int, batch_size::Int) where {T <: Number}
Create a batch of zero states |0...0⟩ with `n` qubits and `batch_size` states.
"""
batch_onehot_encoding(::Type{T}, n::Int, batch_size::Int) where {T <: Number} =
    BatchStateVector(T, n, batch_size)

batch_onehot_encoding(n::Int, batch_size::Int) = batch_onehot_encoding(ComplexF64, n, batch_size)

"""
    batch_onehot_encoding(::Type{T}, indices::Vector{Vector{Int}}) where {T <: Number}
Create a batch of computational basis states specified by `indices`.
Each element of `indices` is a binary vector representing the basis state.
"""
function batch_onehot_encoding(::Type{T}, indices::Vector{Vector{Int}}) where {T <: Number}
    isempty(indices) && throw(ArgumentError("an empty basis list needs explicit qubit and batch dimensions"))
    n = length(indices[1])
    bs = length(indices)
    all(bits -> length(bits) == n, indices) || throw(DimensionMismatch("all basis samples must have the same qubit count"))
    all(_is_valid_indices, indices) || throw(ArgumentError("basis entries must be zero or one"))
    data = zeros(T, 2^n, bs)
    for (i, idx) in enumerate(indices)
        pos = isempty(idx) ? 1 : _sub2ind(idx) + 1
        data[pos, i] = one(T)
    end
    return BatchStateVector(data, n, bs)
end

batch_onehot_encoding(indices::Vector{Vector{Int}}) = batch_onehot_encoding(ComplexF64, indices)

"""
    batch_qubit_encoding(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T <: Number}
Create a batch of product states using qubit encoding.
Each column of `inputs` is a vector of parameters for one state.
"""
function batch_qubit_encoding(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T <: Number}
    Base.require_one_based_indexing(inputs)
    all(isfinite, inputs) || throw(ArgumentError("encoding parameters must be finite"))
    n, bs = size(inputs)
    batch = BatchStateVector(T, n, bs)
    n == 0 && return batch
    for i in 1:bs
        sv = qubit_encoding(T, inputs[:, i])
        batch.data[:, i] = storage(sv)
    end
    return batch
end

batch_qubit_encoding(inputs::AbstractMatrix{<:Real}) = batch_qubit_encoding(ComplexF64, inputs)

"""
    batch_amplitude_encoding(::Type{T}, inputs::AbstractMatrix{<:Number}; nqubits::Int) where {T<:Number}
Create a batch of amplitude encoded states.
Each column of `inputs` is a vector to encode as a quantum state.
The default qubit count is the smallest register that holds all input rows.
"""
function batch_amplitude_encoding(::Type{T}, inputs::AbstractMatrix{<:Number}; nqubits::Int=_batch_amplitude_qubits(inputs)) where {T<:Number}
    d, bs = size(inputs)
    dimension = _batch_dimension(nqubits)
    Base.require_one_based_indexing(inputs)
    0 < d <= dimension || throw(DimensionMismatch("amplitude rows must fit the target Hilbert space"))
    data = zeros(T, dimension, bs)
    for i in 1:bs
        v = view(inputs, :, i)
        vn = norm(v)
        isfinite(vn) && vn > 0 || throw(ArgumentError("each input column must have finite, nonzero norm"))
        if !(vn ≈ 1.)
            println("input vector is not normalized, it will be renormalized as a quantum state.")
        end
        for j in 1:d
            data[j, i] = v[j] / vn
        end
    end
    return BatchStateVector(data, nqubits, bs)
end

function _batch_amplitude_qubits(inputs::AbstractMatrix)
    rows = size(inputs, 1)
    rows > 0 || throw(ArgumentError("amplitude input must have at least one row"))
    return rows == 1 ? 0 : ndigits(rows - 1; base=2)
end

batch_amplitude_encoding(inputs::AbstractMatrix{<:Number}; kwargs...) =
    batch_amplitude_encoding(ComplexF64, inputs; kwargs...)

# Reset functions

function reset!(x::BatchStateVector)
    _require_cpu_storage(x, reset!)
    fill!(storage(x), zero(eltype(x)))
    storage(x)[1, :] .= one(eltype(x))
    return x
end

function reset_onehot!(x::BatchStateVector, indices::Vector{Vector{Int}})
    _require_cpu_storage(x, reset_onehot!)
    batch_size(x) == length(indices) || throw(DimensionMismatch("one basis input is required per sample"))
    all(bits -> length(bits) == nqubits(x), indices) || throw(DimensionMismatch("basis inputs must match the register"))
    all(_is_valid_indices, indices) || throw(ArgumentError("basis entries must be zero or one"))
    fill!(storage(x), zero(eltype(x)))
    for (i, idx) in enumerate(indices)
        pos = isempty(idx) ? 1 : _sub2ind(idx) + 1
        storage(x)[pos, i] = one(eltype(x))
    end
    return x
end

function reset_qubit!(x::BatchStateVector, inputs::AbstractMatrix{<:Real})
    _require_cpu_storage(x, reset_qubit!)
    size(inputs) == (nqubits(x), batch_size(x)) || throw(DimensionMismatch("encoding shape must match the batch"))
    Base.require_one_based_indexing(inputs)
    all(isfinite, inputs) || throw(ArgumentError("encoding parameters must be finite"))
    nqubits(x) == 0 && (storage(x) .= one(eltype(x)); return x)
    angles = Base.mightalias(inputs, storage(x)) ? copy(inputs) : inputs
    for i in 1:batch_size(x)
        sv = qubit_encoding(eltype(x), angles[:, i])
        x.data[:, i] = storage(sv)
    end
    return x
end

# Amplitude access

function amplitude(batch::BatchStateVector, idx::AbstractVector{Int}, i::Int; scaling::Real=√2)
    _require_cpu_storage(batch, amplitude)
    1 <= i <= batch_size(batch) || throw(BoundsError(batch, (:, i)))
    length(idx) == nqubits(batch) || throw(DimensionMismatch("basis input must match the register"))
    _is_valid_indices(idx) || throw(ArgumentError("basis entries must be zero or one"))
    position = isempty(idx) ? 1 : _sub2ind(idx) + 1
    return scaling^nqubits(batch) * storage(batch)[position, i]
end

amplitudes(batch::BatchStateVector) = storage(batch)

# Random batch generation

function rand_batch(rng::Random.AbstractRNG, ::Type{T}, n::Int, batch_size::Int) where {T <: Number}
    dimension = _batch_dimension(n)
    batch_size >= 0 || throw(ArgumentError("batch size must be nonnegative"))
    data = randn(rng, T, dimension, batch_size)
    return normalize!(BatchStateVector(data, n, batch_size))
end

rand_batch(::Type{T}, n::Int, batch_size::Int) where {T<:Number} = rand_batch(Random.default_rng(), T, n, batch_size)
rand_batch(rng::Random.AbstractRNG, n::Int, batch_size::Int) = rand_batch(rng, ComplexF64, n, batch_size)
rand_batch(n::Int, batch_size::Int) = rand_batch(ComplexF64, n, batch_size)

# Permutation (reuses existing permute function from QuantumCircuits)
function QuantumCircuits.permute(x::BatchStateVector, newindex::Vector{Int})
    _require_cpu_storage(x, QuantumCircuits.permute)
    n = nqubits(x)
    sort(newindex) == collect(1:n) ||
        throw(ArgumentError("qubit order must be a permutation of 1:$n"))
    L = 2^n
    bs = batch_size(x)
    data = storage(x)
    new_data = similar(data)
    for i in 1:bs
        col = view(data, :, i)
        new_col = reshape(QuantumCircuits.permute(reshape(col, ntuple(_->2, n)), newindex), L)
        new_data[:, i] = new_col
    end
    return BatchStateVector(new_data, n, bs; preserve_storage=true)
end

# Aliases for consistency with StateVector API

"""
    batch_qstate(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T <: Number}
Alias for `batch_qubit_encoding`. Create a batch of product states using qubit encoding.
Each column of `inputs` is a vector of parameters for one state.
"""
batch_qstate(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T <: Number} = batch_qubit_encoding(T, inputs)

"""
    batch_qstate(inputs::AbstractMatrix{<:Real})
Alias for `batch_qubit_encoding`. Create a batch of product states using qubit encoding.
"""
batch_qstate(inputs::AbstractMatrix{<:Real}) = batch_qubit_encoding(inputs)

"""
    batch_qstate(::Type{T}, n::Int, batch_size::Int) where {T <: Number}
Create a batch of zero states with `n` qubits and `batch_size` states.
"""
batch_qstate(::Type{T}, n::Int, batch_size::Int) where {T <: Number} = batch_onehot_encoding(T, n, batch_size)

"""
    batch_qstate(n::Int, batch_size::Int)
Create a batch of zero states with `n` qubits and `batch_size` states.
"""
batch_qstate(n::Int, batch_size::Int) = batch_onehot_encoding(n, batch_size)
