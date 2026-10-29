"""
    estimate(observable, circuit, initial_state; shots, rng, grouping=:qwc, backend)
    estimate(plan::MeasurementPlan, circuit, initial_state; shots, rng, backend)

Estimate the output observable of a circuit with a total finite-shot budget.
Deterministic gate/Kraus circuits prepare a state once, then reuse independent
copies for measurement groups. Circuits with intermediate `QMeasure` instructions
replay those measurements for every shot in every group; sampling a single
collapsed trajectory is not substituted for independent circuit executions.

`QSelect` is not supported by this estimator: attempted and accepted measurement
budgets differ. Use `execute` to inspect post-selection acceptance explicitly,
or estimate a separately prepared normalized conditional state. For batches,
the budget is per member. Like the state estimator, this operation is stochastic
and has no automatic differentiation contract.
"""
function estimate(observable::Union{QubitsTerm,QubitsOperator}, circuit::QCircuit,
                  initial_state::AbstractQuantumState; shots::Integer,
                  rng::Random.AbstractRNG=Random.default_rng(), grouping::Symbol=:qwc,
                  atol::Real=0, max_terms::Integer=100_000,
                  backend::AbstractBackend=MOSSQuantum.backend(initial_state),
                  noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(),
                  parallel::Bool=false, chunk_size::Integer=256, classical=nothing)
    plan = measurement_plan(observable; grouping=grouping, atol=atol, max_terms=max_terms)
    return estimate(plan, circuit, initial_state; shots=shots, rng=rng, backend=backend,
                    noise_model,readout,method,parallel,chunk_size,classical)
end

function _check_circuit_estimation(plan, circuit, state, shots)
    _has_postselection(circuit) && throw(ArgumentError(
        "circuit estimation does not support QSelect; use execute for explicit attempted/accepted shots"))
    plan.nqubits <= nqubits(state) || throw(ArgumentError("observable acts outside the state's register"))
    return _measurement_allocations(plan, shots)
end

function estimate(plan::MeasurementPlan, circuit::QCircuit, initial_state::AbstractQuantumState;
                  shots::Integer, rng::Random.AbstractRNG=Random.default_rng(),
                  backend::AbstractBackend=MOSSQuantum.backend(initial_state),
                  noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(),
                  parallel::Bool=false, chunk_size::Integer=256, classical=nothing)
    circuit,errors = _noise_configuration(circuit,noise_model,readout)
    allocations = _check_circuit_estimation(plan, circuit, initial_state, shots)
    _check_noise_execution(circuit,initial_state,backend,method,Int[],errors;classical=classical)
    chunk_size > 0 && !(chunk_size isa Bool) || throw(ArgumentError("chunk_size must be positive"))
    parallel && !(method isa KrausTrajectory) && throw(ArgumentError("parallel requires KrausTrajectory"))
    isempty(plan.groups) && return _assemble_estimate(plan, shots, GroupEstimate[])
    if method isa DensityMatrixEvolution && isempty(errors) && _shot_deterministic(circuit)
        prepared = simulate(circuit, initial_state; backend=backend, rng=rng,classical=classical).state
        return estimate(plan, prepared; shots=shots, rng=rng, backend=backend)
    end
    estimates = GroupEstimate[]
    for (group, budget) in zip(plan.groups, allocations)
        measured = QCircuit([circuit, _measurement_rotation(group)])
        # Preserve existing RNG draws for the established measurement-only path.
        legacy = method isa DensityMatrixEvolution && isempty(errors)
        result = execute(measured, initial_state; shots=budget, qubits=group.qubits,
                         rng=rng, backend=backend,readout=errors,method=method,
                         parallel=parallel,chunk_size=chunk_size,result=legacy ? :full : :counts,classical=classical)
        push!(estimates, _group_estimate(group, legacy ? result.samples : result.counts))
    end
    return _assemble_estimate(plan, shots, estimates)
end

function estimate(plan::MeasurementPlan, circuit::QCircuit,
                  initial_state::Union{BatchStateVector,BatchDensityMatrix};
                  shots::Integer, rng::Random.AbstractRNG=Random.default_rng(),
                  backend::AbstractBackend=MOSSQuantum.backend(initial_state),
                  noise_model=nothing, readout=ReadoutError[], method=DensityMatrixEvolution(),
                  parallel::Bool=false, chunk_size::Integer=256, classical=nothing)
    circuit,errors = _noise_configuration(circuit,noise_model,readout)
    _check_circuit_estimation(plan, circuit, initial_state, shots)
    _check_noise_execution(circuit,initial_state,backend,method,Int[],errors;classical=classical)
    chunk_size > 0 && !(chunk_size isa Bool) || throw(ArgumentError("chunk_size must be positive"))
    parallel && !(method isa KrausTrajectory) && throw(ArgumentError("parallel requires KrausTrajectory"))
    return ExpectationEstimate[estimate(plan, circuit, _shot_member(initial_state, index);
        shots=shots, rng=rng, backend=backend,readout=errors,method=method,
        parallel=parallel,chunk_size=chunk_size,classical=classical) for index in 1:batch_size(initial_state)]
end

function estimate(observable, program::NoisyCircuit, initial::AbstractQuantumState;
                  noise_model=nothing, readout=ReadoutError[], kwargs...)
    isnothing(noise_model) || throw(ArgumentError("noise is already expanded"))
    errors = readout isa ReadoutError ? [readout] : collect(readout)
    return estimate(observable,program.circuit,initial;readout=vcat(program.readout,errors),kwargs...)
end

# Weighted Welford accumulation from counts preserves covariance within a group
# without retaining the shots × qubits sample matrix.
function _group_estimate(group::MeasurementGroup, histogram::Dict{String,Int})
    total = 0
    mean = 0.0
    m2 = 0.0
    columns = [[findfirst(==(q),group.qubits) for q in term.positions] for term in group.terms]
    for key in sort!(collect(keys(histogram)))
        weight = histogram[key]
        energy = sum(term.coefficient * (isodd(sum(key[c] == '1' for c in cols)) ? -1 : 1)
                     for (term,cols) in zip(group.terms,columns))
        next = total+weight
        delta = energy-mean
        mean += delta*(weight/next)
        m2 += delta^2*total*(weight/next)
        total = next
    end
    total >= 2 || throw(ArgumentError("group variance needs at least two shots"))
    variance = max(0.0,m2/(total-1))
    isfinite(mean) && isfinite(variance) || throw(ArgumentError("measurement statistics overflowed Float64"))
    return GroupEstimate(group,total,mean,variance)
end
