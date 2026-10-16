


"""
	apply!(x::QuantumMap, state::DensityMatrix) 
	apply a generc quantum channel on the quantum state
"""
function apply!(x::QuantumMap, state::DensityMatrix) 
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(DensityMatrix{Complex{T}}, state)
	end
	_qmap_apply_threaded!(x, state.data, nqubits(state))
	return state
end

apply!(x::QuantumMap, state::StateVector) = apply!(x, DensityMatrix(state)) 

"""
	apply_dagger!(x::QuantumMap, state::DensityMatrix) 
	apply the hermitian conjugate of quantum map on rho
	this function is needed for auto-differentiation
"""
function apply_dagger!(x::QuantumMap, state::DensityMatrix) 
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(DensityMatrix{Complex{T}}, state)
	end
	_qmap_apply_dagger_threaded!(x, state.data, nqubits(state))
	return state
end

"""
	apply_inverse!(x::QuantumMap, state::DensityMatrix) 
	apply the inverse of quantum map on rho, this requires the supermatrix to be invertable.
	this function is needed for auto-differentiation
"""
function apply_inverse!(x::QuantumMap, state::DensityMatrix) 
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(DensityMatrix{Complex{T}}, state)
	end
	_qmap_apply_inverse_threaded!(x, state.data, nqubits(state))
	return state
end


