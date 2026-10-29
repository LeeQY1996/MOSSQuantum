using Test, Random, LinearAlgebra
using SparseArrays: issparse
using MOSSQuantum
using MOSSQuantum.QuantumCircuits.Gates: I₂
using MOSSQuantum.Utilities: trotter_propagator

@testset "Scalar identities and zero operators" begin
    constant = QubitsTerm(2.5)
    @test isempty(constant)
    @test !iszero(constant)
    @test iszero(QubitsTerm(0))
    @test iszero(QubitsTerm(1 => zeros(2, 2)))
    @test !iszero(QubitsTerm())
    @test nqubits(constant) == 0
    @test nqubits(QubitsTerm(3 => "Z")) == 3
    @test nqubits(QubitsOperator(constant)) == 0
    for n in (0, 1, 3)
        identity = Matrix{ComplexF64}(I, 2^n, 2^n)
        for term in (constant, QubitsOperator(constant), QubitsOperator(2.5))
            @test issparse(matrix(n, term))
            @test Matrix(matrix(n, term)) == 2.5identity
        end
        for zero_operator in (QubitsTerm(0), QubitsOperator(), zero(QubitsOperator), zero(constant))
            @test iszero(zero_operator)
            @test Matrix(matrix(n, zero_operator)) == zeros(2^n, 2^n)
        end
        for identity_operator in (one(QubitsTerm), one(constant), one(QubitsOperator), one(QubitsOperator(constant)))
            @test Matrix(matrix(n, identity_operator)) == identity
        end
    end
    @test size(matrix(constant)) == (1, 1)
    @test size(matrix(QubitsOperator())) == (1, 1)
    @test_throws ArgumentError matrix(-1, constant)
    @test_throws ArgumentError matrix(-1, QubitsOperator())
    @test_throws ArgumentError matrix(1, QubitsTerm(2 => "X"))
    @test_throws ArgumentError matrix(1, QubitsOperator(QubitsTerm(2 => "X")))
end

