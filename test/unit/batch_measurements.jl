using Test
using Random
using LinearAlgebra
using MOSS

module BatchSimulationContractFailures
using MOSS
using Random

struct ResizeState <: AbstractInstruction end
MOSS.positions(::ResizeState) = ()

mutable struct DemoBackend <: AbstractBackend
    mode::Symbol
    observed_rngs::Vector{Any}
    observed_resets::Vector{Bool}
end
DemoBackend(mode) = DemoBackend(mode, Any[], Bool[])

MOSS.supports(::DemoBackend, ::Union{ResizeState,Gate,QMeasure,QSelect}, ::BatchStateVector;
              action::Symbol=:apply) = action === :apply

function MOSS.apply!(backend::DemoBackend, ::ResizeState, state::BatchStateVector)
    backend.mode === :increase_batch && return BatchStateVector(nqubits(state), batch_size(state) + 1)
    backend.mode === :decrease_batch && return BatchStateVector(nqubits(state), batch_size(state) - 1)
    backend.mode === :increase_register && return BatchStateVector(nqubits(state) + 1, batch_size(state))
    backend.mode === :single_state && return StateVector(nqubits(state))
    return state
end

MOSS.apply!(::DemoBackend, instruction::Gate, state::BatchStateVector) = apply!(CPUBackend(), instruction, state)

function _metadata(mode::Symbol, count::Int)
    outcomes, probabilities = zeros(Int, count), ones(Float64, count)
    mode === :short_outcomes && return outcomes[1:(end - 1)], probabilities
    mode === :long_outcomes && return vcat(outcomes, 0), probabilities
    mode === :short_probabilities && return outcomes, probabilities[1:(end - 1)]
    mode === :long_probabilities && return outcomes, vcat(probabilities, 1.0)
    mode === :float_outcomes && return Float64.(outcomes), probabilities
    mode === :nonbinary_outcomes && return fill(2, count), probabilities
    mode === :complex_probabilities && return outcomes, ComplexF64.(probabilities)
    mode === :negative_probabilities && return outcomes, fill(-0.1, count)
    mode === :excessive_probabilities && return outcomes, fill(1.1, count)
    mode === :nan_probabilities && return outcomes, fill(NaN, count)
    mode === :infinite_probabilities && return outcomes, fill(Inf, count)
    mode === :float32_probabilities && return Int8.(outcomes), Float32.(probabilities)
    mode === :bigfloat_probabilities && return Int8.(outcomes), BigFloat.(probabilities)
    mode === :rounded_probabilities && return outcomes, fill(nextfloat(1f0), count)
    mode === :wrong_tuple && return outcomes, probabilities, nothing
    return outcomes, probabilities
end

function MOSS.measure!(backend::DemoBackend, state::BatchStateVector, position::Int;
                       auto_reset::Bool=true, rng::Random.AbstractRNG=Random.default_rng())
    push!(backend.observed_rngs, rng)
    push!(backend.observed_resets, auto_reset)
    backend.mode === :real_measurement && return measure!(state, position; auto_reset=auto_reset, rng=rng)
    return _metadata(backend.mode, batch_size(state))
end

function MOSS.apply!(backend::DemoBackend, instruction::QSelect, state::BatchStateVector)
    backend.mode === :real_measurement && return apply!(CPUBackend(), instruction, state)
    return _metadata(backend.mode, batch_size(state))[2]
end
end

