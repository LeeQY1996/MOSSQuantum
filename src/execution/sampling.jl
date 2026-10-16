
"""Draw an index from finite, nonnegative weights using the supplied RNG."""
function discrete_sample(rng::Random.AbstractRNG, weights::AbstractVector{<:Real})
    isempty(weights) && throw(ArgumentError("cannot sample an empty distribution"))
    all(x -> isfinite(x) && x >= 0, weights) ||
        throw(ArgumentError("sampling weights must be finite and nonnegative"))
    total = sum(weights)
    isfinite(total) && total > 0 || throw(ArgumentError("sampling weights must have positive finite sum"))
    threshold = rand(rng) * total
    cumulative = zero(total)
    last_positive = firstindex(weights)
    for i in eachindex(weights)
        weights[i] > 0 && (last_positive = i)
        cumulative += weights[i]
        threshold < cumulative && return i
    end
    return last_positive
end

discrete_sample(weights::AbstractVector{<:Real}) = discrete_sample(Random.default_rng(), weights)
