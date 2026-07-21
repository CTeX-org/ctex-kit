# Issue #1002 资产

数学公式维度未进入 #992 命令边界矩阵：裸行内公式（`$x$`、`\(x\)`、
`\ensuremath{x}`）没有对应的「行」，既有命令 × math 内容（`\texttt{$x$}`
等）没有对应的「列」；且「命令包裹 math 的契约 oracle 用裸公式直接输入
还是 Default 字母」悬而未决——两个候选 oracle 给出互相翻转的结论。

- `issue1002-mwe.tex` — 完整探针矩阵（16 组 × 00/10/01/11，双 oracle
  契约 + `xCJKecglue` 依赖验证），`grep '^MATH|' *.log` 取逐格数值。
- `issue1002-visual.tex` / `issue1002-visual.png` — 可区分 glue 下的
  代表性可视场景（裸 `$x$`、`\(x\)` 左侧空格收窄；`{$x$}`、
  `\fbox{$x$}` 的 `00` 缺口）。

实测基线：裸公式行为在 master `cb6b2f73` 与 PR #1001 分支 `53fc6575`
上一致（预存行为）；命令 × math 列的数值取自 PR #1001 分支（其中
`\mbox{$x$}` 行反映 #998 修复后状态）。机制归因与完整表格见 issue 正文。
