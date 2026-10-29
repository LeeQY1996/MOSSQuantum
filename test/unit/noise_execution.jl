using Random, LinearAlgebra

@testset "Readout errors and records" begin
    zero = StateVector(2)
    error = ReadoutError(1;p0_to_1=.2,p1_to_0=.4)
    @test readout_probabilities(zero,error;qubits=[1]) ≈ [.8,.2]
    @test probabilities(zero) == [1,0,0,0]
    @test_throws ArgumentError ReadoutError(1,[.8 .1;.2 .8])
    @test_throws ArgumentError ReadoutError(1,[-.1 1.1;.2 .8])
    @test_throws ArgumentError ReadoutError((1,2),Matrix{Float64}(I,4,4);scope=:all)
    @test_throws ArgumentError NoiseModel(readout=[error,error])
    @test_throws ArgumentError execute(QCircuit(),zero;shots=0,readout=ReadoutError(3;p0_to_1=0,p1_to_0=0))
    flip = ReadoutError(1;p0_to_1=1,p1_to_0=1,scope=:all)
    c = QCircuit([XGate(1),QMeasure(1)])
    result = execute(c,zero;shots=20,readout=flip,rng=MersenneTwister(4))
    @test result.counts == Dict("10"=>20) # ideal reset to 0, then flipped report
    @test all(r -> only(r).outcome==1 && only(r).reported_outcome==0,result.measurements)
    selected = execute(QCircuit([XGate(1),QSelect(1,1)]),zero;shots=10,readout=flip)
    @test all(selected.accepted)
    @test selected.counts == Dict("00"=>10)
    @test all(r -> only(r).outcome==1 && only(r).reported_outcome==0,selected.measurements)
    # Correlated readout copies bit 2 into bit 1; sampling a partial register
    # must marginalize the full block instead of dropping the error.
    matrix = zeros(4,4)
    for actual in 0:3
        reported = ((actual>>1)&1)*3
        matrix[actual+1,reported+1] = 1
    end
    correlated = ReadoutError((1,2),matrix)
    initial = apply!(XGate(2),copy(zero))
    @test readout_probabilities(initial,correlated;qubits=[1]) == [0,1]
    @test execute(QCircuit(),initial;shots=10,qubits=[1],readout=correlated).counts == Dict("1"=>10)
    @test execute(QCircuit(),initial;shots=10,qubits=[2,1],readout=correlated).counts == Dict("11"=>10)
    @test readout_probabilities(initial,correlated;qubits=Int[]) == [1]
    snapshot = copy(initial)
    execute(QCircuit(),initial;shots=20,readout=error)
    @test initial == snapshot
end

@testset "Noise rules and explicit idle times" begin
    model = NoiseModel(rules=[NoiseRule(XGate,g->AmplitudeDamping(only(positions(g));γ=1))],
                       readout=ReadoutError(1;p0_to_1=1,p1_to_0=1))
    c = QCircuit([QCircuit([XGate(1)])])
    program = with_noise(c,model)
    @test length(program.circuit) == 2
    @test length(c) == 1
    @test execute(program,StateVector(1);shots=10).counts == Dict("1"=>10)
    @test execute(c,StateVector(1);shots=10,noise_model=model).counts == Dict("1"=>10)
    @test_throws ArgumentError with_noise(program,model)
    @test_throws ArgumentError execute(program,StateVector(1);shots=1,noise_model=model)
    before = NoiseModel(rules=[NoiseRule(XGate,g->ResetChannel(1);when=:before)])
    @test execute(c,StateVector(1);shots=5,noise_model=before).counts == Dict("1"=>5)
    staged = NoiseModel(preparation=ResetChannel(1;state=1),terminal=ResetChannel(1))
    @test execute(QCircuit(),StateVector(1);shots=5,noise_model=staged).counts == Dict("0"=>5)
    timed = NoiseModel(rules=[NoiseRule(Delay,g->ThermalRelaxation(g.position;T1=1,T2=2,duration=g.duration))])
    idle = with_noise(QCircuit([XGate(1),Delay(1;duration=2)]),timed)
    @test probabilities(simulate(idle.circuit,StateVector(1)).state)[2] ≈ exp(-2)
    @test execute(QCircuit([Delay(1;duration=2)]),StateVector(1);shots=2).counts == Dict("0"=>2)
    @test_throws ArgumentError NoiseModel(preparation=QuantumMap(1,[2Matrix{Float64}(I,2,2)]))
    exact = NoiseModel(rules=[NoiseRule(XGate,g->ResetChannel(1);qubits=(1,))])
    @test execute(QCircuit([XGate(2)]),StateVector(2);shots=2,noise_model=exact).counts == Dict("01"=>2)
end

