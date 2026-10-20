using Test, MOSS, Zygote, LinearAlgebra, Random

@testset "Storage-preserving constructors retain AD domains" begin
    rng = MersenneTwister(20261020)
    constructors = (StateVector, DensityMatrix, BatchStateVector, BatchDensityMatrix)
    shapes = ((4,), (4, 4), (4, 3), (4, 4, 3))
    for T in (Float32, Float64, ComplexF32, ComplexF64), (constructor, shape) in zip(constructors, shapes), copied in (false, true)
        data = randn(rng, T, shape)
        before = copy(data)
        loss(values) = sum(abs2, storage(constructor(values; copy=copied, preserve_storage=true)))
        gradient = Zygote.gradient(loss, data)[1]
        @test gradient ≈ 2 .* data
        @test size(gradient) == shape
        @test eltype(gradient) === T
        @test data == before
    end
    for T in (Float32, ComplexF32), (constructor, shape) in zip(constructors, shapes)
        data = randn(rng, T, shape)
        loss(values) = sum(abs2, storage(constructor{ComplexF64}(
            constructor(values; preserve_storage=true))))
        gradient = Zygote.gradient(loss, data)[1]
        @test gradient ≈ 2 .* data
        @test eltype(gradient) === T
    end
    # Views remain a constructor option while projected cotangents have the
    # original numerical shape/domain and do not modify the parent buffer.
    for (constructor, shape) in zip(constructors, shapes)
        parent_data = randn(rng, ComplexF64, prod(shape) + 2)
        data = reshape(view(parent_data, 2:length(parent_data)-1), shape)
        before = copy(parent_data)
        gradient = Zygote.gradient(values -> sum(abs2, storage(constructor(values;
            preserve_storage=true))), data)[1]
        @test gradient ≈ 2 .* data
        @test size(gradient) == shape
        @test parent_data == before
    end
end

module ForeignCotangentFixtures
using MOSS, Test

# Metadata is available, but a CPU pullback must reject this storage before
# reading a value or attempting any implicit host transfer.
struct ForeignArray{T,N} <: AbstractArray{T,N}
    values::Array{T,N}
    reads::Base.RefValue{Int}
    writes::Base.RefValue{Int}
    transfers::Base.RefValue{Int}
    copies::Base.RefValue{Int}
end
ForeignArray(values::Array{T,N}) where {T,N} =
    ForeignArray{T,N}(values, Ref(0), Ref(0), Ref(0), Ref(0))
Base.size(data::ForeignArray) = size(data.values)
Base.IndexStyle(::Type{<:ForeignArray}) = IndexLinear()
Base.getindex(data::ForeignArray, indices...) = (data.reads[] += 1; error("foreign scalar read"))
Base.setindex!(data::ForeignArray, value, indices...) = (data.writes[] += 1; error("foreign scalar write"))
Base.copy(data::ForeignArray) = (data.copies[] += 1; error("foreign copy"))
_host_transfer(data::ForeignArray) = (data.transfers[] += 1; error("foreign host transfer"))
Base.Array(data::ForeignArray) = _host_transfer(data)
Base.Array{T}(data::ForeignArray) where {T} = _host_transfer(data)
Base.Array{T,N}(data::ForeignArray) where {T,N} = _host_transfer(data)
Base.collect(data::ForeignArray) = _host_transfer(data)

function rejected(back, data::ForeignArray, wrapped; wrapped_error=ArgumentError)
    before = copy(data.values)
    @test_throws ArgumentError back(data)
    @test_throws wrapped_error back(wrapped)
    @test data.values == before
    @test data.reads[] == 0
    @test data.writes[] == 0
    @test data.transfers[] == 0
    @test data.copies[] == 0
end

function host_view(data::Array)
    parent = zeros(eltype(data), length(data) + 2)
    view_data = reshape(view(parent, 2:length(parent)-1), size(data))
    view_data .= data
    return view_data
end

wrap_like(data, state::MOSS.StateVector) = MOSS.StateVector(data; preserve_storage=true)
wrap_like(data, state::MOSS.DensityMatrix) = MOSS.DensityMatrix(data; preserve_storage=true)
wrap_like(data, state::MOSS.BatchStateVector) = MOSS.BatchStateVector(data; preserve_storage=true)
wrap_like(data, state::MOSS.BatchDensityMatrix) = MOSS.BatchDensityMatrix(data; preserve_storage=true)
end

