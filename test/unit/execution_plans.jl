using Random, LinearAlgebra
@testset "Execution plans snapshot and bind" begin
    for method in (DensityMatrixEvolution(),KrausTrajectory())
        c = QCircuit([RyGate(1,0.;isparas=true),CNOTGate(1,2),AmplitudeDamping(1;γ=.12)])
        initial = StateVector(2)
        plan = prepare_execution(c,initial;method=method,qubits=[2,1])
        bound = bind_execution(plan,[.7])
        reference = execute(bind_parameters(c,[.7]),initial;shots=600,qubits=[2,1],method=method,result=:counts,rng=Xoshiro(11))
        actual = execute(bound;shots=600,result=:counts,rng=Xoshiro(11))
        @test actual.counts == reference.counts
        @test actual.accepted == reference.accepted
        @test bound.parameters == [.7]
        @test active_parameters(c)==[0]
        work = ExecutionWorkspace(bound)
        @test execute(bound;shots=600,result=:counts,rng=Xoshiro(11),workspace=work).counts == actual.counts
        tasks = [Threads.@spawn execute(bound;shots=600,result=:counts,rng=Xoshiro(11),workspace=work) for _ in 1:3]
        @test all(t->fetch(t).counts==actual.counts,tasks)
        @test_throws ArgumentError execute(bind_execution(plan,[.7]);shots=2,workspace=work)
        push!(c,XGate(1)); storage(initial) .= [0,0,0,1]
        @test execute(bound;shots=600,result=:counts,rng=Xoshiro(11)).counts == actual.counts
        @test_throws DimensionMismatch bind_execution(plan,[.3,.4])
        @test_throws ArgumentError bind_execution(plan,[NaN])
        @test execute(bound;shots=0).shots==0
    end
    c = QCircuit([RyGate(1,0.;isparas=true),RyGate(1,0.;isparas=true)])
    p = prepare_execution(c,StateVector(1);parameter_map=ParameterMap([1,1]))
    @test bind_execution(p,[.3]).distribution ≈ [cos(.3)^2,sin(.3)^2]
    global _plan_noise_calls = 0
    model = NoiseModel(rules=[NoiseRule(g->g isa RyGate,g->(global _plan_noise_calls+=1;Depolarizing(1;p=.1)))])
    p = prepare_execution(c,StateVector(1);noise_model=model)
    before = _plan_noise_calls
    for angle in (.1,.2,.3)
        execute(p,[angle,angle];shots=10)
    end
    @test before==2 && _plan_noise_calls==before
    @test_throws UnsupportedOperation prepare_execution(c,BatchStateVector(1,2))
    @test_throws UnsupportedOperation prepare_execution(c,DensityMatrix(1);method=KrausTrajectory())
end

@testset "Prepared feedback, post-selection and readout" begin
    c = QCircuit([HGate(1),QMeasure(1;key=:m,auto_reset=false),
                  Conditional(:m,QCircuit([RyGate(2,0.;isparas=true),Depolarizing(2;p=.1)]);otherwise=XGate(2)),
                  QSelect(2,0)])
    for method in (DensityMatrixEvolution(),KrausTrajectory())
        error = ReadoutError(1,[0.0 1;1 0];scope=:measurement)
        p = prepare_execution(c,StateVector(2);method=method,readout=error)
        b = bind_execution(p,[.8])
        r = execute(b;shots=400,rng=Xoshiro(42))
        direct = execute(bind_parameters(c,[.8]),StateVector(2);shots=400,method=method,readout=error,rng=Xoshiro(42))
        @test r.counts==direct.counts
        @test r.accepted==direct.accepted
        @test r.classical==direct.classical
        @test all(reg->reg[:m]!=reg.physical[:m],r.classical)
        if method isa KrausTrajectory
            threaded = execute(b;shots=400,rng=Xoshiro(42),parallel=true,chunk_size=7)
            @test r.counts==threaded.counts
            @test r.classical==threaded.classical
        end
    end
    @test_throws ArgumentError prepare_execution(QCircuit([Conditional(:missing,XGate(1))]),StateVector(1))
    @test_throws ArgumentError prepare_estimation(c,QubitsTerm(1=>Z),StateVector(2))
end

@testset "Prepared estimation and ordered sweeps" begin
    c = QCircuit([RyGate(1,0.;isparas=true),Depolarizing(1;p=.1)])
    h = QubitsTerm(1=>Z)+.3QubitsTerm(1=>X)
    plan = prepare_estimation(c,h,StateVector(1))
    angles = reshape(collect(range(.1,1.;length=8)),1,:)
    a = run_sweep(plan,angles;shots=2000,rng=Xoshiro(3))
    b = run_sweep(plan,angles;shots=2000,rng=Xoshiro(3),parallel=true)
    @test a.parameters==angles
    @test a.shots==16000 && a.evaluations==8
    @test [r.value for r in a.results]==[r.value for r in b.results]
    @test [r.variance for r in a.results]==[r.variance for r in b.results]
    for (x,r) in zip(vec(angles),a.results)
        @test abs(r.value-.9*(cos(x)+.3sin(x))) < 6r.stderr+.005
        @test r.shots==2000
    end
    ep = prepare_execution(c,StateVector(1))
    full = run_sweep(ep,angles;shots=20,result=:full,rng=Xoshiro(1))
    counts = run_sweep(ep,angles;shots=20,result=:counts,rng=Xoshiro(1),parallel=true)
    @test [r.counts for r in full.results]==[r.counts for r in counts.results]
    @test full.results isa Vector{ShotResult}
    @test counts.results isa Vector{CountsResult}
    angles[1]=9
    @test a.parameters[1]==.1
    @test isempty(run_sweep(plan,zeros(1,0);shots=10).results)
    @test run_sweep(plan,zeros(1,0);shots=10).shots==0
    @test_throws DimensionMismatch run_sweep(plan,zeros(2,0);shots=10)
    rng = Xoshiro(10); untouched = copy(rng)
    @test_throws ArgumentError run_sweep(plan,reshape([.2,NaN],1,2);shots=10,rng=rng)
    @test rand(rng)==rand(untouched)
    feedback = QCircuit([RyGate(1,0.;isparas=true),QMeasure(1;key=:m,auto_reset=false),Conditional(:m,XGate(2))])
    fp = prepare_estimation(feedback,QubitsTerm(2=>Z),StateVector(2);method=KrausTrajectory())
    @test abs(estimate(fp,[.7];shots=5000,rng=Xoshiro(7)).value-cos(.7))<.06
end