@testset "Independent Kraus trajectories and streaming" begin
    initial = StateVector(2)
    c = QCircuit([HGate(1),CNOTGate(1,2),AmplitudeDamping(1;γ=.35),
                  PhaseDamping(2;γ=.2),PauliChannel((2,1),["II","XY"],[.8,.2])])
    truth = probabilities(simulate(c,initial).state)
    n = 6000
    frequencies = zeros(4)
    for seed in 1:3
        result = execute(c,initial;shots=n÷3,method=KrausTrajectory(),rng=MersenneTwister(seed),result=:counts)
        for (key,count) in result.counts
            index = sum((key[j]=='1') << (j-1) for j in 1:2)+1
            frequencies[index] += count/n
        end
    end
    @test maximum(abs.(frequencies-truth)) < .04
    a = execute(c,initial;shots=100,method=KrausTrajectory(),rng=Xoshiro(42),chunk_size=17)
    b = execute(c,initial;shots=100,method=KrausTrajectory(),rng=Xoshiro(42),parallel=true,chunk_size=9)
    @test a.samples == b.samples
    streamed = execute(c,initial;shots=100,method=KrausTrajectory(),rng=Xoshiro(42),result=:counts,chunk_size=23)
    @test streamed.counts == a.counts
    @test streamed.accepted == 100
    @test initial == StateVector(2)
    for T in (Float32,ComplexF32,ComplexF64)
        s = StateVector(T,1)
        decay = QCircuit([XGate(1),AmplitudeDamping(1;γ=1),QMeasure(1;auto_reset=false)])
        result = execute(decay,s;shots=10,method=KrausTrajectory())
        @test result.counts == Dict("0"=>10)
        @test all(r -> only(r).outcome==0,result.measurements)
    end
    post = QCircuit([HGate(1),AmplitudeDamping(1;γ=.3),QSelect(1,1)])
    selected = execute(post,StateVector(1);shots=1000,method=KrausTrajectory(),rng=Xoshiro(7))
    @test 280 < count(selected.accepted) < 420
    @test selected.counts == Dict("1"=>count(selected.accepted))
    @test length(selected.measurements) == 1000
    @test size(selected.samples,1) == count(selected.accepted)
    @test execute(c,initial;shots=0,method=KrausTrajectory()).shots == 0
    @test_throws UnsupportedOperation execute(c,DensityMatrix(initial);shots=0,method=KrausTrajectory())
    @test_throws ArgumentError execute(QCircuit([QuantumGate(1,2X)]),StateVector(1);shots=0,method=KrausTrajectory())
    @test_throws ArgumentError execute(c,initial;shots=1,result=:unknown)
    @test_throws ArgumentError execute(c,initial;shots=1,method=KrausTrajectory(),chunk_size=0)
    batch = BatchStateVector(2,2)
    results = execute(c,batch;shots=10,method=KrausTrajectory(),result=:counts)
    @test length(results) == 2 && all(r->r.accepted==10,results)
    @test isempty(execute(c,BatchStateVector(2,0);shots=10,method=KrausTrajectory()))
    @test_throws UnsupportedOperation execute(c,BatchDensityMatrix(2,0);shots=0,method=KrausTrajectory())
end

@testset "Noisy expectation statistics" begin
    initial = StateVector(1)
    c = QCircuit([XGate(1),AmplitudeDamping(1;γ=.3)])
    observable = QubitsTerm(1=>Z)
    exact = -.4
    values = Float64[]; variances = Float64[]
    for seed in 1:20
        result = estimate(observable,c,initial;shots=300,method=KrausTrajectory(),rng=MersenneTwister(seed))
        push!(values,result.value);push!(variances,result.variance)
    end
    average = sum(values)/length(values)
    empirical_variance = sum(abs2,values .- average)/(length(values)-1)
    @test abs(average-exact) < .05
    @test .3 < empirical_variance/(sum(variances)/length(variances)) < 3
    flip = ReadoutError(1;p0_to_1=1,p1_to_0=1)
    @test estimate(observable,QCircuit(),initial;shots=100,readout=flip).value == -1
    model = NoiseModel(readout=flip)
    @test estimate(observable,with_noise(QCircuit(),model),initial;shots=100).value == -1
    @test_throws ArgumentError estimate(observable,QCircuit([QSelect(1,0)]),initial;shots=10,method=KrausTrajectory())
    group = only(measurement_plan(2QubitsTerm(1=>Z)+QubitsTerm(2=>Z)).groups)
    samples = [0 0;0 0;1 1;1 1]
    from_samples = MOSSQuantum._group_estimate(group,samples)
    from_counts = MOSSQuantum._group_estimate(group,Dict("00"=>2,"11"=>2))
    @test from_counts.value == from_samples.value
    @test from_counts.sample_variance ≈ from_samples.sample_variance
end

