using BenchmarkTools
using Dates
using LinearAlgebra
using MOSS
using Random
using SHA
using TOML

# Loading this entrypoint, including its core-only CLI, does not load an AD
# framework. Opt in before main() so Julia 1.10 also sees the extension methods.
if abspath(PROGRAM_FILE) == abspath(@__FILE__) && "--with-zygote" in ARGS
    using Zygote
end

const REPEATED_EVALUATION_SEED = 20261019

function repeated_evaluation_options(args)
    options = Dict{Symbol,Any}(:qubits => 6, :depth => 2, :seconds => 1.0,
        :blas_threads => 1, :output => nothing, :latency_only => false,
        :steady_only => false, :with_zygote => false)
    index = 1
    while index <= length(args)
        flag = args[index]
        if flag in ("--latency-only", "--steady-only", "--with-zygote")
            options[Symbol(replace(flag[3:end], '-' => '_'))] = true
        elseif flag in ("--qubits", "--depth", "--seconds", "--blas-threads", "--output")
            index += 1
            index <= length(args) || throw(ArgumentError("$flag requires a value"))
            key = Symbol(replace(flag[3:end], '-' => '_'))
            options[key] = flag == "--output" ? args[index] :
                flag == "--seconds" ? parse(Float64, args[index]) : parse(Int, args[index])
        else
            throw(ArgumentError("unknown option $flag; supported options: --qubits N --depth N --seconds N --blas-threads N --output PATH --latency-only --steady-only --with-zygote"))
        end
        index += 1
    end
    options[:qubits] >= 2 || throw(ArgumentError("--qubits must be at least 2"))
    options[:depth] >= 1 || throw(ArgumentError("--depth must be positive"))
    options[:blas_threads] >= 1 || throw(ArgumentError("--blas-threads must be positive"))
    isfinite(options[:seconds]) && options[:seconds] > 0 ||
        throw(ArgumentError("--seconds must be positive and finite"))
    options[:latency_only] && options[:steady_only] &&
        throw(ArgumentError("choose either --latency-only or --steady-only"))
    return options
end

function repeated_evaluation_circuit(qubits, depth; noisy=false)
    circuit = QCircuit()
    for layer in 1:depth
        for position in 1:qubits
            push!(circuit, RyGate(position, 0.0; isparas=true))
            push!(circuit, RzGate(position, 0.0; isparas=true))
        end
        for position in 1:(qubits - 1)
            push!(circuit, CNOTGate(position, position + 1))
        end
        if noisy
            for position in 1:qubits
                push!(circuit, AmplitudeDamping(position; γ=0.08))
            end
        end
    end
    return circuit
end

