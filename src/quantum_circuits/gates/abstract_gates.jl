
abstract type Gate{N} <: QuantumOperation end


# interfaces for Quantum Gates

"""
    nqubits(gate::Gate) -> Int

Return the number of qubits the gate acts on.

# Arguments
- `gate::Gate`: A quantum gate.

# Returns
- `Int`: Number of qubits.

# Examples
```julia
gate = XGate(1)
n = nqubits(gate)  # Returns 1

gate2 = CNOTGate(1, 2)
n2 = nqubits(gate2)  # Returns 2
```
"""
nqubits(x::Gate{N}) where N = N

"""
    positions(gate::Gate) -> Vector{Int}

Return the qubit positions that the gate acts on.

# Arguments
- `gate::Gate`: A quantum gate.

# Returns
- `Vector{Int}`: Qubit positions (1-indexed).

# Examples
```julia
gate = CNOTGate(control=1, target=2)
pos = positions(gate)  # Returns [1, 2]

gate2 = TOFFOLIGate(control1=1, control2=2, target=3)
pos2 = positions(gate2)  # Returns [1, 2, 3]
```
"""
positions(x::Gate) = x.pos


"""
    mat(gate::Gate) -> AbstractMatrix

Return the matrix representation of a quantum gate.

# Arguments
- `gate::Gate`: A quantum gate.

# Returns
- `AbstractMatrix`: Matrix representation of the gate (size 2ⁿ×2ⁿ where n = nqubits(gate)).

# Examples
```julia
gate = XGate(1)
m = mat(gate)  # Returns [0 1; 1 0]

gate2 = HGate(1)
m2 = mat(gate2)  # Returns [1 1; 1 -1]/√2
```

# Notes
- For gates acting on specific qubit positions, the matrix is in the computational basis with qubits ordered as given by `positions(gate)`.
- Concrete gate types must implement this method.
"""
mat(x::Gate) = error("mat not implemented for gate type $(typeof(x)).")

"""
	op(x::Gate)
"""
op(x::Gate) = reshape(mat(x), ntuple(i->2, 2*nqubits(x)))



"""
	ordered_positions(x::Gate)
"""
ordered_positions(x::Gate) = Tuple(sort([positions(x)...]))


"""
    ordered_mat(gate::Gate) -> AbstractMatrix

Return the matrix representation with qubits in canonical (sorted) order.

# Arguments
- `gate::Gate`: A quantum gate.

# Returns
- `AbstractMatrix`: Matrix representation with qubits ordered by their indices.

# Examples
```julia
gate = CNOTGate(control=2, target=1)  # Positions [2, 1]
m_ordered = ordered_mat(gate)  # Qubits reordered as [1, 2]
```

# See also
- [`mat`](@ref): Matrix without reordering.
- [`ordered_positions`](@ref): Get canonical position ordering.
"""
ordered_mat(x::Gate{N}) where N = reshape(ordered_op(x), 2^N, 2^N)

"""
	ordered_op(x::Gate)
"""
function ordered_op(x::Gate)
	is_ordered(x) && return op(x)
	ordered_pos, ordered_data = _get_norm_order(positions(x), op(x))
	return ordered_data
end 


change_positions(x::Gate, m::AbstractDict) = error("change_positions not implemented for gate type $(typeof(x)).")

Base.eltype(x::Gate) = eltype(mat(x))

"""
    shift(gate::Gate, offset::Int) -> Gate

Shift the qubit positions of a gate by a constant offset.

# Arguments
- `gate::Gate`: A quantum gate.
- `offset::Int`: Integer offset to add to all qubit positions.

# Returns
- `Gate`: A new gate with shifted positions.

# Examples
```julia
gate = CNOTGate(control=1, target=2)
shifted_gate = shift(gate, 3)  # Positions become [4, 5]
```

# Notes
- Useful for embedding subcircuits into larger systems.
- The gate type is preserved (e.g., `CNOTGate` remains `CNOTGate`).
"""
shift(x::Gate, j::Int) = _shift_gate_util!(x, j, Dict{Int, Int}())

is_ordered(x::Gate) = _is_pos_ordered(positions(x))


function _is_pos_ordered(pos)
	for i in 1:length(pos)-1
		(pos[i] < pos[i+1]) || return false
	end	
	return true
end

function _get_norm_order(key::NTuple{N, Int}, p::AbstractArray) where N
	seq = sortperm([key...])
	perm = (seq..., [s + N for s in seq]...)
	return key[seq], permute(p, perm)
end


function _shift_gate_util!(x, j::Int, m::AbstractDict)
	for mj in positions(x)
		get!(m, mj, mj+j)
	end
	return change_positions(x, m)
end