@testset "CPU pullbacks reject foreign cotangents before access" begin
    fixtures = ForeignCotangentFixtures
    pure = BatchStateVector(ComplexF64[1 0; 0 1])
    mixed = BatchDensityMatrix(pure)
    pure_before, mixed_before = copy(storage(pure)), copy(storage(mixed))
    unitary = QCircuit([RyGate(1, 0.31; isparas=true)])
    noisy = QCircuit([RyGate(1, 0.31; isparas=true), AmplitudeDamping(1; γ=1.0)])

    @testset "Batch circuit and observation seeds" begin
        for initial in (pure, mixed), circuit in (unitary, noisy)
            output, back = MOSS._batch_circuit_adjoint(circuit, initial)
            output_before = copy(storage(output))
            seed = ones(ComplexF64, size(storage(output)))
            foreign = fixtures.ForeignArray(copy(seed))
            fixtures.rejected(back, foreign, fixtures.wrap_like(foreign, output);
                wrapped_error=MOSS.UnsupportedOperation)
            expected_parameters, expected_state = back(seed)
            parameters, state = back(fixtures.host_view(seed))
            @test parameters ≈ expected_parameters
            @test storage(state) ≈ storage(expected_state)
            @test storage(output) == output_before
        end
        for initial in (pure, mixed)
            values, back = MOSS._batch_expectation_adjoint(QubitsTerm(1 => "Z"), initial)
            foreign = fixtures.ForeignArray(ComplexF64[0.5, -0.2im])
            before = copy(foreign.values)
            @test_throws ArgumentError back(foreign)
            @test foreign.values == before
            @test foreign.reads[] == foreign.writes[] == foreign.transfers[] == foreign.copies[] == 0
            seed = copy(foreign.values)
            @test storage(back(fixtures.host_view(seed))[2]) ≈ storage(back(seed)[2])
            @test values ≈ [1, -1]
        end
        @test storage(pure) == pure_before
        @test storage(mixed) == mixed_before
    end

    @testset "Encoding and scalar contraction seeds" begin
        inputs = [0.12 -0.2; 0.3 0.07]
        before = copy(inputs)
        output, back = MOSS._batch_qubit_encoding_adjoint(ComplexF64, inputs)
        seed = ones(ComplexF64, size(storage(output)))
        foreign = fixtures.ForeignArray(copy(seed))
        fixtures.rejected(back, foreign, BatchStateVector(foreign; preserve_storage=true);
            wrapped_error=MOSS.UnsupportedOperation)
        @test back(fixtures.host_view(seed)) ≈ back(seed)
        @test inputs == before

        output, back = MOSS._qubit_encoding_adjoint(ComplexF64, inputs[:, 1])
        seed = ones(ComplexF64, size(storage(output)))
        foreign = fixtures.ForeignArray(copy(seed))
        fixtures.rejected(back, foreign, StateVector(foreign; preserve_storage=true);
            wrapped_error=MOSS.UnsupportedOperation)
        @test back(fixtures.host_view(seed))[2] ≈ back(seed)[2]

        host = DensityMatrix(ComplexF64, 1)
        host_before = copy(storage(host))
        foreign = fixtures.ForeignArray(ComplexF64[1, 0, 0, 0])
        state = DensityMatrix(foreign; preserve_storage=true)
        @test_throws MOSS.UnsupportedOperation expectation(state, XGate(1), host)
        @test_throws MOSS.UnsupportedOperation expectation(host, XGate(1), state)
        @test foreign.values == [1, 0, 0, 0]
        @test foreign.reads[] == foreign.writes[] == foreign.transfers[] == foreign.copies[] == 0
        @test storage(host) == host_before
    end

    @testset "Postselection scatter seeds" begin
        initial = StateVector(ComplexF64[1, 2im, 3, 4im])
        before = copy(storage(initial))
        for operation in (MOSS._apply_throw_impl, MOSS._apply_keep_impl)
            output, back = Zygote.pullback(operation, QSelect(1, 0), initial)
            output_before = copy(storage(output))
            seed = ones(ComplexF64, size(storage(output)))
            foreign = fixtures.ForeignArray(copy(seed))
            fixtures.rejected(back, foreign, StateVector(foreign; preserve_storage=true);
                wrapped_error=MOSS.UnsupportedOperation)
            @test back(fixtures.host_view(seed))[2] ≈ back(seed)[2]
            @test storage(output) == output_before
        end
        @test storage(initial) == before
    end

    @testset "Constructor projections and sample scatter seeds" begin
        constructors = (StateVector, DensityMatrix, BatchStateVector, BatchDensityMatrix)
        shapes = ((2,), (2, 2), (2, 2), (2, 2, 2))
        for (constructor, shape) in zip(constructors, shapes)
            source = ones(ComplexF64, shape)
            before = copy(source)
            output, back = Zygote.pullback(values -> constructor(values; preserve_storage=true), source)
            foreign = fixtures.ForeignArray(ones(ComplexF64, shape))
            fixtures.rejected(back, foreign, constructor(foreign; preserve_storage=true))
            @test back(fixtures.host_view(copy(source)))[1] ≈ source
            @test source == before
        end
        # Even a host view that is unsuitable for CPU kernels must reject a
        # foreign seed before ProjectTo can silently materialize it on the CPU.
        parent = ones(ComplexF64, 4)
        source = view(parent, 1:2:4)
        _, back = Zygote.pullback(values -> StateVector(values; preserve_storage=true), source)
        foreign = fixtures.ForeignArray(ones(ComplexF64, 2))
        fixtures.rejected(back, foreign, StateVector(foreign; preserve_storage=true))
        @test parent == ones(4)

        for initial in (pure, mixed)
            sample_constructor = initial isa BatchStateVector ? StateVector : DensityMatrix
            output, back = Zygote.pullback(state -> sample_constructor(state, 1), initial)
            seed = ones(ComplexF64, size(storage(output)))
            foreign = fixtures.ForeignArray(copy(seed))
            fixtures.rejected(back, foreign, fixtures.wrap_like(foreign, output))
            @test storage(back(fixtures.host_view(seed))[1]) ≈ storage(back(seed)[1])
        end
        # Typed state conversion shares the projection boundary with array
        # constructors and must reject the same foreign numerical cotangent.
        initial = StateVector(Float32[1, 0])
        _, back = Zygote.pullback(state -> StateVector{ComplexF64}(state), initial)
        foreign = fixtures.ForeignArray(ComplexF64[1, 1])
        fixtures.rejected(back, foreign, StateVector(foreign; preserve_storage=true))
        @test eltype(back(ComplexF64[1, 1])[1]) === Float32
        @test storage(initial) == Float32[1, 0]
    end

    @testset "Pure-to-density and density-list seeds" begin
        list = [DensityMatrix(StateVector(pure, 1)), DensityMatrix(StateVector(pure, 2))]
        list_before = copy.(storage.(list))
        for initial in (pure, list)
            output, back = Zygote.pullback(BatchDensityMatrix, initial)
            seed = ones(ComplexF64, size(storage(output)))
            foreign = fixtures.ForeignArray(copy(seed))
            fixtures.rejected(back, foreign, BatchDensityMatrix(foreign; preserve_storage=true))
            expected = back(seed)[1]
            actual = back(fixtures.host_view(seed))[1]
            if initial isa BatchStateVector
                @test storage(actual) ≈ storage(expected)
            else
                @test all(isapprox.(storage.(actual), storage.(expected)))
            end
        end
        @test storage(pure) == pure_before
        @test storage.(list) == list_before

        # The CPU-only projection restriction does not claim that an external
        # array's own AD projection must use host storage.
        foreign = fixtures.ForeignArray(ComplexF64[1, 2])
        extension = Base.get_extension(MOSS, :MOSSZygoteExt)
        @test isnothing(extension._check_cpu_array_cotangent(foreign, foreign))
        @test foreign.reads[] == foreign.writes[] == foreign.transfers[] == foreign.copies[] == 0
    end
