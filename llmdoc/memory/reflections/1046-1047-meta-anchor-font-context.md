---
name: 1046-1047-meta-anchor-font-context
description: 记录 #1046（l3doc \meta 左右 CJKecglue 不对称）与 #1047（hyperref 锚点前的异常间距）中「注册点的字体上下文」「同一命令多条实现路径」两条机制事实，以及把既有测试全绿当成缺陷不存在证据、低位 box 寄存器被被测命令占用、本地 TeX Live 中途漂移等验证教训
metadata:
  type: feedback
---

# 反思：#1046 / #1047 命令边界注册点的字体上下文与锚点的两条路径

## 任务

修 Issue #1046（l3doc + xeCJK 下 `\meta` 左右间距不对称）与 #1047（ctxdoc 手册里五角星前
的异常间距），两者都是 #1045「手册排版异常」的子问题。分析后确认它们同属一类：#992
capture/register 框架的**注册点**问题——不是策略选错，而是注册挂在了错误的层级（#1046）
或漏了一条实现路径（#1047）。

## 两个缺陷的机制

### #1046：capture 入口的字体决定了缓存的 glue 度量

`\@@_boundary_capture_begin:`（`xeCJK/xeCJK.dtx:5293` 附近）在 capture **入口**处把
`\CJKecglue` 排入临时盒并读成 skip 数值（`xeCJK.dtx:5322`），缓存的度量因此取决于
capture 开始时生效的字体。

l3doc 的 `\meta` 是 `\texttt{ \__codedoc_meta:n {#1} }`（`l3doc.cls:542-543`）。旧实现把
stream capture 包在**内层** `\__codedoc_meta:n`，capture 于是落在 `\texttt` 已切到等宽字体
之后：左边界重放等宽字体的 `\CJKecglue`（lm 下 5.25pt，**不可伸缩**），右边界在 capture
结束、字体恢复后求值，得到正文字体的 3.33pt plus 1.665 minus 1.11。两侧同源不同值。

修法：capture 上移到公开 `\meta`，用 `\@@_boundary_register_stream:nn { meta } { default }`
（与 `\eqref` 同一模式）；内层只保留 `\hbox:n` 参数包装（#920 的目标）。`meta` 相应从专用
适配器保留表移出、改由通用注册表接管：保留表的语义是「必须直接重定义内部排版入口、不能用
LaTeX 通用命令 hook 的命令」（`xeCJK.dtx:6172` 附近的注释），而 `\meta` 现在走的正是通用
hook（`cmd/meta/before|after`），留在保留表里会与该表的定义矛盾；#1010 的用户接口冲突检查
查的是两表并集，所以只落在通用表里也不会让用户注册绕过。
`\Arg`／`\marg`／`\oarg`／`\parg` 不需要这层 capture（它们在内层两侧各排出等宽的
`{`、`[`、`(` 实字符，本身就构成正常的 CJK→Default 边界，去掉内层 capture 前后节点列表
完全相同），但仍留在保留表里，防止用户接口把通用 hook 叠到共享的内部实现上。

### #1047：锚点有两条互不相交的实现路径

`\hypertarget` 在源码里是一个命令，实际排版走两条路，各需一次 `transparent` 注册：

1. `\Hy@raisedlink`（`hyperref.sty:2104`）：排出 `\penalty\@M` 加 `\smash` 后的
   `hbox(0+0)x0`，用来盛放 `pdf:dest` special。非空目标的 `\hypertarget`、目录锚点、
   `threeparttable` 的脚注锚点都走这条。
2. 驱动层 `\hyper@anchor`（`hxetex.def:291`）：**空目标**的 `\hypertarget` 经
   `\hyper@@anchor`（`hyperref.sty:5134`）落到这里，直接排出**裸的** `pdf:dest` whatsit，
   不经过 `\Hy@raisedlink`。

两处的不可见节点都隔在 xeCJK 的 marker 与后续字符之间，使 Boundary→{Default,CJK} 的
marker 探测失败，锚点右侧的 `\CJKecglue` 丢失。

## 机制教训（可提升为稳定规则）

### 注册点的字体上下文是语义的一部分（新规则）

框架文档到目前为止只回答两个问题：注册哪个命令、选哪种策略。它没有回答**在哪一层注册**。
而 capture 入口会现场求值 `\CJKecglue`／`\CJKglue`／`\xeCJK_space_glue:` 三个与字体相关的
量，所以把 hook 挂在字体切换命令的内侧还是外侧，输出不同：内侧得到切换后的度量，而右边界
在 capture 结束、字体已恢复时求值，两侧必然不一致。

这条不限于 `\meta`。判据是：**若被注册命令的定义体里包含字体切换（`\texttt`、`\itshape`、
`\small` 等），capture 必须包在最外层字体切换之外**，否则左右边界会用两套度量。挂在内层的
写法在纯西文和纯 CJK 文档里都看不出问题——只有边界两侧都出现时才暴露。

