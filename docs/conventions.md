# MOSS numerical and API conventions

These conventions describe the public circuit, execution, readout, and backend interfaces. They also distinguish the current dense representation from requirements on an external simulator.

## Qubit and basis ordering

Qubit positions start at `1`. Qubit `1` is the least significant bit. For binary values `b[q]`, the computational-basis amplitude is stored at Julia index

```text
1 + sum(b[q] * 2^(q - 1) for q in 1:n)
```

`onehot_encoding([1, 0])` therefore uses index `2`, while `onehot_encoding([0, 1])` uses index `3`. In the conventional ket label `|b_n … b_1⟩`, qubit `1` appears on the right.

The first position in `positions(g)` corresponds to the least significant local matrix bit. `ordered_positions(g)` sorts positions; `ordered_mat(g)` permutes the matrix accordingly. Convert external matrices with a different bit convention before constructing a gate.

Dense `storage(::StateVector)` is a length `2^n` vector; `storage(::DensityMatrix)` is a `2^n × 2^n` matrix backed by column-major vector storage. `storage(::BatchStateVector)` is a `2^n × B` matrix with one state per column. `storage(::BatchDensityMatrix)` has axes `(2^n, 2^n, B)`, with one density matrix per final-axis slice. External `AbstractQuantumState` implementations need not expose `storage`.

Single and batch pure/mixed states use separate representations with the
same public operation names. Batch size one does not collapse to a single state:
expectations retain a sample vector, readout retains its batch axis, and recorded
execution returns `BatchSimulationResult`. A batch applies one circuit and one
parameter vector to independent samples. Both batch types support zero-qubit
registers and empty batches. Their shapes remain `(1, B)` and `(1, 1, B)` for
zero qubits, and retain a zero-length final axis for B=0. See the
[pure batch guide](batching.md) and [density batch guide](batch-density-matrices.md).

## Circuit order and admission

`QCircuit` accepts `AbstractInstruction` values, including nested circuits. Gates, channels, measurements, and post-selection are instructions. `QubitsTerm` and `QubitsOperator` remain observables rather than executable circuit elements.

Execution visits elements from first to last and recursively executes nested circuits. Appending circuit `b` to `a` runs the original elements of `a` before those of `b`. Circuit multiplication follows operator composition: `a * b` executes `b` then `a`. A circuit adjoint reverses order and adjoints each element; it is meaningful only when all elements support adjoints.

## Active parameters and independent binding

Parameterized gate constructors default to inactive parameters unless `isparas` is set. Built-in variational builders activate their trainable gate parameters.

- `parameters(g)` returns all stored parameters, including inactive values.
- `active_parameters(g)` selects active values in gate-local order; `nparameters(g)` counts them.
- Circuit parameter access traverses instructions in execution order, recursively through nested circuits.
- `reset_parameters!(instruction, values)` updates active slots and returns the resulting instruction. Mutable implementations update in place; immutable implementations return a replacement. Retain the return value. Circuit traversal retains those replacements and requires exactly `nparameters(circuit)` finite values.
- `bind_parameters(instruction, values)` returns an independent instruction with active slots bound in the same order. It accepts a real abstract vector, checks length and finite values, and preserves inactive values. Circuit binding visits each instruction separately.

At gate level, `activate_parameter!(g, j)` selects parameter index `j`. At circuit level, `activate_parameter!(circuit, j)` activates all parameters of instruction `j`; `j` remains an instruction index. Deactivation follows the same distinction. Activation and deactivation may also return replacement instructions, which circuits and adjoint wrappers retain.

Binding copies every instruction occurrence independently through the public `copy_instruction` hook. If the source contains the same gate object twice, the result has two independent active slots; their supplied values may differ. Nested circuits and adjoint gate wrappers use the same rule, including parameterless instructions. The source and input parameter vector remain independent from the result. Immutable values may compare `===` when their contents are equal; independence concerns mutable storage, rather than distinct object identity. Without a map, binding treats every active slot as an independent input value.

Mutating reset retains its existing shared-object behavior. If a mutable gate occurs twice, `reset_parameters!(circuit, [0.2, 0.3])` visits it twice and both occurrences end with the last supplied value, `0.3`. `copy(circuit)` keeps that sharing. Use `bind_parameters` when the occurrences need independent parameter slots.

### Explicit shared parameter maps

`ParameterMap(indices)` assigns one positive integer ID to every active parameter slot. Slots follow recursive `active_parameters(template)` order. Equal IDs make those slots receive the same independent input value:

