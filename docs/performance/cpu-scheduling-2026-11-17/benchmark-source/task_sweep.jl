include("/home/ubuntu/moss-gpu/MOSSGPU/benchmark/cpu_gap_diagnostics.jl")

# Experimental fixed-task sweep; this override is never installed in production.
@eval MOSSQuantum begin
    const _SCHEDULER_SWEEP_TASKS = Ref(1)
    function _parallel_task_count(total_itr::Int, n_threads::Int, min_work::Int, max_tasks::Int)
        return max(1, min(total_itr, n_threads, Threads.nthreads(), _SCHEDULER_SWEEP_TASKS[]))
    end
end

function sweep_main()
    Threads.nthreads() == 16 || error("run this controlled sweep with 16 Julia threads")
    BLAS.set_num_threads(1)
    affinity() = only(filter(line -> startswith(line, "Cpus_allowed_list:"), readlines("/proc/self/status")))
    report = Dict{String,Any}("measurement" => "fixed actual task counts; diagnostic override only",
        "affinity_before" => affinity(), "cases" => Any[])
    for n in (15, 20, 25)
        depth = n == 25 ? 2 : 20
        circuit, _ = cpu_scan_circuit(n, depth)
        state = StateVector(n)
        for (kind, gates) in (("rotations", [g for g in circuit if !(g isa CNOTGate)]),
                              ("cnots", [g for g in circuit if g isa CNOTGate]))
            for tasks in (n == 25 ? (4, 8, 16) : (1, 2, 4, 8, 16))
                MOSSQuantum._SCHEDULER_SWEEP_TASKS[] = tasks
                entry = diagnostic_samples!(s -> raw_apply!(gates, s), state; repetitions=5)
                entry["qubits"], entry["depth"], entry["kind"], entry["tasks"] = n, depth, kind, tasks
                push!(report["cases"], entry)
                println("n=$n depth=$depth kind=$kind tasks=$tasks median=", entry["median_seconds"])
                flush(stdout)
            end
        end
    end
    report["affinity_after"] = affinity()
    @assert report["affinity_before"] == report["affinity_after"]
    report["complete"] = true
    open(ARGS[1], "w") do io
        TOML.print(io, report; sorted=true)
    end
end

sweep_main()