这条应进 `architecture/xecjk-architecture.md` 的 capture/register 一节，并在
`experiment/boundary-register` 的手册里给用户一句对应提醒（用户注册自己的命令时同样会踩）。

### 策略选择要按实际节点次序，不能只看「有没有可见输出」（新规则，补充 #992 五策略的选择判据）

自动分析建议 #1047「注册为 transparent 或 post-transparent 其一」。实测 `post-transparent`
**无效**：它是 after-only 变体，只在命令结束后搬移末尾零尺寸盒子下方的 marker 与候选 glue，
要求 marker 与那个盒子**相邻**。而 `\Hy@raisedlink` 在盒子**之前**还排出 `\penalty`，相邻
条件不成立。`transparent` 在入口就取走 marker 与可选源码空格、节点排完再原样恢复，两种
节点次序都覆盖。

判据不是「命令有无可见输出」（两者都无），而是「命令排出的不可见节点序列长什么样、marker
与末尾盒子是否相邻」。

### 同一个用户可见命令可能走多条实现路径（新规则）

`\hypertarget{t}{锚}` 与 `\hypertarget{t}{}` 是同一个公开命令的两种调用，落到两个完全不同
的内部出口。只注册 `\Hy@raisedlink` 时，空目标形式仍然缺间距。

判据是**读分派函数的分支**（这里是 `\hyper@@anchor`），而不是看公开命令名或「这个包的锚点
都从哪出去」。两个测试的判别力实测互不重叠——去掉 `\Hy@raisedlink` 注册只有 TEST 1、TEST 2
退化（41.66002 → 38.33002），去掉 `\hyper@anchor` 注册只有 TEST 3、TEST 4 各少一枚
3.33pt——这个不重叠本身就是「确实是两条路」的证据。

这与 #1037「根因是代码事实，写成可 grep 的模式穷举全部出现位置」同源，但换了个维度：那次
穷举的是「同一件事在代码里做了几遍」，这次穷举的是「同一个入口分派到几个出口」。

## 验证与探针教训

### 既有测试全绿不构成「缺陷不存在」的证据（本次最严重的判断错误）

#1046 的自动 issue 分析结论是：「未发现左右使用不同间距的代码路径，截图中的不对称更像是
数学尖括号、斜体字形边界及字体变化造成的视觉差异」，并跑了既有的
`codedoc-meta-ecglue01.lvt` 全绿作为支持。

这条结论把一个可 grep 的代码事实归因成了视觉错觉。而它引用的证据是空的：那个测试自己
`\cs_new_protected:Npn \__codedoc_meta:n` 模拟内层函数，**没有 `\texttt` 外层**
（`codedoc-meta-ecglue01.lvt:13,33,69`），而 `\texttt` 正是本缺陷的必要条件——它对这个缺陷
零判别力。维护者当时的判断（「这个听起来是在推脱责任」）是对的。

**教训**：把「既有测试全绿」当作「缺陷不存在」的证据之前，必须先核对那些测试的**构造**是否
真的覆盖了报告的场景。这里的核对成本极低：打开 `.lvt` 看它有没有 `\texttt`。更一般地，
「未发现代码路径」这种否定性结论，需要说明搜索的是什么模式、以及为什么该模式能穷尽；否则
它只是「我没找到」，不是「不存在」。

这与 #1038「既有 `tabular01` 因每行 `\\` 前有空格而零判别力」是同一条规则的第二次发作：
**测试模拟被测对象时，简化掉的那一层可能正是缺陷所在**。#1038 简化掉的是空白，这次简化掉
的是外层字体切换命令。

### 测试用低位 box 寄存器会被被测命令自己占用（新规则）

`l3doc` 的 `\meta` 内部经 `\ensuremath` 排尖括号，会用掉 `\box10`、`\box11` 等低位 scratch
寄存器。我最初用 `\setbox10`／`\setbox11` 存测量结果，读到 `0.0pt` 和被污染的
`108.87561pt`，一度以为是实现缺陷。改用 `\newbox` 具名寄存器后读数正确。

这与 #1029「每项测试用独立的盒子／寄存器」是同一类，但成因不同：那次是自己的用例之间互相
覆盖，这次是**被测命令**覆盖了测试的寄存器。所以规则要加强为：测量类用例一律用 `\newbox`
具名寄存器，不要用 `\setbox0`--`\setbox15`——被测命令用掉哪个 scratch 寄存器不在你的控制
范围内，而失败表现是一个看起来像实现缺陷的错误读数。

### 字体预热的触发点包括「被测命令自己切换字形」（已有规则的补充）

