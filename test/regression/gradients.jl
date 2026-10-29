using Test, LinearAlgebra, Zygote
using MOSSQuantum

function regression_gradient_fd(f, x; step=1e-6)
    result = similar(x)
    for i in eachindex(x)
        xp, xm = copy(x), copy(x)
        xp[i] += step
        xm[i] -= step
        result[i] = (f(xp) - f(xm)) / (2step)
        if eltype(x) <: Complex
            xp, xm = copy(x), copy(x)
            xp[i] += im * step
            xm[i] -= im * step
            result[i] += im * (f(xp) - f(xm)) / (2step)
        end
    end
    return result
end

@testset "density circuit derivatives" begin
    rho = DensityMatrix(1)
    c = QCircuit([RyGate(1, 0.0; isparas=true)])
    @test gradient(c -> real(sum(storage(c * rho))), c)[1] ≈ [1.0]

    # Arbitrary complex matrices check the full cotangent, without assuming
    # either the state or the loss's upstream gradient is Hermitian.
    data = reshape(ComplexF64[sin(i) + im * cos(2i) for i in 1:16], 4, 4)
    weight = reshape(ComplexF64[cos(i) + im * sin(3i) for i in 1:16], 4, 4)
    build(p) = QCircuit([RyGate(1, p[1]; isparas=true),
        RzGate(2, p[2]; isparas=true), CRxGate(1, 2, p[3]; isparas=true)])
    p = [.2, -.4, .7]
    c = build(p)
    loss(c) = real(dot(weight, storage(c * DensityMatrix(data))))
    @test gradient(loss, c)[1] ≈ regression_gradient_fd(p -> loss(build(p)), p) atol=1e-8
    loss_input(v) = real(dot(weight, storage(c * DensityMatrix(v))))
    @test gradient(loss_input, data)[1] ≈ regression_gradient_fd(loss_input, data) atol=1e-8
end

@testset "adjoint FSIM and controlled-controlled phase derivatives" begin
    p = [.3, .2, .1, .4, .5]
    build(p) = QCircuit([FSIMGate((1, 2), p; isparas=fill(true, 5))'])
    x = StateVector(ComplexF64[0, 1, 0, 0])
    target = StateVector(ComplexF64[0, 0, 1, 0])
    loss(c) = real(dot(target, c * x))
    @test gradient(loss, build(p))[1] ≈ regression_gradient_fd(p -> loss(build(p)), p) atol=1e-8

    phase_input = qstate([.5, .5, .5])
    phase_target = onehot_encoding([1, 1, 1])
    phase_circuit(p) = QCircuit([CCPHASEGate(3, 1, 2, p[1])])
    phase_loss(c) = imag(dot(phase_target, c * phase_input))
    @test gradient(phase_loss, phase_circuit([.2]))[1] ≈
        regression_gradient_fd(p -> phase_loss(phase_circuit(p)), [.2]) atol=1e-8
    @test differentiate(CCPHASEGate((1, 2, 3), .2; isparas=false)) === nothing
end

@testset "channel checkpoints and pure-to-density pullbacks" begin
    p = [.2, -.3, .4]
    weight = ComplexF64[.2+.1im .3+.4im; -.4+.2im .6-.1im]
    psi = StateVector(ComplexF64[.6, .8im])
    for gamma in (.2, 1.0)
        build(p) = QCircuit([RyGate(1, p[1]; isparas=true),
            QCircuit([AmplitudeDamping(1; γ=gamma), RzGate(1, p[2]; isparas=true)]),
            Depolarizing(1; p=.1), RxGate(1, p[3]; isparas=true)])
        c = build(p)
        for initial in (psi, DensityMatrix(psi))
            loss(c) = real(dot(weight, storage(c * initial)))
            @test gradient(loss, c)[1] ≈ regression_gradient_fd(p -> loss(build(p)), p) atol=1e-8
            inplace_loss(c) = real(dot(weight, storage(apply!(c, copy(initial)))))
            @test gradient(inplace_loss, c)[1] ≈ regression_gradient_fd(p -> loss(build(p)), p) atol=1e-8
        end
        loss_input(v) = real(dot(weight, storage(c * StateVector(v))))
        @test gradient(loss_input, storage(psi))[1] ≈
            regression_gradient_fd(loss_input, storage(psi)) atol=1e-8
        _, back = Zygote.pullback(c -> real(dot(weight, storage(c * psi))), c)
        first = copy(back(1.0)[1])
        @test back(1.0)[1] ≈ first
        @test back(2.0)[1] ≈ 2first
    end

    c = QCircuit([RyGate(1, .2; isparas=true), AmplitudeDamping(1; γ=1.0)])
    @test gradient(c -> real(sum(storage(c * DensityMatrix(1)))), c)[1] ≈ [0.0] atol=1e-14
end

@testset "state constructors return array cotangents" begin
    h = QubitsTerm(1 => "Z")
    A = ComplexF64[1 0; 0 1]
    loss(v) = real(expectation(h, StateVector(A * v)))
    @test gradient(loss, ComplexF64[.6, .8])[1] ≈ [1.2, -1.6]
    @test gradient(loss, [.6, .8])[1] ≈ [1.2, -1.6]
    @test eltype(gradient(loss, [.6, .8])[1]) <: Real

    observable = QubitsTerm(1 => "+"; coeff=.2+.3im) + QubitsTerm(1 => "Y")
    data = ComplexF64[.4 .1+.2im; .1-.2im .6]
    for source in (data, vec(data))
        dm_loss(v) = abs2(expectation(observable, DensityMatrix(2 .* v)))
        @test gradient(dm_loss, source)[1] ≈ regression_gradient_fd(dm_loss, source) atol=1e-8
        @test size(gradient(dm_loss, source)[1]) == size(source)
    end
    pure_dm_loss(v) = real(expectation(h, DensityMatrix(StateVector(A * v))))
    @test gradient(pure_dm_loss, ComplexF64[.6, .8])[1] ≈ [1.2, -1.6]
end

@testset "reusable long-operator expectation pullbacks" begin
    hermitian_op = QubitsTerm(Dict(i => "Z" for i in 1:6)) + QubitsTerm(1 => "Z")
    nonhermitian_op = QubitsTerm(Dict(i => (i == 1 ? "+" : "Z") for i in 1:6); coeff=.4im) +
        QubitsTerm(1 => "Y"; coeff=.3)
    psi = StateVector(normalize(ComplexF64[sin(i) + im * cos(2i) for i in 1:64]))
    for op in (hermitian_op, nonhermitian_op)
        _, back = Zygote.pullback(s -> expectation(op, s), psi)
        H = matrix(6, op)
        first = back(1.0)[1]
        snapshot = copy(storage(first))
        for seed in (1.0, 2.0, .3+.2im, 1.0)
            expected = (conj(seed) * H + seed * H') * storage(psi)
            @test storage(back(seed)[1]) ≈ expected
        end
        @test storage(first) == snapshot
    end
end
