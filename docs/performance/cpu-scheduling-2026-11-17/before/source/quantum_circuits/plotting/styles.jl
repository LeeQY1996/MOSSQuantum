# 样式和颜色管理
# 管理门样式、颜色和绘图外观

# Constants (DEFAULT_COLOR, DEFAULT_LINEWIDTH, DEFAULT_WBOX) defined in drawing.jl

# 门类型到颜色的默认映射
const DEFAULT_GATE_COLORS = Dict{Type, String}(
    # 单量子位门
    XGate => "#ff6f6f",      # 红色
    YGate => "#6fff6f",      # 绿色
    ZGate => "#6f6fff",      # 蓝色
    HGate => "#ffb86f",      # 橙色
    SGate => "#b86fff",      # 紫色
    TGate => "#6fd8ff",      # 浅蓝

    # 参数门
    RxGate => "#ff8f6f",     # 橙红色
    RyGate => "#6fff8f",     # 浅绿色
    RzGate => "#8f6fff",     # 紫蓝色

    # 双量子位门
    CNOTGate => "#ff6fd8",   # 粉红色
    CZGate => "#d86fff",     # 紫色
    SWAPGate => "#6fd8d8",   # 青色

    # 默认回退颜色
    Gate => DEFAULT_COLOR,
)

# 门类型到标签的默认映射
const DEFAULT_GATE_LABELS = Dict{Type, Union{String,LaTeXString}}(
    XGate => "X",
    YGate => "Y",
    ZGate => "Z",
    HGate => "H",
    SGate => "S",
    TGate => "T",
    sqrtXGate => L"\sqrt{X}",
    sqrtYGate => L"\sqrt{Y}",
    RxGate => L"R_x(\theta)",
    RyGate => L"R_y(\theta)",
    RzGate => L"R_z(\theta)",
    CNOTGate => "",  # CNOT使用特殊符号，不需要标签
    CZGate => "Z",
    SWAPGate => "",  # SWAP使用交叉符号
)

# 全局样式配置
mutable struct PlottingStyle
    default_color::String
    linewidth::Real
    wbox::Real
    gate_colors::Dict{Type, String}
    gate_labels::Dict{Type, Union{String,LaTeXString}}
    show_grid::Bool
    show_axis::Bool
    dpi::Int
    title::String

    function PlottingStyle(;
        default_color::String=DEFAULT_COLOR,
        linewidth::Real=DEFAULT_LINEWIDTH,
        wbox::Real=DEFAULT_WBOX,
        gate_colors::Dict{Type, String}=DEFAULT_GATE_COLORS,
        gate_labels::Dict{Type, Union{String,LaTeXString}}=DEFAULT_GATE_LABELS,
        show_grid::Bool=false,
        show_axis::Bool=false,
        dpi::Int=300,
        title::String=""
    )
        new(default_color, linewidth, wbox, gate_colors, gate_labels,
            show_grid, show_axis, dpi, title)
    end
end

# 全局样式实例
const GLOBAL_STYLE = Ref{PlottingStyle}(PlottingStyle())

"""
    set_default_color(color::String)

设置默认门颜色。

# 参数
- `color::String`: CSS颜色字符串（如"#6fa5ff"）

# 示例
```julia
set_default_color("#ff6f6f")  # 设置为红色
```
"""
function set_default_color(color::String)
    GLOBAL_STYLE[].default_color = color
end

"""
    get_default_color() -> String

获取当前默认门颜色。
"""
function get_default_color()::String
    return GLOBAL_STYLE[].default_color
end

"""
    set_gate_color(gate_type::Type, color::String)

设置特定门类型的颜色。

# 参数
- `gate_type::Type`: 门类型（如`XGate`）
- `color::String`: CSS颜色字符串

# 示例
```julia
set_gate_color(XGate, "#ff0000")  # 设置X门为红色
```
"""
function set_gate_color(gate_type::Type, color::String)
    GLOBAL_STYLE[].gate_colors[gate_type] = color
end

"""
    get_gate_color(gate_type::Type) -> String

获取特定门类型的颜色。如果未设置，返回默认颜色。
"""
function get_gate_color(gate_type::Type)::String
    colors = GLOBAL_STYLE[].gate_colors
    if haskey(colors, gate_type)
        return colors[gate_type]
    else
        # 查找父类型
        for (gt, color) in colors
            if gate_type <: gt
                return color
            end
        end
        return GLOBAL_STYLE[].default_color
    end
end

"""
    set_gate_label(gate_type::Type, label::Union{String,LaTeXString})

设置特定门类型的标签。

# 参数
- `gate_type::Type`: 门类型
- `label`: 标签文本，可以是字符串或LaTeXString

# 示例
```julia
set_gate_label(XGate, L"X")  # 设置X门标签
set_gate_label(RxGate, L"R_x")  # 设置Rx门标签
```
"""
function set_gate_label(gate_type::Type, label::Union{String,LaTeXString})
    GLOBAL_STYLE[].gate_labels[gate_type] = label
end

"""
    get_gate_label(gate_type::Type) -> Union{String,LaTeXString}

获取特定门类型的标签。如果未设置，返回类型名称。
"""
function get_gate_label(gate_type::Type)::Union{String,LaTeXString}
    labels = GLOBAL_STYLE[].gate_labels
    if haskey(labels, gate_type)
        return labels[gate_type]
    else
        # 查找父类型
        for (gt, label) in labels
            if gate_type <: gt
                return label
            end
        end
        return string(gate_type.name.name)
    end
end

"""
    set_linewidth(width::Real)

设置线条宽度。

# 参数
- `width::Real`: 线条宽度（像素）
"""
function set_linewidth(width::Real)
    GLOBAL_STYLE[].linewidth = width
end

"""
    get_linewidth() -> Real

获取当前线条宽度。
"""
function get_linewidth()::Real
    return GLOBAL_STYLE[].linewidth
end

"""
    set_wbox(width::Real)

设置门方框宽度。

# 参数
- `width::Real`: 门方框宽度
"""
function set_wbox(width::Real)
    GLOBAL_STYLE[].wbox = width
end

"""
    get_wbox() -> Real

获取当前门方框宽度。
"""
function get_wbox()::Real
    return GLOBAL_STYLE[].wbox
end

"""
    available_gate_styles() -> Dict{Type, Dict}

获取所有可用的门样式。
"""
function available_gate_styles()::Dict{Type, Dict}
    styles = Dict{Type, Dict}()
    for (gate_type, color) in GLOBAL_STYLE[].gate_colors
        label = get_gate_label(gate_type)
        styles[gate_type] = Dict(:color => color, :label => label)
    end
    return styles
end

"""
    register_gate_style(gate_type::Type; color::Union{String,Nothing}=nothing,
                        label::Union{String,LaTeXString,Nothing}=nothing)

注册或更新门样式。

# 参数
- `gate_type::Type`: 门类型
- `color`: 可选，门颜色
- `label`: 可选，门标签

# 示例
```julia
register_gate_style(XGate; color="#ff0000", label="X")
```
"""
function register_gate_style(gate_type::Type;
                            color::Union{String,Nothing}=nothing,
                            label::Union{String,LaTeXString,Nothing}=nothing)
    if !isnothing(color)
        set_gate_color(gate_type, color)
    end
    if !isnothing(label)
        set_gate_label(gate_type, label)
    end
end