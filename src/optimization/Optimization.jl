module Optimization
using ..MOSSQuantum
using Random, LinearAlgebra
export minimize, OptimizationResult, OptimizationStep

struct OptimizationStep
    iteration::Int
    parameters::Vector{Float64}
    estimate::GradientEstimate
    learning_rate::Float64
end
struct OptimizationResult
    parameters::Vector{Float64}
    estimate::Union{ExpectationEstimate,AdaptiveEstimate}
    history::Vector{OptimizationStep}
    shots::Int
    evaluations::Int
    status::Symbol
end

"""
    minimize(objective::ShotExpectationObjective, initial; method=ParameterShift(),
             optimizer=:adam, iterations=100, learning_rate=0.1, decay=0,
             perturbation_decay=0.101, rng, callback=nothing)

A small reproducible finite-shot optimization workflow. Choose `:adam` or `:sgd`.
With SPSAGradient, step k uses `method.step/k^perturbation_decay`. The learning
rate is `learning_rate/k^decay`; SPSA+SGD commonly uses decay=0.602. History
stores the pre-update parameters corresponding to each gradient's value. Final
parameters receive a fresh independent estimate; the result is not a noisy
best-of-history selection. No convergence guarantee or automatic early stopping
is inferred from shot noise. `callback(step) === false` stops before that update.
"""
function minimize(objective::ShotExpectationObjective,initial::AbstractVector{<:Real};
        method::AbstractGradientMethod=ParameterShift(),optimizer::Symbol=:adam,
        iterations::Integer=100,learning_rate::Real=0.1,decay::Real=0,
        perturbation_decay::Real=0.101,rng::Random.AbstractRNG=Random.default_rng(),callback=nothing,
        max_shots::Union{Nothing,Integer}=nothing)
    optimizer in (:adam,:sgd) || throw(ArgumentError("optimizer must be :adam or :sgd"))
    !(iterations isa Bool) && 0 <= iterations <= typemax(Int) || throw(ArgumentError("iterations must be a nonnegative Int"))
    isfinite(learning_rate) && learning_rate>0 && isfinite(Float64(learning_rate)) && Float64(learning_rate)>0 || throw(ArgumentError("learning_rate must be positive and finite"))
    all(x -> isfinite(x) && x>=0,(decay,perturbation_decay)) || throw(ArgumentError("decay exponents must be finite and nonnegative"))
    supports_gradient(method,objective) || throw(UnsupportedGradient(method,objective))
    x = Float64[initial...]
    length(x)==nparameters(objective.parameter_map) && all(isfinite,x) || throw(ArgumentError("invalid initial parameters"))
    total_budget = isnothing(max_shots) ? nothing : ShotBudget(max_shots)
    final_cost = required_shots(objective)
    !isnothing(total_budget) && remaining_shots(total_budget)<final_cost &&
        throw(ShotBudgetExceeded(final_cost,remaining_shots(total_budget)))
    moment,second = zeros(length(x)),zeros(length(x))
    history = OptimizationStep[]
    shots,evaluations = 0,0
    status = :iteration_limit
    for k in 1:Int(iterations)
        selected = method isa SPSAGradient ? SPSAGradient(step=method.step/k^perturbation_decay,directions=method.directions) : method
        if !isnothing(total_budget) && required_shots(selected,objective,x)>remaining_shots(total_budget)-final_cost
            status = :shot_budget
            break
        end
        gradient = estimate_gradient(selected,objective,x;rng=rng,budget=total_budget)
        rate = Float64(learning_rate/k^decay)
        step = OptimizationStep(k,copy(x),gradient,rate)
        push!(history,step)
        shots = Base.checked_add(shots,gradient.shots); evaluations += gradient.evaluations
        if !isnothing(callback) && callback(deepcopy(step)) === false
            status = :callback
            break
        end
        if optimizer === :adam
            moment .= .9moment .+ .1gradient.gradient
            second .= .999second .+ .001gradient.gradient.^2
            x .-= rate .* (moment ./ (1-.9^k)) ./ (sqrt.(second ./ (1-.999^k)) .+ 1e-8)
        else
            x .-= rate .* gradient.gradient
        end
        all(isfinite,x) || throw(ArgumentError("optimizer produced nonfinite parameters"))
    end
    final = estimate(objective,x;rng=rng,budget=total_budget)
    shots = Base.checked_add(shots,final.shots); evaluations += 1
    return OptimizationResult(x,final,history,shots,evaluations,status)
end
end
