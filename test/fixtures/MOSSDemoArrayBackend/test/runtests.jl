using Test
using LinearAlgebra
import MOSS
using MOSSDemoArrayBackend

const CONTAINERS = (MOSS.StateVector, MOSS.DensityMatrix,
                    MOSS.BatchStateVector, MOSS.BatchDensityMatrix)

function demo_states()
    vector = ComplexF64[1, 0]
    density = vector * vector'
    batch_vector = ComplexF64[1 0; 0 1]
    batch_density = cat(density, ComplexF64[0 0; 0 1]; dims=3)
    return map(CONTAINERS, (vector, density, batch_vector, batch_density)) do constructor, values
        constructor(DemoArray(values); preserve_storage=true)
    end
end

host_values(state) = hostcopy(MOSS.storage(state))
cpu_state(state, constructor) = constructor(host_values(state))

@testset "array family without scalar or host fallback" begin
    values = DemoArray(ComplexF64[1, 0])
    @test size(values) == (2,)
    @test axes(values) == (Base.OneTo(2),)
    @test_throws ScalarAccessError values[1]
    @test_throws ScalarAccessError setindex!(values, 2, 1)
    @test_throws ScalarAccessError iterate(values)
    @test_throws HostConversionError Array(values)
    @test_throws HostConversionError Array{ComplexF64}(values)
    @test_throws HostConversionError Vector{ComplexF64}(values)
    @test_throws HostConversionError convert(Vector{ComplexF64}, values)
    @test_throws HostConversionError collect(values)
    @test copy(values) isa DemoArray
    @test !Base.mightalias(copy(values), values)
    @test reshape(values, 2, 1) isa DemoArray
    @test Base.mightalias(reshape(values, 2, 1), values)
    @test view(values, :) isa DemoArray
    @test Base.mightalias(view(values, :), values)
    @test similar(values, ComplexF32, (2, 3)) isa DemoArray{ComplexF32,2}
    converted = similar(values, ComplexF32, size(values))
    @test copyto!(converted, values) === converted
    @test hostcopy(converted) == ComplexF32[1, 0]
    @test hostcopy(2 .* values .+ values) == ComplexF64[3, 0]
    @test hostcopy(conj.(reshape(values, 1, 2))) == ComplexF64[1 0]
    @test_throws HostConversionError MOSS.StateVector(values)
    @test MOSS.storage(MOSS.StateVector(values; preserve_storage=true)) === values
end

@testset "four generic state containers retain storage" begin
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        @test MOSS.storage(initial) isa DemoArray
        @test MOSS.backend(initial) isa ArrayBackend
        @test MOSS.nqubits(initial) == 1
        @test eltype(initial) === ComplexF64
        snapshot = host_values(initial)

        independent = copy(initial)
        @test MOSS.storage(independent) isa DemoArray
        @test host_values(independent) == snapshot
        @test !Base.mightalias(MOSS.storage(independent), MOSS.storage(initial))
        @test MOSS.backend(independent) isa ArrayBackend
        MOSS.apply!(MOSS.XGate(1), independent)
        @test host_values(initial) == snapshot

        typed = convert(constructor{ComplexF32}, initial)
        @test MOSS.storage(typed) isa DemoArray
        @test eltype(typed) === ComplexF32
        @test host_values(typed) == ComplexF32.(snapshot)
        @test !Base.mightalias(MOSS.storage(typed), MOSS.storage(initial))
        @test MOSS.backend(typed) isa ArrayBackend

        from_state = constructor(initial; copy=true)
        @test MOSS.storage(from_state) isa DemoArray
        @test !Base.mightalias(MOSS.storage(from_state), MOSS.storage(initial))
        @test host_values(from_state) == snapshot
        @test_throws HostConversionError constructor(MOSS.storage(initial))
        @test host_values(initial) == snapshot

        for (result, expected) in ((initial + initial, snapshot + snapshot),
                                   (initial - initial, snapshot - snapshot),
                                   ((0.5 + 0.2im) * initial, (0.5 + 0.2im) * snapshot),
                                   (initial / 2, snapshot / 2))
            @test MOSS.storage(result) isa DemoArray
            @test host_values(result) ≈ expected
            @test !Base.mightalias(MOSS.storage(result), MOSS.storage(initial))
        end
    end
end

