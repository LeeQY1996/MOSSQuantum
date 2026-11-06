# Operators and finite-shot measurement

MOSSQuantum provides exact operator evaluation and a separate finite-shot
estimator. These interfaces share the same qubit convention: qubit 1 is the
least significant tensor factor; sample columns and count-string characters
follow the requested `qubits` order.

## Operator algebra

```julia
using MOSSQuantum, LinearAlgebra

x = QubitsTerm(1 => "X")
y = QubitsTerm(1 => "Y")
z = QubitsTerm(1 => "Z")
H = 0.7 + 0.2x - 0.4z + QubitsTerm(1 => "Z", 2 => "Z")

matrix(2, x * y) ≈ im * matrix(2, z)
iszero(x - x)                         # true
matrix(2, QubitsOperator())           # 4×4 sparse zero matrix
matrix(2, QubitsTerm(0.7))            # 0.7 times the 4×4 identity
simplify(x + x)                       # one term with coefficient 2
```

Terms and sums support addition, subtraction, negation, scalar multiplication
and division, operator multiplication and adjoints. Operator multiplication
preserves matrix order at shared positions. Numeric addition means an identity
term. `zero`, `one`, and `iszero` distinguish a zero coefficient from an empty
support: `isempty(QubitsTerm(2))` is true, while `iszero(QubitsTerm(2))` is false.

`nqubits(H)` reports the largest supported position, not a permanently attached
register size. It is zero for scalar and empty operators. Consequently
`matrix(H)` is 1×1 for those operators; use `matrix(n, H)` to choose the physical
register size explicitly. Constants act correctly on all four CPU state
containers, including zero-qubit registers and empty batches. Exact expectations
retain the existing unnormalized-state convention: `cI` gives `c*norm(ψ)^2`
or `c*tr(ρ)`.

`simplify(H; atol=0)` removes identity factors, extracts exact scalar multiples
of I/X/Y/Z, combines identical tensor-product terms, and removes coefficients
whose magnitude is at most `atol`. For sums the cutoff applies after combining
terms. It preserves arbitrary local 2×2 matrices without approximate matching
or full Pauli expansion; algebraically equivalent expressions with different
general-matrix decompositions need not have the same simplified representation.
The Hermitian capability check likewise remains conservative for general
factorizations, such as products of anti-Hermitian local factors.

Term constructors copy positions and local matrices, and reject duplicate or
nonpositive positions and non-2×2 factors. Copies and arithmetic results own
their factor metadata. `positions` and `oplist` still expose mutable metadata;
do not mutate operators concurrently with evaluation. This strengthens the
previous shallow constructor/copy behavior.

Trotter generation retains its internal grouping of one-body terms. Public
`simplify` now combines terms instead of absorbing them into larger supports.
Constant energies are retained as zero-qubit scalar gates, preserving their
global phase on pure states and two-sided action on density matrices. Physical
time still uses the existing exponential-coefficient convention `t=-im*τ`.
Scalar-gate execution is a CPU capability; other backends must opt in explicitly.

## Repeated circuit execution

State-level `sample(state, shots)` and `counts(state, shots)` sample a fixed
final state. Use `execute` to replay intermediate measurements independently:

```julia
using Random

circuit = QCircuit([HGate(1), QMeasure(1; auto_reset=false)])
result = execute(circuit, StateVector(1); shots=1024, rng=MersenneTwister(42))
result.counts                         # accepted terminal outcomes
result.samples                        # accepted shots × requested qubits
result.measurements                   # records for every attempted shot
result.accepted                       # one Boolean per attempted shot
result.shots                          # attempted shots: 1024

counts(circuit, StateVector(1), 1024; rng=MersenneTwister(42))
sample(circuit, StateVector(1), 1024; rng=MersenneTwister(42))
```

`execute` copies the initial state and preserves the register size. Nested
measurements are recorded in execution order. Each instruction's existing
`auto_reset` setting is honored; `QMeasure` continues to default to resetting
the measured qubit. Counts describe terminal readout, while the records retain
the outcomes before reset. This API does not add classical conditional gates.

