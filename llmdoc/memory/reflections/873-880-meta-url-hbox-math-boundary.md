---
name: 873-880-meta-url-hbox-math-boundary
description: 反思 #873 / #880 修复中"边界 marker 被 hbox 节点或 math 模式遮蔽"的两条修复模式（save/replay vs drain），以及本地 TeX Live usertree 与 CI 漂移导致 7 个 false-positive 测试失败的诊断教训
metadata:
  type: feedback
---

# [Task Reflection]

## Task

为 xeCJK 修复两个边界恢复缺陷并补回归测试：

- **#873**：l3doc 的 `\meta` / `\cs` 在 CJK 之后丢失 ecglue。`\HD@target`
  (hypdoc.sty) 通过 `\raisebox` 产生一个 0x0 hbox 节点。xeCJK 边界恢复链靠
  `\tex_lastkern:D` 判断之前是否插过 marker kern；hbox 节点夹在中间会让
  `\lastkern` 读到 0pt（或非 marker 值），状态机判断失败、左侧 ecglue 丢失。
- **#880**：`\url` 后 CJK 之间也丢 ecglue。url.sty 的 `\Url@FormatString` 把
  内容包在 `$\fam\z@ ... $` 里进入 math 模式，整段 hbox 化的同时 marker kern
  直接被 math 模式吃掉，`\lastkern` 连原 marker 都读不到。

实施方案为**混合修复**：

1. **#873 save/replay**：在 `\HD@target` 入口用 `\xeCJK_if_last_node:` 检测并
   把 `\g_@@_last_node_tl` 暂存到 `\g_@@_hd_saved_node_tl`，调用结束后用
   `\xeCJK_make_node:n` 重新发射 marker，让下游边界检查仍能命中。
2. **#880 drain**：在 `\Url@FormatString` 入口直接 `\xeCJK_remove_node:` 拔掉
   marker 并补 `\l_@@_ecglue_skip`；`\url` 内容必为西文，CJK→西文方向边界总是
   ecglue，不需要区分 marker 类型。

两处都通过 `\@@_package_hook:nn` 在对应包加载后 patch。新增两个回归测试
`xeCJK/testfiles/hypdoc-ecglue01.lvt`、`url-ecglue01.lvt`，已落到
commit `7c3a2c2e`。

## Expected vs Actual

- 预期：修复完应当直接通过本地 `l3build check`，因为补丁面收得很窄、新增测试也都通过。
- 实际：本地多出 7 个看似无关的失败——xeCJK 的 `environ01` / `loading01` /
  `punct-measure-fix01` / `tabular01`，以及 ctex contrib 的 `elegantbook` /
  `pkuthss` / `thuthesis`。我**最初草率判定**为"预存问题、与本次 patch 无关"，
  被用户当场反驳："线上最新 action 是没问题的，要分析清楚再解决"。
  反驳之后才查清楚根因并修通。

## What Went Wrong

1. **错误归因**：把本地一组看起来"跟 patch 不相关"的失败直接打包成"预存问题"，
   没有先比对 CI 现状。CI 是已知良好基线，本地与 CI 的差异应是**第一信号**而不是
   被忽略的背景噪声。
2. **忘了一个关键步骤——重生成 fmt**：发现是 TL 版本漂移后，第一反应是
   `tlmgr --usermode update --all`，但**只更新 `.ltx` / `.sty` 文件不够**。
   xelatex 启动时加载的是预编译的 fmt 文件，里面 dump 的还是老内核。必须
   `fmtutil-user --byfmt xelatex` 才能把 `~/.texlive2026/texmf-var/web2c/xetex/xelatex.fmt`
   同步到新内核。
3. **没在第一时间用 CI 状态作交叉验证**。线上最新 action 是干净的，这条
   信号本来够分辨"是 patch 副作用 vs 本地环境漂移"，但被我跳过。

## Root Cause

- **直接根因（环境）**：本地是 Homebrew 安装的 TeX Live 2026，`tlmgr revision 77655`，
  自 2026-02-07 后没再拉过 TLnet；CI 用 `setup-texlive-action@v4` 每次拉 TLnet
  最新版，包括最新 LaTeX 内核（`fmtversion=2026-06-01`）。commit `06ca4680`
  已经把仓库声明的最低 LaTeX2e 拉到 `2026-06-01`，本地老内核加载时触发 release
  warning，把 `loading01` 的日志第 3 行错开；另 6 个失败则是新版 LaTeX / hyperref /
  graphics 改了 `\showbox` 输出格式（开始打印 `\mathon` / `\mathoff` 节点和
  `$[]$` 风格 Overfull 标记），与本地老内核不一致。
- **思维定式（人）**：本地失败"看起来跟 patch 无关"就归为环境问题——这是一种
  懒分析。正确做法是看 diff 内容找根因（release warning 字样、mathon/mathoff
  节点、`\showbox` 输出差异都是清晰的环境指纹），不是看用例名是否落在改动文件附近。
- **诊断 checklist 缺位**：项目缺少一份"本地 TL usermode 维护与 CI 漂移检测"
  小流程，导致即使遇到典型症状也得每次手动重推一遍。

## Missing Docs or Signals

- **缺少"本地 TL usermode 同步" guide / reference 小节**。`tlmgr --usermode update --all`
  与 `fmtutil-user --byfmt xelatex` 的**双步**流程不写下来就极易忘 fmt 一步。
  附带还要写清楚 `tlmgr --usermode` 不能更新 `tlmgr` 自身、不能更新引擎包
  （xetex / luaotfload / latex-bin 会显示 "mentioned, but neither new nor
  forcibly removed"，这是预期行为而非错误）。
