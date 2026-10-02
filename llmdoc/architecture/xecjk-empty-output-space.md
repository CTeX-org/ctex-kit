# 没有可见输出的命令与命令之后的源码空格（#1103）

本文说明 capture/register 框架里“已注册命令执行后没有可见输出”这一条结束路径：入口空格怎样重放，命令之后紧跟的源码空格由谁删去。框架的整体结构见 [[xecjk-architecture]]「capture/register 框架」；过程与教训见 [[../memory/reflections/1103-empty-output-after-space]]。实现都在 `xeCJK/xeCJK.dtx`。

## 比较基准

oracle 仍是 #992 的直接输入：把命令从源码中删去后的写法（[[../memory/decisions/992-command-boundary-capture-register]]）。没有可见输出时，删去命令会让两侧的源码空格相邻，TeX 把它们读成**一个**空格记号：`中 \cmd 文` 对应 `中  文`，即只有一处空格。

#1103 之前，capture 结束时 `\@@_boundary_replay_before:` 把入口取下的空格放回，命令之后的空格又排出一枚，两枚都留在列表里。两侧都是汉字时多出两枚空格的宽度（`中 \mbox{} 文` 为 26.66pt，直接输入 20.0pt）；入口前不是汉字时多一枚（`A \cmd B`、`$x$ \cmd 文`）。下文的“修复前”指 `e641743e`：它是原基准 `25a33aef` rebase 到含 #1104 的 master 后的对应提交。

修法拆成两部分，原因是重放发生在命令的结束钩子里，命令自己的代码这时可能还没执行完，后面的源码空格在这一刻还处理不了：

1. 结束时只决定 marker 与入口 glue（`\@@_boundary_replay_before_empty:`）。
2. 命令真正结束之后，用 peek 检查下一个记号，删去紧跟的空格（`\@@_boundary_after_space_check:`）。

## capture 的两个新字段

每层 capture 在 `\@@_boundary_capture_allocate:n` 时新建：

- `g_@@_boundary_capture_<n>_space_glue_tl`：`\@@_boundary_capture_space:` 刚取下入口 glue 时 `space_flag` 字段的值，表示入口是否取下了一枚真实的词间 glue。不能直接用 `space_flag`：入口前是 `CJK-space` marker 时，`space_flag` 随后会被改为真，两种情形就分不开了。取下 glue 之后列表末尾是 penalty（`\lastnodetype` 为 13）时记为 `false`：这枚 glue 来自 `~`、`\nobreakspace{}`，不是命令左侧的源码空格，命令之后的空格要照常保留（`中~ \mbox{} 文`，本地审查第一轮以前误删）。
- `g_@@_boundary_capture_<n>_after_space_tl`：capture 开始时内层留下的记录是否仍然有效（`\@@_boundary_after_space_if_armed:TF`）。用于 `\textcolor{red}{}` 这类嵌套空命令：入口空格由内层的颜色命令记下，实际属于外层命令，外层要能把记录接过来。

`\@@_boundary_capture_begin:` 先读取上述有效性，再清除全局记录 `\g_@@_boundary_after_space_bool`，所以下一个 capture 开始时旧记录总会失效。新的 marker 排出时（`\xeCJK_make_node:n`、`\@@_make_space_node:`）也清除这条记录：命令之后又排出了字符，后面的空格属于这个字符。以前检查遇到控制序列时把记录留给外层，命令之后接着排出别的内容时，记录仍保留到下一个 capture 开始，可能被后面的命令误当作内层留下的记录接过来（如 `中~ \RegStream{}\hbox{x}` 之后的下一段，本地审查第一轮发现）。

### 暂停 capture 观察期间排出的 marker

有些代码把字符排进只用来测量或随即丢弃的盒子：ulem 的 `\UL@end` 吃掉定界符后留下的 `*`、`\UL@setULdepth` 量深度用的 `(j`、`\markoverwith` 量装饰符号宽度用的字符（`\uwave` 的 `\char58`、`\xout` 的 `/`、`\dotuline` 的 `.`）、`\sbox` 与 `\xeCJK_fntef_sbox:n` 里的内容。这些字符同样触发 interchar 转换，`\xeCJK_make_node:n` 排出 marker 时会清除上面的记录；它们不在最终的列表里，记录却丢了。`中 \textcolor{red}{\uline{}} 文` 里内层 `\uline{}` 记下、应交给外层的记录因此丢失，结果为 26.66pt，直接输入 20.0pt（本地审查第六轮的重要问题，第五轮来源编号修复的副作用；`\uuline`、`\uwave`、`\xout`、`\dashuline`、`\dotuline` 同样）。

