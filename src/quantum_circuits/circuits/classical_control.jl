_classical_key(key::Union{Symbol,AbstractString}) =
    isempty(string(key)) ? throw(ArgumentError("classical keys must not be empty")) : Symbol(key)

"""Per-execution classical bits, with separate reported and physical values."""
struct ClassicalRegister
    values::Dict{Symbol,Int}
    physical::Dict{Symbol,Int}
end
function ClassicalRegister(values::AbstractDict=Dict{Symbol,Int}())
    bits = Dict{Symbol,Int}()
    for (key,value) in values
        value isa Integer && value in (0,1) || throw(ArgumentError("classical values must be bits"))
        bits[_classical_key(key)] = Int(value)
    end
    return ClassicalRegister(bits,copy(bits))
end
Base.copy(r::ClassicalRegister) = ClassicalRegister(copy(r.values),copy(r.physical))
Base.getindex(r::ClassicalRegister,key::Union{Symbol,AbstractString}) = r.values[_classical_key(key)]
Base.haskey(r::ClassicalRegister,key::Union{Symbol,AbstractString}) = haskey(r.values,_classical_key(key))
Base.length(r::ClassicalRegister) = length(r.values)
Base.isempty(r::ClassicalRegister) = isempty(r.values)
Base.:(==)(a::ClassicalRegister,b::ClassicalRegister) = a.values == b.values && a.physical == b.physical
function Base.setindex!(r::ClassicalRegister,value::Integer,key::Union{Symbol,AbstractString})
    value in (0,1) || throw(ArgumentError("classical values must be bits"))
    key = _classical_key(key)
    r.values[key] = r.physical[key] = Int(value)
    return value
end

"""
    ClassicalCondition(keys, value=1; source=:reported)

Compare the latest classical bits with an integer. The first key is the least
significant bit. Feedback defaults to instrument reports; `source=:physical`
is available for ideal diagnostic control.
"""
struct ClassicalCondition
    keys::Tuple{Vararg{Symbol}}
    value::Int
    source::Symbol
    function ClassicalCondition(keys, value::Integer=1; source::Symbol=:reported)
        ks = keys isa Union{Symbol,AbstractString} ? (_classical_key(keys),) : Tuple(_classical_key(k) for k in keys)
        1 <= length(ks) <= 8sizeof(Int)-2 && allunique(ks) || throw(ArgumentError("condition keys must be nonempty and distinct"))
        0 <= value < (1 << length(ks)) || throw(ArgumentError("condition value does not fit its keys"))
        source in (:reported,:physical) || throw(ArgumentError("source must be :reported or :physical"))
        new(ks,Int(value),source)
    end
end
function (condition::ClassicalCondition)(register::ClassicalRegister)
    bits = condition.source === :reported ? register.values : register.physical
    all(k -> haskey(bits,k),condition.keys) || throw(ArgumentError("condition reads an undefined classical key"))
    return sum(bits[k] << (i-1) for (i,k) in enumerate(condition.keys)) == condition.value
end

"""Execute one branch according to classical bits. Branches are independent snapshots."""
struct Conditional <: AbstractInstruction
    condition::ClassicalCondition
    then_branch::QCircuit
    else_branch::QCircuit
    function Conditional(condition::ClassicalCondition, instruction::AbstractInstruction;
                         otherwise::AbstractInstruction=QCircuit())
        yes = instruction isa QCircuit ? instruction : QCircuit([instruction])
        no = otherwise isa QCircuit ? otherwise : QCircuit([otherwise])
        new(condition,copy_instruction(yes),copy_instruction(no))
    end
end
Conditional(key::Union{Symbol,AbstractString}, instruction::AbstractInstruction; value::Integer=1,
            source::Symbol=:reported, otherwise::AbstractInstruction=QCircuit()) =
    Conditional(ClassicalCondition(key,value;source=source),instruction;otherwise=otherwise)
positions(x::Conditional) = sort!(union(positions(x.then_branch),positions(x.else_branch)))
nparameters(x::Conditional) = nparameters(x.then_branch)+nparameters(x.else_branch)
parameters(x::Conditional) = vcat(parameters(x.then_branch),parameters(x.else_branch))
active_parameters(x::Conditional) = vcat(active_parameters(x.then_branch),active_parameters(x.else_branch))
function reset_parameters!(x::Conditional, values::AbstractVector{<:Real})
    _check_parameter_values(x,values)
    n = nparameters(x.then_branch)
    reset_parameters!(x.then_branch,view(values,1:n))
    reset_parameters!(x.else_branch,view(values,n+1:length(values)))
    return x
end
activate_parameters!(x::Conditional) = (activate_parameters!(x.then_branch);activate_parameters!(x.else_branch);x)
deactivate_parameters!(x::Conditional) = (deactivate_parameters!(x.then_branch);deactivate_parameters!(x.else_branch);x)
copy_instruction(x::Conditional) = Conditional(x.condition,x.then_branch;otherwise=x.else_branch)
change_positions(x::Conditional,m::AbstractDict) = Conditional(x.condition,change_positions(x.then_branch,m);
    otherwise=change_positions(x.else_branch,m))
shift(x::Conditional,j::Int) = _shift_gate_util!(x,j,Dict{Int,Int}())
