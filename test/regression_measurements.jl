@testset "Measurement and post-selection regressions" begin
    @testset "Probabilities and retained qubits" begin
        bell = StateVector(ComplexF64[1, 0, 0, 1] / sqrt(2))
        original = copy(bell)
        for outcome in 0:1
            reduced, p = post_select(bell, 1, outcome)
            @test p ≈ 0.5
            @test nqubits(reduced) == 1
            @test reduced ≈ onehot_encoding([outcome])
            retained, p_keep = post_select(bell, 1, outcome; keep=true)
            @test p_keep ≈ 0.5
            @test nqubits(retained) == 2
            @test retained ≈ onehot_encoding([outcome, outcome])
            inplace = copy(bell)
            @test post_select!(inplace, 1, outcome) ≈ 0.5
            @test inplace ≈ retained
        end
        @test bell == original
        @test_throws DomainError post_select(qstate(1), 1, 1)
        @test_throws DomainError post_select!(qstate(1), 1, 1)
        @test_throws ArgumentError measure(qstate(2), 3)
        @test_throws ArgumentError measure!(qstate(2), 0)
    end

    @testset "Removing a qubit preserves the order of the others" begin
        for pos in 1:4, outcome in 0:1
            bits = [1, 0, 1, 0]
            bits[pos] = outcome
            state = onehot_encoding(bits)
            original = copy(state)
            expected = onehot_encoding(bits[setdiff(1:4, [pos])])
            measured, result, probability = measure(state, pos)
            @test result == outcome
            @test probability ≈ 1
            @test measured ≈ expected
            selected, p = post_select(state, pos, outcome)
            @test selected ≈ expected
            @test p ≈ 1
            @test state == original
        end
        # Coherences on the surviving qubits must be retained as well.
        a = ComplexF64[sqrt(0.3), im * sqrt(0.7)]
        remaining = kron([0., 1.], a)
        state = StateVector(kron([1., 1.] / sqrt(2), remaining))
        measured, _, p = measure(state, 3)
        @test p ≈ 0.5
        @test storage(measured) ≈ remaining
        selected, p = post_select(state, 3, 1)
        @test p ≈ 0.5
        @test storage(selected) ≈ remaining
    end

    @testset "Circuit execution retains the quantum state" begin
        c = QCircuit([XGate(1), QMeasure(1), XGate(2)])
        @test c * qstate(2) ≈ onehot_encoding([0, 1])
        c = QCircuit([XGate(1), QMeasure(1; auto_reset=false), XGate(2)])
        @test c * qstate(2) ≈ onehot_encoding([1, 1])
        c = QCircuit([HGate(1), QSelect(1, 1), XGate(2)])
        @test c * qstate(2) ≈ onehot_encoding([1, 1])
        nested = QCircuit([QCircuit([XGate(1), QMeasure(1)]), XGate(2)])
        @test nested * DensityMatrix(2) ≈ DensityMatrix(onehot_encoding([0, 1]))
    end

    @testset "Post-selection derivatives" begin
        v = ComplexF64[0.2+0.1im, -0.3, 0.5im, 0.7, -0.2im, 0.4, 0.1, -0.6im]
        for keep in (false, true), pos in (1, 3), outcome in 0:1
            weights = collect(1.0:(keep ? 8 : 4))
            loss(x) = begin
                selected, p = post_select(StateVector(x), pos, outcome; keep=keep)
                real(dot(weights, storage(selected))) + 0.7 * p
            end
            actual = gradient(loss, v)[1]
            expected = fdm_gradient(loss, v)
            @test actual ≈ expected atol=1e-7 rtol=1e-7
        end
    end

    @testset "Density matrix indexing" begin
        rho = DensityMatrix(1)
        rho[1, 1] = 0.5
        rho[2, 2] = 0.5
        @test storage(rho) == [0.5 0; 0 0.5]
        rho[2] = 0.25im
        @test rho[2, 1] == 0.25im
    end
end
