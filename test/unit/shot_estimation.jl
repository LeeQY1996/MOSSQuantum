using Test, Random, LinearAlgebra, MOSSQuantum

module ReadoutOnlyEstimatorFixture
import MOSSQuantum
struct ReadoutOnlyBackend <: MOSSQuantum.AbstractBackend end
struct ReadoutOnlyState <: MOSSQuantum.AbstractQuantumState
    probabilities::Vector{Float64}
end
MOSSQuantum.nqubits(::ReadoutOnlyState) = 1
MOSSQuantum.backend(::ReadoutOnlyState) = ReadoutOnlyBackend()
Base.copy(state::ReadoutOnlyState) = ReadoutOnlyState(copy(state.probabilities))
MOSSQuantum.probabilities(::ReadoutOnlyBackend, state::ReadoutOnlyState; qubits=1:1) =
    isempty(qubits) ? [sum(state.probabilities)] : copy(state.probabilities)
end

@testset "Finite-shot measurement planning" begin
    x, y, z = (QubitsTerm(1 => axis) for axis in ("X", "Y", "Z"))
    observable = x + 2z + QubitsTerm(2 => "Z") + QubitsTerm(1 => "Z", 2 => "Z")
    plan = measurement_plan(observable)
    @test plan.grouping === :qwc
    @test plan.nqubits == 2
    @test plan.constant == 0
    @test length(plan.groups) == 2
    @test sum(length(group.terms) for group in plan.groups) == 4
    @test length(measurement_plan(observable; grouping=:none).groups) == 4
    @test length(measurement_plan(x + x).groups[1].terms) == 1
    @test measurement_plan(x + x).groups[1].terms[1].coefficient == 2
    @test measurement_plan((1 + im) * x + (-im) * x).groups[1].terms[1].coefficient == 1
    @test isempty(measurement_plan(x + (-1) * x).groups)
    @test_throws ArgumentError measurement_plan(im * x)
    @test_throws ArgumentError measurement_plan(observable; grouping=:commuting)
    @test_throws ArgumentError measurement_plan(observable; atol=-1)
    @test_throws ArgumentError measurement_plan(observable; atol=NaN)
    @test_throws ArgumentError measurement_plan(observable; max_terms=0)
    @test_throws ArgumentError measurement_plan(observable; max_terms=true)
    @test_throws ArgumentError measurement_plan(observable; max_terms=1)
    @test_throws ArgumentError measurement_plan(QubitsTerm(1 => [NaN 0; 0 1]))
    @test_throws ArgumentError measurement_plan(Inf * x)

    # Expansion handles arbitrary local matrices and combines coefficients
    # globally, including non-Hermitian summands that make a Hermitian sum.
    raising = QubitsTerm(1 => ComplexF64[0 0; 1 0])
    expansion = measurement_plan(raising + adjoint(raising))
    @test length(expansion.groups) == 1
    @test expansion.groups[1].bases == [:X]
    @test expansion.groups[1].terms[1].coefficient == 1
    @test_throws ArgumentError measurement_plan(raising)
    identity = QubitsTerm(1 => ComplexF64[2 0; 0 2])
    @test measurement_plan(identity).constant == 2
    @test isempty(measurement_plan(identity).groups)

    general = QubitsTerm(1 => ComplexF64[1 1-im; 1+im -1], 3 => ComplexF64[2 0; 0 0.5]; coeff=0.3)
    expanded = measurement_plan(general; grouping=:none)
    reference = zeros(ComplexF64, 8, 8)
    for group in expanded.groups, term in group.terms
        factors = Dict(position => string(axis) for (position, axis) in zip(term.positions, term.bases))
        reference += term.coefficient * Matrix(matrix(3, QubitsTerm(factors)))
    end
    @test reference ≈ Matrix(matrix(3, general))
    # Plans snapshot coefficients and basis metadata instead of borrowing the
    # mutable local factors of the input observable.
    source_matrix = ComplexF64[0 1; 1 0]
    source = QubitsTerm(1 => source_matrix)
    snapshot = measurement_plan(source)
    source_matrix .= 0
    @test snapshot.groups[1].terms[1].coefficient == 1
    @test snapshot.groups[1].bases == [:X]
