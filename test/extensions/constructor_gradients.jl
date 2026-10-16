using Test, MOSS, Zygote

@testset "Gradients through explicit constructor copy controls" begin
    observable = QubitsTerm(1 => "Z")
    pure_constructors = (
        (data, owned) -> StateVector(data; copy=owned),
        (data, owned) -> StateVector(data, 1; copy=owned),
        (data, owned) -> StateVector{ComplexF64}(data; copy=owned),
        (data, owned) -> StateVector{ComplexF64}(data, 1; copy=owned),
    )
    for data in (Float32[0.6, 0.8], ComplexF64[0.6, 0.8im])
        for (index, constructor) in enumerate(pure_constructors), owned in (false, true)
            @testset "Pure constructor $index, copy=$owned, $(eltype(data))" begin
                original = copy(data)
                loss(values) = real(expectation(observable, constructor(values, owned)))
                gradient = Zygote.gradient(loss, data)[1]
                @test gradient ≈ 2 .* [data[1], -data[2]]
                @test eltype(gradient) == eltype(data)
                @test data == original
            end
        end
        for owned in (false, true)
            original = copy(data)
            loss(values) = real(expectation(observable,
                DensityMatrix(StateVector(values; copy=owned); copy=owned)))
            gradient = Zygote.gradient(loss, data)[1]
            @test gradient ≈ 2 .* [data[1], -data[2]]
            @test eltype(gradient) == eltype(data)
            @test data == original
        end
        for wrap in (state -> StateVector(state),
                     state -> StateVector(state; copy=false),
                     state -> StateVector(state; copy=true), Base.copy)
            original = copy(data)
            loss(values) = real(expectation(observable, wrap(StateVector(values))))
            gradient = Zygote.gradient(loss, data)[1]
            @test gradient ≈ 2 .* [data[1], -data[2]]
            @test eltype(gradient) == eltype(data)
            @test data == original
        end
    end

    mixed_constructors = (
        (data, owned) -> DensityMatrix(data; copy=owned),
        (data, owned) -> DensityMatrix(data, 1; copy=owned),
        (data, owned) -> DensityMatrix{ComplexF64}(data; copy=owned),
        (data, owned) -> DensityMatrix{ComplexF64}(data, 1; copy=owned),
    )
    for matrix in (Float64[0.7 0.1; 0.1 0.3], ComplexF64[0.7 0.1im; -0.1im 0.3])
        for data in (matrix, vec(matrix))
            for (index, constructor) in enumerate(mixed_constructors), owned in (false, true)
                @testset "Mixed constructor $index, copy=$owned, $(typeof(data))" begin
                    original = copy(data)
                    loss(values) = real(expectation(observable, constructor(values, owned)))
                    gradient = Zygote.gradient(loss, data)[1]
                    expected = reshape(eltype(data)[1, 0, 0, -1], size(data))
                    @test gradient ≈ expected
                    @test eltype(gradient) == eltype(data)
                    @test size(gradient) == size(data)
                    @test data == original
                end
            end
            for wrap in (state -> DensityMatrix(state),
                         state -> DensityMatrix(state; copy=false),
                         state -> DensityMatrix(state; copy=true), Base.copy)
                original = copy(data)
                loss(values) = real(expectation(observable, wrap(DensityMatrix(values))))
                gradient = Zygote.gradient(loss, data)[1]
                @test gradient ≈ reshape(eltype(data)[1, 0, 0, -1], size(data))
                @test eltype(gradient) == eltype(data)
                @test size(gradient) == size(data)
                @test data == original
            end
        end
    end
end
