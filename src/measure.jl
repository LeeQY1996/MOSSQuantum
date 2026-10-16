"""
	apply!(x::QMeasure, qstate)
"""
function apply!(x::QMeasure, qstate::Union{StateVector, DensityMatrix})
	x.keep || error("only keep mode is implemented.")
	_check_measurement_position(x.position, nqubits(qstate))
	probability, istate = _local_measure(storage(qstate), x.position)
	op = I₂
	if x.auto_reset
		m = kron(op[:, istate], QuantumCircuits.Gates.ZERO)/sqrt(probability)
	else
		m = kron(op[:, istate], op[:, istate])/sqrt(probability)
	end
	m = reshape(m, (2, 2))
	apply!(gate(x.position, m), qstate)
	return istate-1, probability
end


"""
	measure!(qstate::StateVector, pos::Int; auto_reset::Bool=true)
Measure the i-th qubit of the quantum state, and return a 2-tuple including the measurement outcome, \n 
and the probability with which we get the outcome. The quantum state is updated inplace. \n 
If auto_reset=true,the measured qubit is reset to 0, otherwise it will be the same as the measurement outcome.
"""
measure!(qstate::Union{StateVector, DensityMatrix}, pos::Int; auto_reset::Bool=true) = apply!(QMeasure(pos, auto_reset=auto_reset), qstate)


function apply(s::QMeasure, qstater::StateVector)
	_check_measurement_position(s.position, nqubits(qstater))
	probability, istate = _local_measure(storage(qstater), s.position)
	r = vec(copy(_qubit_slice(qstater, s.position, istate-1))) / sqrt(probability)
	return StateVector(r, nqubits(qstater)-1), istate-1, probability
end

function _check_measurement_position(pos::Int, n::Int)
	1 <= pos <= n || throw(ArgumentError("qubit position must be between 1 and $n"))
	return nothing
end

# Keeping the axes before and after the selected qubit in place preserves the
# relative order of every remaining qubit, including when pos > 2.
function _qubit_slice(state::StateVector, pos::Int, outcome::Int)
	_check_measurement_position(pos, nqubits(state))
	tensor = reshape(storage(state), 2^(pos-1), 2, :)
	return view(tensor, :, outcome+1, :)
end

"""
	measure(qstate::StateVector, i::Int)
Measure the i-th qubit of the quantum state, and return a 3-tuple including the collapsed quantum state, \n 
the measurement outcome, and the probability with which we get the outcome.
The measured qubit is removed; the remaining qubits retain their relative order.
"""
measure(qstate::StateVector, pos::Int) = apply(QMeasure(pos), qstate)

function compute_probability_zero(v::AbstractVector, key::Int)
	L = length(v)
	pos = 2^(key-1)
	stri = pos * 2
	r = 0.
	for i in 0:stri:(L-1)
		@inbounds for j in 0:(pos-1)
			l = i + j + 1
			r += abs2(v[l])
		end
	end
	return r
end


function _local_measure(v::AbstractVector, key::Int)
	p0 = compute_probability_zero(v, key)
	l = [p0, 1-p0]
	i = discrete_sample(l)
	return l[i], i
end

# for density matrix
function compute_probability_zero(v::AbstractMatrix, key::Int)
	L = size(v, 1)
	pos = 2^(key-1)
	stri = pos * 2
	r = 0.
	for i in 0:stri:(L-1)
		@inbounds for j in 0:(pos-1)
			l = i + j + 1
			r += real(v[l, l])
		end
	end
	return r
end


function _local_measure(v::AbstractMatrix, key::Int)
	p0 = compute_probability_zero(v, key)
	l = [p0, 1-p0]
	i = discrete_sample(l)
	return l[i], i
end
