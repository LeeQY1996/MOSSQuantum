using Test, MOSS, LinearAlgebra

module GenericStateStorageFixtures
mutable struct Activity
    reads::Int
    transfers::Int
end
Activity() = Activity(0, 0)
struct WrappedArray{T,N} <: AbstractArray{T,N}
    data::Array{T,N}
    activity::Activity
end
WrappedArray(data::Array) = WrappedArray(data, Activity())
Base.size(x::WrappedArray) = size(x.data)
Base.IndexStyle(::Type{<:WrappedArray}) = IndexLinear()
function Base.getindex(x::WrappedArray, indices::Int...)
    x.activity.reads += 1
    return getindex(x.data, indices...)
end
Base.setindex!(x::WrappedArray, value, indices::Int...) = setindex!(x.data, value, indices...)
Base.dataids(x::WrappedArray) = Base.dataids(x.data)
Base.similar(x::WrappedArray, ::Type{T}, dims::Dims) where {T} =
    WrappedArray(similar(x.data, T, dims), x.activity)
Base.reshape(x::WrappedArray, dims::Int...) = WrappedArray(reshape(x.data, dims...), x.activity)
Base.reshape(x::WrappedArray, dims::Tuple{Vararg{Int}}) = reshape(x, dims...)
payload(x) = x
payload(x::WrappedArray) = x.data
payload(x::SubArray) = view(payload(parent(x)), parentindices(x)...)
payload(x::Base.ReshapedArray) = reshape(payload(parent(x)), size(x))
payload(x::Base.Broadcast.Broadcasted) = Base.Broadcast.broadcasted(x.f, map(payload, x.args)...)
payload(x::Base.Broadcast.Extruded) = Base.Broadcast.Extruded(payload(x.x), x.keeps, x.defaults)
Base.copyto!(destination::WrappedArray, source::AbstractArray) =
    (copyto!(destination.data, payload(source)); destination)
Base.copyto!(destination::WrappedArray, source::Base.Broadcast.Broadcasted) =
    (Base.Broadcast.materialize!(destination.data, payload(source)); destination)
function Base.convert(::Type{Array{T,N}}, x::WrappedArray{S,N}) where {T,S,N}
    x.activity.transfers += 1
    return Array{T,N}(x.data)
end
struct ShiftedArray{T,N} <: AbstractArray{T,N}
    data::Array{T,N}
end
Base.size(x::ShiftedArray) = size(x.data)
Base.axes(x::ShiftedArray) = map(dimension -> 0:(dimension - 1), size(x))
Base.getindex(::ShiftedArray, indices...) = error("metadata validation read array payload")
end

using .GenericStateStorageFixtures: WrappedArray, ShiftedArray, payload

@testset "Generic dense storage preserves family and ownership" begin
    shapes = ((StateVector, (4,)), (DensityMatrix, (4, 4)),
        (BatchStateVector, (4, 2)), (BatchDensityMatrix, (4, 4, 2)))
    for T in (Float32, Float64, ComplexF32, ComplexF64), (S, dims) in shapes
        plain = reshape(T.(1:prod(dims)), dims)
        wrapped = WrappedArray(copy(plain))
        state = S(wrapped; preserve_storage=true)
        @test nqubits(state) == 2
        @test eltype(state) === T
        @test eltype(typeof(state)) === T
        @test eltype(S{T}) === T
        @test isconcretetype(typeof(state))
        @test !isconcretetype(S{T})
        @test storage(state) isa WrappedArray
        @test Base.mightalias(storage(state), wrapped)
        @test payload(storage(state)) == plain
        @test wrapped.activity.reads == wrapped.activity.transfers == 0

        shared = S(state; copy=false)
        @test Base.mightalias(storage(shared), storage(state))
        same_domain = convert(S{T}, state)
        @test Base.mightalias(storage(same_domain), storage(state))
        for duplicate in (copy(state), S(state; copy=true), S(wrapped; copy=true, preserve_storage=true))
            @test storage(duplicate) isa WrappedArray
            @test !Base.mightalias(storage(duplicate), storage(state))
            @test payload(storage(duplicate)) == plain
        end
        U = T <: Real ? ComplexF64 : ComplexF32
        if U !== T
            converted = convert(S{U}, state)
            @test eltype(converted) === U
            @test storage(converted) isa WrappedArray
            @test !Base.mightalias(storage(converted), storage(state))
            @test payload(storage(converted)) == U.(plain)
        end
        @test wrapped.activity.reads == wrapped.activity.transfers == 0

        # Ordinary constructors retain historical CPU materialization defaults.
        materialized = S(wrapped)
        @test storage(materialized) isa Array
        @test !Base.mightalias(storage(materialized), storage(state))
        @test payload(storage(materialized)) == plain
        @test wrapped.activity.transfers == 1

        for (result, expected) in ((state + state, plain + plain),
                (state - state, plain - plain), (2 * state, 2 .* plain),
                (state / 2, plain ./ 2))
            @test storage(result) isa WrappedArray
            @test payload(storage(result)) == expected
            @test !Base.mightalias(storage(result), storage(state))
        end
    end
