"""One real coefficient times a Pauli word in a measurement plan."""
struct PauliMeasurementTerm
    positions::Vector{Int}
    bases::Vector{Symbol}
    coefficient::Float64
end

"""Terms measured together in the single-qubit bases listed by `qubits`."""
struct MeasurementGroup
    qubits::Vector{Int}
    bases::Vector{Symbol}
    terms::Vector{PauliMeasurementTerm}
end

"""
    MeasurementPlan

A reusable Pauli measurement plan constructed by [`measurement_plan`](@ref).
`constant` is evaluated without shots; `groups` contains the measured terms.
`nqubits` is the minimum register size required by the input observable.
Planning and statistics use Float64 coefficients. Treat the arrays in a plan as
read-only; planning owns its metadata independently of the observable.
"""
struct MeasurementPlan
    constant::Float64
    groups::Vector{MeasurementGroup}
    grouping::Symbol
    nqubits::Int
end

"""
Statistics for one measurement group. `sample_variance` is the unbiased sample
variance of the group's combined per-shot energy, including covariance between
terms measured in the same shot. Its contribution to the variance of the
estimated mean is `sample_variance / shots`.
"""
struct GroupEstimate
    group::MeasurementGroup
    shots::Int
    value::Float64
    sample_variance::Float64
end

"""
    ExpectationEstimate

Finite-shot expectation result. `value` estimates the observable expectation;
`variance` estimates the variance of that mean, and `stderr = sqrt(variance)`.
`shots` counts actual measurements, while `requested_shots` records the total
budget. A constant or zero observable consumes zero shots. `groups` records
the allocated shots, basis and statistics for each independent group.

The error estimate is a sampling standard error, not a deterministic bound or
a confidence interval. In particular, a finite sample can have zero empirical
variance even when the underlying distribution is not deterministic.
"""
struct ExpectationEstimate
    value::Float64
    variance::Float64
    stderr::Float64
    shots::Int
    requested_shots::Int
    groups::Vector{GroupEstimate}
end

const _MEASUREMENT_BASES = (:X, :Y, :Z)

function _measurement_number(value)
    converted = ComplexF64(value)
    isfinite(converted) || throw(ArgumentError("observable coefficients and matrices must be finite in Float64"))
    return converted
end

function _measurement_terms(observable::QubitsTerm)
    return (observable,)
end

function _measurement_terms(observable::QubitsOperator)
    # Sort the supports so dictionary insertion order cannot change a plan.
    return (QubitsTerm(Int[key...], ops, coefficient)
            for key in sort!(collect(keys(observable.data)))
            for (ops, coefficient) in observable.data[key])
end

function _measurement_pauli_expansion(observable, max_terms::Int)
    combined = Dict{Tuple,ComplexF64}()
    required_qubits = 0
    for term in _measurement_terms(observable)
        pos, ops = positions(term), oplist(term)
        length(pos) == length(ops) || throw(ArgumentError("operator positions and matrices must have equal length"))
        all(p -> p > 0, pos) || throw(ArgumentError("operator positions must be positive"))
        length(unique(pos)) == length(pos) || throw(ArgumentError("operator positions must be distinct"))
        isempty(pos) || (required_qubits = max(required_qubits, maximum(pos)))
        expansion = Dict{Tuple,ComplexF64}(() => _measurement_number(coeff(term)))
        for index in sortperm(pos)
            matrix = ops[index]
            size(matrix) == (2, 2) || throw(DimensionMismatch("measurement planning requires local 2×2 matrices"))
            a, b = _measurement_number(matrix[1, 1]), _measurement_number(matrix[1, 2])
            c, d = _measurement_number(matrix[2, 1]), _measurement_number(matrix[2, 2])
            components = ((a + d) / 2, (b + c) / 2, (c - b) / (2im), (a - d) / 2)
            next = Dict{Tuple,ComplexF64}()
            for (word, coefficient) in expansion, axis in 0:3
                component = components[axis + 1]
                iszero(component) && continue
                key = axis == 0 ? word : (word..., (pos[index], axis))
                value = coefficient * component
                isfinite(value) || throw(ArgumentError("Pauli expansion overflowed Float64"))
                iszero(value) && continue
                next[key] = value
                length(next) <= max_terms || throw(ArgumentError("Pauli expansion exceeds max_terms=$max_terms; increase the explicit limit or provide a smaller observable"))
            end
            expansion = next
        end
        for (word, coefficient) in expansion
            value = get(combined, word, zero(ComplexF64)) + coefficient
            isfinite(value) || throw(ArgumentError("combined Pauli coefficients overflowed Float64"))
            if iszero(value)
                delete!(combined, word)
            else
                combined[word] = value
            end
            length(combined) <= max_terms || throw(ArgumentError("Pauli expansion exceeds max_terms=$max_terms; increase the explicit limit or provide a smaller observable"))
        end
    end
    return combined, required_qubits
