---
name: 1103-empty-output-after-space
description: 记录 #1103 修复没有可见输出的已注册命令两侧都有源码空格时多出一枚空格的过程：重放点不能处理命令后的源码空格、命令钩子之后是 \__hook 宏、外层命令代码在内层钩子之后，以及 expl3 函数与测试矩阵构造的几处问题
metadata:
  type: feedback
---

# [Task Reflection]

## Task

#1103（合入 PR #1102，分支 `fix-1092-siunitx-range`）：已注册命令执行后没有可见输出，且两侧都有源码空格时，结果比直接输入多一枚空格；两侧都是汉字时多出两枚间距的宽度（`中 \mbox{} 文` 为 26.66pt，直接输入为 20.0pt）。#1092 时这被登记为已知回退（见 `memory/doc-gaps.md` 中“siunitx 空输出两侧都有源码空格时多出两枚 `\CJKecglue`”一节），之后维护者改为要求彻底修复。

最终做法（`xeCJK/xeCJK.dtx`）：

- 新增 `\__xeCJK_boundary_replay_before_empty:`，由 stream end（首类别为空、entry 未 resolved）、`\__xeCJK_boundary_hmode_transparent_end:`、宽高深都为零的透明盒子调用；last_box 非 hlist 路径与非零尺寸透明盒子仍用原 replay_before。
- capture 新增两个字段：`space_glue` 记录 capture_space 刚取下 glue 时的 space_flag（之后入口前是 CJK-space 时 space_flag 会被改为真，不能再用它区分）；`after_space` 记录 capture 开始时内层记录是否仍有效，供 `\textcolor{red}{}` 这类嵌套空命令把记录传给外层。
- 入口前是 CJK-space 且没有 glue 时只重放 marker 并清 pending；否则照常重放 marker 与 glue。
- `\__xeCJK_boundary_after_space_arm:`／`rearm:` 记录 depth-1 与列表末尾状态，另有 `drop`（CJK-space 无 glue）与 `unchecked`（`中{} `、`中\ ` 的入口）两个标志。`\__xeCJK_boundary_after_space_check:` 在各类结束点调用（inline box／last_box／stream end、hmode_transparent_end、xeCJKfntef 的 `\__xeCJK_ulem_end:` 与 under_symbol_auxii、`\textcolor` 非公式分支、hyperref 的 phantomsection／MakeLinkTarget after 钩子、第二参数为空时的 `\hypertarget`），用 peek 看下一个记号：空格删去（drop 时先 unskip、清 pending，紧跟 `$` 时补 `\xeCJK_space_or_xecglue:`）；名字以 `__hook` 开头的宏展开一层再看；其他控制序列与花括号保留记录给外层；其他字符作废记录。
- xeCJKfntef `\__xeCJK_ulem_onin_entry_check_space:nn` 的透明内容分支：入口前是 CJK-space／CJK-widow 时不解除入口。`fntef-entry-space01` 有 9 项 oracle 随直接输入改变（`符 {\color{red}~中} 后` 由 36.66 变 33.33，与去掉颜色的 `符 {~中} 后` 一致），`.tlg` 已更新。
- 新测试 `xeCJK/testfiles/boundary-empty-space01.lvt`（2305 项）：新代码 0 失败，PR 原 head 1008 项失败，master 1070 项失败。

## Expected vs Actual

