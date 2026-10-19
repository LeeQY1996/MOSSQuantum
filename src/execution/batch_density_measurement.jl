"""
    measure!(batch::BatchDensityMatrix, position; auto_reset=true, rng=Random.default_rng())

Measure each density matrix independently, keeping the register size. Return
`(outcomes, probabilities)` in sample order. Validate every sample before
consuming randomness or changing storage.
"""
measure!(batch::BatchDensityMatrix, position::Int; auto_reset::Bool=true,
         rng::Random.AbstractRNG=Random.default_rng()) =
    apply!(QMeasure(position; auto_reset=auto_reset), batch; rng=rng)

function apply!(instruction::QMeasure, batch::BatchDensityMatrix;
                rng::Random.AbstractRNG=Random.default_rng())
    instruction.keep || throw(ArgumentError("in-place measurement must keep the measured qubit"))
    distributions = _batch_measurement_probabilities(batch, instruction.position)
    outcomes = Vector{Int}(undef, batch_size(batch))
    probabilities = Vector{Float64}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        selected = discrete_sample(rng, view(distributions, :, column))
        outcomes[column] = selected - 1
        probabilities[column] = distributions[selected, column]
        _collapse_batch_density!(batch, column, instruction.position, selected - 1,
                                 probabilities[column], instruction.auto_reset)
    end
    return outcomes, probabilities
end

"""
    measure(batch::BatchDensityMatrix, position; rng=Random.default_rng())

Return `(collapsed_batch, outcomes, probabilities)` without changing the input.
Remove the measured qubit and preserve the relative order of the remaining ones.
"""
measure(batch::BatchDensityMatrix, position::Int; rng::Random.AbstractRNG=Random.default_rng()) =
    apply(QMeasure(position), batch; rng=rng)

function apply(instruction::QMeasure, batch::BatchDensityMatrix;
               rng::Random.AbstractRNG=Random.default_rng())
    distributions = _batch_measurement_probabilities(batch, instruction.position)
    outcomes = Vector{Int}(undef, batch_size(batch))
    probabilities = Vector{Float64}(undef, batch_size(batch))
    dimension = 2^(nqubits(batch) - 1)
    data = Array{eltype(batch)}(undef, dimension, dimension, batch_size(batch))
    for column in 1:batch_size(batch)
        selected = discrete_sample(rng, view(distributions, :, column))
        outcomes[column] = selected - 1
        probabilities[column] = distributions[selected, column]
        indices = _batch_density_selected_indices(batch, instruction.position, selected - 1)
        data[:, :, column] .= storage(batch)[indices, indices, column] ./ probabilities[column]
    end
    return BatchDensityMatrix(data, nqubits(batch) - 1, batch_size(batch)), outcomes, probabilities
end

function _batch_measurement_probabilities(batch::BatchDensityMatrix, position::Int)
    _check_measurement_position(position, nqubits(batch))
    return probabilities(batch; qubits=(position,))
end

function _batch_density_selected_indices(batch::BatchDensityMatrix, position::Int, outcome::Int)
    bit = 1 << (position - 1)
    return [index for index in axes(storage(batch), 1) if ((index - 1) & bit == 0 ? 0 : 1) == outcome]
end

function _collapse_batch_density!(batch::BatchDensityMatrix, column::Int, position::Int,
                                  outcome::Int, probability::Real, auto_reset::Bool)
    selected = _batch_density_selected_indices(batch, position, outcome)
    block = storage(batch)[selected, selected, column] ./ probability
    destination = auto_reset && outcome == 1 ? selected .- (1 << (position - 1)) : selected
    sample = view(storage(batch), :, :, column)
    fill!(sample, zero(eltype(batch)))
    sample[destination, destination] .= block
    return batch
end

"""
    post_select!(batch::BatchDensityMatrix, position, outcome=0)

Keep and normalize the selected block of each sample. Return its raw trace
weight per sample. Every weight must be positive and finite; failures leave the
whole batch unchanged. Inputs need not have unit trace.
"""
post_select!(batch::BatchDensityMatrix, position::Int, outcome::Int=0) =
    apply!(QSelect(position, outcome), batch)

function apply!(instruction::QSelect, batch::BatchDensityMatrix)
    probabilities = _batch_postselection_probabilities(batch, instruction)
    for column in 1:batch_size(batch)
        _collapse_batch_density!(batch, column, instruction.position, instruction.state,
                                 probabilities[column], false)
    end
    return probabilities
end

"""
    post_select(batch::BatchDensityMatrix, position, outcome=0; keep=false)

Return `(collapsed_batch, probabilities)` without changing the input. Remove
the selected qubit unless `keep=true`; preserve the other qubits' order.
"""
post_select(batch::BatchDensityMatrix, position::Int, outcome::Int=0; keep::Bool=false) =
    apply(QSelect(position, outcome), batch; keep=keep)

function apply(instruction::QSelect, batch::BatchDensityMatrix; keep::Bool=false)
    probabilities = _batch_postselection_probabilities(batch, instruction)
    if keep
        result = copy(batch)
        for column in 1:batch_size(batch)
            _collapse_batch_density!(result, column, instruction.position, instruction.state,
                                     probabilities[column], false)
        end
        return result, probabilities
    end
    dimension = 2^(nqubits(batch) - 1)
    data = Array{eltype(batch)}(undef, dimension, dimension, batch_size(batch))
    indices = _batch_density_selected_indices(batch, instruction.position, instruction.state)
    for column in 1:batch_size(batch)
        data[:, :, column] .= storage(batch)[indices, indices, column] ./ probabilities[column]
    end
    return BatchDensityMatrix(data, nqubits(batch) - 1, batch_size(batch)), probabilities
end

function _batch_postselection_probabilities(batch::BatchDensityMatrix, instruction::QSelect)
    _check_measurement_position(instruction.position, nqubits(batch))
    diagonal = _batch_density_diagonal_probabilities(batch; normalized=false)
    indices = _batch_density_selected_indices(batch, instruction.position, instruction.state)
    probabilities = Vector{Float64}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        probability = sum(view(diagonal, indices, column))
        isfinite(probability) && probability > 0 ||
            throw(DomainError(probability, "every sample must have positive finite post-selection probability"))
        probabilities[column] = probability
    end
    return probabilities
end
