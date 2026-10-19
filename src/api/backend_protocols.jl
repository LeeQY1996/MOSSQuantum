"""
    AbstractBackend

An execution backend for quantum states. Extensions implement `backend(state)`,
`supports(backend, operation, state; action=:apply)`, and the supported
`apply!(backend, instruction, state)` or `expectation(backend, observable, state)`
methods. An instruction method returns the resulting state; the legacy
`QMeasure` and `QSelect` methods keep their measurement metadata return values.
"""
abstract type AbstractBackend end

"""The existing dense CPU implementation."""
struct CPUBackend <: AbstractBackend end

"""
    UnsupportedOperation

The requested backend does not implement an operation for this state and action.
`action` is `:apply` or `:expectation`. The error records types rather than state
data, so displaying it does not expand a large quantum state.
"""
struct UnsupportedOperation <: Exception
    backend_type::Type
    operation_type::Type
    state_type::Type
    action::Symbol
end

UnsupportedOperation(b::AbstractBackend, operation, state::AbstractQuantumState, action::Symbol) =
    UnsupportedOperation(typeof(b), typeof(operation), typeof(state), action)

function Base.showerror(io::IO, error::UnsupportedOperation)
    print(io, error.backend_type, " does not support ", error.action, " for ",
          error.operation_type, " with ", error.state_type)
end

"""
    backend(state) -> AbstractBackend

Return the default execution backend for a state. External state representations
implement this method explicitly; there is no assumption about their storage.
"""
function backend(state::AbstractQuantumState)
    throw(ArgumentError("$(typeof(state)) must implement backend(state)"))
end

backend(::Union{StateVector,DensityMatrix,BatchStateVector}) = CPUBackend()

"""
    supports(backend, operation, state; action=:apply) -> Bool

Query whether a backend implements `:apply` or `:expectation` for an operation
and state. Unknown capabilities return `false`. This query describes implemented
capabilities; register bounds are checked separately by `validate_positions`.

The default circuit query requires support for every instruction. Backends whose
instructions change the state representation must specialize that query to track
those transitions. The CPU implementation tracks pure-to-mixed transitions.
"""
supports(::AbstractBackend, operation, ::AbstractQuantumState; action::Symbol=:apply) = false

function supports(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState; action::Symbol=:apply)
    return action === :apply && all(operation -> supports(b, operation, state; action=action), circuit)
end

const _DenseCPUState = Union{StateVector,DensityMatrix,BatchStateVector}

function supports(::CPUBackend, operation, state::AbstractQuantumState; action::Symbol=:apply)
    return _cpu_supports(operation, typeof(state), action)
end

function supports(::CPUBackend, circuit::QCircuit, state::AbstractQuantumState; action::Symbol=:apply)
    return action === :apply && state isa _DenseCPUState &&
        _cpu_circuit_state(circuit, typeof(state)) !== nothing
end

_cpu_supports(operation, ::Type, ::Symbol) = false

function _cpu_supports(operation::Gate, ::Type{S}, action::Symbol) where S
    if action === :apply
        return S <: _DenseCPUState && 1 <= nqubits(operation) <= 5
    elseif action === :expectation
        return S <: Union{StateVector,BatchStateVector} && 1 <= nqubits(operation) <= 5
    end
    return false
end

function _cpu_supports(operation::QuantumMap, ::Type{S}, action::Symbol) where S
    # A map on N qubits applies a supermatrix to 2N vectorized density axes.
    return action === :apply && S <: Union{StateVector,DensityMatrix} && 1 <= nqubits(operation) <= 2
end

_cpu_supports(operation::QMeasure, ::Type{S}, action::Symbol) where S =
    action === :apply && S <: _DenseCPUState && operation.keep

_cpu_supports(::QSelect, ::Type{S}, action::Symbol) where S =
    action === :apply && S <: Union{StateVector,BatchStateVector}

