"""A thread-safe hard cap. Failed sampling calls retain their reserved charge."""
mutable struct ShotBudget
    limit::Int
    used::Int
    lock::ReentrantLock
    ShotBudget(limit::Integer) = new(_execution_shots(limit),0,ReentrantLock())
end
struct ShotBudgetExceeded <: Exception
    requested::Int
    remaining::Int
end
Base.showerror(io::IO,e::ShotBudgetExceeded) = print(io,"shot budget exhausted: requested ",e.requested,", remaining ",e.remaining)
remaining_shots(b::ShotBudget) = lock(()->b.limit-b.used,b.lock)
function _with_shot_budget(f,budget,n::Int)
    isnothing(budget) && return f()
    budget isa ShotBudget || throw(ArgumentError("budget must be a ShotBudget"))
    # Reserve atomically, but do not serialize independent experiments.
    lock(budget.lock) do
        left = budget.limit-budget.used
        n<=left || throw(ShotBudgetExceeded(n,left))
        budget.used += n
    end
    return f()
end
