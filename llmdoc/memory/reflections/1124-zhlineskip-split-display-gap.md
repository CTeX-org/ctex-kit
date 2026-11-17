---
title: "1124：显示公式上方的间距"
type: reflection
---

# 1124：显示公式上方的间距

## 问题

`ctexart` + `zhlineskip` 下，`equation` 里放 `split` 时上方的间距明显窄于单行公式。
报告者给的像素比：单行 65/54、多行 31/42（上/下），最大最小比 210%。报告者后来补充：
「不只是 `split`，`aligned` 也一样，我用 `split` 只是个人习惯」——这是对的，机制在
公式盒的高度上，与具体环境无关。

## 根因（实测）

公式周围的可见间距 = display skip + TeX 自己插入的行间 glue，后者等于
`\baselineskip − 上一行深度 − 公式盒高度`，一旦小于 `\lineskiplimit` 就退回固定的
`\lineskip`。用 `\showbox` 读垂直列表（pdfTeX 2026，本机，报告者 MWE 形状）：

| 配置 | 单行 上/下 | `split` 上/下 |
|---|---|---|
| `ctexart` | 10+7.48 / 10+5.38 | 10+`\lineskip` 4.0 / 10+1.0 |
| `ctexart`+`zhlineskip` | 10+6.85 / 10+4.74 | 10+`\lineskip` **1.0** / 10+1.0 |

- 通用部分：TeX 的双重间距机制本身让高公式退回固定 `\lineskip`，`ctex` 的
  1.5 倍行距只是把这个差异放大（报告者表里「只用 ctex」也有 156%）。
- 本包特有的 3pt：`\spread@equation` 里的 `\openup\jot` 被 #735 的修复搬进了
  `\vcenter` 组，外层 `\lineskip` 因此停在 1pt（把选项换成
  `restoremathleading=false` 实测回到 4.0）。

## 走过的死路（都实测无效，不要再试）

1. `\everydisplay` 里 `\prevdepth=-1000pt`：glue 值完全不变。TeX 在 display 收尾时
   自己重设 `\prevdepth`。
2. `\aftergroup` 里设 `\prevdepth`：同样无效；而且实测 `\aftergroup` 代码运行时
   `\prevdepth`/`\lastskip` 都是 0，说明它在公式盒落盘之前就执行了。
3. `env/equation/before|after` hook 里设 `\prevdepth`：hook 自带分组，赋值被丢弃。
4. `\everydisplay` 里设 `\lineskip`：能改到外层 glue（`split` 上方确实变宽），但
   `\vcenter` 内部的行间 glue也继承了它，`split` 的盒子高度从 15.96pt 涨到 18.89pt。
5. `\dollardollar@end`（所有 display 的收尾点）里设 `\lineskip`：只对 `split`
   有效，对 `equation`/`aligned`/`pmatrix`/`frac` 无效——那些 display 的分组比
   `split`（`\gather@split` 开头 `\endxp\endgroup` 提前收组）深一层，赋值在落盘前
   就被弹出。
6. 给 `\belowdisplayskip` 加固定补偿（目标：多行公式下方也等于单行公式）：在默认
   行距下能把下方间距补到与单行公式一致，但公式不高时会多补——1 行 `split` 在
   1.5 倍行距下多 4.1pt，2.0 倍行距下多约 10pt。固定补偿量的错误方向随行距与公式
   高度翻转，因此没有采用。

## 落地的做法

只改上侧，在 `\gather@split` 的外层组里：

```latex
\dim_set_eq:NN \l_@@_savedlineskip_dim \tex_lineskip:D
\dim_set_eq:NN \tex_lineskip:D \g_@@_displaygapabove_dim
\vcenter\bgroup
\dim_set_eq:NN \tex_lineskip:D \l_@@_savedlineskip_dim   % 组内复原，行间 glue不受影响
\linespread{...}\selectfont \spread@equation
```

标定值是 `\baselineskip − 0.1 quad − \ht(参考公式盒)`，参考公式盒取
`$\displaystyle (x)=y$`（高 7.90pt，与报告者的公式盒一致；最初用 `x=y` 只有
4.54pt，标定结果偏大 3.4pt），`0.1 quad` 是中文正文行的典型深度
（fandol/10.539pt 实测 1.05pt）。

