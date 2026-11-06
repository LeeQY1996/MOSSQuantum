# MOSSQuantum API 与函数文档

本目录覆盖 `MOSSQuantum` 顶层导出以及 `MOSSQuantum.Utilities`、`MOSSQuantum.Optimization` 的公开接口。以当前源码为准；其他家族包的实现能力分别在各自仓库文档中说明。

| 分类 | 内容 |
| --- | --- |
| [状态、编码与线性代数](api/states.md) | 四种稠密容器、存储所有权、编码、随机状态、距离、熵、偏迹 |
| [门、电路、通道与算符](api/gates.md) | 全部门构造、矩阵与位置、Kraus 噪声、观测量代数 |
| [参数系统](api/parameters.md) | 活动参数、共享映射、符号表达式、编译、初值 |
| [执行与实验](api/execution.md) | 后端协议、模拟、测量、采样、噪声、经典控制、准备计划和预算 |
| [梯度与优化](api/differentiation.md) | 精确与有限采样目标、替换梯度、SPSA、有限-shot 优化 |
| [Utilities](api/utilities.md) | 自旋 Hamiltonian、基态、时间演化、Trotter 和变分电路 |
| [完整逐项参考](api/reference.md) | 244 个导出条目，包含两个子模块中的重复导出；实际方法签名、源码位置与原生帮助 |

## 快速示例

```julia
using MOSSQuantum, Random
circuit = QCircuit([HGate(1), CNOTGate(1, 2)])
ψ = circuit * StateVector(2)
@assert probabilities(ψ) ≈ [0.5, 0.0, 0.0, 0.5]
result = execute(circuit, StateVector(2); shots=1000,
                 result=:counts, rng=MersenneTwister(42))
```

关键约定：量子位 1 为最低有效位；批次最后一轴为样本；`apply!` 可能返回更换表示的状态；密度矩阵按迹归一化；保真度采用平方 Uhlmann 定义；默认 `amplitude` 带缩放，读原始振幅使用 `scaling=1`。细节见[数值与所有权约定](conventions.md)。

## 维护与验证

主题页给出调用方式、参数、返回值、所有权和能力边界。逐项参考通过 `docs/generate_api_reference.jl` 从实际加载的包和导出清单重建：

```bash
julia --project=/path/to/environment docs/generate_api_reference.jl
```

该环境须将当前 checkout 作为 `MOSSQuantum` 依赖。文档构建不需要 GPU、PySCF 或 AD 框架；运行相关示例时才需要对应可选依赖。

返回[项目首页](../README.md)。
