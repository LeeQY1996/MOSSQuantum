using Test
using Random
using LinearAlgebra
using MOSS

function _test_mixed_batch(n, count; T=ComplexF64, seed=61)
    rng = MersenneTwister(seed)
    dimension = 2^n
    data = Array{T}(undef, dimension, dimension, count)
    for column in 1:count
        matrix = randn(rng, T, dimension, dimension)
        matrix = matrix * matrix'
        data[:, :, column] .= matrix ./ tr(matrix)
    end
    return BatchDensityMatrix(data, n, count)
end

function _test_density_projection(matrix, position, outcome; keep=true, reset=false)
    bit = 1 << (position - 1)
    indices = [i for i in axes(matrix, 1) if ((i - 1) & bit) == outcome * bit]
    block = matrix[indices, indices]
    weight = real(tr(block))
    if !keep
        return block ./ weight, weight
    end
    result = zeros(eltype(matrix), size(matrix))
    destination = reset && outcome == 1 ? indices .- bit : indices
    result[destination, destination] .= block ./ weight
    return result, weight
end

module BatchDensitySimulationContracts
using MOSS
using Random

struct Transition <: AbstractInstruction end
MOSS.positions(::Transition) = ()
struct ContractBackend <: AbstractBackend
    mode::Symbol
end
MOSS.supports(::ContractBackend, ::Union{Transition,Gate,QMeasure,QSelect},
              ::Union{BatchStateVector,BatchDensityMatrix}; action::Symbol=:apply) = action === :apply
function MOSS.apply!(backend::ContractBackend, ::Transition, state::Union{BatchStateVector,BatchDensityMatrix})
    backend.mode === :increase_batch && return BatchDensityMatrix(nqubits(state), batch_size(state) + 1)
    backend.mode === :increase_register && return BatchDensityMatrix(nqubits(state) + 1, batch_size(state))
    backend.mode === :single_state && return DensityMatrix(nqubits(state))
    backend.mode === :pure && return BatchStateVector(nqubits(state), batch_size(state))
    return BatchDensityMatrix(state)
end
MOSS.apply!(::ContractBackend, instruction::Gate, state::Union{BatchStateVector,BatchDensityMatrix}) =
    apply!(CPUBackend(), instruction, state)
