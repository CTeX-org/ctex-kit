# 决策：#992 用 capture/register 统一命令边界恢复

## 背景

#491 及 #873/#880/#910/#931/#972 的修复分别为 hbox、math、verbatim、write 和 annotation 设计 save/replay、drain 或状态清空。它们能修精确场景，却没有统一观察命令的实际首尾输出类别；同一命令换成 CJK、混合内容或另一种源码空格组合时仍可能失败。#992 将语义改写为“命令包装与相同可见字符的直接输入边界等价”。

## 决策

PR #999 在基础 marker/glue 恢复链之上增加内部 capture/register 框架：

- capture 入口保存前一个由 xeCJK 写入的 marker、源码空格、词间空格、`\CJKecglue`、`\CJKglue`、`CJKspace` 与 `xCJKecglue` 状态，并清空普通恢复状态。
- interchar transition 运行时向所有活跃 capture 报告 `CJK` / `default`，分别记录实际首、尾类别；不从命令名或参数推断输出。
- capture 出口按入口前类别、实际首类别和源码空格重建左边界，再按实际末类别重放 marker 给普通右边界恢复链。
- 无可见输出时完整恢复入口状态。

注册按节点形状而非命令名称分五类：

| 策略 | 用途 |
| --- | --- |
| `box` | 命令结束只留下一个末尾 hbox |
| `wrapped-box` | 命令会直接输出多个节点，需要用透明盒子收集 |
| `stream` | 可见内容直接写入当前列表 |
| `transparent` | 锚点、write 等无可见输出命令 |
| `post-transparent` | 只能用 after hook 处理的末尾盒子，且该盒子的宽、高、深均为零 |

`auto` 使用实际首尾；`default` 固定两端为 Default；`first-default` 只固定首端。前两层 capture register 预分配，更深层按需创建；`\sbox` 暂停观察并保存/恢复基础 marker 与 pending。ulem 使用 `stream-ulem`：framework 仍选择 glue，但通过 ulem 的外层、非装饰 skip 通道排出。原生 ulem 与 xeCJKfntef 线型命令嵌套时只有最外层启动 stream；`\UL@onin` 内层路径没有独立 end，重复 begin 会泄漏 capture 栈。注册表拒绝同一命令重复注册。

Boundary→Default 新增 `\@@_recover_ecglue_source_space:`。只有 `\g_@@_glue_check_pending_bool` 为 true 时才会调用它。它暂时移除自然宽度等于词间空格、finite 且带 shrink 的末尾 glue，并检查前一个节点是否是 xeCJK 写入的 CJK marker，使 Boundary→Default 与 Boundary→CJK 使用相同的源码空格处理方式。

## 实现方式

- `\@@_boundary_emit_left:nnn` 用两份三元素 `\clist_if_in:nnTF` 表达“共享同一动作的语义类别集合”。这里不是逐值分派，改成 `\str_case:nn` 会复制分支或增加中间映射；函数又只在已注册命令的边界重建时执行，不在逐字符主路径，因此固定 O(3) 查找不是性能风险。
- per-layer csname 保持 `g_@@_boundary_capture_<depth>_<field>` 的显式拼写。相同字段要经过 new、clear、set、use、equality 和 box 等不同操作；当前抽 helper 需要建立多组变体并隐藏具体字段。只有未来继续增加每层状态时，才一起评估 record/helper 抽象。
- `\@@_boundary_register_makeboxes:` 包装本包最低支持内核 LaTeX2e 2026-06-01 中的内部 `\@imakebox [#1][#2]#3` 与 `\@iframebox [#1][#2]#3`，明确依赖该参数签名。`command-boundary01` 的 optional `\makebox` / `\framebox` 场景是该依赖的漂移门禁；上游若改签名，补丁与测试必须同步。
- capture 入口先用 `\xeCJK_glue_to_skip:nN` 实际执行用户定义的 glue 并读入 skip 变量，随后 `\tl_gset:ce` 只序列化已求值的数值规格，不会 e-type 展开原始 `\CJKglue` / `\CJKecglue` 定义中的不可展开 token。
- `\@@_recover_ecglue_source_space_success:` 在当前调用关系中只会从 pending=true 的入口到达，但仍保留 `\bool_if:NT` 检查。这样以后增加调用点时，也不会在 pending 已失效后误清状态。命令边界上多做一次布尔检查没有可测的性能影响。
- `\@@_recover_ecglue_source_space_fallback:` 刻意不转入 `\@@_check_for_ecglue_aux:`。尚未移除候选 glue 时，它仍是末节点；移除后若验证失败，restore 又会把它原样还回。两种情况下，aux 都无法越过这枚 glue 取得下方 marker。未获验证的 glue 本身就是要保留的边界，只有 success 路径可替换为 `\CJKecglue`。
- source-space 检查在 `\unskip` 前把完整 `\lastskip` 数值快照保存到 skip 变量；restore 重放同一份 natural/stretch/shrink，不按当前 spacefactor 重新计算。TeX 不能恢复的是 glue 的源码来源，而不是它的数值规格。

