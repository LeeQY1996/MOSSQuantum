# 门绘制方法
# 为QuantumCircuits.jl门类型实现绘图功能
# 类型已在父模块QuantumCircuitsPlotting中导入

# ============================================================================
# 单量子位门绘制
# ============================================================================

function draw_gate!(plt::Plots.Plot, gate::Gate, step::Int, qubit::Int; kwargs...)
    error("draw_gate! not implemented for gate type $(typeof(gate))")
end

# Generic QuantumGate fallback: use type name as label
function draw_gate!(plt::Plots.Plot, gate::QuantumGate{1}, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label=nothing)
    lbl = isnothing(label) ? string(typeof(gate)) : label
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, lbl)
end

function draw_gate!(plt::Plots.Plot, gate::QuantumGate{N}, step::Int, qubits::Tuple;
                    color=DEFAULT_COLOR, label=nothing) where N
    lbl = isnothing(label) ? "U" : label
    if N == 2
        c, t = qubits
        draw_circle!(plt, step, c, color=color)
        draw_vertical_line!(plt, step, c, t, color=color)
        draw_box!(plt, step - DEFAULT_WBOX/2, t - DEFAULT_WBOX/2,
                  DEFAULT_WBOX, DEFAULT_WBOX, color=color)
        draw_text!(plt, step, t, lbl)
    elseif N == 3
        c1, c2, target = qubits
        draw_circle!(plt, step, c1, color=color)
        draw_circle!(plt, step, c2, color=color)
        draw_vertical_line!(plt, step, min(c1, c2, target), max(c1, c2, target), color=color)
        draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
                  DEFAULT_WBOX, DEFAULT_WBOX, color=color)
        draw_text!(plt, step, target, lbl)
    else
        error("Generic QuantumGate drawing not implemented for $N qubits")
    end
end

# AdjointQuantumGate fallback: delegate to parent gate type
function draw_gate!(plt::Plots.Plot, gate::AdjointQuantumGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label=nothing)
    lbl = isnothing(label) ? string(typeof(gate.parent)) * "†" : label
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, lbl)
end

function draw_gate!(plt::Plots.Plot, gate::XGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="X")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::YGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="Y")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::ZGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="Z")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::HGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="H")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::SGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="S")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::TGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="T")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::sqrtXGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}=L"\sqrt{X}")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

function draw_gate!(plt::Plots.Plot, gate::sqrtYGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}=L"\sqrt{Y}")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end

# ============================================================================
# 参数门绘制
# ============================================================================

function draw_gate!(plt::Plots.Plot, gate::RxGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR)
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_x(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_x(\pi/2)"
    elseif isapprox(θ, π/4)
        label = L"R_x(\pi/4)"
    else
        label = L"R_x($θ)"
    end
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::RyGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR)
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_y(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_y(\pi/2)"
    elseif isapprox(θ, π/4)
        label = L"R_y(\pi/4)"
    else
        label = L"R_y($θ)"
    end
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::RzGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR)
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_z(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_z(\pi/2)"
    elseif isapprox(θ, π/4)
        label = L"R_z(\pi/4)"
    else
        label = L"R_z($θ)"
    end
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::PHASEGate, step::Int, qubit::Int;
                    color=DEFAULT_COLOR)
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"P(\pi)"
    elseif isapprox(θ, π/2)
        label = L"P(\pi/2)"
    elseif isapprox(θ, π/4)
        label = L"P(\pi/4)"
    else
        label = L"P($θ)"
    end
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label, fontsize=7)
end

# ============================================================================
# 双量子位门绘制
# ============================================================================

function draw_gate!(plt::Plots.Plot, gate::CNOTGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    control, target = qubits
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_circle_plus!(plt, step, target, color=color)
end

function draw_gate!(plt::Plots.Plot, gate::CZGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="Z")
    control, target = qubits
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label)
end

