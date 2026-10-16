# MOSS numerical and API conventions

These conventions describe the public circuit, execution, readout, and backend interfaces. They also distinguish the current dense representation from requirements on an external simulator.

## Qubit and basis ordering

Qubit positions start at `1`. Qubit `1` is the least significant bit. For binary values `b[q]`, the computational-basis amplitude is stored at Julia index

```text
1 + sum(b[q] * 2^(q - 1) for q in 1:n)
```

`onehot_encoding([1, 0])` therefore uses index `2`, while `onehot_encoding([0, 1])` uses index `3`. In the conventional ket label `|b_n … b_1⟩`, qubit `1` appears on the right.

The first position in `positions(g)` corresponds to the least significant local matrix bit. `ordered_positions(g)` sorts positions; `ordered_mat(g)` permutes the matrix accordingly. Convert external matrices with a different bit convention before constructing a gate.

Dense `storage(::StateVector)` is a length `2^n` vector; `storage(::DensityMatrix)` is a `2^n × 2^n` matrix backed by column-major vector storage. `storage(::BatchStateVector)` is a `2^n × batch_size` matrix with one state per column. External `AbstractQuantumState` implementations need not expose `storage`.

## Circuit order and admission

`QCircuit` accepts `AbstractInstruction` values, including nested circuits. Gates, channels, measurements, and post-selection are instructions. `QubitsTerm` and `QubitsOperator` remain observables rather than executable circuit elements.

Execution visits elements from first to last and recursively executes nested circuits. Appending circuit `b` to `a` runs the original elements of `a` before those of `b`. Circuit multiplication follows operator composition: `a * b` executes `b` then `a`. A circuit adjoint reverses order and adjoints each element; it is meaningful only when all elements support adjoints.

## Active parameters and independent binding

Parameterized gate constructors default to inactive parameters unless `isparas` is set. Built-in variational builders activate their trainable gate parameters.

- `parameters(g)` returns all stored parameters, including inactive values.
- `active_parameters(g)` selects active values in gate-local order; `nparameters(g)` counts them.
- Circuit parameter access traverses instructions in execution order, recursively through nested circuits.
- `reset_parameters!(circuit, values)` mutates active slots in that order and requires exactly `nparameters(circuit)` values.
- `bind_parameters(circuit, values)` returns an independent circuit with active slots bound in the same order. It accepts a real abstract vector, checks length and finite values, and preserves inactive values.

At gate level, `activate_parameter!(g, j)` selects parameter index `j`. At circuit level, `activate_parameter!(circuit, j)` activates all parameters of instruction `j`, rather than the flattened circuit parameter index. Deactivation follows the same distinction.

Binding copies every instruction occurrence independently. If the source contains the same gate object twice, the result has two independent active slots; their supplied values may differ. Nested circuits and adjoint gate wrappers are copied as well. The source and input parameter vector remain independent from the result. This is positional binding; symbolic shared-parameter identity and gradient accumulation across a shared identity are future work. The older mutating reset and shallow-copy behavior remain available.

## Mutation and returned objects

Always retain the returned state:

```julia
state = apply!(circuit, state)
state = apply!(backend(state), instruction, state)
```

A gate can promote real storage to complex storage. A channel applied to a `StateVector` returns a `DensityMatrix`. The returned state can therefore differ in identity and type. `circuit * state` copies the initial state before execution and is useful when evaluating a deterministic loss repeatedly.

Legacy measurement and post-selection have specific return conventions. `measure!` returns `(outcome, probability)` and mutates the state. `measure(state, position)` returns `(reduced_state, outcome, probability)` and removes that qubit, preserving the relative order of the others. Retained measurements default to resetting the measured qubit to zero; `auto_reset=false` retains the observed basis value. In-place post-selection returns its probability. These metadata returns are also retained by CPU backend adapters for `QMeasure` and `QSelect`.

## Probabilities, samples, and counts

`probabilities(state; qubits=1:nqubits(state))` returns a computational-basis distribution without mutation. Qubits must be distinct valid register positions; the input must be normalized. Significant negative probabilities, nonfinite values, and normalization errors are rejected. Small rounding errors are normalized before sampling.

The first requested qubit is the least significant bit of the probability-vector index. Thus a two-qubit state with full probabilities `[0.1, 0.2, 0.3, 0.4]` gives `[0.1, 0.3, 0.2, 0.4]` for `qubits=[2, 1]`. Its qubit-1 marginal is `[0.4, 0.6]`.

| API | Single state | Batch |
| --- | --- | --- |
| `probabilities(state; qubits)` | Vector of length `2^length(qubits)` | Matrix with one distribution per batch column |
| `sample(rng, state, shots; qubits)` | Integer matrix `(shots, length(qubits))` | Integer array `(shots, length(qubits), batch_size)` |
| `counts(rng, state, shots; qubits)` | `Dict{String,Int}` | Vector of histograms, one per batch element |

