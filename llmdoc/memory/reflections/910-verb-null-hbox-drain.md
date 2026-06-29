---
name: 910-verb-null-hbox-drain
description: 反思 xeCJK #910 中 \verb 入口 \null 0×0 hbox 遮蔽 marker，drain 模式与 #880 同型但需要专用 _verb 版本保留 last_node_tl 以避免破坏 ctex 模式下 verb 内 CJK 字体与外部 CJK 之间的 CJKglue
metadata:
  type: feedback
---

# [Task Reflection]

## Task

修复 xeCJK issue #910：l3doc 的 `\verb|...|` 与 shortvrb 的 `|...|` 之前 `\CJKecglue` 丢失，例如 `啊啊 \verb|\begin{document}| 啊啊` 中 `啊` 与 `\verb` 之间的中西文边界间距不出现。同 issue 还涉及 `\meta` 的尾部空格异常，按用户决策本次只处理 `\verb` / shortvrb，`\meta` 另起 follow-up。

实施落地为 `xeCJK.dtx` 中新增 `\@@_patch_verb:` 段（commit `d6e28be1` → `d0cf09a1` 版本号 → `32553705` 改用 `_verb` 专用 drain），新增回归测试 `xeCJK/testfiles/verb-ecglue01.lvt`。`make check-ctex` 4 engine × 3 config 全绿，xeCJK `l3build check` 86/86 PASS。

## Expected vs Actual

- 预期：`\verb` 的 `\leavevmode\null` 与 #873 `\HD@target` 的 `\raisebox` 0×0 hbox 完全同型，按 [[873-880-fixed-point-vs-default-narrowing]] 决策属于 hbox 遮蔽，应该走 save/replay。
- 实际：save/replay 对 `\verb` 不可用——`\verb` 是读分隔符的 `\def` 宏，`\@@_orig_verb:` 之后的代码会在 `\verb` 展开前执行完毕，不能像 `\HD@target` 那样在原命令调用后注入 replay。最终改用与 #880 `\Url@FormatString` 同型的 **drain**：入口拔掉 marker 直接补 `\l_@@_ecglue_skip`。`\verb` 内最后字符到外部 CJK 字符之间的右侧间距由 Default→CJK 类别转换的 `\xeCJK_pre_inter_class_toks:nnn` 自动 prepend `\CJKecglue` 处理，不需要额外修复。
- 第一次直接复用 `\@@_drain_ecglue:`（#880 用的版本）在 xeCJK 自带 `verb-ecglue01.lvt` 与 ctex `verbatim01.xetex` 之间表现不一致：xeCJK 测试通过，但 ctex 模式 `make check-ctex` 中 `verbatim01.xetex` 失败，diff 只一行——verb 内 FandolFang CJK 字体的 `代码` 与外部 FandolSong 的 `和` 之间少了一个 `\CJKglue 0.0 plus 0.60931`。

## What Went Wrong

