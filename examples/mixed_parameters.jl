using MOSSQuantum

θ = Parameter(:θ)
circuit = QCircuit([
    RyGate(1,rand();isparas=true), # anonymous trainable angle, captured once
    RyGate(1,θ),                 # explicitly named trainable variable
    RzGate(1,rand()),            # fixed numeric angle
    RyGate(1,2θ+.1),             # shared named variable
])

compiled = compile_parameters(circuit)
objective = ExpectationObjective(compiled,QubitsTerm(1=>"Z"),StateVector(1))
x = initial_parameters(objective;values=Dict(θ=>.3))
println("Parameter order: ",parameter_order(objective))
println("Parameter sources: ",parameter_info(objective))
value,gradient = value_and_gradient(AdjointGradient(),objective,x)
println("Initial expectation: ",value)

# The optimizer updates every independent input, including anonymous angles.
x .-= 0.05 .* gradient
println("Updated expectation: ",evaluate(objective,x))

# Reusing the full compiled context preserves anonymous identities and defaults.
plan = prepare_estimation(compiled,QubitsTerm(1=>"Z"),StateVector(1))
println("Finite-shot expectation: ",estimate(plan,x;shots=1000).value)

anonymous = first(parameter_order(compiled))
frozen = compile_parameters(compiled;fixed=Dict(anonymous=>x[1]))
println("Remaining trainable inputs: ",parameter_order(frozen))
