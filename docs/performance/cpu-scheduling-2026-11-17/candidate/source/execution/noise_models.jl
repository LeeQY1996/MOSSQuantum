"""
    ReadoutError(qubits, probabilities; scope=:terminal)

Classical confusion matrix: row `true+1`, column `reported+1`. The first qubit
is the least significant local bit. Rows sum to one. `scope` is `:terminal`,
`:measurement`, or `:all`; intermediate errors currently require one qubit.
Inputs are copied. Treat stored configuration as read-only.
"""
struct ReadoutError
    qubits::Vector{Int}
    probabilities::Matrix{Float64}
    scope::Symbol
    function ReadoutError(qubits, probabilities::AbstractMatrix{<:Real}; scope::Symbol=:terminal)
        qs = qubits isa Integer ? [Int(qubits)] : Int[qubits...]
        1 <= length(qs) <= 2 && all(>(0), qs) && allunique(qs) ||
            throw(ArgumentError("readout error requires one or two distinct positive qubits"))
        scope in (:terminal, :measurement, :all) || throw(ArgumentError("invalid readout scope"))
        scope != :terminal && length(qs) != 1 && throw(ArgumentError("intermediate readout errors require one qubit"))
        d = 2^length(qs)
        size(probabilities) == (d,d) || throw(DimensionMismatch("readout matrix dimensions must match qubits"))
        p = Matrix{Float64}(probabilities)
        all(x -> isfinite(x) && x >= 0, p) || throw(ArgumentError("readout probabilities must be finite and nonnegative"))
        tolerance = QuantumCircuits._channel_tolerance(eltype(probabilities), nothing)
        all(x -> isapprox(x,1; atol=tolerance, rtol=0), sum(p; dims=2)) ||
            throw(ArgumentError("readout probability rows must sum to one"))
        p ./= sum(p; dims=2)
        new(qs,p,scope)
    end
end
ReadoutError(qubit::Integer; p0_to_1::Real, p1_to_0::Real, scope::Symbol=:terminal) =
    ReadoutError(qubit, [1-p0_to_1 p0_to_1; p1_to_0 1-p1_to_0]; scope=scope)

"""An explicit idle interval, in the same time unit used by its noise rule."""
struct Delay <: AbstractInstruction
    position::Int
    duration::Float64
    function Delay(position::Int; duration::Real)
        position > 0 || throw(ArgumentError("position must be positive"))
        isfinite(duration) && duration >= 0 || throw(ArgumentError("duration must be finite and nonnegative"))
        new(position, Float64(duration))
    end
end
QuantumCircuits.positions(x::Delay) = (x.position,)
QuantumCircuits.nqubits(::Delay) = 1
QuantumCircuits.change_positions(x::Delay, mapping::AbstractDict) = Delay(mapping[x.position];duration=x.duration)
_cpu_supports(::Delay, ::Type{S}, action::Symbol) where S = action === :apply && S <: _DenseCPUState
_cpu_apply!(x::Delay, state::AbstractQuantumState) = (validate_positions(x,nqubits(state)); state)

"""
    NoiseRule(matcher, factory; when=:after, qubits=nothing)

Match an instruction type or predicate. Call `factory(instruction)` to produce
one physical QuantumMap or a vector of maps. Rules run in registration order,
only on original leaf instructions. `qubits` optionally matches the exact ordered
register. Factory arguments are independent copies.
"""
struct NoiseRule
    matcher::Any
    factory::Any
    when::Symbol
    qubits::Union{Nothing,Tuple{Vararg{Int}}}
    function NoiseRule(matcher, factory; when::Symbol=:after, qubits=nothing)
        when in (:before,:after) || throw(ArgumentError("when must be :before or :after"))
        matcher isa Type || matcher isa Function || throw(ArgumentError("matcher must be an instruction type or predicate"))
        matcher isa Type && !(matcher <: AbstractInstruction) && throw(ArgumentError("matcher must be an instruction type"))
        qs = isnothing(qubits) ? nothing : Tuple(Int[q for q in qubits])
        !isnothing(qs) && (!all(>(0),qs) || !allunique(qs)) && throw(ArgumentError("rule qubits must be positive and distinct"))
        new(matcher,factory,when,qs)
    end
end

