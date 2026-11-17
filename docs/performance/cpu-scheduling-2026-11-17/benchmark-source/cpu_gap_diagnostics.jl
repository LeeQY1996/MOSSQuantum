using MOSSQuantum, LinearAlgebra, Statistics, TOML, Profile, InteractiveUtils
include("cpu_thread_scan.jl")

function raw_apply!(gates, state)
    for gate in gates
        MOSSQuantum.apply_threaded!(gate, storage(state))
    end
    return state
end

function diagnostic_samples!(run!, state; repetitions=7)
    reset!() = (fill!(storage(state), 0); storage(state)[1] = 1)
    reset!()
    run!(state)
    samples, bytes, gc_seconds = Float64[], Int[], Float64[]
    for _ in 1:repetitions
        GC.gc()
        reset!()
        result = @timed run!(state)
        @assert result.value === state && isfinite(result.time) && result.time > 0
        push!(samples, result.time)
        push!(bytes, result.bytes)
        push!(gc_seconds, result.gctime)
    end
    @assert abs(norm(state)^2 - 1) < 1e-8
    return Dict("seconds" => samples, "median_seconds" => median(samples),
                "allocated_bytes" => bytes, "gc_seconds" => gc_seconds)
end

function main()
    length(ARGS) == 1 || error("usage: cpu_gap_diagnostics.jl OUTPUT.toml")
    BLAS.set_num_threads(1)
    affinity() = only(filter(x -> startswith(x, "Cpus_allowed_list:"), readlines("/proc/self/status")))
    before = affinity()
    report = Dict{String,Any}("threads" => Threads.nthreads(), "julia_version" => string(VERSION),
        "affinity_before" => before, "scalar" => "ComplexF64", "cases" => Any[])
    for n in (15, 20), depth in (10, 20)
        circuit, _ = cpu_scan_circuit(n, depth)
        state = StateVector(n)
        apply!(circuit, state)
        reference = copy(storage(state))
        fill!(storage(state), 0); storage(state)[1] = 1
        raw_apply!(circuit, state)
        @assert norm(storage(state) - reference) < 1e-10
        case = Dict{String,Any}("qubits" => n, "depth" => depth,
            "public" => diagnostic_samples!(s -> apply!(circuit, s), state),
            "raw" => diagnostic_samples!(s -> raw_apply!(circuit, s), state))
        if depth == 20
            rotations = [g for g in circuit if !(g isa CNOTGate)]
            cnots = [g for g in circuit if g isa CNOTGate]
            case["rotations"] = diagnostic_samples!(s -> raw_apply!(rotations, s), state)
            case["cnots"] = diagnostic_samples!(s -> raw_apply!(cnots, s), state)
            # Export a small independently checkable full state for the matching MQ run.
            open(replace(ARGS[1], ".toml" => "-n$n.bin"), "w") do io
                write(io, reference)
            end
        end
        push!(report["cases"], case)
        println("n=$n depth=$depth threads=$(Threads.nthreads()) ",
            "public=", case["public"]["median_seconds"], " raw=", case["raw"]["median_seconds"])
        flush(stdout)
    end
    circuit, _ = cpu_scan_circuit(15, 20)
    state = StateVector(15)
    Profile.clear()
    @profile for _ in 1:100
        apply!(circuit, state)
    end
    open(replace(ARGS[1], ".toml" => "-profile.txt"), "w") do io
        Profile.print(io; format=:flat, sortedby=:count, mincount=5, C=true)
        println(io, "\nCNOT dispatch: ", @which MOSSQuantum.apply_threaded!(CNOTGate(1, 2), storage(state)))
    end
    report["affinity_after"] = affinity()
    @assert before == report["affinity_after"] "CPU allocation changed during diagnosis"
    report["complete"] = true
    open(ARGS[1], "w") do io
        TOML.print(io, report; sorted=true)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