## 旧补丁的吸收与保留适配器

- #991 的 `\@setref` / `\real@setref` 改为 `auto` stream；一般 `\null` 由 post-transparent 处理。完整矩阵证明 command after hook 与 source-space pending 已能覆盖内核 `\fi` 后的用户空格，因此旧 wrapper、saved-node 与 replay 删除。
- hyperref annotation 使用 `auto` stream；末尾 math 在结束前报告 Default。入口 save/replay 与 `hyperref-default` marker 删除。
- 完整 `\Url@z` 使用 `default` stream；URL drain 删除。codedoc/doc meta 的参数 hbox 只保留内部排版语义，外侧使用 `default` stream；meta drain 删除。
- color/xcolor push/pop 与 l3color 后端使用 transparent，`\color@b@x` 使用 wrapped-box；颜色 saved marker、专用 pending 与 hlist/whatsit 回退删除。
- xeCJKfntef 与原生 ulem 使用 `stream-ulem`，其 group 入口和 `\ULon` 共用“仅最外层启动”协议；独立 under-symbol 使用同一 capture。fntef saved-last-node、颜色方向隔离和直接 pending 删除。外层 glue callback 只负责把 framework 已决定的 glue 放到装饰区间外。
- `\lstinline` 的分隔符和花括号入口使用 `auto` stream，并在共同 deinit 结束；listings 的 token rescan 逻辑继续独立处理 catcode 语义。
- `\verb` 的 language whatsit 主动 flush 保留，但只负责在 stream 结束前物化节点；biblatex 仍须在 preamble 结束后注册最终 `\let` 目标；l3color/meta/listings/ulem 的薄 wrapper 仍须保持第三方签名或扫描时序。这些适配器不复制边界恢复算法。

## 机制边界

TeX 节点不记录 glue 的来源。已注册命令右侧如果有一枚显式 `\hskip`，而它的自然宽度和 shrink 与词间空格完全相同，恢复逻辑就无法把它和源码空格区分开。继续检查更多节点也无法找回已经丢失的来源信息。需要保留这枚显式 glue 时，可在前面加 `\kern0pt`，也可以改变自然宽度或去掉 shrink。

任意 whatsit 与任意 hbox 仍不能自动成为恢复证据。只有注册命令、已知定点 hook 和实际 marker 可参与恢复，避免重现 #803 的过度恢复。

**Boundary→CJK 方向已补上相同的检查（#996，PR #1001，commit 085f4f86）**：`\@@_check_for_glue_skip:` 在 Boundary→CJK 方向也调用 `\@@_skip_if_interword:N`。只有待检查的 glue 为 finite、带 shrink，而且自然宽度等于词间空格时，才可能把它当作源码空格；其他显式 glue 不再被替换为 `CJKglue`。新增的 `\@@_glue_check_expire_stale:` 会在最外层恢复逻辑发现节点列表为空时清除过期 pending，因为空列表中不可能有相邻的 xeCJK marker；capture 活跃时不清除，以便 ulem 等 stream 把 pending 从内部盒子带到命令外的实际边界。这两处修改修复了 `\g_@@_glue_check_pending_bool` 越过 `\hbox` 或 `\setbox` 分组、误把下一个盒子中的显式 `\hskip` 当作源码词间空格的问题。回归测试 `boundary-crossbox01.lvt` 覆盖 issue MWE、`\kern0pt` 处理方法、同一盒子与不同盒子中的显式 glue，以及两个方向的源码空格处理。旧基线 `boundary-space02.tlg` 和 `fntef-space02.tlg` 的 20pt、40pt 是 pending 泄漏造成的错误输出；修复后的 23.33pt、43.33pt 才符合“显式 `\ ` 原样保留”的测试说明。如果显式 glue 与词间空格在节点列表中没有区别，TeX 仍无法判断来源；处理方法见下文「右侧源码空格的机制边界」。