这些位置都由 `\@@_boundary_capture_suspend:`／`\@@_boundary_capture_resume:` 包住。暂停可以嵌套，按暂停层数保存、恢复三项全局状态：`\g_@@_last_node_tl`、source-space pending（`\g_@@_glue_check_pending_bool`），以及 `\g_@@_boundary_after_space_bool`（保存在 `g_@@_boundary_suspend_<n>_after_space_tl`，第六轮新增）。xeCJKfntef 还包装了 `\markoverwith`（原定义存为 `\@@_ulem_orig_markoverwith:n`），在测量期间暂停观察，做法与 `\UL@setULdepth` 的包装相同。`\uline` 不经过 `\markoverwith`，它的问题只来自 `*` 与 `(j`，由第一项改动解决。

**`\sbox` 适配器在盒子赋值之后清除记录**（本地审查第七轮）。线型命令内部的暂停（`\UL@end`、`\UL@setULdepth`、`\markoverwith`、`\xeCJK_fntef_sbox:n`）发生在命令内部，命令结束时还要把记录交给外层，所以 resume 恢复记录是对的。`\sbox`／`\savebox` 的适配器 `\@@_boundary_sbox:Nn` 也走暂停与恢复，但它是源码里独立的一条命令：`\sbox` 之后的源码空格已经不与它前面的命令相邻。以前 `\sbox` 里的内容排出 marker，清除了前一个命令的记录，第二个命令不会删空格；第六轮让 resume 恢复记录之后，`A \mbox{}\sbox0{x}\mbox{} B` 里第二个 `\mbox{}` 之后的检查又删去了第一个 `\mbox{}` 之后的空格，为 17.91pt，直接输入 `A \sbox0{x} B` 与修复前 `e641743e`、第五轮 `aed1f9d2` 都是 21.24pt（`xCJKecglue=false`；`\sbox0{}`、`\savebox`，或第二个命令换成 `\textcolor{red}{}`、`\uline{}` 同样）。现在 `\@@_boundary_sbox:Nn` 在 `\tex_setbox:D` 赋值之后执行 `\bool_gset_false:N \g_@@_boundary_after_space_bool`。

第七轮曾试过另一种做法并放弃：命令之后的检查遇到未注册的宏就展开一层继续看、遇到未注册的原语就作废记录。这能修好 `\def`、`\setlength` 一类，但 `\sbox` 之后的记录仍会被 resume 恢复，而且改变了以前所有“控制序列保留记录、交给外层”的行为，风险大。规则：**暂停与恢复全局状态的机制用于命令内部时，恢复的状态仍然有效；用于源码里独立的命令（`\sbox`）时，恢复的状态可能已经过期，要在命令结束时按它与后续源码的关系单独处理。**

第六轮曾试过另一种做法并放弃：让 `\xeCJK_make_node:n`、`\@@_make_space_node:` 只在当前分组层数不深于记录所在层数时清除记录。这样上一次排版留下的过期记录会在更浅的分组里存活，`boundary-empty-space01` 的 `tie-hbox/*/01`（`中~\cmd{} \hbox{x}`）20 项失败（18.61pt，应为 21.94pt）。规则：**这条记录是全局的，不能按分组层数决定是否清除；在丢弃或测量用的盒子里排出的 marker，由暂停机制保存、恢复它会改动的全部全局状态来处理。**

## 结束时的重放：`\@@_boundary_replay_before_empty:`

调用点（都是“capture 没有观察到任何类别”的情形）：

- `\@@_boundary_inline_stream_end:n`：首类别为空、`entry` 字段不是 `resolved` 时（`resolved` 时仍按 #1091 的规则只重放 `math` 或调用 `\@@_boundary_resolved_end_hook:`）。
- `\@@_boundary_hmode_transparent_finish:`：由 `\@@_boundary_hmode_transparent_end:` 与颜色推入命令的 `\@@_boundary_hmode_transparent_push_end:` 调用（本地审查第五轮从 `_end:` 拆出，`_end:` 是 finish 加 after_space_check）。
- `\@@_boundary_box_end_transparent:n`：`\@@_boundary_if_capture_box_empty:TF` 为真时（`\l_@@_boundary_box_empty_bool`，判据见下文「透明盒子“没有可见输出”的判据」）。

不调用、仍用原来的 `\@@_boundary_replay_before:` 的路径：`\@@_boundary_last_box_end:n` 末节点不是 hlist 的分支，以及有可见输出的透明盒子。这些情形里命令确实排出了东西，入口空格与命令之后的空格不相邻。

做法分三种：