1. **混淆 drain 通用版与 verb 适用版的语义差**。`\@@_drain_ecglue:` (#880) 的 else 分支 `\tl_gclear:N \g_@@_last_node_tl` 是给"math 模式吃掉 marker、tl 与节点状态不一致"的场景做防御，目的是不让 tl 残留误导下游 `\@@_recover_glue_whatsit:` default 分支。但 `\verb` 不进 math 模式，入口前 `\g_@@_last_node_tl` 是合法状态，**主动 clear 会破坏 ctex 模式下 verb 内 CJK 字体延续到外部 CJK 字体走 CJK→CJK interchar 路径所需要的 tl 状态**。
2. **过度信任 hbox 同型则修复同型**。结构上 `\null` 与 `\HD@target` 都是 0×0 hbox 遮蔽 marker，但 `\HD@target` 是普通调用方控制序列（patch 后可以 wrap save/replay），`\verb` 是分隔符扫描宏（patch 后只能在原命令前下文做事）。**遮蔽节点类型决定修复点**，但**调用方控制序列的语义（参数读取模式）**决定 fixed-point patch 是 save/replay 还是 drain。
3. **错用 expl3 条件变体**。中间一次把 patch 改成 `\xeCJK_if_last_node:T { ... }`——这个变体没定义，**TF 才是定义版本**。报错信息散在 `.log` 中，没看错误就直接 `l3build check` 跑，导致 `verb-ecglue01` 和 `verb01` 同时报 `Undefined control sequence`，差点回退整个修复。诊断时间被这条假阳性消耗了 20+ 分钟，应该先 `\show \verb` 看 patch 是否生效。
4. **`\verb` 的回归测试位置陷阱再次踩中**。第一稿测试把 `\verb|X|` 放在 `\TEST{ ... }{...}` 第二参数里，LaTeX 立刻报 `\verb illegal in argument`——这是 [[556-verb-xkanjiskip-lltjcore]] 已经记录过的陷阱（"`\verb` 不能直接放进宏参数"），但写测试时没翻反思就重复犯错。

## Root Cause

- **理论根因（drain 语义边界）**：`\@@_drain_ecglue:` 与 verb 入口的语义差别在于 else 分支是否清空 `\g_@@_last_node_tl`。这是 #880 与 #910 的真正差异——不是"遮蔽节点类型不同"，而是"**调用方之后是否仍有 interchar 类型转换需要 tl 状态**"：`\url` 内是 math，math 不参与 interchar，math 退出后由 `\@@_if_last_math:` 路径单独处理；`\verb` 内字符是 catcode 12（默认 Default class）或在 ctex 模式下保持 CJK 字符的 XeTeXcharclass（仍是 CJK class），verb→外仍走 token-level interchar，**需要 tl 状态延续**。
- **方法根因（修复模式选择维度不够细）**：当前架构文档的"修复点选择矩阵"按"遮蔽节点类型"分类，但**没区分调用方控制序列的扫描语义**（普通 `\def`/无参 vs 分隔符扫描）。`\verb` 与 `\HD@target` 在"遮蔽类型"列同属 hbox，按现有矩阵都应是 save/replay。本轮发现：`\verb` 的分隔符扫描语义让 save/replay 不可用，必须落到 drain。这是修复模式选择的隐藏维度。
- **诊断流程根因**：改 patch 后没即时 `\show \verb` 验证宏定义就 `l3build check`，被 expl3 条件变体的拼写错误（`:T` vs `:TF`）放出错误信号但被淹没在测试输出里。

## Missing Docs or Signals

- 架构文档 `xecjk-architecture.md` 的"边界恢复修复点选择矩阵"未涵盖 `\verb` 这类**分隔符扫描宏**。需要在矩阵后追加"selection 子维度：调用方控制序列的扫描语义"。
- 缺少专用的 `\@@_drain_ecglue:` vs `\@@_drain_ecglue_verb:` 区分文档：两者只差 else 分支是否 clear `\g_@@_last_node_tl`，但这一点行为差在 ctex 模式下放大成 `\CJKglue` 丢失，文档需要明确"何时复用 `\@@_drain_ecglue:`、何时新建 `_verb` 类专用 drain"。
- expl3 条件变体（`:T` / `:F` / `:TF`）的 declare 站点（`\prg_new_conditional:Npnn ... { T, F, TF }`）与实际 declare 列表的对照应该作为 patch 写作 checklist：**写 patch 前先 grep 看条件谓词 declare 了哪些变体**。

## Promotion Candidates

适合提升到 `architecture/xecjk-architecture.md`（修复点选择矩阵段后追加）：

- **修复模式选择的第二维度——调用方扫描语义**：

  | 调用方语义 | 例子 | 可用模式 |
  |---|---|---|
  | 普通无参/受参控制序列（patch 体可 wrap） | `\HD@target` (#873)、`\set@color` (#807/#831)、`\Hy@BeginAnnot` (#809/#810) | save/replay 或 drain |
  | 分隔符扫描宏（patch 体只能在原命令前下文） | `\verb` (#910)、`\Url@FormatString` (#880) | **仅 drain** |
  | math 模式吃掉 marker | `\Url@FormatString` (#880)、`\__codedoc_meta_original:n`（拟 #910 后续） | **仅 drain** |

  即：遮蔽节点类型决定了 `\@@_check_for_glue:` 探测失败的根因，调用方语义决定了能在哪个时机注入修复。

- **drain 的两种变体**：

  | 变体 | else 分支 | 适用条件 |
  |---|---|---|
  | `\@@_drain_ecglue:` | 主动 clear `\g_@@_last_node_tl` | 调用方之后**不再有 token-level interchar 转换**（如 `\url` 进 math）；或**需要主动清防御 tl 残留** |
  | `\@@_drain_ecglue_verb:` | **不**清 `\g_@@_last_node_tl` | 调用方之后仍走 token-level interchar（如 `\verb` 内 catcode-12 字符出 verb 后继续走 Default→CJK 或 CJK→CJK） |

适合保留为本反思（不上推）：

- expl3 条件变体拼写错误（`:T` vs `:TF`）的诊断教训，属于一般 expl3 写作经验。
- `\verb` 不能进宏参数的测试限制——已经在 [[556-verb-xkanjiskip-lltjcore]] 中记录，本次只是再次验证。

## Follow-up

- recorder 把上述两段（修复模式第二维度 + drain 两种变体）提升到 `architecture/xecjk-architecture.md`。
- recorder 在 `memory/decisions/` 新增一条 `910-verb-drain-vs-drain-verb.md`，记录 `\@@_drain_ecglue_verb:` 不复用 `\@@_drain_ecglue:` 的设计决策与 ctex 模式 verbatim01 回归证据链。
- `\meta` 残余尾巴：myhsia Update x4 锁定到 `\@@_recover_glue_whatsit:` default 分支被 hyperref destination whatsit / `\codeline@wrindex` `\write` whatsit 误触发。已有 workaround `\cs_set_protected:Npn \__codedoc_meta:n #1 { \__codedoc_patchxe_meta:n { \hbox:n {#1} } }`。修复路径有两种候选（drain `\__codedoc_meta_original:n` 或收窄 default 分支），下一次任务再评估。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` 中 `\@@_drain_ecglue_verb:` / `\@@_patch_verb:` 段（commits `d6e28be1` 主修复 + `d0cf09a1` 版本号 + `32553705` 专用 drain）。
- 回归测试：`xeCJK/testfiles/verb-ecglue01.lvt` / `.tlg`。
- 同方向对照反思：[[873-880-meta-url-hbox-math-boundary]]（hbox / math 遮蔽两类）、[[556-verb-xkanjiskip-lltjcore]]（ctex luatex 下 `\verb` 同源问题与测试参数禁忌）。
- 决策记录：[[../decisions/873-880-fixed-point-vs-default-narrowing]]（"修复位置由被遮蔽的节点类型决定"，本轮补一个隐藏维度——调用方扫描语义）。