- 预期：在重放入口空格的地方判断命令有没有输出，没有输出就不重放，改动集中在一处。
- 实际：重放发生在命令的 after 钩子里，命令自身的代码还没执行完，后面的源码空格在这一时刻处理不了。最终拆成“结束时只重放 marker”和“结束后用 peek 检查下一个记号”两部分，检查点分布在十处左右的结束路径上，并要穿过 `\__hook` 宏和外层命令的后续代码。
- 结果：外部矩阵 `tmp/i1103/gen`（9 左 × 9 右 × 10 命令 × 4 空格组合 × 4 间距设置），以“删去命令后的直接输入”为 oracle，相对 PR head 修好约 800 项、0 回退。相对 master 仍有少量单元 master 对而新代码错，全部是 `\numlist{}`／`\unit{}` 在 `中{}`、`中\ `、`中…$` 入口的 00／01／10 组合，值与 master 上的 `\mbox{}` 相同，来自 #1092 的注册，与其他已注册命令规则一致，不是本修复引入。修复前后相同、仍不一致的写法：左侧全角标点后有空格；左侧汉字、右侧无空格、命令后是盒子／规则／标点（`中\cmd\hbox{x}`）；左侧 `中{}`、`中\ ` 且命令后紧接汉字；左侧公式右侧汉字（`xCJKecglue=true` 且使用可区分间距时，transparent、box 一类命令为 19.05pt，直接输入 20.72pt）；`\phantomsection` 不带 `{}` 时命令名后的空格被 TeX 吞掉。siunitx 3.5.5 与 3.6.3 下 `siunitx-ecglue01` 均 576／576，xeCJK 标准测试 125／125，`l3build doc` 通过、索引 0 拒绝。

## What Went Wrong

1. **在重放点和结束后之间反复。** 第一版原型“入口前是 CJK-space 时不 restore_space”只修好 11 组合，却改坏 10 组合。之后几次在“重放时就删空格”与“命令结束后再删”之间来回改。
2. **`\peek_remove_spaces:n`、`\tex_ignorespaces:D` 放在 cmd after 钩子里不起作用。** 钩子之后紧跟的是 `\__hook_next cmd/<name>/after` 之类的宏，下一个记号不是空格。
3. **没有预料到外层命令的代码排在内层钩子之后。** `\hypertarget` 之后还有 `\hyper@anchor`，`\MakeLinkTarget` 有自己的分组，`\textcolor` 之后有 `\set@color`。检查遇到这些控制序列或花括号时如果直接作废记录，外层结束时就没有记录可用。
4. **一度用不变量代替 oracle。** 曾用“11 组合应等于 10 或 01”辅助判断，最后改回以删去命令后的直接输入为准。
5. **expl3 函数用错。** `\tl_if_eq:cnTF` 不能在 e 型展开中使用，导致记录下来的是未展开的代码；`\clist_if_in_p` 与 `\tl_if_eq_p` 不存在（改用 `\str_if_eq_p:ee`）；`\str_range:nnn` 不展开参数，要先 `\exp_args:Ne`。
6. **测试矩阵构造出错，产生假失败。** 用宏参数拼 oracle 时，两个空格记号不会合并成一个，控制空格后的空格也不会被跳过，oracle 里的空格要单独给出；矩阵每项排版前没有重置 `\g__xeCJK_glue_check_pending_bool` 与 `\g__xeCJK_last_node_tl`，前一项的状态带进下一项。
7. **外部矩阵全对，全量测试仍有回退。** 中途一次 `l3build check` 发现 `fntef-entry-space01`、`hyperref-anchor-ecglue01` 失败：给 `\hypertarget` 加了 cmd after 钩子，非空的 `\hypertarget{t5}{锚}` 后的间距也被删去。改为只在第二参数为空时检查。
8. 期间 master 合入两个 agentic CI 提交，已 rebase 到 `origin/master`，没有冲突带来的问题。

## Root Cause

