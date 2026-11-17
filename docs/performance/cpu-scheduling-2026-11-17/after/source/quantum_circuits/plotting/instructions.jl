# Rendering for non-gate circuit instructions. A QuantumMap stores Kraus
# matrices, not the constructor or parameters that produced it, so it must
# not be labelled as a particular noise model.
function _draw_instruction_block!(plt, step, rows, label; color=DEFAULT_COLOR, numbered=true)
    rs = rows isa Integer ? (rows,) : rows
    isempty(rs) && throw(ArgumentError("cannot draw an instruction without quantum positions"))
    length(rs) > 1 && draw_vertical_line!(plt, step, minimum(rs), maximum(rs); color=color)
    for (i, row) in enumerate(rs)
        draw_box!(plt, step - DEFAULT_WBOX/2, row - DEFAULT_WBOX/2,
                  DEFAULT_WBOX, DEFAULT_WBOX; color=color)
        draw_text!(plt, step, row, length(rs) == 1 || !numbered ? label : "$(label)$(i-1)"; fontsize=7)
    end
end

function draw_gate!(plt::Plots.Plot, map::AbstractQuantumMap, step::Int, rows::Union{Int,Tuple};
                    color=DEFAULT_COLOR)
    _draw_instruction_block!(plt, step, rows, "Kraus"; color=color)
end

function draw_gate!(plt::Plots.Plot, delay::Delay, step::Int, row::Int; color=DEFAULT_COLOR)
    _draw_instruction_block!(plt, step, row, "Delay\n$(delay.duration)"; color=color)
end

function draw_gate!(plt::Plots.Plot, condition::Conditional, step::Int, rows::Union{Int,Tuple};
                    color=DEFAULT_COLOR)
    _draw_instruction_block!(plt, step, rows, "IF$(step)"; color=color, numbered=false)
end

function _parameterized_instruction_label(instruction::ParameterizedInstruction; show_parameters=true)
    prototype = instruction.prototype
    name = prototype isa AdjointQuantumGate ?
        string(nameof(typeof(prototype.parent)), "†") : string(nameof(typeof(prototype)))
    show_parameters || return name
    return name * "(" * join(string.(instruction.expressions), ", ") * ")"
end

function draw_gate!(plt::Plots.Plot, instruction::ParameterizedInstruction, step::Int,
                    rows::Union{Int,Tuple}; color=DEFAULT_COLOR, show_parameters=true)
    label = _parameterized_instruction_label(instruction; show_parameters)
    _draw_instruction_block!(plt, step, rows, label; color)
end

function draw_circuit_gate!(plt::Plots.Plot, instruction::ParameterizedInstruction, step::Int,
                            rows; color=DEFAULT_COLOR, show_parameters=true)
    return draw_gate!(plt, instruction, step, rows; color, show_parameters)
end

# The following summaries are a textual legend for compact conditional blocks.
# The ordered positions and branch sequence make the block inspectable even for
# nested conditions and nonadjacent wires.
function _instruction_summary(x::QMeasure; show_parameters=true)
    key = isnothing(x.key) ? "unnamed" : "key=$(repr(x.key))"
    return "measure q$(x.position) ($key, auto_reset=$(x.auto_reset), keep=$(x.keep))"
end
_instruction_summary(x::QSelect; show_parameters=true) = "select q$(x.position)=$(x.state)"
_instruction_summary(x::Delay; show_parameters=true) = "Delay q$(x.position) duration=$(x.duration)"
_instruction_summary(x::AbstractQuantumMap; show_parameters=true) = "Kraus q$(Tuple(positions(x)))"
_instruction_summary(x::ParameterizedInstruction; show_parameters=true) =
    _parameterized_instruction_label(x; show_parameters) * " q$(Tuple(positions(x)))"
function _instruction_summary(x::Conditional; show_parameters=true)
    c = x.condition
    yes = _branch_summary(x.then_branch; show_parameters=show_parameters)
    no = _branch_summary(x.else_branch; show_parameters=show_parameters)
    return "if $(c.keys)=$(c.value) [$(c.source), first key is least significant] { $yes } else { $no }"
end
function _instruction_summary(x::QCircuit; show_parameters=true)
    return _branch_summary(x; show_parameters=show_parameters)
end
function _instruction_summary(x::AbstractInstruction; show_parameters=true)
    name = string(nameof(typeof(x)))
    qs = Tuple(positions(x))
    values = show_parameters ? parameters(x) : nothing
    suffix = isnothing(values) || isempty(values) ? "" : " params=$(Tuple(values))"
    return "$name q$qs$suffix"
end
function _branch_summary(circuit::QCircuit; show_parameters=true)
    isempty(circuit) && return "identity"
    return join((_instruction_summary(x; show_parameters=show_parameters) for x in circuit), "; ")
end

# Split long labels without dropping any content. Lines are outside the circuit,
# so the IF block itself remains clear and the branch alternatives are not
# mistaken for operations that both run.
function _wrap_instruction_note(note::String, width::Int=72)
    words = split(note, ' '; keepempty=false)
    lines = String[]
    line = ""
    for word in words
        candidate = isempty(line) ? word : "$line $word"
        if !isempty(line) && length(candidate) > width
            push!(lines, line)
            line = word
        else
            line = candidate
        end
    end
    isempty(line) || push!(lines, line)
    return lines
end

function _draw_instruction_notes!(plt, gate_positions, nqubits; size=nothing, show_parameters=true)
    notes = String[]
    for ((step, _), (instruction, _)) in sort!(collect(gate_positions); by=first)
        if instruction isa Conditional
            push!(notes, "IF$(step): " * _instruction_summary(instruction; show_parameters=show_parameters))
        elseif instruction isa QMeasure
            push!(notes, "M$(step): " * _instruction_summary(instruction; show_parameters=show_parameters))
        end
    end
    isempty(notes) && return plt
    lines = reduce(vcat, (_wrap_instruction_note(note) for note in notes); init=String[])
    for (i, line) in enumerate(lines)
        draw_text!(plt, 0, nqubits + 0.6 + (i-1)*0.35, line; halign=:left, fontsize=7)
    end
    Plots.plot!(plt; ylim=(0.5, nqubits + 0.9 + length(lines)*0.35))
    if isnothing(size)
        oldsize = plt.attr[:size]
        Plots.plot!(plt; size=(max(oldsize[1], 800), oldsize[2] + 24length(lines)))
    end
    return plt
end

# Readout errors are classical transformations, not quantum Kraus instructions.
# Show their complete scope, ordered qubits and confusion matrices in the title
# of the expanded circuit rather than silently dropping them.
function plot(program::NoisyCircuit; title::String="", kwargs...)
    lines = ["Readout $(e.scope), qubits=$(Tuple(e.qubits)), P=$(repr(e.probabilities))" for e in program.readout]
    fulltitle = join(filter(!isempty, vcat([title], lines)), "\n")
    return plot(program.circuit; title=fulltitle, kwargs...)
end
