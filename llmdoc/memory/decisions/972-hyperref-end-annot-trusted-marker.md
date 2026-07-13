---
name: "972-hyperref-end-annot-trusted-marker"
description: "决策: #972 在顶层 Hy@EndAnnot 观察真实末尾 math 后发布专用 hyperref-default，区分可信输出边界与 #810 排除的陈旧普通 default"
metadata:
  type: decision
---

# 决策：#972 用结束端可信 marker 恢复链接 URL 右侧 ecglue

## 背景

`url` 的 `\Url@FormatString` 以 math 模式排版 URL；单独加载 `url` 时，后续 CJK 字符可直接观察末尾 math 节点并恢复右侧 `CJKecglue`。`hyperref` 在内容后调用 `\Hy@EndAnnot`，其 end-annotation/color whatsit 遮蔽 math 节点，使 #972 的右侧间距变为 0pt。

#809/#810 已在 `\Hy@BeginAnnot` 进入端保存/清空/选择性重放状态，并刻意拒绝普通 `default`，因为它可能是历史残留。该进入端补丁无法证明链接内容最后是什么，也无法穿过结束 whatsit 恢复 #972。

## 候选方案

**方案 A（采纳）**：在顶层 `\Hy@EndAnnot` 调用原始实现前检查最后节点；若为 math，则在结束 whatsit 后发布专用 `hyperref-default`，并让既有 kern/source-space/whatsit 恢复链识别该标记。

**方案 B（原型后否决）**：结束 whatsit 后重放普通 `default`。

**方案 C（否决）**：把所有 `\Hy@EndAnnot` 都视为 Default 边界，或重新允许 `\Hy@BeginAnnot` 重放普通 `default`。

## 决策

采纳方案 A。

## 理由

- `hyperref-default` 的发布条件同时要求 `\c@Hy@AnnotLevel = 1` 和真实末尾 math；它是对可见输出边界的证据，不是任意 annotation 结束的猜测。
- 方案 B 可修直接 MWE，但当后续 CJK 被 `\textcolor` 或另一链接包装时，`\Hy@BeginAnnot` 会按 #810 正确拒绝普通 `default`，边界再次丢失。专用 marker 允许这些已知 wrapper 只转交可信状态。
- 方案 C 会重新引入 #810 的过恢复风险，并可能把 CJK-ending link 误分类为西文边界。
- 只在 annotation level 1 发布，避免嵌套 annotation 的内部结束点提前改写外层链接状态。
- 新 marker 声明追加在既有声明之后，避免改变旧 marker 的数值和无关 `.tlg` 基线。

## 测试约束

同一回归文件必须同时保留 #809/#810 的欠恢复/过恢复用例，并覆盖 #972 的链接与非链接 URL 等宽、左右对称、源码空格吸收、通用 math-ending link、后续颜色切换和后续 annotation。宽度比较证明几何结果，组合用例证明可信状态能跨 wrapper 且普通陈旧状态仍被拒绝。

## 落地引用

- 实现：`xeCJK/xeCJK.dtx`（`\@@_patch_hyperref_annot:`、`hyperref-default` marker 及三条恢复路径），commit `20b3bce7`。
- 回归：`xeCJK/testfiles/hyperref-ecglue01.lvt` / `.tlg`、`loading01.tlg`。
- 架构：[[../../architecture/xecjk-architecture]]。
- 反思：[[../archive/2026-07-13/972-hyperref-end-annot-trusted-marker]] 与 [[../reflections/809-810-hyperref-annot-ecglue]]。
