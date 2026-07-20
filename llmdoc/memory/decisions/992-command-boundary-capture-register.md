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

`auto` 使用实际首尾；`default` 固定两端为 Default；`first-default` 只固定首端。前两层 capture register 预分配，更深层按需创建；`\sbox` 暂停观察并保存/恢复基础 marker 与 pending。ulem 使用 `stream-ulem`：framework 仍选择 glue，但通过 ulem 的外层、非装饰 skip 通道排出。注册表拒绝同一命令重复注册。

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
- xeCJKfntef 与原生 ulem 使用 `stream-ulem`，独立 under-symbol 使用同一 capture；fntef saved-last-node、颜色方向隔离和直接 pending 删除。外层 glue callback 只负责把 framework 已决定的 glue 放到装饰区间外。
- `\lstinline` 的分隔符和花括号入口使用 `auto` stream，并在共同 deinit 结束；listings 的 token rescan 逻辑继续独立处理 catcode 语义。
- `\verb` 的 language whatsit 主动 flush 保留，但只负责在 stream 结束前物化节点；biblatex 仍须在 preamble 结束后注册最终 `\let` 目标；l3color/meta/listings/ulem 的薄 wrapper 仍须保持第三方签名或扫描时序。这些适配器不复制边界恢复算法。

## 机制边界

TeX 节点不记录 glue 来源。已注册命令右侧完全同构于词间空格的显式 `\hskip` 与源码空格无法区分。实现不扩大为通用节点猜测；用户需要保留该显式 glue 时，在它前面放 `\kern0pt`，或改变自然宽度 / shrink。

任意 whatsit 与任意 hbox 仍不能自动成为恢复证据。只有注册命令、已知定点 hook 和实际 marker 可参与恢复，避免重现 #803 的过度恢复。

## 未采用的方案

- **继续逐命令 save/replay/drain**：重复实现同一状态迁移，且不能系统覆盖输出类别、嵌套与四种源码空格。
- **按参数或命令名声明 CJK/Default**：引用、链接、盒子和 verbatim 都可能输出西文、CJK 或混合内容。
- **通用向后扫描任意节点**：会把无证据 whatsit/hbox 当成合法边界，也仍不能解决完全同构 glue 的来源歧义。
- **保留 #991 专用 wrapper**：最终矩阵证明 `\@setref` / `\real@setref` 的完整 stream 与通用 `\null`、source-space pending 可以共同覆盖四种源码空格；继续文本替换 `\null\fi` 只会留下第二套状态机。

## 验证与状态

`command-boundary01` 用 93 组场景执行 372 个 direct-input 宽度 oracle（89 组普通矩阵 + 4 组显式 `\verb`），并逐单元断言 capture/active/suspend 状态归零；`command-boundary02` 用 12 个 paragraph/node 测试覆盖节点结构、ulem 外层非装饰 glue、显式 glue 歧义和 `\kern0pt` workaround。`listings-color01` 另执行 20 个 braced/delimited direct-input 比较。既有 xeCJK 100 项、ctex 四引擎 184 项及专项测试共同锁定下游变化。

#992 的活表只代表已合并状态。PR 未合并时，新的矩阵结果只能作为 PR 预览；合并后必须从合并提交复验再更新 issue。

## 相关

- 架构：`llmdoc/architecture/xecjk-architecture.md`「边界恢复状态机」
- 测试：`llmdoc/reference/build-and-test.md`「xeCJK 命令边界矩阵」
- 被替代的前置决策：`llmdoc/memory/decisions/991-setref-null-marker-replay.md`
- 历史决策：`873-880-fixed-point-vs-default-narrowing.md`、`910-verb-drain-vs-drain-verb.md`、`931-biblatex-let-shadow.md`、`972-hyperref-end-annot-trusted-marker.md`
- Issues：#491、#991、#992；PR #999