Sample columns follow the requested qubit order. The leftmost character of a counts key represents the first requested qubit; this is a readout-order string, not the conventional reversed ket label. For `onehot_encoding([1, 0])`, default counts use `"10"`; requesting `[2, 1]` uses `"01"`.

Zero shots produce empty samples and histograms; negative shots are invalid. An empty qubit selection has distribution `[1]`, sample shape `(shots, 0)`, and the empty-string counts key when shots are positive. Sampling and counts preserve the input state.

## Single-trajectory results and RNG

`simulate(circuit, initial_state; backend=backend(initial_state), rng=...)` executes on a copy and returns a `SimulationResult`:

- `state` is the final state, including any representation or precision promotion.
- `measurements` holds `MeasurementRecord` values in execution order, including nested circuits.
- Each record contains `position`, `outcome`, `probability`, and `kind` (`:measurement` or `:postselection`). The outcome is recorded before automatic reset.

A result describes one circuit trajectory. `sample(rng, result.state, shots)` repeatedly samples its final state. It does not rerun intermediate measurements. To obtain independent intermediate-measurement trajectories, call `simulate` repeatedly from the original initial state while advancing an RNG:

```julia
using MOSS, Random

rng = MersenneTwister(42)
results = [simulate(circuit, initial_state; rng=rng) for _ in 1:100]
```

Explicit RNGs are accepted by `simulate`, `sample`, `counts`, `measure`, and `measure!`; readout also offers keyword forms such as `sample(state, shots; rng=rng)`. Equal seeds reproduce results within the same Julia environment. Random state constructors still use the default RNG; construct input arrays with a local RNG when deterministic initialization is required.

`simulate`, `sample`, and `counts` have no automatic differentiation contract. Use supported deterministic circuit application and expectation APIs for analytic gradients.

## Copying and storage ownership

`storage(state)` exposes mutable backing data. Dense constructors may reuse compatible input arrays, and same-element-type conversions can retain backing storage.

| Expression | Ownership |
| --- | --- |
| `StateVector(existing_state_vector)` | Can reuse its vector |
| `DensityMatrix(existing_density_matrix)` | Can reuse its backing vector |
| `BatchStateVector(existing_batch)` | Copies its matrix |
| `copy(state)` for the three dense state types | Copies numeric storage |
| `copy(circuit)` or `QCircuit(existing_circuit)` | Copies the container and retains instruction objects |
| `bind_parameters(circuit, values)` | Independently copies every instruction occurrence and parameter storage |
| `simulate(circuit, state; ...)` | Executes on an independent state copy |

Independent containers alone do not imply independent parameter arrays. A future uniform constructor-ownership policy would require its own migration guidance.

## Physical quantities and migration notes

`fidelity` uses squared Uhlmann fidelity for normalized states:

```text
F(ρ, σ) = (tr(sqrt(sqrt(ρ) * σ * sqrt(ρ))))²
F(ψ, φ) = |⟨ψ|φ⟩|²
F(ψ, ρ) = ⟨ψ|ρ|ψ⟩
```

Converting pure states to density matrices preserves the answer, including rank-deficient states. The mixed-state implementation handles noncommuting states and truncates eigenvalues at numerical roundoff when constructing positive-semidefinite square roots. This replaces the former `tr(sqrt(ρ) * sqrt(σ))` expression. Results depending on that expression must be updated; for example, a pure state against the maximally mixed qubit now has fidelity `0.5` in either representation.

`MOSS.Utilities.time_evolution(h, t, state)` keeps its exponential-coefficient convention: pure states evolve as `exp(t * h) * ψ`; density matrices evolve as `exp(t * h) * ρ * exp(conj(t) * h)`, for Hermitian `h`. For physical time `τ` and `ℏ = 1`, pass `t = -im * τ`. This preserves trace, Hermiticity, and positivity within numerical tolerance. A real coefficient gives an imaginary-time map whose trace generally changes; normalization is explicit, for example `normalize(time_evolution(h, -0.1, rho))`.

The density overload previously performed only left multiplication. Code requiring the algebraic product `h * rho` can continue to use operator multiplication, which still denotes left multiplication. Evolution now performs two matrix-free Krylov actions and does not construct a dense propagator.

## Capabilities and errors

`supports(b, operation, state; action=:apply)` checks execution support. `action=:expectation` checks observation support. Unknown actions or unsupported combinations return `false`. Unsupported public backend execution or observation raises `UnsupportedOperation`; `validate_positions(operation, nqubits(state))` checks register bounds independently of backend arity or representation support.

The dense CPU backend supports gates on one through five acted-on qubits and generic Kraus channels on at most two physical qubits. Channels convert pure to mixed states and are not implemented for batches. Retained `QMeasure` supports pure and mixed states; `QSelect` currently supports pure states. Batch gate and expectation support does not imply batch noise, measurement, or reverse-mode support. Legacy dense entrypoints retain some earlier assertions and error conventions.
