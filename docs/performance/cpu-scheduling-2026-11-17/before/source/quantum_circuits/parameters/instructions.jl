"""An operation still needs named parameter binding before numerical use."""
struct UnboundParameterError <: Exception
    path::Tuple
    parameters::Tuple
end
function Base.showerror(io::IO, error::UnboundParameterError)
    print(io, "bind_parameters is required before numerical use of the parameterized instruction at ", error.path)
    isempty(error.parameters) || print(io, "; missing values for ", join(string.(getfield.(error.parameters, :name)), ", "))
end

"""Internal symbolic description whose expressions follow prototype active slots."""
struct ParameterizedInstruction{G<:Gate,E<:Tuple} <: AbstractInstruction
    prototype::G
    expressions::E
    function ParameterizedInstruction(prototype::Gate, expressions::Tuple)
        length(expressions) == nparameters(prototype) || throw(DimensionMismatch("one expression is required for each prototype active slot"))
        converted = map(ParameterExpr, expressions)
        copied = copy_instruction(prototype)
        copied isa Gate || throw(ArgumentError("copy_instruction must preserve a gate prototype"))
        new{typeof(copied),typeof(converted)}(copied, converted)
    end
end

"""Name a gate's current active slots without modifying its numeric prototype."""
parameterize(prototype::Gate, expressions::Union{AbstractVector,Tuple}) = ParameterizedInstruction(prototype, Tuple(expressions))
parameterize(prototype::Gate, expression::_SymbolicParameter) = parameterize(prototype, (expression,))
positions(x::ParameterizedInstruction) = positions(x.prototype)
nqubits(x::ParameterizedInstruction) = nqubits(x.prototype)
ordered_positions(x::ParameterizedInstruction) = ordered_positions(x.prototype)
nparameters(x::ParameterizedInstruction) = count(e -> !isempty(e.terms), x.expressions)
copy_instruction(x::ParameterizedInstruction) = ParameterizedInstruction(x.prototype, x.expressions)
function _remap_parameter_prototype(x::AdjointQuantumGate, mapping)
    return AdjointQuantumGate(_remap_parameter_prototype(x.parent, mapping))
end
_remap_parameter_prototype(x::Gate, mapping) = change_positions(x, mapping)
change_positions(x::ParameterizedInstruction, mapping::AbstractDict) = ParameterizedInstruction(_remap_parameter_prototype(x.prototype, mapping), x.expressions)
shift(x::ParameterizedInstruction, offset::Int) = change_positions(x, Dict(p => p + offset for p in positions(x)))
function Base.adjoint(x::ParameterizedInstruction)
    prototype = x.prototype isa AdjointQuantumGate ? x.prototype.parent : AdjointQuantumGate(x.prototype)
    return ParameterizedInstruction(prototype, x.expressions)
end
Base.show(io::IO, x::ParameterizedInstruction) = print(io, nameof(typeof(x.prototype)), "(", positions(x), "; ", join(string.(x.expressions), ", "), ")")

"""
    parameter_slots(instruction) -> Tuple

Return stable local keys for the instruction's current active parameters, in
`active_parameters` order. Keys identify physical slots even when another slot
is frozen. Built-in gates use their complete numerical parameter indices.

An extension may return distinct `Int` or `Symbol` keys. The default supports
parameterless instructions and instructions whose complete parameter vector is
fully active. Partially active extensions without the built-in activity mask
must implement this hook to participate in named or mixed compilation. Existing
pure numerical parameter writers do not require this hook.
"""
function parameter_slots(x::AbstractInstruction)
    slot_count = nparameters(x)
    slot_count == 0 && return ()
    values = parameters(x)
    values isa AbstractVector{<:Real} && length(values) == slot_count ||
        throw(ArgumentError("$(typeof(x)) must implement parameter_slots(instruction) to identify its active physical parameter slots"))
    return Tuple(1:slot_count)
