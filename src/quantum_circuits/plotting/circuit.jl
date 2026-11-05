# 电路层绘图逻辑
# 处理整个电路的布局和绘制
# 类型已在父模块QuantumCircuitsPlotting中导入

# 低层绘图和门绘制函数已在同一模块中定义，直接可用

# ============================================================================
# 电路布局算法
# ============================================================================

"""
    compute_circuit_layout(circuit::QCircuit) -> (depth::Int, nqubits::Int, grid::Dict)

计算电路布局，返回深度、量子位数和门位置网格。

# 算法步骤：
1. 确定电路涉及的量子位范围
2. 使用贪心算法将门分配到时间步
3. 处理门之间的依赖关系
4. 返回布局网格

# 参数
- `circuit::QCircuit`: 量子电路

# 返回
- `depth::Int`: 电路深度（时间步数）
- `nqubits::Int`: 量子位数
- `grid::Dict{Tuple{Int,Int}, Any}`: 门位置网格，(time, qubit) -> 门信息
"""
# Nested circuits execute recursively, so lay out their leaves in execution order.
function _plot_instructions(circuit::QCircuit)
    instructions = Any[]
    for instruction in circuit
        if instruction isa QCircuit
            append!(instructions, _plot_instructions(instruction))
        else
            push!(instructions, instruction)
        end
    end
    return instructions
end

function _plot_qubits(circuit::QCircuit)
    return sort!(unique!(Int[q for instruction in _plot_instructions(circuit)
                             for q in positions(instruction)]))
end

# Measurements, post-selection and conditional feedback can carry dependencies
# beyond their quantum wires. Keep them ordered relative to the whole diagram.
_is_layout_barrier(instruction) = instruction isa Union{QMeasure,QSelect,QuantumCircuits.Conditional}

function _compute_layout(circuit::QCircuit; sequential::Bool=false)
    instructions = _plot_instructions(circuit)
    qubit_list = _plot_qubits(circuit)
    qubit_to_row = Dict(q => i for (i, q) in enumerate(qubit_list))
    occupied = Set{Tuple{Int,Int}}()
    last_on_wire = zeros(Int, length(qubit_list))
    gate_positions = Dict{Tuple{Int,Int}, Any}()
    depth = 0
    fence = 1

    for instruction in instructions
        rows = Int[qubit_to_row[q] for q in positions(instruction)]
        if isempty(rows)
            # A condition with empty branches still reads classical data and
            # has an execution position, but must not invent a quantum wire.
            instruction isa QuantumCircuits.Conditional ||
                throw(ArgumentError("cannot draw $(typeof(instruction)): it has no quantum positions"))
            depth += 1
            gate_positions[(depth, 0)] = (instruction, rows)
            fence = depth + 1
            continue
        end
        span = minimum(rows):maximum(rows)
        barrier = _is_layout_barrier(instruction)
        # A visual span may cover wires which are not operands; occupancy keeps
        # its connecting line clear, while last_on_wire preserves execution order.
        time = sequential || barrier ? depth + 1 : max(fence, maximum(last_on_wire[rows]) + 1)
        while any((time, row) in occupied for row in span)
            time += 1
        end
        for row in span
            push!(occupied, (time, row))
        end
        for row in rows
            last_on_wire[row] = time
        end
        gate_positions[(time, first(rows))] = (instruction, rows)
        depth = max(depth, time)
        barrier && (fence = time + 1)
    end
    return depth, length(qubit_list), gate_positions
end

compute_circuit_layout(circuit::QCircuit) = _compute_layout(circuit)

"""
    compute_circuit_stats(circuit::QCircuit) -> (nqubits, depth, gate_count)

计算展平嵌套电路后的量子位数、布局深度和指令类型统计。
"""
function compute_circuit_stats(circuit::QCircuit)
    depth, nqubits, _ = compute_circuit_layout(circuit)
    gate_counts = Dict{String,Int}()
    for instruction in _plot_instructions(circuit)
        name = string(typeof(instruction).name.name)
        gate_counts[name] = get(gate_counts, name, 0) + 1
    end
    return nqubits, depth, gate_counts
end

# ============================================================================
# 电路绘制函数
# ============================================================================

"""
    plot_circuit_internal(circuit::QCircuit; kwargs...) -> Plots.Plot

内部电路绘制函数，执行实际绘图工作。
"""
function plot_circuit_internal(circuit::QCircuit; kwargs...)
    return plot(circuit; kwargs...)
end

"""
    draw_qubit_names!(plt::Plots.Plot, nqubits::Int; names=[])

绘制量子位名称。

# 参数
- `plt`: 绘图对象
- `nqubits`: 量子位数
- `names`: 自定义名称列表，如果为空则使用默认名称 q₁, q₂, ...
"""
function draw_qubit_names!(plt::Plots.Plot, nqubits::Int; names=[])
    if isempty(names)
        names = ["q" * subscript(string(i)) for i in 1:nqubits]
    end

    for i in 1:nqubits
        draw_text!(plt, 0, i, names[i], color="black", halign=:center, valign=:center)
    end
end

# ============================================================================
# 绘图上下文管理
# ============================================================================

"""
    CircuitPlotContext

电路绘图上下文，管理绘图状态。
"""
mutable struct CircuitPlotContext
    plt::Plots.Plot
    nqubits::Int
    depth::Int
    current_step::Int
    qubit_names::Vector{String}

    function CircuitPlotContext(nqubits::Int, depth::Int; qubit_names=[])
        if isempty(qubit_names)
            qubit_names = ["q" * subscript(string(i)) for i in 1:nqubits]
        end

        plt = new_circuit_plot(nqubits, depth; qubit_names=qubit_names)
        new(plt, nqubits, depth, 0, qubit_names)
    end
end

"""
    increment_step!(ctx::CircuitPlotContext)

递增当前时间步。
"""
function increment_step!(ctx::CircuitPlotContext)
    ctx.current_step += 1
    return ctx.current_step
end

"""
    reset_step!(ctx::CircuitPlotContext, step::Int=0)

重置当前时间步。
"""
function reset_step!(ctx::CircuitPlotContext, step::Int=0)
    ctx.current_step = step
end