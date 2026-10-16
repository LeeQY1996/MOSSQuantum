# Main expectation functions for BatchStateVector

function expectation(m::QubitsTerm, batch::BatchStateVector)
    isempty(m) && return coeff(m) .* dot(batch, batch)

    pos = positions(m)
    if length(pos) <= LARGEST_SUPPORTED_NTERMS_BATCH
        mat = _get_mat(m)
        # Convert Vector{Int} to Tuple for dispatch
        pos_tuple = tuple(pos...)
        return expectation_value(pos_tuple, mat, batch)
    else
        # Fallback for large terms
        bs = batch_size(batch)
        results = Vector{promote_type(eltype(batch), eltype(m))}(undef, bs)
        for i in 1:bs
            sv = StateVector(_batch_expectation_column(batch, i, eltype(results)), nqubits(batch))
            results[i] = dot(sv, m * sv)
        end
        return results
    end
end

function expectation(m::QubitsOperator, batch::BatchStateVector)
    if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS_BATCH
        bs = batch_size(batch)
        results = zeros(promote_type(eltype(batch), eltype(m)), bs)
        for (k, v) in m.data
            mat = _get_mat(length(k), v)
            term_results = expectation_value(k, mat, batch)
            results .+= term_results
        end
        return results
    else
        # Fallback for large terms
        bs = batch_size(batch)
        results = zeros(promote_type(eltype(batch), eltype(m)), bs)
        for i in 1:bs
            sv = StateVector(_batch_expectation_column(batch, i, eltype(results)), nqubits(batch))
            results[i] = expectation(m, sv)
        end
        return results
    end
end

function expectation(m::Gate, batch::BatchStateVector)
    pos = ordered_positions(m)
    mat = ordered_mat(m)
    return expectation_value(pos, mat, batch)
end

function expectation(m::AbstractMatrix, batch::BatchStateVector)
    bs = batch_size(batch)
    results = Vector{promote_type(eltype(batch), eltype(m))}(undef, bs)
    data = storage(batch)
    for i in 1:bs
        col = view(data, :, i)
        results[i] = dot(col, m, col)
    end
    return results
end

# Two-state batch expectation
function expectation(state_c::BatchStateVector, m::QubitsTerm, state::BatchStateVector)
    @assert batch_size(state_c) == batch_size(state) "Batch sizes must match"
    isempty(m) && return coeff(m) .* dot(state_c, state)

    pos = positions(m)
    if length(pos) <= LARGEST_SUPPORTED_NTERMS_BATCH
        mat = _get_mat(m)
        # Convert Vector{Int} to Tuple for dispatch
        pos_tuple = tuple(pos...)
        return expectation_value(pos_tuple, mat, state, state_c)
    else
        bs = batch_size(state)
        results = Vector{promote_type(eltype(state), eltype(state_c), eltype(m))}(undef, bs)
        for i in 1:bs
            sv_c = StateVector(_batch_expectation_column(state_c, i, eltype(results)), nqubits(state_c))
            sv = StateVector(_batch_expectation_column(state, i, eltype(results)), nqubits(state))
            results[i] = expectation(sv_c, m, sv)
        end
        return results
    end
end

function expectation(state_c::BatchStateVector, m::QubitsOperator, state::BatchStateVector)
    @assert batch_size(state_c) == batch_size(state) "Batch sizes must match"

    if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS_BATCH
        bs = batch_size(state)
        results = zeros(promote_type(eltype(state), eltype(state_c), eltype(m)), bs)
        for (k, v) in m.data
            mat = _get_mat(length(k), v)
            term_results = expectation_value(k, mat, state, state_c)
            results .+= term_results
        end
        return results
    else
        bs = batch_size(state)
        results = zeros(promote_type(eltype(state), eltype(state_c), eltype(m)), bs)
        for i in 1:bs
            sv_c = StateVector(_batch_expectation_column(state_c, i, eltype(results)), nqubits(state_c))
            sv = StateVector(_batch_expectation_column(state, i, eltype(results)), nqubits(state))
            results[i] = expectation(sv_c, m, sv)
        end
        return results
    end
end

function expectation(state_c::BatchStateVector, m::Gate, state::BatchStateVector)
    @assert batch_size(state_c) == batch_size(state) "Batch sizes must match"
    pos = ordered_positions(m)
    mat = ordered_mat(m)
    return expectation_value(pos, mat, state, state_c)
end

function expectation(state_c::BatchStateVector, m::AbstractMatrix, state::BatchStateVector)
    @assert batch_size(state_c) == batch_size(state) "Batch sizes must match"
    bs = batch_size(state)
    results = Vector{promote_type(eltype(state), eltype(state_c), eltype(m))}(undef, bs)
    data_c = storage(state_c)
    data = storage(state)
    for i in 1:bs
        col_c = view(data_c, :, i)
        col = view(data, :, i)
        results[i] = dot(col_c, m, col)
    end
    return results
end