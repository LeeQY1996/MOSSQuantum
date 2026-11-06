# 执行、采样、噪声与实验

[API 目录](../api.md) · [逐项参考](reference.md)

## 选择合适入口

| 调用 | 返回值 | 主要语义 |
| --- | --- | --- |
| `apply!(instruction,state)` / `apply!(backend,instruction,state)` | 执行后的状态 | 原地或返回类型提升/纯态转混态；始终接住返回值 |
| `simulate(circuit,initial; rng=..., backend=...)` | `SimulationResult` / `BatchSimulationResult` | 复制初态并记录一次轨迹及中间测量 |
| `probabilities(state; qubits=1:nqubits(state))` | 实概率向量；批次为矩阵 | 终态边缘分布，不执行中间测量 |
| `sample([rng,]state,shots; qubits=...)` | 位样本矩阵 `(shots,qubits)` | 批次为 `(shots,qubits,B)` |
| `counts([rng,]state,shots; qubits=...)` | 位串计数字典；批次为字典向量 | 字符按请求的 `qubits` 顺序排列 |
| `execute(circuit,initial; shots,rng=...,...)` | `ShotResult`；`result=:counts` 返回 `CountsResult` | 从初态独立重放每个 shot，包括中间测量和拒绝 |
| `expectation(O,state)` | 精确复数标量/批次向量 | 不产生有限-shot 误差 |
| `estimate(O,state; shots,rng=...,...)` | `ExpectationEstimate` / 批次估计列表 | Pauli 分组后的有限采样估计 |
| `estimate(O,circuit,initial; shots,rng=...,...)` | 期望估计 | 每个分组执行电路，支持相应噪声/经典控制配置 |

`SimulationResult.state` 是最终状态，`.measurements` 是按执行顺序的 `MeasurementRecord` 列表，`.classical` 是最终经典寄存器。批次结果的记录/寄存器按样本分开。`MeasurementRecord` 包含位置、物理结果、概率、类型、报告结果和可选经典键；概率是复位前的概率。

`ShotResult` 保留尝试/接受信息、终态样本、中间记录与经典寄存器；`CountsResult` 只保留统计需要的信息以减少内存。后选择时 `shots` 是尝试次数，接受数可能为零。多次采样 `simulate(...).state` 不会重放已经发生的中间测量；独立实验使用 `execute`。

```julia
using MOSSQuantum, Random
c = QCircuit([HGate(1), CNOTGate(1, 2)])
s = StateVector(2)
r = execute(c, s; shots=100, rng=MersenneTwister(42), result=:counts)
e = estimate(QubitsTerm(1=>"Z", 2=>"Z"), c, s;
             shots=100, rng=MersenneTwister(42))
@assert e.value ≈ 1
```

直接对 `QMeasure`/`QSelect` 调用 `apply!` 的返回值是测量元数据/选择概率；这两个叶指令通过 `measure!`/`post_select!` 使用时应按各自返回约定接收，而不是把元数据赋给状态。

`measure!(state,pos; auto_reset=true,rng=...)` 保留寄存器并原地坍缩，返回测量结果和对应概率；批次逐样本返回向量。`measure(state,pos; rng=...)` 的纯态非原地路径移除测量位并返回约化态、结果、概率。`post_select!`/`post_select` 类似地固定选择某结果；零概率选择会报错，完整重载见逐项参考。

## 后端协议与能力查询

`AbstractQuantumState`、`AbstractBackend` 是扩展接口；`CPUBackend()` 表示稠密 CPU 实现，`backend(state)` 根据存储识别默认后端。

```julia
supports(backend, operation, state; action=:apply)  # Bool
validate_backend_execution(backend,circuit,state; action=:apply)
execution_capability(backend(state),circuit,state; mode=:simulate,method=DensityMatrixEvolution())
```

`supports` 是局部能力检查；完整配置使用 `execution_capability`，返回 `ExecutionCapability(status,issues,final_state_types)`。状态是 `:supported`、`:unsupported`、`:unknown`，问题中包含嵌套指令路径和原因。查询不执行电路，不抽样；未绑定模板会保留未知项。`UnsupportedOperation` 表示具体后端动作未实现。

扩展后端通过 `execution_capability_step(backend,instruction,state_type; mode,method)` 声明所有可能的输出状态类型；通过 `execution_capability_backend(backend,state; mode,method)` 声明模式级协议。两者返回 `CapabilityStep`，问题记录类型是 `CapabilityIssue`。终态采样扩展钩子为 `validate_terminal_sampling`、`prepare_terminal_sampling`、`draw_terminal_samples`，不要将 CPU 内部数组操作当成所有后端的通用行为。见[扩展指南](../extending.md)。

## 经典控制

```julia
ClassicalRegister(values=Dict{Symbol,Int}())
ClassicalCondition(keys,value=1; source=:reported)
Conditional(condition,instruction; otherwise=QCircuit())
Conditional(key,instruction; value=1,source=:reported,otherwise=QCircuit())
```