@testset "Independent batch collapse" begin
    for position in 1:4, auto_reset in (false, true)
        original = rand_batch(MersenneTwister(30 + position), ComplexF64, 4, 5)
        batch = copy(original)
        reference_rng = MersenneTwister(81)
        references = [StateVector(original, column) for column in 1:batch_size(original)]
        expected = [measure!(state, position; auto_reset=auto_reset, rng=reference_rng)
                    for state in references]
        outcomes, probabilities = measure!(batch, position; auto_reset=auto_reset, rng=MersenneTwister(81))
        @test outcomes == first.(expected)
        @test probabilities ≈ last.(expected)
        @test eltype(outcomes) === Int
        @test eltype(probabilities) === Float64
        @test norm(batch) ≈ ones(5)
        @test nqubits(batch) == 4
        for column in 1:5
            @test StateVector(batch, column) ≈ references[column]
        end
    end

    basis = batch_onehot_encoding([[0], [1], [0], [1]])
    outcomes, probabilities = apply!(QMeasure(1; auto_reset=false), basis; rng=MersenneTwister(1))
    @test outcomes == [0, 1, 0, 1]
    @test probabilities == ones(4)
    @test storage(basis) == [1 0 1 0; 0 1 0 1]
    outcomes, probabilities = measure!(basis, 1; rng=MersenneTwister(1))
    @test outcomes == [0, 1, 0, 1]
    @test probabilities == ones(4)
    @test storage(basis) == [1 1 1 1; 0 0 0 0]

    independent = apply!(QCircuit([HGate(1)]), BatchStateVector(1, 128))
    outcomes, _ = measure!(independent, 1; auto_reset=false, rng=MersenneTwister(99))
    @test Set(outcomes) == Set([0, 1])

    invalid = BatchStateVector([inv(sqrt(2)) 2.0; inv(sqrt(2)) 0.0])
    before = copy(storage(invalid))
    rng = MersenneTwister(21)
    @test_throws ArgumentError measure!(invalid, 1; rng=rng)
    @test storage(invalid) == before
    @test rand(rng) == rand(MersenneTwister(21))
    @test_throws ArgumentError apply!(QMeasure(1; keep=false), basis)
    @test_throws ArgumentError measure!(basis, 0)
    @test_throws ArgumentError measure!(basis, 2)
end

@testset "Batch measurement removes one qubit" begin
    for n in (1, 4), position in 1:n
        original = rand_batch(MersenneTwister(9 + position), ComplexF64, n, 3)
        snapshot = copy(storage(original))
        reference_rng = MersenneTwister(108)
        expected = [measure(StateVector(original, column), position; rng=reference_rng) for column in 1:3]
        result, outcomes, probabilities = measure(original, position; rng=MersenneTwister(108))
        @test nqubits(result) == n - 1
        @test batch_size(result) == 3
        @test outcomes == getindex.(expected, 2)
        @test probabilities ≈ getindex.(expected, 3)
        @test storage(original) == snapshot
        @test !Base.mightalias(storage(result), storage(original))
        for column in 1:3
            @test StateVector(result, column) ≈ expected[column][1]
        end
    end
end

@testset "Atomic batch post-selection" begin
    for position in 1:4, outcome in (0, 1), keep in (false, true)
        original = rand_batch(MersenneTwister(19 + position), ComplexF64, 4, 3)
        snapshot = copy(storage(original))
        expected = [post_select(StateVector(original, column), position, outcome; keep=keep)
                    for column in 1:3]
        result, probabilities = post_select(original, position, outcome; keep=keep)
        @test nqubits(result) == (keep ? 4 : 3)
        @test probabilities ≈ last.(expected)
        @test storage(original) == snapshot
        @test !Base.mightalias(storage(result), storage(original))
        for column in 1:3
            @test StateVector(result, column) ≈ expected[column][1]
        end
        kept = copy(original)
        inplace_probabilities = post_select!(kept, position, outcome)
        @test inplace_probabilities ≈ probabilities
        @test norm(kept) ≈ ones(3)
        for column in 1:3
            expected_kept, _ = post_select(StateVector(original, column), position, outcome; keep=true)
            @test StateVector(kept, column) ≈ expected_kept
        end
    end

    impossible = BatchStateVector([inv(sqrt(2)) 1.0; inv(sqrt(2)) 0.0])
    snapshot = copy(storage(impossible))
    @test_throws DomainError post_select!(impossible, 1, 1)
    @test storage(impossible) == snapshot
    @test_throws DomainError post_select(impossible, 1, 1; keep=true)
    @test_throws DomainError post_select(impossible, 1, 1)
    @test storage(impossible) == snapshot
    @test_throws ArgumentError post_select!(impossible, 0, 0)
    @test_throws ArgumentError post_select(impossible, 2, 0)

    nonfinite = BatchStateVector([1.0 NaN; 0.0 0.0])
    snapshot = copy(storage(nonfinite))
    @test_throws DomainError post_select!(nonfinite, 1, 0)
    @test isequal(storage(nonfinite), snapshot)

    last_qubit = BatchStateVector([0.6 0.8; 0.8 0.6])
    removed, probabilities = post_select(last_qubit, 1, 1)
    @test nqubits(removed) == 0
    @test size(storage(removed)) == (1, 2)
    @test storage(removed) ≈ ones(1, 2)
    @test probabilities ≈ [0.64, 0.36]
end

