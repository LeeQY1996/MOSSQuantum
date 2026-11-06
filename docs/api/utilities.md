# `MOSSQuantum.Utilities` 实用函数

[API 目录](../api.md) · [逐项参考](reference.md)

```julia
using MOSSQuantum
using MOSSQuantum.Utilities
```

这些函数在 `Utilities` 子模块导出；两个变分电路构造也在包顶层导出。

## 自旋 Hamiltonian

```julia
heisenberg_1d(L::Int; J=1.0,Jzz=J,hz=0.0)
heisenberg_2d(m::Int,n::Int=m; J=1.0,Jzz=J,hz=0.0)
heisenberg_2d((m,n); kwargs...)
ising_1d(L::Int; J=1.0,hz=1.0)
ising_2d(m::Int,n::Int=m; J=1.0,hz=1.0)
ising_2d((m,n); kwargs...)
```

返回简化后的 `QubitsOperator`，使用开放边界、最近邻耦合。Heisenberg 的键项为 `J(XX+YY)+Jzz ZZ`、场项为 `hz Z`。Ising 的键项为 `J XX`、场项为 `hz Z`；符号没有隐含负号或自旋 `1/2` 因子。二维格点用 Julia `LinearIndices((m,n))` 的列主序编号。

## 基态、演化与门融合

| 调用 | 参数与返回值 |
| --- | --- |
| `ground_state(h::QubitsOperator; kwargs...)` | 要求厄米 Hamiltonian，KrylovKit 求最低实部本征对，返回 `(energy,StateVector)`；额外关键词传给 `eigsolve`，不收敛报错 |
| `time_evolution(h,t,state; kwargs...)` | 纯态计算 `exp(tH)ψ`，混态计算 `exp(tH)ρexp(conj(t)H)`，返回新状态；Hamiltonian 须厄米；额外关键词传给 KrylovKit |
| `trotter_propagator(h,t; order=2,stepsize=abs(t))` | 返回近似 `exp(tH)` 的电路 |
| `trotter_propagator(h,(ti,tf); order=2,stepsize=0.01)` | 在给定参数区间构造传播电路；`order` 必须是至少 2 的正偶数 |
| `fuse_gates(circuit; max_qubits=5)` | 返回融合相邻可合并门后的电路，受 `max_qubits` 限制；不是所有动态/噪声指令的通用优化器 |

物理时间 `τ`、`ℏ=1` 时传 `t=-im*τ`；实数 `t` 是未归一化虚时间映射，返回值不会自动归一化。稠密状态和矩阵的内存随量子位数指数增长。

```julia
h = ising_1d(3; J=1.0, hz=0.5)
energy, ground = ground_state(h)
ψ = time_evolution(h, -0.1im, StateVector(3))
c = trotter_propagator(h, -0.1im)
ψapprox = c * StateVector(3)
```

## 变分电路

```julia
variational_circuit_1d(L::Int,depth::Int; θs=...)
real_variational_circuit_1d(L::Int,depth::Int; θs=...)
```

返回活动参数已启用的 `QCircuit`，每层采用方向交替的最近邻 CNOT 链。

`variational_circuit_1d` 使用逐位 `Rz–Ry–Rz` 块，参数数为 `3L(depth+1)`；实变体只用 `Ry`，参数数为 `L(depth+1)`。显式 `θs::Vector{<:Real}` 长度必须完全匹配；不提供时从全局默认 RNG 在 `[0,2π)` 抽取，因此需要复现时自行生成 `θs`。

```julia
using Random
rng = MersenneTwister(42)
c = real_variational_circuit_1d(3, 2; θs=2π .* rand(rng, 9))
@assert nparameters(c) == 9
```

QFT、Shor 等算法演示在独立 [MOSSAlgorithmZoo](https://github.com/LeeQY1996/MOSSAlgorithmZoo) 仓库维护。
