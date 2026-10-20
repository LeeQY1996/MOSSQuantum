module StorageBackendRoutingFixtures
using MOSS, Random
struct Registered end
struct Unregistered end
struct GuardedArray{T,N,B} <: AbstractArray{T,N}
    values::Array{T,N}
    reads::Base.RefValue{Int}
    writes::Base.RefValue{Int}
    copies::Base.RefValue{Int}
end
GuardedArray(values::Array{T,N}, ::Type{B}) where {T,N,B} =
    GuardedArray{T,N,B}(values, Ref(0), Ref(0), Ref(0))
Base.size(data::GuardedArray) = size(data.values)
Base.IndexStyle(::Type{<:GuardedArray}) = IndexLinear()
Base.getindex(data::GuardedArray, indices...) = (data.reads[] += 1; error("scalar indexing is forbidden"))
Base.setindex!(data::GuardedArray, value, indices...) = (data.writes[] += 1; error("scalar writes are forbidden"))
function Base.copy(data::GuardedArray{T,N,B}) where {T,N,B}
    data.copies[] += 1
    return GuardedArray{T,N,B}(copy(data.values), data.reads, data.writes, data.copies)
end
function Base.reshape(data::GuardedArray{T,N,B}, dims::Int...) where {T,N,B}
    values = reshape(data.values, dims...)
    return GuardedArray{T,length(dims),B}(values, data.reads, data.writes, data.copies)
end
Base.similar(data::GuardedArray{T,N,B}, ::Type{S}, dims::Dims) where {T,N,B,S} =
    GuardedArray(Array{S}(undef, dims), B)

Base.copyto!(destination::GuardedArray, source::GuardedArray) = (copyto!(destination.values, source.values); destination)

struct ProbeBackend <: MOSS.AbstractBackend end
const RegisteredPure = MOSS.StateVector{T,A} where {T<:Number,A<:GuardedArray{T,1,Registered}}
MOSS.backend(::RegisteredPure) = ProbeBackend()
# A legacy backend can own whole nested circuits and measurement instructions
# without accepting RNG keywords or implementing the recorded measure! hook.
struct LegacyBackend <: MOSS.AbstractBackend
    events::Vector{Symbol}
end
MOSS.supports(::LegacyBackend, ::Union{MOSS.XGate,MOSS.QMeasure}, ::RegisteredPure;
              action::Symbol=:apply) = action === :apply
function MOSS.apply!(backend::LegacyBackend, gate::MOSS.XGate, state::RegisteredPure)
    push!(backend.events, :gate)
    return MOSS.apply!(ProbeBackend(), gate, state)
end
function MOSS.apply!(backend::LegacyBackend, ::MOSS.QCircuit, state::RegisteredPure)
    push!(backend.events, :circuit)
    return state
end
function MOSS.apply!(backend::LegacyBackend, ::MOSS.QMeasure, ::RegisteredPure)
    push!(backend.events, :measurement)
    return 0, 1.0
end

MOSS.supports(::ProbeBackend, ::MOSS.XGate, ::RegisteredPure; action::Symbol=:apply) = action === :apply
MOSS.supports(::ProbeBackend, ::MOSS.ZGate, ::RegisteredPure; action::Symbol=:apply) = action === :expectation
function MOSS.apply!(::ProbeBackend, gate::MOSS.XGate, state::RegisteredPure)
    MOSS.validate_positions(gate, MOSS.nqubits(state))
    data = MOSS.storage(state).values
    data[1], data[2] = data[2], data[1]
    return state
end
MOSS.expectation(::ProbeBackend, ::MOSS.ZGate, state::RegisteredPure) =
    abs2(MOSS.storage(state).values[1]) - abs2(MOSS.storage(state).values[2])
MOSS.probabilities(::ProbeBackend, state::RegisteredPure; qubits=1:MOSS.nqubits(state)) =
    abs2.(MOSS.storage(state).values)
function MOSS.measure!(::ProbeBackend, state::RegisteredPure, position::Int;
                       auto_reset::Bool=true, rng=Random.default_rng())
    MOSS.validate_positions(MOSS.QMeasure(position), MOSS.nqubits(state))
    return 0, 1.0
end
function MOSS.apply(::ProbeBackend, operator::MOSS.QubitsTerm, state::RegisteredPure)
    result = copy(state)
    result.data.values .*= MOSS.coeff(operator)
    return result
end
end

