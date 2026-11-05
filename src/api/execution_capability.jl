"""A static capability finding. `path` identifies nested circuit indices and branches."""
struct CapabilityIssue
    status::Symbol
    path::Tuple
    reason::String
end

"""
    CapabilityStep(status, state_types=(); reason="")

A backend's static assessment of one instruction. `status` is `:supported`,
`:unsupported`, or `:unknown`. A supported step must give every possible
resulting state type, including representation changes; an unsupported or
unknown step gives no state types. The assessment must not modify inputs or
consume random numbers.
"""
struct CapabilityStep
    status::Symbol
    state_types::Tuple
    reason::String
    function CapabilityStep(status::Symbol, state_types::Tuple=(); reason::AbstractString="")
        status in (:supported, :unsupported, :unknown) || throw(ArgumentError("invalid capability status"))
        all(t -> t isa Type && t <: AbstractQuantumState, state_types) ||
            throw(ArgumentError("capability state types must be quantum state types"))
        (status === :supported) == !isempty(state_types) ||
            throw(ArgumentError("only supported steps have resulting state types"))
        new(status, state_types, String(reason))
    end
end

"""
    execution_capability_step(backend, instruction, state_type; mode, method)

Extension hook for static capability analysis. Unknown backends return `:unknown`
by default. Implementations must account for the selected execution mode and
noise method, and return all possible output state types without executing the
instruction. This hook supplements the existing `supports` and backend preflight
protocols; it does not change them.
"""
execution_capability_step(::AbstractBackend, instruction, ::Type{S}; mode, method) where {S<:AbstractQuantumState} =
    CapabilityStep(:unknown; reason="backend has not declared a static transition for $(typeof(instruction))")

"""
    execution_capability_backend(backend, state; mode, method)

Backend extension hook for the selected state, mode and method. A supported
result asserts that the backend implements the mode's required state, copying,
measurement and terminal-readout protocols; instruction support is checked
separately. Unknown backends must remain unknown, including for empty circuits.
"""
execution_capability_backend(::AbstractBackend, ::AbstractQuantumState; mode, method) =
    CapabilityStep(:unknown; reason="backend has not declared execution-mode support")

function execution_capability_backend(::CPUBackend, state::AbstractQuantumState; mode, method)
    state isa _DenseCPUState && _cpu_storage_supported(state.data) ||
        return CapabilityStep(:unsupported; reason="CPU backend requires supported dense CPU storage")
    return CapabilityStep(:supported,(typeof(state),))
end

function execution_capability_step(::CPUBackend, op, ::Type{S}; mode, method) where {S<:AbstractQuantumState}
    # In execute, selection is implemented by measurement and rejection.
    check = op isa QSelect && mode in (:execute, :estimate) ? QMeasure(op.position; auto_reset=false) : op
    _cpu_supports(check, S, :apply) ||
        return CapabilityStep(:unsupported; reason="$(typeof(op)) is not supported for $S in $mode")
    if method isa KrausTrajectory && op isa QuantumMap
        return CapabilityStep(:supported, (S,))
    end
    return CapabilityStep(:supported, (_cpu_result_state(check, S),))
end

"""Static assessment of a complete execution configuration."""
struct ExecutionCapability
    status::Symbol
    issues::Vector{CapabilityIssue}
    final_state_types::Vector{Type}
end

function _capability_issue!(issues, status, path, reason)
    push!(issues, CapabilityIssue(status, path, String(reason)))
end

function _unbound_capability_issues!(issues, circuit::QCircuit, path=())
    for (index, instruction) in enumerate(circuit)
        itempath = (path..., index)
        if instruction isa QCircuit
            _unbound_capability_issues!(issues, instruction, itempath)
        elseif instruction isa Conditional
            _unbound_capability_issues!(issues, instruction.then_branch, (itempath..., :then))
            _unbound_capability_issues!(issues, instruction.else_branch, (itempath..., :else))
        elseif instruction isa QuantumCircuits.ParameterizedInstruction
            _capability_issue!(issues, :unknown, itempath,
                "parameter template requires complete numeric binding before backend capability can be determined")
        end
    end
    return issues
