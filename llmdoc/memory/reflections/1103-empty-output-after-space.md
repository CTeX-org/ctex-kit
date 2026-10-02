---
name: 1103-empty-output-after-space
description: 记录 #1103 修复没有可见输出的已注册命令两侧都有源码空格时多出一枚空格的过程：重放点不能处理命令后的源码空格、命令钩子之后是 \__hook 宏、外层命令代码在内层钩子之后，以及 expl3 函数与测试矩阵构造的几处问题
metadata:
  type: feedback
---

# [Task Reflection]

> 各轮小节里的 `boundary-empty-space01` TEST 编号是写下时的编号。第二、四、五、六、七、九轮都插入过 TEST，不能用一条换算对应到当前编号；按 TEST 名称找当前编号，名称与各组的旧编号见 `llmdoc/reference/build-and-test.md`「组成」一节（每条括号里列出各轮之前的编号）。

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

第一轮修复提交为 `52217645`。本地审查第二轮报告 1 项阻塞问题、1 项重要问题、2 项小问题，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`）：

1. **阻塞：plain `\halign` 中命令之后紧跟 `\cr`、`\crcr`、`\span` 时报错。** `中 \mbox{}\cr` 报 `Forbidden control sequence found while scanning use of \__xeCJK_boundary_after_space_hook:N`，修复前的 `e641743e` 不报错。第一轮只把对 `\l_peek_token` 的判断移进了 align-safe 分组，控制序列分支仍先结束分组，再把下一个记号读成 `\__xeCJK_boundary_after_space_hook:N` 的参数；读参数时碰到对齐记号，TeX 同样插入列模板。现在 `\__xeCJK_boundary_after_space_test:` 把空格以外的分派拆到 `\__xeCJK_boundary_after_space_test_other:`，先在分组内用新增的 `\__xeCJK_boundary_if_peek_align:TF` 排除含义为 `\cr`、`\crcr`、`\span` 的记号，作废记录，再处理其他控制序列。
2. **重要：空盒子探测无限递归。** `A \mbox{\discretionary{}{}{\kern0pt}} B` 报 `TeX capacity exceeded`：列表末尾的节点属于 `\discretionary` 的不断行文本，`\unkern` 删不掉它，`\__xeCJK_boundary_box_empty_probe:` 反复看到同一个节点。新增 `\__xeCJK_boundary_box_empty_probe_remove:N`，限制删除次数（第 64 次起不再删除），超过就停下，按有可见输出处理（最初比较删除前后的末尾状态，因 `\makebox[0pt]{}` 误判而改掉，见下文教训）；`\box_set_to_last:N` 取到空盒子或不是 hbox 时也停下，取到非零尺寸的盒子时放回。
3. **小问题：`unchecked` 标志的 dtx 注释与实现不符。** 实现只在入口前是 `CJK` marker 时设置，注释仍写“`CJK` 或 `CJK-space` marker”，已更正。
4. **小问题：无输出透明盒子判据的 dtx 注释过时。** 注释仍写“宽、高、深都为零的透明盒子”，改为引用 `\__xeCJK_boundary_if_capture_box_empty:TF`。

另外，第二轮审查者的矩阵左侧包含 `{ }`，暴露了第一轮登记有误的 `中{ }\cmd 文`。第一轮把它登记为“修复前后相同，或修复前也与直接输入不一致”；实测修复前与直接输入一致，现在少一枚空格（`中{ }\mbox{} 文` 修复前 26.66pt、现在 23.33pt、直接输入 26.66pt；`A{ }\mbox{} B` 为 21.24／17.91／21.24pt），是回退。它在命令之前的节点列表与 `X{} \cmd Y`、`X\ \cmd Y`、`X\space\cmd Y` 相同，后三者修复前多一枚空格、现在正确。审查者的矩阵在每种间距设置下各有 126 项这类回退（9 个命令 × 14 种右侧，`01` 写法）。维护者决定保留当前修复，作为已知限制写入用户手册（`xeCJK/xeCJK.dtx`「CJK 文字与命令交互时的间距」一节）并给出替代写法，见 `llmdoc/memory/decisions/1103-group-space-before-empty-command.md`。第一轮写下的“相对修复前 base 的回退由 298 项降为 3 项，剩下 3 项都是 oracle 写错”只对第一轮审查者的矩阵成立，那个矩阵左侧没有 `{ }`，`doc-gaps.md` 与 `build-and-test.md` 已补充说明。

测试 `boundary-empty-space01` 由 3803 项增至 3824 项：新增 TEST 7（plain `\halign` 的 `\cr`、`\crcr`、`\span`，10 项），零尺寸盒子一组（现为 TEST 8）增加 `disc/11` 与两项 `\makebox[0pt]{}`，TEST 1–4 各增加两项 `color-math-direct`。这些新用例在 `52217645` 上分别报 `Forbidden control sequence` 与 `TeX capacity exceeded`。

### 教训

- **align-safe 规则要覆盖“读成参数”。** 第一轮的教训写成“读取 `\l_peek_token` 时必须仍在 align-safe 分组内”，只管住了判断，没有管住把下一个记号当作宏参数读入。读参数与判断一样会让 TeX 看到对齐记号。修复第一轮时只测了 LaTeX `tabular` 的 `&`，没有测 plain `\halign` 的 `\cr`、`\crcr`、`\span`；按第一轮“左侧、右侧与上下文各自列出可能的记号种类”的教训，表格上下文的右侧应列出全部对齐记号。`memory/lessons-learned.md` 中的对应条目已改写。
- **“无法区分”时先比较修复前的行为，再决定登记方式。** 判断某个写法“无法区分”只说明新代码对它与另一写法给出同样的结果，不说明这个结果相对修复前是改进还是回退。第一轮没有实测修复前的 `中{ }\mbox{} 文`，就把它写成“修复前也不一致”，结论是推出来的。应当先在修复前的版本上测出数值，与直接输入比较：修复前就不一致的登记为未修写法；修复前一致、现在不一致的是回退，要报给维护者决定，并在用户手册里写明。
- **探测循环要保证会停下。** 从列表末尾逐个删去节点的循环，遇到删不掉的节点（`\discretionary` 的不断行文本、无法取下的盒子）就会无限递归。第一次修正用“删除前后末尾状态相同就停下”判断，却把两枚相同 glue 中删去一枚的情形（`\makebox[0pt]{}`）也当成删不掉，858 项回到修复前的结果；协调者重跑上一轮审查者的矩阵、与上一提交逐项比较才发现。最后改为限制删除次数。教训：用“状态没变”推断“没有进展”，要先确认相同状态不会由不同节点产生。

## 最终全范围审查（第四轮）

第二轮修复提交为 `682d6e08`。本地审查第三轮只报告一项文档小问题（索引与反思仍按已放弃的“比较删除前后的末尾状态”描述空盒子探测），由 `410f365d` 修正。最终全范围审查（第四轮）在 `410f365d` 上报告 1 项阻塞问题、1 项重要问题、2 项小问题，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`）：

