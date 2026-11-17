"""
    fuse_gates(circuit::QCircuit; max_qubits::Int=5) -> QCircuit

Combine adjacent nonparameterized gates while their combined support contains at
most `max_qubits` qubits. The returned circuit has the same operation order and
leaves the input circuit unchanged. Parameterized gates, channels, measurements,
and postselections separate fusion blocks; nested circuits are fused recursively.
`max_qubits` must be between 1 and the simulator limit of 5.
"""
function fuse_gates(circuit::QCircuit; max_qubits::Int=5)
    1 <= max_qubits <= 5 || throw(ArgumentError("max_qubits must be between 1 and 5."))
    result = QCircuit()
    pending = nothing
    for operation in circuit
        eligible = operation isa Gate && parameters(operation) === nothing && nqubits(operation) <= max_qubits
        if !eligible
            if pending !== nothing
                push!(result, pending)
                pending = nothing
            end
            push!(result, operation isa QCircuit ? fuse_gates(operation; max_qubits=max_qubits) : operation)
        elseif pending === nothing
            pending = operation
        else
            support = sort!(unique!([positions(pending)..., positions(operation)...]))
            if length(support) <= max_qubits
                combined = _fusion_matrix(operation, support) * _fusion_matrix(pending, support)
                pending = QuantumGate(Tuple(support), combined)
            else
                push!(result, pending)
                pending = operation
            end
        end
    end
    pending === nothing || push!(result, pending)
    return result
end

# Embed a gate in the sorted union of a fusion block's qubits. The first qubit
# remains the least significant bit, as in StateVector and ordered_mat.
function _fusion_matrix(g::Gate, support::Vector{Int})
    pos = ordered_positions(g)
    data = ordered_mat(g)
    pos == Tuple(support) && return data
    bits = [searchsortedfirst(support, p) - 1 for p in pos]
    mask = sum(1 << bit for bit in bits)
    dim = 1 << length(support)
    local_dim = 1 << length(bits)
    result = zeros(eltype(data), dim, dim)
    for column in 0:(dim - 1)
        local_column = sum(((column >> bit) & 1) << (j - 1) for (j, bit) in enumerate(bits))
        remainder = column & ~mask
        for local_row in 0:(local_dim - 1)
            row = remainder
            for (j, bit) in enumerate(bits)
                row |= ((local_row >> (j - 1)) & 1) << bit
            end
            result[row + 1, column + 1] = data[local_row + 1, local_column + 1]
        end
    end
    return result
end
