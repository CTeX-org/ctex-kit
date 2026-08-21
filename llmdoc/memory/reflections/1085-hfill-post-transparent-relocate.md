---
name: 1085-hfill-post-transparent-relocate
description: 记录 #1085 修复 xeCJK post-transparent 边界恢复把 \hfill 无限阶填充 glue 误当候选搬运、致使 \null 排到 fill 之前破坏居中的问题；核心教训是陈旧构建产物 xeCJK.sty 导致方向性误判、复用带守卫函数未重验新调用点前置条件、\par 自身 \unskip 污染诊断需用 \hbox to 隔离、测试注释没实测就写具体，以及自动分析根因方向对但代码定位错
metadata:
  type: feedback
---

# [Task Reflection]

## Task

Issue #1085：xeCJK 下 `\noindent\hfill 秋风 \hfill\null\par` 这类居中写法，当 CJK 文字
后有源码空格、行尾是 `\null` 时，右侧 `\hfill` 的填充 glue 位置错乱，导致文字不居中、被
推到右边距甚至溢出。纯西文（`Title`）和花括号包裹（`{秋风}`）正常，裸 CJK 和
`\begingroup 秋风 \endgroup` 异常。

修复在 `xeCJK.dtx` 的 `\@@_boundary_post_transparent_relocate_glue:`（#1003／PR #1005
引入），单点改动 + `\changes{v3.10.6}`；回归测试在 `command-boundary02.lvt` 新增
TEST 16–19。

## Expected vs Actual

- 预期：`\@@_boundary_post_transparent_relocate_glue:` 已由 #1003／PR #1005 验证过右边界
  恢复逻辑，本次只需在其判据里加一条排除条件。
- 实际：函数无条件 `\tex_unskip:D` 取走末尾 glue 并当作候选搬运，未区分该 glue 是否为
  无限阶（fil/fill）填充 glue。`\hfill` 产生的 `0pt plus 1fill` 被当成普通候选，结果
  `\null` 被排到 `marker + fill` 之前（实测节点序 `null, marker, fill`，正确应为
  `marker, fill, null`），`\null` 不在列表末尾，破坏两侧 `\hfill` 的对称填充。

## What Went Wrong

1. **用陈旧构建产物 `xeCJK.sty` 复现，得到方向相反的结论。** 任务开始时直接用工作树里
   既有的 `xeCJK/xeCJK.sty`（一个旧的构建产物）复现问题，得出「当前 master 已修复此
   bug」的**完全相反**结论，险些据此关闭 issue。真相是那个 sty 落后于当前 `.dtx`。
2. **第一版门控复用了不匹配前置条件的守卫函数。** 直接复用同文件 Boundary→Default 方向
   的 `\@@_skip_if_interword:N`（要求 finite + 带 shrink + 宽度等于词间空格）。跑回归
   立刻发现 `command-boundary-math05` 的 `null-explicit` 场景（`\textnormal{$x$ }\hskip
   7pt\null`）height-delta 从 0 变 8.52pt——`\hskip 7pt` 无 shrink，被 interword 判据
   误拦，破坏了 #1002／#1003 的 math-space 恢复。
3. **`\par` 自身的 `\unskip` 一度让诊断误判为「fill 彻底消失」。** 段落模式下 LaTeX 的
   `\par` 在行尾会 `\unskip`，叠加在 xeCJK 行为之上，使节点日志一度看起来像「fill 丢失」，
   实际隔离 `\par` 后才看清是「顺序错乱 + `\par` 的 `\unskip` 二次作用」。
4. **新增测试的标题和注释在没实测判别力之前先写具体。** TEST 18（finite `\hskip 30pt`）
   最初标题写「keeps a finite non-interword glue in place」、注释写「the `\null` must
   not jump in front of it」；撤掉修复重跑后发现该测试**不在** diff 里——finite glue 在
   新旧逻辑下都照常搬运，`\null` 确实前移，但 30pt 无伸缩，位置错了也无视觉影响，不是
   bug，与最初写的说法方向相反。
5. **自动分析给出的根因方向对，但代码定位错。** issue 里 codex 机器人的分析说「unskip
   移除末尾 glue 后 fallback 没恢复」——方向对，但它指向 Boundary→CJK 的
   `\@@_check_for_glue_skip_consume_and_fallback:`，实际发生在 post-transparent 的
   `\@@_boundary_post_transparent_relocate_glue:`。自动分析的「症状描述」可作线索，但
   「代码定位」仍需用节点实测 + 读码独立确认，不能直接采信。

## Root Cause

`\@@_boundary_post_transparent_relocate_glue:` 在搬运「marker + 候选 glue」后缀之前，
只检查该 glue 是否物理相邻于末尾零尺寸盒子，没有检查它的伸缩阶数。`\hfill` 的
`0pt plus 1fill` 满足「物理相邻」这一条件，因而被当成与词间空格、显式 `\hskip` 同类的
候选处理，搬运顺序把 `\null` 排到了 fill 之前。

