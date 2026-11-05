"""A parameter map expands independent inputs into active instruction slots."""
abstract type AbstractParameterMap end

"""
    ParameterMap(indices)
    ParameterMap(template::AbstractInstruction)
    ParameterMap(template::AbstractInstruction, indices)

Map each active parameter slot, in `active_parameters(template)` order, to an
independent parameter index. Indices must use every integer in `1:k`; repeated
indices explicitly share a value. For example, `[1, 2, 1]` maps three slots to
two independent values. An empty map has no slots or independent values.

The map is an immutable snapshot of its indices. `length(map)` counts slots and
`nparameters(map)` counts independent values. `parameter_indices(map)` returns
an independent vector. `ParameterMap(template)` creates an identity map; the
two-argument constructor also checks the current number of active slots.

Maps are separate from circuits and do not imply shared mutable gate storage.
After changing instruction order or activation, rebuild or review the map.
Binding detects slot-count mismatches, but cannot detect a changed layout with
the same number of slots.
"""
struct ParameterMap <: AbstractParameterMap
    indices::Tuple{Vararg{Int}}
    count::Int

    function ParameterMap(indices::Union{AbstractVector{<:Integer},Tuple{Vararg{Integer}}})
        slots = length(indices)
        # Bound indices before conversion or allocation based on their values.
        all(index -> !(index isa Bool) && 1 <= index <= slots, indices) ||
            throw(ArgumentError("parameter indices must be positive integers in 1:$slots; Bool indices are not supported."))
        stored = Tuple(Int(index) for index in indices)
        count = isempty(stored) ? 0 : maximum(stored)
        length(unique(stored)) == count ||
            throw(ArgumentError("parameter indices must use every integer in 1:$count; missing identities are not allowed."))
        return new(stored, count)
    end
end

ParameterMap(indices::Union{AbstractVector,Tuple}) =
    throw(ArgumentError("parameter indices must be integers."))

function _check_parameter_map(template::AbstractInstruction, map::AbstractParameterMap)
    expected = nparameters(template)
    length(map) == expected ||
        throw(DimensionMismatch("expected $expected active parameter slots, received a map with $(length(map)) slots."))
    return map
end

function ParameterMap(template::AbstractInstruction)
    QuantumCircuits._has_parameterized(template) && throw(ArgumentError("named parameter templates compile their own affine map; use compile_parameters"))
    return ParameterMap(collect(1:nparameters(template)))
end
ParameterMap(template::AbstractInstruction, indices) = _check_parameter_map(template, ParameterMap(indices))

Base.length(map::ParameterMap) = length(map.indices)
Base.copy(map::ParameterMap) = map
Base.:(==)(left::ParameterMap, right::ParameterMap) = left.indices == right.indices
Base.hash(map::ParameterMap, seed::UInt) = hash(map.indices, hash(ParameterMap, seed))
QuantumCircuits.nparameters(map::ParameterMap) = map.count

"""
    parameter_indices(map::ParameterMap) -> Vector{Int}

Return an independent vector of the parameter identity for each active slot.
Changing this vector does not change `map`.
"""
parameter_indices(map::ParameterMap) = Int[map.indices...]

"""Return independent input IDs in vector-binding order."""
parameter_order(map::ParameterMap) = collect(1:nparameters(map))
independent_parameters(map::ParameterMap) = parameter_order(map)
trainable_parameters(map::ParameterMap) = parameter_order(map)
_is_symbolic_map(::AbstractParameterMap) = false
_parameter_row(map::ParameterMap, slot::Integer) = (map.indices[slot] => 1,)

"""
    expand_parameters(map::AbstractParameterMap, values)

Expand independent inputs into active gate-slot order. Integer maps gather
shared inputs; compiled affine maps also apply coefficients and offsets.
"""
function expand_parameters(map::ParameterMap, values::AbstractVector{<:Real})
    Base.require_one_based_indexing(values)
    length(values) == nparameters(map) || throw(DimensionMismatch("expected $(nparameters(map)) independent parameters, received $(length(values))."))
    all(isfinite, values) || throw(ArgumentError("parameter values must be finite."))
    return [values[index] for index in map.indices]
end

"""
    accumulate_parameter_gradients(map::ParameterMap, slot_gradients::AbstractVector{<:Real})

Sum active-slot gradients into independent-parameter order. Each slot contributes
to the identity given by `parameter_indices(map)`. The input must contain
`length(map)` entries; the result has `nparameters(map)` entries. Neither input
is modified. Nonfinite gradients propagate through the sums.

This reduction is independent of an AD framework or simulator backend. It does
not establish derivative support for an instruction or backend by itself.
"""
function accumulate_parameter_gradients(map::ParameterMap, slot_gradients::AbstractVector{<:Real})
    length(slot_gradients) == length(map) ||
        throw(DimensionMismatch("expected $(length(map)) slot gradients, received $(length(slot_gradients))."))
    T = eltype(slot_gradients)
    if !isconcretetype(T)
        T = isempty(slot_gradients) ? Float64 : mapreduce(typeof, promote_type, slot_gradients)
    end
    # Bool is Real too; repeated Boolean contributions require integer sums.
    RT = typeof(zero(T) + zero(T))
    result = zeros(RT, nparameters(map))
    for (index, gradient) in zip(map.indices, slot_gradients)
        result[index] += gradient
    end
    return result
end
