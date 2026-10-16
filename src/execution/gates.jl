function apply!(x::Gate, state::StateVector)
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(StateVector{Complex{T}}, state)
	end
	apply_threaded!(x, storage(state))
	return state
end

function apply!(x::Gate, state::DensityMatrix)
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(DensityMatrix{Complex{T}}, state)
	end
	_dm_apply_threaded!(x, state.data, nqubits(state))
	return state
end

function apply!(circuit::QCircuit, state::Union{StateVector, DensityMatrix})
	for gate in circuit
		if gate isa Union{QMeasure, QSelect}
			# These operations mutate the state and return measurement metadata.
			apply!(gate, state)
		else
			state = apply!(gate, state)
		end
	end
	return state
end

Base.:*(circuit::QCircuit, state::Union{StateVector, DensityMatrix}) = apply!(circuit, copy(state))

function _check_pos_range(x, n::Int)
	pos = ordered_positions(x)
	(length(pos) > 5) && throw("only implement 5-qubit gates and less currently.")
	return (pos[1] >= 1) && (pos[end] <= n)
end
