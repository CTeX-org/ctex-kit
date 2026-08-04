# 决策：#1046／#1047 命令边界的注册点选择

## 背景

#1045 报告 xeCJK 手册排版异常，#1046 与 #1047 是其中两个子问题。两者都不是
#992 capture/register 框架的策略选错，而是**注册点**选错：一个挂在了错误的
层级，一个漏了一条实现路径。

自动 issue 分析对 #1046 给出的结论是「未发现左右使用不同间距的代码路径，
截图中的不对称更像是数学尖括号、斜体字形边界及字体变化造成的视觉差异」，
并引用既有测试全绿作为支持。这个结论不成立：它引用的
`codedoc-meta-ecglue01` 自己模拟内层 `\__codedoc_meta:n`，没有 `\texttt`
外层，而 `\texttt` 正是缺陷的必要条件，该测试对这个场景零判别力。实测左侧
`\CJKecglue` 在四种源码空格组合下恒为不可伸缩的 `5.25pt`、右侧恒为
`3.33pt plus 1.665 minus 1.11`，是可复现的代码事实。

## 决策一：`\meta` 的 stream capture 注册在公开命令，而非内层参数排版函数

`\@@_boundary_capture_begin:` 在 capture **入口**处把 `\CJKecglue`、
`\CJKglue` 和词间空格分别排入临时盒并读成 skip 数值，缓存的度量因此取决于
进入命令那一刻生效的字体。l3doc 把 `\meta` 定义为
`\texttt{ \__codedoc_meta:n {#1} }`，旧实现把 capture 包在内层的
`\__codedoc_meta:n` 上，于是左边界重放等宽字体的度量，右边界在 capture
结束、字体已恢复之后求值，两侧取到两套数值。

改为 `\@@_boundary_register_stream:nn { meta } { default }`，走通用
`cmd/meta/before|after` hook；内层 `\__codedoc_meta:n` 只保留 `\hbox:n`
参数包装，#920 的目标不变。`meta` 相应从专用适配器保留表移入通用注册表：
保留表的语义是「必须直接重定义内部排版入口、不能用 LaTeX 通用命令 hook 的
命令」，`\meta` 现在走的正是通用 hook，留在保留表里会与该表定义矛盾；#1010
的用户接口冲突检查查两表并集，因此只落在通用表里也不会让用户注册绕过。

否决的两个做法：

- **手写 `\cs_gset_protected:Npn \meta` 保存并重定义公开命令**。会破坏
  `\DeclareDocumentCommand` 的参数语义，还要另起一个内部保存名。框架既然已
  提供注册函数，就不该手写 hook 或重定义公开命令。
- **让下游（ctxdoc）自己用 `experiment/boundary-register` 注册**。实测被
  #1010 的冲突检查以 `The command '\meta' already has an xeCJK boundary`
  正确拒绝——`\meta` 当时在保留表里。这个拒绝是有信息量的诊断：它说明该命令
  已被专用适配器接管，修复必须落在那张表上，而不是在外面叠一层。

`\Arg`、`\marg`、`\oarg`、`\parg` 不需要这层 capture：它们在
`\__codedoc_meta:n` 两侧各排出等宽的 `{`、`[`、`(` 实字符，本身就构成正常的
CJK→Default 边界，去掉内层 capture 前后节点列表逐字节相同。它们仍留在保留
表，防止用户接口把通用 hook 叠到共享的内部实现上。`doc` 宏包的 `\meta`
没有 `\texttt` 外层，本来对称，实现未改。

## 决策二：hyperref 的行内锚点注册其中两个出口为 `transparent`

hyperref 的行内锚点有多个出口，区分依据是**调用点**而不是锚点内容。本次注册
其中两个：

1. 驱动层 `\hyper@anchor`——承接经 `\hyper@@anchor` 进来的锚点，直接排出裸的
   `pdf:dest` whatsit。**`\hypertarget` 的两个分支最终都走这里**：
   `\@hyper@@anchor` 在 `\ifHy@activeanchor` 为假时统一调用 `\hyper@anchor`，
   与目标内容是否为空无关。该命令由驱动定义（`hxetex.def`、`hluatex.def`、
   `hpdftex.def`、`hdvipdfm.def` 同名，`hdvips.def` 没有），注册前用
   `\cs_if_exist:NT` 守卫；hyperref 在 `\AtEndOfPackage` 阶段载入驱动，
   包尾钩子里的存在性检查时机正确。
2. `\Hy@raisedlink`——承接需要抬升的锚点，以及下游手工包裹
   的写法，例如 ctxdoc 的 `\exptarget` 定义为
   `\Hy@raisedlink{\hypertarget{expstar}{}}`。它在水平模式下排出
   `\penalty\@M` 加一个 `\smash` 后的 `hbox(0+0)x0`。承接的具体入口有：
   无编号标题（`\section*`、`\chapter*`，以及目录、参考文献等自动生成的
   无编号标题）、caption、公式编号、脚注、`\bibitem`。目录**条目**不走这条
   路——`\contentsline` 用 `\hyper@linkstart`／`\hyper@linkend`，与抬升锚点
   无关（实测计数为 0）。

两者都没有可见输出，与 `hypdoc` 的 `\HD@target` 同属一类。

### 已接受：第三个出口暂不覆盖

