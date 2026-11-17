"""Frozen measurement groups and CPU execution metadata for repeated expectations."""
struct EstimationPlan{P}
    execution::P
    measurement::MeasurementPlan
    rotations::Vector{Vector{Any}}
    expanded::Vector{Vector{Int}}
end
struct BoundEstimationPlan{P}
    plan::P
    executions::Vector{BoundExecutionPlan}
    parameters::Vector{Float64}
end
function prepare_estimation(circuit::Union{QCircuit,_ParameterContext},observable::Union{QubitsTerm,QubitsOperator},initial::AbstractQuantumState;
                            grouping::Symbol=:qwc,atol::Real=0,max_terms::Integer=100_000,kwargs...)
    measurement = measurement_plan(observable;grouping,atol,max_terms)
    template = circuit isa _ParameterContext ? circuit.template : circuit
    template isa QCircuit || throw(ArgumentError("prepared estimation requires a circuit template"))
    _has_postselection(template) && throw(ArgumentError("estimation does not support post-selection"))
    measurement.nqubits<=nqubits(initial) || throw(ArgumentError("observable exceeds the state register"))
    execution = prepare_execution(circuit,initial;qubits=Int[],kwargs...)
    _has_postselection(execution.template) && throw(ArgumentError("estimation does not support post-selection"))
    rotations = [_noise_preflight!(Any[],_measurement_rotation(g),execution.initial,CPUBackend(),execution.method) for g in measurement.groups]
    expanded = [_readout_register(execution.readout,g.qubits,nqubits(initial)) for g in measurement.groups]
    return EstimationPlan(execution,measurement,rotations,expanded)
end
function bind_execution(plan::EstimationPlan,values::AbstractVector{<:Real}=Float64[])
    base = bind_execution(plan.execution,values)
    return _finish_estimation(plan,base)
end
function _bind_estimation_flat(plan::EstimationPlan,flat::AbstractVector{<:Real})
    return _finish_estimation(plan,_bind_execution_flat(plan.execution,flat))
end
parameter_order(plan::EstimationPlan) = parameter_order(plan.execution)
trainable_parameters(plan::EstimationPlan) = trainable_parameters(plan.execution)
independent_parameters(plan::EstimationPlan) = independent_parameters(plan.execution)
parameter_info(plan::EstimationPlan) = parameter_info(plan.execution)
initial_parameters(plan::EstimationPlan;kwargs...) = initial_parameters(plan.execution;kwargs...)
function _finish_estimation(plan,base)
    p = base.plan
    bound = BoundExecutionPlan[]
    for (i,g) in enumerate(plan.measurement.groups)
        gp = ExecutionPlan(p.template,p.initial,p.parameter_map,p.operations,p.method,p.readout,p.classical,
                           g.qubits,plan.expanded[i],p.deterministic)
        ops = vcat(base.operations,plan.rotations[i])
        state = p.deterministic ? _prepared_evolve(plan.rotations[i],copy(base.prepared_state)) : nothing
        distribution = isnothing(state) ? nothing : _shot_distribution(state,CPUBackend(),gp.expanded)
        push!(bound,BoundExecutionPlan(gp,ops,copy(base.parameters),state,distribution))
    end
    return BoundEstimationPlan(plan,bound,copy(base.parameters))
end

"""Independent pilot measurements choose production allocations; pilot data are not reused in means."""
struct VarianceAllocation
    pilot_shots::Int
    function VarianceAllocation(;pilot_shots::Integer=16)
        n = _execution_shots(pilot_shots)
        n>=2 || throw(ArgumentError("pilot_shots must be at least two per group"))
        new(n)
    end
end
struct AdaptiveEstimate
    value::Float64
    variance::Float64
    stderr::Float64
    shots::Int
    requested_shots::Int
    groups::Vector{GroupEstimate}
    pilot_groups::Vector{GroupEstimate}
    pilot_shots::Int
    production_shots::Int
end
function _variance_allocations(total,variances)
    k = length(variances)
    k==0 && return Int[]
    total>=2k || throw(ArgumentError("production needs at least two shots per group"))
    weights = sqrt.(variances)
    largest = maximum(weights)
    if largest==0
        weights .= 1
    else
        weights ./= largest
    end
    extras = (total-2k).*(weights./sum(weights))
    counts = floor.(Int,extras)
    left = total-2k-sum(counts)
    order = sortperm(extras.-counts;rev=true,alg=Base.Sort.MergeSort)
    for i in 1:left
        counts[order[i]] += 1
    end
    return counts .+ 2
end
function _estimation_cost(plan,shots,allocation)
    n = _execution_shots(shots)
    k = length(plan.measurement.groups)
    allocation === :uniform || allocation isa VarianceAllocation || throw(ArgumentError("allocation must be :uniform or VarianceAllocation"))
    _measurement_allocations(plan.measurement,n)
    if allocation isa VarianceAllocation && k>0
        pilot = Base.checked_mul(k,allocation.pilot_shots)
        n>=Base.checked_add(pilot,Base.checked_mul(2,k)) || throw(ArgumentError("budget must cover pilot and at least two production shots per group"))
    end
    return k==0 ? 0 : n
end
function _estimate_groups(bound,allocations,rng,parallel,chunk_size)
    groups = GroupEstimate[]
    for (g,e,n) in zip(bound.plan.measurement.groups,bound.executions,allocations)
        if e.plan.deterministic
            # Direct sufficient statistics avoid histogram string allocations.
            draws = _draw_samples!(Matrix{Int}(undef,n,length(e.plan.expanded)),rng,e.distribution,n,length(e.plan.expanded))
            _readout_samples!(draws,e.plan.expanded,e.plan.readout,rng)
            push!(groups,_group_estimate(g,view(draws,:,1:length(g.qubits))))
        else
            push!(groups,_group_estimate(g,execute(e;shots=n,result=:counts,rng,parallel,chunk_size).counts))
        end
    end
    return groups
end
function estimate(bound::BoundEstimationPlan;shots::Integer,rng::Random.AbstractRNG=Random.default_rng(),
                  allocation=:uniform,budget=nothing,parallel::Bool=false,chunk_size::Integer=256)
    cost = _estimation_cost(bound.plan,shots,allocation)
    _prepared_options(shots,:counts,parallel,chunk_size,bound.plan.execution.method)
    return _with_shot_budget(budget,cost) do
        plan = bound.plan.measurement
        if allocation === :uniform
            groups = _estimate_groups(bound,_measurement_allocations(plan,shots),rng,parallel,chunk_size)
            return _assemble_estimate(plan,shots,groups)
        end
        pilots = _estimate_groups(bound,fill(allocation.pilot_shots,length(plan.groups)),rng,parallel,chunk_size)
        pilot_cost = sum((g.shots for g in pilots);init=0)
        ns = _variance_allocations(Int(shots)-pilot_cost,[g.sample_variance for g in pilots])
        groups = _estimate_groups(bound,ns,rng,parallel,chunk_size)
        result = _assemble_estimate(plan,shots,groups)
        return AdaptiveEstimate(result.value,result.variance,result.stderr,pilot_cost+result.shots,
            Int(shots),groups,pilots,pilot_cost,result.shots)
    end
end
estimate(plan::EstimationPlan,values::AbstractVector{<:Real}=Float64[];kwargs...) = estimate(bind_execution(plan,values);kwargs...)
