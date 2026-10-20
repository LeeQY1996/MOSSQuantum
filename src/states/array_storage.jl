# State wrappers validate metadata without inspecting or transferring payloads.
function _state_dimension(n::Int)
    0 <= n < 8sizeof(Int) - 1 ||
        throw(ArgumentError("qubit count must be nonnegative and its state dimension must fit Int"))
    return 1 << n
end

function _state_density_dimension(n::Int)
    dimension = _state_dimension(n)
    n <= div(8sizeof(Int) - 2, 2) ||
        throw(ArgumentError("the vectorized density dimension must fit Int"))
    return dimension
end

# An owned copy of a view allocates from its parent's family rather than
# materializing a foreign array through Base's generic view implementation.
_state_storage_template(data::AbstractArray) = data
_state_storage_template(data::SubArray) = _state_storage_template(parent(data))
_state_storage_template(data::Base.ReshapedArray) = _state_storage_template(parent(data))
_state_storage_template(data::PermutedDimsArray) = _state_storage_template(parent(data))

function _state_similar(data::AbstractArray, ::Type{T}, dims::Tuple) where {T<:Number}
    Base.require_one_based_indexing(data)
    template = _state_storage_template(data)
    result = similar(template, T, dims)
    result isa AbstractArray{T} && size(result) == dims ||
        throw(ArgumentError("similar must return numerical storage of the requested type and shape"))
    Base.require_one_based_indexing(result)
    result isa Array && !(template isa Array) &&
        throw(ArgumentError("$(typeof(template)) must implement same-family similar storage; implicit Array materialization is unsupported"))
    return result
end

function _copy_state_storage_as(data::AbstractArray, ::Type{T}) where {T<:Number}
    result = _state_similar(data, T, size(data))
    Base.mightalias(result, data) &&
        throw(ArgumentError("similar must allocate independent state storage"))
    copyto!(result, data)
    return result
end

function _state_storage(data::AbstractArray{<:Number,N}, ::Type{T};
                        copy::Bool=false, preserve_storage::Bool=false) where {N,T<:Number}
    Base.require_one_based_indexing(data)
    if preserve_storage
        return !copy && eltype(data) === T ? data : _copy_state_storage_as(data, T)
    end
    converted = convert(Array{T,N}, data)
    return copy ? Base.copy(converted) : converted
end

function _state_broadcast(f, data::AbstractArray, arguments...)
    for argument in arguments
        argument isa AbstractArray && size(argument) != size(data) &&
            throw(DimensionMismatch("state arithmetic requires matching dimensions"))
    end
    _state_storage_template(data) isa Array && return f.(data, arguments...)
    T = Base.promote_op(f, eltype(data),
        map(argument -> argument isa AbstractArray ? eltype(argument) : typeof(argument), arguments)...)
    T <: Number || throw(ArgumentError("state arithmetic must produce numerical storage"))
    result = _state_similar(data, T, size(data))
    result .= f.(data, arguments...)
    return result
end
