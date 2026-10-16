using BenchmarkTools
using LinearAlgebra
using MOSS
using Random
using Zygote

"""Generate a deterministic unitary outside the timed workload."""
function benchmark_gate(rng, positions)
    dimension = 1 << length(positions)
    unitary = Matrix(qr(randn(rng, ComplexF64, dimension, dimension)).Q)
    return QuantumGate(positions, unitary)
end

function benchmark_circuit(nqubits, depth; noisy=false)
    circuit = QCircuit()
    for layer in 1:depth
        for position in 1:nqubits
            push!(circuit, RyGate(position, 0.1 * (layer + position); isparas=true))
            push!(circuit, RzGate(position, 0.07 * (layer - position); isparas=true))
        end
        for position in 1:(nqubits - 1)
            push!(circuit, CNOTGate(position, position + 1))
        end
        if noisy
            for position in 1:nqubits
                push!(circuit, Depolarizing(position; p=0.05))
            end
        end
    end
    return circuit
end

function circuit_gradient(circuit, observable, initial_state)
    loss(c) = real(expectation(observable, c * initial_state))
    return Zygote.gradient(loss, circuit)[1]
end

"""
Build workloads without running them. Each mutating benchmark gets an independent
state in setup, outside the timed expression, and uses exactly one evaluation.
"""
function build_suite(; state_qubits=12, noise_qubits=6, gradient_qubits=6)
    state_qubits >= 9 || throw(ArgumentError("state_qubits must be at least 9"))
    noise_qubits >= 2 || throw(ArgumentError("noise_qubits must be at least 2"))
    gradient_qubits >= 2 || throw(ArgumentError("gradient_qubits must be at least 2"))
    rng = MersenneTwister(20261016)
    suite = BenchmarkGroup()
    first_calls = Pair{String, Function}[]

    state = normalize!(StateVector(randn(rng, ComplexF64, 1 << state_qubits)))
    suite["gates"] = BenchmarkGroup()
    for arity in 1:5
        group = suite["gates"]["$(arity)_qubit"] = BenchmarkGroup()
        # The one-to-three-qubit and four-to-five-qubit dispatcher families are
        # both covered, with adjacent and separated/high-index positions.
        adjacent = ntuple(i -> i, arity)
        separated = arity == 1 ? (state_qubits,) :
            Tuple(round.(Int, range(1, stop=state_qubits, length=arity)))
        for (label, positions) in (("adjacent", adjacent), ("separated", separated))
            operation = benchmark_gate(rng, positions)
            group[label] = @benchmarkable apply!($operation, input) setup=(input=copy($state)) evals=1
            let operation=operation, input=copy(state)
                push!(first_calls, "gate/$(arity)/$label" => (() -> apply!(operation, input)))
            end
        end
    end

    suite["batch"] = BenchmarkGroup()
    for size in (1, 4, 16)
        group = suite["batch"]["size_$size"] = BenchmarkGroup()
        batch = normalize!(BatchStateVector(randn(rng, ComplexF64, 1 << state_qubits, size)))
        for arity in 1:5
            positions = ntuple(i -> 2 * i - 1, arity)
            operation = benchmark_gate(rng, positions)
            group["$(arity)_qubit"] = @benchmarkable apply!($operation, input) setup=(input=copy($batch)) evals=1
            let operation=operation, input=copy(batch)
                push!(first_calls, "batch/$size/gate/$arity" => (() -> apply!(operation, input)))
            end
        end
    end

    suite["noise"] = BenchmarkGroup()
    density = DensityMatrix(normalize!(StateVector(randn(rng, ComplexF64, 1 << noise_qubits))))
    channel = AmplitudeDamping(noise_qubits; γ=0.15)
    noisy_circuit = benchmark_circuit(noise_qubits, 2; noisy=true)
    suite["noise"]["channel"] = @benchmarkable apply!($channel, input) setup=(input=copy($density)) evals=1
    suite["noise"]["circuit"] = @benchmarkable apply!($noisy_circuit, input) setup=(input=copy($density)) evals=1
    let input=copy(density)
        push!(first_calls, "noise/channel" => (() -> apply!(channel, input)))
    end
    let input=copy(density)
        push!(first_calls, "noise/circuit" => (() -> apply!(noisy_circuit, input)))
    end

    suite["expectation"] = BenchmarkGroup()
    observable = QubitsTerm(1 => "X", noise_qubits => "X") +
                 QubitsTerm(1 => "Z"; coeff=0.5)
    expectation_batch = normalize!(BatchStateVector(randn(rng, ComplexF64, 1 << state_qubits, 16)))
    for (label, input) in (("state_vector", state), ("density_matrix", density), ("batch", expectation_batch))
        suite["expectation"][label] = @benchmarkable expectation($observable, $input) evals=1
        let input=input
            push!(first_calls, "expectation/$label" => (() -> expectation(observable, input)))
        end
    end

    suite["gradient"] = BenchmarkGroup()
    gradient_observable = QubitsTerm(1 => "Z") +
                          QubitsTerm(1 => "X", gradient_qubits => "X"; coeff=0.5)
    pure_initial = qstate(gradient_qubits)
    mixed_initial = DensityMatrix(pure_initial)
    for (label, noisy, input) in (("unitary", false, pure_initial), ("noisy", true, mixed_initial))
        circuit = benchmark_circuit(gradient_qubits, 2; noisy=noisy)
        # circuit * input copies the state internally. This allocation belongs
        # to the public differentiated workflow and remains in the measurement.
        suite["gradient"][label] = @benchmarkable circuit_gradient($circuit, $gradient_observable, $input) evals=1
        let circuit=circuit, input=input
            push!(first_calls, "gradient/$label" => (() -> circuit_gradient(circuit, gradient_observable, input)))
        end
    end
    return suite, first_calls
end

"""Report first calls separately; later cases may reuse earlier compilation."""
function report_first_calls(first_calls)
    println("First invocation timings in this process (compilation included):")
    for (label, invoke) in first_calls
        println(label)
        @time invoke()
    end
end

function main(args=ARGS)
    all(arg -> arg in ("--latency-only", "--steady-only", "--smoke"), args) ||
        throw(ArgumentError("supported flags: --latency-only, --steady-only, --smoke"))
    ("--latency-only" in args && "--steady-only" in args) &&
        throw(ArgumentError("choose either --latency-only or --steady-only"))
    suite, first_calls = build_suite()
    println("Julia ", VERSION, "; threads=", Threads.nthreads(), "; BLAS threads=", BLAS.get_num_threads())
    "--steady-only" in args || report_first_calls(first_calls)
    "--latency-only" in args && return nothing

    println("Warmed BenchmarkTools trials (one evaluation per sample):")
    results = if "--smoke" in args
        run(suite; samples=1, seconds=0.01, verbose=true)
    else
        run(suite; seconds=1, verbose=true)
    end
    show(stdout, MIME("text/plain"), results)
    println()
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
