"""
    BatchStateVector(data; copy=false)
    BatchStateVector(state::BatchStateVector; copy=true)
    BatchStateVector(state::StateVector; copy=false)

Construct a batch of dense pure states. Array inputs and single-state inputs
reuse compatible storage by default. The batch-to-batch constructor retains its
historical `copy=true` default. Explicit `copy=true` guarantees independent
storage; `copy=false` permits reuse but conversions can still allocate.
`storage(batch)` exposes the mutable backing matrix.
"""
struct BatchStateVector{T <: Number} <: AbstractQuantumState
    data::Matrix{T}
    nqubits::Int
    batch_size::Int

    function BatchStateVector{T}(data::AbstractMatrix{<:Number}, nqubits::Int, batch_size::Int; copy::Bool=false) where {T <: Number}
        @assert size(data, 1) == 2^nqubits
        @assert size(data, 2) == batch_size
        converted = convert(Matrix{T}, data)
        new{T}(copy ? Base.copy(converted) : converted, nqubits, batch_size)
    end
end

# Outer constructors
BatchStateVector(data::AbstractMatrix{T}, nqubits::Int, batch_size::Int; copy::Bool=false) where {T <: Number} =
    BatchStateVector{T}(data, nqubits, batch_size; copy=copy)

BatchStateVector(data::AbstractMatrix{T}, nqubits::Int; copy::Bool=false) where {T <: Number} =
    BatchStateVector{T}(data, nqubits, size(data, 2); copy=copy)

BatchStateVector(data::AbstractMatrix{T}; copy::Bool=false) where {T <: Number} =
    BatchStateVector{T}(data, _nqubits(data), size(data, 2); copy=copy)

function BatchStateVector{T}(nqubits::Int, batch_size::Int) where {T <: Number}
    data = zeros(T, 2^nqubits, batch_size)
    data[1, :] .= one(T)
    return BatchStateVector{T}(data, nqubits, batch_size)
end

BatchStateVector(::Type{T}, nqubits::Int, batch_size::Int) where {T<:Number} = BatchStateVector{T}(nqubits, batch_size)
BatchStateVector(nqubits::Int, batch_size::Int) = BatchStateVector(ComplexF64, nqubits, batch_size)

# Copy constructor
BatchStateVector(x::BatchStateVector; copy::Bool=true) = BatchStateVector(x.data, x.nqubits, x.batch_size; copy=copy)

# Basic accessors
storage(x::BatchStateVector) = x.data
QuantumCircuits.nqubits(x::BatchStateVector) = x.nqubits
batch_size(x::BatchStateVector) = x.batch_size

Base.eltype(::Type{BatchStateVector{T}}) where T = T
Base.eltype(x::BatchStateVector) = eltype(typeof(x))

Base.getindex(x::BatchStateVector, i::Int, j::Int) = getindex(storage(x), i, j)
Base.setindex!(x::BatchStateVector, v, i::Int, j::Int) = setindex!(storage(x), v, i, j)

# Convert between types
Base.convert(::Type{BatchStateVector{T}}, x::BatchStateVector) where {T<:Number} =
    BatchStateVector(convert(Matrix{T}, storage(x)), nqubits(x), batch_size(x))

Base.copy(x::BatchStateVector) = BatchStateVector(copy(storage(x)), nqubits(x), batch_size(x))

# Convert from StateVector to BatchStateVector (single state batch)
function BatchStateVector(sv::StateVector{T}; copy::Bool=false) where {T <: Number}
    data = reshape(storage(sv), :, 1)
    return BatchStateVector(data, nqubits(sv), 1; copy=copy)
end

"""
    StateVector(batch::BatchStateVector, i; copy=true)

Extract a state with independent vector storage. The column view must be
materialized for the current `StateVector` representation, including when
`copy=false`; that option permits reuse but does not guarantee it.
"""
function StateVector(batch::BatchStateVector, i::Int; copy::Bool=true)
    @assert 1 <= i <= batch_size(batch)
    data = reshape(view(storage(batch), :, i), :)
    return StateVector(data, nqubits(batch))
end

# Convert a vector of StateVectors to BatchStateVector
function BatchStateVector(vec::AbstractVector{<:StateVector}; copy::Bool=false)
    isempty(vec) && error("Vector of StateVectors is empty")
    nq = nqubits(vec[1])
    bs = length(vec)
    for sv in vec
        @assert nqubits(sv) == nq "All StateVectors must have same number of qubits"
    end
    data = Matrix{eltype(vec[1])}(undef, 2^nq, bs)
    for i in 1:bs
        data[:, i] = storage(vec[i])
    end
    return BatchStateVector(data, nq, bs)
