"""Exact gate-occurrence parameter shifts; unknown gates need a `parameter_shift_rule`."""
struct ParameterShift <: AbstractGradientMethod end
"""Central differences. Sampling variance grows as 1/step²; truncation bias is not a standard error."""
struct FiniteDifference <: AbstractGradientMethod
    step::Float64
    function FiniteDifference(;step::Real=0.01)
        isfinite(step) && step > 0 && isfinite(Float64(step)) && Float64(step)>0 || throw(ArgumentError("step must be positive and finite"))
        new(Float64(step))
    end
end
"""Average independent Rademacher simultaneous perturbations using central differences."""
struct SPSAGradient <: AbstractGradientMethod
    step::Float64
    directions::Int
    function SPSAGradient(;step::Real=0.1,directions::Integer=8)
        h = FiniteDifference(;step=step).step
        !(directions isa Bool) && 1 <= directions <= typemax(Int) || throw(ArgumentError("directions must be a positive Int"))
        new(h,Int(directions))
    end
end

"""
    parameter_shift_rule(gate, active_index)

Return `(coefficient, shift)` pairs for the derivative of one active gate slot,
or `nothing` if unsupported. A recipe is a contract of the gate family, not a
rule inferred from its matrix at one angle. Shared slots are shifted separately.
"""
parameter_shift_rule(::Gate,::Integer) = nothing
function parameter_shift_rule(g::Union{RxGate,RyGate,RzGate,PHASEGate,CPHASEGate,CCPHASEGate},i::Integer)
    1 <= i <= nparameters(g) || throw(BoundsError(active_parameters(g),i))
    return [(0.5,pi/2),(-0.5,-pi/2)]
end
function parameter_shift_rule(g::Union{CRxGate,CRyGate,CRzGate},i::Integer)
    1 <= i <= nparameters(g) || throw(BoundsError(active_parameters(g),i))
    # Controlled rotations have gaps 1/2 and 1, requiring four evaluations.
    a,b = (sqrt(2)+1)/(4sqrt(2)), (1-sqrt(2))/(4sqrt(2))
    return [(a,pi/2),(-a,-pi/2),(b,3pi/2),(-b,-3pi/2)]
end
parameter_shift_rule(g::AdjointQuantumGate,i::Integer) = parameter_shift_rule(g.parent,i)

"""
    ShotExpectationObjective(template, observable, initial; shots, parameter_map,
                             backend, method, noise_model, readout, classical)

Snapshot a scalar finite-shot expectation. `shots` is the budget PER objective
execution, shared across its Pauli groups; a gradient executes many objectives.
Noise rules are expanded once at construction and frozen, including rules that
inspect gate angles. Use an explicit function with finite differences for a
parameter-dependent noise model. Batch objectives are not implicit reductions.
"""
struct ShotExpectationObjective{S<:AbstractQuantumState,B<:AbstractBackend,M,P<:AbstractParameterMap}
    template::QCircuit
    plan::MeasurementPlan
    initial_state::S
    parameter_map::P
    shots::Int
    backend::B
    method::M
    readout::Vector{ReadoutError}
    classical::ClassicalRegister
    prepared::Union{Nothing,EstimationPlan}
    allocation::Union{Symbol,VarianceAllocation}
end
function ShotExpectationObjective(template::Union{QCircuit,_ParameterContext},observable::Union{QubitsTerm,QubitsOperator},initial::AbstractQuantumState;
        shots::Integer,parameter_map=nothing,parameter_order=nothing,fixed=nothing,backend::AbstractBackend=MOSSQuantum.backend(initial),
        method=DensityMatrixEvolution(),noise_model=nothing,readout=ReadoutError[],classical=nothing,
        grouping::Symbol=:qwc,atol::Real=0,max_terms::Integer=100_000,allocation=:uniform)
    initial isa Union{BatchStateVector,BatchDensityMatrix} && throw(ArgumentError("a shot objective needs one state; reduce batch objectives explicitly"))
    circuit,map,errors = _prepare_execution_parameters(template;parameter_map,parameter_order,fixed,noise_model,readout)
    plan = measurement_plan(observable;grouping=grouping,atol=atol,max_terms=max_terms)
    budget = _execution_shots(shots)
    _check_circuit_estimation(plan,circuit,initial,budget)
    register = _initial_classical(classical)
    if _is_symbolic_map(map)
        validate_positions(circuit,nqubits(initial))
        _validate_classical_flow(circuit,register)
        _check_readout_errors(errors)
    else
        _check_noise_execution(circuit,initial,backend,method,Int[],errors;classical=register)
    end
    prepared = backend isa CPUBackend && initial isa Union{StateVector,DensityMatrix} ? prepare_estimation(circuit,observable,initial;
        parameter_map=map,method=method,readout=errors,classical=register,grouping=grouping,atol=atol,max_terms=max_terms) : nothing
    if isnothing(prepared)
        allocation === :uniform || throw(ArgumentError("adaptive allocation requires CPU prepared execution"))
    else
        _estimation_cost(prepared,budget,allocation)
    end
    return ShotExpectationObjective(circuit,plan,copy(initial),map,budget,backend,method,errors,register,prepared,allocation)