`lessons-learned.md` 已有「字体度量回归要隔离 shaping 与首次初始化」（预热所有 lazy
family）。本次是再次印证，但新增一个具体触发点：`\meta` 的参数用 `\meta@font@select`
（`\itshape`）排版，CJK 斜体还要经过自动伪斜。不预热时 `左\meta{中文}右` 实测在
54.4378 / 76.23781 / 135.92561 之间跳。

**要预热的不只是测试正文显式用到的字体，还有被测命令自己会切换到的字形。** 判断方法是读
被测命令的定义体，把它切换的每一种字形都在 `\START` 前排一遍。

### `l3build` 只编译一遍，`\ref` 排出的是 `??`（新规则）

我最初用 `\hbox{参见 \ref{sec} 节}` 对比 `\hbox{参见 1 节}`，差 5.86pt，误以为是 `\ref`
路径也受影响。实际是首轮 `.aux` 未就绪，`\ref` 排出两字符的 `??`，宽度与最终编号不同。
改用 `\hyperref[...]{1}` 直接给出链接文字，绕开 `.aux` 依赖。

**规则**：`.lvt` 里不要用依赖 `.aux` 的量（`\ref`、`\pageref`、`\cite`、`\nameref`）做
宽度比较——它们在单遍编译里取到的是占位符。需要测「引用命令周围的间距」时，用不依赖
`.aux` 的等价入口（`\hyperref[...]{显式文字}`）。

### 本地环境中途漂移：判断「测试失败是否由本次改动引起」的可靠方法

会话进行中 TeX Live 正在更新，11 项既有测试失败与本次改动无关：`xelatex.fmt` 在我某次运行
后 32 秒被重建；`l3kernel` 已到 79868 而 `l3backend` 停在 78544，而 expl3 2026-07-20 把
后端接口从 `\__color_backend_select_<model>:n` 改成了 `:nN`，本地 l3backend 只有 `:n` 版本，
`\use:c` 找不到就把颜色参数当文本排了出来（`\special{pdf:bc [1.0 0.0 0.0]}` 变成可见的
`1.0 0.0 0.0` 文本）。

我用 `git stash` 切到 master 跑同一组测试、逐字节 `diff` 两边的 `.diff` 文件，确认全部
IDENTICAL，才排除嫌疑。

**规则**：判断一批测试失败是否由本次改动引起，可靠方法是**在同一环境下跑 master 并逐字节
比对 diff 文件**，而不是看 diff 内容像不像自己改的地方——颜色 special 变成可见文本，看起来
就很像间距类改动的后果。另外：**`tlmgr update` 报 "no updates available" 不等于本地各包
之间自洽**，TLnet 上游包之间也可能处于不一致状态（这里是 l3kernel 与 l3backend 差了
一千余个 revision）。

## 实现过程中被拒绝和走偏的两次尝试

### 公开实验性接口正确拒绝了注册，反而确认了内部修复的必要性

我先试 `\xeCJKsetup{experiment/boundary-register={command=\meta,strategy=stream,mode=default}}`，
被冲突检查以 `The command '\meta' already has an xeCJK boundary` 拒绝——`\meta` 当时在专用
适配器保留表里。这说明两件事：#1010 的双表并集检查按设计工作；这类问题**必须在 xeCJK 内部
改注册点**，不能让下游（ctxdoc）自己注册绕过。

值得记的是这次「被拒绝」是有信息量的诊断结果，而不是障碍：它直接告诉我该命令已被专用适配器
接管，修复要落在那张表上（把 `meta` 从保留表移出、改由通用注册表接管），而不是在外面叠一层。

### 想手写 `\cs_gset_protected:Npn \meta` 保存并重定义公开命令

一度想保存 `\meta` 再重定义。这会破坏 `\DeclareDocumentCommand` 的参数语义，还要另起一个
内部保存名。改用框架既有的 `\@@_boundary_register_stream:nn`（走 `cmd/meta/before|after`
通用 hook）后干净得多。

**教训**：框架已经提供注册函数时，不要手写 hook 或重定义公开命令。这与 #1029 的判据互为
两面——#1029 是「命令本体即赋值语句时通用 hook 不适用，要用专用适配器」，这次是「命令是
普通排版命令时不要绕过通用注册函数」。判据仍然是命令本体做什么，而不是修哪个包更方便。

## Promotion Candidates

按落点分三档。

**应进稳定文档（`architecture/xecjk-architecture.md` 与 `experiment/boundary-register`
手册）：**

- **注册点的字体上下文是语义的一部分。** capture 入口现场求值三个字体相关的 glue，注册
  必须包在被注册命令最外层字体切换之外；挂在内侧会让左右边界用两套度量。
- **策略选择按实际节点次序，不只看有无可见输出。** `post-transparent` 是 after-only 变体，
  要求 marker 与末尾零尺寸盒子相邻；命令在盒子前还排 `\penalty` 时不成立，须用
  `transparent`。
