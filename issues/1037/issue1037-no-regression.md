# #1037 跨 issue 无回归复放

基线取本 PR 的父提交 dcbded8b（不取更早的发布版——那样看到的差异会是 #1026/#1035 自身的改进）。
head = fe740f29。

## #992 命令边界矩阵（四个驱动，共 573 个单元）

| 驱动 | 父提交 PASS/FAIL | head PASS/FAIL |
|---|---|---|
| `command-boundary-core-matrix` | 197/7 | 197/7 |
| `command-boundary-links-matrix` | 92/0 | 92/0 |
| `command-boundary-math-matrix` | 272/0 | 272/0 |
| `command-boundary-verb-matrix` | 12/0 | 12/0 |

core 的 7 项 FAIL 两侧为同一批（`ref/C/CCC` 与 `ref/C/WCW` 的 00/01/10/11 组合），
属既有失败，非本 PR 引入。逐项 diff 为空。

## #1026 资产 MWE

| 版本 | Overfull |
|---|---|
| 父提交 dcbded8b | 4.47pt |
| head fe740f29 | 无溢出 |

`core` 的 FAIL 集合在两侧逐项相同（`diff` 为空）。

## 守卫用例（issue1037-guard-mwe.tex）

这两个用例在最终实现下必须零错误。它们检验的不是排版结果，而是修复本身不会在
不相关的文档里引入编译错误。

| 版本 | 错误数 |
|---|---|
| 父提交 dcbded8b | 0 |
| 第一版修复 b3eedae2（守卫不足） | 8 |
| head fe740f29 | 0 |

第一版修复的首个错误是 `Too many }'s`，栈顶为 `\UL@stop ... \egroup \egroup`。

## 收缩量按盒深度统计（#1026 资产 MWE 的段落）

`depth>=3` 表示被固化在 ulem 定宽片段盒内、行断行取不到；`depth2` 表示在行上可用。

| 版本 | 盒内 | 行上可用 |
|---|---|---|
| #1026 缺陷版 `c39b1fce` | 16 | 0 |
| 发布版 v3.10.3 | 8 | 6 |
| 父提交 dcbded8b（含 #1035） | 8 | 6 |
| head fe740f29 | 0 | 14 |

父提交与发布版逐位相同，且渲染 PNG 逐像素一致（`ImageChops.difference` 的 bbox 为
`None`）——即 #1035 没有引入新问题，它修回的发布版行为本身就带这条缺陷。
