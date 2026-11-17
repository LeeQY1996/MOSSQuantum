export AbstractInstruction, validate_positions, copy_instruction

"""
    AbstractInstruction <: QuantumOperation

An operation that can be stored in a `QCircuit`. Extend this type for a new
instruction, and implement `positions` and the execution methods for its backend.
Hamiltonian terms and operators are `QuantumOperation`s, but are not instructions.

Instructions have no parameters by default. Parameterized instructions must
implement the parameter interface as well as their backend execution methods.
"""
abstract type AbstractInstruction <: QuantumOperation end

function nparameters(instruction::AbstractInstruction)
    values = active_parameters(instruction)
    return isnothing(values) ? 0 : length(values)
end
parameters(::AbstractInstruction) = nothing
active_parameters(::AbstractInstruction) = nothing
activate_parameter!(x::AbstractInstruction, ::Int) = x
activate_parameters!(x::AbstractInstruction) = x
deactivate_parameter!(x::AbstractInstruction, ::Int) = x
deactivate_parameters!(x::AbstractInstruction) = x

"""
    copy_instruction(instruction::AbstractInstruction)

Return an independently mutable copy of an instruction. The default is
`deepcopy`; extensions may specialize this hook for their own resource or
storage ownership. Circuit copies visit each instruction occurrence separately,
including repeated references and nested circuits. This differs from the shallow
`copy(circuit)` container operation.
"""
copy_instruction(instruction::AbstractInstruction) = deepcopy(instruction)

function _check_parameter_values(instruction::AbstractInstruction, values::AbstractVector{<:Real})
    expected = nparameters(instruction)
    length(values) == expected ||
        throw(DimensionMismatch("expected $expected active parameters, received $(length(values))."))
    all(isfinite, values) || throw(ArgumentError("parameter values must be finite."))
    return expected
end

function _checked_instruction_result(result, operation::Symbol)
    result isa AbstractInstruction ||
        throw(ArgumentError("$operation must return an AbstractInstruction, received $(typeof(result))."))
    return result
end

function _checked_reset_result(result, expected)
    instruction = _checked_instruction_result(result, :reset_parameters!)
    nparameters(instruction) == expected ||
        throw(ArgumentError("parameter reset must preserve the number of active parameters."))
    values = active_parameters(instruction)
    (isnothing(values) || all(isfinite, values)) ||
        throw(ArgumentError("parameter values must remain finite in the instruction's parameter storage."))
    return instruction
end

"""
    reset_parameters!(instruction::AbstractInstruction, values::AbstractVector{<:Real})

Replace the active parameters in `active_parameters(instruction)` order. Frozen
parameters retain their values. Implement this public method for a trainable
external instruction; no particular parameter fields or private helper methods
are required. Mutable implementations may update and return `instruction`;
immutable implementations return a replacement instruction. Always retain the
return value. Values must be finite and have length `nparameters(instruction)`.

The fallback accepts parameterless instructions and preserves the legacy reset
helper adapter for existing gate implementations.
"""
function reset_parameters!(instruction::AbstractInstruction, values::AbstractVector{<:Real})
    expected = _check_parameter_values(instruction, values)
    expected == 0 && return instruction
    consumed = reset_parameters_util!(instruction, collect(values), 0)
    consumed == expected ||
        throw(ArgumentError("$(typeof(instruction)) must implement reset_parameters!(instruction, values)."))
    return _checked_reset_result(instruction, expected)
end

function reset_parameters_util!(instruction::AbstractInstruction, ::Vector{<:Real}, pos::Int)
    nparameters(instruction) == 0 && return pos
    throw(ArgumentError("$(typeof(instruction)) must implement reset_parameters!(instruction, values)."))
end

"""
    validate_positions(operation, nqubits) -> nothing

Check that every position reported by an operation is an integer in
`1:nqubits`. This checks register bounds only; each backend separately determines
which instruction types and arities it implements. Empty position lists are
valid, for example for an empty circuit or an instruction with no quantum inputs.
"""
function validate_positions(operation, n::Integer)
    n >= 0 || throw(ArgumentError("the number of qubits must be nonnegative"))
    for position in positions(operation)
        position isa Integer || throw(ArgumentError("qubit positions must be integers"))
        1 <= position <= n || throw(ArgumentError("qubit position $position must be between 1 and $n"))
    end
    return nothing
end
