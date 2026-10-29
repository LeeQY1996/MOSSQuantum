module MOSSQuantumDemoArrayBackend

using LinearAlgebra
import MOSSQuantum

export DemoArray, ArrayBackend, ScalarAccessError, HostConversionError, hostcopy
export DemoUnknown, DemoRyObjective, AnalyticRyGradient

struct ScalarAccessError <: Exception end
Base.showerror(io::IO, ::ScalarAccessError) = print(io, "DemoArray forbids scalar indexing")
struct HostConversionError <: Exception end
Base.showerror(io::IO, ::HostConversionError) = print(io, "DemoArray forbids implicit host conversion")

"""An array family whose numerical work must run in its own backend.

The original allocation owns a CPU Array. Views/reshapes retain that allocation;
only this package accesses the private parent. Scalar indexing and implicit
Array/collect materialization deliberately fail, so accidental CPU fallback is
observable even on a machine without an accelerator.
"""
struct DemoArray{T,N,P<:AbstractArray{T,N}} <: AbstractArray{T,N}
    buffer::P
end

_wrap(data::AbstractArray{T,N}) where {T,N} = DemoArray{T,N,typeof(data)}(data)
DemoArray(data::Array; copy::Bool=true) = _wrap(copy ? Base.copy(data) : data)
hostcopy(data::DemoArray) = copy(data.buffer)

Base.size(data::DemoArray) = size(data.buffer)
Base.axes(data::DemoArray) = axes(data.buffer)
Base.IndexStyle(::Type{<:DemoArray}) = IndexCartesian()
Base.getindex(::DemoArray, indices...) = throw(ScalarAccessError())
Base.setindex!(::DemoArray, value, indices...) = throw(ScalarAccessError())
Base.Array(::DemoArray) = throw(HostConversionError())
Base.Array{T}(::DemoArray) where T = throw(HostConversionError())
Base.Array{T,N}(::DemoArray) where {T,N} = throw(HostConversionError())
Base.convert(::Type{Array{T,N}}, ::DemoArray) where {T,N} = throw(HostConversionError())
Base.collect(::DemoArray) = throw(HostConversionError())

Base.copy(data::DemoArray) = _wrap(copy(data.buffer))
Base.mightalias(first::DemoArray, second::DemoArray) = Base.mightalias(first.buffer, second.buffer)
Base.similar(data::DemoArray, ::Type{T}, dims::Dims{N}) where {T,N} =
    _wrap(Array{T,N}(undef, dims))
Base.copyto!(destination::DemoArray, source::DemoArray) =
    (copyto!(destination.buffer, source.buffer); destination)
Base.copyto!(destination::DemoArray, source::Array) =
    (copyto!(destination.buffer, source); destination)
Base.reshape(data::DemoArray, dims::Int...) = _wrap(reshape(data.buffer, dims...))
Base.reshape(data::DemoArray, dims::Dims) = _wrap(reshape(data.buffer, dims))
Base.vec(data::DemoArray) = reshape(data, length(data))
Base.view(data::DemoArray, indices...) = _wrap(view(data.buffer, indices...))

# Array-family broadcast operations execute against this package's own parent,
# rather than relying on AbstractArray's scalar fallback.
struct DemoArrayStyle{N} <: Base.Broadcast.AbstractArrayStyle{N} end
Base.BroadcastStyle(::Type{<:DemoArray{T,N}}) where {T,N} = DemoArrayStyle{N}()
Base.BroadcastStyle(::DemoArrayStyle{N}, ::DemoArrayStyle{M}) where {N,M} =
    DemoArrayStyle{max(N,M)}()
Base.BroadcastStyle(::DemoArrayStyle{N}, ::Base.Broadcast.DefaultArrayStyle{M}) where {N,M} =
    DemoArrayStyle{max(N,M)}()
Base.BroadcastStyle(::Base.Broadcast.DefaultArrayStyle{M}, ::DemoArrayStyle{N}) where {N,M} =
    DemoArrayStyle{max(N,M)}()
_owned_argument(data::DemoArray) = data.buffer
_owned_argument(data) = data
_owned_argument(data::Base.Broadcast.Broadcasted) =
    Base.Broadcast.broadcasted(data.f, map(_owned_argument, data.args)...)
_owned_argument(data::Base.Broadcast.Extruded) =
    Base.Broadcast.Extruded(_owned_argument(data.x), data.keeps, data.defaults)
Base.copy(data::Base.Broadcast.Broadcasted{<:DemoArrayStyle}) =
    _wrap(copy(_owned_argument(data)))
function _copy_broadcast!(destination::DemoArray, source::Base.Broadcast.Broadcasted)
    copyto!(destination.buffer, _owned_argument(source))
    return destination
end
Base.copyto!(destination::DemoArray, source::Base.Broadcast.Broadcasted) =
    _copy_broadcast!(destination, source)
Base.copyto!(destination::DemoArray, source::Base.Broadcast.Broadcasted{Nothing}) =
    _copy_broadcast!(destination, source)