function _physical_maps(maps)
    values = maps isa QuantumMap ? [maps] : collect(maps)
    all(x -> x isa QuantumMap, values) || throw(ArgumentError("noise factories must return QuantumMap values"))
    for x in values
        QuantumCircuits._validate_channel_data(x; check_tp=true)
    end
    return QuantumMap[deepcopy(x) for x in values]
end

"""Noise configuration with explicit preparation, instruction, terminal, and classical readout stages."""
struct NoiseModel
    rules::Vector{NoiseRule}
    readout::Vector{ReadoutError}
    preparation::Vector{QuantumMap}
    terminal::Vector{QuantumMap}
    function NoiseModel(; rules=NoiseRule[], readout=ReadoutError[], preparation=QuantumMap[], terminal=QuantumMap[])
        rs = deepcopy(NoiseRule[rules...])
        errors = readout isa ReadoutError ? [deepcopy(readout)] : deepcopy(ReadoutError[readout...])
        _check_readout_errors(errors)
        new(rs, errors, _physical_maps(preparation), _physical_maps(terminal))
    end
end

function _check_readout_errors(errors)
    for scope in (:terminal,:measurement)
        seen = Set{Int}()
        for error in errors
            # Revalidate mutable configuration before execution.
            ReadoutError(error.qubits,error.probabilities; scope=error.scope)
            error.scope in (scope,:all) || continue
            isempty(intersect(seen,error.qubits)) || throw(ArgumentError("overlapping readout errors in $scope scope"))
            union!(seen,error.qubits)
        end
    end
    return nothing
end

"""An explicitly expanded noise program; inspect `.circuit` and `.readout`."""
struct NoisyCircuit
    circuit::QCircuit
    readout::Vector{ReadoutError}
end

"""Bind the quantum template and retain an independent readout configuration."""
function bind_parameters(program::NoisyCircuit, values; kwargs...)
    return NoisyCircuit(bind_parameters(program.circuit, values; kwargs...), deepcopy(program.readout))
end
QuantumCircuits.independent_parameters(program::NoisyCircuit) = independent_parameters(program.circuit)
QuantumCircuits.parameter_expressions(program::NoisyCircuit) = parameter_expressions(program.circuit)
function QuantumCircuits.substitute_parameters(program::NoisyCircuit, replacements)
    return NoisyCircuit(substitute_parameters(program.circuit, replacements), deepcopy(program.readout))
end

function _append_noise!(output, instruction, rules, timing)
    # A symbolic wrapper describes the same gate family and positions as its
    # numeric prototype. Never pass placeholder angles to a user callback.
    matched_instruction = instruction isa QuantumCircuits.ParameterizedInstruction ? instruction.prototype : instruction
    for rule in rules
        rule.when === timing || continue
        isnothing(rule.qubits) || rule.qubits == Tuple(positions(instruction)) || continue
        matched = rule.matcher isa Type ? matched_instruction isa rule.matcher : rule.matcher(copy_instruction(instruction))
        matched isa Bool || throw(ArgumentError("noise predicate must return Bool"))
        matched || continue
        generated = rule.factory isa QuantumMap ? rule.factory : rule.factory(copy_instruction(instruction))
        append!(output, _physical_maps(generated))
    end
end

function _expand_noise!(output, circuit, rules)
    for instruction in circuit
        if instruction isa QCircuit
            _expand_noise!(output,instruction,rules)
        elseif instruction isa Conditional
            yes,no = AbstractInstruction[],AbstractInstruction[]
            _expand_noise!(yes,instruction.then_branch,rules)
            _expand_noise!(no,instruction.else_branch,rules)
            push!(output,Conditional(instruction.condition,QCircuit(yes);otherwise=QCircuit(no)))
        else
            _append_noise!(output,instruction,rules,:before)
            instruction isa Delay || push!(output,copy_instruction(instruction))
            _append_noise!(output,instruction,rules,:after)
        end
    end
end