For gate/Kraus circuits without intermediate measurement, the implementation
evolves once and samples the final distribution. Fixed Kraus noise still uses
the density-matrix implementation; this optimization does not introduce a
random-Kraus trajectory backend.

In `execute`, a `QSelect` is an actual measurement followed by rejection. A
failed selection consumes an attempted shot, retains its record, and stops
that shot. It does not contribute to `samples` or `counts`. Sample row `j`
corresponds to attempted shot `findall(result.accepted)[j]`; the histogram total
is `count(result.accepted)`. Impossible selections yield no accepted samples.
In contrast, existing `simulate` keeps its forced conditional post-selection
semantics. It must not be interpreted as a shot acceptance experiment.

For a batch, circuit execution returns a vector of `ShotResult`s, with the full
budget per member. Circuit-level `sample` returns a vector of matrices because
post-selection can leave different accepted counts. State-level batch sampling
retains its existing `(shots, qubits, batch)` shape. A supplied RNG is consumed
in member order. Empty batches return an empty result vector.

## Finite-shot expectation estimates

```julia
bell = QCircuit([HGate(1), CNOTGate(1, 2)])
initial = StateVector(2)
H = 0.3 + QubitsTerm(1 => "X", 2 => "X") + 0.5QubitsTerm(1 => "Z")

exact = expectation(H, bell * initial)
plan = measurement_plan(H; grouping=:qwc)
estimated = estimate(plan, bell, initial; shots=4096, rng=MersenneTwister(42))
estimated.value
estimated.stderr
estimated.variance                    # estimated variance of the mean
estimated.shots                       # measurements actually consumed
estimated.requested_shots
estimated.groups                      # bases, allocations and group statistics

# Prepared pure states, density matrices and their batches are also accepted.
estimate(H, bell * initial; shots=4096, grouping=:none, rng=MersenneTwister(42))
```

`measurement_plan` expands local 2×2 factors into I/X/Y/Z, combines identical
Pauli words, and checks that the combined observable is Hermitian. Complex
summands are allowed when their sum is Hermitian. Planning and reported
statistics use Float64 coefficients. `atol=0` is exact by default; an explicit
tolerance may remove small coefficients or accept small imaginary roundoff.
Pauli expansion can grow exponentially, so `max_terms=100_000` bounds
intermediate and final expansion counts and raises an error rather than silently
truncating. Plans snapshot the observable; treat their metadata arrays as
read-only.

`:qwc` groups qubit-wise commuting terms with compatible single-qubit bases.
It is a deterministic greedy grouping, not necessarily a minimum grouping and
not a grouping of all globally commuting terms. `:none` measures each
nonconstant word separately. X measurements apply H; Y measurements apply S†
then H; Z measurements need no rotation.

`shots` is the **total budget across groups**, allocated as evenly as possible.
Earlier groups receive the remainder. At least two shots per nonconstant group
are required to report an unbiased sample variance. A constant or zero
observable consumes zero measurements, even when the requested budget is
positive. Physical input states must be normalized, including constant-only
estimates. Batch estimates return one result per member, using the budget per
member.

Each group computes the combined energy for each actual draw. Its
`sample_variance` therefore includes covariance between terms sharing that
draw. Independent group contributions give
`variance = sum(group.sample_variance / group.shots)` and
`stderr = sqrt(variance)`. The standard error describes sampling uncertainty;
it is not a deterministic error bound or a confidence interval. A finite sample
can have zero empirical variance without the true distribution being
deterministic.

Circuit estimates replay intermediate `QMeasure` events for every shot. They
currently reject `QSelect`, so attempted and accepted budgets are never silently
interchanged. Use `execute` to study acceptance, or estimate an explicitly
prepared normalized conditional state. `estimate` has no AD contract;
`expectation` and the existing deterministic gradient interfaces retain their
exact meaning.

## Chemistry boundary

Molecule input, electronic-structure drivers, fermionic mappings, active spaces
and chemistry ansatzes will belong to a separate `MOSSChemistry` package.
This foundation adds no Python or chemistry-engine dependency to the main
package. The chemistry package is a subsequent implementation step, not part of
this change.
