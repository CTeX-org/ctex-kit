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
