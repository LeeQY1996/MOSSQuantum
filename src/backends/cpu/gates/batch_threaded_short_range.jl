# Reuse the single-state dispatcher so its position thresholds and matrix
# orientation conventions also apply to every column of a batch.
function _apply_gate_batch_short!(positions, mat, data, nq, bs)
    for i in 1:bs
        _apply_gate_threaded2!(positions, mat, view(data, :, i))
    end
    return data
end