end
parameter_order(objective::ShotExpectationObjective) = parameter_order(objective.parameter_map)
trainable_parameters(objective::ShotExpectationObjective) = trainable_parameters(objective.parameter_map)
independent_parameters(objective::ShotExpectationObjective) = independent_parameters(objective.parameter_map)
parameter_info(objective::ShotExpectationObjective) = parameter_info((;template=objective.template,parameter_map=objective.parameter_map))
initial_parameters(objective::ShotExpectationObjective;kwargs...) = initial_parameters((;template=objective.template,parameter_map=objective.parameter_map);kwargs...)
required_shots(objective::ShotExpectationObjective) = isempty(objective.plan.groups) ? 0 : objective.shots
function estimate(objective::ShotExpectationObjective,values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng(),budget=nothing)
    x = _gradient_input(objective,values)
    if !isnothing(objective.prepared)
        return estimate(objective.prepared,x;shots=objective.shots,
                        allocation=objective.allocation,rng=rng,budget=budget)
    end
    bound = bind_parameters(objective.template,x,objective.parameter_map)
    return _with_shot_budget(budget,required_shots(objective)) do
        _sample_bound(objective,bound,rng)
    end
end
evaluate(objective::ShotExpectationObjective,values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng(),budget=nothing) = estimate(objective,values;rng=rng,budget=budget).value
function _sample_bound(objective::ShotExpectationObjective,bound,rng)
    if !isnothing(objective.prepared)
        return estimate(_bind_estimation_flat(objective.prepared,active_parameters(bound));
                        shots=objective.shots,allocation=objective.allocation,rng=rng)
    end
    return estimate(objective.plan,bound,objective.initial_state;shots=objective.shots,
        backend=objective.backend,method=objective.method,readout=objective.readout,classical=objective.classical,rng=rng)
end

"""
Gradient statistics. `shots` is the total actual measurement budget including
an independent value estimate; `evaluations` counts objective calls.
`sampling_covariance` propagates measurement error. `covariance` additionally
estimates SPSA direction variability from independent directions; it is `nothing`
for one SPSA direction. `stderr` follows `covariance`. Neither includes finite
step bias, physical noise bias, or an error guarantee from a finite sample.
"""
struct GradientEstimate
    value::Float64
    value_variance::Float64
    gradient::Vector{Float64}
    sampling_covariance::Matrix{Float64}
    covariance::Union{Nothing,Matrix{Float64}}
    stderr::Union{Nothing,Vector{Float64}}
    shots::Int
    evaluations::Int
end

function _checked_shift_recipe(g::Gate,i)
    recipe = parameter_shift_rule(g,i)
    isnothing(recipe) && return nothing
    isempty(recipe) && throw(ArgumentError("parameter shift recipe cannot be empty"))
    pairs = Tuple{Float64,Float64}[]
    for item in recipe
        length(item)==2 || throw(ArgumentError("shift terms need coefficient and shift"))
        a,s = item
        a isa Real && s isa Real && isfinite(a) && isfinite(s) || throw(ArgumentError("shift recipes must be finite and real"))
        push!(pairs,(Float64(a),Float64(s)))
    end
    all(t -> all(isfinite,t),pairs) || throw(ArgumentError("shift recipe overflows Float64"))
    abs(sum(first,pairs)) <= 1e-12*max(1,sum(t->abs(first(t)),pairs)) || throw(ArgumentError("shift coefficients must sum to zero"))
    return pairs