- 第 1 至 3 条同出一源：没有先弄清“命令结束”在记号流里实际是哪个位置。after 钩子不是命令的最后一个记号，钩子之后有 `\__hook` 系列宏，再往外还有外层命令自己的代码。重放点只能决定 marker 与 glue，源码空格只能在所有这些代码都执行完之后由 peek 处理；peek 必须能穿过 `\__hook` 宏，并且在遇到不认识的控制序列时把记录交给外层，而不是作废。
- 第 4 条：辅助不变量本身没有经过直接输入的验证。lessons-learned 已有“oracle 需要复刻被测实现的细节时，说明判据选错了”，这次是相反方向的同类问题：用一个推出来的关系代替实际排版结果。
- 第 5 条：与 #550“写可展开命令前先逐个实测候选函数”同类，这次的新情况是函数名本身不存在或参数不展开，不只是可展开性。
- 第 6 条：与 #1091 R12“oracle 不一致时先单独运行，确认没有受前一用例状态影响”是同一类问题在外部矩阵上的再次出现；矩阵只对单项结果负责，全局状态必须逐项清零。
- 第 7 条：外部矩阵只覆盖设计时想到的命令与写法，不能代替既有回归测试；钩子挂得比需要的范围宽，只有既有测试里的非空用例能发现。

## Missing Docs or Signals

- 没有文档说明 LaTeX 命令钩子展开后的记号次序：`cmd/<name>/after` 之后紧跟 `\__hook_next…` 一类宏，钩子里的 peek 看不到源码的下一个记号。
- 没有文档说明在已注册命令内部做“结束后检查”时，外层命令（`\hypertarget`、`\MakeLinkTarget`、`\textcolor`）的代码还在后面，需要把记录交给外层。
- `space_flag` 在入口前是 CJK-space 时会被改写，这一点只在代码里，没有写进架构文档；本次因此另加了 `space_glue` 字段。
- 测试构造注意事项里没有写“宏参数拼接时空格记号不合并、控制空格后的空格不跳过”，也没有写外部矩阵每项要重置的全局量。

## Promotion Candidates

由 recorder 决定是否提升：

- `memory/lessons-learned.md` 的“LaTeX2e 命令钩子机制”一组（第 2、3 条）：
  - “在 cmd after 钩子里 peek 下一个记号，看到的是 `\__hook` 宏而不是源码”：需要识别名字以 `__hook` 开头的宏并展开一层再看。
  - “钩子之后外层命令的代码可能还没执行”：遇到不认识的控制序列或花括号时，把待处理状态保留给外层结束时检查，不要作废。
- `reference/coding-conventions.md` 的 expl3 一节（第 5 条）：`\tl_if_eq:cnTF` 不能用于 e 型展开，`\clist_if_in_p`、`\tl_if_eq_p` 不存在（用 `\str_if_eq_p:ee`），`\str_range:nnn` 不展开参数（先 `\exp_args:Ne`）。可并入 #550 那组“可展开的替代”，并提醒新函数名先用 `\cs_if_exist:NTF` 确认存在（与 #1043 同一做法）。
- `reference/build-and-test.md` 的命令边界矩阵一节（第 6、7 条）：用宏参数拼 oracle 时空格的两条规则；矩阵每项排版前重置 `\g__xeCJK_glue_check_pending_bool` 与 `\g__xeCJK_last_node_tl`；外部矩阵通过后仍要跑全量 `l3build check`。另补 `boundary-empty-space01`（2305 项）的说明。
- `architecture/xecjk-architecture.md`（不属于本反思的改动范围，列出供 recorder 处理）：`replay_before_empty` 的调用条件、`space_glue`／`after_space` 字段、after_space 检查的调用点与 peek 规则、xeCJKfntef 透明内容分支的变化。
- `memory/doc-gaps.md`：#1092 那一节改写为“已由 #1103 修复”，并登记上文列出的修复前后相同、仍不一致的五类写法，以及 `\numlist{}`／`\unit{}` 在 `中{}`、`中\ `、`中…$` 入口与 master 不同的原因。
- 只留在 memory、不提升：第 1 条的反复过程本身与第 4 条（已有相近规则，作为实例即可）；第 8 条 rebase。

## Follow-up

- 由 recorder 按上面的候选更新 `xecjk-architecture.md`、`build-and-test.md`、`coding-conventions.md`、`doc-gaps.md`，并在 `llmdoc/index.md` 的反思列表中加入本文件。
- 以后在命令钩子里处理“命令之后的源码”前，先用 `\tracingmacros` 或打印下一个记号的方式确认钩子之后的实际记号次序，再决定检查放在哪里。
- 外部矩阵每次重构后，先单独运行几个失败单元确认不是状态泄漏，再跑全量 `l3build check`。

