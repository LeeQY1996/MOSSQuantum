# Run from any directory in an environment containing this checkout:
# julia --project=/path/to/environment docs/generate_api_reference.jl
using MOSSQuantum, REPL, Markdown
const ROOT = dirname(@__DIR__)
const OUT = joinpath(@__DIR__, "api", "reference.md")

function declared_exports(path)
    result = Symbol[]
    for line in eachline(path)
        startswith(strip(line), "export ") || continue
        append!(result, Symbol.(strip.(split(strip(line)[8:end], ','))))
    end
    return unique(result)
end

const GROUPS = [
    (MOSSQuantum, declared_exports(joinpath(ROOT, "src", "api", "exports.jl"))),
    (MOSSQuantum.Utilities, declared_exports(joinpath(ROOT, "src", "utilities", "Utilities.jl"))),
    (MOSSQuantum.Optimization, [:minimize, :OptimizationResult, :OptimizationStep]),
]

function own_methods(value)
    (value isa Function || value isa Type) || return Method[]
    return filter(collect(methods(value))) do method
        file = String(method.file)
        startswith(file, ROOT * "/") || (!isabspath(file) && isfile(joinpath(ROOT, file)))
    end
end

function source_link(method)
    file = String(method.file)
    path = isabspath(file) ? relpath(file, ROOT) : file
    return "[" * path * ":" * string(method.line) * "](https://github.com/LeeQY1996/MOSSQuantum/blob/main/" * path * "#L" * string(method.line) * ")"
end

mkpath(dirname(OUT))
open(OUT, "w") do io
    println(io, "# 完整公开 API 参考\n")
    println(io, "[API 目录](../api.md) · [状态](states.md) · [门与算符](gates.md) · [参数](parameters.md) · [执行](execution.md) · [梯度](differentiation.md) · [实用工具](utilities.md)\n")
    println(io, "本页由 `docs/generate_api_reference.jl` 根据源码导出清单和实际加载的方法生成。每项列出此包定义的方法签名；`where`、参数类型及关键字名按当前实现保留。关键字的默认值、参数/返回值说明和使用示例见对应主题页与原生帮助。只记录当前包的方法，不将 Julia 标准库的全部重载混入索引。\n")
    for (mod, exports) in GROUPS
        println(io, "## ", mod, "\n")
        println(io, join(["[`$name`](#api-$(replace(string(mod),'.'=>'-'))-$name)" for name in exports], " · "), "\n")
        for name in exports
            isdefined(mod, name) || error("Exported symbol is undefined: $mod.$name")
            value = getfield(mod, name)
            anchor = "api-$(replace(string(mod),'.'=>'-'))-$name"
            println(io, "<a id=\"", anchor, "\"></a>\n")
            println(io, "### `", mod, ".", name, "`\n")
            println(io, "参数、返回值和使用限制请按 [API 主题目录](../api.md) 查阅；以下签名直接取自当前实现。\n")
            if value isa AbstractArray
                println(io, "矩阵常量；元素类型 `", eltype(value), "`，形状 `", size(value), "`。用于局部门矩阵；放入电路时使用相应 `...Gate` 构造。\n")
            elseif value isa Type && isabstracttype(value)
                println(io, "公开抽象协议；具体实现和适用条件见主题页及下方原生帮助。\n")
            end
            ms = own_methods(value)
            if !isempty(ms)
                println(io, "```julia")
                for method in ms
                    rendered = first(split(sprint(show, method), " @ "))
                    rendered = replace(rendered, ROOT * "/" => "")
                    println(io, rendered)
                end
                println(io, "```\n")
                println(io, "源码：", join(unique(source_link.(ms)), " · "), "\n")
            end
            documentation = Base.Docs.doc(Base.Docs.Binding(mod, name))
            help = isnothing(documentation) ? "" : sprint(show, MIME"text/markdown"(), documentation)
            if !isempty(help) && !occursin("No documentation found.", help) && !(name in (:positions, :ordered_positions, :TOFFOLIGate, :QMeasure, :QSelect, :trotter_propagator))
                help = replace(help, r"\[(`[^`]+`)\]\(@ref[^)]*\)" => s"\1")
                # Old circuit help contains an obsolete vector-measurement example.
                help = replace(help, "QMeasure([1, 2])" => "QMeasure(1)")
                lines = split(help, '\n')
                in_fence = false
                for i in eachindex(lines)
                    startswith(lines[i], "```") && (in_fence = !in_fence)
                    if !in_fence && occursin(r"^#{1,3} ", lines[i])
                        lines[i] = "###" * lines[i]
                    end
                end
                println(io, "原生帮助：\n\n", join(lines, "\n"), "\n")
            elseif value isa DataType && isstructtype(value) && !isempty(fieldnames(value))
                println(io, "字段：", join(["`$field::$(fieldtype(value,field))`" for field in fieldnames(value)], "；"), "。结果和计划应通过对应公共函数创建；把配置字段视为只读。\n")
            end
        end
    end
end
println("Generated ", OUT, " with ", sum(length(group[2]) for group in GROUPS), " exported entries.")
