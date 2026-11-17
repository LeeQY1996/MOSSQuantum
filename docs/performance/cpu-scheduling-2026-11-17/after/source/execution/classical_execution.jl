_has_classical(::AbstractInstruction) = false
_has_classical(x::QMeasure) = !isnothing(x.key)
_has_classical(::Conditional) = true
_has_classical(x::QCircuit) = any(_has_classical,x)

function _initial_classical(value)
    register = isnothing(value) ? ClassicalRegister() : value isa ClassicalRegister ? copy(value) : ClassicalRegister(value)
    keys(register.values) == keys(register.physical) || throw(ArgumentError("classical reported/physical keys must agree"))
    for data in (register.values,register.physical)
        all(v -> v in (0,1),values(data)) || throw(ArgumentError("classical registers contain bits only"))
        all(k -> !isempty(string(k)),keys(data)) || throw(ArgumentError("classical keys cannot be empty"))
    end
    return register
end

function _classical_flow(circuit::QCircuit,available::Set{Symbol})
    available = copy(available)
    for instruction in circuit
        if instruction isa QCircuit
            available = _classical_flow(instruction,available)
        elseif instruction isa QMeasure && !isnothing(instruction.key)
            push!(available,instruction.key)
        elseif instruction isa Conditional
            all(k -> k in available,instruction.condition.keys) ||
                throw(ArgumentError("condition reads a key not defined on every preceding path"))
            yes = _classical_flow(instruction.then_branch,available)
            no = _classical_flow(instruction.else_branch,available)
            available = intersect(yes,no)
        end
    end
    return available
end
_validate_classical_flow(circuit,register) = (_classical_flow(circuit,Set(keys(register.values))); nothing)

function _write_classical!(register,instruction::QMeasure,actual,reported)
    isnothing(instruction.key) && return
    register.values[instruction.key] = reported
    register.physical[instruction.key] = actual
    return nothing
end

"""Reconstruct latest named bits from records, optionally starting with an initial register."""
function classical_register(records::AbstractVector{MeasurementRecord}; initial=nothing)
    register = _initial_classical(initial)
    for record in records
        isnothing(record.key) && continue
        register.values[record.key] = record.reported_outcome
        register.physical[record.key] = record.outcome
    end
    return register
end
classical_register(result::SimulationResult) = copy(result.classical)
classical_register(result::Union{ShotResult,BatchSimulationResult}) = copy.(result.classical)

"""Histogram of final classical bits (all attempts by default, including rejected shots)."""
function classical_counts(result::ShotResult, keys; source::Symbol=:reported, accepted_only::Bool=false)
    condition = ClassicalCondition(keys,0;source=source)
    histogram = Dict{String,Int}()
    for (i,register) in enumerate(result.classical)
        accepted_only && !result.accepted[i] && continue
        bits = source === :reported ? register.values : register.physical
        all(k -> haskey(bits,k),condition.keys) || throw(ArgumentError("requested key is absent in an execution"))
        key = join(bits[k] for k in condition.keys)
        histogram[key] = get(histogram,key,0)+1
    end
    return histogram
end

_has_channel(::AbstractInstruction) = false
_has_channel(::QuantumMap) = true
_has_channel(c::QCircuit) = any(_has_channel,c)
_has_channel(c::Conditional) = _has_channel(c.then_branch) || _has_channel(c.else_branch)
function _empty_dynamic_batch(circuit,state,method)
    method isa DensityMatrixEvolution && state isa BatchStateVector && _has_channel(circuit) &&
        return BatchDensityMatrix(state)
    return copy(state)
end
