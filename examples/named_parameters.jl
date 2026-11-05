using MOSSQuantum

θ = Parameter(:θ)
φ = Parameter(:φ)
circuit = QCircuit([RyGate(1, θ), RzGate(2, -θ/2 + φ + π/4),
                    CNOTGate(1, 2), RyGate(2, θ)])
observable = QubitsTerm(1 => "Z") + 0.3 * QubitsTerm(2 => "X")
initial = StateVector(2)

bound = bind_parameters(circuit, Dict(θ => 0.4, φ => 0.1))
println("Probabilities: ", probabilities(simulate(bound, initial).state))

objective = ExpectationObjective(circuit, observable, initial;
    parameter_order=[θ, φ])
value, gradient = value_and_gradient(AdjointGradient(), objective, [0.4, 0.1])
println("Parameter order: ", parameter_order(objective))
println("Expectation: ", value, "; gradient: ", gradient)

fixed_objective = ExpectationObjective(circuit, observable, initial;
    parameter_order=[θ, φ], fixed=Dict(φ => 0.1))
fixed_value, fixed_gradient = value_and_gradient(AdjointGradient(), fixed_objective, [0.4])
println("With φ fixed: ", fixed_value, "; θ gradient: ", fixed_gradient)

plan = prepare_execution(circuit, initial; parameter_order=[θ, φ])
println("Counts: ", execute(plan, [0.4, 0.1]; shots=1000).counts)
