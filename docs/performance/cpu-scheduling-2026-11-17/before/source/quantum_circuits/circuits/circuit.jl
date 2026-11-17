abstract type QuantumCircuit <: AbstractInstruction end

"""
	struct QMeasure <: AbstractInstruction
	Quantum Measurement
"""
struct QMeasure <: AbstractInstruction
	position::Int
	auto_reset::Bool
	keep::Bool
    key::Union{Nothing,Symbol}

    function QMeasure(position::Int; auto_reset::Bool=true, keep::Bool=true, key=nothing)
        name = isnothing(key) ? nothing : _classical_key(key)
        new(position,auto_reset,keep,name)
    end
end
positions(x::QMeasure) = [x.position]
nparameters(x::QMeasure) = 0
parameters(x::QMeasure) = nothing
change_positions(x::QMeasure, m::AbstractDict) = QMeasure(m[x.position]; auto_reset=x.auto_reset, keep=x.keep, key=x.key)


"""
	struct QSelect <: QuantumOperation
	post selection, do we need it?
"""
struct QSelect <: AbstractInstruction
	position::Int
	state::Int

	function QSelect(key::Int, state::Int=0)
		(state==0 || state==1) || error("selected state must be 0 or 1.")
		new(key, state)
	end
end
positions(x::QSelect) = [x.position]
nparameters(x::QSelect) = 0
parameters(x::QSelect) = nothing
change_positions(x::QSelect, m::AbstractDict) = QSelect(m[x.position], x.state)

active_parameters(x::Union{QMeasure, QSelect}) = nothing
activate_parameter!(x::Union{QMeasure, QSelect}, j::Int) = x
activate_parameters!(x::Union{QMeasure, QSelect}) = x
deactivate_parameter!(x::Union{QMeasure, QSelect}, j::Int) = x
deactivate_parameters!(x::Union{QMeasure, QSelect}) = x
reset_parameters_util!(x::Union{QMeasure, QSelect}, p::Vector{<:Real}, pos::Int) = pos
shift(x::Union{QMeasure, QSelect}, j::Int) = _shift_gate_util!(x, j, Dict{Int, Int}())


const CircuitElement = AbstractInstruction


"""
    QCircuit <: QuantumCircuit

A quantum circuit representing a sequence of quantum operations (gates, channels, measurements, or subcircuits).

# Fields
- `operations::Vector{CircuitElement}`: Sequence of quantum operations.

# Constructors
```julia
QCircuit()  # Create empty circuit
QCircuit(ops; copy=false)  # Reuse a compatible operation vector when possible
QCircuit(circuit::QCircuit; copy=true)  # Shallow-copy its operation vector
```

# Examples
```julia
# Create empty circuit
circuit = QCircuit()

# Add operations
push!(circuit, HGate(1))
push!(circuit, CNOTGate(1, 2))
push!(circuit, AmplitudeDamping(1, γ=0.1))

# Create from array
ops = [XGate(1), YGate(2), ZGate(3)]
circuit2 = QCircuit(ops)
```

# See also
- [`push!`](@ref): Add operation to circuit.
- [`append!`](@ref): Append operations to circuit.
- [`QMeasure`](@ref): Measurement operation.
- [`QSelect`](@ref): Post-selection operation.

# Ownership
`copy=true` copies the operation vector, not its instructions. With `copy=false`,
a `Vector{AbstractInstruction}` is stored directly; other vector types are
converted to that representation and therefore receive a new container.
`QCircuit(existing)` and `copy(existing)` shallow-copy the container by default.
Nested circuits and mutable instruction parameters remain shared. Use
`copy_instruction` for an independent instruction tree.
"""
struct QCircuit <: QuantumCircuit
	operations::Vector{CircuitElement}

	function QCircuit(operations::Vector{CircuitElement}; copy::Bool=false)
		return new(copy ? Base.copy(operations) : operations)
	end
end

function QCircuit(operations::AbstractVector; copy::Bool=false)
	all(operation -> operation isa AbstractInstruction, operations) ||
		throw(ArgumentError("a circuit accepts only AbstractInstruction values; observables are not instructions"))
	return QCircuit(CircuitElement[operations...])
end

QCircuit() = QCircuit(Vector{CircuitElement}())
QCircuit(x::QCircuit; copy::Bool=true) = QCircuit(x.operations; copy=copy)
Base.similar(circuit::QCircuit) = QCircuit()
Base.copy(circuit::QCircuit) = QCircuit(copy(circuit.operations))
Base.length(x::QCircuit) = length(x.operations)
Base.getindex(x::QCircuit, j::Int) = x.operations[j]
function Base.setindex!(x::QCircuit, v, j::Int)
	v isa AbstractInstruction || throw(ArgumentError("a circuit accepts only AbstractInstruction values"))
	return setindex!(x.operations, v, j)
end
Base.iterate(x::QCircuit) = iterate(x.operations)
Base.iterate(x::QCircuit, state) = iterate(x.operations, state)
Base.eltype(x::QCircuit) = eltype(x.operations)
Base.empty!(x::QCircuit) = (empty!(x.operations); x)
Base.isempty(x::QCircuit) = isempty(x.operations)
Base.firstindex(x::QCircuit) = firstindex(x.operations)
Base.lastindex(x::QCircuit) = lastindex(x.operations)
Base.reverse(x::QCircuit) = QCircuit(reverse(x.operations))

"""
	Base.:*(x::QCircuit, y::QCircuit)
	Do we need it?
"""
Base.:*(x::QCircuit, y::QCircuit) = QCircuit(vcat(y.operations, x.operations))
Base.adjoint(x::QCircuit) = QCircuit(adjoint.(Iterators.reverse(x.operations)))

