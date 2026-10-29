using Random, LinearAlgebra

@testset "Exact parameter-shift and independent shared slots" begin
    for construct in (RxGate,RyGate,RzGate,PHASEGate), inverse in (false,true)
        g = construct(1,.0;isparas=true)
        circuit = QCircuit([RyGate(1,.41),inverse ? g' : g,RxGate(1,.28)])
        objective = ExpectationObjective(circuit,QubitsTerm(1=>Z)+.3QubitsTerm(1=>X),StateVector(1))
        x = [.43]
        result = estimate_gradient(ParameterShift(),objective,x)
        value,truth = value_and_gradient(AdjointGradient(),objective,x)
        @test result.value ≈ value
        @test result.gradient ≈ truth atol=1e-12
        @test result.shots==0 && result.evaluations==3
        @test result.stderr == [0]
    end
    for construct in (CRxGate,CRyGate,CRzGate,CPHASEGate), inverse in (false,true)
        g = construct(1,2,.0;isparas=true)
        c = QCircuit([RyGate(1,.71),RyGate(2,.51),g,RxGate(1,.31),RxGate(2,.28)])
        inverse && (c[3]=g')
        h = QubitsTerm(1=>X)+.3QubitsTerm(1=>Y,2=>Z)+.7QubitsTerm(2=>Y)
        objective = ExpectationObjective(c,h,StateVector(2))
        result = estimate_gradient(ParameterShift(),objective,[.43])
        _,truth = value_and_gradient(AdjointGradient(),objective,[.43])
        @test result.gradient ≈ truth atol=1e-12
        @test result.evaluations == (construct==CPHASEGate ? 3 : 5)
    end
    c = QCircuit([RyGate(1,0.;isparas=true),RyGate(1,0.;isparas=true)])
    map = ParameterMap([1,1])
    objective = ExpectationObjective(c,QubitsTerm(1=>Z),StateVector(1);parameter_map=map)
    result = estimate_gradient(ParameterShift(),objective,[.4])
    @test result.gradient[1] ≈ -2sin(.8)
    @test result.evaluations == 5
    @test active_parameters(c) == [0,0]
    @test_throws UnsupportedGradient estimate_gradient(ParameterShift(),x->sum(x),[1.])
    @test_throws ArgumentError FiniteDifference(step=0)
    @test_throws ArgumentError SPSAGradient(directions=0)
    @test_throws DimensionMismatch estimate_gradient(ParameterShift(),objective,[1.,2.])
    @test_throws ArgumentError estimate_gradient(ParameterShift(),objective,[NaN])
    measured = ExpectationObjective(QCircuit([RyGate(1,0.;isparas=true),QMeasure(1)]),QubitsTerm(1=>Z),StateVector(1))
    @test !supports_gradient(ParameterShift(),measured)
    @test !supports_gradient(FiniteDifference(),measured)
end

@testset "Finite shot gradients, budgets and covariance" begin
    c = QCircuit([RyGate(1,0.;isparas=true),Depolarizing(1;p=.1)])
    h = QubitsTerm(1=>Z)
    objective = ShotExpectationObjective(c,h,StateVector(1);shots=600)
    @test supports_gradient(ParameterShift(),objective)
    result = estimate_gradient(ParameterShift(),objective,[.6];rng=Xoshiro(4))
    @test abs(result.gradient[1]+.9sin(.6)) < 6result.stderr[1]
    @test result.shots==1800 && result.evaluations==3
    @test result.sampling_covariance == result.covariance
    @test result.value_variance >= 0
    a = estimate_gradient(ParameterShift(),objective,[.6];rng=Xoshiro(3))
    b = estimate_gradient(ParameterShift(),objective,[.6];rng=Xoshiro(3))
    @test a.gradient == b.gradient && a.value == b.value
    gradients,variances = Float64[],Float64[]
    for seed in 1:25
        r = estimate_gradient(ParameterShift(),objective,[.6];rng=Xoshiro(seed))
        push!(gradients,r.gradient[1]);push!(variances,r.covariance[1,1])
    end
    mean = sum(gradients)/length(gradients)
    variance = sum(abs2,gradients.-mean)/(length(gradients)-1)
    @test abs(mean+.9sin(.6)) < .03
    @test .3 < variance/(sum(variances)/length(variances)) < 3
    shotfd = estimate_gradient(FiniteDifference(step=.2),objective,[.6];rng=Xoshiro(5))
    @test abs(shotfd.gradient[1]+.9sin(.6)) < 6shotfd.stderr[1]+.01
    @test shotfd.shots == 1800
    shotsp = estimate_gradient(SPSAGradient(step=.2,directions=4),objective,[.6];rng=Xoshiro(8))
    @test shotsp.shots == 5400 && shotsp.evaluations==9
    @test length(shotsp.stderr)==1
    one_direction = estimate_gradient(SPSAGradient(directions=1),objective,[.6];rng=Xoshiro(8))
    @test isnothing(one_direction.stderr) && isnothing(one_direction.covariance)
    @test one_direction.sampling_covariance[1,1] >= 0
    @test_throws ArgumentError ShotExpectationObjective(c,h,StateVector(1);shots=1)
    @test_throws ArgumentError ShotExpectationObjective(c,h,BatchStateVector(1,2);shots=100)
    constant = ShotExpectationObjective(c,QubitsOperator(2),StateVector(1);shots=0)
    r = estimate_gradient(ParameterShift(),constant,[.2])
    @test r.gradient == [0.] && r.shots==0 && r.value==2
    input = [.6]
    value,gradient = value_and_gradient(ParameterShift(),objective,input;rng=Xoshiro(3))
    @test input == [.6] && value == a.value && gradient == a.gradient
    @test active_parameters(objective.template) == [0.]
end

@testset "Numerical strategies and feedback gradients" begin
    f = x->sum(abs2,x)
    r = estimate_gradient(FiniteDifference(step=1e-4),f,[.3,.6])
    @test r.gradient ≈ [.6,1.2] atol=1e-10
    @test r.evaluations==5 && r.shots==0
    r = estimate_gradient(SPSAGradient(step=.1,directions=1000),f,[.3,.6];rng=Xoshiro(9))
    @test norm(r.gradient-[.6,1.2]) < .15
    @test r.sampling_covariance == zeros(2,2)
    @test minimum(eigvals(Symmetric(r.covariance))) >= -1e-12
    circuit = QCircuit([RyGate(1,0.;isparas=true),QMeasure(1;key=:m),Conditional(:m,XGate(2))])
    objective = ShotExpectationObjective(circuit,QubitsTerm(2=>Z),StateVector(2);shots=2000,method=KrausTrajectory())
    r = estimate_gradient(ParameterShift(),objective,[.7];rng=Xoshiro(11))
    @test abs(r.gradient[1]+sin(.7)) < 6r.stderr[1]
    @test r.shots==6000
    flip = ReadoutError(1;p0_to_1=1,p1_to_0=1,scope=:measurement)
    noisy = ShotExpectationObjective(circuit,QubitsTerm(2=>Z),StateVector(2);shots=2000,readout=flip)
    r = estimate_gradient(ParameterShift(),noisy,[.7];rng=Xoshiro(12))
    @test abs(r.gradient[1]-sin(.7)) < 6r.stderr[1]
    # Differentiating an active gate inside a branch must retain flat slot order.
    c = QCircuit([HGate(1),QMeasure(1;key=:m),Conditional(:m,RyGate(2,0.;isparas=true))])
    conditional = ShotExpectationObjective(c,QubitsTerm(2=>Z),StateVector(2);shots=3000)
    r = estimate_gradient(ParameterShift(),conditional,[.7];rng=Xoshiro(21))
    @test abs(r.gradient[1]+.5sin(.7)) < 6r.stderr[1]
end
