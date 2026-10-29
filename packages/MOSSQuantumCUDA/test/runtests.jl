using Test, Random, LinearAlgebra
using MOSSQuantum, MOSSQuantumCUDA
import CUDA

include("host.jl")

if CUDA.functional()
    CUDA.allowscalar(false)
    include("device.jl")
elseif "--require-gpu" in ARGS
    error("GPU acceptance was requested, but CUDA.functional() is false; no hardware acceptance was performed")
else
    @testset "CUDA hardware acceptance (GPU unavailable)" begin
        @test_skip CUDA.functional()
    end
end
