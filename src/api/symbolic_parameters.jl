"""Immutable affine input-to-slot map produced by `compile_parameters`."""
struct AffineParameterMap{T<:Real} <: AbstractParameterMap
    rows::Tuple
    offsets::Tuple{Vararg{T}}
    variables::Tuple{Vararg{Parameter}}
    inputs::Tuple{Vararg{Parameter}}
    fixed::Tuple
    layout::Tuple
    registry::Tuple
end

Base.length(map::AffineParameterMap) = length(map.rows)
Base.copy(map::AffineParameterMap) = map
QuantumCircuits.nparameters(map::AffineParameterMap) = length(map.inputs)
parameter_order(map::AffineParameterMap) = Parameter[map.inputs...]
independent_parameters(map::AffineParameterMap) = Parameter[map.variables...]
trainable_parameters(map::AffineParameterMap) = parameter_order(map)
_is_symbolic_map(::AffineParameterMap) = true
_parameter_row(map::AffineParameterMap, slot::Integer) = map.rows[slot]

function _parameter_result_type(map::AffineParameterMap{T}, values) where T
    V = isconcretetype(eltype(values)) ? eltype(values) :
        (isempty(values) ? T : mapreduce(typeof, promote_type, values))
    return promote_type(T, V)
end

function expand_parameters(map::AffineParameterMap, values::AbstractVector{<:Real})
    Base.require_one_based_indexing(values)
    length(values) == nparameters(map) || throw(DimensionMismatch("expected $(nparameters(map)) trainable parameters, received $(length(values))."))
    all(x -> !(x isa Bool) && isfinite(x), values) || throw(ArgumentError("named parameter values must be finite real numbers excluding Bool"))
    T = _parameter_result_type(map, values)
    result = Vector{T}(undef, length(map))
    for j in eachindex(result)
        value = convert(T, map.offsets[j])
        for (index, coefficient) in map.rows[j]
            value = QuantumCircuits._parameter_add(value, QuantumCircuits._parameter_multiply(coefficient, values[index]))
        end
        isfinite(value) || throw(ArgumentError("expanded gate parameter overflows its numerical domain at slot $j"))
        result[j] = value
    end
    return result
end

function accumulate_parameter_gradients(map::AffineParameterMap, gradients::AbstractVector{<:Real})
    Base.require_one_based_indexing(gradients)
    length(gradients) == length(map) || throw(DimensionMismatch("expected $(length(map)) active-slot gradients, received $(length(gradients))."))
    T = _parameter_result_type(map, gradients)
    result = zeros(T, nparameters(map))
    for (row, gradient) in zip(map.rows, gradients), (index, coefficient) in row
        result[index] = QuantumCircuits._parameter_add(result[index], QuantumCircuits._parameter_multiply(coefficient, gradient))
    end
    return result
end

# A context owns both the snapshot and its identities; no global registry is used.
const _ParameterContext = NamedTuple{(:template, :parameter_map),<:Tuple{AbstractInstruction,AbstractParameterMap}}

function _checked_parameter_slots(instruction::AbstractInstruction)
    slots = parameter_slots(instruction)
    slots isa Tuple || throw(ArgumentError("parameter_slots must return a Tuple of stable local keys"))
    length(slots) == nparameters(instruction) || throw(DimensionMismatch("parameter_slots must match active parameter count"))
    all(key -> (key isa Int && !(key isa Bool)) || key isa Symbol, slots) && allunique(slots) ||
        throw(ArgumentError("parameter_slots must contain distinct Int or Symbol keys"))
    return slots
end

function _parameter_layout!(output, instruction::AbstractInstruction, path::Tuple=())
    if instruction isa QCircuit
        for (i, child) in enumerate(instruction)
            _parameter_layout!(output, child, (path..., i))
        end
    elseif instruction isa Conditional
        _parameter_layout!(output, instruction.then_branch, (path..., :then))
        _parameter_layout!(output, instruction.else_branch, (path..., :else))
    elseif instruction isa QuantumCircuits.ParameterizedInstruction
        push!(output, (path, typeof(instruction.prototype), Tuple(positions(instruction)),
                       _checked_parameter_slots(instruction.prototype), instruction.expressions))
    else
        push!(output, (path, typeof(instruction), Tuple(positions(instruction)), _checked_parameter_slots(instruction)))
    end
    return output
end
_parameter_layout(instruction) = Tuple(_parameter_layout!(Any[], instruction))

