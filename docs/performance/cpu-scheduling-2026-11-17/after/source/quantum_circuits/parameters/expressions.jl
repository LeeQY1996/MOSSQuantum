"""A named variable with an immutable identity, independent of its display name."""
struct Parameter
    id::UUID
    name::Symbol
    function Parameter(name::Union{Symbol,AbstractString})
        isempty(string(name)) && throw(ArgumentError("a parameter name must not be empty"))
        new(uuid4(RandomDevice()), Symbol(name))
    end
end
Base.:(==)(a::Parameter, b::Parameter) = a.id == b.id
Base.isequal(a::Parameter, b::Parameter) = isequal(a.id, b.id)
Base.hash(p::Parameter, seed::UInt) = hash(p.id, hash(Parameter, seed))
Base.copy(p::Parameter) = p
Base.show(io::IO, p::Parameter) = print(io, p.name)

function _finite_parameter_real(x)
    x isa Real && !(x isa Bool) && isfinite(x) ||
        throw(ArgumentError("parameter values and coefficients must be finite real numbers, excluding Bool"))
    return x
end

function _parameter_arithmetic(operation, checked_operation, a::Real, b::Real)
    if a isa Integer && b isa Integer && !(a isa BigInt) && !(b isa BigInt)
        left, right = promote(a, b)
        try
            return checked_operation(left, right)
        catch error
            error isa OverflowError || rethrow()
            throw(ArgumentError("integer parameter arithmetic overflowed; use a floating-point value or BigInt"))
        end
    end
    return operation(a, b)
end
_parameter_add(a::Real, b::Real) = _parameter_arithmetic(+, Base.Checked.checked_add, a, b)
_parameter_multiply(a::Real, b::Real) = _parameter_arithmetic(*, Base.Checked.checked_mul, a, b)

"""An immutable real affine expression `constant + sum(coefficient * parameter)`."""
struct ParameterExpr{T<:Real}
    terms::Tuple{Vararg{Pair{Parameter,T}}}
    constant::T
    function ParameterExpr(terms::Tuple, constant::Real)
        _finite_parameter_real(constant)
        for term in terms
            term isa Pair && first(term) isa Parameter || throw(ArgumentError("expression terms must pair a Parameter with a real coefficient"))
            _finite_parameter_real(last(term))
        end
        T = isempty(terms) ? typeof(constant) : promote_type(typeof(constant), map(term -> typeof(last(term)), terms)...)
        # Irrational constants need a domain with additive zero and arithmetic.
        T = typeof(zero(Int) + convert(T, constant))
        stored = Pair{Parameter,T}[]
        for term in terms
            p, coefficient = first(term), convert(T, last(term))
            j = findfirst(item -> first(item) == p, stored)
            if isnothing(j)
                push!(stored, p => coefficient)
            else
                first(stored[j]).name == p.name || throw(ArgumentError("one parameter identity has conflicting names"))
                stored[j] = p => _parameter_add(last(stored[j]), coefficient)
            end
        end
        filter!(term -> !iszero(last(term)), stored)
        all(term -> isfinite(last(term)), stored) || throw(ArgumentError("parameter coefficients overflow their numerical domain"))
        c = convert(T, constant)
        isfinite(c) || throw(ArgumentError("parameter constant overflows its numerical domain"))
        new{T}(Tuple(stored), c)
    end
end
ParameterExpr(value::Real) = ParameterExpr((), value)
ParameterExpr(p::Parameter) = ParameterExpr((p => 1,), 0)
ParameterExpr(e::ParameterExpr) = e
const _SymbolicParameter = Union{Parameter,ParameterExpr}
Base.copy(e::ParameterExpr) = e

function Base.:(==)(a::ParameterExpr, b::ParameterExpr)
    a.constant == b.constant && length(a.terms) == length(b.terms) || return false
    return all(term -> any(other -> first(term) == first(other) && last(term) == last(other), b.terms), a.terms)
end
Base.isequal(a::ParameterExpr, b::ParameterExpr) =
    isequal(a.constant, b.constant) && length(a.terms) == length(b.terms) &&
    all(term -> any(other -> isequal(first(term), first(other)) && isequal(last(term), last(other)), b.terms), a.terms)
function Base.hash(e::ParameterExpr, seed::UInt)
    isempty(e.terms) && return hash(e.constant, seed)
    length(e.terms) == 1 && iszero(e.constant) && last(only(e.terms)) == 1 && return hash(first(only(e.terms)), seed)
    unordered = foldl((h, term) -> h ⊻ hash(term), e.terms; init=zero(UInt))
    return hash((e.constant, unordered, length(e.terms)), hash(ParameterExpr, seed))