function MOSS.measure!(backend::ContractBackend, state::Union{BatchStateVector,BatchDensityMatrix}, position::Int;
                       auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    count = batch_size(state)
    backend.mode === :short && return zeros(Int, count - 1), ones(count)
    backend.mode === :bad_outcome && return fill(2, count), ones(count)
    backend.mode === :bad_probability && return zeros(Int, count), fill(1.2, count)
    backend.mode === :rounded && return zeros(Int8, count), fill(nextfloat(1f0), count)
    return measure!(state, position; auto_reset=auto_reset, rng=rng)
end
MOSS.apply!(::ContractBackend, instruction::QSelect, state::Union{BatchStateVector,BatchDensityMatrix}) =
    apply!(CPUBackend(), instruction, state)
end

@testset "Batch density probabilities and sampling" begin
    batch = _test_mixed_batch(3, 4)
    snapshot = copy(storage(batch))
    for qubits in (1:3, [3, 1], [2], Int[])
        result = probabilities(batch; qubits=qubits)
        @test size(result) == (2^length(qubits), 4)
        for column in 1:4
            @test result[:, column] ≈ probabilities(DensityMatrix(batch, column); qubits=qubits)
        end
        @test vec(sum(result; dims=1)) ≈ ones(4)
    end
    first_draws = sample(MersenneTwister(15), batch, 100; qubits=[3, 1])
    @test size(first_draws) == (100, 2, 4)
    @test first_draws == sample(MersenneTwister(15), batch, 100; qubits=[3, 1])
    @test all(bit -> bit == 0 || bit == 1, first_draws)
    histograms = counts(MersenneTwister(15), batch, 100; qubits=[3, 1])
    @test length(histograms) == 4
    @test all(histogram -> sum(values(histogram)) == 100, histograms)
    @test storage(batch) == snapshot
    @test_throws ArgumentError probabilities(batch; qubits=[1, 1])
    @test_throws ArgumentError probabilities(batch; qubits=[4])
    @test_throws ArgumentError sample(batch, -1)

    # A marginal may combine invalid entries into an apparently valid weight.
    negative = BatchDensityMatrix(reshape(ComplexF64[1.2 0; 0 -0.2], 2, 2, 1))
    @test_throws DomainError probabilities(negative; qubits=Int[])
    imaginary = BatchDensityMatrix(reshape(ComplexF64[0.5+0.2im 0; 0 0.5-0.2im], 2, 2, 1))
    @test_throws ArgumentError probabilities(imaginary; qubits=Int[])
    invalid = BatchDensityMatrix(reshape([2.0 0; 0 0], 2, 2, 1))
    @test_throws ArgumentError probabilities(invalid)
    nonfinite = BatchDensityMatrix(reshape([NaN 0; 0 1], 2, 2, 1))
    @test_throws ArgumentError probabilities(nonfinite)
    rounded = BatchDensityMatrix(reshape(Float32[nextfloat(1f0) 0; 0 0], 2, 2, 1))
    @test probabilities(rounded) == reshape([1.0, 0.0], 2, 1)

    empty = BatchDensityMatrix(2, 0)
    @test size(probabilities(empty)) == (4, 0)
    @test size(sample(empty, 7)) == (7, 2, 0)
    @test isempty(counts(empty, 7))
    scalar = BatchDensityMatrix(0, 3)
    @test probabilities(scalar) == ones(1, 3)
    @test size(sample(scalar, 5)) == (5, 0, 3)
    @test counts(scalar, 5) == [Dict("" => 5) for _ in 1:3]
    @test size(sample(batch, 0)) == (0, 3, 4)
end

@testset "Independent density measurement and reset" begin
    for n in (1, 3), position in 1:n, auto_reset in (false, true)
        original = _test_mixed_batch(n, 4; seed=42 + position)
        snapshot = copy(storage(original))
        batch = copy(original)
        distributions = probabilities(original; qubits=[position])
        reference_rng = MersenneTwister(90)
        expected_outcomes = [MOSS.discrete_sample(reference_rng, view(distributions, :, column)) - 1
                             for column in 1:4]
        outcomes, weights = measure!(batch, position; auto_reset=auto_reset, rng=MersenneTwister(90))
        @test outcomes == expected_outcomes
        @test eltype(outcomes) === Int
        @test eltype(weights) === Float64
        @test nqubits(batch) == n
        for column in 1:4
            expected, probability = _test_density_projection(storage(original)[:, :, column], position,
                                                            outcomes[column]; reset=auto_reset)
            @test storage(batch)[:, :, column] ≈ expected
            @test weights[column] ≈ probability
            @test tr(storage(batch)[:, :, column]) ≈ 1
            @test ishermitian(storage(batch)[:, :, column])
        end
        removed, removed_outcomes, removed_weights = measure(original, position; rng=MersenneTwister(90))
        @test removed_outcomes == outcomes
        @test removed_weights ≈ weights
        @test nqubits(removed) == n - 1
        @test batch_size(removed) == 4
        @test storage(original) == snapshot
        @test !Base.mightalias(storage(original), storage(removed))
        for column in 1:4
            expected, _ = _test_density_projection(storage(original)[:, :, column], position,
                                                   outcomes[column]; keep=false)
            @test storage(removed)[:, :, column] ≈ expected
        end
    end

    bell = QCircuit([HGate(1), CNOTGate(1, 2)]) * BatchStateVector(2, 8)
    entangled = BatchDensityMatrix(bell)
    outcomes, weights = measure!(entangled, 1; auto_reset=false, rng=MersenneTwister(25))
    @test weights ≈ fill(0.5, 8)
    for column in 1:8
        @test probabilities(entangled)[:, column] ≈ (outcomes[column] == 0 ? [1, 0, 0, 0] : [0, 0, 0, 1])
    end
    @test_throws ArgumentError measure!(entangled, 0)
    @test_throws ArgumentError measure!(entangled, 3)
    @test_throws ArgumentError apply!(QMeasure(1; keep=false), entangled)

    invalid = _test_mixed_batch(1, 2)
    storage(invalid)[:, :, 2] .*= 2
    snapshot = copy(storage(invalid))
    rng = MersenneTwister(39)
    @test_throws ArgumentError measure!(invalid, 1; rng=rng)
    @test storage(invalid) == snapshot
    @test rand(rng) == rand(MersenneTwister(39))
    for (diagonal, exception) in ((ComplexF64[1.2, -0.2], DomainError),
                                  (ComplexF64[0.5+0.1im, 0.5-0.1im], ArgumentError),
                                  (ComplexF64[NaN, 1], ArgumentError))
        invalid = _test_mixed_batch(1, 2)
        storage(invalid)[1, 1, 2], storage(invalid)[2, 2, 2] = diagonal
        snapshot = copy(storage(invalid))
        rng = MersenneTwister(40)
        @test_throws exception measure!(invalid, 1; rng=rng)
        @test isequal(storage(invalid), snapshot)
        @test rand(rng) == rand(MersenneTwister(40))
    end
end

@testset "Atomic density post-selection" begin
    for position in 1:3, outcome in (0, 1), keep in (false, true)
        original = _test_mixed_batch(3, 3; seed=84 + position)
        snapshot = copy(storage(original))
        result, weights = post_select(original, position, outcome; keep=keep)
        @test nqubits(result) == (keep ? 3 : 2)
        @test batch_size(result) == 3
        @test storage(original) == snapshot
        @test !Base.mightalias(storage(result), storage(original))
        for column in 1:3
            expected, weight = _test_density_projection(storage(original)[:, :, column], position, outcome; keep=keep)
            @test storage(result)[:, :, column] ≈ expected
            @test weights[column] ≈ weight
        end
        kept = copy(original)
        @test post_select!(kept, position, outcome) ≈ weights
        for column in 1:3
            expected, _ = _test_density_projection(storage(original)[:, :, column], position, outcome)
            @test storage(kept)[:, :, column] ≈ expected
        end
    end
    raw = BatchDensityMatrix(reshape([1.2 0.2; 0.2 0.8], 2, 2, 1))
    removed, weights = post_select(raw, 1, 1)
    @test weights ≈ [0.8]
    @test storage(removed) ≈ ones(1, 1, 1)
    impossible = BatchDensityMatrix(cat([0.5 0; 0 0.5], [1.0 0; 0 0]; dims=3))
    snapshot = copy(storage(impossible))
    @test_throws DomainError post_select!(impossible, 1, 1)
    @test_throws DomainError post_select(impossible, 1, 1)
    @test_throws DomainError post_select(impossible, 1, 1; keep=true)
    @test storage(impossible) == snapshot
    @test_throws ArgumentError post_select!(impossible, 2, 1)
    nonfinite = copy(impossible)
    storage(nonfinite)[2, 2, 2] = Inf
    snapshot = copy(storage(nonfinite))
    @test_throws ArgumentError post_select!(nonfinite, 1, 1)
    @test storage(nonfinite) == snapshot

    empty = BatchDensityMatrix(3, 0)
    @test measure!(empty, 2) == (Int[], Float64[])
    @test post_select!(empty, 2, 1) == Float64[]
    removed, outcomes, weights = measure(empty, 2)
    @test size(storage(removed)) == (4, 4, 0)
    @test outcomes == Int[]
    @test weights == Float64[]
    selected, weights = post_select(empty, 2, 1)
    @test size(storage(selected)) == (4, 4, 0)
    @test weights == Float64[]
    selected, _ = post_select(empty, 2, 1; keep=true)
    @test size(storage(selected)) == (8, 8, 0)
    @test_throws ArgumentError measure!(BatchDensityMatrix(0, 2), 1)
    @test_throws ArgumentError post_select!(BatchDensityMatrix(0, 2), 1)
end

@testset "Mixed batch simulation and recorded transitions" begin
    initial = BatchStateVector(Float32, 2, 5)
    snapshot = copy(storage(initial))
    # Reset the first measured qubit so that post-selection is possible in every sample.
    circuit = QCircuit([HGate(1), CNOTGate(1, 2),
                        QCircuit([AmplitudeDamping(2; γ=0.2), QMeasure(1)]),
                        QSelect(1, 0), QMeasure(2; auto_reset=false)])
    first_result = simulate(circuit, initial; rng=MersenneTwister(58))
    repeated = simulate(circuit, initial; rng=MersenneTwister(58))
    direct = apply!(circuit, copy(initial); rng=MersenneTwister(58))
    @test first_result isa BatchSimulationResult
    @test first_result.state isa BatchDensityMatrix
    @test eltype(first_result.state) === Float32
    @test first_result.state ≈ repeated.state
    @test first_result.state ≈ direct
    @test first_result.measurements == repeated.measurements
    @test storage(initial) == snapshot
    @test !Base.mightalias(storage(initial), storage(first_result.state))
    @test length(first_result.measurements) == 5
    @test first_result.measurements[1] !== first_result.measurements[2]
    for records in first_result.measurements
        @test getfield.(records, :position) == [1, 1, 2]
        @test getfield.(records, :kind) == [:measurement, :postselection, :measurement]
        @test records[2].probability ≈ 1 rtol=1e-5
    end
    mixed_initial = _test_mixed_batch(2, 3)
    mixed_snapshot = copy(storage(mixed_initial))
    mixed_result = simulate(QCircuit([TGate(1), QMeasure(2)]), mixed_initial; rng=MersenneTwister(4))
    @test mixed_result.state isa BatchDensityMatrix
    @test length(mixed_result.measurements) == 3
    @test storage(mixed_initial) == mixed_snapshot
    @test simulate(QCircuit(), mixed_initial).measurements == [MeasurementRecord[] for _ in 1:3]
    @test simulate(QCircuit([AmplitudeDamping(1; γ=0.1)]), BatchStateVector(1, 0)).state isa BatchDensityMatrix
    @test simulate(QCircuit([QMeasure(1)]), BatchDensityMatrix(1, 0)).measurements == Vector{MeasurementRecord}[]
    @test_throws UnsupportedOperation simulate(QCircuit([QMeasure(1; keep=false)]), mixed_initial)
    @test_throws UnsupportedOperation simulate(QCircuit([QCircuit([QMeasure(1; keep=false)])]), mixed_initial)
    malformed = QCircuit([QMeasure(1), QCircuit([gate(1, [NaN 0.0; 0.0 1.0])])])
    rng = MersenneTwister(74)
    @test_throws ArgumentError simulate(malformed, mixed_initial; rng=rng)
    @test rand(rng) == rand(MersenneTwister(74))
    @test storage(mixed_initial) == mixed_snapshot

    contracts = BatchDensitySimulationContracts
    transition = QCircuit([contracts.Transition(), QMeasure(1)])
    external = simulate(transition, initial; backend=contracts.ContractBackend(:mixed), rng=MersenneTwister(2))
    @test external.state isa BatchDensityMatrix
    @test length(external.measurements) == 5
    returned_pure = simulate(transition, mixed_initial; backend=contracts.ContractBackend(:pure))
    @test returned_pure.state isa BatchStateVector
    resized = simulate(QCircuit([contracts.Transition()]), mixed_initial;
                       backend=contracts.ContractBackend(:increase_register))
    @test nqubits(resized.state) == 3
    @test batch_size(resized.state) == 3
    @test_throws DimensionMismatch simulate(transition, mixed_initial; backend=contracts.ContractBackend(:increase_batch))
    @test_throws ArgumentError simulate(transition, mixed_initial; backend=contracts.ContractBackend(:single_state))
    @test_throws DimensionMismatch simulate(QCircuit([QMeasure(1)]), mixed_initial; backend=contracts.ContractBackend(:short))
    @test_throws ArgumentError simulate(QCircuit([QMeasure(1)]), mixed_initial; backend=contracts.ContractBackend(:bad_outcome))
    @test_throws DomainError simulate(QCircuit([QMeasure(1)]), mixed_initial; backend=contracts.ContractBackend(:bad_probability))
    rounded = simulate(QCircuit([QMeasure(1)]), BatchDensityMatrix(Float32, 1, 2);
                       backend=contracts.ContractBackend(:rounded))
    @test all(records -> records[1].probability == 1, rounded.measurements)
end
