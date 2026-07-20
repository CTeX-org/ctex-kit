---
name: 1001-boundary-capture-gap-fixes
description: 反思 PR #1001 在 #999 capture/register 框架上收敛 #992 状态表三个跟踪项（#996 Boundary→CJK 缺对称校验、#998 math/rule 对 capture 不可见、#1000 siunitx）时的判据收敛过程、`report_first` 与 `last_tl` 语义分裂、管道吞退出码再犯，及测试驱动跨版本引用已删除变量
metadata:
  type: feedback
---

# [Task Reflection]

## Task

在分支 `fix-996-998-1000-boundary-capture` 上收敛 #992 状态表遗留的三个跟踪项，均建立在 #999 的 capture/register 框架之上：#996（Boundary→CJK 方向缺少与 Boundary→Default 同款的同构 glue 校验，导致跨盒 pending 泄漏）、#998（`\mbox{$x$}`、`\mbox{\vrule}` 等 math/rule 内容不触发 interchar 转换，box/wrapped-box capture 把有墨迹的盒子误判为“无可见输出”并透明恢复）、#1000（siunitx 的 `\unit`/`\qty`/`\num` 首字符是 `\mathon`，遮蔽左侧 CJK marker，源码空格丢失）。四个 commit：085f4f86（#996）、14336c4d（#998）、c8c803bf（#1000）、a1df81ef（基线刷新）。CI 全绿，自动 review APPROVE，0 阻塞 0 重要 3 小建议（2 条以证据判定不改，1 条维护者明确跳过）。

## Expected vs Actual

- 预期：#999 已把命令边界收敛为五类注册策略（box/wrapped-box/stream/transparent/post-transparent），#992 剩余三项只是往同一套状态机里补边界条件，属于收尾性质的小修复，验证一轮全量测试即可关闭。
- 实际：三项修复各自暴露了框架建立时未覆盖的语义缝隙——#996 的 pending 旗标是全局的且能跨 `\setbox` 分组存活；#998 的“可见输出”判据从“观察到字符类别”这一个维度不够，需要盒子几何 + 尾节点墨迹两个维度联合判定，且判据每收紧一轮就命中新的下游反例（ctex 内核 `\[` display leader、thuthesis 封面预排盒）；#996 顺带修复的两个历史基线（boundary-space02、fntef-space02）证明旧值本身就是要修的 bug，不是要保护的行为。全量测试第一轮因为管道吞了退出码，一度看不出六个测试的回归。

## What Went Wrong

1. **管道吞退出码几乎掩盖 6 个测试回归**。第一轮全量验证跑 `l3build check -q 2>&1 | tail`，看到的尾部输出显示正常就当作通过；实际 `l3build` 的真实退出码是 1，boundary-space02、cjkmath01、cjkmath02、fntef-space02、ref-ecglue01、ref-ecglue02 六个文件产生了 diff。`tail` 截断了完整失败列表，而管道结构本身让 shell 拿到的是 `tail` 的退出码而非 `l3build` 的。这与既有「git push 不接管道」是同一条规则在测试执行侧的再次发生——凡是要靠退出码判断成败的命令，管道后接任何二次处理都会把真实 rc 吞掉，必须先落文件再 `echo EXIT=$?` 单独确认。

2. **「无可见输出」判据三轮才收敛，每轮都命中新反例**。初版判据只看“观察类别是否为空”，被 ref-ecglue01 的 `\nfss@text{??}` 戳穿——undefined `\ref` 产生的 `??` 属于 HalfRight 标点类，不进入 CJK/Default 观察类别，在 stream 内外表现不一致。二版加入“盒尺寸非零（宽 && (高 || 深)）”，暴露 ctex 内核 `\[` 在垂直模式插入的 `\makebox[.6\linewidth]{}` 空白占位盒（cjkmath01/02 回归）被误判为有内容，以及 ctxdoc `resize-function` 与 thuthesis 封面 `\thu@pad` 里 `\makebox[..][l]{\box...}` 这类把预排盒塞进末尾的命令同样命中。终版加尾节点探针（`\hbox_unpack:` 复制到临时盒后取 `\lastnodetype:D`：char=0、rule=3、math=10、punct-kern=12 才算现场排版的墨迹；hlist=1、glue=11 保持透明，因为它们可能是预排盒或填充对齐）。核心教训是「可见性」不能只看几何尺寸，必须区分“本层现场排版留下的痕迹”与“预先构造好塞进来的盒子/纯空白占位”，前者才该按 Default 重建边界，后者必须保持透明恢复。每收紧一轮判据都要重跑全量 xeCJK + ctex 四引擎 + config-contrib + config-ctxdoc，thuthesis 封面这类下游模板反而是暴露反例最快的信号源——这与 lessons-learned 里“可见排版修复需要三类证据”“命令边界修复必须覆盖输出等价矩阵”是同一条规则的又一次具体应验，本次的新增细节是“下游模板比自造 MWE 更容易撞到框架假设的边界”。

