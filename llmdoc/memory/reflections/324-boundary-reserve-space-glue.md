---
name: 324-boundary-reserve-space-glue
description: 反思 xeCJK issue #324 中 CJK→Boundary 宏路径提前输出空格 glue 遮蔽标记 kern，导致边界恢复失效的修复经验
type: reflection
---

# 324 boundary reserve space glue Reflection

## Task
- 记录 xeCJK issue #324 的修复经验：当源码里 CJK 字符后换行、下一行以 `\autoref` 等宏命令开头时，xeCJK 没有消除源文件里的行尾空格，导致输出里出现多余空格。
- 总结 `\@@_boundary_reserve_space:` 中“保留空格”实现为何破坏了边界恢复状态机，以及这次修复对 xeCJK/ctex 测试面的联动启示。

## Expected vs Actual
- Expected outcome.
  - 期望 CJK 字符后的源码换行空格在“下一 token 是宏命令”的场景下，与“下一 token 是普通字符”的场景保持一致：只保留用于后续恢复判定的 `CJK-space` 标记 kern，不立即产出可见空格 glue。
  - 期望后续 `Boundary -> CJK` 或 `Boundary -> Default` 恢复路径仍能通过 `\lastkern` 识别前一个边界类型，按既有状态机正确决定是否恢复 glue。
- Actual outcome.
  - 实际上，宏路径中的 `\@@_boundary_reserve_space:` 在 `\@@_boundary_group_end:n { CJK-space }` 之后又立即执行 `\xeCJK_space_or_xecglue:`，当场输出了一段空格 glue。
  - 这段 glue 把刚插入的 `CJK-space` 标记 kern 遮蔽掉，导致后续恢复路径基于 `\lastkern` 的判定失效，于是本应被 xeCJK 吃掉的源码行尾空格残留为实际输出空白。
  - 修复后不仅 #324 的 `\autoref` 场景恢复正常，ctex 侧 xetex 回归中 heading/basic/beamer 等多组测试里原本潜伏的多余 glue 也一并消失，说明影响面明显超出原 issue 描述。

## What Went Wrong
- 最容易忽略的错误是把“保留源码中的空格”理解成“立即输出一个空格 glue”。对当前 xeCJK 架构而言，`CJK -> Boundary` 阶段真正需要保留的是后续状态机要读的边界标记，而不是立刻排版一个空格节点。
- 宏路径与非宏路径的行为长期不一致，却没有第一时间被当成 bug 信号：
  - 非宏路径只执行 `\@@_boundary_group_end:n { CJK-space }`，留下标记 kern；
  - 宏路径却额外执行 `\xeCJK_space_or_xecglue:`，留下一个实际 glue。
  两条路径随后都进入同一套 `Boundary -> CJK` / `Boundary -> Default` 恢复逻辑，因此前端状态本应一致；这种不一致本身就说明实现偏离了状态机设计。
- 对影响范围的初始判断也偏窄。若只把 #324 看作“`\autoref` 前多一个空格”的局部兼容问题，就容易低估它对 ctex 下游基线的影响；实际受影响的是更底层的边界恢复链，因此任何依赖 xeCJK 且会形成“CJK 后换行再接宏”的文档结构都可能中招。

## Root Cause
- 根因与现有架构文档中“边界恢复状态机”的第一层完全一致：xeCJK 依赖内部标记 kern，并在后续通过 `\lastkern` 判断前一个边界类型。
- #324 的 bug 并不是 whatsit、颜色或链接注释那类“外部节点插入打断恢复链”的问题，而是 xeCJK 自己在宏路径上提前插入了一个 glue，使 `\lastkern` 再也看不到刚刚写下的 `CJK-space` 标记。
- 换句话说，这不是“恢复逻辑太弱”，而是“进入恢复逻辑之前，宏路径已经把状态机赖以工作的标记遮蔽掉了”。因此最干净的修复不是增加新的恢复分支，而是回到与非宏路径一致的前置行为：
  - 只保留 `CJK-space` 标记 kern；
  - 不立即输出空格 glue；
  - 让既有 `Boundary -> CJK` / `Boundary -> Default` 路径继续按统一机制工作。