- **同一个用户可见命令可能走多条实现路径，判据是读分派函数的分支。** `\hypertarget` 的
  空／非空目标分别落到 `\hyper@anchor` 与 `\Hy@raisedlink`。

**应进 `reference/build-and-test.md`（测试设计约束）：**

- **测量类 `.lvt` 一律用 `\newbox` 具名寄存器**，不要用 `\setbox0`--`\setbox15`：被测命令
  会占用低位 scratch 寄存器，失败表现是一个看起来像实现缺陷的错误读数。
- **`.lvt` 不要用依赖 `.aux` 的量做宽度比较**（`l3build` 只编译一遍，`\ref` 排出 `??`）。
- **字体预热要覆盖被测命令自己切换到的字形**，不只是测试正文显式用到的字体。
- **判断测试失败是否由本次改动引起，在同一环境跑 master 并逐字节比对 diff 文件**；
  `tlmgr` 报无更新不等于本地各包自洽。

**应进 `memory/lessons-learned.md`（跨任务判断规则）：**

- **既有测试全绿只说明「测试覆盖的场景没问题」。** 把它当作「缺陷不存在」的证据之前，必须
  核对测试构造是否真的覆盖了报告的场景——尤其当测试用简化替身模拟被测对象时，简化掉的那
  一层可能正是缺陷所在（#1038 简化掉空白，#1046 简化掉外层 `\texttt`）。
- **「未发现相关代码路径」这类否定性结论要说明搜索了什么模式、为什么该模式能穷尽**，否则
  它只是「我没找到」。把代码事实归因成视觉错觉是这条失效的典型后果。

**留在本反思即可**：两次被拒绝／走偏的尝试记录，以及 l3kernel/l3backend 版本错配的具体
症状（时效性内容）。

## Follow-up

- recorder 同步 `architecture/xecjk-architecture.md`：capture/register 一节增加「注册点的
  层级与字体上下文」，并把 `post-transparent` 的相邻性前置条件写进策略选择判据；`meta` 从
  保留表移到通用注册表这一变化也要在双表并集不变量的描述里体现。
- recorder 同步 `reference/build-and-test.md`：登记
  `codedoc-meta-symmetry01.lvt/.tlg`（13 项断言）与
  `hyperref-anchor-ecglue01.lvt/.tlg`（7 项断言），xeCJK 标准回归总数从 120 增至 122；
  并记录既有 `codedoc-meta-ecglue01` 对 #1046 零判别力这一事实，避免后来者以为已覆盖。
- `experiment/boundary-register` 的用户手册补一句：注册自己的命令时，若命令定义体里有字体
  切换，hook 要挂在最外层。这与 #1029 已补的「命令本体即赋值语句」提醒同属「哪些命令模式
  需要特殊处理」清单。
- #1045 下还有其他手册排版异常子问题，排查时先按本次的两条判据过一遍：注册点是否在字体
  切换外侧、该命令是否还有别的实现出口。

## 相关

- Issue：#1046、#1047；父 issue #1045（手册排版异常）。
- 实现：`xeCJK/xeCJK.dtx` 中 `\@@_boundary_register_stream:nn { meta } { default }`
  （替代内层 `\__codedoc_meta:n` 上的 inline stream）、
  `\@@_boundary_register_transparent:n { Hy@raisedlink }` 与
  `\@@_boundary_register_transparent:n { hyper@anchor }`（后者带 `\cs_if_exist:NT` 守卫，
  因为它由驱动定义）。
- 上游参考位置：`l3doc.cls:542-543`、`hyperref.sty:2104`、`hyperref.sty:5134`、
  `hxetex.def:291`；capture 入口求值处 `xeCJK/xeCJK.dtx:5293` 与 `:5322` 附近。
- 测试：`xeCJK/testfiles/codedoc-meta-symmetry01.lvt/.tlg`、
  `xeCJK/testfiles/hyperref-anchor-ecglue01.lvt/.tlg`。
- 相关决策：[[992-command-boundary-capture-register]]、[[1010-boundary-register-public-api]]、
  [[1029-sbox-adapter]]（通用 hook 与专用适配器的选择边界，本次是同一判据的另一面）、
  [[873-880-fixed-point-vs-default-narrowing]]（`\HD@target` 同为无可见输出的 transparent
  注册，是 #1047 的先例）。
- 相关反思：[[1038-tabular-cr-group-peek]]（既有测试因简化掉一层而零判别力）、
  [[1037-ulem-word-front-ecglue]]（根因是代码事实，须穷举全部位置）、
  [[1029-sbox-global-prefix]]（测试寄存器独立性、报告者／分析者给出的结论须核实）、
  [[1043-halign-alignment-tab-in-boundary-args]]（探针与归因须分别验证）。