end

function _capability_walk!(issues, b, circuit::QCircuit, state_types, mode, method, n, path)
    types = state_types
    for (index, op) in enumerate(circuit)
        itempath = (path..., index)
        if op isa QCircuit
            types = _capability_walk!(issues,b,op,types,mode,method,n,itempath)
        elseif op isa Conditional
            if mode === :apply
                _capability_issue!(issues,:unsupported,itempath,"classical control requires simulate or execute")
                return Type[]
            end
            yes = _capability_walk!(issues,b,op.then_branch,types,mode,method,n,(itempath...,:then))
            no = _capability_walk!(issues,b,op.else_branch,types,mode,method,n,(itempath...,:else))
            types = unique(vcat(yes,no))
        else
            try
                validate_positions(op,n)
            catch e
                if e isa Union{ArgumentError,DimensionMismatch,BoundsError}
                    _capability_issue!(issues,:unsupported,itempath,sprint(showerror,e))
                    return Type[]
                end
                rethrow()
            end
            next = Type[]
            for T in types
                step = execution_capability_step(b,op,T;mode=mode,method=method)
                step isa CapabilityStep || throw(ArgumentError("execution_capability_step must return CapabilityStep"))
                if step.status === :supported
                    append!(next,step.state_types)
                else
                    _capability_issue!(issues,step.status,itempath,isempty(step.reason) ? "instruction capability not declared" : step.reason)
                end
            end
            types = unique(next)
        end
        isempty(types) && return types
    end
    return types
end