第一版把标定放在 `begindocument/end` 只算一次，code review 指出脚注、表格等处的
字号与行距不同，一次性标定在那些地方会失准（实测 `\footnotesize` 里单行公式上方
是 5.875pt，而 `split` 仍用正文字号的 6.5pt）。现在每次 `\@@_setdisplaygap:` 按当时
的 `\baselineskip` 与当前字体的 quad 现算，代价是每个 `split` 多排一个 hbox。
改成现算时踩了一个坑：`\dim_eval:n { 0.1 \f@size pt }` 会把 `\f@size` 的数字接到
`0.1` 后面变成 `0.110pt`（TeX 先发 Illegal unit of measure 再把后面的项吃掉，读数
是 0），正确写法是 `0.1 \tex_fontdimen:D 6 \tex_font:D`（factor 乘内部 dimen）或者
显式加 `*`。

效果（默认行距，pdfTeX）：单行 16.85/14.74、`split` 上方 16.85/11.0。

## 扩展到所有显示公式（第二版）

第一版只改 `\gather@split`，因为那是 zhlineskip 原本就打的补丁点。报告者追问 `aligned`
之后重新找挂点，实测两条关键事实：

1. **`\everydisplay` 里的赋值才活得到公式盒落盘那一刻**；`\dollardollar@end` 里改
   `\lineskip` 只对 `split` 有效（`split` 的 `\@xp\endgroup` 让落盘点浅一层），
   对 `equation`／`aligned`／`pmatrix` 全无效果。
2. 只设 `\lineskip` 不够：比参考公式高、但自然 glue仍为正的公式（例如裸 `$$` 里放
   `\dfrac`，自然 glue `0.306pt`）走的是 `\baselineskip` 那条路径，间距照旧偏紧。所以
   必须把 `\lineskiplimit` 也抬到同一个值，做成真正的下限。

于是把标定与赋值挪进 `\everydisplay`，覆盖 `aligned`、`pmatrix`、`\[...\]`、裸
`$$...$$`；赋值随显示组消失，不外泄。

两个必须配套的例外：

- **公式内部**：`aligned`／`matrix`／`cases`／`gathered`／`array` 等内层容器的行距也
  由 `\lineskip` 决定，实测不还原时 `aligned` 的盒高从 `17.46+12.19` 涨到
  `20.21+14.94`（行间 glue `4.0`→`9.5`）。所以 `\RestoreMathEnvironmentLeading` 的 hook
  里同时复原 `\lineskip` 与 `\lineskiplimit`，`split` 的 vcenter 组同样复原。
- **逐行落盘的显示环境**：`eqnarray`、`align`、`gather`、`multline` 的行间 glue 也读
  `\lineskip`，抬下限会把行距一起改掉（两行 `align` 的行间 glue 会从 `3.0pt` 抬到
  下限）。判断方式试了四次，第 4 条才是最终做法：
  1. `env/.../before|after` 钩子里的**全局**布尔能用，但用户用 `\newenvironment`
     包一层时钩子不执行（实测包装后的 `gather` 两行减一行从 `24.57pt` 涨到
     `30.07pt`）。
  2. 把标记改到 `\start@gather`／`\start@align`／`\start@multline`／`\eqnarray`
     这些真正启动环境的代码路径上：**不行**。实测 `\everydisplay` 有的在它之前、
     有的在它之后触发（`gather` 的测量趟与真实趟夹着 `\endgather`），标记在落盘
     那一刻总是 0。用全局计数器也一样。
  3. 试过 `\everydisplay` 里读 `\@currenvir` 再比对名单：能用（`\clist_if_in`
     对它 catcode 敏感，改用 `\str_if_eq` 逐个比），但名单要覆盖用户给包装环境起
     的名字，等于把责任推给用户登记。
  4. 最终做法（code review 给出的）：把标记放在环境启动宏的**最开头**，
     `\pretocmd \start@gather {\bool_set_true:N \l_..._bool}{}{}`，对
     `\start@align`／`\start@multline`／`\eqnarray` 同样处理，`\everydisplay`
     检查这个局部布尔。关键在于 `\start@gather` 里的 `\dollardollar@begin` 在
     `\collect@body` 之前就跑，`\everydisplay` 也在那里触发；标记插在
     `\collect@body` 前后都来不及被读到（这正是第 2 条失败的原因）。宏开头时环境
     组还在栈上，局部布尔就够，包装环境也照样走到，无需登记：实测未登记的
     `mygather` 两行减一行 `30.06897pt` → `24.56903pt`（与 base 相同）。
  `eqnarray` 是 code review 补的：漏掉它时两行减一行的盒高实测 `18.0pt` →
  `19.5pt`。
