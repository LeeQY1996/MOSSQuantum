# Numerical reverse passes for independent samples. Optional AD integrations
# register these helpers without becoming a dependency of circuit execution.
function _check_batch_circuit_adjoint(circuit::QCircuit)
    _check_circuit_adjoint(circuit)
    return nothing
end

_batch_sample(state::BatchStateVector, column::Int, ::Type{T}=eltype(state)) where {T<:Number} =
    StateVector(Vector{T}(view(storage(state), :, column)), nqubits(state))
_batch_sample(state::BatchDensityMatrix, column::Int, ::Type{T}=eltype(state)) where {T<:Number} =
    DensityMatrix(Matrix{T}(view(storage(state), :, :, column)), nqubits(state))
_batch_wrap(data, state::BatchStateVector) = BatchStateVector(data, nqubits(state))
_batch_wrap(data, state::BatchDensityMatrix) = BatchDensityMatrix(data, nqubits(state))

function _batch_circuit_seed(seed, output)
    data = seed isa Union{BatchStateVector,BatchDensityMatrix} ? storage(seed) : seed
    data isa AbstractArray{<:Number} && ndims(data) == ndims(storage(output)) ||
        throw(ArgumentError("a batch circuit cotangent must be a numerical array or batch state"))
    size(data) == size(storage(output)) ||
        throw(DimensionMismatch("batch circuit cotangent must match the output shape"))
    Base.require_one_based_indexing(data)
    return data
end

function _batch_circuit_adjoint(circuit::QCircuit, initial::Union{BatchStateVector,BatchDensityMatrix})
    _check_batch_circuit_adjoint(circuit)
    saved_circuit = copy_instruction(circuit)
    if _has_quantum_map(saved_circuit)
        return _batch_channel_circuit_adjoint(saved_circuit, initial)
    end
    output = saved_circuit * initial
    # Public output storage never doubles as a retained reconstruction point.
    saved_output = copy(output)
    slots = nparameters(saved_circuit)
    RT = typeof(real(zero(eltype(saved_output))))
    function back(seed)
        if isnothing(seed)
            return zeros(RT, slots), _batch_wrap(zeros(eltype(saved_output), size(storage(initial))), initial)
        end
        data = _batch_circuit_seed(seed, saved_output)
        T = promote_type(eltype(data), eltype(saved_output))
        seed_state = _batch_wrap(data, saved_output)
        state_gradient = Array{T}(undef, size(data))
        parameter_gradient = zeros(promote_type(RT, typeof(real(zero(T)))), slots)
        for column in 1:batch_size(saved_output)
            delta = _batch_sample(seed_state, column, T)
            result = _batch_sample(saved_output, column, T)
            delta, gradient, _ = back_propagate(delta, saved_circuit, result)
            parameter_gradient .+= gradient
            selectdim(state_gradient, ndims(state_gradient), column) .= storage(delta)
        end
        return parameter_gradient, _batch_wrap(state_gradient, initial)
    end
    return output, back
end

function _batch_channel_circuit_adjoint(saved_circuit::QCircuit,
                                        initial::Union{BatchStateVector,BatchDensityMatrix})
    count = batch_size(initial)
    slots = nparameters(saved_circuit)
    # Reuse the proven single-state checkpoint reverse pass. In particular,
    # complete damping and other singular channels are valid fixed maps.
    sample_outputs = Union{StateVector,DensityMatrix}[]
    sample_backs = Function[]
    for column in 1:count
        result, sample_back = _circuit_adjoint(saved_circuit, _batch_sample(initial, column))
        push!(sample_outputs, result)
        push!(sample_backs, sample_back)
    end
    output = if count == 0
        saved_circuit * copy(initial)
    else
        BatchDensityMatrix(DensityMatrix[result for result in sample_outputs])
    end
    input_shape = size(storage(initial))
    RT = typeof(real(zero(eltype(output))))
    function back(seed)
        isnothing(seed) && return zeros(RT, slots), _batch_wrap(zeros(eltype(output), input_shape), initial)
        data = _batch_circuit_seed(seed, output)
        T = promote_type(eltype(data), eltype(output))
        gradient = zeros(T, input_shape)
        parameters = zeros(promote_type(RT, typeof(real(zero(T)))), slots)
        for column in 1:count
            delta = DensityMatrix(Matrix{T}(view(data, :, :, column)), nqubits(initial))
            sample_parameters, sample_gradient = sample_backs[column](delta)
            parameters .+= sample_parameters
            selectdim(gradient, ndims(gradient), column) .= storage(sample_gradient)
        end
        return parameters, _batch_wrap(gradient, initial)
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

function _batch_single_expectation_pullback(observable::QubitsTerm, state::DensityMatrix)
    if isempty(observable)
        value = expectation(observable, state)
        return value, seed -> (nothing,
            DensityMatrix((seed * conj(coeff(observable))) * one(storage(state)), nqubits(state)))
    end
    return _qterm_expec_util(observable, state)
end
_batch_single_expectation_pullback(observable::QubitsOperator, state::DensityMatrix) =
    _qop_expec_util(observable, state)

function _batch_expectation_adjoint(observable::Union{QubitsTerm,QubitsOperator},
                                     state::Union{BatchStateVector,BatchDensityMatrix})
    validate_positions(observable, nqubits(state))
    saved_observable = deepcopy(observable)
    T = promote_type(eltype(state), eltype(observable))
    saved_state = _batch_wrap(Array{T}(storage(state)), state)
    values = expectation(saved_observable, saved_state)
    function back(seed)
        isnothing(seed) && return nothing,
            _batch_wrap(zeros(T, size(storage(saved_state))), saved_state)
        seed isa AbstractVector{<:Number} ||
            throw(ArgumentError("a batch expectation cotangent must be a vector"))
        length(seed) == batch_size(saved_state) ||
            throw(DimensionMismatch("batch expectation cotangent must have one entry per sample"))
        Base.require_one_based_indexing(seed)
        CT = promote_type(T, eltype(seed))
        gradient = Array{CT}(undef, size(storage(saved_state)))
        for column in 1:batch_size(saved_state)
            sample = _batch_sample(saved_state, column, CT)
            _, sample_back = _batch_single_expectation_pullback(saved_observable, sample)
            _, sample_gradient = sample_back(seed[column])
            selectdim(gradient, ndims(gradient), column) .= storage(sample_gradient)
        end
        return nothing, _batch_wrap(gradient, saved_state)
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
