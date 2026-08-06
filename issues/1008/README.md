# Issue #1008 资产

带选项的 `\zhnum[opts]{counter}` / `\zhdig[opts]{counter}` 把计数器**名**而不是当时的
计数器**值**写进 `.toc` 一类辅助文件。该文件在下一次编译的 `\tableofcontents` 处读回
时计数器已归零，于是目录编号与正文不符。

报告者想做的是「按层级混搭中文数字样式」——`\section` 用 `Normal`、`\subsection` 用
`Financial`。手册当时只写「带了选项的命令是不可展开的，在某些场合使用时要小心」，据此
容易以为这是设计限制；实际上「不可展开」与「不能写进辅助文件」是两件不同的事。

修法：在 `\zhnum` / `\zhdig` 这一层先把计数器展开成数值，再交给处理**数值**的
`\zhnumberwithoptions` / `\zhdigitswithoptions`。写进辅助文件的从
`\zhnumwithoptions{style=Normal}{section}` 变成
`\zhnumberwithoptions{style=Normal}{1}`——数值已固定，样式留待读回时套用。

**没有改成完全可展开，这是有意取舍**：样式靠 `\tl_set_eq:NN` 一类赋值实现，赋值无法在
`\edef` 的展开中生效，硬做只会把「不可展开」换成「静默用错样式」。

排查中另发现一个独立笔误：`\zhdigwithoptions` 把选项当额外参数传给
`\zhnum_digits_counter:n`（多写了一个 `#1`），于是带选项的 `\zhdig` **此前完全不可用**。

## 文件

- `issue1008-mwe.tex` — 复现 MWE（编译两遍后比对目录与正文），含成因注释。
- `issue1008-toc-compact.tex` — 上面那张对照图用的紧凑版（目录与正文同页可见）。
- `issue1008-zhdig.tex` — 下面那张 `\zhdig` 对照图用的源文件。
- `issue1008-toc-before-after.png` — 根因一的修复前后对照：左侧目录「零 / 零.零」而
  正文「一 / 一.壹」；右侧两者一致。
- `issue1008-zhdig-before-after.png` — 根因二的修复前后对照：左侧报
  `Use of \??? doesn't match its definition` 并把 `tyle=Fin…` 印到页面上；右侧正确
  排出「壹贰叁」。
- `issue1008-toc-before.txt` / `issue1008-toc-after.txt` — 两侧 `.toc` 的实际内容，
  即判据本身（计数器名 vs 固定下来的数值）。

## 实测记录

对照用的「修复前」是系统安装的 zhnumber（`\ProvidesExplPackage` 报 3.0），「修复后」是
本 PR 分支的 `zhnumber.dtx` 现场 unpack 的 `zhnumber.sty`；两侧同一份 `.tex`、同一引擎
（XeTeX，TeX Live 2026），各编译两遍。

`\zhdig` 那组：修复前日志 1 处 `!` 报错，修复后 0 处。
