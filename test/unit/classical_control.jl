using Random, LinearAlgebra

@testset "Classical register and conditional binding" begin
    input = Dict("a"=>1,:b=>0)
    register = ClassicalRegister(input)
    input["a"] = 0
    @test register[:a] == 1 && register["b"] == 0
    @test ClassicalCondition((:a,:b),1)(register)
    @test !ClassicalCondition((:a,:b),2)(register)
    copied = copy(register); copied[:a] = 0
    @test register[:a] == 1
    @test_throws ArgumentError ClassicalRegister(Dict(:a=>2))
    @test_throws ArgumentError ClassicalCondition((:a,:a),1)
    @test_throws ArgumentError ClassicalCondition(:a,2)
    @test_throws ArgumentError ClassicalCondition(:missing)(register)
    @test_throws ArgumentError QMeasure(1;key="")
    condition = Conditional(:a,RyGate(1,.1;isparas=true);otherwise=RzGate(2,.2;isparas=true))
    @test nparameters(condition) == 2
    @test active_parameters(condition) == [.1,.2]
    bound = bind_parameters(condition,[.3,.4])
    @test active_parameters(bound) == [.3,.4]
    @test active_parameters(condition) == [.1,.2]
    @test positions(shift(condition,2)) == [3,4]
    @test change_positions(QMeasure(1;key=:a),Dict(1=>2)).key == :a
    @test shift(QCircuit([QMeasure(1;key=:a),condition]),2)[1].key == :a
end

@testset "Independent reported and physical classical control" begin
    initial = StateVector(1)
    circuit = QCircuit([HGate(1),QMeasure(1;auto_reset=false,key=:m),Conditional(:m,XGate(1))])
    snapshot = copy(initial)
    for method in (DensityMatrixEvolution(),KrausTrajectory())
        result = execute(circuit,initial;shots=200,method=method,rng=Xoshiro(12))
        @test result.counts == Dict("0"=>200)
        histogram = classical_counts(result,:m)
        @test sum(values(histogram)) == 200
        @test 60 < histogram["1"] < 140
        @test all(r -> only(r).key == :m,result.measurements)
        @test all(r -> r[:m] in (0,1),result.classical)
        @test estimate(QubitsTerm(1=>Z),circuit,initial;shots=200,method=method).value == 1
        streamed = execute(circuit,initial;shots=200,method=method,rng=Xoshiro(12),result=:counts)
        @test streamed.counts == result.counts
        noisy = ReadoutError(1;p0_to_1=1,p1_to_0=1,scope=:measurement)
        wrong = execute(circuit,initial;shots=100,method=method,readout=noisy,rng=Xoshiro(1))
        @test wrong.counts == Dict("1"=>100)
        @test all(r -> r.values[:m] != r.physical[:m],wrong.classical)
        ideal = QCircuit([HGate(1),QMeasure(1;auto_reset=false,key=:m),Conditional(:m,XGate(1);source=:physical)])
        @test execute(ideal,initial;shots=100,method=method,readout=noisy).counts == Dict("0"=>100)
        registers = classical_register(result)
        registers[1][:m] = 1-registers[1][:m]
        @test registers[1] != result.classical[1]
        @test classical_register(result.measurements[2]) == result.classical[2]
    end
    @test initial == snapshot
    seeded = ClassicalRegister(Dict(:m=>1))
    result = simulate(QCircuit([Conditional(:m,XGate(1))]),initial;classical=seeded)
    @test probabilities(result.state) == [0,1]
    @test result.classical == seeded
    @test seeded[:m] == 1
    @test execute(QCircuit(),initial;shots=2,classical=seeded).classical == [seeded,seeded]
    overwrite = QCircuit([XGate(1),QMeasure(1;key=:m),QMeasure(1;key=:m),Conditional(:m,XGate(1))])
    r = simulate(overwrite,initial)
    @test [m.outcome for m in r.measurements] == [1,0]
    @test r.classical[:m] == 0
    @test probabilities(r.state) == [1,0]
end

