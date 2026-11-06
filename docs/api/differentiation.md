# 目标函数、梯度与有限采样优化

[API 目录](../api.md) · [逐项参考](reference.md)

## 目标函数与精确梯度

```julia
ExpectationObjective(template,observable,initial;
    parameter_map=nothing,parameter_order=nothing,fixed=nothing,backend=backend(initial))
BatchExpectationObjective(template,observable,initial;
    reduction=:mean,weights=nothing,parameter_map=nothing,kwargs...)
```

这两个构造返回快照目标，复制模板、观测量、初态和权重；后端保留为执行资源。`evaluate(objective,values)` 返回有限实标量；批次 `evaluate_batch` 返回按样本顺序的实向量，`evaluate` 再归约为均值、求和或显式 `:weighted_sum`。权重不自动归一化，可为负；非加权归约拒绝 `weights`，空批次不能作为目标。

目标不携带梯度算法。`AbstractGradientMethod` 是可替换梯度协议；`AdjointGradient()` 是已有稠密 CPU 确定性反向算法。单状态和批次纯态/混态的受支持酉门、固定通道和厄米观测量可以使用，测量、后选择、随机执行和可训练噪声不自动获得此契约。

| 调用 | 返回值/扩展约定 |
| --- | --- |
| `supports_gradient(method,objective[,values])` | `Bool`；带参数形式还能验证当前绑定值 |
| `value_and_gradient(method,objective,values)` | `(value,gradient)`；梯度与独立输入同长度 |
| `value_and_pullback(method,objective,values)` | `(value,pullback)`；`pullback(cotangent)` 返回参数向量的余切 |
| `differentiable_value(method,objective,values)` | 前向实标量；通过可选 ChainRulesCore 扩展向 AD 消费者提供所选反传 |
| `evaluate(f::Function,values)` | 调用 `f(values)`；自定义目标无需继承量子状态类型 |
| `UnsupportedGradient` | 算法不支持该目标/配置时的异常 |

```julia
using MOSSQuantum
c = QCircuit([RyGate(1, 0.0; isparas=true)])
o = ExpectationObjective(c, QubitsTerm(1=>"Z"), StateVector(1))
@assert supports_gradient(AdjointGradient(), o)
value, gradient = value_and_gradient(AdjointGradient(), o, [0.2])
@assert value ≈ cos(0.2)
@assert gradient[1] ≈ -sin(0.2)
```

显式 `value_and_gradient` 不要求安装 AD 框架。使用 `Zygote.gradient` 时在同一环境安装并加载 `Zygote`，可对 `differentiable_value` 求导。前向支持和梯度支持需分别检查，见[扩展指南](../extending.md)。

## 有限采样目标与数值梯度

```julia
ShotExpectationObjective(template,O,initial; shots,parameter_map=nothing,
    backend=backend(initial),method=DensityMatrixEvolution(),noise_model=nothing,
    readout=ReadoutError[],classical=nothing,allocation=:uniform,kwargs...)
ParameterShift()
FiniteDifference(; step=0.01)
SPSAGradient(; step=0.1,directions=8)
estimate_gradient(method,objective,values; rng=Random.default_rng(),budget=nothing)
```

`ShotExpectationObjective` 是单状态实目标；`shots` 是**每次目标评估**的跨组总预算。`estimate(objective,values)` 返回 `ExpectationEstimate` 或 `AdaptiveEstimate`，`evaluate` 只取 `.value`。噪声在构造时展开并冻结；角度依赖噪声若需要随参数变化，使用显式函数配合差分。

`ParameterShift` 按门的每次出现逐槽移位，再汇总共享参数，未知门需要 `parameter_shift_rule(gate,active_index)`。该钩子返回 `(coefficient,shift)` 对列表或 `nothing`；规则必须对整个门族成立，不能从某个角度矩阵推断。受控旋转通常需要四点评估。`FiniteDifference` 是中心差分；`SPSAGradient` 平均独立 Rademacher 同时扰动方向。

`GradientEstimate` 返回目标值、梯度、采样不确定度/协方差、shot 数与评估数；`value_and_gradient` 可取相同方法的 `(value,gradient)`。差分的截断偏差不属于采样标准误，小步长会放大采样方差。SPSA 不保证单次方向的无偏梯度等于精确导数。按 `required_shots(method,objective,values)` 计算真实评估成本，不应将单次目标预算误当成整个梯度预算。

## `MOSSQuantum.Optimization`

子模块须显式导入：

```julia
using MOSSQuantum.Optimization
result = minimize(objective,initial;
    method=ParameterShift(),optimizer=:adam,iterations=100,learning_rate=0.1,
    decay=0,perturbation_decay=0.101,rng=Random.default_rng(),callback=nothing,
    max_shots=nothing)
```

`objective` 为 `ShotExpectationObjective`，`initial` 是有限实参数向量。支持 `:adam`、`:sgd`。第 `k` 步学习率为 `learning_rate/k^decay`；SPSA 扰动为 `method.step/k^perturbation_decay`。`callback(step)===false` 在当次更新前停止。

`OptimizationStep` 记录 `iteration`、更新前的 `parameters`、`GradientEstimate` 和学习率。`OptimizationResult` 记录最终参数、一次全新独立最终能量估计、历史、总 shots、评估数和状态；状态为 `:iteration_limit`、`:callback` 或 `:shot_budget`。`max_shots` 为整个优化硬上限，算法预留最终评估预算。不会根据采样噪声自动推断收敛或保证找到最优解。见[优化示例](../../examples/optimization/README.md)。