- 入口前是 `CJK-space` marker、没有取下 glue（`中 \cmd`）：汉字后的源码空格已被前视吃掉，列表里只有 marker。直接输入 `中 X` 也只留 marker，所以只重放 `CJK-space` marker、清除 `\g_@@_glue_check_pending_bool`，不排出空格 glue。
- `space_glue` 为真（`{中} \cmd`、`A \cmd`）：照常调用 `\@@_boundary_replay_before:` 放回 marker 与 glue。
- 以上两种都转到 `\@@_boundary_replay_before_empty_arm:`，由它调用 `\@@_boundary_after_space_arm:` 记下状态（颜色弹出命令例外，见下一小节）。其余情形照常重放；若本层 `after_space` 为真（从内层接过记录），调用 `\@@_boundary_after_space_rearm:` 把记录交给更外一层。

### 颜色弹出命令只转交配对的推入命令留下的记录

`\reset@color` 与 l3color 的 `\__color_backend_reset:` 由 `\aftergroup` 在分组结束之后执行。它们的入口取下的 glue 是分组里正文末尾的空格，不是命令左侧的源码空格：`\textcolor{red}{A } B` 删去颜色命令后是 `{A } B`，两枚空格都保留（21.24pt）。第四轮以前这枚 glue 被当作命令左侧的源码空格，` B` 前的空格被删去（17.91pt），相对修复前 `e641743e` 是回退（最终全范围审查第四轮的阻塞问题；`{\color{red}red } text` 同理）。

弹出命令自己不记下记录，但要能转交内层留下的记录：`中 \textcolor{red}{} 文` 删去命令后是 `中  文`，`\set@color` 记下的入口空格属于外层，`\reset@color` 要把它交出去。第四轮的做法是“本层 `after_space` 为真就转交”，但记录可能来自正文里的其他命令：`\textcolor{red}{A \mbox{}} B` 的记录由 `\mbox{}` 记下，入口空格是正文里的空格，删去 `\mbox{}` 后是 `{A } B`，两枚空格都保留；转交之后 ` B` 前的空格被删去（17.91pt，修复前与直接输入 21.24pt；本地审查第五轮的阻塞问题）。正文末尾是 `\hypertarget{x}{}`、`\phantomsection`、`\unit{}`、`\uline{}`、内层 `\textcolor{blue}{}`，或写成 `{\color{red}A \mbox{}} B`、`\uline{\textcolor{red}{A \mbox{}} B}`、用户分组 `A {\color{red}} B`，都是同一问题。

现在按“来源编号 + 分组层数”配对：