## Missing Docs or Signals

- `xecjk-architecture.md` 里对 post-transparent 候选 glue 的描述（约 185 行附近）只列了
  「真实空格」「显式 glue」两类物理形状，未提及需要排除无限阶填充 glue；本次改动后应补充
  这一条件。
- 判别力验证的做法（撤掉修复重跑，比对哪些测试变红）在既有 lessons-learned 里已有原则，
  但本次是「新增测试先写故事化标题、后被判别力验证证伪」的又一次具体发作，说明该原则仍
  需要在写测试注释这一步反复提醒。

## Promotion Candidates

- **在同一仓库内新旧构建产物之间也会出现「加载了非当前实现」的失效，不止 TEXINPUTS 指向
  系统版这一种形态。** 已有 lessons-learned 条目「从源码树验证时必须核对实际加载文件」
  只覆盖了 TEXINPUTS 指向系统安装宏包的情形；本次是工作树里 commit 出来的 `.sty` 落后于
  `.dtx` 源码的新变体，判据也不同：`\GetIdInfo$Id:` 版本戳只由 `l3build tag` 回写，不
  随普通编辑更新，不能用它判断 sty 内容是否反映当前代码。建议在该条目下补一条子情形，
  或在 `build-and-test.md` 里提醒「用 sty 复现前先 `l3build unpack` 从当前 dtx 干净解包」。
- **复用带守卫函数必须重验其在新调用点的前置条件，这条已在 lessons-learned 里，本次是
  被回归测试当场抓住的实例，可以作为该条目的 Source 补充。** 教训要点：同一个「候选
  glue」在不同恢复路径有不同的合法形状集合——Boundary→Default 的候选一定是源码空格
  （interword 形状），post-transparent 的候选还包括 math-space 参数内的显式 glue（可能
  无 shrink、宽度任意），门控不能照抄。
- **诊断 xeCJK 边界恢复时，凡涉及行尾 glue 的问题，先用 `\setbox0=\hbox to <宽>{...}`
  固定宽度、不经段落算法，隔离掉 `\par`／`\parfillskip`／`\rightskip` 的干扰，再看节点
  序。** 这条尚未见于 lessons-learned，值得单独收录：`\par` 的 `\unskip` 是本仓库反复
  要处理行尾 glue 时的通用背景噪音，不是本次特有。
- **判别力验证要区分「这条测试测的是 bug」还是「测的是未变行为」，测试标题与注释要按
  实测结果写，不能先写故事化描述再验证。** 已有「没实测就写具体」类教训（参见
  `1043-halign-alignment-tab-in-boundary-args.md`、`1057-fntef-nest-linebreak.md`），
  本次是同一失效模式在「测试标题/注释」这一具体载体上的又一次发作，Source 可以追加
  本反思。

## Follow-up

- recorder：`llmdoc/architecture/xecjk-architecture.md` 中 post-transparent 候选 glue
  的描述需要补充「排除无限阶（fil/fill）glue，用 `\skip_if_finite:nTF` 判断，非有限则
  不搬运，直接把零尺寸盒子放回末尾」这一条件，并说明它与 #1003 已有的 math-space 例外
  是两个独立维度（一个管阶数、一个管相邻关系）。
- 若后续再出现「用工作树里的 `.sty` 复现问题」场景，先确认该文件是刚从当前 `.dtx`
  `l3build unpack` 出来的，不要依赖文件已存在这一事实。

## 相关引用

- Issue：#1085。关联：#1003、PR #1005（引入 `\@@_boundary_post_transparent_relocate_glue:`）。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_boundary_post_transparent_relocate_glue:`。
- 测试：`xeCJK/testfiles/command-boundary02.lvt/.tlg` TEST 16–19；回归核对未误伤
  `command-boundary-math05` 的 `null-explicit` 场景。
- 架构：[[../../architecture/xecjk-architecture.md]]。
- 相关反思：[[1005-xcjkecglue-right-boundary-recovery]]（post-transparent 恢复机制的
  原始确立与「有限节点移动必须同时有注册范围、尺寸条件和物理 marker 证据」）、
  [[1054-l3backend-defense-scope-and-kpse-lsr]]（「从源码树验证时必须核对实际加载文件」
  的另一种发作，那次是 TEXINPUTS 指向系统版，本次是仓库内构建产物陈旧）、
  [[1043-halign-alignment-tab-in-boundary-args]]（「没实测就把测试注释写具体」的同型
  教训）、[[1057-fntef-nest-linebreak]]（「判别力验证要区分测的是 bug 还是未变行为」的
  同型教训）。
