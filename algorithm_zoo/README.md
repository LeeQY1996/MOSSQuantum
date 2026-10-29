# MOSSQuantum algorithm zoo

Runnable, small examples that demonstrate quantum algorithms with MOSSQuantum. These
examples live in the MOSSQuantum repository and use its existing project environment;
they are educational programs rather than new exported core APIs.

| Example | Julia script | Jupyter notebook |
| --- | --- | --- |
| [Finite-shot optimization](optimization/README.md) | [run.jl](optimization/run.jl) | — |
| [Sample-based quantum diagonalization (SQD)](sqd/README.md) | [run.jl](sqd/run.jl) | [sqd.ipynb](sqd/sqd.ipynb) |

From the repository root, first prepare the project with
`julia --project=. -e 'using Pkg; Pkg.instantiate()'`, then follow the run
instructions for each example. The examples use seeded random number generators
where reproducibility matters.

Each example provides a runnable Julia script; SQD also provides a Jupyter notebook. The
notebook explains the algorithm alongside the code; both formats use the same
example implementation so their behavior stays consistent. See the individual
example's README for setup and execution instructions.