function _check_parameter_map(template::AbstractInstruction, map::AffineParameterMap)
    length(map) == nparameters(template) || throw(DimensionMismatch("affine map and active instruction slots disagree"))
    _parameter_layout(template) == map.layout || throw(ArgumentError("affine parameter map belongs to a different instruction layout; compile the template again"))
    return map
end

function _register_parameter!(registry, parameter, kind, initial, source)
    index = findfirst(entry -> entry.parameter == parameter, registry)
    if isnothing(index)
        push!(registry, (; parameter, kind, label=parameter.name, initial=deepcopy(initial),
                          sources=(source,), candidates=kind === :anonymous ? (deepcopy(initial),) : ()))
    else
        entry = registry[index]
        entry.label == parameter.name || throw(ArgumentError("one parameter identity has conflicting names"))
        source in entry.sources || (registry[index] = merge(entry, (; sources=(entry.sources..., source))))
    end
    return nothing
end

function _register_parameter_tree!(registry, instruction::AbstractInstruction, path::Tuple=())
    if instruction isa QCircuit
        for (index, child) in enumerate(instruction)
            _register_parameter_tree!(registry, child, (path..., index))
        end
    elseif instruction isa Conditional
        _register_parameter_tree!(registry, instruction.then_branch, (path..., :then))
        _register_parameter_tree!(registry, instruction.else_branch, (path..., :else))
    elseif instruction isa QuantumCircuits.ParameterizedInstruction
        slots = _checked_parameter_slots(instruction.prototype)
        active_index = 0
        for (slot, expression) in zip(slots, instruction.expressions)
            isempty(expression.terms) && continue
            active_index += 1
            source = (; path, slot, active_index)
            for (parameter, _) in expression.terms
                _register_parameter!(registry, parameter, :named, missing, source)
            end
        end
    else
        slots = _checked_parameter_slots(instruction)
        isempty(slots) && return registry
        values = active_parameters(instruction)
        values isa AbstractVector{<:Real} && length(values) == length(slots) ||
            throw(ArgumentError("$(typeof(instruction)) must expose its active numerical values for mixed compilation"))
        for (active_index, slot) in enumerate(slots)
            value = values[active_index]
            initial = value isa Real && !(value isa Bool) && isfinite(value) ? value : missing
            parameter = Parameter(Symbol("_anon_", count(entry -> entry.kind === :anonymous, registry) + 1))
            _register_parameter!(registry, parameter, :anonymous, initial, (; path, slot, active_index))
        end
    end
    return registry
end

function _ordered_parameters(variables, requested)
    isnothing(requested) && return Parameter[variables...]
    order = collect(requested)
    all(p -> p isa Parameter, order) || throw(ArgumentError("parameter_order must contain Parameter objects"))
    length(order) == length(variables) && allunique(order) && Set(order) == Set(variables) ||
        throw(ArgumentError("parameter_order must contain each registered variable exactly once"))
    return Parameter[order...]
end

function _anonymous_parameter(registry, path, slot)
    matches = filter(entry -> entry.kind === :anonymous &&
        any(source -> source.path == path && source.slot == slot, entry.sources), registry)
    length(matches) == 1 || throw(ArgumentError("anonymous parameter source no longer matches the compiled layout; compile the original template again"))
    return only(matches).parameter
end

function _freeze_parameter_tree(instruction::AbstractInstruction, registry, assignments, path::Tuple=())
    if instruction isa QCircuit
        return QCircuit([_freeze_parameter_tree(child, registry, assignments, (path..., index))
                         for (index, child) in enumerate(instruction)])
    elseif instruction isa Conditional
        return Conditional(instruction.condition,
            _freeze_parameter_tree(instruction.then_branch, registry, assignments, (path..., :then));
            otherwise=_freeze_parameter_tree(instruction.else_branch, registry, assignments, (path..., :else)))
    elseif instruction isa QuantumCircuits.ParameterizedInstruction
        return QuantumCircuits._substitute_parameter_instruction(instruction, assignments)
    end
    slots = _checked_parameter_slots(instruction)
    isempty(slots) && return copy_instruction(instruction)
    handles = [_anonymous_parameter(registry, path, slot) for slot in slots]
    any(p -> haskey(assignments, p), handles) || return copy_instruction(instruction)
    instruction isa Gate || throw(ArgumentError("fixing anonymous slots of $(typeof(instruction)) requires a gate materialization hook; bind its complete vector instead"))
    return parameterize(instruction, Tuple(get(assignments, p, p) for p in handles))
