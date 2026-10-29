# Noise simulation

MOSSQuantum provides physical Kraus channels, explicit noise insertion, classical
readout errors, exact density-matrix evolution, and independent CPU pure-state
trajectories. The core has no additional runtime dependencies. Quantum chemistry
remains a separate planned companion package.

## Channels and physical conventions

| Constructor | Meaning |
| --- | --- |
| `AmplitudeDamping(q; γ)` | Decay from 1 to 0 with probability γ |
| `PhaseDamping(q; γ)` | Multiply off-diagonal entries by `sqrt(1-γ)` |
| `BitFlip`, `PhaseFlip`, `BitPhaseFlip` | Apply X, Z, or Y with probability `p` |
| `PauliChannel(qs, words, probabilities)` | A probability distribution over Pauli words |
| `Depolarizing(qs; p)` | `(1-p)ρ + p*tr(ρ)*I/d`, for one or two qubits |
| `GeneralizedAmplitudeDamping(q; γ, excited_population=0)` | Bidirectional energy exchange, with an explicit equilibrium population of state 1 |
| `ThermalRelaxation(q; T1, T2, duration, excited_population=0)` | Population relaxation with T1 and coherence relaxation with T2 |
| `ResetChannel(q; state=0, p=1)` | Replace the qubit by the selected basis state with probability p |
| `MixedUnitary(qs, matrices, probabilities)` | A mixture of unitary errors; a single unitary represents coherent error |
| `QuantumMap(qs, matrices; check_tp=true, atol=nothing)` | Custom physical Kraus channel |

Noise constructors validate their parameters. Ordinary probabilities lie in
[0,1]; Pauli and mixed-unitary probabilities must sum to one. Depolarizing `p`
is an affine mixing parameter, **not** the probability of a nonidentity Pauli.
Its valid range is `[0, d²/(d²-1)]`, where `d=2^length(qs)`. In particular, `p=1`
is fully depolarizing, and the historical single-qubit range `[0,4/3]` remains
valid. For one qubit X, Y and Z each have probability `p/4`.

The first character in a Pauli word acts on the first supplied position, the
least significant local matrix bit. For example, `"XZ"` on `(3,1)` applies X to
qubit 3 and Z to qubit 1. This also specifies explicitly correlated errors.

Thermal lifetimes use a common time unit with `duration`. Lifetimes must be
positive, `T2 ≤ 2T1`, and duration must be finite and nonnegative. Positive
infinite lifetimes are allowed. The channel satisfies

```text
population_1(t) = equilibrium + (population_1(0) - equilibrium) * exp(-t/T1)
coherence_01(t) = coherence_01(0) * exp(-t/T2)
```

General `QuantumMap` construction defaults to `check_tp=false` to preserve
non-trace-preserving CP maps used by low-level deterministic applications.
Physical noise constructors, noise models and stochastic channel execution
require trace preservation. `is_tp(channel; atol=...)` is also available.
Kraus construction establishes complete positivity; completeness establishes
trace preservation. These checks do not certify that an arbitrary supplied
initial density matrix is positive semidefinite.

Constructors copy Kraus inputs. `kraus_matrices` and `ordered_supermat` expose
borrowed **read-only** matrices. To update a channel, construct a new
`QuantumMap`; execution rejects stale or malformed Kraus/supermatrix pairs.
Configuration and circuit inputs must not be mutated concurrently with execution.

CPU channel execution currently supports one or two local qubits, including
nonadjacent and unsorted positions, in larger registers. Constructor acceptance
of a larger custom map does not imply backend execution support.

## Configuring a noisy circuit

```julia
using MOSSQuantum, Random

circuit = QCircuit([HGate(1), CNOTGate(1,2), Delay(1; duration=20.0)])
model = NoiseModel(
    rules=[
        NoiseRule(HGate, g -> Depolarizing(only(positions(g)); p=0.01)),
        NoiseRule(CNOTGate, g -> Depolarizing(positions(g); p=0.03)),
        NoiseRule(Delay, g -> ThermalRelaxation(g.position;
            T1=1000.0, T2=1500.0, duration=g.duration)),
    ],
    readout=[ReadoutError(1; p0_to_1=0.02, p1_to_0=0.05)],
)
program = with_noise(circuit, model)
exact_state = simulate(program, StateVector(2)).state
result = execute(program, StateVector(2); shots=1000, rng=Xoshiro(42))
@assert sum(values(result.counts)) == 1000
```

