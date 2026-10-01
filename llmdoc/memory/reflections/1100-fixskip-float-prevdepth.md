---
name: 1100-fixskip-float-prevdepth
description: 记录 #1100 修复 ctex `fixskip=true` 时紧跟标题、就地放置的 [h] 浮动体与后文的距离少一段行间胶；第一版只凭“全局标记 + @nobreak + \prevdepth=-1000pt”判断，被对抗式审查推翻（-1000pt 是 TeX 共用的哨兵值，\hrule、\nointerlineskip 也会留下；titlesec 接管的标题不清标记；runin 标题会清 @nobreak）；教训是判断“这个值是不是我留下的”要列出能产生同一值的全部来源，并考虑不经过 ctex 代码的外部标题；测试方面，参照用例不能放进分组，切换 fixskip 的用例要逐个重设，每个判断条件都要逐项变异
metadata:
  type: feedback
---

# 反思：#1100 fixskip 时紧跟标题的就地浮动体与后文间距变小

## Task

现象：`fixskip=true` 时，紧跟标题、就地放置的 `[h]` 浮动体，其题注与后文的距离比
`fixskip=false` 少约一段行间胶（XeLaTeX `ctexart` 实测 21.78pt 对 27.77pt；
`caption` 宏包加 `belowskip=-12pt` 时为 12.87pt 对 18.86pt）。

根因：`\CTEX@fixheadingskip` 在标题后把 `\prevdepth` 设为 -1000pt。LaTeX 的
`\end@float` 在竖直模式下保存并恢复 `\prevdepth`
（`\@tempdima\prevdepth \vbox{} \prevdepth\@tempdima`）；就地放置时，输出例程也不改主竖直
列表的 `\prevdepth`。于是 -1000pt 一直保留到浮动体之后的第一行，那一行前面的行间胶被取消。

最终修法（`1ab213e4`，注释修订 `69da27e2`，分支 `fix-1100-fixskip-float`）：

- `\CTEX@fixheadingskip` 记下当前 `\prevdepth`、当时 `\@afterheading` 的执行次数，并置全局标记；
  `\CTEX@setheadingskip` 清除标记。
- 导言区结束时用 ctexpatch 加三个钩子：
  - `\@afterheading` 开头：计数加一。
  - `\@xfloat` 开头：检查是否同时满足外部竖直模式、`\prevdepth`=-1000pt、`\lastnodetype`≠3
    （最后一个节点不是标尺），并且满足“`@nobreak` 为真且次数差为 1”或“`@noskipsec` 为真且
    次数差小于 2”之一。
  - `\end@float` 末尾：`\@currbox` 已被 `\@addtocurcol` 用 `\box` 取空（即就地放置）时，恢复记下的
    `\prevdepth`。
- 回归测试为 `ctex/test/testfiles/heading-fixskip02.lvt`、`heading-fixskip03.lvt`。

## Expected vs Actual

- 预期：找到 -1000pt 一直保留的原因后，在浮动体之后恢复深度，一次修好。
- 实际：第一版（`5c35e236`）只用“全局标记 + `@nobreak` + `\prevdepth`=-1000pt”判断，
  对抗式审查给出了三类反例，其中 `ctexbook` + `titlesec` 相对 v2.6.5 回退。第二版改用
  `\@afterheading` 次数差与最后节点类型，并补上 runin 标题。仍有两种写法无法区分，登记为已知限制。

## What Went Wrong

### 1. 把共用的哨兵值当成自己留下的标记

-1000pt 是 TeX 内部 `ignore_depth` 的值，不是 ctex 专用的值。`\hrule`（含 `titlesec` 的
`\titlerule`）和 `\nointerlineskip` 也会把 `\prevdepth` 设为 -1000pt，而且不清 `@nobreak`。
第一版看到 -1000pt 就恢复，会把这些用户有意设下的深度改回去。

另外，`titlesec` 接管的标题不经过 `\CTEX@setheadingskip`，全局标记不会被清除，于是标记一直
保留到后面某个 -1000pt 处才生效，造成 `ctexbook` + `titlesec` 的回退。

改用 ctex 独有的哨兵值不可行：LaTeX 的 `\addpenalty` 等代码直接比较 `\prevdepth = -1000pt`，
换值会改变这些代码的行为。所以只能靠旁证（`\@afterheading` 次数差、最后节点类型）认出
“这个 -1000pt 是 ctex 刚留下的”。

### 2. 漏掉 runin 标题

runin 标题执行 `\@nobreakfalse`，第一版的 `@nobreak` 条件对它永远不成立。是审查发现的，
第二版增加 `\if@noskipsec` 分支。

### 3. 测试本身有两处没测到

- 参照用例放在分组里：标题设置的 `\everypar` 随分组结束丢失，`\if@nobreak`／`\if@noskipsec`
  是全局的，残留下来，污染后续用例。改为不加分组。
- 用 `\ctexset` 多次切换 `fixskip`：参照用例设为 `false` 后，后面的用例没有重新设回 `true`。
  这个疏忽让“去掉次数判断”这一变异起初没有被检出，逐项变异时才发现。

