---
name: 826-fntef-boolean-flag-iteration
description: 反思 xeCJK #826 fntef glue-on-kern-pair 修复在初始提交后经历的 boolean flag + glueshrink 迭代，侧重调试过程与状态污染教训
type: reflection
---

# [Task Reflection]

## Task
- 为 xeCJK #826 的 `\@@_check_for_glue_skip:` 在初始提交 (a0690e67) 之后发生的多轮迭代编写反思。初始修复已正确识别问题（fntef 右侧 finite glue 叠在 CJK kern pair 标记上方），但后续暴露四个新问题：`\l_@@_last_skip` 状态污染、`\quad` 误处理、`\ ` 显式空格误判、fallback 路径错误。
- 总结这段迭代中的根因分析方法、回归诊断信号和最终三层过滤设计的收敛过程。

## Expected vs Actual
- 预期结果：
  - 初始修复后，fntef 右侧 CJKglue 恢复正常，且不影响非 fntef 路径的标点识别、章节标题间距、显式空格行为。
- 实际结果：
  - thuthesis 回归：整篇文档 CJKglue / punct spacing 发生微妙偏移（宽度变化 0.01--0.1pt 级别）。
  - ctex heading 回归：`第一章\quad 引言` 格式中 `\quad` 被 unskip 吃掉，章节标题紧贴。
  - `\ ` 显式空格误判：CJK 字符间的 `\ ` 也有 shrink，被错误地当作 fntef 空格处理。
  - basic01/nobreak01 回归：punct -> CJK 过渡丢失标点检测链。

## What Went Wrong
1. **状态污染是最隐蔽的 bug**。`\l_@@_last_skip` 在初始实现中被无条件赋值（`\skip_set:Nn \l_@@_last_skip { \tex_lastskip:D }`），不管当前是否处于 fntef 上下文。在非 fntef 路径中，这条赋值覆盖了 `\@@_check_for_glue_auxiii:` 需要读取的合法 `\l_@@_last_skip` 值，导致 punct 检测链拿到错误的 skip 数据。由于影响是全局性但幅度微小，只有跑 thuthesis 完整文档才能发现。

2. **过滤条件不够窄**。初版只用 `\skip_if_finite:nTF` 过滤 fil 级 glue，但没有区分"fntef 产生的 inter-word glue（有 shrink）"和"用户显式写的 `\quad`（无 shrink）"。`\quad` 的 glue 是 finite 但没有 shrink，直接被 unskip 了。

3. **依赖错误信号做区分**。尝试用 `\g_@@_last_node_tl` 检测"上一个 node 是否是 CJK boundary"来区分 `\ ` 与 fntef glue，但 CJK -> Boundary handler 已经覆写了该变量，使得在 glue 检测点无法回溯到"这个 glue 是从哪里来的"。

4. **fallback 路径选错**。初始实现在 glue 下方不是 kern pair 时回退到 `\xeCJK_check_for_xglue:`。但该函数默认是 no-op（只在用户启用 xCJKecglue 时有实际定义），而正确的 fallback 应是 `\@@_check_for_glue_auxii:`，它包含完整的 punct 检测链。这直接破坏了 basic01/nobreak01 中标点右侧过渡到 CJK 时的正常识别。

## Root Cause
- 核心根因是**作用域泄漏**：初始实现把"只在 fntef 上下文需要的副作用"放在了"所有路径共享的入口处"。`\l_@@_last_skip` 的赋值只对 fntef 路径有意义，但写在了 boolean 检测之前，导致非 fntef 路径的下游函数读到被覆盖的值。
- 次要根因是**过滤维度不足**：仅靠 glue 自身属性（finite / shrink）不足以唯一识别"fntef inter-word glue"，需要叠加一个来源信号（`\g_@@_ulem_pending_bool`）作为第一层守卫。
- 第三个根因是**对 fallback 语义理解不精确**：`\xeCJK_check_for_xglue:` 是为"无标记可恢复"的正常终态设计的，而"有 glue 但下方不是 kern pair"不是终态，仍可能是 punct 过渡，必须走完 `auxii` 检测链。

## Missing Docs or Signals
- **缺少 `\l_@@_last_skip` 生命周期文档**：该变量在 `\@@_check_for_glue:` 入口赋值、在 `\@@_check_for_glue_auxiii:` 中使用。它的合法赋值时机和读取时机没有被明确文档化，导致新代码在不知情的情况下提前覆盖它。
- **缺少 fntef 上下文信号的设计说明**：`\g_@@_ulem_pending_bool` 是后来新增的，用于标记"刚关闭 ulem group、接下来可能产生 inter-word glue"。这类布尔标志的 set/clear 时机应作为状态机的一部分被记录。
- **缺少 fallback 链的完整路径图**：`\@@_check_for_glue:` 的各 branch 最终到达哪个出口，哪些出口包含 punct 检测、哪些是真正的终止，目前只能通过读源码理解。
- **contrib 测试作为必要验证的提醒不够强**：xeCJK 自身 76 个测试全部通过，但 thuthesis/pkuthss 立刻暴露回归。说明 spacing 类变更的验证矩阵必须包含 contrib 测试。

## Promotion Candidates
- 适合提升到 `architecture/xecjk-architecture.md` 或 `architecture/package-architecture.md` 的：
  - `\@@_check_for_glue:` 分支的完整 fallback 路径图，明确 `auxii`（punct 检测链）vs `xglue`（终止态）的语义区别。
  - `\l_@@_last_skip` 的合法赋值/读取窗口约束：只能在确认进入 glue 处理路径后赋值，不能在共享入口处无条件赋值。
  - `\g_@@_ulem_pending_bool` 的 set/clear 时机作为 fntef 兼容层状态机的一部分。
- 适合提升到 `reference/build-and-test.md` 的：
  - spacing 类修复必须同时跑 xeCJK 本包测试 + ctex xetex 基线 + thuthesis/pkuthss contrib 测试，三层缺一不可。
- 适合暂留 memory 的：
  - `\quad` 无 shrink、`\ ` 有 shrink 的具体数值特征。
  - `\g_@@_last_node_tl` 被 CJK->Boundary handler 覆写的时序细节。
  - 三层过滤（boolean -> finite -> shrink > 0）的具体实现选择。

## Follow-up
- 在 `architecture/xecjk-architecture.md` 的边界恢复状态机章节中补充 `\@@_check_for_glue_skip:` 分支的完整路径图，包括 boolean guard、finite/shrink 双重过滤、正确的 fallback 出口。
- 在 `reference/build-and-test.md` 中将 contrib 测试（thuthesis/pkuthss）提升为 spacing/punct 类修复的必要验证步骤，而不是可选附加。
- 后续若再对 `\@@_check_for_glue:` 做修改，第一步检查是否有变量在 boolean guard 外被赋值——任何共享变量的写入必须在确认"属于本路径"之后才能执行。
