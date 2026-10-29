using Test
using LinearAlgebra
import MOSSQuantum
using MOSSQuantumDemoArrayBackend

const CONTAINERS = (MOSSQuantum.StateVector, MOSSQuantum.DensityMatrix,
                    MOSSQuantum.BatchStateVector, MOSSQuantum.BatchDensityMatrix)

function demo_states()
    vector = ComplexF64[1, 0]
    density = vector * vector'
    batch_vector = ComplexF64[1 0; 0 1]
    batch_density = cat(density, ComplexF64[0 0; 0 1]; dims=3)
    return map(CONTAINERS, (vector, density, batch_vector, batch_density)) do constructor, values
        constructor(DemoArray(values); preserve_storage=true)
    end
end

host_values(state) = hostcopy(MOSSQuantum.storage(state))
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
    @test_throws HostConversionError MOSSQuantum.StateVector(values)
    @test MOSSQuantum.storage(MOSSQuantum.StateVector(values; preserve_storage=true)) === values
end

@testset "four generic state containers retain storage" begin
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        @test MOSSQuantum.storage(initial) isa DemoArray
        @test MOSSQuantum.backend(initial) isa ArrayBackend
        @test MOSSQuantum.nqubits(initial) == 1
        @test eltype(initial) === ComplexF64
        snapshot = host_values(initial)

        independent = copy(initial)
        @test MOSSQuantum.storage(independent) isa DemoArray
        @test host_values(independent) == snapshot
        @test !Base.mightalias(MOSSQuantum.storage(independent), MOSSQuantum.storage(initial))
        @test MOSSQuantum.backend(independent) isa ArrayBackend
        MOSSQuantum.apply!(MOSSQuantum.XGate(1), independent)
        @test host_values(initial) == snapshot

        typed = convert(constructor{ComplexF32}, initial)
        @test MOSSQuantum.storage(typed) isa DemoArray
        @test eltype(typed) === ComplexF32
        @test host_values(typed) == ComplexF32.(snapshot)
        @test !Base.mightalias(MOSSQuantum.storage(typed), MOSSQuantum.storage(initial))
        @test MOSSQuantum.backend(typed) isa ArrayBackend

        from_state = constructor(initial; copy=true)
        @test MOSSQuantum.storage(from_state) isa DemoArray
        @test !Base.mightalias(MOSSQuantum.storage(from_state), MOSSQuantum.storage(initial))
        @test host_values(from_state) == snapshot
        @test_throws HostConversionError constructor(MOSSQuantum.storage(initial))
        @test host_values(initial) == snapshot

        for (result, expected) in ((initial + initial, snapshot + snapshot),
                                   (initial - initial, snapshot - snapshot),
                                   ((0.5 + 0.2im) * initial, (0.5 + 0.2im) * snapshot),
                                   (initial / 2, snapshot / 2))
            @test MOSSQuantum.storage(result) isa DemoArray
            @test host_values(result) ≈ expected
            @test !Base.mightalias(MOSSQuantum.storage(result), MOSSQuantum.storage(initial))
        end
    end
end

