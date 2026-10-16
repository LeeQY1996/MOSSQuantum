module QuantumCircuits

using SparseArrays, LinearAlgebra, TensorOperations
using Requires

# gates
export nqubits, positions, mat, ordered_positions, ordered_mat, change_positions, shift, differentiate
export parameters, nparameters, active_parameters, activate_parameter!, activate_parameters!, deactivate_parameter!, deactivate_parameters!, reset_parameters!
export Gate, ParametricGate, QuantumGate, AdjointQuantumGate, gate, XGate, YGate, ZGate, SGate, HGate, TGate, sqrtXGate, sqrtYGate
export SWAPGate, iSWAPGate, CZGate, CNOTGate, CONTROLGate
export TOFFOLIGate, FREDKINGate, CONTROLCONTROLGate

# parametric gates
export RxGate, RyGate, RzGate, PHASEGate
export CRxGate, CRyGate, CRzGate, CPHASEGate, FSIMGate
export CCPHASEGate


# quantum channel
export AbstractQuantumMap, QuantumMap, ordered_supermat, kraus_matrices, is_tp
export AmplitudeDamping, PhaseDamping, Depolarizing


# circuit 
export QMeasure, QSelect, QCircuit

# hamiltonian
export QubitsTerm, oplist, coeff, QubitsOperator, matrix, simplify

abstract type QuantumOperation end

# auxiliary
include("utils/tensor_ops.jl")


# elementary gate matrices
include("gates/Gates.jl")

using .Gates


# gate operations
include("gates/abstract_gates.jl")
include("gates/quantum_gate.jl")
include("gates/parametric_gates.jl")
include("gates/one_qubit.jl")
include("gates/two_qubit.jl")
include("gates/three_qubit.jl")
include("gates/differentiation.jl")

# quantum channel
include("channels/abstract_maps.jl")
include("channels/quantum_map.jl")
include("channels/one_qubit.jl")

# circuit
include("circuits/circuit.jl")

# qubit hamiltonian
include("operators/qubits_term.jl")
include("operators/qubits_operator.jl")

# ============================================================================
# 绘图功能（条件加载）
# ============================================================================

function __init__()
    @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        @require LaTeXStrings="b964fa9f-0449-5b57-a5c2-d3ea65f4040f" begin
            # 加载绘图模块文件，这将在当前模块(QuantumCircuits)内创建子模块QuantumCircuitsPlotting
            include("plotting/QuantumCircuitsPlotting.jl")

            # 现在QuantumCircuitsPlotting子模块已定义，我们可以引用它
            # 在模块级别定义转发函数并导出
            @eval begin
                # 导入绘图模块的函数
                import .QuantumCircuitsPlotting: plot as plot_, circuit_plot as circuit_plot_, draw_gate! as draw_gate!_, draw! as draw!_
                import .QuantumCircuitsPlotting: new_circuit_plot as new_circuit_plot_, save_circuit_plot as save_circuit_plot_
                import .QuantumCircuitsPlotting: set_default_color as set_default_color_, get_default_color as get_default_color_
                import .QuantumCircuitsPlotting: available_gate_styles as available_gate_styles_, register_gate_style as register_gate_style_

                # 定义模块级的转发函数
                plot(circuit::QCircuit; kwargs...) = plot_(circuit; kwargs...)
                circuit_plot(circuit::QCircuit; kwargs...) = circuit_plot_(circuit; kwargs...)
                draw_gate!(plt, gate, step, qubit; kwargs...) = draw_gate!_(plt, gate, step, qubit; kwargs...)
                draw!(plt, gate, step, qubit; kwargs...) = draw!_(plt, gate, step, qubit; kwargs...)
                new_circuit_plot(args...; kwargs...) = new_circuit_plot_(args...; kwargs...)
                save_circuit_plot(args...; kwargs...) = save_circuit_plot_(args...; kwargs...)
                set_default_color(color) = set_default_color_(color)
                get_default_color() = get_default_color_()
                available_gate_styles() = available_gate_styles_()
                register_gate_style(args...; kwargs...) = register_gate_style_(args...; kwargs...)

                # 导出这些函数
                export plot, circuit_plot, draw_gate!, draw!
                export new_circuit_plot, save_circuit_plot
                export set_default_color, get_default_color
                export available_gate_styles, register_gate_style
            end

            @info "QuantumCircuits绘图模块已加载。使用plot(circuit)绘制电路。"
        end

        # 如果只有Plots没有LaTeXStrings，提供有限功能
        @static if !isdefined(@__MODULE__, :QuantumCircuitsPlotting)
            @warn """
            Plots.jl已加载，但LaTeXStrings.jl未安装。
            绘图功能有限：参数门将显示为文本而非LaTeX。
            安装LaTeXStrings以获得更好的显示效果：
                ] add LaTeXStrings
            """
        end
    end
end

# 当Plots.jl未安装时的回退函数（仅在绘图模块未加载时生效）
function plot(circuit::QCircuit; kwargs...)
    error("""
    绘图功能需要Plots.jl和LaTeXStrings.jl。
    请安装这些包：
        ] add Plots LaTeXStrings
    然后重新加载QuantumCircuits。
    """)
end

function circuit_plot(circuit::QCircuit; kwargs...)
    plot(circuit; kwargs...)
end

end