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