```julia
parameter_map = ParameterMap([1, 2, 1])
parameter_indices(parameter_map) # a new Int vector: [1, 2, 1]
length(parameter_map)            # 3 active slots
nparameters(parameter_map)       # 2 independent values

# For a template with three active slots:
bound = bind_parameters(template, [0.2, -0.4], parameter_map)
active_parameters(bound)         # [0.2, -0.4, 0.2]
nparameters(bound)               # still 3 active slots
```

The constructor accepts an integer vector or tuple, snapshots its contents, and rejects Boolean IDs, nonpositive IDs, and gaps in `1:k`. Every ID in that range must be used: `[2, 1, 2]` is valid, while `[1, 3]` and `[2, 2]` are invalid. `ParameterMap(Int[])` has zero slots and zero independent values. `ParameterMap(template)` creates an identity map for the current active slots; `ParameterMap(template, indices)` also checks that the slot count matches the template.

`bind_parameters(template, values, parameter_map)` checks that the map has exactly `nparameters(template)` slots and that `values` contains exactly `nparameters(parameter_map)` finite real values with one-based indexing. It gathers `values[parameter_indices(parameter_map)]`, then uses independent binding. Frozen values are preserved, and every instruction occurrence retains independent mutable storage even when several slots receive equal values. The existing two-argument binding and mutating reset keep their previous behavior.

A map is an immutable value separate from the template and output circuit. Mutating its constructor input or the vector returned by `parameter_indices` cannot change it; `copy(parameter_map)` returns the map itself. The output circuit does not retain a map or shared identity. If activation, nesting, or instruction order changes, rebuild or review the map before reusing it. Validation checks only the number of active slots; a reorder with the same count cannot be detected automatically.

Gradients use the reverse operation: add the contributions of all slots carrying each ID. If `flat_gradient` follows `active_parameters(template)` order, then

```julia
accumulate_parameter_gradients(parameter_map, [2.0, 3.0, 5.0]) # [7.0, 3.0]
```

computes `shared_gradient[j] = sum(flat_gradient[i] for i in eachindex(indices) if indices[i] == j)`. This helper requires one real gradient entry per slot and permits nonfinite gradients to propagate through the sums. For supported deterministic dense CPU circuits, differentiating a loss that calls the three-argument `bind_parameters` with Zygote performs this accumulation automatically. A map represents repeated values; symbolic expressions such as `2θ` or `θ + φ` are outside its contract.

For the existing dense CPU circuit reverse pass, `differentiate(gate)` returns one gate per active parameter, in the same order. Its matrices store `(∂U/∂θ)' * U` for unitary `U`, rather than the raw derivative `∂U/∂θ`. A trainable gate without this method raises an explicit error. These derivatives support documented deterministic single/batch pure and mixed workflows with unitary gates and fixed `QuantumMap` channels. The noisy batch reverse pass retains per-sample checkpoints, so singular fixed maps such as amplitude damping at `γ=1` are allowed. Arbitrary instructions and external backends require their own derivative support; trainable noise and batch stochastic derivatives are not provided.

## Mutation and returned objects

`evaluate(objective, values)` and `differentiable_value(method, objective, values)` have the same ordinary forward meaning; the latter carries the chosen differentiation policy for optional AD adapters. A forward call never requires a gradient capability. `supports_gradient(method, objective)` separately reports support for parameter differentiation, and unknown combinations are unsupported. No fallback algorithm is silently selected.

The explicit-method scalar interface differentiates only `values`. Its method and objective configuration are fixed, including a built-in objective's initial state and observable; use the legacy supported state-gradient APIs when differentiating state inputs. Numerical pullbacks accept a real scalar seed and return a real parameter vector, support repeated calls, and preserve saved state when the caller changes a previously returned gradient. AD-specific zero/thunk and input-domain projection belong to the optional ChainRulesCore adapter.

`ExpectationObjective` snapshots its template, observable, and initial state, retains its backend, and executes on an independent state copy. Its `ParameterMap` continues to define independent input order. The output is the real part of a scalar expectation. This concrete adapter is separate from the public objective protocol, which accepts external objective types without any quantum-state or storage requirement.

