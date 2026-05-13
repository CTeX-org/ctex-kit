---
name: 831-reset-color-pending-bool
description: 反思 #831 colorbox/textcolor 右侧间距修复的四轮迭代——从 \reset@color 直接插入 kern 到专用布尔延迟处理的收敛过程
type: reflection
---

# [Task Reflection]

## Task
- 为 #831 的 colorbox/textcolor 右侧间距修复完成最终方案。前置工作（显式 `}` catcode 2 set 点、`\reset@color` 定点补丁、hlist 回退路径）已完成并提交，但 `\reset@color` 的 hlist 路径直接在 color pop whatsit 后插入 kern 对，在 pkuthss/thuthesis/beamer 的标题/页面布局 hlist 中触发了多余零和 kern 对。需要找到既能修复 colorbox 右侧间距、又不影响布局结构中 hlist 的方案。

## Expected vs Actual
- 预期结果：colorbox/textcolor 右侧的 CJKglue 恢复正常，所有测试基线不变。
- 实际结果：经过四轮迭代才达到预期。前三轮分别产生了 pkuthss/thuthesis kern 对回归、"2021~年" glue 回归、以及同一 glue 回归（boolean 泄漏）。第四轮引入 `\g_@@_reset_color_pending_bool` 专用布尔才干净解决。

## What Went Wrong

1. **第一轮（已提交 e5cc6ef7）：`\reset@color` hlist 路径直接插入 kern 对**。当 `\lastnodetype` 为 hlist 且 `\g_@@_last_node_tl` 为 CJK 类型时，在 `\@@_orig_reset_color:` 之后直接执行 `\xeCJK_make_node:n` + `\bool_gset_true:N \g_@@_ulem_pending_bool`。问题：hlist 检查过于宽泛——任何 hlist（包括 beamer frame title、thuthesis header 中的布局 hbox）只要前方有 CJK 字符就触发，导致大量零和 kern 对出现在与 colorbox 无关的布局结构中，pkuthss/thuthesis 基线全面偏移。

2. **第二轮（未提交）：whatsit 回退不带门控**。把 hlist 回退逻辑从 `\reset@color` 移到 `\@@_check_for_glue_skip:` 的非 kern 非 hlist 分支，在该分支中无条件检查 whatsit。问题：CJK->Boundary 的 catcode 2 路径也会使 `\g_@@_ulem_pending_bool` 为真，且后续 glue 的 `\unskip` 后 `\lastnodetype` 可能恰好为 whatsit（例如 `\typeout` 产生的 whatsit），导致非 colorbox 场景误入 whatsit 恢复路径。具体表现为 pkuthss 中 "2021~年" 的 `~` 从 XITS interword space 变为 CJKglue。

3. **第三轮（未提交）：用 `\g_@@_ulem_pending_bool` 门控 whatsit 回退**。想法是只在 `\g_@@_ulem_pending_bool` 为真时才进入 whatsit 路径。问题：`\g_@@_ulem_pending_bool` 有三个 set 点（fntef ulem group / underdot 独立模式 / CJK->Boundary catcode 2），其中 catcode 2 set 点在 `}` 触发时设置，但此后可能紧跟 `~` 等非 colorbox 场景。该 boolean 不具备区分"来自 `\reset@color`"与"来自 `}`"的能力，"2021~年" 回归依旧。

4. **第四轮（已提交 fc40526f）：`\g_@@_reset_color_pending_bool` 专用布尔**。在 `\reset@color` 的 hlist 路径中仅设置此专用布尔（不插入 kern 对），在 `\@@_check_for_glue_skip:` 的非 kern 非 hlist 分支中用此布尔门控 whatsit 检查。该布尔仅由 `\reset@color` 设置，仅在 `\@@_check_for_glue_skip:` 中消费，完全隔离于其他 pending boolean 的生产端。

## Root Cause

