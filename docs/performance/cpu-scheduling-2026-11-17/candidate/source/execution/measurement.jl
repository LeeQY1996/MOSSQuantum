"""
	apply!(x::QMeasure, qstate)
"""
function _cpu_apply!(x::QMeasure, qstate::Union{StateVector, DensityMatrix}; rng::Random.AbstractRNG=Random.default_rng())
	x.keep || error("only keep mode is implemented.")
	_check_measurement_position(x.position, nqubits(qstate))
	probability, istate = _local_measure(storage(qstate), x.position, rng)
	op = I₂
	if x.auto_reset
		m = kron(op[:, istate], QuantumCircuits.Gates.ZERO)/sqrt(probability)
	else
		m = kron(op[:, istate], op[:, istate])/sqrt(probability)
	end
	m = reshape(m, (2, 2))
	_cpu_apply!(gate(x.position, m), qstate)
	return istate-1, probability
end


"""
	measure!(qstate::StateVector, pos::Int; auto_reset::Bool=true)
Measure the i-th qubit of the quantum state, and return a 2-tuple including the measurement outcome, \n 
and the probability with which we get the outcome. The quantum state is updated inplace. \n 
If auto_reset=true,the measured qubit is reset to 0, otherwise it will be the same as the measurement outcome.
"""
measure!(qstate::Union{StateVector, DensityMatrix}, pos::Int; auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng()) = measure!(backend(qstate), qstate, pos; auto_reset=auto_reset, rng=rng)


function _cpu_apply(s::QMeasure, qstater::StateVector; rng::Random.AbstractRNG=Random.default_rng())
	_check_measurement_position(s.position, nqubits(qstater))
	probability, istate = _local_measure(storage(qstater), s.position, rng)
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
measure(qstate::StateVector, pos::Int; rng::Random.AbstractRNG=Random.default_rng()) = apply(QMeasure(pos), qstate; rng=rng)

"""
    measure!(batch::BatchStateVector, position; auto_reset=true, rng=Random.default_rng())

Measure each batch column independently, preserving the register size. Return
`(outcomes, probabilities)` in column order. Each column is collapsed and,
when `auto_reset=true`, its measured qubit is reset to zero. An empty batch
returns empty vectors; `position` must still name an existing qubit.
"""
measure!(batch::BatchStateVector, position::Int; auto_reset::Bool=true,
         rng::Random.AbstractRNG=Random.default_rng()) =
    measure!(backend(batch), batch, position; auto_reset=auto_reset, rng=rng)

function _cpu_apply!(instruction::QMeasure, batch::BatchStateVector;
                rng::Random.AbstractRNG=Random.default_rng())
    instruction.keep || throw(ArgumentError("in-place measurement must keep the measured qubit"))
    distributions = _batch_measurement_probabilities(batch, instruction.position)
    outcomes = Vector{Int}(undef, batch_size(batch))
    probabilities = Vector{Float64}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        selected = discrete_sample(rng, view(distributions, :, column))
        outcomes[column] = selected - 1
        probabilities[column] = distributions[selected, column]
        _collapse_batch_column!(batch, column, instruction.position, selected - 1,
                                probabilities[column], instruction.auto_reset)
    end
    return outcomes, probabilities
end

"""
    measure(batch::BatchStateVector, position; rng=Random.default_rng())

Measure each column independently and remove the measured qubit. Return
`(collapsed_batch, outcomes, probabilities)` without modifying the input. The
remaining qubits retain their relative order, including for the last qubit.
"""
measure(batch::BatchStateVector, position::Int; rng::Random.AbstractRNG=Random.default_rng()) =
    apply(QMeasure(position), batch; rng=rng)

function _cpu_apply(instruction::QMeasure, batch::BatchStateVector;
               rng::Random.AbstractRNG=Random.default_rng())
    distributions = _batch_measurement_probabilities(batch, instruction.position)
    outcomes = Vector{Int}(undef, batch_size(batch))
    probabilities = Vector{Float64}(undef, batch_size(batch))
    dimension = 2^(nqubits(batch) - 1)
    data = Matrix{eltype(batch)}(undef, dimension, batch_size(batch))
    for column in 1:batch_size(batch)
        selected = discrete_sample(rng, view(distributions, :, column))
        outcomes[column] = selected - 1
        probabilities[column] = distributions[selected, column]
        data[:, column] .= vec(_batch_qubit_slice(batch, instruction.position, selected - 1, column)) ./
                           sqrt(probabilities[column])
    end
    return BatchStateVector(data, nqubits(batch) - 1, batch_size(batch)), outcomes, probabilities
end

# Validate every column before mutating or consuming randomness. Unlike a dense
# density matrix, columns of this matrix are separate pure states.
function _batch_measurement_probabilities(batch::BatchStateVector, position::Int)
    _check_measurement_position(position, nqubits(batch))
    values = zeros(Float64, 2, batch_size(batch))
    bit = 1 << (position - 1)
    for column in 1:batch_size(batch), basis in axes(storage(batch), 1)
        outcome = ((basis - 1) & bit) == 0 ? 1 : 2
        values[outcome, column] += abs2(storage(batch)[basis, column])
    end
    for column in 1:batch_size(batch)
        _normalize_probabilities!(view(values, :, column), _probability_tolerance(eltype(batch)))
    end
    return values
end

function _batch_qubit_slice(batch::BatchStateVector, position::Int, outcome::Int, column::Int)
    tensor = reshape(view(storage(batch), :, column), 2^(position - 1), 2,
                     2^(nqubits(batch) - position))
    return view(tensor, :, outcome + 1, :)
end

function _collapse_batch_column!(batch::BatchStateVector, column::Int, position::Int,
                                 outcome::Int, probability::Real, auto_reset::Bool)
    data = storage(batch)
    stride = 1 << (position - 1)
    scale = inv(sqrt(probability))
    for block in 0:(2stride):(size(data, 1) - 1), offset in 1:stride
        zero_index = block + offset
        one_index = zero_index + stride
        if outcome == 0
            data[zero_index, column] *= scale
            data[one_index, column] = zero(eltype(batch))
        elseif auto_reset
            data[zero_index, column] = data[one_index, column] * scale
            data[one_index, column] = zero(eltype(batch))
        else
            data[zero_index, column] = zero(eltype(batch))
            data[one_index, column] *= scale
        end
    end
    return batch
end

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


function _local_measure(v::AbstractVector, key::Int, rng::Random.AbstractRNG=Random.default_rng())
	p0 = compute_probability_zero(v, key)
	l = [p0, 1-p0]
	_normalize_probabilities!(l, _probability_tolerance(eltype(v)))
	i = discrete_sample(rng, l)
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


function _local_measure(v::AbstractMatrix, key::Int, rng::Random.AbstractRNG=Random.default_rng())
	p0 = compute_probability_zero(v, key)
	l = [p0, 1-p0]
	_normalize_probabilities!(l, _probability_tolerance(eltype(v)))
	i = discrete_sample(rng, l)
	return l[i], i
end
