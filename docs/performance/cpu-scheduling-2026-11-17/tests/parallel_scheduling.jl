using Test, Random, LinearAlgebra, MOSSQuantum

module ParallelSchedulingFixtures
function embed_gate(n, positions, local_matrix)
    full = zeros(eltype(local_matrix), 2^n, 2^n)
    for input in 0:(2^n - 1)
        local_input = sum(((input >> (q - 1)) & 1) << (axis - 1)
                          for (axis, q) in enumerate(positions))
        for local_output in 0:(2^length(positions) - 1)
            output = input
            for (axis, q) in enumerate(positions)
                output = (output & ~(1 << (q - 1))) |
                         (((local_output >> (axis - 1)) & 1) << (q - 1))
            end
            full[output + 1, input + 1] = local_matrix[local_output + 1, local_input + 1]
        end
    end
    return full
end
end

@testset "Bounded CPU scheduling" begin
    task_count = MOSSQuantum._parallel_task_count
    run = MOSSQuantum.parallel_run
    available = Threads.nthreads()

    @testset "Work grain and task budget" begin
        @test task_count(0, 16, 1024, 16) == 1
        @test task_count(1023, 16, 1024, 16) == 1
        @test task_count(1024, 16, 1024, 16) == 1
        @test task_count(2047, 16, 1024, 16) == 1
        @test task_count(2048, 16, 1024, 16) == min(2, available)
        @test task_count(8192, 16, 1024, 16) == min(8, available)
        @test task_count(8192, 16, 1024, 3) == min(3, available)
        @test task_count(8192, 2, 1024, 16) == min(2, available)
        @test task_count(typemax(Int), 16, 1, 16) == min(16, available)
        for invalid in ((-1, 4, 1, 4), (10, 0, 1, 4), (10, 4, 0, 4),
                        (10, 4, 1, 0), (10, -1, 1, 4), (10, 4, -1, 4))
            @test_throws ArgumentError task_count(invalid...)
        end
    end

    @testset "Complete disjoint partitions and direct caller path" begin
        for total in (0, 1, 7, 17, 1025), cap in (1, 2, 3, 16)
            visits = zeros(Int, total)
            chunks = Channel{Tuple{Int,Int,Task}}(max(1, available))
            caller = current_task()
            function visit(first, last, counts, events)
                put!(events, (first, last, current_task()))
                for index in first:last
                    counts[index + 1] += 1
                end
                return counts
            end
            run(total, 16, visit, visits, chunks; min_work=1, max_tasks=cap)
            close(chunks)
            actual = collect(chunks)
            expected = task_count(total, 16, 1, cap)
            @test length(actual) == expected
            @test all(==(1), visits)
            @test length(unique(item[3] for item in actual)) == expected
            intervals = sort([(first, last) for (first, last, _) in actual])
            @test intervals == [(div(total * i, expected), div(total * (i + 1), expected) - 1)
                                for i in 0:(expected - 1)]
            @test total == 0 || all(first <= last for (first, last) in intervals)
            if expected == 1
                @test only(actual)[3] === caller
            else
                @test all(item[3] !== caller for item in actual)
            end
        end
        token = Ref(:returned)
        @test run(9, 16, (first, last) -> token; min_work=10) === token
        failure = ArgumentError("direct caller failure")
        caught = try
            run(9, 16, (first, last) -> throw(failure); min_work=10)
        catch error
            error
        end
        @test caught === failure
    end

    @testset "Spawn callers and nested calls retain a bounded task set" begin
        function observe_from_spawn()
            events = Channel{Task}(available)
            run(37, 16, (first, last) -> put!(events, current_task()); min_work=1, max_tasks=3)
            close(events)
            return collect(events)
        end
        spawned = fetch(Threads.@spawn observe_from_spawn())
        @test length(spawned) == task_count(37, 16, 1, 3)
        @test length(unique(spawned)) == length(spawned)

        inline_events = Channel{Task}(available)
        run(1, 16, (first, last) -> run(31, 16, (inner_first, inner_last) ->
            put!(inline_events, current_task()); min_work=1, max_tasks=3); min_work=2)
        close(inline_events)
        @test length(collect(inline_events)) == task_count(31, 16, 1, 3)

        events = Channel{Tuple{Task,Task,Int,Int}}(available)
        function outer(first, last)
            owner = current_task()
            run(31, 16, (inner_first, inner_last) ->
                put!(events, (owner, current_task(), inner_first, inner_last)); min_work=1)
        end
        run(37, 16, outer; min_work=1, max_tasks=4)
        close(events)
        nested = collect(events)
        @test length(nested) == task_count(37, 16, 1, 4)
        @test all(owner === inner && first == 0 && last == 30
                  for (owner, inner, first, last) in nested)
        @test length(unique(item[1] for item in nested)) == length(nested)
    end

    @testset "Worker failures finish the other chunks before returning" begin
        count = task_count(37, 16, 1, 4)
        finished = zeros(Int, 37)
        failed = Channel{Nothing}(1)
        function fail_one(first, last)
            if first == 0
                put!(failed, nothing)
                error("scheduled worker failure")
            end
            fetch(failed)
            sleep(0.02)
            finished[first + 1] = 1
        end
        caught = try
            run(37, 16, fail_one; min_work=1, max_tasks=4)
        catch error
            error
        end
        @test caught isa (count == 1 ? ErrorException : CompositeException)
        @test sum(finished) == count - 1
        if count > 1
            @test length(caught.exceptions) == 1
            @test all(finished[div(37 * i, count) + 1] == 1 for i in 1:(count - 1))
        end
        @test run(1, 1, (first, last) -> :usable) === :usable
    end
