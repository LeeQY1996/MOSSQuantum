_valid_parameter_initial(value) = value isa Real && !(value isa Bool) && isfinite(value)

function _parameter_info_entry(entry, inputs, fixed)
    return (;
        parameter=entry.parameter,
        kind=entry.kind,
        label=entry.label,
        initial=deepcopy(entry.initial),
        sources=deepcopy(entry.sources),
        fixed=deepcopy(get(fixed, entry.parameter, nothing)),
        input_index=get(inputs, entry.parameter, nothing),
    )
end

"""
    parameter_info(compiled_or_map)

Return an independent tuple of parameter descriptions in original registration
order. Each entry records its identity, display label, captured initial value
(`missing` when unavailable), source slots, fixed value (`nothing` when
trainable), and current input index (`nothing` when fixed). Anonymous labels
are for display only; use the returned `parameter` handle for dictionary keys.

An integer `ParameterMap` alone has no template from which to recover initial
values or source slots. Query its compiled context to include that information.
"""
function parameter_info(map::AffineParameterMap)
    inputs = Dict(parameter => index for (index, parameter) in enumerate(map.inputs))
    fixed = Dict(map.fixed)
    return Tuple(_parameter_info_entry(entry, inputs, fixed) for entry in map.registry)
end

function _legacy_default(candidates)
    isempty(candidates) && return missing
    all(_valid_parameter_initial, candidates) || return missing
    value = first(candidates)
    return all(other -> isequal(other, value), candidates) ? deepcopy(value) : missing
end

function _legacy_initial_registry(map::ParameterMap)
    return Tuple((;
        parameter=index,
        kind=:anonymous,
        label=Symbol("parameter_", index),
        initial=missing,
        sources=(),
        candidates=(),
    ) for index in 1:nparameters(map))
end

function _legacy_initial_slots!(result, instruction::AbstractInstruction, path::Tuple=())
    if instruction isa QCircuit
        for (index, child) in enumerate(instruction)
            _legacy_initial_slots!(result, child, (path..., index))
        end
    elseif instruction isa Conditional
        _legacy_initial_slots!(result, instruction.then_branch, (path..., :then))
        _legacy_initial_slots!(result, instruction.else_branch, (path..., :else))
    else
        count = nparameters(instruction)
        count == 0 && return result
        values = active_parameters(instruction)
        values isa AbstractVector{<:Real} && length(values) == count ||
            throw(ArgumentError("$(typeof(instruction)) must expose its active numerical parameters to recover initial values"))
        # Legacy numeric circuits do not require the new physical-slot hook.
        # Missing physical coordinates are descriptive only, never used to bind.
        slots = try
            Tuple(parameter_slots(instruction))
        catch error
            error isa ArgumentError || error isa MethodError || rethrow()
            ntuple(_ -> missing, count)
        end
        length(slots) == count || throw(DimensionMismatch("parameter_slots must match active parameter count"))
        for index in 1:count
            push!(result, (;
                value=deepcopy(values[index]),
                source=(; path, slot=deepcopy(slots[index]), active_index=index),
            ))
        end
    end
    return result
end

function _legacy_initial_registry(template::AbstractInstruction, map::ParameterMap)
    _check_parameter_map(template, map)
    slots = _legacy_initial_slots!(Any[], template)
    length(slots) == length(map) || throw(DimensionMismatch("parameter map and recovered initial slots disagree"))
    candidates_by_id = [Any[] for _ in 1:nparameters(map)]
    sources_by_id = [Any[] for _ in 1:nparameters(map)]
    for (index, slot) in zip(map.indices, slots)
        push!(candidates_by_id[index], slot.value)
        push!(sources_by_id[index], slot.source)
    end
    return Tuple(begin
        candidates = Tuple(candidates_by_id[index])
        (;
            parameter=index,
            kind=:anonymous,
            label=Symbol("parameter_", index),
            initial=_legacy_default(candidates),
            sources=Tuple(sources_by_id[index]),
            candidates,
        )
    end for index in 1:nparameters(map))
end

function _legacy_parameter_info(registry)
    return Tuple((;
        parameter=entry.parameter,
        kind=entry.kind,
        label=entry.label,
        initial=deepcopy(entry.initial),
        sources=deepcopy(entry.sources),
        fixed=nothing,
        input_index=entry.parameter,
    ) for entry in registry)
end

parameter_info(map::ParameterMap) = _legacy_parameter_info(_legacy_initial_registry(map))
function parameter_info(context::_ParameterContext)
    map = context.parameter_map
    _check_parameter_map(context.template, map)
    return map isa ParameterMap ?
        _legacy_parameter_info(_legacy_initial_registry(context.template, map)) : parameter_info(map)
end

