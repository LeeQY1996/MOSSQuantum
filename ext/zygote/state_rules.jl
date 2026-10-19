


@adjoint storage(x::Union{StateVector, DensityMatrix,BatchStateVector}) = storage(x), z -> (z,)

# These operations preserve the numerical state. Keep the incoming cotangent
# representation rather than exposing the wrapper's data/nqubits fields to AD.
@adjoint StateVector(x::StateVector; copy::Bool=false) = StateVector(x; copy=copy), z -> (z,)
@adjoint DensityMatrix(x::DensityMatrix; copy::Bool=false) = DensityMatrix(x; copy=copy), z -> (z,)
@adjoint Base.copy(x::Union{StateVector, DensityMatrix,BatchStateVector}) = Base.copy(x), z -> (z,)
@adjoint BatchStateVector(x::BatchStateVector; copy::Bool=true) = BatchStateVector(x; copy=copy), z -> (z,)

# State pullbacks use state wrappers internally; an array constructor must
# return an array cotangent, with the original shape and real/complex domain.
function _array_cotangent(data, z)
    isnothing(z) && return nothing
    values = z isa Union{StateVector, DensityMatrix,BatchStateVector} ? storage(z) : z
    return Zygote.ProjectTo(data)(reshape(values, size(data)))
end

@adjoint BatchStateVector(data::AbstractMatrix{<:Number}, n::Int, count::Int; copy::Bool=false) = BatchStateVector(data, n, count; copy=copy), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchStateVector(data::AbstractMatrix{<:Number}, n::Int; copy::Bool=false) = BatchStateVector(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchStateVector(data::AbstractMatrix{<:Number}; copy::Bool=false) = BatchStateVector(data; copy=copy), z -> (_array_cotangent(data, z),)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int, count::Int; copy::Bool=false) where {T<:Number} = BatchStateVector{T}(data, n, count; copy=copy), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int; copy::Bool=false) where {T<:Number} = BatchStateVector{T}(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}; copy::Bool=false) where {T<:Number} = BatchStateVector{T}(data; copy=copy), z -> (_array_cotangent(data, z),)

@adjoint BatchStateVector(::Type{T}, n::Int, count::Int) where {T<:Number} = BatchStateVector(T, n, count), z -> (nothing, nothing, nothing)
@adjoint BatchStateVector{T}(n::Int, count::Int) where {T<:Number} = BatchStateVector{T}(n, count), z -> (nothing, nothing)
@adjoint BatchStateVector(n::Int, count::Int) = BatchStateVector(n, count), z -> (nothing, nothing)

@adjoint BatchStateVector(x::StateVector; copy::Bool=false) = begin
    result = BatchStateVector(x; copy=copy)
    return result, z -> (isnothing(z) ? nothing : StateVector(_array_cotangent(storage(x), z), nqubits(x)),)
end

@adjoint StateVector(x::BatchStateVector, column::Int; copy::Bool=true) = begin
    result = StateVector(x, column; copy=copy)
    return result, z -> begin
        isnothing(z) && return nothing, nothing
        values = z isa StateVector ? storage(z) : z
        gradient = zeros(eltype(values), size(storage(x)))
        gradient[:, column] .= values
        return BatchStateVector(Zygote.ProjectTo(storage(x))(gradient), nqubits(x)), nothing
    end
end

@adjoint Base.convert(::Type{BatchStateVector{T}}, x::BatchStateVector) where {T<:Number} = begin
    result = convert(BatchStateVector{T}, x)
    return result, z -> (nothing, isnothing(z) ? nothing :
        BatchStateVector(_array_cotangent(storage(x), z), nqubits(x)))
end

@adjoint StateVector(data::AbstractVector{<:Number}, n::Int; copy::Bool=false) = StateVector(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint StateVector(data::AbstractVector{<:Number}; copy::Bool=false) = StateVector(data; copy=copy), z -> (_array_cotangent(data, z),)
@adjoint DensityMatrix(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}, n::Int; copy::Bool=false) = DensityMatrix(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint DensityMatrix(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}; copy::Bool=false) = DensityMatrix(data; copy=copy), z -> (_array_cotangent(data, z),)

@adjoint StateVector{T}(data::AbstractVector{<:Number}, n::Int; copy::Bool=false) where {T<:Number} = StateVector{T}(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint StateVector{T}(data::AbstractVector{<:Number}; copy::Bool=false) where {T<:Number} = StateVector{T}(data; copy=copy), z -> (_array_cotangent(data, z),)
@adjoint DensityMatrix{T}(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}, n::Int; copy::Bool=false) where {T<:Number} = DensityMatrix{T}(data, n; copy=copy), z -> (_array_cotangent(data, z), nothing)
@adjoint DensityMatrix{T}(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}; copy::Bool=false) where {T<:Number} = DensityMatrix{T}(data; copy=copy), z -> (_array_cotangent(data, z),)

# Zero-state initializers have only discrete/type arguments. Their internal
# array mutation must not become part of a surrounding differentiable loss.
@adjoint StateVector(::Type{T}, n::Int) where {T<:Number} = StateVector(T, n), z -> (nothing, nothing)
@adjoint DensityMatrix(::Type{T}, n::Int) where {T<:Number} = DensityMatrix(T, n), z -> (nothing, nothing)
@adjoint StateVector{T}(n::Int) where {T<:Number} = StateVector{T}(n), z -> (nothing,)
@adjoint DensityMatrix{T}(n::Int) where {T<:Number} = DensityMatrix{T}(n), z -> (nothing,)

@adjoint DensityMatrix(x::StateVector; copy::Bool=false) = begin
    y = DensityMatrix(x; copy=copy)
    return y, z -> (_density_to_state_cotangent(x, _to_sv(y, z)),)
end

# this is stupid, why should I need it
@adjoint dot(x::StateVector, y::StateVector) = Zygote.pullback(dot, storage(x), storage(y))

# #StateVectorBatch
# @adjoint dot(x::StateVectorBatch, y::StateVectorBatch) = Zygote.pullback(dot, storage(x), storage(y))