`BatchExpectationObjective` likewise snapshots a nonempty initial pure or mixed batch,
circuit, observable, and optional weights, and retains its backend. `evaluate_batch`
returns the real sample expectations in column order. `evaluate` reduces them by
`:mean` (default), `:sum`, or `:weighted_sum`. Weighted sums require one finite real
weight per sample, allow negative weights, and do not normalize the weights.
Weights on other reductions are rejected. The gradient has one entry per
independent circuit parameter, regardless of batch size; the same reduction is
applied to sample contributions. Empty batch containers are supported, but scalar
batch objectives require at least one sample.

### Repeated evaluation and pullback ownership

Each CPU `AdjointGradient` call binds an independent circuit and prepares its own output state, observable snapshot, and any channel checkpoints. Preparing another pullback at a different parameter point does not replace an earlier pullback's saved data. A returned gradient is independent of later pullback calls, and changing the caller's parameter vector or the objective after preparation does not change that prepared pullback.

The objective's fields contain mutable objects even though its outer struct is immutable. Later evaluations inspect the current template, parameter map, observable, and initial state rather than trusting a previous capability query. Parameters can also change a custom gate's matrix or derivative validity; every bound circuit is checked before execution. No persistent matrix, derivative, or capability cache is attached to the objective.

Independent CPU pullbacks may be prepared and called concurrently while their common objective is kept unchanged. Give each task its own parameter inputs. For `BatchExpectationObjective` with a `BatchDensityMatrix` initial state, calls to the same prepared CPU `AdjointGradient` pullback may also run concurrently: its saved observable is private and read-only, and each call owns its observation, cotangent, and reverse buffers. Serialize calls to other prepared pullbacks. Concurrent mutation of an objective or its inputs during preparation is outside this contract. These CPU guarantees do not impose storage, compilation, or workspace interfaces on external backends or gradient methods.

Always retain the returned state:

```julia
state = apply!(circuit, state)
state = apply!(backend(state), instruction, state)
```

A gate can promote real storage to complex storage. A channel applied to a `StateVector` returns a `DensityMatrix`; a channel applied to `BatchStateVector` returns `BatchDensityMatrix`. The returned state can therefore differ in identity and type. `circuit * state` copies the initial state before execution and is useful when evaluating a deterministic loss repeatedly.

Density-batch gate and channel execution preserves an existing floating component
type, even when operation coefficients use wider precision. Complex operations
on real floating storage return `Complex{T}` with the same component type `T`;
nonfloating storage uses numeric promotion. Execution does not silently normalize
states when changing representation or numeric domain.

Legacy measurement and post-selection have specific return conventions. `measure!` returns `(outcome, probability)` and mutates the state. `measure(state, position)` returns `(reduced_state, outcome, probability)` and removes that qubit, preserving the relative order of the others. Retained measurements default to resetting the measured qubit to zero; `auto_reset=false` retains the observed basis value. In-place post-selection returns its probability. These metadata returns are also retained by CPU backend adapters for `QMeasure` and `QSelect`.

For either batch type, outcomes and probabilities are vectors in sample order.
`measure!` and `post_select!` retain the register size; nonmutating `measure` and
`post_select(...; keep=false)` remove the selected qubit from every sample.
Batch post-selection requires positive finite selected probability in every
sample and checks the entire batch before mutation. For density batches, the
reported post-selection weight is the raw selected-block trace, and inputs need
not have unit trace. `partial_tr(batch, sites)` on a pure batch preserves its
existing return contract: individual `DensityMatrix` values for partial reductions,
or sample norms squared when tracing every site of a nonzero register. On a density
batch, partial reductions return an independent `BatchDensityMatrix`; tracing every
site of a nonzero register returns the vector of sample traces. Empty `sites`
copies the density batch, including for a zero-qubit register.

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

## Recorded execution and RNG

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

For `BatchStateVector` or `BatchDensityMatrix`, `simulate` returns
`BatchSimulationResult`. Its state retains the batch and can change from pure to
mixed after noise; `measurements[column]` contains that sample's records in
instruction order, including nested circuits. Random draws follow instruction
order and then column order. Recorded `QMeasure` keeps the register size;
qubit-removing measurements must use `measure` separately. Batch size one retains
the nested record structure, and an empty batch has no sample record lists.

Explicit RNGs are accepted by `simulate`, `sample`, `counts`, `measure`, and `measure!`; readout also offers keyword forms such as `sample(state, shots; rng=rng)`. Random initialization accepts `rand_state(rng, n)`, `rand_densitymatrix(rng, n)`, `rand_batch(rng, n, batch_size)`, and `rand_batch_densitymatrix(rng, n, batch_size)`. Equal seeds reproduce results within the same Julia environment.

