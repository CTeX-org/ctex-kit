# 决策：#992 用 capture/register 统一命令边界恢复

## 背景

#491 及 #873/#880/#910/#931/#972 的修复分别为 hbox、math、verbatim、write 和 annotation 设计 save/replay、drain 或状态清空。它们能修精确场景，却没有统一观察命令的实际首尾输出类别；同一命令换成 CJK、混合内容或另一种源码空格组合时仍可能失败。#992 将语义改写为“命令包装与相同可见字符的直接输入边界等价”。

## 决策

PR #999 在基础 marker/glue 恢复链之上增加内部 capture/register 框架：

- capture 入口保存前一可信 marker、源码空格、词间空格、`\CJKecglue`、`\CJKglue`、`CJKspace` 与 `xCJKecglue` 状态，并清空普通恢复状态。
- interchar transition 运行时向所有活跃 capture 报告 `CJK` / `default`，分别记录实际首、尾类别；不从命令名或参数推断输出。
- capture 出口按入口前类别、实际首类别和源码空格重建左边界，再按实际末类别重放 marker 给普通右边界恢复链。
- 无可见输出时完整恢复入口状态。

注册按节点形状而非命令名称分五类：

| 策略 | 用途 |
| --- | --- |
| `box` | 命令结束只留下一个末尾 hbox |
| `wrapped-box` | 命令会直接输出多个节点，需要透明盒收集 |
| `stream` | 可见内容直接写入当前列表 |
| `transparent` | 锚点、write 等无可见输出命令 |
| `post-transparent` | 只能用 after hook 处理的零尺寸尾盒 |

`auto` 使用实际首尾；`default` 固定两端为 Default；`first-default` 只固定首端。前两层 capture register 预分配，更深层按需创建；`\sbox` 暂停观察并保存/恢复基础 marker 与 pending。ulem 使用 `stream-ulem`：framework 仍选择 glue，但通过 ulem 的外层、非装饰 skip 通道排出。原生 ulem 与 xeCJKfntef 线型命令嵌套时只有最外层启动 stream；`\UL@onin` 内层路径没有独立 end，重复 begin 会泄漏 capture 栈。注册表拒绝同一命令重复注册。

Boundary→Default 新增受 `\g_@@_glue_check_pending_bool` 门控的 `\@@_recover_ecglue_source_space:`。它只暂时移除 natural width 等于词间空格、finite 且带 shrink 的末尾 glue，并检查其下方是否有可信 CJK marker，与 Boundary→CJK 的源码空格处理形成对称。

## 实现形态

- `\@@_boundary_emit_left:nnn` 用两份三元素 `\clist_if_in:nnTF` 表达“共享同一动作的语义类别集合”。这里不是逐值分派，改成 `\str_case:nn` 会复制分支或增加中间映射；函数又只在已注册命令的边界重建时执行，不在逐字符主路径，因此固定 O(3) 查找不是性能风险。
- per-layer csname 保持 `g_@@_boundary_capture_<depth>_<field>` 的显式拼写。相同字段要经过 new、clear、set、use、equality 和 box 等不同操作；当前抽 helper 需要建立多组变体并隐藏具体字段。只有未来继续增加每层状态时，才一起评估 record/helper 抽象。
- `\@@_boundary_register_makeboxes:` 包装本包最低支持内核 LaTeX2e 2026-06-01 中的内部 `\@imakebox [#1][#2]#3` 与 `\@iframebox [#1][#2]#3`，明确依赖该参数签名。`command-boundary01` 的 optional `\makebox` / `\framebox` 场景是该依赖的漂移门禁；上游若改签名，补丁与测试必须同步。
- capture 入口先用 `\xeCJK_glue_to_skip:nN` 实际执行用户定义的 glue 并读入 skip 变量，随后 `\tl_gset:ce` 只序列化已求值的数值规格，不会 e-type 展开原始 `\CJKglue` / `\CJKecglue` 定义中的不可展开 token。
- `\@@_recover_ecglue_source_space_success:` 在当前调用图中只会从 pending=true 的入口到达，但仍保留 `\bool_if:NT` 防御守卫。该 helper 独立命名，未来增加调用点时不应在 pending 已失效后误清状态；一次命令边界上的布尔检查不构成可测性能成本。
- `\@@_recover_ecglue_source_space_fallback:` 刻意不转入 `\@@_check_for_ecglue_aux:`。尚未移除候选 glue 时，它仍是末节点；移除后若验证失败，restore 又会把它原样还回。两种情况下，aux 都无法越过这枚 glue 取得下方 marker。未获验证的 glue 本身就是要保留的边界，只有 success 路径可替换为 `\CJKecglue`。
- source-space 检查在 `\unskip` 前把完整 `\lastskip` 数值快照保存到 skip 变量；restore 重放同一份 natural/stretch/shrink，不按当前 spacefactor 重新计算。TeX 不能恢复的是 glue 的源码来源，而不是它的数值规格。

