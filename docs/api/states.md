# 状态、编码与线性代数

[API 目录](../api.md) · [逐项签名与原生帮助](reference.md)

## 状态容器

```julia
StateVector(n::Int)
StateVector(data::AbstractVector; copy=false, preserve_storage=false)
DensityMatrix(n::Int)
DensityMatrix(data::Union{AbstractVector,AbstractMatrix}; copy=false, preserve_storage=false)
DensityMatrix(state::StateVector)
BatchStateVector(n::Int, B::Int)
BatchStateVector(data::AbstractMatrix; copy=false, preserve_storage=false)
BatchDensityMatrix(n::Int, B::Int)
BatchDensityMatrix(data::AbstractArray{<:Number,3}; copy=false, preserve_storage=false)
BatchDensityMatrix(state::Union{StateVector,DensityMatrix,BatchStateVector})
```

`n` 是量子位数，`B` 是独立样本数；整数构造返回全零计算基态，默认元素类型为 `ComplexF64`。四类都支持显式 `Type` 首参数或 `{T}` 构造。数组维度分别是 `(2^n,)`、`(2^n,2^n)`、`(2^n,B)`、`(2^n,2^n,B)`。单列批次仍是批次。构造检查形状，不自动保证数组已归一化、密度矩阵半正定或迹为一。

`copy=false` 允许复用兼容数组，但转换仍可分配。`preserve_storage=true` 保留数组家族；能保存数组并不代表 CPU 后端能执行它。单状态的复制构造默认共享存储，批次到同类批次的复制构造默认 `copy=true`；`copy(state)` 始终产生独立数值存储。纯态到混态转换分配外积。

`StateVector(batch, i)`、`DensityMatrix(batch, i)` 提取独立样本。批次可以由单状态或同类状态列表构造，详见对应原生帮助。

| 函数 | 输入与返回值 | 所有权/形状 |
| --- | --- | --- |
| `storage(state)` | 底层数组 | 可写、与状态共享 |
| `amplitudes(state)` | 纯态或纯态批次的振幅数组 | 同底层存储 |
| `nqubits(state)` | 量子位数 `Int` | 不改变状态 |
| `batch_size(batch)` | 样本数 `Int` | 不去掉大小为 1 的轴 |
| `amplitude(state, bits; scaling=√2)` | 指定计算基振幅 | 默认乘 `scaling^n`，读原始振幅请用 `scaling=1` |
| `amplitude(batch, bits, i; scaling=√2)` | 第 `i` 列的计算基振幅 | `bits` 长度等于 `n` |

量子位使用 1 起始编号，量子位 1 是索引中的最低有效位。不要把输出字符串的书写顺序与整数的大端二进制表示混用。

## 编码、随机状态与重置

| 调用 | 参数含义与返回值 |
| --- | --- |
| `onehot_encoding(n)` / `onehot_encoding(bits)` | 返回零态/指定 0、1 位串的 `StateVector` |
| `qubit_encoding(inputs::AbstractVector{<:Real})` | 每个输入 `x` 编为 `cos(πx/2)\|0⟩+sin(πx/2)\|1⟩`，返回乘积纯态 |
| `qstate(n)` / `qstate(inputs)` | 上述零态/量子位编码的便利入口 |
| `amplitude_encoding(v; nqubits=ceil(Int,log2(length(v))))` | 补零到 `2^nqubits` 并按范数归一化，返回纯态；输入不能是零向量 |
| `batch_onehot_encoding(n,B)` / `batch_onehot_encoding(bit_vectors)` | 返回独立计算基态批次；列表中每个向量为一个样本 |
| `batch_qubit_encoding(inputs::AbstractMatrix)` | 每列一个输入样本，返回纯态批次 |
| `batch_amplitude_encoding(inputs; nqubits=...)` | 逐列补零归一化；每列须非零 |
| `rand_state([rng,] [T,] n)` | 归一化高斯向量，返回纯态；这里要求 `n≥1` |
| `rand_densitymatrix([rng,] [T,] n)` | 随机正半定、单位迹密度矩阵 |
| `rand_batch([rng,] [T,] n,B)` | 随机独立纯态，逐列归一化 |
| `rand_batch_densitymatrix([rng,] [T,] n,B)` | 随机独立混态，逐样本单位迹 |
| `reset!(state)` | 原地改成零计算基态，返回状态 |
| `reset_onehot!(state,bits)` | 原地重设计算基态；批次传位串向量列表 |
| `reset_qubit!(state,inputs)` | 原地重做量子位编码；批次传输入矩阵 |

方括号表示可选位置参数；`T` 用来选择元素类型，不是额外的必选参数。构造和随机函数的准确重载见逐项参考。

```julia
using MOSSQuantum, Random
ψ = onehot_encoding([1, 0])
@assert amplitude(ψ, [1, 0]; scaling=1) == 1
batch = batch_qubit_encoding([0.0 1.0; 0.0 0.0])
@assert size(storage(batch)) == (4, 2)
ρ = DensityMatrix(ψ)
@assert tr(ρ) ≈ 1
```

## 线性代数、距离与约化状态

| 函数 | 返回值与约定 |
| --- | --- |
| `norm(state)` | 纯态欧氏范数，混态为矩阵/存储范数；批次逐样本返回向量 |
| `dot(x,y)` | 纯态内积，混态 Hilbert–Schmidt 内积；批次逐样本返回向量 |
| `normalize!(state)` / `normalize(state)` | 原地/复制归一化；混态按迹归一化 |
| `tr(ρ)` | 密度矩阵迹；混态批次返回迹向量 |
| `ishermitian(ρ)` | 检查密度矩阵厄米性；也用于算符 |
| `fidelity(x,y)` | 已归一化状态的**平方 Uhlmann 保真度**；纯态为 `abs2(dot(x,y))`，不是平方根保真度 |
| `distance2(x,y)` / `distance(x,y)` | 存储内积诱导的平方距离/距离；不是迹距离；批次逐样本计算 |
| `permute(state,order::Vector{Int})` | 按量子位轴排列生成新状态；`order` 应为完整排列 |
| `schmidt_numbers(ρ::DensityMatrix)` | `Hermitian(storage(ρ))` 的特征值；不进行双体切分 |
| `renyi_entropy(ρ; α=1)` | 用密度矩阵特征值求 Rényi 熵；`α=1` 为 von Neumann 熵，以 2 为底的对数 |

```julia
partial_tr(state, sites::Vector{Int})
```

`sites` 是**被迹掉**的量子位，须唯一且在寄存器范围内。通常单状态返回 `DensityMatrix`；迹掉全部非零寄存器返回迹或范数平方。纯态批次返回 `Vector{DensityMatrix}`，混态批次返回 `BatchDensityMatrix`；迹掉全部量子位时返回每个样本的标量向量。空 `sites` 对单密度矩阵直接返回原对象，对纯态返回新混态，对混态批次返回复制。

详细所有权与数值约定见[约定](../conventions.md)，批次行为见[纯态批次](../batching.md)和[密度矩阵批次](../batch-density-matrices.md)。
