# Issue #1046 资产

`l3doc` + `xeCJK` 下 `\meta` 两侧的 `\CJKecglue` 不对称：左侧是不可伸缩的
`5.25pt`，右侧是 `3.33pt plus 1.665 minus 1.11`（Latin Modern，10pt）。
四种源码空格组合下左侧数值恒定，因此不是源码空格语义差异，也不是尖括号
或斜体字形造成的视觉错觉。

根因（注册点的字体上下文）：命令边界 capture 在**入口**处把 `\CJKecglue`
排入临时盒并读成 skip 数值（`\__xeCJK_boundary_capture_begin:`，
`xeCJK.dtx` 中 `\xeCJK_glue_to_skip:nN { \CJKecglue }` 一行），缓存的度量
取决于 capture 开始时生效的字体。`l3doc` 的 `\meta` 定义为
`\texttt{ \__codedoc_meta:n {#1} }`，而适配器把 stream capture 包在**内层**
的 `\__codedoc_meta:n` 上——capture 因此落在 `\texttt` 已经切到等宽字体
之后：左边界重放等宽字体的 `\CJKecglue`，右边界在 capture 结束、字体恢复
之后求值，得到正文字体的数值。

修法：capture 上移到公开的 `\meta`，改用通用注册
`\@@_boundary_register_stream:nn { meta } { default }`；内层
`\__codedoc_meta:n` 只保留 `\hbox:n` 参数包装（#920 的目标不变）。

- `issue1046-mwe.tex` — 对照 MWE。四种源码空格组合加一行直接输入的参考
  `左\texttt{$\langle$name$\rangle$}右`，各行右端画红竖线。
- `issue1046-before.png` — 修复前：前四行比参考行宽，`左` 与 `⟨` 之间偏松。
- `issue1046-after.png` — 修复后：五行右端竖线对齐。

实测宽度（`l3doc` 10pt + FandolSong）：

| | 修复前 | 修复后 | oracle |
| --- | --- | --- | --- |
| `左\meta{name}右`（四种空格组合） | 57.3578pt | 55.4378pt | 55.4378pt |
| 单侧边界贡献（左 / 右） | 15.25 / 13.33pt | 13.33 / 13.33pt | 13.33pt |

`ctxdoc`（TeX Gyre Pagella）下：59.62122pt → 56.72289pt。

`\Arg`、`\marg`、`\oarg`、`\parg` 不受影响：它们在 `\__codedoc_meta:n`
两侧各自排出等宽的 `{`、`[`、`(` 实字符，本身就构成正常的 CJK→Default
边界；去掉内层 capture 前后节点列表逐字节相同。`doc` 宏包的 `\meta`
没有 `\texttt` 外层，本来就对称，实现未改。

回归测试 `codedoc-meta-symmetry01`（13 项断言，用真 `l3doc` 类）。把注册点
改回内层可复现缺陷：8 项断言失败，数值为 1.92pt（=5.25−3.33）、15.25pt
与 badness 10000。既有的 `codedoc-meta-ecglue01` 对这个缺陷零判别力，
因为它模拟的 `\__codedoc_meta:n` 没有 `\texttt` 外层。
