using MOSS, LinearAlgebra, Random, Profile
BLAS.set_num_threads(1)

function profile_case(n, B)
    rng = MersenneTwister(20261020)
    pure = rand_batch(rng, n, B)
    d = 1 << n
    data = storage(BatchDensityMatrix(pure))
    for b in 1:B
        data[:, :, b] .*= 0.8
        for i in 1:d
            data[i, i, b] += 0.2 / d
        end
    end
    state = BatchDensityMatrix(data)
    template = QCircuit()
    for layer in 1:2
        for q in 1:n
            push!(template, RyGate(q, 0.0; isparas=true))
            push!(template, RzGate(q, 0.0; isparas=true))
        end
        for q in 1:n-1
            push!(template, CNOTGate(q, q+1))
        end
    end
    observable = QubitsTerm(1 => "Z"; coeff=0.7) + QubitsTerm(1 => "X", n => "X"; coeff=0.3)
    objective = BatchExpectationObjective(template, observable, state;
        parameter_map=ParameterMap(template, repeat(collect(1:2n), 2)))
    theta = 0.2 .* randn(rng, 2n)
    gate = RyGate(1, 0.3)
    channel = AmplitudeDamping(1; γ=0.08)
    calls = ["gate" => (() -> apply!(gate, copy(state))),
             "channel" => (() -> apply!(channel, copy(state))),
             "expectation" => (() -> expectation(observable, state)),
             "evaluate" => (() -> evaluate(objective, theta)),
             "gradient" => (() -> value_and_gradient(AdjointGradient(), objective, theta)),
             "prepare" => (() -> value_and_pullback(AdjointGradient(), objective, theta))]
    _, back = value_and_pullback(AdjointGradient(), objective, theta)
    push!(calls, "pullback" => (() -> back(1.0)))
    for (_, f) in calls
        f()
    end
    for (name, f) in calls
        bytes = minimum([@allocated(f()) for _ in 1:3])
        println("ALLOC\t", n, '\t', B, '\t', name, '\t', bytes)
    end
    if n == 6
        Profile.Allocs.clear()
        Profile.Allocs.@profile sample_rate=1.0 back(1.0)
        results = Profile.Allocs.fetch()
        totals = Dict{String,Tuple{Int,Int}}()
        for allocation in results.allocs
            frames = filter(frame -> occursin("/MOSS/src/", string(frame.file)), allocation.stacktrace)
            isempty(frames) && continue
            frame = first(frames)
            key = string(frame.file, ':', frame.line, ' ', frame.func)
            count, bytes = get(totals, key, (0, 0))
            totals[key] = (count + 1, bytes + allocation.size)
        end
        for (key, (count, bytes)) in first(sort!(collect(totals); by=pair -> -last(pair)[2]), min(12, length(totals)))
            println("PROFILE\t", bytes, '\t', count, '\t', key)
        end
    end
end

profile_case(4, 16)
profile_case(6, 16)
