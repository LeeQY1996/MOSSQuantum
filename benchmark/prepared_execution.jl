using MOSSQuantum, Random, LinearAlgebra, TOML, SHA
BLAS.set_num_threads(1)
function trial(label, f)
    f()
    rows = [(@timed f()) for _ in 1:5]
    return Dict("case"=>label,"seconds"=>sort([r.time for r in rows])[3],
                "bytes"=>sort([r.bytes for r in rows])[3])
end
function main()
    baseline = "--baseline" in ARGS
    c = QCircuit([HGate(1),CNOTGate(1,2),AmplitudeDamping(1;γ=.08)])
    d = QCircuit([HGate(1),QMeasure(1;key=:m,auto_reset=false),Conditional(:m,XGate(2)),Depolarizing(2;p=.03)])
    v = QCircuit([RyGate(1,0.;isparas=true),RyGate(2,0.;isparas=true),CNOTGate(1,2),Depolarizing(1;p=.03)])
    state = StateVector(4)
    h = QubitsTerm(1=>Z)+.2QubitsTerm(2=>X)
    xs = [[x,.3] for x in range(.1,1.;length=16)]
    rows = Any[]
    for (label,circuit,method) in (("fixed_density",c,DensityMatrixEvolution()),("feedback_trajectory",d,KrausTrajectory()))
        direct = ()->[execute(circuit,state;shots=200,method=method,result=:counts,rng=Xoshiro(i)) for i in 1:12]
        push!(rows,trial(label*"/direct",direct))
        if !baseline
            push!(rows,trial(label*"/prepare",()->prepare_execution(circuit,state;method=method)))
            prepared_plan = prepare_execution(circuit,state;method=method)
            push!(rows,trial(label*"/bind",()->bind_execution(prepared_plan,Float64[])))
            bound = bind_execution(prepared_plan,Float64[])
            work = ExecutionWorkspace(bound)
            push!(rows,trial(label*"/prepared",()->[execute(bound;shots=200,result=:counts,rng=Xoshiro(i),workspace=work) for i in 1:12]))
        end
    end
    push!(rows,trial("parameter_scan/direct",()->[estimate(h,bind_parameters(v,x),state;shots=200,rng=Xoshiro(i)) for (i,x) in enumerate(xs)]))
    if !baseline
        plan = prepare_estimation(v,h,state)
        matrix = hcat(xs...)
        push!(rows,trial("parameter_scan/sweep_serial",()->run_sweep(plan,matrix;shots=200,rng=Xoshiro(42))))
        push!(rows,trial("parameter_scan/sweep_threaded",()->run_sweep(plan,matrix;shots=200,rng=Xoshiro(42),parallel=true)))
        push!(rows,trial("parameter_scan/prepared",()->[estimate(plan,x;shots=200,rng=Xoshiro(i)) for (i,x) in enumerate(xs)]))
    end
    direct_gradient = function(x,seed)
        rng = Xoshiro(seed)
        f = y -> estimate(h,bind_parameters(v,y),state;shots=200,rng=rng).value
        value = f(x)
        gradient = zeros(2)
        for j in 1:2
            plus,minus = copy(x),copy(x)
            plus[j] += pi/2; minus[j] -= pi/2
            gradient[j] = (f(plus)-f(minus))/2
        end
        return value,gradient
    end
    push!(rows,trial("vqe_gradient/direct",()->[direct_gradient(x,i) for (i,x) in enumerate(xs)]))
    if !baseline
        objective = ShotExpectationObjective(v,h,state;shots=200)
        push!(rows,trial("vqe_gradient/prepared",()->[estimate_gradient(ParameterShift(),objective,x;rng=Xoshiro(i)) for (i,x) in enumerate(xs)]))
        push!(rows,trial("parameter_scan/prepare",()->prepare_estimation(v,h,state)))
    end
    report=Dict("julia"=>string(VERSION),"threads"=>Threads.nthreads(),"blas_threads"=>BLAS.get_num_threads(),
        "cpu"=>Sys.cpu_info()[1].model,"cases"=>rows,
        "source_sha256"=>Dict(f=>bytes2hex(sha256(read(joinpath(@__DIR__,"..",f)))) for f in
            ("src/execution/execution_plans.jl","src/execution/noisy_execution.jl",
             "src/observables/estimation_plans.jl","src/differentiation/sampled_gradients.jl")),"notes"=>"Median of 5 warmed trials; construction excluded from prepared rows; allocations are cumulative, not peak memory.")
    path=first(filter(x->x!="--baseline",ARGS))
    open(io->TOML.print(io,report),path,"w")
    println(path)
end
main()