Base.copyto!(destination::DemoArray, source::Base.Broadcast.Broadcasted{<:Base.Broadcast.AbstractArrayStyle{0}}) =
    _copy_broadcast!(destination, source)

struct ArrayBackend <: MOSSQuantum.AbstractBackend end

const DemoStateVector = MOSSQuantum.StateVector{T,A} where {T<:Number,A<:DemoArray}
const DemoDensityMatrix = MOSSQuantum.DensityMatrix{T,A} where {T<:Number,A<:DemoArray}
const DemoBatchStateVector = MOSSQuantum.BatchStateVector{T,A} where {T<:Number,A<:DemoArray}
const DemoBatchDensityMatrix = MOSSQuantum.BatchDensityMatrix{T,A} where {T<:Number,A<:DemoArray}
const DemoState = Union{DemoStateVector,DemoDensityMatrix,DemoBatchStateVector,DemoBatchDensityMatrix}

MOSSQuantum.backend(::DemoStateVector) = ArrayBackend()
MOSSQuantum.backend(::DemoDensityMatrix) = ArrayBackend()
MOSSQuantum.backend(::DemoBatchStateVector) = ArrayBackend()
MOSSQuantum.backend(::DemoBatchDensityMatrix) = ArrayBackend()

struct DemoUnknown <: MOSSQuantum.AbstractInstruction end
MOSSQuantum.positions(::DemoUnknown) = (1,)

const DemoGate = Union{MOSSQuantum.XGate,MOSSQuantum.RyGate}
MOSSQuantum.supports(::ArrayBackend, ::DemoGate, ::DemoState; action::Symbol=:apply) = action === :apply
MOSSQuantum.supports(::ArrayBackend, operation::MOSSQuantum.QuantumMap, ::DemoState; action::Symbol=:apply) =
    action === :apply && MOSSQuantum.nqubits(operation) == 1
MOSSQuantum.supports(::ArrayBackend, ::MOSSQuantum.ZGate, ::DemoState; action::Symbol=:apply) = action === :expectation
MOSSQuantum.supports(::ArrayBackend, ::AbstractMatrix{<:Number}, ::DemoState; action::Symbol=:apply) = action === :apply
MOSSQuantum.supports(::ArrayBackend, ::typeof(MOSSQuantum.probabilities), ::DemoState; action::Symbol=:apply) = action === :probabilities

"""Lift a public one-qubit matrix; little-endian qubit 1 is the low bit."""
function _lift(matrix, position, n)
    dimension = 1 << n
    result = zeros(eltype(matrix), dimension, dimension)
    mask = 1 << (position - 1)
    for column in 0:(dimension - 1)
        source_bit = (column & mask) == 0 ? 0 : 1
        for destination_bit in 0:1
            row = destination_bit == 0 ? column & ~mask : column | mask
            result[row + 1, column + 1] = matrix[destination_bit + 1, source_bit + 1]
        end
    end
    return result
end

function _check_operation(backend, operation, state; action=:apply)
    MOSSQuantum.supports(backend, operation, state; action=action) ||
        throw(MOSSQuantum.UnsupportedOperation(backend, operation, state, action))
    MOSSQuantum.validate_positions(operation, MOSSQuantum.nqubits(state))
    return nothing
end

