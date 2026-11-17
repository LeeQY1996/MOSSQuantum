const QOP_DATA_TYPE = Dict{Tuple{Vararg{Int}}, Vector{Tuple{Vector{AbstractMatrix}, Number}}}
const QOP_DATA_VALUE_TYPE = Vector{Tuple{Vector{AbstractMatrix}, Number}}

"""
    QubitsOperator(terms::QubitsTerm...)
    QubitsOperator(value::Number)

A sum of tensor-product terms. The empty sum is the zero operator; a numeric
argument is a scalar multiple of the identity. Arithmetic does not mutate its
operands. Use `simplify` to combine identical terms and remove zero coefficients.
"""
struct QubitsOperator <: QuantumOperation
    data::QOP_DATA_TYPE
end

QubitsOperator() = QubitsOperator(QOP_DATA_TYPE())
QubitsOperator(value::Number) = QubitsOperator(QubitsTerm(value))

function QubitsOperator(first::QubitsTerm, others::QubitsTerm...)
    result = QubitsOperator()
    add!(result, first)
    for term in others
        add!(result, term)
    end
    return result
end

function Base.copy(x::QubitsOperator)
    result = QubitsOperator()
    for (sites, terms) in x.data, (operators, value) in terms
        add!(result, QubitsTerm(sites, operators, value))
    end
    return result
end

Base.keys(x::QubitsOperator) = keys(x.data)
Base.isempty(x::QubitsOperator) = all(isempty, values(x.data))
Base.iszero(x::QubitsOperator) = isempty(simplify(x))
Base.zero(::Type{QubitsOperator}) = QubitsOperator()
Base.zero(x::QubitsOperator) = QubitsOperator()
Base.one(::Type{QubitsOperator}) = QubitsOperator(1)
Base.one(x::QubitsOperator) = QubitsOperator(one(eltype(x)))
nqubits(x::QubitsOperator) = get_largest_pos(x)

function add!(x::QubitsOperator, term::QubitsTerm)
    sites = Tuple(positions(term))
    terms = get!(x.data, sites, QOP_DATA_VALUE_TYPE())
    push!(terms, (AbstractMatrix[copy(matrix) for matrix in oplist(term)], coeff(term)))
    return x
end

Base.:+(x::QubitsTerm, y::QubitsTerm) = QubitsOperator(x, y)
Base.:+(x::QubitsOperator, y::QubitsTerm) = add!(copy(x), y)
Base.:+(x::QubitsTerm, y::QubitsOperator) = y + x

function Base.:+(x::QubitsOperator, y::QubitsOperator)
    result = copy(x)
    for (sites, terms) in y.data, (operators, value) in terms
        add!(result, QubitsTerm(sites, operators, value))
    end
    return result
end

const QubitObservable = Union{QubitsTerm,QubitsOperator}
Base.:+(x::QubitObservable, y::Number) = x + QubitsTerm(y)
Base.:+(x::Number, y::QubitObservable) = QubitsTerm(x) + y
Base.:-(x::QubitObservable, y::QubitObservable) = x + (-y)
Base.:-(x::QubitObservable, y::Number) = x + (-y)
Base.:-(x::Number, y::QubitObservable) = x + (-y)
Base.:-(x::QubitsOperator) = -one(eltype(x)) * x
Base.:+(x::QubitsOperator) = copy(x)

function Base.:*(x::QubitsOperator, y::Number)
    result = QubitsOperator()
    for (sites, terms) in x.data, (operators, value) in terms
        add!(result, QubitsTerm(sites, operators, value * y))
    end
    return result
end
Base.:*(x::Number, y::QubitsOperator) = y * x
Base.:/(x::QubitsOperator, y::Number) = x * inv(y)

"""Multiply tensor factors in operator order, including shared positions."""
function Base.:*(x::QubitsTerm, y::QubitsTerm)
    operators = Dict{Int,AbstractMatrix}(site => matrix for (site, matrix) in zip(positions(x), oplist(x)))
    for (site, matrix) in zip(positions(y), oplist(y))
        operators[site] = haskey(operators, site) ? operators[site] * matrix : matrix
    end
    return simplify(QubitsTerm(operators; coeff=coeff(x) * coeff(y)))