end
function _shift_recipes!(recipes,circuit)
    for operation in circuit
        if operation isa QCircuit
            _shift_recipes!(recipes,operation) || return false
        elseif operation isa Conditional
            _shift_recipes!(recipes,operation.then_branch) || return false
            _shift_recipes!(recipes,operation.else_branch) || return false
        else
            for i in 1:nparameters(operation)
                operation isa Gate || return false
                recipe = _checked_shift_recipe(operation,i)
                isnothing(recipe) && return false
                push!(recipes,recipe)
            end
        end
    end
    return true
end
const _KnownShiftGate = Union{RxGate,RyGate,RzGate,PHASEGate,CPHASEGate,CCPHASEGate,CRxGate,CRyGate,CRzGate}
_known_shift_gate(operation::Gate) = operation isa _KnownShiftGate
_known_shift_gate(operation::AdjointQuantumGate) = _known_shift_gate(operation.parent)
function _static_shift_support(circuit::QCircuit)
    for operation in circuit
        if operation isa QCircuit
            _static_shift_support(operation) || return false
        elseif operation isa Conditional
            _static_shift_support(operation.then_branch) && _static_shift_support(operation.else_branch) || return false
        elseif nparameters(operation)>0
            gate = operation isa QuantumCircuits.ParameterizedInstruction ? operation.prototype : operation
            gate isa Gate && _known_shift_gate(gate) || return false
        end
    end
    return true
end

function supports_gradient(::ParameterShift,objective::Union{ExpectationObjective,ShotExpectationObjective})
    try
        _check_parameter_map(objective.template,objective.parameter_map)
        objective isa ExpectationObjective && !_parameter_deterministic(objective.template) && return false
        _is_symbolic_map(objective.parameter_map) && return _static_shift_support(objective.template)
        return _shift_recipes!(Any[],objective.template)
    catch err
        err isa InterruptException && rethrow()
        return false
    end
end
supports_gradient(::Union{FiniteDifference,SPSAGradient},::Union{ShotExpectationObjective,Function}) = true
supports_gradient(::Union{FiniteDifference,SPSAGradient},objective::ExpectationObjective) = _parameter_deterministic(objective.template)

function _check_gradient_gate_values(circuit::QCircuit)
    for op in circuit
        if op isa QCircuit
            _check_gradient_gate_values(op)
        elseif op isa Conditional
            _check_gradient_gate_values(op.then_branch)
            _check_gradient_gate_values(op.else_branch)
        elseif op isa Gate
            _check_batch_objective_gate(op)
        end
    end
    return nothing
end
function _validate_sampled_bound(objective::ExpectationObjective,bound)
    validate_positions(bound,nqubits(objective.initial_state))
    validate_backend_execution(objective.backend,bound,objective.initial_state;mode=:apply)
    supports(objective.backend,bound,objective.initial_state) ||
        throw(UnsupportedOperation(objective.backend,bound,objective.initial_state,:apply))
    objective.backend isa CPUBackend && _check_gradient_gate_values(bound)
    return bound
end
function _validate_sampled_bound(objective::ShotExpectationObjective,bound)
    _check_noise_execution(bound,objective.initial_state,objective.backend,objective.method,Int[],
                           objective.readout;classical=objective.classical)
    objective.backend isa CPUBackend && _check_gradient_gate_values(bound)
    return bound
end
function supports_gradient(method::Union{ParameterShift,FiniteDifference,SPSAGradient},
                           objective::Union{ExpectationObjective,ShotExpectationObjective},
                           values::AbstractVector{<:Real})
    try
        x = _gradient_input(objective,values)
        objective isa ExpectationObjective && !_parameter_deterministic(objective.template) && return false
        bound = _validate_sampled_bound(objective,bind_parameters(objective.template,x,objective.parameter_map))
        return !(method isa ParameterShift) || _shift_recipes!(Any[],bound)
    catch err
        err isa Union{InterruptException,OutOfMemoryError} && rethrow()
        return false
    end
end
supports_gradient(method::Union{FiniteDifference,SPSAGradient},objective::Function,values::AbstractVector{<:Real}) =
    supports_gradient(method,objective)

function _require_sampled_gradient_support(method,objective,values)
    supports_gradient(method,objective,values) || throw(UnsupportedGradient(method,objective))
    return nothing
end

