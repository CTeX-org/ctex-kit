---
name: 465-fntef-font-state-and-underdot-space
description: xeCJKfntef #465 修复反思：ulem 下字体状态跨分组丢失 + \CJKunderdot 的 \ignorespaces 吞空格
type: reflection
---

# [Task Reflection]

## Task
- 为 xeCJKfntef issue #465 记录一次双问题修复反思：一是 `\CJKunderline{...}` 等 ulem 路径中，CJK→CJK 过渡会关闭并重开 CJK 分组，导致 `\bfseries` / `\sffamily` 等字体状态在边界处丢失；二是 `\CJKunderdot` / `\CJKunderanysymbol` 在命令尾部调用 `\ignorespaces`，吞掉了后续本应保留的组间空格。
- 总结这次定位过程中走过的错误路径、真正起作用的诊断信号，以及后续在 xeCJK interchar / fntef / ulem 交界处排障时应优先复用的方法。

## Expected vs Actual
- 预期结果：
  - ulem 装饰命令内部的字体切换应跨越 xeCJK 的 CJK 分组边界保持连续，不应在 CJK→CJK 或 Default→CJK 过渡时退回旧的 NFSS / CJK family 状态。
  - `\CJKunderdot{文字{\bfseries 文字}} ~ \CJKunderdot{文字}` 中，两个装饰组之间应和普通文本、`\CJKunderline`、`\CJKsout` 等命令一样保留 `~` 产生的间距。
- 实际结果：
  - ulem 路径在 CJK 分组关闭再开启时，把局部赋值的 `\f@series`、`\f@shape`、`\l_xeCJK_family_tl`、`\CJK@family` 一起回滚，导致装饰文字中的字体切换不能跨边界延续。
  - 只有 `\CJKunderdot` / `\CJKunderanysymbol` 丢失后续空格，而 `\CJKunderline` 等共享 ulem 路径的命令没有同类问题，说明空格不是在通用 interchar / ulem 收尾逻辑中丢的，而是在 underdot 这一路径被单独吃掉了。

## What Went Wrong
- 排查空格问题时，前期过早把怀疑集中在 `\xeCJK_ulem_right:`、右侧 node hoisting、`\xeCJK_check_for_glue:` 以及“花括号是否会打断 XeTeX interchar 状态”这些机制上，做了多轮局部假设验证，但它们都没有解释“为什么只有 underdot 失效”。
- 初期诊断更关注“末端应该补上的 glue / kern 为什么没有生效”，而不是先证明“空格 token 到底有没有走到 underdot 内部入口”。这使得调查停留在输出节点后段，绕了较长一圈。
- 对字体状态问题，如果只盯 `ulem` 重启下划线这一表面动作，容易忽略 xeCJK interchar 架构里“关组再开组”本身就会回滚局部 NFSS/CJK 状态；真正丢失的不是装饰命令专有状态，而是 TeX 分组语义下的局部字体赋值。

## Root Cause
- 子问题 1（字体状态丢失）的根因是 xeCJK 的 interchar + ulem 联动实现基于显式分组：`\@@_ulem_CJK_and_CJK:N` 在处理 CJK→CJK 过渡时会关闭当前 CJK 组、停止/重启 underline、再打开新的 CJK 组。由于字体切换状态是局部赋值，组一关闭，`\f@series`、`\f@shape`、`\l_xeCJK_family_tl`、`\CJK@family` 就恢复到外层值。修复必须围绕“跨组边界搬运字体状态”展开，而不是只改 underline 启停顺序。
- 子问题 2（空格丢失）的根因是 `\CJKunderdot` 和 `\CJKunderanysymbol` 定义末尾的 `\tex_ignorespaces:D`。它会无条件吞掉命令后的空格 token，包括用户刻意写出的 `~` 所对应的空白语义。由于 `\CJKunderline` 等 ulem 路径根本没有 `\ignorespaces`，所以它们能正常把空格交给 xeCJK 的 interchar 机制处理，问题自然只在 underdot 路径暴露。

## Missing Docs or Signals
- 这次暴露出一个文档空缺：xeCJK 与 ulem 的兼容层里，只要存在“关组/开组”重建边界的实现，就必须显式盘点哪些状态是局部赋值且需跨组保存恢复，尤其是 NFSS 系列与 xeCJK family 状态。这类规则目前更像隐含经验，而不是稳定文档中的明确检查项。
- 另一个缺失信号是：对 inline decoration 命令，`\ignorespaces` 不是“无害的尾部清理”，在 xeCJK 这种依赖 interchar 空格/边界观察的系统里，它会直接篡改后续 token 流，应默认视为高危操作。这个约束值得在 guide/reference 中明确。
- 诊断方法层面，也缺少一条更显式的提示：遇到“空格消失”时，应优先在装饰命令内部入口记录 `\lastkern` / `\lastskip` 或等价前态，先判断 glue 是否根本没有进入路径，而不是直接追尾部收尾宏。此次在 `\@@_under_symbol_auxii:nnnnnn` 入口看到第二次调用时 `lastkern=0.00017pt, lastskip=0.0pt`，才真正证明空格 glue 从未出现。

## Promotion Candidates
- 适合先留在 memory 的内容：
  - 本次具体的误判顺序：先怀疑 `ulem_right`、node hoisting、brace 对 interchar 的影响，最后才通过 AUXII 入口态定位到 `\ignorespaces`。这类调查弯路适合保留为案例，便于下次遇到相似症状时快速排除，但不必直接写进稳定架构文档。
  - `fntef-space01` 通过宽度比较而不是肉眼 PDF 对比来抓 spacing 回归，这一具体测试命名和案例设计也可先作为记忆沉淀。
- 值得后续提升到 stable docs 的内容：
  - 可写入 `guides/` 或 `reference/`：在 xeCJK 的 inline 装饰/包装命令里，避免尾部 `\ignorespaces`，因为空格应交给 interchar 机制统一决策；若确有需要，必须先证明不会吞掉用户有意保留的边界 token。
  - 可写入 `guides/`：定位 xeCJK spacing bug 时，优先看“入口态”而不是只看最终节点。通过在关键入口记录 `\lastkern` / `\lastskip` / 盒宽，能快速判断问题发生在 token 被吃掉、glue 未生成，还是生成后又被收尾逻辑改写。
  - 可写入 `architecture/` 或 `reference/`：凡是 xeCJK interchar 兼容层通过 TeX 分组重建上下文的代码，都应把“需要跨组保存的局部状态”作为显式设计点，至少包括 NFSS series/shape 与 xeCJK family 变量。
  - 可写入 `reference/build-and-test.md`：对 xeCJK spacing 类问题，盒宽比较通常比视觉检查更稳；对字体状态类问题，`\showbox` 输出是确认真实字体切换是否跨边界保留的可靠信号。

## Follow-up
- 后续若再修改 xeCJKfntef / ulem 兼容层，优先做两类回归：
  - 字体状态类：构造含 `\bfseries`、`\sffamily`、族切换的装饰文本，用 `\showbox` 验证跨 CJK 边界后的实际字体节点。
  - 空格类：用 plain/underline/underdot 并排宽度比较，确认装饰命令不会吞掉组间空格或 `~` 对应宽度。
- 若后续再整理稳定文档，优先把“inline decoration 禁用 `\ignorespaces`”与“跨组边界显式保存 NFSS/CJK family 状态”提升为 xeCJK 兼容层的通用维护规则。