end

@testset "Scheduled gate kernels preserve complex amplitudes and ownership" begin
    rng = MersenneTwister(171126)
    n = 19
    gates = [RxGate(1, 0.23), RyGate(4, -0.71), RzGate(n, 0.43),
             CNOTGate(1, n), CNOTGate(n, 1), CNOTGate(2, 3), CZGate(1, n),
             PHASEGate(n, -0.39), XGate(1), SWAPGate(1, n), iSWAPGate(2, n - 1)]
    for scalar in (ComplexF32, ComplexF64)
        data = normalize!(randn(rng, scalar, 2^n))
        absolute_tolerance = scalar === ComplexF64 ? 1e-13 : 1e-7
        relative_tolerance = scalar === ComplexF64 ? 1e-12 : 2e-6
        expected = StateVector(copy(data))
        for gate in gates
            MOSSQuantum.apply_serial!(gate, expected)
            actual = StateVector(copy(data))
            owner = storage(actual)
            single_expected = StateVector(copy(data))
            MOSSQuantum.apply_serial!(gate, single_expected)
            @test apply!(gate, actual) === actual
            @test storage(actual) === owner
            @test storage(actual) ≈ storage(single_expected) atol=absolute_tolerance rtol=relative_tolerance
        end
        actual = StateVector(copy(data))
        @test apply!(QCircuit(gates), actual) === actual
        @test storage(actual) ≈ storage(expected) atol=absolute_tolerance rtol=relative_tolerance
    end

    positions = (6, 1, 4, 2, 5)
    local_matrix = Matrix(qr(randn(rng, ComplexF64, 32, 32)).Q)
    gate = QuantumGate(positions, local_matrix)
    full = ParallelSchedulingFixtures.embed_gate(6, positions, local_matrix)
    for columns in (0, 1, 2, 5, 9)
        data = randn(rng, ComplexF64, 64, columns)
        batch = BatchStateVector(copy(data), 6, columns)
        owner = storage(batch)
        @test apply!(gate, batch) === batch
        @test storage(batch) === owner
        @test storage(batch) ≈ full * data atol=1e-12 rtol=1e-12
    end
