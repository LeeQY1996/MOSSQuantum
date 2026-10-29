function host_action(gate, state)
    prepared = MOSSQuantumCUDA._prepare_gate(gate, eltype(state), nqubits(state))
    data = storage(state)
    return [MOSSQuantumCUDA._local_amplitude(data, prepared.matrix, prepared.positions, basis)
            for basis in 0:(length(data) - 1)]
end

@testset "CUDA local arithmetic vs independent CPU kernels" begin
    rng = MersenneTwister(43)
    for T in (Float32, Float64, ComplexF32, ComplexF64), n in (5, 7), arity in 1:5
        data = normalize!(randn(rng, T, 1 << n))
        positions = Tuple(randperm(rng, n)[1:arity])
        matrix = Matrix(qr(randn(rng, T, 1 << arity, 1 << arity)).Q)
        gate = QuantumGate(positions, matrix)
        state = StateVector(data)
        expected = apply!(gate, copy(state))
        @test host_action(gate, state) ≈ storage(expected)
        @test storage(state) == data
    end
    for gate in (HGate(1), YGate(3), CNOTGate(4, 1), CNOTGate(1, 4),
                 SWAPGate(2, 5), TOFFOLIGate(5, 1, 3), FREDKINGate(4, 1, 2),
                 RxGate(3, 0.2), CRyGate(4, 1, -0.3), FSIMGate(5, 2, [0.2, -0.1, 0.3, 0.1, -0.2]))
        state = StateVector(normalize!(randn(rng, ComplexF64, 32)))
        @test host_action(gate, state) ≈ storage(apply!(gate, copy(state)))
        @test host_action(gate', state) ≈ storage(apply!(gate', copy(state)))
    end
    # Control is the low local bit: |qubit 1=1⟩ -> |11⟩.
    @test host_action(CNOTGate(1, 2), StateVector(ComplexF64[0, 1, 0, 0])) == [0, 0, 0, 1]
    @test host_action(CNOTGate(2, 1), StateVector(ComplexF64[0, 0, 1, 0])) == [0, 0, 0, 1]
end

@testset "CUDA host preflight and precision" begin
    @test eltype(MOSSQuantumCUDA._prepare_gate(RyGate(1, 0.2), Float32, 1).matrix) === Float32
    @test eltype(MOSSQuantumCUDA._prepare_gate(RzGate(1, 0.2), Float32, 1).matrix) === ComplexF32
    @test eltype(MOSSQuantumCUDA._prepare_gate(RyGate(1, 0.2), ComplexF32, 1).matrix) === ComplexF32
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_gate(XGate(2), ComplexF64, 1)
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_gate(CNOTGate(1, 1), ComplexF64, 2)
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_gate(RyGate(1, NaN), ComplexF64, 1)
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_matrix(fill(1e300, 2, 2), (1,), Float32, 1)
    @test_throws DimensionMismatch MOSSQuantumCUDA._prepare_matrix(ones(3, 3), (1,), Float64, 1)
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_matrix(ones(64, 64), (1, 2, 3, 4, 5, 6), Float64, 6)
    plan = MOSSQuantumCUDA.PreparedGate[]
    circuit = QCircuit([XGate(1), QCircuit([RzGate(2, 0.2), RyGate(1, -0.4)])])
    @test MOSSQuantumCUDA._prepare_circuit!(plan, circuit, Float32, 2) === ComplexF32
    @test length(plan) == 3
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_circuit!(MOSSQuantumCUDA.PreparedGate[],
        QCircuit([HGate(1), QMeasure(1)]), ComplexF64, 2)
    @test MOSSQuantumCUDA._readout_positions((3, 1), 3) == [3, 1]
    @test MOSSQuantumCUDA._readout_positions((), 0) == []
    @test_throws ArgumentError MOSSQuantumCUDA._readout_positions((1, 1), 3)
    @test_throws ArgumentError MOSSQuantumCUDA._readout_positions((0,), 3)
    @test MOSSQuantumCUDA._normalize_readout!([0.5, 0.5], ComplexF64) == [0.5, 0.5]
    @test_throws ArgumentError MOSSQuantumCUDA._normalize_readout!([0.2, 0.3], ComplexF64)
    @test_throws ArgumentError MOSSQuantumCUDA._normalize_readout!([NaN], ComplexF64)
    @test_throws ArgumentError MOSSQuantumCUDA._normalize_readout!([Inf], ComplexF64)
    @test_throws DimensionMismatch MOSSQuantumCUDA._prepare_term(QubitsTerm(1 => ones(3, 3)), ComplexF64, 2)
    @test_throws ArgumentError MOSSQuantumCUDA._prepare_term(QubitsTerm(3 => "Z"), ComplexF64, 2)
    changed_term = QubitsTerm(1 => "X", 2 => "Z")
    pop!(oplist(changed_term))
    @test_throws DimensionMismatch MOSSQuantumCUDA._prepare_term(changed_term, ComplexF64, 2)
    backend = CUDABackend()
    for state in (StateVector(1), DensityMatrix(1), BatchStateVector(1, 2), BatchDensityMatrix(1, 2))
        @test !supports(backend, XGate(1), state)
        @test !supports(backend, QCircuit(), state)
        @test_throws UnsupportedOperation apply!(backend, QCircuit(), state)
    end
    @test_throws ArgumentError gpu_state(-1)
    @test_throws ArgumentError gpu_state(1; T=Int)
    if !CUDA.functional()
        @test_throws ArgumentError gpu_state(1)
        @test_throws ArgumentError to_gpu(StateVector(1))
    end
    ambiguities = Test.detect_ambiguities(MOSSQuantumCUDA, MOSSQuantum; recursive=true)
    @test isempty(filter(pair -> any(method -> method.module === MOSSQuantumCUDA, pair), ambiguities))
end

@testset "CUDA observable preparation vs dense references" begin
    rng = MersenneTwister(28)
    for T in (Float32, Float64, ComplexF32, ComplexF64)
        state = StateVector(normalize!(randn(rng, T, 32)))
        for term in (QubitsTerm(5 => "Y", 1 => "X", 3 => "Z"; coeff=0.3 + 0.2im),
                     QubitsTerm(Int[], Matrix{Float64}[], -2.0),
                     QubitsTerm(2 => randn(rng, ComplexF64, 2, 2)))
            plan, coefficient, _ = MOSSQuantumCUDA._prepare_term(term, T, 5)
            data = storage(state)
            for gate in plan
                data = [MOSSQuantumCUDA._local_amplitude(data, gate.matrix, gate.positions, basis) for basis in 0:31]
            end
            dense = isempty(term) ? coeff(term) * Matrix{T}(I, 32, 32) : matrix(5, term)
            @test coefficient * dot(storage(state), data) ≈ dot(storage(state), dense * storage(state)) atol=2e-6
        end
    end
end
