---
name: "746-remove-legacy-font-hooks"
description: "决策: 移除 ctex 和 xeCJK 中对 LaTeX < 2020/10/01 的字体钩子兼容代码，响应上游移除 \\@rmfamilyhook"
type: decision
---

## 问题

Issue #746: LaTeX 团队（Frank Mittelbach）通知即将移除 `\@rmfamilyhook`、`\@sffamilyhook`、`\@ttfamilyhook` 和 `\@defaultfamilyhook` 的兼容定义。

## 现状分析

ctex 和 xeCJK 已通过版本检测在 LaTeX >= 2020/10/01 下走新钩子路径，旧代码路径不会被触发：

- **ctex**: `\cs_if_exist:NTF \ctex_gadd_ltxhook:nn` 门控，新路径使用 `\hook_gput_code:nnn`
- **xeCJK**: `\ctex_if_format_at_least:nTF { 2020/10/01 }` 门控，新路径使用 `\ctex_gadd_ltxhook:nn`

**Why:** 旧代码虽不影响运行，但作为死代码会误导维护者，且随上游变更可能引发困惑。

## 决策

移除旧兼容代码，仅保留新钩子路径。

**Breaking change**: 不再支持 LaTeX < 2020/10/01。

### ctex 侧

- 移除 `\@@_provide_font_hook_aux:NNNN` 的旧回退分支（直接操作 `\@rmfamilyhook` 或 patch `\rmfamily`）
- 保留 `\ctex_provide_font_hook:NNN` 接口不变（`\@rmfamilyhook` 参数仍用于构造 `\CTEX@rmfamilyhook` 名称）

### xeCJK 侧

- 移除 `\ctex_if_format_at_least:nTF { 2020/10/01 }` 的 false 分支（含 `\@rmfamilyhook` 路径和 `\fontfamily` 重定义路径约 40 行）
- 移除不再需要的 `\xeCJK@fontfamily` 和 `\@@_update_family_aux:`

**How to apply:** 后续涉及 LaTeX 内核钩子变更时，可直接引用新 hook API，无需考虑旧回退路径。
