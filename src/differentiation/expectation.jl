# gradient of expectation values


function _qterm_expec_util(m::QubitsTerm, state::StateVector)
	_require_cpu_storage(state, m, :expectation)
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

function _qterm_expec_util(m::QubitsTerm, state::DensityMatrix)
    _require_cpu_storage(state, m, :expectation)
    return expectation(m, state), z -> (
        nothing, (z * m') * DensityMatrix(one(storage(state)), nqubits(state)))
end


function _qop_expec_util(m::QubitsOperator, state_in::StateVector)
	_require_cpu_storage(state_in, m, :expectation)
	if _largest_nterm(m) <= LARGEST_SUPPORTED_NTERMS
		return expectation(m, state_in), z -> (nothing, (conj(z) * m + z * m') * state_in ) 
	else
		state = storage(state_in)
		T = promote_type(eltype(m), eltype(state))
		workspace = similar(state, T)
		state_2 = zeros(T, length(state))
		for (k, v) in m.data
		    for item in v
		    	_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, workspace)
		    	state_2 .+= workspace
		    end
		end
		r = dot(state, state_2)
		return r, z -> begin
			if ishermitian(m)
			    grad = (conj(z) + z) .* state_2
			else
				grad = conj(z) .* state_2
				back_workspace = similar(grad)
				md = m'
				for (k, v) in md.data
					for item in v
						_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), state, back_workspace)
						@. grad += z * back_workspace
		    		end
		    	end
			end
		    return (nothing, StateVector(grad, nqubits(state_in)))
		end
	end	
end
# _qop_expec_util(m::QubitsOperator, state::DensityMatrix) = expectation(m, state), z -> (
# 	nothing, storage( (conj(z) * m + z * m') * DensityMatrix(one(storage(state)), nqubits(state)) ) )

function _qop_expec_util(m::QubitsOperator, state::DensityMatrix)
    _require_cpu_storage(state, m, :expectation)
    return expectation(m, state), z -> (
        nothing, (z * m') * DensityMatrix(one(storage(state)), nqubits(state)))
end
