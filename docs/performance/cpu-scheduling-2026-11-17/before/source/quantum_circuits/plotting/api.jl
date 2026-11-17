# 用户面向API
# 提供简单易用的绘图接口

# 绘图函数已在同一模块中定义，直接可用

# ============================================================================
# 主要绘图函数
# ============================================================================

"""
    new_circuit_plot(nqubits::Int, depth::Int; kwargs...) -> Plots.Plot

创建新的电路绘图画布。

# 参数
- `nqubits::Int`: 量子位数
- `depth::Int`: 电路深度（时间步数）
- `qubit_names::Vector{String}`: 量子位名称（默认：["q₁", "q₂", ...]）
- `grid::Bool`: 是否显示网格（默认：false）
- `dpi::Int`: 图像DPI（默认：300）
- `size::Tuple{Int,Int}`: 图像尺寸（默认：自动计算）
- `title::String`: 图像标题（默认：""）

# 返回
- `Plots.Plot`: 空电路画布

# 示例
```julia
plt = new_circuit_plot(3, 5; qubit_names=["|0⟩", "|1⟩", "|2⟩"], grid=true)
```
"""
function new_circuit_plot(nqubits::Int, depth::Int;
                         qubit_names::Vector{String}=String[],
                         grid::Bool=false,
                         dpi::Int=300,
                         size::Union{Tuple{Int,Int},Nothing}=nothing,
                         title::String="")::Plots.Plot

    nqubits >= 0 || throw(ArgumentError("nqubits must be nonnegative"))
    depth >= 0 || throw(ArgumentError("depth must be nonnegative"))
    isempty(qubit_names) || length(qubit_names) == nqubits ||
        throw(ArgumentError("expected $nqubits qubit names, got $(length(qubit_names))"))

    # 自动计算图像尺寸
    if isnothing(size)
        width = (depth + 1) * 60
        height = (nqubits + 1) * 60
        size = (width, height)
    end

    # 创建绘图
    plt = Plots.plot(legend=false,
                    aspect_ratio=1,
                    grid=grid,
                    showaxis=grid,
                    ticks=grid,
                    yflip=true,
                    size=size,
                    dpi=dpi,
                    title=title)

    # 绘制量子位名称
    if !isempty(qubit_names)
        draw_qubit_names!(plt, nqubits; names=qubit_names)
    else
        draw_qubit_names!(plt, nqubits)
    end

    # 绘制量子位线
    start_col = get_wbox() / 2
    end_col = depth + 1 - get_wbox() / 2
    draw_qubit_lines!(plt, nqubits, start_col, end_col)

    # 设置x轴范围
    Plots.plot!(plt, xlim=(0 - get_wbox()/2, depth + 1))

    return plt
end

"""
    plot(circuit::QCircuit; kwargs...) -> Plots.Plot

绘制QuantumCircuits.jl电路。

# 参数
- `circuit::QCircuit`: 要绘制的量子电路
- `qubit_names::Vector{String}`: 量子位名称（默认为实际量子位编号）
- `grid::Bool`: 是否显示网格（默认：false）
- `dpi::Int`: 图像DPI（默认：300）
- `size::Tuple{Int,Int}`: 图像尺寸（默认：自动计算）
- `title::String`: 图像标题（默认：""）
- `show_parameters::Bool`: 是否显示参数值（默认：true）
- `gate_colors::Dict{Type, String}`: 门类型到颜色的映射
- `layout_algorithm::Symbol`: 布局算法（`:auto`, `:compact`, `:sequential`）

# 返回值
- `Plots.Plot`: 可进一步自定义或保存的绘图对象

# 示例
```julia
using MOSSQuantum, Plots, LaTeXStrings
# Plots 与 LaTeXStrings 共同启用可选绘图扩展

circuit = QCircuit()
push!(circuit, XGate(1))
push!(circuit, HGate(2))
push!(circuit, CNOTGate(1, 2))

# 基础绘图
plt = MOSSQuantum.QuantumCircuits.plot(circuit)

# 自定义绘图
plt = MOSSQuantum.QuantumCircuits.plot(circuit;
    qubit_names=["q₁", "q₂"],
    grid=true,
    dpi=600,
    title="量子傅里叶变换电路"
)

# 保存图像
savefig(plt, "circuit.png")
```
"""
function plot(circuit::QCircuit;
             qubit_names::Vector{String}=String[],
             grid::Bool=false,
             dpi::Int=300,
             size::Union{Tuple{Int,Int},Nothing}=nothing,
             title::String="",
             show_parameters::Bool=true,
             gate_colors::Dict{Type,String}=Dict{Type,String}(),
             layout_algorithm::Symbol=:auto)::Plots.Plot

    layout_algorithm in (:auto, :compact, :sequential) ||
        throw(ArgumentError("unsupported layout algorithm: $layout_algorithm"))
    depth, nqubits, gate_positions = _compute_layout(circuit;
        sequential=(layout_algorithm == :sequential))
    # Labels follow actual positions even when only a sparse subset is used.
    names = isempty(qubit_names) ? ["q" * subscript(string(q)) for q in _plot_qubits(circuit)] : qubit_names
    plt = new_circuit_plot(nqubits, depth;
                          qubit_names=names, grid=grid, dpi=dpi,
                          size=size, title=title)

    for ((time, _), (gate, rows)) in sort!(collect(gate_positions); by=first)
        isempty(rows) && continue # classical-only condition is explained below the diagram
        gate_color = get(gate_colors, typeof(gate), get_gate_color(typeof(gate)))
        target = length(rows) == 1 ? first(rows) : Tuple(rows)
        draw_circuit_gate!(plt, gate, time, target;
                           color=gate_color, show_parameters=show_parameters)
    end
    _draw_instruction_notes!(plt, gate_positions, nqubits; size=size, show_parameters=show_parameters)

    return plt
