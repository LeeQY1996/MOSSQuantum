# MOSS

MOSS (550W) is a Julia framework for quantum circuit simulation, variational quantum algorithms, and quantum machine learning. It provides a differentiable programming interface for quantum circuits, enabling end-to-end gradient-based optimization with automatic differentiation.

MOSS merges the circuit representation of [QuantumCircuits.jl](https://github.com/guochu/QuantumCircuits.jl) and the simulation/differentiation capabilities of [VQC.jl](https://github.com/LeeQY1996/VQC.jl) into a single unified package.

## Features

- **Quantum circuit representation**: Single-qubit, two-qubit, and three-qubit gates, parametric gates, measurements, post-selection, and quantum channels (Kraus operators).
- **State simulation**: Dense state vectors, density matrices, and batch state vectors with serial/threaded gate application.
- **Differentiable**: Both quantum circuits and quantum states are differentiable via Zygote. Gradients flow through circuit application, expectation values, and post-selection.
- **Hamiltonian tools**: Pauli string operators (`QubitsTerm`, `QubitsOperator`), expectation value computation, Trotterization, and variational ansatz construction.
- **Algorithms**: QFT, Shor's order finding, VQE/QAOA ansatze, ground state solvers, and time evolution.
- **Visualization**: Circuit diagram rendering via Plots.jl (loaded on demand).

## Installation

```julia
using Pkg
Pkg.add("MOSS")
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
using MOSS, Plots

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

- [Zygote](https://github.com/FluxML/Zygote.jl) — automatic differentiation
- [StaticArrays](https://github.com/JuliaArrays/StaticArrays.jl) — efficient small arrays
- [KrylovKit](https://github.com/Jutho/KrylovKit.jl) — Krylov subspace methods
- [TensorOperations](https://github.com/Jutho/TensorOperations.jl) — tensor contractions
- [Plots](https://github.com/JuliaPlots/Plots.jl) — visualization (loaded on demand; currently a declared package dependency)

## Development

- [Architecture and package boundaries](docs/architecture.md)
- [Numerical and API conventions](docs/conventions.md), including current fidelity and mixed-state evolution limitations
- [Extension guide](docs/extending.md)
- [Core foundation roadmap](docs/roadmap.md)
- [Benchmark setup and workloads](benchmark/README.md)

Run the test suite through the package entrypoint:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Retain the return value of `apply!`: execution can promote numeric storage or convert a state vector to a density matrix when applying noise. See the conventions for qubit ordering, parameter activation, and storage ownership.

## License

GNU General Public License v3.0
