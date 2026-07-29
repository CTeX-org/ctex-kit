# Issue #1029 资产

`ctexart` + `algorithm2e[ruled]` 下算法标题整段不显示的修复（PR #1036）证据。

两个被比较的版本：

- **base `05baf1e0`**：PR #1036 的父提交，含本 issue 的缺陷。
- **PR #1036**：本次修复。

## 修复前后

- `issue1029-mwe.tex`：Issue 报告的最小复现（缩小页面便于截图，缺陷现象不变）。
- `issue1029-before.png` / `issue1029-after.png`：分别用 base 与 PR 编译的渲染（200dpi）。
- `issue1029-before-after.png`：上下对照图。

`pdftotext` 抽取结果：

| | 首行 |
|---|---|
| base `05baf1e0` | 无标题行，直接是 `Data: an input value x` |
| PR #1036 | `Algorithm 1: Algorithm heading should be visible here` |

缺陷版不报错也不警告，标题只是静默消失。

## 根因的机制复现

- `issue1029-mechanism.tex`：**不加载 xeCJK**，纯 LaTeX 即可触发，证明这是 LaTeX
  命令钩子机制的通用陷阱而非本包特有。
- `issue1029-mechanism-output.txt`：上述文件的实测输出。

```
NO-HOOK=21.8pt            无钩子：\global 正常
HOOK-NO-ASSIGN=21.8pt     钩子内容为 \relax（不含赋值）：\global 仍正常
HOOK-WITH-ASSIGN=0.0pt    钩子内容含赋值：\global 被吃掉，盒子随分组丢失
```

`\global` 在 TeX 里是「等待下一个赋值」的前缀状态。`cmd/sbox/before` 的代码插在
`\setbox` 之前执行，钩子里任何赋值都会把这个待用前缀消耗掉，于是 `\global\sbox`
静默退化为局部赋值。xeCJK 原先挂在该钩子上的 `\@@_boundary_capture_suspend:`
做的正是多个 `\int_gincr:N`／`\tl_gset:`。

`algorithm2e` 的 `\algocf@makecaption@ruled` 用 `\global\sbox\algocf@capbox` 在浮动体
分组内保存标题，分组外再 `\box` 出来——前缀失效后盒子已空。实测紧接 `\global\sbox`
之后盒子正确（308.11221pt），到使用点变 0.0pt。

## 复现方式

`<tree>` 为对应版本 `l3build unpack` 得到的 `build/unpacked`（xeCJK 与 ctex 都要）：

```sh
TEXINPUTS="<tree>:" xelatex issue1029-mwe.tex && pdftotext issue1029-mwe.pdf -
xelatex issue1029-mechanism.tex   # 机制复现不需要任何 TEXINPUTS 设置
```

## 一个容易误判的点

`\global\savebox` 跨分组本来就不生效，**与本包无关**：`\savebox` 是 robust 命令，
`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，前缀根本到不了内部入口。
未加载本包的原版 LaTeX 中三种形式（无可选参数、`[wd]`、`[wd][pos]`）一律 `0.0pt`。
本次修复解决的是 `\global\sbox`；需要全局保存盒子时应使用 `\global\sbox` 或
`\global\setbox`。

## #992 的 sbox 场景无回归（隔离语义）

`cmd/sbox/before`／`after` 这两个钩子是 #992 为隔离 `\sbox` 离线测量盒子而引入的：
`\sbox` 里的内容不得影响外层可见间距。#1029 把钩子换成专用适配器，必须保持同样效果，
因此按 #992 的矩阵格式（候选 vs 去掉包装的 oracle、扣除固有宽度差、`00/10/01/11`
四种源码空格、`xCJKecglue=false/true` × 默认／可区分间距）补了一份 sbox 专项矩阵。

- `command-boundary-sbox-matrix.tex`：矩阵驱动，6 个场景 × 4 种源码空格 = 每配置 24 单元，
  四种配置合计 96。场景覆盖 scratch box 藏 CJK／藏西文两个方向，以及嵌在 `\fbox` 内
  （`algorithm2e` 的实际形状：外层盒子命令内部再做离线测量）。
- `issue992-sbox-matrix-results.txt`：三个版本的完整结果。
- `issue992-sbox-showcase.tex` 与 `issue992-sbox-no-regression.png`：可视对照。

| 版本 | 矩阵结果 | showcase delta |
|---|---|---|
| base `05baf1e0`（原钩子） | **96／96** | 0.0pt |
| PR #1036（专用适配器） | **96／96** | 0.0pt |
| 对照组：删掉 `suspend`／`resume` | 72／96（24 项失败） | −4.0pt |

前两行相同即为无回归；第三行是**判别力对照**——若不加对照组，全绿的矩阵无法说明
它究竟能不能发现隔离失效。失败集中在 `scratch-in-fbox` 与 `scratch-hidden-CJK`，
delta 为 3.33pt（默认胶）或 4.0pt（`CJKecglue=5pt`），方向是外层西文两侧被误插
CJKecglue。

仓库内对应的固化门禁是 `command-boundary01` 的 `scratch-hidden-CJK` 单元，以及
#1029 新增的 `boundary-sbox-global01` 第 6 项。

复现：

```sh
for cfg in false-default false-custom true-default true-custom; do
  TEXINPUTS="<tree>:" xelatex -jobname=m-$cfg command-boundary-sbox-matrix.tex
done
grep -c '|PASS|' m-*.log
```
