# Each instruction occurrence gets its own copy, even when the source circuit
# contains the same gate object more than once. A single deepcopy(circuit) would
# preserve those aliases and let the final parameter assignment overwrite them.
_copy_parameter_occurrences(instruction) = deepcopy(instruction)
_copy_parameter_occurrences(circuit::QCircuit) =
    QCircuit([_copy_parameter_occurrences(instruction) for instruction in circuit])

"""
    bind_parameters(circuit::QCircuit, values::AbstractVector{<:Real}) -> QCircuit

Return an independent circuit with its active parameters replaced by `values`,
in the traversal order returned by `active_parameters(circuit)`. Inactive
parameters retain their values. Nested circuits are traversed in execution order.

Each occurrence of an instruction is copied independently, including repeated
references to the same gate. This API assigns independent parameter slots rather
than symbolic shared parameters. The input circuit and parameter vector are not
modified. Values must be finite and match `nparameters(circuit)`.
"""
function bind_parameters(circuit::QCircuit, values::AbstractVector{<:Real})
    expected = nparameters(circuit)
    length(values) == expected ||
        throw(DimensionMismatch("expected $expected active parameters, received $(length(values))."))
    all(isfinite, values) || throw(ArgumentError("parameter values must be finite."))
    result = _copy_parameter_occurrences(circuit)
    reset_parameters!(result, collect(values))
    all(isfinite, active_parameters(result)) ||
        throw(ArgumentError("parameter values must remain finite in the circuit's parameter storage."))
    return result
end