**math 与 rule 内容现在按 Default 重建边界（#998，PR #1001，commits 14336c4d/19fedf48）**：math 模式内容与 `\vrule` 不触发 XeTeX interchar class 转换，所以 capture 看不到它们的首尾类别。box/wrapped-box 结束时，`\@@_boundary_if_capture_box_visible:` 会在没有观察到类别的情况下检查盒子尺寸和末节点类型。盒子必须宽度非零、高度或深度非零，并且末节点是 char(0)、rule(3)、math(10) 或 kern(12)，才认为它直接排出了可见内容。此时按 Default 重建首尾边界，使 `\mbox{$x$}`、`\mbox{\vrule...}` 的外围间距与直接输入西文相同。宽、高、深均为零的盒子、只用于留白的盒子，以及末尾为 hlist(1) 或 glue(11) 的命令仍恢复进入命令前的状态；这覆盖 `\null`、空 `\mbox`、ctex 内核 `\[` 使用的空白 `\makebox`，以及 thuthesis 的 `\thu@pad` 等把已经排好的盒子放到末尾的命令，因为 capture 无法据此判断里面的字符类别。

推断出的 default 通过 `\@@_boundary_capture_report_first:n` 只补上外层尚未取得的 `first_tl`，不能直接覆盖所有外层 `last_tl`，否则 `\fcolorbox` 命令内部的辅助盒子会覆盖已经观察到的 CJK 末类别。嵌套盒子结束时写入的 marker 会留在外层盒子的节点列表末尾；外层结束时，`\@@_boundary_box_set_last_from_node:` 读取这个 marker，只更新本层末类别。这样，`\mbox{中\mbox{$x$}}` 以及对应的 rule 情况可以逐层得到正确的 Default 末类别，`\nfss@text` 嵌套在 stream 内时也与单独调用相同。`\mbox{\vrule...}` 的比较对象是 Default 字母；直接输入裸 `\vrule` 本身不触发 interchar 转换，这项 XeTeX 限制没有改变。`\fbox{$x$}` 和 `\colorbox{yellow}{$x$}` 的末节点是 frame/wrapper hlist，目前仍恢复命令前的状态，记在 #992 的未处理项目中。`command-boundary01` 先新增 12 组 math、数字、rule 和空盒子场景，从 408 个比较增加到 456 个；本地审查后再补 4 组嵌套 math/rule 场景，合计 472 个。

## 未采用的方案

- **继续逐命令 save/replay/drain**：重复实现同一状态迁移，且不能系统覆盖输出类别、嵌套与四种源码空格。
- **按参数或命令名声明 CJK/Default**：引用、链接、盒子命令和 verbatim 都可能输出西文、CJK 或混合内容。
- **通用向后扫描任意节点**：会把无证据 whatsit/hbox 当成合法边界，也仍不能解决完全同构 glue 的来源歧义。
- **保留 #991 专用 wrapper**：最终矩阵证明 `\@setref` / `\real@setref` 的完整 stream 与通用 `\null`、source-space pending 可以共同覆盖四种源码空格；继续文本替换 `\null\fi` 只会留下第二套状态机。

## 验证与状态

