---
name: 931-biblatex-pagetracker-let-shadow
description: 反思 xeCJK #931 中 biblatex 的 pagetracker=page 选项通过 \let 拷贝 \blx@pagetracker@context 到 \blx@pagetracker 的时机陷阱——正确 hook 点必须是 \let 目标而非 \let 源，且必须延迟到 \at_end_preamble 才生效
metadata:
  type: feedback
---

# [Task Reflection]

## Task

修复 xeCJK issue #931：中文参考文献条目首字符前多出一段空白。zepinglee 提供的 minimal repro（`biblatex` + `authoryear` style + `biber` backend）显示 `张伯伟 2002` 里 `张` 前有多余 `\CJKecglue`，二分定位到 xeCJK 的 `0118358a`（PR #315 全局 whatsit 恢复链）。

修复落地为 `xeCJK.dtx` 中新增 `\@@_patch_biblatex_pagetracker:` 段（补丁点选 `\blx@pagetracker`，hook 时机 `\@@_at_end_preamble:n`），语义为清空 `\g_@@_last_node_tl` 而非补/drain ecglue；新增回归测试 `xeCJK/testfiles/biblatex-ecglue01.lvt`。`xeCJK l3build check` 88/88 全绿。

## Expected vs Actual

- 预期：`\@@_recover_glue_whatsit:` 的 default 分支被 biblatex 的 `\abx@aux@page` `\write` whatsit 误触发（与 #920 l3doc `codeline@wrindex` write 同源），照 #920 模式在 biblatex 侧下 patch 就行。
- 实际：**第一次 patch 挂在 `\blx@pagetracker@context` 完全不生效**——加 `\iow_term:x` 打点也没输出。根因是 biblatex 的 `authoryear.bbx` 通过 `\ExecuteBibliographyOptions{...pagetracker,...}` 在**加载 bbx 时**展开 `\blx@opt@pagetracker@page`，其内部执行 `\let\blx@pagetracker\blx@pagetracker@context`——注意是 **`\let` 值传递**而非**符号引用**。xeCJK 用 `\@@_package_hook:nn { biblatex } { ... }` hook 到 `package/biblatex/after` fire 时，`.bbx` 已经加载完，`\blx@pagetracker` 早就 let 到了 orig 版的 `\blx@pagetracker@context`；此时改源函数 `\blx@pagetracker@context` 已经改不到 `\blx@bibitem` 里实际调用的 `\blx@pagetracker` 拷贝。
- 修正：补丁点从 `\blx@pagetracker@context`（\let 源）改为 `\blx@pagetracker`（\let 目标），hook 时机从 `\@@_package_hook:nn { biblatex }` 改为 `\@@_at_end_preamble:n`——此时 `.bbx` 已完全加载，`\blx@pagetracker` 已 let 到最终目标（可能是 `\blx@pagetracker@context` / `\blx@pagetracker@spread` / `\relax`），无论指向哪个都能包住。

## What Went Wrong

1. **误把 `\let` 当符号引用**。直觉上把 `\let\A\B` 看成"以后 `\A` 都跳去 `\B`"，其实 TeX 里是**值传递**——`\A` 冻结到执行 `\let` 那一刻 `\B` 的 meaning，后续再改 `\B` 不影响 `\A`。这是 TeX 补丁最经典的时序陷阱之一，本次踩中的形态是"biblatex 的 pagetracker 用 `\let` 把可选行为绑定成硬拷贝"。同型陷阱在 hyperref / listings 等宏包里也常见（`\let\originalCS\somecommand` 保存旧定义再重定义 `\somecommand`，patch 挂在 `\somecommand` 上就不会生效）。
2. **hook 时机与包内部延迟展开的耦合没排查**。`\@@_package_hook:nn { biblatex }` 展开为 `\ctex_at_end_package:nn { biblatex }`，即 `package/biblatex/after` LaTeX3 hook——它 fire 时机是**包主 `.sty` 执行完**，但 biblatex 的 style 加载（`\RequireBibliographyStyle{\blx@bbxfile}` at biblatex.sty L16439）**在 `.sty` 内部**发生，也就是 hook fire 之前 `.bbx` 已经加载并跑了 `\ExecuteBibliographyOptions`。事前没想到"包主 sty 加载内部会 require 一系列 style 且立即 exec options"这种嵌套 mount 模型。
3. **诊断第一步做错了 grep 方向**。看到多余 ecglue 就直接扫源码里 `abx@aux@page`——找到 `\blx@pagetracker@context`（write 的宿主）就当成 hook 点，没进一步查"这个 context 函数是**谁**调用"。正确顺序应该是从 `\blx@bibitem` 逆推：`\blx@bibitem` 调 `\blx@pagetracker` → grep 才发现 `\let\blx@pagetracker\blx@pagetracker@context`。走反了 grep 方向浪费了一次全 build + run 的迭代（xeCJK unpack + biber + xelatex ×3 大约 15s，本次多试一轮）。
4. **首次 unpack 后没确认 sty 时间戳与 dtx 一致**。改完 dtx 直接 xelatex 跑，看到多余 ecglue 还在时以为 patch 逻辑不对，实际是 `xeCJK.sty` 还是旧的（dtx 10:04、sty 10:02）。这次是靠"文件加载对不对？历史上好几次搞错了版本来着"的人肉纠错才发现。已有 memory 里没记录这条硬约束（`dtx` 改完必须 `l3build unpack` + 显式检查 sty mtime）。

