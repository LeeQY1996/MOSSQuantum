struct _ExecutionParameterSlot
    instruction::Gate
    slots::UnitRange{Int}
end

"""A snapshot of a CPU circuit, state, fixed noise and validation. Treat fields as read-only."""
struct ExecutionPlan{S,M}
    template::QCircuit
    initial::S
    parameter_map::ParameterMap
    operations::Vector{Any}
    method::M
    readout::Vector{ReadoutError}
    classical::ClassicalRegister
    qubits::Vector{Int}
    expanded::Vector{Int}
    deterministic::Bool
end

"""A bound execution snapshot. Repeated calls share no mutable execution buffers."""
struct BoundExecutionPlan{P}
    plan::P
    operations::Vector{Any}
    parameters::Vector{Float64}
    prepared_state::Any
    distribution::Any
end

function _execution_skeleton(circuit,initial,method,offset=Ref(0))
    output = Any[]
    for op in circuit
        if op isa QCircuit
            append!(output,_execution_skeleton(op,initial,method,offset))
        elseif op isa Conditional
            yes = _execution_skeleton(op.then_branch,initial,method,offset)
            no = _execution_skeleton(op.else_branch,initial,method,offset)
            push!(output,_CompiledConditional(op.condition,yes,no))
        elseif nparameters(op)>0
            op isa Gate || throw(ArgumentError("prepared execution supports active parameters on gates only"))
            n = nparameters(op)
            push!(output,_ExecutionParameterSlot(op,offset[]+1:offset[]+n))
            offset[] += n
        else
            _noise_preflight!(output,QCircuit([op]),initial,CPUBackend(),method)
        end
    end
    return output
end

"""
    prepare_execution(circuit, initial; parameter_map, method, noise_model,
                      readout, classical, qubits)

Snapshot and validate one dense CPU state (not a state batch). Noise factories
are expanded once, then frozen. `bind_execution(plan, values)` binds only active
gates and caches deterministic output distributions. Rebuild the plan to change
state, circuit structure, measurement selection, or noise configuration.
"""
function prepare_execution(circuit::QCircuit,initial::AbstractQuantumState;
        parameter_map::ParameterMap=ParameterMap(circuit),method=DensityMatrixEvolution(),
        noise_model=nothing,readout=ReadoutError[],classical=nothing,qubits=1:nqubits(initial))
    initial isa Union{StateVector,DensityMatrix} && supports(CPUBackend(),method,initial) ||
        throw(UnsupportedOperation(CPUBackend(),method,initial,:apply))
    _check_parameter_map(circuit,parameter_map)
    snapshot,errors = _noise_configuration(copy_instruction(circuit),noise_model,readout)
    _check_parameter_map(snapshot,parameter_map)
    state = copy(initial)
    register = _initial_classical(classical)
    indices = _readout_qubits(state,qubits)
    _,expanded = _check_noise_execution(snapshot,state,CPUBackend(),method,indices,errors;classical=register)
    ops = _execution_skeleton(snapshot,state,method)
    return ExecutionPlan(snapshot,state,parameter_map,ops,method,errors,register,indices,expanded,
                         method isa DensityMatrixEvolution && _shot_deterministic(snapshot))
end
function _bind_execution_ops(ops,flat,plan)
    output = Any[]
    for op in ops
        if op isa _ExecutionParameterSlot
            gate = bind_parameters(op.instruction,view(flat,op.slots))
            # Custom writers may change support: validate every new active gate.
            validate_positions(gate,nqubits(plan.initial))
            supports(CPUBackend(),gate,plan.initial) || throw(UnsupportedOperation(CPUBackend(),gate,plan.initial,:apply))
            _noise_preflight!(output,QCircuit([gate]),plan.initial,CPUBackend(),plan.method)
        elseif op isa _CompiledConditional
            push!(output,_CompiledConditional(op.condition,_bind_execution_ops(op.then_branch,flat,plan),
                                              _bind_execution_ops(op.else_branch,flat,plan)))
        else
            push!(output,op)
        end
    end
    return output
end
function _execution_values(plan,values)
    _check_gradient_input(values)
    length(values)==nparameters(plan.parameter_map) || throw(DimensionMismatch("independent parameter count disagrees"))
    x = Float64[values...]
    all(isfinite,x) || throw(ArgumentError("parameters overflow Float64"))
    return x
end
function _prepared_evolve(ops,state)
    for op in ops
        state = apply!(CPUBackend(),op,state)
    end
    return state
end
function _bind_execution(plan::ExecutionPlan,values::AbstractVector{<:Real};prepare::Bool=true)
    x = _execution_values(plan,values)
    ops = _bind_execution_ops(plan.operations,x[parameter_indices(plan.parameter_map)],plan)
    return _finish_execution(plan,ops,x;prepare=prepare)
end
function _finish_execution(plan,ops,x;prepare::Bool=true)
    state = prepare && plan.deterministic ? _prepared_evolve(ops,copy(plan.initial)) : nothing
    distribution = isnothing(state) ? nothing : _shot_distribution(state,CPUBackend(),plan.expanded)
    return BoundExecutionPlan(plan,ops,x,state,distribution)
end

bind_execution(plan::ExecutionPlan,values::AbstractVector{<:Real}=Float64[]) = _bind_execution(plan,values)

"""Optional reusable buffers tied to one bound plan. Concurrent uses serialize on a lock."""
struct ExecutionWorkspace{P,W}
    owner::P
    trajectory::W
    lock::ReentrantLock
end
ExecutionWorkspace(bound::BoundExecutionPlan) = ExecutionWorkspace(bound,
    bound.plan.method isa KrausTrajectory ? _trajectory_workspace(bound.plan.initial,bound.operations) : nothing,
    ReentrantLock())

function _prepared_options(shots,result,parallel,chunk_size,method)
    n = _execution_shots(shots)
    result in (:full,:counts) || throw(ArgumentError("result must be :full or :counts"))
    chunk_size isa Integer && !(chunk_size isa Bool) && 0<chunk_size<=typemax(Int) || throw(ArgumentError("chunk_size must be a positive Int"))
    parallel && !(method isa KrausTrajectory) && throw(ArgumentError("parallel shots require KrausTrajectory"))
    return n
end
function execute(bound::BoundExecutionPlan;shots::Integer,rng::Random.AbstractRNG=Random.default_rng(),
                 result::Symbol=:full,parallel::Bool=false,chunk_size::Integer=256,workspace=nothing,budget=nothing)
    p = bound.plan
    n = _prepared_options(shots,result,parallel,chunk_size,p.method)
    !isnothing(workspace) && (!(workspace isa ExecutionWorkspace) || workspace.owner !== bound) &&
        throw(ArgumentError("workspace belongs to another bound execution"))
    work = isnothing(workspace) ? ExecutionWorkspace(bound) : workspace
    return _with_shot_budget(budget,n) do
      lock(work.lock) do
        _execute_prepared(p.initial,CPUBackend(),p.readout,p.method,p.qubits,bound.operations,p.expanded,
            p.deterministic,bound.distribution,p.classical;count_shots=n,rng,result,parallel,chunk_size,
            workspace=work.trajectory)
      end
    end
end
execute(plan::ExecutionPlan,values::AbstractVector{<:Real}=Float64[];kwargs...) = execute(bind_execution(plan,values);kwargs...)
