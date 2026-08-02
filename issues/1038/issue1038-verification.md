# #1038 修复前后与触发面实测

基线取本 PR 的父提交 655b3d5e（即 master）。head = 本 PR。

## 报告者的 MWE

| 版本 | 错误数 | 首个错误 |
|---|---|---|
| 父提交 655b3d5e | 3 | ! Improper alphabetic constant. |
| 本 PR | 0 | — |

## 触发面（每种写法单独一个文件——同一文件里前一个报错会中止编译，使后面假绿）

| 写法 | 父提交 | 本 PR |
|---|---|---|
| `tabular` + `中文\\` | 3 | 0 |
| `tabular` + `\\[2pt]` | 3 | 0 |
| `tabular` + `甲&乙\\` | 3 | 0 |
| `tabularx` | 0 | 0 |
| `array`（数学模式） | 0 | 0 |
| `align*` | 0 | 0 |
| `\halign` + `\cr` | 0 | 0 |
| `center` + `\\` | 0 | 0 |
| `pmatrix` | 0 | 0 |
| `array` 宏包 `>{...}` 列型 | 0 | 0 |

判据是**替换文本的首记号**，不是「有没有用 `{\ifnum0=`}\fi` 平衡技巧」：

| 换行命令 | 替换文本首记号 | 是否触发 |
|---|---|---|
| `\@tabularcr` | 显式 `{` | 是 |
| `\@arraycr` | `$`（math shift） | 否 |
| `tbl` 层的 `\\`（`tabularx`／加载 `array` 后） | 控制序列 | 否 |
| `\halign` | 无此包装，直接 `\cr` | 否 |

`\@arraycr` 用的正是同一个平衡技巧（`latex.ltx:16818`），所以「有无技巧」不是有效判据。

## XeTeX 的类别判定规则（对照 `xetex.web`）

类别选择发生在 `main_control` 主循环：`get_x_token` 正常完全展开取记号，只有落在
`hmode+letter` / `other_char` / `char_given` / `char_num` 四个分支才按该字符的类别走
`check_for_inter_char_toks`；其余任何 `cur_cmd` 走 `check_for_post_char_toks`，目标被
硬编码为 `char_class_boundary`。

| 后续记号 | 触发的转换 |
|---|---|
| 显式字母 / other 字符 | 该字符自身的类别 |
| `\protected` 宏展开为字母 | 该字母的类别（`\protected` **不**阻断展开）|
| `\let` 得到的隐式字母 | 该字母的类别（判据是 catcode，不是显式/隐式）|
| `\bgroup`（隐式 `{`，catcode 1） | Boundary |
| 显式 `{` / `}` / `$` / `^` / 源码空格 | Boundary |
| `\relax` / `\kern` / `\unskip` / `\hbox` / `\penalty` | Boundary |

Boundary 在新引擎是 4095、旧引擎 255；4096 是「忽略」类别，不是边界类别。

## 附带改善

`中\bgroup $x$\egroup 文` 修复前拿不到 `\CJKecglue`（29.04527pt），修复后与显式花括号
形态及无分组 oracle 一致（32.37527pt）。由 `boundary-bgroup01` 固定。

## #1002 行为未受影响

`中 {$x$} 文` 与 `中{$x$}文` 的节点列表与盒宽在修复前后逐项相同，且与 oracle
（`中 $x$ 文`、`中$x$文`）一致，均为 32.37527pt、两枚 3.33pt glue。

## 回归

xeCJK 117/117、ctex 四引擎 185/185、`l3build doc`（247 页 + 51 页）、CHANGELOG 门禁。
