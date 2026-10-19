# MOSS

MOSS (550W) is a Julia framework for quantum circuit simulation, variational quantum algorithms, and quantum machine learning. It provides a dense CPU simulator, explicit readout and experiment results, and public state/backend interfaces for companion packages. Optional Zygote integration supports analytic gradients for supported deterministic circuit workflows.

MOSS merges the circuit representation of [QuantumCircuits.jl](https://github.com/guochu/QuantumCircuits.jl) and the simulation/differentiation capabilities of [VQC.jl](https://github.com/LeeQY1996/VQC.jl) into a single unified package.

## Features

- **Quantum circuit representation**: Single-qubit, two-qubit, and three-qubit gates, parametric gates, measurements, post-selection, and quantum channels (Kraus operators).
- **State simulation**: Dense state vectors, density matrices, and batch state vectors with serial/threaded gate application.
- **Differentiation**: Replaceable explicit gradient methods and optional Zygote integration, including shared-parameter pure-state batches with unitary circuits, supported expectations, and qubit encoding. Stochastic execution has no AD contract.
- **Hamiltonian tools**: Pauli string operators (`QubitsTerm`, `QubitsOperator`), expectation value computation, Trotterization, and variational ansatz construction.
- **Algorithms**: QFT, Shor's order finding, variational ansatze, ground state solvers, and time evolution.
- **Readout and results**: Probabilities, seeded samples/counts, batch measurement and post-selection, and execution results retaining intermediate records for each sample.
- **Extension interfaces**: Custom instructions, implicit states, selectable backends, capability queries, public parameter reset/copy hooks, and parameter binding with explicit sharing maps.
- **Visualization**: Optional circuit diagrams through Plots.jl and LaTeXStrings.

## Installation

MOSS requires Julia 1.10 or later. Julia 1.13 is the primary development and acceptance version; the minimum-version checks target Julia 1.10.

```julia
using Pkg
# Add this checkout to your active environment.
Pkg.develop(path="/absolute/path/to/MOSS")
```

From this checkout, `julia --project=. -e 'using Pkg; Pkg.instantiate()'` prepares the Julia 1.13 development environment. The checked-in Manifest is generated with Julia 1.13; for Julia 1.10, develop the checkout into a fresh environment so its dependencies resolve for that version, as the minimum-version checks do. Install optional integrations in the environment that will use them:

```julia
using Pkg
Pkg.add("Zygote")
Pkg.add(["Plots", "LaTeXStrings"])
```

## Quick Start

### Bell state

```julia
using MOSS

state = qstate(2)
circuit = QCircuit()
push!(circuit, HGate(1))
push!(circuit, CNOTGate(1, 2))
state = apply!(circuit, state)
println(amplitudes(state))
```

### Readout and recorded execution

```julia
using MOSS, Random

bell = QCircuit([HGate(1), CNOTGate(1, 2)])
result = simulate(bell, StateVector(2); rng=MersenneTwister(42))
probabilities(result.state) # approximately [0.5, 0, 0, 0.5]
sample(MersenneTwister(42), result.state, 100) # 100 × 2, qubits in column order
counts(MersenneTwister(42), result.state, 100)

measured = simulate(QCircuit([bell, QMeasure(1; auto_reset=false)]),
    StateVector(2); rng=MersenneTwister(42))
measured.measurements # outcome and probability, including nested circuits
```

`simulate` copies its input state. A single-state result describes one trajectory; a batch result contains one trajectory and record list per column. Sampling the final state does not rerun intermediate measurements; repeat `simulate` from the initial state for independent trajectories. Count-string characters follow the requested `qubits` order, with qubit 1 first by default. Batch samples have axes `(shots, qubits, batch)`.

### Independent parameter binding

```julia
using MOSS

template = QCircuit([RyGate(1, 0.0; isparas=true)])
bound = bind_parameters(template, [π / 4])
state = bound * StateVector(1)
```

Binding accepts individual instructions as well as circuits. It follows `active_parameters(template)` order, preserves inactive values, and copies every instruction occurrence independently through `copy_instruction`. The source and parameter vector remain independent of the result. Public `reset_parameters!` writers may return replacement instructions, allowing external immutable gates with their own field layout.

### Shared parameter values

Use a separate map to bind several active slots to one independent value:

```julia
using MOSS

template = QCircuit([RyGate(1, 0.0; isparas=true),
                     RzGate(1, 0.0; isparas=true),
                     RyGate(1, 0.0; isparas=true)])
parameter_map = ParameterMap([1, 2, 1])
values = [0.2, -0.4]
bound = bind_parameters(template, values, parameter_map)
active_parameters(bound) # [0.2, -0.4, 0.2]
length(parameter_map)    # 3 active slots
nparameters(parameter_map) # 2 independent values

# Sum a gradient in active-slot order into independent-value order.
accumulate_parameter_gradients(parameter_map, [2.0, 3.0, 5.0]) # [7.0, 3.0]
```

The map records positions in `active_parameters` order. It stays separate from the bound circuit, whose three slots retain independent storage. Rebuild or review the map after changing activation, circuit structure, or instruction order; matching slot counts cannot detect a reorder. IDs must use every integer in `1:k`; an empty map has no parameters. See the [parameter conventions](docs/conventions.md#explicit-shared-parameter-maps) for validation and ownership details.

On the existing supported dense CPU circuit gradient path, Zygote sums the contributions of shared slots automatically:

```julia
using Zygote

initial = StateVector(1)
observable = QubitsTerm(1 => "Z")
loss(values) = real(expectation(observable,
    bind_parameters(template, values, parameter_map) * initial))
gradient = Zygote.gradient(loss, values)[1] # 2 entries
```

### Execution and selectable differentiation

```julia
template = QCircuit([RyGate(1, 0.0; isparas=true), RyGate(1, 0.0; isparas=true)])
objective = ExpectationObjective(template, QubitsTerm(1 => "Z"), StateVector(1);
    parameter_map=ParameterMap([1, 1]))
values = [0.2]
value = evaluate(objective, values) # forward execution only
method = AdjointGradient()
value, gradient = value_and_gradient(method, objective, values) # no AD package needed
```

Pass a `parameter_map` keyword when creating the objective to use shared values. Its constructor snapshots the template, observable, and initial state while retaining the selected execution backend. Forward execution carries no gradient method. Query `supports_gradient(method, objective)` before requesting derivatives; the current CPU method supports deterministic unitary circuits and fixed channels with supported Hermitian observables.

An optional ChainRulesCore extension connects an explicitly chosen method to AD:

```julia
using Zygote
loss(values) = differentiable_value(method, objective, values)
gradient = Zygote.gradient(loss, values)[1]
```

External methods specialize public `value_and_gradient`/`value_and_pullback` hooks, and external objectives implement `evaluate` without requiring a quantum state or simulator inheritance. The [independent differentiation fixture](test/fixtures/MOSSDemoDifferentiation) demonstrates replacing both. Existing Zygote circuit interfaces remain available. Additional numerical gradient algorithms are separate future work; the [extension guide](docs/extending.md#execution-and-replaceable-differentiation) defines the current contracts.

### Pure-state batches

`StateVector` represents one pure state. The existing `BatchStateVector` represents
independent pure states in a `(2^n, B)` matrix, one sample per column. Both use
`apply!`, circuit multiplication, `expectation`, readout, and `simulate`; a batch
of size one retains its batch shape and result type.

```julia
using MOSS, Random

batch = BatchStateVector(2, 4)
batch_template = QCircuit([RyGate(1, 0.0; isparas=true), CNOTGate(1, 2)])
batch_objective = BatchExpectationObjective(batch_template, QubitsTerm(2 => "Z"), batch;
    reduction=:mean)
sample_values = evaluate_batch(batch_objective, [0.2]) # 4 real expectations
value, gradient = value_and_gradient(AdjointGradient(), batch_objective, [0.2])

batch_result = simulate(QCircuit([HGate(1), QMeasure(1; auto_reset=false)]), batch;
    rng=MersenneTwister(42))
batch_result.measurements[1] # records for the first sample
```

All samples share the circuit, parameter vector, and observable. Scalar batch
objectives support `:mean`, `:sum`, and `:weighted_sum`; weights are explicit and
are not normalized. Forward execution stays independent of the gradient method,
and the optional `differentiable_value` adapter works with the selected method.
CPU batch gradients currently cover deterministic unitary circuits with supported
Hermitian observables. Measurement and post-selection are forward capabilities;
batch noise and batch density matrices are not implemented. See the
[batch guide](docs/batching.md) for shapes, measurement semantics, supported
encoding derivatives, and gradient boundaries.

### State and circuit ownership

```julia
data = ComplexF64[1, 0]
state = StateVector(data; copy=true) # independent numeric storage
shallow = copy(template)             # new container, shared instructions
independent = copy_instruction(template) # independent mutable instruction data
```

Existing constructor defaults are preserved: compatible array inputs generally permit reuse, `StateVector(state)` and `DensityMatrix(rho)` permit reuse, and `BatchStateVector(batch)` copies. Explicit `copy=true` copies numeric state storage; the same keyword on `QCircuit` copies its container. Type or layout conversion may allocate even with `copy=false`. Immutable instruction copies may remain `===`. See [ownership conventions](docs/conventions.md#copying-and-storage-ownership) for the complete table.

Retain the return value of `reset_parameters!`, activation, and deactivation when working with replacement instructions. Mutating reset keeps its historical alias behavior: a repeated mutable gate ends with the last supplied value. Circuit `activate_parameter!(circuit, j)` still selects instruction `j`. The container methods `push!`, `append!`, and `empty!` return the modified circuit.

### Expectation value

```julia
using MOSS

circuit = QCircuit()
push!(circuit, RxGate(1, π/4))
push!(circuit, CNOTGate(1, 2))

state = qstate(2)
state = apply!(circuit, state)

h = QubitsTerm(1=>"Z", 2=>"Z")
println("⟨ZZ⟩ = ", expectation(h, state))
```

### Variational circuit optimization

```julia
using MOSS, Zygote

circuit = variational_circuit_1d(3, 2)
initial_state = qstate(3)
observable = QubitsTerm(1=>"Z")

# Circuit multiplication preserves the initial state on every evaluation.
loss(c) = real(expectation(observable, c * initial_state))
grad = Zygote.gradient(loss, circuit)[1]
# Entries follow active_parameters(circuit) order.
```

### Hamiltonian simulation

```julia
using MOSS, MOSS.Utilities

# Build Ising Hamiltonian
h = ising_1d(4, J=1.0, hz=0.5)

# Find ground state
E, gs = ground_state(h)
println("Ground state energy: ", E)

# Real-time Trotter evolution for time 0.1 with ℏ = 1
circuit = trotter_propagator(h, -0.1im)
state = apply!(circuit, qstate(4))
```

### Circuit visualization

```julia
using MOSS, Plots, LaTeXStrings

circuit = QCircuit()
push!(circuit, HGate(1))
push!(circuit, CNOTGate(1, 2))
push!(circuit, RxGate(1, π/4))
push!(circuit, QMeasure(2))

plt = MOSS.QuantumCircuits.plot(circuit)
savefig(plt, "circuit.png")
```

## Gate library

| Category | Gates |
|---|---|
| Single-qubit | `XGate`, `YGate`, `ZGate`, `HGate`, `SGate`, `TGate`, `sqrtXGate`, `sqrtYGate` |
| Parametric | `RxGate`, `RyGate`, `RzGate`, `PHASEGate` |
| Two-qubit | `CNOTGate`, `CZGate`, `SWAPGate`, `iSWAPGate`, `CONTROLGate` |
| Controlled parametric | `CRxGate`, `CRyGate`, `CRzGate`, `CPHASEGate`, `FSIMGate` |
| Three-qubit | `TOFFOLIGate`, `FREDKINGate`, `CONTROLCONTROLGate`, `CCPHASEGate` |
| Channels | `AmplitudeDamping`, `PhaseDamping`, `Depolarizing` |
| Operations | `QMeasure`, `QSelect` |

`MOSS.QuantumCircuits.Gates` supplies elementary matrices such as `H`, `X`, `Y`, `Z`, `CNOT`, `CZ`, and `SWAP`, and matrix functions `Rx`, `Ry`, and `Rz`. Use the corresponding `...Gate` types to place operations in a circuit.

## Utilities module

`MOSS.Utilities` provides pre-built algorithms and Hamiltonians:

- **Spin Hamiltonians**: `heisenberg_1d`, `heisenberg_2d`, `ising_1d`, `ising_2d`
- **Ground state & evolution**: `ground_state`, `time_evolution`
- **Trotterization**: `trotter_propagator`, `fuse_gates`
- **Quantum algorithms**: `QFT`, `order_finding`
- **Variational circuits**: `variational_circuit_1d`, `real_variational_circuit_1d`

## Dependencies

- [StaticArrays](https://github.com/JuliaArrays/StaticArrays.jl) — efficient small arrays
- [KrylovKit](https://github.com/Jutho/KrylovKit.jl) — Krylov subspace methods
- [TensorOperations](https://github.com/Jutho/TensorOperations.jl) — tensor contractions

ChainRulesCore is an optional rule dependency for the explicit-method scalar interface; Zygote is an optional AD consumer and also supports the legacy circuit/state interfaces. Neither is required for forward execution or explicit numerical `value_and_gradient` calls. Plots and LaTeXStrings are optional plotting dependencies and must both be loaded to enable circuit diagrams. All supported Julia versions use native package extensions; the Requires bridge has been removed. FiniteDifferences is a test dependency. See the [verification record](docs/roadmap.md#verification-record) for measured Julia-version coverage.

## Development

- [Architecture and package boundaries](docs/architecture.md)
- [Numerical and API conventions](docs/conventions.md), including squared Uhlmann fidelity, two-sided density evolution, qubit order, RNGs, and ownership
- [Pure-state batches and gradient boundaries](docs/batching.md)
- [Extension guide](docs/extending.md)
- [Core foundation roadmap](docs/roadmap.md)
- [Benchmark setup and workloads](benchmark/README.md)
- [Repeated-evaluation measurements and allocation optimization](docs/performance/repeated-evaluation-2026-10-19.md)

Run the test suite through the package entrypoint:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Backend extensions use `AbstractInstruction`, `AbstractQuantumState`, `backend`, `supports`, `apply!(backend, ...)`, and `expectation(backend, ...)`; the [independent demo package](test/fixtures/MOSSDemoBackend) exercises these public contracts without dense storage.

The [independent trainable-gate package](test/fixtures/MOSSDemoGates) demonstrates an immutable custom gate using public parameter methods and the existing CPU gradient path. Its `differentiate` method returns gates storing `(∂U/∂θ)' * U` in active-parameter order. This path covers supported deterministic single-state circuits and unitary pure-state batches. Arbitrary instructions, custom backends, stochastic execution, and trainable noise need their own derivative support.

Retain the return value of `apply!`: execution can promote numeric storage or convert a state vector to a density matrix when applying noise. See the conventions for qubit ordering, parameter activation, and storage ownership.

## License

GNU General Public License v3.0