1. **阻塞：颜色正文以空格结尾时，颜色命令之后的空格被删去。** `\textcolor{red}{A } B`、`{\color{red}red } text` 为 17.91pt，修复前 `e641743e` 与直接输入 `{A } B` 都是 21.24pt，是回退。`\reset@color` 由 `\aftergroup` 在分组结束之后执行，它的 transparent capture 入口取下的是分组里正文末尾的空格，被当作命令左侧的源码空格。现在 `\reset@color` 改用新增的 `\__xeCJK_boundary_register_transparent_pop:n` 注册，l3color 的 `\__color_backend_reset:` 也改用新增的 `\__xeCJK_boundary_hmode_transparent_pop_begin:`，capture 的 `kind` 记为 `transparent-pop`；`\__xeCJK_boundary_replay_before_empty_arm:` 在 `kind` 为 `transparent-pop` 且 `after_space` 不为真时只调用 `\__xeCJK_boundary_replay_before:`，不记下记录。`after_space` 为真时（`\textcolor{red}{}` 里 `\set@color` 留下的记录）照常转交。
2. **重要：列模板以空的已注册命令结尾时报错。** `\halign{#\mbox{}\cr 中 \cr}` 里命令之后的下一个记号是 TeX 插入的 `\endtemplate`（`\outer` 记号），把 `\l_peek_token` 交给 `\token_if_eq_meaning:NNTF` 时报 `Forbidden control sequence`，接着 Emergency stop。新增 `\__xeCJK_boundary_if_peek_outer:TF`：用原语 `\tex_meaning:D` 展开 `\l_peek_token` 的含义，前 6 个字符是 `\outer` 时作废记录并结束 align-safe 分组。`after_space_test`、`brace_test`、`math_test`、`ignore_test` 都先经过这一检查，原判断移入各自的 `_aux` 函数。
3. **小问题：llmdoc 里仍是 rebase 前的提交号。** 已改为历史中的对应提交（如原基准 `25a33aef` 对应 `e641743e`，`3e2eb5e2` 对应 `52217645`），对应关系由提交说明一致性核对。
4. **小问题：`build-and-test.md` 里 xeCJK 标准测试仍写 125 项。** 已改为 126 项。

另一个报告中的写法 `\halign{# &#\cr 中&文\cr}`（模板里 `#` 之后有空格、不含命令）在修复前与现在都报 `Forbidden control sequence`，来自 xeCJK 在汉字之后的前视，与本修复无关，登记在 `llmdoc/memory/doc-gaps.md`。审查“未计入问题的观察”（`\uwave{}`、`\CJKunderdot{}` 左侧是西文或 `{中}`；可区分间距、`xCJKecglue=true` 时的 `A{} \mbox{} 文`）修复前也与直接输入不一致，补进 `doc-gaps.md` 的对应列举。

测试 `boundary-empty-space01` 由 3824 项增至 3848 项、10 个 TEST：新增 TEST 8（列模板以命令结尾，6 项）与 TEST 9（颜色正文以空格结尾，9 项 × `xCJKecglue=false/true` = 18 项），原零尺寸盒子一组改为 TEST 10。在 `410f365d` 上 TEST 9 失败 14 项，TEST 8 报 `Forbidden control sequence`。

### 教训

- **矩阵只把颜色命令当作命令本身来测。** 自己的矩阵与前几轮审查者的矩阵都把 `\textcolor{red}{}`、`\color{red}` 作为“被删去的命令”放在两段文字之间，没有测“颜色正文末尾有空格”这种由颜色命令隐式插入 `\reset@color` 的写法。`\aftergroup` 执行的命令看到的列表末尾属于已经结束的分组，入口推断出的“左侧空格”并不存在。列举被测命令时，除了命令本身，还要列出它会隐式插入、在别的位置执行的命令。已提升到 `memory/lessons-learned.md`。
- **列举对齐记号只想到源码里能写出的那些。** 第二轮按“表格上下文的右侧要列出全部对齐记号”的教训排除了 `\cr`、`\crcr`、`\span`，没有想到 TeX 在列模板末尾自己插入的 `\endtemplate`，它还是 `\outer` 记号，连作为参数比较都不行。列举下一个记号的种类时，要把 TeX 自己插入的记号与 `\outer` 记号也算进去。比较 `\meaning` 的输出时注意它以反斜杠开头、字符 catcode 为 12，`\str_if_eq:nn` 不展开 `\c_backslash_str`，要用 `:ee`。已提升到 `memory/lessons-learned.md`。

## 本地审查第五轮

