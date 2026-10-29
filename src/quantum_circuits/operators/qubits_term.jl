"""
    QubitsTerm(position => operator, ...; coeff=1)
    QubitsTerm(value::Number)

A coefficient times a tensor product of local 2×2 matrices. Positions are
positive, distinct, and sorted internally; qubit 1 is the least significant
tensor factor. Inputs are copied, including their local matrices.

An empty support denotes the identity, so `QubitsTerm(2)` represents `2I` on
any register. `isempty(term)` describes support, not whether the term is zero.
"""
struct QubitsTerm <: QuantumOperation
    positions::Vector{Int}
    op::Vector{<:AbstractMatrix}
    coeff::Number

    function QubitsTerm(pos::Vector{Int}, matrices::Vector, value::Number)
        length(pos) == length(matrices) ||
            throw(DimensionMismatch("each operator position needs one local matrix"))
        all(>(0), pos) || throw(ArgumentError("operator positions must be positive"))
        length(unique(pos)) == length(pos) ||
            throw(ArgumentError("operator positions must be distinct"))
        ordered_pos, ordered_matrices = _get_normal_order(pos, matrices)
        for matrix in ordered_matrices
            size(matrix) == (2, 2) || throw(DimensionMismatch("local operators must be 2×2 matrices"))
            eltype(matrix) <: Number || throw(ArgumentError("local operators must have numeric entries"))
        end
        new(ordered_pos, ordered_matrices, value)
    end
end

positions(x::QubitsTerm) = x.positions
oplist(x::QubitsTerm) = x.op
coeff(x::QubitsTerm) = x.coeff
nqubits(x::QubitsTerm) = get_largest_pos(x)
get_largest_pos(x::QubitsTerm) = isempty(x.positions) ? 0 : maximum(x.positions)

QubitsTerm(pos::Tuple, matrices::Vector, value::Number) = QubitsTerm(Int[pos...], matrices, value)
QubitsTerm(value::Number) = QubitsTerm(Int[], AbstractMatrix[], value)

function QubitsTerm(x::AbstractDict{Int}; coeff::Number=1.)
    sites, operators = dict_to_site_ops(x)
    return QubitsTerm(sites, operators, coeff)
end

# Do not construct a Dict first: it would silently discard duplicate positions.
function QubitsTerm(items::Pair{Int,<:Union{AbstractString,AbstractMatrix}}...; coeff::Number=1.)
    return QubitsTerm(Int[first(item) for item in items],
                     [last(item) for item in items], coeff)
end

Base.copy(x::QubitsTerm) = QubitsTerm(positions(x), oplist(x), coeff(x))
Base.isempty(x::QubitsTerm) = isempty(oplist(x))
Base.iszero(x::QubitsTerm) = iszero(coeff(x)) || any(iszero, oplist(x))
Base.zero(::Type{QubitsTerm}) = QubitsTerm(0)
Base.zero(x::QubitsTerm) = QubitsTerm(zero(eltype(x)))
Base.one(::Type{QubitsTerm}) = QubitsTerm(1)
Base.one(x::QubitsTerm) = QubitsTerm(one(eltype(x)))
Base.adjoint(x::QubitsTerm) = QubitsTerm(positions(x), [item' for item in oplist(x)], conj(coeff(x)))
Base.:*(x::QubitsTerm, y::Number) = QubitsTerm(positions(x), oplist(x), coeff(x) * y)
Base.:*(x::Number, y::QubitsTerm) = y * x
Base.:/(x::QubitsTerm, y::Number) = QubitsTerm(positions(x), oplist(x), coeff(x) / y)
Base.:-(x::QubitsTerm) = -one(coeff(x)) * x
Base.:+(x::QubitsTerm) = copy(x)

function Base.eltype(x::QubitsTerm)
    T = typeof(coeff(x))
    for item in oplist(x)
        T = promote_type(T, eltype(item))
    end
    return T
end

function _get_normal_order(key::Vector{Int}, operators)
    sequence = sortperm(key)
    return key[sequence], AbstractMatrix[copy(_get_op(operators[i])) for i in sequence]
end

_get_op(matrix::AbstractMatrix) = matrix
_get_op(name::AbstractString) = _op_mapping[name]

const _op_mapping = Dict("X"=>X, "Y"=>Y, "Z"=>Z, "+"=>[0. 1.; 0. 0.], "-"=>[0. 0.; 1. 0.],
    "I"=>I₂, "u"=>[1. 0.; 0. 0.], "d"=>[0. 0.; 0. 1.], "0"=>[1. 0.; 0. 0.], "1"=>[0. 0.; 0. 1.])

function dict_to_site_ops(operators::AbstractDict)
    sites = Int[]
    matrices = Any[]
    for (site, operator) in operators
        push!(sites, site)
        push!(matrices, operator)
    end
    return sites, matrices
end
