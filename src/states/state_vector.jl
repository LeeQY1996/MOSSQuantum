"""
    StateVector(data; copy=false, preserve_storage=false)
    StateVector(state::StateVector; copy=false)

Construct a dense pure state. Array inputs use compatible CPU storage by default.
`preserve_storage=true` retains the input array family; execution support is
queried separately through its backend.
Use `copy=true` to obtain independent storage, or `Base.copy(state)` to copy an
existing state. `copy=false` permits reuse; element-type or layout conversion can
still allocate. `storage(state)` exposes the mutable backing array.
"""
struct StateVector{T<:Number,A<:AbstractVector{T}} <: AbstractQuantumState
    data::A
    nqubits::Int

    function StateVector{T,A}(data::A, n::Int) where {T<:Number,A<:AbstractVector{T}}
        dimension = _state_dimension(n)
        Base.require_one_based_indexing(data)
        length(data) == dimension || throw(DimensionMismatch("state length must equal 2^n"))
        return new{T,A}(data, n)
    end
end

function StateVector{T}(data::AbstractVector{<:Number}, n::Int;
                         copy::Bool=false, preserve_storage::Bool=false) where {T<:Number}
    dimension = _state_dimension(n)
    Base.require_one_based_indexing(data)
    length(data) == dimension || throw(DimensionMismatch("state length must equal 2^n"))
    converted = _state_storage(data, T; copy=copy, preserve_storage=preserve_storage)
    return StateVector{T,typeof(converted)}(converted, n)
end

StateVector(data::AbstractVector{T}, n::Int; kwargs...) where {T<:Number} = StateVector{T}(data, n; kwargs...)
StateVector{T}(data::AbstractVector{<:Number}; kwargs...) where {T<:Number} = StateVector{T}(data, _nqubits(data); kwargs...)
StateVector(data::AbstractVector{T}; kwargs...) where {T<:Number} = StateVector{T}(data; kwargs...)
function StateVector{T}(nqubits::Int) where {T<:Number} 
    v = zeros(T, _state_dimension(nqubits))
    v[1] = 1
    return StateVector{T}(v, nqubits)
end
StateVector(::Type{T}, nqubits::Int) where {T<:Number} = StateVector{T}(nqubits)
StateVector(nqubits::Int) = StateVector(ComplexF64, nqubits)
StateVector(x::StateVector; copy::Bool=false) = StateVector(x.data, nqubits(x); copy=copy, preserve_storage=true)
StateVector{T}(x::StateVector; copy::Bool=false) where {T<:Number} =
    StateVector{T}(x.data, nqubits(x); copy=copy, preserve_storage=true)

storage(x::StateVector) = x.data
QuantumCircuits.nqubits(x::StateVector) = x.nqubits

Base.eltype(::Type{<:StateVector{T}}) where T = T
Base.eltype(x::StateVector) = eltype(typeof(x))
Base.getindex(x::StateVector, j::Int) = getindex(storage(x), j)
Base.setindex!(x::StateVector, v, j::Int) = setindex!(storage(x), v, j)

Base.convert(::Type{StateVector{T}}, x::StateVector) where {T<:Number} = StateVector{T}(storage(x), nqubits(x); preserve_storage=true)
Base.copy(x::StateVector) = StateVector(x; copy=true)

Base.cat(v::StateVector) = v
function Base.cat(v::StateVector...)
    for state in v
        _require_cpu_storage(state, cat)
    end
    a, b = _qcat_util(storage.(v)...)
    return StateVector(kron(a, b); preserve_storage=true)
end

Base.isapprox(x::StateVector, y::StateVector; kwargs...) = isapprox(storage(x), storage(y); kwargs...)
Base.:(==)(x::StateVector, y::StateVector) = storage(x) == storage(y)


Base.:+(x::StateVector, y::StateVector) = StateVector(_state_broadcast(+, storage(x), storage(y)), nqubits(x); preserve_storage=true)
Base.:-(x::StateVector, y::StateVector) = StateVector(_state_broadcast(-, storage(x), storage(y)), nqubits(x); preserve_storage=true)
Base.:*(x::StateVector, y::Number) = StateVector(_state_broadcast(*, storage(x), y), nqubits(x); preserve_storage=true)
Base.:*(x::Number, y::StateVector) = y * x
Base.:/(x::StateVector, y::Number) = StateVector(_state_broadcast(/, storage(x), y), nqubits(x); preserve_storage=true)
Base.:*(m::AbstractMatrix, x::StateVector) = apply(backend(x), m, x)