## 相关引用

- 实现：`xeCJK/xeCJK.dtx` 中的 `\__xeCJK_boundary_replay_before_empty:`、`\__xeCJK_boundary_after_space_arm:`、`\__xeCJK_boundary_after_space_check:`、`\__xeCJK_ulem_onin_entry_check_space:nn`。
- 测试：`xeCJK/testfiles/boundary-empty-space01.lvt/.tlg`、`xeCJK/testfiles/fntef-entry-space01.tlg`；外部矩阵 `tmp/i1103/gen`（本地，未跟踪）。
- 前序：[[1092-siunitx-range-auto-stream]]、[[1091-fntef-ulem-terminator-entry-space]]、[[../decisions/992-command-boundary-capture-register.md]]。

## 本地审查第一轮

上文是第一版提交时的记录。本地审查第一轮报告 2 项阻塞问题、1 项重要建议、2 项小问题，修复如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`）：

1. **表格单元格末尾报错。** `中 \mbox{} & 文` 报 `Extra alignment tab`：`\__xeCJK_boundary_after_space_test:` 一开始就结束了 align-safe 分组，之后读取等同于 `&` 的 `\l_peek_token`，TeX 插入列模板的结尾。现在所有判断都在 `\group_align_safe_begin:`／`end:` 之间；`\peek_remove_spaces:n` 的回调在 align-safe 分组之外执行，删去空格之后由 `\__xeCJK_boundary_after_space_math_test:` 重新进入分组再 peek 一次。
2. **公式前间距丢失。** `中 \color{red}$y$`、`中 \mbox{}{$y$}` 以前丢失 `\xeCJK_space_or_xecglue:`。等同于 `\relax` 的记号（xcolor 的 `\XC@ecolor`）执行后继续看，`\ignorespaces` 之后再看一个记号（`\__xeCJK_boundary_after_space_ignore_test:`）；`drop` 为真时，左花括号由 `\__xeCJK_boundary_after_space_brace:w` 只吸收一枚、看其后是否 `$`，删去空格之后遇到左花括号也这样处理。
3. **左侧紧贴 `~`、`\nobreakspace{}` 时误删命令之后的空格。** `space_glue` 在取下 glue 后列表末尾是 penalty 时记为假。`中{ }\cmd 文` 与 `中{} \cmd 文` 列表相同、无法区分，按后者处理，登记为已知限制。
4. **`unchecked` 标志范围过宽。** 以前入口前是 `CJK-space` marker 时也设置，`\textbf{中} \color{red} 文` 多出空格；现在只在 `CJK` marker 时设置。
5. **记录泄漏。** 新 marker 排出时（`\xeCJK_make_node:n`、`\__xeCJK_make_space_node:`）清除“命令之后的空格”记录，避免它被后面的命令接过来（如 `中~ \RegStream{}\hbox{x}` 之后的下一段）。
6. **透明盒子的空判据。** 以前用宽、高、深之和，正负抵消，且 `\mbox{\smash{\rlap{\rule{2pt}{1pt}}}}` 被当成空盒子。现在由 `\__xeCJK_boundary_if_capture_box_empty:TF` 判断：三者分别为零，并在盒子副本里从末尾向前删去 glue、kern、penalty，拆开零尺寸 hbox，列表变空才算没有可见输出。新增寄存器 `\l__xeCJK_boundary_probe_inner_box`，`loading01.tlg` 随之多一行。

测试 `boundary-empty-space01` 由 2305 项增至 3803 项（7 个 TEST，组成见 `llmdoc/reference/build-and-test.md`）。旧 head 上 tie 类 216 项失败，`C-groupmath`／`C-colormath` 80 项失败，表格用例报错。审查者的 110448 组外部矩阵上，相对修复前 base 的回退由 298 项降为 3 项，剩下 3 项是矩阵 oracle 写错（`中 \phantomsection{}$y$` 删去命令后应是 `中 {}$y$`）。另一已知限制 `\mbox{} \mbox{}`（`xCJKecglue=true`、可区分间距、`01` 写法）修复前后都与直接输入不一致，登记在 `llmdoc/memory/doc-gaps.md`；左侧是公式、右侧是汉字一项也补记了修复前后的数值。

### 教训

- **自己的验证矩阵只列出与直接输入一致的组合。** `boundary-empty-space01` 只收入与直接输入一致的组合，外部矩阵 `tmp/i1103/gen` 也只覆盖设计时想到的 9 种左侧与 9 种右侧；表格单元格、命令左侧的 `~`、`\color` 或花括号后接公式这类写法从一开始就不在里面，所以“0 失败”说明不了它们。审查者从更宽的输入空间独立构造矩阵（110448 组），一次就找到这几类。以后构造矩阵时，左侧、右侧与上下文（表格、分组、颜色声明）各自列出可能的记号种类，再决定哪些移出，移出的组合要登记理由。
- **peek 之后读取 `\l_peek_token` 前必须仍在 align-safe 分组内。** 下一个记号可能是 `&`，在分组之外判断它会让 TeX 提前结束单元格。`\peek_remove_spaces:n` 的回调已经在它自己的 align-safe 分组之外，回调里要读下一个记号就得重新 peek。已提升到 `memory/lessons-learned.md`。这条只管住了判断，没有管住把下一个记号读成参数，第二轮因此又报阻塞问题，见下文「本地审查第二轮」。
- **记录类的旁路状态要在新内容排出时清除。** 只在“下一个 capture 开始”时清除，中间排出的字符不会让记录失效，记录可能被不相关的命令接过来。已提升到 `memory/lessons-learned.md`。
- **零尺寸不等于没有输出。** `\smash`、`\rlap` 之类会造出尺寸为零、内容可见的盒子；“没有可见输出”要看列表里的节点，而不只看盒子尺寸。

## 本地审查第二轮

第一轮修复提交为 `3e2eb5e2`。本地审查第二轮报告 1 项阻塞问题、1 项重要问题、2 项小问题，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`）：

