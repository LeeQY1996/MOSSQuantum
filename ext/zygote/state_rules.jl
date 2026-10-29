


@adjoint storage(x::Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix}) = storage(x), z -> (z,)

# These operations preserve the numerical state. Keep the incoming cotangent
# representation rather than exposing the wrapper's data/nqubits fields to AD.
@adjoint StateVector(x::StateVector; copy::Bool=false) = StateVector(x; copy=copy), z -> (z,)
@adjoint DensityMatrix(x::DensityMatrix; copy::Bool=false) = DensityMatrix(x; copy=copy), z -> (z,)
@adjoint Base.copy(x::Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix}) = Base.copy(x), z -> (z,)
@adjoint BatchStateVector(x::BatchStateVector; copy::Bool=true) = BatchStateVector(x; copy=copy), z -> (z,)

# State pullbacks use state wrappers internally; an array constructor must
# return an array cotangent, with the original shape and real/complex domain.
function _check_cpu_array_cotangent(data, values)
    if MOSSQuantum._state_storage_template(data) isa Array
        values isa AbstractArray && MOSSQuantum._cpu_storage_supported(values) ||
            throw(ArgumentError("a CPU array cotangent requires supported host storage"))
    end
    return nothing
end

function _array_cotangent(data, z)
    isnothing(z) && return nothing
    values = z isa Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix} ? storage(z) : z
    _check_cpu_array_cotangent(data, values)
    return Zygote.ProjectTo(data)(reshape(values, size(data)))
end

_state_cotangent(x::StateVector, z) = isnothing(z) ? nothing :
    StateVector(_array_cotangent(storage(x), z), nqubits(x); preserve_storage=true)
_state_cotangent(x::DensityMatrix, z) = isnothing(z) ? nothing :
    DensityMatrix(_array_cotangent(storage(x), z), nqubits(x); preserve_storage=true)
_state_cotangent(x::BatchStateVector, z) = isnothing(z) ? nothing :
    BatchStateVector(_array_cotangent(storage(x), z), nqubits(x); preserve_storage=true)
_state_cotangent(x::BatchDensityMatrix, z) = isnothing(z) ? nothing :
    BatchDensityMatrix(_array_cotangent(storage(x), z), nqubits(x); preserve_storage=true)

@adjoint StateVector{T}(x::StateVector; copy::Bool=false) where {T<:Number} =
    StateVector{T}(x; copy=copy), z -> (_state_cotangent(x, z),)
@adjoint DensityMatrix{T}(x::DensityMatrix; copy::Bool=false) where {T<:Number} =
    DensityMatrix{T}(x; copy=copy), z -> (_state_cotangent(x, z),)
@adjoint BatchStateVector{T}(x::BatchStateVector; copy::Bool=true) where {T<:Number} =
    BatchStateVector{T}(x; copy=copy), z -> (_state_cotangent(x, z),)

