# Finite-shot variational optimization

Run from the repository root:

```sh
julia --project=. examples/optimization/run.jl
```

The example optimizes a two-qubit noisy energy using 2,000 shots per objective
call and 60 Adam updates. It prints a fresh final energy estimate, its sampling
standard error, and total shots. No additional dependencies are required.

To reuse the workflow, import the optimization module:

```julia
using MOSSQuantum.Optimization
result = minimize(objective, initial_parameters;
    method=SPSAGradient(step=.2, directions=4), optimizer=:sgd,
    iterations=100, learning_rate=.2, decay=.602,
    perturbation_decay=.101, rng=Xoshiro(42))
```

Construct `objective` using `ShotExpectationObjective`; see the
[classical control and gradient guide](../../docs/classical-control-and-gradients.md).
`method=ParameterShift()` and `optimizer=:adam` are defaults. Learning rate is
`learning_rate/k^decay`; SPSA perturbation size is `step/k^perturbation_decay`.
`result.history` contains each gradient estimate and its pre-update parameters.
`callback(step) === false` stops before that update; the callback receives a copy.
`result.parameters` always receives a fresh final estimate, including with zero
iterations. Total shots include every gradient value/shift and that final estimate.

The result reports `:iteration_limit`, `:callback`, or `:shot_budget`, not an inferred convergence
claim. Choose budgets and schedules for the problem; noise and finite-difference
bias can prevent convergence. The workflow does not select the lowest noisy
history value as a claimed optimum.

## Total shot cap

Pass `max_shots=200_000` to `minimize` to cap the entire run, including gradient
value/shift evaluations, any adaptive pilots, and the fresh final estimate.
The workflow reserves the final estimate, completes only whole steps that fit,
and returns `status=:shot_budget` when another gradient would exceed the cap.
A cap smaller than the final estimate is rejected before sampling. The per-call
`shots` value remains unchanged. See [prepared experiments and budgets](../../docs/prepared-experiments.md).

Run `julia --project=. examples/optimization/prepared_run.jl` for a complete
prepared parameter scan followed by adaptive-shot optimization capped at 100,000
shots. The scan uses its own separate 12,000-shot budget.
