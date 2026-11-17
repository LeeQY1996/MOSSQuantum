function apply_serial!(x::Gate, batch::BatchStateVector)
    positions = ordered_positions(x)
    mat = ordered_mat(x)
    data = storage(batch)
    nq = nqubits(batch)
    bs = batch_size(batch)

    # Simple loop over batch, applying gate to each state
    for i in 1:bs
        state_vec = view(data, :, i)
        _apply_gate_batch_column!(positions, mat, state_vec)
    end
    return batch
end

"""
    apply_threaded!(x::Gate, batch::BatchStateVector)
Apply gate to batch of states with threading optimization.
Decision logic: if batch size is small, use threading within each state (existing threaded algorithm).
If batch size is large, thread over batch.
"""
function apply_threaded!(x::Gate, batch::BatchStateVector)
    positions = ordered_positions(x)
    mat = ordered_mat(x)
    data = storage(batch)
    nq = nqubits(batch)
    bs = batch_size(batch)
    state_size = size(data, 1)

    if isempty(positions)
        data .*= _zero_qubit_matrix_value(mat)
        return batch
    end

    # Decision logic
    if bs == 1
        # Single state, use existing threaded algorithm
        apply_threaded!(x, view(data, :, 1))
    elseif bs <= 4 && state_size >= 32
        # Small batch, large states: use specialized batch algorithm
        # For 1-3 qubit gates
        if length(positions) <= 3
            _apply_gate_batch_short!(positions, mat, data, nq, bs)
        else
            # For 4-5 qubit gates
            _apply_gate_batch_long!(positions, mat, data, nq, bs)
        end
    else
        # Larger batch: thread over batch
        _apply_gate_batch_threaded_over_batch!(positions, mat, data, nq, bs)
    end
    return batch
end

# The serial kernels cover up to four qubits. Five-qubit gates require the
# general dispatcher, including when parallelism is over batch columns.
function _apply_gate_batch_column!(positions, mat, state_vec)
    if length(positions) == 5
        _apply_gate_threaded2!(positions, mat, state_vec)
    else
        _apply_gate_2!(positions, mat, state_vec)
    end
end

function _apply_gate_batch_threaded_over_batch!(positions, mat, data, nq, bs)
    # Simple threading over batch, applying serial gate to each state
    Threads.@threads for i in 1:bs
        state_vec = view(data, :, i)
        _apply_gate_batch_column!(positions, mat, state_vec)
    end
end