@adjoint BatchStateVector(data::AbstractMatrix{<:Number}, n::Int, count::Int; copy::Bool=false, preserve_storage::Bool=false) = BatchStateVector(data, n, count; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchStateVector(data::AbstractMatrix{<:Number}, n::Int; copy::Bool=false, preserve_storage::Bool=false) = BatchStateVector(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchStateVector(data::AbstractMatrix{<:Number}; copy::Bool=false, preserve_storage::Bool=false) = BatchStateVector(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int, count::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchStateVector{T}(data, n, count; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}, n::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchStateVector{T}(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchStateVector{T}(data::AbstractMatrix{<:Number}; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchStateVector{T}(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)

@adjoint BatchStateVector(::Type{T}, n::Int, count::Int) where {T<:Number} = BatchStateVector(T, n, count), z -> (nothing, nothing, nothing)
@adjoint BatchStateVector{T}(n::Int, count::Int) where {T<:Number} = BatchStateVector{T}(n, count), z -> (nothing, nothing)
@adjoint BatchStateVector(n::Int, count::Int) = BatchStateVector(n, count), z -> (nothing, nothing)

@adjoint BatchStateVector(x::StateVector; copy::Bool=false) = begin
    result = BatchStateVector(x; copy=copy)
    return result, z -> (_state_cotangent(x, z),)
end

function _zero_state_cotangent(data, ::Type{T}) where {T<:Number}
    gradient = MOSSQuantum._state_similar(data, T, size(data))
    return fill!(gradient, zero(T))
end

@adjoint StateVector(x::BatchStateVector, column::Int; copy::Bool=true) = begin
    result = StateVector(x, column; copy=copy)
    return result, z -> begin
        isnothing(z) && return nothing, nothing
        values = z isa StateVector ? storage(z) : z
        _check_cpu_array_cotangent(storage(x), values)
        gradient = _zero_state_cotangent(storage(x), eltype(values))
        gradient[:, column] .= values
        return BatchStateVector(Zygote.ProjectTo(storage(x))(gradient), nqubits(x); preserve_storage=true), nothing
    end
end

@adjoint Base.convert(::Type{BatchStateVector{T}}, x::BatchStateVector) where {T<:Number} = begin
    result = convert(BatchStateVector{T}, x)
    return result, z -> (nothing, _state_cotangent(x, z))
end

@adjoint StateVector(data::AbstractVector{<:Number}, n::Int; copy::Bool=false, preserve_storage::Bool=false) = StateVector(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint StateVector(data::AbstractVector{<:Number}; copy::Bool=false, preserve_storage::Bool=false) = StateVector(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)
@adjoint DensityMatrix(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}, n::Int; copy::Bool=false, preserve_storage::Bool=false) = DensityMatrix(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint DensityMatrix(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}; copy::Bool=false, preserve_storage::Bool=false) = DensityMatrix(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)

@adjoint StateVector{T}(data::AbstractVector{<:Number}, n::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = StateVector{T}(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint StateVector{T}(data::AbstractVector{<:Number}; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = StateVector{T}(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)
@adjoint DensityMatrix{T}(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}, n::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = DensityMatrix{T}(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint DensityMatrix{T}(data::Union{AbstractVector{<:Number}, AbstractMatrix{<:Number}}; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = DensityMatrix{T}(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)

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


@adjoint BatchDensityMatrix(data::AbstractArray{<:Number,3}, n::Int, count::Int; copy::Bool=false, preserve_storage::Bool=false) = BatchDensityMatrix(data, n, count; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchDensityMatrix(data::AbstractArray{<:Number,3}, n::Int; copy::Bool=false, preserve_storage::Bool=false) = BatchDensityMatrix(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchDensityMatrix(data::AbstractArray{<:Number,3}; copy::Bool=false, preserve_storage::Bool=false) = BatchDensityMatrix(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)
@adjoint BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}, n::Int, count::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchDensityMatrix{T}(data, n, count; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing, nothing)
@adjoint BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}, n::Int; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchDensityMatrix{T}(data, n; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z), nothing)
@adjoint BatchDensityMatrix{T}(data::AbstractArray{<:Number,3}; copy::Bool=false, preserve_storage::Bool=false) where {T<:Number} = BatchDensityMatrix{T}(data; copy=copy, preserve_storage=preserve_storage), z -> (_array_cotangent(data, z),)

@adjoint BatchDensityMatrix(::Type{T}, n::Int, count::Int) where {T<:Number} = BatchDensityMatrix(T, n, count), z -> (nothing, nothing, nothing)
@adjoint BatchDensityMatrix{T}(n::Int, count::Int) where {T<:Number} = BatchDensityMatrix{T}(n, count), z -> (nothing, nothing)
@adjoint BatchDensityMatrix(n::Int, count::Int) = BatchDensityMatrix(n, count), z -> (nothing, nothing)
@adjoint BatchDensityMatrix(x::BatchDensityMatrix; copy::Bool=true) = BatchDensityMatrix(x; copy=copy), z -> (z,)

@adjoint Base.convert(::Type{BatchDensityMatrix{T}}, x::BatchDensityMatrix) where {T<:Number} = begin
    result = convert(BatchDensityMatrix{T}, x)
    return result, z -> (nothing, _state_cotangent(x, z))
end

@adjoint DensityMatrix(x::BatchDensityMatrix, column::Int; copy::Bool=true) = begin
    result = DensityMatrix(x, column; copy=copy)
    return result, z -> begin
        isnothing(z) && return nothing, nothing
        values = z isa DensityMatrix ? storage(z) : z
        _check_cpu_array_cotangent(storage(x), values)
        values = reshape(values, size(storage(result)))
        gradient = _zero_state_cotangent(storage(x), eltype(values))
        gradient[:, :, column] .= values
        return BatchDensityMatrix(Zygote.ProjectTo(storage(x))(gradient), nqubits(x); preserve_storage=true), nothing
    end
end

@adjoint BatchDensityMatrix(x::BatchStateVector; copy::Bool=false) = begin
    result = BatchDensityMatrix(x; copy=copy)
    back = _batch_density_pure_back(result, x)
    return result, z -> (back(z),)
end

@adjoint BatchDensityMatrix(x::DensityMatrix; copy::Bool=false) = begin
    result = BatchDensityMatrix(x; copy=copy)
    return result, z -> (_state_cotangent(x, z),)
end

@adjoint BatchDensityMatrix{T}(x::BatchDensityMatrix; copy::Bool=true) where {T<:Number} = begin
    result = BatchDensityMatrix{T}(x; copy=copy)
    return result, z -> (_state_cotangent(x, z),)
end
@adjoint BatchDensityMatrix{T}(x::DensityMatrix; copy::Bool=false) where {T<:Number} = begin
    result = BatchDensityMatrix{T}(x; copy=copy)
    return result, z -> (_state_cotangent(x, z),)
end

function _batch_density_pure_back(result, initial::BatchStateVector)
    MOSSQuantum._require_cpu_storage(initial, BatchDensityMatrix)
    MOSSQuantum._require_cpu_storage(result, BatchDensityMatrix)
    saved = Base.copy(initial)
    project = Zygote.ProjectTo(storage(initial))
    function back(z)
        isnothing(z) && return nothing
        values = z isa BatchDensityMatrix ? storage(z) : z
        size(values) == size(storage(result)) || throw(DimensionMismatch("density cotangent must match its batch"))
        _check_cpu_array_cotangent(storage(result), values)
        T = promote_type(eltype(saved), eltype(values))
        gradient = zeros(T, size(storage(saved)))
        for column in 1:batch_size(saved)
            delta = view(values, :, :, column)
            gradient[:, column] .= (delta + delta') * view(storage(saved), :, column)
        end
        return BatchStateVector(project(gradient), nqubits(saved); preserve_storage=true)
    end
    return back
end
@adjoint BatchDensityMatrix{T}(x::BatchStateVector; copy::Bool=false) where {T<:Number} = begin
    result = BatchDensityMatrix{T}(x; copy=copy)
    back = _batch_density_pure_back(result, x)
    return result, z -> (back(z),)
end
@adjoint BatchDensityMatrix(x::StateVector; copy::Bool=false) = begin
    result = BatchDensityMatrix(x; copy=copy)
    back = _batch_density_pure_back(result, BatchStateVector(x; copy=true))
    return result, z -> begin
        gradient = back(z)
        return (isnothing(gradient) ? nothing : StateVector(gradient, 1),)
    end
end
@adjoint BatchDensityMatrix{T}(x::StateVector; copy::Bool=false) where {T<:Number} = begin
    result = BatchDensityMatrix{T}(x; copy=copy)
    back = _batch_density_pure_back(result, BatchStateVector(x; copy=true))
    return result, z -> begin
        gradient = back(z)
        return (isnothing(gradient) ? nothing : StateVector(gradient, 1),)
    end
end

@adjoint BatchDensityMatrix(states::AbstractVector{<:DensityMatrix}; copy::Bool=false) = begin
    result = BatchDensityMatrix(states; copy=copy)
    projects = [Zygote.ProjectTo(storage(state)) for state in states]
    registers = nqubits.(states)
    return result, z -> begin
        isnothing(z) && return (nothing,)
        values = z isa BatchDensityMatrix ? storage(z) : z
        size(values) == size(storage(result)) || throw(DimensionMismatch("density cotangent must match its batch"))
        for state in states
            _check_cpu_array_cotangent(storage(state), values)
        end
        return ([DensityMatrix(projects[b](MOSSQuantum._copy_state_storage_as(view(values, :, :, b), eltype(values))), registers[b]; preserve_storage=true)
            for b in eachindex(projects)],)
    end
end