寄存器分别保留报告值与物理值，条件默认读取报告值；第一经典键是整数的最低有效位。`QMeasure(i; key=:m,auto_reset=false)` 写入该键；`classical_register(records)` 从记录恢复寄存器，`classical_counts(result; ...)` 统计经典输出。未定义键不能被读取。条件分支在 `simulate`/`execute` 中执行，直接 `apply!` 不提供经典控制语义。

## 噪声配置

| 接口 | 输入与结果 |
| --- | --- |
| `ReadoutError(qubits,probabilities; scope=:terminal)` | 经典混淆矩阵，行是真值、列是报告值；支持 1–2 位终态误差，中间误差只支持 1 位 |
| `ReadoutError(i; p0_to_1,p1_to_0,scope=:terminal)` | 单位点误报率便利构造；`scope=:measurement` 或 `:all` 控制中间读出 |
| `NoiseRule(matcher,factory; when=:after,qubits=nothing)` | 匹配指令类型/谓词，工厂返回物理 `QuantumMap` 或列表；注册顺序执行 |
| `NoiseModel(;rules=[],readout=[],preparation=[],terminal=[])` | 独立复制的噪声配置；准备/终态列表为量子通道 |
| `with_noise(circuit,model)` | 展开一次，返回 `NoisyCircuit`；`.circuit` 与 `.readout` 可检查；重复展开报错 |
| `Delay(i; duration)` | 明确空闲时间；自身不产生噪声，需要匹配的噪声规则 |
| `readout_probabilities(state,errors; qubits=...)` | 将经典报告错误施加到终态概率，不改变量子态 |
| `DensityMatrixEvolution()` | 默认密度矩阵噪声演化策略 |
| `KrausTrajectory()` | CPU 纯态独立随机 Kraus 轨迹策略；不代表 AD 支持 |

噪声规则只匹配原始叶指令，不递归匹配生成的噪声。工厂收到独立副本。未绑定符号模板仅接受“指令类型 + 固定通道”的规则；需要角度依赖工厂时先绑定。完整示例见[噪声指南](../noise-simulation.md)。

## 分组估计与误差

```julia
measurement_plan(O; grouping=:qwc,atol=0,max_terms=100_000)
```

返回 `MeasurementPlan`，保存无需采样的常数、`MeasurementGroup` 组和最小寄存器大小；每个组保存 `PauliMeasurementTerm`。仅对可展开为实系数 Pauli 项的厄米观测量建立统计契约。`shots` 是跨组总预算，不能每个组重复用作完整预算。常数/零算符消耗零 shot。

`ExpectationEstimate` 的 `.value` 是均值估计，`.variance` 是估计均值的方差，`.stderr=sqrt(variance)`；`GroupEstimate.sample_variance` 是组内每-shot 总能量的无偏样本方差，包含同组项的协方差。标准误不是严格误差界，样本方差为零也不能保证真实分布确定。

## 准备计划、预算与扫参

```julia
plan = prepare_execution(circuit,initial; method=DensityMatrixEvolution(),
    noise_model=nothing,readout=ReadoutError[],classical=nothing,qubits=1:nqubits(initial))
bound = bind_execution(plan,values)
execute(bound; shots=1024,rng=rng,result=:counts)

plan = prepare_estimation(circuit,O,initial; grouping=:qwc,kwargs...)
bound = bind_execution(plan,values)
estimate(bound; shots=1024,rng=rng,allocation=:uniform)
```

`ExecutionPlan`/`EstimationPlan` 快照电路、状态和固定噪声，`BoundExecutionPlan`/`BoundEstimationPlan` 绑定独立值。计划支持单个稠密 CPU 状态，确定性输出可缓存；改状态、结构、噪声或测量应重建计划。`ExecutionWorkspace(bound)` 是独立可变工作缓冲，不应并发共享。

`VarianceAllocation(;pilot_shots=16)` 先独立试采样，再将生产采样数按标准差分配；每组试采样至少 2 次，生产阶段也至少 2 次。`AdaptiveEstimate` 分别记录试采样和生产计数，试采样不重用进生产均值。

`ShotBudget(limit)` 是线程安全硬预算；`remaining_shots(budget)` 返回可用数，`required_shots(objective)` / `required_shots(method,objective,values)` 提前计算成本。超额抛出 `ShotBudgetExceeded`；已预留采样的调用失败后仍保留扣款。

`run_sweep(plan,parameters; shots,rng=...,parallel=false,budget=nothing,...)` 按矩阵列运行参数点，返回 `ExperimentResult(parameters,results,shots,evaluations)`；`shots` 是每点预算。先全部绑定验证，再按列分配种子；同一 Julia 环境中串行与线程扫参可复现。见[准备实验指南](../prepared-experiments.md)。