- **来源编号**：`\@@_boundary_after_space_arm:` 在本层 `after_space` 不为真时（记下的是本层入口取下的新空格）递增 `\g_@@_boundary_after_space_id_int` 并写入 `\g_@@_boundary_after_space_origin_int`；本层 `after_space` 为真时，入口空格来自内层已经记下的那一条（`\textcolor{red}{\mbox{}}` 里的 `\mbox`、配对成功的弹出命令），编号不变。`\@@_boundary_after_space_rearm:` 也不改编号。最初 arm 总是分配新编号，`中 \textcolor{red}{\mbox{}} 文` 因此在弹出时配对失败、多一枚空格（审查者矩阵上 612 项），本地验证时发现后改正。
- **推入命令**：`\set@color` 改用 `\@@_boundary_register_transparent_push:n` 注册，before 钩子是 `\@@_boundary_hmode_transparent_kind_begin:n { transparent-push }`（`kind` 记为 `transparent-push`，其余代码只特殊处理 `transparent-pop`，这个值走普通路径），after 钩子是 `\@@_boundary_hmode_transparent_push_end:`。push_end 先做 finish（重放与 arm），若当前分组层数等于 `\l_@@_boundary_textcolor_level_int` 加一、`\g_@@_boundary_color_origin_<包装层数>_tl` **存在**、**且**它仍是 `?`，把当前记录的来源编号（没有有效记录时为空）存进这个变量，最后做 after_space_check。三个条件由 `\bool_lazy_all:nT` 依次求值，存在性检查（`\tl_if_exist_p:c`）排在用 `\tl_use:c` 读值之前。
- **只有第一个推入命令存编号**：正文里的 `\color`、`\normalcolor` 也调用 `\set@color`，层数同样是包装层数加一。第五轮的 push_end 只比较层数，正文里最后一个推入命令会覆盖 `\textcolor` 自己存下的编号，`\reset@color` 配对失败：`\textcolor{red}{A \color{blue}} B`、`\textcolor{red}{A \color{blue}\mbox{}} B`、`\textcolor{red}{A \normalcolor} B` 为 17.91pt，修复前与直接输入 `{A } B` 都是 21.24pt（本地审查第六轮的阻塞问题）。现在包装在调用原 `\textcolor` 之前把本层的变量设为 `?`（不存在时先 `\tl_new:c`），push_end 只在值仍是 `?` 时存编号，所以只有 `\textcolor` 自己的 `\set@color`（第一个推入命令）存下编号。
- **先检查变量是否存在**：不在 `\textcolor` 里时 `\l_@@_boundary_textcolor_level_int` 是 -1，分组层数 0 的 `\color`（`\begin{document}` 之后直接写 `\color{blue}`，或段落里的 `中 \color{red} 文`）也满足“层数等于包装层数加一”。第六轮的 push_end 随即用 `\tl_use:c` 读 `\g__xeCJK_boundary_color_origin_-1_tl`，这个变量只由 `\textcolor` 包装创建，从未存在，报 `Erroneous variable`（color 与 xcolor 都如此；`aed1f9d2` 与修复前 `e641743e` 都不报错，本地审查第七轮的阻塞问题）。以前测试里的颜色用例都在 `\hbox` 或 `\TEST` 的分组里，层数不为 0，没有发现。规则：**读按层数拼出名字的变量之前先检查它是否存在；哨兵值 -1 加一等于 0，与真实的分组层数 0 相同。**
- **包装层数**：`\@@_boundary_textcolor:nnn` 的非公式分支在调用原 `\textcolor` 之前把 `\l_@@_boundary_textcolor_level_int` 设为当前分组层数（并把上面的变量设为 `?`），之后设回 -1（初值 -1）。它是局部变量：嵌套的内层 `\textcolor` 在外层的分组里设置和设回，外层分组结束、外层的 `\reset@color` 执行时，TeX 已恢复外层记下的值。`\set@color` 在 `\textcolor` 自己的分组里执行，所以层数正好深一层；`\reset@color` 在分组结束后执行，层数等于包装层数。
- **弹出命令**：`\reset@color` 用 `\@@_boundary_register_transparent_pop:n` 注册，before 钩子是 `\@@_boundary_hmode_transparent_pop_begin:`；`\__color_backend_reset:` 的包装也用它。它在 `\@@_boundary_hmode_transparent_kind_begin:n { transparent-pop }` 开始 capture（capture 开始时会清除全局记录）**之前**先判断是否配对：记录有效、当前层数等于包装层数、且当前记录的来源编号等于 `\g_@@_boundary_color_origin_<当前层数>_tl`。不配对且本层 capture 处于活动状态时，把本层 `after_space` 字段改为 `false`，这样 `\@@_boundary_replay_before_empty:` 不 rearm。
- **重放**：`\@@_boundary_replay_before_empty_arm:` 在 `kind` 为 `transparent-pop` 且本层 `after_space` 不为 `true` 时只调用 `\@@_boundary_replay_before:`，不记下记录；其余情形（包括配对成功、`after_space` 为真的弹出命令）走原有路径：`space_glue` 为真时调用 `\@@_boundary_replay_before:`，否则只重放 `CJK-space` marker 并清 pending，然后调用 `\@@_boundary_after_space_arm:`。

结果：`\textcolor{red}{}` 里 `\set@color` 的记录在 `\reset@color` 时编号仍相同，照常转交；正文里其他命令记下的记录编号不同，不转交。不经过 `\textcolor` 包装的 `\color`（用户分组 `A {\color{red}} B`，删去颜色命令后还剩 `A {} B`）与 l3color 的包装层数是 -1，永远不配对，不转交。新增的两个全局整数与一个局部整数让 `loading01.tlg` 多三行。

规则：**由 `\aftergroup` 执行的命令看到的列表末尾属于已经结束的分组**，入口取下的 glue 不能当作命令左侧的源码空格；**转交记录之前要确认记录是谁记下的**，“有没有记录”不能代替“记录从哪来”。

### 透明盒子“没有可见输出”的判据

`\@@_boundary_if_capture_box_empty:TF` 要求两个条件：

1. 盒子的宽、高、深**分别**为零（`\@@_boundary_if_box_zero:NTF`）。以前比较三者之和，正负值相互抵消时会误判。
2. 在探测盒子 `\l_@@_boundary_probe_box` 里拆开盒子的副本，由 `\@@_boundary_box_empty_probe:` 从末尾向前检查：glue、kern、penalty 由 `\@@_boundary_box_empty_probe_remove:N` 删去后继续；末尾是 hlist 时用 `\box_set_to_last:N` 取到 `\l_@@_boundary_probe_inner_box`，是零尺寸的 hbox 就拆开继续检查；列表变空时（`\g_@@_boundary_probe_type_int` 为 -1）才算没有可见输出。字符、规则、公式、非零尺寸的盒子、vbox，以及无法从列表中删去的 whatsit 都按有可见输出处理，与以前相同。