1. **阻塞：plain `\halign` 中命令之后紧跟 `\cr`、`\crcr`、`\span` 时报错。** `中 \mbox{}\cr` 报 `Forbidden control sequence found while scanning use of \__xeCJK_boundary_after_space_hook:N`，修复前的 `25a33aef` 不报错。第一轮只把对 `\l_peek_token` 的判断移进了 align-safe 分组，控制序列分支仍先结束分组，再把下一个记号读成 `\__xeCJK_boundary_after_space_hook:N` 的参数；读参数时碰到对齐记号，TeX 同样插入列模板。现在 `\__xeCJK_boundary_after_space_test:` 把空格以外的分派拆到 `\__xeCJK_boundary_after_space_test_other:`，先在分组内用新增的 `\__xeCJK_boundary_if_peek_align:TF` 排除含义为 `\cr`、`\crcr`、`\span` 的记号，作废记录，再处理其他控制序列。
2. **重要：空盒子探测无限递归。** `A \mbox{\discretionary{}{}{\kern0pt}} B` 报 `TeX capacity exceeded`：列表末尾的节点属于 `\discretionary` 的不断行文本，`\unkern` 删不掉它，`\__xeCJK_boundary_box_empty_probe:` 反复看到同一个节点。新增 `\__xeCJK_boundary_box_empty_probe_remove:N`，比较删除前后的 `\lastnodetype`、`\lastkern`、`\lastskip`、`\lastpenalty`，没有变化就停下，按有可见输出处理；`\box_set_to_last:N` 取到空盒子或不是 hbox 时也停下，取到非零尺寸的盒子时放回。
3. **小问题：`unchecked` 标志的 dtx 注释与实现不符。** 实现只在入口前是 `CJK` marker 时设置，注释仍写“`CJK` 或 `CJK-space` marker”，已更正。
4. **小问题：无输出透明盒子判据的 dtx 注释过时。** 注释仍写“宽、高、深都为零的透明盒子”，改为引用 `\__xeCJK_boundary_if_capture_box_empty:TF`。

