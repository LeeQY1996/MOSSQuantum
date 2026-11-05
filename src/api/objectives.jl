"""
    ExpectationObjective(template, observable, initial_state;
                         parameter_map=ParameterMap(template), backend=backend(initial_state))

A scalar objective evaluating the real part of an observable's expectation
after executing a bound circuit. The parameter map defines the independent
input order. Construction snapshots the instruction tree, observable, and
initial state; the backend is retained as an execution resource. Evaluation
copies the initial state and never modifies the template or input values.

This is an adapter for MOSSQuantum state/backends, not a required base type for external
objectives. It carries no gradient method. `AdjointGradient` has narrower
capabilities than forward evaluation, reported by `supports_gradient`.
"""
struct ExpectationObjective{O,S<:AbstractQuantumState,B<:AbstractBackend,P<:AbstractParameterMap}
    template::QCircuit
    observable::O
    initial_state::S
    parameter_map::P
    backend::B

    function ExpectationObjective(template::Union{QCircuit,_ParameterContext}, observable, initial_state::AbstractQuantumState;
                                  parameter_map=nothing, parameter_order=nothing, fixed=nothing,
                                  backend::AbstractBackend=MOSSQuantum.backend(initial_state))
        copied_template, compiled_map = _prepare_parameter_template(template; parameter_map, parameter_order, fixed)
        copied_template isa QCircuit || throw(ArgumentError("an expectation objective requires a circuit template"))
        copied_state = copy(initial_state)
        copied_state isa AbstractQuantumState ||
            throw(ArgumentError("copy(initial_state) must return an AbstractQuantumState."))
        copied_observable = deepcopy(observable)
        return new{typeof(copied_observable),typeof(copied_state),typeof(backend),typeof(compiled_map)}(
            copied_template, copied_observable, copied_state, compiled_map, backend)
    end
end

function evaluate(objective::ExpectationObjective, values::AbstractVector{<:Real})
    bound = bind_parameters(objective.template, values, objective.parameter_map)
    state = apply!(objective.backend, bound, copy(objective.initial_state))
    value = expectation(objective.backend, objective.observable, state)
    value isa Number || throw(ArgumentError("an expectation objective must produce a scalar expectation."))
    return _check_objective_value(real(value))
end

"""
    BatchExpectationObjective(template, observable, initial_state;
                              parameter_map=ParameterMap(template),
                              backend=backend(initial_state), reduction=:mean, weights=nothing)

A real scalar objective for a nonempty `BatchStateVector` or `BatchDensityMatrix`
sharing one circuit, parameter vector, and observable. The last axis indexes
samples. `evaluate_batch` returns the real expectation for each sample in input order; `evaluate` reduces
these values using `:mean` (default), `:sum`, or `:weighted_sum`.

`:weighted_sum` requires a finite real weight for every sample. Weights may be
negative and are not normalized. Other reductions reject `weights`. Construction
snapshots the circuit, observable, states, and weights; the backend remains an
execution resource. Forward execution does not select a gradient method.
"""
struct BatchExpectationObjective{O,S<:Union{BatchStateVector,BatchDensityMatrix},B<:AbstractBackend,W,P<:AbstractParameterMap}
    template::QCircuit
    observable::O
    initial_state::S
    parameter_map::P
    backend::B
    reduction::Symbol
    weights::W

    function BatchExpectationObjective(template::Union{QCircuit,_ParameterContext}, observable,
                                       initial_state::Union{BatchStateVector,BatchDensityMatrix};
                                       parameter_map=nothing, parameter_order=nothing, fixed=nothing,
                                       backend::AbstractBackend=MOSSQuantum.backend(initial_state),
                                       reduction::Symbol=:mean, weights=nothing)
        copied_template, compiled_map = _prepare_parameter_template(template; parameter_map, parameter_order, fixed)
        copied_template isa QCircuit || throw(ArgumentError("an expectation objective requires a circuit template"))
        count = batch_size(initial_state)
        count > 0 || throw(ArgumentError("a batch expectation objective requires at least one sample."))
        reduction in (:sum, :mean, :weighted_sum) ||
            throw(ArgumentError("batch reduction must be :sum, :mean, or :weighted_sum."))
        if reduction === :weighted_sum
            weights isa AbstractVector{<:Real} ||
                throw(ArgumentError(":weighted_sum requires a real weight vector."))
            Base.require_one_based_indexing(weights)
            length(weights) == count ||
                throw(DimensionMismatch("expected $count sample weights, received $(length(weights))."))
            all(isfinite, weights) || throw(ArgumentError("sample weights must be finite."))
            saved_weights = Tuple(deepcopy(collect(weights)))
        else
            isnothing(weights) || throw(ArgumentError("weights are only valid with :weighted_sum."))
            saved_weights = nothing
        end
        copied_state = copy(initial_state)
        copied_observable = deepcopy(observable)
        return new{typeof(copied_observable),typeof(copied_state),typeof(backend),typeof(saved_weights),typeof(compiled_map)}(
            copied_template, copied_observable, copied_state, compiled_map, backend, reduction, saved_weights)
    end
