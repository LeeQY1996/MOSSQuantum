# gradient of expectation values


function _qterm_expec_util(m::QubitsTerm, state::StateVector)
	if length(positions(m)) <= LARGEST_SUPPORTED_NTERMS
	    return expectation(m, state), z -> (nothing, (conj(z) * m + z * m') * state ) 
	else
		v = m * state
		return dot(state, v), z -> begin
		   m1 = conj(z) * m
		   m2 = z * m'
		   _apply_qterm_util!(m1, storage(state), storage(v))
		   v2 = storage( m2 * state )
		   v2 .+= storage(v)
		   return (nothing, StateVector(v2, nqubits(state)))
		end
	end
end

# this could be slow
# _qterm_expec_util(m::QubitsTerm, state::DensityMatrix) = expectation(m, state), z -> (
# 	nothing,  storage((conj(z) * m + z * m') *  DensityMatrix(one(storage(state)), nqubits(state)))  )

_qterm_expec_util(m::QubitsTerm, state::DensityMatrix) = expectation(m, state), z -> (
			nothing,  (z * m') *  DensityMatrix(one(storage(state)), nqubits(state)))  


@adjoint expectation(m::QubitsTerm, state::Union{StateVector, DensityMatrix}) = _qterm_expec_util(m, state)

function _qop_expec_util(m::QubitsOperator, state_in::StateVector)
	if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS
		return expectation(m, state_in), z -> (nothing, (conj(z) * m + z * m') * state_in ) 
	else
		state = storage(state_in)
		workspace = similar(state)
		state_2 = zeros(eltype(state), length(state))
		for (k, v) in m.data
		    for item in v
		    	_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, workspace)
		    	state_2 .+= workspace
		    end
		end
		r = dot(state, state_2)
		return r, z -> begin
			if ishermitian(m)
			    state_2 .*= (conj(z) + z)
			else
				state_2 .*= conj(z)
				md = m'
				for (k, v) in md.data
					for item in v
						_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, workspace)
						@. state_2 += z * workspace
		    		end
		    	end
			end
		    return (nothing, StateVector(state_2, nqubits(state_in)))
		end
	end	
end
# _qop_expec_util(m::QubitsOperator, state::DensityMatrix) = expectation(m, state), z -> (
# 	nothing, storage( (conj(z) * m + z * m') * DensityMatrix(one(storage(state)), nqubits(state)) ) )

_qop_expec_util(m::QubitsOperator, state::DensityMatrix) = expectation(m, state), z -> (
	nothing,  (z * m') * DensityMatrix(one(storage(state)), nqubits(state)) ) 


@adjoint expectation(m::QubitsOperator, state::Union{StateVector, DensityMatrix}) = _qop_expec_util(m, state)


