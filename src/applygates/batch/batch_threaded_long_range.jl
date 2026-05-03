# Batch versions of 4-5 qubit gate operations

# For four-qubit gate
function _apply_gate_batch_long!(key::Tuple{Int, Int, Int, Int}, U::AbstractMatrix, data::AbstractMatrix, _nq::Int, bs::Int)
    # Simple implementation: loop over batch and apply gate to each state
    for i in 1:bs
        state_vec = view(data, :, i)
        _apply_fourbody_gate_impl!(key, SMatrix{16,16, eltype(data)}(U), state_vec)
    end
    return data
end

# For five-qubit gate
function _apply_gate_batch_long!(key::Tuple{Int, Int, Int, Int, Int}, U::AbstractMatrix, data::AbstractMatrix, _nq::Int, bs::Int)
    # Simple implementation: loop over batch and apply gate to each state
    for i in 1:bs
        state_vec = view(data, :, i)
        _apply_fivebody_gate_impl!(key, SMatrix{32,32, eltype(data)}(U), state_vec)
    end
    return data
end

# Threaded version over batch for 4-5 qubit gates
function _apply_gate_batch_long_threaded!(key, U::AbstractMatrix, data::AbstractMatrix, _nq::Int, bs::Int)
    Threads.@threads for i in 1:bs
        state_vec = view(data, :, i)
        if length(key) == 4
            _apply_fourbody_gate_impl!(key, SMatrix{16,16, eltype(data)}(U), state_vec)
        elseif length(key) == 5
            _apply_fivebody_gate_impl!(key, SMatrix{32,32, eltype(data)}(U), state_vec)
        else
            error("Unsupported number of qubits: $(length(key))")
        end
    end
    return data
end

# Main dispatcher function for 4-5 qubit gates
function _apply_gate_batch_long!(positions, mat, data, nq, bs)
    # Simple threading strategy: if batch size is large enough, thread over batch
    # Otherwise use serial loop
    if bs >= 8
        return _apply_gate_batch_long_threaded!(positions, mat, data, nq, bs)
    else
        if length(positions) == 4
            return _apply_gate_batch_long!(positions, mat, data, nq, bs)
        elseif length(positions) == 5
            return _apply_gate_batch_long!(positions, mat, data, nq, bs)
        else
            error("Unsupported number of qubits: $(length(positions))")
        end
    end
end