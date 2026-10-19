module MOSSChainRulesCoreExt

import MOSS
import ChainRulesCore
using ChainRulesCore: AbstractZero, NoTangent, ZeroTangent, ProjectTo, unthunk

function ChainRulesCore.rrule(::typeof(MOSS.differentiable_value),
                             method::MOSS.AbstractGradientMethod,
                             objective,
                             values::AbstractVector{<:Real})
    MOSS._check_gradient_input(values)
    parameter_domain = copy(values)
    project_values = ProjectTo(values)
    value, core_pullback = MOSS.value_and_pullback(method, objective, values)
    MOSS._check_objective_value(value)
    project_output = ProjectTo(value)

    function objective_pullback(output_cotangent)
        seed = unthunk(output_cotangent)
        seed isa AbstractZero &&
            return NoTangent(), NoTangent(), NoTangent(), ZeroTangent()
        gradient = core_pullback(project_output(seed))
        MOSS._check_parameter_gradient(gradient, parameter_domain)
        return NoTangent(), NoTangent(), NoTangent(), project_values(gradient)
    end

    return value, objective_pullback
end

end
