function _require_cuda()
    CUDA.functional() || throw(ArgumentError("MOSSQuantumCUDA needs a functional NVIDIA GPU and CUDA driver"))
end

"""
    gpu_state(n; T=ComplexF64)

Allocate |0…0⟩ directly on the current CUDA device. The default matches MOSSQuantum
precision; ComplexF32 is an explicit choice. No full host state is allocated.
"""
function gpu_state(n::Int; T::Type=ComplexF64)
    T <: Scalar || throw(ArgumentError("unsupported CUDA state scalar type"))
    0 <= n < 8sizeof(Int) - 1 || throw(ArgumentError("invalid qubit count"))
    _require_cuda()
    data = CUDA.CuArray{T,1,CUDA.DeviceMemory}(undef, 1 << n)
    fill!(data, zero(T))
    copyto!(data, 1, T[1], 1, 1)
    CUDA.synchronize()
    return MOSSQuantum.StateVector(data; preserve_storage=true)
end

"""Explicitly copy a host state vector onto the current CUDA device, preserving precision."""
function to_gpu(state::MOSSQuantum.StateVector)
    data = MOSSQuantum.storage(state)
    data isa StridedVector || throw(ArgumentError("to_gpu expects host vector storage or an existing CUDA state"))
    eltype(state) <: Scalar || throw(ArgumentError("unsupported CUDA state scalar type"))
    _require_cuda()
    return MOSSQuantum.StateVector(CUDA.CuArray{eltype(state),1,CUDA.DeviceMemory}(data); preserve_storage=true)
end
function to_gpu(state::CUDAState)
    _check_state(state)
    return copy(state)
end

"""Explicitly copy device amplitudes into an independent CPU StateVector."""
to_cpu(state::CUDAState) = MOSSQuantum.StateVector(Array(MOSSQuantum.storage(state)))