@testset "Operator arithmetic follows dense matrix algebra" begin
    x, y, z = QubitsTerm(1 => "X"), QubitsTerm(1 => "Y"), QubitsTerm(1 => "Z")
    for term in (x, y, z)
        @test matrix(1, term * term) == Matrix{ComplexF64}(I, 2, 2)
        @test isempty(term * term)
        @test iszero(term - term)
    end
    @test matrix(1, x * y) == im * Z
    @test matrix(1, y * x) == -im * Z
    @test matrix(1, x * y - y * x) == 2im * Z
    @test iszero(x * y + y * x)
    @test matrix(1, x + 2) == X + 2I
    @test matrix(1, 2 + x) == X + 2I
    @test matrix(1, x - 2) == X - 2I
    @test matrix(1, 2 - x) == 2I - X

    rng = MersenneTwister(9102)
    for trial in 1:6
        a, b, c = [randn(rng, ComplexF64, 2, 2) for _ in 1:3]
        left = QubitsTerm(1 => a, 3 => b; coeff=0.3 - 0.2im)
        right = QubitsTerm(2 => c, 3 => a; coeff=-0.5 + 0.7im)
        dense_left = (0.3 - 0.2im) * kron(b, Matrix{ComplexF64}(I, 2, 2), a)
        dense_right = (-0.5 + 0.7im) * kron(a, c, Matrix{ComplexF64}(I, 2, 2))
        @test Matrix(matrix(3, left)) ≈ dense_left
        @test Matrix(matrix(3, right)) ≈ dense_right
        @test Matrix(matrix(3, left * right)) ≈ dense_left * dense_right
        @test Matrix(matrix(3, right * left)) ≈ dense_right * dense_left
        @test Matrix(matrix(3, left')) ≈ dense_left'
        @test Matrix(matrix(3, left / 2)) ≈ dense_left / 2
        first_sum, second_sum = left + right + 0.7, 2right - left - 0.4im
        dense_first, dense_second = dense_left + dense_right + 0.7I, 2dense_right - dense_left - 0.4im * I
        @test Matrix(matrix(3, first_sum + second_sum)) ≈ dense_first + dense_second
        @test Matrix(matrix(3, first_sum - second_sum)) ≈ dense_first - dense_second
        @test Matrix(matrix(3, first_sum * second_sum)) ≈ dense_first * dense_second
        @test Matrix(matrix(3, first_sum * left)) ≈ dense_first * dense_left
        @test Matrix(matrix(3, right * second_sum)) ≈ dense_right * dense_second
        @test Matrix(matrix(3, first_sum')) ≈ dense_first'
        @test Matrix(matrix(3, first_sum / 2)) ≈ dense_first / 2
        @test iszero(first_sum - first_sum)
        @test iszero(QubitsOperator() * first_sum)
        @test iszero(first_sum * QubitsOperator())
    end
end

@testset "Canonical simplification and explicit coefficient cutoff" begin
    x = QubitsTerm(1 => "X")
    combined = simplify(x + x)
    @test length(combined.data[(1,)]) == 1
    @test matrix(1, combined) == 2X
    @test isempty(simplify(x - x))
    @test matrix(2, simplify(QubitsTerm(2 => 3I₂, 1 => 2X; coeff=0.5))) == kron(I₂, 3X)
    @test isempty(simplify(QubitsTerm(2 => 2I₂)))
    @test coeff(simplify(QubitsTerm(2 => 2I₂))) == 2
    @test matrix(1, simplify(QubitsTerm(1 => -im * Y) + im * QubitsTerm(1 => "Y"))) == zeros(2, 2)
    tiny = 6e-4x + 6e-4x
    @test matrix(1, simplify(tiny; atol=1e-3)) ≈ 1.2e-3X
    @test isempty(simplify(tiny; atol=2e-3))
    @test !isempty(simplify(1e-20x))
    @test_throws ArgumentError simplify(tiny; atol=-1)
    @test_throws ArgumentError simplify(tiny; atol=NaN)
    @test_throws ArgumentError simplify(x; atol=Inf)

    arbitrary = ComplexF64[1 2im; 0.3 -0.5]
    term = QubitsTerm(1 => arbitrary, 2 => "I"; coeff=2)
    simplified = simplify(term)
    @test positions(simplified) == [1]
    @test only(oplist(simplified)) == arbitrary
    @test matrix(2, simplified) == matrix(2, term)
    @test length(simplify(term + copy(term)).data[(1,)]) == 1
    @test matrix(2, simplify(term + copy(term))) == 2matrix(2, term)
end

@testset "Operator validation and independent ownership" begin
    @test_throws DimensionMismatch QubitsTerm([1], AbstractMatrix[], 1)
    @test_throws DimensionMismatch QubitsTerm(1 => ones(3, 3))
    @test_throws ArgumentError QubitsTerm(0 => "X")
    @test_throws ArgumentError QubitsTerm(-1 => "Z")
    @test_throws ArgumentError QubitsTerm(1 => "X", 1 => "Y")
    @test_throws ArgumentError QubitsTerm([1, 1], [X, Y], 1)
    source = [1.0 2.0; 3.0 4.0]
    term = QubitsTerm(1 => source)
    expected = copy(source)
    source[1, 1] = 99
    @test matrix(1, term) == expected
    term_copy = copy(term)
    only(oplist(term_copy))[1, 1] = 88
    @test matrix(1, term) == expected
    operator = QubitsOperator(term)
    for result in (copy(operator), operator + term, operator - term,
                   operator * 2, simplify(operator), operator')
        first(result.data[(1,)])[1][1][1, 1] = 77
        @test matrix(1, operator) == expected
        @test matrix(1, term) == expected
    end
    moved = change_positions(QubitsTerm(1 => "X", 3 => "Y"), Dict(1 => 3, 3 => 1))
    @test matrix(3, moved) == kron(X, I₂, Y)
    @test_throws ArgumentError change_positions(QubitsTerm(1 => "X", 2 => "Y"), Dict(1 => 2, 2 => 2))
end

@testset "Trotter retains constant energy and zero-time identity" begin
    for n in (0, 2), time in (-0.17im, 0.12)
        initial = StateVector(n)
        scalar = 0.7
        propagator = trotter_propagator(QubitsOperator(scalar), time; stepsize=abs(time) / 3)
        @test storage(propagator * initial) ≈ exp(time * scalar) * storage(initial)
        density = DensityMatrix(initial)
        @test storage(propagator * density) ≈ abs2(exp(time * scalar)) * storage(density)
        @test storage(trotter_propagator(QubitsOperator(), time) * initial) == storage(initial)
        @test isempty(trotter_propagator(QubitsOperator(scalar), zero(time)))
    end
    ham = 0.7 + QubitsTerm(2 => "X"; coeff=0.4)
    initial = normalize(StateVector(ComplexF64[1, 2im, 3, -1im]))
    time = -0.23im
    exact = exp(time * Matrix(matrix(2, ham)))
    @test storage(trotter_propagator(ham, time) * initial) ≈ exact * storage(initial)
    density = DensityMatrix(initial)
    @test storage(trotter_propagator(ham, time) * density) ≈ exact * storage(density) * exact'
    nn = QubitsTerm(1 => "Z", 2 => "Z") + QubitsTerm(2 => "Z", 3 => "Z") + 1.2
    state = rand_state(MersenneTwister(51), 3)
    @test storage(trotter_propagator(nn, time) * state) ≈ exp(time * Matrix(matrix(3, nn))) * storage(state)
    @test_throws ArgumentError trotter_propagator(ham, time; order=0)
    @test_throws ArgumentError trotter_propagator(ham, time; stepsize=0)
end