- **缺少"本地失败 vs CI 失败"的诊断 checklist**。判定指纹：
  - `LaTeX2e <YYYY-MM-DD>` 的 release warning 出现在前几行 → 本地内核低于仓库声明。
  - `.tlg` diff 出现 `\mathon` / `\mathoff` / `$[]$` / `pre-display` 等新增节点 →
    本地 LaTeX / hyperref / graphics 包级 `\showbox` 实现旧版。
  - 引擎 banner（如 `XeTeX 0.99996`）一致但包级 diff 大 → 不是引擎差异，
    是包差异（如本轮 6/7 个失败的真实情况）。
- **边界恢复架构文档里没有显式记录"修复点选择矩阵"**：当一个 marker 被某种
  下游节点遮蔽时，应在哪里下补丁是有规律可寻的。本轮把这种规律实际**实践**了
  一次，但 `architecture/xecjk-architecture.md` 里没体现。

## Promotion Candidates

适合提升到 **`architecture/xecjk-architecture.md`**（由 recorder 落地）：

- **边界恢复修复点矩阵**——按"marker 被什么遮蔽"分类，给出对应修复模式：

  | 遮蔽类型                     | 案例                          | 修复位置                                  | 修复模式                                                                  |
  | ---------------------------- | ----------------------------- | ----------------------------------------- | ------------------------------------------------------------------------- |
  | hbox 节点（marker 仍在但回看不到） | #873 `\HD@target` 的 `\raisebox` 0x0 hbox | 调用方入口                                | **save/replay**：入口保存 `\g_@@_last_node_tl`，调用结束后 `\xeCJK_make_node:n` 重发 |
  | math 模式（marker 被吃掉）         | #880 `\Url@FormatString` 的 `$...$` | 调用方入口                                | **drain**：入口 `\xeCJK_remove_node:` + 直接补 `\l_@@_ecglue_skip`                |
  | whatsit 节点（color / annot 等）   | #807 / #809 / #810 / #831      | `\@@_recover_glue_whatsit:` 或调用方入口      | **whatsit 恢复链**，必要时配合 **专用 pending boolean**（如 `\g_@@_reset_color_pending_bool`） |
  | 用户 brace / 显式分组               | #831 catcode 2 路径             | 状态机内部                                | **brace 路径状态保存**                                                       |

  这张表的核心规律是：**修复位置由"被遮蔽的节点类型"决定，而不是由 marker 本身的
  类型决定**。本轮 #873 / #880 的修复并不经过 `\@@_recover_glue_whatsit:`
  （hbox 走 else 分支，math 直接吃 marker），所以与 PR #831 的 "default 分支
  boolean gate" 思路是正交的。

适合提升到 **`reference/build-and-test.md`**（由 recorder 落地）：

- 新增"本地 TL usertree 同步"小节，记录双步流程：

  ```bash
  # 1. 同步包到 usertree（已 init 过 ~/texmf + ~/.texlive2026/）
  tlmgr --usermode update --all
  # 2. 重生成 xelatex fmt（必须，否则启动时仍用老内核）
  fmtutil-user --byfmt xelatex
  ```

  以及"本地失败 diff 指纹检查表"——release warning / mathon-mathoff / 引擎
  banner 的判读规则。

适合放到 **`memory/decisions/`** 一条新决策（由 recorder 落地）：

- **#873 / #880：选 input-side fixed-point patch 而非"收窄 default 分支"的理由**。
  备选方案曾考虑仿 PR #831 给 `\@@_recover_glue_whatsit:` 的 default 分支加
  pending boolean gate（仅在 `\set@color` / `\HD@target` / `\Url@FormatString`
  等已知调用方显式置位时才允许 default 分支吐 ecglue）。**未采纳**，因为：
  - #873 走的是 hbox else 分支，根本不进 `recover_glue_whatsit`；
  - #880 在 math 模式里 marker 已被吃掉，更进不去；
  - 收窄 default 分支是另一类问题（防止任意 whatsit 误触发），应作独立 PR 处理。
  一句话总结：**修复位置取决于被遮蔽的节点类型，不取决于 marker 类型**。

仅保留在本反思（不上推）：

- 本轮 7 个本地失败的具体清单与诊断细节、`tlmgr --usermode update` 输出里那 9 个
  被升级的包（amsmath/babel/firstaid/graphics/hyperref/l3kernel/latex/thuthesis/tools，
  rev 76xxx → 79xxx）。
- "误归因为预存问题"这条人因教训本身——值得记住，但属于 reflection 范畴。

## Follow-up

- 下次主助手起手就该**先 check 本地 fmt 时间戳与仓库声明的最低 LaTeX2e
  日期**，把 TL 漂移挡在分析前面，而不是出现一堆 `.tlg` diff 才去排查。
- 等用户确认后，由 recorder 把上面三处 Promotion Candidates 落到稳定文档
  （architecture/reference/decisions），本反思保持不变。
- 如果未来真要落"收窄 `\@@_recover_glue_whatsit:` default 分支"的独立 PR，
  应明确动机是"防御任意 whatsit 误触发"，而不是"修 #873 / #880 的副作用"——
  两者目标完全不同。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` 中 `\HD@target` 与 `\Url@FormatString` 的
  `\@@_package_hook:nn` patch 段（commit `7c3a2c2e`）。
- 回归测试：`xeCJK/testfiles/hypdoc-ecglue01.lvt` / `.tlg`，
  `xeCJK/testfiles/url-ecglue01.lvt` / `.tlg`。
- 同方向但不同修复模式的对照反思：
  [[807-set-color-stale-state]]、[[809-810-hyperref-annot-ecglue]]、
  [[831-reset-color-pending-bool]]。
- 仓库 LaTeX2e 依赖声明上调：commit `06ca4680`（ctex/xeCJK/zhlineskip 声明依赖
  LaTeX2e 2026-06-01）。
