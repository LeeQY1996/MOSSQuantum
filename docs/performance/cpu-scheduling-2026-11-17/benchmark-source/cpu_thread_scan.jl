using MOSSQuantum, LinearAlgebra, Random, Statistics, TOML

# Match cpu_gpu_circuits.jl exactly without requiring CUDA for CPU-only runs.
function cpu_scan_circuit(n, depth)
    rng = MersenneTwister(46113 + n)
    angles = 2π .* rand(rng, n, depth) .- π
    rotations = (RxGate, RyGate, RzGate)
    circuit = QCircuit()
    for layer in 1:depth
        for qubit in 1:n
            push!(circuit, rotations[mod1(layer + qubit, 3)](qubit, angles[qubit, layer]))
        end
        for qubit in 1:n-1
            push!(circuit, CNOTGate(qubit, qubit + 1))
        end
    end
    @assert length(circuit) == depth * (2n - 1)
    return circuit, angles
end

function cpu_scan_apply!(circuit, state)
    GC.gc()
    fill!(storage(state), 0)
    storage(state)[1] = 1
    return @elapsed begin
        result = apply!(circuit, state)
        @assert result === state
    end
end

function cpu_scan_case(n, depth, repetitions)
    circuit, angles = cpu_scan_circuit(n, depth)
    initialization_seconds = @elapsed state = StateVector(n)
    warmup_seconds = cpu_scan_apply!(circuit, state)
    seconds = Float64[]
    for repetition in 1:repetitions
        push!(seconds, cpu_scan_apply!(circuit, state))
        println("qubits=", n, " depth=", depth, " threads=", Threads.nthreads(),
            " repetition=", repetition, " seconds=", last(seconds))
        flush(stdout)
    end
    norm_squared = norm(state)^2
    @assert abs(norm_squared - 1) < 1e-8
    return Dict{String,Any}(
        "qubits" => n, "depth" => depth, "gates" => length(circuit),
        "state_bytes" => sizeof(ComplexF64) * (1 << n), "seed" => 46113 + n,
        "angles_by_layer" => [angles[:, layer] for layer in 1:depth],
        "initialization_seconds" => initialization_seconds,
        "warmup_seconds" => warmup_seconds, "cpu_seconds" => seconds,
        "cpu_median_seconds" => median(seconds), "cpu_minimum_seconds" => minimum(seconds),
        "cpu_maximum_seconds" => maximum(seconds), "norm_squared" => norm_squared,
        "complete" => true)
end

function cpu_scan_main()
    1 <= length(ARGS) <= 4 ||
        error("usage: cpu_thread_scan.jl OUTPUT.toml [DEPTH=2] [REPETITIONS=3] [QUBITS=15,20,25,30]")
    depth = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 2
    repetitions = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 3
    qubits = length(ARGS) >= 4 ? parse.(Int, split(ARGS[4], ',')) : [15, 20, 25, 30]
    depth > 0 && repetitions > 0 && !isempty(qubits) && all(n -> 1 <= n <= 30, qubits) ||
        error("depth and repetitions must be positive; choose 1–30 qubits")
    BLAS.set_num_threads(1)
    tiny, _ = cpu_scan_circuit(3, 2)
    cpu_scan_apply!(tiny, StateVector(3))
    report = Dict{String,Any}(
        "measurement" => "warmed CPU public apply!(circuit, state)",
        "purpose" => depth <= 2 ? "short_circuit_thread_screening" : "full_circuit_timing",
        "limitation" => "Short-circuit screening does not establish the best thread count for depths 10 and 20.",
        "scalar" => "ComplexF64", "julia_version" => string(VERSION),
        "julia_threads" => Threads.nthreads(), "blas_threads" => BLAS.get_num_threads(),
        "cpu_model" => first(Sys.cpu_info()).model, "repetitions" => repetitions,
        "rotations" => "(Rx,Ry,Rz)[mod1(layer+qubit,3)]",
        "timing_excludes" => ["initialization", "reset", "GC", "normalization check"],
        "cases" => Dict{String,Any}[], "complete" => false)
    for n in qubits
        # Each case returns only metadata; collect its state before allocating the next.
        GC.gc()
        push!(report["cases"], cpu_scan_case(n, depth, repetitions))
        open(ARGS[1], "w") do io
            TOML.print(io, report; sorted=true)
        end
    end
    report["complete"] = true
    open(ARGS[1], "w") do io
        TOML.print(io, report; sorted=true)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    cpu_scan_main()
end
