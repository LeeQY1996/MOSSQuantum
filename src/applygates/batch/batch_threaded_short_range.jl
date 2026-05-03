# Batch versions of 1-3 qubit gate operations

# For single qubit gate
function _apply_gate_batch_short!(key::Int, U::AbstractMatrix, data::AbstractMatrix, nq::Int, bs::Int)
    # Simple implementation: loop over batch and apply gate to each state
    for i in 1:bs
        state_vec = view(data, :, i)
        if key > 3
            _apply_onebody_gate_H!(key, SMatrix{2,2, eltype(data)}(transpose(U)), state_vec)
        else
            _apply_onebody_gate_L!(key, SMatrix{2,2, eltype(data)}(U), state_vec)
        end
    end
    return data
end

function _apply_gate_batch_short!(key::Tuple{Int}, U::AbstractMatrix, data::AbstractMatrix, nq::Int, bs::Int)
    return _apply_gate_batch_short!(key[1], U, data, nq, bs)
end

# For two-qubit gate
function _apply_gate_batch_short!(key::Tuple{Int, Int}, U::AbstractMatrix, data::AbstractMatrix, nq::Int, bs::Int)
    q1, q2 = key
    for i in 1:bs
        state_vec = view(data, :, i)
        if q1 > 3 && q2 > 3
            _apply_twobody_gate_HH!(key, U, state_vec)
        elseif q1 <= 3 && q2 > 3
            _apply_twobody_gate_LH!(key, U, state_vec)
        else
            _apply_twobody_gate_LL!(key, U, state_vec)
        end
    end
    return data
end

# For three-qubit gate
function _apply_gate_batch_short!(key::Tuple{Int, Int, Int}, U::AbstractMatrix, data::AbstractMatrix, nq::Int, bs::Int)
    q1, q2, q3 = key
    for i in 1:bs
        state_vec = view(data, :, i)
        if q1 > 3 && q2 > 3 && q3 > 3
            _apply_threebody_gate_HHH!(key, U, state_vec)
        elseif q1 <= 3 && q2 > 3 && q3 > 3
            _apply_threebody_gate_LHH!(key, U, state_vec)
        elseif q1 <= 3 && q2 <= 3 && q3 > 3
            _apply_threebody_gate_LLH!(key, U, state_vec)
        else
            _apply_threebody_gate_LLL!(key, U, state_vec)
        end
    end
    return data
end

# Threaded version over batch
function _apply_gate_batch_short_threaded!(key, U::AbstractMatrix, data::AbstractMatrix, nq::Int, bs::Int)
    Threads.@threads for i in 1:bs
        state_vec = view(data, :, i)
        if isa(key, Int)
            if key > 3
                _apply_onebody_gate_H!(key, SMatrix{2,2, eltype(data)}(transpose(U)), state_vec)
            else
                _apply_onebody_gate_L!(key, SMatrix{2,2, eltype(data)}(U), state_vec)
            end
        elseif length(key) == 1
            k = key[1]
            if k > 3
                _apply_onebody_gate_H!(k, SMatrix{2,2, eltype(data)}(transpose(U)), state_vec)
            else
                _apply_onebody_gate_L!(k, SMatrix{2,2, eltype(data)}(U), state_vec)
            end
        elseif length(key) == 2
            q1, q2 = key
            if q1 > 3 && q2 > 3
                _apply_twobody_gate_HH!(key, U, state_vec)
            elseif q1 <= 3 && q2 > 3
                _apply_twobody_gate_LH!(key, U, state_vec)
            else
                _apply_twobody_gate_LL!(key, U, state_vec)
            end
        elseif length(key) == 3
            q1, q2, q3 = key
            if q1 > 3 && q2 > 3 && q3 > 3
                _apply_threebody_gate_HHH!(key, U, state_vec)
            elseif q1 <= 3 && q2 > 3 && q3 > 3
                _apply_threebody_gate_LHH!(key, U, state_vec)
            elseif q1 <= 3 && q2 <= 3 && q3 > 3
                _apply_threebody_gate_LLH!(key, U, state_vec)
            else
                _apply_threebody_gate_LLL!(key, U, state_vec)
            end
        end
    end
    return data
end

# Main dispatcher function
function _apply_gate_batch_short!(positions, mat, data, nq, bs)
    # Simple threading strategy: if batch size is large enough, thread over batch
    # Otherwise use serial loop
    if bs >= 8
        return _apply_gate_batch_short_threaded!(positions, mat, data, nq, bs)
    else
        if isa(positions, Int)
            return _apply_gate_batch_short!(positions, mat, data, nq, bs)
        elseif length(positions) == 1
            return _apply_gate_batch_short!(positions[1], mat, data, nq, bs)
        elseif length(positions) == 2
            return _apply_gate_batch_short!(positions, mat, data, nq, bs)
        elseif length(positions) == 3
            return _apply_gate_batch_short!(positions, mat, data, nq, bs)
        else
            error("Unsupported number of qubits: $(length(positions))")
        end
    end
end