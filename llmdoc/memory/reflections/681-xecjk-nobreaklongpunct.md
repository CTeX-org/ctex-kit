---
title: "681: xeCJK NoBreakLongPunct 断行修复"
type: reflection
---

# 681: xeCJK NoBreakLongPunct 断行修复

## 问题

issue #681 反映 XeLaTeX/xeCJK 下省略号（`‥`、`…`）会被允许出现在行首。原有实现虽然把省略号放在 `LongPunct` 集合内，用于长标点挤压与间距计算，但没有把“长标点可压缩”与“长标点禁止行首”这两个语义拆开，导致省略号沿着普通断行路径继承了可在行首出现的行为。

## 最终方案

修复方案不是把省略号从 `LongPunct` 中移除，而是新增独立属性 `NoBreakLongPunct`：

- 省略号仍保留在 `LongPunct` 中，继续参与既有的长标点度量与挤压逻辑。
- 同时把省略号标记为 `NoBreakLongPunct`，把“禁止行首断开”作为额外语义单独建模。
- 新增用户键：`NoBreakLongPunct`、`NoBreakLongPunct+`、`NoBreakLongPunct-`，允许用户调整默认集合。

这样做避免了把一类字符从既有分类中硬拆出去，也避免为了个别字符复制整套长标点逻辑。

## 修改路径

本次修复需要同时覆盖 3 条断行相关路径：

1. `CJK → FullRight`
2. `Default → FullRight`
3. `punct_kern`

教训是：xeCJK 的断行控制并不集中在单一点上。若只补其中一条路径，省略号仍可能在另一路径上泄漏出可断行行为。处理标点断行问题时，必须按字符类别迁移路径把相关分支全部检查一遍，而不能只修表层 penalty。

## 测试与回归信号

本次新增 `xeCJK/testfiles/ellipsis01.lvt` 作为专项回归测试，用来锁定省略号相关行为。与此同时，`ctex/test/testfiles/punct.tlg` 的基线也发生了可观察变化：省略号前的 penalty 从 `0` 变为 `10000`。这类基线变化说明：

- `ctex` 侧集成测试仍会反映 xeCJK 标点行为的外部可见结果；
- 但具体字符分类与断行语义更适合在 `xeCJK/testfiles/` 中建立更聚焦的最小复现测试。

## 经验

- **字符分类与断行策略要分层建模**：`LongPunct` 负责长标点行为，不应顺手承担“是否允许行首”这类独立语义。
- **优先新增属性而不是破坏旧分类**：若一个字符需要“保留既有行为 + 额外约束”，优先加正交属性，避免回归到大量条件分支复制。
- **xeCJK 标点问题经常有多条 token/类别路径**：排查时至少要检查 `CJK`、`Default` 与 kerning 相关路径是否都一致处理。
- **基线中的 penalty 变化是重要诊断信号**：从 `0` 到 `10000` 这种变化可以直接说明断行许可状态发生了本质改变。
