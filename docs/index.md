# MOSSQuantum 文档

<img src="assets/brand/moss-qubit-grid.png" alt="MOSS 家族展示图标" width="200">

量子线路、稠密状态模拟、参数绑定、噪声、采样和梯度。

[API 与函数索引](api.md) · [安装与快速开始](../README.md) · [GitHub 仓库](https://github.com/LeeQY1996/MOSSQuantum) · [图标与品牌素材](branding.md)

## 使用这份参考

先从 API 索引按功能查找类型或函数，再查看真实签名、参数、返回值、示例和能力限制。Julia 标识保持原名；说明以中文为主。左侧搜索支持函数名和正文关键词。

本网站由当前默认分支的 Markdown 构建，不是按发行版本冻结的文档。精确行为以同一提交的源码为准，函数条目可从页底返回源文件。

## MOSS 家族

| 文档站点 | 仓库 |
| --- | --- |
| [MOSSQuantum](https://leeqy1996.github.io/MOSSQuantum/) | [GitHub](https://github.com/LeeQY1996/MOSSQuantum) |
| [MOSSMPS](https://leeqy1996.github.io/MOSSMPS/) | [GitHub](https://github.com/LeeQY1996/MOSSMPS) |
| [MOSSStabilizer](https://leeqy1996.github.io/MOSSStabilizer/) | [GitHub](https://github.com/LeeQY1996/MOSSStabilizer) |
| [MOSSChemistry](https://leeqy1996.github.io/MOSSChemistry/) | [GitHub](https://github.com/LeeQY1996/MOSSChemistry) |
| [MOSSFragmentTN](https://leeqy1996.github.io/MOSSFragmentTN/) | [GitHub](https://github.com/LeeQY1996/MOSSFragmentTN) |
| [MOSSGPU](https://leeqy1996.github.io/MOSSGPU/) | [GitHub](https://github.com/LeeQY1996/MOSSGPU) |
| [MOSSAlgorithmZoo](https://leeqy1996.github.io/MOSSAlgorithmZoo/) | [GitHub](https://github.com/LeeQY1996/MOSSAlgorithmZoo) |

仅核心包 `MOSSQuantum` 的名称保留 `Quantum`；其余库包使用 `MOSSMPS`、`MOSSStabilizer`、`MOSSChemistry`、`MOSSFragmentTN` 和 `MOSSGPU`，Julia 包名与仓库名保持一致。`MOSSAlgorithmZoo` 是案例集合，按脚本加载，不是独立 Julia 库。

## 文档范围

参考描述当前实现，不将规划功能视作已有能力。随机、有限采样、数值截断、外部 Python 环境和 GPU 硬件等要求在相应条目中说明。[文档维护](BUILDING.md) 介绍本地构建与自动发布。