_cpu_supports(::Union{QubitsTerm,QubitsOperator}, ::Type{S}, action::Symbol) where S =
    action === :expectation && S <: _DenseCPUState

_cpu_supports(::AbstractMatrix, ::Type{S}, action::Symbol) where S =
    action === :expectation && S <: Union{StateVector,BatchStateVector}

_cpu_result_state(operation, ::Type{S}) where S = S
_cpu_result_state(::QuantumMap, ::Type{S}) where {S<:StateVector} = DensityMatrix

# Operators contain several register tuples rather than one positions list.
function QuantumCircuits.validate_positions(observable::QubitsOperator, n::Integer)
    n >= 0 || throw(ArgumentError("the number of qubits must be nonnegative"))
    for key in keys(observable.data), position in key
        1 <= position <= n ||
            throw(ArgumentError("qubit position $position must be between 1 and $n"))
    end
    return nothing
end

function _cpu_circuit_state(circuit::QCircuit, state_type::Type)
    for operation in circuit
        if operation isa QCircuit
            state_type = _cpu_circuit_state(operation, state_type)
            state_type === nothing && return nothing
        else
            _cpu_supports(operation, state_type, :apply) || return nothing
            state_type = _cpu_result_state(operation, state_type)
        end
    end
    return state_type
end

"""
    apply!(backend, instruction, state)

Execute an instruction using an explicitly selected backend. CPU methods adapt
the existing two-argument `apply!` methods, including their return conventions.
Unknown combinations throw `UnsupportedOperation`. Backend extensions validate
positions before mutating their state and return the resulting state.
"""
function apply!(b::AbstractBackend, operation, state::AbstractQuantumState)
    throw(UnsupportedOperation(b, operation, state, :apply))
end

function apply!(b::CPUBackend, operation::AbstractInstruction, state::_DenseCPUState)
    supports(b, operation, state) || throw(UnsupportedOperation(b, operation, state, :apply))
    validate_positions(operation, nqubits(state))
    return apply!(operation, state)
end

function _apply_backend_circuit!(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState)
    supports(b, circuit, state) || throw(UnsupportedOperation(b, circuit, state, :apply))
    validate_positions(circuit, nqubits(state))
    for operation in circuit
        result = apply!(b, operation, state)
        if result isa AbstractQuantumState
            state = result
        elseif !(operation isa Union{QMeasure,QSelect})
            throw(ArgumentError("apply! for $(typeof(operation)) must return an AbstractQuantumState"))
        end
    end
    return state
end

apply!(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState) =
    _apply_backend_circuit!(b, circuit, state)

# Resolve the circuit/backend intersection explicitly.
apply!(b::CPUBackend, circuit::QCircuit, state::_DenseCPUState) =
    _apply_backend_circuit!(b, circuit, state)

# Existing dense methods are more specific and retain their behavior.
apply!(operation::AbstractInstruction, state::AbstractQuantumState) =
    apply!(backend(state), operation, state)

"""
    expectation(backend, observable, state)

Evaluate an observable with an explicit backend. This is separate from applying
an instruction: Hamiltonian terms and operators are valid observables without
being executable circuit elements. Unknown combinations throw
`UnsupportedOperation`.
"""
function expectation(b::AbstractBackend, observable, state::AbstractQuantumState)
    throw(UnsupportedOperation(b, observable, state, :expectation))
end

function expectation(b::CPUBackend, observable, state::_DenseCPUState)
    supports(b, observable, state; action=:expectation) ||
        throw(UnsupportedOperation(b, observable, state, :expectation))
    if observable isa AbstractMatrix
        dimension = 2^nqubits(state)
        size(observable) == (dimension, dimension) ||
            throw(DimensionMismatch("observable dimensions must match the quantum state"))
    else
        validate_positions(observable, nqubits(state))
    end
    return expectation(observable, state)
end

expectation(observable, state::AbstractQuantumState) = expectation(backend(state), observable, state)
