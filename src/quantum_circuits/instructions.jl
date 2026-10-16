export AbstractInstruction, validate_positions

"""
    AbstractInstruction <: QuantumOperation

An operation that can be stored in a `QCircuit`. Extend this type for a new
instruction, and implement `positions` and the execution methods for its backend.
Hamiltonian terms and operators are `QuantumOperation`s, but are not instructions.

Instructions have no parameters by default. Parameterized instructions must
implement the parameter interface as well as their backend execution methods.
"""
abstract type AbstractInstruction <: QuantumOperation end

nparameters(::AbstractInstruction) = 0
parameters(::AbstractInstruction) = nothing
active_parameters(::AbstractInstruction) = nothing
activate_parameter!(x::AbstractInstruction, ::Int) = x
activate_parameters!(x::AbstractInstruction) = x
deactivate_parameter!(x::AbstractInstruction, ::Int) = x
deactivate_parameters!(x::AbstractInstruction) = x
reset_parameters_util!(::AbstractInstruction, ::Vector{<:Real}, pos::Int) = pos

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