end
function parameter_slots(x::Gate)
    slot_count = nparameters(x)
    slot_count == 0 && return ()
    mask = is_parameters(x)
    isnothing(mask) && return invoke(parameter_slots, Tuple{AbstractInstruction}, x)
    values = parameters(x)
    mask isa AbstractVector{Bool} && values isa AbstractVector{<:Real} &&
        length(mask) == length(values) && count(identity, mask) == slot_count ||
        throw(ArgumentError("invalid gate activity layout; implement parameter_slots(instruction) for a custom slot layout"))
    return Tuple(findall(mask))
end
parameter_slots(x::AdjointQuantumGate) = parameter_slots(x.parent)
function parameter_slots(x::ParameterizedInstruction)
    slots = parameter_slots(x.prototype)
    length(slots) == length(x.expressions) ||
        throw(ArgumentError("parameter_slots(prototype) must identify every original active expression slot"))
    return Tuple(slot for (slot, expression) in zip(slots, x.expressions) if !isempty(expression.terms))
end

_has_parameterized(::AbstractInstruction) = false
_has_parameterized(::ParameterizedInstruction) = true
_has_parameterized(c::QCircuit) = any(_has_parameterized, c)
_has_parameterized(c::Conditional) = _has_parameterized(c.then_branch) || _has_parameterized(c.else_branch)

_has_anonymous_parameters(x::AbstractInstruction) = nparameters(x) > 0
_has_anonymous_parameters(::ParameterizedInstruction) = false
_has_anonymous_parameters(c::QCircuit) = any(_has_anonymous_parameters, c)
_has_anonymous_parameters(c::Conditional) = _has_anonymous_parameters(c.then_branch) || _has_anonymous_parameters(c.else_branch)

function _require_numeric_parameter_mutation(instruction::AbstractInstruction)
    _has_parameterized(instruction) && throw(ArgumentError("configure fixed named variables on the objective or use substitute_parameters; symbolic templates cannot be changed by numeric activity writers"))
    return nothing
end

function _collect_parameter_expressions!(output, x::ParameterizedInstruction)
    append!(output, x.expressions)
    return output
end
_collect_parameter_expressions!(output, ::AbstractInstruction) = output
function _collect_parameter_expressions!(output, circuit::QCircuit)
    for x in circuit
        _collect_parameter_expressions!(output, x)
    end
    return output
end
function _collect_parameter_expressions!(output, x::Conditional)
    _collect_parameter_expressions!(output, x.then_branch)
    _collect_parameter_expressions!(output, x.else_branch)
    return output
end
"""Return every symbolic expression slot, including constants, in occurrence order."""
parameter_expressions(x::AbstractInstruction) = _collect_parameter_expressions!(ParameterExpr[], x)
function _named_parameters(x::AbstractInstruction)
    result = Parameter[]
    for expression in parameter_expressions(x), term in expression.terms
        p = first(term)
        old = findfirst(q -> q == p, result)
        if isnothing(old)
            push!(result, p)
        elseif result[old].name != p.name
            throw(ArgumentError("one parameter identity has conflicting names"))
        end
    end
    return result
end
"""
Return named free variables in deterministic first-occurrence order. Compile a
template that mixes named variables and anonymous active numerical slots first;
its compiled context also identifies the anonymous independent parameters.
"""
function independent_parameters(x::AbstractInstruction)
    _has_parameterized(x) && _has_anonymous_parameters(x) &&
        throw(ArgumentError("compile_parameters is required before querying independent parameters of a mixed named and numerical template"))
    return _named_parameters(x)
end
parameter_order(x::AbstractInstruction) = independent_parameters(x)
function trainable_parameters end

function _require_bound_parameters(x::AbstractInstruction, path::Tuple=())
    if x isa ParameterizedInstruction
        throw(UnboundParameterError(path, Tuple(_named_parameters(x))))
    elseif x isa QCircuit
        for (i, op) in enumerate(x)
            _require_bound_parameters(op, (path..., i))
        end
    elseif x isa Conditional
        _require_bound_parameters(x.then_branch, (path..., :then))
        _require_bound_parameters(x.else_branch, (path..., :else))
    end
    return nothing
