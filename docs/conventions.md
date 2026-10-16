# MOSS numerical and API conventions

These conventions describe the existing dense simulator so users and extension authors can reason about states, circuits, and gradients. Known inconsistencies are called out explicitly and remain separate from the source reorganization.

## Qubit and basis ordering

Qubit positions start at `1`. Qubit `1` is the least significant bit. For binary values `b[q]`, the computational basis amplitude is stored at Julia index

```text
1 + sum(b[q] * 2^(q - 1) for q in 1:n)
```

For example, `onehot_encoding([1, 0])` has its nonzero amplitude at index `2`, while `onehot_encoding([0, 1])` uses index `3`. In the conventional ket label `|b_n … b_1⟩`, qubit `1` appears on the right.

The first position in `positions(g)` corresponds to the least significant local matrix bit. `ordered_positions(g)` sorts positions; `ordered_mat(g)` performs the corresponding basis permutation. External matrices using a different bit convention must be converted before constructing a gate.

`storage(::StateVector)` is a length `2^n` vector. `storage(::DensityMatrix)` is a `2^n × 2^n` matrix backed by column-major vector storage. `storage(::BatchStateVector)` is a `2^n × batch_size` matrix with one state per column. These are current dense storage layouts, not a requirement for a future MPS or stabilizer representation.

## Circuit order

`push!(circuit, operation)` appends an operation. Execution visits circuit elements from first to last, recursively executing nested circuits. Appending circuit `b` to `a` executes the original elements of `a` before those of `b`.

Circuit multiplication follows operator composition: `a * b` constructs a circuit that executes `b` and then `a`. A circuit adjoint reverses the operation order and adjoints each element; it is meaningful only when those elements support adjoints.

## Active parameters

Parameterized gate constructors default to inactive parameters unless their `isparas` flags are set. Built-in variational circuit builders activate their trainable gate parameters.

- `parameters(g)` returns all stored gate parameters, including inactive values.
- `active_parameters(g)` selects the active values in gate-local order.
- `nparameters(g)` counts active parameters.
- Circuit parameter access traverses elements in execution order and concatenates the corresponding values. `parameters(circuit)` includes inactive values; `active_parameters(circuit)` does not.
- `reset_parameters!(circuit, values)` consumes exactly `nparameters(circuit)` values and updates active parameters in that same traversal order.

At gate level, `activate_parameter!(g, j)` selects the gate's parameter index `j`. At circuit level, `activate_parameter!(circuit, j)` activates all parameters of circuit element `j`; it does not select the circuit's flattened parameter index. The analogous deactivation methods have the same distinction.

Current parameter storage can be shared when the same gate is reused or a circuit is shallow-copied. There is no public shared-parameter identity and accumulation protocol yet. For independent parameter binding, construct independent gates or use `deepcopy` as appropriate until the planned binding API is available.

## Mutation and returned objects

Always retain the state returned by gate or circuit execution:

```julia
state = apply!(circuit, state)
```

`apply!` can replace a real state with a complex state when a gate requires complex storage. Applying a channel to a `StateVector` returns a `DensityMatrix`. Consequently the returned object can differ from the supplied object in both identity and type.

`circuit * state` copies the input state before applying the circuit and returns the resulting state. It is the convenient existing entrypoint for a differentiable workflow that must reuse its initial state.

Measurement and post-selection entrypoints have operation-specific return values. `measure!` mutates the state and returns `(outcome, probability)`. `measure(state, position)` returns `(reduced_state, outcome, probability)` and removes the measured qubit while preserving the relative order of the remaining qubits. `QMeasure` defaults to resetting a retained measured qubit to zero; set `auto_reset=false` to keep the observed basis value.

Circuit execution currently discards measurement and post-selection metadata and returns only the final state. A unified experiment result and RNG interface is planned; code should not assume those interfaces already exist.

## Copying and storage ownership

`storage(state)` exposes mutable backing data. Mutating it changes the state. Constructors accepting arrays may reuse a compatible dense array instead of copying it. Converting to the same element type can also retain backing storage.

Use `copy(state)` when independent numeric storage is required. Current state-to-state constructor behavior differs:

| Expression | Current behavior |
| --- | --- |
| `StateVector(existing_state_vector)` | Reuses the existing vector when its type already matches |
| `DensityMatrix(existing_density_matrix)` | Reuses the existing backing vector when its type already matches |
| `BatchStateVector(existing_batch)` | Copies the matrix |
| `copy(state)` for any of the three dense state types | Copies numeric storage |
| `copy(circuit)` or `QCircuit(existing_circuit)` | Copies the operation container and retains its operation objects |

An independent operation container therefore does not guarantee independent parameter arrays. Ownership rules should be made more uniform in a later behavior change, with explicit migration guidance.

## Physical quantities and known corrections

Pure-state fidelity is currently `abs2(dot(x, y))`, and pure-state–density-matrix fidelity uses `⟨ψ|ρ|ψ⟩`. The density-matrix–density-matrix implementation is inconsistent with these cases. A subsequent correction must choose a single fidelity convention, document it, and verify that converting a pure state to a density matrix preserves the answer. The current mixed-state formula is not a physical convention to reproduce in new code.

The existing `time_evolution(h, t, state)` passes `t` directly as the coefficient of the exponential. For a pure state, a real physical time `τ` and `ℏ = 1` require the coefficient `-im * τ`. The density-matrix overload currently applies only left multiplication and needs correction before use as physical mixed-state evolution. Physical unitary mixed-state evolution must implement `U * ρ * U'` and preserve trace, Hermiticity, and positivity.

Random state constructors and measurement currently use the process default RNG. Tests that need deterministic inputs can construct arrays with an explicit local RNG before wrapping them as states. Explicit RNG plumbing through execution and sampling is tracked in the roadmap.

## Errors and backend limits

The dense CPU gate dispatcher currently supports gates acting on one through five qubits. A channel superoperator acts on doubled density-matrix indices, so the same dispatcher also limits generic channels to at most two physical qubits. These are implementation capabilities, not limits on a future operation representation.

Position validity, dimensions, supported backend operations, and supported differentiation methods should ultimately have distinct checks. Existing APIs use a mixture of assertions and exceptions; the directory move preserves that behavior.