第四轮修复提交为 `be7e530c`。本地审查第五轮（增量，`410f365d..be7e530c`）报告 1 项阻塞问题、1 项重要问题、1 项小问题，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`「颜色弹出命令只转交配对的推入命令留下的记录」与「align-safe 分组」）：

1. **阻塞：颜色正文以“空格 + 空命令”结尾时，颜色命令之后的空格被删去。** `\textcolor{red}{A \mbox{}} B` 为 17.91pt，修复前 `e641743e` 与直接输入 `{A } B` 都是 21.24pt，是第四轮的修复引入的回退；正文末尾换成 `\hypertarget{x}{}`、`\phantomsection`、`\unit{}`、`\uline{}`、内层 `\textcolor{blue}{}`，或写成 `{\color{red}A \mbox{}} B`、`\uline{\textcolor{red}{A \mbox{}} B}`、用户分组 `A {\color{red}} B`，都一样。原因：第四轮让 `\reset@color` 在本层 `after_space` 为真时转交记录，但这条记录可能由正文里的其他命令记下，入口空格是正文里的空格。现在记录带来源编号：`\__xeCJK_boundary_after_space_arm:` 每记下一条新记录就递增 `\g__xeCJK_boundary_after_space_id_int` 并写入 `\g__xeCJK_boundary_after_space_origin_int`，rearm 不改编号。`\set@color` 改用新增的 `\__xeCJK_boundary_register_transparent_push:n` 注册（before 钩子 `\__xeCJK_boundary_hmode_transparent_kind_begin:n { transparent-push }`，after 钩子 `\__xeCJK_boundary_hmode_transparent_push_end:`）；`\textcolor` 包装的非公式分支在调用原函数前把 `\l__xeCJK_boundary_textcolor_level_int` 设为当前分组层数，之后设回 -1；push_end 在当前层数等于包装层数加一时把当前记录的编号（没有记录时为空）存进 `\g__xeCJK_boundary_color_origin_<包装层数>_tl`，再做 after_space_check（为此从 `\__xeCJK_boundary_hmode_transparent_end:` 拆出 `\__xeCJK_boundary_hmode_transparent_finish:`）。`\__xeCJK_boundary_hmode_transparent_pop_begin:` 只在记录有效、当前层数等于包装层数、且当前记录的编号等于该层存下的编号时转交，否则把本层 `after_space` 字段设为假。不经过 `\textcolor` 包装的 `\color` 与 l3color 不转交。新增的三个整数变量让 `loading01.tlg` 多三行。
2. **重要：`\outer` 检查漏掉 `\long\outer`、`\protected\outer` 宏。** 第四轮的 `\__xeCJK_boundary_if_peek_outer:TF` 只比较 `\meaning` 的前 6 个字符，这两类宏的含义以 `\long`、`\protected` 开头，`中 \mbox{}\EmptyOuterB` 仍报 `Forbidden control sequence`。现在取前 22 个字符（`\protected\long\outer` 加一个字符），用 `\exp_args:Nee \str_if_in:nnTF` 查找 `\c_backslash_str outer`。
3. **小问题：TEST 8 缺“命令 + 空格”结尾的模板。** 增加 `tmpl-mbox-space`（模板末尾是 `\mbox{} `，删去空格之后再看下一个记号时遇到 `\endtemplate`）。

测试 `boundary-empty-space01` 由 3848 项增至 3871 项、11 个 TEST：新增 TEST 9（空命令之后紧跟 `\outer` 宏，4 项，用 `\BEGINTEST`／`\ENDTEST`，因为 `\outer` 宏不能出现在宏参数里），颜色正文一组改为 TEST 10、每种设置增加 9 项，零尺寸盒子一组改为 TEST 11，TEST 8 增加 1 项。TEST 9 的 oracle 写成宽度相同的 `中 `：直接输入 `中 \EmptyOuterA` 在 xeCJK 汉字之后的前视里也报 `Forbidden control sequence`，修复前 `e641743e` 就如此，登记在 `llmdoc/memory/doc-gaps.md`。在 `be7e530c` 上 TEST 9 报 `Forbidden control sequence`；去掉该 TEST 后 TEST 10 的新用例失败 18 项。

修复前后都与直接输入不一致、不在测试里比较的写法登记在 `doc-gaps.md`：`\textcolor{red}{中 \mbox{}} 文`（修复前与现在都是 26.66pt，直接输入 `{中 } 文` 23.33pt）、l3color 的 `\color_group_begin:`…`\color_group_end:` 正文以空格结尾（都是 17.91pt，直接输入 21.24pt，审查者报告）。本轮当时还登记了嵌套的空颜色命令 `中 \textcolor{red}{\textcolor{blue}{}} 文`（写作“都是 26.66pt，直接输入 20.0pt”），第六轮实测 `aed1f9d2` 上它与直接输入一致（20.0pt），这条登记有误，已从 `doc-gaps.md` 删去，改为 TEST 10 的正向用例 `tc-tc-C`，见下文「本地审查第六轮」。

### 教训

- **转交记录时只问“有没有记录”，没有问“记录从哪来”。** 第四轮为保住 `\textcolor{red}{}` 的转交，用“本层 `after_space` 为真”作条件，默认这条记录一定是配对的 `\set@color` 记下的；正文里任何一个空命令都能留下同样有效的记录。这与第一轮“入口只看取下了 glue，不看 glue 是源码空格还是 `~` 之后的空格”是同一类错误：用状态存在代替状态来源。修好一处“来源被误认”之后，要检查新加的条件本身是不是又依赖了一个只看存在、不看来源的状态。已提升到 `memory/lessons-learned.md`。
- **`\meaning` 前缀的顺序是 `\protected`、`\long`、`\outer`。** 第四轮只测了 TeX 插入的 `\endtemplate`（含义以 `\outer` 开头），就按开头比较；用户用 `\long\outer\def` 定义的宏前面还有别的前缀。用 `\meaning` 的前缀判断宏属性时，要先列出全部前缀组合与 TeX 打印它们的顺序。`memory/lessons-learned.md` 中的对应条目已更正。
- **为第四轮修复补的测试只覆盖了修复想要保住的那一种写法。** TEST 9（现 TEST 10）的 `tc-empty-C`／`tc-empty-L` 确认 `\set@color` 的记录仍被转交，但没有一项让正文里别的命令留下记录，所以“转交条件过宽”没有被测到。给一个条件加测试时，除了它应当成立的情形，也要列出“条件同样成立、但不该动作”的写法。

本轮修复的第一版让 `\@@_boundary_after_space_arm:` 每次都分配新编号，`中 \textcolor{red}{\mbox{}} 文` 里 `\mbox` 接过 `\set@color` 的记录后编号变了，`\reset@color` 配对失败；协调者重跑审查者矩阵、与上一 head 逐行比较时发现 612 项变差，改为本层 `after_space` 为真时保留原编号。同一次全量检查还发现 `fntef-entry-space01` 的 `sibling-color-then-nested-tie-cjk-spaced` 失败：它的 oracle `符 {\color{red}}{~中} 后` 本身含用户分组里的空颜色命令，上一 head 上这个 oracle 碰巧与候选一致，现在恢复为修复前的 36.66pt（多一枚空格，已登记 doc-gaps），比较对象改为删去颜色命令的 `符 {}{~中} 后`（33.33pt，候选与之相同）。

## 本地审查第六轮

第五轮修复提交为 `aed1f9d2`。本地审查第六轮（增量，`be7e530c..aed1f9d2`，run `r6-incr-050819`）报告 1 项阻塞问题、1 项重要问题、2 项小问题，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`「颜色弹出命令只转交配对的推入命令留下的记录」「暂停 capture 观察期间排出的 marker」「align-safe 分组」）：