"""
    push!(circuit::QCircuit, operation::CircuitElement) -> QCircuit

Add a quantum operation to the end of a circuit.

# Arguments
- `circuit::QCircuit`: The quantum circuit.
- `operation::CircuitElement`: Operation to add (Gate, AbstractQuantumMap, QMeasure, QSelect, or QCircuit).

# Returns
- `QCircuit`: The modified circuit (mutated in-place).

# Examples
```julia
circuit = QCircuit()
push!(circuit, HGate(1))          # Add Hadamard gate
push!(circuit, CNOTGate(1, 2))    # Add CNOT gate
push!(circuit, QMeasure([1, 2]))  # Add measurement
```

# See also
- [`append!`](@ref): Append multiple operations.
"""
Base.push!(x::QCircuit, s::CircuitElement) = (push!(x.operations, s); x)
Base.push!(::QCircuit, ::QuantumOperation) =
	throw(ArgumentError("a circuit accepts only AbstractInstruction values; observables are not instructions"))
# Base.push!(x::QCircuit, s::QCircuit) = push!(x.operations, s)
Base.append!(x::QCircuit, s::Vector{<:CircuitElement}) = (append!(x.operations, s); x)
function Base.append!(x::QCircuit, operations::AbstractVector)
	all(operation -> operation isa AbstractInstruction, operations) ||
		throw(ArgumentError("a circuit accepts only AbstractInstruction values; observables are not instructions"))
	append!(x.operations, operations)
	return x
end
"""
    append!(circuit::QCircuit, other::QCircuit) -> QCircuit

Append all operations from another circuit to the end of this circuit.

# Arguments
- `circuit::QCircuit`: The quantum circuit to append to.
- `other::QCircuit`: Another quantum circuit whose operations will be appended.

# Returns
- `QCircuit`: The modified circuit (mutated in-place).

# Examples
```julia
circuit1 = QCircuit([HGate(1), CNOTGate(1, 2)])
circuit2 = QCircuit([XGate(3), YGate(4)])
append!(circuit1, circuit2)  # circuit1 now contains all four operations
```

# See also
- [`push!`](@ref): Add single operation.
- [`append!(circuit::QCircuit, ops::Vector)`](@ref): Append array of operations.
"""
Base.append!(x::QCircuit, s::QCircuit) = (append!(x.operations, s.operations); x)
Base.push!(x::QCircuit, s::Tuple{Int, <:AbstractMatrix}) = push!(x, gate(s[1], s[2]))
Base.push!(x::QCircuit, s::Tuple{NTuple{N, Int}, <:AbstractMatrix}) where N = push!(x, gate(s[1], s[2]))

change_positions(x::QCircuit, m::AbstractDict) = QCircuit([change_positions(o, m) for o in x.operations])

shift(x::QCircuit, j::Int) = _shift_gate_util!(x, j, Dict{Int, Int}())

function positions(x::QCircuit)
	pos = Set{Int}()
	for g in x
		r = positions(g)
		for item in r
			push!(pos, item)
		end
	end
	return sort([pos...])
end

function nparameters(x::QCircuit)
	n = 0
	for o in x
		n += nparameters(o)
	end
	return n
end

function _circuit_parameter_values(read_parameters, x::QCircuit)
	chunks = AbstractVector[]
	for o in x
		p = read_parameters(o)
		if !isnothing(p) && !isempty(p)
			push!(chunks, p)
		end
	end
	isempty(chunks) && return Float64[]
	T = reduce(promote_type, eltype.(chunks))
	paras = T[]
	for chunk in chunks
		append!(paras, chunk)
	end
	return paras
end
parameters(x::QCircuit) = _circuit_parameter_values(parameters, x)
active_parameters(x::QCircuit) = _circuit_parameter_values(active_parameters, x)

function activate_parameter!(x::QCircuit, j::Int)
	_require_numeric_parameter_mutation(x)
	x[j] = _checked_instruction_result(activate_parameters!(x[j]), :activate_parameters!)
	return x
end
function activate_parameters!(x::QCircuit)
	_require_numeric_parameter_mutation(x)
	for j in eachindex(x.operations)
		x[j] = _checked_instruction_result(activate_parameters!(x[j]), :activate_parameters!)
	end
	return x
end
function deactivate_parameter!(x::QCircuit, j::Int)
	_require_numeric_parameter_mutation(x)
	x[j] = _checked_instruction_result(deactivate_parameters!(x[j]), :deactivate_parameters!)
	return x
end
function deactivate_parameters!(x::QCircuit)
	_require_numeric_parameter_mutation(x)
	for j in eachindex(x.operations)
		x[j] = _checked_instruction_result(deactivate_parameters!(x[j]), :deactivate_parameters!)
	end
	return x
end

function reset_parameters!(x::QCircuit, p::AbstractVector{<:Real})
	_require_numeric_parameter_mutation(x)
	_check_parameter_values(x, p)
	pos = 0
	for j in eachindex(x.operations)
		n = nparameters(x[j])
		x[j] = _checked_reset_result(reset_parameters!(x[j], view(p, pos+1:pos+n)), n)
		pos += n
	end
	return x
end

# Preserve the legacy cursor adapter while using the public replacement-aware
# instruction writer for the circuit traversal itself.
function reset_parameters_util!(x::QCircuit, p::Vector{<:Real}, pos::Int)
	n = nparameters(x)
	reset_parameters!(x, view(p, pos+1:pos+n))
	return pos + n
end

copy_instruction(x::QCircuit) = QCircuit([copy_instruction(instruction) for instruction in x])

function _shift_gate_util!(x::QCircuit, j::Int, m::AbstractDict)
	r = similar(x)
	for item in x
		push!(r, _shift_gate_util!(item, j, m))
	end
	return r
end
