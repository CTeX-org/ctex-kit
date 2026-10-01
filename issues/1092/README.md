# Issue #1092 资产

xeCJK 只给 siunitx 的 `\unit`、`\qty`、`\num`、`\si`、`\SI` 注册了命令边界处理（#1000）。其余排版命令左侧紧接汉字时都缺少 `\CJKecglue`，右侧正常。

根因：siunitx 在命令内部用 `$...$` 排版数字和单位。直接在源码写 `中$30$` 时，xeCJK 在汉字之后看到下一个记号是 `$`，会在公式前补上 `\CJKecglue`；汉字之后是 `\numrange` 这样的宏时，xeCJK 只留下一对边界标记（kern），等到 siunitx 在宏内部进入数学模式，`\mathon` 节点把标记盖住，间距就再也补不上。已注册的命令由 stream capture 在入口按 Default 首类别补上间距，未注册的命令没有这一步。

- `issue1092-mwe.tex` — issue 原 MWE，补上列表、乘积、复数、时长四行。
- `issue1092-confirm.tex`／`issue1092-confirm.png` — 带标注的对比图：绿色为汉字与 siunitx 输出之间实际排出的间距，红色竖条表示此处没有间距。`\SI`、`\qty` 两侧都是 3.33pt；其余 11 个命令左侧为 0pt，右侧为 3.33pt。用 `xelatex "\def\LABEL{...}\input{issue1092-confirm}"` 编译。
- `issue1092-matrix.tex` — 宽度矩阵：命令写法与去掉命令后的同样可见内容比较，`CJKecglue` 设为 5pt，四种源码空格（`00/10/01/11`）。未注册的命令在中文上下文里每格差 −5pt，西文上下文为 0。
- `issue1092-nodes.tex` — 节点列表：`中$30$` 在 `\mathon` 前有 `\glue 3.33`；`中\numrange{30}{70}` 在 `\mathon` 前只有一对 `\kern -0.00017`／`\kern 0.00017` 标记。

测试环境：XeLaTeX，TeX Live 2026，siunitx 2026-05-15 v3.5.5；xeCJK 为仓库 master（v3.10.7 开发版）与 TeX Live 安装的 v3.10.1，结果相同。