end

function _measurement_compatible(basis::Dict{Int,Symbol}, term::PauliMeasurementTerm)
    return all(get(basis, position, axis) == axis for (position, axis) in zip(term.positions, term.bases))
end

"""
    measurement_plan(observable; grouping=:qwc, atol=0, max_terms=100_000)

Expand a `QubitsTerm` or `QubitsOperator` into Pauli words, combine duplicate
words, and group them for finite-shot measurement. Arbitrary local 2×2 matrices
are expanded into I/X/Y/Z without building a full-register matrix. The resulting
observable must be Hermitian (all combined Pauli coefficients real).

`:qwc` deterministically groups qubit-wise commuting words, which can share
single-qubit basis rotations; `:none` measures each nonconstant word separately.
The greedy grouping is not guaranteed minimal. `atol` is an explicit absolute
coefficient tolerance: coefficients of magnitude at most `atol` are discarded
and imaginary components of magnitude at most `atol` are accepted as roundoff.
The default discards only exact zeros. Local expansion may grow exponentially;
`max_terms` bounds both intermediate and combined word counts and never silently
truncates an observable.
"""
function measurement_plan(observable::Union{QubitsTerm,QubitsOperator};
                          grouping::Symbol=:qwc, atol::Real=0, max_terms::Integer=100_000)
    grouping in (:qwc, :none) || throw(ArgumentError("grouping must be :qwc or :none"))
    isfinite(atol) && atol >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))
    !(max_terms isa Bool) && 1 <= max_terms <= typemax(Int) ||
        throw(ArgumentError("max_terms must be a positive Int-sized integer"))
    words, required_qubits = _measurement_pauli_expansion(observable, Int(max_terms))
    constant = 0.0
    grouped_terms = Vector{PauliMeasurementTerm}[]
    group_bases = Dict{Int,Symbol}[]
    for word in sort!(collect(keys(words)))
        coefficient = words[word]
        abs(coefficient) <= atol && continue
        abs(imag(coefficient)) <= atol || throw(ArgumentError("finite-shot estimation requires a Hermitian observable; Pauli word $word has coefficient $coefficient"))
        value = real(coefficient)
        if isempty(word)
            constant = value
            continue
        end
        term = PauliMeasurementTerm(Int[p for (p, _) in word],
                                    Symbol[_MEASUREMENT_BASES[a] for (_, a) in word], value)
        index = grouping == :qwc ? findfirst(b -> _measurement_compatible(b, term), group_bases) : nothing
        if isnothing(index)
            push!(grouped_terms, PauliMeasurementTerm[])
            push!(group_bases, Dict{Int,Symbol}())
            index = length(grouped_terms)
        end
        push!(grouped_terms[index], term)
        for (position, axis) in zip(term.positions, term.bases)
            group_bases[index][position] = axis
        end
    end
    groups = MeasurementGroup[]
    for (basis, terms) in zip(group_bases, grouped_terms)
        qubits = sort!(collect(keys(basis)))
        push!(groups, MeasurementGroup(qubits, Symbol[basis[q] for q in qubits], terms))
    end
    return MeasurementPlan(constant, groups, grouping, required_qubits)
end

function _measurement_allocations(plan::MeasurementPlan, shots::Integer)
    !(shots isa Bool) && 0 <= shots <= typemax(Int) ||
        throw(ArgumentError("shots must be a nonnegative Int-sized integer"))
    count = length(plan.groups)
    count == 0 && return Int[]
    div(shots, count) >= 2 || throw(ArgumentError("at least two shots per measurement group are required to estimate variance ($count groups)"))
    base, extra = divrem(Int(shots), count)
    return [base + (index <= extra) for index in 1:count]
end

function _measurement_rotation(group::MeasurementGroup)
    circuit = QCircuit()
    for (position, axis) in zip(group.qubits, group.bases)
        if axis === :X
            push!(circuit, HGate(position))
        elseif axis === :Y
            push!(circuit, adjoint(SGate(position)))
            push!(circuit, HGate(position))
        end
    end
    return circuit
end

function _group_estimate(group::MeasurementGroup, draws::AbstractMatrix{<:Integer})
    size(draws, 2) == length(group.qubits) || throw(DimensionMismatch("draw columns must match group qubits"))
    count = size(draws, 1)
    count >= 2 || throw(ArgumentError("at least two draws are required to estimate variance"))
    indices = Dict(position => index for (index, position) in enumerate(group.qubits))
    supports = [[indices[position] for position in term.positions] for term in group.terms]
    mean, m2 = 0.0, 0.0
    for shot in 1:count
        energy = 0.0
        for (term, support) in zip(group.terms, supports)
            sign = 1
            for column in support
                bit = draws[shot, column]
                bit in (0, 1) || throw(ArgumentError("measurement draws must contain only zero and one"))
                sign *= 1 - 2bit
            end
            energy += term.coefficient * sign
        end
        isfinite(energy) || throw(ArgumentError("sampled group energy overflowed Float64"))
        delta = energy - mean
        mean += delta / shot
        m2 += delta * (energy - mean)
    end
    variance = max(0.0, m2 / (count - 1))
    isfinite(mean) && isfinite(variance) || throw(ArgumentError("measurement statistics overflowed Float64"))
    return GroupEstimate(group, count, mean, variance)
