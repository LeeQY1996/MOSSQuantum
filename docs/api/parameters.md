# 数值参数、共享映射与符号参数

[API 目录](../api.md) · [逐项参考](reference.md)

## 数值参数与复制

| 接口 | 输入、返回值与副作用 |
| --- | --- |
| `parameters(instruction)` | 全部数值参数，包含非活动参数；没有参数的叶指令可能返回 `nothing` |
| `active_parameters(instruction)` | 仅活动参数，按电路遍历顺序展平；非参数指令可能返回 `nothing` |
| `nparameters(instruction)` | 活动参数数目；不同于全部物理参数个数 |
| `activate_parameter!(instruction,j)` / `deactivate_parameter!(instruction,j)` | 激活/停用单个槽；**对电路，`j` 选择的是第 `j` 条指令** |
| `activate_parameters!(instruction)` / `deactivate_parameters!(instruction)` | 激活/停用所有可切换参数 |
| `reset_parameters!(instruction,values)` | 按活动顺序写回；长度必须匹配。可能返回替换指令，调用方应保存返回值 |
| `copy_instruction(instruction)` | 独立复制指令树与可变参数；不可变对象允许仍为同一身份 |
| `bind_parameters(template,values[,map])` | 复制后绑定，返回独立指令/电路，不修改模板和输入向量 |

数值门如 `RyGate(1,0.0)` 默认不活动；创建训练模板时显式用 `isparas=true`。同一可变门重复放入电路会存在别名；原地重置保留历史别名语义，独立绑定则逐次复制指令出现位置。

## 独立输入到活动槽的映射

```julia
ParameterMap(indices)
ParameterMap(template)
ParameterMap(template, indices)
expand_parameters(map, values)
accumulate_parameter_gradients(map, slot_gradients)
```

`AbstractParameterMap` 是映射协议。`ParameterMap([1,2,1])` 表示三个槽共享两个独立值，索引必须覆盖连续 `1:k`。`length(map)` 是活动槽数，`nparameters(map)` 是独立输入数；`parameter_indices(map)` 返回独立索引副本。

`expand_parameters` 返回活动槽值；`accumulate_parameter_gradients` 将槽梯度求和到独立输入顺序，返回长度 `nparameters(map)` 的向量，两者均不修改输入。仿射符号映射还应用系数和偏移，以及梯度链式规则。

```julia
using MOSSQuantum
c = QCircuit([RyGate(1, 0.0; isparas=true), RzGate(1, 0.0; isparas=true)])
m = ParameterMap([1, 1])
bound = bind_parameters(c, [0.2], m)
@assert active_parameters(bound) == [0.2, 0.2]
@assert accumulate_parameter_gradients(m, [2.0, 3.0]) == [5.0]
```

整数映射只检查槽数量，不能发现相同槽数的指令重排；改变结构/活动标记后应重建映射。

## 符号与编译上下文

```julia
θ = Parameter(:θ)
expr = 2θ + 0.1
c = QCircuit([RyGate(1; θ=expr), RzGate(1; θ=θ)])
context = compile_parameters(c)
values = initial_parameters(context; values=Dict(θ => 0.2))
bound = bind_parameters(context, values)
```

`Parameter` 使用独立身份；同名并不自动成为同一变量，复用同一对象才共享。`ParameterExpr` 表示实系数仿射表达式，支持加减、常量乘法，不是通用非线性符号系统。未完成数值绑定就执行/求矩阵会抛出 `UnboundParameterError`。

| 接口 | 参数与返回值 |
| --- | --- |
| `parameterize(prototype, expressions)` | 以现有活动槽为模板，返回符号指令；表达式数量须与槽数匹配 |
| `parameter_slots(instruction)` | 稳定局部槽键的 `Tuple`，供自定义门和编译使用 |
| `parameter_expressions(instruction)` | 指令树内的参数表达式 |
| `independent_parameters(instruction_or_map)` | 注册的独立参数；编译映射保留已经固定的变量 |
| `trainable_parameters(context_or_map)` | 当前未固定的训练参数 |
| `parameter_order(context_or_map)` | 数值向量绑定的输入顺序；整数映射返回输入 ID，符号映射返回 `Parameter` |
| `substitute_parameters(instruction,replacements)` | 替换符号并返回独立指令；未替换符号保留 |
| `compile_parameters(template_or_context; parameter_order=nothing,fixed=nothing,parameter_map=nothing)` | 返回 `(;template,parameter_map)` 快照；固定值通过参数句柄字典给出 |
| `materialize_parameters(prototype,values,active_mask)` | 扩展钩子：将完整活动槽值与布尔标记变成数值门，返回门对象 |
| `parameter_info(compiled_or_map)` | 独立描述元组，记录 `parameter`、`kind`、`label`、`initial`、`sources`、`fixed`、`input_index` |
| `initial_parameters(compiled_or_map; values=Dict())` | 显式值覆盖已捕获初值，按当前训练输入顺序返回数值向量；缺失/歧义初值报错 |

编译允许符号槽与原有数值活动槽混用；匿名槽身份属于编译上下文，应复用 `context` 才能继续固定/重排它们。匿名显示名不能作为名字绑定；使用 `parameter_info` 中的参数句柄。单独整数映射没有模板初值，因此补初值时使用完整编译上下文。

`fixed` 与 `parameter_order` 用于符号/混合上下文；显式 `parameter_map` 不能同时指定这两项。编译保留模板快照，不计算占位矩阵，也不消耗用户 RNG。详细规则见[参数指南](../parameters.md)和[所有权约定](../conventions.md)。
