# The arithmetic helper is also exercised on host arrays against independent
# dense references. Only the wrapper below uses CUDA execution intrinsics.
@inline function _local_amplitude(input, matrix, positions::NTuple{N,Int}, basis::Int) where N
    row = 0
    base = basis
    for j in 1:N
        shift = positions[j] - 1
        row |= ((basis >> shift) & 1) << (j - 1)
        base &= ~(1 << shift)
    end
    result = zero(eltype(matrix))
    for column in 0:((1 << N) - 1)
        source = base
        for j in 1:N
            source |= ((column >> (j - 1)) & 1) << (positions[j] - 1)
        end
        @inbounds result += matrix[row + 1, column + 1] * input[source + 1]
    end
    return result
end

function _gate_kernel!(output, input, matrix, positions::NTuple{N,Int}) where N
    index = Int((CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x)
    stride = Int(CUDA.gridDim().x * CUDA.blockDim().x)
    while index <= length(output)
        @inbounds output[index] = _local_amplitude(input, matrix, positions, index - 1)
        index += stride
    end
    return nothing
end

function _gate_output(data, prepared::PreparedGate{T}) where T
    output = similar(data, T, length(data))
    matrix = CUDA.CuArray{T,2,CUDA.DeviceMemory}(prepared.matrix)
    threads = min(256, length(data))
    blocks = min(cld(length(data), threads), 65535)
    # Keep scratch and metadata alive until execution finishes; no persistent
    # workspace or stream is shared between calls.
    GC.@preserve data matrix output begin
        CUDA.@cuda threads=threads blocks=blocks _gate_kernel!(output, data, matrix, prepared.positions)
        CUDA.synchronize()
    end
    return output
end
