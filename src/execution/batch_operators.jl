"""Apply a shared observable as a linear operator to every pure-state column."""
function _apply_batch_operator(operator::Union{QubitsTerm,QubitsOperator}, batch::BatchStateVector)
    _check_batch_observable(operator, batch)
    T = promote_type(eltype(operator), eltype(batch))
    output = Matrix{T}(undef, size(storage(batch)))
    for column in 1:batch_size(batch)
        # The single-state operator kernels allocate in the input's scalar
        # domain. Promote before entering them, including for complex operators
        # acting on a real batch.
        state = StateVector(Vector{T}(view(storage(batch), :, column)), nqubits(batch))
        output[:, column] .= storage(operator * state)
    end
    return BatchStateVector(output, nqubits(batch))
end

(operator::QubitsTerm)(batch::BatchStateVector) = _apply_batch_operator(operator, batch)
(operator::QubitsOperator)(batch::BatchStateVector) = _apply_batch_operator(operator, batch)
Base.:*(operator::Union{QubitsTerm,QubitsOperator}, batch::BatchStateVector) = operator(batch)
