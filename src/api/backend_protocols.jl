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
`action` identifies the requested API, such as `:apply`, `:expectation`, or
`:probabilities`. The error records types rather than state
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

# CPU kernels use scalar indexing and assume disjoint, column-major storage.
# Only known host arrays and contiguous views rooted in them are admitted.
_cpu_storage_supported(::AbstractArray) = false
_cpu_storage_supported(::Array) = true
function _cpu_storage_supported(data::SubArray)
    _cpu_storage_supported(parent(data)) || return false
    all(index -> index isa Union{Integer,UnitRange,Base.Slice{<:Base.OneTo}},
        parentindices(data)) || return false
    all(axis -> axis isa Base.OneTo, axes(data)) || return false
    isempty(data) && return true
    expected = 1
    for dimension in 1:ndims(data)
        size(data, dimension) > 1 && stride(data, dimension) != expected && return false
        expected *= size(data, dimension)
    end
    return true
end
_cpu_storage_supported(data::Base.ReshapedArray) = _cpu_storage_supported(parent(data))

function backend(state::Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix})
    _cpu_storage_supported(state.data) && return CPUBackend()
    throw(ArgumentError("no default backend is registered for dense storage $(typeof(state.data)); implement backend(state) for this storage type"))
end

@inline function _require_cpu_storage(state::Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix},
                                     operation, action::Symbol=:apply)
    _cpu_storage_supported(state.data) ||
        throw(UnsupportedOperation(CPUBackend(), operation, state, action))
    return nothing
end

"""
    supports(backend, operation, state; action=:apply) -> Bool

Query whether a backend implements `:apply`, `:expectation`, or `:probabilities`
for an operation and state. Readout support passes `probabilities` as the operation.
Unknown capabilities return `false`. This query describes implemented
capabilities; register bounds are checked separately by `validate_positions`.

The default circuit query requires support for every instruction. Backends whose
instructions change the state representation must specialize that query to track
those transitions. The CPU implementation tracks pure-to-mixed transitions.
"""
supports(::AbstractBackend, operation, ::AbstractQuantumState; action::Symbol=:apply) = false

function supports(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState; action::Symbol=:apply)
    return action === :apply && all(operation -> supports(b, operation, state; action=action), circuit)
end

# Dense state families; CPU support also requires an eligible storage layout.
const _DenseCPUState = Union{StateVector,DensityMatrix,BatchStateVector,BatchDensityMatrix}

function supports(::CPUBackend, operation, state::AbstractQuantumState; action::Symbol=:apply)
    return state isa _DenseCPUState && _cpu_storage_supported(state.data) &&
        _cpu_supports(operation, typeof(state), action)
end

function supports(::CPUBackend, circuit::QCircuit, state::AbstractQuantumState; action::Symbol=:apply)
    return action === :apply && state isa _DenseCPUState && _cpu_storage_supported(state.data) &&
        _cpu_circuit_state(circuit, typeof(state)) !== nothing
end

_cpu_supports(operation, ::Type, ::Symbol) = false

function _cpu_supports(operation::Gate, ::Type{S}, action::Symbol) where S
    if action === :apply
        return S <: _DenseCPUState && 1 <= nqubits(operation) <= 5
    elseif action === :expectation
        return S <: Union{StateVector,BatchStateVector,BatchDensityMatrix} && 1 <= nqubits(operation) <= 5
    end
    return false
end

function _cpu_supports(operation::QuantumMap, ::Type{S}, action::Symbol) where S
    # A map on N qubits applies a supermatrix to 2N vectorized density axes.
    return action === :apply && S <: _DenseCPUState && 1 <= nqubits(operation) <= 2
end

_cpu_supports(operation::QMeasure, ::Type{S}, action::Symbol) where S =
    action === :apply && S <: _DenseCPUState && operation.keep

_cpu_supports(::QSelect, ::Type{S}, action::Symbol) where S =
    action === :apply && S <: Union{StateVector,BatchStateVector,BatchDensityMatrix}

_cpu_supports(::Union{QubitsTerm,QubitsOperator}, ::Type{S}, action::Symbol) where S =
    action === :expectation && S <: _DenseCPUState

_cpu_supports(::AbstractMatrix, ::Type{S}, action::Symbol) where S =
    action === :expectation && S <: Union{StateVector,BatchStateVector,BatchDensityMatrix}

_cpu_result_state(operation, ::Type{S}) where S = S
_cpu_result_state(::QuantumMap, ::Type{S}) where {S<:StateVector} = DensityMatrix
_cpu_result_state(::QuantumMap, ::Type{S}) where {S<:BatchStateVector} = BatchDensityMatrix

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

