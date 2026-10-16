@testset "Dense state ownership controls" begin
    for (data, constructors) in (
        ([1.0, 0.0, 0.0, 0.0],
         (StateVector, x -> StateVector(x, 2), StateVector{Float64},
          x -> StateVector{Float64}(x, 2))),
        ([1.0, 0.0, 0.0, 0.0],
         (DensityMatrix, x -> DensityMatrix(x, 1), DensityMatrix{Float64},
          x -> DensityMatrix{Float64}(x, 1))),
        ([1.0 0.0; 0.0 0.0],
         (DensityMatrix, x -> DensityMatrix(x, 1), DensityMatrix{Float64},
          x -> DensityMatrix{Float64}(x, 1))),
        ([1.0 1.0; 0.0 0.0],
         (BatchStateVector, x -> BatchStateVector(x, 1),
          x -> BatchStateVector(x, 1, 2), x -> BatchStateVector{Float64}(x, 1, 2))),
    )
        for constructor in constructors
            state = constructor(data)
            @test Base.mightalias(storage(state), data)
        end
    end

    for (data, constructor) in (
        ([1.0, 0.0], (x; kwargs...) -> StateVector(x; kwargs...)),
        ([1.0, 0.0, 0.0, 0.0], (x; kwargs...) -> DensityMatrix(x; kwargs...)),
        ([1.0 0.0; 0.0 0.0], (x; kwargs...) -> DensityMatrix(x; kwargs...)),
        ([1.0 1.0; 0.0 0.0], (x; kwargs...) -> BatchStateVector(x; kwargs...)),
    )
        borrowed = constructor(data; copy=false)
        owned = constructor(data; copy=true)
        @test Base.mightalias(storage(borrowed), data)
        @test !Base.mightalias(storage(owned), data)
        before = Base.copy(data)
        storage(owned)[1] = 3
        @test data == before
        data[1] = 2
        @test storage(borrowed)[1] == 2
        @test storage(owned)[1] == 3
    end

    for (original, constructor, default_shares, target) in (
        (StateVector([1.0, 0.0]), StateVector, true, StateVector{Float32}),
        (DensityMatrix([1.0 0.0; 0.0 0.0]), DensityMatrix, true, DensityMatrix{Float32}),
        (BatchStateVector([1.0 1.0; 0.0 0.0]), BatchStateVector, false, BatchStateVector{Float32}),
    )
        @test Base.mightalias(storage(constructor(original)), storage(original)) == default_shares
        @test Base.mightalias(storage(constructor(original; copy=false)), storage(original))
        owned = constructor(original; copy=true)
        copied = Base.copy(original)
        @test !Base.mightalias(storage(owned), storage(original))
        @test !Base.mightalias(storage(copied), storage(original))
        @test storage(owned) == storage(original) == storage(copied)
        @test Base.mightalias(storage(convert(typeof(original), original)), storage(original))
        converted = convert(target, original)
        @test eltype(converted) === Float32
        @test storage(converted) == storage(original)
        @test !Base.mightalias(storage(converted), storage(original))
        storage(owned)[1] = 5
        storage(copied)[1] = 6
        @test storage(original)[1] == 1
    end

    for (data, constructor) in (
        ([1.0, 0.0], (x; kwargs...) -> StateVector{Float32}(x; kwargs...)),
        ([1.0 0.0; 0.0 0.0], (x; kwargs...) -> DensityMatrix{Float32}(x; kwargs...)),
        ([1.0 1.0; 0.0 0.0], (x; kwargs...) -> BatchStateVector{Float32}(x, 1, 2; kwargs...)),
    )
        for flag in (false, true)
            state = constructor(data; copy=flag)
            @test eltype(state) === Float32
            @test !Base.mightalias(storage(state), data)
        end
    end

    # Layout conversion is allowed to allocate even with copy=false.
    backing = ones(4, 2)
    column = view(backing, :, 1)
    @test !Base.mightalias(storage(StateVector(column; copy=false)), backing)
    @test !Base.mightalias(storage(BatchStateVector(view(backing, :, :); copy=false)), backing)
end