第 2 条的原因：`\smash`、`\rlap` 得到的零尺寸盒子里仍可能有重叠排出的内容。`\mbox{\smash{\rlap{\rule{2pt}{1pt}}}}` 以前被当成空盒子，命令之后的空格被删去。新增的寄存器 `\l__xeCJK_boundary_probe_inner_box` 让 `loading01.tlg` 多一行。

探测必须在删不掉节点时停下（本地审查第二轮的重要问题）。列表末尾的节点属于前面某个 `\discretionary` 的不断行文本时，`\unskip`、`\unkern`、`\unpenalty` 不删去它，`\lastnodetype` 不变，以前的探测因此无限递归：`A \mbox{\discretionary{}{}{\kern0pt}} B` 报 `TeX capacity exceeded`。现在：

- `\@@_boundary_box_empty_probe_remove:N` 限制删除次数（每次探测从零计数，第 64 次起不再删除），超过限制就停下，按有可见输出处理。最初的做法是比较删除前后的末尾状态（`\lastnodetype`、`\lastkern`、`\lastskip`、`\lastpenalty`），相同就停下；但 `\makebox[0pt]{}` 里是两枚相同的 fil glue，删去一枚后末尾状态也不变，被误判为有输出，这种盒子两侧的空格又回到修复前的结果（审查者矩阵上 858 项），所以改为计数。
- `\box_set_to_last:N` 取到空盒子（末尾的盒子删不掉）或取到的不是 hbox 时停下；取到非零尺寸的 hbox 时用 `\box_use_drop:N` 放回再停下。两种情形都按有可见输出处理。

## 记录：arm、rearm 与两个标志

记录是一个全局布尔量加一个 token list：`\g_@@_boundary_after_space_tl` 的内容为“外层层号（当前层号减一）；`\lastnodetype`、`\lastkern`、`\lastskip`”，由 `\@@_boundary_after_space_rearm:` 写入，状态部分由可展开的 `\@@_boundary_after_space_state:` 生成。`\@@_boundary_after_space_arm:` 先调用 rearm，再分配新的来源编号（见上文「颜色弹出命令只转交配对的推入命令留下的记录」），然后设置两个标志：

- `\g_@@_boundary_after_space_drop_bool`：只重放了 `CJK-space` marker（没有 glue）时为真。删去空格时还要把列表末尾的 glue `\unskip` 掉并关掉源码空格检查，因为直接输入 `中  X` 不开启这项检查。
- `\g_@@_boundary_after_space_unchecked_bool`：放回了真实 glue、入口前是 `CJK` marker、capture 开始时 pending 为假（`中{} \cmd`、`中\ \cmd`）时为真。直接输入不检查这枚空格、后面的汉字保留它，所以删去命令之后的空格时同样关掉检查。本层 `after_space` 为真（记录来自内层）时保留内层设置的值。入口前是 `CJK-space` marker 时不设置：以前也设置，`\textbf{中} \color{red} 文` 因此多出一枚空格（本地审查第一轮修正）。

## 检查：`\@@_boundary_after_space_check:`

只在记录有效、且记录里的层号与列表末尾状态都与当前一致时动作；不一致说明命令在重放之后又排出了内容，后面的空格不再与入口空格相邻，记录作废。

调用点在各类结束路径的最后：

- 核心：`\@@_boundary_inline_box_end:n`、`\@@_boundary_inline_last_box_end:n`、`\@@_boundary_inline_stream_end:n`、`\@@_boundary_hmode_transparent_end:`、`\@@_boundary_hmode_transparent_push_end:`（存下来源编号之后）。
- xeCJKfntef：`\@@_ulem_end:` 末尾、`\@@_under_symbol_auxii:nnnnnn` 末尾。
- 颜色：`\@@_boundary_textcolor:nnn` 的非公式分支（正文两端不是公式时 `\textcolor` 不启动 capture，`\reset@color` 的钩子之后还有 `\textcolor` 自己的结束分组）。
- hyperref：`\phantomsection`、`\MakeLinkTarget` 的 `cmd/.../after` 钩子；`\hypertarget` 的包装在第二个参数为空时调用。第二个参数不为空时会排出可见内容，由字符一侧的检查处理；曾经无条件调用，结果 `\hypertarget{t5}{锚}` 之后的间距也被删去（`hyperref-anchor-ecglue01` 发现）。