end

function Base.:*(x::QubitsOperator, y::QubitsTerm)
    result = QubitsOperator()
    for (sites, terms) in x.data, (operators, value) in terms
        add!(result, QubitsTerm(sites, operators, value) * y)
    end
    return simplify(result)
end

function Base.:*(x::QubitsTerm, y::QubitsOperator)
    result = QubitsOperator()
    for (sites, terms) in y.data, (operators, value) in terms
        add!(result, x * QubitsTerm(sites, operators, value))
    end
    return simplify(result)
end

function Base.:*(x::QubitsOperator, y::QubitsOperator)
    result = QubitsOperator()
    for (left_sites, left_terms) in x.data, (left_operators, left_value) in left_terms
        left = QubitsTerm(left_sites, left_operators, left_value)
        for (right_sites, right_terms) in y.data, (right_operators, right_value) in right_terms
            right = QubitsTerm(right_sites, right_operators, right_value)
            add!(result, left * right)
        end
    end
    return simplify(result)
end

function Base.adjoint(x::QubitsOperator)
    result = QubitsOperator()
    for (sites, terms) in x.data, (operators, value) in terms
        add!(result, adjoint(QubitsTerm(sites, operators, value)))
    end
    return result
end

function _check_simplification_tolerance(atol::Real)
    isfinite(atol) && atol >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))
    return nothing
end

# Normalize exact scalar multiples of I/X/Y/Z only. Other local matrices keep
# their entries; simplification never expands a general matrix in the Pauli basis.
function _canonical_local_operator(matrix::AbstractMatrix)
    a, b, c, d = matrix[1, 1], matrix[1, 2], matrix[2, 1], matrix[2, 2]
    if iszero(b) && iszero(c)
        a == d && return a, nothing
        a == -d && return a, Matrix{eltype(matrix)}(Z)
    elseif iszero(a) && iszero(d)
        b == c && return b, Matrix{eltype(matrix)}(X)
        if b == -c
            phase = -im * c
            return phase, Matrix{typeof(im * one(eltype(matrix)))}(Y)
        end
    end
    return one(eltype(matrix)), copy(matrix)
end

"""
    simplify(term::QubitsTerm; atol=0)
    simplify(operator::QubitsOperator; atol=0)

Normalize exact local scalar/Pauli factors, remove identity factors, combine
identical tensor-product terms, and discard coefficients with `abs(c) <= atol`.
The default removes exact zeros only. For sums the cutoff is applied **after**
combining terms. Arbitrary 2×2 factors are retained without Pauli expansion or
approximate matrix matching. The input and its matrices remain independent of
the result. Unlike Trotter's internal grouping, this operation does not absorb
single-site terms into larger supports.
"""
function simplify(term::QubitsTerm; atol::Real=0)
    _check_simplification_tolerance(atol)
    iszero(term) && return zero(term)
    sites = Int[]
    operators = AbstractMatrix[]
    value = coeff(term)
    for (site, matrix) in zip(positions(term), oplist(term))
        scalar, canonical = _canonical_local_operator(matrix)
        value *= scalar
        if !isnothing(canonical)
            push!(sites, site)
            push!(operators, canonical)
        end
    end
    abs(value) <= atol && return QubitsTerm(zero(value))
    return QubitsTerm(sites, operators, value)
end

# Immutable value keys avoid depending on mutable matrix identity or signed zero.
_operator_key_number(value) = (iszero(real(value)) ? 0 : real(value), iszero(imag(value)) ? 0 : imag(value))
_term_key(term::QubitsTerm) = (Tuple(positions(term)), Tuple(Tuple(_operator_key_number(value) for value in matrix) for matrix in oplist(term)))

