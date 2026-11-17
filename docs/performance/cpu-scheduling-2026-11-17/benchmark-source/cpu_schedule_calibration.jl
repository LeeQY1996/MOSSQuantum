include("cpu_gap_diagnostics.jl")
using Dates, SHA

file_sha256(path) = bytes2hex(open(sha256, path))

function calibration_resources()
    return Dict("affinity" => only(filter(line -> startswith(line, "Cpus_allowed_list:"),
        readlines("/proc/self/status"))),
        "cpuset" => strip(read("/sys/fs/cgroup/cpuset.cpus.effective", String)))
end

function calibration_sources()
    root = dirname(dirname(pathof(MOSSQuantum)))
    return Dict(relpath(joinpath(directory, file), root) => file_sha256(joinpath(directory, file))
        for (directory, _, files) in walkdir(joinpath(root, "src")) for file in files if endswith(file, ".jl"))
end

function compare_cpu_reference(path, actual)
    @assert filesize(path) == sizeof(ComplexF64) * length(actual)
    return open(path, "r") do io
        buffer = Vector{ComplexF64}(undef, min(length(actual), 1 << 18))
        error2 = reference_norm = actual_norm = maximum_error = 0.0
        for offset in 1:length(buffer):length(actual)
            resize!(buffer, min(length(buffer), length(actual) - offset + 1))
            read!(io, buffer)
            @inbounds for index in eachindex(buffer)
                expected, observed = buffer[index], actual[offset + index - 1]
                error2 += abs2(observed - expected)
                maximum_error = max(maximum_error, abs(observed - expected))
                reference_norm += abs2(expected)
                actual_norm += abs2(observed)
            end
        end
        relative = sqrt(error2 / reference_norm)
        @assert relative < 1e-10 && maximum_error < 1e-10
        @assert abs(reference_norm - 1) < 1e-8 && abs(actual_norm - 1) < 1e-8
        return Dict("amplitudes_checked" => length(actual), "relative_l2_error" => relative,
            "maximum_amplitude_error" => maximum_error, "reference_norm_squared" => reference_norm,
            "actual_norm_squared" => actual_norm)
    end
end

function calibration_reference(directory, n, depth, angles, data, mode, sources)
    binary, metadata = joinpath(directory, "n$n-d$depth.bin"), joinpath(directory, "n$n-d$depth.toml")
    if mode == "write" && !ispath(binary) && !ispath(metadata)
        Base.ENDIAN_BOM == 0x04030201 || error("reference export requires little endian")
        open(binary, "w") do io
            write(io, data)
        end
        record = Dict("qubits" => n, "depth" => depth, "scalar" => "ComplexF64",
            "angles_by_layer" => [angles[:, layer] for layer in 1:depth],
            "bytes" => filesize(binary), "sha256" => file_sha256(binary),
            "created_threads" => Threads.nthreads(), "core_source_sha256" => sources)
        open(metadata, "w") do io
            TOML.print(io, record; sorted=true)
        end
    end
    isfile(binary) && isfile(metadata) || error("missing baseline pair for n$n/d$depth")
    record = TOML.parsefile(metadata)
    @assert record["qubits"] == n && record["depth"] == depth && record["scalar"] == "ComplexF64"
    @assert record["angles_by_layer"] == [angles[:, layer] for layer in 1:depth]
    @assert record["bytes"] == filesize(binary) == 16 * (1 << n)
    @assert record["sha256"] == file_sha256(binary)
    if mode == "write"
        record["sha256"] == bytes2hex(sha256(reinterpret(UInt8, data))) ||
            error("existing baseline differs; use a separate BASELINE_DIR for each thread configuration")
    end
    return binary, metadata, record
end

