# Four- and five-qubit gates use the same tested dispatcher as single states.
function _apply_gate_batch_long!(positions, mat, data, nq, bs)
    for i in 1:bs
        _apply_gate_threaded2!(positions, mat, view(data, :, i))
    end
    return data
end