1. **阻塞（R6-B1）：正文里另有 `\color`／`\normalcolor` 时，颜色命令之后的空格被删去。** `\textcolor{red}{A \color{blue}} B`、`\textcolor{red}{A \color{blue}\mbox{}} B`、`\textcolor{red}{A \normalcolor} B` 在 `aed1f9d2` 上为 17.91pt，修复前 `e641743e` 与直接输入 `{A } B` 都是 21.24pt，是第五轮的修复引入的回退。原因：正文里的 `\color`、`\normalcolor` 也调用 `\set@color`，所在分组层数同样是包装层数加一，`\__xeCJK_boundary_hmode_transparent_push_end:` 结束时又存一次来源编号，覆盖了 `\textcolor` 自己的推入命令存下的编号，`\reset@color` 配对失败。修复：`\__xeCJK_boundary_textcolor:nnn` 在调用原 `\textcolor` 之前把本层的 `\g__xeCJK_boundary_color_origin_<level>_tl` 设为 `?`（不存在时先创建）；push_end 只在层数等于包装层数加一、且存下的值仍是 `?` 时才存编号，所以只有第一个推入命令（`\textcolor` 自己的 `\set@color`）存下编号。
2. **重要（R6-I1）：颜色命令里嵌套空线型命令时多一枚空格。** `中 \textcolor{red}{\uline{}} 文`（以及 `\uuline`、`\uwave`、`\xout`、`\dashuline`、`\dotuline`）在 `aed1f9d2` 上为 26.66pt，直接输入 20.0pt，相对 `be7e530c` 是回退，是第五轮来源编号修复的副作用。原因：线型命令内部有几处在暂停 capture 观察期间把字符排进只用来测量或随即丢弃的盒子：`\UL@end` 吃掉定界符后留下的 `*`、`\UL@setULdepth` 的 `(j`、`\markoverwith` 量装饰符号宽度用的字符（`\uwave` 的 `\char58`、`\xout` 的 `/`、`\dotuline` 的 `.`）。这些字符触发 interchar 转换，`\xeCJK_make_node:n` 排出 marker 时清除“命令之后的空格待删去”的记录，内层空命令交给外层的记录就丢了。暂停机制当时只保存、恢复 `\g__xeCJK_last_node_tl` 与 source-space pending。修复两处：(a) `\__xeCJK_boundary_capture_suspend:`／`\__xeCJK_boundary_capture_resume:` 按暂停层数另外保存、恢复 `\g__xeCJK_boundary_after_space_bool`（新变量 `g__xeCJK_boundary_suspend_<n>_after_space_tl`）；(b) 新包装 `\markoverwith`（原定义存为 `\__xeCJK_ulem_orig_markoverwith:n`），与 `\UL@setULdepth` 一样在测量期间暂停 capture 观察。这两处属于同一 PR 内 #1103 修复的一部分，`\changes` 没有单独加条目。
3. **小问题（R6-M1）：`\outer` 检查误判替换文本以 `\outer...` 开头的普通宏。** 第五轮在 `\meaning` 的前 22 个字符里查找 `\outer`，`\def\Foo{\outerX}`（含义 `macro:->\outerX`）被当作 `\outer` 记号，记录被作废。修复：改为与四个前缀逐一精确比较开头：`\outer `、`\long\outer `、`\protected\outer `、`\protected\long\outer `（各带一个空格；TeX 打印前缀的顺序是 protected、long、outer）。新增 `\__xeCJK_boundary_if_prefix:nN` 与常量 `\c__xeCJK_boundary_outer_str`、`\c__xeCJK_boundary_long_outer_str`、`\c__xeCJK_boundary_protected_outer_str`、`\c__xeCJK_boundary_protected_long_outer_str`，用 `\c_backslash_str` 拼成。
4. **小问题（R6-M2）：嵌套空颜色命令的过时说法。** doc-gaps、测试注释、architecture 与本反思都说 `中 \textcolor{red}{\textcolor{blue}{}} 文` 仍多一枚空格；实测 `aed1f9d2` 与现在都与直接输入一致（20.0pt）。已删去这些说法，改为 TEST 10 的正向用例 `tc-tc-C`。

### 被放弃的做法

修 R6-I1 时先试过让 `\xeCJK_make_node:n`／`\__xeCJK_make_space_node:` 只在当前分组层数不深于记录所在层数时清除记录，想让排进嵌套盒子的 marker 不影响外层的记录。这样上一次排版留下的过期记录会在更浅的分组里存活，`boundary-empty-space01` 的 `tie-hbox/*/01`（`中~\cmd{} \hbox{x}`）20 项失败（18.61pt，应为 21.94pt）。结论：这条记录是全局的，不能按分组层数决定是否清除；在丢弃或测量用的盒子里排出的 marker，应由暂停机制保存、恢复它改动的状态来处理。

修 R6-M1 的第一版用 `\tl_to_str:n { \protected \long \outer }` 生成比较串。`\tl_to_str:n` 在每个控制词之后补一个空格，得到 `\protected \long \outer `，与 `\meaning` 打印的 `\protected\long\outer macro:` 不同，`\protected\long\outer` 宏于是漏检，报 `Forbidden control sequence`。改为用 `\c_backslash_str` 拼出常量，并在 TEST 9 增加 `outer-D` 固定这一前缀。

### 测试与验证

测试 `boundary-empty-space01` 由 3871 项增至 3898 项、12 个 TEST：TEST 9 新增 `outer-D`（`\protected\long\outer` 宏）；新 TEST 11 “empty command followed by a macro whose text starts with outer”（`not-outer-C`、`not-outer-space`），原零尺寸盒子一组顺延为 TEST 12；TEST 10 每种 `xCJKecglue` 设置新增 12 项：`tc-tc-C`、`tc-uline-C`、`tc-xout-C`、`tc-uwave-C`、`tc-uuline-C`、`tc-dashuline-C`、`tc-dotuline-C`、`tc-uline-empty-L`、`tc-xout-L`、`tc-color-L`、`tc-color-mbox-L`、`tc-normal-L`。在 `aed1f9d2` 上运行新测试，`tc-color-L`、`tc-color-mbox-L`、`tc-normal-L`、`tc-uline-C`、`tc-xout-C`、`tc-uwave-C`、`tc-uuline-C`、`tc-dashuline-C`、`tc-uline-empty-L` 失败，各 2 次，共 18 次（当时还没有加 `tc-dotuline-C` 与 `tc-xout-L`）。

xeCJK 全部 126 个测试通过（保存 `.tlg` 之后重跑受影响的 `boundary-empty-space01`、`loading01`、`fntef-entry-space01` 均通过）；`l3build doc` 通过，索引接受 4621 项、拒绝 0 项；siunitx 3.6.3 下 `siunitx-ecglue01` 为 576／576；外部矩阵 `tmp/i1103/r1probe/big.tex` 的结果与第五轮 head `aed1f9d2` 完全相同，相对修复前 `e641743e` 只有 3 项 `C-phantom-M/10` 不同（来自 oracle 本身，与以前一样）。另外 xeCJKfntef 的 13 个线型命令 × 4 种写法 × 2 种设置的探针都与直接输入一致。

仍未解决、与修复前相同：`\textcolor{red}{中 \mbox{}} 文` 修复前与现在都是 26.66pt，直接输入 `{中 } 文` 23.33pt（第五轮已登记，保留）。

### 教训

- **配对时只清点了“谁会读”，没有清点“谁会写”。** 第五轮的教训是转交记录前要确认记录的来源，于是给 `\set@color` 加了“按层数存编号”的写入点，但没有列出同一层里所有会调用 `\set@color` 的命令；正文里的 `\color`、`\normalcolor` 满足同样的层数条件，覆盖了编号。给一个存放处加写入点时，要列出所有能在同样条件下到达这个写入点的调用者，并决定以哪一个为准（这里是第一个）。已并入 `memory/lessons-learned.md`「转交或接过记录之前，确认记录是谁记下的」。
- **暂停机制只保存了设计它时关心的状态。** 第一轮让 marker 排出时清除记录，没有同步把这条记录加进暂停机制；第五轮的来源编号修复让内层记录的转交更依赖这条记录，问题才显现。新增一项“marker 排出时会改动”的全局状态时，要同时检查所有暂停、恢复全局状态的地方。修补时不要用分组层数限制全局记录的清除，那会让过期记录存活。已提升到 `memory/lessons-learned.md`。
- **修好一处之后，前几轮写下的“仍不一致”要重新实测。** 嵌套空颜色命令的登记是第五轮写下的，`aed1f9d2` 上实际已与直接输入一致，却在 doc-gaps、测试注释、architecture 与本反思里留了一轮。登记“仍不一致”的写法时要写明实测所在的提交；下一轮修改相关机制后，把这些登记逐条重新跑一次。
- **生成比较串的函数本身也要验证。** `\tl_to_str:n` 在控制词后补空格，这与 `\meaning` 的打印格式不同。用于逐字比较的常量，写好后先与一个真实记号的 `\meaning` 比较一次。已提升到 `memory/lessons-learned.md`。

