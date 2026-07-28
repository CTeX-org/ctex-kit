# Issue #1026 资产

这些文件用于验证 xeCJKfntef 装饰在换行时右边界不对齐的修复（PR #1035），
以及确认该修复没有回退 #1002 的行内公式边界间距语义。

三个被比较的版本：

- **base `c39b1fce`**：PR #1035 的父提交，含 #1002 的修复，也含本 issue 的回归。
- **PR #1035**：本次修复。
- v3.10.3（系统 TeX Live）仅在需要「发布版基线」时作为参照；它早于 #1002 的修复，
  因此不能用来判断 #1002 语义是否回退。

## #1026 修复前后

- `issue1026-mwe.tex`：Issue 报告的最小复现。`paperwidth=10cm`，正文右边距在
  200dpi 渲染下对应 681px。
- `issue1026-before.png` / `issue1026-after.png`：分别用 base 与 PR #1035 编译的
  首页渲染（200dpi）。
- `issue1026-before-after.png`：上下对照图，红线标出正文右边距。

实测数值：

| | overfull | 各行右端（px） |
|---|---|---|
| base `c39b1fce` | 18.91pt、3.91pt | 722 / 671 / 680 / 671 / 671 / 203 |
| PR #1035 | 4.47pt | 681 / 671 / 668 / 671 / 671 / 203 |
| v3.10.3 发布版 | 4.47pt | 681 / 671 / 668 / 671 / 671 / 203 |

修复后与发布版逐像素一致。

## #1002 无回归

- `issue1002-base-c39b1fce.txt` / `issue1002-pr1035.txt`：用 `issues/1002/issue1002-mwe.tex`
  这一数值 oracle 在两个版本上编译所得的 24 行结果。两份文件**逐字节相同**，
  说明 #1002 建立的边界间距契约未被改动。
- `issue1002-no-regression.png`：上半为 `issues/1002/issue1002-visual.tex` 的渲染，
  下半为 `issues/1002/inline-math-showcase.tex` 第 13 页（`\CJKunderline{$x$}`，
  正是本 PR 改动的代码路径）。

像素级比对结论（原始像素 SHA-256）：

- `issue1002-visual.tex`：base 与 PR #1035 渲染**逐像素相同**。
- `inline-math-showcase.tex`：全部 17 页**逐像素相同**，含
  `\CJKunderline{$x$}`、`\CJKunderdot{$x$}`、`\CJKsout{$x$}`、
  `\hyperref[...]{$x$}`、`\href{...}{$x$}` 各页。

复现方式（`<tree>` 为对应版本 `l3build unpack` 得到的 `build/unpacked`）：

```sh
TEXINPUTS="<tree>:" xelatex issue1026-mwe.tex
TEXINPUTS="<tree>:" xelatex ../1002/issue1002-mwe.tex   # 取日志中 ^MATH 各行
TEXINPUTS="<tree>:" xelatex ../1002/inline-math-showcase.tex
```

`inline-math-showcase.tex` 需要 `issues/992/showcase-lib.tex`，编译时的相对路径
应保持 `issues/1002/` 为工作目录。
