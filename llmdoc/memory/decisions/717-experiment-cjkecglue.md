# 决策: 将跨引擎 `CJKecglue` 统一接口保持为实验性

- 日期: 2026-05-03
- 关联: Issue #717

## 上下文

`ctex` 需要为“汉英文间胶长设定”提供一个统一入口，但各引擎后端并不存在完全同构的实现：XeTeX 通过 `xeCJK` 的 `CJKecglue` 处理，LuaTeX / upTeX 更接近 `xkanjiskip`，pdfTeX 则没有对应能力。

## 决策

1. 新增 `\ctexset{ experiment/CJKecglue = ... }`，而不是把 `CJKecglue` 直接放入 `ctex` 主 keypath。
2. 统一接口放在 `ctex / experiment` 子路径下，作为实验性命名空间的一部分。
3. 映射策略固定为：XeTeX 转发给 `xeCJK` 的 `CJKecglue`，LuaTeX / upTeX 写入 `xkanjiskip`，pdfTeX 输出不支持 warning。

## 理由

- pdfTeX 无法提供对应能力，无法把该接口承诺为全引擎正式一致语义。
- XeTeX 与 LuaTeX / upTeX 的底层参数模型不同，统一名字不等于统一底层契约。
- 先放入 `experiment/` 可让 `ctex` 暴露跨引擎入口，同时保留后续调整映射与语义边界的空间。

## 约束

- 后续新增类似“统一入口但后端能力不完全一致”的 key，应优先评估是否放入 `ctex / experiment` 子路径。
- 只有当多引擎行为、命名与预期长期稳定后，才考虑从 `experiment/` 提升到主 keypath。
- 维护者应把 `experiment/` 视为命名空间约束，而不是临时别名堆放区。
