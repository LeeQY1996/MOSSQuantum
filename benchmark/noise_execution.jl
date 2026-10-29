# Run from the root environment. No benchmark-only runtime dependency is needed:
# julia --project=. benchmark/noise_execution.jl /tmp/noise-benchmark.toml
using MOSSQuantum, Random, LinearAlgebra, TOML, SHA, Dates
BLAS.set_num_threads(1)
_median(x) = (s=sort(x); (s[(length(s)+1)÷2]+s[(length(s)+2)÷2])/2)

function measure_case(label, f; repeats=3)
    f() # compile and warm all paths before measurement
    trials = Any[]
    for _ in 1:repeats
        GC.gc()
        push!(trials,@timed f())
    end
    return Dict("case"=>label,"seconds"=>_median([r.time for r in trials]),
        "allocated_bytes"=>Int(_median([r.bytes for r in trials])),
        "retained_result_bytes"=>Base.summarysize(last(trials).value),
        "gc_seconds"=>_median([r.gctime for r in trials]))
end

function main()
    rows = Any[]
    for n in (4,8), noise in (:pauli,:damping)
        circuit = QCircuit()
        for q in 1:n
            push!(circuit,HGate(q))
            push!(circuit,noise === :pauli ? Depolarizing(q;p=.05) : AmplitudeDamping(q;γ=.05))
        end
        initial = StateVector(n)
        for (name,method) in (("density",DensityMatrixEvolution()),("trajectory",KrausTrajectory()))
            for mode in (:full,:counts)
                label = "n=$n/$noise/$name/$mode/shots=1000"
                push!(rows,measure_case(label,()->execute(circuit,initial;shots=1000,
                    method=method,result=mode,rng=Xoshiro(42))))
            end
        end
        push!(rows,measure_case("n=$n/$noise/trajectory/threaded/counts/shots=1000",
            ()->execute(circuit,initial;shots=1000,method=KrausTrajectory(),parallel=true,
                        result=:counts,rng=Xoshiro(42))))
    end
    for mode in (:full,:counts)
        c = QCircuit([HGate(q) for q in 1:8])
        push!(rows,measure_case("n=8/density/$mode/shots=100000",
            ()->execute(c,StateVector(8);shots=100000,result=mode,rng=Xoshiro(42))))
    end
    for b in (1,4)
        c = QCircuit([HGate(1),AmplitudeDamping(1;γ=.2)])
        push!(rows,measure_case("batch=$b/trajectory/counts/shots=1000",
            ()->execute(c,BatchStateVector(4,b);shots=1000,method=KrausTrajectory(),result=:counts,rng=Xoshiro(42))))
    end
    root = dirname(@__DIR__)
    sources = Dict(f=>bytes2hex(sha256(read(joinpath(root,f)))) for f in
        ("src/execution/noisy_execution.jl","src/execution/shot_execution.jl",
         "src/execution/noise_models.jl","src/quantum_circuits/channels/one_qubit.jl"))
    report = Dict("julia"=>string(VERSION),"threads"=>Threads.nthreads(),"blas_threads"=>BLAS.get_num_threads(),
        "cpu"=>Sys.cpu_info()[1].model,"timestamp_utc"=>string(now(UTC)),"source_sha256"=>sources,
        "cases"=>rows,"process_peak_rss_bytes"=>Sys.maxrss(),
        "notes"=>"Warmed medians of 3 trials; allocations are cumulative, retained size is not peak memory. Both methods use the same shots for sampling; this is not a speedup claim at equal observable error. Process RSS includes compilation and all cases.")
    path = isempty(ARGS) ? "/tmp/moss-noise-benchmark.toml" : ARGS[1]
    open(io->TOML.print(io,report),path,"w")
    println("Wrote ",path," (",length(rows)," cases)")
end
main()