- **核心根因：共享全局布尔的语义过载**。`\g_@@_ulem_pending_bool` 从 #826 的 fntef 专属标记逐步扩展为"已知会产生 glue-on-kern-pair 的场景标记"（三个 set 点）。当尝试将 `\reset@color` hlist 信号也通过此布尔传递时，消费端无法区分信号来源，导致非 colorbox 路径（如 `~`）误触发 whatsit 恢复。
- **次要根因：hlist 检查缺乏来源鉴别**。TeX 的 `\lastnodetype` 只能告诉你"最后一个节点是 hlist"，但无法区分是 colorbox 的 hbox、beamer frame title 的 hbox、还是其他布局 hbox。在 `\reset@color` 中直接基于 hlist 类型做恢复，命中面过大。
- **第三个根因：`\typeout` 等隐式 whatsit 干扰**。`\typeout` 插入的 whatsit 节点使得在 `\unskip` 后 `\lastnodetype` 为 whatsit（类型 4），而非预期的 kern 或 hlist，打乱了基于 `\lastnodetype` 的类型分派。

## Missing Docs or Signals

- **缺少 `\g_@@_ulem_pending_bool` 的"信号来源 -> 消费端"对照表**。如果有一份明确列出"哪些场景设置此布尔、哪些检查消费此布尔、每个消费端期望的语义前提是什么"的表格，第三轮的错误（共享布尔导致 catcode 2 路径泄漏到 whatsit 检查）可以在设计阶段被发现。
- **缺少 `\lastnodetype` 在常见场景下的实际值参考表**。不同场景（colorbox 后、`\typeout` 后、beamer header 中）的 `\lastnodetype` 返回值对于调试至关重要，目前只能通过 `\typeout{\the\lastnodetype}` 实验性探测。
- **"2021~年" 测试场景的诊断依赖 pkuthss 完整文档**。纯 xeCJK 单元测试无法覆盖这种由文档类布局结构与 CJK 字符交互产生的回归，必须跑 contrib 测试。

## Promotion Candidates

- **适合提升到 `architecture/xecjk-architecture.md`**：
  - `\g_@@_reset_color_pending_bool` 的生命周期（仅 `\reset@color` hlist 路径设置、仅 `\@@_check_for_glue_skip:` whatsit 回退消费），作为 `\g_@@_ulem_pending_bool` 之外的第二个 pending boolean 信号。
  - `\@@_check_for_glue_skip:` 的三路分派（kern / hlist / whatsit-via-reset-color-bool）完整路径图。
- **适合更新 `decisions/831-boundary-explicit-brace-ecglue.md`**：
  - 将"阶段 2 `\reset@color` 补丁"中的实现从"直接插入 kern 对"更新为"设置专用布尔 + whatsit 延迟回退路径"。
- **适合更新 `decisions/826-fntef-right-side-cjkglue.md`**：
  - 明确 `\g_@@_ulem_pending_bool` 的职责边界——不应用于传递 `\reset@color` hlist 信号。
- **仅保留在 memory**：
  - `\typeout` 插入 whatsit 导致 `\lastnodetype` 为 4 的具体行为。
  - 四轮迭代中每轮的具体回归表现和诊断命令。
  - 共享全局布尔过载的一般性教训（与 #826 反思中的状态污染教训互补）。

## Follow-up

- 更新 `decisions/831-boundary-explicit-brace-ecglue.md`，将阶段 2 的描述从"直接重放 kern 对"修正为"设置 `\g_@@_reset_color_pending_bool` + whatsit 延迟回退"。
- 在 `architecture/xecjk-architecture.md` 的边界恢复状态机章节中补充 `\@@_check_for_glue_skip:` 的 whatsit 回退路径和 `\g_@@_reset_color_pending_bool` 的位置。
- 考虑为 `\g_@@_ulem_pending_bool` 和 `\g_@@_reset_color_pending_bool` 建立一份 pending boolean 信号对照表（生产端 / 消费端 / 语义约束），防止后续再出现信号过载问题。