end

"""
    circuit_plot(circuit::QCircuit; kwargs...) -> Plots.Plot

`plot`的别名，提供向后兼容性。
"""
const circuit_plot = plot

"""
    save_circuit_plot(plt::Plots.Plot, filename::String; kwargs...)

保存电路绘图到文件。

# 参数
- `plt::Plots.Plot`: 绘图对象
- `filename::String`: 文件名（支持.png, .pdf, .svg等格式）
- `kwargs...`: 传递给`savefig`的额外参数

# 示例
```julia
plt = plot(circuit)
save_circuit_plot(plt, "circuit.png")
save_circuit_plot(plt, "circuit.pdf", dpi=600)
```
"""
function save_circuit_plot(plt::Plots.Plot, filename::String; kwargs...)
    Plots.savefig(plt, filename; kwargs...)
end

# ============================================================================
# 低层绘图API
# ============================================================================

"""
    draw!(plt::Plots.Plot, gate::Gate, step::Int, qubit::Int; kwargs...)

在绘图上绘制单个量子门（低层API）。

# 参数
- `plt::Plots.Plot`: 目标绘图
- `gate::Gate`: 要绘制的门
- `step::Int`: 时间步（列位置）
- `qubit::Int`: 量子位（行位置）
- `color::String`: 门颜色（默认：基于门类型）
- `label::Union{String,LaTeXString}`: 自定义标签
- `scale::Real`: 缩放因子（默认：1.0）

# 示例
```julia
plt = new_circuit_plot(3, 5)
draw!(plt, XGate(1), 2, 1)  # 在时间步2，量子位1绘制X门
draw!(plt, CNOTGate(1, 2), 3, (1, 2))  # 绘制CNOT门
```
"""
function draw!(plt::Plots.Plot, gate::Gate, step::Int, qubits::Union{Int,Tuple}; kwargs...)
    draw_gate!(plt, gate, step, qubits; kwargs...)
end


# ============================================================================
# 辅助函数
# ============================================================================

"""
    get_circuit_stats(circuit::QCircuit) -> Dict

获取电路统计信息。

# 返回
- `Dict`: 包含量子位数、深度、门类型统计等信息

# 示例
```julia
stats = get_circuit_stats(circuit)
println("量子位数: ", stats[:nqubits])
println("电路深度: ", stats[:depth])
```
"""
function get_circuit_stats(circuit::QCircuit)::Dict
    nqubits, depth, gate_counts = compute_circuit_stats(circuit)

    return Dict(
        :nqubits => nqubits,
        :depth => depth,
        :gate_counts => gate_counts,
        :total_gates => sum(values(gate_counts); init=0)
    )
end

"""
    print_circuit_info(circuit::QCircuit)

打印电路信息。
"""
function print_circuit_info(circuit::QCircuit)
    stats = get_circuit_stats(circuit)

    println("电路信息:")
    println("  量子位数: ", stats[:nqubits])
    println("  电路深度: ", stats[:depth])
    println("  总门数: ", stats[:total_gates])

    if !isempty(stats[:gate_counts])
        println("  门类型统计:")
        for (gate_type, count) in sort(collect(stats[:gate_counts]), by=x->x[2], rev=true)
            println("    - $gate_type: $count")
        end
    end
end
