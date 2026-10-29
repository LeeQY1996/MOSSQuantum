module MOSSQuantumChainRulesCoreExt

import MOSSQuantum
import ChainRulesCore
using ChainRulesCore: AbstractZero, NoTangent, ZeroTangent, ProjectTo, unthunk

function ChainRulesCore.rrule(::typeof(MOSSQuantum.differentiable_value),
                             method::MOSSQuantum.AbstractGradientMethod,
                             objective,
                             values::AbstractVector{<:Real})
    MOSSQuantum._check_gradient_input(values)
    parameter_domain = copy(values)
    project_values = ProjectTo(values)
    value, core_pullback = MOSSQuantum.value_and_pullback(method, objective, values)
    MOSSQuantum._check_objective_value(value)
    project_output = ProjectTo(value)

    function objective_pullback(output_cotangent)
        seed = unthunk(output_cotangent)
        seed isa AbstractZero &&
            return NoTangent(), NoTangent(), NoTangent(), ZeroTangent()
        gradient = core_pullback(project_output(seed))
        MOSSQuantum._check_parameter_gradient(gradient, parameter_domain)
        return NoTangent(), NoTangent(), NoTangent(), project_values(gradient)
    end

    return value, objective_pullback
end

end
