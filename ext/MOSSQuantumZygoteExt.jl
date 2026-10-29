module MOSSQuantumZygoteExt

using MOSSQuantum
using Zygote
using Zygote: @adjoint

using MOSSQuantum: _circuit_adjoint, _qubit_encoding_adjoint, _qterm_expec_util, _qop_expec_util
using MOSSQuantum: _density_to_state_cotangent, _to_sv
using MOSSQuantum: _batch_circuit_adjoint, _batch_expectation_adjoint, _batch_qubit_encoding_adjoint
using MOSSQuantum: _apply_throw_impl, _apply_keep_impl, _apply_impl

@adjoint *(circuit::QCircuit, x::Union{StateVector, DensityMatrix}) = _circuit_adjoint(circuit, x)
@adjoint apply!(circuit::QCircuit, x::Union{StateVector, DensityMatrix}) = _circuit_adjoint(circuit, x)
@adjoint *(circuit::QCircuit, state::Union{BatchStateVector,BatchDensityMatrix}) = _batch_circuit_adjoint(circuit, state)
@adjoint apply!(circuit::QCircuit, state::Union{BatchStateVector,BatchDensityMatrix}) = _batch_circuit_adjoint(circuit, state)
@adjoint qubit_encoding(::Type{T}, values::Vector{<:Real}) where {T<:Number} = _qubit_encoding_adjoint(T, values)
@adjoint batch_qubit_encoding(::Type{T}, values::AbstractMatrix{<:Real}) where {T<:Number} = begin
    result, back = _batch_qubit_encoding_adjoint(T, values)
    project = Zygote.ProjectTo(values)
    return result, seed -> (nothing, project(back(seed)))
end
@adjoint batch_qubit_encoding(values::AbstractMatrix{<:Real}) = begin
    result, back = _batch_qubit_encoding_adjoint(ComplexF64, values)
    project = Zygote.ProjectTo(values)
    return result, seed -> (project(back(seed)),)
end
@adjoint expectation(m::QubitsTerm, state::Union{StateVector, DensityMatrix}) = _qterm_expec_util(m, state)
@adjoint expectation(m::QubitsOperator, state::Union{StateVector, DensityMatrix}) = _qop_expec_util(m, state)
@adjoint expectation(m::Union{QubitsTerm,QubitsOperator}, state::Union{BatchStateVector,BatchDensityMatrix}) = _batch_expectation_adjoint(m, state)

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