@testset "explicit and implicit array backend execution" begin
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        backend = ArrayBackend()
        reference = cpu_state(initial, constructor)
        snapshot = host_values(initial)
        gate = MOSSQuantum.RyGate(1, 0.37)
        @test MOSSQuantum.supports(backend, gate, initial)
        @test MOSSQuantum.supports(backend, MOSSQuantum.ZGate(1), initial; action=:expectation)
        @test !MOSSQuantum.supports(backend, gate, initial; action=:expectation)
        @test !MOSSQuantum.supports(backend, MOSSQuantum.ZGate(1), initial; action=:apply)

        explicit = MOSSQuantum.apply!(backend, gate, copy(initial))
        implicit = MOSSQuantum.apply!(gate, copy(initial))
        reference = MOSSQuantum.apply!(gate, reference)
        @test host_values(explicit) ≈ MOSSQuantum.storage(reference)
        @test host_values(implicit) ≈ MOSSQuantum.storage(reference)
        @test MOSSQuantum.storage(explicit) isa DemoArray
        @test MOSSQuantum.storage(implicit) isa DemoArray
        expected = MOSSQuantum.expectation(MOSSQuantum.QubitsTerm(1 => "Z"), reference)
        @test MOSSQuantum.expectation(backend, MOSSQuantum.ZGate(1), explicit) ≈ expected
        @test MOSSQuantum.expectation(MOSSQuantum.ZGate(1), implicit) ≈ expected

        template = MOSSQuantum.QCircuit([MOSSQuantum.XGate(1), MOSSQuantum.RyGate(1, 0.0; isparas=true)])
        bound = MOSSQuantum.bind_parameters(template, [0.21])
        @test MOSSQuantum.supports(backend, bound, initial)
        explicit_circuit = MOSSQuantum.apply!(backend, bound, copy(initial))
        implicit_circuit = MOSSQuantum.apply!(bound, copy(initial))
        product_circuit = bound * initial
        circuit_reference = bound * cpu_state(initial, constructor)
        @test host_values(explicit_circuit) ≈ MOSSQuantum.storage(circuit_reference)
        @test host_values(implicit_circuit) ≈ MOSSQuantum.storage(circuit_reference)
        @test host_values(product_circuit) ≈ MOSSQuantum.storage(circuit_reference)
        @test MOSSQuantum.storage(product_circuit) isa DemoArray
        @test host_values(initial) == snapshot

        if initial isa Union{MOSSQuantum.StateVector,MOSSQuantum.DensityMatrix}
            objective = MOSSQuantum.ExpectationObjective(template, MOSSQuantum.ZGate(1), initial)
            expected_value = real(MOSSQuantum.expectation(MOSSQuantum.QubitsTerm(1 => "Z"), circuit_reference))
            @test objective.backend isa ArrayBackend
            @test MOSSQuantum.storage(objective.initial_state) isa DemoArray
            @test MOSSQuantum.evaluate(objective, [0.21]) ≈ expected_value
            @test !MOSSQuantum.supports_gradient(MOSSQuantum.AdjointGradient(), objective)
            @test_throws MOSSQuantum.UnsupportedGradient MOSSQuantum.value_and_gradient(MOSSQuantum.AdjointGradient(), objective, [0.21])
        else
            objective = MOSSQuantum.BatchExpectationObjective(template, MOSSQuantum.ZGate(1), initial)
            expected_values = real.(MOSSQuantum.expectation(MOSSQuantum.QubitsTerm(1 => "Z"), circuit_reference))
            @test objective.backend isa ArrayBackend
            @test MOSSQuantum.storage(objective.initial_state) isa DemoArray
            @test MOSSQuantum.evaluate_batch(objective, [0.21]) ≈ expected_values
            @test MOSSQuantum.evaluate(objective, [0.21]) ≈ sum(expected_values) / length(expected_values)
            @test !MOSSQuantum.supports_gradient(MOSSQuantum.AdjointGradient(), objective)
            @test_throws MOSSQuantum.UnsupportedGradient MOSSQuantum.value_and_gradient(MOSSQuantum.AdjointGradient(), objective, [0.21])
        end
        @test host_values(initial) == snapshot
    end
end

