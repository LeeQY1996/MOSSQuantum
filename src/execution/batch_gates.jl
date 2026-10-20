function _cpu_apply!(x::Gate, batch::BatchStateVector)
    supports(CPUBackend(), x, batch) || throw(UnsupportedOperation(CPUBackend(), x, batch, :apply))
    validate_positions(x, nqubits(batch))
    register = Tuple(positions(x))
    length(register) == nqubits(x) && length(unique(register)) == length(register) ||
        throw(ArgumentError("gate positions must be distinct and match its qubit count"))
    dimension = 2^nqubits(x)
    size(mat(x)) == (dimension, dimension) ||
        throw(DimensionMismatch("gate matrix dimensions must match its qubit count"))
    T = eltype(batch)
    if (eltype(x) <: Complex) && (T <: Real)
        batch = convert(BatchStateVector{Complex{T}}, batch)
    end
    apply_threaded!(x, batch)
    return batch
end

function _check_batch_cpu_instructions(circuit::QCircuit, batch::_DenseBatchState)
    for instruction in circuit
        if instruction isa QCircuit
            _check_batch_cpu_instructions(instruction, batch)
        elseif instruction isa Gate
            _check_batch_density_gate(instruction, batch)
        elseif instruction isa QuantumMap
            _check_batch_density_channel(instruction, batch)
        end
    end
    return nothing
end

function _cpu_apply!(circuit::QCircuit, batch::_DenseBatchState;
                rng::Random.AbstractRNG=Random.default_rng())
    chosen_backend = backend(batch)
    supports(chosen_backend, circuit, batch) ||
        throw(UnsupportedOperation(chosen_backend, circuit, batch, :apply))
    validate_positions(circuit, nqubits(batch))
    _check_batch_cpu_instructions(circuit, batch)
    # External dense instruction specializations must still participate.
    for instruction in circuit
        if instruction isa QMeasure
            apply!(instruction, batch; rng=rng)
        elseif instruction isa QSelect
            apply!(instruction, batch)
        elseif instruction isa QCircuit
            batch = apply!(instruction, batch; rng=rng)
        else
            batch = apply!(instruction, batch)
            batch isa AbstractQuantumState ||
                throw(ArgumentError("apply! for $(typeof(instruction)) must return an AbstractQuantumState"))
        end
    end
    return batch
end

Base.:*(circuit::QCircuit, batch::BatchStateVector) = _apply_circuit_copy(circuit, batch)
