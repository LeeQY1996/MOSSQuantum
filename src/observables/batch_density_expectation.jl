"""One `tr(O * rho)` per density-matrix sample, in sample order."""
function expectation(observable::Union{QubitsTerm,QubitsOperator}, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = Vector{T}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        state = DensityMatrix(Matrix{T}(view(storage(batch), :, :, column)), nqubits(batch))
        values[column] = expectation(observable, state)
    end
    return values
end

function expectation(observable::AbstractMatrix, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = Vector{T}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        values[column] = tr(observable * view(storage(batch), :, :, column))
    end
    return values
end

function expectation(observable::Gate, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = Vector{T}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        # Observation contracts the left action only. Gate execution elsewhere
        # performs the two-sided U*rho*U' transformation.
        state = DensityMatrix(Matrix{T}(view(storage(batch), :, :, column)), nqubits(batch))
        apply_threaded!(observable, state.data)
        values[column] = tr(state)
    end
    return values
end

function _apply_batch_operator(observable::Union{QubitsTerm,QubitsOperator}, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    data = Array{T,3}(undef, size(storage(batch)))
    for column in 1:batch_size(batch)
        state = DensityMatrix(Matrix{T}(view(storage(batch), :, :, column)), nqubits(batch))
        data[:, :, column] .= storage(observable * state)
    end
    return BatchDensityMatrix(data, nqubits(batch))
end

(observable::QubitsTerm)(batch::BatchDensityMatrix) = _apply_batch_operator(observable, batch)
(observable::QubitsOperator)(batch::BatchDensityMatrix) = _apply_batch_operator(observable, batch)
Base.:*(observable::Union{QubitsTerm,QubitsOperator}, batch::BatchDensityMatrix) = observable(batch)

function Base.:*(observable::AbstractMatrix, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    data = Array{T,3}(undef, size(storage(batch)))
    for column in 1:batch_size(batch)
        data[:, :, column] .= observable * view(storage(batch), :, :, column)
    end
    return BatchDensityMatrix(data, nqubits(batch))
end