3. **「向外层报告」与「运行时观察」被同一个函数混用，酿成 fcolorbox 回归**。#998 初版直接复用既有的 `\@@_boundary_capture_class:n` 把推断出的 default 上报外层，但该函数同时会覆写外层的 `last_tl`——fcolorbox 的 wrapped-box 内部先含一个 box，内层盒的 default 推断把“内容其实已经上报过 CJK”的外层末类别降级覆盖，四格 fcolorbox 全灭。修复方式是新增专用函数 `\@@_boundary_capture_report_first:n`：只写尚未取得 `first_tl` 的外层（`tl_if_empty:cT`），完全不动 `last_tl`；外层的真实末类别改由本层重放的 marker 以列表证据自行修正。这次的教训不是“加个 if 判断就完事”，而是两个操作本来语义不同——“报告首类别推断值”和“更新已观察到的末类别”——却共享同一入口函数，命名上区分开来才能防止未来再复用错。

4. **旧基线本身可能是需要修的 bug，不是要保护的行为**。boundary-space02（测试名字面意思是“CJK + backslash-space preserved”）与 fntef-space02（“explicit backslash-space before fntef preserved”）的旧基线分别是 20pt 和 40pt——两者的测试名和注释都在断言“显式 `\ ` 应该原样保留”，但旧值实际上是“前一个测试的盒尾泄漏的 pending 把这次的显式 `\ ` 吞成了 CJKglue”产生的错误输出。#996 修复 pending 过期机制后，新基线 23.33pt/43.33pt 才真正符合测试名字面语义。判定“基线更新是修复而非引入回归”的方法：先看测试名/注释与断言值是否自相矛盾，再用节点级证据确认（`.tlg` 里 `\glue 3.33` 对应保留的显式空格，`\glue 0.0 plus 0.96` 对应被吞成 CJKglue 的错误旧值）。

5. **复用型测试驱动引用内部变量必须防御跨版本删除**。gh-assets 上驱动 #992 矩阵的 `\MatrixReset`（`issues/992/showcase-lib.tex` 及 `command-boundary-*-matrix.tex` 等多个驱动共享同一段代码）直接 `\bool_gset_false:N \g__xeCJK_reset_color_pending_bool`，该变量在 #999 里已被删除；驱动在新 master 上跑会直接报未定义变量错误。修复是加 `\bool_if_exist:NT \g__xeCJK_reset_color_pending_bool { \bool_gset_false:N \g__xeCJK_reset_color_pending_bool }` 守卫。核心问题是这类“可复用测试基础设施”默认假设“能在任意后续 master 上重跑”，但它引用的是被测框架的内部私有变量而非公开接口；框架重构删掉该变量时，驱动侧的隐含假设会静默失效，不会有任何编译期信号提示“这段驱动过期了”，只有真正重跑才会暴露。

6. **PR 证据链按角色分层，且严格遵守“已合并 issue 活表不在合并前更新”的既有惯例**。首评占位内容被替换为三个 issue（#996/#998/#1000）各自的 before/after 视觉对比：同一份 MWE 源码通过切换 `TEXINPUTS` 分别用 master 解包和分支解包的 `xeCJK.sty` 各排一次，`pdftoppm` + `magick` 拼图，BEFORE 标红、AFTER 标绿；gh-assets 固定提交 `fcff1eb3`。#992 issue 的活表按 #999 反思里已确立的惯例，等真正 merge 后再从合并提交复验并更新，本轮只在 PR body 和 gh-assets README 留预览表，没有提前动活表。

## Root Cause

- #1 的根因是判断成败的信号来源与实际执行链路脱节：用退出码判断成功，却让退出码经过了一层不相关的命令（`tail`），这在任何“先跑命令再看结果”的场景里都会复现，不只限于 git push。
- #2/#3 的共同根因是“capture/register 框架建立时的抽象层级”与“新增边界条件所处的语义层级”不匹配：框架在 #999 建立时是按“运行时观察到的首尾类别”这一维度设计的单一信号源，而 #998 需要的信号（“有墨迹但没有被 interchar 观察到”）和 #996 需要的信号（“pending 旗标应该跟着分组结束周期性过期，而不是全局常驻”）都不在原设计的单一维度里，必须新增维度而不是在旧维度上加分支。#3 尤其体现在“报告”和“观察”被复用同一个函数入口，说明新增维度时如果不新增独立命名的函数，语义会互相污染。
- #4 的根因是历史基线在建立时没有做“测试名/注释与断言值一致性”的自查，只要 `.tlg` 生成成功就被当作 ground truth 固化，后续任何看到该基线的人都会默认它是正确行为而不会去反查测试名字面语义。
- #5 的根因是测试基础设施（尤其是长期维护在 orphan 分支上、被多个驱动共享的公共库）与被测框架的耦合方式是“直接引用内部私有变量”而不是“通过公开接口交互”，这种耦合在被测框架内部重构时没有任何显式契约保证兼容。

