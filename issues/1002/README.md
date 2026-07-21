# Issue #1002 资产

这些文件用于检查行内公式与中文相邻时的间距。测试分为两部分：直接输入
`$x$`、`\(x\)`、`\ensuremath{x}`；以及在分组、字体命令、颜色命令和
盒子命令中使用 `$x$`。

## 文件

- `issue1002-mwe.tex`：完整测试文件。每次测量前都会清理 xeCJK 的相关
  状态，避免前一项测试影响后一项。它同时记录直接输入的绝对宽度变化，
  并分别以 `$x$` 和西文字母 `x` 为比较基准。
- `issue1002-master-10500b33.txt`：使用 PR #1001 合并后的 `master`
  提交 `10500b33` 编译所得的完整数值。
- `issue1002-v3.10.3-4628cb44.txt`：使用 xeCJK v3.10.3 对应提交
  `4628cb44` 编译所得的完整数值。
- `issue1002-visual.tex` 和 `issue1002-visual.png`：使用 5pt
  `CJKecglue` 和 1pt `CJKglue` 排出的代表性对照。

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

编译命令：

```sh
TEXINPUTS=/path/to/xeCJK/build/unpacked//: xelatex issue1002-mwe.tex
grep '^MATH' issue1002-mwe.log
```