"""
    execution_capability(backend, circuit, state; mode=:simulate, method=DensityMatrixEvolution(),
                         qubits=nothing, readout=ReadoutError[], classical=nothing,
                         noise_model=nothing, result=:full, parallel=false,
                         observable=nothing, grouping=:qwc, shots=nothing)

Statically inspect an execution request without evolving the state, expanding
noise factories, or drawing random numbers. `qubits` is accepted only for
`:execute`; `nothing` selects all qubits. `mode` is `:apply`, `:simulate`,
`:execute`, or `:estimate`; the latter requires `observable`. The result status
is `:supported`, `:unsupported`, or `:unknown`;
`issues` includes nested instruction paths. A supported report concerns the
capability and structural validity only: data-dependent properties such as state
normalization and the probability of a post-selection are checked by execution.

External backends opt in by implementing `execution_capability_backend` and
`execution_capability_step`. Reports
are conservative if a backend or an option cannot be analyzed statically. Noise
models with factories are not expanded by this query and are reported unknown;
use an already expanded circuit to inspect its individual instructions.
"""
function execution_capability(b::AbstractBackend, circuit::QCircuit, state::AbstractQuantumState;
        mode::Symbol=:simulate, method=DensityMatrixEvolution(), qubits=nothing,
        readout=ReadoutError[], classical=nothing, noise_model=nothing,
        result::Symbol=:full, parallel::Bool=false, observable=nothing,
        grouping::Symbol=:qwc, atol::Real=0, max_terms::Integer=100_000, shots=nothing)
    mode in (:apply,:simulate,:execute,:estimate) || throw(ArgumentError("invalid execution capability mode"))
    if mode !== :execute && !isnothing(qubits)
        return ExecutionCapability(:unsupported,
            CapabilityIssue[CapabilityIssue(:unsupported,(),"qubits is only accepted for execute; estimate selects qubits by measurement group")],Type[])
    end
    if QuantumCircuits._has_parameterized(circuit)
        issues = _unbound_capability_issues!(CapabilityIssue[], circuit)
        return ExecutionCapability(:unknown, issues, Type[])
    end
    if mode === :estimate
        return _estimation_capability(b,circuit,state;method,readout,classical,noise_model,
                                      result,parallel,observable,grouping,atol,max_terms,shots)
    end
    issues = CapabilityIssue[]
    if !isnothing(observable) || grouping !== :qwc || atol != 0 || max_terms != 100_000
        _capability_issue!(issues,:unsupported,(),"observable, grouping, atol and max_terms are estimate options")
    end
    if !isnothing(shots)
        if mode !== :execute
            _capability_issue!(issues,:unsupported,(),"shots is only accepted for execute or estimate")
        else
            try
                shots isa Integer || throw(ArgumentError("shots must be an integer"))
                _execution_shots(shots)
            catch e
                if e isa Union{ArgumentError,DimensionMismatch,BoundsError,DomainError}
                    _capability_issue!(issues,:unsupported,(),sprint(showerror,e))
                else
                    rethrow()
                end
            end
        end
    end
    if mode === :apply && (!isnothing(classical) || !isnothing(noise_model) ||
                          readout isa ReadoutError || !isempty(readout) || !(method isa DensityMatrixEvolution) ||
                          result !== :full || parallel)
        _capability_issue!(issues,:unsupported,(),"apply mode does not accept execution options or classical control")
    end
    stochastic = method isa AbstractNoiseMethod && _stochastic_noise_method(method)
    if !(method isa AbstractNoiseMethod)
        _capability_issue!(issues,:unsupported,(),"unsupported execution method")
    elseif stochastic && !supports(b,method,state)
        _capability_issue!(issues,:unsupported,(),"backend does not support the selected stochastic method and state")
    elseif !stochastic && !(method isa DensityMatrixEvolution)
        _capability_issue!(issues,:unsupported,(),"backend does not support the selected execution method")
    end
    mode === :execute && !(result in (:full,:counts)) &&
        _capability_issue!(issues,:unsupported,(),"result must be :full or :counts")
    mode === :execute && parallel && !(method isa KrausTrajectory) &&
        _capability_issue!(issues,:unsupported,(),"parallel execution requires KrausTrajectory")
    mode !== :execute && (result !== :full || parallel) &&
        _capability_issue!(issues,:unsupported,(),"result and parallel options apply only to execute")
    modecap = execution_capability_backend(b,state;mode=mode,method=method)
    modecap isa CapabilityStep || throw(ArgumentError("execution_capability_backend must return CapabilityStep"))
    modecap.status !== :supported && _capability_issue!(issues,modecap.status,(),modecap.reason)
    if mode === :simulate && _has_postselection(circuit) &&
       (_has_classical(circuit) || !isnothing(classical) || stochastic)
        _capability_issue!(issues,:unsupported,(),"dynamic or trajectory simulate does not support forced post-selection")
    end
    # Expanding a NoiseModel can call arbitrary user factories and can remove
    # Delay instructions. Inspecting the unexpanded circuit and treating its
    # failures as definitive would therefore be unsound as well as impure.
    if !isnothing(noise_model)
        _capability_issue!(issues,:unknown,(),"noise models are not expanded during capability queries")
        status = any(i -> i.status === :unsupported,issues) ? :unsupported : :unknown
        return ExecutionCapability(status,issues,Type[])
    end
    try
        validate_positions(circuit,nqubits(state))
        if mode !== :apply
            _validate_classical_flow(circuit,_initial_classical(classical))
            requested = isnothing(qubits) ? (mode === :execute ? (1:nqubits(state)) : Int[]) : qubits
            indices = _readout_qubits(state,requested)
            errors = readout isa ReadoutError ? [readout] : ReadoutError[readout...]
            _readout_register(errors,indices,nqubits(state))
        end
        checked_circuit = stochastic && !(method isa KrausTrajectory) ? _stochastic_validation_circuit(circuit) : circuit
        validate_backend_execution(b,checked_circuit,state;mode=mode)
    catch e
        if e isa Union{ArgumentError,DimensionMismatch,BoundsError,DomainError,UnsupportedOperation}
            _capability_issue!(issues,:unsupported,(),sprint(showerror,e))
        else
            rethrow()
        end
    end
    # Match the existing complete-program preflight, which validates both
    # branches and converts QSelect to a measurement for shot execution.
    if b isa CPUBackend && mode !== :apply && state isa _DenseCPUState && _cpu_storage_supported(state.data)
        try
            checked = _shot_validation_circuit(circuit,state,b)
            supports(b,checked,state) || _capability_issue!(issues,:unsupported,(),"the execution preflight rejects the complete circuit")
            if mode === :execute || _has_classical(circuit) || !isnothing(classical) ||
               readout isa ReadoutError || !isempty(readout) || method isa KrausTrajectory
                _noise_preflight!(Any[],circuit,state,b,method)
            end
        catch e
            if e isa Union{ArgumentError,DimensionMismatch,BoundsError,DomainError,UnsupportedOperation}
                _capability_issue!(issues,:unsupported,(),sprint(showerror,e))
            else
                rethrow()
            end
        end
    end
    types = _capability_walk!(issues,b,circuit,Type[typeof(state)],mode,method,nqubits(state),())
    status = any(i -> i.status === :unsupported,issues) ? :unsupported :
             any(i -> i.status === :unknown,issues) ? :unknown : :supported
    return ExecutionCapability(status,issues,types)
