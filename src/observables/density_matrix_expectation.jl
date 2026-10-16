
function expectation(m::QubitsTerm, state::DensityMatrix)
    isempty(m) && return coeff(m) * tr(state)
    if length(positions(m)) <= 3
        T = promote_type(eltype(m), eltype(state))
        data = convert(Matrix{T}, storage(state))
        return expectation_value_serial(Tuple(positions(m)), _get_mat(m), data)
    else
        return tr(m * state)
    end
end

function expectation(m::QubitsOperator, state::DensityMatrix)
    if _largest_nterm(m) <= 3
        T = promote_type(eltype(m), eltype(state))
        data = convert(Matrix{T}, storage(state))
        r = zero(T)
        for (k, v) in m.data
            r += expectation_value_serial(k, _get_mat(length(k), v), data)
        end
        return r
    else
        return tr(m * state)
    end
end
