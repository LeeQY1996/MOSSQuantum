# Run this file in a fresh process in an environment containing MOSS and the
# optional dependencies needed for the selected scenario.
using Test

scenario = isempty(ARGS) ? "core" : only(ARGS)

if scenario == "core"
    using MOSS
    loaded = Set(package.name for package in keys(Base.loaded_modules))
    @test all(name -> !(name in loaded), ("Zygote", "Plots", "LaTeXStrings", "FiniteDifferences"))
    @test !isdefined(MOSS, :Zygote)
    @test !isdefined(MOSS, :Requires)
    @test Base.get_extension(MOSS, :MOSSZygoteExt) === nothing
    @test Base.get_extension(MOSS, :MOSSPlotsExt) === nothing
    circuit = QCircuit()
    push!(circuit, HGate(1))
    @test norm(circuit * qstate(1)) ≈ 1
    @test_throws ArgumentError MOSS.QuantumCircuits.plot(circuit)
elseif scenario in ("zygote_first", "moss_first_zygote")
    if scenario == "zygote_first"
        using Zygote
        using MOSS
    else
        using MOSS
        using Zygote
    end
    circuit = QCircuit()
    theta = 0.37
    push!(circuit, RyGate(1, theta; isparas=true))
    observable = QubitsTerm(1 => "Z")
    initial = qstate(1)
    loss(c) = real(expectation(observable, c * initial))
    @test Zygote.gradient(loss, circuit)[1] ≈ [-sin(theta)]
    @test Base.get_extension(MOSS, :MOSSZygoteExt) !== nothing
elseif scenario in ("plots_first", "moss_first_plots", "latex_then_moss_then_plots")
    if scenario == "plots_first"
        using Plots, LaTeXStrings
        using MOSS
    elseif scenario == "moss_first_plots"
        using MOSS
        @test_throws ArgumentError MOSS.QuantumCircuits.plot(QCircuit())
        using LaTeXStrings, Plots
    else
        using LaTeXStrings
        using MOSS
        @test_throws ArgumentError MOSS.QuantumCircuits.plot(QCircuit())
        using Plots
    end
    circuit = QCircuit()
    push!(circuit, HGate(1))
    @test MOSS.QuantumCircuits.plot(circuit) isa Plots.Plot
    @test MOSS.QuantumCircuits.circuit_plot(circuit) isa Plots.Plot
    @test MOSS.QuantumCircuits.new_circuit_plot(1, 1) isa Plots.Plot
    @test Base.get_extension(MOSS, :MOSSPlotsExt) !== nothing
else
    throw(ArgumentError("unknown optional integration scenario: $scenario"))
end

println("Optional integration load order passed: ", scenario)
