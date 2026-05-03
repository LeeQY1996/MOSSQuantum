# 低层绘图工具
# 移植自QuantumCircuitDraw.jl/src/tools.jl，适配QuantumCircuits.jl

const DEFAULT_LINEWIDTH = 3
const DEFAULT_WBOX = 0.7
const DEFAULT_COLOR = "#6fa5ff"

"""
    rectangle(x, y, w, h) -> Shape

创建矩形形状。
"""
rectangle(x, y, w, h) = Shape(x .+ [0, w, w, 0], y .+ [0, 0, h, h])

"""
    draw_box!(plt::Plots.Plot, x::Real, y::Real, width::Real, height::Real; color, linewidth)

绘制填充方框。
"""
function draw_box!(plt::Plots.Plot, x::Real, y::Real, width::Real, height::Real;
                   color=DEFAULT_COLOR, linewidth::Real=0)
    plot!(plt, rectangle(x, y, width, height),
          color=color, linewidth=linewidth, fill=true)
end

"""
    draw_circle!(plt::Plots.Plot, x::Real, y::Real; color, size)

绘制实心圆圈。
"""
function draw_circle!(plt::Plots.Plot, x::Real, y::Real;
                      color=DEFAULT_COLOR, size::Real=9)
    scatter!(plt, [x], [y],
             color=color, markersize=size,
             markershape=:circle, markerstrokewidth=0)
end

"""
    draw_line!(plt::Plots.Plot, x1::Real, y1::Real, x2::Real, y2::Real; color, linewidth)

绘制直线。
"""
function draw_line!(plt::Plots.Plot, x1::Real, y1::Real, x2::Real, y2::Real;
                    color=DEFAULT_COLOR, linewidth::Real=DEFAULT_LINEWIDTH)
    plot!(plt, [x1, x2], [y1, y2],
          color=color, linewidth=linewidth)
end

"""
    draw_text!(plt::Plots.Plot, x::Real, y::Real, txt; color, halign, valign, fontsize)

绘制文本标注。
"""
function draw_text!(plt::Plots.Plot, x::Real, y::Real, txt;
                    color="black", halign::Symbol=:center, valign::Symbol=:center, fontsize::Int=10)
    annotate!(plt, x, y, text(txt, fontsize, color, halign, valign))
end

"""
    draw_circle_plus!(plt::Plots.Plot, x::Real, y::Real; color)

绘制圆圈加号（用于CNOT目标位）。
"""
function draw_circle_plus!(plt::Plots.Plot, x::Real, y::Real; color=DEFAULT_COLOR)
    draw_circle!(plt, x, y, color=color, size=19)
    draw_line!(plt, x-0.15, y, x+0.15, y, color="white", linewidth=2)
    draw_line!(plt, x, y-0.15, x, y+0.15, color="white", linewidth=2)
end

"""
    draw_cross!(plt::Plots.Plot, x::Real, y::Real; color)

绘制交叉符号（用于SWAP门）。
"""
function draw_cross!(plt::Plots.Plot, x::Real, y::Real; color=DEFAULT_COLOR)
    draw_line!(plt, x-0.15, y-0.15, x+0.15, y+0.15, color=color)
    draw_line!(plt, x-0.15, y+0.15, x+0.15, y-0.15, color=color)
end

"""
    subscript(text::String) -> String

将数字转换为下标形式。
"""
function subscript(text::String)
    subscripts = Dict(
        '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
        '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉',
    )
    return join([subscripts[c] for c in text])
end

"""
    draw_qubit_lines!(plt::Plots.Plot, nqubits::Int, start_col::Real, end_col::Real)

绘制量子位线。
"""
function draw_qubit_lines!(plt::Plots.Plot, nqubits::Int, start_col::Real, end_col::Real)
    for q in 1:nqubits
        draw_line!(plt, start_col, q, end_col, q, color="black")
    end
end

"""
    draw_vertical_line!(plt::Plots.Plot, col::Real, qubit1::Int, qubit2::Int; color)

绘制垂直线条（用于连接控制门）。
"""
function draw_vertical_line!(plt::Plots.Plot, col::Real, qubit1::Int, qubit2::Int;
                             color=DEFAULT_COLOR)
    draw_line!(plt, col, qubit1, col, qubit2, color=color)
end