end
for operation in (:mat, :ordered_mat, :parameters, :active_parameters, :differentiate)
    @eval $operation(x::ParameterizedInstruction) = throw(UnboundParameterError((), Tuple(_named_parameters(x))))
end
for operation in (:activate_parameters!, :deactivate_parameters!)
    @eval $operation(::ParameterizedInstruction) = throw(ArgumentError("configure fixed named variables on the objective or use substitute_parameters"))
end
for operation in (:activate_parameter!, :deactivate_parameter!)
    @eval $operation(::ParameterizedInstruction, ::Int) = throw(ArgumentError("configure fixed named variables on the objective or use substitute_parameters"))
end
reset_parameters!(::ParameterizedInstruction, ::AbstractVector{<:Real}) = throw(ArgumentError("use bind_parameters to bind named variables"))

function _substitute_parameter_expr(expression::ParameterExpr, replacements)
    result = ParameterExpr(expression.constant)
    for term in expression.terms
        replacement = get(replacements, first(term), first(term))
        result += replacement isa Real ? _parameter_multiply(last(term), replacement) : last(term) * replacement
    end
    return result
end
_substitute_parameter_instruction(x::AbstractInstruction, replacements) = copy_instruction(x)
_substitute_parameter_instruction(x::ParameterizedInstruction, replacements) =
    ParameterizedInstruction(x.prototype, map(e -> _substitute_parameter_expr(e, replacements), x.expressions))
_substitute_parameter_instruction(c::QCircuit, replacements) = QCircuit([_substitute_parameter_instruction(x, replacements) for x in c])
_substitute_parameter_instruction(c::Conditional, replacements) = Conditional(c.condition,
    _substitute_parameter_instruction(c.then_branch, replacements);
    otherwise=_substitute_parameter_instruction(c.else_branch, replacements))
"""Simultaneously replace a subset of named variables by values or affine expressions."""
function substitute_parameters(x::AbstractInstruction, replacements::AbstractDict)
    resolved = _resolve_parameter_assignments(_named_parameters(x), replacements; require_all=false, numeric=false)
    return _substitute_parameter_instruction(x, resolved)
end