end

@testset "Preserved host views keep selected gradient methods" begin
    angle = [0.31]
    circuit = QCircuit([RyGate(1, 0.0; isparas=true)])
    observed = QubitsTerm(1 => "Z")
    pure_parent = [0.0, 1.0, 0.0, 0.0]
    pure = StateVector(view(pure_parent, 2:3); preserve_storage=true)
    density_parent = zeros(6)
    density_parent[2] = 1
    mixed = DensityMatrix(view(density_parent, 2:5), 1; preserve_storage=true)
    batch_parent = zeros(2, 4)
    batch_parent[1, :] .= 1
    batch = BatchStateVector(view(batch_parent, :, 2:3); preserve_storage=true)
    density_batch_parent = zeros(2, 2, 4)
    density_batch_parent[1, 1, :] .= 1
    density_batch = BatchDensityMatrix(view(density_batch_parent, :, :, 2:3); preserve_storage=true)
    for state in (pure, mixed, batch, density_batch)
        objective = state isa Union{StateVector,DensityMatrix} ?
            ExpectationObjective(circuit, observed, state) :
            BatchExpectationObjective(circuit, observed, state)
        method = AdjointGradient()
        @test supports_gradient(method, objective)
        value, gradient = value_and_gradient(method, objective, angle)
        @test value ≈ cos(angle[1])
        @test gradient ≈ [-sin(angle[1])]
        @test Zygote.gradient(values -> differentiable_value(method, objective, values), angle)[1] ≈ gradient
        @test storage(state)[1] == 1
    end
end