## 旧补丁的吸收与保留适配器

- #991 的 `\@setref` / `\real@setref` 改为 `auto` stream；一般 `\null` 的 post-transparent 负责零盒。完整矩阵证明 command after hook 与 source-space pending 已能覆盖内核 `\fi` 后的用户空格，因此旧 wrapper、saved-node 与 replay 删除。
- hyperref annotation 使用 `auto` stream；末尾 math 在结束前报告 Default。入口 save/replay 与 `hyperref-default` marker 删除。
- 完整 `\Url@z` 使用 `default` stream；URL drain 删除。codedoc/doc meta 的参数 hbox 只保留内部排版语义，外侧使用 `default` stream；meta drain 删除。
- color/xcolor push/pop 与 l3color 后端使用 transparent，`\color@b@x` 使用 wrapped-box；颜色 saved marker、专用 pending 与 hlist/whatsit 回退删除。
- xeCJKfntef 与原生 ulem 使用 `stream-ulem`，其 group 入口和 `\ULon` 共用“仅最外层启动”协议；独立 under-symbol 使用同一 capture。fntef saved-last-node、颜色方向隔离和直接 pending 删除。外层 glue callback 只负责把 framework 已决定的 glue 放到装饰区间外。
- `\lstinline` 的分隔符和花括号入口使用 `auto` stream，并在共同 deinit 结束；listings 的 token rescan 逻辑继续独立处理 catcode 语义。
- `\verb` 的 language whatsit 主动 flush 保留，但只负责在 stream 结束前物化节点；biblatex 仍须在 preamble 结束后注册最终 `\let` 目标；l3color/meta/listings/ulem 的薄 wrapper 仍须保持第三方签名或扫描时序。这些适配器不复制边界恢复算法。

## 机制边界

TeX 节点不记录 glue 来源。已注册命令右侧完全同构于词间空格的显式 `\hskip` 与源码空格无法区分。实现不扩大为通用节点猜测；用户需要保留该显式 glue 时，在它前面放 `\kern0pt`，或改变自然宽度 / shrink。

任意 whatsit 与任意 hbox 仍不能自动成为恢复证据。只有注册命令、已知定点 hook 和实际 marker 可参与恢复，避免重现 #803 的过度恢复。

**Boundary→CJK 方向对称校验已补齐（#996，PR #1001，commit 085f4f86）**：`\@@_check_for_glue_skip:`（Boundary→CJK）候选校验升级为与 Boundary→Default 同款的 `\@@_skip_if_interword:N` 谓词（finite、带 shrink、自然宽度等于词间空格），不再无条件接受任意 finite+shrink glue。同时新增 `\@@_glue_check_expire_stale:`：顶层恢复链（`\g_@@_boundary_capture_depth_int` 为 0，即无活跃 capture）在探测到 `\tex_lastnodetype:D` 为负（空列表）时结束过期 pending，因为空列表上不可能存在紧邻可信 marker 的证据；capture 活跃时不做该判断，以保护 ulem 等 stream 在内部字盒中合法携带的 pending。两处联合修复了 `\g_@@_glue_check_pending_bool` 跨 `\hbox`/`\setbox` 分组存活、导致下一个盒子里第一个显式非同构 `\hskip` 被误判为源码词间空格并换成 `CJKglue` 的预存缺陷。回归 `xeCJK/testfiles/boundary-crossbox01.lvt`（issue MWE、kern workaround、同盒内/跨盒两种歧义窗口、双向 source-space 完整性，共 7 个 `\TEST`）。旧基线 `boundary-space02.tlg`/`fntef-space02.tlg` 的 20pt/40pt 实为该泄漏 bug 的错误输出（测试名字面语义要求“显式 `\ ` 原样保留”），修复后刷新为 23.33pt/43.33pt，才真正符合测试名断言（见 `xeCJK/testfiles/boundary-space02.tlg`、`xeCJK/testfiles/fntef-space02.tlg`）。词间空格完全同构的显式 glue 仍是双向共同的机制边界，workaround 不变（`\kern0pt`），见下文与「右侧源码空格的机制边界」一节。

