# Optional developer diagnostic for machines without a GPU. This uses CUDA.jl
# compiler internals (tested with 6.4.2), not the package's execution API. Select
# and install a CUDA toolkit in the active environment before running this file.
# Successful PTX generation is not hardware acceptance.
using CUDA, MOSSQuantumCUDA

const CC = CUDA.CUDACore
const GCCompiler = CC.GPUCompiler
target = isempty(ARGS) ? "sm_80" : ARGS[1]
config = CC.compiler_config(nothing; arch=target, kernel=true)
println("Julia=", VERSION, " CUDA.jl=", pkgversion(CUDA),
        " compiler=", CC.compiler_version(), " target=", target)

domains = ((Float32, Float32), (Float32, Float64), (Float32, ComplexF32),
           (Float32, ComplexF64), (Float64, Float64), (Float64, ComplexF64),
           (ComplexF32, ComplexF32), (ComplexF32, ComplexF64), (ComplexF64, ComplexF64))
for (input_type, output_type) in domains, arity in 1:5
    types = Tuple{CUDA.CuDeviceArray{output_type,1,1}, CUDA.CuDeviceArray{input_type,1,1},
                  CUDA.CuDeviceArray{output_type,2,1}, NTuple{arity,Int}}
    source = GCCompiler.methodinstance(typeof(MOSSQuantumCUDA._gate_kernel!), types)
    job = GCCompiler.CompilerJob(source, config)
    io = IOBuffer()
    GCCompiler.code_native(io, job; raw=true)
    ptx = String(take!(io))
    @assert occursin(".entry", ptx)
    println("PTX compiled: ", input_type, " -> ", output_type,
            " / ", arity, " qubits / ", sizeof(ptx), " bytes")
end
