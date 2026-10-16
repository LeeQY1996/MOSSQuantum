

function apply!(x::QSelect, qstate::StateVector)
	slice = _qubit_slice(qstate, x.position, x.state)
	p = real(dot(slice, slice))
	p > 0 || throw(DomainError(p, "cannot post-select an outcome with zero probability"))
	x.state == 0 ? apply!(gate(x.position, QuantumCircuits.Gates.UP), qstate) : apply!(gate(x.position, QuantumCircuits.Gates.DOWN), qstate)
	qstate.data ./= sqrt(p)
	return p
end

function apply(x::QSelect, qstate::StateVector; keep::Bool=false)
	r = _apply_impl(x, qstate, keep=keep)
	p = real(dot(storage(r), storage(r)))
	p > 0 || throw(DomainError(p, "cannot post-select an outcome with zero probability"))
	return r / sqrt(p), p
end

"""
	post_select!(qstate::StateVector, key::Int, state::Int=0)
Post-select the i-th qubit of the quantum state, and the quantum state is updated inplace, the probability is returned.
"""
post_select!(qstate::StateVector, key::Int, state::Int=0) = apply!(QSelect(key, state), qstate)

"""
	post_select(qstate::StateVector, key::Int, state::Int=0; keep::Bool=false)
Return the collapsed quantum state as well as the probability.
If `keep=false`, remove the selected qubit and retain the relative order of the
remaining qubits. If `keep=true`, preserve the original number of qubits.
"""
post_select(qstate::StateVector, key::Int, state::Int=0; keep::Bool=false) = apply(QSelect(key, state), qstate, keep=keep)





function _apply_throw_impl(x::QSelect, qstate::StateVector)
	r = vec(copy(_qubit_slice(qstate, x.position, x.state)))
	return StateVector(r, nqubits(qstate)-1)
end

function _apply_keep_impl(x::QSelect, qstate::StateVector)
	tmp = copy(qstate)
	x.state == 0 ? apply!(gate(x.position, QuantumCircuits.Gates.UP), tmp) : apply!(gate(x.position, QuantumCircuits.Gates.DOWN), tmp)
	return tmp
end

function _apply_impl(x::QSelect, qstate::StateVector; keep::Bool=false)
	return keep ? _apply_keep_impl(x, qstate) : _apply_throw_impl(x, qstate)
end

cnorm(x::AbstractVector) = sqrt(dot(x, x))