@testset "Dynamic circuit preflight, branches and noise" begin
    initial = StateVector(2)
    bad = QCircuit([HGate(1),QMeasure(1;key=:a),Conditional(:b,XGate(2))])
    rng = Xoshiro(45); reference = copy(rng)
    @test_throws ArgumentError execute(bad,initial;shots=0,rng=rng)
    @test_throws ArgumentError execute(bad,initial;shots=10,rng=rng)
    @test rand(rng) == rand(reference)
    partial = QCircuit([QMeasure(1;key=:a),Conditional(:a,QMeasure(2;key=:b)),Conditional(:b,XGate(1))])
    @test_throws ArgumentError simulate(partial,initial)
    both = QCircuit([QMeasure(1;key=:a),Conditional(:a,QMeasure(2;key=:b);otherwise=QMeasure(1;key=:b)),Conditional(:b,XGate(1))])
    @test simulate(both,initial).classical[:b] == 0
    @test_throws ArgumentError execute(QCircuit([QMeasure(1;key=:a),Conditional(:a,XGate(3))]),initial;shots=0)
    @test_throws UnsupportedOperation apply!(Conditional(:a,XGate(1)),initial)
    @test_throws UnsupportedOperation execute(QCircuit([QMeasure(1;key=:a),Conditional(:a,QMeasure(2;keep=false))]),initial;shots=0)
    circuit = QCircuit([HGate(1),QMeasure(1;key=:m,auto_reset=false),Conditional(:m,XGate(1))])
    model = NoiseModel(rules=[NoiseRule(XGate,g->BitFlip(only(positions(g));p=1))])
    result = execute(circuit,initial;shots=500,noise_model=model,rng=Xoshiro(91))
    @test 180 < result.counts["10"] < 320
    @test result.counts["10"] == classical_counts(result,:m)["1"]
    post = QCircuit([QMeasure(1;key=:m),Conditional(:m,QSelect(2,1);value=0)])
    r = execute(post,initial;shots=10)
    @test !any(r.accepted) && isempty(r.counts)
    @test classical_counts(r,:m) == Dict("0"=>10)
    @test isempty(classical_counts(r,:m;accepted_only=true))
    @test_throws ArgumentError estimate(QubitsTerm(1=>Z),post,initial;shots=10)
    for size in (0,1,3), mixed in (false,true)
        state = mixed ? BatchDensityMatrix(2,size) : BatchStateVector(2,size)
        outputs = execute(circuit,state;shots=4)
        @test length(outputs) == size
        @test all(r->r.counts==Dict("00"=>4),outputs)
        simulation = simulate(circuit,state)
        @test batch_size(simulation.state)==size
        @test length(simulation.classical)==size
    end
    mixed_branch = QCircuit([HGate(1),QMeasure(1;key=:a),Conditional(:a,AmplitudeDamping(2;γ=.2))])
    batch = simulate(mixed_branch,BatchStateVector(2,20);rng=Xoshiro(1))
    @test batch.state isa BatchDensityMatrix
    @test tr(batch.state) ≈ ones(20)
    parallel = execute(circuit,initial;shots=100,method=KrausTrajectory(),rng=Xoshiro(23),parallel=true)
    serial = execute(circuit,initial;shots=100,method=KrausTrajectory(),rng=Xoshiro(23))
    @test parallel.classical == serial.classical
    @test parallel.samples == serial.samples
end

@testset "Teleportation with measurement feedback" begin
    message = ComplexF64[cos(.37),exp(.63im)*sin(.37)]
    data = zeros(ComplexF64,8);data[1:2] .= message
    initial = StateVector(data)
    circuit = QCircuit([HGate(2),CNOTGate(2,3),CNOTGate(1,2),HGate(1),
        QMeasure(1;key=:phase,auto_reset=false),QMeasure(2;key=:flip,auto_reset=false),
        Conditional(:flip,XGate(3)),Conditional(:phase,ZGate(3))])
    for seed in 1:16, method in (DensityMatrixEvolution(),KrausTrajectory())
        result = simulate(circuit,initial;method=method,rng=Xoshiro(seed))
        reduced = partial_tr(result.state,[1,2])
        @test storage(reduced) ≈ message*message'
        @test Set(keys(result.classical.values)) == Set([:phase,:flip])
    end
end

@testset "Empty dynamic batches validate post-selection" begin
    circuit = QCircuit([QMeasure(1;key=:m), QSelect(1,0)])
    for state in (BatchStateVector(1,0), BatchDensityMatrix(1,0)), method in (DensityMatrixEvolution(), KrausTrajectory())
        if state isa BatchDensityMatrix && method isa KrausTrajectory
            @test_throws UnsupportedOperation simulate(circuit,state;method=method)
        else
            @test_throws ArgumentError simulate(circuit,state;method=method)
        end
    end
end