@testset "pure and mixed transformations preserve the array family" begin
    pure, mixed, batch_pure, batch_mixed = demo_states()
    pure_snapshot, batch_snapshot = host_values(pure), host_values(batch_pure)
    converted = MOSSQuantum.DensityMatrix(pure)
    batch_converted = MOSSQuantum.BatchDensityMatrix(batch_pure)
    @test MOSSQuantum.storage(converted) isa DemoArray
    @test MOSSQuantum.storage(batch_converted) isa DemoArray
    @test host_values(converted) == pure_snapshot * pure_snapshot'
    @test host_values(batch_converted) == host_values(batch_mixed)
    @test !Base.mightalias(MOSSQuantum.storage(converted), MOSSQuantum.storage(pure))
    @test !Base.mightalias(MOSSQuantum.storage(batch_converted), MOSSQuantum.storage(batch_pure))

    one_column = MOSSQuantum.BatchStateVector(pure)
    one_density = MOSSQuantum.BatchDensityMatrix(mixed)
    @test MOSSQuantum.storage(one_column) isa DemoArray
    @test size(MOSSQuantum.storage(one_column)) == (2, 1)
    @test MOSSQuantum.storage(one_density) isa DemoArray
    @test size(MOSSQuantum.storage(one_density)) == (2, 2, 1)

    extracted_pure = MOSSQuantum.StateVector(batch_pure, 2)
    extracted_mixed = MOSSQuantum.DensityMatrix(batch_mixed, 2)
    @test MOSSQuantum.storage(extracted_pure) isa DemoArray
    @test MOSSQuantum.storage(extracted_mixed) isa DemoArray
    @test host_values(extracted_pure) == ComplexF64[0, 1]
    @test host_values(extracted_mixed) == ComplexF64[0 0; 0 1]
    MOSSQuantum.apply!(MOSSQuantum.XGate(1), extracted_pure)
    MOSSQuantum.apply!(MOSSQuantum.XGate(1), extracted_mixed)
    @test host_values(batch_pure) == batch_snapshot
    @test host_values(batch_mixed) == host_values(demo_states()[4])

    for (constructor, initial) in zip(CONTAINERS, demo_states())
        channel = MOSSQuantum.AmplitudeDamping(1; γ=0.2)
        @test MOSSQuantum.supports(ArrayBackend(), channel, initial)
        reference = MOSSQuantum.apply!(channel, cpu_state(initial, constructor))
        output = MOSSQuantum.apply!(channel, copy(initial))
        @test output isa Union{MOSSQuantum.DensityMatrix,MOSSQuantum.BatchDensityMatrix}
        @test MOSSQuantum.storage(output) isa DemoArray
        @test host_values(output) ≈ MOSSQuantum.storage(reference)
        circuit = MOSSQuantum.QCircuit([MOSSQuantum.XGate(1), channel, MOSSQuantum.RyGate(1, 0.11)])
        circuit_output = circuit * initial
        circuit_reference = circuit * cpu_state(initial, constructor)
        @test MOSSQuantum.storage(circuit_output) isa DemoArray
        @test host_values(circuit_output) ≈ MOSSQuantum.storage(circuit_reference)
    end
    @test host_values(pure) == pure_snapshot
    @test host_values(batch_pure) == batch_snapshot
end

