using Test, Random, MOSSQuantum

struct CapabilityUnknownBackend <: MOSSQuantum.AbstractBackend end

@testset "configuration-level execution capability" begin
    backend = CPUBackend()
    initial = StateVector(2)
    before = copy(storage(initial))
    rng = MersenneTwister(421)
    untouched_rng = copy(rng)
    circuit = QCircuit([HGate(1),CNOTGate(1,2)])
    for mode in (:apply,:simulate,:execute)
        report = execution_capability(backend,circuit,initial;mode=mode)
        @test report.status === :supported
        @test isempty(report.issues)
        @test only(report.final_state_types) === typeof(initial)
    end
    @test storage(initial) == before
    @test rand(rng) == rand(untouched_rng)
    @test execution_capability(CapabilityUnknownBackend(),circuit,initial).status === :unknown
    @test execution_capability(backend,QCircuit([XGate(3)]),initial).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:execute,qubits=[1,1]).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:execute,result=:invalid).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:execute,parallel=true).status === :unsupported
    @test execution_capability(backend,circuit,DensityMatrix(2);method=KrausTrajectory()).status === :unsupported
    @test execution_capability(backend,QCircuit([QMeasure(1;key=:m)]),initial;mode=:apply).status === :supported
    @test_throws ArgumentError execution_capability(backend,circuit,initial;mode=:bogus)

    branching = QCircuit([QMeasure(1;key=:m),
        Conditional(:m,AmplitudeDamping(1;γ=0.2)),HGate(2)])
    report = execution_capability(backend,branching,initial;mode=:simulate)
    @test report.status === :supported
    @test DensityMatrix in report.final_state_types
    @test typeof(initial) in report.final_state_types
    @test storage(initial) == before
    selection = QCircuit([HGate(1),QSelect(1,1)])
    @test execution_capability(backend,selection,initial;mode=:simulate).status === :supported
    @test execution_capability(backend,selection,initial;mode=:execute).status === :supported
    @test execution_capability(backend,selection,initial;mode=:simulate,method=KrausTrajectory()).status === :unsupported
    @test execution_capability(backend,QCircuit([QMeasure(1;key=:m),QSelect(1,1)]),initial;mode=:simulate).status === :unsupported
    invalid_branch = QCircuit([QMeasure(1;key=:m),Conditional(:m,XGate(1);
        otherwise=QMeasure(2;keep=false))])
    report = execution_capability(backend,invalid_branch,initial;mode=:execute)
    @test report.status === :unsupported
    @test any(i -> i.path == (2,:else,1),report.issues)
    missing = QCircuit([Conditional(:missing,XGate(1))])
    @test execution_capability(backend,missing,initial;mode=:simulate).status === :unsupported
    model = NoiseModel(rules=[NoiseRule(HGate,_ -> error("noise factory must not run during capability query"))])
    @test execution_capability(backend,circuit,initial;noise_model=model).status === :unknown
    expanded = with_noise(circuit,NoiseModel())
    @test execution_capability(backend,expanded,initial;mode=:execute).status === :supported
    @test execution_capability(backend,expanded,initial;mode=:apply).status === :unsupported
    @test execution_capability(backend,expanded,initial;noise_model=model).status === :unsupported
    @test execution_capability(CapabilityUnknownBackend(),QCircuit(),initial).status === :unknown
    observable = QubitsTerm(1=>"X") + QubitsTerm(2=>"Z")
    @test execution_capability(backend,circuit,initial;mode=:estimate,observable=observable,shots=100).status === :supported
    @test execution_capability(backend,circuit,initial;mode=:estimate,observable=observable,shots=1).status === :unsupported
    @test execution_capability(backend,selection,initial;mode=:estimate,observable=observable,shots=100).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:estimate,observable=QubitsTerm(3=>"Z"),shots=100).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:estimate).status === :unsupported
    @test execution_capability(backend,circuit,initial;mode=:estimate,observable=observable,shots=100,noise_model=model).status === :unknown
end

struct CapabilityUntouchedState <: MOSSQuantum.AbstractQuantumState end
MOSSQuantum.nqubits(::CapabilityUntouchedState) = error("unexpected state access")

@testset "capability execution options" begin
    b = CPUBackend()
    state = StateVector(2)
    circuit = QCircuit([HGate(1)])
    @test execution_capability(b,circuit,state;mode=:execute,shots=-1).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,shots=true).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,shots=4).status === :supported
    @test execution_capability(b,circuit,state;mode=:simulate,shots=4).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:apply,observable=QubitsTerm(1=>"Z")).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,grouping=:none).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,atol=0.1).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,max_terms=1).status === :unsupported
    @test execution_capability(b,circuit,state;mode=:execute,qubits=[2,1]).status === :supported
    @test execution_capability(b,circuit,state;mode=:execute,qubits=[1,1]).status === :unsupported
    for mode in (:apply,:simulate,:estimate)
        observable = mode === :estimate ? QubitsTerm(1=>"Z") : nothing
        report = execution_capability(b,circuit,state;mode=mode,qubits=[1],observable=observable)
        @test report.status === :unsupported
        @test occursin("qubits",only(report.issues).reason)
    end
    @test execution_capability(b,circuit,state;mode=:estimate,observable=QubitsTerm(1=>"Z"),shots=10).status === :supported
    @test execution_capability(b,QCircuit(),CapabilityUntouchedState();mode=:simulate,qubits=[1]).status === :unsupported
    @test execution_capability(b,QCircuit(),CapabilityUntouchedState();mode=:estimate,qubits=[1]).status === :unsupported
end