外层这几处要再调用一次的原因：内层被注册的命令（`\hyper@anchor`、`\__hyp_target_raise:n`、`\set@color`／`\reset@color`）结束时，外层命令的代码还在后面，内层的检查看到的下一个记号不是源码。

## peek 规则

`\@@_boundary_after_space_peek:` 用 `\peek_after:Nw` 看下一个记号，不展开它，由 `\@@_boundary_after_space_test:` 分派（空格以外的情形由 `\@@_boundary_after_space_test_other:` 继续分派）：

- **`\outer` 记号**（`\@@_boundary_if_peek_outer:TF`）：最先判断，作废记录并结束 align-safe 分组，不再做别的处理。`\@@_boundary_after_space_test:`、`\@@_boundary_after_space_brace_test:`、`\@@_boundary_after_space_math_test:`、`\@@_boundary_after_space_ignore_test:` 这四个 peek 之后的判断函数都先经过这一检查，原来的判断移入各自的 `_aux` 函数。原因见下文「align-safe 分组」。
- **空格**：作废记录并删去连续的空格（`\peek_remove_spaces:n`）。`drop` 为真时先 `\unskip` 末尾 glue、清 pending，删去空格之后再 peek 一次（`\@@_boundary_after_space_math_test:`），看下一个记号是不是 `$` 或左花括号；`unchecked` 为真时清 pending。
- **名字以 `__hook` 开头的控制序列**（`\@@_boundary_after_space_hook:nN`）：展开一层再 peek。LaTeX 命令钩子在 `after` 钩子之后紧跟 `\__hook_next …` 一类宏，钩子里看到的不是源码的下一个记号。判断用 `\str_range:nnn` 取名字前 6 个字符，名字先经 `\exp_args:Ne` 求出。
- **等同于 `\relax` 的控制序列**：照常执行，再 peek。xcolor 的 `\color` 在 `\set@color` 之后是 `\XC@ecolor\ignorespaces`，`\XC@ecolor` 通常等同于 `\relax`。
- **`\ignorespaces`**（`\@@_boundary_after_space_ignore_test:`）：再看一个记号。是控制序列时放回 `\ignorespaces`、保留记录；否则按本列表的规则处理下一个记号（空格本来就会被 `\ignorespaces` 跳过，`$` 等字符也不受它影响）。color 包的 `\color` 直接以 `\ignorespaces` 结尾。
- **左花括号**：`drop` 为假时保留记录；`drop` 为真时由 `\@@_boundary_after_space_brace:w` 看花括号之后是否 `$`（见下文）。
- **含义是 `\cr`、`\crcr`、`\span` 的记号**（`\@@_boundary_if_peek_align:TF`）：作废记录并结束 align-safe 分组，不再做别的处理（plain `\halign` 里命令后紧跟这些记号时，命令之后没有源码空格，也没有外层命令要接过记录）。这一判断排在控制序列分支之前，原因见下文「align-safe 分组」。
- **其他控制序列与右花括号**：保留记录，不作废，留给外层命令结束时再检查。
- **其他记号**：作废记录；`drop` 为真时检查它是不是 `$`。

`drop` 为真、下一个记号（删去空格之后，或“其他记号”分支里）是 `$` 时，`\@@_boundary_after_space_math:` 删去末尾的 `CJK-space` marker、清 pending 并补 `\xeCJK_space_or_xecglue:`，与直接输入 `中 $x$` 在公式之前补的间距一致。直接输入 `中 {$x$}` 在左花括号之后看到 `$` 时也补这枚间距，所以下一个记号是左花括号时，`\@@_boundary_after_space_brace:w` 用与 `\@@_boundary_group_math:w` 相同的办法（`\afterassignment` 加 `\let`）只吸收这一枚左花括号，看它后面的记号，再补发隐式左花括号 `\c_group_begin_token`。不吸收整个花括号组的原因见 [[../memory/decisions/1038-tabular-cr-group-peek]]。本地审查第一轮之前，`中 \color{red}$y$`、`中 \mbox{}{$y$}` 都丢失这枚公式前间距。

### align-safe 分组

上面所有对 `\l_peek_token` 的判断都在 `\group_align_safe_begin:` 与 `\group_align_safe_end:` 之间进行，每个分支先判断、再结束 align-safe 分组。表格单元格末尾的下一个记号可能是 `&` 或 `\cr`，`\l_peek_token` 这时等同于这个记号；在 align-safe 分组之外读取它，TeX 会插入列模板的结尾，单元格提前结束，报 `Extra alignment tab`（`中 \mbox{} & 文`，本地审查第一轮的阻塞问题；以前 `\@@_boundary_after_space_test:` 一开始就结束了 align-safe 分组）。