LinearAlgebra.norm(x::StateVector) = norm(storage(x))
LinearAlgebra.dot(x::StateVector, y::StateVector) = dot(storage(x), storage(y))
LinearAlgebra.dot(x::StateVector, m::AbstractVector, y::StateVector) = dot(storage(x), m, storage(y))
LinearAlgebra.normalize!(x::StateVector) = (normalize!(storage(x)); x)
LinearAlgebra.normalize(x::StateVector) = normalize!(copy(x))

"""
    fidelity(x, y)

Return the squared Uhlmann fidelity of normalized quantum states. For density
matrices this is `(tr(sqrt(sqrt(x) * y * sqrt(x))))^2`; for pure states it is
`abs2(dot(x, y))`, and for a pure state and a density matrix it is `⟨ψ|ρ|ψ⟩`.
Converting a pure state to a density matrix preserves the result.
"""
fidelity(x::StateVector, y::StateVector) = abs2(dot(x, y))
distance2(x::StateVector, y::StateVector) = _distance2(x, y)
distance(x::StateVector, y::StateVector) = _distance(x, y)


# encoding
onehot_encoding(::Type{T}, n::Int) where {T <: Number} = StateVector(onehot(T, 2^n, 1), n)
onehot_encoding(n::Int) = onehot_encoding(ComplexF64, n)
onehot_encoding(::Type{T}, i::AbstractVector{Int}) where {T <: Number} = StateVector(onehot(T, 2^(length(i)), _sub2ind(i)+1), length(i))
onehot_encoding(i::AbstractVector{Int})= onehot_encoding(ComplexF64, i)

function onehot(::Type{T}, L::Int, pos::Int) where T
    r = zeros(T, L)
    r[pos] = one(T)
    return r
end


"""
    kernal_mapping(s::Real) = [cos(s*pi/2), sin(s*pi/2)]
    This maps 0 -> [1, 0] (|0>), and 1 -> [0, 1] (|1>)
"""
kernal_mapping(s::Real) = [cos(s*pi/2), sin(s*pi/2)]


"""
    qstate(::Type{T}, thetas::AbstractVector{<:Real}) where {T <: Number}
Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas]\n
Example: qstate(Complex{Float64}, [0.5, 0.7])
"""
function qubit_encoding(::Type{T}, i::AbstractVector{<:Real}) where {T <: Number}
    isempty(i) && throw("empty input.")
    v = [convert(Vector{T}, item) for item in kernal_mapping.(i)]
    (length(v) == 1) && return StateVector{T}(v[1])
    a, b = _qcat_util(v...)
    return StateVector(kron(a, b))
end  
qubit_encoding(mpsstr::AbstractVector{<:Real}) = qubit_encoding(ComplexF64, mpsstr)

"""
    qstate(::Type{T}, thetas::AbstractVector{<:Real}) where {T <: Number}
Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas.
Example: qstate(Complex{Float64}, [0.5, 0.7])
"""
qstate(::Type{T}, thetas::AbstractVector{<:Real}) where {T <: Number} = qubit_encoding(T, thetas)

"""
    qstate(thetas::AbstractVector{<:Real})
Return a product quantum state of [[cos(pi*theta/2), sin(pi*theta/2)]] for theta in thetas.
"""
qstate(thetas::AbstractVector{<:Real}) = qubit_encoding(ComplexF64, thetas)

"""
    qstate(::Type{T}, n::Int) where {T <: Number}
Return a zero quantum state with n qubits.
"""
qstate(::Type{T}, n::Int) where {T <: Number} = StateVector(T, n)

"""
    qstate(n::Int)
Return a zero quantum state with n qubits.
"""
qstate(n::Int) = StateVector(ComplexF64, n)

function amplitude_encoding(::Type{T}, v::AbstractVector{<:Number}; nqubits::Int=ceil(Int, log2(length(v)))) where {T<:Number}
    vn = norm(v)
    (vn ≈ 1.) || println("input vector is not normalized, it will be renormalized as a quantum state.")
    vv = zeros(T, 2^nqubits)
    for i in 1:length(v)
        vv[i] = v[i] / vn
    end
    return StateVector(vv, nqubits)
end
amplitude_encoding(v::AbstractVector; kwargs...) = amplitude_encoding(ComplexF64, v; kwargs...)

