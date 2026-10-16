module MOSSZygoteExt

using MOSS
using Zygote
using Zygote: @adjoint

using MOSS: _circuit_adjoint, _qubit_encoding_adjoint, _qterm_expec_util, _qop_expec_util
using MOSS: _density_to_state_cotangent, _to_sv
using MOSS: _apply_throw_impl, _apply_keep_impl, _apply_impl

@adjoint *(circuit::QCircuit, x::Union{StateVector, DensityMatrix}) = _circuit_adjoint(circuit, x)
@adjoint apply!(circuit::QCircuit, x::Union{StateVector, DensityMatrix}) = _circuit_adjoint(circuit, x)
@adjoint *(circuit::QCircuit, state::BatchStateVector) =
    throw(ArgumentError("Circuit differentiation for BatchStateVector is not implemented."))
@adjoint apply!(circuit::QCircuit, state::BatchStateVector) =
    throw(ArgumentError("Circuit differentiation for BatchStateVector is not implemented."))
@adjoint qubit_encoding(::Type{T}, values::Vector{<:Real}) where {T<:Number} = _qubit_encoding_adjoint(T, values)
@adjoint expectation(m::QubitsTerm, state::Union{StateVector, DensityMatrix}) = _qterm_expec_util(m, state)
@adjoint expectation(m::QubitsOperator, state::Union{StateVector, DensityMatrix}) = _qop_expec_util(m, state)

@adjoint bind_parameters(template::QCircuit, values::AbstractVector{<:Real}) = begin
    bound = bind_parameters(template, values)
    return bound, gradient -> (nothing, Zygote.ProjectTo(values)(gradient))
end

@adjoint bind_parameters(template::QCircuit, values::AbstractVector{<:Real}, map::ParameterMap) = begin
    bound = bind_parameters(template, values, map)
    return bound, gradient -> (nothing,
        isnothing(gradient) ? nothing : Zygote.ProjectTo(values)(accumulate_parameter_gradients(map, gradient)),
        nothing)
end

include("zygote/state_rules.jl")
include("zygote/post_selection_rules.jl")

end