function calibration_main()
    3 <= length(ARGS) <= 6 || error("usage: cpu_schedule_calibration.jl OUTPUT.toml BASELINE_DIR write|check [QUBITS=15,20,25] [DEPTHS=10,20] [REPS=5]")
    output, directory, mode = ARGS[1:3]
    qubits = length(ARGS) >= 4 ? parse.(Int, split(ARGS[4], ',')) : [15, 20, 25]
    depths = length(ARGS) >= 5 ? parse.(Int, split(ARGS[5], ',')) : [10, 20]
    repetitions = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 5
    mode in ("write", "check") && repetitions > 0 && !isempty(qubits) && !isempty(depths) &&
        all(n -> 1 <= n <= 25, qubits) && all(d -> d in (10, 20), depths) || error("invalid calibration settings")
    ispath(output) && error("refusing to overwrite output")
    mode == "write" ? mkpath(directory) : (isdir(directory) || error("baseline directory is missing"))
    BLAS.set_num_threads(1)
    resources, sources = calibration_resources(), calibration_sources()
    report = Dict{String,Any}("complete" => false, "mode" => mode, "scalar" => "ComplexF64",
        "julia_version" => string(VERSION), "mossquantum_version" => string(pkgversion(MOSSQuantum)),
        "threads" => Threads.nthreads(), "blas_threads" => BLAS.get_num_threads(),
        "repetitions" => repetitions, "baseline_directory" => abspath(directory),
        "resource_before" => resources, "core_source_sha256" => sources,
        "diagnostic_source_sha256" => Dict(file => file_sha256(joinpath(@__DIR__, file)) for file in
            ("cpu_thread_scan.jl", "cpu_gap_diagnostics.jl", "cpu_schedule_calibration.jl")),
        "started_at_utc" => string(now(UTC), 'Z'), "cases" => Any[],
        "validation_scope" => "Public and raw complete circuits are compared with every saved old-public ComplexF64 amplitude. Separate rotation/CNOT groups check normalization, not independent full-state references.")
    save!() = open(io -> TOML.print(io, report; sorted=true), output, "w")
    save!()
    for n in qubits, depth in depths
        circuit, angles = cpu_scan_circuit(n, depth)
        rotations = [gate for gate in circuit if !(gate isa CNOTGate)]
        cnots = [gate for gate in circuit if gate isa CNOTGate]
        state = StateVector(n)
        @assert eltype(state) === ComplexF64
        case = Dict{String,Any}("qubits" => n, "depth" => depth, "gates" => length(circuit))
        push!(report["cases"], case)
        for (name, run!) in (("public", s -> apply!(circuit, s)),
                ("raw", s -> raw_apply!(circuit, s)),
                ("rotations", s -> raw_apply!(rotations, s)), ("cnots", s -> raw_apply!(cnots, s)))
            before = calibration_resources()
            @assert before == resources "CPU allocation changed before calibration group"
            println("START n=$n depth=$depth threads=$(Threads.nthreads()) group=$name")
            flush(stdout)
            entry = diagnostic_samples!(run!, state; repetitions)
            entry["minimum_seconds"], entry["maximum_seconds"] = minimum(entry["seconds"]), maximum(entry["seconds"])
            entry["resource_before"], entry["resource_after"] = before, calibration_resources()
            @assert entry["resource_after"] == resources "CPU allocation changed during calibration group"
            if name in ("public", "raw")
                binary, metadata, reference = calibration_reference(directory, n, depth, angles, storage(state),
                    name == "public" ? mode : "check", sources)
                entry["correctness"] = compare_cpu_reference(binary, storage(state))
                case["reference_metadata"] = basename(metadata)
                case["reference_metadata_sha256"] = file_sha256(metadata)
                case["reference_sha256"] = reference["sha256"]
            end
            case[name] = entry
            save!()
            println("DONE n=$n depth=$depth group=$name median=", entry["median_seconds"])
            flush(stdout)
        end
    end
    report["resource_after"] = calibration_resources()
    @assert report["resource_after"] == resources && calibration_sources() == sources
    report["finished_at_utc"] = string(now(UTC), 'Z')
    report["complete"] = true
    save!()
end

function calibration_self_test()
    mktempdir() do directory
        data = ComplexF64[0.6, 0.8im]
        angles = reshape([0.2], 1, 1)
        binary, metadata, original = calibration_reference(directory, 1, 1, angles, data, "write", Dict())
        @assert compare_cpu_reference(binary, data)["relative_l2_error"] == 0
        calibration_reference(directory, 1, 1, angles, data, "write", Dict())
        @assert TOML.parsefile(metadata) == original
        rejected = false
        try
            compare_cpu_reference(binary, ComplexF64[0.8, 0.6im])
        catch error
            error isa AssertionError || rethrow()
            rejected = true
        end
        @assert rejected
    end
    println("REFERENCE_SELF_TEST_PASSED (roundtrip, existing-reference preservation, changed-state rejection)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    ARGS == ["--self-test"] ? calibration_self_test() : calibration_main()
end