### 4. 临时测试加载了系统旧版 ctex

Bash 工具调用之间 `export` 的 `TEXINPUTS` 不会保留，有一次探针静默加载了系统 TeX Live 的旧
ctex，读数是修复前的值。这条教训在 `build-and-test.md`（“手写 MWE 前先确认 `TEXINPUTS`……”）
和 #1026 反思中已有记载，本次是重犯，具体形式是“环境变量不跨工具调用”。

## Root Cause

- 设计第一版判据时，只问了“ctex 自己什么时候会留下 -1000pt”，没有反过来问“还有谁会留下
  -1000pt”“哪些标题不经过 ctex 的代码”。对共用的值，必须先枚举全部来源，再找能区分来源的旁证。
- runin 与 `titlesec` 两类标题路径不在第一版的测试矩阵里，测试只覆盖了 ctex 自带的普通
  标题。
- 测试用例之间共享全局状态（`\if@nobreak`、`\if@noskipsec`、`\ctexset` 设下的键值），
  用例的结果依赖前一个用例的残留，变异实验才暴露这一点。

## 有效做法

- 用 `\OMIT`／`\TIMO` 包住排版，在 `\TIMO` 之后统一输出测量结果，使 `.tlg` 不含随引擎变化的
  分页输出和字体信息，一份 `.tlg` 通过四个引擎。
- ctexpatch 对带参数的宏用 `\scantokens` 按 `@` 为字母重建，钩子名要用 `\CTEX@...@hook` 形式，
  不能含 `_` 和 `:`；无参数的宏走 `\edef` 分支，不受此限制。
- 每个判断条件单独做一次变异，确认它只让对应的用例失败（与 `lessons-learned.md` 中“变异要
  逐项做”一条相符）。
- 临时测试在同一条命令里 `export TEXINPUTS` 并运行，再 `grep` 日志里实际加载的 `.def` 路径。

## 已知限制

标题后直接写 `\nointerlineskip`，或 `\hrule` 后接 `\vspace` 再接 `[h]` 浮动体时，判据无法区分，
仍会恢复深度。`\vspace` 之后最后节点不再是标尺，`\lastnodetype` 判据失效。

## Missing Docs or Signals

- `ctex-architecture.md` 只在键表里列出 `fixskip`，没有说明它把 `\prevdepth` 设为 -1000pt，
  也没有说明这个值会穿过 `\end@float` 保留下来。
- 没有任何文档提醒：-1000pt 是 TeX 与 LaTeX 共用的哨兵值，不能拿来当 ctex 的私有标记，
  也不能换成别的值。
- `build-and-test.md` 的测试约束里没有“参照用例不加分组”“切换选项的用例逐个重设”这两条。
- ctexpatch 一节只写“字符串化 → 替换 → rescan”，没有写带参数宏的钩子名限制。

## Promotion Candidates

- `reference/build-and-test.md`（测试写法）：
  - `\OMIT`／`\TIMO` 包住排版、在 `\TIMO` 后统一输出测量结果，可使一份 `.tlg` 通过四个引擎；
    以 `heading-fixskip02/03` 为例。
  - 参照用例不要放进分组：分组会丢掉局部的 `\everypar`，而全局开关残留，污染后续用例。
  - 多个用例用 `\ctexset` 切换同一选项时，每个用例开头都显式设定，不依赖前一个用例的值。
- `architecture/ctex-architecture.md`：
  - 标题一节补 `fixskip` 的机制：`\CTEX@fixheadingskip` 设 -1000pt，浮动体相关的三个钩子
    （`\@afterheading` 计数、`\@xfloat` 检查、`\end@float` 恢复）及判据。
  - ctexpatch 一节补：带参数的宏经 `\scantokens` 按 `@` 为字母重建，钩子名用 `\CTEX@...@hook`，
    不能含 `_`／`:`；无参数的宏走 `\edef`。
- `memory/doc-gaps.md`：登记上面“已知限制”中的两种写法。
- `memory/lessons-learned.md`（跨任务规则，可考虑新增）：判断某个状态值是不是自己留下的，
  先枚举所有能产生同一值的来源（含不经过本包代码的外部宏包路径），再找能区分来源的旁证；
  共用的哨兵值不能换成私有值时尤其如此。
- 不需提升：`TEXINPUTS` 加载路径一条已在 `build-and-test.md` 和 lessons-learned 中有记载，
  本次只是重犯，留在本反思即可；逐项变异一条也已有记载。

## Follow-up

- 由 recorder 按上面的候选更新 `build-and-test.md`、`ctex-architecture.md`、`doc-gaps.md`，
  并在 `llmdoc/index.md` 登记本反思。
- 以后修改 `fixskip` 或标题后的竖直间距时，测试矩阵至少包含：ctex 普通标题、runin 标题、
  `titlesec` 接管的标题、标题后 `\hrule`／`\titlerule`、标题后 `\nointerlineskip`。
