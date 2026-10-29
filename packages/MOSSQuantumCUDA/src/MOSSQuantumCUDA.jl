module MOSSQuantumCUDA

import CUDA
import MOSSQuantum
using LinearAlgebra
using StaticArrays: StaticArray

export CUDABackend, gpu_state, to_gpu, to_cpu

"""Single-state CUDA execution on the current device; owns no mutable workspace."""
struct CUDABackend <: MOSSQuantum.AbstractBackend end

const Scalar = Union{Float32,Float64,ComplexF32,ComplexF64}
const CUDAState = MOSSQuantum.StateVector{T,A} where {T<:Number,A<:CUDA.CuArray{T,1,CUDA.DeviceMemory}}

include("preparation.jl")
include("kernels.jl")
include("execution.jl")
include("observables.jl")
include("storage.jl")

end
