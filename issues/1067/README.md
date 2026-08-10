# Issue #1067 资产

`\CJKunderline` 正文里用花括号括住一段内容时，该处中西文间距（`\CJKecglue`）的**可收缩量**
失效。自然宽度不变，所以只在 `\hbox to` 一类固定宽度、且收缩量吃紧的场合显现；段落断行下
两种写法都不溢出、视觉一致。

根因是 `ulem` 按源码空格把正文切成固定宽度的片段盒：花括号使紧接其前的源码空格不再成为切分
点，于是该处间距连自然宽度带可收缩量一起落进了片段盒内部，盒宽固定，收缩量随之失效。

## 文件

- `issue1067-mwe.tex` / `issue1067-comparison.png` — 复现 MWE 与对比图。12pt 字号下正文
  自然宽度 79.98pt，压进 78pt 需要 1.98pt 收缩量。四行分别是：无编组（排得进）、有编组
  （溢出框外）、`\color{red}hello`（花括号留给参数，排得进）、`\CJKunderdot`（符号型命令，
  排得进）。后两行是手册给出的替代写法。
- `issue1067-showbox-probe.tex` / `issue1067-segment-box-widths.txt` — 根因判据的探针与它的
  原始读数。片段盒宽度从 `10/10/20.56/10/10` 变成 `10/10/23.89/10/10`——**个数不变**，第三个
  正好多出 3.33pt，即那一处间距的自然宽度。

## 实测记录

两侧都用 PR 分支现场 `l3build unpack` 出的 `xeCJK.sty`（v3.10.6），引擎 XeTeX，TeX Live 2026。

压窄 2pt 时的 `\badness`（73 = 收缩量够，1000000 = 不够）：

| 写法 | badness |
| --- | --- |
| 无装饰命令（oracle） | 73 |
| `\CJKunderline{虚室 hello 生白}` | 73 |
| `\CJKunderline{虚室 {hello} 生白}` | 1000000 |
| `\CJKunderline{虚室 \textbf{hello} 生白}` | 1000000 |
| `\CJKunderline{虚室 {文字} 生白}` | 1000000 |
| `\CJKunderline{虚室 \color{red}hello 生白}` | 73 |
| `\CJKunderdot{虚室 {hello} 生白}` | 73 |

`{文字}` 那一行说明汉字之间的 `\CJKglue` 同样受影响，不限于中西文边界——这一点比原报告
所述更广。

注意本问题只在 v3.10.5 及以后可复现：系统安装的 v3.10.4 下两种写法的溢出量相同（都
4.22pt），v3.10.5 下才分化为 2.0pt 与 3.11pt。
