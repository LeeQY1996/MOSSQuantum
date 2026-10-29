# Sample-based quantum diagonalization (SQD)

This example prepares a parameterized 12-qubit state with MOSSQuantum, optimizes its
energy, and samples it to select a computational-basis subspace for classical
diagonalization. The model is an excitation-conserving spin system; this is a
simulator example, not a quantum-chemistry or hardware calculation.

From the repository root, after installing the dependencies of the root MOSSQuantum
project, run:

```sh
julia --project=. algorithm_zoo/sqd/run.jl
# Optional arguments: shots and optimization steps, respectively
julia --project=. algorithm_zoo/sqd/run.jl 32768 350
```

For an interactive, step-by-step walkthrough with plots, install Jupyter and
the Julia package IJulia in your preferred environment. Install the zoo's
plotting dependencies separately from the repository root:

```sh
julia --project=algorithm_zoo -e 'using Pkg; Pkg.instantiate()'
```

Then launch `jupyter lab` from the repository root (or from `algorithm_zoo/sqd`). Open
[sqd.ipynb](sqd.ipynb) and select a Julia kernel provided by IJulia. Run the
cells in order; the notebook activates the root MOSSQuantum project and loads Plots
from the separate zoo environment. This does not add a plotting dependency to
MOSSQuantum itself. Both entrypoints use the same `sqd.jl` implementation.

The figures show ideal-state variational energy and sampled SQD energy at
optimization checkpoints, their errors relative to the sector reference, and
SQD error against cumulative shots. The shot curves use nested prefixes of one
seeded sample, not independent trials or confidence intervals. Re-evaluating
the checkpoints and shot prefixes adds sampling and diagonalization work. The
notebook includes previews from the default run; executing the cells regenerates
the figures with the current settings.

The defaults are 32,768 shots, 350 optimization steps and `MersenneTwister(42)`.
The script prints the energy during optimization, the SQD energies before and
after optimization using the same shot count and random-stream seed, and a
high-accuracy numerical reference for the full six-excitation sector. Changing
shots, iterations or seed may change the results. In particular, finite-shot
accuracy is not guaranteed for arbitrary settings.

With Julia 1.13.1, the default run lowers the variational energy from about
`-3.17256` to `-4.30989`. The initial and optimized SQD energies are
`-3.28600` and `-4.33136`, respectively, against the full-sector reference
`-4.33987`: an absolute difference of about `0.00851` after optimization.
The selected subspace grows from 109 to 753 configurations in this run.

## Model and steps

The example uses a ring of 12 sites and six excitations, with occupation
`nᵢ = |1⟩⟨1|ᵢ` and site 13 identified with site 1:

```text
H = Σᵢ εᵢ nᵢ + 0.25 Σᵢ nᵢnᵢ₊₁
    + Σᵢ tᵢ (σ⁺ᵢσ⁻ᵢ₊₁ + σ⁻ᵢσ⁺ᵢ₊₁)
εᵢ = -0.55 + 0.10(i - 1) + 0.04 sin(i)
tᵢ = 0.6 + 0.15 cos(i),                  i = 1, …, 12
```

1. Prepare one excitation in each neighboring pair, then apply eight layers of
   excitation-preserving partial exchange gates. The 44 gate angles are
   independent optimization parameters.
2. Minimize `⟨ψ(θ)|H|ψ(θ)⟩` using Adam and central finite differences, keeping
   the best observed parameters. This example calculates exact expectations
   from the MOSSQuantum simulator's state amplitudes and the sparse Hamiltonian in the
   six-excitation sector. It does not use the reference eigenvalue or eigenvector
   in the objective. On hardware, expectation estimation would require
   measurements of Hamiltonian terms; that procedure is not implemented here.
3. Sample both the initial and optimized circuits. Keep six-excitation shots
   and deduplicate the bitstrings. Since the simulator is noiseless and the
   circuit preserves excitation number, the sector filter is a consistency
   check. Construct the sparse matrix `Hₛ[i,j] = ⟨bᵢ|H|bⱼ⟩` for each sampled
   basis and find its lowest eigenpair. Counts select the basis; they are not
   matrix entries or the resulting eigenvector coefficients.
4. Separately solve for the lowest energy in the full six-excitation sector,
   with `binomial(12, 6) = 924` configurations, for comparison. This reference
   calculation is not a requirement of SQD. The sampled-subspace energy is a
   variational upper bound to the sector ground energy, up to numerical error.

The default optimizer evaluates the 44-parameter circuit 31,151 times; it is a
simple teaching implementation, not a scalable training strategy. The
Hamiltonian matrices are assembled directly in the relevant bases, without a
full 4096 × 4096 matrix. Small subspaces use dense diagonalization; larger ones
use the Hermitian iterative solver from MOSSQuantum's existing KrylovKit dependency.
Solver convergence and residuals are checked. State-vector simulation and full
sector enumeration still scale exponentially.

Samples have one column per qubit in MOSSQuantum order. Qubit 1 is the least
significant bit of a zero-based basis index; displayed strings put qubit 1
first. For example, `100000000000` corresponds to index 1. See
[MOSSQuantum conventions](../../docs/conventions.md#qubit-and-basis-ordering).

The example does not implement noisy configuration recovery, self-consistency,
chemistry integrals or a hardware experiment. See `sqd.jl` for the optimization
and SQD helpers and `run.jl` for the entrypoint.

## References

- Robledo-Moreno et al., [Chemistry Beyond the Scale of Exact Diagonalization on a Quantum-Centric Supercomputer](https://arxiv.org/abs/2405.05068), for SQD and configuration recovery.
- IBM Quantum, [Sample-based quantum diagonalization](https://qiskit.qotlabs.org/learning/courses/quantum-diagonalization-algorithms/sqd-overview), for the subspace projection workflow.