"""
    materialize_parameters(prototype, values, active_mask)

Bind the prototype's original active slots, retaining only the requested active
slots. Frozen original values are preserved. Extensions may override this hook
when their public activity writers cannot express the requested mask.
"""
function materialize_parameters(prototype::Gate, values::AbstractVector{<:Real}, active_mask::AbstractVector{Bool})
    slot_count = nparameters(prototype)
    length(values) == length(active_mask) == slot_count || throw(DimensionMismatch("values and activity mask must match prototype active slots"))
    for value in values
        value isa Bool && throw(ArgumentError("bound gate values must be finite real numbers excluding Bool"))
        isfinite(value) || throw(ArgumentError("bound gate values must be finite real numbers"))
    end
    original = parameters(prototype)
    if isnothing(original) && slot_count == 0
        result = copy_instruction(prototype)
        result isa Gate || throw(ArgumentError("copy_instruction must return a Gate for a gate prototype"))
        return result
    end
    original isa AbstractVector{<:Real} || throw(ArgumentError("gate must implement materialize_parameters to expose and preserve its complete numerical parameters"))
    old_values = collect(original)
    old_mask = is_parameters(prototype)
    if isnothing(old_mask)
        length(old_values) == slot_count || throw(ArgumentError("gate must implement materialize_parameters for partially active prototypes"))
        old_mask = trues(slot_count)
    else
        old_mask isa AbstractVector{Bool} || throw(ArgumentError("prototype activity mask must be a Boolean vector; implement materialize_parameters for a custom slot layout"))
        old_mask = collect(old_mask)
        length(old_mask) == length(old_values) && count(identity, old_mask) == slot_count || throw(ArgumentError("invalid prototype activity layout"))
    end
    active_indices = findall(old_mask)
    for index in eachindex(old_values)
        old_mask[index] || isfinite(old_values[index]) ||
            throw(ArgumentError("frozen prototype parameters must be finite"))
    end
    result = copy_instruction(prototype)
    result isa Gate || throw(ArgumentError("copy_instruction must return a Gate for a gate prototype"))
    result = reset_parameters!(result, collect(values))
    result isa Gate || throw(ArgumentError("reset_parameters! must return a Gate when materializing a gate prototype"))
    for (i, slot) in enumerate(active_indices)
        if !active_mask[i]
            result = deactivate_parameter!(result, slot)
            result isa Gate || throw(ArgumentError("deactivate_parameter! must return a Gate when materializing a gate prototype"))
        end
    end
    result isa Gate || throw(ArgumentError("materialize_parameters must return a numerical Gate"))
    after = parameters(result)
    after isa AbstractVector{<:Real} && length(after) == length(old_values) && all(isfinite, after) ||
        throw(ArgumentError("gate cannot materialize the requested numerical parameters"))
    expected = copy(old_values)
    for (j, slot) in enumerate(active_indices)
        expected[slot] = values[j]
    end
    all(i -> isequal(after[i], convert(typeof(after[i]), expected[i])), eachindex(after)) ||
        throw(ArgumentError("gate failed to preserve full numerical parameter values; implement materialize_parameters"))
    wanted = collect(values[active_mask])
    active = active_parameters(result)
    nparameters(result) == count(identity, active_mask) && active isa AbstractVector{<:Real} && length(active) == length(wanted) &&
        all(i -> isequal(active[i], convert(typeof(active[i]), wanted[i])), eachindex(active)) ||
        throw(ArgumentError("gate cannot express the requested active mask; implement materialize_parameters"))
    return result
end

# Positional symbolic constructors leave all existing numeric constructors intact.
for name in (:RxGate, :RyGate, :RzGate, :PHASEGate)
    @eval function $name(pos::Int, expression::_SymbolicParameter; isparas=nothing)
        isnothing(isparas) || throw(ArgumentError("use fixed on a named objective instead of isparas"))
        parameterize($name(pos, 0.0; isparas=true), (expression,))
    end
end
for name in (:CRxGate, :CRyGate, :CRzGate, :CPHASEGate)
    @eval begin
        function $name(pos::Tuple{Int,Int}, expression::_SymbolicParameter; isparas=nothing)
            isnothing(isparas) || throw(ArgumentError("use fixed on a named objective instead of isparas"))
            parameterize($name(pos, 0.0; isparas=true), (expression,))
        end
        $name(control::Int, target::Int, expression::_SymbolicParameter; kwargs...) = $name((control, target), expression; kwargs...)
    end
end
function CCPHASEGate(pos::Tuple{Int,Int,Int}, expression::_SymbolicParameter; isparas=nothing)
    isnothing(isparas) || throw(ArgumentError("use fixed on a named objective instead of isparas"))
    parameterize(CCPHASEGate(pos, 0.0; isparas=true), (expression,))
end
CCPHASEGate(a::Int,b::Int,c::Int,expression::_SymbolicParameter; kwargs...) = CCPHASEGate((a,b,c), expression; kwargs...)
function FSIMGate(pos::Tuple{Int,Int}, expressions::AbstractVector; isparas=nothing)
    isnothing(isparas) || throw(ArgumentError("use fixed on a named objective instead of isparas"))
    length(expressions) == 5 || throw(ArgumentError("5 parameters expected"))
    any(x -> x isa _SymbolicParameter, expressions) || throw(ArgumentError("FSIM parameters must be real values or affine expressions"))
    return parameterize(FSIMGate(pos, zeros(5); isparas=fill(true,5)), Tuple(expressions))
end
FSIMGate(c::Int,t::Int,expressions::AbstractVector; kwargs...) = FSIMGate((c,t), expressions; kwargs...)
