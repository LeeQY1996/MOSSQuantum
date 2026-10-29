# Main expectation functions for BatchStateVector

function _check_batch_observable(observable, batch::_DenseBatchState)
    validate_positions(observable, nqubits(batch))
    if observable isa Union{Gate,QubitsTerm}
        register = Tuple(positions(observable))
        length(unique(register)) == length(register) ||
            throw(ArgumentError("observable positions must be distinct"))
    end
    if observable isa Gate
        length(register) == nqubits(observable) ||
            throw(ArgumentError("gate observable positions must match its qubit count"))
        0 <= nqubits(observable) <= 5 ||
            throw(UnsupportedOperation(CPUBackend(), observable, batch, :expectation))
        dimension = 2^nqubits(observable)
        size(mat(observable)) == (dimension, dimension) ||
            throw(DimensionMismatch("gate observable dimensions must match its register"))
        Tuple(ordered_positions(observable)) == Tuple(sort(collect(register))) ||
            throw(ArgumentError("ordered observable positions must match its register"))
        size(ordered_mat(observable)) == (dimension, dimension) ||
            throw(DimensionMismatch("ordered gate observable dimensions must match its register"))
    elseif observable isa QubitsTerm
        length(oplist(observable)) == length(positions(observable)) ||
            throw(DimensionMismatch("observable factors must match their registers"))
        all(matrix -> size(matrix) == (2, 2), oplist(observable)) ||
            throw(DimensionMismatch("observable factors must be single-qubit matrices"))
    elseif observable isa QubitsOperator
        for (register, terms) in observable.data, (operators, _) in terms
            length(unique(register)) == length(register) ||
                throw(ArgumentError("observable positions must be distinct"))
            length(operators) == length(register) && all(matrix -> size(matrix) == (2, 2), operators) ||
                throw(DimensionMismatch("observable factors must match their registers"))
        end
    end
    return nothing
end

function _check_batch_observable(observable::AbstractMatrix, batch::_DenseBatchState)
    dimension = size(storage(batch), 1)
    size(observable) == (dimension, dimension) ||
        throw(DimensionMismatch("observable dimensions must match the batch register"))
    return nothing
end

function _cpu_expectation(m::QubitsTerm, batch::BatchStateVector)
    _check_batch_observable(m, batch)
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

function _cpu_expectation(m::QubitsOperator, batch::BatchStateVector)
    _check_batch_observable(m, batch)
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

function _cpu_expectation(m::Gate, batch::BatchStateVector)
    _check_batch_observable(m, batch)
    pos = ordered_positions(m)
    mat = ordered_mat(m)
    return expectation_value(pos, mat, batch)
end

function _cpu_expectation(m::AbstractMatrix, batch::BatchStateVector)
    _check_batch_observable(m, batch)
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
function _cpu_cross_expectation(state_c::BatchStateVector, m::QubitsTerm, state::BatchStateVector)
    _check_batch_pair(state_c, state)
    _check_batch_observable(m, state)
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

function _cpu_cross_expectation(state_c::BatchStateVector, m::QubitsOperator, state::BatchStateVector)
    _check_batch_pair(state_c, state)
    _check_batch_observable(m, state)

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

function _cpu_cross_expectation(state_c::BatchStateVector, m::Gate, state::BatchStateVector)
    _check_batch_pair(state_c, state)
    _check_batch_observable(m, state)
    pos = ordered_positions(m)
    mat = ordered_mat(m)
    return expectation_value(pos, mat, state, state_c)
end

function _cpu_cross_expectation(state_c::BatchStateVector, m::AbstractMatrix, state::BatchStateVector)
    _check_batch_pair(state_c, state)
    _check_batch_observable(m, state)
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