@testset "Dense storage selects and guards execution backends" begin
    fixtures = StorageBackendRoutingFixtures
    for (make_state, data) in (
        (a -> StateVector(a, 1; preserve_storage=true), ComplexF64[1, 0]),
        (a -> DensityMatrix(a, 1; preserve_storage=true), ComplexF64[1, 0, 0, 0]),
        (a -> BatchStateVector(a, 1, 2; preserve_storage=true), ComplexF64[1 1; 0 0]),
        (a -> BatchDensityMatrix(a, 1, 2; preserve_storage=true), reshape(ComplexF64[1,0,0,0,1,0,0,0], 2,2,2)))
        guarded = fixtures.GuardedArray(data, fixtures.Unregistered)
        state = make_state(guarded)
        operation = XGate(1)
        observable = QubitsTerm(1 => "Z")
        circuit = QCircuit([operation])
        @test !supports(CPUBackend(), operation, state)
        @test !supports(CPUBackend(), circuit, state)
        @test !supports(CPUBackend(), observable, state; action=:expectation)
        @test !supports(CPUBackend(), probabilities, state; action=:probabilities)
        @test_throws ArgumentError MOSS.backend(state)
        @test_throws ArgumentError apply!(operation, state)
        @test_throws ArgumentError expectation(observable, state)
        @test_throws ArgumentError circuit * state
        @test_throws ArgumentError observable * state
        @test_throws ArgumentError probabilities(state)
        @test_throws ArgumentError sample(MersenneTwister(1), state, 1)
        @test_throws ArgumentError counts(MersenneTwister(1), state, 1)
        @test_throws ArgumentError measure!(state, 1)
        @test_throws UnsupportedOperation apply!(CPUBackend(), operation, state)
        @test_throws UnsupportedOperation apply!(CPUBackend(), circuit, state)
        @test_throws UnsupportedOperation expectation(CPUBackend(), observable, state)
        @test_throws UnsupportedOperation MOSS.apply(CPUBackend(), observable, state)
        @test_throws UnsupportedOperation probabilities(CPUBackend(), state)
        @test_throws UnsupportedOperation measure!(CPUBackend(), state, 1)
        @test_throws UnsupportedOperation simulate(circuit, state; backend=CPUBackend())
        @test_throws UnsupportedOperation partial_tr(state, [1])
        @test guarded.reads[] == 0
        @test guarded.writes[] == 0
        @test guarded.copies[] == 0
    end

    @testset "Registered array-backed states use their own public backend" begin
        guarded = fixtures.GuardedArray(ComplexF64[1,0], fixtures.Registered)
        state = StateVector(guarded, 1; preserve_storage=true)
        @test MOSS.backend(state) isa fixtures.ProbeBackend
        @test !supports(CPUBackend(), XGate(1), state)
        @test expectation(ZGate(1), state) == 1
        @test probabilities(state) == [1, 0]
        @test apply!(XGate(1), state) === state
        @test expectation(ZGate(1), state) == -1
        @test expectation(ZGate(1), QCircuit([XGate(1)]) * state) == 1
        @test state.data.values == [0, 1]
        @test MOSS.measure!(state, 1) == (0, 1.0)
        scaled = QubitsTerm(1 => "Z"; coeff=2.0) * state
        @test scaled.data.values == 2 .* state.data.values
        @test scaled.data !== state.data
        template = QCircuit([XGate(1)])
        objective = ExpectationObjective(template, ZGate(1), state)
        @test evaluate(objective, Float64[]) == 1
        @test !supports_gradient(AdjointGradient(), objective)
        @test_throws UnsupportedGradient value_and_gradient(AdjointGradient(), objective, Float64[])
        forced_cpu = ExpectationObjective(template, ZGate(1), state; backend=CPUBackend())
        @test !supports_gradient(AdjointGradient(), forced_cpu)
        @test_throws UnsupportedGradient value_and_pullback(AdjointGradient(), forced_cpu, Float64[])
        before = copy(state.data.values)
        @test_throws UnsupportedOperation apply!(QCircuit([XGate(1), HGate(1)]), state)
        @test state.data.values == before
        @test_throws UnsupportedOperation apply!(CPUBackend(), XGate(1), state)
        @test guarded.reads[] == 0
        @test guarded.writes[] == 0

        legacy = fixtures.LegacyBackend(Symbol[])
        nested = QCircuit([XGate(1), QCircuit([XGate(1)]), QMeasure(1), XGate(1)])
        # Exercise the generic public circuit adapter while allowing nested
        # dispatch to select the backend's more specific public hook.
        output = invoke(apply!, Tuple{MOSS.AbstractBackend,QCircuit,MOSS.AbstractQuantumState},
                        legacy, nested, state)
        @test output === state
        @test legacy.events == [:gate, :circuit, :measurement, :gate]
        @test state.data.values == before
        @test guarded.reads[] == guarded.writes[] == 0
    end

    @testset "CPU layout support is deliberately conservative" begin
        data = ComplexF64[1, 0, 0, 0, 0, 0, 0, 0]
        contiguous = StateVector(view(data, 1:4), 2; preserve_storage=true)
        @test MOSS.backend(contiguous) isa CPUBackend
        @test supports(CPUBackend(), probabilities, contiguous; action=:probabilities)
        @test !supports(CPUBackend(), probabilities, contiguous; action=:apply)
        @test !supports(CPUBackend(), probabilities, contiguous; action=:expectation)
        for state in (StateVector(1), DensityMatrix(1), BatchStateVector(1,2), BatchDensityMatrix(1,2))
            @test supports(CPUBackend(), probabilities, state; action=:probabilities)
            @test !supports(CPUBackend(), probabilities, state; action=:apply)
        end
        @test apply!(XGate(2), contiguous) === contiguous
        @test data[3] == 1
        @test probabilities(contiguous) == [0, 0, 1, 0]
        @test expectation(QubitsTerm(2 => "Z"), contiguous) == -1
        stepped = StateVector(view(data, 1:2:7), 2; preserve_storage=true)
        @test !supports(CPUBackend(), XGate(1), stepped)
        @test_throws ArgumentError MOSS.backend(stepped)
        @test_throws UnsupportedOperation apply!(CPUBackend(), XGate(1), stepped)
        repeated = BatchStateVector(view(reshape(data, 4, 2), :, [1, 1]), 2, 2; preserve_storage=true)
        @test !supports(CPUBackend(), XGate(1), repeated)
        @test_throws ArgumentError MOSS.backend(repeated)
        @test_throws UnsupportedOperation apply!(CPUBackend(), XGate(1), repeated)
    end
end
