"""
    ExpectationObjective(template, observable, initial_state;
                         parameter_map=ParameterMap(template), backend=backend(initial_state))

A scalar objective evaluating the real part of an observable's expectation
after executing a bound circuit. The parameter map defines the independent
input order. Construction snapshots the instruction tree, observable, and
initial state; the backend is retained as an execution resource. Evaluation
copies the initial state and never modifies the template or input values.

This is an adapter for MOSS state/backends, not a required base type for external
objectives. It carries no gradient method. `AdjointGradient` has narrower
capabilities than forward evaluation, reported by `supports_gradient`.
"""
struct ExpectationObjective{O,S<:AbstractQuantumState,B<:AbstractBackend}
    template::QCircuit
    observable::O
    initial_state::S
    parameter_map::ParameterMap
    backend::B

    function ExpectationObjective(template::QCircuit, observable, initial_state::AbstractQuantumState;
                                  parameter_map::ParameterMap=ParameterMap(template),
                                  backend::AbstractBackend=MOSS.backend(initial_state))
        _check_parameter_map(template, parameter_map)
        copied_template = copy_instruction(template)
        copied_state = copy(initial_state)
        copied_state isa AbstractQuantumState ||
            throw(ArgumentError("copy(initial_state) must return an AbstractQuantumState."))
        copied_observable = deepcopy(observable)
        return new{typeof(copied_observable),typeof(copied_state),typeof(backend)}(
            copied_template, copied_observable, copied_state, parameter_map, backend)
    end
end

function evaluate(objective::ExpectationObjective, values::AbstractVector{<:Real})
    bound = bind_parameters(objective.template, values, objective.parameter_map)
    state = apply!(objective.backend, bound, copy(objective.initial_state))
    value = expectation(objective.backend, objective.observable, state)
    value isa Number || throw(ArgumentError("an expectation objective must produce a scalar expectation."))
    return _check_objective_value(real(value))
end
