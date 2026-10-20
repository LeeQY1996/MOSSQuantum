function _cpu_expectation(m::QubitsTerm, state::StateVector)
	isempty(m) && return coeff(m) * dot(state, state)
	if length(positions(m)) <= LARGEST_SUPPORTED_NTERMS
	    return expectation_value(Tuple(positions(m)), _get_mat(m), storage(state))
	else
		return dot(state, m * state)
	end
end


function _cpu_expectation(m::QubitsOperator, state::StateVector)
	if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS
		r = zero(eltype(state))
		for (k, v) in m.data
			r += expectation_value(k, _get_mat(length(k), v), storage(state))
		end
		return r
	else
		# state = storage(state)
		# workspace = similar(state)
		# state_2 = zeros(eltype(state), length(state))
		# for (k, v) in m.data
		#     for item in v
		#     	_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, workspace)
		#     	state_2 .+= workspace
		#     end
		# end
		# return dot(state, state_2)
		return dot(state, m * state)
	end
end


function _cpu_cross_expectation(state_c::StateVector, m::QubitsTerm, state::StateVector)
	isempty(m) && return coeff(m) * dot(state_c, state)
	if length(positions(m)) <= LARGEST_SUPPORTED_NTERMS
		return expectation_value(Tuple(positions(m)), _get_mat(m), storage(state), storage(state_c))
	else
		return dot(state_c, m * state)
	end
end

function _cpu_cross_expectation(state_c::StateVector, m::QubitsOperator, state::StateVector)
	if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS
		r = zero(eltype(state))
		for (k, v) in m.data
			r += expectation_value(k, _get_mat(length(k), v), storage(state), storage(state_c))
		end
		return r
	else
		# state = storage(state)
		# workspace = similar(state)
		# state_2 = zeros(eltype(state), length(state))
		# for (k, v) in m.data
		#     for item in v
		#     	_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, workspace)
		#     	state_2 .+= workspace
		#     end
		# end
		# return dot(state_c, state_2)
		return dot(state_c, m * state)
	end
end

_cpu_expectation(m::Gate, state::StateVector) = expectation_value(ordered_positions(m), ordered_mat(m), storage(state))
_cpu_cross_expectation(state_c::StateVector, m::Gate, state::StateVector) = expectation_value(
	ordered_positions(m), ordered_mat(m), storage(state), storage(state_c))

_cpu_cross_expectation(state_c::StateVector, m::AbstractMatrix, state::StateVector) = dot(storage(state_c), m, storage(state))
_cpu_expectation(m::AbstractMatrix, state::StateVector) = dot(state, m, state)
