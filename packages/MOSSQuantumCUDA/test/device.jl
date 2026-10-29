# This file is included only with a functional NVIDIA GPU. Scalar indexing is
# disabled in runtests.jl and never re-enabled, including inside test helpers.
@testset "Real CUDA storage and ownership" begin
    for T in (Float32, Float64, ComplexF32, ComplexF64), n in (0, 1, 5)
        state = gpu_state(n; T=T)
        @test storage(state) isa CUDA.CuArray{T,1,CUDA.DeviceMemory}
        @test backend(state) isa CUDABackend
        @test storage(to_cpu(state)) == storage(StateVector(T, n))
        @test norm(state) ≈ 1
        @test probabilities(state) ≈ probabilities(StateVector(T, n))
        owned = copy(state)
        @test !Base.mightalias(storage(state), storage(owned))
        @test storage(owned) isa CUDA.CuArray
        @test storage(StateVector(state)) === storage(state)
        @test storage(StateVector(storage(state); preserve_storage=true)) === storage(state)
        @test !Base.mightalias(storage(to_gpu(state)), storage(state))
        converted = convert(StateVector{ComplexF32}, state)
        @test storage(converted) isa CUDA.CuArray{ComplexF32}
        @test to_cpu(converted) ≈ StateVector(ComplexF32, n)
        # Storage conversion works independently of execution support.
        mixed = DensityMatrix(state)
        @test storage(mixed) isa CUDA.CuArray
        @test Array(storage(mixed)) ≈ storage(DensityMatrix(to_cpu(state)))
        @test !supports(CUDABackend(), XGate(1), mixed)
    end
    host = StateVector(2)
    uploaded = to_gpu(host)
    @test storage(host) == ComplexF64[1, 0, 0, 0]
    @test storage(to_cpu(uploaded)) == storage(host)
    downloaded = to_cpu(uploaded)
    storage(downloaded)[1] = 0
    @test probabilities(uploaded) == [1, 0, 0, 0]
    backing = CUDA.CuArray{ComplexF64,1,CUDA.DeviceMemory}(ComplexF64[1, 0, 0, 0, 0, 0, 0, 0])
    sliced = StateVector(view(backing, 1:4); preserve_storage=true)
    @test backend(sliced) isa CUDABackend
    @test storage(copy(sliced)) isa CUDA.CuArray
    @test !Base.mightalias(storage(copy(sliced)), backing)
    for T in (ComplexF32, ComplexF64), n in (0, 2), count in (0, 1, 3)
        host_batch = BatchStateVector(T, n, count)
        array = CUDA.CuArray{T,2,CUDA.DeviceMemory}(storage(host_batch))
        batch = BatchStateVector(array, n, count; preserve_storage=true)
        @test storage(batch) === array
        @test storage(copy(batch)) isa CUDA.CuArray
        @test !Base.mightalias(storage(copy(batch)), array)
        @test storage(convert(BatchStateVector{ComplexF32}, batch)) isa CUDA.CuArray{ComplexF32}
        density_batch = BatchDensityMatrix(batch)
        @test storage(density_batch) isa CUDA.CuArray
        @test Array(storage(density_batch)) ≈ storage(BatchDensityMatrix(host_batch))
        @test storage(copy(density_batch)) isa CUDA.CuArray
        @test !Base.mightalias(storage(copy(density_batch)), storage(density_batch))
        @test storage(convert(BatchDensityMatrix{ComplexF32}, density_batch)) isa CUDA.CuArray{ComplexF32}
        @test !supports(CUDABackend(), XGate(1), batch)
        @test !supports(CUDABackend(), XGate(1), density_batch)
        @test_throws UnsupportedOperation apply!(CUDABackend(), XGate(1), batch)
        @test_throws UnsupportedOperation apply!(CUDABackend(), XGate(1), density_batch)
        if count > 0
            sample_state = StateVector(batch, 1)
            @test storage(sample_state) isa CUDA.CuArray
            @test !Base.mightalias(storage(sample_state), array)
            @test to_cpu(sample_state) ≈ StateVector(T, n)
            sample_density = DensityMatrix(density_batch, 1)
            @test storage(sample_density) isa CUDA.CuArray
            @test !Base.mightalias(storage(sample_density), storage(density_batch))
        end
    end
end

