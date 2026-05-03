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
function compute_circuit_layout(circuit::QCircuit)
    # 收集所有量子位
    all_qubits = Set{Int}()
    for gate in circuit
        for pos in positions(gate)
            push!(all_qubits, pos)
        end
    end

    # 如果没有门，返回默认值
    if isempty(all_qubits)
        return 1, 1, Dict{Tuple{Int,Int}, Any}()
    end

    nqubits = length(all_qubits)
    qubit_list = sort(collect(all_qubits))

    # 创建量子位映射：实际量子位索引 -> 绘图行号
    qubit_to_row = Dict(q => i for (i, q) in enumerate(qubit_list))

    # 初始化时间步网格
    max_time = 0
    occupied = Dict{Tuple{Int,Int}, Bool}()  # (time, row) -> occupied
    gate_positions = Dict{Tuple{Int,Int}, Any}()  # (time, row) -> gate信息

    # 贪心布局算法
    for gate in circuit
        gate_pos = positions(gate)
        gate_rows = [qubit_to_row[q] for q in gate_pos]

        # 多量子位门占据其跨度范围内的所有行（避免竖直线与其他门重叠）
        span_rows = minimum(gate_rows):maximum(gate_rows)

        # 找到第一个可用的时间步
        time = 1
        while any(get(occupied, (time, r), false) for r in span_rows)
            time += 1
        end

        # 占据该时间步跨度范围内的所有行
        for r in span_rows
            occupied[(time, r)] = true
        end

        # 记录门位置（使用第一个量子位作为主位置）
        main_row = qubit_to_row[gate_pos[1]]
        gate_positions[(time, main_row)] = (gate, gate_rows)

        max_time = max(max_time, time)
    end

    return max_time, nqubits, gate_positions
end

"""
    compute_circuit_stats(circuit::QCircuit) -> (nqubits::Int, depth::Int, gate_count::Dict)

计算电路统计信息。
"""
function compute_circuit_stats(circuit::QCircuit)
    all_qubits = Set{Int}()
    gate_counts = Dict{String, Int}()

    for gate in circuit
        for pos in positions(gate)
            push!(all_qubits, pos)
        end

        # 统计门类型
        gate_type = string(typeof(gate).name.name)
        gate_counts[gate_type] = get(gate_counts, gate_type, 0) + 1
    end

    nqubits = length(all_qubits)

    # 计算深度（简化版本，实际深度需要布局算法）
    depth = isempty(circuit) ? 1 : length(circuit)

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
    # 计算布局
    depth, nqubits, gate_grid = compute_circuit_layout(circuit)

    # 创建绘图画布
    plt = new_circuit_plot(nqubits, depth; kwargs...)

    # 绘制所有门
    for ((time, row), (gate, rows)) in gate_grid
        # 根据门类型调用相应的绘制函数
        if length(rows) == 1
            draw_gate!(plt, gate, time, rows[1])
        elseif length(rows) == 2
            draw_gate!(plt, gate, time, (rows[1], rows[2]))
        elseif length(rows) == 3
            draw_gate!(plt, gate, time, (rows[1], rows[2], rows[3]))
        else
            error("门绘制尚未实现：$(typeof(gate))（$(length(rows))量子位）")
        end
    end

    return plt
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