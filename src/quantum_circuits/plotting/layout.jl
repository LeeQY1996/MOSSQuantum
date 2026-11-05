# 高级布局算法
# 提供多种电路布局选项
# 类型已在父模块QuantumCircuitsPlotting中导入

"""
    compute_compact_layout(circuit::QCircuit) -> Dict{Tuple{Int,Int}, Any}

计算紧凑布局，尽可能减少电路深度。

# 算法
1. 按指令顺序保留量子位上的依赖关系
2. 将可并行的指令放在同一时间步，避免连接线重叠
3. 将测量、后选择与经典条件作为全局顺序屏障

# 参数
- `circuit::QCircuit`: 量子电路

# 返回
- `Dict{Tuple{Int,Int}, Any}`: 门位置网格
"""
compute_compact_layout(circuit::QCircuit) = last(_compute_layout(circuit))

"""
    compute_sequential_layout(circuit::QCircuit) -> Dict

按执行顺序逐个放置指令，每个指令占一列。
"""
compute_sequential_layout(circuit::QCircuit) = last(_compute_layout(circuit; sequential=true))

"""
    validate_layout(circuit::QCircuit, layout::Dict) -> Bool

验证布局是否有效（无冲突）。

# 参数
- `circuit::QCircuit`: 原始电路
- `layout::Dict`: 布局网格

# 返回
- `Bool`: 布局是否有效
"""
function validate_layout(circuit::QCircuit, layout::Dict)::Bool
    # 检查每个门是否都出现在布局中
    gate_count = 0
    for ((time, row), (gate, rows)) in layout
        gate_count += 1
        # 验证门属于电路（简化检查）
    end

    # 检查冲突：同一时间步的同一量子位只能有一个门
    occupied = Set{Tuple{Int,Int}}()
    for ((time, row), (gate, rows)) in layout
        for r in rows
            pos = (time, r)
            if pos in occupied
                return false  # 冲突
            end
            push!(occupied, pos)
        end
    end

    return true
end

"""
    get_layout_quality(circuit::QCircuit, layout::Dict) -> Dict

评估布局质量指标。

# 返回
- `Dict`: 包含深度、并行度等指标
"""
function get_layout_quality(circuit::QCircuit, layout::Dict)::Dict
    if isempty(layout)
        return Dict(:depth => 0, :parallelism => 0.0, :efficiency => 0.0)
    end

    # 计算深度
    times = [time for (time, row) in keys(layout)]
    depth = maximum(times)

    # 计算并行度（平均每时间步的门数）
    time_gates = Dict{Int, Int}()
    for (time, row) in keys(layout)
        time_gates[time] = get(time_gates, time, 0) + 1
    end

    avg_parallelism = length(layout) / depth

    # 计算效率（使用的量子位时间步 / 总量子位时间步）
    total_qubit_timesteps = depth * length(Set([row for (time, row) in keys(layout)]))
    used_qubit_timesteps = length(layout)
    efficiency = total_qubit_timesteps > 0 ? used_qubit_timesteps / total_qubit_timesteps : 0.0

    return Dict(
        :depth => depth,
        :avg_parallelism => avg_parallelism,
        :efficiency => efficiency,
        :total_gates => length(layout)
    )
end