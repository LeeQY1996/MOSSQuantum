function _check_bound_instruction(result, expected)
    return QuantumCircuits._checked_reset_result(result, expected)
end

"""
    bind_parameters(instruction::AbstractInstruction, values::AbstractVector{<:Real})

Return an independent instruction with its active parameters replaced by `values`
in `active_parameters(instruction)` order. Frozen parameters retain their values.
The default uses the public `copy_instruction` and `reset_parameters!` hooks;
writers may return a replacement instruction, including an immutable one.

For circuits, nested instructions are visited in execution order and each
occurrence is bound separately. Repeated source references become independent
parameter slots rather than symbolic shared parameters. Parameterless
instructions are copied as well. The source instruction and parameter vector
are not modified. Values must be finite and match `nparameters(instruction)`.
"""
function bind_parameters(instruction::AbstractInstruction, values::AbstractVector{<:Real})
    expected = QuantumCircuits._check_parameter_values(instruction, values)
    copied = QuantumCircuits._checked_instruction_result(copy_instruction(instruction), :copy_instruction)
    # A writer may retain its input vector as storage. Give each occurrence an
    # owned vector so later edits to the caller's values cannot change the bind.
    return _check_bound_instruction(reset_parameters!(copied, collect(values)), expected)
end

function bind_parameters(circuit::QCircuit, values::AbstractVector{<:Real})
    expected = QuantumCircuits._check_parameter_values(circuit, values)
    instructions = AbstractInstruction[]
    pos = 0
    for instruction in circuit
        n = nparameters(instruction)
        push!(instructions, bind_parameters(instruction, view(values, pos+1:pos+n)))
        pos += n
    end
    return _check_bound_instruction(QCircuit(instructions), expected)
end
