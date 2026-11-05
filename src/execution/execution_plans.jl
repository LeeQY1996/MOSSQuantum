struct _ExecutionParameterSlot
    instruction::Gate
    slots::UnitRange{Int}
end

_parameter_deterministic(op::AbstractInstruction) = _shot_deterministic(op)
_parameter_deterministic(circuit::QCircuit) = all(_parameter_deterministic,circuit)
_parameter_deterministic(op::QuantumCircuits.ParameterizedInstruction) =
    _parameter_deterministic(op.prototype)

"""A snapshot of a CPU circuit, state, fixed noise and validation. Treat fields as read-only."""
struct ExecutionPlan{S,M,P<:AbstractParameterMap}
    template::QCircuit
    initial::S
    parameter_map::P
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

function _execution_parameter_structure(instruction::AbstractInstruction)
    if instruction isa QCircuit
        return (:circuit,Tuple(_execution_parameter_structure(child) for child in instruction))
    elseif instruction isa Conditional
        return (:conditional,_execution_parameter_structure(instruction.then_branch),
                _execution_parameter_structure(instruction.else_branch))
    end
    return (typeof(instruction),Tuple(positions(instruction)),nparameters(instruction))
end

function _prepare_execution_parameters(source;
        parameter_map=nothing,parameter_order=nothing,fixed=nothing,noise_model=nothing,readout=ReadoutError[])
    if source isa _ParameterContext
        source.template isa QCircuit || throw(ArgumentError("prepared execution requires a circuit template"))
        compiled = _prepare_parameter_template(source;parameter_map,parameter_order,fixed)
        # Readout-only models have no instruction expansion. In particular,
        # preserve nested source paths instead of flattening them unnecessarily.
        readout_only = noise_model isa NoiseModel && isempty(noise_model.rules) &&
            isempty(noise_model.preparation) && isempty(noise_model.terminal)
        model = readout_only ? nothing : noise_model
        snapshot,errors = _noise_configuration(copy_instruction(compiled.template),model,readout)
        readout_only && append!(errors,deepcopy(noise_model.readout))
        if _execution_parameter_structure(snapshot) != _execution_parameter_structure(compiled.template)
            throw(ArgumentError("noise expansion changed this compiled parameter layout; prepare the original circuit with noise_model to compile the expanded circuit once"))
        end
        _check_parameter_map(snapshot,compiled.parameter_map)
        return snapshot,compiled.parameter_map,errors
    end
    snapshot,errors = _noise_configuration(copy_instruction(source),noise_model,readout)
    snapshot,map = _prepare_parameter_template(snapshot;parameter_map,parameter_order,fixed)
    return snapshot,map,errors
end

"""
    prepare_execution(circuit_or_context, initial; parameter_map, method, noise_model,
                      readout, classical, qubits)

Snapshot and validate one dense CPU state (not a state batch). Noise factories
are expanded once, then frozen. Compiled contexts retain their input identities;
noise that changes their layout requires preparing the original circuit.
`bind_execution(plan, values)` binds active gates and caches deterministic output
distributions. Rebuild the plan to change state, structure, measurement or noise.
"""
function prepare_execution(circuit::Union{QCircuit,_ParameterContext},initial::AbstractQuantumState;
        parameter_map=nothing,parameter_order=nothing,fixed=nothing,method=DensityMatrixEvolution(),
        noise_model=nothing,readout=ReadoutError[],classical=nothing,qubits=1:nqubits(initial))
    initial isa Union{StateVector,DensityMatrix} && supports(CPUBackend(),method,initial) ||
        throw(UnsupportedOperation(CPUBackend(),method,initial,:apply))
    snapshot,map,errors = _prepare_execution_parameters(circuit;parameter_map,parameter_order,fixed,noise_model,readout)
    state = copy(initial)
    register = _initial_classical(classical)
    indices = _readout_qubits(state,qubits)
    if _is_symbolic_map(map)
        # Symbolic prototypes contain storage placeholders, not evaluation points.
        # Position, classical-flow and readout checks do not inspect gate values.
        validate_positions(snapshot,nqubits(state))
        _validate_classical_flow(snapshot,register)
        _check_readout_errors(errors)
        expanded = _readout_register(errors,indices,nqubits(state))
        ops = Any[]
    else
        _,expanded = _check_noise_execution(snapshot,state,CPUBackend(),method,indices,errors;classical=register)
        ops = _execution_skeleton(snapshot,state,method)
    end
    return ExecutionPlan(snapshot,state,map,ops,method,errors,register,indices,expanded,
                         method isa DensityMatrixEvolution && _parameter_deterministic(snapshot))
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
    _is_symbolic_map(plan.parameter_map) && any(x -> x isa Bool,values) &&
        throw(ArgumentError("symbolic parameter values must be real numbers, not Bool"))
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
function _validate_prepared_gate_values(circuit::QCircuit)
    for op in circuit
        if op isa QCircuit
            _validate_prepared_gate_values(op)
        elseif op isa Conditional
            _validate_prepared_gate_values(op.then_branch)
            _validate_prepared_gate_values(op.else_branch)
        elseif op isa Gate
            _check_batch_objective_gate(op)
        end
    end
    return nothing
