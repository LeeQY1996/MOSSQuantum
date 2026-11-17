function _readout_qubits(state, qubits)
    indices = Int[qubits...]
    length(unique(indices)) == length(indices) || throw(ArgumentError("readout qubits must be distinct"))
    all(q -> 1 <= q <= nqubits(state), indices) || throw(ArgumentError("readout qubit out of range"))
    return indices
end

function _readout_index(basis::Int, qubits)
    index = 0
    for (j, q) in enumerate(qubits)
        index |= ((basis >> (q - 1)) & 1) << (j - 1)
    end
    return index + 1
end

function _probability_tolerance(::Type{T}) where T
    RT = typeof(real(zero(T)))
    # Repeated gate applications and probability summation accumulate rounding.
    # Match the usual isapprox scale rather than requiring a few machine ulps.
    return max(sqrt(eps(Float64)), RT <: AbstractFloat ? sqrt(Float64(eps(RT))) : 0.0)
end

function _normalize_probabilities!(values::AbstractVector{<:Real}, tolerance::Real)
    all(isfinite, values) || throw(ArgumentError("probabilities must be finite"))
    minimum(values) >= -tolerance || throw(DomainError(minimum(values), "probabilities must be nonnegative"))
    values .= max.(values, 0)
    total = sum(values)
    isapprox(total, 1; atol=tolerance, rtol=tolerance) ||
        throw(ArgumentError("state probabilities must sum to one; normalize the state first (sum = $total)"))
    values ./= total
    return values
end

"""
    probabilities(state; qubits=1:nqubits(state))

Computational-basis probabilities without changing `state`. The first requested
qubit is the least significant bit of the returned vector's zero-based index.
For a batch, return one probability vector per column. Inputs must be normalized.
Third-party representations can implement this method without dense storage.
"""
function _cpu_probabilities(state::StateVector; qubits=1:nqubits(state))
    indices = _readout_qubits(state, qubits)
    values = zeros(Float64, 2^length(indices))
    for (i, amplitude) in enumerate(storage(state))
        values[_readout_index(i - 1, indices)] += abs2(amplitude)
    end
    return _normalize_probabilities!(values, _probability_tolerance(eltype(state)))
end

function _cpu_probabilities(state::DensityMatrix; qubits=1:nqubits(state))
    indices = _readout_qubits(state, qubits)
    values = zeros(Float64, 2^length(indices))
    tolerance = _probability_tolerance(eltype(state))
    data = storage(state)
    for i in axes(data, 1)
        abs(imag(data[i, i])) <= tolerance || throw(ArgumentError("density-matrix diagonal must be real"))
        real(data[i, i]) >= -tolerance || throw(DomainError(data[i, i], "density-matrix probabilities must be nonnegative"))
        values[_readout_index(i - 1, indices)] += real(data[i, i])
    end
    return _normalize_probabilities!(values, tolerance)
end

function _cpu_probabilities(state::BatchStateVector; qubits=1:nqubits(state))
    indices = _readout_qubits(state, qubits)
    values = zeros(Float64, 2^length(indices), batch_size(state))
    for b in 1:batch_size(state), i in axes(storage(state), 1)
        values[_readout_index(i - 1, indices), b] += abs2(storage(state)[i, b])
    end
    for b in 1:batch_size(state)
        _normalize_probabilities!(view(values, :, b), _probability_tolerance(eltype(state)))
    end
    return values
end

function _cpu_probabilities(state::BatchDensityMatrix; qubits=1:nqubits(state))
    indices = _readout_qubits(state, qubits)
    diagonal = _batch_density_diagonal_probabilities(state; normalized=true)
    values = zeros(Float64, 2^length(indices), batch_size(state))
    for b in 1:batch_size(state), i in axes(diagonal, 1)
        values[_readout_index(i - 1, indices), b] += diagonal[i, b]
    end
    return values
end