@testset "Ownership across state representations" begin
    state = StateVector([1.0, 0.0, 0.0, 0.0])
    borrowed = BatchStateVector(state)
    @test Base.mightalias(storage(borrowed), storage(state))
    @test Base.mightalias(storage(BatchStateVector(state; copy=false)), storage(state))
    @test !Base.mightalias(storage(BatchStateVector(state; copy=true)), storage(state))
    storage(borrowed)[2, 1] = 2
    @test state[2] == 2

    for flag in (nothing, false, true)
        extracted = isnothing(flag) ? StateVector(borrowed, 1) : StateVector(borrowed, 1; copy=flag)
        @test storage(extracted) == storage(state)
        @test !Base.mightalias(storage(extracted), storage(borrowed))
        extracted[1] = 7
        @test storage(borrowed)[1, 1] == 1
    end

    for flag in (false, true)
        density = DensityMatrix(state; copy=flag)
        @test !Base.mightalias(storage(density), storage(state))
        @test storage(density) == storage(state) * storage(state)'
        joined = BatchStateVector([state, Base.copy(state)]; copy=flag)
        @test !Base.mightalias(storage(joined), storage(state))
        @test storage(joined)[:, 1] == storage(state)
    end
end

@testset "Circuit ownership and container returns" begin
    gate = RyGate(1, 0.2; isparas=true)
    operations = AbstractInstruction[gate]
    borrowed = QCircuit(operations)
    explicit_borrow = QCircuit(operations; copy=false)
    owned = QCircuit(operations; copy=true)
    @test borrowed.operations === operations
    @test explicit_borrow.operations === operations
    @test owned.operations !== operations
    @test owned[1] === gate
    push!(operations, XGate(2))
    @test length(borrowed) == 2
    @test length(owned) == 1

    for flag in (false, true)
        for input in ([gate], Any[gate], view(operations, 1:1))
            circuit = QCircuit(input; copy=flag)
            @test circuit.operations !== input
            @test circuit[1] === gate
        end
    end
    @test QCircuit(borrowed).operations !== borrowed.operations
    @test QCircuit(borrowed; copy=false).operations === borrowed.operations
    @test QCircuit(borrowed; copy=true).operations !== borrowed.operations

    nested = QCircuit([gate])
    source = QCircuit(AbstractInstruction[nested, XGate(2)])
    shallow = Base.copy(source)
    @test shallow.operations !== source.operations
    @test shallow[1] === nested
    reset_parameters!(shallow, [0.7])
    @test active_parameters(source) ≈ [0.7]
    independent = MOSS.copy_instruction(source)
    @test independent[1] !== nested
    reset_parameters!(independent, [0.9])
    @test active_parameters(source) ≈ [0.7]
    @test active_parameters(independent) ≈ [0.9]
    repeated = QCircuit([gate, gate])
    independently_repeated = MOSS.copy_instruction(repeated)
    reset_parameters!(independently_repeated, [0.1, 0.3])
    @test active_parameters(independently_repeated) ≈ [0.1, 0.3]
    @test active_parameters(repeated) ≈ [0.7, 0.7]

    circuit = QCircuit()
    @test push!(circuit, XGate(1)) === circuit
    @test push!(circuit, (1, [1.0 0.0; 0.0 1.0])) === circuit
    @test append!(circuit, [YGate(1)]) === circuit
    @test append!(circuit, Any[ZGate(1)]) === circuit
    @test append!(circuit, QCircuit([HGate(1)])) === circuit
    @test length(circuit) == 5
    replacement = XGate(2)
    @test (circuit[1] = replacement) === replacement
    @test circuit[1] === replacement
    term = QubitsTerm(1 => "Z")
    before = collect(circuit)
    for invalid in (Any[XGate(1), term], [HGate(1), term], view(Any[XGate(1), term], :))
        @test_throws ArgumentError append!(circuit, invalid)
        @test collect(circuit) == before
        @test_throws ArgumentError QCircuit(invalid; copy=true)
    end
    @test_throws ArgumentError (circuit[1] = term)
    @test collect(circuit) == before
    count_before = length(circuit)
    @test append!(circuit, circuit) === circuit
    @test length(circuit) == 2 * count_before
    @test empty!(circuit) === circuit
    @test isempty(circuit)
    @test empty!(append!(push!(circuit, XGate(1)), [YGate(1)])) === circuit
end
