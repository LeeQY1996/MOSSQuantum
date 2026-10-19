# This entrypoint intentionally reuses the established timing and provenance
# helpers without changing the older benchmark or loading an AD framework.
include(joinpath(@__DIR__, "repeated_evaluation.jl"))

if abspath(PROGRAM_FILE) == abspath(@__FILE__) && "--with-zygote" in ARGS
    using Zygote
end

const BATCH_EXECUTION_SEED = 20261020

function batch_execution_options(args)
    inherited = String[]
    batches = [1, 4, 16, 64]
    index = 1
    while index <= length(args)
        flag = args[index]
        if flag in ("--batches", "--batch-counts")
            index += 1
            index <= length(args) || throw(ArgumentError("$flag requires comma-separated counts"))
            batches = parse.(Int, split(args[index], ','))
        else
            push!(inherited, flag)
            if flag in ("--qubits", "--depth", "--seconds", "--blas-threads", "--output")
                index += 1
                index <= length(args) || throw(ArgumentError("$flag requires a value"))
                push!(inherited, args[index])
            end
        end
        index += 1
    end
    !isempty(batches) && all(>(0), batches) ||
        throw(ArgumentError("batch counts must be positive"))
    length(unique(batches)) == length(batches) ||
        throw(ArgumentError("batch counts must be distinct"))
    options = repeated_evaluation_options(inherited)
    options[:batches] = batches
    return options
end

"""Construct seeded inputs, objectives, and scalar references outside timings."""
function batch_execution_cases(; qubits=6, depth=2, batches=[1, 4, 16, 64])
    rng = MersenneTwister(BATCH_EXECUTION_SEED)
    pure = rand_batch(rng, ComplexF64, qubits, maximum(batches))
    dimension = 1 << qubits
    mixed_data = storage(BatchDensityMatrix(pure))
    for b in axes(mixed_data, 3)
        mixed_data[:, :, b] .*= 0.8
        for j in 1:dimension
            mixed_data[j, j, b] += 0.2 / dimension
        end
    end
    unitary = repeated_evaluation_circuit(qubits, depth)
    noisy = repeated_evaluation_circuit(qubits, depth; noisy=true)
    parameter_map = ParameterMap(unitary, repeat(collect(1:(2qubits)), depth))
    values = 0.2 .* randn(rng, nparameters(parameter_map))
    observable = QubitsTerm(1 => "Z"; coeff=0.7) +
        QubitsTerm(1 => "X", qubits => "X"; coeff=0.3)
    # A general two-qubit unitary avoids measuring only a specialized named gate.
    gate = QuantumGate((1, qubits), Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q))
    channel = AmplitudeDamping(qubits; γ=0.08)
    cases = NamedTuple[]
    for count in batches
        pure_input = BatchStateVector(storage(pure)[:, 1:count], qubits, count)
        mixed_input = BatchDensityMatrix(mixed_data[:, :, 1:count], qubits, count)
        for (label, circuit, initial, with_channel) in (
                ("pure_unitary", unitary, pure_input, false),
                ("mixed_unitary", unitary, mixed_input, false),
                ("pure_fixed_noise", noisy, pure_input, true),
                ("mixed_fixed_noise", noisy, mixed_input, true))
            objective = BatchExpectationObjective(circuit, observable, initial;
                parameter_map=parameter_map, reduction=:mean)
            singles = [initial isa BatchStateVector ? StateVector(initial, b) :
                DensityMatrix(initial, b) for b in 1:count]
            reference = [ExpectationObjective(circuit, observable, sample;
                parameter_map=parameter_map) for sample in singles]
            push!(cases, (name="$(label)_B$(count)", kind=label,
                batch_count=count, objective=objective, reference=reference,
                initial=initial, singles=singles, values=copy(values),
                observable=observable, gate=gate,
                channel=with_channel ? channel : nothing))
        end
    end
    return cases
end

function batch_execution_operations(case, method; with_zygote=false)
    operations = Pair{String,Function}[
        "expectation" => (() -> expectation(case.observable, case.initial)),
    ]
    append!(operations, repeated_evaluation_operations(case, method; with_zygote=with_zygote))
    return operations
end

