# Check both the public matrix and its CPU ordering before entering @inbounds
# kernels, even when the sample axis is empty.
function _check_batch_density_gate(operation::Gate, state::Union{BatchDensityMatrix,BatchStateVector})
    supports(CPUBackend(), operation, state) ||
        throw(UnsupportedOperation(CPUBackend(), operation, state, :apply))
    validate_positions(operation, nqubits(state))
    register = Tuple(positions(operation))
    length(register) == nqubits(operation) && length(unique(register)) == length(register) ||
        throw(ArgumentError("gate positions must be distinct and match its qubit count"))
    Tuple(ordered_positions(operation)) == Tuple(sort(collect(register))) ||
        throw(ArgumentError("ordered gate positions must match its register"))
    dimension = 2^nqubits(operation)
    for data in (mat(operation), ordered_mat(operation))
        size(data) == (dimension, dimension) ||
            throw(DimensionMismatch("gate matrix dimensions must match its qubit count"))
        all(isfinite, data) || throw(ArgumentError("gate matrices must be finite"))
    end
    return nothing
end

function _check_batch_density_channel(operation::QuantumMap,
                                      state::Union{BatchDensityMatrix,BatchStateVector})
    supports(CPUBackend(), operation, state) ||
        throw(UnsupportedOperation(CPUBackend(), operation, state, :apply))
    validate_positions(operation, nqubits(state))
    register = Tuple(positions(operation))
    length(register) == nqubits(operation) && length(unique(register)) == length(register) ||
        throw(ArgumentError("channel positions must be distinct and match its qubit count"))
    Tuple(ordered_positions(operation)) == Tuple(sort(collect(register))) ||
        throw(ArgumentError("ordered channel positions must match its register"))
    dimension = 2^nqubits(operation)
    isempty(kraus_matrices(operation)) && throw(ArgumentError("a channel needs at least one Kraus matrix"))
    for data in kraus_matrices(operation)
        size(data) == (dimension, dimension) ||
            throw(DimensionMismatch("Kraus matrix dimensions must match the channel register"))
        all(isfinite, data) || throw(ArgumentError("Kraus matrices must be finite"))
    end
    supermatrix = ordered_supermat(operation)
    size(supermatrix) == (dimension^2, dimension^2) ||
        throw(DimensionMismatch("channel supermatrix dimensions must match its register"))
    all(isfinite, supermatrix) || throw(ArgumentError("channel supermatrix must be finite"))
    return nothing
end

function _batch_density_execution_type(operation, state::BatchDensityMatrix)
    T = eltype(state)
    # Keep the state's floating precision, as scalar density execution does.
    # A Float32 state can already carry Float32 trace roundoff; widening its
    # wrapper after a Float64 gate would misrepresent that numerical accuracy.
    if typeof(real(zero(T))) <: AbstractFloat
        return T <: Real && eltype(operation) <: Complex ? Complex{T} : T
    end
    return promote_type(T, eltype(operation))
end

function _cpu_apply!(operation::Gate, state::BatchDensityMatrix)
    _check_batch_density_gate(operation, state)
    T = _batch_density_execution_type(operation, state)
    state = T == eltype(state) ? state : convert(BatchDensityMatrix{T}, state)
    for b in 1:batch_size(state)
        _dm_apply_threaded!(operation, vec(view(storage(state), :, :, b)), nqubits(state))
    end
    return state
end

function _cpu_apply!(operation::QuantumMap, state::BatchDensityMatrix)
    _check_batch_density_channel(operation, state)
    T = _batch_density_execution_type(operation, state)
    state = T == eltype(state) ? state : convert(BatchDensityMatrix{T}, state)
    for b in 1:batch_size(state)
        _qmap_apply_threaded!(operation, vec(view(storage(state), :, :, b)), nqubits(state))
    end
    return state
end

function _cpu_apply!(operation::QuantumMap, state::BatchStateVector)
    _check_batch_density_channel(operation, state)
    return _cpu_apply!(operation, BatchDensityMatrix(state))
end

function apply_dagger!(operation::QuantumMap, state::BatchDensityMatrix)
    _require_cpu_storage(state, operation)
    _check_batch_density_channel(operation, state)
    T = _batch_density_execution_type(operation, state)
    state = T == eltype(state) ? state : convert(BatchDensityMatrix{T}, state)
    for b in 1:batch_size(state)
        _qmap_apply_dagger_threaded!(operation, vec(view(storage(state), :, :, b)), nqubits(state))
    end
    return state
end

Base.:*(circuit::QCircuit, state::BatchDensityMatrix) = _apply_circuit_copy(circuit, state)
