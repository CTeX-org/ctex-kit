# Issue #1100 资产

`section/fixskip=true`（以及 `chapter/fixskip`、`part/fixskip`）时，紧跟标题的 `[h]` 浮动体如果就地放下，题注与后文之间的距离比 `fixskip=false` 小约一行间胶；浮动体前有正文段落时不受影响。

根因：`\CTEX@fixheadingskip` 在标题后把 `\prevdepth` 设为 `-1000pt`，让标题后第一行不加行间胶。`[h]` 浮动体在竖直模式结束时，LaTeX 的 `\end@float` 会保存并恢复 `\prevdepth`（让浮动体对行间胶透明），就地放置浮动体的输出例程也不改变主竖直列表的 `\prevdepth`。于是浮动体之后的第一行仍然看到 `-1000pt`，紧贴浮动体下方的 `\intextsep` 排出。

- `issue1100-mwe.tex` — 带标注的 MWE。`xelatex "\def\FIX{false}\input{issue1100-mwe}"` 与 `\def\FIX{true}` 各编译三遍。
- `issue1100-confirm.png` — 上述两种设置的对比图（加载 `caption` 并设 `belowskip=-12pt`）。红色区域与数字是题注末行基线到后文首行基线的距离。
- `issue1100-measure.tex` — 不画图、只在日志输出 `RESULT` 距离的测量文件，可用 `\def\CAP{1}` 加载 `caption`。
- `issue1100-probe.tex` — 在 `env/figure/after` 钩子里输出 `\prevdepth`，紧跟标题的图之后为 `-1000.0pt`，紧跟正文的图之后为正常的行深度。

测量结果（XeLaTeX，`ctexart`，单位 pt，“紧跟标题，紧跟正文”）：

|                  | `fixskip=false`    | `fixskip=true`     |
| ---------------- | ------------------ | ------------------ |
| 不加载 `caption` | 27.77，28.61       | 21.78，28.61       |
| `caption` + `belowskip=-12pt` | 18.86，19.70 | 12.87，19.70 |

pdfLaTeX、LuaLaTeX 与 `ctexbook` 的 `\chapter` 结果相同。
