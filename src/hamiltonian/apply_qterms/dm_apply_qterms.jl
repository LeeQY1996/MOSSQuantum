# Multiplication by a Hamiltonian means left multiplication H * rho. In the
# column-major vectorization, the first n qubits are the row indices of rho.
function (h::QubitsTerm)(dm::DensityMatrix)
    T = promote_type(eltype(h), eltype(dm))
    v = convert(Vector{T}, dm.data)
    vout = similar(v)
    _dm_apply_qterm_util!(h, v, vout, nqubits(dm))
    return DensityMatrix(vout, nqubits(dm))
end

function (h::QubitsOperator)(dm::DensityMatrix)
    T = promote_type(eltype(h), eltype(dm))
    v = convert(Vector{T}, dm.data)
    vout = zeros(T, length(v))
    if _largest_nterm(h) <= LARGEST_SUPPORTED_NTERMS
        _dm_apply_util!(h, v, vout, nqubits(dm))
    else
        workspace = similar(v)
        for (k, terms) in h.data
            for (ops, coefficient) in terms
                _dm_apply_qterm_util!(QubitsTerm(k, ops, coefficient), v, workspace, nqubits(dm))
                vout .+= workspace
            end
        end
    end
    return DensityMatrix(vout, nqubits(dm))
end

Base.:*(h::QubitsOperator, dm::DensityMatrix) = h(dm)
Base.:*(h::QubitsTerm, dm::DensityMatrix) = h(dm)

_dm_apply_qterm_util!(m::QubitsTerm, v::AbstractVector, vout::AbstractVector, n::Int) =
    _apply_qterm_util!(m, v, vout)

_dm_apply_util!(m::QubitsOperator, v::AbstractVector, vout::AbstractVector, n::Int) =
    _apply_util!(m, v, vout)
