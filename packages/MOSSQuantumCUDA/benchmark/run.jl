using MOSSQuantum, MOSSQuantumCUDA, CUDA, LinearAlgebra

CUDA.functional() || error("This benchmark requires a functional NVIDIA GPU")
CUDA.allowscalar(false)
n = isempty(ARGS) ? 18 : parse(Int, ARGS[1])
repetitions = length(ARGS) < 2 ? 10 : parse(Int, ARGS[2])
1 <= n <= 30 || error("choose 1–30 qubits within the available device memory")
repetitions > 0 || error("repetitions must be positive")
CUDA.versioninfo()
println("Julia threads: ", Threads.nthreads(), "; BLAS threads: ", BLAS.get_num_threads())
println("qubits=", n, " repetitions=", repetitions, " scalar=ComplexF64")

circuit = QCircuit()
for layer in 1:3
    for q in 1:n
        push!(circuit, RyGate(q, 0.13 * layer))
    end
    for q in 1:(n - 1)
        push!(circuit, CNOTGate(q, q + 1))
    end
end
host = StateVector(n)
device = to_gpu(host)
cpu_result = circuit * host
gpu_result = circuit * device
@assert to_cpu(gpu_result) ≈ cpu_result
observable = QubitsTerm(n => "Z")
@assert expectation(observable, gpu_result) ≈ expectation(observable, cpu_result)
@assert probabilities(gpu_result; qubits=(n,)) ≈ probabilities(cpu_result; qubits=(n,))

function report(label, prepare, operation)
    operation(prepare())
    CUDA.synchronize()
    times = Float64[]
    for _ in 1:repetitions
        input = prepare() # exclude copies/reset from mutating execution timings
        CUDA.synchronize()
        push!(times, @elapsed begin
            operation(input)
            CUDA.synchronize()
        end)
    end
    println(label, "\tmean_seconds=", sum(times) / length(times), "\tminimum_seconds=", minimum(times))
end

report("cpu_circuit", () -> copy(host), s -> apply!(circuit, s))
report("gpu_circuit", () -> copy(device), s -> apply!(circuit, s))
report("cpu_expectation", () -> cpu_result, s -> expectation(observable, s))
report("gpu_expectation", () -> gpu_result, s -> expectation(observable, s))
report("gpu_marginal_with_readout", () -> gpu_result, s -> probabilities(s; qubits=(n,)))
report("host_to_device", () -> host, to_gpu)
report("device_to_host", () -> device, to_cpu)
