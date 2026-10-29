MOSSQuantum.backend(::CUDAState) = CUDABackend()

function MOSSQuantum.supports(backend::CUDABackend, circuit::MOSSQuantum.QCircuit,
                       state::MOSSQuantum.AbstractQuantumState; action::Symbol=:apply)
    return state isa CUDAState && eltype(state) <: Scalar && action === :apply &&
        all(instruction -> MOSSQuantum.supports(backend, instruction, state), circuit)
end

function MOSSQuantum.supports(::CUDABackend, gate::MOSSQuantum.Gate, state::CUDAState; action::Symbol=:apply)
    return eltype(state) <: Scalar && action in (:apply, :expectation) && 1 <= MOSSQuantum.nqubits(gate) <= 5
end
MOSSQuantum.supports(::CUDABackend, ::Union{MOSSQuantum.QubitsTerm,MOSSQuantum.QubitsOperator}, state::CUDAState;
              action::Symbol=:apply) = eltype(state) <: Scalar && action === :expectation
MOSSQuantum.supports(::CUDABackend, ::typeof(MOSSQuantum.probabilities), state::CUDAState;
              action::Symbol=:apply) = eltype(state) <: Scalar && action === :probabilities

function _check_state(state::CUDAState)
    eltype(state) <: Scalar || throw(ArgumentError("unsupported CUDA state scalar type"))
    CUDA.device(MOSSQuantum.storage(state)) == CUDA.device() ||
        throw(ArgumentError("select the state's CUDA device before execution"))
    return nothing
end

function _require_support(backend, operation, state; action=:apply)
    MOSSQuantum.supports(backend, operation, state; action=action) ||
        throw(MOSSQuantum.UnsupportedOperation(backend, operation, state, action))
    _check_state(state)
    return nothing
end

function _execute(prepared::PreparedGate, state::CUDAState)
    output = _gate_output(MOSSQuantum.storage(state), prepared)
    if eltype(output) === eltype(state)
        copyto!(MOSSQuantum.storage(state), output)
        CUDA.synchronize()
        return state
    end
    return MOSSQuantum.StateVector(output; preserve_storage=true)
end

function MOSSQuantum.apply!(backend::CUDABackend, gate::MOSSQuantum.Gate, state::CUDAState)
    _require_support(backend, gate, state)
    return _execute(_prepare_gate(gate, eltype(state), MOSSQuantum.nqubits(state)), state)
end

function MOSSQuantum.apply!(backend::CUDABackend, circuit::MOSSQuantum.QCircuit, state::CUDAState)
    _require_support(backend, circuit, state)
    plan = PreparedGate[]
    _prepare_circuit!(plan, circuit, eltype(state), MOSSQuantum.nqubits(state))
    for prepared in plan
        state = _execute(prepared, state)
    end
    return state
end