function _gradient_input(objective,values)
    _check_gradient_input(values)
    if objective isa Union{ExpectationObjective,ShotExpectationObjective}
        _check_parameter_map(objective.template,objective.parameter_map)
        length(values)==nparameters(objective.parameter_map) || throw(DimensionMismatch("independent parameter count disagrees"))
        _is_symbolic_map(objective.parameter_map) && any(x -> x isa Bool,values) &&
            throw(ArgumentError("symbolic parameter values must be real numbers, not Bool"))
    end
    result = Float64[values...]
    all(isfinite,result) || throw(ArgumentError("parameters overflow Float64"))
    return result
end
function _gradient_observation(objective::ShotExpectationObjective,values,rng)
    sample = estimate(objective,values;rng=rng)
    return (value=sample.value,variance=sample.variance,shots=sample.shots)
end
function _gradient_observation(objective,values,rng)
    value = Float64(_check_objective_value(evaluate(objective,copy(values))))
    isfinite(value) || throw(ArgumentError("objective must be finite"))
    return (value=value,variance=0.0,shots=0)
end
function _gradient_flat_observation(objective,flat,rng)
    if objective isa ShotExpectationObjective && !isnothing(objective.prepared)
        sample = estimate(_bind_estimation_flat(objective.prepared,flat);
                          shots=objective.shots,allocation=objective.allocation,rng=rng)
        return (value=sample.value,variance=sample.variance,shots=sample.shots)
    end
    bound = _is_symbolic_map(objective.parameter_map) ? _flat_bind(objective.template,flat) :
        bind_parameters(objective.template,flat)
    if objective isa ShotExpectationObjective
        sample = _sample_bound(objective,bound,rng)
        return (value=sample.value,variance=sample.variance,shots=sample.shots)
    end
    state = apply!(objective.backend,bound,copy(objective.initial_state))
    value = Float64(real(expectation(objective.backend,objective.observable,state)))
    isfinite(value) || throw(ArgumentError("objective must be finite"))
    return (value=value,variance=0.0,shots=0)
end
function _gradient_result(value,gradient,sampling,covariance,shots,evaluations)
    all(isfinite,gradient) && all(isfinite,sampling) && (isnothing(covariance) || all(isfinite,covariance)) ||
        throw(ArgumentError("gradient statistics overflowed"))
    stderr = isnothing(covariance) ? nothing : sqrt.(max.(diag(covariance),0))
    return GradientEstimate(value.value,value.variance,gradient,sampling,covariance,stderr,shots,evaluations)
end

"""Estimate a gradient with explicit RNG, statistical uncertainty and shot accounting."""
estimate_gradient(method::AbstractGradientMethod,objective,values::AbstractVector{<:Real};kwargs...) =
    throw(UnsupportedGradient(method,objective))
function _estimate_gradient(method::ParameterShift,objective::Union{ExpectationObjective,ShotExpectationObjective},values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng())
    x = _gradient_input(objective,values)
    _require_sampled_gradient_support(method,objective,x)
    bound = bind_parameters(objective.template,x,objective.parameter_map)
    recipes = Any[]
    _shift_recipes!(recipes,bound) || throw(UnsupportedGradient(method,objective))
    flat = expand_parameters(objective.parameter_map,x)
    # Validate all recipes before any objective sampling or RNG consumption.
    if _is_symbolic_map(objective.parameter_map)
        for (slot,recipe) in enumerate(recipes), (_,shift) in recipe
            shifted = copy(flat); shifted[slot] += shift
            _validate_sampled_bound(objective,_flat_bind(objective.template,shifted))
        end
    end
    value = _gradient_observation(objective,x,rng)
    gradient = zeros(length(x)); covariance = zeros(length(x),length(x))
    shots,evaluations = value.shots,1
    for (slot,recipe) in enumerate(recipes)
        row = _parameter_row(objective.parameter_map,slot)
        for (weight,shift) in recipe
            shifted = copy(flat); shifted[slot] += shift
            sample = _gradient_flat_observation(objective,shifted,rng)
            for (target,coefficient) in row
                gradient[target] += coefficient*weight*sample.value
                for (other,other_coefficient) in row
                    covariance[target,other] += coefficient*other_coefficient*weight^2*sample.variance
                end
            end
            shots = Base.checked_add(shots,sample.shots); evaluations += 1
        end
    end
    return _gradient_result(value,gradient,covariance,copy(covariance),shots,evaluations)