@testset "Batch simulation records and promotion" begin
    initial = BatchStateVector(Float32, 2, 6)
    snapshot = copy(storage(initial))
    nested = QCircuit([QSelect(2, 0), HGate(1), QMeasure(1; auto_reset=false)])
    circuit = QCircuit([HGate(2), TGate(2), QMeasure(2), nested, XGate(2)])
    first_result = simulate(circuit, initial; rng=MersenneTwister(41))
    repeated = simulate(circuit, initial; rng=MersenneTwister(41))
    @test first_result isa MOSS.BatchSimulationResult
    @test first_result.state isa BatchStateVector{ComplexF32}
    @test storage(initial) == snapshot
    @test !Base.mightalias(storage(initial), storage(first_result.state))
    @test first_result.state ≈ repeated.state
    @test first_result.measurements == repeated.measurements
    @test length(first_result.measurements) == 6
    @test all(records -> length(records) == 3, first_result.measurements)
    @test first_result.measurements[1] !== first_result.measurements[2]
    for records in first_result.measurements
        @test getfield.(records, :position) == [2, 2, 1]
        @test getfield.(records, :kind) == [:measurement, :postselection, :measurement]
        @test records[1].probability ≈ 0.5 rtol=1e-6
        @test records[2].outcome == 0
        @test records[2].probability ≈ 1 rtol=1e-6
        @test records[3].probability ≈ 0.5 rtol=1e-6
    end

    # The direct circuit interface must retain state wrappers when an instruction
    # returns metadata, including when an earlier gate promotes its element type.
    direct = apply!(circuit, copy(initial); rng=MersenneTwister(41))
    @test direct isa BatchStateVector{ComplexF32}
    @test direct ≈ first_result.state
    @test norm(direct) ≈ ones(6)
    @test simulate(QCircuit(), initial).measurements == [MeasurementRecord[] for _ in 1:6]
    @test simulate(QCircuit([XGate(1)]), StateVector(1)) isa SimulationResult

    cpu = CPUBackend()
    measured = BatchStateVector(1, 2)
    @test supports(cpu, QMeasure(1), measured)
    @test supports(cpu, QSelect(1), measured)
    @test !supports(cpu, QMeasure(1; keep=false), measured)
    @test apply!(cpu, QMeasure(1), measured) == ([0, 0], [1.0, 1.0])
    @test measure!(cpu, measured, 1; rng=MersenneTwister(4)) == ([0, 0], [1.0, 1.0])
    @test apply!(cpu, QSelect(1), measured) == [1.0, 1.0]
    @test apply!(cpu, QCircuit([QMeasure(1), QSelect(1), XGate(1)]), measured) === measured
    @test storage(measured) == [0 0; 1 1]

    # Three-qubit generic channels remain beyond the CPU superoperator limit.
    blocked = BatchStateVector(3, 3)
    before = copy(storage(blocked))
    unsupported = QCircuit([XGate(1), QCircuit([QuantumMap((1, 2, 3), [Matrix{Float64}(I, 8, 8)])])])
    rng = MersenneTwister(3)
    @test_throws UnsupportedOperation apply!(unsupported, blocked; rng=rng)
    @test storage(blocked) == before
    @test rand(rng) == rand(MersenneTwister(3))
    @test_throws UnsupportedOperation simulate(unsupported, blocked)
    @test storage(blocked) == before
    @test_throws ArgumentError apply!(QCircuit([XGate(1), XGate(4)]), blocked)
    @test storage(blocked) == before
end

@testset "Empty batch and scalar-register measurement boundaries" begin
    empty = BatchStateVector(3, 0)
    @test measure!(empty, 2; rng=MersenneTwister(3)) == (Int[], Float64[])
    @test post_select!(empty, 2, 1) == Float64[]
    removed, outcomes, probabilities = measure(empty, 2; rng=MersenneTwister(3))
    @test size(storage(removed)) == (4, 0)
    @test nqubits(removed) == 2
    @test outcomes == Int[]
    @test probabilities == Float64[]
    selected, probabilities = post_select(empty, 2, 1)
    @test size(storage(selected)) == (4, 0)
    @test nqubits(selected) == 2
    @test probabilities == Float64[]
    selected, probabilities = post_select(empty, 2, 1; keep=true)
    @test size(storage(selected)) == (8, 0)
    @test probabilities == Float64[]
    result = simulate(QCircuit([HGate(1), QMeasure(2), QSelect(3, 1)]), empty)
    @test result isa MOSS.BatchSimulationResult
    @test size(storage(result.state)) == (8, 0)
    @test isempty(result.measurements)

    scalar = BatchStateVector(0, 2)
    @test_throws ArgumentError measure!(scalar, 1)
    @test_throws ArgumentError measure(scalar, 1)
    @test_throws ArgumentError post_select!(scalar, 1)
    @test_throws ArgumentError post_select(scalar, 1)
    @test simulate(QCircuit(), scalar).state == scalar
    @test_throws ArgumentError simulate(QCircuit([QMeasure(1)]), scalar)
