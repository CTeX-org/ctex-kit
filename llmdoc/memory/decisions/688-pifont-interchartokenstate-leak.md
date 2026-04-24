---
name: "688-pifont-interchartokenstate-leak"
description: "决策: pifont hook 中 \\Pifont 在 \\makexeCJKinactive 前先进入水平模式，防止垂直模式下局部赋值通过分页泄漏到输出例程"
type: decision
---

## 问题

Issue #688: 使用 `\ding` 等 pifont 命令时，特定分页组合下页眉页脚中文不显示。

## 根因

xeCJK 对 pifont 的兼容 hook 中，`\Pifont` 被重定义为：

```tex
\RenewDocumentCommand \Pifont { m }
  { \makexeCJKinactive \usefont { U } {#1} { m } { n } }
```

`\makexeCJKinactive` 执行 `\XeTeXinterchartokenstate = 0`（局部赋值）。当 `\ding` 位于段首（仍处于垂直模式）时：

1. `\makexeCJKinactive` 在垂直模式下将 interchartokenstate 设为 0
2. `\usefont` 选择字体但不进入水平模式
3. `\char"B7` 触发隐式 `\leavevmode` 进入水平模式
4. 若此时发生分页，输出例程在 `\XeTeXinterchartokenstate = 0` 下运行
5. 页眉页脚中的 CJK 字符失去 interchar token 处理，导致中文不显示

## 决策

在 `\makexeCJKinactive` 前插入 `\mode_leave_vertical:`：

```tex
\RenewDocumentCommand \Pifont { m }
  { \mode_leave_vertical: \makexeCJKinactive \usefont { U } {#1} { m } { n } }
```

**Why:** 先进入水平模式可确保任何由 `\leavevmode` 触发的分页发生在 `\XeTeXinterchartokenstate` 被修改之前，输出例程始终在 state=1 下运行。

**How to apply:** xeCJK 中所有在垂直模式可能被调用且包含 `\makexeCJKinactive` 的命令，都应在禁用 xeCJK 前先确保进入水平模式。

## 回归测试

`xeCJK/testfiles/pifont01.lvt`:
- TEST 1-2: 验证 `\ding` / `\Pisymbol` 前后 `\XeTeXinterchartokenstate` 恢复为 1
- TEST 3: 拦截 `\makexeCJKinactive`，验证在垂直模式起始的 `\ding` 调用中，`\makexeCJKinactive` 被调用时已处于水平模式（旧代码返回 vmode，修复后返回 hmode）

## 影响范围

- 仅影响 xeCJK（XeTeX 路径）
- 改动位于 `xeCJK/xeCJK.dtx` 的 pifont hook 区段
- 不影响 ctex 的其他引擎路径
