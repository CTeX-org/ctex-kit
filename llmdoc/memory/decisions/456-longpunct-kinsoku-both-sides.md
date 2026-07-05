---
name: "456-longpunct-kinsoku-both-sides"
description: "决策: #456 长标点与其他标点相邻断点改为两侧禁则联合判断，而非只检查一侧或新增 penalty 类机制; 决策树落在既有 \\@@_punct_kern:NN 内新增辅助函数 \\@@_punct_kern_break:NN, 不引入新的字符类/special punct 属性"
metadata:
  type: decision
---

# 决策：#456 长标点断点改为两侧禁则联合判断，落在既有 `\@@_punct_kern:NN` 内

## 背景

v3.6.0（2018/01/23）起，`\@@_punct_kern:NN` 对"长标点（`LongPunct`）与其他标点相邻"的断点策略是"只要一侧是长标点就总允许折行"。v3.10.0（2026/04/27）为 `NoBreakLongPunct`（见 #681）在**右侧**时补了一次修正，但只覆盖了"右侧是长标点"这一支下的 `NoBreakLongPunct` 检查，未覆盖"左侧是长标点、右侧是 `NoBreakLongPunct`"的组合，也完全未检查断点左侧是否有全角左标点悬空、右侧是否有全角右标点落首的一般禁则。三类实际违规见 [[456-longpunct-kinsoku-both-sides]] 反思与架构文档 `xeCJK-architecture.md` 长标点断点小节。

## 决策 1：改为"两侧禁则必须同时满足才 breakable"，而非新增字符类或 special punct 属性

备选方案包括：仿照 #681 的 `NoBreakLongPunct` 模式，为"左侧长标点+右侧全角右标点"再新增一个正交 special punct 属性；或者引入类似 #811 的 penalty 类机制单独处理长标点与特定类的过渡。

**采纳方案**：不新增字符类或属性，直接重写 `\@@_punct_kern:NN` 的决策树，新增内部辅助函数 `\@@_punct_kern_break:NN` 承载"断点两侧联合判断"逻辑：

- 外层先用 `\bool_lazy_or:nnTF { long_p #1 } { long_p #2 }` 保留原有的"两侧都不是长标点"时的 nobreak 快速路径；
- 只要有一侧是长标点，进入 `\@@_punct_kern_break:NN`：断点前（`#1`）必须是全角右标点或长标点，断点后（`#2`）必须是全角左标点或非 `NoBreakLongPunct` 的长标点，两者同时满足才 breakable。

**理由**：

- 本问题的本质是"断点函数已知一侧信息，但没有检查另一侧"，是决策树的逻辑缺口，不是缺少一个新的标点属性。`NoBreakLongPunct`（#681）之所以新增正交属性，是因为它要表达一个新的字符级语义（"这个长标点不能在其前断行"）；而 #456 要表达的是"断点判断必须联合两侧已有信息"，这是控制流问题，加属性无法解决。
- `\@@_punct_kern:NN` 已经同时持有 `#1`、`#2` 两个参数，两侧信息本来就在函数作用域内，联合判断是最小改动路径。
- 参照 #811 决策：penalty 类机制适合"某个字符类整体需要禁则"（如 `HalfRight` 类），但本问题不是某个类整体需要 penalty，而是"长标点参与的断点，两侧各自需要按已有类型（`FullLeft`/`FullRight`/`NoBreakLongPunct`）做门控"，属于 `\@@_punct_kern:NN` 既有的 kern-vs-nobreak 决策语义，不需要新的 interchar penalty 通道。

## 决策 2：`\@@_punct_kern_break:NN` 延续"选函数再喂参数"模式，不在内部直接展开 kern

`\@@_punct_kern:NN` 原有结构是：先选出 `\@@_punct_breakable_kern:NN` 或 `\@@_punct_nobreak_kern:NN` 这个函数名，再在尾部统一执行 `#1 #2`。`\@@_punct_kern_break:NN` 延续同一模式，只做判断、留函数名，不在分支内部直接执行 kern 逻辑。

**理由**：保持与既有代码风格一致，且避免在新增分支里重复实现 `\@@_punct_breakable_kern:NN` / `\@@_punct_nobreak_kern:NN` 已有的 kern 计算逻辑。

## 决策 3：`\g_@@_last_punct_tl` 在参与 `\@@_punct_if_right:N` 前显式 `\exp_after:wN` 展开

`\@@_punct_kern_break:NN` 的 `#1` 来自 `\g_@@_last_punct_tl`（tl 类型全局变量）。`\@@_punct_if_right:N` 内部用 `\xeCJKtoken_value_class:N` 查询字符的 `\XeTeXcharclass`，要求参数是字符记号，不能直接吃 tl；而 `\@@_punct_if_long:N`（special punct clist 机制生成，内部 `\if_cs_exist:w` 判断缓存 csname）可以直接吃 tl。

**采纳方案**：调用 `\@@_punct_if_right:NTF #1` 前显式加 `\exp_after:wN` 展开 `#1` 为字符记号；调用 `\@@_punct_if_long_p:N` 时不做额外展开，直接传参。

**理由**：两类条件函数的参数形态要求不同是既有事实（详见反思 [[456-longpunct-kinsoku-both-sides]]），不是本次引入的新约束；`\exp_after:wN` 是 xeCJK 处理 tl-vs-char-token 混用场景的既有惯用法，无需新增中间变量或额外的类型转换封装。

## 合法断点清单（回归覆盖）

以下组合修复后仍保持可断：

- `，——`（全角右标点 + 长标点）
- `……——`（长标点 + 长标点，两侧均满足"全角右标点或长标点"/"全角左标点或非-NoBreakLongPunct 长标点"）
- `——（`（长标点 + 全角左标点）

## 归属与关联

- 实现：`xeCJK/xeCJK.dtx`（`\@@_punct_kern:NN`、新增 `\@@_punct_kern_break:NN`），commit `ba70a4b5`，分支 `issue-456-longpunct-kinsoku`，Issue #456。
- 回归测试：新增 `xeCJK/testfiles/longpunct-kinsoku01.lvt`（9em 窄版面三类禁则场景 + 两个合法断点保留场景）；基线联动 `ctex/test/testfiles/punct.tlg`（`……」` 从可断改为 `\penalty 10000` 禁则保护，属预期变化）。xeCJK 91/91、ctex 181/181 全量通过。
- 架构文档：`llmdoc/architecture/xecjk-architecture.md` 标点压缩系统一节，长标点断点两侧禁则小节。
- 相关既有决策：[[811-halfright-prebreakpenalty]]（penalty 类禁则的适用边界）、[[382-dash-width-and-ligature-opt-in]]（`PoZheHao` 类需被 `\@@_punct_if_right:N` 承认为全角右标点，本次决策 3 沿用该前提）。
- 反思：[[456-longpunct-kinsoku-both-sides]]。