end

parameter_order(objective::Union{ExpectationObjective,BatchExpectationObjective}) = parameter_order(objective.parameter_map)
independent_parameters(objective::Union{ExpectationObjective,BatchExpectationObjective}) = independent_parameters(objective.parameter_map)
trainable_parameters(objective::Union{ExpectationObjective,BatchExpectationObjective}) = trainable_parameters(objective.parameter_map)

function _check_batch_objective_configuration(objective::BatchExpectationObjective)
    count = batch_size(objective.initial_state)
    count > 0 || throw(ArgumentError("a batch expectation objective requires at least one sample."))
    dimension = 2^nqubits(objective.initial_state)
    expected_shape = objective.initial_state isa BatchStateVector ? (dimension, count) :
        (dimension, dimension, count)
    size(storage(objective.initial_state)) == expected_shape ||
        throw(DimensionMismatch("batch storage no longer matches its sample and register dimensions."))
    _check_parameter_map(objective.template, objective.parameter_map)
    return nothing
end

function _check_batch_objective_gate(gate::Gate)
    register = Tuple(positions(gate))
    length(register) == nqubits(gate) && length(unique(register)) == length(register) ||
        throw(ArgumentError("gate positions must contain one distinct register per qubit."))
    matrix = mat(gate)
    dimension = 2^nqubits(gate)
    matrix isa AbstractMatrix{<:Number} && size(matrix) == (dimension, dimension) ||
        throw(DimensionMismatch("gate matrix dimensions must match its qubit count."))
    all(isfinite, matrix) || throw(ArgumentError("gate matrix entries must be finite."))
    return nothing
end

function _check_batch_objective_gates(circuit::QCircuit)
    for instruction in circuit
        if instruction isa QCircuit
            _check_batch_objective_gates(instruction)
        elseif instruction isa Gate
            _check_batch_objective_gate(instruction)
        elseif instruction isa QuantumMap
            register = Tuple(positions(instruction))
            length(register) == nqubits(instruction) && length(unique(register)) == length(register) ||
                throw(ArgumentError("channel positions must be distinct and match its qubit count."))
            Tuple(ordered_positions(instruction)) == Tuple(sort(collect(register))) ||
                throw(ArgumentError("ordered channel positions must match its register."))
            local_dimension = 2^nqubits(instruction)
            matrices = kraus_matrices(instruction)
            !isempty(matrices) || throw(ArgumentError("a channel needs at least one Kraus matrix."))
            for matrix in matrices
                size(matrix) == (local_dimension, local_dimension) ||
                    throw(DimensionMismatch("Kraus dimensions must match the channel register."))
                all(isfinite, matrix) || throw(ArgumentError("Kraus matrix entries must be finite."))
            end
            dimension = local_dimension^2
            matrix = ordered_supermat(instruction)
            size(matrix) == (dimension, dimension) ||
                throw(DimensionMismatch("channel supermatrix dimensions must match its qubit count."))
            all(isfinite, matrix) || throw(ArgumentError("channel matrix entries must be finite."))
        end
    end
    return nothing
end

function _check_batch_objective_observable(observable::QubitsTerm)
    length(unique(positions(observable))) == length(positions(observable)) ||
        throw(ArgumentError("observable positions must be distinct."))
    all(matrix -> size(matrix) == (2, 2), oplist(observable)) ||
        throw(DimensionMismatch("each observable tensor factor must have size (2, 2)."))
    return nothing