end

@testset "Many small batch states share a bounded outer task set" begin
    tiny = zeros(ComplexF64, 2, 8)
    tiny_owners = Vector{Task}(undef, 8)
    caller = current_task()
    @test MOSSQuantum._run_batch_columns!(tiny, 8) do column
        tiny_owners[column] = current_task()
    end === tiny
    @test all(owner === caller for owner in tiny_owners)

    data = zeros(ComplexF64, 32, 2048)
    owners = Vector{Task}(undef, 2048)
    inner_owners = similar(owners)
    inner_calls, inner_first, inner_last = zeros(Int, 2048), zeros(Int, 2048), zeros(Int, 2048)
    result = MOSSQuantum._run_batch_columns!(data, 2048) do column
        owners[column] = current_task()
        data[1, column] = column
        MOSSQuantum.parallel_run(19, Threads.nthreads(), (first, last) -> begin
            inner_owners[column] = current_task()
            inner_calls[column] += 1
            inner_first[column], inner_last[column] = first, last
        end; min_work=1)
    end
    @test result === data
    @test data[1, :] == collect(1:2048)
    @test length(unique(owners)) == min(4, Threads.nthreads())
    @test all(owners .=== inner_owners)
    @test all(==(1), inner_calls)
    @test all(iszero, inner_first) && all(==(18), inner_last)

    rng = MersenneTwister(171127)
    positions = (5, 1, 4, 2, 3)
    local_matrix = Matrix(qr(randn(rng, ComplexF64, 32, 32)).Q)
    full = ParallelSchedulingFixtures.embed_gate(5, positions, local_matrix)
    initial = randn(rng, ComplexF64, 32, 2048)
    batch = BatchStateVector(copy(initial), 5, 2048)
    owner = storage(batch)
    @test apply!(QuantumGate(positions, local_matrix), batch) === batch
    @test storage(batch) === owner
    @test storage(batch) ≈ full * initial atol=1e-12 rtol=1e-12
end

@testset "Many small density matrices preserve promotion, channels and adjoints" begin
    rng = MersenneTwister(171128)
    initial = zeros(Float32, 2, 2, 8192)
    initial[1, 1, :] .= 0.25f0 .+ 0.5f0 .* rand(rng, Float32, 8192)
    initial[2, 2, :] .= 1f0 .- initial[1, 1, :]
    initial[1, 2, :] .= 0.125f0
    initial[2, 1, :] .= 0.125f0
    owners = Vector{Task}(undef, 8192)
    MOSSQuantum._run_batch_columns!(initial, 8192) do column
        owners[column] = current_task()
    end
    @test length(unique(owners)) == min(2, Threads.nthreads())

    source = BatchDensityMatrix(copy(initial), 1, 8192)
    gate = RxGate(1, 0.37)
    promoted = apply!(gate, source)
    @test eltype(promoted) === ComplexF32
    @test promoted !== source && !Base.mightalias(storage(promoted), storage(source))
    @test storage(source) == initial
    channel = AmplitudeDamping(1; γ=0.21)
    noisy = copy(promoted)
    dual = copy(promoted)
    @test apply!(channel, noisy) === noisy
    @test MOSSQuantum.apply_dagger!(channel, dual) === dual
    @test eltype(noisy) === eltype(dual) === ComplexF32
    for column in (1, 4096, 4097, 8192)
        scalar = apply!(gate, DensityMatrix(copy(initial[:, :, column]), 1))
        @test storage(promoted)[:, :, column] ≈ storage(scalar) atol=1e-6 rtol=1e-6
        @test storage(noisy)[:, :, column] ≈ storage(apply!(channel, copy(scalar))) atol=1e-6 rtol=1e-6
        @test storage(dual)[:, :, column] ≈ storage(MOSSQuantum.apply_dagger!(channel, copy(scalar))) atol=1e-6 rtol=1e-6
    end
end
