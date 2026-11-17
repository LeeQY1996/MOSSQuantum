

function _cpu_apply!(x::QSelect, qstate::StateVector)
	slice = _qubit_slice(qstate, x.position, x.state)
	p = real(dot(slice, slice))
	p > 0 || throw(DomainError(p, "cannot post-select an outcome with zero probability"))
	x.state == 0 ? _cpu_apply!(gate(x.position, QuantumCircuits.Gates.UP), qstate) : _cpu_apply!(gate(x.position, QuantumCircuits.Gates.DOWN), qstate)
	qstate.data ./= sqrt(p)
	return p
end

function _cpu_apply(x::QSelect, qstate::StateVector; keep::Bool=false)
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
	x.state == 0 ? _cpu_apply!(gate(x.position, QuantumCircuits.Gates.UP), tmp) : _cpu_apply!(gate(x.position, QuantumCircuits.Gates.DOWN), tmp)
	return tmp
end

function _apply_impl(x::QSelect, qstate::StateVector; keep::Bool=false)
	return keep ? _apply_keep_impl(x, qstate) : _apply_throw_impl(x, qstate)
end

"""
    post_select!(batch::BatchStateVector, position, outcome=0)

Post-select the same outcome in every batch column, keeping the measured qubit.
Return one probability per column. Every column must have a positive finite
probability; all columns are checked before any state data is changed.
"""
post_select!(batch::BatchStateVector, position::Int, outcome::Int=0) =
    apply!(QSelect(position, outcome), batch)

function _cpu_apply!(instruction::QSelect, batch::BatchStateVector)
    probabilities = _batch_postselection_probabilities(batch, instruction)
    for column in 1:batch_size(batch)
        _collapse_batch_column!(batch, column, instruction.position, instruction.state,
                                probabilities[column], false)
    end
    return probabilities
end

"""
    post_select(batch::BatchStateVector, position, outcome=0; keep=false)

Return `(collapsed_batch, probabilities)` in column order without changing the
input. Remove the selected qubit unless `keep=true`. Empty batches preserve
their batch size and return an empty probability vector.
"""
post_select(batch::BatchStateVector, position::Int, outcome::Int=0; keep::Bool=false) =
    apply(QSelect(position, outcome), batch; keep=keep)

function _cpu_apply(instruction::QSelect, batch::BatchStateVector; keep::Bool=false)
    probabilities = _batch_postselection_probabilities(batch, instruction)
    if keep
        result = copy(batch)
        for column in 1:batch_size(batch)
            _collapse_batch_column!(result, column, instruction.position, instruction.state,
                                    probabilities[column], false)
        end
        return result, probabilities
    end
    data = Matrix{eltype(batch)}(undef, 2^(nqubits(batch) - 1), batch_size(batch))
    for column in 1:batch_size(batch)
        data[:, column] .= vec(_batch_qubit_slice(batch, instruction.position, instruction.state, column)) ./
                           sqrt(probabilities[column])
    end
    return BatchStateVector(data, nqubits(batch) - 1, batch_size(batch)), probabilities
end

function _batch_postselection_probabilities(batch::BatchStateVector, instruction::QSelect)
    _check_measurement_position(instruction.position, nqubits(batch))
    probabilities = Vector{Float64}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        selected = _batch_qubit_slice(batch, instruction.position, instruction.state, column)
        probability = Float64(real(dot(selected, selected)))
        isfinite(probability) && probability > 0 ||
            throw(DomainError(probability, "every batch column must have positive finite post-selection probability"))
        probabilities[column] = probability
    end
    return probabilities
end

cnorm(x::AbstractVector) = sqrt(dot(x, x))