`NoiseRule(matcher, factory; when=:after, qubits=nothing)` matches an instruction
type or a predicate. `qubits` optionally matches the exact ordered register.
The factory receives an independent instruction copy and returns a `QuantumMap`
or an iterable of maps; a fixed map is also accepted instead of a factory.

Rules execute in registration order, before or after each original leaf
instruction, including leaves inside nested circuits. Generated noise is not
matched again. `preparation` maps run before the circuit; `terminal` maps run
after it. A rule may target a spectator qubit, provided that qubit is within the
input register. Noise generation is completed and checked before sampling.

`with_noise` snapshots and expands the circuit into a `NoisyCircuit`. Inspect
`.circuit` to review the quantum instructions and `.readout` for classical
errors. Applying `with_noise` again, or supplying another `noise_model` when
executing a `NoisyCircuit`, raises an error. Deliberately extracting `.circuit`
removes this metadata and guard.

Alternatively pass `noise_model=model` directly to `execute`, `simulate`, or
circuit-level `estimate`. Expansion happens once per call. `Delay` is an ideal
CPU no-op without a matching noise rule. No scheduler infers idle durations
from circuit position, gate depth, or missing gates.

## Exact evolution and trajectories

```julia
using MOSSQuantum, Random

circuit = QCircuit([HGate(1), CNOTGate(1,2), AmplitudeDamping(1; γ=0.2)])
initial = StateVector(2)
exact = simulate(circuit, initial; method=DensityMatrixEvolution())
trajectory = simulate(circuit, initial; method=KrausTrajectory(), rng=Xoshiro(5))
@assert exact.state isa DensityMatrix
@assert trajectory.state isa StateVector
@assert norm(trajectory.state) ≈ 1

samples = execute(circuit, initial; shots=2000, method=KrausTrajectory(),
                  parallel=true, rng=Xoshiro(6))
energy = estimate(QubitsTerm(1=>Z) + QubitsTerm(2=>Z), circuit, initial;
                  shots=2000, method=KrausTrajectory(), rng=Xoshiro(7))
@assert energy.shots == 2000
```

`DensityMatrixEvolution()` preserves default execution: channels sum all Kraus
branches and promote pure states only when needed. Without intermediate
measurements the evolved state is reused for terminal shots.

`KrausTrajectory()` requires CPU `StateVector` or `BatchStateVector` input and
unitary circuit gates. Each channel draws branch k with probability
`norm(K[k]*ψ)^2` and renormalizes its state. Mixtures of unitary errors are
recognized and sampled directly. Every shot executes its own noise trajectory
and intermediate measurements. A single final trajectory is not reused as
multiple independent noisy shots. Mixed-state inputs and unsupported backends
raise `UnsupportedOperation`; there is no implicit decomposition or CPU fallback.

`simulate(...; method=KrausTrajectory())` returns one final pure state and its
measurement records. Its state is not the ensemble density matrix. Trajectory
`simulate` rejects forced `QSelect`; use `execute` to sample actual rejection.
Default density-method `simulate` retains its existing conditional selection
contract. `execute` keeps attempted/accepted shot semantics: failed selection
consumes a shot and contributes no terminal sample. `estimate` continues to
reject `QSelect` because accepted and attempted measurement budgets differ.

Batch execution returns one result per member, with the full shots budget per
member. Batch `simulate` retains its batch state and record structure, including
empty and singleton batches. All these entrypoints preserve the initial state.

`parallel=true` is available for trajectory `execute` and circuit `estimate`.
Shot-indexed RNG seeds keep trajectory results reproducible across serial and
threaded execution and changes to `chunk_size`, within the same Julia environment.
Calls advance the caller's RNG; changing method changes the random experiment.
Legacy default execution retains its existing random draw order.

## Classical readout errors

```julia
using MOSSQuantum, Random

error = ReadoutError(1; p0_to_1=0.1, p1_to_0=0.3, scope=:all)
state = StateVector(1)
@assert readout_probabilities(state, error) ≈ [0.9, 0.1]
@assert probabilities(state) == [1.0, 0.0]
draws = sample(state, 100; readout=error, rng=Xoshiro(8))
reported = estimate(QubitsTerm(1=>Z), state; shots=1000,
                    readout=error, rng=Xoshiro(9))

# Deterministically report a flipped bit without changing physical collapse.
flip = ReadoutError(1; p0_to_1=1, p1_to_0=1, scope=:measurement)
r = execute(QCircuit([XGate(1), QMeasure(1; auto_reset=false)]), state;
            shots=1, readout=flip)
record = only(only(r.measurements))
@assert record.outcome == 1 && record.reported_outcome == 0
```

