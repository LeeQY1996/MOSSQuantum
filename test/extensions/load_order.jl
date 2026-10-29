# Run this file in a fresh process in an environment containing MOSSQuantum and the
# optional dependencies needed for the selected scenario.
using Test

scenario = isempty(ARGS) ? "core" : only(ARGS)

if scenario == "core"
    using MOSSQuantum
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test all(name -> !(name in loaded),
        ("ChainRulesCore", "Zygote", "Plots", "LaTeXStrings", "FiniteDifferences"))
    @test !isdefined(MOSSQuantum, :Zygote)
    @test !isdefined(MOSSQuantum, :Requires)
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumZygoteExt) === nothing
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) === nothing
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt) === nothing
    circuit = QCircuit()
    push!(circuit, HGate(1))
    @test norm(circuit * qstate(1)) ≈ 1
    batch = BatchStateVector(1, 2)
    @test norm(circuit * batch) ≈ ones(2)
    objective = BatchExpectationObjective(
        QCircuit([RyGate(1, 0.0; isparas=true)]), QubitsTerm(1 => "Z"), batch)
    @test evaluate(objective, [0.37]) ≈ cos(0.37)
    @test value_and_gradient(AdjointGradient(), objective, [0.37])[2] ≈ [-sin(0.37)]
    mixed = BatchDensityMatrix(batch)
    noisy_circuit = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=0.2)])
    mixed_objective = BatchExpectationObjective(noisy_circuit, QubitsTerm(1 => "Z"), mixed)
    @test size(storage(noisy_circuit * batch)) == (2, 2, 2)
    @test evaluate(mixed_objective, [0.37]) ≈ 0.2 + 0.8cos(0.37)
    @test value_and_gradient(AdjointGradient(), mixed_objective, [0.37])[2] ≈ [-0.8sin(0.37)]
    loaded_after_execution = Set(package.name for package in keys(Base.loaded_modules))
    @test all(name -> !(name in loaded_after_execution), ("ChainRulesCore", "Zygote"))
    @test_throws ArgumentError MOSSQuantum.QuantumCircuits.plot(circuit)
elseif scenario in ("chainrules_first", "mossquantum_first_chainrules")
    if scenario == "chainrules_first"
        using ChainRulesCore
        using MOSSQuantum
    else
        using MOSSQuantum
        @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) === nothing
        using ChainRulesCore
    end
    theta = 0.37
    circuit = QCircuit([RyGate(1, 0.0; isparas=true)])
    objective = ExpectationObjective(circuit, QubitsTerm(1 => "Z"), qstate(1))
    value, pullback = ChainRulesCore.rrule(differentiable_value,
        AdjointGradient(), objective, [theta])
    @test value ≈ cos(theta)
    @test pullback(1.0)[4] ≈ [-sin(theta)]
    batch_objective = BatchExpectationObjective(circuit, QubitsTerm(1 => "Z"),
        BatchStateVector(1, 2); reduction=:sum)
    batch_value, batch_pullback = ChainRulesCore.rrule(differentiable_value,
        AdjointGradient(), batch_objective, [theta])
    @test batch_value ≈ 2cos(theta)
    @test batch_pullback(1.0)[4] ≈ [-2sin(theta)]
    noisy_objective = BatchExpectationObjective(
        QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=0.2)]),
        QubitsTerm(1 => "Z"), BatchDensityMatrix(1, 2))
    mixed_value, mixed_pullback = ChainRulesCore.rrule(differentiable_value,
        AdjointGradient(), noisy_objective, [theta])
    @test mixed_value ≈ 0.2 + 0.8cos(theta)
    @test mixed_pullback(1.0)[4] ≈ [-0.8sin(theta)]
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) !== nothing
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumZygoteExt) === nothing
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test !("Zygote" in loaded)
elseif scenario in ("zygote_first", "mossquantum_first_zygote")
    if scenario == "zygote_first"
        using Zygote
        using MOSSQuantum
    else
        using MOSSQuantum
        using Zygote
    end
    circuit = QCircuit()
    theta = 0.37
    push!(circuit, RyGate(1, theta; isparas=true))
    observable = QubitsTerm(1 => "Z")
    initial = qstate(1)
    loss(c) = real(expectation(observable, c * initial))
    @test Zygote.gradient(loss, circuit)[1] ≈ [-sin(theta)]
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumZygoteExt) !== nothing
    objective = ExpectationObjective(circuit, observable, initial)
    parameter_loss(values) = differentiable_value(AdjointGradient(), objective, values)
    @test Zygote.gradient(parameter_loss, [theta])[1] ≈ [-sin(theta)]
    batch = BatchStateVector(1, 2)
    batch_loss(c) = real(sum(expectation(observable, c * batch)))
    @test Zygote.gradient(batch_loss, circuit)[1] ≈ [-2sin(theta)]
    batch_objective = BatchExpectationObjective(circuit, observable, batch)
    batch_parameter_loss(values) = differentiable_value(AdjointGradient(), batch_objective, values)
    @test Zygote.gradient(batch_parameter_loss, [theta])[1] ≈ [-sin(theta)]
    noisy_circuit = QCircuit([RyGate(1, 0.0; isparas=true), AmplitudeDamping(1; γ=0.2)])
    for batch_initial in (batch, BatchDensityMatrix(batch))
        noisy_batch_loss(values) = real(sum(expectation(observable,
            bind_parameters(noisy_circuit, values) * batch_initial)))
        @test Zygote.gradient(noisy_batch_loss, [theta])[1] ≈ [-1.6sin(theta)]
    end
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumChainRulesCoreExt) !== nothing
elseif scenario in ("plots_first", "mossquantum_first_plots", "latex_then_mossquantum_then_plots")
    if scenario == "plots_first"
        using Plots, LaTeXStrings
        using MOSSQuantum
    elseif scenario == "mossquantum_first_plots"
        using MOSSQuantum
        @test_throws ArgumentError MOSSQuantum.QuantumCircuits.plot(QCircuit())
        using LaTeXStrings, Plots
    else
        using LaTeXStrings
        using MOSSQuantum
        @test_throws ArgumentError MOSSQuantum.QuantumCircuits.plot(QCircuit())
        using Plots
    end
    circuit = QCircuit()
    push!(circuit, HGate(1))
    @test MOSSQuantum.QuantumCircuits.plot(circuit) isa Plots.Plot
    @test MOSSQuantum.QuantumCircuits.circuit_plot(circuit) isa Plots.Plot
    @test MOSSQuantum.QuantumCircuits.new_circuit_plot(1, 1) isa Plots.Plot
    @test Base.get_extension(MOSSQuantum, :MOSSQuantumPlotsExt) !== nothing
else
    throw(ArgumentError("unknown optional integration scenario: $scenario"))
end

println("Optional integration load order passed: ", scenario)