function batch_execution_mutating_operations(case)
    operations = Pair{String,Any}["gate_apply" => case.gate]
    !isnothing(case.channel) && push!(operations, "channel_apply" => case.channel)
    return operations
end

function batch_execution_first_mutating!(rows, case, name, operation)
    # Match BenchmarkTools setup: copy/reset is excluded from first-call timing.
    working = copy(case.initial)
    return repeated_evaluation_first!(rows, case, name, () -> apply!(operation, working))
end

function batch_execution_steady_mutating!(rows, case, name, operation, seconds)
    initial = case.initial
    benchmark = @benchmarkable apply!($operation, working) setup=(working=copy($initial)) evals=1
    benchmark.params.seconds = seconds
    trial = run(benchmark)
    estimate = median(trial)
    push!(rows, repeated_evaluation_row("steady_median", case, name;
        time_ns=estimate.time, bytes=estimate.memory, allocations=estimate.allocs,
        gc_time_ns=estimate.gctime, samples=length(trial), evals=trial.params.evals))
    return nothing
end

function batch_execution_check(case, method; with_zygote=false)
    original = copy(storage(case.initial))
    repeated_evaluation_check(case, method; with_zygote=with_zygote)
    sample_values = [evaluate(objective, case.values) for objective in case.reference]
    isapprox(evaluate_batch(case.objective, case.values), sample_values; atol=1e-11) ||
        error("sample value/order mismatch for $(case.name)")
    reference_value = sum(sample_values) / case.batch_count
    value, gradient = value_and_gradient(method, case.objective, case.values)
    isapprox(value, reference_value; atol=1e-11) || error("loop value mismatch")
    reference_gradient = zeros(eltype(case.values), length(case.values))
    for objective in case.reference
        _, sample_gradient = value_and_gradient(method, objective, case.values)
        reference_gradient .+= sample_gradient
    end
    reference_gradient ./= case.batch_count
    isapprox(gradient, reference_gradient; atol=1e-10) || error("loop gradient mismatch")
    scalar_expectations = [expectation(case.observable, sample) for sample in case.singles]
    isapprox(expectation(case.observable, case.initial), scalar_expectations; atol=1e-11) ||
        error("loop expectation mismatch")
    for (_, operation) in batch_execution_mutating_operations(case)
        result = apply!(operation, copy(case.initial))
        for (b, sample) in enumerate(case.singles)
            reference = apply!(operation, copy(sample))
            extracted = result isa BatchStateVector ? StateVector(result, b) : DensityMatrix(result, b)
            isapprox(storage(extracted), storage(reference); atol=1e-11) ||
                error("loop gate/channel mismatch")
        end
        # Output modifications must stay private, including the pure-to-mixed path.
        fill!(storage(result), 0)
        storage(case.initial) == original || error("mutating workload leaked into input")
    end
    storage(case.initial) == original || error("input state changed")
    return nothing
end