end

@testset "Batch simulation validates external backend contracts" begin
    F = BatchSimulationContractFailures
    initial = BatchStateVector(1, 2)
    snapshot = copy(storage(initial))
    for mode in (:increase_batch, :decrease_batch)
        @test_throws DimensionMismatch simulate(QCircuit([F.ResizeState()]), initial; backend=F.DemoBackend(mode))
        @test_throws DimensionMismatch simulate(QCircuit([QCircuit([F.ResizeState()]), QMeasure(1)]), initial;
                                               backend=F.DemoBackend(mode))
        @test storage(initial) == snapshot
    end
    @test_throws ArgumentError simulate(QCircuit([F.ResizeState()]), initial; backend=F.DemoBackend(:single_state))
    replaced = simulate(QCircuit([F.ResizeState()]), initial; backend=F.DemoBackend(:increase_register))
    @test nqubits(replaced.state) == 2
    @test batch_size(replaced.state) == length(replaced.measurements) == 2

    for mode in (:short_outcomes, :long_outcomes, :short_probabilities, :long_probabilities)
        @test_throws DimensionMismatch simulate(QCircuit([QMeasure(1)]), initial; backend=F.DemoBackend(mode))
    end
    for mode in (:short_probabilities, :long_probabilities)
        @test_throws DimensionMismatch simulate(QCircuit([QSelect(1)]), initial; backend=F.DemoBackend(mode))
    end
    for mode in (:float_outcomes, :nonbinary_outcomes, :complex_probabilities, :wrong_tuple)
        @test_throws ArgumentError simulate(QCircuit([QMeasure(1)]), initial; backend=F.DemoBackend(mode))
    end
    @test_throws ArgumentError simulate(QCircuit([QSelect(1)]), initial;
                                       backend=F.DemoBackend(:complex_probabilities))
    for mode in (:negative_probabilities, :excessive_probabilities, :nan_probabilities, :infinite_probabilities)
        for instruction in (QMeasure(1), QSelect(1))
            @test_throws DomainError simulate(QCircuit([instruction]), initial; backend=F.DemoBackend(mode))
        end
    end
    for mode in (:float32_probabilities, :bigfloat_probabilities, :rounded_probabilities)
        result = simulate(QCircuit([QMeasure(1), QSelect(1)]), BatchStateVector(Float32, 1, 2);
                          backend=F.DemoBackend(mode))
        @test result.state isa BatchStateVector{Float32}
        @test all(records -> all(record -> record.outcome == 0 && record.probability == 1, records), result.measurements)
    end
    @test storage(initial) == snapshot

    backend = F.DemoBackend(:real_measurement)
    rng = MersenneTwister(307)
    measured = simulate(QCircuit([HGate(1), QMeasure(1; auto_reset=false),
                                  QCircuit([QMeasure(1; auto_reset=true)])]), initial;
                        backend=backend, rng=rng)
    reference = simulate(QCircuit([HGate(1), QMeasure(1; auto_reset=false),
                                   QCircuit([QMeasure(1; auto_reset=true)])]), initial;
                         rng=MersenneTwister(307))
    @test measured.state ≈ reference.state
    @test measured.measurements == reference.measurements
    @test length(backend.observed_rngs) == 2
    @test all(observed -> observed === rng, backend.observed_rngs)
    @test backend.observed_resets == [false, true]
    @test storage(initial) == snapshot

    # A backend declaration cannot make the recorded measure! protocol express
    # qubit removal. Reject it before an earlier stochastic instruction runs.
    blocked_backend = F.DemoBackend(:real_measurement)
    blocked_rng = MersenneTwister(998)
    removes_qubit = QCircuit([HGate(1), QMeasure(1), QCircuit([QMeasure(1; keep=false)])])
    @test supports(blocked_backend, removes_qubit, initial)
    @test_throws UnsupportedOperation simulate(removes_qubit, initial; backend=blocked_backend, rng=blocked_rng)
    @test isempty(blocked_backend.observed_rngs)
    @test rand(blocked_rng) == rand(MersenneTwister(998))
    @test storage(initial) == snapshot
end
