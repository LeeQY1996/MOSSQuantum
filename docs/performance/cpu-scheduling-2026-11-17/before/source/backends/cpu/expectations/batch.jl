# Batch expectation value computations for BatchStateVector

# Import the constant from apply_qterms.jl
# LARGEST_SUPPORTED_NTERMS is defined as 5 in apply_qterms.jl
const LARGEST_SUPPORTED_NTERMS_BATCH = 5

# Note: _get_mat and _largest_nterm are available in the same module

# Batch expectation value functions
# These compute expectation values for each state in a batch

"""
    expectation_value(pos, m, batch)
Compute expectation values of operator `m` acting on qubits `pos` for each state in `batch`.
Returns a vector of length `batch_size(batch)`.
"""
function expectation_value(pos::Int, m::AbstractMatrix, batch::BatchStateVector)
    nq = nqubits(batch)
    bs = batch_size(batch)
    L = 2^nq
    results = zeros(promote_type(eltype(batch), eltype(m)), bs)
    data = storage(batch)

    sj = 2
    s1 = 2^(pos-1)
    s2 = s1 * sj

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch))
        col = view(data, :, b)
        for i in 0:s2:(L-1)
            for j in 0:(s1-1)
                pos_start = i + j + 1
                v = SVector(col[pos_start], col[pos_start + s1])
                @fastmath r += dot(v, m, v)
            end
        end
        results[b] = r
    end
    return results
end

function expectation_value(pos::Tuple{Int}, m::AbstractMatrix, batch::BatchStateVector)
    return expectation_value(pos[1], m, batch)
end

function expectation_value(pos::Tuple{Int, Int}, m::AbstractMatrix, batch::BatchStateVector)
    nq = nqubits(batch)
    bs = batch_size(batch)
    L = 2^nq
    results = zeros(promote_type(eltype(batch), eltype(m)), bs)
    data = storage(batch)

    q1, q2 = pos
    pos1, pos2 = 2^(q1-1), 2^(q2-1)
    stride1, stride2 = 2 * pos1, 2 * pos2

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch))
        col = view(data, :, b)
        for i in 0:stride2:(L-1)
            for j in 0:stride1:(pos2-1)
                @inbounds for k in 0:(pos1-1)
                    l = i + j + k + 1
                    vi = SVector(col[l], col[l + pos1], col[l + pos2], col[l + pos1 + pos2])
                    @fastmath r += dot(vi, m, vi)
                end
            end
        end
        results[b] = r
    end
    return results
end

function expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractMatrix, batch::BatchStateVector)
    nq = nqubits(batch)
    bs = batch_size(batch)
    L = 2^nq
    results = zeros(promote_type(eltype(batch), eltype(m)), bs)
    data = storage(batch)

    q1, q2, q3 = pos
    pos1, pos2, pos3 = 2^(q1-1), 2^(q2-1), 2^(q3-1)
    stride1, stride2, stride3 = 2 * pos1, 2 * pos2, 2 * pos3

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch))
        col = view(data, :, b)
        for h in 0:stride3:(L-1)
            for i in 0:stride2:(pos3-1)
                for j in 0:stride1:(pos2-1)
                    @inbounds for k in 0:(pos1-1)
                        l000 = h + i + j + k + 1
                        l100 = l000 + pos1
                        l010 = l000 + pos2
                        l110 = l010 + pos1

                        l001 = l000 + pos3
                        l101 = l001 + pos1
                        l011 = l001 + pos2
                        l111 = l011 + pos1

                        vi = SVector(col[l000], col[l100], col[l010], col[l110],
                                     col[l001], col[l101], col[l011], col[l111])
                        @fastmath r += dot(vi, m, vi)
                    end
                end
            end
        end
        results[b] = r
    end
    return results
end

# Two-state batch expectation (for transition matrix elements)
function expectation_value(pos::Int, m::AbstractMatrix, batch1::BatchStateVector, batch2::BatchStateVector)
    @assert nqubits(batch1) == nqubits(batch2) "Number of qubits must match"
    @assert batch_size(batch1) == batch_size(batch2) "Batch sizes must match"

    nq = nqubits(batch1)
    bs = batch_size(batch1)
    L = 2^nq
    results = zeros(promote_type(eltype(batch1), eltype(batch2), eltype(m)), bs)
    data1 = storage(batch1)
    data2 = storage(batch2)

    sj = 2
    s1 = 2^(pos-1)
    s2 = s1 * sj

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch1))
        col1 = view(data1, :, b)
        col2 = view(data2, :, b)
        for i in 0:s2:(L-1)
            for j in 0:(s1-1)
                pos_start = i + j + 1
                v = SVector(col1[pos_start], col1[pos_start + s1])
                v_c = SVector(col2[pos_start], col2[pos_start + s1])
                @fastmath r += dot(v_c, m, v)
            end
        end
        results[b] = r
    end
    return results
end

function expectation_value(pos::Tuple{Int}, m::AbstractMatrix, batch1::BatchStateVector, batch2::BatchStateVector)
    return expectation_value(pos[1], m, batch1, batch2)