end
Base.:(==)(a::ParameterExpr, b::Real) = isempty(a.terms) && a.constant == b
Base.:(==)(a::Real, b::ParameterExpr) = b == a
Base.isequal(a::ParameterExpr, b::Real) = isempty(a.terms) && isequal(a.constant, b)
Base.isequal(a::Real, b::ParameterExpr) = isequal(b, a)
Base.:(==)(a::ParameterExpr, b::Parameter) = a == ParameterExpr(b)
Base.:(==)(a::Parameter, b::ParameterExpr) = ParameterExpr(a) == b
Base.isequal(a::ParameterExpr, b::Parameter) = isequal(a, ParameterExpr(b))
Base.isequal(a::Parameter, b::ParameterExpr) = isequal(ParameterExpr(a), b)

_parameter_magnitude(value::Real) = abs(value)
_parameter_magnitude(value::Integer) = value < 0 ? -big(value) : value

function Base.show(io::IO, e::ParameterExpr)
    isempty(e.terms) && return show(io, e.constant)
    for (j, term) in enumerate(e.terms)
        coefficient = last(term)
        j > 1 && print(io, coefficient < 0 ? " - " : " + ")
        j == 1 && coefficient < 0 && print(io, "-")
        magnitude = _parameter_magnitude(coefficient)
        magnitude == one(magnitude) || (show(io, magnitude); print(io, "*"))
        show(io, first(term))
    end
    if !iszero(e.constant)
        print(io, e.constant < 0 ? " - " : " + ")
        show(io, _parameter_magnitude(e.constant))
    end
end

function _add_parameter_expr(a::ParameterExpr, b::ParameterExpr)
    ParameterExpr((a.terms..., b.terms...), _parameter_add(a.constant, b.constant))
end
Base.:+(a::_SymbolicParameter, b::Union{_SymbolicParameter,Real}) = _add_parameter_expr(ParameterExpr(a), ParameterExpr(b))
Base.:+(a::Real, b::_SymbolicParameter) = b + a
Base.:+(a::_SymbolicParameter) = ParameterExpr(a)
function Base.:*(coefficient::Real, value::_SymbolicParameter)
    _finite_parameter_real(coefficient)
    e = ParameterExpr(value)
    return ParameterExpr(Tuple(first(term) => _parameter_multiply(coefficient, last(term)) for term in e.terms), _parameter_multiply(coefficient, e.constant))
end
Base.:*(value::_SymbolicParameter, coefficient::Real) = coefficient * value
Base.:-(value::_SymbolicParameter) = -1 * value
Base.:-(a::_SymbolicParameter, b::Union{_SymbolicParameter,Real}) = a + (-ParameterExpr(b))
Base.:-(a::Real, b::_SymbolicParameter) = ParameterExpr(a) + (-b)
function Base.:/(a::_SymbolicParameter, b::Real)
    _finite_parameter_real(b)
    iszero(b) && throw(ArgumentError("parameter expressions cannot be divided by zero"))
    e = ParameterExpr(a)
    return ParameterExpr(Tuple(first(term) => last(term) / b for term in e.terms), e.constant / b)
end
Base.:*(::_SymbolicParameter, ::_SymbolicParameter) = throw(ArgumentError("only real affine parameter expressions are supported; products of variables are nonlinear"))
Base.:/(::Union{Real,_SymbolicParameter}, ::_SymbolicParameter) = throw(ArgumentError("division by a parameter is nonlinear"))

"""Resolve either identity keys or unique names against a template's variables."""
function _resolve_parameter_assignments(vars, assignments::AbstractDict; require_all::Bool=true, numeric::Bool=true)
    variables = collect(vars)
    all(p -> p isa Parameter, variables) || throw(ArgumentError("expected named parameters"))
    keyed_by_identity = all(key -> key isa Parameter, keys(assignments))
    keyed_by_name = all(key -> key isa Union{Symbol,AbstractString}, keys(assignments))
    keyed_by_identity || keyed_by_name || throw(ArgumentError("use only Parameter keys or only unique parameter names in one binding"))
    result = Dict{Parameter,Any}()
    for (key, value) in assignments
        matches = keyed_by_identity ? filter(p -> p == key, variables) : filter(p -> p.name == Symbol(key), variables)
        isempty(matches) && throw(ArgumentError("unknown parameter $(repr(key))"))
        length(matches) == 1 || throw(ArgumentError("parameter name $(repr(key)) is ambiguous; bind using Parameter objects"))
        p = only(matches)
        haskey(result, p) && throw(ArgumentError("parameter $(p.name) was supplied more than once"))
        if numeric
            _finite_parameter_real(value)
        elseif value isa Real
            _finite_parameter_real(value)
        elseif !(value isa _SymbolicParameter)
            throw(ArgumentError("parameter replacements must be finite real numbers, Parameters, or affine expressions"))
        end
        result[p] = value
    end
    if require_all
        missing = filter(p -> !haskey(result, p), variables)
        isempty(missing) || throw(ArgumentError("missing values for parameters $(join(string.(getfield.(missing, :name)), ", "))"))
    end
    return result
end
