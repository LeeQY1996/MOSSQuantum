# QuantumCircuits绘图模块主文件
# 提供QuantumCircuits.jl电路的绘图功能

module QuantumCircuitsPlotting

using ..Plots, ..LaTeXStrings
import ..Plots: plot, savefig
import ..QuantumCircuits
import ..QuantumCircuits: Gate, ParametricGate, QuantumGate, AdjointQuantumGate
import ..QuantumCircuits: QCircuit, QMeasure, QSelect, AbstractQuantumMap
import ..QuantumCircuits: AbstractInstruction, Conditional, parameters
import ..QuantumCircuits: ParameterizedInstruction
import ..MOSSQuantum: Delay, NoisyCircuit
import ..QuantumCircuits: positions
# 导入具体门类型
import ..QuantumCircuits: XGate, YGate, ZGate, SGate, HGate, TGate, sqrtXGate, sqrtYGate
import ..QuantumCircuits: SWAPGate, iSWAPGate, CZGate, CNOTGate, CONTROLGate
import ..QuantumCircuits: TOFFOLIGate, FREDKINGate, CONTROLCONTROLGate
import ..QuantumCircuits: RxGate, RyGate, RzGate, PHASEGate
import ..QuantumCircuits: CRxGate, CRyGate, CRzGate, CPHASEGate, FSIMGate, CCPHASEGate

# 导出API
export plot, circuit_plot, draw!, draw_gate!
export new_circuit_plot, save_circuit_plot
export set_default_color, get_default_color
export available_gate_styles, register_gate_style

# 包含子模块
include("drawing.jl")
include("gates.jl")
include("circuit.jl")
include("layout.jl")
include("styles.jl")
include("api.jl")
include("instructions.jl")

end # module
