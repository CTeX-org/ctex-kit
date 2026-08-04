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

## 决策二：hyperref 的行内锚点按两条出口分别注册 `transparent`

`\hypertarget` 在源码里是一个命令，实际排版按目标是否为空分派到两个互不相交
的内部出口，各需一次注册：

1. `\Hy@raisedlink`——非空目标的 `\hypertarget`、目录锚点、
   `threeparttable` 脚注锚点走这条，排出 `\penalty\@M` 加一个 `\smash` 后的
   `hbox(0+0)x0`。
2. 驱动层 `\hyper@anchor`——空目标的 `\hypertarget` 经 `\hyper@@anchor`
   落到这里，直接排出裸的 `pdf:dest` whatsit。该命令由驱动定义
   （`hxetex.def`、`hluatex.def`、`hpdftex.def`、`hdvipdfm.def` 同名，
   `hdvips.def` 没有），注册前用 `\cs_if_exist:NT` 守卫。

两者都没有可见输出，与 `hypdoc` 的 `\HD@target` 同属一类。

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

- `codedoc-meta-symmetry01`：13 项断言，用真实 `l3doc` 类。四种源码空格
  组合均为 55.4378pt，与 oracle `左\texttt{$\langle$name$\rangle$}右` 相等
  （修复前 57.3578pt）；左右单边贡献均 13.33pt（修复前左 15.25pt）。判别力
  已实测：把注册点改回内层后 8 项失败。
- `hyperref-anchor-ecglue01`：7 项断言。`\exptarget\expstar` 与裸
  `\hypertarget{t}{}$\star$` 均由 38.33002pt 恢复为 41.66002pt，等于直接
  输入 `$\star$` 的 oracle。两个注册的判别力互不重叠。
- xeCJK 标准回归 122／122；ctex 主回归与 `config-contrib` 的失败项已用
  「同一环境跑 master 并逐字节比对 diff」确认全部与改动无关。
- `ctxdoc` 真实环境（TeX Gyre Pagella）：`\meta` 59.62122pt → 56.72289pt，
  `\exptarget\expstar` 40.41847pt → 43.05331pt。手册排版警告由 559 条降至
  551 条。

## 相关资料

- Issue：#1046、#1047；父 issue #1045
- 架构：[[../../architecture/xecjk-architecture]]（「注册点的层级与字体
  上下文」「策略选择要看不可见节点的实际次序」「同一个公开命令可能有多条
  实现出口」三节）
- 内部框架决策：[[992-command-boundary-capture-register]]
- 用户接口决策：[[1010-boundary-register-public-api]]
- 通用 hook 与专用适配器的选择边界：[[1029-sbox-adapter]]
- `\HD@target` 作为 transparent 注册的先例：
  [[873-880-fixed-point-vs-default-narrowing]]
- 测试：[[../../reference/build-and-test]]
- 反思：[[../reflections/1046-1047-meta-anchor-font-context]]