## Missing Docs or Signals

- `reference/build-and-test.md` 目前没有把“`l3build check` 之类靠退出码判断成败的命令，禁止直接接管道二次处理”写成显式规则；现有的「git push 不接管道」规则范围窄，只覆盖了 push 场景，没有泛化到所有依赖退出码的验证命令。
- `xecjk-architecture.md` 里 #992 capture/register 模型段落目前记录了“运行时首尾类别恢复”这一个信号维度，但没有记录“box/wrapped-box 的可见性判据是几何尺寸 + 尾节点墨迹类型的联合判定”这第二个维度，也没有记录“report_first 与观察到的 last_tl 是两个独立操作，不能共享同一入口函数”这条约束。
- gh-assets 上被多个矩阵驱动共享的测试库（`showcase-lib.tex` 及各 `*-matrix.tex`）没有任何“依赖的框架内部变量清单”或“兼容性检查”机制，导致框架重构删变量后驱动静默失效，直到真正重跑才发现。

## Promotion Candidates

- **管道吞退出码的泛化规则**：应把既有 `feedback_git_push_no_pipe.md` 的适用范围从“git push”扩展为“任何靠退出码判断成败且输出可能很长的验证命令”，本次 `l3build check -q 2>&1 | tail` 正是同一类反例，值得在该 feedback 文件或 `reference/build-and-test.md` 里补一条通用写法：`cmd > /tmp/x.log 2>&1; echo EXIT=$?`，先落文件再看内容，且必须显式打印/检查 `EXIT` 而不是靠肉眼扫尾部输出判断。
- **可见性联合判据可以提升到 `xecjk-architecture.md`**：box/wrapped-box capture 的“无可见输出”判定矩阵（观察类别为空 AND 几何全零 → 透明；观察类别为空 AND 几何非零 AND 尾节点是 char/rule/math/punct-kern → 按 Default 重建；观察类别为空 AND 几何非零 AND 尾节点是 hlist/glue → 保持透明）值得整理成表格附加到现有 #992 段落，作为“判定可见性不能只看单一维度”这条已有 lessons-learned 规则的最新、最完整的一个应验案例。
- **`report_first` vs 覆写 `last_tl` 的函数命名区分**，可以作为 #992/#999 段落里“capture 内部状态更新契约”新增一条子规则：任何向外层 capture 传递推断值的函数，必须显式声明它只写“尚未观察到的槛位”还是“覆盖已观察到的槛位”，两者不能用同一个函数名。

## Follow-up

- 若后续还遇到测试驱动因框架内部变量重命名/删除而失效的第三个实例，考虑给 gh-assets 上的共享矩阵驱动补一条“框架内部变量依赖清单 + 存在性守卫”的通用约定，而不是逐个案例补 `\bool_if_exist:NT`。
- 下次涉及“靠命令退出码判断验证是否通过”的任务开始前，主动确认执行方式是否符合“落文件 + 单独 echo EXIT”，不要依赖对既有 `feedback_git_push_no_pipe.md` 规则名称的字面匹配来判断适用范围。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` 中 `\@@_glue_check_expire_stale:`（#996）、`\@@_boundary_if_capture_box_visible:` + `\@@_boundary_capture_report_first:n`（#998）、siunitx package hook 段（#1000）。
- 回归测试：`xeCJK/testfiles/boundary-crossbox01.lvt/.tlg`（#996 MWE、workaround 与同列表歧义窗口）、`xeCJK/testfiles/command-boundary01.lvt`（#998 新增 48 个宽度 oracle，累计 456）、`xeCJK/testfiles/siunitx-ecglue01.lvt/.tlg`（#1000 五命令 × CJK/Latin/可选参数/数学内嵌矩阵）、`xeCJK/testfiles/boundary-space02.tlg` + `fntef-space02.tlg`（基线刷新）、`ctex/test/testfiles-ctxdoc/resize-function.tlg`（#998 联动）。
- gh-assets 证据：`fcff1eb3`（PR #1001 before/after 三图）、`issues/992/showcase-lib.tex` 与 `command-boundary-*-matrix.tex`（`\MatrixReset` 的 `\bool_if_exist:NT` 守卫）。
- 同方向对照反思：[[../archive/2026-07-20/999-command-boundary-capture-framework.md]]（capture/register 框架初版的三层证据与合并前不更新活表惯例，本次三处收尾均延续该惯例）、[[931-biblatex-pagetracker-let-shadow]]（同为“补丁点/契约命名必须区分两种语义相近但实际不同的操作”这一类根因的另一实例）。
- 决策记录：[[../decisions/992-command-boundary-capture-register.md]]（本次 #996/#998/#1000 均在该决策记录的 A/B 复现结论段落追加）。