function MOSSQuantum.apply!(backend::ArrayBackend, operation::DemoGate, state::DemoState)
    _check_operation(backend, operation, state)
    matrix = _lift(MOSSQuantum.mat(operation), only(MOSSQuantum.positions(operation)), MOSSQuantum.nqubits(state))
    data = MOSSQuantum.storage(state).buffer
    if state isa DemoStateVector || state isa DemoBatchStateVector
        copyto!(data, matrix * data)
    elseif state isa DemoDensityMatrix
        copyto!(data, matrix * data * matrix')
    else
        for b in axes(data, 3)
            sample = view(data, :, :, b)
            copyto!(sample, matrix * sample * matrix')
        end
    end
    return state
end

function MOSSQuantum.apply!(backend::ArrayBackend, operation::MOSSQuantum.QuantumMap, state::DemoState)
    _check_operation(backend, operation, state)
    if state isa DemoStateVector
        return MOSSQuantum.apply!(backend, operation, MOSSQuantum.DensityMatrix(state))
    elseif state isa DemoBatchStateVector
        return MOSSQuantum.apply!(backend, operation, MOSSQuantum.BatchDensityMatrix(state))
    end
    data = MOSSQuantum.storage(state).buffer
    matrices = [_lift(matrix, only(MOSSQuantum.positions(operation)), MOSSQuantum.nqubits(state))
                for matrix in MOSSQuantum.kraus_matrices(operation)]
    if state isa DemoDensityMatrix
        result = sum(matrix * data * matrix' for matrix in matrices)
        copyto!(data, result)
    else
        for b in axes(data, 3)
            sample = view(data, :, :, b)
            result = sum(matrix * sample * matrix' for matrix in matrices)
            copyto!(sample, result)
        end
    end
    return state
end

function MOSSQuantum.expectation(backend::ArrayBackend, observable::MOSSQuantum.ZGate, state::DemoState)
    _check_operation(backend, observable, state; action=:expectation)
    matrix = _lift(MOSSQuantum.mat(observable), only(MOSSQuantum.positions(observable)), MOSSQuantum.nqubits(state))
    data = MOSSQuantum.storage(state).buffer
    if state isa DemoStateVector
        return dot(data, matrix * data)
    elseif state isa DemoDensityMatrix
        return tr(matrix * data)
    elseif state isa DemoBatchStateVector
        return [dot(view(data, :, b), matrix * view(data, :, b)) for b in axes(data, 2)]
    end
    return [tr(matrix * view(data, :, :, b)) for b in axes(data, 3)]
end

function _same_container(state::DemoState, data::Array)
    constructor = state isa DemoStateVector ? MOSSQuantum.StateVector :
        state isa DemoDensityMatrix ? MOSSQuantum.DensityMatrix :
        state isa DemoBatchStateVector ? MOSSQuantum.BatchStateVector : MOSSQuantum.BatchDensityMatrix
    return constructor(DemoArray(data; copy=false); preserve_storage=true)
end

"""An out-of-place observable action; mixed states receive left multiplication."""
function MOSSQuantum.apply(backend::ArrayBackend, observable::AbstractMatrix{<:Number}, state::DemoState)
    MOSSQuantum.supports(backend, observable, state) ||
        throw(MOSSQuantum.UnsupportedOperation(backend, observable, state, :apply))
    dimension = 1 << MOSSQuantum.nqubits(state)
    size(observable) == (dimension, dimension) || throw(DimensionMismatch("observable register mismatch"))
    data = MOSSQuantum.storage(state).buffer
    if !(state isa DemoBatchDensityMatrix)
        return _same_container(state, observable * data)
    end
    result = Array{promote_type(eltype(observable),eltype(state)),3}(undef, size(data))
    for b in axes(data, 3)
        result[:, :, b] = observable * view(data, :, :, b)
    end
    return _same_container(state, result)
end

"""Compute readout values inside this backend, returning ordinary host metadata."""
function MOSSQuantum.probabilities(::ArrayBackend, state::DemoState; qubits=1:MOSSQuantum.nqubits(state))
    indices = Int[qubits...]
    length(unique(indices)) == length(indices) || throw(ArgumentError("readout qubits must be distinct"))
    all(q -> 1 <= q <= MOSSQuantum.nqubits(state), indices) || throw(ArgumentError("readout qubit out of range"))
    data = MOSSQuantum.storage(state).buffer
    isbatch = state isa Union{DemoBatchStateVector,DemoBatchDensityMatrix}
    count = isbatch ? MOSSQuantum.batch_size(state) : 1
    dimension = 1 << MOSSQuantum.nqubits(state)
    result = zeros(Float64, 1 << length(indices), count)
    real_type = typeof(float(real(zero(eltype(state)))))
    tolerance = max(sqrt(eps(Float64)), sqrt(Float64(eps(real_type))))
    for b in 1:count
        weights = if state isa DemoStateVector
            abs2.(data)
        elseif state isa DemoDensityMatrix
            diag(data)
        elseif state isa DemoBatchStateVector
            abs2.(view(data, :, b))
        else
            diag(view(data, :, :, b))
        end
        all(value -> isfinite(value) && abs(imag(value)) <= tolerance && real(value) >= -tolerance, weights) ||
            throw(ArgumentError("invalid readout probabilities"))
        total = sum(real, weights)
        isapprox(total, 1; atol=tolerance, rtol=tolerance) || throw(ArgumentError("readout needs a normalized state"))
        for basis in 0:(dimension - 1)
            outcome = 0
            for (bit, qubit) in enumerate(indices)
                outcome |= ((basis >> (qubit - 1)) & 1) << (bit - 1)
            end
            result[outcome + 1, b] += max(real(weights[basis + 1]), 0) / total
        end
    end
    return isbatch ? result : vec(result)
end

"""A fixed demo objective cos(theta), backed by the external array executor."""
struct DemoRyObjective{O}
    objective::O
end
function DemoRyObjective()
    initial = MOSSQuantum.StateVector(DemoArray(ComplexF64[1, 0]); preserve_storage=true)
    circuit = MOSSQuantum.QCircuit([MOSSQuantum.RyGate(1, 0.0; isparas=true)])
    return DemoRyObjective(MOSSQuantum.ExpectationObjective(circuit, MOSSQuantum.ZGate(1), initial))
end
MOSSQuantum.evaluate(objective::DemoRyObjective, values::AbstractVector{<:Real}) =
    MOSSQuantum.evaluate(objective.objective, values)
struct AnalyticRyGradient <: MOSSQuantum.AbstractGradientMethod end
MOSSQuantum.supports_gradient(::AnalyticRyGradient, ::DemoRyObjective) = true
function MOSSQuantum.value_and_gradient(::AnalyticRyGradient, objective::DemoRyObjective,
                                 values::AbstractVector{<:Real})
    value = MOSSQuantum.evaluate(objective, values)
    return value, [-sin(only(values))]
end

end