end

@testset "Pauli basis rotations and finite-shot statistics" begin
    x, y, z = (QubitsTerm(1 => axis) for axis in ("X", "Y", "Z"))
    plus_x = StateVector(ComplexF64[1, 1] / sqrt(2))
    plus_y = StateVector(ComplexF64[1, im] / sqrt(2))
    minus_y = StateVector(ComplexF64[1, -im] / sqrt(2))
    for (observable, state, expected) in ((x, plus_x, 1), (y, plus_y, 1), (y, minus_y, -1), (z, StateVector(1), 1))
        before = copy(state)
        result = estimate(observable, state; shots=37, rng=MersenneTwister(27))
        @test result.value == expected
        @test result.variance == result.stderr == 0
        @test result.shots == result.requested_shots == 37
        @test state == before
    end

    mixed = DensityMatrix(ComplexF64[0.5 -0.3im; 0.3im 0.5])
    result = estimate(y, mixed; shots=20_000, rng=MersenneTwister(28))
    @test abs(result.value - 0.6) < 0.03
    @test result.variance ≈ result.groups[1].sample_variance / 20_000
    @test result.stderr ≈ sqrt(result.variance)
    @test result.groups[1].sample_variance > 0
    @test estimate(y, mixed; shots=20_000, rng=MersenneTwister(28)).value == result.value

    observable = x + 2y + 3z
    plan = measurement_plan(observable)
    result = estimate(plan, plus_y; shots=11, rng=MersenneTwister(29))
    @test getproperty.(result.groups, :shots) == [4, 4, 3]
    @test result.shots == result.requested_shots == 11
    @test result.variance ≈ sum(group.sample_variance / group.shots for group in result.groups)
    @test_throws ArgumentError estimate(plan, plus_y; shots=5)
    @test_throws ArgumentError estimate(plan, plus_y; shots=-1)
    @test_throws ArgumentError estimate(plan, plus_y; shots=big(typemax(Int)) + 1)

    # Both Z outcomes on a Bell pair are equal. The group energy is ±2, so its
    # sample variance includes positive covariance between the two terms.
    bell = StateVector(ComplexF64[1, 0, 0, 1] / sqrt(2))
    correlated = QubitsTerm(1 => "Z") + QubitsTerm(2 => "Z")
    result = estimate(correlated, bell; shots=2000, rng=MersenneTwister(30))
    draws = sample(MersenneTwister(30), bell, 2000)
    energies = [2 - 2sum(row) for row in eachrow(draws)]
    average = sum(energies) / length(energies)
    sample_variance = sum(abs2(value - average) for value in energies) / (length(energies) - 1)
    @test result.value ≈ average
    @test only(result.groups).sample_variance ≈ sample_variance
    @test result.variance ≈ sample_variance / 2000
    @test only(result.groups).sample_variance > 3.9
    @test estimate(correlated, bell; shots=2000, grouping=:none, rng=MersenneTwister(30)).shots == 2000

    # XX, YY and ZZ commute globally, but need three distinct product bases.
    # The Bell state has eigenvalues +1, -1, +1 respectively.
    bell_observable = QubitsTerm(1 => "X", 2 => "X") +
                      QubitsTerm(1 => "Y", 2 => "Y") + QubitsTerm(1 => "Z", 2 => "Z")
    bell_plan = measurement_plan(bell_observable)
    @test length(bell_plan.groups) == 3
    bell_result = estimate(bell_plan, bell; shots=9, rng=MersenneTwister(301))
    @test getproperty.(bell_result.groups, :value) == [1, -1, 1]
    @test bell_result.value == 1
    @test bell_result.variance == 0

    # A Pauli word may span more than five total register qubits: only local
    # basis rotations are gates, and parity uses all selected output columns.
    long_word = QubitsTerm((index => "X" for index in 1:7)...)
    long_state = StateVector(fill(ComplexF64(1 / sqrt(128)), 128))
    @test estimate(long_word, long_state; shots=9).value == 1
