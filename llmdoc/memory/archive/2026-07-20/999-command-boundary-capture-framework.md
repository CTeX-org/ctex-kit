# 反思：#999 从命令矩阵收敛到 capture/register

## 先证明问题族有限

#491 的逐命令案例让失败看起来像不断增长的 edge case。#992 先把 26 行状态表展开为实际输出类别、相邻类别和 `00/10/01/11`，再用节点探针把失败归入盒子遮蔽、流式节点、透明节点和“暂时移除源码空格 glue 后检查下方 marker”等有限形状。只有先建立完整矩阵，才能判断公共原语是否真的覆盖问题族，而不是把某个 MWE 修绿。

这也改变了实现粒度：命令名称只决定挂哪个 hook，恢复算法由节点形状和运行时首尾类别决定。新增 case 通常应注册为 box、wrapped-box、stream、transparent 或 post-transparent，而不是再复制 save/replay/drain。

## 输出类别必须运行时观察

引用、链接、verb、盒子和文档命令都可能输出西文、CJK 或混合内容。参数文本也不一定等于外侧可见内容：`\eqref` 有括号，`\meta` 有数学尖括号，`\cs` 有固定的反斜线首端。按命令名或参数整体贴类别会在另一端失败。

capture 让 interchar transition 把实际 `CJK` / `default` 写入所有活跃层；首端和末端分别记录，混合内容无需额外分支。固定包装只声明 `default` 或 `first-default`，不伪造其余端点。

## 嵌套和测量必须成为一等状态

单个 scratch register 会被内层盒命令覆盖。最终实现为每层保存 box、入口 marker、首尾类别、三类 glue 和选项状态；前两层预分配，深层惰性创建，并用 active stack 配对 hook。12 层嵌套用例证明深度不是静态上限。

`\sbox` 的内容是离线测量，不是外层命令的可见输出。如果不暂停 capture，scratch 中的 CJK 会错误改写外层首尾类别。suspend depth 必须支持嵌套，测试也必须在每个矩阵单元后断言 depth、stack 和 suspension 全部归零。

## 三层证据各管一件事

- 宽度 oracle 回答“候选与直接输入的外围几何是否相同”；`command-boundary01` 最终用 408 个比较覆盖主体矩阵，包含原生 `\uline`、ulem/fntef 双向嵌套及 transparent/box/wrapped-box 跨策略嵌套；`listings-color01` 另用 20 个比较覆盖 `\lstinline` 的两类扫描入口。
- 节点 oracle 回答“等宽结果是否由正确 glue/kern/box 结构产生”；`command-boundary02` 锁定 12 个段落与节点场景，其中 ulem 用例证明弹性 CJKglue 位于装饰 leader 之外。
- gh-assets MWE 与截图回答“维护者能否肉眼理解和复核”；默认 glue 与可区分 glue 都要展示。

默认词间空格可能与 `CJKecglue` 等宽，默认 `CJKglue` 又可能为零。只用其中任一层都会留下假通过：宽度看不出等宽节点替换，节点日志不适合 issue 讨论，截图也难以量化微小差异。

## 测试说明层不能经过被测状态机

`\texttt{\detokenize{...}}` 仍会经过 xeCJK，无法忠实展示源码空格；把 `\verb*` 塞进普通宏参数又会破坏分隔符扫描。稳定展示要让 starred verbatim scanner 从调用点直接读取 literal，再在分隔符结束后进入测量阶段。`00/10/01/11` 还要显式编号，使讨论不依赖肉眼数空格。

同样，lazy font family 的首次创建必须发生在 `\START` 前。`command-boundary02` 若在记录区第一次切换 FandolFang，不同平台的 fontspec Info 会形成与实现无关的基线噪声；预热不是排版修复，而是测试隔离。

## 无法判源时应公开边界

TeX glue 节点不携带“源码空格”或“显式 `\hskip`”来源。两者参数完全相同时，任何节点级算法都不可能可靠区分。只在 pending 已设置且下方有可信 marker 时暂时移除候选 glue，已经是可证明的最大安全范围；继续向前检查更多节点只会扩大误伤。

这类限制应同时提供机制证据、回归和 workaround。`\kern0pt` 放在同构显式 glue 前，可阻止检查过程越过该 kern 到达 marker；使用不同自然宽度或无 shrink glue 也可避开。明确承认不可区分，比把罕见输入静默解释成源码空格更可维护。

## 原型结果与已合并状态要分层

PR #999 的固定提交和 gh-assets 固定提交可以先产生拟更新表，便于 review；但 issue #992 的活表代表用户当前从主线能得到的行为。PR 未合并时更新活表会把原型误报成已发布事实，也会在后续 rebase 或 review 修订时失去可追溯基线。

因此预览表只发在 PR，并明确固定实现/资产提交与“合并前不更新 #992”。合并后从合并提交重跑矩阵，再原地更新 issue 活表。正确的技术结果也必须配合正确的状态传播时机。

## 替换框架必须审计所有真实入口

只把包内 `\CJKunderline` 接入 stream 仍不足以替代旧 ulem 边界逻辑：原生 `\uline` 与声明式 `\xeCJKfntefon` 经过 `\ULon`，不会经过包内命令的分组入口。把 begin 直接下移到 `\UL@hook` 又太晚，此时已经进入内部字盒，会导致分组失配。最终保留包内命令的早期入口，并在 `\ULon` 用局部布尔补齐未启动的原生路径；两处必须共用“仅最外层启动”协议，因为原生 ulem 外嵌 fntef 时内层走 `\UL@onin`，不会产生第二个公共 end。若内层仍重复 begin，每次调用都会永久遗留一层 capture。五组双向嵌套矩阵及逐格 idle-stack 断言锁定该不变量。

这条审计同样发现 `\lstinline{...}` 绕过分隔符路径的 `\lstinline@`，直接进入 `\lst@InlineG`。因此“旧 helper 已删除”不是替换完成的充分条件；还要从每个公共入口追到真实扫描分支，并用每条入口的矩阵与 idle-stack 断言证明共享状态机确实覆盖。

## 结果

统一框架覆盖 box、wrapped-box、stream、transparent、post-transparent 与 ulem 的外层 glue 通道，处理实际首尾类别、混合输出、嵌套、`\sbox` 隔离、源码空格、`CJKspace` / `xCJKecglue`、引用、URL、hyperref、verb、codedoc/doc、color/l3color、fntef/ulem、listings、hypdoc、biblatex 和一般 `\null`。#991 及 #873/#880/#910/#931/#972、#826/#830/#831 的逐命令边界算法全部删除；保留的第三方薄适配器只处理签名、扫描时序或内部排版语义，历史定点补丁成为演进证据而不是未来模板。
