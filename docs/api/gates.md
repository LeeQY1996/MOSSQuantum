# 门、电路、通道与算符

[API 目录](../api.md) · [逐项参考](reference.md)

## 门类型与矩阵

`AbstractInstruction` 是可执行指令协议。`Gate{N}` 是 `N` 量子位门，`ParametricGate{N}` 增加数值参数接口。门中的位置使用 1 起始编号，`positions(g)` 的第一个位置是局部矩阵的最低有效位。门的数值角度使用弧度。

| 构造形式 | 参数和行为 | 返回值 |
| --- | --- | --- |
| `XGate(i)`, `YGate(i)`, `ZGate(i)` | 在位置 `i` 放置 Pauli 门 | 相应门对象 |
| `HGate(i)`, `SGate(i)`, `TGate(i)` | Hadamard、π/2 相位、π/4 相位 | 相应门对象 |
| `sqrtXGate(i)`, `sqrtYGate(i)` | X/Y 的平方根门 | 相应门对象 |
| `RxGate(i,θ; isparas=false)`, `RyGate(...)`, `RzGate(...)` | 绕轴旋转；`isparas=true` 纳入活动参数 | 参数门 |
| `PHASEGate(i,θ; isparas=false)` | 单比特相位门 | 参数门 |
| `SWAPGate(a,b)`, `iSWAPGate(a,b)` | 交换、含相位交换 | 双比特门 |
| `CNOTGate(control,target)`, `CZGate(control,target)` | 控制 X、控制 Z；也支持命名 `control`/`target` | 双比特门 |
| `CONTROLGate(control,target,U)` | `U` 是目标位的 `2×2` 矩阵 | 受控门 |
| `CRxGate(c,t,θ; isparas=false)`, `CRyGate(...)`, `CRzGate(...)`, `CPHASEGate(...)` | 受控旋转/相位 | 双比特参数门 |
| `FSIMGate(a,b,[θ,φ,δp,δm,δmoff]; isparas=fill(false,5))` | 五参数广义 FSim；活动标记逐参数设置 | 双比特参数门 |
| `TOFFOLIGate(c1,c2,t)` | 双控制 X | 三比特门 |
| `FREDKINGate(c,a,b)` | 受控交换 | 三比特门 |
| `CONTROLCONTROLGate(c1,c2,t,U)` | 双控制目标矩阵 | 三比特门 |
| `CCPHASEGate(c1,c2,t,θ,isparas=true)` | 双控制相位；此位置参数形式默认活动 | 三比特参数门 |
| `QuantumGate(positions,U)` / `gate(positions,U)` | 任意 `2^N×2^N` 局部门矩阵；位置为整数/元组/向量 | 通用门对象 |
| `AdjointQuantumGate(g)` / `g'` | 共轭转置门包装；保留参数相关信息 | 伴随门 |

命名参数形式 `RyGate(i; θ=θ)` 等还接受符号参数，详见[参数](parameters.md)。门矩阵接口本身不保证每个后端都能执行。

`H`、`X`、`Y`、`Z`、`S`、`T`、`CNOT`、`CZ`、`SWAP` 是已导出的矩阵常量，不带位置；`Rx(θ)`、`Ry(θ)`、`Rz(θ)` 返回 `2×2` 矩阵。执行电路使用相应的 `...Gate`。

| 接口 | 结果 |
| --- | --- |
| `nqubits(g)` / `positions(g)` | 局部门位数/有序位置集合 |
| `mat(g)` | 按原始位置顺序的局部门矩阵 |
| `ordered_positions(g)` / `ordered_mat(g)` | 升序位置/同步重排后的矩阵 |
| `change_positions(g,mapping::AbstractDict)` | 根据旧位置到新位置的字典生成重定位指令 |
| `shift(g,offset::Int)` | 全部位置平移 `offset` 的新指令 |
| `differentiate(g)` | 活动参数顺序的导数门；CPU 旧反传约定为 `(∂U/∂θ)'U`，不是直接 `∂U/∂θ` |
| `validate_positions(operation,n)` | 验证寄存器位置；非法位置/重复位置报错 |

## 电路与中间指令

```julia
QCircuit()
QCircuit(ops; copy=false)
QCircuit(circuit::QCircuit; copy=true)
QMeasure(position; auto_reset=true, keep=true, key=nothing)
QSelect(position, state=0)
```

