# 决策: 不在 ctex 侧修复 cleveref appendix 语义问题

- 日期: 2026-04-24
- 关联: Issue #725, PR #772, 分支 fix/725-cleveref-patch-toggle

## 上下文

LaTeX2e 2024-11-01 后，firstaid 的 `\firstaid@cref@updatelabeldata` 缺少 appendix 特判，导致 cleveref 在 appendix 后的引用类型退化（`appendix` -> `chapter`）。该问题在不加载 ctex 的纯 `book + hyperref + cleveref` 环境中同样复现。

上游 `latex2e#2049` 明确表示不会在 firstaid 中完整修复此问题，cleveref 自 CTAN 0.21.4 以来长期无人维护。

## 决策

1. 不在 ctex 侧为 appendix 语义问题打补丁（非 ctex 职责范围）。
2. 新增 `\ctexset{ patch/cleveref = false }` 开关，让用户在补丁产生副作用时可以关闭。
3. 保留原有 cleveref 补丁（`\expandafter` 注入）默认开启，因为该补丁解决的核心展开问题仍然有效。

## 理由

- cleveref appendix 问题的根因在 LaTeX2e firstaid 层，不属于 ctex 的兼容职责。
- 为用户需求无法预期的组合提供退路（开关），优于继续堆叠复杂的上游补丁。
- 上游无人修复意味着该问题可能长期存在，ctex 不应承担无限维护成本。
