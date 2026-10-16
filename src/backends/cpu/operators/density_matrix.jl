_dm_apply_qterm_util!(m::QubitsTerm, v::AbstractVector, vout::AbstractVector, n::Int) =
    _apply_qterm_util!(m, v, vout)

_dm_apply_util!(m::QubitsOperator, v::AbstractVector, vout::AbstractVector, n::Int) =
    _apply_util!(m, v, vout)