function draw_gate!(plt::Plots.Plot, gate::SWAPGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    q1, q2 = qubits
    draw_vertical_line!(plt, step, q1, q2, color=color)
    draw_cross!(plt, step, q1, color=color)
    draw_cross!(plt, step, q2, color=color)
end

function draw_gate!(plt::Plots.Plot, gate::iSWAPGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    q1, q2 = qubits
    draw_vertical_line!(plt, step, q1, q2, color=color)
    draw_cross!(plt, step, q1, color=color)
    draw_cross!(plt, step, q2, color=color)
    draw_text!(plt, step, q1, "i", color=color, halign=:left, valign=:top)
end

function draw_gate!(plt::Plots.Plot, gate::CONTROLGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="U")
    control, target = qubits
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label)
end

function draw_gate!(plt::Plots.Plot, gate::CRxGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    control, target = qubits
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_x(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_x(\pi/2)"
    else
        label = L"R_x($θ)"
    end
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::CRyGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    control, target = qubits
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_y(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_y(\pi/2)"
    else
        label = L"R_y($θ)"
    end
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::CRzGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    control, target = qubits
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"R_z(\pi)"
    elseif isapprox(θ, π/2)
        label = L"R_z(\pi/2)"
    else
        label = L"R_z($θ)"
    end
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::CPHASEGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR)
    control, target = qubits
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"P(\pi)"
    elseif isapprox(θ, π/2)
        label = L"P(\pi/2)"
    else
        label = L"P($θ)"
    end
    draw_circle!(plt, step, control, color=color)
    draw_vertical_line!(plt, step, control, target, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label, fontsize=7)
end

function draw_gate!(plt::Plots.Plot, gate::FSIMGate, step::Int, qubits::Tuple{Int,Int};
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="FSIM")
    q1, q2 = qubits
    draw_box!(plt, step - DEFAULT_WBOX/2, q1 - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, q1, label)
    draw_vertical_line!(plt, step, q1, q2, color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, q2 - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, q2, label)
end

# ============================================================================
# 三量子位门绘制
# ============================================================================

function draw_gate!(plt::Plots.Plot, gate::TOFFOLIGate, step::Int, qubits::Tuple{Int,Int,Int};
                    color=DEFAULT_COLOR)
    c1, c2, target = qubits
    draw_circle!(plt, step, c1, color=color)
    draw_circle!(plt, step, c2, color=color)
    draw_vertical_line!(plt, step, min(c1, c2, target), max(c1, c2, target), color=color)
    draw_circle_plus!(plt, step, target, color=color)
end

function draw_gate!(plt::Plots.Plot, gate::FREDKINGate, step::Int, qubits::Tuple{Int,Int,Int};
                    color=DEFAULT_COLOR)
    c, q1, q2 = qubits
    draw_circle!(plt, step, c, color=color)
    draw_vertical_line!(plt, step, min(c, q1, q2), max(c, q1, q2), color=color)
    draw_cross!(plt, step, q1, color=color)
    draw_cross!(plt, step, q2, color=color)
end

function draw_gate!(plt::Plots.Plot, gate::CONTROLCONTROLGate, step::Int, qubits::Tuple{Int,Int,Int};
                    color=DEFAULT_COLOR, label::Union{String,LaTeXString}="U")
    c1, c2, target = qubits
    draw_circle!(plt, step, c1, color=color)
    draw_circle!(plt, step, c2, color=color)
    draw_vertical_line!(plt, step, min(c1, c2, target), max(c1, c2, target), color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label)
end

function draw_gate!(plt::Plots.Plot, gate::CCPHASEGate, step::Int, qubits::Tuple{Int,Int,Int};
                    color=DEFAULT_COLOR)
    c1, c2, target = qubits
    θ = gate.paras[1]
    if isapprox(θ, π)
        label = L"P(\pi)"
    elseif isapprox(θ, π/2)
        label = L"P(\pi/2)"
    else
        label = L"P($θ)"
    end
    draw_circle!(plt, step, c1, color=color)
    draw_circle!(plt, step, c2, color=color)
    draw_vertical_line!(plt, step, min(c1, c2, target), max(c1, c2, target), color=color)
    draw_box!(plt, step - DEFAULT_WBOX/2, target - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, target, label, fontsize=7)
end

# ============================================================================
# 测量和选择操作
# ============================================================================

function draw_gate!(plt::Plots.Plot, gate::QMeasure, step::Int, qubit::Int;
                    color="black")
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)

    center_x = step
    center_y = qubit + 0.1
    radius = 0.23

    theta = 0:0.1:π
    x = radius * cos.(theta) .+ center_x
    y = -radius * sin.(theta) .+ center_y
    plot!(plt, x, y, color=:white, linewidth=2)

    draw_line!(plt, center_x, center_y, center_x + radius, center_y - radius,
               color=:white, linewidth=2)
end

function draw_gate!(plt::Plots.Plot, gate::QSelect, step::Int, qubit::Int;
                    color=DEFAULT_COLOR)
    label = gate.state == 0 ? "|0⟩" : "|1⟩"
    draw_box!(plt, step - DEFAULT_WBOX/2, qubit - DEFAULT_WBOX/2,
              DEFAULT_WBOX, DEFAULT_WBOX, color=color)
    draw_text!(plt, step, qubit, label)
end