Execute an instruction using an explicitly selected backend. CPU methods call
internal implementations, retaining public instruction hooks within circuits and
the existing measurement metadata return conventions.
Unknown combinations throw `UnsupportedOperation`. Backend extensions validate
positions before mutating their state and return the resulting state.
"""
function apply!(b::AbstractBackend, operation, state::AbstractQuantumState; kwargs...)
    throw(UnsupportedOperation(b, operation, state, :apply))
end

function apply!(b::CPUBackend, operation::AbstractInstruction, state::_DenseCPUState; kwargs...)
    _require_cpu_storage(state, operation)
    supports(b, operation, state) || throw(UnsupportedOperation(b, operation, state, :apply))
    validate_positions(operation, nqubits(state))
    return _cpu_apply!(operation, state; kwargs...)
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
function apply!(b::CPUBackend, circuit::QCircuit, state::_DenseCPUState;
                rng::Random.AbstractRNG=Random.default_rng())
    _require_cpu_storage(state, circuit)
    supports(b, circuit, state) || throw(UnsupportedOperation(b, circuit, state, :apply))
    validate_positions(circuit, nqubits(state))
    return _cpu_apply!(circuit, state; rng=rng)
end

# Existing dense methods are more specific and retain their behavior.
apply!(operation::AbstractInstruction, state::AbstractQuantumState; kwargs...) =
    apply!(backend(state), operation, state; kwargs...)
apply!(operation::AbstractInstruction, state::_DenseCPUState; kwargs...) =
    apply!(backend(state), operation, state; kwargs...)

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
    return _cpu_expectation(observable, state)
end

expectation(observable, state::AbstractQuantumState) = expectation(backend(state), observable, state)

# Dense conveniences always select a backend; the CPU adapter never recurses
# through these methods. External storage can therefore retain these state types.
expectation(observable, state::_DenseCPUState) = expectation(backend(state), observable, state)

function expectation(b::AbstractBackend, left::AbstractQuantumState, observable, right::AbstractQuantumState)
    throw(UnsupportedOperation(b, observable, right, :expectation))
end
function expectation(b::CPUBackend, left::_DenseCPUState, observable, right::_DenseCPUState)
    _require_cpu_storage(left, observable, :expectation)
    _require_cpu_storage(right, observable, :expectation)
    return _cpu_cross_expectation(left, observable, right)
end
expectation(left::StateVector, observable, right::StateVector) =
    expectation(backend(right), left, observable, right)
expectation(left::BatchStateVector, observable, right::BatchStateVector) =
    expectation(backend(right), left, observable, right)

function apply(b::AbstractBackend, operation, state::AbstractQuantumState; kwargs...)
    throw(UnsupportedOperation(b, operation, state, :apply))
end
function apply(b::CPUBackend, operation::Union{QMeasure,QSelect}, state::_DenseCPUState; kwargs...)
    _require_cpu_storage(state, operation)
    return _cpu_apply(operation, state; kwargs...)
end
apply(operation::Union{QMeasure,QSelect}, state::_DenseCPUState; kwargs...) =
    apply(backend(state), operation, state; kwargs...)

function apply(b::CPUBackend, observable::Union{QubitsTerm,QubitsOperator,AbstractMatrix}, state::_DenseCPUState)
    _require_cpu_storage(state, observable)
    return _cpu_linear_apply(observable, state)
end
_cpu_linear_apply(observable::Union{QubitsTerm,QubitsOperator}, state::_DenseBatchState) =
    _apply_batch_operator(observable, state)
function _cpu_linear_apply(observable::AbstractMatrix, state::StateVector)
    dimension = 2^nqubits(state)
    size(observable) == (dimension, dimension) || throw(DimensionMismatch("observable dimensions must match the state register"))
    return StateVector(observable * storage(state), nqubits(state))
end
function _cpu_linear_apply(observable::AbstractMatrix, state::BatchStateVector)
    _check_batch_observable(observable, state)
    return BatchStateVector(observable * storage(state), nqubits(state), batch_size(state))
end

function probabilities(b::AbstractBackend, state::AbstractQuantumState; qubits=1:nqubits(state))
    throw(UnsupportedOperation(b, probabilities, state, :probabilities))
end
function probabilities(b::CPUBackend, state::_DenseCPUState; qubits=1:nqubits(state))
    _require_cpu_storage(state, probabilities, :probabilities)
    return _cpu_probabilities(state; qubits=qubits)
end
probabilities(state::_DenseCPUState; qubits=1:nqubits(state)) =
    probabilities(backend(state), state; qubits=qubits)

function _apply_circuit_copy(circuit::QCircuit, state::_DenseCPUState)
    chosen = backend(state)
    supports(chosen, circuit, state) || throw(UnsupportedOperation(chosen, circuit, state, :apply))
    validate_positions(circuit, nqubits(state))
    return apply!(chosen, circuit, copy(state))
end

function apply!(instruction::QMeasure, state::_DenseCPUState;
                rng::Random.AbstractRNG=Random.default_rng())
    chosen = backend(state)
    if chosen isa CPUBackend
        # Keep the existing direct-call error for qubit-removing in-place
        # measurements; explicit CPU capability queries still reject them.
        !instruction.keep && return _cpu_apply!(instruction, state; rng=rng)
        return apply!(chosen, instruction, state; rng=rng)
    end
    instruction.keep || throw(UnsupportedOperation(chosen, instruction, state, :apply))
    return measure!(chosen, state, instruction.position;
                    auto_reset=instruction.auto_reset, rng=rng)
end

_cpu_supports(::typeof(probabilities), ::Type{S}, action::Symbol) where {S} =
    action === :probabilities && S <: _DenseCPUState
