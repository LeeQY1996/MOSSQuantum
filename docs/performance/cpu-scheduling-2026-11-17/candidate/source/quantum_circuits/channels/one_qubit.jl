# Physical channel constructors retain the historical depolarizing and phase
# damping parameter conventions. General QuantumMap remains available for CP maps.
function _noise_probability(value::Real, name; upper=1)
    isfinite(value) && 0 <= value <= upper ||
        throw(ArgumentError("$name must be finite and between 0 and $upper"))
    return float(value)
end

function AmplitudeDamping(pos::Int; γ::Real)
    γ = _noise_probability(γ, "γ")
    return QuantumMap(pos, [[1 0; 0 sqrt(1-γ)], [0 sqrt(γ); 0 0]]; check_tp=true)
end

"""Phase damping with off-diagonal multiplier `sqrt(1-γ)`."""
function PhaseDamping(pos::Int; γ::Real)
    γ = _noise_probability(γ, "γ")
    return QuantumMap(pos, [[1 0; 0 sqrt(1-γ)], [0 0; 0 sqrt(γ)]]; check_tp=true)
end

BitFlip(pos::Int; p::Real) = PauliChannel(pos, ["I", "X"], [1-_noise_probability(p,"p"), p])
PhaseFlip(pos::Int; p::Real) = PauliChannel(pos, ["I", "Z"], [1-_noise_probability(p,"p"), p])
BitPhaseFlip(pos::Int; p::Real) = PauliChannel(pos, ["I", "Y"], [1-_noise_probability(p,"p"), p])

"""
    PauliChannel(positions, words, probabilities)

Mixture of Pauli words. The first character acts on the first supplied position
(the least significant local bit). Probabilities must sum to one.
"""
function PauliChannel(pos, words::AbstractVector{<:AbstractString}, probabilities::AbstractVector{<:Real})
    register = pos isa Int ? (pos,) : Tuple(pos)
    1 <= length(register) <= 2 || throw(ArgumentError("PauliChannel supports one or two qubits"))
    length(words) == length(probabilities) && !isempty(words) || throw(ArgumentError("words and probabilities must match"))
    matrices = Matrix{ComplexF64}[]
    lookup = Dict('I'=>I₂, 'X'=>X, 'Y'=>Y, 'Z'=>Z)
    for word in words
        length(word) == length(register) && all(c -> haskey(lookup,c), word) ||
            throw(ArgumentError("Pauli words must match the register and contain I/X/Y/Z"))
        matrix = ones(ComplexF64, 1, 1)
        for c in word
            matrix = kron(lookup[c], matrix)
        end
        push!(matrices, matrix)
    end
    return MixedUnitary(register, matrices, probabilities)
end

"""Depolarizing channel `(1-p)ρ + p*tr(ρ)*I/d`, for one or two qubits."""
function Depolarizing(pos; p::Real)
    register = pos isa Int ? (pos,) : Tuple(pos)
    n = length(register)
    1 <= n <= 2 || throw(ArgumentError("Depolarizing supports one or two qubits"))
    count = 4^n
    p = _noise_probability(p, "p"; upper=count/(count-1))
    words = [join(digits) for digits in Iterators.product(ntuple(_ -> ('I','X','Y','Z'), n)...)]
    probabilities = fill(p/count, count)
    probabilities[1] = max(zero(p), 1-(count-1)*p/count)
    return PauliChannel(register, vec(words), probabilities)
end

"""A mixture of unitary matrices with finite, nonnegative probabilities summing to one."""
function MixedUnitary(pos, unitaries::AbstractVector{<:AbstractMatrix}, probabilities::AbstractVector{<:Real})
    length(unitaries) == length(probabilities) && !isempty(unitaries) || throw(ArgumentError("unitaries and probabilities must match"))
    weights = Float64[_noise_probability(p,"probability") for p in probabilities]
    tolerance = max(_channel_tolerance(eltype(probabilities), nothing), 1e-14)
    isapprox(sum(weights), 1; atol=tolerance, rtol=0) || throw(ArgumentError("probabilities must sum to one"))
    weights ./= sum(weights)
    for u in unitaries
        size(u,1) == size(u,2) && all(isfinite,u) || throw(ArgumentError("unitaries must be finite square matrices"))
        isapprox(u'*u, Matrix{eltype(u)}(I,size(u)...); atol=_channel_tolerance(eltype(u), nothing), rtol=0) ||
            throw(ArgumentError("matrix is not unitary"))
    end
    T = promote_type(map(eltype, unitaries)..., eltype(weights))
    ks = [Matrix{T}(sqrt(p)*u) for (p,u) in zip(weights,unitaries)]
    return QuantumMap(pos isa Int ? (pos,) : Tuple(pos), ks; check_tp=true, atol=max(tolerance, _channel_tolerance(T,nothing)))
end

"""Generalized amplitude damping; `excited_population` is the equilibrium |1⟩ population."""
function GeneralizedAmplitudeDamping(pos::Int; γ::Real, excited_population::Real=0)
    γ = _noise_probability(γ,"γ")
    e = _noise_probability(excited_population,"excited_population")
    γ, e = promote(γ,e)
    return QuantumMap(pos, [sqrt(1-e)*[1 0; 0 sqrt(1-γ)],
        sqrt(1-e)*[0 sqrt(γ); 0 0], sqrt(e)*[sqrt(1-γ) 0; 0 1],
        sqrt(e)*[0 0; sqrt(γ) 0]]; check_tp=true)
end

"""With probability `p`, replace a qubit by `|state⟩`; otherwise leave it unchanged."""
function ResetChannel(pos::Int; state::Integer=0, p::Real=1)
    state in (0,1) || throw(ArgumentError("reset state must be 0 or 1"))
    p = _noise_probability(p,"p")
    a = zeros(typeof(p),2,2); b = copy(a)
    a[state+1,1] = sqrt(p); b[state+1,2] = sqrt(p)
    return QuantumMap(pos, [sqrt(1-p)*Matrix{typeof(p)}(I,2,2), a,b]; check_tp=true)
end

"""
    ThermalRelaxation(pos; T1, T2, duration, excited_population=0)

Relax population with T1 and coherence with T2, using a common time unit.
Positive infinite lifetimes are supported; require T2 ≤ 2T1 and finite duration ≥ 0.
"""
function ThermalRelaxation(pos::Int; T1::Real, T2::Real, duration::Real, excited_population::Real=0)
    T1 > 0 && T2 > 0 && T2/2 <= T1 || throw(ArgumentError("require positive T1/T2 and T2 ≤ 2T1"))
    isfinite(duration) && duration >= 0 || throw(ArgumentError("duration must be finite and nonnegative"))
    e = _noise_probability(excited_population,"excited_population")
    T1,T2,duration,e = promote(float(T1),float(T2),float(duration),e)
    γ = -expm1(-duration/T1)
    inverse_phi = max(zero(float(T2)), inv(T2)-inv(T1)/2)
    phase = PhaseDamping(pos; γ=-expm1(-2duration*inverse_phi))
    amplitude = GeneralizedAmplitudeDamping(pos; γ=γ, excited_population=e)
    return QuantumMap(pos, [b*a for a in kraus_matrices(amplitude) for b in kraus_matrices(phase)]; check_tp=true)
end