@testset "CUDA gates, nested circuits, and rejection atomicity" begin
    rng = MersenneTwister(781)
    for T in (Float32, Float64, ComplexF32, ComplexF64), arity in 1:5
        n = 7
        host = StateVector(normalize!(randn(rng, T, 1 << n)))
        positions = Tuple(randperm(rng, n)[1:arity])
        gate = QuantumGate(positions, Matrix(qr(randn(rng, ComplexF64, 1 << arity, 1 << arity)).Q))
        actual = apply!(gate, to_gpu(host))
        expected = apply!(gate, copy(host))
        @test to_cpu(actual) ≈ expected
        @test eltype(actual) === eltype(expected)
        @test storage(actual) isa CUDA.CuArray
    end
    gates = (HGate(1), YGate(3), CNOTGate(4, 1), CNOTGate(1, 4), SWAPGate(2, 5),
             TOFFOLIGate(5, 1, 3), FREDKINGate(4, 1, 2), RxGate(3, 0.2),
             CRyGate(4, 1, -0.3), FSIMGate(5, 2, [0.2, -0.1, 0.3, 0.1, -0.2]))
    for gate in gates
        host = StateVector(normalize!(randn(rng, ComplexF64, 32)))
        @test to_cpu(apply!(gate, to_gpu(host))) ≈ apply!(gate, copy(host))
        @test to_cpu(apply!(gate', to_gpu(host))) ≈ apply!(gate', copy(host))
    end
    circuit = QCircuit([HGate(1), QCircuit([CNOTGate(1, 2), RyGate(3, 0.3)]), RzGate(2, -0.4)])
    initial = gpu_state(3)
    result = simulate(circuit, initial)
    @test to_cpu(result.state) ≈ simulate(circuit, StateVector(3)).state
    @test isempty(result.measurements)
    @test to_cpu(initial) == StateVector(3)
    @test to_cpu(circuit * initial) ≈ circuit * StateVector(3)
    @test apply!(QCircuit(), initial) === initial
    for unsupported in (QMeasure(1), QSelect(1, 0), AmplitudeDamping(1; γ=0.2),
                        QuantumGate((1, 2, 3, 4, 5, 6), Matrix{ComplexF64}(I, 64, 64)))
        state = gpu_state(6)
        before = to_cpu(state)
        bad = QCircuit([XGate(1), QCircuit([unsupported])])
        @test !supports(CUDABackend(), bad, state)
        @test_throws UnsupportedOperation apply!(bad, state)
        @test to_cpu(state) == before
    end
    for invalid in (XGate(4), CNOTGate(1, 1), RyGate(1, NaN))
        state = gpu_state(3)
        @test_throws ArgumentError apply!(QCircuit([XGate(1), QCircuit([invalid])]), state)
        @test to_cpu(state) == StateVector(3)
    end
    @test_throws UnsupportedOperation apply!(CPUBackend(), XGate(1), initial)
    @test_throws UnsupportedOperation expectation(CPUBackend(), ZGate(1), initial)
    @test_throws UnsupportedOperation probabilities(CPUBackend(), initial)
end

@testset "CUDA observation, readout, and objectives" begin
    rng = MersenneTwister(612)
    for T in (Float32, Float64, ComplexF32, ComplexF64)
        host = StateVector(normalize!(randn(rng, T, 32)))
        state = to_gpu(host)
        term = QubitsTerm(5 => "Y", 1 => "X", 3 => "Z"; coeff=0.3 + 0.2im)
        identity_term = QubitsTerm(Int[], Matrix{Float64}[], 2.0)
        for observable in (ZGate(3), CNOTGate(5, 1), term, identity_term,
                           term + QubitsTerm(2 => "Z"), QubitsOperator())
            expected = if observable isa QubitsOperator && isempty(observable.data)
                zero(T)
            elseif observable isa QubitsTerm && isempty(observable)
                coeff(observable) * sum(abs2, storage(host))
            else
                expectation(observable, host)
            end
            @test expectation(observable, state) ≈ expected atol=5e-6
            @test to_cpu(state) == host
        end
        for qubits in (1:5, (5, 1), (3,), (), (5, 4, 3, 2, 1))
            @test probabilities(state; qubits=qubits) ≈ probabilities(host; qubits=qubits) atol=5e-6
        end
        @test_throws ArgumentError probabilities(state; qubits=(1, 1))
        @test_throws ArgumentError probabilities(state; qubits=(6,))
        @test_throws ArgumentError probabilities(2 * state)
    end
    for bad in (ComplexF64[NaN, 0], ComplexF64[Inf, 0], ComplexF64[0, 0])
        @test_throws ArgumentError probabilities(to_gpu(StateVector(bad)))
    end
    bell = QCircuit([HGate(1), CNOTGate(1, 2)]) * gpu_state(2)
    @test probabilities(bell) ≈ [0.5, 0, 0, 0.5]
    @test sample(MersenneTwister(9), bell, 30) == sample(MersenneTwister(9), to_cpu(bell), 30)
    @test counts(MersenneTwister(9), bell, 30) == counts(MersenneTwister(9), to_cpu(bell), 30)
    template = QCircuit([RyGate(1, 0.0; isparas=true), RyGate(1, 0.0; isparas=true)])
    objective = ExpectationObjective(template, QubitsTerm(1 => "Z"), gpu_state(1);
                                     parameter_map=ParameterMap([1, 1]))
    @test evaluate(objective, [0.2]) ≈ cos(0.4)
    @test evaluate(objective, [-0.3]) ≈ cos(-0.6)
    @test evaluate(objective, [0.2]) ≈ cos(0.4)
    @test !supports_gradient(AdjointGradient(), objective)
    @test_throws UnsupportedGradient value_and_gradient(AdjointGradient(), objective, [0.2])
    @test to_cpu(objective.initial_state) == StateVector(1)
    # Independent task work owns separate scratch buffers and states.
    jobs = [Threads.@spawn to_cpu(apply!(RyGate(1, theta), gpu_state(1))) for theta in (0.2, 0.7)]
    @test fetch(jobs[1]) ≈ apply!(RyGate(1, 0.2), StateVector(1))
    @test fetch(jobs[2]) ≈ apply!(RyGate(1, 0.7), StateVector(1))
end