## Root Cause

- **理论根因（`\let` 拷贝时机的心智模型盲区）**：xeCJK 已有 patch 都对准**语法上"看起来会被调用的名字"**（`\Url@FormatString`、`\HD@target`、`\Hy@BeginAnnot`），而 biblatex 的 `pagetracker` 选项引入了一层"选项驱动的 `\let` 绑定"——语法上 `\blx@pagetracker` 是被调用者，但语义上它是 `\let` 的**目标**。所有第三方补丁模式（save/replay / drain / clear last_node_tl）都必须先解决"补哪个名字"，然后才轮到语义模式选择。**补丁点选择的第三维度：目标控制序列是否是 `\let` 拷贝**——是的话必须 patch `\let` 目标本身，且必须等 `\let` 执行后才装 patch。
- **方法根因（hook 时机分类不完整）**：xeCJK 现有 hook 只有三档：`\@@_after_preamble:n`（`begindocument/end`）/ `\@@_at_end_preamble:n`（`begindocument/before`）/ `\@@_package_hook:nn`（`package/<name>/after`）。前两档都在 preamble 结束后 fire（此时任何 `\let` 都已定型），第三档 fire 早于 preamble 结束，能捕获包内部**首次** `.sty` 加载结束的瞬间。对于"包会在自己 sty 内部立即 exec 选项 + `\let` 绑定"这类嵌套加载模式，`\@@_package_hook:nn` 就太早了；必须选前两档之一。
- **诊断流程根因**：`\iow_term:x` 打点确实是"patch 是否 fire"的可靠信号，但**前提是打点写到最终被调用的名字上**。本次打点在 `\blx@pagetracker@context`（\let 源），\let 拷贝完毕后源函数被替换，但被调用的名字（\let 目标）依然指向未打点的旧拷贝——所以没输出并不能证明"patch 没装"，反而恰恰暴露了"patch 装在了错的名字上"。

## Missing Docs or Signals

- 架构文档 `xecjk-architecture.md` 的"边界恢复修复点选择矩阵"目前只覆盖两个维度：遮蔽节点类型 + 调用方扫描语义。需要追加第三个维度：**目标控制序列的绑定形态**（普通 `\def` vs `\let` 拷贝目标）。
- 缺少 xeCJK hook 三档时机的对照表：（1）fire 时机相对 `\usepackage` 展开的先后；（2）能否捕获"包内部 nested `\Require*Style` 加载"；（3）能否捕获"包内部选项立即 `\let` 绑定"。
- `dtx` 改完后**必须** `l3build unpack` 才能重跑测试的硬约束，`reference/build-and-test.md` 里没写清楚"改 dtx 后跑测试的强制两步流程"。这条踩过好几次（本次是"改完直接跑"，靠 mtime 对比才自救），值得提升到 reference。

## Promotion Candidates

适合提升到 `architecture/xecjk-architecture.md`（修复点选择矩阵段的双维度后追加）：

