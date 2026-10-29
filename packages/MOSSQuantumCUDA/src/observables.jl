function MOSSQuantum.expectation(backend::CUDABackend, gate::MOSSQuantum.Gate, state::CUDAState)
    _require_support(backend, gate, state; action=:expectation)
    prepared = _prepare_gate(gate, eltype(state), MOSSQuantum.nqubits(state); preserve_precision=false)
    data = MOSSQuantum.storage(state)
    return dot(data, _gate_output(data, prepared))
end

function _prepare_term(term::MOSSQuantum.QubitsTerm, ::Type{T}, n) where T
    pos = MOSSQuantum.positions(term)
    length(pos) == length(MOSSQuantum.oplist(term)) || throw(DimensionMismatch("observable positions and factors must match"))
    length(unique(pos)) == length(pos) || throw(ArgumentError("observable positions must be distinct"))
    MOSSQuantum.validate_positions(term, n)
    coefficient = MOSSQuantum.coeff(term)
    isfinite(coefficient) || throw(ArgumentError("observable coefficient must be finite"))
    R = promote_type(T, eltype(term))
    R <: Scalar || throw(ArgumentError("observable promotion is unsupported on CUDA"))
    plan = PreparedGate[]
    for (position, matrix) in zip(pos, MOSSQuantum.oplist(term))
        size(matrix) == (2, 2) || throw(DimensionMismatch("term factors must be 2 × 2 matrices"))
        push!(plan, _prepare_matrix(matrix, (position,), R, n; preserve_precision=false))
    end
    return plan, coefficient, R
end

function _term_expectation(state, prepared)
    plan, coefficient, T = prepared
    source = MOSSQuantum.storage(state)
    if isempty(plan)
        return coefficient * dot(source, source)
    end
    data = source
    for gate in plan
        data = _gate_output(data, gate)
    end
    return coefficient * dot(source, data)
end

function MOSSQuantum.expectation(backend::CUDABackend, term::MOSSQuantum.QubitsTerm, state::CUDAState)
    _require_support(backend, term, state; action=:expectation)
    return _term_expectation(state, _prepare_term(term, eltype(state), MOSSQuantum.nqubits(state)))
end

function MOSSQuantum.expectation(backend::CUDABackend, operator::MOSSQuantum.QubitsOperator, state::CUDAState)
    _require_support(backend, operator, state; action=:expectation)
    # QubitsOperator stores descriptions of tensor-product terms. Never form a
    # register-sized host matrix or access any CPU simulation kernel.
    prepared = [_prepare_term(MOSSQuantum.QubitsTerm(collect(positions), matrices, coefficient),
                             eltype(state), MOSSQuantum.nqubits(state))
                for (positions, entries) in operator.data for (matrices, coefficient) in entries]
    result = zero(promote_type(eltype(state), eltype(operator)))
    for term in prepared
        result += _term_expectation(state, term)
    end
    return result
end

"""Return host readout probabilities; state amplitudes and marginalization stay on the GPU."""
function MOSSQuantum.probabilities(backend::CUDABackend, state::CUDAState; qubits=1:MOSSQuantum.nqubits(state))
    _require_support(backend, MOSSQuantum.probabilities, state; action=:probabilities)
    n = MOSSQuantum.nqubits(state)
    indices = _readout_positions(qubits, n)
    data = MOSSQuantum.storage(state)
    # Reductions run on the GPU. Only the requested distribution crosses back.
    weights = Float64.(abs2.(data))
    values = if isempty(indices)
        [sum(weights)]
    elseif indices == collect(1:n)
        Array(weights)
    else
        other = setdiff(collect(1:n), indices)
        tensor = reshape(weights, ntuple(_ -> 2, n))
        ordered = permutedims(tensor, Tuple(vcat(indices, other)))
        marginal = sum(reshape(ordered, 1 << length(indices), :); dims=2)
        Array(vec(marginal))
    end
    return _normalize_readout!(values, eltype(state))
end