function simplify(operator::QubitsOperator; atol::Real=0)
    _check_simplification_tolerance(atol)
    terms = QubitsTerm[]
    indices = Dict{Any,Int}()
    coefficients = Number[]
    for sites in sort!(collect(keys(operator.data)))
        for (matrices, value) in operator.data[sites]
            term = simplify(QubitsTerm(sites, matrices, value))
            iszero(term) && continue
            key = _term_key(term)
            index = get(indices, key, 0)
            if iszero(index)
                push!(terms, term)
                push!(coefficients, coeff(term))
                indices[key] = length(terms)
            else
                coefficients[index] += coeff(term)
            end
        end
    end
    result = QubitsOperator()
    for (term, value) in zip(terms, coefficients)
        abs(value) <= atol && continue
        add!(result, QubitsTerm(positions(term), oplist(term), value))
    end
    return result
end

function Base.eltype(x::QubitsOperator)
    T = Int
    for (_, terms) in x.data, (operators, value) in terms
        T = promote_type(T, typeof(value))
        for matrix in operators
            T = promote_type(T, eltype(matrix))
        end
    end
    return T
end

function _operator_dimension(n::Int)
    0 <= n < 8sizeof(Int) - 1 || throw(ArgumentError("invalid number of operator qubits"))
    return 1 << n
end

"""Return a sparse matrix on `n` qubits, including zero and scalar operators."""
function matrix(n::Int, x::QubitsOperator)
    dimension = _operator_dimension(n)
    get_largest_pos(x) <= n || throw(ArgumentError("operator positions exceed the requested register"))
    result = spzeros(eltype(x), dimension, dimension)
    for (sites, terms) in x.data, (operators, value) in terms
        result += _generateprodham(n, sites_ops_to_dict(sites, operators)) * value
    end
    return result
end

matrix(x::QubitsOperator) = matrix(get_largest_pos(x), x)
matrix(n::Int, x::QubitsTerm) = _generateprodham(n, sites_ops_to_dict(positions(x), oplist(x))) * coeff(x)
matrix(x::QubitsTerm) = matrix(get_largest_pos(x), x)

function _generateprodham(n::Int, operators::AbstractDict{Int,<:AbstractMatrix})
    _operator_dimension(n)
    all(site -> 1 <= site <= n, keys(operators)) ||
        throw(ArgumentError("operator positions exceed the requested register"))
    T = foldl(promote_type, (eltype(matrix) for matrix in values(operators)); init=Int)
    result = sparse(reshape(T[one(T)], 1, 1))
    identity = sparse(Matrix{T}(I, 2, 2))
    for site in n:-1:1
        local_operator = get(operators, site, identity)
        size(local_operator) == (2, 2) || throw(DimensionMismatch("local operators must be 2×2 matrices"))
        result = kron(result, sparse(local_operator))
    end
    return result
end

function get_largest_pos(x::QubitsOperator)
    result = 0
    for sites in keys(x.data)
        isempty(sites) || (result = max(result, maximum(sites)))
    end
    return result
end

sites_ops_to_dict(sites, operators) = Dict{Int,AbstractMatrix}(site => matrix for (site, matrix) in zip(sites, operators))
_index_map(x::NTuple{N,Int}, mapping::AbstractDict) where N = ntuple(j -> mapping[x[j]], N)

change_positions(x::QubitsTerm, mapping::AbstractDict) =
    QubitsTerm(Int[mapping[site] for site in positions(x)], oplist(x), coeff(x))

function change_positions(x::QubitsOperator, mapping::AbstractDict)
    result = QubitsOperator()
    for (sites, terms) in x.data, (operators, value) in terms
        add!(result, change_positions(QubitsTerm(sites, operators, value), mapping))
    end
    return result
end

# Preserve the historical local-block grouping as a Trotter optimization,
# separate from the public algebraic meaning of simplify.
function absorb_one_bodies(ham::QubitsOperator)
    result = QubitsOperator()
    keys_in_order = sort!(collect(keys(ham.data)))
    for sites in keys_in_order
        target = sites
        if length(sites) == 1
            candidate = findfirst(key -> length(key) > 1 && only(sites) in key, keys_in_order)
            isnothing(candidate) || (target = keys_in_order[candidate])
        end
        for (operators, value) in ham.data[sites]
            if target == sites
                add!(result, QubitsTerm(sites, operators, value))
            else
                matrices = AbstractMatrix[site == only(sites) ? only(operators) : I₂ for site in target]
                add!(result, QubitsTerm(target, matrices, value))
            end
        end
    end
    return result
end
