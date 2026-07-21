---
name: 1005-xcjkecglue-right-boundary-recovery
description: 记录 PR #1005 修复 #1003 时发现的右边界状态缺口，包括盒内过期 spacefactor、post-transparent 边界后缀移动、节点证据、changelog 门禁和并行测试误报
metadata:
  type: feedback
---

# [Task Reflection]

## Task

在 #999 的 capture/register 框架上增加公共能力，修复 #1003 中 `xCJKecglue=true` 时的两类普通命令差异：嵌套盒子或中西混合盒子以大写西文字母结束后，右侧源码空格没有换成 `CJKecglue`；`\null` 前存在显式 `\hskip` 时，零尺寸盒子遮住了可恢复的右边界。PR #1005 关联 #992，但不关闭它；合并后关闭 #1003。

实现提交为 e6ce56b4，changelog 提交为 b15474ca；42d58e11 和 7f6ed5e4 根据 Bot 的小建议补充两层节点检查的说明。

## Expected vs Actual

- 预期：#1003 的失败已经由矩阵精确列出，只需调整末类别 marker 的重放方式。
- 实际：两类场景中的末类别和物理 marker 都正确。缺失的是 marker 之外、下一次恢复仍要使用的状态：盒子路径需要外层列表真实的 `spacefactor`；post-transparent 路径需要保持“marker + 至多一枚 glue”的物理相邻关系。
- 预期：本地完整 xeCJK 与 ctex 测试通过后，首轮 CI 可以直接进入审查。
- 实际：`.dtx` 新增了 `\changes`，但首次提交没有运行 `make changelog`，因此 `check-changelog-result` 精确失败。补交 `xeCJK/CHANGELOG.md` 后全部 CI 通过。

## What Went Wrong

1. **把右边界过早压缩成单个类别 marker。** `\@@_boundary_box_set_last_from_node:` 已能正确取得 `default`，但盒内末尾大写字母把全局 `\g_@@_space_factor_int` 留成 999；盒内 TeX `\spacefactor` 不会传播到外层，盒外生成源码空格时实际使用 1000。旧出口只重放 marker，后续严格比较便用过期的 999 计算词间空格，错误保留 3.33pt，而不是换成 5pt `CJKecglue`。

2. **post-transparent 只处理了紧邻 marker。** `中 \hskip 7pt\null Alpha` 在 `\null` 后置 hook 执行前的列表末尾是“`CJK-space` marker + 7pt glue + 零尺寸 hbox”。旧实现取走 hbox 后只检查最后节点是否直接为 marker，看到 glue 就放弃；后续 Default 字符只能看到 hlist，无法让现有恢复链根据 marker 把 7pt 换成 `CJKecglue`。

3. **宽度差只说明结果，不说明恢复链在哪一步失效。** 可区分间距下的 1.67pt 与 2pt 差值提示了“普通词间空格”和“7pt 减 5pt”，但只有 `\showbox` 节点列表和 `spacefactor` 打点才证明：第一类失败是 999／1000 的缓存脱节，第二类失败是 hlist 截断物理后缀。若直接按差值补 glue，很容易形成新的逐命令补丁。

4. **完整测试也可能出现基础设施误报。** `make check-ctex` 的并行 LuaTeX 槽在首个用例报告 `build/check/abstract01.log` 不存在；同轮 pdfTeX、XeTeX、upTeX 和三组 config 全绿，随后在无并发写入的包目录执行 `l3build check -q -e luatex`，184／184 通过。这个证据组合说明问题来自并行临时目录，而不是本次 xeCJK 修改。

5. **0pt glue 也是需要保存的节点。** Bot 提到可以在 0pt 时不重新插入 glue，但 post-transparent 未命中 marker 时的契约是按原顺序恢复“glue + 零尺寸盒子”。删除 0pt glue 虽不改变自然宽度，却会改变 `\lastnodetype`、断行位置和后续恢复链能看到的节点证据，因此不能以“宽度为零”为由省略。

6. **新增 `\changes` 后没有在首次推送前更新 changelog。** 本地 `l3build check` 和 `l3build doc` 都不会证明生成的 `CHANGELOG.md` 已同步；这项要求由独立 CI 门禁检查。实现提交前应把 `make changelog` 与 `git diff --check` 一起列入固定收尾步骤。

## Root Cause