@testset "explicit and implicit array backend execution" begin
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        backend = ArrayBackend()
        reference = cpu_state(initial, constructor)
        snapshot = host_values(initial)
        gate = MOSS.RyGate(1, 0.37)
        @test MOSS.supports(backend, gate, initial)
        @test MOSS.supports(backend, MOSS.ZGate(1), initial; action=:expectation)
        @test !MOSS.supports(backend, gate, initial; action=:expectation)
        @test !MOSS.supports(backend, MOSS.ZGate(1), initial; action=:apply)

        explicit = MOSS.apply!(backend, gate, copy(initial))
        implicit = MOSS.apply!(gate, copy(initial))
        reference = MOSS.apply!(gate, reference)
        @test host_values(explicit) ≈ MOSS.storage(reference)
        @test host_values(implicit) ≈ MOSS.storage(reference)
        @test MOSS.storage(explicit) isa DemoArray
        @test MOSS.storage(implicit) isa DemoArray
        expected = MOSS.expectation(MOSS.QubitsTerm(1 => "Z"), reference)
        @test MOSS.expectation(backend, MOSS.ZGate(1), explicit) ≈ expected
        @test MOSS.expectation(MOSS.ZGate(1), implicit) ≈ expected

        template = MOSS.QCircuit([MOSS.XGate(1), MOSS.RyGate(1, 0.0; isparas=true)])
        bound = MOSS.bind_parameters(template, [0.21])
        @test MOSS.supports(backend, bound, initial)
        explicit_circuit = MOSS.apply!(backend, bound, copy(initial))
        implicit_circuit = MOSS.apply!(bound, copy(initial))
        product_circuit = bound * initial
        circuit_reference = bound * cpu_state(initial, constructor)
        @test host_values(explicit_circuit) ≈ MOSS.storage(circuit_reference)
        @test host_values(implicit_circuit) ≈ MOSS.storage(circuit_reference)
        @test host_values(product_circuit) ≈ MOSS.storage(circuit_reference)
        @test MOSS.storage(product_circuit) isa DemoArray
        @test host_values(initial) == snapshot

        if initial isa Union{MOSS.StateVector,MOSS.DensityMatrix}
            objective = MOSS.ExpectationObjective(template, MOSS.ZGate(1), initial)
            expected_value = real(MOSS.expectation(MOSS.QubitsTerm(1 => "Z"), circuit_reference))
            @test objective.backend isa ArrayBackend
            @test MOSS.storage(objective.initial_state) isa DemoArray
            @test MOSS.evaluate(objective, [0.21]) ≈ expected_value
            @test !MOSS.supports_gradient(MOSS.AdjointGradient(), objective)
            @test_throws MOSS.UnsupportedGradient MOSS.value_and_gradient(MOSS.AdjointGradient(), objective, [0.21])
        else
            objective = MOSS.BatchExpectationObjective(template, MOSS.ZGate(1), initial)
            expected_values = real.(MOSS.expectation(MOSS.QubitsTerm(1 => "Z"), circuit_reference))
            @test objective.backend isa ArrayBackend
            @test MOSS.storage(objective.initial_state) isa DemoArray
            @test MOSS.evaluate_batch(objective, [0.21]) ≈ expected_values
            @test MOSS.evaluate(objective, [0.21]) ≈ sum(expected_values) / length(expected_values)
            @test !MOSS.supports_gradient(MOSS.AdjointGradient(), objective)
            @test_throws MOSS.UnsupportedGradient MOSS.value_and_gradient(MOSS.AdjointGradient(), objective, [0.21])
        end
        @test host_values(initial) == snapshot
    end
end

@testset "pure and mixed transformations preserve the array family" begin
    pure, mixed, batch_pure, batch_mixed = demo_states()
    pure_snapshot, batch_snapshot = host_values(pure), host_values(batch_pure)
    converted = MOSS.DensityMatrix(pure)
    batch_converted = MOSS.BatchDensityMatrix(batch_pure)
    @test MOSS.storage(converted) isa DemoArray
    @test MOSS.storage(batch_converted) isa DemoArray
    @test host_values(converted) == pure_snapshot * pure_snapshot'
    @test host_values(batch_converted) == host_values(batch_mixed)
    @test !Base.mightalias(MOSS.storage(converted), MOSS.storage(pure))
    @test !Base.mightalias(MOSS.storage(batch_converted), MOSS.storage(batch_pure))

    one_column = MOSS.BatchStateVector(pure)
    one_density = MOSS.BatchDensityMatrix(mixed)
    @test MOSS.storage(one_column) isa DemoArray
    @test size(MOSS.storage(one_column)) == (2, 1)
    @test MOSS.storage(one_density) isa DemoArray
    @test size(MOSS.storage(one_density)) == (2, 2, 1)

    extracted_pure = MOSS.StateVector(batch_pure, 2)
    extracted_mixed = MOSS.DensityMatrix(batch_mixed, 2)
    @test MOSS.storage(extracted_pure) isa DemoArray
    @test MOSS.storage(extracted_mixed) isa DemoArray
    @test host_values(extracted_pure) == ComplexF64[0, 1]
    @test host_values(extracted_mixed) == ComplexF64[0 0; 0 1]
    MOSS.apply!(MOSS.XGate(1), extracted_pure)
    MOSS.apply!(MOSS.XGate(1), extracted_mixed)
    @test host_values(batch_pure) == batch_snapshot
    @test host_values(batch_mixed) == host_values(demo_states()[4])

    for (constructor, initial) in zip(CONTAINERS, demo_states())
        channel = MOSS.AmplitudeDamping(1; γ=0.2)
        @test MOSS.supports(ArrayBackend(), channel, initial)
        reference = MOSS.apply!(channel, cpu_state(initial, constructor))
        output = MOSS.apply!(channel, copy(initial))
        @test output isa Union{MOSS.DensityMatrix,MOSS.BatchDensityMatrix}
        @test MOSS.storage(output) isa DemoArray
        @test host_values(output) ≈ MOSS.storage(reference)
        circuit = MOSS.QCircuit([MOSS.XGate(1), channel, MOSS.RyGate(1, 0.11)])
        circuit_output = circuit * initial
        circuit_reference = circuit * cpu_state(initial, constructor)
        @test MOSS.storage(circuit_output) isa DemoArray
        @test host_values(circuit_output) ≈ MOSS.storage(circuit_reference)
    end
    @test host_values(pure) == pure_snapshot
    @test host_values(batch_pure) == batch_snapshot