end

function _assemble_estimate(plan::MeasurementPlan, requested_shots::Integer, groups::Vector{GroupEstimate})
    value = plan.constant + sum((group.value for group in groups); init=0.0)
    variance = sum((group.sample_variance / group.shots for group in groups); init=0.0)
    isfinite(value) && isfinite(variance) || throw(ArgumentError("expectation statistics overflowed Float64"))
    return ExpectationEstimate(value, variance, sqrt(variance),
                               sum((group.shots for group in groups); init=0), Int(requested_shots), groups)
end

"""
    estimate(observable, state; shots, rng=Random.default_rng(), grouping=:qwc,
             atol=0, max_terms=100_000, backend=backend(state))
    estimate(plan::MeasurementPlan, state; shots, rng=Random.default_rng(),
             backend=backend(state))

Estimate a Hermitian observable by actual finite-shot Pauli measurements.
`shots` is the total budget across measurement groups, allocated as evenly as
possible; earlier groups receive the remainder. Each nonconstant group requires
at least two shots. Constant and zero observables consume none. Input states
must be normalized. Inputs and reusable plans are not mutated.

Each group rotates an independent copy of the state into its measurement bases
and samples computational-basis outcomes. Error estimates include within-group
covariance. This is a statistical estimator, with no automatic differentiation
contract; `expectation` remains the exact deterministic operation.

For a batch, return one `ExpectationEstimate` per member, using `shots` as the
budget **per member** and consuming the supplied RNG in batch-column order.
"""
function estimate(observable::Union{QubitsTerm,QubitsOperator}, state::AbstractQuantumState;
                  shots::Integer, rng::Random.AbstractRNG=Random.default_rng(),
                  grouping::Symbol=:qwc, atol::Real=0, max_terms::Integer=100_000,
                  backend::AbstractBackend=MOSSQuantum.backend(state),readout=nothing)
    plan = measurement_plan(observable; grouping=grouping, atol=atol, max_terms=max_terms)
    return estimate(plan, state; shots=shots, rng=rng, backend=backend,readout=readout)
end

function estimate(plan::MeasurementPlan, state::AbstractQuantumState;
                  shots::Integer, rng::Random.AbstractRNG=Random.default_rng(),
                  backend::AbstractBackend=MOSSQuantum.backend(state),readout=nothing)
    !isnothing(readout) && return estimate(plan,QCircuit(),state;shots=shots,rng=rng,backend=backend,readout=readout)
    plan.nqubits <= nqubits(state) || throw(ArgumentError("observable acts outside the state's register"))
    allocations = _measurement_allocations(plan, shots)
    # Validate normalization even when the observable is constant or zero.
    probabilities(backend, state; qubits=Int[])
    estimates = GroupEstimate[]
    for (group, count) in zip(plan.groups, allocations)
        rotation = _measurement_rotation(group)
        # Z-only readout needs no gate capability, including for implicit
        # third-party states that expose probabilities without gate execution.
        rotated = isempty(rotation) ? state : apply!(backend, rotation, copy(state))
        distribution = probabilities(backend, rotated; qubits=group.qubits)
        distribution isa AbstractVector{<:Real} ||
            throw(ArgumentError("measurement probabilities must be a real vector"))
        Base.require_one_based_indexing(distribution)
        length(distribution) == _state_dimension(length(group.qubits)) ||
            throw(DimensionMismatch("measurement probability count must be 2^length(group.qubits)"))
        draws = Matrix{Int}(undef, count, length(group.qubits))
        _draw_samples!(draws, rng, distribution, count, length(group.qubits))
        push!(estimates, _group_estimate(group, draws))
    end
    return _assemble_estimate(plan, shots, estimates)
end

function estimate(plan::MeasurementPlan, state::Union{BatchStateVector,BatchDensityMatrix};
                  shots::Integer, rng::Random.AbstractRNG=Random.default_rng(),
                  backend::AbstractBackend=MOSSQuantum.backend(state),readout=nothing)
    !isnothing(readout) && return estimate(plan,QCircuit(),state;shots=shots,rng=rng,backend=backend,readout=readout)
    plan.nqubits <= nqubits(state) || throw(ArgumentError("observable acts outside the state's register"))
    _measurement_allocations(plan, shots)
    return [estimate(plan, state isa BatchStateVector ? StateVector(state, index) : DensityMatrix(state, index);
                     shots=shots, rng=rng, backend=backend) for index in 1:batch_size(state)]
end