- 这也说明 #324 与 #491 的关系需要区分层次：#491 描述的是更一般的“标记可能被中间节点遮蔽”的结构性限制；#324 虽然表象相似，但中间遮蔽物不是不可控的 whatsit，而是 xeCJK 自己额外插入的 glue，因此属于可以直接修正的一致性 bug。

## Missing Docs or Signals
- 现有 `llmdoc/architecture/package-architecture.md` 已经提供了足够强的高层心智模型，尤其是“第一层：用 `\lastkern` 标记 kern 判定上一边界类型”。这次问题恰好证明该模型是对的：一旦标记后面又塞进 glue，恢复判定就必然失败。
- 还缺少一个更面向实现的稳定信号：对边界状态机而言，`CJK -> Boundary` 阶段若后续仍需依赖 `\lastkern` 判定，就不应在标记 kern 之后立刻输出会遮蔽它的节点，哪怕这个节点看起来只是“无害的空格 glue”。
- 还缺少一个排查提示：当宏路径与非宏路径最终汇入同一恢复逻辑时，若两条路径在“退出当前边界时留下什么节点”上不一致，应优先把这种不一致视为 bug 线索，而不是个别分支的合理特化。
- 测试文档层面也值得补一个信号：xeCJK 的边界修复不能只在本包单测中验证，还需要同步看 ctex 的 xetex 基线，因为 ctex 会在测试时解包并使用当前 xeCJK 源码；底层边界行为的微调常常会带出一批下游 `.tlg` 联动更新。

## Promotion Candidates
- 适合后续提升到 stable docs 的内容：
  - `architecture/`：在 xeCJK 边界恢复状态机章节补充一条明确约束：凡后续恢复要依赖 `\lastkern` 读取标记 kern，就不能在该标记之后立即插入 glue/whatsit 等会改变“最后一个节点可观察性”的节点；否则应视为对状态机前置条件的破坏。
  - `guides/` 或 `reference/`：补充“宏路径与非宏路径一致性”作为 interchar/Boundary 问题的排查启发式。如果两条路径共享同一恢复链，却在前置节点输出上不一致，优先检查是否存在多余节点遮蔽标记的问题。
  - `reference/build-and-test.md`：补充 xeCJK 修改后同步验证 ctex xetex 基线的提醒，尤其是说明这类下游联动不是偶发噪声，而是 xeCJK 作为 ctex XeTeX 后端的正常验证范围。
- 更适合暂留 memory 的内容：
  - 本次具体受影响的 ctex 测试簇（heading/basic/beamer 约二十个 `.tlg`）可先作为任务级记忆保留，等待未来再出现同类“xeCJK 小改动带来大批 ctex 节点级基线变化”的案例时，再决定是否抽象成更稳定的测试指南。
  - “在 regression-test 框架里优先用 `\ifdim\wd0=\wd2` 比较盒子宽度，而不是依赖 expl3 维度表达式”这条经验，更偏测试实现细节，暂不必写进架构文档，但可在后续同类测试设计中复用。

## Follow-up
- 后续再遇到 xeCJK 边界异常时，先按“恢复依赖的最后可观察节点是什么”来排查：如果某条路径在写入标记后又立即追加 glue/whatsit/box 等节点，应优先怀疑它遮蔽了状态机标记，而不是先扩展恢复分支。
- 对所有涉及 xeCJK 边界恢复的修复，默认把 ctex 的 xetex `l3build check` 视为必要联动验证，而不是可选附加步骤。
- 若后续继续积累到两三个类似案例，可考虑把“标记节点不得被后续节点遮蔽”的约束正式提升到 `llmdoc/architecture/package-architecture.md`。
