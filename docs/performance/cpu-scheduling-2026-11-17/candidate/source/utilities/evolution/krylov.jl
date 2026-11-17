using KrylovKit: eigsolve, exponentiate


function ground_state(h::QubitsOperator; kwargs...)
	ishermitian(h) || throw(ArgumentError("input operator is not hermitian."))
	n = QuantumCircuits.get_largest_pos(h)
	T = eltype(h)
	init_state = rand_state(T, n)

	eigvalues, eigvectors, info = eigsolve(x -> storage(h(StateVector(x, n))), storage(init_state), 1, :SR; ishermitian=true, kwargs...)
	(info.converged>=1) || error("eigsolve fails to converge.")
	return eigvalues[1], StateVector(eigvectors[1], n)
end


"""
    time_evolution(h::QubitsOperator, t::Number, state; kwargs...)

Apply `exp(t * h)` to a pure state, or `exp(t * h) * ρ * exp(conj(t) * h)`
to a density matrix, using Krylov exponentiation for Hermitian `h`.
For physical time `τ` with `ℏ = 1`, pass `t = -im * τ`.
Real `t` describes an unnormalized imaginary-time map; the result is not
automatically normalized. Additional keywords are passed to KrylovKit.
"""
function time_evolution(h::QubitsOperator, t::Number, v::StateVector; kwargs...)
	ishermitian(h) || throw(ArgumentError("input operator is not hermitian."))
	(QuantumCircuits.get_largest_pos(h) <= nqubits(v)) || throw(ArgumentError("number of qubits mismatch."))
	n = nqubits(v)
	T = promote_type(eltype(h), typeof(t), eltype(v) )
	v = convert(StateVector{T}, v)
	tmp, info = exponentiate(x -> storage(h(StateVector(x, n))), t, storage(v); ishermitian=true, kwargs...)
	(info.converged>=1) || error("eigsolve fails to converge.")
	return StateVector(tmp, n)
end


function time_evolution(h::QubitsOperator, t::Number, v::DensityMatrix; kwargs...)
	ishermitian(h) || throw(ArgumentError("input operator is not hermitian."))
	(QuantumCircuits.get_largest_pos(h) <= nqubits(v)) || throw(ArgumentError("number of qubits mismatch."))
	n = nqubits(v)
	T = promote_type(eltype(h), typeof(t), eltype(v) )
	v = convert(DensityMatrix{T}, v)
	left_action = x -> storage(h(DensityMatrix(x, n)))
	left, info = exponentiate(left_action, t, storage(v); ishermitian=true, kwargs...)
	(info.converged>=1) || error("left density-matrix evolution fails to converge.")
	# Evolve the adjoint to apply exp(conj(t) * h) on the right without
	# materializing either the full Hamiltonian or its exponential.
	right_adjoint, info = exponentiate(left_action, t, copy(left'); ishermitian=true, kwargs...)
	(info.converged>=1) || error("right density-matrix evolution fails to converge.")
	return DensityMatrix(copy(right_adjoint'), n)
end
