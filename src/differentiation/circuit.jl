
_to_sv(x::StateVector, Δ) = Δ isa StateVector ? Δ : StateVector(Δ, nqubits(x))
_to_sv(x::DensityMatrix, Δ) = Δ isa DensityMatrix ? Δ : DensityMatrix(Δ, nqubits(x))

_has_quantum_map(circuit::QCircuit) = any(item -> item isa QuantumMap ||
    (item isa QCircuit && _has_quantum_map(item)), circuit)

function _circuit_operations!(operations, circuit::QCircuit)
    for item in circuit
        if item isa QCircuit
            _circuit_operations!(operations, item)
        else
            push!(operations, item)
        end
    end
    return operations
end

# The pullback of psi -> psi * psi' for an arbitrary (not necessarily
# Hermitian) density-matrix cotangent.
function _density_to_state_cotangent(x::StateVector, Δ::DensityMatrix)
    d = storage(Δ)
    return StateVector((d + d') * storage(x), nqubits(x))
end

function _check_circuit_adjoint(circuit::QCircuit)
    for operation in circuit
        if operation isa QCircuit
            _check_circuit_adjoint(operation)
        elseif operation isa Gate
            matrix = mat(operation)
            isapprox(matrix' * matrix, I) ||
                throw(ArgumentError("Circuit differentiation requires unitary gates; $(typeof(operation)) is not unitary."))
        elseif !(operation isa QuantumMap)
            throw(ArgumentError("Circuit differentiation does not support $(typeof(operation)); supported instructions are unitary gates and QuantumMap channels."))
        end
    end
    return nothing
end

function _circuit_adjoint(circuit::QCircuit, x::Union{StateVector, DensityMatrix})
    _check_circuit_adjoint(circuit)
    if !_has_quantum_map(circuit)
        # Unitary circuits reconstruct their inputs backwards, so the memory
        # needed for differentiation does not grow with circuit depth.
        y = circuit * x
        return y, Δ -> begin
            Δ, grads, _ = back_propagate(copy(_to_sv(y, Δ)), circuit, copy(y))
            return grads, Δ
        end
    end

    operations = _circuit_operations!(Any[], circuit)
    checkpoints = Dict{Int, Union{StateVector, DensityMatrix}}()
    y = copy(x)
    for (i, item) in enumerate(operations)
        # Channels can be singular. Save their inputs rather than requiring
        # an inverse, while still reconstructing all intervening unitary gates.
        item isa QuantumMap && (checkpoints[i] = copy(y))
        y = apply!(item, y)
    end
    return y, Δ -> begin
        Δ = copy(_to_sv(y, Δ))
        state = copy(y)
        RT = real(eltype(y))
        grads = Vector{RT}[]
        for i in reverse(eachindex(operations))
            item = operations[i]
            if item isa QuantumMap
                Δ = apply_dagger!(item, Δ)
                state = copy(checkpoints[i])
                if state isa StateVector
                    Δ = _density_to_state_cotangent(state, Δ)
                end
            else
                Δ, ∇θs, state = back_propagate(Δ, item, state)
                !isnothing(∇θs) && push!(grads, ∇θs)
            end
        end
        return _flatten_gradients(grads, RT), Δ
    end
end

function _qubit_encoding_adjoint(::Type{T}, mpsstr::Vector{<:Real}) where {T<:Number}
    y = qubit_encoding(T, mpsstr)
    return y, Δ -> begin
        circuit = QCircuit([RyGate(i, theta*pi, isparas=true) for (i, theta) in enumerate(mpsstr)])
        Δ, grads, y = back_propagate(copy(StateVector(Δ)), circuit, copy(y))
        return nothing, grads .* pi
    end
end

function back_propagate(Δ::StateVector, m::Gate, y::StateVector)
    Δ = apply!(m', Δ)
    y = apply!(m', y)
    ∇θs = nothing
    if nparameters(m) > 0
        ∇θs = [real(expectation(y, item, Δ)) for item in differentiate(m)]
    end
    return Δ, ∇θs, y
end

# This contraction is tr(x * m * y), so m acts only on the row indices.
function expectation(x::DensityMatrix, m::Gate, y::DensityMatrix)
    yc = convert(DensityMatrix{promote_type(eltype(m), eltype(y))}, copy(y))
    apply_threaded!(m, yc.data)
    return dot(storage(x)', storage(yc))
end 

function _density_gate_gradients(Δ::DensityMatrix, m::Gate, x::DensityMatrix)
    nparameters(m) == 0 && return nothing
    return map(differentiate(m)) do item
        # D = (dU)'U, hence d(U*x*U') in the input frame is D'*x + x*D.
        T = promote_type(eltype(item), eltype(x))
        left = convert(Vector{T}, copy(x.data))
        right = copy(left)
        pos = ordered_positions(item)
        bra_pos = ntuple(i -> pos[i] + nqubits(x), length(pos))
        d = ordered_mat(item)
        if length(left) >= 32
            _apply_gate_threaded2!(pos, d', left)
            _apply_gate_threaded2!(bra_pos, transpose(d), right)
        else
            _apply_gate_2!(pos, d', left)
            _apply_gate_2!(bra_pos, transpose(d), right)
        end
        return real(dot(Δ.data, left) + dot(Δ.data, right))
    end
end

function back_propagate(Δ::DensityMatrix, m::Gate, y::DensityMatrix)
    Δ = apply!(m', Δ)
    y = apply!(m', y)
    ∇θs = _density_gate_gradients(Δ, m, y)
    return Δ, ∇θs, y
end

function _flatten_gradients(grads, ::Type{RT}) where RT
    all_grads = RT[]
    for item in Iterators.reverse(grads)
        append!(all_grads, item)
    end
    return all_grads
end

function back_propagate_util(Δ, circuit::QCircuit, y)
    RT = real(eltype(y))
    grads = Vector{RT}[]
    for item in reverse(circuit)
        Δ, ∇θs, y = back_propagate(Δ, item, y)
        !isnothing(∇θs) && push!(grads, ∇θs)
    end

    return Δ, _flatten_gradients(grads, RT), y
end

back_propagate(Δ::StateVector, circuit::QCircuit, y::StateVector) = back_propagate_util(Δ, circuit, y)
back_propagate(Δ::DensityMatrix, circuit::QCircuit, y::DensityMatrix) = back_propagate_util(Δ, circuit, y)