@testset "unknown capabilities fail before mutation" begin
    for initial in demo_states()
        snapshot = host_values(initial)
        @test !MOSSQuantum.supports(MOSSQuantum.CPUBackend(), MOSSQuantum.XGate(1), initial)
        @test !MOSSQuantum.supports(MOSSQuantum.CPUBackend(), MOSSQuantum.ZGate(1), initial; action=:expectation)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.CPUBackend(), MOSSQuantum.XGate(1), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.expectation(MOSSQuantum.CPUBackend(), MOSSQuantum.ZGate(1), initial)
        @test !MOSSQuantum.supports(ArrayBackend(), DemoUnknown(), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(DemoUnknown(), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.HGate(1), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.expectation(MOSSQuantum.XGate(1), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.QubitsTerm(1 => "X") * initial
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.QCircuit([MOSSQuantum.XGate(1), DemoUnknown()]), initial)
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.apply!(MOSSQuantum.QCircuit([MOSSQuantum.XGate(1), MOSSQuantum.HGate(1)]), initial)
        @test_throws ArgumentError MOSSQuantum.apply!(MOSSQuantum.QCircuit([MOSSQuantum.XGate(1), MOSSQuantum.RyGate(2, 0.2)]), initial)
        @test host_values(initial) == snapshot
    end
end

@testset "public linear action and readout backend hooks" begin
    matrix = ComplexF64[0 1; 1 0]
    for (constructor, initial) in zip(CONTAINERS, demo_states())
        snapshot = host_values(initial)
        @test MOSSQuantum.supports(ArrayBackend(), matrix, initial)
        output = MOSSQuantum.apply(ArrayBackend(), matrix, initial)
        expected = initial isa MOSSQuantum.BatchDensityMatrix ?
            cat((matrix * snapshot[:, :, b] for b in axes(snapshot, 3))...; dims=3) : matrix * snapshot
        @test MOSSQuantum.storage(output) isa DemoArray
        @test host_values(output) == expected
        @test !Base.mightalias(MOSSQuantum.storage(output), MOSSQuantum.storage(initial))
        if !(initial isa MOSSQuantum.DensityMatrix)
            @test host_values(matrix * initial) == expected
        end
        @test_throws DimensionMismatch MOSSQuantum.apply(ArrayBackend(), ones(3, 3), initial)
        @test MOSSQuantum.supports(ArrayBackend(), MOSSQuantum.probabilities, initial; action=:probabilities)
        reference = cpu_state(initial, constructor)
        @test MOSSQuantum.probabilities(ArrayBackend(), initial) == MOSSQuantum.probabilities(reference)
        @test MOSSQuantum.probabilities(initial) == MOSSQuantum.probabilities(reference)
        @test MOSSQuantum.probabilities(initial; qubits=Int[]) == MOSSQuantum.probabilities(reference; qubits=Int[])
        @test_throws ArgumentError MOSSQuantum.probabilities(initial; qubits=[1, 1])
        @test_throws ArgumentError MOSSQuantum.probabilities(initial; qubits=[2])
        @test_throws MOSSQuantum.UnsupportedOperation MOSSQuantum.probabilities(MOSSQuantum.CPUBackend(), initial)
        @test host_values(initial) == snapshot
    end
    wide = MOSSQuantum.StateVector(DemoArray(ComplexF64[1, 0, 0, 0]); preserve_storage=true)
    MOSSQuantum.apply!(MOSSQuantum.XGate(2), wide)
    @test host_values(wide) == ComplexF64[0, 0, 1, 0]
    @test MOSSQuantum.probabilities(wide; qubits=[2, 1]) == [0, 1, 0, 0]
    @test MOSSQuantum.probabilities(wide; qubits=[1, 2]) == [0, 0, 1, 0]
end

@testset "external gradient selection stays independent of storage" begin
    objective = DemoRyObjective()
    values = [0.37]
    method = AnalyticRyGradient()
    @test MOSSQuantum.evaluate(objective, values) ≈ cos(0.37)
    @test MOSSQuantum.supports_gradient(method, objective)
    @test !MOSSQuantum.supports_gradient(MOSSQuantum.AdjointGradient(), objective)
    value, gradient = MOSSQuantum.value_and_gradient(method, objective, values)
    @test value ≈ cos(0.37)
    @test gradient ≈ [-sin(0.37)]
    value, back = MOSSQuantum.value_and_pullback(method, objective, values)
    @test value ≈ cos(0.37)
    @test back(1.0) ≈ gradient
    @test back(-2.0) ≈ -2gradient
    values[1] = 0.2
    back(1.0)[1] = 100
    @test back(1.0) ≈ gradient
    @test MOSSQuantum.differentiable_value(method, objective, [0.37]) ≈ cos(0.37)
end

@testset "fixture needs no AD framework" begin
    @test !haskey(Base.loaded_modules, Base.PkgId(Base.UUID("e88e6eb3-aa80-5325-afca-941959d7151f"), "Zygote"))
    @test !haskey(Base.loaded_modules, Base.PkgId(Base.UUID("d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"), "ChainRulesCore"))
end