- **没有钩子的结构**：plain `\TeX` 的 `\displaylines`、`\eqalignno`（`$$\halign`
  显示对齐）与公式里手写的 `\vbox` 挂不上任何钩子，行距仍会被下限影响（实测
  `\displaylines` 两行减一行 `23.87pt` → `29.37pt`）。手册里写成已知差异，不再声称
  「公式内部的行距保持原样」。

复原函数的守卫是另一个必踩的坑：一开始把原值存成**全局**变量，结果
`env/aligned/begin` 之类的钩子在**行内公式**里也会跑。第一个显示公式之前全局值还是
`\dim_new:N` 的 `0pt`；出现过显示公式之后，行内环境拿到的其实是上一个显示公式
保存的值。code review 用它自己的构造量到行内 `aligned` 盒高 `22.43pt` → `21.93pt`；
本仓库的复现用例（`article` 10pt、两行 `\dfrac`，见 `display-gap.lvt` TEST 7）在
修前是 `24.56903pt`、修后 `25.06903pt`，与 base 一致。改成显示组内的局部变量 +
局部布尔守卫（不在显示公式里就什么都不做）后两个测量点相等。

`\changes` 里不能写 `$$` 或 `\[...\]`：`scripts/extract-changes.py` 会把 `$...$` 当
数学处理，`$$` 出来是 `$0$`；ctxdoc 的改动列表里 `\[` 会当行间公式开始，报
`\@newline was complete` 一类的错。

## 下方：实测走不通的四条路

- `\belowdisplayskip` 想在公式之后补：**太晚**。实测在 `$$` 之后 `\advance\belowdisplayskip`
  确实改了寄存器，但列表里插入的仍是旧值——跳过是在公式结束时就落盘的。
- `\prevdepth` 想抑制下一行的行间 glue：**水平模式里不许赋值**（`$$` 之后接着排正文时
  就是水平模式，TeX 直接报 `You can't use \prevdepth in horizontal mode`）。ctex
  #1100 能用这招，是因为标题后是竖直模式。
- 固定补偿：矮公式会补多（默认行距下一行 `split` 多 4.1pt，2.0 倍行距下约 10pt）。
- 幻影深度 + 负 skip：幻影深度会把可见间距变成 `δ − d`，`d` 仍然未知，换汤不换药。

结论：下侧维持 TeX 的规则，手册记作已知差异。

## 各环境现在的实测值（默认行距，pdfTeX）

单行 `equation` 16.85／14.74；`split`、`aligned`、`pmatrix`、`\[...\]`、裸 `$$` 的
上方都等于 16.85（下方仍是 11 左右，见上一节）；`gather`／`align`／`multline` 保持
5.74／3.58 不动；`aligned` 的盒高 `17.46+12.19` 与内层行间 glue `4.0` 都不变。

## 教训

- 「可见间距」与「基线距离」是两件事：TeX 保证后者，前者随公式盒高深变化。整盒
  高深看起来不变（改动前后 `split-leading` 的总高完全一样）正说明它测不到间距。
- 回归用例必须让机制真的发生：本例要求默认 1.5 倍行距且公式够高，否则改动按设计
  不生效而测试照样绿。判别力要用「把改动换成 `\relax`」验证，实测只有新加的
  `display-gap.lvt` 会红。
- 标定用的参考盒子必须与被测对象同形：`x=y` 与 `(x)=y` 的高度差 3.4pt 直接变成
  补偿量的系统误差。