end
function _estimate_gradient(method::FiniteDifference,objective,values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng())
    x = _gradient_input(objective,values)
    _require_sampled_gradient_support(method,objective,x)
    perturbations = Tuple{Vector{Float64},Vector{Float64}}[]
    for i in eachindex(x)
        plus,minus = copy(x),copy(x)
        plus[i] += method.step; minus[i] -= method.step
        plus[i] != minus[i] || throw(ArgumentError("difference step is below parameter resolution"))
        all(isfinite,plus) && all(isfinite,minus) || throw(ArgumentError("difference step overflows parameter values"))
        if objective isa Union{ExpectationObjective,ShotExpectationObjective} && _is_symbolic_map(objective.parameter_map)
            _validate_sampled_bound(objective,bind_parameters(objective.template,plus,objective.parameter_map))
            _validate_sampled_bound(objective,bind_parameters(objective.template,minus,objective.parameter_map))
        end
        push!(perturbations,(plus,minus))
    end
    value = _gradient_observation(objective,x,rng)
    gradient = zeros(length(x)); covariance = zeros(length(x),length(x))
    shots,evaluations = value.shots,1
    for (i,(plus,minus)) in enumerate(perturbations)
        a,b = _gradient_observation(objective,plus,rng),_gradient_observation(objective,minus,rng)
        gradient[i] = (a.value-b.value)/(2method.step)
        covariance[i,i] = (a.variance+b.variance)/(4method.step^2)
        shots = Base.checked_add(shots,Base.checked_add(a.shots,b.shots)); evaluations += 2
    end
    return _gradient_result(value,gradient,covariance,copy(covariance),shots,evaluations)
end
function _estimate_gradient(method::SPSAGradient,objective,values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng())
    x = _gradient_input(objective,values)
    _require_sampled_gradient_support(method,objective,x)
    value = _gradient_observation(objective,x,rng)
    n,m = length(x),method.directions
    gradient = zeros(n); sampling = zeros(n,n)
    shots,evaluations = value.shots,1
    n==0 && return _gradient_result(value,gradient,sampling,copy(sampling),shots,evaluations)
    samples = zeros(n,m)
    for j in 1:m
        direction = [rand(rng,Bool) ? 1.0 : -1.0 for _ in 1:n]
        plus,minus = x+method.step*direction,x-method.step*direction
        all(plus .!= minus) || throw(ArgumentError("SPSA step is below parameter resolution"))
        a,b = _gradient_observation(objective,plus,rng),_gradient_observation(objective,minus,rng)
        samples[:,j] .= ((a.value-b.value)/(2method.step))*direction
        sampling .+= ((a.variance+b.variance)/(4method.step^2*m^2))*(direction*direction')
        shots = Base.checked_add(shots,Base.checked_add(a.shots,b.shots)); evaluations += 2
    end
    gradient .= vec(sum(samples;dims=2))/m
    centered = samples .- gradient
    covariance = m>1 ? (centered*centered')/(m*(m-1)) : nothing
    return _gradient_result(value,gradient,sampling,covariance,shots,evaluations)
end
function value_and_gradient(method::Union{ParameterShift,FiniteDifference,SPSAGradient},objective,values::AbstractVector{<:Real};rng::Random.AbstractRNG=Random.default_rng(),budget=nothing)
    result = estimate_gradient(method,objective,values;rng=rng,budget=budget)
    return result.value,result.gradient
end

function required_shots(method::Union{ParameterShift,FiniteDifference,SPSAGradient},objective,values::AbstractVector{<:Real})
    x = _gradient_input(objective,values)
    _require_sampled_gradient_support(method,objective,x)
    calls = if method isa ParameterShift
        recipes = Any[]
        bound = bind_parameters(objective.template,x,objective.parameter_map)
        _shift_recipes!(recipes,bound) || throw(UnsupportedGradient(method,objective))
        Base.checked_add(1,sum(length,recipes;init=0))
    elseif method isa FiniteDifference
        Base.checked_add(1,Base.checked_mul(2,length(x)))
    else
        isempty(x) ? 1 : Base.checked_add(1,Base.checked_mul(2,method.directions))
    end
    return objective isa ShotExpectationObjective ? Base.checked_mul(calls,required_shots(objective)) : 0
end
function estimate_gradient(method::Union{ParameterShift,FiniteDifference,SPSAGradient},objective,values::AbstractVector{<:Real};
                           rng::Random.AbstractRNG=Random.default_rng(),budget=nothing)
    cost = required_shots(method,objective,values)
    return _with_shot_budget(budget,cost) do
        _estimate_gradient(method,objective,values;rng=rng)
    end
end
