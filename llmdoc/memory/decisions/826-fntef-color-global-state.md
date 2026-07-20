# 决策: fntef+textcolor 组合时 hbox 内 interchar 全局状态污染

> **状态：已由 #992 / PR #999 替代。** 根因分析仍有效；当前
> `\xeCJK_fntef_sbox:n` 使用可嵌套 capture suspend/resume 隔离装饰符号
> 测量，同时保存、恢复 marker 与 source-space pending，不再手工只保存
> `\g_@@_last_node_tl`。

## 问题

`\textcolor{red}{\CJKunderdot{文字}}文字` 等 fntef+textcolor 组合在 fntef 效果后的 CJK 字符前产生多余的 CJKecglue（应为 CJKglue）。所有 6 种 fntef 效果（CJKunderdot、CJKunderline、CJKunderdblline、CJKunderwave、CJKsout、CJKxout）与 `\textcolor` 组合时均受影响。

## 根因

`\xeCJK_fntef_sbox:n` 通过 `\hbox_set:Nn` 渲染装饰符号（如 underdot 的 `.`）。hbox 内部的字符触发 XeTeX interchar toks，全局修改 `\g_@@_last_node_tl`（从 `CJK-space` 变为 `default`）。

当外层有 `\textcolor` 时，`\set@color` 补丁读取已被污染的 `\g_@@_last_node_tl`（值为 `default` 而非 `CJK-space`），用错误的节点类型重建 kern pair 标记。后续 `\@@_check_for_glue_skip:` 根据 `default` 标记走 ecglue 路径而非 CJKglue 路径。

## 方案

在 `\xeCJK_fntef_sbox:n` 的 `\hbox_set:Nn` 前后保存/恢复 `\g_@@_last_node_tl`：

```
\tl_set_eq:NN \l_@@_tmp_tl \g_@@_last_node_tl
\hbox_set:Nn \l_@@_fntef_box { \color_ensure_current: #1 }
\tl_gset_eq:NN \g_@@_last_node_tl \l_@@_tmp_tl
```

## 设计决策

- **隔离而非禁用 interchar**：hbox 内仍需要 interchar 正常工作（字体切换等），不能用 `\makexeCJKinactive`。正确做法是让 hbox 内的全局副作用不泄漏到外层。
- **确立通用模式**：任何通过 `\hbox_set:Nn` 渲染可能包含 CJK 字符的内容时，都应在 hbox 前后隔离 `\g_@@_last_node_tl`。`\xeCJK_fntef_sbox:n` 是第一个已知实例。
- **与 #826 的关系**：#826 修复的是 fntef 右侧 glue-on-kern-pair 的恢复逻辑（`\@@_check_for_glue_skip:`）。本修复解决的是更上游的问题——kern pair 标记本身就被错误重建，导致恢复逻辑即使正确也会选错路径。两者独立但互补。

## 测试覆盖

`xeCJK/testfiles/fntef-color01.lvt`：覆盖所有 6 种 fntef 效果与 `\textcolor` 的组合。Test 8 记录 `color-wraps-fntef`（`\textcolor` 包裹整个 fntef 命令）的当前行为作为基线——underline 类效果因 ulem hbox 宽度差异导致视觉宽度不一致，属于预存已知行为。

## 归属

commit `d458eb8c`，属于边界恢复状态机的第五类修复场景——hbox 内 interchar 全局状态泄漏。与 #315（whatsit）、#252/#476（ecglue 度量）、#324（宏路径 glue 遮蔽）、#826（glue-on-kern-pair）、#831（显式 `}` / textcolor / mbox 变体）并列。
