
abstract type ParametricGate{N} <: Gate{N} end


parameters(x::Gate) = nothing
is_parameters(x::Gate) = nothing
active_parameters(x::Gate) = nothing
nparameters(x::Gate) = (values = active_parameters(x); isnothing(values) ? 0 : length(values))

parameters(x::ParametricGate) = x.paras
parameters(x::AdjointQuantumGate) = parameters(x.parent)
is_parameters(x::ParametricGate) = hasfield(typeof(x), :isparas) ? getfield(x, :isparas) : nothing
is_parameters(x::AdjointQuantumGate) = is_parameters(x.parent)
nparameters(x::ParametricGate) = (values = active_parameters(x); isnothing(values) ? 0 : length(values))
active_parameters(x::ParametricGate) = parameters(x)[is_parameters(x)]
active_parameters(x::AdjointQuantumGate) = active_parameters(x.parent)
nparameters(x::AdjointQuantumGate) = nparameters(x.parent)
activate_parameter!(x::Gate, j::Int) = x
activate_parameters!(x::Gate) = x
deactivate_parameter!(x::Gate, j::Int) = x
deactivate_parameters!(x::Gate) = x

function reset_parameters_util!(x::Gate, p::Vector{<:Real}, pos::Int)
	n = nparameters(x)
	(n == 0) && return pos
	mask = is_parameters(x)
	isnothing(mask) && throw(ArgumentError("$(typeof(x)) must implement reset_parameters!(instruction, values)."))
	parameters(x)[mask] .= view(p, pos+1:(pos+n))
	return pos + n
end

function activate_parameter!(x::ParametricGate, j::Int)
	is_parameters(x)[j] = true
	return x
end
function activate_parameters!(x::ParametricGate)
	is_parameters(x) .= true
	return x
end
function deactivate_parameter!(x::ParametricGate, j::Int)
	is_parameters(x)[j] = false
	return x
end
function deactivate_parameters!(x::ParametricGate)
	is_parameters(x) .= false
	return x
end

function _replace_adjoint_parent(x::AdjointQuantumGate, parent, operation::Symbol)
	parent isa Gate || throw(ArgumentError("$operation for an adjoint parent must return a Gate."))
	return parent === x.parent ? x : AdjointQuantumGate(parent)
end

copy_instruction(x::AdjointQuantumGate) =
	_replace_adjoint_parent(x, copy_instruction(x.parent), :copy_instruction)

function reset_parameters!(x::AdjointQuantumGate, values::AbstractVector{<:Real})
	expected = _check_parameter_values(x, values)
	result = _replace_adjoint_parent(x, reset_parameters!(x.parent, values), :reset_parameters!)
	return _checked_reset_result(result, expected)
end

function activate_parameter!(x::AdjointQuantumGate, j::Int)
	return _replace_adjoint_parent(x, activate_parameter!(x.parent, j), :activate_parameter!)
end
function activate_parameters!(x::AdjointQuantumGate)
	return _replace_adjoint_parent(x, activate_parameters!(x.parent), :activate_parameters!)
end
function deactivate_parameter!(x::AdjointQuantumGate, j::Int)
	return _replace_adjoint_parent(x, deactivate_parameter!(x.parent, j), :deactivate_parameter!)
end
function deactivate_parameters!(x::AdjointQuantumGate)
	return _replace_adjoint_parent(x, deactivate_parameters!(x.parent), :deactivate_parameters!)
end

"""
    differentiate(gate::Gate)

Return one derivative gate per active parameter, in `active_parameters(gate)`
order, for the existing dense CPU circuit reverse pass. For a unitary matrix
`U(θ)`, each returned gate stores `(∂U/∂θ)' * U`, not the raw derivative `∂U/∂θ`.
The derivative gate has the same register positions as `gate`.

Gates with no active parameters return `nothing`. A trainable external gate must
implement this public method to support the existing circuit reverse pass;
parameter binding and execution alone do not establish differentiation support.
"""
function differentiate(x::Gate)
	nparameters(x) == 0 && return nothing
	throw(ArgumentError("$(typeof(x)) must implement differentiate(gate) for its active parameters."))
end