"""Construct deterministic public-API objectives without executing them."""
function repeated_evaluation_cases(; qubits=6, depth=2)
    rng = MersenneTwister(REPEATED_EVALUATION_SEED)
    pure = normalize!(StateVector(randn(rng, ComplexF64, 1 << qubits)))
    dimension = 1 << qubits
    # A genuinely mixed initial state, rather than just a density representation
    # of a pure state. Setup and objective snapshots are outside all timings.
    mixed = DensityMatrix(0.8 * (storage(pure) * storage(pure)') +
        (0.2 / dimension) * Matrix{ComplexF64}(I, dimension, dimension))
    observable = QubitsTerm(1 => "Z"; coeff=0.7) +
        QubitsTerm(1 => "X", qubits => "X"; coeff=0.3)
    unitary = repeated_evaluation_circuit(qubits, depth)
    noisy = repeated_evaluation_circuit(qubits, depth; noisy=true)
    slots = nparameters(unitary)
    values = 0.2 .* randn(rng, slots)
    # Every layer shares the same Ry/Rz pair on each qubit. The slots and gate
    # work are unchanged; only the independent parameter count is reduced.
    shared_map = ParameterMap(unitary, repeat(collect(1:(2qubits)), depth))
    return [
        (name="pure", objective=ExpectationObjective(unitary, observable, pure), values=copy(values)),
        (name="mixed", objective=ExpectationObjective(unitary, observable, mixed), values=copy(values)),
        (name="fixed_noise", objective=ExpectationObjective(noisy, observable, mixed), values=copy(values)),
        (name="shared", objective=ExpectationObjective(unitary, observable, pure; parameter_map=shared_map),
            values=copy(values[1:(2qubits)])),
    ]
end

function repeated_evaluation_zygote(method, objective, values)
    return Zygote.gradient(theta -> differentiable_value(method, objective, theta), values)[1]
end

function repeated_evaluation_operations(case, method; with_zygote=false)
    objective, values = case.objective, case.values
    operations = Pair{String,Function}[
        "evaluate" => (() -> evaluate(objective, values)),
        "value_and_gradient" => (() -> value_and_gradient(method, objective, values)),
        "pullback_prepare" => (() -> value_and_pullback(method, objective, values)),
    ]
    with_zygote && push!(operations, "zygote_gradient" =>
        (() -> repeated_evaluation_zygote(method, objective, values)))
    return operations
end

function repeated_evaluation_row(phase, case, operation; time_ns, bytes, allocations,
                                 gc_time_ns, samples, evals)
    return (phase=phase, case=case.name, operation=operation,
        parameter_slots=nparameters(case.objective.template), independent_parameters=length(case.values),
        time_ns=time_ns, bytes=bytes, allocations=allocations, gc_time_ns=gc_time_ns,
        samples=samples, evals=evals)
end

function repeated_evaluation_first!(rows, case, operation, invoke)
    timed = @timed invoke()
    push!(rows, repeated_evaluation_row("first_call", case, operation;
        time_ns=timed.time * 1e9, bytes=timed.bytes,
        allocations=Base.gc_alloc_count(timed.gcstats), gc_time_ns=timed.gctime * 1e9,
        samples=1, evals=1))
    return timed.value
end

"""Check public results and pullback reuse outside measured expressions."""
function repeated_evaluation_check(case, method; with_zygote=false)
    objective, values = case.objective, case.values
    original = copy(values)
    initial = copy(storage(objective.initial_state))
    supports_gradient(method, objective) || error("unsupported case $(case.name)")
    value = evaluate(objective, values)
    gradient_value, gradient = value_and_gradient(method, objective, values)
    prepared_value, back = value_and_pullback(method, objective, values)
    isapprox(value, gradient_value; atol=1e-11) || error("gradient value mismatch")
    isapprox(value, prepared_value; atol=1e-11) || error("pullback value mismatch")
    all(isfinite, gradient) || error("nonfinite gradient")
    isapprox(back(1.0), gradient; atol=1e-10) || error("pullback gradient mismatch")
    isapprox(back(-0.5), -0.5gradient; atol=1e-10) || error("pullback seed mismatch")
    # Interleave another parameter point; the already prepared pullback must
    # continue to represent its original input and return independent vectors.
    other = values .+ 0.013
    evaluate(objective, other)
    value_and_gradient(method, objective, other)
    first_gradient = back(1.0)
    first_gradient .= 123
    isapprox(back(1.0), gradient; atol=1e-10) || error("pullback snapshot changed")
    step = 1e-6
    plus, minus = copy(values), copy(values)
    plus[1] += step
    minus[1] -= step
    finite_difference = (evaluate(objective, plus) - evaluate(objective, minus)) / (2step)
    isapprox(gradient[1], finite_difference; atol=1e-7, rtol=1e-5) ||
        error("first-coordinate finite difference mismatch")
    if with_zygote
        isapprox(repeated_evaluation_zygote(method, objective, values), gradient; atol=1e-10) ||
            error("optional Zygote gradient mismatch")
    end
    values == original || error("input parameters changed")
    storage(objective.initial_state) == initial || error("initial state changed")
    return nothing
end

function repeated_evaluation_steady!(rows, case, operation, invoke, seconds)
    benchmark = @benchmarkable $invoke() evals=1
    benchmark.params.seconds = seconds
    trial = run(benchmark)
    estimate = median(trial)
    push!(rows, repeated_evaluation_row("steady_median", case, operation;
        time_ns=estimate.time, bytes=estimate.memory, allocations=estimate.allocs,
        gc_time_ns=estimate.gctime, samples=length(trial), evals=trial.params.evals))
    return nothing
end

function repeated_evaluation_command_output(command)
    try
        return strip(read(command, String))
    catch
        return "unavailable"
    end
end

function repeated_evaluation_metadata(options)
    root = normpath(joinpath(@__DIR__, ".."))
    manifest = joinpath(@__DIR__, "Manifest.toml")
    project = joinpath(@__DIR__, "Project.toml")
    source_hashes = Dict{String,String}()
    for directory in ("src", "ext")
        for (folder, _, files) in walkdir(joinpath(root, directory))
            for file in files
                endswith(file, ".jl") || continue
                path = joinpath(folder, file)
                source_hashes[relpath(path, root)] = bytes2hex(sha256(read(path)))
            end
        end
    end
    source_summary = join((path * "\0" * source_hashes[path]
        for path in sort!(collect(keys(source_hashes)))), '\n')
    return Dict(
        "recorded_utc" => string(now(UTC)), "julia_version" => string(VERSION),
        "julia_executable" => joinpath(Sys.BINDIR, Base.julia_exename()),
        "julia_threads" => Threads.nthreads(), "blas_threads" => BLAS.get_num_threads(),
        "blas_configuration" => sprint(show, BLAS.get_config()),
        "cpu" => string(first(Sys.cpu_info()).model), "logical_cpu_threads" => Sys.CPU_THREADS,
        "total_memory_bytes" => Sys.total_memory(), "os" => string(Sys.KERNEL),
        "architecture" => string(Sys.ARCH), "word_size" => Sys.WORD_SIZE,
        "revision" => repeated_evaluation_command_output(`git -C $root rev-parse HEAD`),
        "working_tree" => repeated_evaluation_command_output(`git -C $root status --short`),
        "diff_stat" => repeated_evaluation_command_output(`git -C $root diff --stat HEAD`),
        "benchmark_project_sha256" => bytes2hex(sha256(read(project))),
        "benchmark_manifest_sha256" => isfile(manifest) ? bytes2hex(sha256(read(manifest))) : "unavailable",
        "script_sha256" => bytes2hex(sha256(read(@__FILE__))),
        "source_snapshot_sha256" => bytes2hex(sha256(source_summary)),
        "source_file_sha256" => source_hashes,
        "active_project" => something(Base.active_project(), "unavailable"),
        "reproduction_command" => [joinpath(Sys.BINDIR, Base.julia_exename());
            "--project=" * dirname(something(Base.active_project(), project));
            "--threads=" * string(Threads.nthreads()); PROGRAM_FILE; ARGS],
        "qubits" => options[:qubits], "depth" => options[:depth],
        "seconds_per_trial" => options[:seconds], "seed" => REPEATED_EVALUATION_SEED,
        "scalar_type" => "ComplexF64 state, Float64 parameters", "method" => "AdjointGradient",
        "with_zygote" => options[:with_zygote],
        "zygote_loaded" => haskey(Base.loaded_modules,
            Base.PkgId(Base.UUID("e88e6eb3-aa80-5325-afca-941959d7151f"), "Zygote")),
        "chainrulescore_loaded" => haskey(Base.loaded_modules,
            Base.PkgId(Base.UUID("d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"), "ChainRulesCore")),
        "latency_note" => "First calls include compilation after package loading and construction; later cases reuse earlier compilation. Pullback application follows its measured preparation.",
        "steady_note" => "Median BenchmarkTools samples, evals=1; setup and correctness checks excluded. Prepared pullback reused; each call includes reverse work and result allocation.",
    )
end

function repeated_evaluation_write(rows, metadata, output)
    header = (:phase, :case, :operation, :parameter_slots, :independent_parameters,
        :time_ns, :bytes, :allocations, :gc_time_ns, :samples, :evals)
    write_rows = function(io)
        println(io, join(string.(header), '\t'))
        for row in rows
            println(io, join((string(getproperty(row, key)) for key in header), '\t'))
        end
    end
    write_rows(stdout)
    if !isnothing(output)
        mkpath(dirname(abspath(output)))
        open(write_rows, output, "w")
        open(output * ".metadata.toml", "w") do io
            TOML.print(io, metadata; sorted=true)
        end
        println(stderr, "Saved ", abspath(output), " and metadata")
    end
    return nothing
end

function repeated_evaluation_main(args=ARGS)
    options = repeated_evaluation_options(args)
    options[:with_zygote] && !isdefined(@__MODULE__, :Zygote) &&
        error("load Zygote before calling main with --with-zygote when using include")
    BLAS.set_num_threads(options[:blas_threads])
    cases = repeated_evaluation_cases(qubits=options[:qubits], depth=options[:depth])
    method = AdjointGradient()
    rows = NamedTuple[]
    if !options[:steady_only]
        for case in cases
            for (operation, invoke) in repeated_evaluation_operations(case, method;
                    with_zygote=options[:with_zygote])
                result = repeated_evaluation_first!(rows, case, operation, invoke)
                if operation == "pullback_prepare"
                    _, back = result
                    repeated_evaluation_first!(rows, case, "pullback_apply", () -> back(1.0))
                end
            end
        end
    end
    # Checks deliberately follow first-call timings to preserve their meaning.
    for case in cases
        repeated_evaluation_check(case, method; with_zygote=options[:with_zygote])
    end
    if !options[:latency_only]
        for case in cases
            operations = repeated_evaluation_operations(case, method; with_zygote=options[:with_zygote])
            _, back = value_and_pullback(method, case.objective, case.values)
            push!(operations, "pullback_apply" => (() -> back(1.0)))
            for (operation, invoke) in operations
                repeated_evaluation_steady!(rows, case, operation, invoke, options[:seconds])
            end
        end
    end
    metadata = repeated_evaluation_metadata(options)
    !options[:with_zygote] && (metadata["zygote_loaded"] || metadata["chainrulescore_loaded"]) &&
        error("core benchmark unexpectedly loaded Zygote or ChainRulesCore")
    repeated_evaluation_write(rows, metadata, options[:output])
    return rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    repeated_evaluation_main()
end