end

@testset "unknown capabilities fail before mutation" begin
    for initial in demo_states()
        snapshot = host_values(initial)
        @test !MOSS.supports(MOSS.CPUBackend(), MOSS.XGate(1), initial)
        @test !MOSS.supports(MOSS.CPUBackend(), MOSS.ZGate(1), initial; action=:expectation)
        @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.CPUBackend(), MOSS.XGate(1), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.expectation(MOSS.CPUBackend(), MOSS.ZGate(1), initial)
        @test !MOSS.supports(ArrayBackend(), DemoUnknown(), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.apply!(DemoUnknown(), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.HGate(1), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.expectation(MOSS.XGate(1), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.QubitsTerm(1 => "X") * initial
        @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.QCircuit([MOSS.XGate(1), DemoUnknown()]), initial)
        @test_throws MOSS.UnsupportedOperation MOSS.apply!(MOSS.QCircuit([MOSS.XGate(1), MOSS.HGate(1)]), initial)
        @test_throws ArgumentError MOSS.apply!(MOSS.QCircuit([MOSS.XGate(1), MOSS.RyGate(2, 0.2)]), initial)
        @test host_values(initial) == snapshot
    end
end

@testset "public linear action and readout backend hooks" begin
    matrix = ComplexF64[0 1; 1 0]
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        snapshot = host_values(initial)
        @test MOSS.supports(ArrayBackend(), matrix, initial)
        output = MOSS.apply(ArrayBackend(), matrix, initial)
        expected = initial isa MOSS.BatchDensityMatrix ?
            cat((matrix * snapshot[:, :, b] for b in axes(snapshot, 3))...; dims=3) : matrix * snapshot
        @test MOSS.storage(output) isa DemoArray
        @test host_values(output) == expected
        @test !Base.mightalias(MOSS.storage(output), MOSS.storage(initial))
        if !(initial isa MOSS.DensityMatrix)
            @test host_values(matrix * initial) == expected
        end
        @test_throws DimensionMismatch MOSS.apply(ArrayBackend(), ones(3, 3), initial)
        @test MOSS.supports(ArrayBackend(), MOSS.probabilities, initial; action=:probabilities)
        reference = cpu_state(initial, constructor)
        @test MOSS.probabilities(ArrayBackend(), initial) == MOSS.probabilities(reference)
        @test MOSS.probabilities(initial) == MOSS.probabilities(reference)
        @test MOSS.probabilities(initial; qubits=Int[]) == MOSS.probabilities(reference; qubits=Int[])
        @test_throws ArgumentError MOSS.probabilities(initial; qubits=[1, 1])
        @test_throws ArgumentError MOSS.probabilities(initial; qubits=[2])
        @test_throws MOSS.UnsupportedOperation MOSS.probabilities(MOSS.CPUBackend(), initial)
        @test host_values(initial) == snapshot
    end
    wide = MOSS.StateVector(DemoArray(ComplexF64[1, 0, 0, 0]); preserve_storage=true)
    MOSS.apply!(MOSS.XGate(2), wide)
    @test host_values(wide) == ComplexF64[0, 0, 1, 0]
    @test MOSS.probabilities(wide; qubits=[2, 1]) == [0, 1, 0, 0]
    @test MOSS.probabilities(wide; qubits=[1, 2]) == [0, 0, 1, 0]
end

@testset "external gradient selection stays independent of storage" begin
    objective = DemoRyObjective()
    values = [0.37]
    method = AnalyticRyGradient()
    @test MOSS.evaluate(objective, values) ≈ cos(0.37)
    @test MOSS.supports_gradient(method, objective)
    @test !MOSS.supports_gradient(MOSS.AdjointGradient(), objective)
    value, gradient = MOSS.value_and_gradient(method, objective, values)
    @test value ≈ cos(0.37)
    @test gradient ≈ [-sin(0.37)]
    value, back = MOSS.value_and_pullback(method, objective, values)
    @test value ≈ cos(0.37)
    @test back(1.0) ≈ gradient
    @test back(-2.0) ≈ -2gradient
    values[1] = 0.2
    back(1.0)[1] = 100
    @test back(1.0) ≈ gradient
    @test MOSS.differentiable_value(method, objective, [0.37]) ≈ cos(0.37)
end

@testset "fixture needs no AD framework" begin
    @test !haskey(Base.loaded_modules, Base.PkgId(Base.UUID("e88e6eb3-aa80-5325-afca-941959d7151f"), "Zygote"))
    @test !haskey(Base.loaded_modules, Base.PkgId(Base.UUID("d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"), "ChainRulesCore"))
end
