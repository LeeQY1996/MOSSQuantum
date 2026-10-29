"""Ordered experiment results; columns of `parameters` identify rows of `results`."""
struct ExperimentResult{R}
    parameters::Matrix{Float64}
    results::Vector{R}
    shots::Int
    evaluations::Int
end

"""
    run_sweep(plan, parameters; shots, rng, parallel=false, budget, ...)

Execute columns of independent parameter values. Validate and bind every point
before sampling; then assign one RNG seed per point in column order. Serial and
threaded sweeps therefore agree in the same Julia environment. `shots` is per
point. Parallelism here is across points, not nested shot parallelism.
"""
function run_sweep(plan::Union{ExecutionPlan,EstimationPlan},parameters::AbstractMatrix{<:Real};
        shots::Integer,rng::Random.AbstractRNG=Random.default_rng(),parallel::Bool=false,
        result::Symbol=:counts,allocation=:uniform,budget=nothing,chunk_size::Integer=256)
    Base.require_one_based_indexing(parameters)
    execution = plan isa ExecutionPlan ? plan : plan.execution
    size(parameters,1)==nparameters(execution.parameter_map) || throw(DimensionMismatch("parameter rows must match independent parameters"))
    xs = Matrix{Float64}(parameters)
    all(isfinite,xs) || throw(ArgumentError("parameters must be finite Float64 values"))
    perpoint = plan isa ExecutionPlan ? _prepared_options(shots,result,false,chunk_size,plan.method) : _estimation_cost(plan,shots,allocation)
    _prepared_options(shots,result,false,chunk_size,execution.method)
    plan isa ExecutionPlan && allocation !== :uniform && throw(ArgumentError("allocation applies to expectation sweeps only"))
    bound = [_bind_execution(execution,view(xs,:,j);prepare=false) for j in axes(xs,2)]
    total = Base.checked_mul(perpoint,size(xs,2))
    T = plan isa ExecutionPlan ? (result === :full ? ShotResult : CountsResult) :
        (allocation === :uniform ? ExpectationEstimate : AdaptiveEstimate)
    values = Vector{T}(undef,length(bound))
    return _with_shot_budget(budget,total) do
        seeds = [rand(rng,UInt64) for _ in eachindex(bound)]
        function run(j)
            item = bound[j]
            ready = _finish_execution(item.plan,item.operations,item.parameters)
            values[j] = plan isa ExecutionPlan ?
                execute(ready;shots,result,rng=Random.Xoshiro(seeds[j]),chunk_size) :
                estimate(_finish_estimation(plan,ready);shots,allocation,rng=Random.Xoshiro(seeds[j]),chunk_size)
        end
        if parallel
            Threads.@threads for j in eachindex(bound)
                run(j)
            end
        else
            for j in eachindex(bound)
                run(j)
            end
        end
        return ExperimentResult(xs,values,total,length(values))
    end
end