把下一个记号读成宏参数同样会让 TeX 看到它。控制序列分支原来先结束 align-safe 分组，再把下一个记号作为 `\@@_boundary_after_space_hook:N` 的参数读入，判断它的名字是否以 `__hook` 开头；plain `\halign` 里命令之后紧跟 `\cr`、`\crcr` 或 `\span` 时，读参数就在分组之外碰到了对齐记号，TeX 插入列模板，报 `Forbidden control sequence found while scanning use of \__xeCJK_boundary_after_space_hook:N`（`中 \mbox{}\cr`，本地审查第二轮的阻塞问题；修复前的 `e641743e` 没有这项检查，不报错）。所以 `\@@_boundary_after_space_test_other:` 先在分组内用 `\@@_boundary_if_peek_align:TF` 比较 `\l_peek_token` 的含义，排除 `\cr`、`\crcr`、`\span`，再结束分组、读参数。规则是：**判断 `\l_peek_token` 和把下一个记号读成参数都必须在 align-safe 分组内完成，或者先在分组内排除对齐记号**。`&` 不是控制序列，不会进入读参数的分支。

上面排除 `\cr` 一类记号的比较本身也要读 `\l_peek_token`。plain `\halign` 的列模板以空的已注册命令结尾、命令左侧有空格时（`\halign{#\mbox{}\cr 中 \cr}`），命令之后的下一个记号是 TeX 在列模板末尾插入的 `\endtemplate`。它是 `\outer` 记号，`\l_peek_token` 等同于它时也是 `\outer`；把 `\l_peek_token` 交给 `\token_if_eq_meaning:NNTF` 就是把它放进宏参数，报 `Forbidden control sequence`，接着 Emergency stop（最终全范围审查第四轮的重要问题；第二轮只排除了 `\cr`／`\crcr`／`\span`）。所以 `\@@_boundary_if_peek_outer:TF` 在所有判断之前，用原语 `\tex_meaning:D` 展开 `\l_peek_token` 的含义，再由 `\@@_boundary_if_peek_outer:w` 把含义的开头与四个前缀逐一精确比较：`\outer `、`\long\outer `、`\protected\outer `、`\protected\long\outer `（各带一个空格，对应 `\outer endtemplate:`、`\long\outer macro:` 等）。

- 不能用 `\token_to_meaning:N`，它同样把 `\l_peek_token` 作为参数读入。
- 不能只比较 `\outer` 一种开头。TeX 打印宏前缀的顺序是 `\protected`、`\long`、`\outer`，`\long\outer`、`\protected\outer` 宏的含义分别以 `\long\outer macro:`、`\protected\outer macro:` 开头。第四轮只比较前 6 个字符，`中 \mbox{}\EmptyOuterB`（`\long\outer\def`）仍报 `Forbidden control sequence`（本地审查第五轮的重要问题）。
- 也不能在含义里随便查找 `\outer`。第五轮改为在前 22 个字符里查找，替换文本以 `\outer...` 开头的普通宏（`\def\Foo{\outerX}`，含义 `macro:->\outerX`）因此被误判为 `\outer` 记号，记录被作废（本地审查第六轮的小问题）。四个前缀都以空格结尾，所以 `\outerX` 这类名字不会匹配。`\outer` 原语本身的含义是 `\outer`，后面没有空格，不匹配，照常走其他分支（它是普通原语，不是 `\outer` 记号）。
- 比较由 `\@@_boundary_if_prefix:nN` 完成：取含义的前 `\str_count:N` 个字符，与前缀用 `\str_if_eq:eeTF` 比较；四个调用由 `\bool_lazy_any:nTF` 组合。
- 前缀常量 `\c_@@_boundary_outer_str`、`\c_@@_boundary_long_outer_str`、`\c_@@_boundary_protected_outer_str`、`\c_@@_boundary_protected_long_outer_str` 用 `\c_backslash_str` 拼成（`\str_const:Ne`），末尾接 `\c_space_tl`。`\meaning` 的输出以反斜杠开头、字符 catcode 为 12，控制词之间没有空格。不能用 `\tl_to_str:n { \protected \long \outer }` 生成：它在每个控制词后补一个空格，得到 `\protected \long \outer `，与 `\meaning` 打印的 `\protected\long\outer macro:` 不同，`\protected\long\outer` 宏于是漏检（第六轮修复的第一版就因此报 `Forbidden control sequence`）。

规则补充：**`\l_peek_token` 可能是 `\outer` 记号，在交给任何以它为参数的函数之前，先用原语 `\meaning` 排除。**