`simulate`, `sample`, and `counts` have no automatic differentiation contract. Use supported deterministic circuit application and expectation APIs for analytic gradients.

## Copying and storage ownership

`storage(state)` exposes mutable backing data. Dense constructors taking arrays or existing states, and circuit constructors, accept an explicit `copy` keyword while preserving their existing defaults. For dense states, `copy=true` guarantees independent numeric storage. `copy=false` permits reuse, but element-type or layout conversion may still allocate. Same-element-type `convert` can retain backing storage.

| Expression | Ownership |
| --- | --- |
| `StateVector(data_or_state; copy=false)` | Reuses compatible storage by default; `copy=true` copies it |
| `DensityMatrix(data_or_density_matrix; copy=false)` | Reuses compatible storage by default; `copy=true` copies it |
| `DensityMatrix(pure_state; copy=...)` | Always creates independent density-matrix storage |
| `BatchStateVector(data_or_single_state; copy=false)` | Reuses compatible storage by default; `copy=true` copies it |
| `BatchStateVector(existing_batch; copy=true)` | Copies by default; `copy=false` permits reuse |
| `StateVector(batch, i; copy=true)` | Copies the column; the current representation also materializes it with `copy=false` |
| `BatchDensityMatrix(data_or_single_density; copy=false)` | Reuses compatible storage by default; `copy=true` copies it |
| `BatchDensityMatrix(existing_batch; copy=true)` | Copies by default; `copy=false` permits reuse |
| `BatchDensityMatrix(pure_state_or_pure_batch; copy=...)` | Always allocates independent per-sample outer products |
| `BatchDensityMatrix(density_list; copy=...)` | Always allocates independent sample storage |
| `DensityMatrix(density_batch, i; copy=true)` | Materializes independent storage even with `copy=false` |
| `copy(state)` for the four dense state types | Copies numeric storage |
| `QCircuit(operations; copy=false)` | Reuses a `Vector{AbstractInstruction}`; converting other vector types allocates a container |
| `copy(circuit)` or `QCircuit(existing_circuit; copy=true)` | Copies the container and retains instruction objects; `QCircuit(...; copy=false)` can share the container |
| `copy_instruction(instruction_or_circuit)` | Independently copies mutable instruction data, recursively per occurrence for circuits |
| `bind_parameters(instruction_or_circuit, values)` | Independently copies every occurrence and binds its active parameters |
| `simulate(circuit, state; ...)` | Executes on an independent state copy |

Independent circuit containers alone do not imply independent parameter arrays. `QCircuit(...; copy=true)` is shallow; use `copy_instruction(circuit)` for independent mutable instruction data without changing parameter values. The default hook uses `deepcopy`; extensions managing resources can specialize it while preserving storage independence. Immutable instructions may remain `===` after copying.

`push!`, `append!`, and `empty!` return the modified `QCircuit`, matching their documented container API. Earlier versions returned its internal operation vector; code relying on that return value should now use `circuit.operations` explicitly.

## Physical quantities and migration notes

`normalize!(BatchStateVector)` normalizes each sample by its vector norm.
`normalize!(BatchDensityMatrix)` divides each sample by its finite positive real
trace, validating all traces before mutation. `tr(density_batch)` returns sample
traces, whereas `norm(density_batch)` returns Frobenius norms. Unit-trace mixed
samples generally have norms below one. Constructors check shape rather than
positivity or normalization; density readout validates finite real nonnegative
diagonal probabilities and unit trace, including when requesting a marginal.

Gate execution on a density batch applies `UρᵢU†` independently to each sample.
`QubitsTerm`, `QubitsOperator`, and full-matrix multiplication denote the algebraic
left action `Oρᵢ`; `expectation(O, batch)` returns `tr(Oρᵢ)` per sample. These
operator products need not be physical density matrices.

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

The dense CPU backend supports gates on one through five acted-on qubits and generic Kraus channels on at most two physical qubits for single and batch states. Channels convert pure to mixed states while preserving sample independence. Retained `QMeasure` supports all four dense representations; `QSelect` supports single pure states and both batch types. Batch operators and expectations, measurement, post-selection, and recorded execution are supported. Batch reverse-mode support covers documented deterministic unitary/fixed-channel, observable, encoding, and constructor paths; it does not extend to stochastic execution, trainable noise, or every state operation. Legacy dense entrypoints retain some earlier assertions and error conventions.
