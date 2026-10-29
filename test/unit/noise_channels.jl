using LinearAlgebra, Random

@testset "Physical noise channels and contracts" begin
    rng = MersenneTwister(172)
    for c in (AmplitudeDamping(1;γ=.3),PhaseDamping(1;γ=.3),Depolarizing(1;p=.3),
              BitFlip(1;p=.2),PhaseFlip(1;p=.2),BitPhaseFlip(1;p=.2),
              GeneralizedAmplitudeDamping(1;γ=.3,excited_population=.2),
              ResetChannel(1;state=1,p=.4),ThermalRelaxation(1;T1=10,T2=15,duration=2))
        @test is_tp(c)
        for T in (ComplexF32,ComplexF64)
            initial = rand_densitymatrix(rng,T,1)
            rho = copy(storage(initial))
            output = apply!(c,copy(initial))
            reference = sum(k*rho*k' for k in kraus_matrices(c))
            @test storage(output) ≈ reference
            @test tr(output) ≈ 1
            @test ishermitian(storage(output)) || storage(output) ≈ storage(output)'
            @test minimum(eigvals(Hermitian(storage(output)))) >= -1e-6
            @test eltype(output) == T
        end
    end
    initial = rand_densitymatrix(rng,1)
    rho = storage(initial)
    for p in (0.,.5,1.,4/3)
        @test storage(apply!(Depolarizing(1;p=p),copy(initial))) ≈ (1-p)*rho+p*I/2
    end
    plus = DensityMatrix(StateVector(ComplexF64[1,1]/sqrt(2)))
    @test storage(apply!(PhaseDamping(1;γ=.36),copy(plus)))[1,2] ≈ .4
    for e in (0.,.2,1.), g in (0.,.7,1.)
        fixed = DensityMatrix(ComplexF64[1-e 0;0 e])
        @test apply!(GeneralizedAmplitudeDamping(1;γ=g,excited_population=e),copy(fixed)) ≈ fixed
    end
    for t in (0.,.1,10.,1000.), (t1,t2) in ((10.,5.),(10.,15.),(10.,20.),(Inf,10.),(Inf,Inf))
        c = ThermalRelaxation(1;T1=t1,T2=t2,duration=t,excited_population=.2)
        actual = storage(apply!(c,copy(initial)))
        @test actual[2,2] ≈ .2+(rho[2,2]-.2)*exp(-t/t1)
        @test actual[1,2] ≈ rho[1,2]*exp(-t/t2) atol=1e-13
        @test is_tp(c)
    end
    for constructor in (AmplitudeDamping,PhaseDamping)
        for p in (-.1,1.1,NaN,Inf)
            @test_throws ArgumentError constructor(1;γ=p)
        end
    end
    for p in (-.1,1.1,NaN,Inf)
        @test_throws ArgumentError BitFlip(1;p=p)
        @test_throws ArgumentError ResetChannel(1;p=p)
    end
    @test_throws ArgumentError Depolarizing(1;p=1.4)
    @test_throws ArgumentError ThermalRelaxation(1;T1=1,T2=3,duration=1)
    @test_throws ArgumentError ThermalRelaxation(1;T1=NaN,T2=1,duration=1)
    @test_throws ArgumentError ThermalRelaxation(1;T1=1,T2=1,duration=-1)
    @test_throws ArgumentError MixedUnitary(1,[X,Z],[.5,.4])
    @test_throws ArgumentError MixedUnitary(1,[2X],[1.])
    @test_throws ArgumentError PauliChannel((1,2),["IX","AB"],[.5,.5])
    @test_throws ArgumentError QuantumMap((1,1),[Matrix{Float64}(I,4,4)])
    @test_throws ArgumentError QuantumMap(0,[Matrix{Float64}(I,2,2)])
    @test_throws DimensionMismatch QuantumMap(1,[ones(3,3)])
    @test_throws ArgumentError QuantumMap(1,Matrix{Float64}[])
    @test_throws ArgumentError QuantumMap(1,[fill(NaN,2,2)])
    @test_throws ArgumentError QuantumMap(1,[2Matrix{Float64}(I,2,2)];check_tp=true)
    @test !is_tp(QuantumMap(1,[2Matrix{Float64}(I,2,2)]))
    source = [Matrix{Float64}(I,2,2)]
    c = QuantumMap(1,source;check_tp=true)
    source[1][1,1] = 4
    @test is_tp(c)
    kraus_matrices(c)[1][1,1] = 2
    @test_throws ArgumentError apply!(c,StateVector(1))
    @test_throws ArgumentError apply!(c,BatchDensityMatrix(1,1))
    # Public Kraus mutation cannot silently leave the cached superoperator stale.
    @test_throws ArgumentError execute(QCircuit([c]),StateVector(1);shots=2,method=KrausTrajectory())
end

@testset "Two-qubit correlated noise and position order" begin
    rng = MersenneTwister(53)
    psi = rand_state(rng,3)
    rho = storage(DensityMatrix(psi))
    for register in ((1,3),(3,1)), word in ("IX","XY","ZZ")
        c = PauliChannel(register,["II",word],[.6,.4])
        local_u = kron(Dict('I'=>I(2),'X'=>X,'Y'=>Y,'Z'=>Z)[word[2]],
                       Dict('I'=>I(2),'X'=>X,'Y'=>Y,'Z'=>Z)[word[1]])
        # Build a full operator by applying a gate to each basis column, an
        # independent reference to the density-channel superoperator path.
        full = hcat([storage(apply!(QuantumGate(register,local_u),
                     StateVector(ComplexF64[i==j for i in 1:8]))) for j in 1:8]...)
        @test storage(apply!(c,copy(psi))) ≈ .6rho+.4full*rho*full'
        batch = BatchStateVector(hcat(storage(psi),storage(psi)))
        output = apply!(c,batch)
        @test storage(output)[:,:,1] ≈ storage(apply!(c,copy(psi)))
    end
    two = rand_densitymatrix(rng,2)
    for p in (0.,.4,1.,16/15)
        c = Depolarizing((2,1);p=p)
        @test is_tp(c)
        @test storage(apply!(c,copy(two))) ≈ (1-p)*storage(two)+p*I/4
    end
end

@testset "Noise constructor precision" begin
    for p in (0f0,.3f0,1f0)
        @test is_tp(Depolarizing(1;p=p))
        @test is_tp(BitFlip(1;p=p))
        @test is_tp(AmplitudeDamping(1;γ=p))
        @test is_tp(GeneralizedAmplitudeDamping(1;γ=p,excited_population=.2f0))
    end
    @test is_tp(MixedUnitary(1,[X,Y,Z],Float32[.1,.2,.7]))
    @test is_tp(ThermalRelaxation(1;T1=10f0,T2=15f0,duration=.2f0))
end
