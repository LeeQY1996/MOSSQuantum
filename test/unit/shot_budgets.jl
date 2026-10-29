using Random
@testset "Independent pilot allocation and hard shot budgets" begin
    p = prepare_estimation(QCircuit(),QubitsTerm(1=>Z)+100QubitsTerm(1=>X),StateVector(1))
    policy = VarianceAllocation(pilot_shots=16)
    ratios = Float64[]; errors = Float64[]; variances = Float64[]
    for seed in 1:24
        a = estimate(p;shots=2000,allocation=policy,rng=Xoshiro(seed))
        u = estimate(p;shots=2000,rng=Xoshiro(seed))
        @test a.shots==2000 && a.pilot_shots==32 && a.production_shots==1968
        @test sum(g.shots for g in a.groups)==1968
        @test all(g->g.shots>=2,a.groups)
        @test a.variance ≈ sum(g.sample_variance/g.shots for g in a.groups)
        push!(ratios,a.variance/u.variance)
        push!(errors,a.value-1)
        push!(variances,a.variance)
    end
    @test sum(ratios)/length(ratios)<.6
    @test abs(sum(errors)/length(errors))<4sqrt(sum(variances))/length(errors)
    z = prepare_estimation(QCircuit(),2QubitsTerm(),StateVector(1))
    constant = estimate(z;shots=0,allocation=policy)
    @test constant.value==2 && constant.shots==0 && constant.variance==0
    @test_throws ArgumentError estimate(p;shots=35,allocation=policy)
    @test_throws ArgumentError VarianceAllocation(pilot_shots=1)
    b = ShotBudget(4000)
    @test estimate(p;shots=2000,allocation=policy,budget=b).shots==2000
    @test remaining_shots(b)==2000
    @test estimate(p;shots=2000,budget=b).shots==2000
    rng=Xoshiro(1);copyrng=copy(rng)
    @test_throws ShotBudgetExceeded estimate(p;shots=100,budget=b,rng=rng)
    @test rand(rng)==rand(copyrng)
    @test remaining_shots(b)==0
    @test estimate(z;shots=100,budget=b).shots==0
    @test_throws ArgumentError ShotBudget(-1)
    @test_throws ArgumentError ShotBudget(true)
    ep = prepare_execution(QCircuit([HGate(1)]),StateVector(1))
    cap = ShotBudget(100)
    jobs = [Threads.@spawn try
        execute(ep;shots=100,result=:counts,budget=cap,rng=Xoshiro(i)); true
    catch err
        err isa ShotBudgetExceeded || rethrow(); false
    end for i in 1:4]
    @test count(fetch,jobs)==1
    @test remaining_shots(cap)==0
    cap=ShotBudget(199)
    @test_throws ShotBudgetExceeded run_sweep(ep,zeros(0,2);shots=100,budget=cap)
    @test remaining_shots(cap)==199
    a=run_sweep(p,zeros(0,2);shots=100,allocation=policy,budget=ShotBudget(200))
    @test a.results isa Vector{AdaptiveEstimate}
    @test a.shots==200
end

@testset "Gradient budget preflight" begin
    c=QCircuit([RyGate(1,0.;isparas=true)])
    o=ShotExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);shots=100)
    @test required_shots(o)==100
    @test required_shots(ParameterShift(),o,[.3])==300
    @test required_shots(SPSAGradient(directions=4),o,[.3])==900
    b=ShotBudget(299);rng=Xoshiro(1);copyrng=copy(rng)
    @test_throws ShotBudgetExceeded estimate_gradient(ParameterShift(),o,[.3];budget=b,rng=rng)
    @test remaining_shots(b)==299 && rand(rng)==rand(copyrng)
    b=ShotBudget(300)
    g=estimate_gradient(ParameterShift(),o,[.3];budget=b,rng=Xoshiro(1))
    @test g.shots==300 && remaining_shots(b)==0
    adaptive=ShotExpectationObjective(c,QubitsTerm(1=>Z)+.3QubitsTerm(1=>X),StateVector(1);
        shots=100,allocation=VarianceAllocation(pilot_shots=8))
    g=estimate_gradient(ParameterShift(),adaptive,[.3];budget=ShotBudget(300),rng=Xoshiro(2))
    @test g.shots==300 && isfinite(g.gradient[1])
end
