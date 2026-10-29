# Preparation reads only host instruction metadata. Complete circuits are
# validated before the first state write, including nested instructions.
struct PreparedGate{T,N}
    matrix::Matrix{T}
    positions::NTuple{N,Int}
end

_host_storage(::AbstractArray) = false
_host_storage(::Union{Array,StaticArray}) = true
_host_storage(data::Union{SubArray,Base.ReshapedArray,PermutedDimsArray,Adjoint,Transpose}) =
    _host_storage(parent(data))

function _checked_positions(positions, n; max_arity=5)
    result = Tuple(Int(p) for p in positions)
    1 <= length(result) <= max_arity || throw(ArgumentError("CUDA local gates support 1–$max_arity qubits"))
    length(unique(result)) == length(result) || throw(ArgumentError("gate positions must be distinct"))
    all(p -> 1 <= p <= n, result) || throw(ArgumentError("gate position outside the state register"))
    return result
end

function _prepare_matrix(matrix::AbstractMatrix, positions, ::Type{T}, n;
                         preserve_precision=true) where T
    T <: Scalar || throw(ArgumentError("CUDA execution needs Float32/Float64 or their complex types"))
    pos = _checked_positions(positions, n)
    dimension = 1 << length(pos)
    size(matrix) == (dimension, dimension) || throw(DimensionMismatch("gate matrix does not match its positions"))
    _host_storage(matrix) || throw(ArgumentError("local gate matrices must use supported host storage"))
    eltype(matrix) <: Union{Integer,AbstractFloat,Complex{<:Union{Integer,AbstractFloat}}} ||
        throw(ArgumentError("unsupported gate matrix scalar domain"))
    all(isfinite, matrix) || throw(ArgumentError("gate matrix must be finite"))
    R = preserve_precision ? (T <: Real && eltype(matrix) <: Complex ? Complex{T} : T) :
        promote_type(T, eltype(matrix))
    R <: Scalar || throw(ArgumentError("observable promotion is unsupported on CUDA"))
    converted = Matrix{R}(matrix)
    all(isfinite, converted) || throw(ArgumentError("gate matrix overflows the selected precision"))
    return PreparedGate(converted, pos)
end

function _prepare_gate(gate::MOSSQuantum.Gate, ::Type{T}, n; kwargs...) where T
    pos = _checked_positions(MOSSQuantum.positions(gate), n)
    length(pos) == MOSSQuantum.nqubits(gate) || throw(DimensionMismatch("gate arity does not match positions"))
    return _prepare_matrix(MOSSQuantum.mat(gate), pos, T, n; kwargs...)
end

function _prepare_circuit!(plan, circuit::MOSSQuantum.QCircuit, ::Type{T}, n) where T
    current_type = T
    for instruction in circuit
        if instruction isa MOSSQuantum.QCircuit
            current_type = _prepare_circuit!(plan, instruction, current_type, n)
        elseif instruction isa MOSSQuantum.Gate
            prepared = _prepare_gate(instruction, current_type, n)
            push!(plan, prepared)
            current_type = eltype(prepared.matrix)
        else
            throw(ArgumentError("CUDA circuits currently support gates only"))
        end
    end
    return current_type
end

function _readout_positions(qubits, n)
    indices = Int[qubits...]
    length(unique(indices)) == length(indices) || throw(ArgumentError("readout qubits must be distinct"))
    all(q -> 1 <= q <= n, indices) || throw(ArgumentError("readout qubit out of range"))
    return indices
end

function _normalize_readout!(values, ::Type{T}) where T
    tolerance = max(sqrt(eps(Float64)), sqrt(Float64(eps(typeof(real(zero(T)))))))
    all(isfinite, values) || throw(ArgumentError("probabilities must be finite"))
    total = sum(values)
    isapprox(total, 1; atol=tolerance, rtol=tolerance) ||
        throw(ArgumentError("state probabilities must sum to one; normalize the state first (sum = $total)"))
    values ./= total
    return values
end