`QCircuit` 保存有序指令序列，允许嵌套电路。`push!`、`append!`、`empty!` 返回被修改电路。复制电路容器仍共享指令；`copy_instruction(circuit)` 才递归复制可变指令数据。

`QMeasure` 进行计算基测量，`auto_reset=true` 时测后复位零态；`key` 为经典位名；`keep=false` 的移除量子位方式仅适用于相应非原地路径。`QSelect` 固定选择 0 或 1。在 `execute` 中它消耗尝试次数并拒绝不符合的 shot。不要把接受数当成请求尝试数。

```julia
using MOSSQuantum
bell = QCircuit([HGate(1), CNOTGate(1, 2)])
ψ = bell * StateVector(2)  # 输入状态保持独立
ψ = apply!(AmplitudeDamping(1; γ=0.1), ψ)  # 接住可能改变类型的返回值
@assert ψ isa DensityMatrix
```

## Kraus 通道

```julia
QuantumMap(positions, kraus_matrices; check_tp=false, atol=nothing)
```

通道表示 `ρ ↦ Σ KᵢρKᵢ†`。`positions` 规定局部矩阵位顺序；Kraus 矩阵维度必须匹配。需要物理保迹噪声时设置 `check_tp=true`；通用 `QuantumMap` 也允许非保迹 CP 映射。`AbstractQuantumMap` 为扩展抽象协议；`kraus_matrices(map)` 返回 Kraus 数据，`is_tp(map; atol=...)` 检查保迹，`ordered_supermat(map)` 返回按升序量子位排列的超算符矩阵。

| 构造 | 含义与限制 |
| --- | --- |
| `AmplitudeDamping(i; γ)` | 振幅阻尼，`0≤γ≤1` |
| `PhaseDamping(i; γ)` | 相干项乘 `sqrt(1-γ)`，不是直接乘 `1-γ` |
| `BitFlip(i; p)` / `PhaseFlip(i; p)` / `BitPhaseFlip(i; p)` | 分别以 `p` 施加 X/Z/Y，`0≤p≤1` |
| `PauliChannel(pos,words,probabilities)` | 一或二比特 Pauli 混合；字符串字符与位置逐一对应；概率和为一 |
| `MixedUnitary(pos,unitaries,probabilities)` | 酉矩阵的概率混合，输入须有限且概率非负、和为一 |
| `Depolarizing(pos; p)` | 一或二比特 `(1-p)ρ+p*tr(ρ)I/d`；允许 `p≤4^N/(4^N-1)` |
| `GeneralizedAmplitudeDamping(i; γ,excited_population=0)` | 有限温度振幅阻尼，平衡激发态布居在 `[0,1]` |
| `ResetChannel(i; state=0,p=1)` | 以 `p` 重置到指定 0/1 状态 |
| `ThermalRelaxation(i; T1,T2,duration,excited_population=0)` | 使用统一时间单位，`T1,T2>0`、`T2≤2T1`、`duration≥0`；允许正无穷寿命 |

以上噪声构造返回经过保迹检查的 `QuantumMap`。默认密度演化会把纯态/纯态批次转成混态；随机纯态噪声轨迹通过 `execute(...; method=KrausTrajectory())` 选择。

## 算符

```julia
QubitsTerm(1=>"Z", 2=>"Z"; coeff=1)
QubitsOperator(terms...)
```

`QubitsTerm` 是系数乘局部算符张量积，局部项可用名字或 `2×2` 矩阵；`QubitsOperator` 是项的和，支持常数项、零、加减乘法和伴随。算符是观测量，不是 `QCircuit` 指令。

`oplist(term)` 取局部矩阵列表，`coeff(term)` 取系数；`matrix(observable)` / `matrix(n,observable)` 构造完整稠密矩阵（内存随寄存器指数增长），`simplify(operator; atol=...)` 合并等价项/删除小项，返回简化算符。`expectation(O,state)` 对纯态返回 `⟨ψ|O|ψ⟩`，对混态返回 `tr(Oρ)`，批次返回每个样本一项；`expectation(left,O,right)` 计算双边纯态矩阵元。

完整算符代数、测量分组见[算符与测量指南](../operators-and-measurement.md)。
