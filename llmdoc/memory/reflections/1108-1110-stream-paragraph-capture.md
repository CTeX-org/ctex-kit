---
name: 1108-1110-stream-paragraph-capture
description: 记录 #1108／#1110 处理 stream 正文跨段落时 capture 过期的三次提交（只处理第一段、依次跟随每一段、按分组层级登记 \aftergroup），以及被否决的“段落结束即重置全部 capture”和逐段 \aftergroup 带来的平方级回退
metadata:
  type: feedback
---

# [Task Reflection]

## Task

stream 命令（如 `\href`）的正文直接写进外层列表，可能经宏执行 `\par`。capture 记录的入口 marker、入口源码空格与首尾类别属于命令开始时的段落，段落结束后即过期。

- `ff098f05`（#1108，PR #1109）：命令结束时已在垂直模式，不再走 `\@@_boundary_hmode_stream_end:n`（原路径报 `Improper \spacefactor`，并把 marker kern 写进垂直列表）。`\changes` 由 `4d69aca2` 补上。
- `4d69aca2`（#1110 首个提交）：段落在 `para/begin` 取得局部编号，`para/end` 重置在这一段开始的 capture；编号用 `\aftergroup` 带出普通分组。
- `2ad70732`（PR #1113 审查后）：capture 依次跟随每一段（`par_tl` 改为 `p<编号>` 等待下一段认领），`\everyvbox` 给盒子换新编号。
- `b3b48f76`（PR #1113 再次审查后；architecture 文档称之前的实现为“PR #1113 第三版”）：编号改存按 `\currentgrouplevel` 索引的全局 tl 槽位，同一分组层级只登记一次 `\aftergroup`。

当前机制以 `architecture/xecjk-architecture.md`「stream 正文跨段落」一节为准；本文只记录过程。

## Expected vs Actual

- 预期：段落结束时重置一次 capture 就够了。
- 实际一：`4d69aca2` 只处理正文里的第一段。`\href{u}{a\par b\par\leavevmode}前` 仍多 3.33pt：第二段结束时记下的编号已不相等，不再重置。
- 实际二：`4d69aca2` 与 `2ad70732` 都逐段 `\seq_gpush:Nn` 加逐段 `\aftergroup`。正文整体包在 `\begingroup` 一类环境（`setspace` 的 `spacing`）里时，栈和 `\aftergroup` 都要到环境结束才释放，`\seq_gpush:Nn` 每次复制整个序列，排版时间按段落数平方增长：5000 段从 master 的 0.77s 变成 10.8s。`b3b48f76` 为 0.84s，`\newenvironment` 包装的 40000 段为 3.0s（master 2.1s）。

## What Went Wrong

1. **只测了“一段”。** 跨段落的状态机至少要测两段、三段，以及段落之间夹 `\vbox`／`center`／`itemize`／脚注的写法；`2ad70732` 补上 8 种用例，它们在 `4d69aca2` 上失败 16 处。
2. **没有对“随段落数增长”的资源做量级检查。** 每段登记一次 `\aftergroup`、每段压一次全局栈，在没有外层分组时无害，在整篇正文都在一个分组里时就退化成平方级。功能探针全部通过也看不出来。
3. **曾试过“每次段落结束都重置所有 capture”**：`listings-color01` 失败 14 项（`\lstinline` 的测量盒子里排有段落），没有采用。段落与 capture 的归属必须靠编号区分，不能一刀切。

## Root Cause

- 段落是分组之外的状态，局部变量会随分组恢复、全局变量又会被盒子里的段落污染；任何把两者对齐的机制都要同时说明“盒子里”和“普通分组里”两种情况。
- 用 `\aftergroup` 传值时，登记次数应只取决于分组深度，不能取决于分组内事件的次数。

## Missing Docs or Signals

- 测试里没有固定性能量级的手段。`b3b48f76` 的做法可复用：不测时间，改为插桩计数（`hyperref-paragraph02` TEST 9 包装 `\@@_boundary_par_carry:`，1 段与 500 段都只执行 2 次），结果写进 `.tlg`，对机器速度不敏感。
- 槽位选 tl 而非 int：按需 `\tl_new:c` 不分配寄存器，不会让其他测试（如 `loading01`）的基线多出寄存器分配记录。

## Promotion Candidates

- 已同步：`architecture/xecjk-architecture.md`「stream 正文跨段落」（含槽位与平方级回退）。
- 已登记：`memory/doc-gaps.md` 中正文里的盒子、脚注内容被当作命令两侧类别的问题（#1114，与段落无关）。
- `memory/lessons-learned.md`（候选，再出现一次再提升）：在 `\aftergroup`、全局栈等“分组结束才释放”的结构里登记的次数，要与分组深度而非事件数成正比；用插桩计数而非计时把这一点写进回归测试。