end

function _affine_rows!(rows, offsets, instruction::AbstractInstruction, inputs, registry, path::Tuple=())
    if instruction isa QCircuit
        for (index, child) in enumerate(instruction)
            _affine_rows!(rows, offsets, child, inputs, registry, (path..., index))
        end
    elseif instruction isa Conditional
        _affine_rows!(rows, offsets, instruction.then_branch, inputs, registry, (path..., :then))
        _affine_rows!(rows, offsets, instruction.else_branch, inputs, registry, (path..., :else))
    elseif instruction isa QuantumCircuits.ParameterizedInstruction
        for expression in instruction.expressions
            isempty(expression.terms) && continue
            push!(rows, Tuple(findfirst(==(p), inputs) => coefficient for (p, coefficient) in expression.terms))
            push!(offsets, expression.constant)
        end
    else
        for slot in _checked_parameter_slots(instruction)
            parameter = _anonymous_parameter(registry, path, slot)
            push!(rows, (findfirst(==(parameter), inputs) => 1,))
            push!(offsets, 0)
        end
    end
    return nothing
end

function _compiled_affine_context(template, registry, variables, assignments)
    inputs = filter(p -> !haskey(assignments, p), variables)
    snapshot = _freeze_parameter_tree(template, registry, assignments)
    rows, offsets = Any[], Real[]
    _affine_rows!(rows, offsets, snapshot, inputs, registry)
    types = Type[typeof(c) for row in rows for (_, c) in row]
    append!(types, typeof.(offsets))
    T = isempty(types) ? Float64 : foldl(promote_type, types)
    typed_rows = Tuple(Tuple(Int(index) => convert(T, coefficient) for (index, coefficient) in row) for row in rows)
    typed_offsets = Tuple(convert(T, offset) for offset in offsets)
    saved_fixed = Tuple(p => deepcopy(assignments[p]) for p in variables if haskey(assignments, p))
    map = AffineParameterMap{T}(typed_rows, typed_offsets, Tuple(variables), Tuple(inputs), saved_fixed,
                                _parameter_layout(snapshot), Tuple(registry))
    _check_parameter_map(snapshot, map)
    return (; template=snapshot, parameter_map=map)
end

function _compile_named_parameters(template; parameter_order=nothing, fixed=nothing)
    QuantumCircuits._has_anonymous_parameters(template) && !isnothing(parameter_order) &&
        throw(ArgumentError("compile a mixed template first, then reorder its complete parameter handles on that context"))
    registry = _register_parameter_tree!(Any[], template)
    variables = _ordered_parameters([entry.parameter for entry in registry], parameter_order)
    # Resolve against the complete registry, including anonymous provenance.
    preliminary = _compiled_affine_context(template, registry, variables, Dict{Parameter,Any}())
    isnothing(fixed) && return preliminary
    assignments = _resolve_context_values(preliminary.parameter_map, fixed; require_all=false, scope=:variables)
    return _compiled_affine_context(preliminary.template, registry, variables, assignments)
end

"""
    compile_parameters(template_or_context; parameter_order=nothing, fixed=nothing, parameter_map=nothing)

Own a reusable template snapshot and input-to-slot map. Named expressions and
anonymous numerical active slots share a single affine input order. Plain
numeric templates keep their integer map. Reuse the returned context to retain
anonymous identities, reorder all handles, or append fixed variables.
Compilation does not evaluate placeholder matrices or draw from the user's RNG.
"""
function compile_parameters(template::AbstractInstruction; parameter_order=nothing, fixed=nothing, parameter_map=nothing)
    if !isnothing(parameter_map)
        parameter_map isa AbstractParameterMap || throw(ArgumentError("parameter_map must implement AbstractParameterMap"))
        isnothing(parameter_order) && isnothing(fixed) || throw(ArgumentError("explicit parameter_map cannot be combined with parameter_order or fixed"))
        QuantumCircuits._has_parameterized(template) && !_is_symbolic_map(parameter_map) &&
            throw(ArgumentError("named parameter templates cannot use an integer parameter map"))
        _check_parameter_map(template, parameter_map)
        return (; template=copy_instruction(template), parameter_map=copy(parameter_map))
    elseif QuantumCircuits._has_parameterized(template)
        return _compile_named_parameters(template; parameter_order, fixed)
    end
    isnothing(parameter_order) && isnothing(fixed) || throw(ArgumentError("parameter_order and fixed require a named or mixed parameter context"))
    snapshot = copy_instruction(template)
    return (; template=snapshot, parameter_map=ParameterMap(snapshot))
