function _cpu_apply!(x::Gate, state::StateVector)
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(StateVector{Complex{T}}, state)
	end
	apply_threaded!(x, storage(state))
	return state
end

function _cpu_apply!(x::Gate, state::DensityMatrix)
	@assert _check_pos_range(x, nqubits(state))
	T = eltype(state)
	if (eltype(x) <: Complex) && (T <: Real)
		state = convert(DensityMatrix{Complex{T}}, state)
	end
	_dm_apply_threaded!(x, state.data, nqubits(state))
	return state
end

function _cpu_apply!(circuit::QCircuit, state::Union{StateVector, DensityMatrix};
                     rng::Random.AbstractRNG=Random.default_rng())
    # Retain public instruction hooks after the circuit's CPU storage preflight.
    for operation in circuit
        if operation isa QMeasure
            apply!(operation, state; rng=rng)
        elseif operation isa QSelect
            apply!(operation, state)
        elseif operation isa QCircuit
            state = apply!(operation, state; rng=rng)
        else
            state = apply!(operation, state)
        end
    end
    return state
end

Base.:*(circuit::QCircuit, state::Union{StateVector, DensityMatrix}) = _apply_circuit_copy(circuit, state)

function _check_pos_range(x, n::Int)
	pos = ordered_positions(x)
	(length(pos) > 5) && throw("only implement 5-qubit gates and less currently.")
	return (pos[1] >= 1) && (pos[end] <= n)
end