## 本地审查第七轮

第六轮修复提交为 `61c313bd`。本地审查第七轮（增量，`aed1f9d2..61c313bd`，run `r7-incr-060233`）报告 1 项阻塞问题、1 项重要问题、1 项小问题，补充报告另指出 R6-M2 只修了一部分，处理如下（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`「颜色弹出命令只转交配对的推入命令留下的记录」「暂停 capture 观察期间排出的 marker」「仍不一致的写法」）：

1. **阻塞（R7-B1）：分组层数 0 的 `\color` 报 `Erroneous variable`。** `\begin{document}` 之后直接写 `\color{blue}`，或段落里的 `中 \color{red} 文`，`\__xeCJK_boundary_hmode_transparent_push_end:` 读取从未创建的 `\g__xeCJK_boundary_color_origin_-1_tl`（color 与 xcolor 都如此）。原因：不在 `\textcolor` 里时 `\l__xeCJK_boundary_textcolor_level_int` 为 -1，分组层数 0 时“层数等于包装层数加一”成立；第六轮新加的“存下的值仍是 `?`”比较用 `\tl_use:c` 读变量，读之前没有检查它是否存在。`aed1f9d2` 与修复前 `e641743e` 都不报错；以前测试里的颜色用例都在 `\hbox` 或 `\TEST` 的分组里，层数不为 0，所以没有发现。修复：push_end 的条件改为 `\bool_lazy_all:nT`，在层数比较与 `?` 比较之间加 `\tl_if_exist_p:c`（变量由 `\textcolor` 包装创建，不在包装里时不存在）。
2. **重要（R7-I1）：`\sbox` 夹在两个空命令之间时，第一个命令之后的空格被删去。** `A \mbox{}\sbox0{x}\mbox{} B` 为 17.91pt，直接输入 `A \sbox0{x} B` 与 `e641743e`、`aed1f9d2` 都是 21.24pt（`xCJKecglue=false`）；`\sbox0{}`、`\savebox`，或第二个命令换成 `\textcolor{red}{}`、`\uline{}` 同样。原因：第六轮让 `\__xeCJK_boundary_capture_suspend:`／`resume:` 保存、恢复 `\g__xeCJK_boundary_after_space_bool`，`\sbox` 的适配器 `\__xeCJK_boundary_sbox:Nn` 也走暂停与恢复。`\sbox` 里的内容排出 marker，清除了第一个 `\mbox{}` 的记录（以前就是这样，所以第二个命令不会删空格）；现在 resume 又把记录恢复，第二个命令之后的检查就删去了第一个命令之后的空格。修复：`\__xeCJK_boundary_sbox:Nn` 在盒子赋值之后执行 `\bool_gset_false:N \g__xeCJK_boundary_after_space_bool`，理由是 `\sbox` 之后的源码空格已经不与之前的命令相邻。线型命令内部的暂停（`\UL@end`、`\UL@setULdepth`、`\markoverwith`、`\xeCJK_fntef_sbox:n`）仍保留记录：它们在命令内部，命令结束时要把记录交给外层。
3. **小问题（R7-M1）：第六轮新增的 TEST 11 没有判别力。** 它在 `aed1f9d2`（子串查找版本）上也通过：`中 \mbox{}\EmptyNotOuter 文` 的记录不论作废与否，宏展开之后排出的汉字都会清除它，所以抓不到要防止的误判。改为把宏放在颜色命令正文末尾，让记录必须交给外层：`not-outer-C`（`中 \textcolor{red}{\mbox{}\EmptyNotOuter} 文`，比较 `中  文`）、`not-outer-L`（`A \textcolor{red}{\mbox{}\EmptyNotOuter} B`，比较 `A  B`）、`not-outer-tail`（`中 \textcolor{red}{\mbox{}\EmptyNotOuter}`，比较 `中 `）。在 `aed1f9d2` 上这 3 项都失败（TEST 11 只在默认设置下执行一次）。
4. **补充：R6-M2 只修了一部分。** `\textcolor{red}{中 \mbox{}} 文` 的已知差异只写了 `xCJKecglue=false` 时直接输入 `{中 } 文` 为 23.33pt；`xCJKecglue=true` 时直接输入为 20.0pt，现在与修复前都是 26.66pt。已在 `doc-gaps.md` 与 architecture 补上 `true` 时的数值。

### 被放弃的做法

修 R7-I1 时先试过：命令之后的检查遇到未注册的宏就展开一层继续看，遇到未注册的原语就作废记录。这样 `A \def\x{}\mbox{} B`、`\setlength` 一类能修好，但 `\sbox` 之后的记录仍然被 resume 恢复，而且会改变以前所有“控制序列保留记录、交给外层”的行为，风险大，放弃。最终只在 `\sbox` 的适配器里清除记录。

### 新登记的已知限制

调查 R7-I1 时发现一类修复前不存在、现在无法区分的写法：空格与空命令之间只有不排出内容的命令或空分组（`A \sbox0{x}\mbox{} B`、`A \def\x{}\mbox{} B`、`A {}\mbox{} B`、`A \stepcounter{foo}\mbox{} B`）。命令之前的节点列表与 `A \mbox{} B` 相同，只能按后者处理，命令后的空格被删去（17.91pt，修复前与直接输入 21.24pt；两侧都是汉字时，`xCJKecglue=true` 下与直接输入一致；`xCJKecglue=false` 下同样少一枚空格（`中 \sbox0{x}\mbox{} 文`、`中 {}\mbox{} 文` 为 20.0pt，直接输入 23.33pt），但修复前多一枚（26.66pt），不算回退）。`aed1f9d2` 上已经如此（更早的提交没有逐一核对），与 `前{ }\mbox{} 后` 同属一类。已写入用户手册“CJK 文字与命令交互时的间距”一节的已知限制段落（例子 `A \sbox0{x}\mbox{} B`、`A {}\mbox{} B`），`\changes` 条目相应扩写，CHANGELOG 重新生成；登记在 `doc-gaps.md`。`xCJKecglue=true` 时第一个 `\mbox{}` 在列表里不留节点，`A \mbox{}\sbox0{x}\mbox{} B` 也落入这一类，所以新的 TEST 12 只在 `xCJKecglue=false` 下比较。

### 测试与验证

测试 `boundary-empty-space01` 由 3898 项增至 3903 项、13 个 TEST：`\START` 之后、所有 `\TEST` 之外写 `\color{red}\normalcolor`（`\TEST` 自己开一个分组，层数不为 0），不计入项数；TEST 11 改为上面的 3 项；新 TEST 12 “sbox between empty commands”（`xCJKecglue=false`，4 项：`mbox-sbox-mbox`、`mbox-sbox-tc`、`mbox-savebox-mbox`、`mbox-sbox-uline`），原零尺寸盒子一组顺延为 TEST 13。判别力：`61c313bd` 上分组层数 0 的 `\color` 报错；注释掉那一行后 TEST 12 的 4 项失败；`aed1f9d2` 上 TEST 11 的 3 项都失败（TEST 11 只在默认设置下执行一次）。

xeCJK 全部 126 个测试通过；`l3build doc` 通过，索引接受 4613 项、拒绝 0 项；siunitx 3.6.3 下 `siunitx-ecglue01` 为 576／576；外部矩阵 `tmp/i1103/r1probe/big.tex` 的结果与第六轮 head 完全相同，相对 `e641743e` 只有 3 项 `C-phantom-M/10` 不同（oracle 本身的问题，与以前一样）；xeCJKfntef 13 个线型命令的探针都与直接输入一致；第六轮的颜色探针除已登记的 `\textcolor{red}{中 \mbox{}} 文` 外都一致。

### 教训

- **哨兵值加一等于真实的分组层数 0。** 第六轮写“层数等于包装层数加一”时只想了 `\textcolor` 里面的情形，没有把不在包装里时的 -1 代入算一遍；读按层数拼出名字的变量之前也没有检查它是否存在。所有测试用例都包在 `\TEST` 或 `\hbox` 的分组里，分组层数 0 这个最常见的位置反而没有被执行过。凡是条件依赖分组层数的代码，至少要有一个用例写在所有分组之外。已提升到 `memory/lessons-learned.md`。
- **恢复全局状态之前，要问状态是否已经过期。** 第六轮的教训是暂停机制要保存、恢复所有被改动的全局状态，这对命令内部的测量盒子成立；`\sbox` 也用同一套机制，但它是源码里独立的命令，命令结束之后，之前的记录已经与后面的源码空格不相邻。把一项状态加进共用机制时，要逐个检查所有调用者，区分“命令内部的暂停”与“独立命令的暂停”。已并入 `memory/lessons-learned.md`「暂停观察的机制要保存、恢复所有会被改动的全局状态」。
- **新测试要在被替换的版本上运行一次。** TEST 11 是为防止“子串查找误判 `\outer...` 宏”而加的，却没有在子串查找版本 `aed1f9d2` 上运行确认会失败；记录被后面的汉字清除，误判不影响结果。这是“回归测试须以重新引入缺陷的方式确认会失败”的又一次实例：用例要让被测的判断直接决定可观察的结果，这里是把宏放在颜色命令正文末尾，让记录必须交给外层。
- **修一处时发现的“无法区分”要与已有的同类限制放在一起登记。** `A \sbox0{x}\mbox{} B` 一类与 `X{ }\cmd Y` 原因相同，都是命令之前的节点列表相同；登记时并入用户手册同一段，而不是另开说明。

## 本地审查第八轮

第七轮修复提交为 `870661c8`。本地审查第八轮（增量，`61c313bd..870661c8`，run `r8-incr-073140`）结论 COMMENT，阻塞 0、重要 0、小问题 1；补充报告另报一项范围外的新观察，按重要问题处理（机制见 `llmdoc/architecture/xecjk-empty-output-space.md`「align-safe 分组」「仍不一致的写法」）：

1. **小问题（R8-M1）：第七轮登记的无法区分写法，把两侧都是汉字时的结果写错了。** architecture「仍不一致的写法」、`doc-gaps.md` 与本反思第七轮一节都写“两侧都是汉字时与直接输入一致”。实测只在 `xCJKecglue=true` 时成立；`xCJKecglue=false` 下 `中 \sbox0{x}\mbox{} 文`、`中 {}\mbox{} 文` 为 20.0pt，直接输入 23.33pt，同样少一枚空格，但修复前是 26.66pt（多一枚），不算回退。三处已改为按设置分别描述。
2. **范围外的新观察（R8S-I1，按重要问题处理）：空命令之后紧跟 `\outer` 宏、宏后面还有文字时报 `Forbidden control sequence`。** `A \mbox{}\OA B`（`\OA` 用 `\outer\def` 定义为空）报错；修复前 `e641743e` 与直接输入 `A \OA B` 都不报错。问题从 #1103 第一个提交 `e2c2695f` 起就存在；TEST 9 的写法都以 `}` 结尾，所以没有发现，`doc-gaps.md` 也因此写成命令之后的检查“现在不报错”。原因：命令之后的检查用 `\peek_after:Nw`（`\futurelet`）看下一个记号，`\l_peek_token` 等同于这个 `\outer` 记号，自己也成了 `\outer`。`\__xeCJK_boundary_if_peek_outer:TF` 认出它、作废记录后，`\l_peek_token` 仍是 `\outer`；`\OA` 展开为空，下一个字符 `B` 触发 Boundary 到 Default 的 interchar 代码 `\peek_meaning_remove:NTF \tex_italiccorrection:D {...}{\token_if_space:NTF \l_peek_token ...}`，扫描这段参数时碰到 `\l_peek_token`，报错。删去命令之后的空格时（`A \mbox{} \OA B`），`\peek_remove_spaces:n` 也把 `\l_peek_token` 留成下一个非空格记号，同样报错。修复：新增 `\__xeCJK_boundary_peek_token_clear:`（`\tex_let:D \l_peek_token \scan_stop:`）；`\__xeCJK_boundary_if_peek_outer:w` 的真分支先调用它再 `\prg_return_true:`；`drop` 为假、删去空格之后不再看下一个记号的分支由 `\peek_remove_spaces:n { }` 改为 `\peek_remove_spaces:n { \__xeCJK_boundary_peek_token_clear: }`。清除写在单独的宏里，宏体照常执行，不经过参数扫描。

仍报错、与修复前相同（不是本修复引入）：直接输入 `中 \OA 文`，报错来自 xeCJK 汉字之后的前视，`doc-gaps.md` 已登记。

### 测试与验证

`boundary-empty-space01` 由 3903 项增至 3907 项，仍为 13 个 TEST，0 失败。TEST 9 由 5 项增至 9 项，新增：`outer-text-L`（`A \mbox{}\EmptyOuterA B`，比较 `A \EmptyOuterA B`）、`outer-space-L`（`A \mbox{} \EmptyOuterD B`）、`outer-text-tc`（`A \textcolor{red}{}\EmptyOuterB B`），后两项也比较 `A \EmptyOuterA B`；`outer-text-C`（`中 \mbox{}\EmptyOuterC 文`）比较宽度相同的 `中 \relax 文`，因为直接输入 `中 \EmptyOuterC 文` 在汉字之后的前视里报错。判别力：`61c313bd` 上新用例报 `Forbidden control sequence`。

xeCJK 全部 126 个测试通过；`l3build doc` 通过，索引接受 4686 项、拒绝 0 项；siunitx 3.6.3 下 `siunitx-ecglue01` 为 576／576；外部矩阵 `tmp/i1103/r1probe/big.tex` 的结果与第七轮 head `870661c8` 完全相同，相对修复前 `e641743e` 只有 3 项 `C-phantom-M/10` 不同（oracle 本身的问题）；xeCJKfntef 线型命令探针全部与直接输入一致，颜色探针除已登记的 tc-mboxC 外都一致；第七轮的 `\sbox`、空分组等探针结果与第七轮相同（只剩已写入用户手册的无法区分写法）。

### 教训

- **第四轮修 `\outer` 时只测了以 `}` 结尾的写法。** 第四轮的 `\endtemplate`、第五轮和第六轮的 TEST 9 都让 `\outer` 记号出现在盒子或单元格末尾，后面没有字符，所以从来没有执行到“认出之后还有代码读 `\l_peek_token`”这一步。检查认出一个危险记号之后，要问它留下的状态（这里是共用变量 `\l_peek_token`）还会被谁读到，并让测试覆盖“危险记号之后还有内容”的写法。已并入 `memory/lessons-learned.md`「`\l_peek_token` 可能是 `\outer` 记号」。
- **`\l_peek_token` 是共用的变量，不只属于自己的代码。** 前几轮的规则只要求“自己的判断不把它交给以它为参数的函数”，没有考虑别的模块（xeCJK 的 interchar 代码）也会在参数里写它。修改共用变量的含义（或者让它保留一个危险的含义）时，要考虑之后所有读它的代码，最简单的办法是用完之后改回无害的值。
- **范围外的新观察也要处理。** R8S-I1 不在本轮增量范围内，也不是第七轮引入的，但它是 #1103 引入、修复前不存在的报错。补充报告里的观察要和正式问题一样判断真假，确认存在就修。
- **登记“现在不报错”时要写明覆盖了哪些写法。** `doc-gaps.md` 的说法只对以 `}` 结尾的写法成立，却写成了一般的结论。这与第六轮“登记仍不一致的写法时要写明实测所在的提交”是同一类问题：登记结论时连同实测的输入范围一起写下。R8-M1 也是同类：只在一种设置下实测，就写成了两种设置都成立的结论。

## 本地审查第九轮

第八轮修复提交为 `45e4a2f7`。本地审查第九轮（增量，`870661c8..45e4a2f7`，run `r9-incr-081016`）报告 1 项阻塞问题，补充报告确认 R8-M1、R8S-I1 已修复、其余 25 项仍成立。

1. **阻塞（R9-B1）：删去空格之后在 align-safe 分组之外清除 `\l_peek_token`。** 第八轮把 `drop` 为假的分支改为 `\peek_remove_spaces:n { \__xeCJK_boundary_peek_token_clear: }`。这个回调在 `\peek_remove_spaces:n` 结束 align-safe 分组之后执行；左侧是西文、命令之后有空格、接着是 `&`、`\cr`、`\span` 时，`\l_peek_token` 等同于这个对齐记号，`\tex_let:D` 读到它，TeX 插入列模板的结尾。tabular 里 `A \mbox{} & B`（以及 `\textcolor{red}{}`、`\hypertarget{a}{}`、`\uline{}`、`\unit{}`、用户注册的命令）报 `Extra alignment tab has been changed to \cr`；plain `\halign` 的 `A \mbox{} &C\cr`、`A \mbox{} \cr`、`A \mbox{} \span C\cr` 报 `Missing control sequence inserted`。修复前 `e641743e` 与 `870661c8` 都不报错。修复：回调改为 `\group_align_safe_begin: \__xeCJK_boundary_peek_token_clear: \group_align_safe_end:`。左侧是汉字时 `drop` 为真、不走这个分支，以前的 tabular 用例（TEST 6）与 `\halign` 用例（TEST 7）左侧都是汉字或命令之后没有空格，所以没有覆盖。

### 测试与验证

`boundary-empty-space01` 由 3907 项增至 3914 项、14 个 TEST：新增“empty command after a latin letter at the end of a tabular cell”（左侧是西文的 tabular 单元格，比较对象是命令之后不写空格的同一行；`l` 列模板末尾的 `\unskip` 被命令留下的节点挡住，删去命令的直接输入总是更窄，修复前也如此），原 `\halign` TEST 新增 6 项西文、命令之后有空格的写法。`45e4a2f7` 上新 TEST 报 `Extra alignment tab`。xeCJK 全部 126 个测试通过；`l3build doc` 通过，索引接受 4683 项、拒绝 0 项；siunitx 3.6.3 下 `siunitx-ecglue01` 为 576／576；外部矩阵与 `45e4a2f7` 完全相同；第八轮的 `\outer` 探针除修复前就报错的直接输入 `中 \OA 文` 外都不报错。

### 教训

- **给 `\l_peek_token` 赋值也是读取它。** 第八轮的教训是“认出 `\outer` 记号之后清除 `\l_peek_token`”，写清除代码时只想到它不经过参数扫描，没有想到 `\let` 本身读取右侧的记号，等同于对齐记号时同样触发列模板的结尾。这与第一、二轮的 R1-B1、R2-B1 根因相同：在 align-safe 分组之外读 `\l_peek_token`。修补一个“读 `\l_peek_token`”的问题时，新写的代码要用同一条规则检查一遍。
- **每个分支都要配一组表格用例。** 第一轮起的表格用例左侧都是汉字，走 `drop` 为真的分支；`drop` 为假的分支（左侧是西文、`{中}`、`A{}` 等）在表格里没有用例。新增或修改一个分支时，表格、`\halign`、`\outer` 宏这几类“下一个记号特殊”的用例要按分支各配一组。

## 本地审查第十轮

第九轮修复提交为 `44f39b2c`。本地审查第十轮（增量，`45e4a2f7..44f39b2c`，run `r10-incr-083910`）结论 COMMENT，阻塞 0、重要 0、小问题 3：

1. **小问题（R10-M1）：新 TEST 插在 `\halign` 注释与 `\EmptyAlign` 之间。** 已把 tabular 西文一组移到那两行注释之前。
2. **小问题（R10-M2）：tabular 西文一组的比较对象与注释不对。** 注释说删去命令的直接输入比任何带命令的写法窄，实测只有 `\mbox{}`、`\textcolor{red}{}`、transparent、box 命令留下的节点挡住 `l` 列模板末尾的 `\unskip`；`\hypertarget`、`\uline`、`\unit`、`\numlist`、stream 命令与直接输入同宽。整张表的宽度由最宽的 `\mbox{}` 行决定，其他行的宽度变化测不出来，这组在修复前 `e641743e` 上也通过。改为每个命令单独排一张表（`\EmptyTabCell`），按命令是否留下节点选择比较对象；修复前 `e641743e` 上后 5 项宽度失败。
3. **小问题（R10-M3）：llmdoc 里的 TEST 编号没有随插入的 TEST 顺延。** architecture 与 doc-gaps 共 6 处改为用 TEST 名称引用。

`boundary-empty-space01` 由 3914 项增至 3922 项，仍为 14 个 TEST，0 失败。

### 教训

- **整体比较会掩盖局部差异。** 一张多行表格只比较整表宽度，最宽的一行决定结果，其他行的变化测不出来。每个比较应只包含一个被测写法；这与“oracle 用直接输入”的规则是同一个要求：比较对象要能区分被测写法的对错。
- **引用测试用名称，不用编号。** 插入一个 TEST 会让后面的编号全部变化，用编号引用的文档会一起过时。

## 本地审查第十一轮

第十轮修复提交为 `5878160a`。本地审查第十一轮（增量，`44f39b2c..5878160a`，run `r11-incr-092451`）结论 COMMENT，阻塞 0、重要 0、小问题 2：

1. **小问题（R11-M1）：`build-and-test.md` 的 TEST 列表仍用第八轮时的编号。** 第十轮只改了 architecture 与 doc-gaps，build-and-test 里同一段出现两个 TEST 7、之后的编号都比 `.tlg` 小一，`index.md` 却写“文档里的 TEST 编号改用名称引用”。已按当前 `.tlg` 重排列表，每条括号里注明旧编号；“判别力”一段保留当时的编号并注明；index 的说法改为具体范围。
2. **小问题（R11-M2）：西文 tabular 单元格末尾的差异没有登记。** `A \mbox{} & B` 修复前与现在都比直接输入 `A  & B` 宽一枚空格（`l` 列模板末尾的 `\unskip` 被命令留下的节点挡住），不是回退，但 doc-gaps 与测试头注释的“仍不一致”列表都没有它。已补登。

教训：把“改用名称引用”写进摘要之前，要对所有引用编号的文档做一次 grep，而不是只改审查者点到的几处；第十轮的教训（引用测试用名称）本身也要按这个规则检查。

## 本地审查第十二轮

第十一轮修复提交为 `d0cbe149`。本地审查第十二轮（增量，`5878160a..d0cbe149`，run `r12-incr-093620`）结论 COMMENT，阻塞 0、重要 0、小问题 2，都是剩余的旧编号：`build-and-test.md`「判别力」一段的“当时的 TEST 9（现 TEST 10）”应为现 TEST 11，零尺寸盒子一条缺“第九轮前为 TEST 13”，`\halign` 一条末尾的注记重复；`lessons-learned.md` 一处仍写 TEST 9。已改正，`lessons-learned.md` 改用 TEST 名称。第十一轮写下“改名前先 grep 全部文档”，自己仍没有 grep 到 `lessons-learned.md`：grep 时要用测试文件名与测试名两个关键词，而不是只看审查者提到的文件。

## 本地审查第十三轮

第十二轮修复提交为 `2ddac91b`。本地审查第十三轮（增量，`d0cbe149..2ddac91b`，run `r13-incr-095037`）结论 COMMENT，阻塞 0、重要 0、小问题 1：`build-and-test.md`「审查者的独立矩阵更宽」一段仍用旧编号（“上面的 TEST 7”“上面的 TEST 10 与 TEST 8”等），且没有注明。已按当前 `.tlg` 改正并注明；本反思开头加一行说明各轮小节用写下时的编号。

## 本地审查第十四轮

第十三轮修复提交为 `5ed3672c`。本地审查第十四轮（增量，`2ddac91b..5ed3672c`，run `r14-incr-100734`）结论 COMMENT，阻塞 0、重要 0、小问题 1：反思开头新加的说明只给了第九轮的一条换算，对第二、四、五、六轮小节里的编号不成立。修复提交 `5336949d` 改为列出插入过 TEST 的轮次、按名称查 build-and-test 的旧编号注记，但当时只列了第四、五、六、七、九轮，漏了第二轮（见第十五轮）。

## 本地审查第十五轮

第十四轮修复提交为 `5336949d`。本地审查第十五轮（增量，`5ed3672c..5336949d`，run `r15-incr-101525`）结论 COMMENT，阻塞 0、重要 0、小问题 1：开头列出插入过 TEST 的轮次时漏了第二轮（`682d6e08` 在零尺寸盒子一组之前插入 `\halign` 一组），第十四轮小节写“各轮都插入过 TEST”又说过了头。修复提交 `e14877cd` 补上第二轮，并改写第十四轮小节（改写里的问题见第十六轮）。

## 本地审查第十六轮

第十五轮修复提交为 `e14877cd`。本地审查第十六轮（增量，`5336949d..e14877cd`，run `r16-incr-102130`）结论 COMMENT，阻塞 0、重要 0、小问题 1：`e14877cd` 改写第十四轮小节时把修复提交 `5336949d` 写成已列出第二轮，实际 `5336949d` 只列了第四、五、六、七、九轮，与第十五轮小节矛盾。修复提交 `18dd1929` 改为如实记录 `5336949d` 漏了第二轮。

## 本地审查第十七轮

本地审查第十七轮（增量，`e14877cd..18dd1929`，run `r17-incr-102711`）结论 COMMENT，阻塞 0、重要 0、小问题 1：`18dd1929` 没有新增第十六轮小节，而是改写第十五轮小节的末句，在其中记下第十六轮的修复，第十五轮小节因此混进了下一轮的修复内容。已补上第十六轮小节，第十五轮小节只保留本轮的修复。

教训：每轮审查都在本文件里单独记一节，修复写在指出它的那一轮下面，不要回头改写前一轮的小节去记录后一轮的修复。

## 本地审查第十八轮

第十七轮修复提交为 `ccd430cb`。本地审查第十八轮（增量，`18dd1929..ccd430cb`，run `r18-incr-103143`）结论 COMMENT，阻塞 0、重要 0、小问题 1：第十七轮小节与 `ccd430cb` 的提交说明都写 `18dd1929`“用括号补记”，与 git 历史不符。修复提交 `4aa1e896` 把它改成“在第十五轮小节末尾追加一句”，仍与 git 历史不符（见第十九轮）；`ccd430cb` 的提交说明不改写历史去修正，以本节为准。

## 本地审查第十九轮

第十八轮修复提交为 `4aa1e896`。本地审查第十九轮（增量，`ccd430cb..4aa1e896`，run `r19-incr-103702`）结论 COMMENT，阻塞 0、重要 0、小问题 1：第十七、十八轮小节说 `18dd1929` 在第十五轮小节末尾“追加”了一句，git 历史显示它先把原来的末句改写，再接上新句子。已改为“改写第十五轮小节的末句”，只描述结果，不再描述编辑的具体步骤。

教训：在记录里转述某个提交做了什么时，先用 `git show` 看实际的差异再写；只写它造成的结果，避免“追加”“用括号”这类容易与差异不符的细节。