`ReadoutError(qubits, matrix; scope=:terminal)` uses rows for true local outcomes
and columns for reported outcomes: `matrix[true+1, reported+1]`. Rows must sum to
one. The first supplied qubit is the least significant bit. Explicit one- and
two-qubit terminal confusion matrices are supported. Requesting only part of a
correlated block samples/marginalizes the full block before returning the requested
qubits. Disjoint errors may be combined; overlapping errors in the same scope
are rejected instead of being silently ordered.

Scopes are `:terminal`, `:measurement`, and `:all`. Intermediate readout errors
currently require single-qubit blocks, matching `QMeasure`. A record's `outcome`
and `probability` retain the physical measurement meaning; `reported_outcome`
adds the instrument result. Existing four-argument record construction defaults
the reported value to the physical one. `QSelect` acceptance still uses the
physical result. Ideal automatic reset is unchanged; a flipped report does not
introduce feedback-reset noise. For noisy feedback reset, use a named
`QMeasure(...; auto_reset=false)` followed by `Conditional(key, XGate(...))`;
see the [classical control guide](classical-control-and-gradients.md).

`readout_probabilities` explicitly includes classical error; `probabilities`
continues to describe the quantum state. State-level `sample`, `counts`, and
`estimate` accept `readout`; state batch samples retain their three-dimensional
shape. `simulate` has no terminal sample, so only intermediate reported outcomes
are reflected in its records.

For `estimate`, measurement basis rotations are ideal in this version: the model
is expanded on the supplied preparation circuit, then basis rotations and
classical readout are applied. Terminal quantum errors in a model precede those
rotations. Standard errors describe sampling fluctuations of the noisy reported
observable, including within-group covariance; they do not include systematic
noise bias or implement error mitigation. Noise parameters and stochastic
execution have no AD contract. Existing deterministic fixed-noise gradients
remain supported.

## Memory and performance

Use `execute(...; result=:counts, chunk_size=256)` to return a `CountsResult`
without retaining per-shot samples or intermediate records. Its integer
`accepted` counts successful attempts; `shots` counts attempts. The default
`:full` returns the existing `ShotResult`, with an acceptance mask and records
for every attempt. Histogram storage can still grow to the number of distinct
outcomes; it is not constant in the number of measured qubits.

Trajectory execution reuses state, candidate and probability workspaces within
serial chunks or worker tasks. New noisy estimator paths accumulate group
statistics from counts. Exact evolution uses O(4^n) state storage, whereas each
trajectory worker uses O(2^n) state storage; more shots trade runtime for sampling
accuracy. Trajectories are not necessarily faster on small registers.

Run `julia --project=. benchmark/noise_execution.jl /tmp/noise.toml` for warmed
CPU time, cumulative allocations, retained result size and process peak RSS.
The report records Julia/CPU/thread metadata and source hashes. Cumulative
allocations and retained result size are not peak memory. Process RSS includes
compilation. Compare accuracy as well as time when choosing an execution method.

Measured results and their scope are recorded in the
[CPU noise performance report](performance/noise-2026-10-28/README.md).

GPU noise remains a separate companion milestone requiring hardware validation.
Continuous-time Lindblad solvers, non-Markovian noise, leakage/multilevel states,
trainable noise parameters and readout-error mitigation remain outside this
gate-level milestone. Explicit finite-shot gradients are now provided by the
[sampled gradient interfaces](classical-control-and-gradients.md).

## Acceptance record

On Julia 1.13.1 with four Julia threads and one BLAS thread, standard
`Pkg.test(; test_args=["--load-orders"])` passed 9,409 assertions across 107
reported testsets, including 419 new noise checks and the optional integration
loading checks. The four independent backend/gate/differentiation fixtures
separately passed 830 assertions. All three Julia examples above executed.
Tests cover analytic channel behavior, physical invariants, readout orientation,
correlated marginals, post-selection, independent trajectories, empirical
estimator variance, low precision, empty batches, RNG reproducibility and
explicit backend rejection. Existing fixed-noise gradients remain covered.
Julia 1.10 and remote CI were not run for this milestone. Performance measurements
are CPU-only and are recorded separately from numerical acceptance.
