module MOSSQuantumPlotsExt

import MOSSQuantum
import MOSSQuantum.QuantumCircuits
using Plots, LaTeXStrings

include("../src/quantum_circuits/plotting/QuantumCircuitsPlotting.jl")

for name in (:plot, :circuit_plot, :draw_gate!, :draw!, :new_circuit_plot,
             :save_circuit_plot, :set_default_color, :get_default_color,
             :available_gate_styles, :register_gate_style)
    @eval QuantumCircuits._plotting_dispatch(::Val{$(QuoteNode(name))}, args...; kwargs...) =
        getfield(QuantumCircuitsPlotting, $(QuoteNode(name)))(args...; kwargs...)
end

end
