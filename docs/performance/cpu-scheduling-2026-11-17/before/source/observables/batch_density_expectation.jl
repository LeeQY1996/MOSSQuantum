# The scalar density expectation wrappers convert an entire state into the
# observable's scalar domain. These small contractions only read matrix blocks;
# promote the local observable instead and reuse it across all samples.
function _batch_density_short_expectation!(values, register::NTuple{N,Int},
                                           matrix::AbstractMatrix, data,
                                           ::Type{T}) where {N,T<:Number}
    dimension = 1 << N
    local_matrix = SMatrix{dimension,dimension,T}(matrix)
    kernel_register = N == 1 ? register[1] : register
    for column in axes(data, 3)
        values[column] += _expectation_value_util(kernel_register, local_matrix,
            view(data, :, :, column))
    end
    return values
end

"""One `tr(O * rho)` per density-matrix sample, in sample order."""
function _cpu_expectation(observable::QubitsTerm, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = zeros(T, batch_size(batch))
    isempty(values) && return values
    data = storage(batch)
    if isempty(observable)
        for column in axes(data, 3)
            sample_trace = zero(T)
            for index in axes(data, 1)
                sample_trace += data[index, index, column]
            end
            values[column] = coeff(observable) * sample_trace
        end
    elseif length(positions(observable)) <= 3
        _batch_density_short_expectation!(values, Tuple(positions(observable)),
            _get_mat(observable), data, T)
    else
        for column in axes(data, 3)
            state = DensityMatrix(Matrix{T}(view(data, :, :, column)), nqubits(batch))
            values[column] = expectation(observable, state)
        end
    end
    return values
end

function _cpu_expectation(observable::QubitsOperator, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = zeros(T, batch_size(batch))
    isempty(values) && return values
    data = storage(batch)
    if _largest_nterm(observable) <= 3
        for (register, terms) in observable.data
            _batch_density_short_expectation!(values, register,
                _get_mat(length(register), terms), data, T)
        end
    else
        for column in axes(data, 3)
            state = DensityMatrix(Matrix{T}(view(data, :, :, column)), nqubits(batch))
            values[column] = expectation(observable, state)
        end
    end
    return values
end

function _cpu_expectation(observable::AbstractMatrix, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    values = Vector{T}(undef, batch_size(batch))
    for column in 1:batch_size(batch)
        values[column] = tr(observable * view(storage(batch), :, :, column))
    end
    return values
end

function _cpu_expectation(observable::Gate, batch::BatchDensityMatrix)
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

(observable::QubitsTerm)(batch::BatchDensityMatrix) = apply(backend(batch), observable, batch)
(observable::QubitsOperator)(batch::BatchDensityMatrix) = apply(backend(batch), observable, batch)
Base.:*(observable::Union{QubitsTerm,QubitsOperator}, batch::BatchDensityMatrix) = observable(batch)

function _cpu_linear_apply(observable::AbstractMatrix, batch::BatchDensityMatrix)
    _check_batch_observable(observable, batch)
    T = promote_type(eltype(observable), eltype(batch))
    data = Array{T,3}(undef, size(storage(batch)))
    for column in 1:batch_size(batch)
        data[:, :, column] .= observable * view(storage(batch), :, :, column)
    end
    return BatchDensityMatrix(data, nqubits(batch))
end

Base.:*(observable::AbstractMatrix, batch::BatchDensityMatrix) = apply(backend(batch), observable, batch)
