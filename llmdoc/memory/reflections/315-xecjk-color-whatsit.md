---
name: 315-xecjk-color-whatsit
description: xeCJK #315 修复反思：当 \special 插入 whatsit 节点时，不能只依赖 \lastkern 检测边界标记，必须保留可跨 whatsit 恢复 glue 的状态
type: reflection
---

## 任务

修复 xeCJK issue #315：在 `\textcolor`、`color`/`xcolor` 等颜色命令包裹文本后，CJK 与 Latin 或 CJK 与 CJK 边界上的 `CJKecglue` / `CJKglue` 消失，导致中文与数字、英文或相邻中文之间的间距异常收缩。

## 根因

问题的直接触发器不是颜色命令本身，而是它在节点链中插入的 `\special{color push/pop}`。这些 `\special` 会生成 whatsit 节点，使 `\lastnodetype = 9`。

xeCJK 旧实现把“上一边界上是否刚刚插入过内部标记”主要编码在 `\lastkern` 上：

- 在 `\xeCJK_make_node:n` 时插入特定标记 kern
- 在 `\@@_check_for_ecglue:` 或 `\xeCJK_check_for_glue:` 中通过 `\lastkern` 判断边界类型
- 命中后再恢复 `CJKecglue` 或 `CJKglue`

这条设计默认“边界标记 kern 会紧邻当前待处理位置”。一旦中间夹入 whatsit，`\lastkern` 就看不到原先的标记 kern，于是 Boundary→Default 和 Boundary→CJK 这两类过渡上的 glue 恢复链会失效。

关键心智模型是：whatsit 节点不会改变字符类别，但会改变“最后一个可检查节点”的可见性，因此它破坏的是 xeCJK 的状态恢复观测方式，而不是 interchar 分类本身。

## 修复

修复没有试图让 whatsit 变得“透明”，而是给原有的边界恢复机制补上一条显式回退路径：

1. 新增全局变量 `\g_@@_last_node_tl`，在 `\xeCJK_make_node:n` 时同步记录刚刚创建的内部标记类型。
2. 新增 `\@@_if_last_whatsit:TF`，用 `\lastnodetype = 9` 检测上一节点是否为 whatsit。
3. 新增 `\@@_recover_ecglue_whatsit:` 与 `\@@_recover_glue_whatsit:`，当常规 `\lastkern` 检测失败但上一节点是 whatsit 时，通过 `\g_@@_last_node_tl` 回看前一个边界标记类型，决定是否补回 `CJKecglue` / `CJKglue`。
4. 在 `\@@_check_for_ecglue:` 与 `\xeCJK_check_for_glue:` 的标准检测链末尾追加上述 whatsit 回退。
5. 在 `\xeCJK_remove_node:` 清空 `\g_@@_last_node_tl`，避免保存的边界类型跨越后续无关节点而误判。

因此，修复后的机制应理解为“两层检测”：

- 正常路径：仍优先依赖 `\lastkern`，成本低且保持旧行为。
- 异常路径：若最后节点是 whatsit，则从保存的边界类型回退恢复 glue。

## 测试策略

新增 `xeCJK/testfiles/color01.lvt`，用盒子宽度不变性测试验证 whatsit 回退机制。测试覆盖 5 个场景：

1. `\textcolor` 包裹纯 Default 内容（`文AB字`）时，左右两侧 `CJKecglue` 保持不变。
2. `\textcolor` 包裹单个 CJK 内容（`文字文`）时，左右 `CJKglue` 保持不变。
3. `\textcolor` 包裹单个数字（`终于3岁`）时，确认最初复现案例中的两侧 `CJKecglue` 恢复。
4. `\textcolor` 包裹混合 Latin 内容（`中word中`）时，确认多字符 Default 串不会破坏边界恢复。
5. 嵌套 `\textcolor` 颜色组时，确认多个 whatsit 连续出现也不会打断恢复链。

这里依然优先用盒子宽度对比，而不是只做节点 dump。原因是 issue #315 的用户可见症状本质上就是“有无恢复到正确 glue 宽度”；只要包裹颜色后的盒子宽度与未包裹版本完全一致，就能稳定验证 glue 恢复链在用户层面成立，同时避免测试日志对节点细节过度耦合。

## 影响范围

虽然直接复现来自 `xcolor` / `color`，但这次修复实际上覆盖了所有“通过 `\special` 在边界标记与当前字符之间插入 whatsit”的场景，例如超链接、PDF 注解等。ctex 的 beamer 回归基线更新正是这一点的旁证：修复后，超链接注解 whatsit 后面的 `CJKglue` 会重新出现，因此日志与旧基线不同是预期结果。

## 教训

- 遇到 xeCJK 间距丢失问题时，不要只看字符类和 glue 参数；任何会在节点链里插入 whatsit 的机制都可能让基于 `\lastkern` 的检测失效。
- 对 node-level 状态机来说，“上一节点是什么”与“上一次保存的边界类型是什么”是两个不同概念；当 TeX 原语只能观测到最后一个节点时，必要时要自己额外保存状态。
- 回归测试应覆盖“单个颜色组”和“嵌套颜色组”两层，因为后一类更容易暴露多个 whatsit 连续出现时的状态覆盖问题。
