# Issue #1002 资产

这些文件用于检查行内公式与中文相邻时的间距。测试分为两部分：直接输入
`$x$`、`\(x\)`、`\ensuremath{x}`；以及在分组、字体命令、颜色命令和
盒子命令中使用 `$x$`。

## 文件

- `issue1002-mwe.tex`：确定比较基准时使用的初始测试文件。每次测量前
  都会清理 xeCJK 的相关状态，避免前一项测试影响后一项。它同时记录
  直接输入的绝对宽度变化，并分别以 `$x$` 和西文字母 `x` 比较。
- `issue1002-master-10500b33.txt`：使用 PR #1001 合并后的 `master`
  提交 `10500b33` 编译所得的完整数值。
- `issue1002-v3.10.3-4628cb44.txt`：使用 xeCJK v3.10.3 对应提交
  `4628cb44` 编译所得的完整数值。
- `issue1002-visual.tex` 和 `issue1002-visual.png`：使用 5pt
  `CJKecglue` 和 1pt `CJKglue` 排出的代表性对照。
- `inline-math-matrix.tex` 及三个 `inline-math-matrix-*.tex`：状态表使用的
  完整测试文件。四种间距设置分别启动 XeLaTeX 编译，避免同一次编译中
  切换 `xCJKecglue` 影响后续结果。每次测试都以直接输入 `$x$` 为比较
  基准，覆盖 17 种命令、四种周边文字组合和四种源码空格。
- `inline-math-verdicts.tsv`：上述完整测试的逐命令结果。`CMC`、`WMW`、
  `CMW`、`WMC` 依次表示中文—公式—中文、西文—公式—西文、
  中文—公式—西文、西文—公式—中文；每列的四个字母对应
  `00`、`10`、`01`、`11`。
- `inline-math-showcase.tex` 和 `inline-math-showcase-true.tex`：逐命令排版
  对照的源文件。`false` 和 `true` 分别启动 XeLaTeX 编译；最终图片把
  对应页面上下合并，因此每张图都包含两种选项值和四种周边文字，共
  8 组、32 项。
- `showcase/*.png`：状态表引用的逐命令排版图片。
- `pr/fbox-after.png`：PR 预览图。使用待合并分支提交 `2092edad`
  编译 `inline-math-showcase*.tex`，展示 `\\fbox{$x$}` 在
  `xCJKecglue=false/true`、四种周边文字和 `00/10/01/11` 下均与直接
  输入 `$x$` 相同。它只说明待合并分支的结果，不提前更新 #992 或
  #1002 的已合并状态表。

## 复查结果

- 直接输入 `$x$` 的结果在 `4628cb44` 和 `10500b33` 上完全相同，
  因此不是 PR #999 或 PR #1001 引入的问题。
- `xCJKecglue=false` 时，`$x$` 左右每出现一个源码空格，总宽度都会减少
  1.67pt，也就是使用 3.33pt 的普通词间空格代替 5pt 的
  `CJKecglue`；设为 `true` 后，四种写法等宽。这说明现有实现确实把
  `xCJKecglue` 用于行内公式，只是手册尚未明确写出这一点。
- `\(x\)` 和 `\ensuremath{x}` 与直接输入 `$x$` 不一致：`10` 和 `11`
  均少 3.33pt。两者应与 `$x$` 使用同一比较基准。
- 对命令内部的 `$x$`，比较时应只去掉外层命令并保留公式；改用字母 `x`
  会掩盖 `\texttt{$x$}`、`\textbf{$x$}` 和 `\mbox{$x$}` 在左侧源码空格
  上的差异。
- 显式分组、颜色命令、`\fbox` 和 `\colorbox` 在两种比较方法下都有差异，
  需要在确定公式的间距规则后分别修正。

## 公式专用状态表

状态表采用 #992 已确定的规则：命令包裹后的写法和直接输入使用相同的
`xCJKecglue` 设置；每格只有在默认间距和 5pt/1pt 间距下都与直接输入
`$x$` 相同时才记为通过。两个混合方向用于分别检查公式左侧和右侧，
避免两侧的宽度差互相抵消。

本次测试基于 `master` 提交 `10500b33`。每套设置包含 17 种命令、
四种周边文字组合和四种源码空格，共 272 个单元：

- `xCJKecglue=false`：默认间距 191／272 通过，5pt/1pt 间距
  181／272 通过；
- `xCJKecglue=true`：默认间距 182／272 通过，5pt/1pt 间距
  176／272 通过。

这些是当前失败情况的记录，不表示已经完成修复。修复合并后，应从新的
`master` 提交重新编译，再更新 #1002 的表格和图片。

编译命令：

```sh
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex issue1002-mwe.tex
grep '^MATH' issue1002-mwe.log
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-matrix.tex
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-matrix-false-custom.tex
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-matrix-true-default.tex
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-matrix-true-custom.tex
grep '^INLINE' inline-math-matrix*.log
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-showcase.tex
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex inline-math-showcase-true.tex
```