function batch_execution_metadata(options)
    metadata = repeated_evaluation_metadata(options)
    metadata["seed"] = BATCH_EXECUTION_SEED
    metadata["script_sha256"] = bytes2hex(sha256(read(@__FILE__)))
    metadata["helper_script"] = "benchmark/repeated_evaluation.jl"
    metadata["helper_script_sha256"] = bytes2hex(sha256(read(joinpath(@__DIR__, "repeated_evaluation.jl"))))
    active_project = Base.active_project()
    active_manifest = isnothing(active_project) ? nothing : joinpath(dirname(active_project), "Manifest.toml")
    metadata["active_project_sha256"] = isnothing(active_project) ? "unavailable" : bytes2hex(sha256(read(active_project)))
    metadata["active_manifest_sha256"] = isnothing(active_manifest) || !isfile(active_manifest) ? "unavailable" : bytes2hex(sha256(read(active_manifest)))
    metadata["batch_counts"] = options[:batches]
    metadata["cases"] = ["pure_unitary", "mixed_unitary", "pure_fixed_noise", "mixed_fixed_noise"]
    metadata["reduction"] = "mean"
    metadata["parameter_sharing"] = "All samples share the entire parameter vector; each layer reuses the same per-qubit Ry/Rz parameters."
    metadata["input_note"] = "Batches use prefixes of one seeded ComplexF64 batch. Mixed states are 0.8|psi><psi| + 0.2I/D. Setup, objective construction, and reference checks are excluded."
    metadata["mutating_note"] = "gate_apply and channel_apply call apply! on a fresh private copy made in BenchmarkTools setup, with evals=1. The input reset/copy is excluded; internal promotion/allocation is included. First-call reset/copy is also excluded."
    metadata["reference_note"] = "Outside timings, compare gates/channels, per-sample expectations/values, and shared-parameter gradients with explicit single-state loops; check finite-difference coordinate, repeated pullback seeds, and private ownership."
    metadata["operation_definitions"] = Dict(
        "gate_apply" => "apply! of one seeded general two-qubit unitary on positions (1,n) to a private initial-state copy; all four cases",
        "channel_apply" => "apply! of one fixed amplitude-damping channel on qubit n to a private initial-state copy; the two fixed-noise cases, including pure-to-mixed allocation",
        "expectation" => "expectation of the shared two-term observable on the initial batch; no circuit execution",
        "evaluate" => "public scalar mean objective, including binding, state copy, forward circuit, and reduction",
        "value_and_gradient" => "public AdjointGradient value and parameter gradient, including forward and reverse work",
        "pullback_prepare" => "public value_and_pullback preparation, including forward execution and private captured state",
        "pullback_apply" => "back(1.0) on a reusable prepared pullback; preparation excluded, reverse work/output allocation included",
        "zygote_gradient" => "optional adapter gradient of differentiable_value(AdjointGradient(), objective, parameters)")
    return metadata
end

function batch_execution_write(rows, metadata, output, cases)
    lookup = Dict(case.name => case for case in cases)
    header = (:phase, :case, :kind, :batch_count, :operation, :parameter_slots,
        :independent_parameters, :time_ns, :bytes, :allocations, :gc_time_ns, :samples, :evals)
    output_rows = [merge(row, (kind=lookup[row.case].kind,
        batch_count=lookup[row.case].batch_count)) for row in rows]
    write_rows = function(io)
        println(io, join(string.(header), '\t'))
        for row in output_rows
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
    return output_rows
end

function batch_execution_main(args=ARGS)
    options = batch_execution_options(args)
    options[:with_zygote] && !isdefined(@__MODULE__, :Zygote) &&
        error("load Zygote before calling main with --with-zygote when using include")
    BLAS.set_num_threads(options[:blas_threads])
    cases = batch_execution_cases(qubits=options[:qubits], depth=options[:depth], batches=options[:batches])
    method = AdjointGradient()
    rows = NamedTuple[]
    if !options[:steady_only]
        for case in cases
            for (name, operation) in batch_execution_mutating_operations(case)
                batch_execution_first_mutating!(rows, case, name, operation)
            end
            for (name, invoke) in batch_execution_operations(case, method; with_zygote=options[:with_zygote])
                result = repeated_evaluation_first!(rows, case, name, invoke)
                if name == "pullback_prepare"
                    _, back = result
                    repeated_evaluation_first!(rows, case, "pullback_apply", () -> back(1.0))
                end
            end
        end
    end
    for case in cases
        batch_execution_check(case, method; with_zygote=options[:with_zygote])
    end
    if !options[:latency_only]
        for case in cases
            for (name, operation) in batch_execution_mutating_operations(case)
                batch_execution_steady_mutating!(rows, case, name, operation, options[:seconds])
            end
            operations = batch_execution_operations(case, method; with_zygote=options[:with_zygote])
            _, back = value_and_pullback(method, case.objective, case.values)
            push!(operations, "pullback_apply" => (() -> back(1.0)))
            for (name, invoke) in operations
                repeated_evaluation_steady!(rows, case, name, invoke, options[:seconds])
            end
        end
    end
    metadata = batch_execution_metadata(options)
    !options[:with_zygote] && (metadata["zygote_loaded"] || metadata["chainrulescore_loaded"]) &&
        error("core batch execution benchmark unexpectedly loaded an AD framework")
    return batch_execution_write(rows, metadata, options[:output], cases)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    batch_execution_main()
end