#999 的框架正确统一了“命令实际输出的首尾类别”，但右边界恢复不只依赖类别。它还依赖生成候选源码空格时所在列表的 `spacefactor`，以及 marker 与待检查 glue 在物理节点列表中的相邻关系。盒子和零尺寸 hbox 分别隔离了这两项信息，旧出口没有把它们恢复到外层。

## What Worked

- 在公共 `\@@_boundary_replay_node:n` 中，重放 `default`、`default-space` 或 `normalspace` 时同步 `\g_@@_space_factor_int` 与当前 `\tex_spacefactor:D`。stream 内容本来就更新外层值，box 内容则由这一步消除盒内缓存污染；不需要识别具体命令或大写字母。
- post-transparent 只跨越已经注册、且宽、高、深均为零的末尾盒子。第一层检查盒子是否直接盖住真实 marker；未命中时只暂存一枚末尾 glue，再检查其下方的 marker。命中后按“盒子、marker、glue”重放，未命中则按“glue、盒子”恢复原序。
- `command-boundary01` 把 #1003 的 16 个普通命令单元从精确跳过改为实际断言，总数从 1648 增至 1664，失败数为 0；#1002 的四个公式单元继续精确跳过。
- `command-boundary02` 用节点列表分别锁定三件事：大写盒子尾部得到 5pt `CJKecglue`；有源码空格时 `\null` 后得到 5pt；没有源码空格时显式 7pt glue 原样保留。宽度矩阵与节点基线互相补充。
- Bot 的小建议逐项处理：能提升维护性的注释直接补入；不应修改的性能和 0pt glue 建议则用调用频率、节点契约和测试证据回复。最后 `make check-pr-ci` 证明全部 CI 通过、没有未确认评论或未解决 thread。

## Missing Docs or Signals

- `xecjk-architecture.md` 需要把“右边界后续恢复所需的状态”补充为类别 marker、外层 `spacefactor` 和 post-transparent 的有界节点后缀，而不能继续只写“重放末类别 marker”。
- `992-command-boundary-capture-register.md` 需要把 #1003 从已知失败更新为 PR #1005 的修复机制与验证结果，同时保留“issue 活表只在合并后更新”的状态边界。
- `build-and-test.md` 中的 1648、20 个红叉、12 个节点测试和 #1003 已知失败已经过时，应更新为 1664、只剩四个 #1002 公式跳过、15 个节点测试和 #1003 的修复覆盖。
- `lessons-learned.md` 可以提炼一条跨任务规则：语义 marker 正确不代表恢复状态完整；跨列表恢复还要核对生成后续节点所需的引擎状态和物理相邻关系。

## Promotion Candidates

- **边界出口必须恢复后续判断所需的完整状态，而不只是最终分类。** 对需要在后续 token 到来时再决定动作的状态机，应列出后续判断读取的全部信息，包括引擎状态、物理节点和 pending 标志。
- **有限节点移动必须同时有注册范围、尺寸条件和物理 marker 证据。** 三项缺一不可；不能扩展为对任意 hbox/whatsit 的向后扫描。
- **宽度测试与节点测试应分别证明几何结果和恢复路径。** 可区分 glue 能放大差异，但仍需节点列表区分“值正确”与“节点来源、顺序正确”。
- **新增 `\changes` 时必须在首次推送前运行 `make changelog`。** `l3build doc` 通过不能替代 changelog freshness 门禁。

## Follow-up

- PR #1005 合并后，从合并提交重新运行 #992 活表使用的矩阵，再把 #1003 对应红叉改成绿勾；不要在 PR 尚未合并时提前修改 issue 活表。
- #1002 的四个公式单元不属于本修复，继续保留精确跳过和独立 issue，不把普通命令矩阵全绿误写成整个 #992 已完成。
- 如果未来为新的 post-transparent 命令注册 after-only 路径，必须先证明其末尾盒子确为零尺寸，并复用同一有界后缀移动，不能增加命令专用向后扫描。

## 相关引用

- Issue 与 PR：#992、#1003、PR #1005。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_boundary_replay_node:n`、`\@@_boundary_post_transparent_relocate:`、`\@@_boundary_post_transparent_relocate_glue:`。
- 测试：`xeCJK/testfiles/command-boundary01.lvt/.tlg`、`command-boundary02.lvt/.tlg`。
- 调查缓存：`.llmdoc-tmp/investigations/issue-1003.md`，使用前已由主代理按节点列表和完整回归重新验证。
- 架构与决策：[[../../architecture/xecjk-architecture.md]]、[[../decisions/992-command-boundary-capture-register.md]]、[[../../reference/build-and-test.md]]。