`\__hyp_target_raise:n` 是第三个抬升出口，`\phantomsection` 与
`\MakeLinkTarget` 走它，编号标题的锚点也经过它。它排出同构的 `\penalty\@M`
加 `\smash` 抬升盒子，不经过 `\Hy@raisedlink`，因此 `\phantomsection` 右侧
仍丢失一枚 `\CJKecglue`（38.33002pt 对 oracle 41.66002pt）。

暂不覆盖的理由是两条现成途径都不适用：它不接受通用命令 hook（LaTeX hook
机制拒绝 expl3 私有函数）；`\@@_boundary_wrap_transparent_onearg:NN` 会把
begin 钩子里的赋值卷进它的参数展开，实测把 `\spacefactor` 赋值写进了
`pdf:dest` 名字、并把锚点名 `section*.1` 排成可见文本（盒宽由 41.66002pt 变
84.49002pt）。需要为它单独设计适配器，作为独立议题跟踪。
`hyperref-anchor-ecglue01` 的 TEST 7 把这个缺口固定为断言，补上注册时会主动
失败，强制回来更新出口清单。

### 两次被推翻的机制陈述

本决策的机制描述被盲审连续推翻两次，形态相同：

1. 先写「非空目标经 `\Hy@raisedlink`、空目标经 `\hyper@anchor`」。计数器实测：
   四种 `\hypertarget` 形式的 `\Hy@raisedlink` 调用次数**均为 0**。
2. 改对分派依据后又写「行内锚点有两个出口」，并把「两个」写进架构文档与
   lessons-learned。计数器实测：`\phantomsection` 使 `\__hyp_target_raise:n`
   计数 +1 而另两者均为 0。

两次都是从「注册这些之后报告的现象消失」推出了更强的断言。**「A 与 B 都必要」
既不能推出「只有 A 和 B」，也不能推出「按某条件在 A、B 间分派」**；三者是独立
命题，各需自己的探针。写「全部」「两个」「只有」这类穷尽性断言前应先问：我用
什么手段排除了第三种可能？

**否决 `post-transparent`**（实测无效）：它是 after-only 变体，只搬移末尾
零尺寸盒子下方的 marker 与候选 glue，要求 marker 与那个盒子**相邻**；而
`\Hy@raisedlink` 在盒子之前还排出 `\penalty`，相邻条件不成立。因此策略选择
的判据不是「命令有无可见输出」（两者都无），而是命令排出的不可见节点序列
长什么样、marker 与末尾盒子是否相邻。

## 已接受的限制

无源码空格 + 不可见命令 + 紧接公式仍缺一枚 `3.33pt`，例如
`带有\hypertarget{t}{}$\star$标` = 38.33002pt。这不是本次引入：在未改动的
版本上用既有的 `\textcolor{red}{}`（`transparent`）与 `\null`
（`post-transparent`）替换锚点，读数同为 38.33002pt。

## 验证状态

- `codedoc-meta-symmetry01`：9 个 `\TEST` 块共 12 项断言，用真实 `l3doc` 类。
  四种源码空格组合均为 55.4378pt，与 oracle `左\texttt{$\langle$name$\rangle$}右`
  相等（修复前 57.3578pt）；左右单边贡献均 13.33pt（修复前左 15.25pt）。
  判别力已实测：把注册点改回内层后 8 项失败。
- `hyperref-anchor-ecglue01`：9 项断言。手工包裹的 `\TestTarget`（复刻
  ctxdoc `\exptarget` 的 `\Hy@raisedlink{\hypertarget{...}{}}` 写法）加链接
  公式、裸 `\hypertarget{t}{}$\star$` 均由 38.33002pt 恢复为 41.66002pt，
  等于直接输入 `$\star$` 的 oracle；带西文可见内容的
  `\hypertarget{t}{word}$\star$` 由 59.75002pt 恢复为 63.08002pt。两个注册
  的判别力互不重叠（去 `\Hy@raisedlink` 使 TEST 1、2 失败；去
  `\hyper@anchor` 使 TEST 3、4、4b 失败）。TEST 7 固定第三个出口的已知缺口仍为 3.33pt。
- xeCJK 标准回归 122／122；ctex 主回归与 `config-contrib` 的失败项已用
  「同一环境跑 master 并逐字节比对 diff」确认全部与改动无关。
- `ctxdoc` 真实环境（TeX Gyre Pagella）：`\meta` 59.62122pt → 56.72289pt，
  `\exptarget\expstar` 40.41847pt → 43.05331pt。手册排版警告由 559 条降至
  551 条。

## 相关资料

- Issue：#1046、#1047；父 issue #1045
- 架构：[[../../architecture/xecjk-architecture]]（「注册点的层级与字体
  上下文」「策略选择要看不可见节点的实际次序」「同一类节点可能有多个出口，
  按调用点而非参数形态区分」三节）
- 内部框架决策：[[992-command-boundary-capture-register]]
- 用户接口决策：[[1010-boundary-register-public-api]]
- 通用 hook 与专用适配器的选择边界：[[1029-sbox-adapter]]
- `\HD@target` 作为 transparent 注册的先例：
  [[873-880-fixed-point-vs-default-narrowing]]
- 测试：[[../../reference/build-and-test]]
- 反思：[[../reflections/1046-1047-meta-anchor-font-context]]