"""Expand noise once without mutating the source circuit. Re-expansion is rejected."""
function with_noise(circuit::QCircuit, model::NoiseModel)
    if QuantumCircuits._has_parameterized(circuit)
        all(rule -> rule.matcher isa Type && rule.factory isa QuantumMap, model.rules) ||
            throw(ArgumentError("unbound parameter templates accept only instruction-type noise rules with fixed QuantumMap values; bind parameters before using a noise predicate or factory"))
    end
    _check_readout_errors(model.readout)
    output = AbstractInstruction[_physical_maps(model.preparation)...]
    _expand_noise!(output,circuit,model.rules)
    append!(output,_physical_maps(model.terminal))
    return NoisyCircuit(QCircuit(output),deepcopy(model.readout))
end
with_noise(::NoisyCircuit, ::NoiseModel) = throw(ArgumentError("noise is already expanded; use the original circuit"))

function _readout_register(errors, indices, n)
    _check_readout_errors(errors)
    expanded = copy(indices)
    for error in errors
        all(q -> q <= n, error.qubits) || throw(ArgumentError("readout qubit outside register"))
        error.scope in (:terminal,:all) || continue
        # Sampling the full correlated block before taking a marginal also works
        # when the requested output contains just one member of the block.
        isempty(intersect(error.qubits,indices)) && continue
        for q in error.qubits
            q in expanded || push!(expanded,q)
        end
    end
    return expanded
end

function _readout_samples!(samples, indices, errors, rng)
    for error in errors
        error.scope in (:terminal,:all) || continue
        columns = [findfirst(==(q),indices) for q in error.qubits]
        any(isnothing,columns) && continue
        for row in axes(samples,1)
            actual = sum(samples[row,c] << (j-1) for (j,c) in enumerate(columns))
            reported = discrete_sample(rng,view(error.probabilities,actual+1,:))-1
            for (j,c) in enumerate(columns)
                samples[row,c] = (reported >> (j-1)) & 1
            end
        end
    end
    return samples
end

function _reported_outcome(position, actual, errors, rng)
    for error in errors
        error.scope in (:measurement,:all) && error.qubits == [position] || continue
        return discrete_sample(rng,view(error.probabilities,actual+1,:))-1
    end
    return actual
end

"""Classical readout distribution; ideal `probabilities` retains its existing meaning."""
function readout_probabilities(state::AbstractQuantumState, errors; qubits=1:nqubits(state), backend=MOSSQuantum.backend(state))
    errors = errors isa ReadoutError ? [errors] : collect(errors)
    indices = _readout_qubits(state,qubits)
    expanded = _readout_register(errors,indices,nqubits(state))
    p = probabilities(backend,state; qubits=expanded)
    p isa AbstractVector{<:Real} || throw(ArgumentError("readout requires a real probability vector"))
    Base.require_one_based_indexing(p)
    length(p) == 2^length(expanded) || throw(DimensionMismatch("readout probability count must match qubits"))
    tolerance = _probability_tolerance(eltype(p))
    p = Float64[p...]
    _normalize_probabilities!(p,tolerance)
    for error in errors
        error.scope in (:terminal,:all) || continue
        columns = [findfirst(==(q),expanded) for q in error.qubits]
        any(isnothing,columns) && continue
        out = zeros(Float64,length(p))
        for basis in 0:length(p)-1
            actual = sum(((basis >> (c-1)) & 1) << (j-1) for (j,c) in enumerate(columns))
            for reported in 0:2^length(columns)-1
                target = basis
                for (j,c) in enumerate(columns)
                    target = (target & ~(1 << (c-1))) | (((reported >> (j-1)) & 1) << (c-1))
                end
                out[target+1] += p[basis+1]*error.probabilities[actual+1,reported+1]
            end
        end
        p = out
    end
    out = zeros(Float64,2^length(indices))
    mask = length(out)-1
    for basis in 0:length(p)-1
        out[(basis & mask)+1] += p[basis+1]
    end
    return out
end

function readout_probabilities(state::Union{BatchStateVector,BatchDensityMatrix},errors;
                               qubits=1:nqubits(state),backend=MOSSQuantum.backend(state))
    errors = errors isa ReadoutError ? [errors] : collect(errors)
    indices = _readout_qubits(state,qubits)
    expanded = _readout_register(errors,indices,nqubits(state))
    probabilities(backend,state;qubits=expanded)
    output = Matrix{Float64}(undef,2^length(indices),batch_size(state))
    for b in 1:batch_size(state)
        output[:,b] .= readout_probabilities(_shot_member(state,b),errors;qubits=indices,backend=backend)
    end
    return output
end
