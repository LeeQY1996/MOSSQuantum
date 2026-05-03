function (h::QubitsTerm)(dm::DensityMatrix)
	v = dm.data
	vout = similar(v)
	_dm_apply_qterm_util!(h, v, vout, nqubits(dm))
	return DensityMatrix(vout, nqubits(dm))
end

function (h::QubitsOperator)(dm::DensityMatrix) 
	v = dm.data
	vout = zeros(eltype(v), length(v))
	if _largest_nterm(h) <= LARGEST_SUPPORTED_NTERMS
		_dm_apply_util!(h, v, vout, nqubits(dm))
	else
		workspace = similar(v)
		for (k, dd) in h.data
			for item in dd
			   _dm_apply_qterm_util!(QubitsTerm(k, item[1], item[2]), v, workspace, nqubits(dm)) 
			   vout .+= workspace
			end
		end
	end
	return DensityMatrix(vout, nqubits(dm))
end


Base.:*(h::QubitsOperator, dm::DensityMatrix) = h(dm)
Base.:*(h::QubitsTerm, dm::DensityMatrix) = h(dm)



const LARGEST_SUPPORTED_NTERMS = 5


function _dm_apply_qterm_util!(m::QubitsTerm, v::AbstractVector, vout::AbstractVector, n::Int)
	tmp = coeff(m)
	@. vout = tmp^2 * v
	if length(v) >= 32
		for (pos, mat) in zip(positions(m), oplist(m))
			_apply_gate_threaded2!(pos, mat, vout)
			_apply_gate_threaded2!(Tuple(pos.+n), -mat, vout)
		end	
	else    
		for (pos, mat) in zip(positions(m), oplist(m))
			_apply_gate_2!(pos, mat, vout)
			_apply_gate_2!(Tuple(pos.+n), -mat, vout)
		end			
	end 
end


function _dm_apply_util!(m::QubitsOperator, v::AbstractVector, vout::AbstractVector, n::Int) 
	if length(v) >= 32
		_dm_apply_threaded_util!(m, v, vout, n)
	else 
		_dm_apply_serial_util!(m, v, vout, n)
	end
end


function _dm_apply_serial_util!(m::QubitsOperator, v::AbstractVector, vout::AbstractVector, n::Int)
    for (k, bond) in m.data
        _apply_gate_2!(k, _get_mat(length(k), bond), v, vout)
		_apply_gate_2!(Tuple(k.+n), -_get_mat(length(k), bond), v, vout)
    end
    return vout
end

function _dm_apply_threaded_util!(m::QubitsOperator, v::AbstractVector, vout::AbstractVector, n::Int)
    for (k, bond) in m.data
        _apply_gate_threaded2!(k, _get_mat(length(k), bond), v, vout)
		_apply_gate_threaded2!(Tuple(k.+n), -_get_mat(length(k), bond), v, vout)
    end
    return vout
end