# Check the full diagonal before taking a marginal. Invalid entries must not be
# hidden by cancellation when multiple basis states contribute to one outcome.
function _batch_density_diagonal_probabilities(state::BatchDensityMatrix; normalized::Bool)
    data = storage(state)
    values = Matrix{Float64}(undef, size(data, 1), batch_size(state))
    tolerance = _probability_tolerance(eltype(state))
    for b in 1:batch_size(state), i in axes(data, 1)
        value = data[i, i, b]
        isfinite(value) || throw(ArgumentError("density-matrix diagonal must be finite"))
        abs(imag(value)) <= tolerance || throw(ArgumentError("density-matrix diagonal must be real"))
        real(value) >= -tolerance || throw(DomainError(value, "density-matrix probabilities must be nonnegative"))
        values[i, b] = max(real(value), 0)
    end
    if normalized
        for b in 1:batch_size(state)
            _normalize_probabilities!(view(values, :, b), tolerance)
        end
    end
    return values
end

function _draw_samples!(output, rng, distribution, nshots, nbits)
    all(p -> isfinite(p) && p >= 0, distribution) || throw(ArgumentError("invalid sampling distribution"))
    cumulative = cumsum(distribution)
    total = last(cumulative)
    isfinite(total) && total > 0 || throw(ArgumentError("sampling probabilities must have positive finite sum"))
    last_positive = findlast(p -> p > 0, distribution)
    for shot in 1:nshots
        selected = searchsortedlast(cumulative, rand(rng) * total) + 1
        basis = (selected > length(distribution) ? last_positive : selected) - 1
        for bit in 1:nbits
            output[shot, bit] = (basis >> (bit - 1)) & 1
        end
    end
    return output
end

"""
    sample([rng], state, shots; qubits=1:nqubits(state))

Sample terminal readout without collapsing `state`. Rows are shots and columns
follow `qubits` in the requested order. For a batch the third axis is the batch
index. Reusing equally seeded RNGs reproduces draws in the same Julia environment.
"""
function sample(rng::Random.AbstractRNG, state, shots::Integer; qubits=1:nqubits(state),readout=nothing)
    !isnothing(readout) && return execute(QCircuit(),state;shots=shots,qubits=qubits,rng=rng,readout=readout).samples
    shots >= 0 || throw(ArgumentError("shots must be nonnegative"))
    indices = _readout_qubits(state, qubits)
    distribution = probabilities(state; qubits=indices)
    return _draw_samples!(Matrix{Int}(undef, shots, length(indices)), rng, distribution, shots, length(indices))
end

function sample(rng::Random.AbstractRNG, state::Union{BatchStateVector,BatchDensityMatrix}, shots::Integer; qubits=1:nqubits(state),readout=nothing)
    if !isnothing(readout)
        indices = _readout_qubits(state,qubits)
        results = execute(QCircuit(),state;shots=shots,qubits=indices,rng=rng,readout=readout)
        output = Array{Int}(undef,Int(shots),length(indices),batch_size(state))
        for b in eachindex(results)
            output[:,:,b] .= results[b].samples
        end
        return output
    end
    shots >= 0 || throw(ArgumentError("shots must be nonnegative"))
    indices = _readout_qubits(state, qubits)
    distributions = probabilities(state; qubits=indices)
    output = Array{Int}(undef, shots, length(indices), batch_size(state))
    for b in 1:batch_size(state)
        _draw_samples!(view(output, :, :, b), rng, view(distributions, :, b), shots, length(indices))
    end
    return output
end

sample(state, shots::Integer; rng::Random.AbstractRNG=Random.default_rng(), kwargs...) = sample(rng, state, shots; kwargs...)

function _sample_counts(draws::AbstractMatrix)
    histogram = Dict{String, Int}()
    for row in axes(draws, 1)
        key = join(view(draws, row, :))
        histogram[key] = get(histogram, key, 0) + 1
    end
    return histogram
end

"""
    counts([rng], state, shots; qubits=1:nqubits(state))

Terminal-readout histogram. In each string the leftmost character is the first
requested qubit. Batch input returns one histogram per batch element.
"""
function counts(rng::Random.AbstractRNG, state, shots::Integer; kwargs...)
    draws = sample(rng, state, shots; kwargs...)
    return ndims(draws) == 2 ? _sample_counts(draws) :
        [_sample_counts(view(draws, :, :, b)) for b in axes(draws, 3)]
end

counts(state, shots::Integer; rng::Random.AbstractRNG=Random.default_rng(), kwargs...) = counts(rng, state, shots; kwargs...)
