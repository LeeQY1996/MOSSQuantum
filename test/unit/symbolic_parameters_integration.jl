using Test, Random

@testset "Named parameter execution boundaries" begin
    θ, φ = Parameter(:θ), Parameter(:φ)
    template = QCircuit([XGate(1), QCircuit([RyGate(1, θ + φ)])])
    state = StateVector(1)
    before = copy(storage(state))
    @test_throws UnboundParameterError apply!(template, state)
    @test_throws UnboundParameterError template * state
    @test storage(state) == before
    @test_throws UnboundParameterError validate_backend_execution(CPUBackend(), template, state)
    for run in (
        (c, s, rng) -> simulate(c, s; rng),
        (c, s, rng) -> execute(c, s; shots=10, rng),
        (c, s, rng) -> estimate(QubitsTerm(1 => "Z"), c, s; shots=10, rng),
    )
        rng = MersenneTwister(431)
        reference = copy(rng)
        @test_throws UnboundParameterError run(template, state, rng)
        @test rand(rng) == rand(reference)
        @test storage(state) == before
    end
    conditional = QCircuit([XGate(1), Conditional(:flag, XGate(1); otherwise=RyGate(1, θ))])
    rng = MersenneTwister(88)
    reference = copy(rng)
    @test_throws UnboundParameterError simulate(conditional, state;
        classical=ClassicalRegister(Dict(:flag => 1)), rng)
    @test rand(rng) == rand(reference)
    @test storage(state) == before
    for (circuit, path) in ((template, (2, 1)), (conditional, (2, :else, 1)))
        for mode in (:apply, :simulate, :execute, :estimate)
            report = execution_capability(CPUBackend(), circuit, state; mode)
            @test report.status === :unknown
            @test any(issue -> issue.path == path && occursin("binding", issue.reason), report.issues)
        end
    end
end

@testset "Fixed noise on named parameter templates" begin
    θ = Parameter(:θ)
    template = QCircuit([RyGate(1, θ), RzGate(1, θ/2)])
    readout = ReadoutError(1; p0_to_1=0.1, p1_to_0=0.2)
    channel = BitFlip(1; p=0.13)
    model = NoiseModel(rules=[NoiseRule(RyGate, channel)], readout=[readout])
    program = with_noise(template, model)
    @test length(program.circuit) == 3
    @test program.circuit[2] isa QuantumMap
    @test independent_parameters(program) == [θ]
    @test length(parameter_expressions(program)) == 2
    bound = bind_parameters(program, Dict(θ => 0.37))
    reference = with_noise(bind_parameters(template, Dict(θ => 0.37)), model)
    @test storage(simulate(bound, StateVector(1)).state) ≈
          storage(simulate(reference, StateVector(1)).state)
    @test bound.readout !== program.readout
    @test bound.readout[1].probabilities !== program.readout[1].probabilities
    partial = substitute_parameters(program, Dict(θ => 0.2))
    @test isempty(independent_parameters(partial))
    @test bind_parameters(partial, Dict()) isa NoisyCircuit
    @test_throws UnboundParameterError execute(program, StateVector(1); shots=0)

    # A callback must be rejected without ever receiving placeholder angles.
    predicate = _ -> error("noise predicate was called before binding")
    factory = _ -> error("noise factory was called before binding")
    @test_throws ArgumentError with_noise(template, NoiseModel(rules=[NoiseRule(predicate, channel)]))
    @test_throws ArgumentError with_noise(template, NoiseModel(rules=[NoiseRule(RyGate, factory)]))
    numeric = bind_parameters(template, Dict(θ => 0.37))
    @test length(with_noise(numeric, NoiseModel(rules=[NoiseRule(RyGate, _ -> channel)])).circuit) == 3
end