end

# Helper function to compute nqubits from matrix rows
function _nqubits(m::AbstractMatrix)
    n = round(Int, log2(size(m, 1)))
    (2^n == size(m, 1)) || error("Number of rows is not a power of 2")
    return n
end

# Comparison
Base.isapprox(x::BatchStateVector, y::BatchStateVector; kwargs...) =
    size(x.data) == size(y.data) && isapprox(x.data, y.data; kwargs...)

Base.:(==)(x::BatchStateVector, y::BatchStateVector) =
    x.nqubits == y.nqubits && x.batch_size == y.batch_size && x.data == y.data

# Basic arithmetic operations
Base.:+(x::BatchStateVector, y::BatchStateVector) =
    BatchStateVector(storage(x) + storage(y), nqubits(x), batch_size(x))

Base.:-(x::BatchStateVector, y::BatchStateVector) =
    BatchStateVector(storage(x) - storage(y), nqubits(x), batch_size(x))

Base.:*(x::BatchStateVector, y::Number) =
    BatchStateVector(storage(x) * y, nqubits(x), batch_size(x))

Base.:*(x::Number, y::BatchStateVector) = y * x

Base.:/(x::BatchStateVector, y::Number) =
    BatchStateVector(storage(x) / y, nqubits(x), batch_size(x))

# Matrix multiplication (applies same matrix to each state in batch)
Base.:*(m::AbstractMatrix, x::BatchStateVector) =
    BatchStateVector(m * storage(x), nqubits(x), batch_size(x))

# Linear algebra operations
LinearAlgebra.norm(x::BatchStateVector) = [norm(view(storage(x), :, i)) for i in 1:batch_size(x)]

function LinearAlgebra.normalize!(x::BatchStateVector)
    for i in 1:batch_size(x)
        col = view(storage(x), :, i)
        normalize!(col)
    end
    return x
end

LinearAlgebra.normalize(x::BatchStateVector) = normalize!(copy(x))

# Dot product between two batches (element-wise)
function LinearAlgebra.dot(x::BatchStateVector, y::BatchStateVector)
    @assert batch_size(x) == batch_size(y) "Batch sizes must match"
    return [dot(view(storage(x), :, i), view(storage(y), :, i)) for i in 1:batch_size(x)]
end

# Dot product with weight vector m (element-wise)
function LinearAlgebra.dot(x::BatchStateVector, m::AbstractVector, y::BatchStateVector)
    @assert batch_size(x) == batch_size(y) == length(m) "Dimensions must match"
    return [dot(view(storage(x), :, i), m[i], view(storage(y), :, i)) for i in 1:batch_size(x)]
end

# Fidelity for each pair
function fidelity(x::BatchStateVector, y::BatchStateVector)
    @assert batch_size(x) == batch_size(y) "Batch sizes must match"
    return abs2.(dot(x, y))
end

# Distance functions for batch
function distance2(x::BatchStateVector, y::BatchStateVector)
    @assert batch_size(x) == batch_size(y) "Batch sizes must match"
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
    isempty(indices) && error("indices is empty")
    n = length(indices[1])
    bs = length(indices)
    data = zeros(T, 2^n, bs)
    for (i, idx) in enumerate(indices)
        @assert length(idx) == n "All indices must have same length"
        pos = _sub2ind(idx) + 1
        data[pos, i] = one(T)
    end
    return BatchStateVector(data, n, bs)
end

batch_onehot_encoding(indices::Vector{Vector{Int}}) = batch_onehot_encoding(ComplexF64, indices)

"""
    batch_qubit_encoding(::Type{T}, inputs::Matrix{<:Real}) where {T <: Number}
Create a batch of product states using qubit encoding.
Each column of `inputs` is a vector of parameters for one state.
"""
function batch_qubit_encoding(::Type{T}, inputs::Matrix{<:Real}) where {T <: Number}
    n, bs = size(inputs)
    batch = BatchStateVector(T, n, bs)
    for i in 1:bs
        sv = qubit_encoding(T, inputs[:, i])
        batch.data[:, i] = storage(sv)
    end
    return batch
end

