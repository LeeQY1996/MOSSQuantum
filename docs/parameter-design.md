# MOSSQuantum 线路参数设计

日期：2026-10-30。接口已实现；使用方法见[参数指南](parameters.md)。本页保留参数语义、兼容策略和验收标准。

命名参数与旧式数值活动槽的直接混用另见[混合参数整合设计](mixed-parameter-design.md)，该补充方案已接入编译、初值、绑定和执行接口。

参数和实数仿射表达式使线路可以直接描述共享变量、角度缩放和常数偏置。符号线路编译为可复用参数布局，完整绑定时实例化现有数值门；模拟后端继续接收原来的数值指令。参数映射统一负责数值展开和梯度回传。

第一版覆盖参数身份、表达式、完整与部分绑定、目标中的固定变量，以及现有梯度和执行计划的贯通。MindQuantum 的 [ParameterResolver](https://www.mindspore.cn/mindquantum/docs/en/master/core/parameterresolver/mindquantum.core.parameterresolver.ParameterResolver.html) 提供了命名系数和常数项的参照；本方案将变量身份、表达式和具体数值分别管理。

## 用户接口

以下示例使用已实现的接口。

```julia
θ = Parameter(:θ)
φ = Parameter(:φ)

template = QCircuit([
    RyGate(1, θ),
    RzGate(2, -θ / 2 + φ + π / 4),
    RxGate(1, θ),
])

independent_parameters(template)  # [θ, φ]
nparameters(template)             # 3 个门参数槽

bound = bind_parameters(template, Dict(θ => 0.4, φ => 0.1))
active_parameters(bound)          # [0.4, 0.685398..., 0.4]
result = execute(bound, StateVector(2); shots=1000)
```

同一个 `θ` 在三个门槽中出现，始终表示同一个独立变量。`bound` 是独立的数值线路，可以交给当前支持这些门的后端执行。优化时应向目标传入 `template`，由目标保留共享关系：

```julia
objective = ExpectationObjective(template, observable, initial;
    parameter_order=[θ, φ])

parameter_order(objective)  # [θ, φ]
value, gradient = value_and_gradient(AdjointGradient(), objective, [0.4, 0.1])
# gradient 的顺序是 [∂f/∂θ, ∂f/∂φ]
```

完整绑定后的普通数值线路不携带原来的符号映射。直接以 `bound` 创建旧式目标，仍按旧规则把活动门槽视为独立输入。

## 参数身份

`Parameter` 是不可变值，保存一个稳定身份和一个非空显示名称，不保存当前数值、可训练标记或后端信息。

```julia
θ1 = Parameter(:θ)
θ2 = Parameter(:θ)

θ1 == θ2       # false，同名而不同身份
copy(θ1) == θ1 # true
```

身份建议使用 UUID；相等性与哈希由身份决定，不能使用内存地址或显示名称。创建身份使用独立的系统随机源，不消耗调用者的模拟 RNG。复制参数、表达式或线路时保留身份，复制其中的可变数值存储。

复用一个参数表示共享；连接两条线路保留各自已有身份，不自动合并同名变量。需要主动共享、拆分或重新命名时，使用后文的显式替换接口。读取持久化身份时，同一身份对应冲突名称应报错；第一版不另行建设线路文件格式。

绑定以 `Parameter` 为键最明确。也允许使用 `Symbol` 或字符串作为便捷键，但名称必须在当前模板中唯一；有重名时列出冲突参数并要求按参数对象绑定。同一次绑定统一采用参数对象键或名称键，不混用两种方式。

## 仿射表达式

`ParameterExpr{T<:Real}` 表示

\[
e(p)=b+\sum_i a_i p_i.
\]

它不继承 `Real`，也不隐式转换为 `Float64`。只有完整绑定后，表达式才产生实数值。

第一版支持以下运算：

| 操作 | 示例 |
| --- | --- |
| 参数、表达式及实数之间的加减 | `θ + φ + π/4`、`θ - 0.2` |
| 一元正负号 | `-θ` |
| 乘以实数常量 | `2θ`、`0.5 * (θ + φ)` |
| 除以非零实数常量 | `θ / 2` |
| 常数表达式 | `ParameterExpr(0.3)` |

参数相乘、参数作除数、`sin(θ)` 等非线性表达式不属于第一版。使用者可以在外层数值函数中变换输入，或后续通过单独的非线性参数映射扩展。

表达式构造时合并同身份项、删除精确为零的系数并折叠常数。`θ-θ` 和 `0*θ` 不再依赖 θ；小而非零的系数必须保留。不做近似消项或角度周期折叠。系数、常数以及绑定输入必须为有限实数；新符号接口不接受 Bool 作为角度或系数。

表达式本身不可变，其公开项数据采用不可变表示或独立快照，不保留调用者字典或向量的可变别名。算术按 Julia 数值提升规则保留系数类型，直到数值门的构造或写入阶段。当前内置数值门的 Float64 存储语义继续保留，转换溢出必须报错。

表达式保留变量首次出现顺序，供显示和默认参数发现使用。相等性与哈希比较规范化后的系数和常数，不依赖求和项的排列顺序；因此相等表达式仍可能具有不同的默认发现顺序，向量调用以目标已经捕获的 `parameter_order` 为准。第一版无需提供无序字典形式的表达式构造器。

## 符号门与数值门

保留现有 `RyGate(1, 0.3)` 等数值构造器的类型、存储和行为。新增接受 `Parameter` 或 `ParameterExpr` 的构造器，内部返回 `ParameterizedInstruction` 包装，作为 `AbstractInstruction` 存入 `QCircuit`。

包装保存数值门原型、原型中待绑定的局部槽及对应表达式。原型只是构造资料；其占位数值不得用于执行线路、调用噪声工厂，或证明任意绑定值均受后端支持。绑定后仍需检查真实门值及执行能力。

包装需要支持位置查询、复制、重定位、伴随、打印和符号参数发现。伴随通过对数值原型取伴随来实现，表达式本身保持不变；不能普遍假设取负角度就等于任意门的伴随。

未绑定模板的 `mat`、`parameters`、`active_parameters` 及执行入口应给出明确的待绑定错误。执行前扫描整棵线路，包括条件的两个分支；缺值时不能先演化线路前半段或消耗 RNG。`execution_capability` 对尚未绑定的配置报告 `:unknown` 并说明需要数值绑定。

`nparameters` 保留门参数槽语义：在符号包装上统计仍依赖自由变量的表达式槽，不统计独立变量个数。纯常数槽计为零；在数值线路上继续统计已有活动槽。

符号模板不使用 `isparas` 或原地激活/停用接口管理变量冻结。对包含未绑定符号的模板调用这些修改接口时，应提示使用目标的 `fixed` 或显式替换。原数值接口不受影响。

## 参数发现与顺序

新增以下查询，避免把门槽数和优化变量数混用：

| 接口 | 含义 |
| --- | --- |
| `parameter_expressions(instruction)` | 按出现顺序返回包装保存的全部表达式槽快照，包括纯常数槽 |
| `independent_parameters(template)` | 按首次出现顺序返回去重后的自由变量 |
| `trainable_parameters(objective_or_plan)` | 当前目标允许变化的变量 |
| `parameter_order(objective_or_plan)` | 输入数值向量和输出梯度所采用的变量顺序 |
| `nparameters(numeric_instruction)` | 继续返回活动门槽数 |
| `nparameters(parameter_map)` | 继续返回映射的独立输入数目 |

`parameter_expressions` 的长度不保证等于 `nparameters`，编译布局另行保存每个表达式对应的指令路径与原局部槽。上述变量查询在命名模板或其目标上返回 `Parameter`；旧整数映射的 `parameter_order` 为整数 ID 顺序，匿名数值模板继续通过已有槽接口查询。

遍历遵循指令实际出现顺序；嵌套线路递归遍历，`Conditional` 固定先 then 后 else。两个分支都参与参数发现，测量结果不能改变输入向量的维度或顺序。

默认参数顺序不依赖字典迭代或 UUID 排序。用户可以通过 `parameter_order` 显式指定完整的自由变量顺序；必须无重复且恰好覆盖模板变量。固定部分变量后，训练顺序为这个完整顺序中剩余变量的相对顺序。

旧数值线路的发现、激活、槽计数和整数 `ParameterMap` 保持原样。符号参数门可与没有活动匿名槽的数值门混合。若同时出现旧式 `isparas=true` 匿名槽，第一版要求显式命名，避免自动生成变量身份及顺序：

```julia
legacy = RyGate(1, 0.0; isparas=true)
named = parameterize(legacy, [θ])
```

`parameterize(gate, expressions)` 按原型当前活动槽顺序对应表达式，复制原型，不改变原有冻结数值。它也为外部门提供统一入口。

## 完整绑定与替换

`bind_parameters` 完整绑定模板中的自由变量，返回拥有独立数值存储的线路。它不修改模板、映射或输入数据。

```julia
bound = bind_parameters(template, Dict(θ => 0.4, φ => 0.1))
bound = bind_parameters(template, [0.4, 0.1]; parameter_order=[θ, φ])
```

符号模板的向量绑定按独立变量顺序解释；旧数值模板的两参数向量绑定继续按活动门槽解释。显式向符号模板提供旧整数 `ParameterMap` 应拒绝，不能同时应用两套共享关系。

缺失键、未知键、歧义名称、错误向量长度或非有限值均在写入前拒绝。缺失键列出参数和使用位置，未知键默认不忽略。所有验证先于状态修改和执行 RNG 消耗。

新增 `substitute_parameters(template, replacements)` 处理部分绑定以及参数身份替换：

```julia
partial = substitute_parameters(template, Dict(φ => 0.1))
independent_parameters(partial)  # [θ]

shared = substitute_parameters(other_template, Dict(θ2 => θ))
renamed = substitute_parameters(template, Dict(θ => Parameter(:angle)))
```

替换值可为有限实数、参数或仿射表达式。所有键先在原模板上解析；未知键、歧义名称及混合键形式按完整绑定的规则拒绝。替换对原表达式同时进行一次，不递归应用新引入的替换规则；例如交换 θ 与 φ 不会形成递归。替换后重新规范化表达式和发现自由变量，不修改原模板。完全替换后的模板不再保留被消去变量的训练关系。

替换返回描述模板；执行前仍需完整绑定剩余变量并完成数值实例化。剩余变量为空时，可以通过 `bind_parameters(template, Dict())` 完成这一步。

## 固定变量与优化输入

冻结通过目标或执行计划的 `fixed` 配置表达：

```julia
objective = ExpectationObjective(template, observable, initial;
    parameter_order=[θ, φ], fixed=Dict(φ => 0.1))

independent_parameters(objective)  # [θ, φ]，原模板的自由变量
trainable_parameters(objective)   # [θ]
parameter_order(objective)        # [θ]
value, gradient = value_and_gradient(AdjointGradient(), objective, [0.4])
# 输入与梯度都只有一个元素
```

`fixed` 保存非训练变量值的独立快照；其余变量全部可训练。第一版不另加一个可能与 `fixed` 冲突的训练掩码。固定变量仍保留在源模板中，并参与角度计算。改变固定值或训练集合需要重新构造目标或计划。

对表达式 `2θ+φ` 固定 θ 后，φ 仍然活动。只有不再依赖任何训练变量的门槽才可以在编译后的数值门中停用。

完整绑定一次性生成数值线路；替换改变模板中的表达式；固定变量配置限定某个目标的输入空间。这三个操作有各自独立的用途。

## 参数编译与映射协议

目标和计划内部采用同一个编译入口，原子地生成绑定模板、仿射映射和源槽布局，不让调用者手工维护三者的一致性。为了避免用占位角度实例化外部门，内部绑定模板保留描述包装，只有完整绑定的结果包含纯数值门。

扩展包可以通过公共编译入口复用映射：

```julia
compiled = compile_parameters(template; parameter_order=[θ, φ])
angles = expand_parameters(compiled.parameter_map, [0.4, 0.1])
bound = bind_parameters(compiled.template, [0.4, 0.1], compiled.parameter_map)
```

固定变量贡献合入常数后，剩余活动门槽满足

\[
\alpha=A x+b,
\]

其中 x 是目标的训练输入，α 是编译后数值线路的活动门参数。实现按行保存稀疏系数，不要求实际构造稠密 A。

编译顺序如下：

1. 快照整棵模板，规范化表达式，确定完整变量顺序及固定值。
2. 把纯常数和只依赖固定变量的槽写为数值常量，并关闭这些槽的数值活动标记。
3. 其余槽保留活动标记，按数值线路的实际活动槽顺序生成 A 的行和 b。
4. 保存 `(指令出现路径, 原局部槽)` 到活动行或常量槽的对应关系。
5. 验证数值模板、映射维度和活动顺序一致，再交给现有执行和梯度入口。

目标和计划构造只检查结构、参数布局和公开扩展协议。依赖实际角度的 `mat`、`differentiate`、值域和后端验证，在每次完整绑定后进行；准备阶段不能用占位值执行这些检查或演化状态。符号源槽数可能与固定变量后数值活动槽数不同，新的编译路径须按自身布局验证，不能套用旧绑定中“活动槽数量保持不变”的源模板检查。

必须始终满足

```text
length(expand_parameters(map, x)) == nparameters(lowered_template)
length(accumulate_parameter_gradients(map, g)) == length(x)
```

源模板可以有多个表达式槽而没有训练变量：编译后这些槽均为数值常量，活动映射为 0×0，线路仍照常执行。允许空线路、重复变量和秩亏的映射，例如单门依赖 `θ+φ`。

以上示例未固定变量时有

\[
A=\begin{bmatrix}1&0\\-1/2&1\\1&0\end{bmatrix},
\qquad b=\begin{bmatrix}0\\\pi/4\\0\end{bmatrix}.
\]

固定 θ 为 0.4 后，第一和第三个门槽成为常量，活动映射仅剩第二个槽：`α_active = φ + π/4 - 0.2`。因此旧数值槽计数与映射行数仍一致。

引入统一的参数映射协议：

| 接口 | 职责 |
| --- | --- |
| `AbstractParameterMap` | 整数映射和仿射映射的共同协议 |
| `expand_parameters(map, x)` | 生成活动门槽值 |
| `accumulate_parameter_gradients(map, gα)` | 把活动槽梯度回传到训练输入 |
| `parameter_order(map)` | 返回映射的输入顺序快照 |
| 内部稀疏行查询 | 参数移位、预算及协方差传播使用 |

既有 `ParameterMap` 保留构造器、整数 ID、`length`、`nparameters`、`parameter_indices` 和累加行为；它对应每行一个 1 且 b 为零的特例。编译器生成 `AffineParameterMap` 保存新表达式的映射，第一版不要求用户直接构造它。

两种映射的 `length(map)` 均为编译后活动门槽数，`nparameters(map)` 均为训练输入数。

`parameter_indices` 继续只服务整数映射。仿射映射的一行可以依赖多个变量，不能用虚构的单一索引代替；通用执行代码改为调用展开和回传协议。

### 外部门的数值实例化

增加可选扩展点：

```julia
materialize_parameters(prototype::YourGate,
    values::AbstractVector{<:Real}, active_mask::AbstractVector{Bool})
```

`values` 和 `active_mask` 对应包装保存的原型活动槽，而非原型的所有数值参数。该方法返回拥有独立存储的数值指令：所有待绑定槽写入 values，最终只有 mask 为真的槽参与现有数值梯度；原型中原来冻结的其他参数保持原值。

默认适配仅使用现有公开复制、参数写入、激活和逐槽停用接口，始终保留方法返回的替换对象。完成后验证完整数值参数、活动槽数量、活动值和顺序。停用方法可能是默认无操作，不能假定调用就已成功。

无法实现请求掩码的外部门必须覆盖此 hook；不通过访问其 `paras` 或 `isparas` 字段兜底。内置门和适配充分的外部不可变门都应纳入验收。

## 梯度与有限 shots

各梯度方法采用明确的坐标空间：

| 方法 | 计算方式 | 回传 |
| --- | --- | --- |
| `AdjointGradient` | 现有反向过程得到活动门槽梯度 | `A' * gα` |
| `ParameterShift` | 对一个门的一次出现位置单独位移 | `A' * gα` |
| `FiniteDifference` | 在训练输入 x 中扰动，每次重新展开全部角度 | 已是输入梯度，不再乘 A' |
| `SPSAGradient` | 在训练输入 x 中抽取扰动方向，每次重新展开 | 已是输入梯度，不再乘 A' |

共享变量直接加 π/2 一般不满足单门参数移位公式。例如两个连续的 `Ry(θ)` 对零态的 Z 期望为 `cos(2θ)`，导数为 `-2sin(2θ)`；应逐个门槽位移再求和。

相同源门对象多次出现也按不同门槽位移。一个槽对多个变量的贡献只计算一次槽梯度，再按该行系数分配，不为每个变量重复测量。

保留原数值目标的 `supports_gradient(method, objective)` 入口，并增加 `supports_gradient(method, objective, values)`，用于在真实绑定点验证梯度。符号目标的无数值查询仅依据可声明的门族和协议判断；对只能在具体值上判定的外部门保守返回 false。实际求导和预算预检使用带 values 的路径，避免这个保守结果阻止合法绑定点。参数移位配方也从真实绑定门收集，而不读取占位原型。

有限 shots 的参数移位需要回传完整协方差。第一版维持不同目标调用使用独立测量：

\[
\widehat g_{\alpha,j}=\sum_r c_{jr}\widehat F(\alpha+s_{jr}e_j),
\qquad v_j=\sum_r c_{jr}^{2}\operatorname{Var}(\widehat F_{jr}),
\]

\[
C_x=A^\mathsf{T}\operatorname{diag}(v_j)A.
\]

例如单门角度为 `2θ+φ`，该槽梯度估计方差为 v，则两个变量的协方差贡献为

\[
v\begin{bmatrix}4&2\\2&1\end{bmatrix}.
\]

不能继续仅更新协方差对角线。有限差分和 SPSA 保持其输入空间中的统计定义，避免重复应用映射。

只对编译后仍活动的槽要求导数或移位配方。零训练变量时返回空梯度并计算一次目标值。假设每次目标执行预算为 B，活动槽配方长度为 r_j，训练变量数为 k，SPSA 方向数为 d，则包含独立目标值估计的预算为：

| 方法 | 预算 |
| --- | --- |
| 参数移位 | `B * (1 + sum(r_j))` |
| 有限差分 | `B * (1 + 2k)` |
| SPSA，k 大于零 | `B * (1 + 2d)` |
| 任意方法，k 等于零 | `B` |

配方不支持、数值转换失败和预算不足应在测量前失败。不根据系数大小增加调用数；系数通过梯度及协方差传播。

## 执行计划与噪声

`ExpectationObjective`、`BatchExpectationObjective`、`ShotExpectationObjective`、`prepare_execution` 和 `prepare_estimation` 使用同一编译结果。它们在符号输入上增加 `parameter_order` 和 `fixed`；旧式 `parameter_map` 用法继续保留，两套配置不能同时提供。

`run_sweep` 的参数矩阵继续为“输入变量数 × 参数点数”。命名目标或计划的行顺序取自 `parameter_order`，固定变量不占输入行。多个绑定和 pullback 各自拥有数值存储，不在参数对象或表达式中缓存可变当前值。

编译后的计划快照包括指令树、变量顺序、固定值、映射和源槽布局。调用者随后调整原模板不影响已有计划。改变固定值、活动集合或结构需要重建。无需引入跨模板全局缓存；如果内部复用布局，必须校验指令路径、类别、位置和原局部槽，不能只比较槽数。

固定噪声、读出配置和现有噪声通道可以继续使用。符号门包装会改变 `isa RyGate` 等匹配结果，因此固定 `NoiseRule` 必须按包装原型的实际门类型和位置匹配，再插入固定通道；保留表达式后统一编译。

第一版在未绑定符号模板上仅接受类型匹配加固定 `QuantumMap` 的规则，以及明确的制备、终态和读出配置。可调用谓词或噪声工厂可能读取角度，不能以占位零值调用后静默冻结，应明确拒绝。用户完整绑定后再调用 `with_noise`，仍按已有数值规则执行。

参数相关噪声属于额外函数依赖，不因增加仿射门参数而自动获得解析梯度。prepared 路径仍采用固定噪声快照；不对每次绑定隐式重新调用工厂。

CPU、MPS 和稳定子后端都接收编译后的原数值门。能绑定参数不代表某个后端支持该门或某种梯度；现有表示和方法边界继续有效。

## 错误与兼容策略

| 情况 | 行为 |
| --- | --- |
| 模板缺少数值就执行或读取数值矩阵 | 待绑定错误，包含参数与指令路径 |
| 名称对应多个不同身份 | 拒绝名称绑定，提示使用参数对象键 |
| 完整绑定缺值或含未知键 | 拒绝，列出缺失项或未知项 |
| 参数顺序遗漏、重复或含多余变量 | 拒绝，不隐式补齐 |
| 非有限值、Bool、转换溢出、常量除零 | 在写入或执行前拒绝 |
| 变量相乘或非线性运算 | 说明第一版支持的表达式范围 |
| 符号门与匿名活动槽混用 | 自动编译统一映射；匿名身份及初值通过编译上下文查询 |
| 同时提供符号配置和旧整数映射 | 拒绝重复映射 |
| 外部门不能实现活动掩码 | 说明需要覆盖数值实例化 hook |
| 符号模板使用可调用噪声规则 | 提示先完整绑定或使用固定规则 |

符号数据存放于 `QuantumCircuits` 的描述层，定义在门的符号构造器之前。参数编译和映射放在主包 API 层。使用原数值门的调用者和后端扩展无需接受符号标量。

## 代码改动范围

| 位置 | 设计中的改动 |
| --- | --- |
| 新的 `quantum_circuits/parameters/` | 参数身份、仿射表达式、包装、发现、替换及数值实例化 hook |
| [门构造器](../src/quantum_circuits/gates/one_qubit.jl)及二三比特参数门 | 新增符号重载，保留现有数值类型 |
| [参数映射](../src/api/parameter_map.jl)与[参数绑定](../src/api/parameter_binding.jl) | 通用映射协议、符号编译及完整绑定 |
| [目标函数](../src/api/objectives.jl) | 捕获编译快照及训练输入顺序，参数化映射字段类型 |
| [伴随梯度](../src/differentiation/objectives.jl) | 复用槽梯度及通用回传，保留绑定后检查 |
| [采样梯度](../src/differentiation/sampled_gradients.jl) | 移除直接整数 gather，逐槽位移并传播完整协方差 |
| [执行计划](../src/execution/execution_plans.jl)、[估计计划](../src/observables/estimation_plans.jl)与[参数扫描](../src/execution/experiments.jl) | 统一展开、维度、顺序及快照语义 |
| [噪声模型](../src/execution/noise_models.jl) | 固定规则按原型匹配，拒绝未绑定值相关工厂 |
| 打印、绘图与可选 AD 扩展 | 展示符号表达式；AD 继续通过编译目标和现有数值梯度工作 |
| MOSSChemistry | 在核心能力验收后复用参数缩放，逐步替换私有槽展开及回传 |

## 验收标准

验收以可计算结果和兼容边界为准：

1. 同名不同身份、显式共享、复制保留身份、线路拼接和按名称绑定歧义均有确定行为。
2. 表达式精确消项、微小系数保留、常数折叠、顺序、哈希及输入所有权符合契约。
3. 完整绑定、部分替换、固定混合表达式、全固定变量和空线路产生正确数值线路；每个编译映射行对应一个活动数值槽。
4. 至少覆盖两个连续 `Ry(θ)`、单门 `2θ+φ`、含偏置的多门共享参数，比较解析结果、伴随、参数移位和有限差分；SPSA 使用统计验收。外部门另验证占位值不合法而真实绑定值合法的情况，构造和预检不得误拒绝。
5. 对 `2θ+φ` 独立验证协方差中的非对角项，验证预算、evaluations、零训练变量和失败前 RNG 状态。
6. 纯态、密度矩阵、两种 batch 继续使用各自已有梯度域；MPS 验收参数移位和有限差分；稳定子对不支持的数值参数门保持明确拒绝。
7. 嵌套线路、条件双分支、多次引用同一门、伴随和位置变换保留变量身份及顺序。实际执行分支不改变参数布局。
8. 直接执行、prepared execution、有限 shots 估计、prepared estimation 和 `run_sweep` 数值一致，原模板和固定值输入的后续修改不影响快照。
9. 固定噪声的原型类型匹配正确，不以占位值执行工厂；不支持的规则在使用 RNG 前拒绝。
10. 内置多参数门和一个外部不可变门验证部分活动掩码与数值实例化；未实现 hook 的不兼容扩展清楚报错。
11. 既有数值参数、整数 `ParameterMap`、目标、采样梯度和执行计划测试继续通过；核心最低和主要支持的 Julia 版本均运行相关测试。

## 实施顺序

| 阶段 | 交付 | 完成条件 |
| --- | --- | --- |
| 1 参数前端 | 身份、表达式、符号门、发现、绑定、替换与显示 | 新模板可绑定后执行，旧数值行为不变 |
| 2 数值编译 | 公共映射协议、活动槽裁剪、固定变量及目标快照 | 纯态、混态和 batch 伴随梯度正确；外部门适配成立 |
| 3 现有流程贯通 | 参数移位、FD、SPSA、协方差、预算、prepared、扫描与固定噪声 | 全链路验收通过，不遗留依赖整数 gather 的通用路径 |
| 4 家族接入 | MPS 验收、化学参数迁移、示例和兼容说明 | 典型 VQE 与共享参数线路复用主包能力 |

第一版到上述流程贯通后再对外作为完整参数能力发布。非线性符号代数、符号 Hamiltonian 系数、可训练噪声、运行时经典值生成角度及编码器和 ansatz 的批量分组接口，分别在后续需求中设计。
