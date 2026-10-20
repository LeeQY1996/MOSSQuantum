@adjoint QSelect(key::Int, state::Int) = QSelect(key, state), z -> (nothing, nothing)

@adjoint _apply_throw_impl(x::QSelect, qstate::StateVector) = begin
    result = _apply_throw_impl(x, qstate)
    return result, z -> begin
        data = storage(_to_sv(result, z))
        m = zeros(eltype(data), length(storage(qstate)))
        slice = view(reshape(m, 2^(x.position-1), 2, :), :, x.state+1, :)
        copyto!(slice, reshape(data, size(slice)))
        return (nothing, m)
    end
end

@adjoint _apply_keep_impl(x::QSelect, qstate::StateVector) = _apply_keep_impl(x, qstate), z -> begin
    state = _to_sv(qstate, z)
    return (nothing, storage(_apply_keep_impl(x, state)))
end

@adjoint _apply_impl(x::QSelect, qstate::StateVector; keep::Bool) = begin
    return keep ? Zygote.pullback(_apply_keep_impl, x, qstate) : Zygote.pullback(_apply_throw_impl, x, qstate)
end
