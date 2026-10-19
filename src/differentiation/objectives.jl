function _cpu_adjoint_parameters_valid(instruction::AbstractInstruction)
    count = nparameters(instruction)
    count isa Integer && count >= 0 || return false
    active = active_parameters(instruction)
    isnothing(active) && return count == 0
    return active isa AbstractVector{<:Real} && length(active) == count && all(isfinite, active)
end

function _cpu_adjoint_gate_valid(instruction::Gate, state_type::Type)
    _cpu_supports(instruction, state_type, :apply) || return false
    _cpu_adjoint_parameters_valid(instruction) || return false
    register = Tuple(positions(instruction))
    length(register) == nqubits(instruction) && length(unique(register)) == length(register) || return false
    unitary = mat(instruction)
    dimension = 2^nqubits(instruction)
    unitary isa AbstractMatrix{<:Number} && size(unitary) == (dimension, dimension) || return false
    all(isfinite, unitary) && isapprox(unitary' * unitary, I) || return false
    nparameters(instruction) == 0 && return true
    derivatives = differentiate(instruction)
    isnothing(derivatives) && return false
    length(derivatives) == nparameters(instruction) || return false
    for derivative in derivatives
        derivative isa Gate || return false
        nqubits(derivative) == nqubits(instruction) || return false
        Tuple(positions(derivative)) == register || return false
        matrix = mat(derivative)
        matrix isa AbstractMatrix{<:Number} && size(matrix) == (dimension, dimension) || return false
        all(isfinite, matrix) || return false
    end
    return true
end

function _cpu_adjoint_circuit_state(circuit::QCircuit, state_type::Type)
    for instruction in circuit
        if instruction isa QCircuit
            state_type = _cpu_adjoint_circuit_state(instruction, state_type)
            isnothing(state_type) && return nothing
        elseif instruction isa Gate
            _cpu_adjoint_gate_valid(instruction, state_type) || return nothing
        elseif instruction isa QuantumMap
            _cpu_supports(instruction, state_type, :apply) || return nothing
            nparameters(instruction) == 0 || return nothing
            dimension = 2^(2nqubits(instruction))
            supermatrix = ordered_supermat(instruction)
            size(supermatrix) == (dimension, dimension) && all(isfinite, supermatrix) || return nothing
            state_type = _cpu_result_state(instruction, state_type)
        else
            return nothing
        end
    end
    return state_type
end

function _cpu_adjoint_observable_valid(observable::QubitsTerm)
    isfinite(coeff(observable)) || return false
    length(unique(positions(observable))) == length(positions(observable)) || return false
    return all(matrix -> size(matrix) == (2, 2) && all(isfinite, matrix), oplist(observable)) &&
        ishermitian(observable)
end

function _cpu_adjoint_observable_valid(observable::QubitsOperator)
    for (register, terms) in observable.data
        length(unique(register)) == length(register) || return false
        for (operators, coefficient) in terms
            length(register) == length(operators) && isfinite(coefficient) || return false
            all(matrix -> size(matrix) == (2, 2) && all(isfinite, matrix), operators) || return false
        end
    end
    return ishermitian(observable)
end

function _supports_cpu_adjoint(objective::ExpectationObjective, template::QCircuit=objective.template)
    objective.backend isa CPUBackend || return false
    objective.initial_state isa Union{StateVector,DensityMatrix} || return false
    observable = objective.observable
    observable isa Union{QubitsTerm,QubitsOperator} || return false
    try
        _check_parameter_map(template, objective.parameter_map)
        validate_positions(template, nqubits(objective.initial_state))
        validate_positions(observable, nqubits(objective.initial_state))
        _cpu_adjoint_observable_valid(observable) || return false
        final_type = _cpu_adjoint_circuit_state(template, typeof(objective.initial_state))
        return !isnothing(final_type) && _cpu_supports(observable, final_type, :expectation)
    catch error
        error isa Union{InterruptException,OutOfMemoryError} && rethrow()
        return false
    end
end

supports_gradient(::AdjointGradient, objective::ExpectationObjective) = _supports_cpu_adjoint(objective)

# Legacy pure-state operator contractions allocate in the state's scalar domain.
# Promote the observation workspace when a real state meets a complex Hermitian
# observable, without changing the objective's state or the legacy API.
_cpu_observation_state(state::StateVector, observable) =
    convert(StateVector{promote_type(eltype(state), eltype(observable))}, state)
_cpu_observation_state(state::DensityMatrix, observable) =
    convert(DensityMatrix{promote_type(eltype(state), eltype(observable))}, state)

function _cpu_objective_expectation_pullback(observable::QubitsTerm, state::Union{StateVector,DensityMatrix})
    if isempty(observable)
        # A constant term has no tensor factors. The legacy pure-state helper
        # otherwise builds a QubitsOperator, whose keys require a nonempty site.
        value = expectation(observable, state)
        return value, (seed::Real) -> (nothing,
            state isa StateVector ? (2seed * real(coeff(observable))) * state :
                DensityMatrix((seed * real(coeff(observable))) * one(storage(state)), nqubits(state)))
    end
    return _qterm_expec_util(observable, state)
end

_cpu_objective_expectation_pullback(observable::QubitsOperator, state::Union{StateVector,DensityMatrix}) =
    _qop_expec_util(observable, state)

function value_and_pullback(method::AdjointGradient, objective::ExpectationObjective, values::AbstractVector{<:Real})
    _require_gradient_support(method, objective)
    _check_gradient_input(values)
    saved_values = copy(values)
    bound = bind_parameters(objective.template, saved_values, objective.parameter_map)
    _supports_cpu_adjoint(objective, bound) || throw(UnsupportedGradient(method, objective))
    observable = deepcopy(objective.observable)
    # Both circuit-adjoint paths copy their input before execution. Passing the
    # snapshot directly avoids a second full state copy without sharing the
    # output or channel checkpoints between prepared pullbacks.
    output, circuit_back = _circuit_adjoint(bound, objective.initial_state)
    observation_state = _cpu_observation_state(output, observable)
    expectation_value, observation_back = _cpu_objective_expectation_pullback(observable, observation_state)
    value = _check_objective_value(real(expectation_value))
    parameter_map = objective.parameter_map
    RT = typeof(real(zero(eltype(output))))
    back = function(seed::Real)
        if iszero(seed)
            return zeros(RT, length(saved_values))
        end
        _, state_gradient = observation_back(seed)
        slot_gradients, _ = circuit_back(state_gradient)
        gradient = accumulate_parameter_gradients(parameter_map, slot_gradients)
        return _check_parameter_gradient(gradient, saved_values)
    end
    return value, back
end

function value_and_gradient(method::AdjointGradient, objective::ExpectationObjective, values::AbstractVector{<:Real})
    value, back = value_and_pullback(method, objective, values)
    return value, back(one(value))
end

function _supports_cpu_batch_adjoint(objective::BatchExpectationObjective, template::QCircuit=objective.template)
    objective.backend isa CPUBackend || return false
    observable = objective.observable
    observable isa Union{QubitsTerm,QubitsOperator} || return false
    try
        _check_batch_objective_configuration(objective)
        _check_parameter_map(template, objective.parameter_map)
        register_size = nqubits(objective.initial_state)
        validate_positions(template, register_size)
        validate_positions(observable, register_size)
        _cpu_adjoint_observable_valid(observable) || return false
        state_type = StateVector{eltype(objective.initial_state)}
        # A batch of pure states has no mixed-state transition. In particular,
        # single-state support for fixed channels does not establish batch
        # support, and stochastic measurement/postselection are not adjoints.
        _has_quantum_map(template) && return false
        final_type = _cpu_adjoint_circuit_state(template, state_type)
        return final_type === state_type && _cpu_supports(observable, final_type, :expectation)
    catch error
        error isa Union{InterruptException,OutOfMemoryError} && rethrow()
        return false
    end
end

supports_gradient(::AdjointGradient, objective::BatchExpectationObjective) = _supports_cpu_batch_adjoint(objective)

function value_and_pullback(method::AdjointGradient, objective::BatchExpectationObjective,
                            values::AbstractVector{<:Real})
    _require_gradient_support(method, objective)
    _check_gradient_input(values)
    saved_values = copy(values)
    bound = bind_parameters(objective.template, saved_values, objective.parameter_map)
    _supports_cpu_batch_adjoint(objective, bound) || throw(UnsupportedGradient(method, objective))

    # Reuse the same numerical batch reverse passes as optional AD adapters.
    # Both helpers own private circuit/state/observable snapshots, and perform
    # one shared batch forward followed by independent per-column reverse work.
    observable = deepcopy(objective.observable)
    parameter_map = objective.parameter_map
    output, circuit_back = _batch_circuit_adjoint(bound, objective.initial_state)
    sample_values, observation_back = _batch_expectation_adjoint(observable, output)
    value = _reduce_batch_objective(objective, real.(sample_values))
    weights = _batch_objective_weights(objective, typeof(value))
    back = function(seed::Real)
        iszero(seed) && return zeros(typeof(value), length(saved_values))
        # A heterogeneous real weight vector still needs a concrete numerical
        # seed domain for the dense observation workspace.
        seed_type = mapreduce(weight -> typeof(seed * weight), promote_type, weights)
        sample_seeds = seed_type[seed * weight for weight in weights]
        _, state_gradient = observation_back(sample_seeds)
        slot_gradients, _ = circuit_back(state_gradient)
        gradient = accumulate_parameter_gradients(parameter_map, slot_gradients)
        return _check_parameter_gradient(gradient, saved_values)
    end
    return value, back
end

function value_and_gradient(method::AdjointGradient, objective::BatchExpectationObjective,
                            values::AbstractVector{<:Real})
    value, back = value_and_pullback(method, objective, values)
    return value, back(one(value))
end
