---
name: "873-880-fixed-point-vs-default-narrowing"
description: "决策: #873 / #880 选 input-side fixed-point patch（save/replay 与 drain），不选收窄 \\@@_recover_glue_whatsit: default 分支——修复位置由被遮蔽的节点类型决定，与 marker 类型无关"
metadata:
  type: decision
---

# 决策：#873 / #880 选 input-side fixed-point patch 而非“收窄 default 分支”

> **状态：已由 #992 / PR #999 替代。** 本文保留当时选择 save/replay 与
> drain 的历史依据；当前 `\HD@target` 使用 transparent capture，完整
> `\Url@z` 与 codedoc/doc meta 使用 stream capture，旧 helper 和通用
> whatsit 恢复猜测均已删除。

## 背景

#873（`\meta` 后 CJK 丢 ecglue）与 #880（`\url` 后 CJK 丢 ecglue）根因相同：xeCJK 边界恢复链通过 `\tex_lastkern:D` 判断 marker，但被中间节点遮蔽（#873 是 `\HD@target` 的 0x0 hbox，#880 是 `\Url@FormatString` 的 math 模式）。曾考虑两条修复路径。

## 候选方案

**方案 A（采纳）**：在调用方入口下 fixed-point patch。

- #873 → save/replay `\g_@@_last_node_tl`
- #880 → drain marker + 直接补 ecglue

**方案 B（未采纳）**：仿 PR #831 给 `\@@_recover_glue_whatsit:` 的 default 兜底分支加 pending boolean gate，只在已知调用方（`\set@color` / `\HD@target` / `\Url@FormatString`）显式置位时才允许 default 分支吐 ecglue。

## 决策

采纳方案 A。

## 理由

- #873 走的是 boundary check 的 hbox else 分支，根本不进 `\@@_recover_glue_whatsit:`。
- #880 在 math 模式下 marker 已被吃掉，更进不去 whatsit 恢复链。
- 收窄 default 分支是另一类问题——“防御任意第三方 whatsit 误触发”。它与 #873 / #880 的根因正交。
- **核心规律**：修复位置取决于“被遮蔽的节点类型”，不取决于 marker 类型。详见 [[../../architecture/xecjk-architecture]] 中“边界恢复修复点选择矩阵”。

## 后续

若未来要落“收窄 `\@@_recover_glue_whatsit:` default 分支”的独立 PR，动机应是“防御任意 whatsit 误触发”而非“修 #873 / #880 副作用”——两个目标完全不同。

## 落地引用

- 实现：`xeCJK/xeCJK.dtx` `\@@_patch_hd_target:` / `\@@_patch_url_format:`（commit `7c3a2c2e`）。
- 回归测试：`xeCJK/testfiles/hypdoc-ecglue01.lvt` / `url-ecglue01.lvt`。
- 反思：[[../reflections/873-880-meta-url-hbox-math-boundary]]。
