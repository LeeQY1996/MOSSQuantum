using MOSSQuantum, LinearAlgebra, Random, Statistics, TOML, SHA
push!(LOAD_PATH, dirname(dirname(pathof(MOSSQuantum))))

module BaselineCPU
include(joinpath(ARGS[2], "MOSSQuantum.jl"))
end

function paired_circuit(api, n, depth, angles; cnots_only=false)
    circuit = api.QCircuit()
    rotations = (api.RxGate, api.RyGate, api.RzGate)
    for layer in 1:depth
        if !cnots_only
            for qubit in 1:n
                push!(circuit, rotations[mod1(layer + qubit, 3)](qubit, angles[qubit, layer]))
            end
        end
        for qubit in 1:n-1
            push!(circuit, api.CNOTGate(qubit, qubit + 1))
        end
    end
    @assert length(circuit) == depth * (cnots_only ? n - 1 : 2n - 1)
    return circuit
end

function paired_apply(api, circuit, state, raw)
    fill!(api.storage(state), 0)
    api.storage(state)[1] = 1
    return @elapsed if raw
        for gate in circuit
            api.apply_threaded!(gate, api.storage(state))
        end
    else
        result = api.apply!(circuit, state)
        @assert result === state
    end
end

function paired_main()
    length(ARGS) == 2 || error("usage: paired_dispatch.jl OUTPUT.toml BASELINE_SRC")
    BLAS.set_num_threads(1)
    affinity() = only(filter(line -> startswith(line, "Cpus_allowed_list:"), readlines("/proc/self/status")))
    before = affinity()
    report = Dict{String,Any}("measurement" => "old and new modules in one process, one shared state buffer, alternating order",
        "threads" => Threads.nthreads(), "affinity_before" => before, "cases" => Any[])
    old, new = BaselineCPU.MOSSQuantum, MOSSQuantum
    for n in (15, 20, 25)
        depth = n == 25 ? 10 : 20
        rng = MersenneTwister(46113 + n)
        angles = 2π .* rand(rng, n, depth) .- π
        for raw in (n == 15 ? (false, true) : (false,))
            circuits = [paired_circuit(api, n, depth, angles; cnots_only=raw) for api in (old, new)]
            shared = zeros(ComplexF64, 1 << n)
            states = [api.StateVector(shared; copy=false, preserve_storage=true) for api in (old, new)]
            @assert old.storage(states[1]) === new.storage(states[2]) === shared
            paired_apply(old, circuits[1], states[1], raw)
            reference = copy(shared)
            for i in 1:2
                paired_apply((old, new)[i], circuits[i], states[i], raw)
                @assert norm(shared - reference) < 1e-10
            end
            seconds = [Float64[], Float64[]]
            maximum_l2_error = 0.0
            for repetition in 1:7
                GC.gc()
                for i in (isodd(repetition) ? (1, 2) : (2, 1))
                    push!(seconds[i], paired_apply((old, new)[i], circuits[i], states[i], raw))
                    error = norm(shared - reference)
                    @assert error < 1e-10
                    maximum_l2_error = max(maximum_l2_error, error)
                end
            end
            @assert abs(norm(shared)^2 - 1) < 1e-8
            case = Dict("qubits" => n, "depth" => depth, "kind" => raw ? "cnots_raw" : "public",
                "before_seconds" => seconds[1], "after_seconds" => seconds[2],
                "before_median_seconds" => median(seconds[1]), "after_median_seconds" => median(seconds[2]),
                "l2_error" => maximum_l2_error)
            push!(report["cases"], case)
            println("n=$n depth=$depth kind=", case["kind"], " before=", median(seconds[1]),
                " after=", median(seconds[2]), " L2=", maximum_l2_error)
            flush(stdout)
        end
    end
    report["affinity_after"] = affinity()
    @assert before == report["affinity_after"]
    report["complete"] = true
    open(ARGS[1], "w") do io
        TOML.print(io, report; sorted=true)
    end
end

paired_main()