`command-boundary01` 用 118 组场景执行 472 个 direct-input 宽度比较（114 组普通矩阵，加 4 组显式 `\verb`），并在每个单元后确认 capture/active/suspend 状态归零。覆盖范围包括五组原生 ulem 与 fntef 线型、符号命令双向嵌套，跨注册策略嵌套，PR #1001 新增的 12 组 math、数字、rule 和空盒子场景，以及 4 组“已观察 CJK 前缀后接推断 math/rule 后缀”的嵌套场景。`command-boundary02` 用 12 个 paragraph/node 测试覆盖节点结构、ulem 外层不带装饰的 glue、TeX 无法区分来源的显式 glue，以及 `\kern0pt` 处理方法。`listings-color01` 另执行 20 个 braced/delimited direct-input 比较。既有 xeCJK 回归测试、ctex 四引擎 184 项测试和专项测试共同检查下游变化。

#992 的活表只代表已合并状态。PR 未合并时，新的矩阵结果只能作为 PR 预览；合并后必须从合并提交复验再更新 issue。本文档当前口径基于 PR #1001 分支及本地 review 修复 19fedf48；最新代码已通过 xeCJK 103 项、ctex ctxdoc 专项与 3 项 contrib 本地回归，尚未 merge。

用户报告 #995/#996/#998 的 A/B 复现（v3.10.3 发行版 vs PR #999 开发分支）已完成根因定位；#1000 是后续独立报告的 siunitx 边界丢失问题：

- **#995 已由 #999 框架顺带修复**。旧 `\set@color`/`\reset@color` 补丁曾在 `\settowidth` 等离线测量场景写 `\g_@@_last_node_tl` 并让旧 whatsit 猜测分支信任陈旧全局 tl，导致 `\settowidth{...}{甲\colorbox{yellow}{乙}}` 污染全局边界状态，使随后相同源码的 `\hbox{丙\special{audit} 丁}` 从 23.33pt 变为 20.0pt。capture/register 框架删除这两个机制（`\set@color`/`\reset@color` 改注册为 `transparent`）后 DELTA=0。回归测试 `xeCJK/testfiles/colorbox-measure01.lvt`：两组 direct-input oracle（含 `\special` whatsit 的盒子、纯文本盒子）在 `\settowidth`+`\colorbox` 测量前后逐次宽度比较（`\wd` 相等）。
- **#996 已由 PR #1001（commit 085f4f86）修复**：见上文“机制边界”一节 Boundary→CJK 方向对称校验。
- **#998 已由 PR #1001（commit 14336c4d）修复**：见上文“机制边界”一节 math/rule 按 Default 重建。
- **#1000 已由 PR #1001（commit c8c803bf）修复**：siunitx 的 `\unit`、`\qty` 和 `\num` 在 math 模式排版数字与单位，入口的 `\mathon` 会遮住左侧 CJK marker，情况与修复前的 `\eqref` 相同，因此注册为固定 Default 首尾的 `stream` capture（`\@@_boundary_register_siunitx:`）。v2 旧名 `\si`、`\SI` 是独立的顶层命令；注册前分别用 `\cs_if_exist:cT` 检查命令是否存在。`\ang` 会输出角度符号，目前还没有确定应与哪种直接输入比较，因此暂不注册。回归测试 `siunitx-ecglue01.lvt` 包含 9 组 `\BoundaryMatrix`，每组执行 4 种源码空格组合，共 36 个宽度比较，另检查 math 内嵌使用后的 capture 栈是否归零。

四个问题均已发布确认评论；#996/#998/#1000 的 before/after 视觉对比落在 gh-assets 固定提交 `fcff1eb3`，#995 的 MWE/截图落在 `gh-assets:issues/995/`。#996、#998、#1000 在 #992 issue 活表上的行按既有惯例——PR #1001 未合并前只作预览，合并后须从合并提交复验再更新为已修复状态。PR #999 body 已加 `Closes #995`。

## 相关

- 架构：`llmdoc/architecture/xecjk-architecture.md`「边界恢复状态机」
- 测试：`llmdoc/reference/build-and-test.md`「xeCJK 命令边界矩阵」
- 被替代的前置决策：`llmdoc/memory/decisions/991-setref-null-marker-replay.md`
- 历史决策：`873-880-fixed-point-vs-default-narrowing.md`、`910-verb-drain-vs-drain-verb.md`、`931-biblatex-let-shadow.md`、`972-hyperref-end-annot-trusted-marker.md`
- Issues：#491、#991、#992、#995、#996、#998、#1000；PR #999、PR #1001