end

function expectation_value(pos::Tuple{Int, Int}, m::AbstractMatrix, batch1::BatchStateVector, batch2::BatchStateVector)
    @assert nqubits(batch1) == nqubits(batch2) "Number of qubits must match"
    @assert batch_size(batch1) == batch_size(batch2) "Batch sizes must match"

    nq = nqubits(batch1)
    bs = batch_size(batch1)
    L = 2^nq
    results = zeros(promote_type(eltype(batch1), eltype(batch2), eltype(m)), bs)
    data1 = storage(batch1)
    data2 = storage(batch2)

    q1, q2 = pos
    pos1, pos2 = 2^(q1-1), 2^(q2-1)
    stride1, stride2 = 2 * pos1, 2 * pos2

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch1))
        col1 = view(data1, :, b)
        col2 = view(data2, :, b)
        for i in 0:stride2:(L-1)
            for j in 0:stride1:(pos2-1)
                @inbounds for k in 0:(pos1-1)
                    l = i + j + k + 1
                    vi = SVector(col1[l], col1[l + pos1], col1[l + pos2], col1[l + pos1 + pos2])
                    vi_c = SVector(col2[l], col2[l + pos1], col2[l + pos2], col2[l + pos1 + pos2])
                    @fastmath r += dot(vi_c, m, vi)
                end
            end
        end
        results[b] = r
    end
    return results
end

function expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractMatrix, batch1::BatchStateVector, batch2::BatchStateVector)
    @assert nqubits(batch1) == nqubits(batch2) "Number of qubits must match"
    @assert batch_size(batch1) == batch_size(batch2) "Batch sizes must match"

    nq = nqubits(batch1)
    bs = batch_size(batch1)
    L = 2^nq
    results = zeros(promote_type(eltype(batch1), eltype(batch2), eltype(m)), bs)
    data1 = storage(batch1)
    data2 = storage(batch2)

    q1, q2, q3 = pos
    pos1, pos2, pos3 = 2^(q1-1), 2^(q2-1), 2^(q3-1)
    stride1, stride2, stride3 = 2 * pos1, 2 * pos2, 2 * pos3

    # For each batch element
    for b in 1:bs
        r = zero(eltype(batch1))
        col1 = view(data1, :, b)
        col2 = view(data2, :, b)
        for h in 0:stride3:(L-1)
            for i in 0:stride2:(pos3-1)
                for j in 0:stride1:(pos2-1)
                    @inbounds for k in 0:(pos1-1)
                        l000 = h + i + j + k + 1
                        l100 = l000 + pos1
                        l010 = l000 + pos2
                        l110 = l010 + pos1

                        l001 = l000 + pos3
                        l101 = l001 + pos1
                        l011 = l001 + pos2
                        l111 = l011 + pos1

                        vi = SVector(col1[l000], col1[l100], col1[l010], col1[l110],
                                     col1[l001], col1[l101], col1[l011], col1[l111])
                        vi_c = SVector(col2[l000], col2[l100], col2[l010], col2[l110],
                                       col2[l001], col2[l101], col2[l011], col2[l111])
                        @fastmath r += dot(vi_c, m, vi)
                    end
                end
            end
        end
        results[b] = r
    end
    return results
end

# The single-state kernels take amplitude vectors, not StateVector wrappers.
# Promote real amplitudes when a complex operator or bra requires it.
function _batch_expectation_column(batch::BatchStateVector, i::Int, ::Type{T}) where T
    column = view(storage(batch), :, i)
    return eltype(batch) == T ? column : T.(column)
end

function expectation_value(pos::Union{NTuple{4,Int}, NTuple{5,Int}}, m::AbstractMatrix,
                           batch::BatchStateVector)
    T = promote_type(eltype(batch), eltype(m))
    results = zeros(T, batch_size(batch))
    for i in eachindex(results)
        results[i] = expectation_value(pos, m, _batch_expectation_column(batch, i, T))
    end
    return results
end

function expectation_value(pos::Union{NTuple{4,Int}, NTuple{5,Int}}, m::AbstractMatrix,
                           batch1::BatchStateVector, batch2::BatchStateVector)
    @assert nqubits(batch1) == nqubits(batch2) "Number of qubits must match"
    @assert batch_size(batch1) == batch_size(batch2) "Batch sizes must match"
    T = promote_type(eltype(batch1), eltype(batch2), eltype(m))
    results = zeros(T, batch_size(batch1))
    for i in eachindex(results)
        ket = _batch_expectation_column(batch1, i, T)
        bra = _batch_expectation_column(batch2, i, T)
        results[i] = expectation_value(pos, m, ket, bra)
    end
    return results
end
expectation_value(::Tuple{}, matrix::AbstractMatrix, batch::BatchStateVector) =
    _zero_qubit_matrix_value(matrix) .* dot(batch, batch)
expectation_value(::Tuple{}, matrix::AbstractMatrix, batch::BatchStateVector,
                  batch_c::BatchStateVector) =
    _zero_qubit_matrix_value(matrix) .* dot(batch_c, batch)
