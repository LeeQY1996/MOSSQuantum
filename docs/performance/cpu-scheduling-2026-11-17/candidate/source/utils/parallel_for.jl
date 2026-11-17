using Base.Threads

const MIN_SIZE = 1024
const _CPU_PARALLEL_ACTIVE = :MOSSQuantum_cpu_parallel_active

function _parallel_task_count(total_itr::Int, n_threads::Int, min_work::Int, max_tasks::Int)
    total_itr >= 0 || throw(ArgumentError("iteration count must be nonnegative"))
    n_threads > 0 && min_work > 0 && max_tasks > 0 ||
        throw(ArgumentError("thread budget, minimum work and task limit must be positive"))
    return max(1, min(n_threads, Threads.nthreads(), max_tasks, div(total_itr, min_work)))
end

function _run_cpu_partition(f::F, total_itr, tasks, partition, args...) where {F}
    task_local_storage(_CPU_PARALLEL_ACTIVE, true) do
        f(get_size_1(total_itr, tasks, partition),
          get_size_2(total_itr, tasks, partition) - 1, args...)
    end
end


get_size_1(total_itr::Int, n_threads::Int, thread_id::Int) = div(total_itr * thread_id, n_threads)
get_size_2(total_itr::Int, n_threads::Int, thread_id::Int) = div(total_itr * (thread_id + 1), n_threads)

"""
    Run zero-based inclusive partitions, keeping at least min_work iterations
    per task. Nested calls inside a CPU partition use the caller's task.
"""
function parallel_run(total_itr::Int, n_threads::Int, f::F, args...;
                      min_work::Int=MIN_SIZE, max_tasks::Int=n_threads) where {F}
    tasks = _parallel_task_count(total_itr, n_threads, min_work, max_tasks)
    if tasks == 1 || get(task_local_storage(), _CPU_PARALLEL_ACTIVE, false) === true
        return f(0, total_itr-1, args...)
    end
    # @threads creates a full pool of tasks even when fewer partitions have work.
    @sync for partition in 0:tasks-1
        Threads.@spawn _run_cpu_partition(f, total_itr, tasks, partition, args...)
    end
    return nothing
end

"""
    The inner function f is assumed to be Zero Based
"""
function parallel_sum(::Type{T}, total_itr::Int, n_threads::Int, f::Function, args...) where {T<:Real}
    if (total_itr >= MIN_SIZE) && (n_threads > 1)
        # nave, resi, jobs = partition_jobs(total_itr, n_threads)
        r = Atomic{T}(0)
        Threads.@threads for thread_id in 0:(n_threads-1)
            ist = get_size_1(total_itr, n_threads, thread_id)
            ifn = get_size_2(total_itr, n_threads, thread_id) - 1
            atomic_add!(r, f(ist, ifn, args...))
        end
        return r[]
    else
        return f(0, total_itr-1, args...)
    end    
end


function parallel_sum(::Type{T}, total_itr::Int, n_threads::Int, f::Function, args...) where {T<:Complex}
    if (total_itr >= MIN_SIZE) && (n_threads > 1)
        # nave, resi, jobs = partition_jobs(total_itr, n_threads)
        RT = real(T)
        rr = Atomic{RT}(0)
        ri = Atomic{RT}(0)
        Threads.@threads for thread_id in 0:(n_threads-1)
            ist = get_size_1(total_itr, n_threads, thread_id)
            ifn = get_size_2(total_itr, n_threads, thread_id) - 1
            tmp = f(ist, ifn, args...)
            atomic_add!(rr, real(tmp))
            atomic_add!(ri, imag(tmp))
        end
        return Complex(rr[], ri[])
    else
        return f(0, total_itr-1, args...)
    end    
end