"""Resolve explicit values without completing defaults or resolving anonymous labels."""
function _resolve_context_values(map::AffineParameterMap, assignments; require_all::Bool=true, scope::Symbol=:inputs)
    assignments isa AbstractDict || throw(ArgumentError("parameter values must be supplied as a dictionary"))
    scope in (:inputs, :variables) || throw(ArgumentError("parameter scope must be :inputs or :variables"))
    variables = scope === :inputs ? map.inputs : map.variables
    handles = all(key -> key isa Parameter, keys(assignments))
    names = all(key -> key isa Symbol || key isa AbstractString, keys(assignments))
    handles || names || throw(ArgumentError("parameter dictionary keys must be all Parameter handles or all explicit names; the two forms cannot be mixed"))
    resolved = Dict{Parameter,Any}()
    for (key, value) in assignments
        _valid_parameter_initial(value) || throw(ArgumentError("parameter values must be finite real numbers excluding Bool"))
        parameter = if handles
            index = findfirst(==(key), map.variables)
            isnothing(index) && throw(ArgumentError("unknown parameter handle $key; anonymous handles belong to their compiled context"))
            map.variables[index]
        else
            name = Symbol(key)
            matches = filter(entry -> entry.kind === :named && entry.parameter.name == name, map.registry)
            isempty(matches) && throw(ArgumentError("unknown explicit parameter name $name; anonymous display labels cannot be used as names"))
            length(matches) == 1 || throw(ArgumentError("ambiguous explicit parameter name $name; use Parameter handles"))
            only(matches).parameter
        end
        parameter in variables || throw(ArgumentError("parameter $parameter is already fixed and has no training input"))
        haskey(resolved, parameter) && throw(ArgumentError("multiple keys name the same parameter $parameter"))
        resolved[parameter] = deepcopy(value)
    end
    if require_all
        missing_parameters = filter(parameter -> !haskey(resolved, parameter), variables)
        isempty(missing_parameters) || throw(ArgumentError("missing values for parameters $(join(string.(missing_parameters), ", "))"))
    end
    return resolved
end

function _resolve_legacy_initial_values(map::ParameterMap, assignments)
    assignments isa AbstractDict || throw(ArgumentError("parameter values must be supplied as a dictionary"))
    resolved = Dict{Int,Any}()
    for (key, value) in assignments
        key isa Integer && !(key isa Bool) || throw(ArgumentError("integer parameter maps require integer ID keys"))
        1 <= key <= nparameters(map) || throw(ArgumentError("unknown integer parameter ID $key"))
        _valid_parameter_initial(value) || throw(ArgumentError("parameter values must be finite real numbers excluding Bool"))
        resolved[Int(key)] = deepcopy(value)
    end
    return resolved
end

function _initial_parameter_vector(values)
    isempty(values) && return Float64[]
    T = mapreduce(typeof, promote_type, values)
    result = T[values...]
    all(_valid_parameter_initial, result) || throw(ArgumentError("initial parameter values must remain finite after numerical promotion"))
    return result
end

function _complete_initial_parameters(registry, inputs, assignments)
    values = Real[]
    entries = Dict(entry.parameter => entry for entry in registry)
    for parameter in inputs
        entry = entries[parameter]
        if haskey(assignments, parameter)
            push!(values, assignments[parameter])
        elseif _valid_parameter_initial(entry.initial)
            push!(values, deepcopy(entry.initial))
        elseif entry.kind === :named
            throw(ArgumentError("missing initial value for named parameter $(entry.label); provide it through values"))
        elseif length(entry.candidates) > 1 && all(_valid_parameter_initial, entry.candidates) &&
                !all(value -> isequal(value, first(entry.candidates)), entry.candidates)
            throw(ArgumentError("conflicting initial values for shared parameter $parameter at $(entry.sources); provide an explicit values[$parameter] override"))
        else
            throw(ArgumentError("no finite initial value for anonymous parameter $parameter at $(entry.sources); provide an explicit values override"))
        end
    end
    return _initial_parameter_vector(values)
end

"""
    initial_parameters(compiled_or_map; values=Dict())

Build the complete finite real input vector in current `parameter_order`.
Anonymous parameters use the numerical values captured at construction; named
parameters need explicit values. Overrides use Parameter handles or unique
explicit names, without mixing the two key forms. Anonymous display labels are
not name aliases. Already fixed variables cannot receive training initial values.

For integer maps, override keys are integer IDs. Shared numerical slots provide
a default only when every occurrence has exactly the same finite initial value.
This helper never samples, binds instructions, or stores optimizer updates.
"""
function initial_parameters(map::AffineParameterMap; values=Dict())
    assignments = _resolve_context_values(map, values; require_all=false)
    return _complete_initial_parameters(map.registry, map.inputs, assignments)
end
function initial_parameters(map::ParameterMap; values=Dict())
    assignments = _resolve_legacy_initial_values(map, values)
    return _complete_initial_parameters(_legacy_initial_registry(map), 1:nparameters(map), assignments)
end
function initial_parameters(context::_ParameterContext; values=Dict())
    map = context.parameter_map
    _check_parameter_map(context.template, map)
    if map isa ParameterMap
        assignments = _resolve_legacy_initial_values(map, values)
        return _complete_initial_parameters(_legacy_initial_registry(context.template, map), 1:nparameters(map), assignments)
    end
    return initial_parameters(map; values)
end