end

function _check_batch_objective_observable(observable::QubitsOperator)
    for (register, terms) in observable.data
        length(unique(register)) == length(register) ||
            throw(ArgumentError("observable positions must be distinct."))
        for (operators, _) in terms
            length(register) == length(operators) && all(matrix -> size(matrix) == (2, 2), operators) ||
                throw(DimensionMismatch("observable tensor factors must match their registers."))
        end
    end
    return nothing
end

_check_batch_objective_observable(observable::Gate) = _check_batch_objective_gate(observable)
_check_batch_objective_observable(observable) = nothing

function _check_batch_objective_execution(objective::BatchExpectationObjective, bound::QCircuit)
    state, execution_backend = objective.initial_state, objective.backend
    supports(execution_backend, bound, state) ||
        throw(UnsupportedOperation(execution_backend, bound, state, :apply))
    if execution_backend isa CPUBackend
        final_type = _cpu_circuit_state(bound, typeof(state))
        _cpu_supports(objective.observable, final_type, :expectation) ||
            throw(UnsupportedOperation(execution_backend, objective.observable, state, :expectation))
    else
        supports(execution_backend, objective.observable, state; action=:expectation) ||
            throw(UnsupportedOperation(execution_backend, objective.observable, state, :expectation))
    end
    validate_positions(bound, nqubits(state))
    if objective.observable isa AbstractMatrix
        dimension = 2^nqubits(state)
        size(objective.observable) == (dimension, dimension) ||
            throw(DimensionMismatch("observable dimensions must match the quantum state."))
    else
        validate_positions(objective.observable, nqubits(state))
    end
    if execution_backend isa CPUBackend
        # Validate the entire bound circuit before the first sample or gate is
        # executed. Forward checks do not require unitarity or derivative rules.
        _check_batch_objective_gates(bound)
        _check_batch_objective_observable(objective.observable)
    end
    return nothing
end

"""
    evaluate_batch(objective::BatchExpectationObjective, values) -> AbstractVector{<:Real}

Execute a shared bound circuit and return one real expectation per sample,
without reducing the sample axis or invoking a gradient method. Neither the
initial batch nor the caller's parameter vector is modified.
"""
function evaluate_batch(objective::BatchExpectationObjective, values::AbstractVector{<:Real})
    _check_batch_objective_configuration(objective)
    bound = bind_parameters(objective.template, values, objective.parameter_map)
    _check_batch_objective_execution(objective, bound)
    state = apply!(objective.backend, bound, copy(objective.initial_state))
    expectations = expectation(objective.backend, objective.observable, state)
    expectations isa AbstractVector{<:Number} ||
        throw(ArgumentError("a batch expectation objective must produce a vector of sample expectations."))
    length(expectations) == batch_size(objective.initial_state) ||
        throw(DimensionMismatch("the number of expectations must match the input batch."))
    Base.require_one_based_indexing(expectations)
    return real.(expectations)
end

function _reduce_batch_objective(objective::BatchExpectationObjective, values::AbstractVector{<:Real})
    if objective.reduction === :weighted_sum
        return _check_objective_value(sum(weight * value for (weight, value) in zip(objective.weights, values)))
    end
    total = sum(values)
    return _check_objective_value(objective.reduction === :mean ? total / length(values) : total)
end

evaluate(objective::BatchExpectationObjective, values::AbstractVector{<:Real}) =
    _reduce_batch_objective(objective, evaluate_batch(objective, values))

function _batch_objective_weights(objective::BatchExpectationObjective, ::Type{T}) where {T<:Real}
    objective.reduction === :weighted_sum && return objective.weights
    weight = objective.reduction === :mean ? one(T) / batch_size(objective.initial_state) : one(T)
    return ntuple(_ -> weight, batch_size(objective.initial_state))
end

parameter_info(objective::Union{ExpectationObjective,BatchExpectationObjective}) =
    parameter_info((; template=objective.template, parameter_map=objective.parameter_map))
initial_parameters(objective::Union{ExpectationObjective,BatchExpectationObjective}; kwargs...) =
    initial_parameters((; template=objective.template, parameter_map=objective.parameter_map); kwargs...)
