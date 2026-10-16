module MOSS

using LinearAlgebra, StaticArrays
using SparseArrays, TensorOperations
using Random

# Julia 1.9+ loads optional integrations through package extensions.
@static if !isdefined(Base, :get_extension)
    using Requires
end

# ============================================================================
# QuantumCircuits 子模块
# ============================================================================

include("quantum_circuits/QuantumCircuits.jl")

# 导入 QuantumCircuits 子模块
using .QuantumCircuits
using .QuantumCircuits.Gates
using .QuantumCircuits: permute, _kron_ops, _get_op, get_largest_pos, QOP_DATA_VALUE_TYPE

include("api/exports.jl")
include("api/parameter_binding.jl")

# Shared indexing, tensor and sampling helpers.
include("utils/distance.jl")
include("utils/parallel_for.jl")
include("execution/sampling.jl")
include("utils/tensor_ops.jl")
include("utils/index_ops.jl")

# State representations.
include("api/state_protocols.jl")
include("states/state_vector.jl")
include("states/batch_state_vector.jl")
include("states/density_matrix.jl")

# CPU gate kernels and public execution methods.
include("backends/cpu/gates/serial_short_range.jl")
include("backends/cpu/gates/threaded_short_range.jl")
include("backends/cpu/gates/threaded_long_range.jl")
include("execution/gates.jl")
include("backends/cpu/gates/generic.jl")
include("backends/cpu/gates/specific.jl")
include("execution/channels.jl")
include("backends/cpu/gates/channels.jl")
include("backends/cpu/gates/batch_threaded_short_range.jl")
include("backends/cpu/gates/batch_threaded_long_range.jl")
include("execution/batch_gates.jl")
include("backends/cpu/gates/batch.jl")

# Measurement and postselection.
include("execution/measurement.jl")
include("execution/post_selection.jl")

# Operator execution and expectation values.
include("backends/cpu/operators/utils.jl")
include("backends/cpu/operators/short_range_serial.jl")
include("backends/cpu/operators/short_range_threaded.jl")
include("backends/cpu/operators/long_range_threaded.jl")
include("execution/operators.jl")
include("backends/cpu/operators/density_matrix.jl")
include("backends/cpu/operators/generic.jl")
include("backends/cpu/expectations/serial.jl")
include("backends/cpu/expectations/threaded.jl")
include("backends/cpu/expectations/threaded_2.jl")
include("backends/cpu/expectations/high_qubit_terms.jl")
include("backends/cpu/expectations/high_qubit_terms_2.jl")
include("observables/expectation.jl")
include("backends/cpu/expectations/state_vector.jl")
include("backends/cpu/expectations/batch.jl")
include("observables/batch_expectation.jl")
include("backends/cpu/expectations/density_matrix_serial.jl")
include("observables/density_matrix_expectation.jl")

# Public backend contracts adapt the dense CPU implementation.
include("api/backend_protocols.jl")
include("execution/probabilities.jl")
include("execution/simulation.jl")

# Differentiation and partial trace.
include("differentiation/circuit.jl")
include("differentiation/expectation.jl")
include("observables/partial_trace.jl")

# Utilities retains its existing public module and import behavior.
include("utilities/Utilities.jl")
import .Utilities: variational_circuit_1d, real_variational_circuit_1d

@static if !isdefined(Base, :get_extension)
    function __init__()
        @require Zygote="e88e6eb3-aa80-5325-afca-941959d7151f" include("../ext/MOSSZygoteExt.jl")
        @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
            @require LaTeXStrings="b964fa9f-0449-5b57-a5c2-d3ea65f4040f" include("../ext/MOSSPlotsExt.jl")
        end
    end
end

end
