# Numerical reverse passes for a shared unitary circuit acting on independent
# pure-state columns. Optional AD integrations register these helpers separately.
function _check_batch_circuit_adjoint(circuit::QCircuit)
    _check_circuit_adjoint(circuit)
    _has_quantum_map(circuit) &&
        throw(ArgumentError("BatchStateVector circuit differentiation supports unitary gates only; QuantumMap channels are not supported."))
    return nothing
end

function _batch_circuit_adjoint(circuit::QCircuit, initial::BatchStateVector)
    _check_batch_circuit_adjoint(circuit)
    saved_circuit = copy_instruction(circuit)
    output = saved_circuit * initial
    # The result is public mutable storage. Retain a private reconstruction
    # point so later result, input, or gate mutation cannot alter this pullback.
    saved_output = copy(output)
    slots = nparameters(saved_circuit)
    RT = typeof(real(zero(eltype(saved_output))))
    function back(seed)
        if isnothing(seed)
            return zeros(RT, slots), BatchStateVector(zeros(eltype(saved_output), size(storage(saved_output))), nqubits(initial))
        end
        data = seed isa BatchStateVector ? storage(seed) : seed
        data isa AbstractMatrix{<:Number} ||
            throw(ArgumentError("a batch circuit cotangent must be a matrix or BatchStateVector"))
        size(data) == size(storage(saved_output)) ||
            throw(DimensionMismatch("batch circuit cotangent must match the output shape"))
        T = promote_type(eltype(data), eltype(saved_output))
        state_gradient = Matrix{T}(undef, size(data))
        parameter_gradient = zeros(promote_type(RT, typeof(real(zero(T)))), slots)
        for column in 1:batch_size(saved_output)
            delta = StateVector(Vector{T}(view(data, :, column)), nqubits(saved_output))
            result = StateVector(Vector{T}(view(storage(saved_output), :, column)), nqubits(saved_output))
            delta, gradient, _ = back_propagate(delta, saved_circuit, result)
            parameter_gradient .+= gradient
            state_gradient[:, column] .= storage(delta)
        end
        return parameter_gradient, BatchStateVector(state_gradient, nqubits(saved_output))
    end
    return output, back
end

function _batch_single_expectation_pullback(observable::QubitsTerm, state::StateVector)
    if isempty(observable)
        value = expectation(observable, state)
        return value, seed -> (nothing,
            (conj(seed) * coeff(observable) + seed * conj(coeff(observable))) * state)
    end
    return _qterm_expec_util(observable, state)
end

_batch_single_expectation_pullback(observable::QubitsOperator, state::StateVector) =
    _qop_expec_util(observable, state)

function _batch_expectation_adjoint(observable::Union{QubitsTerm,QubitsOperator}, state::BatchStateVector)
    validate_positions(observable, nqubits(state))
    saved_observable = deepcopy(observable)
    T = promote_type(eltype(state), eltype(observable))
    # Keep this snapshot separate from both the caller and the returned values.
    saved_state = BatchStateVector(Matrix{T}(storage(state)), nqubits(state))
    values = expectation(saved_observable, saved_state)
    function back(seed)
        isnothing(seed) && return nothing,
            BatchStateVector(zeros(T, size(storage(saved_state))), nqubits(saved_state))
        seed isa AbstractVector{<:Number} ||
            throw(ArgumentError("a batch expectation cotangent must be a vector"))
        length(seed) == batch_size(saved_state) ||
            throw(DimensionMismatch("batch expectation cotangent must have one entry per sample"))
        Base.require_one_based_indexing(seed)
        CT = promote_type(T, eltype(seed))
        gradient = Matrix{CT}(undef, size(storage(saved_state)))
        for column in 1:batch_size(saved_state)
            # Complex cotangents can create complex intermediate operators even
            # when both the observable and original state are real.
            sample = StateVector(Vector{CT}(view(storage(saved_state), :, column)), nqubits(saved_state))
            _, sample_back = _batch_single_expectation_pullback(saved_observable, sample)
            _, sample_gradient = sample_back(seed[column])
            gradient[:, column] .= storage(sample_gradient)
        end
        return nothing, BatchStateVector(gradient, nqubits(saved_state))
    end
    return values, back
end

function _batch_qubit_encoding_adjoint(::Type{T}, inputs::AbstractMatrix{<:Real}) where {T<:Number}
    Base.require_one_based_indexing(inputs)
    all(isfinite, inputs) || throw(ArgumentError("encoding parameters must be finite"))
    saved_inputs = copy(inputs)
    n, count = size(saved_inputs)
    output = BatchStateVector(T, n, count)
    sample_backs = Function[]
    if n > 0
        for column in 1:count
            # Each closure owns both its old encoding angles and its output.
            # Copying into the public batch leaves those reconstruction points
            # independent of later caller or result mutation.
            sample, sample_back = _qubit_encoding_adjoint(T, saved_inputs[:, column])
            storage(output)[:, column] .= storage(sample)
            push!(sample_backs, sample_back)
        end
    end
    RT = promote_type(eltype(saved_inputs), typeof(real(zero(T))))
    function back(seed)
        isnothing(seed) && return zeros(RT, size(saved_inputs))
        data = seed isa BatchStateVector ? storage(seed) : seed
        data isa AbstractMatrix{<:Number} ||
            throw(ArgumentError("a batch encoding cotangent must be a matrix or BatchStateVector"))
        size(data) == size(storage(output)) ||
            throw(DimensionMismatch("batch encoding cotangent must match the output shape"))
        Base.require_one_based_indexing(data)
        gradient = zeros(promote_type(RT, typeof(real(zero(eltype(data))))), size(saved_inputs))
        if n > 0
            for column in 1:count
                _, sample_gradient = sample_backs[column](Vector(view(data, :, column)))
                gradient[:, column] .= sample_gradient
            end
        end
        return gradient
    end
    return output, back
end
