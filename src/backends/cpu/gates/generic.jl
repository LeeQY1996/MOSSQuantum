function _zero_qubit_matrix_value(matrix::AbstractMatrix)
    size(matrix) == (1, 1) || throw(DimensionMismatch("a zero-qubit operation must have a 1×1 matrix"))
    return matrix[1, 1]
end

function _apply_gate_2!(::Tuple{}, matrix::AbstractMatrix, state::AbstractVector)
    state .*= _zero_qubit_matrix_value(matrix)
    return state
end
_apply_gate_threaded2!(positions::Tuple{}, matrix::AbstractMatrix, state::AbstractVector) =
    _apply_gate_2!(positions, matrix, state)

apply_serial!(x::Gate, s::AbstractVector) = _apply_gate_2!(ordered_positions(x), ordered_mat(x), s)
apply_serial!(x::Gate, state::StateVector) = (apply_serial!(x, storage(state)); state)


"""
    currently support mostly 5-qubit gate
"""
apply_threaded!(x::Gate, s::AbstractVector) = (length(s) >= 32) ? _apply_gate_threaded2!(ordered_positions(x), ordered_mat(x), s) : apply_serial!(x, s)


# unitary gate operation on density matrix
function _dm_apply_threaded!(x::Gate{N}, s::AbstractVector, n::Int) where N
	pos = ordered_positions(x)
	m = ordered_mat(x)
	if length(s) >= 32
		_apply_gate_threaded2!(pos, m, s)
		_apply_gate_threaded2!(ntuple(i->pos[i]+n, N), conj(m), s)
	else
		_apply_gate_2!(pos, m, s)
		_apply_gate_2!(ntuple(i->pos[i]+n, N), conj(m), s)
	end
end
