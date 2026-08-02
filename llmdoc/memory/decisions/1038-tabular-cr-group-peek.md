# 决策：CJK→Boundary 的花括号分支只吸收一枚左花括号（#1038）

## 背景

`c8923052`（#1002 的行内公式边界修复）在 `\xeCJK_CJK_and_Boundary:w` 里新增 group-begin 分支，用于修复 `中{$x$}` 这类「显式花括号包住行内公式」时丢失 `\CJKecglue` 的问题。该分支调用的 `\@@_boundary_group_math:w` 用 `n` 型参数吞掉整个花括号组，判断组内首记号是否 `$`，然后用隐式的 `\c_group_begin_token #1 \c_group_end_token` 重新发出。

这在 `tabular` 里出错：

```latex
\begin{tabular}{l}
  中文\\
\end{tabular}
```

报 `! Improper alphabetic constant.`，指向 `\c_group_end_token`（#1038）。

## 根因

两件事叠加。

**一、XeTeX 判断字符类时会展开宏，`\protected` 挡不住。** 纯 XeTeX 实测（不加载 LaTeX 与 expl3）：

| 输入 | 触发的类别转换 | 前瞻看到的记号 |
|---|---|---|
| `X{q}` | 1→4095 Boundary | `begin-group character {` |
| `X\PBRACE`（`\protected\def\PBRACE{{q}}`） | 1→4095 Boundary | `begin-group character {` |
| `X\PLET`（`\protected\def\PLET{aq}`） | **1→0 Default** | `the letter a` |
| `X\relax` | 1→4095 Boundary | `\relax` |

第三行证明 `\protected` 无效：要判定下一个字符是 `a`，XeTeX 必须先展开 `\PLET`。`\protected` 只对 `\edef`／`\write` 一类完全展开语境有效，对「不断展开直到取得不可展开记号」的类别前瞻无效。

**二、被吞掉的是 LaTeX 平衡花括号技巧的一半。** `tabular` 里 `\\` 已 `\let` 为 `\@tabularcr`，替换文本为 `{\ifnum0=`}\fi\@ifstar\@xtabularcr\@xtabularcr`（`latex.ltx:16825`）。XeTeX 展开它、看到首个显式 `{`、归为 Boundary 类，于是注入 `\xeCJK_CJK_and_Boundary:w`；group-begin 分支随即把 `{\ifnum0=`}` 整个吞掉（实测 `#1` = `\ifnum 0=`）。重新发出时用的是隐式 group-end 控制序列，而反引号常量语法要求紧跟**显式**字符记号 `}`，故报错。

## 决定

`\@@_boundary_group_math:w` 改为只吸收触发转换的那一枚左花括号：

```latex
\cs_new_protected:Npn \@@_boundary_group_math:w
  {
    \tex_afterassignment:D \@@_boundary_group_math_peek:
    \tex_let:D \@@_boundary_group_math_brace:
  }
\cs_new_eq:NN \@@_boundary_group_math_brace: \scan_stop:
\cs_new_protected:Npn \@@_boundary_group_math_peek:
  { \peek_after:Nw \@@_boundary_group_math_branches: }
\cs_new_protected:Npn \@@_boundary_group_math_branches:
  {
    \token_if_math_toggle:NTF \l_peek_token
      { \@@_boundary_CJK_and_math: }
      {
        \bool_if:NTF \l_@@_peek_ignore_spaces_bool
          { \@@_boundary_reserve_space: }
          { \@@_boundary_group_end:n { CJK } }
      }
    \c_group_begin_token
  }
```

`\afterassignment` + `\let` 把左花括号当作赋值的右值吸收——实测 `\currentgrouplevel` 不变，即**不开新分组**；随后 `\peek_after:Nw` 看下一个记号判断是否 `$`；最后补发一枚隐式左花括号恢复分组，由源码里原有的 `}` 正常闭合（实测配对正常）。

除这一枚花括号外输入流原样保留，`` ` `` 与 `}` 的相邻关系因此不被破坏。判别结果：

| 输入 | 花括号后首记号 | 判定 |
|---|---|---|
| `tabular` 里的 `中文\\` | `\ifnum` | 非数学，不加 glue，不报错 |
| `中文{$x$}` | `math shift character $` | 数学，加 glue |
| `中文{x}` | `the letter x` | 非数学 |
| `中文{{$x$}}` | `begin-group character {` | 非数学（与既有语义一致）|
| `中文{}` | `end-group character }` | 非数学 |

## 为什么不能删掉这条分支

实测把两个分支退回 `c8923052` 之前的形状后，**恰好两项**失败：

- `command-boundary-math01`（`.lvt:160`，`\MathBoundaryCommandMatrix{group}{{$x$}}`）：32 条 `group/CMC`、`group/CMW` 的 00/10/01/11 变体报 boundary delta 3.33pt／5.0pt；其余走 `\@@_boundary_identity:n` 或 box 适配器的用例仍通过。
- `command-boundary-math02`（`.lvt:70`，`\setbox0=\hbox{中 {$x$} 文}`）：期望的 `\glue 5.0` 变成两枚互相抵消的 kern，盒宽由 35.71527pt 降到 30.71527pt。

即该分支专门服务「CJK 后紧跟显式花括号、组内首记号是 `$`」这一情形，必须收窄而非删除。

## 为什么不改成「重发显式花括号字符」

另一条思路是保留抓参数，但用 catcode 技巧造出真正 catcode 1/2 的字符记号来重发，这样反引号就能读到显式 `}`。不采纳：它仍会提前吞掉 `\ifnum0=` 之后的内容并改变 `\@ifstar` 的前瞻时序，风险面比「只吸收一枚记号」大得多，且没有对应的验证手段能穷举被改变的时序。

## 触发面

逐个隔离实测（每种写法单独一个文件——同一文件内前一个用例报错会中止编译，使后面的假绿）：

- **受影响并已修复**：`tabular`、`tabular` 带可选参数（`\\[2pt]`）、`tabular` 中 `&` 之后。
- **从未受影响**：`array`、`align`、`pmatrix`、`tabularx`、`array` 宏包的 `>{...}` 列型、`\halign`、`center`、`minipage`。

数学与 `\halign` 路径直接用 `\cr`，不经过 `{\ifnum0=`}\fi` 这个平衡技巧，因此不触发。

## 测试

`xeCJK/testfiles/tabular01.lvt` 新增 TEST 3（`中文\\`）与 TEST 4（`&` 之后、`\\[2pt]`、末行）。

该文件早已存在且正是测 `tabular` 里的 CJK，却对本缺陷**零判别力**：原有四行每行 `\\` 前都有一个源码空格，走 CJK→NormalSpace 路径，不进 `\@@_boundary_group_math:w`；实测缺陷版下 `tabular01` 全绿。注释中写明了这一点。

判别力已实测 rc 1：还原抓参数形式后 TEST 3／4 各报 `Improper alphabetic constant`，TEST 1／2 零命中。

## 验证

- xeCJK 116／116、ctex 四引擎 185／185、`l3build doc`、CHANGELOG 新鲜度门禁。
- `中 {$x$} 文` 与 `中{$x$}文` 的节点列表和盒宽在修复前后逐项相同，且与 oracle（`中 $x$ 文`、`中$x$文`）一致——即 #1002 的行为未受影响。

## 相关资料

- 反思：[[../reflections/1038-tabular-cr-group-peek]]
- 引入来源：[[1002-inline-math-boundary-oracle]]
- 实现：`xeCJK/xeCJK.dtx` 的 `\@@_boundary_group_math:w` 一族