end

@testset "Preserved views retain opt-in aliasing and independent samples" begin
    for (S, dims) in ((StateVector, (4,)), (DensityMatrix, (4, 4)),
            (BatchStateVector, (4, 2)), (BatchDensityMatrix, (4, 4, 2)))
        backing = reshape(collect(1.0:(2prod(dims))), (2dims[1], dims[2:end]...))
        indices = (1:2:size(backing, 1), ntuple(_ -> Colon(), length(dims) - 1)...)
        source = view(backing, indices...)
        state = S(source; preserve_storage=true)
        @test Base.mightalias(storage(state), source)
        @test payload(storage(state)) == source
        @test !Base.mightalias(storage(S(source)), source)
        @test !Base.mightalias(storage(copy(state)), source)
        @test storage(copy(state)) isa Array
    end
    pure = StateVector(WrappedArray(ComplexF32[0.6, 0.8]); preserve_storage=true)
    batch = BatchStateVector(pure)
    @test Base.mightalias(storage(batch), storage(pure))
    @test storage(batch) isa WrappedArray
    for copy_keyword in (false, true)
        sample = StateVector(batch, 1; copy=copy_keyword)
        @test storage(sample) isa WrappedArray
        @test !Base.mightalias(storage(sample), storage(batch))
        @test payload(storage(sample)) == payload(storage(pure))
    end
    density = DensityMatrix(pure)
    @test density.data isa WrappedArray
    @test storage(density) isa WrappedArray
    @test payload(storage(density)) ≈ payload(storage(pure)) * payload(storage(pure))'
    @test !Base.mightalias(storage(density), storage(pure))
    mixed_batch = BatchDensityMatrix(density)
    @test Base.mightalias(storage(mixed_batch), storage(density))
    for copy_keyword in (false, true)
        sample = DensityMatrix(mixed_batch, 1; copy=copy_keyword)
        @test storage(sample) isa WrappedArray
        @test !Base.mightalias(storage(sample), storage(mixed_batch))
        @test payload(storage(sample)) == payload(storage(density))
    end
    outer_products = BatchDensityMatrix(batch)
    @test storage(outer_products) isa WrappedArray
    @test payload(storage(outer_products))[:, :, 1] ≈ payload(storage(density))
    @test !Base.mightalias(storage(outer_products), storage(batch))
    @test storage(BatchStateVector([pure, pure])) isa WrappedArray
    @test storage(BatchDensityMatrix([density, density])) isa WrappedArray
    for state in (pure, batch, density, mixed_batch)
        before = copy(payload(storage(state)))
        operation = state isa DensityMatrix ? schmidt_numbers : reset!
        @test_throws UnsupportedOperation operation(state)
        @test payload(storage(state)) == before
    end
    @test_throws UnsupportedOperation cat(pure, pure)
    @test_throws UnsupportedOperation cat(density, density)
    @test_throws DimensionMismatch StateVector(0) + StateVector(2)
    @test_throws DimensionMismatch DensityMatrix(0) - DensityMatrix(2)
end

@testset "Storage metadata validation precedes allocation and payload access" begin
    for (S, dims, valid_dims) in ((StateVector, (3,), (4,)),
            (DensityMatrix, (3, 3), (4, 4)), (BatchStateVector, (3, 2), (4, 2)),
            (BatchDensityMatrix, (3, 3, 2), (4, 4, 2)))
        bad = WrappedArray(zeros(dims))
        @test_throws ArgumentError S(bad; preserve_storage=true)
        @test bad.activity.reads == bad.activity.transfers == 0
        shifted = ShiftedArray(zeros(valid_dims))
        @test_throws ArgumentError S(shifted; preserve_storage=true)
        @test_throws ArgumentError S(shifted)
    end
    for n in (0, 2), B in (0, 1)
        pure = BatchStateVector(WrappedArray(ones(ComplexF32, 2^n, B)); preserve_storage=true)
        mixed = BatchDensityMatrix(pure)
        @test storage(mixed) isa WrappedArray
        @test size(storage(mixed)) == (2^n, 2^n, B)
        @test size(storage(copy(mixed))) == (2^n, 2^n, B)
    end
    for S in (StateVector, DensityMatrix)
        @test_throws ArgumentError S(zeros(4), -1; preserve_storage=true)
    end
    for S in (BatchStateVector, BatchDensityMatrix)
        source = S === BatchStateVector ? zeros(2, 1) : zeros(2, 2, 1)
        @test_throws ArgumentError S(source, 1, -1; preserve_storage=true)
    end
end