end

function compile_parameters(context::_ParameterContext; parameter_order=nothing, fixed=nothing, parameter_map=nothing)
    isnothing(parameter_map) || throw(ArgumentError("a compiled context already owns its parameter_map"))
    map = context.parameter_map
    _check_parameter_map(context.template, map)
    if !(map isa AffineParameterMap)
        isnothing(parameter_order) && isnothing(fixed) || throw(ArgumentError("integer contexts retain the existing integer map configuration"))
        return (; template=copy_instruction(context.template), parameter_map=copy(map))
    end
    variables = _ordered_parameters(map.variables, parameter_order)
    assignments = Dict{Parameter,Any}(map.fixed)
    if !isnothing(fixed)
        additions = _resolve_context_values(map, fixed; require_all=false, scope=:variables)
        for (parameter, value) in additions
            haskey(assignments, parameter) && !isequal(assignments[parameter], value) &&
                throw(ArgumentError("already fixed values cannot be changed on a compiled context; rebuild from the original template"))
            assignments[parameter] = value
        end
    end
    return _compiled_affine_context(context.template, map.registry, variables, assignments)
end
Base.copy(context::_ParameterContext) = compile_parameters(context)
parameter_order(context::_ParameterContext) = parameter_order(context.parameter_map)
independent_parameters(context::_ParameterContext) = independent_parameters(context.parameter_map)
trainable_parameters(context::_ParameterContext) = trainable_parameters(context.parameter_map)
_prepare_parameter_template(template; kwargs...) = compile_parameters(template; kwargs...)

function _flat_bind_walk(instruction::AbstractInstruction, flat, cursor)
    if instruction isa QCircuit
        return QCircuit([_flat_bind_walk(child, flat, cursor) for child in instruction])
    elseif instruction isa Conditional
        yes = _flat_bind_walk(instruction.then_branch, flat, cursor)
        no = _flat_bind_walk(instruction.else_branch, flat, cursor)
        return Conditional(instruction.condition, yes; otherwise=no)
    elseif instruction isa QuantumCircuits.ParameterizedInstruction
        mask = Bool[!isempty(expression.terms) for expression in instruction.expressions]
        values = Real[]
        for (expression, active) in zip(instruction.expressions, mask)
            if active
                push!(values, flat[cursor[]])
                cursor[] += 1
            else
                push!(values, expression.constant)
            end
        end
        T = isempty(values) ? Float64 : mapreduce(typeof, promote_type, values)
        return materialize_parameters(instruction.prototype, T[values...], mask)
    end
    n = nparameters(instruction)
    result = bind_parameters(instruction, view(flat, cursor[]:cursor[] + n - 1))
    cursor[] += n
    return result
end

"""Bind already-expanded active slots without applying an affine map twice."""
function _flat_bind(template::AbstractInstruction, flat::AbstractVector{<:Real})
    Base.require_one_based_indexing(flat)
    length(flat) == nparameters(template) || throw(DimensionMismatch("active parameter-slot count disagrees"))
    all(isfinite, flat) || throw(ArgumentError("gate parameters must be finite"))
    return _flat_bind_walk(template, flat, Ref(1))
end

function _bind_named_parameters(template, values::AbstractVector{<:Real}; parameter_order=nothing)
    compiled = compile_parameters(template; parameter_order)
    return bind_parameters(compiled.template, values, compiled.parameter_map)
end
function bind_parameters(template::AbstractInstruction, assignments::AbstractDict)
    return bind_parameters(compile_parameters(template), assignments)
end

function bind_parameters(context::_ParameterContext, values::AbstractVector{<:Real})
    return bind_parameters(context.template, values, context.parameter_map)
end
function bind_parameters(context::_ParameterContext, assignments::AbstractDict)
    map = context.parameter_map
    _check_parameter_map(context.template, map)
    if map isa AffineParameterMap
        resolved = _resolve_context_values(map, assignments)
        return bind_parameters(context, _initial_parameter_vector(Real[resolved[p] for p in map.inputs]))
    end
    resolved = _resolve_legacy_initial_values(map, assignments)
    length(resolved) == nparameters(map) || throw(ArgumentError("dictionary binding requires every training input"))
    return bind_parameters(context, _initial_parameter_vector(Real[resolved[p] for p in 1:nparameters(map)]))
end