end
function _bind_execution(plan::ExecutionPlan,values::AbstractVector{<:Real};prepare::Bool=true)
    x = _execution_values(plan,values)
    return _bind_execution_flat(plan,expand_parameters(plan.parameter_map,x);prepare,parameters=x)
end

# Gate-occurrence parameter shifts live in slot coordinates, which need not be
# representable by an independent input vector (for example two shared Ry gates).
function _bind_execution_flat(plan::ExecutionPlan,flat::AbstractVector{<:Real};
                              prepare::Bool=true,parameters=flat)
    _check_parameter_map(plan.template,plan.parameter_map)
    _check_gradient_input(flat)
    length(flat)==nparameters(plan.template) || throw(DimensionMismatch("active parameter count disagrees"))
    values = Float64[flat...]
    all(isfinite,values) || throw(ArgumentError("parameters overflow Float64"))
    if _is_symbolic_map(plan.parameter_map)
        bound = _flat_bind(plan.template,values)
        _validate_prepared_gate_values(bound)
        ops,_ = _check_noise_execution(bound,plan.initial,CPUBackend(),plan.method,
                                       plan.qubits,plan.readout;classical=plan.classical)
    else
        ops = _bind_execution_ops(plan.operations,values,plan)
    end
    return _finish_execution(plan,ops,Float64[parameters...];prepare)
end
function _finish_execution(plan,ops,x;prepare::Bool=true)
    state = prepare && plan.deterministic ? _prepared_evolve(ops,copy(plan.initial)) : nothing
    distribution = isnothing(state) ? nothing : _shot_distribution(state,CPUBackend(),plan.expanded)
    return BoundExecutionPlan(plan,ops,x,state,distribution)
end

bind_execution(plan::ExecutionPlan,values::AbstractVector{<:Real}=Float64[]) = _bind_execution(plan,values)

parameter_order(plan::ExecutionPlan) = parameter_order(plan.parameter_map)
trainable_parameters(plan::ExecutionPlan) = trainable_parameters(plan.parameter_map)
independent_parameters(plan::ExecutionPlan) = independent_parameters(plan.parameter_map)
parameter_info(plan::ExecutionPlan) = parameter_info((;template=plan.template,parameter_map=plan.parameter_map))
initial_parameters(plan::ExecutionPlan;kwargs...) = initial_parameters((;template=plan.template,parameter_map=plan.parameter_map);kwargs...)

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
        sampler = isnothing(bound.distribution) ? nothing :
            _ProbabilityTerminalSampler(bound.distribution,length(p.expanded))
        _execute_prepared(p.initial,CPUBackend(),p.readout,p.method,p.qubits,bound.operations,p.expanded,
            p.deterministic,sampler,p.classical;count_shots=n,rng,result,parallel,chunk_size,
            workspace=work.trajectory)
      end
    end
end
execute(plan::ExecutionPlan,values::AbstractVector{<:Real}=Float64[];kwargs...) = execute(bind_execution(plan,values);kwargs...)
