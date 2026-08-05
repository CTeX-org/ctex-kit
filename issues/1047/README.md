# Issue #1047 资产

`ctxdoc` 手册中 `\exptarget\expstar` 的五角星左侧缺少 `\CJKecglue`，紧贴
前一个汉字；去掉 `\exptarget` 后正常。

根因（不可见锚点遮蔽 marker）：`hyperref` 的行内锚点在 xeCJK 的 marker 与
后续字符之间插入不可见节点，使 Boundary→{Default,CJK} 路径的 marker 探测
失败。有两条彼此独立的路径，各需一次注册：

1. `\Hy@raisedlink`：水平模式下排出 `\penalty\@M` 加一个 `\smash` 后的
   `hbox(0+0)x0`（内含 `pdf:dest` special）。带非空目标的 `\hypertarget`、
   目录锚点、`threeparttable` 的脚注锚点都走这条。
2. 驱动层的 `\hyper@anchor`：空目标的 `\hypertarget` 经 `\hyper@@anchor`
   落到这里，直接排出**裸的** `pdf:dest` whatsit，不经过 `\Hy@raisedlink`。
   `hxetex.def`、`hluatex.def`、`hpdftex.def`、`hdvipdfm.def` 使用同一名称。

两者都没有可见输出，注册为 `transparent`（入口取走 marker 与可选源码空格，
锚点节点排出后原样恢复），与 `hypdoc` 的 `\HD@target` 同属一类。

**不能用 `post-transparent`**（已实测无效）：那个 after-only 变体要求
marker 与末尾零尺寸盒子相邻，而 `\Hy@raisedlink` 在盒子**之前**还排出了
`\penalty`，搬移条件不成立。

- `issue1047-mwe.tex` — 对照 MWE。四行分别是 `\Hy@raisedlink` 锚点加链接、
  仅链接、裸 `\hypertarget`、直接输入 `$\star$`（参考）。
- `issue1047-before.png` — 修复前：第 1、3 行五角星紧贴 `有`。
- `issue1047-after.png` — 修复后：四行一致。

实测宽度（`article` 10pt + FandolSong）：

| | 修复前 | 修复后 | oracle |
| --- | --- | --- | --- |
| `带有 \exptarget\expstar{} 标` | 38.33002pt | 41.66002pt | 41.66002pt |
| `带有 \hypertarget{t}{}$\star$ 标` | 38.33002pt | 41.66002pt | 41.66002pt |
| `带有 \hypertarget{t}{}word 标` | 54.75pt | 58.08pt | 58.08pt |

`ctxdoc`（TeX Gyre Pagella）下：40.41847pt → 43.05331pt。

非空目标不受影响：`\hypertarget{t}{锚}$\star$` 仍按 CJK–CJK 处理，与直接
输入 `锚$\star$` 等宽（51.66002pt），注册 `transparent` 不会给它补上
`\CJKecglue`。

## 既有限制（改动前后相同）

无源码空格 + 不可见命令 + 紧接公式仍缺一枚 `3.33pt`，例如
`带有\hypertarget{t}{}$\star$标` = 38.33002pt。这不是本次引入：在未改动的
版本上用既有的 `\textcolor{red}{}`（`transparent`）与 `\null`
（`post-transparent`）替换锚点，读数同为 38.33002pt。

回归测试 `hyperref-anchor-ecglue01`（7 项断言）。两个注册的判别力互不重叠，
正好说明是两条独立路径：去掉 `\Hy@raisedlink` 注册使 TEST 1、2 失败；
去掉 `\hyper@anchor` 注册使 TEST 3、4 失败，各差 3.33pt。

## 出口清单（PR 定稿，2026-08-05）

最终实现覆盖三个出口，另有一个已知未覆盖。区分依据是**调用点**，不是锚点内容
——最初写的「按目标是否为空分派」经计数器实测为假。

**已覆盖：**

| 出口 | 承接的入口 |
| --- | --- |
| 驱动层 `\hyper@anchor` | **全部** `\hypertarget`（空/非空目标皆然，`\@hyper@@anchor` 在 `\ifHy@activeanchor` 为假时统一调用它） |
| `\Hy@raisedlink` | 无编号标题（`\section*`、`\chapter*`、目录与参考文献标题）、caption、公式编号、脚注、`\bibitem`，以及下游手工包裹（ctxdoc 的 `\exptarget`） |
| `\__hyp_target_raise:n` | `\phantomsection`、`\MakeLinkTarget`、编号标题锚点 |

第三个出口不接受通用命令 hook（LaTeX hook 拒绝 expl3 私有函数），需用
**带花括号转发参数**的包装变体：它会把参数再次交给 `\hbox:n`，无花括号转发会
让紧随其后的 `\Hy@SaveSpaceFactor` 被卷进 `\hyper@anchorstart` 的参数，把
`\spacefactor` 赋值写进 `pdf:dest` 名字并把锚点名排成可见文本。该故障与 xeCJK
的钩子无关——不挂任何钩子、仅做无花括号透传同样复现（81.16002pt）。

**已知未覆盖：** `\hyper@anchorstart` 的裸调用。`\pdfbookmark` 直接写
`\hyper@anchorstart{...}\hyper@anchorend`，绕过上面三处（计数器实测三者均为 0），
右侧仍缺一枚 `\CJKecglue`。这不是本次引入，base 上同样如此。两种就手补法均实测
不可行：注册 `\@pdfm@dest` 使盒宽暴涨并报十余处错误；注册 `\hyper@anchorstart`
不报错但也不生效，已覆盖的三处不受影响，原因尚未查明。已另立议题跟踪，
`hyperref-anchor-ecglue01` 的 TEST 10 把该缺口固定为断言。

- `issue1047-outlets-mwe.tex` — 五种锚点写法加一行直接输入的参考，全篇同一字号，
  各行右端画红竖线。
- `issue1047-outlets-before.png` — 修复前：五种写法全部比参考窄。
- `issue1047-outlets-after.png` — 修复后：前四种与参考对齐，`\pdfbookmark` 仍窄
  （已知未覆盖）。

### 文档写法上的教训

「行内锚点有几个出口」这个数字先后写错四次，每次都是从「注册这些之后报告的现象
消失」推出更强的断言，每次都被一支计数器探针或一次隔离实验推翻。因此定稿改为
**只维护「已覆盖」与「已知未覆盖」两份清单、不给出总数**：清单的每一条都能被单条
探针核查，总数只能由穷举审计支撑，而那个审计从未做过。
