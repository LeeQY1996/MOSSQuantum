using Random, LinearAlgebra

@testset "Mixed parameters share independent coordinates across gradient methods" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    circuit = QCircuit([RyGate(1,.17;isparas=true),RyGate(1,2θ+φ+.1),
                        RyGate(1,θ),RyGate(1,.2)])
    compiled = compile_parameters(circuit)
    a = first(parameter_order(compiled))
    x = [.31,.23,-.14]
    angle = x[1]+3x[2]+x[3]+.3
    expected = -sin(angle).*[1,3,1]
    objective = ExpectationObjective(compiled,QubitsTerm(1=>Z),StateVector(1))
    @test parameter_order(objective)==[a,θ,φ]
    @test initial_parameters(objective;values=Dict(θ=>x[2],φ=>x[3]))==[.17,x[2],x[3]]
    for method in (AdjointGradient(),ParameterShift(),FiniteDifference(step=1e-5))
        value,gradient = value_and_gradient(method,objective,x)
        @test value ≈ cos(angle)
        @test gradient ≈ expected atol=1e-8
    end
    # One SPSA direction differentiates along that direction, in input space.
    rng = Xoshiro(82)
    probe = copy(rng)
    direction = [rand(probe,Bool) ? 1.0 : -1.0 for _ in x]
    result = estimate_gradient(SPSAGradient(step=1e-5,directions=1),objective,x;rng)
    @test result.gradient ≈ direction.*dot(expected,direction) atol=1e-8

    updated = x .+ [.19,0,0]
    @test evaluate(objective,updated) ≈ cos(angle+.19)
    @test evaluate(objective,x) ≈ cos(angle)
    @test initial_parameters(objective;values=Dict(θ=>x[2],φ=>x[3]))[1]==.17
    @test_throws DimensionMismatch evaluate(objective,x[2:end])

    reordered = compile_parameters(compiled;parameter_order=[φ,a,θ])
    reordered_objective = ExpectationObjective(reordered,QubitsTerm(1=>Z),StateVector(1))
    @test first(value_and_gradient(AdjointGradient(),reordered_objective,x[[3,1,2]])) ≈ cos(angle)
    @test last(value_and_gradient(AdjointGradient(),reordered_objective,x[[3,1,2]])) ≈ expected[[3,1,2]]
    @test independent_parameters(reordered_objective)==[φ,a,θ]
end

@testset "Mixed shot gradients propagate occurrence covariance" begin
    θ,φ = Parameter(:θ),Parameter(:φ)
    circuit = QCircuit([RyGate(1,.17;isparas=true),RyGate(1,2θ+φ+.1),RyGate(1,θ),RyGate(1,.2)])
    compiled = compile_parameters(circuit)
    a = first(parameter_order(compiled))
    shot = ShotExpectationObjective(compiled,QubitsTerm(1=>Z),StateVector(1);shots=1800)
    x = [.31,.23,-.14]
    @test parameter_order(shot)==[a,θ,φ]
    @test initial_parameters(shot;values=Dict(θ=>.23,φ=>-.14))==[.17,.23,-.14]
    @test [i.parameter for i in parameter_info(shot)]==independent_parameters(compiled)
    @test required_shots(ParameterShift(),shot,x)==7*1800
    result = estimate_gradient(ParameterShift(),shot,x;rng=Xoshiro(35))
    expected = -sin(x[1]+3x[2]+x[3]+.3).*[1,3,1]
    @test all(abs.(result.gradient.-expected).<6result.stderr)
    @test result.evaluations==7 && result.shots==12600
    covariance = result.sampling_covariance
    @test covariance[2,3] ≈ 2covariance[3,3]
    @test covariance[2,2]>4covariance[3,3]>0
    @test covariance[1,2]==covariance[1,3]==0
    @test covariance ≈ covariance'
    for method in (FiniteDifference(step=.05),SPSAGradient(step=.05,directions=3))
        estimate = estimate_gradient(method,shot,x;rng=Xoshiro(26))
        @test length(estimate.gradient)==3
        @test all(isfinite,estimate.gradient)
        @test estimate.shots==required_shots(method,shot,x)
    end
end

