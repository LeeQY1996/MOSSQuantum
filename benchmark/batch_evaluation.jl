# Reuse deterministic circuit construction, timing, validation, and environment
# metadata helpers without running or changing the earlier benchmark entrypoint.
include(joinpath(@__DIR__, "repeated_evaluation.jl"))

if abspath(PROGRAM_FILE) == abspath(@__FILE__) && "--with-zygote" in ARGS
    using Zygote
end

const BATCH_EVALUATION_COUNTS = (1, 4, 16)

"""Build batch and per-sample reference objectives outside all measured calls."""
function batch_evaluation_cases(; qubits=6, depth=2)
    rng = MersenneTwister(REPEATED_EVALUATION_SEED)
    initial = rand_batch(rng, ComplexF64, qubits, maximum(BATCH_EVALUATION_COUNTS))
    circuit = repeated_evaluation_circuit(qubits, depth)
    parameter_map = ParameterMap(circuit, repeat(collect(1:(2qubits)), depth))
    observable = QubitsTerm(1 => "Z"; coeff=0.7) +
        QubitsTerm(1 => "X", qubits => "X"; coeff=0.3)
    values = 0.2 .* randn(rng, nparameters(parameter_map))
    return map(BATCH_EVALUATION_COUNTS) do count
        batch = BatchStateVector(storage(initial)[:, 1:count], qubits, count)
        objective = BatchExpectationObjective(circuit, observable, batch;
            parameter_map=parameter_map, reduction=:mean)
        reference = [ExpectationObjective(circuit, observable, StateVector(batch, index);
            parameter_map=parameter_map) for index in 1:count]
        (name="batch_$(count)", objective=objective, reference=reference, values=copy(values))
    end
end

function batch_evaluation_loop_value(case)
    return sum(evaluate(objective, case.values) for objective in case.reference) / length(case.reference)
end

function batch_evaluation_loop_value_and_gradient(case, method)
    value = zero(eltype(case.values))
    gradient = zeros(eltype(case.values), length(case.values))
    for objective in case.reference
        sample_value, sample_gradient = value_and_gradient(method, objective, case.values)
        value += sample_value
        gradient .+= sample_gradient
    end
    count = length(case.reference)
    return value / count, gradient / count
end

function batch_evaluation_operations(case, method; with_zygote=false)
    operations = repeated_evaluation_operations(case, method; with_zygote=with_zygote)
    push!(operations, "loop_evaluate" => (() -> batch_evaluation_loop_value(case)),
        "loop_value_and_gradient" => (() -> batch_evaluation_loop_value_and_gradient(case, method)))
    return operations
end

function batch_evaluation_check(case, method; with_zygote=false)
    repeated_evaluation_check(case, method; with_zygote=with_zygote)
    native_samples = evaluate_batch(case.objective, case.values)
    reference_samples = [evaluate(objective, case.values) for objective in case.reference]
    isapprox(native_samples, reference_samples; atol=1e-11) || error("sample order/value mismatch")
    native_value, native_gradient = value_and_gradient(method, case.objective, case.values)
    reference_value, reference_gradient = batch_evaluation_loop_value_and_gradient(case, method)
    isapprox(native_value, batch_evaluation_loop_value(case); atol=1e-11) || error("loop value mismatch")
    isapprox(native_value, reference_value; atol=1e-11) || error("loop gradient value mismatch")
    isapprox(native_gradient, reference_gradient; atol=1e-10) || error("loop gradient mismatch")
    return nothing
end

function batch_evaluation_metadata(options)
    metadata = repeated_evaluation_metadata(options)
    metadata["script_sha256"] = bytes2hex(sha256(read(@__FILE__)))
    metadata["helper_script"] = "benchmark/repeated_evaluation.jl"
    metadata["helper_script_sha256"] = bytes2hex(sha256(read(joinpath(@__DIR__, "repeated_evaluation.jl"))))
    metadata["batch_counts"] = collect(BATCH_EVALUATION_COUNTS)
    metadata["reduction"] = "mean"
    metadata["parameter_sharing"] = "Each layer reuses the same Ry/Rz pair on each qubit; all samples share the entire parameter vector."
    metadata["input_note"] = "B=1/4/16 use prefixes of the same seeded batch; reference objectives are constructed outside timings."
    metadata["batch_adjoint_note"] = "The public batch adjoint uses one shared batch forward and per-column reverse reconstruction; optional AD and explicit methods reuse the same numerical helpers. This baseline makes no acceleration claim."
    metadata["reference_note"] = "loop_evaluate and loop_value_and_gradient explicitly evaluate prebuilt single-state objectives and average values/gradients."
    return metadata
end

function batch_evaluation_write(rows, metadata, output, cases)
    counts = Dict(case.name => batch_size(case.objective.initial_state) for case in cases)
    output_rows = [merge(row, (batch_count=counts[row.case],)) for row in rows]
    header = (:phase, :case, :batch_count, :operation, :parameter_slots, :independent_parameters,
        :time_ns, :bytes, :allocations, :gc_time_ns, :samples, :evals)
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

function batch_evaluation_main(args=ARGS)
    options = repeated_evaluation_options(args)
    options[:with_zygote] && !isdefined(@__MODULE__, :Zygote) &&
        error("load Zygote before calling main with --with-zygote when using include")
    BLAS.set_num_threads(options[:blas_threads])
    cases = batch_evaluation_cases(qubits=options[:qubits], depth=options[:depth])
    method = AdjointGradient()
    rows = NamedTuple[]
    if !options[:steady_only]
        for case in cases
            for (operation, invoke) in batch_evaluation_operations(case, method;
                    with_zygote=options[:with_zygote])
                result = repeated_evaluation_first!(rows, case, operation, invoke)
                if operation == "pullback_prepare"
                    _, back = result
                    repeated_evaluation_first!(rows, case, "pullback_apply", () -> back(1.0))
                end
            end
        end
    end
    for case in cases
        batch_evaluation_check(case, method; with_zygote=options[:with_zygote])
    end
    if !options[:latency_only]
        for case in cases
            operations = batch_evaluation_operations(case, method; with_zygote=options[:with_zygote])
            _, back = value_and_pullback(method, case.objective, case.values)
            push!(operations, "pullback_apply" => (() -> back(1.0)))
            for (operation, invoke) in operations
                repeated_evaluation_steady!(rows, case, operation, invoke, options[:seconds])
            end
        end
    end
    metadata = batch_evaluation_metadata(options)
    !options[:with_zygote] && (metadata["zygote_loaded"] || metadata["chainrulescore_loaded"]) &&
        error("core batch benchmark unexpectedly loaded Zygote or ChainRulesCore")
    return batch_evaluation_write(rows, metadata, options[:output], cases)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    batch_evaluation_main()
end