@testset "Trajectory simulation states and noise edge cases" begin
    c = QCircuit([HGate(1),AmplitudeDamping(1;γ=.4),QMeasure(1;auto_reset=false)])
    for T in (Float32,ComplexF32,ComplexF64), seed in 1:5
        r = simulate(c,StateVector(T,1);method=KrausTrajectory(),rng=Xoshiro(seed))
        @test r.state isa StateVector
        @test norm(r.state) ≈ 1
        @test eltype(r.state) == Complex{typeof(float(real(zero(T))))}
        @test only(r.measurements).outcome in (0,1)
    end
    for b in (0,1,3)
        r = simulate(c,BatchStateVector(1,b);method=KrausTrajectory(),rng=Xoshiro(2))
        @test r.state isa BatchStateVector
        @test batch_size(r.state) == b
        @test length(r.measurements) == b
    end
    model = NoiseModel(rules=[NoiseRule(HGate,g->BitFlip(1;p=.1))])
    @test simulate(with_noise(c,model),StateVector(1);method=KrausTrajectory()).state isa StateVector
    @test simulate(c,StateVector(1);noise_model=model).state isa DensityMatrix
    @test_throws ArgumentError simulate(QCircuit([QSelect(1,0)]),StateVector(1);method=KrausTrajectory())
    @test supports(CPUBackend(),KrausTrajectory(),StateVector(1))
    @test !supports(CPUBackend(),KrausTrajectory(),DensityMatrix(1))
    @test execute(QCircuit(),StateVector(0);shots=5,method=KrausTrajectory()).counts == Dict(""=>5)
    @test isempty(execute(QCircuit(),BatchStateVector(0,0);shots=0,method=KrausTrajectory(),result=:counts))
    bad = QuantumMap(1,[2Matrix{Float64}(I,2,2)])
    rng = Xoshiro(93); reference = copy(rng)
    @test_throws ArgumentError execute(QCircuit([bad]),StateVector(1);shots=2,method=KrausTrajectory(),rng=rng)
    @test rand(rng) == rand(reference)
    nonunit = QuantumGate(1,[1. 0;0 .5])
    @test_throws ArgumentError execute(QCircuit([nonunit]),StateVector(1);shots=2,method=KrausTrajectory())
    @test_throws ArgumentError estimate(QubitsOperator(1),QCircuit(),StateVector(1);shots=0,
        readout=ReadoutError(2;p0_to_1=0,p1_to_0=0))
    result = execute(QCircuit([QSelect(1,1)]),StateVector(1);shots=9,method=KrausTrajectory(),result=:counts)
    @test result.accepted == 0 && isempty(result.counts)
    @test execute(QCircuit([ResetChannel(1;state=1)]),StateVector(1);shots=20,method=KrausTrajectory()).counts == Dict("1"=>20)
end

@testset "State readout convenience and batch axes" begin
    error = ReadoutError(1;p0_to_1=1,p1_to_0=1)
    @test counts(StateVector(1),10;readout=error) == Dict("1"=>10)
    @test sample(StateVector(1),4;readout=error) == ones(Int,4,1)
    @test estimate(QubitsTerm(1=>Z),StateVector(1);shots=5,readout=error).value == -1
    for b in (0,1,2), mixed in (false,true)
        state = mixed ? BatchDensityMatrix(1,b) : BatchStateVector(1,b)
        @test size(sample(state,4;readout=error)) == (4,1,b)
        @test size(readout_probabilities(state,error)) == (2,b)
        @test all(r->r.value == -1,estimate(QubitsTerm(1=>Z),state;shots=4,readout=error))
        @test length(counts(state,4;readout=error)) == b
    end
    @test MeasurementRecord(1,0,1,:measurement).reported_outcome == 0
    @test_throws ArgumentError execute(QCircuit(),StateVector(1);shots=1,chunk_size=0)
    tiny = MOSSQuantum._trajectory_channel(AmplitudeDamping(1;γ=1e-14))
    @test isnothing(tiny.weights)
end

module NoiseBackendBoundaryFixture
using MOSSQuantum
struct OtherBackend <: AbstractBackend end
struct State <: AbstractQuantumState end
Base.copy(::State) = State()
MOSSQuantum.nqubits(::State) = 1
MOSSQuantum.backend(::State) = OtherBackend()
MOSSQuantum.probabilities(::OtherBackend,::State;qubits=1:1) = isempty(qubits) ? [1.] : [.25,.75]
struct BadDistributionBackend <: AbstractBackend end
MOSSQuantum.probabilities(::BadDistributionBackend,::State;qubits=1:1) = isempty(qubits) ? [1.] : [.2,.3,.5]
end

@testset "Noise respects explicit backend and distributions" begin
    f = NoiseBackendBoundaryFixture
    s = f.State()
    flip = ReadoutError(1;p0_to_1=1,p1_to_0=1)
    @test readout_probabilities(s,flip) ≈ [.75,.25]
    @test !supports(f.OtherBackend(),KrausTrajectory(),s)
    @test_throws UnsupportedOperation execute(QCircuit(),s;shots=0,method=KrausTrajectory())
    @test_throws UnsupportedOperation execute(QCircuit(),StateVector(1);shots=0,backend=f.OtherBackend(),method=KrausTrajectory())
    @test_throws DimensionMismatch execute(QCircuit(),s;shots=1,backend=f.BadDistributionBackend(),readout=flip,result=:counts)
    @test_throws DimensionMismatch readout_probabilities(s,flip;backend=f.BadDistributionBackend())
    @test supports(CPUBackend(),DensityMatrixEvolution(),StateVector(1))
end