@testset "Compiled mixed contexts preserve identities in prepared plans" begin
    θ = Parameter(:θ)
    source = QCircuit([RyGate(1,.13;isparas=true),QCircuit([RyGate(1,2θ+.1)]),
                       RyGate(1,.2),Depolarizing(1;p=.08)])
    compiled = compile_parameters(source)
    a = first(parameter_order(compiled))
    x = [.44,.21]
    bound = bind_parameters(compiled,x)
    observable = QubitsTerm(1=>Z)+.3QubitsTerm(1=>X)
    for method in (DensityMatrixEvolution(),KrausTrajectory())
        execution = prepare_execution(compiled,StateVector(1);method)
        estimation = prepare_estimation(compiled,observable,StateVector(1);method)
        shot = ShotExpectationObjective(compiled,observable,StateVector(1);shots=400,method)
        for object in (execution,estimation,shot)
            @test parameter_order(object)==[a,θ]
            @test initial_parameters(object;values=Dict(θ=>x[2]))==[.13,x[2]]
            @test [i.parameter for i in parameter_info(object)]==[a,θ]
        end
        @test execute(execution,x;shots=400,result=:counts,rng=Xoshiro(17)).counts ==
              execute(bound,StateVector(1);shots=400,result=:counts,method,rng=Xoshiro(17)).counts
        @test estimate(estimation,x;shots=400,rng=Xoshiro(19)).value == estimate(shot,x;rng=Xoshiro(19)).value
        xs = hcat(x,x.+[.2,0],x.+[0,.1])
        for plan in (execution,estimation)
            serial = run_sweep(plan,xs;shots=100,rng=Xoshiro(12))
            threaded = run_sweep(plan,xs;shots=100,rng=Xoshiro(12),parallel=true)
            @test serial.parameters==xs && serial.shots==300
            if plan isa ExecutionPlan
                @test [r.counts for r in serial.results]==[r.counts for r in threaded.results]
            else
                @test [r.value for r in serial.results]==[r.value for r in threaded.results]
            end
        end
        frozen = prepare_execution(compiled,StateVector(1);fixed=Dict(a=>x[1]),method)
        @test parameter_order(frozen)==[θ]
        @test initial_parameters(frozen;values=Dict(θ=>x[2]))==[x[2]]
        @test execute(frozen,[x[2]];shots=100,result=:counts,rng=Xoshiro(20)).counts ==
              execute(execution,x;shots=100,result=:counts,rng=Xoshiro(20)).counts
    end
    fully_fixed = compile_parameters(compiled;fixed=Dict(a=>x[1],θ=>x[2]))
    frozen_plan = prepare_execution(fully_fixed,StateVector(1))
    @test isempty(initial_parameters(frozen_plan))
    @test isempty(parameter_order(frozen_plan))
    @test execute(frozen_plan;shots=10).shots==10
    @test length(run_sweep(frozen_plan,zeros(0,2);shots=10).results)==2
end

@testset "Mixed prepared feedback and frozen noise boundaries" begin
    θ = Parameter(:θ)
    circuit = QCircuit([HGate(1),QMeasure(1;key=:m,auto_reset=false),
        Conditional(:m,QCircuit([RyGate(2,.1;isparas=true),RyGate(2,θ)]);
            otherwise=QCircuit([RyGate(2,.2;isparas=true),RyGate(2,-θ/2)]))])
    compiled = compile_parameters(circuit)
    @test parameter_order(compiled)[2]==θ
    point = [.3,.6,.4]
    plan = prepare_execution(compiled,StateVector(2);method=KrausTrajectory())
    actual = execute(plan,point;shots=300,rng=Xoshiro(75))
    expected = execute(bind_parameters(compiled,point),StateVector(2);shots=300,method=KrausTrajectory(),rng=Xoshiro(75))
    @test actual.counts==expected.counts
    @test actual.classical==expected.classical

    simple = QCircuit([RyGate(1,.1;isparas=true),RyGate(1,θ)])
    compiled = compile_parameters(simple)
    model = NoiseModel(rules=[NoiseRule(RyGate,BitFlip(1;p=.1))])
    raw_plan = prepare_execution(simple,StateVector(1);noise_model=model)
    @test initial_parameters(raw_plan;values=Dict(θ=>.3))==[.1,.3]
    @test execute(raw_plan,[.2,.3];shots=50).shots==50
    @test_throws ArgumentError prepare_execution(compiled,StateVector(1);noise_model=model)
    @test_throws ArgumentError ShotExpectationObjective(compiled,QubitsTerm(1=>Z),StateVector(1);shots=50,noise_model=model)
    numeric = compile_parameters(QCircuit([RyGate(1,.1;isparas=true)]))
    @test_throws ArgumentError prepare_execution(numeric,StateVector(1);noise_model=model)
    @test_throws ArgumentError ShotExpectationObjective(numeric,QubitsTerm(1=>Z),StateVector(1);shots=50,noise_model=model)
    error = ReadoutError(1,[.97 .03;.08 .92])
    with_readout = prepare_execution(compiled,StateVector(1);readout=error)
    @test parameter_order(with_readout)==parameter_order(compiled)
    nested = compile_parameters(QCircuit([simple]))
    direct_readout = prepare_execution(nested,StateVector(1);readout=error)
    model_readout = prepare_execution(nested,StateVector(1);noise_model=NoiseModel(readout=error))
    @test parameter_order(model_readout)==parameter_order(nested)
    @test execute(model_readout,[.2,.3];shots=100,result=:counts,rng=Xoshiro(57)).counts ==
          execute(direct_readout,[.2,.3];shots=100,result=:counts,rng=Xoshiro(57)).counts
end
