---
name: 972-hyperref-end-annot-trusted-marker
description: 反思 #972 从普通 default 原型收敛到可信 hyperref-default 的过程，以及 start/end 固定点、组合回归和视觉证据的验证方法
metadata:
  type: reflection
---

# #972 hyperref 结束端可信 marker 反思

## 任务

修复加载 `hyperref` 后 `\url` 右侧 `CJKecglue` 从 3.33pt 变为 0pt 的问题，同时保留 #809/#810 对链接开始端欠恢复和过恢复的保护。

## 初始判断与不足

根因很快定位到 `\Hy@EndAnnot`：`url` 留下的 math 节点原本能触发 last-math 恢复，结束 annotation whatsit 把它遮蔽。首个原型在结束 whatsit 后直接放置普通 `default`，基本 MWE 立即恢复为 3.33pt，容易据此误判完成。

但普通 `default` 没有表达来源。当后续 CJK 被 `\textcolor` 或另一链接包装时，#810 的 `\Hy@BeginAnnot` 会刻意拒绝重放它，因为普通 `default` 可能是陈旧状态；基本 MWE 的修复因此不能组合。只测直接相邻字符证明了局部结果，没有证明边界状态能穿过真实宏包装。

## 收敛过程

最终新增 `hyperref-default`，只在顶层 `\Hy@EndAnnot` 调用原始实现前确实观察到 math 末节点时发布。它仍表达 Default-like 西文边界，但名称同时记录可信来源；颜色和下一 annotation 可以选择性转交它，普通 `default` 的 #810 排除规则不变。

这一过程也修正了 #809/#810 反思中过度泛化的“只 patch `\Hy@BeginAnnot`”：对入口状态污染，该结论正确；对输出末节点被结束 whatsit 遮蔽，结束端才拥有所需证据。补丁点应由发生状态变化的事件决定，不应按宏包选一个永久唯一入口。

## 验证方法

- 直接几何：链接与 `\nolinkurl` 总宽相等、左右边界对称、源码空格不叠加。
- 语义泛化：测试普通 math-ending `\href`，证明方案依赖真实节点而非公开 `\url` 名称。
- 组合消费：后续 CJK 分别经过 `\textcolor` 和另一 `\href`，验证可信 marker 穿过新增 whatsit。
- 反向保护：保留 #810 的 CJK-only link 用例，防止修欠恢复时重新引入过恢复。
- 基线稳定：把新 marker 声明追加到现有 marker 之后，避免改变旧数值；`loading01.tlg` 只增加新 dimension。
- 可视证据：同一 MWE 的 master/修复版并排图同时展示盒宽、右边界测量和肉眼间距。对可见排版缺陷，PR 只有数字表格仍不够完整，截图应与可执行 MWE 一起提供。

## 教训

- “状态值相同”不等于“状态来源同样可信”；若下游必须区分历史缓存与当前观察，专用 marker 比复用通用 marker 更安全。
- 一个 direct MWE 只能证明 producer→consumer 的最短路径；状态恢复补丁还要测试会插入节点的 wrapper consumer。
- 对欠恢复问题必须配套过恢复用例，反之亦然。
- 开始端和结束端不是互斥架构选择，而是不同事件的固定点；每个固定点只发布自己能证明的状态。
- 视觉排版修复的交付证据应包括 MWE、定量测量和前后渲染，三者分别证明可复现、可比较和可肉眼审查。

## 提升结果

- 稳定架构更新到 `llmdoc/architecture/xecjk-architecture.md` 与 `package-architecture.md`。
- 决策记录为 [[../../decisions/972-hyperref-end-annot-trusted-marker]]。
- 跨任务规则提升到 `llmdoc/memory/lessons-learned.md`，本反思因此直接归档。