另外，第二轮审查者的矩阵左侧包含 `{ }`，暴露了第一轮登记有误的 `中{ }\cmd 文`。第一轮把它登记为“修复前后相同，或修复前也与直接输入不一致”；实测修复前与直接输入一致，现在少一枚空格（`中{ }\mbox{} 文` 修复前 26.66pt、现在 23.33pt、直接输入 26.66pt；`A{ }\mbox{} B` 为 21.24／17.91／21.24pt），是回退。它在命令之前的节点列表与 `X{} \cmd Y`、`X\ \cmd Y`、`X\space\cmd Y` 相同，后三者修复前多一枚空格、现在正确。审查者的矩阵在每种间距设置下各有 126 项这类回退（9 个命令 × 14 种右侧，`01` 写法）。维护者决定保留当前修复，作为已知限制写入用户手册（`xeCJK/xeCJK.dtx`「CJK 文字与命令交互时的间距」一节）并给出替代写法，见 `llmdoc/memory/decisions/1103-group-space-before-empty-command.md`。第一轮写下的“相对修复前 base 的回退由 298 项降为 3 项，剩下 3 项都是 oracle 写错”只对第一轮审查者的矩阵成立，那个矩阵左侧没有 `{ }`，`doc-gaps.md` 与 `build-and-test.md` 已补充说明。

测试 `boundary-empty-space01` 由 3803 项增至 3824 项：新增 TEST 7（plain `\halign` 的 `\cr`、`\crcr`、`\span`，10 项），零尺寸盒子一组（现为 TEST 8）增加 `disc/11` 与两项 `\makebox[0pt]{}`，TEST 1–4 各增加两项 `color-math-direct`。这些新用例在 `3e2eb5e2` 上分别报 `Forbidden control sequence` 与 `TeX capacity exceeded`。

### 教训

- **align-safe 规则要覆盖“读成参数”。** 第一轮的教训写成“读取 `\l_peek_token` 时必须仍在 align-safe 分组内”，只管住了判断，没有管住把下一个记号当作宏参数读入。读参数与判断一样会让 TeX 看到对齐记号。修复第一轮时只测了 LaTeX `tabular` 的 `&`，没有测 plain `\halign` 的 `\cr`、`\crcr`、`\span`；按第一轮“左侧、右侧与上下文各自列出可能的记号种类”的教训，表格上下文的右侧应列出全部对齐记号。`memory/lessons-learned.md` 中的对应条目已改写。
- **“无法区分”时先比较修复前的行为，再决定登记方式。** 判断某个写法“无法区分”只说明新代码对它与另一写法给出同样的结果，不说明这个结果相对修复前是改进还是回退。第一轮没有实测修复前的 `中{ }\mbox{} 文`，就把它写成“修复前也不一致”，结论是推出来的。应当先在修复前的版本上测出数值，与直接输入比较：修复前就不一致的登记为未修写法；修复前一致、现在不一致的是回退，要报给维护者决定，并在用户手册里写明。
- **探测循环要保证会停下。** 从列表末尾逐个删去节点的循环，遇到删不掉的节点（`\discretionary` 的不断行文本、无法取下的盒子）就会无限递归。第一次修正用“删除前后末尾状态相同就停下”判断，却把两枚相同 glue 中删去一枚的情形（`\makebox[0pt]{}`）也当成删不掉，858 项回到修复前的结果；协调者重跑上一轮审查者的矩阵、与上一提交逐项比较才发现。最后改为限制删除次数。教训：用“状态没变”推断“没有进展”，要先确认相同状态不会由不同节点产生。