`\peek_remove_spaces:n` 的回调在它自己的 align-safe 分组结束之后执行，回调里不能直接读 `\l_peek_token`；所以删去空格之后的判断要重新 `\group_align_safe_begin:` 再 peek 一次。`\@@_boundary_after_space_brace:w` 与 `\@@_boundary_after_space_ignore_test:` 前的 peek 同样包在 align-safe 分组里。

## xeCJKfntef 的透明内容分支

`\@@_ulem_onin_entry_check_space:nn` 在入口有源码空格、`\g_@@_ulem_onin_transparent_bool` 为真（入口之后排出过颜色等透明命令）时，若入口前（该层 `before` 字段）是 `CJK-space` 或 `CJK-widow`，不解除入口，与没有透明内容时的 `\@@_ulem_onin_entry_keep:nn` 一致。理由来自直接输入的变化：`符 {\color{red}~中} 后` 里颜色命令没有可见输出，按上面的规则只放回 marker，汉字后的空格与 `~` 合为一处，结果与去掉颜色的 `符 {~中} 后` 相同（33.33pt；#1103 前为 36.66pt）。`fntef-entry-space01` 因此有 9 项期望值随直接输入改变，见 [[../reference/build-and-test]]。

## 仍不一致的写法

修复前后相同、或修复前也与直接输入不一致的写法，已接受的回退，plain `\halign` 模板里 `#` 之后有空格时的既有报错，以及 `\numlist{}`／`\unit{}` 部分组合与 master 不同的原因，登记在 [[../memory/doc-gaps]]「没有可见输出的命令两侧都有源码空格」一节。其中以下几项与上文机制直接相关：

- `X{ }\cmd Y`（空格写在花括号里）：**相对修复前是回退**，维护者决定接受（[[../memory/decisions/1103-group-space-before-empty-command]]）。它在命令之前留下的节点列表与 `X{} \cmd Y`、`X\ \cmd Y`、`X\space\cmd Y` 相同（左侧是汉字时，列表末尾都是 `CJK` marker 加一枚词间 glue），`space_glue` 无法区分，按后者处理，删去命令之后的空格：`中{ }\mbox{} 文` 修复前与直接输入都是 26.66pt，现在 23.33pt。后三者修复前多一枚空格，现在正确。用户手册「CJK 文字与命令交互时的间距」一节写明了这一限制与替代写法（把空格写在命令之后的花括号里，或改用 `~`）。
- 空格与空命令之间只有不排出内容的命令或空分组（`A \sbox0{x}\mbox{} B`、`A \def\x{}\mbox{} B`、`A {}\mbox{} B`、`A \stepcounter{foo}\mbox{} B`）：命令之前的节点列表与 `A \mbox{} B` 相同，只能按后者处理，命令后的空格被删去（`xCJKecglue=false` 时 17.91pt，修复前与直接输入 21.24pt；两侧都是汉字时与直接输入一致）。与上一条同属“无法区分”一类，相对修复前也是回退，第六轮的 head `aed1f9d2` 上已是这样（更早的提交没有逐一核对），第七轮登记。用户手册「CJK 文字与命令交互时的间距」一节的已知限制段落写明了这一类（例子 `A \sbox0{x}\mbox{} B`、`A {}\mbox{} B`）。`xCJKecglue=true` 时第一个 `\mbox{}` 在列表里不留节点，`A \mbox{}\sbox0{x}\mbox{} B` 也落入这一类，所以上文 `\sbox` 一段的数值只对 `xCJKecglue=false` 成立。
- `\mbox{} \mbox{}` 这类两个空命令之间有空格的写法，在 `xCJKecglue=true` 且可区分间距、右侧空格写法 01 时与直接输入不一致。
- 颜色正文以“汉字 + 空格 + 空命令”结尾（`\textcolor{red}{中 \mbox{}} 文`）：修复前与现在都多一枚空格，上文的配对规则不改变它的结果。`xCJKecglue=false` 时为 26.66pt，直接输入 `{中 } 文` 23.33pt；`xCJKecglue=true` 时同为 26.66pt，直接输入 20.0pt。嵌套的空颜色命令 `中 \textcolor{red}{\textcolor{blue}{}} 文` 与直接输入一致（20.0pt），由 TEST 10 的 `tc-tc-C` 固定；第五轮曾误记为仍多一枚空格。l3color 的 `\color_group_begin:`…`\color_group_end:` 正文以空格结尾时，修复前与现在都删去命令之后的空格。

测试见 `xeCJK/testfiles/boundary-empty-space01.lvt`，组成见 [[../reference/build-and-test]]。
