function apply!(x::Gate, batch::BatchStateVector)
    @assert _check_pos_range(x, nqubits(batch))
    T = eltype(batch)
    if (eltype(x) <: Complex) && (T <: Real)
        batch = convert(BatchStateVector{Complex{T}}, batch)
    end
    apply_threaded!(x, batch)
    return batch
end

function apply!(circuit::QCircuit, batch::BatchStateVector)
    for gate in circuit
        batch = apply!(gate, batch)
    end
    return batch
end

Base.:*(circuit::QCircuit, batch::BatchStateVector) = apply!(circuit, copy(batch))