**math 与 rule 对 capture 已按 Default 重建（#998，PR #1001，commits 14336c4d/19fedf48）**：math 模式内容与 `\vrule` 仍不触发 XeTeX interchar class 转换，capture 依然观察不到首、尾类别本身；但 box/wrapped-box 结束路径新增 `\@@_boundary_if_capture_box_visible:`——在“无观察类别”前提下联合判定盒是否携带现场墨迹：宽度非零、且高度或深度非零，同时用 `\hbox_unpack:` 把该盒复制到临时盒读 `\tex_lastnodetype:D` 探测尾节点类型，命中 char(0)/rule(3)/math(10)/kern(12) 才视为“本层现场排版留下的痕迹”。命中时按 Default 首尾重建边界（`\mbox{$x$}`、`\mbox{\vrule...}` 现表现为与直接输入西文等价）；未命中（尾节点是 hlist(1)/glue(11)，或盒零尺寸/单一维度为零）保持完整透明恢复——这一保护集专为 `\null`/空 `\mbox`、ctex 内核 `\[` display leader 的空白 `\makebox` 占位盒、thuthesis `\thu@pad` 一类把预排盒/填充 glue 塞进末尾的命令而设，capture 无法判断它们内部的真实类别。推断出的 default 经 `\@@_boundary_capture_report_first:n` 只补尚未取得的 `first_tl`；不得直接覆写所有外层 `last_tl`，否则内部构造盒会使 `\fcolorbox` 等已观察到的 CJK 末类别降级。内层盒重放的可信 marker 留在父盒列表，由父层结束路径 `\@@_boundary_box_set_last_from_node:` 校正本层末类别，使 `\mbox{中\mbox{$x$}}` 与对应 rule 形状的推断结果按实际列表逐层传播，也保持 `\nfss@text`（`\ref` 内部 `\mbox`）嵌套在 stream 内时与裸调用等价。`\mbox{\vrule...}` 的契约 oracle 是 Default 字母（引擎对直接输入的裸 `\vrule` 本身不触发 interchar，这一条引擎机制边界不因本次修复改变）；`\fbox{$x$}`/`\colorbox{yellow}{$x$}` 的尾节点是 frame/wrapper hlist，仍保持透明恢复，留作 #992 已知项（透明保持集会因命令的包装节点形状而扩大）。回归 `command-boundary01` 先新增 12 组 math/数字/rule/空盒场景从 408 升到 456，后补 4 组嵌套 math/rule 场景升到 472。

## 未采用的方案

- **继续逐命令 save/replay/drain**：重复实现同一状态迁移，且不能系统覆盖输出类别、嵌套与四种源码空格。
- **按参数或命令名声明 CJK/Default**：引用、链接、盒子和 verbatim 都可能输出西文、CJK 或混合内容。
- **通用向后扫描任意节点**：会把无证据 whatsit/hbox 当成合法边界，也仍不能解决完全同构 glue 的来源歧义。
- **保留 #991 专用 wrapper**：最终矩阵证明 `\@setref` / `\real@setref` 的完整 stream 与通用 `\null`、source-space pending 可以共同覆盖四种源码空格；继续文本替换 `\null\fi` 只会留下第二套状态机。

## 验证与状态