function reset!(x::StateVector)
    _require_cpu_storage(x, reset!)
    fill!(storage(x), zero(eltype(x)))
    x[1] = one(eltype(x))
    return x
end
function reset_onehot!(x::StateVector, i::AbstractVector{Int})
    _require_cpu_storage(x, reset_onehot!)
    @assert nqubits(x) == length(i)
    pos = _sub2ind(i) + 1
    fill!(storage(x), zero(eltype(x)))
    x[pos] = one(eltype(x))
    return x
end

function reset_qubit!(x::StateVector, i::AbstractVector{<:Real})
    _require_cpu_storage(x, reset_qubit!)
    @assert nqubits(x) == length(i)
    if length(i) == 1
        copyto!(storage(x), kernal_mapping(i[1]))
        return x
    end
    a, b = _qcat_util(kernal_mapping.(i)...)
    m = length(a)
    n = length(b)
    xs = storage(x)
    for j in 1:m
        n_start = (j-1) * n + 1
        n_end = j * n
        tmp = a[j]
        @. xs[n_start:n_end] = tmp * b
    end
    return x
end

"""
    amplitude(s::StateVector, i::AbstractVector{Int}; scaling::Real=√2)
Return the amplitude of a quantum state at a specific computational basis state.

The `scaling` parameter is used to scale the amplitude by a factor of `scaling^nqubits(s)`.
"""
function amplitude(s::StateVector, i::AbstractVector{Int}; scaling::Real=√2)
    _require_cpu_storage(s, amplitude)
    @assert length(i)==nqubits(s)
    idx = _sub2ind(i) + 1
    return scaling==1 ? s[idx] : s[idx] * scaling^(nqubits(s))
end
amplitudes(s::StateVector) = storage(s)

function rand_state(rng::Random.AbstractRNG, ::Type{T}, n::Int) where {T <: Number}
    (n >= 1) || error("number of qubits must be positive.")
    v = randn(rng, T, 2^n)
    v ./= norm(v)
    return StateVector(v, n)
end
rand_state(::Type{T}, n::Int) where {T<:Number} = rand_state(Random.default_rng(), T, n)
rand_state(rng::Random.AbstractRNG, n::Int) = rand_state(rng, ComplexF64, n)
rand_state(n::Int) = rand_state(ComplexF64, n)

function QuantumCircuits.permute(x::StateVector, newindex::Vector{Int})
    _require_cpu_storage(x, QuantumCircuits.permute)
    n = nqubits(x)
    L = length(storage(x))
    return StateVector(reshape(permute(reshape(storage(x), ntuple(i->2,n)), newindex), L), n; preserve_storage=true)
end


function _sub2ind(v::AbstractVector{Int})
    @assert _is_valid_indices(v)
    isempty(v) && error("input index is empty.")
    L = length(v)
    r = v[1]
    for i in 2:L
        r |= v[i] << (i-1)
    end
    return r
end

function _qcat_util(vr::Union{AbstractVector, AbstractMatrix}...)
    v = reverse(vr)
    L = length(v)
    # println("$(typeof(v)), $L")
    (L >= 2) || error("something wrong.")
    Lh = div(L, 2)
    a = v[1]
    for i in 2:Lh
        a = kron(a, v[i])
    end
    b = v[Lh + 1]
    for i in Lh+2 : L
        b = kron(b, v[i])
    end
    return a, b
end

function _is_valid_indices(i::AbstractVector{Int})
    for s in i
        (s == 0 || s == 1) || return false 
    end   
    return true
end

function _nqubits(s::AbstractVector)
    Base.require_one_based_indexing(s)
    dimension = length(s)
    ispow2(dimension) || throw(ArgumentError("state dimension must be a positive power of two"))
    return trailing_zeros(dimension)
end



# function reset!(x::AbstractVector, i::AbstractVector{<:AbstractFloat})
#     (nqubits(x) == length(i)) || error("input basis mismatch with number of qubits.")
#     mpsstr = kernal_mapping.(i)
#     for (pos, item) in enumerate(Iterators.product(mpsstr...))
#         x[pos] = prod(item)
#     end
#     return x
# end


# function qrandn(::Type{T}, n::Int) where {T <: Number}
# 	(n >= 1) || error("number of qubits must be positive.")
# 	v = randn(T, 2^n)
# 	v ./= norm(v)
# 	return v
# end

# qrandn(n::Int) = qrandn(Complex{Float64}, n)