end

function _estimation_capability(b,circuit,state;method,readout,classical,noise_model,
                                result,parallel,observable,grouping,atol,max_terms,shots)
    issues = CapabilityIssue[]
    result === :full || _capability_issue!(issues,:unsupported,(),"result is not an estimate option")
    _has_postselection(circuit) && _capability_issue!(issues,:unsupported,(),"estimate does not support post-selection")
    if !(observable isa Union{QubitsTerm,QubitsOperator,MeasurementPlan})
        _capability_issue!(issues,:unsupported,(),"estimate requires a Pauli observable or MeasurementPlan")
        return ExecutionCapability(:unsupported,issues,Type[])
    end
    plan = try
        p = observable isa MeasurementPlan ? observable :
            measurement_plan(observable;grouping=grouping,atol=atol,max_terms=max_terms)
        p.nqubits <= nqubits(state) || throw(ArgumentError("observable acts outside the state's register"))
        if !isnothing(shots)
            shots isa Integer || throw(ArgumentError("shots must be an integer"))
            _measurement_allocations(p,shots)
        end
        p
    catch e
        if e isa Union{ArgumentError,DimensionMismatch,BoundsError,DomainError}
            _capability_issue!(issues,:unsupported,(),sprint(showerror,e))
            return ExecutionCapability(:unsupported,issues,Type[])
        end
        rethrow()
    end
    base = execution_capability(b,circuit,state;mode=:execute,method,readout,classical,
                                noise_model,parallel,qubits=Int[])
    append!(issues,base.issues)
    for (index,group) in enumerate(plan.groups)
        measured = QCircuit([circuit,_measurement_rotation(group)])
        check = execution_capability(b,measured,state;mode=:execute,method,readout,classical,
                                     noise_model,parallel,qubits=group.qubits)
        for issue in check.issues
            _capability_issue!(issues,issue.status,(:measurement_group,index,issue.path...),issue.reason)
        end
    end
    status = any(i -> i.status === :unsupported,issues) ? :unsupported :
             any(i -> i.status === :unknown,issues) ? :unknown : :supported
    return ExecutionCapability(status,issues,base.final_state_types)
end

execution_capability(circuit::QCircuit, state::AbstractQuantumState; kwargs...) =
    execution_capability(backend(state),circuit,state;kwargs...)

function execution_capability(b::AbstractBackend, program::NoisyCircuit, state::AbstractQuantumState;
                              mode::Symbol=:simulate, noise_model=nothing, readout=ReadoutError[], kwargs...)
    if mode === :apply
        return ExecutionCapability(:unsupported,
            CapabilityIssue[CapabilityIssue(:unsupported,(),"NoisyCircuit has no apply! entry point")],Type[])
    end
    if !isnothing(noise_model)
        return ExecutionCapability(:unsupported,
            CapabilityIssue[CapabilityIssue(:unsupported,(),"noise is already expanded")],Type[])
    end
    errors = readout isa ReadoutError ? [readout] : ReadoutError[readout...]
    return execution_capability(b,program.circuit,state;mode,readout=vcat(program.readout,errors),kwargs...)
end
execution_capability(program::NoisyCircuit, state::AbstractQuantumState;kwargs...) =
    execution_capability(backend(state),program,state;kwargs...)
