# unitary gate operation on density matrix
function _qmap_apply_threaded!(x::QuantumMap{N}, s::AbstractVector, n::Int) where N
	pos = ordered_positions(x)
	pos2 = ntuple(i->pos[i]+n, N)
	all_pos = (pos..., pos2...)
	m = ordered_supermat(x)
	if length(s) >= 32
		_apply_gate_threaded2!(all_pos, m, s)
	else
		_apply_gate_2!(all_pos, m, s)
	end
end

function _qmap_apply_dagger_threaded!(x::QuantumMap{N}, s::AbstractVector, n::Int) where N
	pos = ordered_positions(x)
	pos2 = ntuple(i->pos[i]+n, N)
	all_pos = (pos..., pos2...)
	m = ordered_supermat(x)
	if length(s) >= 32
		_apply_gate_threaded2!(all_pos, m', s)
	else
		_apply_gate_2!(all_pos, m', s)
	end
end

function _qmap_apply_inverse_threaded!(x::QuantumMap{N}, s::AbstractVector, n::Int) where N
	pos = ordered_positions(x)
	pos2 = ntuple(i->pos[i]+n, N)
	all_pos = (pos..., pos2...)
	m = ordered_supermat(x)
	if length(s) >= 32
		_apply_gate_threaded2!(all_pos, inv(m), s)
	else
		_apply_gate_2!(all_pos, inv(m), s)
	end
end