`command-boundary01` 用 118 组场景执行 472 个 direct-input 宽度 oracle（114 组普通矩阵 + 4 组显式 `\verb`），并逐单元断言 capture/active/suspend 状态归零；含五组原生 ulem 与 fntef 线型/符号命令双向嵌套（锁定“仅最外层拥有 stream”的不变量）、跨策略嵌套、PR #1001 新增 12 组 math/数字/rule/空盒场景，以及 4 组已观察前缀后接推断 math/rule 的嵌套场景（见上文 #998）。`command-boundary02` 用 12 个 paragraph/node 测试覆盖节点结构、ulem 外层非装饰 glue、显式 glue 歧义和 `\kern0pt` workaround。`listings-color01` 另执行 20 个 braced/delimited direct-input 比较。既有 xeCJK 回归（含 `colorbox-measure01`、PR #1001 新增 `boundary-crossbox01`/`siunitx-ecglue01`）、ctex 四引擎 184 项及专项测试共同锁定下游变化。

#992 的活表只代表已合并状态。PR 未合并时，新的矩阵结果只能作为 PR 预览；合并后必须从合并提交复验再更新 issue。本文档当前口径基于 PR #1001 分支及本地 review 修复 19fedf48；最新代码已通过 xeCJK 103 项、ctex ctxdoc 专项与 3 项 contrib 本地回归，尚未 merge。

用户报告 #995/#996/#998 的 A/B 复现（v3.10.3 发行版 vs PR #999 开发分支）已完成根因定位；#1000 是后续独立报告的 siunitx 边界丢失问题：

- **#995 已由 #999 框架顺带修复**。旧 `\set@color`/`\reset@color` 补丁曾在 `\settowidth` 等离线测量场景写 `\g_@@_last_node_tl` 并让旧 whatsit 猜测分支信任陈旧全局 tl，导致 `\settowidth{...}{甲\colorbox{yellow}{乙}}` 污染全局边界状态，使随后相同源码的 `\hbox{丙\special{audit} 丁}` 从 23.33pt 变为 20.0pt。capture/register 框架删除这两个机制（`\set@color`/`\reset@color` 改注册为 `transparent`）后 DELTA=0。回归测试 `xeCJK/testfiles/colorbox-measure01.lvt`：两组 direct-input oracle（含 `\special` whatsit 的盒子、纯文本盒子）在 `\settowidth`+`\colorbox` 测量前后逐次宽度比较（`\wd` 相等）。
- **#996 已由 PR #1001（commit 085f4f86）修复**：见上文“机制边界”一节 Boundary→CJK 方向对称校验。
- **#998 已由 PR #1001（commit 14336c4d）修复**：见上文“机制边界”一节 math/rule 按 Default 重建。
- **#1000 已由 PR #1001（commit c8c803bf）修复**：siunitx 的 `\unit`/`\qty`/`\num` 在 math 模式排版数字与单位，入口的 `\mathon` 遮蔽左侧 CJK marker，机制与修复前的 `\eqref` 相同；按同款策略注册为固定 Default 首尾的 `stream` capture（`\@@_boundary_register_siunitx:`）。v2 旧名 `\si`/`\SI` 是独立顶层命令，经 `\cs_if_exist:cT` 存在性守卫单独注册；`\ang` 输出含度符号，oracle 语义未定，暂不注册。回归 `xeCJK/testfiles/siunitx-ecglue01.lvt`：9 组 `\BoundaryMatrix`（5 命令 + `unit` 可选参数变体）× 4 种源码空格组合 = 36 个宽度比较，加 1 组 math 内嵌 capture 栈归零断言。

四个问题均已发布确认评论；#996/#998/#1000 的 before/after 视觉对比落在 gh-assets 固定提交 `fcff1eb3`，#995 的 MWE/截图落在 `gh-assets:issues/995/`。#996、#998、#1000 在 #992 issue 活表上的行按既有惯例——PR #1001 未合并前只作预览，合并后须从合并提交复验再更新为已修复状态。PR #999 body 已加 `Closes #995`。

## 相关

- 架构：`llmdoc/architecture/xecjk-architecture.md`「边界恢复状态机」
- 测试：`llmdoc/reference/build-and-test.md`「xeCJK 命令边界矩阵」
- 被替代的前置决策：`llmdoc/memory/decisions/991-setref-null-marker-replay.md`
- 历史决策：`873-880-fixed-point-vs-default-narrowing.md`、`910-verb-drain-vs-drain-verb.md`、`931-biblatex-let-shadow.md`、`972-hyperref-end-annot-trusted-marker.md`
- Issues：#491、#991、#992、#995、#996、#998、#1000；PR #999、PR #1001