- **补丁点选择的第三维度——目标控制序列的绑定形态**：

  | 绑定形态 | 例子 | 补丁点必须选 | Hook 时机 |
  |---|---|---|---|
  | 普通 `\def` / `\protected\def` | `\Url@FormatString` (#880)、`\HD@target` (#873)、`\Hy@BeginAnnot` (#809/#810) | 该 `\def` 本身 | `\@@_package_hook:nn` 或更晚 |
  | `\let` 拷贝目标（选项驱动的行为绑定） | `\blx@pagetracker` (#931) | **\let 目标**（不是 \let 源） | **必须** `\@@_at_end_preamble:n` 或 `\@@_after_preamble:n`，等 \let 执行完 |

- **hook 三档时机对照表**：

  | Hook | fire 时机 | 捕获包 nested `.bbx/.cbx` 加载后的 `\let` | 捕获包 nested `\Require*Style` 前的 `.sty` 定义 |
  |---|---|---|---|
  | `\@@_package_hook:nn { pkg }` | `package/pkg/after` = pkg 主 sty 加载完 | ✗（`.bbx` 已加载完，`\let` 已定型；但可以覆盖 sty 定义） | ✓ |
  | `\@@_at_end_preamble:n` | `begindocument/before` | ✓ | ✓（更晚，任何 sty 都能改） |
  | `\@@_after_preamble:n` | `begindocument/end` | ✓ | ✓ |

  关键判断：**如果目标控制序列会被包内部通过 `\let` 二次绑定，hook 时机必须晚于 `\let` 执行**。默认 `\@@_package_hook:nn` 已经足够处理绝大多数情况，但对 biblatex 这种"包 sty 内部就 `\Require*Style` 载入子样式并 exec 选项"的模式，必须显式退到 `\@@_at_end_preamble:n`。

- **`\@@_recover_glue_whatsit:` default 分支的第四类误触发场景**：`\write` whatsit（`biblatex \abx@aux@page` / `l3doc \codeline@wrindex`）。三个已知误触发场景（`\verb` 后 `\setlanguage` write / `l3doc \codeline@wrindex` write / biblatex `\abx@aux@page` write）指向同一个未来 PR——`\@@_recover_glue_whatsit:` default 分支收窄（[[../decisions/873-880-fixed-point-vs-default-narrowing]] 预留方向）。本次没走这条决策路径，而是在 biblatex 一侧做定点 patch，因为独立收窄 PR 涉及全 xeCJK 状态机的一致性验证，代价远大于一个包 patch。

适合保留为本反思（不上推）：

- `dtx` 改完必须 `l3build unpack` 的硬约束——已经在 `reference/build-and-test.md` 里隐含（`l3build` 章节），但没做成硬 checklist；本次是纯个人流程失误，属于工作流经验而非架构层面。若下次再踩，考虑升级为 memory feedback。

## Follow-up

- recorder 把 "补丁点选择第三维度" + "hook 三档时机对照表" 提升到 `architecture/xecjk-architecture.md`，插入到现有"修复点选择矩阵"段之后。
- recorder 在 `memory/decisions/` 新增一条 `931-biblatex-let-shadow.md`，记录"补丁点必须选 `\let` 目标 + hook 时机必须晚于 `\let` 执行"的决策与 biblatex `authoryear.bbx` 的具体证据链（`\ExecuteBibliographyOptions{pagetracker}` → `\blx@opt@pagetracker@page` → `\let\blx@pagetracker\blx@pagetracker@context`）。
- 未来若再遇到第三方 `\write` whatsit 误触发 `\@@_recover_glue_whatsit:` default 分支（第四例、第五例……），达到阈值时考虑推动 [[../decisions/873-880-fixed-point-vs-default-narrowing]] 中预留的 default 分支收窄独立 PR。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` 中 `\@@_patch_biblatex_pagetracker:` 段（本次改动 68 行注释 + 15 行代码）。
- 回归测试：`xeCJK/testfiles/biblatex-ecglue01.lvt` / `.tlg`（stub 版 `\blx@pagetracker` 触发 `\protected@write` whatsit）。
- biblatex 上游证据链：`biblatex.sty` L10195（`\blx@pagetracker@context` 定义）、L15618（`\let\blx@pagetracker\blx@pagetracker@context`）、L16439（`\RequireBibliographyStyle`）、`authoryear.bbx` L147（`\ExecuteBibliographyOptions{...pagetracker,...}`）。
- 同方向对照反思：[[910-verb-null-hbox-drain]]（drain 通用版 vs 专用版）、[[809-810-hyperref-annot-ecglue]]（`\Hy@BeginAnnot` 选择性重放 + 保留 `default` 分支的约束）、[[../decisions/910-verb-drain-vs-drain-verb]]（drain 变体决策）。
- 决策记录：[[../decisions/873-880-fixed-point-vs-default-narrowing]]（本次仍走 input-side fixed-point patch，未触发 default 分支收窄的独立 PR）。