end

@testset "Constants, zero observables and batch shot budgets" begin
    constant = QubitsTerm(Int[], Matrix{ComplexF64}[], 2.5)
    state = StateVector(2)
    rng = MersenneTwister(31)
    expected_rng = copy(rng)
    for budget in (0, 7)
        result = estimate(constant, state; shots=budget, rng=rng)
        @test result.value == 2.5
        @test result.variance == result.stderr == 0
        @test result.shots == 0
        @test result.requested_shots == budget
        @test isempty(result.groups)
    end
    @test rand(rng) == rand(expected_rng)
    @test estimate(QubitsOperator(), state; shots=0).value == 0
    @test estimate(constant, StateVector(0); shots=0).value == 2.5
    constant_sum = QubitsOperator(constant)
    @test measurement_plan(constant_sum).constant == 2.5
    @test isempty(measurement_plan(constant_sum).groups)
    @test estimate(constant_sum, state; shots=11).value == 2.5
    @test estimate(constant_sum, state; shots=11).shots == 0
    scalar_and_pauli = 0.3 + QubitsTerm(1 => "X", 2 => "X") + 0.5QubitsTerm(1 => "Z")
    scalar_plan = measurement_plan(scalar_and_pauli)
    @test scalar_plan.constant == 0.3
    @test length(scalar_plan.groups) == 2
    with_constant = estimate(scalar_plan, state; shots=100, rng=MersenneTwister(311))
    without_constant = estimate(QubitsTerm(1 => "X", 2 => "X") + 0.5QubitsTerm(1 => "Z"),
                                state; shots=100, rng=MersenneTwister(311))
    @test with_constant.value ≈ 0.3 + without_constant.value
    @test with_constant.variance == without_constant.variance
    @test with_constant.shots == without_constant.shots == 100
    circuit_constant = estimate(scalar_and_pauli, QCircuit(), state;
                               shots=100, rng=MersenneTwister(311))
    @test circuit_constant.value == with_constant.value
    @test circuit_constant.variance == with_constant.variance
    @test_throws ArgumentError estimate(constant, state; shots=-1)
    @test_throws ArgumentError estimate(constant, state; shots=true)
    @test_throws ArgumentError estimate(constant, 2 * state; shots=0)
    @test_throws ArgumentError estimate(QubitsTerm(3 => "X"), state; shots=8)
    @test_throws ArgumentError estimate(QubitsTerm(1 => "X"), 2 * state; shots=8)

    basis = [StateVector(ComplexF64[1, 0]), StateVector(ComplexF64[0, 1])]
    batch = BatchStateVector(basis)
    observable = QubitsTerm(1 => "Z")
    for states in (batch, BatchDensityMatrix(batch))
        before = copy(states)
        results = estimate(observable, states; shots=13, rng=MersenneTwister(32))
        @test length(results) == 2
        @test getproperty.(results, :value) == [1, -1]
        @test getproperty.(results, :shots) == [13, 13]
        @test getproperty.(results, :variance) == [0, 0]
        @test states == before
    end
    @test isempty(estimate(observable, BatchStateVector(1, 0); shots=2))
    @test_throws ArgumentError estimate(observable, BatchStateVector(1, 0); shots=1)
end

@testset "Readout-only backend estimation" begin
    state = ReadoutOnlyEstimatorFixture.ReadoutOnlyState([1.0, 0.0])
    result = estimate(QubitsTerm(1 => "Z"), state; shots=4)
    @test result.value == 1
    @test result.variance == 0
    @test_throws UnsupportedOperation estimate(QubitsTerm(1 => "X"), state; shots=4)
    malformed = ReadoutOnlyEstimatorFixture.ReadoutOnlyState([0.2, 0.3, 0.5])
    @test_throws DimensionMismatch estimate(QubitsTerm(1 => "Z"), malformed; shots=4)
end