batch_qubit_encoding(inputs::Matrix{<:Real}) = batch_qubit_encoding(ComplexF64, inputs)

"""
    batch_amplitude_encoding(::Type{T}, inputs::Matrix{<:Number}; nqubits::Int=ceil(Int, log2(size(inputs,1)))) where {T<:Number}
Create a batch of amplitude encoded states.
Each column of `inputs` is a vector to encode as a quantum state.
"""
function batch_amplitude_encoding(::Type{T}, inputs::Matrix{<:Number}; nqubits::Int=ceil(Int, log2(size(inputs,1)))) where {T<:Number}
    d, bs = size(inputs)
    nqubits >= 0 || throw(ArgumentError("number of qubits must be nonnegative"))
    d <= 2^nqubits || throw(DimensionMismatch("input has more amplitudes than the target Hilbert space"))
    data = zeros(T, 2^nqubits, bs)
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

batch_amplitude_encoding(inputs::Matrix{<:Number}; kwargs...) =
    batch_amplitude_encoding(ComplexF64, inputs; kwargs...)

# Reset functions

function reset!(x::BatchStateVector)
    fill!(storage(x), zero(eltype(x)))
    storage(x)[1, :] .= one(eltype(x))
    return x
end

function reset_onehot!(x::BatchStateVector, indices::Vector{Vector{Int}})
    @assert nqubits(x) == length(indices[1])
    @assert batch_size(x) == length(indices)
    fill!(storage(x), zero(eltype(x)))
    for (i, idx) in enumerate(indices)
        pos = _sub2ind(idx) + 1
        storage(x)[pos, i] = one(eltype(x))
    end
    return x
end

function reset_qubit!(x::BatchStateVector, inputs::Matrix{<:Real})
    @assert nqubits(x) == size(inputs, 1)
    @assert batch_size(x) == size(inputs, 2)
    for i in 1:batch_size(x)
        sv = qubit_encoding(eltype(x), inputs[:, i])
        x.data[:, i] = storage(sv)
    end
    return x
end

# Amplitude access

function amplitude(batch::BatchStateVector, idx::AbstractVector{Int}, i::Int; scaling::Real=√2)
    @assert 1 <= i <= batch_size(batch)
    sv = StateVector(batch, i)
    return amplitude(sv, idx; scaling=scaling)
end

amplitudes(batch::BatchStateVector) = storage(batch)

# Random batch generation

function rand_batch(rng::Random.AbstractRNG, ::Type{T}, n::Int, batch_size::Int) where {T <: Number}
    (n >= 1) || error("number of qubits must be positive.")
    data = randn(rng, T, 2^n, batch_size)
    for i in 1:batch_size
        col = view(data, :, i)
        col ./= norm(col)
    end
    return BatchStateVector(data, n, batch_size)
end

rand_batch(::Type{T}, n::Int, batch_size::Int) where {T<:Number} = rand_batch(Random.default_rng(), T, n, batch_size)
rand_batch(rng::Random.AbstractRNG, n::Int, batch_size::Int) = rand_batch(rng, ComplexF64, n, batch_size)
rand_batch(n::Int, batch_size::Int) = rand_batch(ComplexF64, n, batch_size)

# Permutation (reuses existing permute function from QuantumCircuits)
function QuantumCircuits.permute(x::BatchStateVector, newindex::Vector{Int})
    n = nqubits(x)
    L = 2^n
    bs = batch_size(x)
    data = storage(x)
    new_data = similar(data)
    for i in 1:bs
        col = view(data, :, i)
        new_col = reshape(QuantumCircuits.permute(reshape(col, ntuple(_->2, n)), newindex), L)
        new_data[:, i] = new_col
    end
    return BatchStateVector(new_data, n, bs)
end

# Aliases for consistency with StateVector API

"""
    batch_qstate(::Type{T}, inputs::Matrix{<:Real}) where {T <: Number}
Alias for `batch_qubit_encoding`. Create a batch of product states using qubit encoding.
Each column of `inputs` is a vector of parameters for one state.
"""
batch_qstate(::Type{T}, inputs::Matrix{<:Real}) where {T <: Number} = batch_qubit_encoding(T, inputs)

"""
    batch_qstate(inputs::Matrix{<:Real})
Alias for `batch_qubit_encoding`. Create a batch of product states using qubit encoding.
"""
batch_qstate(inputs::Matrix{<:Real}) = batch_qubit_encoding(inputs)

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
