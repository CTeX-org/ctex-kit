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
- `g_@@_boundary_capture_<n>_after_space_tl`：capture 开始时内层留下的记录是否仍然有效（`\@@_boundary_after_space_if_armed:TF`），并且记录之后没有看到可能排出内容的记号（`\g_@@_boundary_after_space_clean_bool`，见下文「clean 标志」）。用于 `\textcolor{red}{}` 这类嵌套空命令：入口空格由内层的颜色命令记下，实际属于外层命令，外层要能把记录接过来。

`\@@_boundary_capture_begin:` 先读取上述有效性，再清除全局记录 `\g_@@_boundary_after_space_bool`。读取时记录可能已经过期：记录只比较层号与列表末尾的状态，中间排出的内容可能让状态恰好相同，所以接过记录还要求 clean 标志为真（最终全范围审查 `final-full-110923` 的阻塞问题，见下文）。新的 marker 排出时（`\xeCJK_make_node:n`、`\@@_make_space_node:`）也清除这条记录：命令之后又排出了字符，后面的空格属于这个字符。以前检查遇到控制序列时把记录留给外层，命令之后接着排出别的内容时，记录仍保留到下一个 capture 开始，可能被后面的命令误当作内层留下的记录接过来（如 `中~ \RegStream{}\hbox{x}` 之后的下一段，本地审查第一轮发现）。

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

stream 结束时首类别为空、末类别却是 `math`、`math-space` 或 `math-space-frozen` 的情形不按“无可见输出”处理（`\@@_boundary_inline_stream_end:n` 里 `entry` 不是 `resolved` 的分支）：`A \textcolor{red}{\Nop $x$} B` 的正文以用户宏开头、以公式结尾，公式开头不是正文第一个记号，`\@@_boundary_math_begin:n` 没有报告首类别，结尾时 `\@@_boundary_math_end:n` 却确认了末类别。以前走 `\@@_boundary_replay_before_empty:`，`\textcolor` 之后的空格被删去（23.63pt，修复前与直接输入 26.96pt；`79222a0d` 起就是这样，第二十五轮的盲审报告作为范围外观察提出），现在照常调用 `\@@_boundary_replay_before:`。`879a9261` 只认 `math`，正文以公式加空格结尾的 `A \textcolor{red}{\Nop $x$ } B` 末类别是 `math-space-frozen`，仍少一枚空格（第二十六轮的 R26-I3）。

首、末类别都为空时还要看正文有没有排出节点。正文只排出规则、盒子、图片、kern、glue、whatsit 这类不报告类别的内容时（`A \hyperlink{a}{\rule{2pt}{1pt}} B`、`\hyperlink{a}{\includegraphics{...}}`、用户注册 stream 命令的 `\RegStream{\kern2pt}`），以前同样走 `\@@_boundary_replay_before_empty:`，命令之后的空格被删去（19.91pt，修复前与直接输入 23.24pt；最终全范围审查 `final6-full-015816` 的阻塞问题 RF6-B1，从第一个提交起就存在）。现在 `stream` 一类的 capture 开始时放下哨兵（`\@@_boundary_stream_sentinel_put:`，按层号写入的版本是 `\@@_boundary_stream_sentinel_put:n`），stream 结束、取下正文末尾的 marker 之后由 `\@@_boundary_stream_if_unchanged:nTF` 判断列表是否没有变化（`\@@_boundary_stream_if_body_empty:TF` 调用它）：没有变化就按没有可见输出处理；有变化就照常调用 `\@@_boundary_replay_before:`。哨兵按开始时列表末尾的节点分两种（`sentinel` 字段）：

- **`state`**：末尾是 glue、kern 或 penalty（`\lastnodetype` 为 11、12、13）时，只把节点类型与 `\lastkern`、`\lastskip`、`\lastpenalty` 的值写进 `last_state` 字段（`\@@_boundary_stream_last_state:`），不往列表里放节点，结束时比较这些值。正文开头的代码常要读取或删去这个节点：全角标点的转换代码（`\xeCJK_if_last_punct:TF`）检查前一个标点留下的 glue、penalty 与 marker 决定挤压，用户命令以 `\unskip`、`\unkern` 开头删去命令之前的空格或 kern。`e1952979` 起一律在列表里放一对 kern，挡住了它们：`如上。\ref{a}项`（不加载 hyperref，编号以全角括号开头）由 60.0pt 变为 65.0pt，`中，\RS{（}文` 由 35.0pt 变为 40.0pt，`Text \mynote{x} B`（`\mynote` 定义为 `\unskip\footnote{#1}`）由 34.893pt 变为 38.223pt（最终全范围审查 `final7-full-052308` 的阻塞问题 RF7-B1 与重要问题 RF7-I1）。代价是正文不排出文字、又以同类同值的 glue、kern 或 penalty 结尾时看不出正文有输出：`a \mystream{\rule{1pt}{1pt} } b` 为 18.22pt，修复前与直接输入 21.55pt，写进用户手册第一类（doc-gaps A4）。
- **`true`**：末尾是盒子、whatsit、字符等节点时，正文常以同类节点结尾（`\rule`、`\fbox`、图片都是盒子，颜色是 whatsit，XeTeX 的字符也可能是 whatsit），只比较类型与数值认不出（见下一段 `91b0e0a2` 的教训），所以在列表里放 `stream-begin` 节点（一对正负 kern）。`\@@_boundary_stream_sentinel_if_last:TF` 先比较 `\lastkern`，再临时取下末尾的 kern，确认下面是负值的那一半再放回，用户自己写的一枚 `\kern9sp` 不再被当作哨兵（`中 \RS{\kern9sp} 文` 恢复为修复前的 26.66014pt，`final7` 的观察）。正文报告类别时（`\@@_boundary_capture_class:n`）先取下仍在末尾的这对 kern，以免挡在入口 marker 与第一个字符之间。这时前一个节点不是 glue、kern、penalty，标点挤压与 `\unskip` 本来就不会处理它，所以放节点不影响它们。

`\@@_boundary_stream_sentinel_remove:n` 只取下 `true` 一种放在列表里的节点。

`91b0e0a2` 的第一版用 `\@@_boundary_after_space_state:` 比较 capture 开始与 stream 结束时列表末尾的节点类型、`\lastkern`、`\lastskip`，认不出与开始时末尾同类的节点：正文以颜色 whatsit 结尾（`\hyperlink{a}{\textcolor{red}{\rule...}}`，XeTeX 的西文字符本身也是 whatsit）、命令之前是盒子而正文先有空 `\mbox{}` 再排出内容（`\mbox{x} \RegStream{\rule...} B`、`\hyperlink{a}{\mbox{}\rule...}`），以及正文只有 `\special` 的 `A \hyperlink{a}{\special{x}} B`，命令之后的空格仍被删去（本地审查第三十七轮的 R37-B1、R37-I1、R37-I2）。当时 dtx 与 doc-gaps 把正文只有 `\special` 的写法说成“用户手册写明的第一类限制”，手册里其实没有这一条（R37-I2）；改用哨兵后这类写法与修复前、直接输入相同，这句说法已删去。

hyperref 的 `\Hy@BeginAnnot`、`\Hy@EndAnnot` 在正文前后自己写入链接注释的 special：链接注释的 stream 开始时不放哨兵（`\l_@@_boundary_stream_sentinel_bool` 为假），写入开始 special 之后由 `\@@_boundary_stream_content_begin:` 放下，写入结束 special 之前由 `\@@_boundary_stream_content_end:` 记下列表是否没有变化（`body_empty` 字段）并取下哨兵；开始 special 是 whatsit，链接里放的总是 `true` 一种。正文里嵌套的命令自己判断为没有可见输出时（`\hyperlink{a}{\mbox{}}`、`\RegStream{\textcolor{red}{}}`），它留下的空盒子、颜色 whatsit 会挡住外层的哨兵：内层 capture 开始时若外层的哨兵仍表明列表没有变化（`\@@_boundary_stream_if_unchanged:nTF`），就取下它（`true` 一种）并记下 `outer_clean` 字段，内层按没有可见输出结束时按当时的列表末尾重新放下外层哨兵（`\@@_boundary_stream_sentinel_put:n`，层号是当前层减一），可能从 `state` 换成 `true`。哨兵只放在正文可能什么也不排出的命令里：`\@@_boundary_register_stream:nn` 注册的命令（用户注册的 stream 命令、siunitx 的 `\unit`、`\ref` 内部的 `\@setref` 等，经 `\@@_boundary_inline_stream_begin_sentinel:n`）与 hyperref 的链接注释；正文排出内容后哨兵留在列表中间，是一对宽度为零的 kern。`\verb`、`\lstinline`、`\url`、正文两端有公式的 `\textcolor` 等直接调用 stream 开始函数的命令不放哨兵（`\ref` 内部的 `\@setref` 经 `\@@_boundary_register_stream:nn` 注册，放哨兵），节点列表与以前相同；它们首、末类别都为空时按有可见输出处理，与修复前相同（`e1952979` 曾一律按没有可见输出处理，`A \verb| | B` 少一枚空格，23.16pt，修复前与直接输入 `A {\ttfamily\ } B` 都是 26.49pt：抄录的空格不报告类别；本地审查第三十八轮的阻塞问题 R38-B1）（第一次实现时对所有 stream 都放，`verb01`、`listings-color01`、`verb-ecglue02` 的 `.tlg` 多出一对 kern）。哨兵用固定的 9sp，不经 `\xeCJK_declare_node:n` 编号，以免改变 xeCJKfntef 之后声明的 marker 数值（第一次实现时 `fntef-entry-space01` 的 marker kern 全部变了）。xeCJKfntef 的 `stream-ulem` 由 ulem 自己排出装饰盒子，也不放哨兵，仍按类别判断（`中 \uline{\mbox{}} 文` 曾在第一版里多出一枚空格，旧探针比对发现）。

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
- hyperref：`\phantomsection`、`\MakeLinkTarget` 的 `cmd/.../after` 钩子；`\hypertarget` 的包装在第二个参数为空时调用。第二个参数不为空时会排出可见内容，由字符一侧的检查处理；曾经无条件调用，结果 `\hypertarget{t5}{锚}` 之后的间距也被删去（`hyperref-anchor-ecglue01` 发现）。包装只加在 hyperref 原来的定义上（`\@@_boundary_if_hypertarget_plain:NTF`：不是 `\protected` 的宏、`\cs_parameter_spec:N` 为 `#1#2`）。beamer 用 `\renewcommand<>` 把 `\hypertarget` 改成先读覆盖说明的 `\protected` 命令，原定义存在 `\@orig\hypertarget`；这时包装加在 `\@orig\hypertarget` 上，两者都不是原定义时不包装。以前按 `#1#2` 直接包装 `\hypertarget`，beamer 下 `\hypertarget<2>{tgt}{目标}` 把 `<`、`2` 读成两个参数，排出“2>tgt 目标”，不报错（最终全范围审查 `final5-full-005223` 的阻塞问题 RF5-B1；回归测试 `boundary-empty-space02`）。包装用 `\cs_gset_nopar:cpn`，与 hyperref 的定义一样不是 `\long`。

外层这几处要再调用一次的原因：内层被注册的命令（`\hyper@anchor`、`\__hyp_target_raise:n`、`\set@color`／`\reset@color`）结束时，外层命令的代码还在后面，内层的检查看到的下一个记号不是源码。

## clean 标志：记录之后有没有看到可能排出内容的记号

`\@@_boundary_after_space_check:` 遇到控制序列时保留记录，留给外层命令结束时再检查（见下文「peek 规则」）。外层命令不一定存在，记录就一直留着，直到后面某个 capture 开始。这时 `\@@_boundary_after_space_if_armed:TF` 只比较层号与列表末尾的状态，中间若排出了同类节点，状态也相同：

- `A \mbox{}\rule{2pt}{1pt}\mbox{} B`：`\mbox{}` 的空盒子与 `\rule` 排出的规则之后，`\lastnodetype` 都不是 glue，第二个 `\mbox{}` 接过记录，删去它之后的空格。结果为 19.91pt，修复前与直接输入 `A \rule{2pt}{1pt} B` 都是 23.24pt。
- `A \textcolor{red}{}\special{x}\textcolor{blue}{} B`：两次的末尾都是 whatsit，17.91pt 对 21.24pt。
- 记录还能越过盒子与段落：先排 `\hbox{A \mbox{}\rule{1pt}{1pt}}`，再排 `\rule{1pt}{1pt}\mbox{} B`，后者为 8.08pt，应为 11.41pt。

这是最终全范围审查 `final-full-110923` 的阻塞问题（ledger RF-B1），从第一个提交 `e2c2695f` 起就存在。以前的测试在用例之间只清除 last node 与 pending，不清除这条记录，用例之间的残留没有暴露出来；`boundary-empty-space01` 的 `\EmptyReset` 现在也清除 `\g__xeCJK_boundary_after_space_bool`。

修法是全局布尔量 `\g_@@_boundary_after_space_clean_bool`：`\@@_boundary_after_space_rearm:` 写入记录时设为真，检查看到可能排出内容的记号时设为假，capture 开始与颜色弹出命令（`\@@_boundary_hmode_transparent_pop_begin:`）只在它为真时接过记录。暂停与恢复时它与记录一起保存（`g_@@_boundary_suspend_<n>_after_space_clean_tl`）。

由 `\@@_boundary_after_space_known_cs:nNTF` 判断控制序列：

- **不改动 clean，也不展开**：已注册命令（`\g_@@_boundary_registered_prop` 里除 `post-transparent` 之外的类别）与保留表里的专用适配器，它们自己的 capture 会处理边界；`\phantomsection`、`\MakeLinkTarget` 也写入保留表。宏包内部代码，即名字里有 `@` 或 `_` 的控制序列（`\textcolor` 包装末尾的 `\int_set:Nn`、xeCJKfntef 的 `\UL@...`）与 LaTeX 命令钩子在 after 钩子之后调用的 `\UseHookWithArguments`（`\@@_boundary_if_internal_name:nTF`；只认这一个名字，用户直接写的 `\UseHook` 照常按可能排出内容处理）。条件是不处在展开用户宏之后（见下）。这一豁免有代价：`\makeatletter` 之后直接写在两个空命令之间的内部命令即使排出内容，也不改 clean 标志，后一个命令接过记录，多删一枚空格。`A \mbox{}\hb@xt@1pt{}\mbox{} B` 为 18.91pt，修复前与直接输入 `A \hb@xt@1pt{} B` 都是 22.24pt（最终全范围审查 `final3-full-190620` 的重要问题 RF3-I1）。用户手册「CJK 文字与命令交互时的间距」一节把它归入“少一枚空格”的第一类限制，维护者 2026-10-03 接受；把内部命令写在花括号里（`A \mbox{}{\hb@xt@1pt{}}\mbox{} B`）时，左花括号把标志改为假，两侧空格保留（测试 `brace-internal-L`）。
- **展开一层再看**：不带参数的用户宏（`\def\Nop{}`、`\def\Sp{ }`），即不属于上一条、`\cs_parameter_spec:N` 为空的宏，含义与 `\@@_boundary_identity:n` 相同的宏（`\newcommand\Id[1]{#1}`，展开后参数原样留在原处），以及 `\fi`、`\csname`、`\ifnum`、`\expandafter` 一类可展开原语。hyperref 的 `\fi` 展开后消失，`\expandafter` 露出的 `\put@me@back` 名字有 `@`，仍按宏包代码处理；用户直接写的 `\csname rule\endcsname` 展开后是 `\rule`，把 clean 标志改为假。
- **不展开，设为假**：带参数的用户宏（`\UseHook{...}`、`\newcommand\Gobble[1]{}`）。`\NewDocumentCommand` 定义的命令本身不带参数，照常展开；带参数的展开后停在某个带参数的内部宏上（只有 `m` 一类参数时是 `\<命令名> code`，有可选参数时是 ltcmd 读取参数的内部函数，第二十八轮的小问题 R28-M1 指出以前只写了前一种），按这一条处理；不带参数的展开为空。用户宏展开后遇到带参数的宏（`\def\Nop{\@gobble x}`）同样停下，按排出内容处理，与修复前一样多一枚空格（第二十八轮补充报告指出，用户手册已补写）。展开它们会连参数一起吃掉，看不出参数原来的位置；直接输入 `A \Gobble{x} B` 保留两枚空格，这里也保留（第二十六轮的重要问题 R26-I2：`879a9261` 及以前展开它们，`A \mbox{}\UseHook{foo}\mbox{} B` 少一枚空格）。`\noexpand`、`\primitive` 也不展开：它们给下一个记号加的“不展开”标记，在 `\peek_after:Nw` 读走记号之后就丢失了，`A \mbox{}\noexpand\Foo B` 会多排出 `\Foo` 的内容（R26-I1，`879a9261` 引入）。
- **两个标志**：用户宏展开后由 `\@@_boundary_after_space_mark_expanded:N` 置 `\g_@@_boundary_after_space_expanded_bool`，之后即使看到空格也不删去（展开得到的空格不在源码里紧跟命令）。可展开原语展开后不置这个标志（hyperref 的 `\expandafter\put@me@back` 之后还要按宏包代码判断），但另置 `\g_@@_boundary_after_space_keep_space_bool`，同样不删空格：`A \mbox{}\the\T B`（`\T={ }`）、`A \mbox{}\expandafter\relax\space B` 以前为 17.91pt，修复前与直接输入 21.24pt（最终全范围审查 `final2-full-175113` 的重要问题 RF2-I1，`879a9261` 引入）。条件原语 `\if...`、`\fi`、`\else`、`\or`、`\unless` 例外（`\@@_boundary_if_conditional:NF` 按含义判断），它们本身不排出空格。源码里直接写的 `\fi` 之后的空格读入时就被跳过，这条例外只在条件原语来自宏的替换文本时起作用：`\newcommand\Foo[1]{\ifhmode\mbox{}\fi}` 之后，`A \Foo{x} B` 里 `\fi` 之后是源码空格，照常删去，与删去没有可见输出的 `\Foo` 之后的 `A  B` 相同（17.91pt；修复前 21.24pt）。`5c63d784` 用 `A \iftrue\mbox{}\fi B` 举例，这个写法根本不经过例外，测试也没有覆盖它（第三十轮的小问题 R30-M1）。expanded 标志为真时，遇到名字里有 `@`、`_` 的记号也不再当作宏包代码，而按本节的规则判断：展开得到的 `\@empty` 照常展开，`\@gobble` 带参数，停下。`7cc9629b` 在这里直接把 clean 标志改为假，`A \mbox{}\NDNop\mbox{} B`（`\NewDocumentCommand\NDNop{}{}`）多一枚空格，与用户手册“展开后为空的宏不受限制”不符（第二十七轮的重要问题 R27-I1）。是否在 `$` 之前补间距另由 `\g_@@_boundary_after_space_math_block_bool` 决定，规则与直接输入时 xeCJK 的前视（`\xeCJK_CJK_and_Boundary:w`）一致：前视只越过恒等宏看 `$`（`中 \Id{$x$}` 补间距，19.05pt），所以展开过其他用户宏或可展开原语之后不补（`中 \mbox{}\ifhmode $x$\fi` 与直接输入都是 15.72pt，R26-M2）。前视越过恒等宏之后，参数里的 `\Nop $x$` 由 `\Nop` 自己的边界处理，直接输入 `中 \Id{\Nop $x$}` 补间距（19.05pt）；所以展开过恒等宏之后（`\g_@@_boundary_after_space_identity_bool`）再展开用户宏时只置 expanded 标志（展开可展开原语本来就不置 expanded 标志），两者都不置 math_block 标志。`7cc9629b` 只对用户宏这样做，可展开原语照样置 math_block 标志，`中 \mbox{}\Id{\ifhmode $x$\fi}` 少补公式前间距（15.72pt，修复前与直接输入 19.05pt；第二十七轮的阻塞问题 R27-B1）。`879a9261` 把两件事放在一个标志上，恒等宏之后连空格也删去：`A \mbox{}\Id{\Nop} B` 为 17.91pt，修复前与直接输入 21.24pt（第二十六轮的阻塞问题 R26-B1）；那一版的说明还把直接输入 `中 \Id{\Nop $x$}` 写成不补间距（R26-M1）。
- **设为假**：其他不可展开的控制序列（`\rule`、`\special`、`\par`、`\small`），以及 `\textbf` 等文字命令。文字命令在保留表里取值 `text`（`\@@_boundary_register_text_command:NN`），因为它们的普通正文不经过 capture，没有代码检查记录是否还紧邻列表末尾。
- 左花括号、`\cr` 一类对齐记号、不是 `\textcolor` 正文结尾的右花括号也设为假。`\textcolor` 正文结尾的右花括号由 `\@@_boundary_after_space_if_color_body_end:F` 认出：上一层的 `\g_@@_boundary_color_origin_<层数>_tl` 等于当前记录的来源编号。
- **活动字符**：`\@@_boundary_after_space_cs_name:N` 对活动字符不取名字（得到空字符串），`\@@_boundary_after_space_known_cs:nNTF` 先排除活动字符。判断用 `\@@_boundary_if_active_char:NTF`：`\token_to_str:N` 只得到一个字符的是活动字符，控制序列前面还有转义字符。`349f9f77` 用的 `\token_if_active:NTF` 按含义判断，活动空格被 `\let` 成控制空格（`\obeyspaces\let =\ `）时认不出，仍然报错（本地审查第三十二轮的阻塞问题 R32-B1）。认出的活动字符直接交给 `\@@_boundary_after_space_unknown_cs:N`。`\obeyspaces` 之下的活动空格经 `\token_to_str:N` 得到普通空格，`\__cs_to_str:N` 读参数时跳过它、读到后面的 `}`，报 `Argument of \__cs_to_str:N has an extra }`（最终全范围审查 `final3-full-190620` 的阻塞问题 RF3-B1，从第一个提交 `e2c2695f` 起就存在）。活动空格等同于 `\space`，展开一层得到空格并置 expanded 标志，所以不删去：`{\obeyspaces 中 \mbox{} 文}` 与直接输入 `{\obeyspaces 中  文}` 相同（23.33pt，修复前 26.66pt），`{\obeyspaces A \color{red} B}` 与修复前相同（`\ignorespaces` 本来就跳过展开出的空格）。

`\ignorespaces` 之后是控制序列时（`\@@_boundary_after_space_ignore_cs:N`）同样按上面的规则判断；用户宏展开一层（同样置 expanded 标志）后回到 `\@@_boundary_after_space_ignore_test:`，否则放回 `\ignorespaces`。展开之后看到的不是控制序列时，空格照常删去（`\ignorespaces` 本来就会跳过它），其他记号作废记录、放回 `\ignorespaces`，不补公式前的间距。`\textcolor{red}{\mbox{}}` 的 `\mbox` 因此仍能接过 `\set@color` 的记录；最初的版本在这里不展开用户宏，`\textcolor{red}{\csname uline\endcsname{}}` 一类用例多一枚空格，被 `tmp/i1103/r4/t6.tex` 的探针发现。

第一版（`6a5e4dd7`）把“名字里没有 `@`、`_` 的可展开记号”都当作用户宏，展开之后连内部名字也按未知处理。hyperref 的 `\hypertarget` 在内层出口 `\hyper@anchor` 之后还有 `\fi\expandafter\put@me@back`，`\phantomsection` 的 after 钩子之后是 `\UseHookWithArguments`；检查把它们当作用户宏一路展开，直到 `\let`、`\global` 把 clean 标志改为假，`中 \textcolor{red}{\hypertarget{x}{}} 文`、`A \phantomsection\mbox{} B` 等回到修复前的结果（本地审查第二十四轮的重要问题 R24-I1）。同一轮的小问题 R24-M1：`\ignorespaces` 路径展开用户宏后没有置 expanded 标志，`中 \color{red}\Nop $x$` 又补了公式前的间距（19.05pt，直接输入 15.72pt）。

第二版（`6cfeee80`）为了跳过 hyperref 的 `\fi`，把所有不是宏的可展开原语都按宏包代码处理：既不展开、也不改 clean 标志。用户直接写的 `\csname rule\endcsname`、`\ifhmode\special{x}\fi` 于是又让记录越过排出的内容：`A \mbox{}\csname rule\endcsname{2pt}{1pt}\mbox{} B` 为 19.91pt，修复前与直接输入 23.24pt（本地审查第二十五轮的重要问题 R25-I1）。第三版（`879a9261`）让原语照常展开，并把钩子命令的白名单收窄到 `\UseHookWithArguments`；但 `\UseHook{foo}` 作为用户宏展开时连参数一起吃掉，结果并没有改变，说明却写成已修正（第二十六轮的 R26-I2，由上面的“不展开，设为假”一条修好）。

代价：空命令之后、下一个空命令之前若是未注册的命令，即使它实际不排出内容，也按排出内容处理，两侧的空格都保留，与修复前一样多一枚空格（`A \mbox{}\small\mbox{} B` 为 20.47pt，直接输入 `A \small B` 17.38pt；`\bgroup\egroup`、`\null` 同样）。用户手册「CJK 文字与命令交互时的间距」一节写明了这一限制。另一方面，第七轮记录的 `A \mbox{}\def\x{}\mbox{} B`（修复前与直接输入都是 21.24pt，`79222a0d` 为 17.91pt）因此回到 21.24pt。

第七轮曾放弃过“展开未注册的宏、遇到未注册的原语就作废”的做法（见上文 `\sbox` 一段），理由是会改变“控制序列保留记录、交给外层”的行为。现在的做法不作废记录，记录照常留给外层命令结束时检查（`\textcolor{red}{\mbox{}\rule{1pt}{1pt}} 文` 仍由外层检查作废），只是不再让它被后面的 capture 接过。规则：**留给外层的记录只能由外层命令的检查使用；后面的命令要接过记录，必须确认中间没有可能排出内容的记号，不能只比较列表末尾的状态。**

## peek 规则

`\@@_boundary_after_space_peek:` 用 `\peek_after:Nw` 看下一个记号，不展开它，由 `\@@_boundary_after_space_test:` 分派（空格以外的情形由 `\@@_boundary_after_space_test_other:` 继续分派）：

- **`\outer` 记号**（`\@@_boundary_if_peek_outer:TF`）：最先判断，清除 `\l_peek_token`、作废记录并结束 align-safe 分组，不再做别的处理。`\@@_boundary_after_space_test:`、`\@@_boundary_after_space_brace_test:`、`\@@_boundary_after_space_math_test:`、`\@@_boundary_after_space_ignore_test:` 这四个 peek 之后的判断函数都先经过这一检查，原来的判断移入各自的 `_aux` 函数。原因见下文「align-safe 分组」。
- **空格**：作废记录并删去连续的空格（`\peek_remove_spaces:n`）。`drop` 为真时先 `\unskip` 末尾 glue、清 pending，删去空格之后再 peek 一次（`\@@_boundary_after_space_math_test:`），看下一个记号是不是 `$` 或左花括号；`unchecked` 为真时清 pending，删去空格之后清除 `\l_peek_token`（原因见下文「align-safe 分组」）。
- **名字以 `__hook` 开头的控制序列**（`\@@_boundary_after_space_hook:nN`）：展开一层再 peek。用户自己定义的宏等可展开的控制序列也展开一层再 peek，规则见上文「clean 标志」。LaTeX 命令钩子在 `after` 钩子之后紧跟 `\__hook_next …` 一类宏，钩子里看到的不是源码的下一个记号。判断用 `\str_range:nnn` 取名字前 6 个字符，名字先经 `\exp_args:Ne` 求出。
- **等同于 `\relax` 的控制序列**：照常执行，再 peek。xcolor 的 `\color` 在 `\set@color` 之后是 `\XC@ecolor\ignorespaces`，`\XC@ecolor` 通常等同于 `\relax`。
- **`\ignorespaces`**（`\@@_boundary_after_space_ignore_test:`）：再看一个记号。是控制序列时放回 `\ignorespaces`、保留记录（用户宏先展开一层，并按上文「clean 标志」更新标志）；否则按本列表的规则处理下一个记号（空格本来就会被 `\ignorespaces` 跳过，`$` 等字符也不受它影响）。color 包的 `\color` 直接以 `\ignorespaces` 结尾。
- **左花括号**：`drop` 为假时保留记录；`drop` 为真时由 `\@@_boundary_after_space_brace:w` 看花括号之后是否 `$`（见下文）。
- **含义是 `\cr`、`\crcr`、`\span` 的记号**（`\@@_boundary_if_peek_align:TF`）：作废记录并结束 align-safe 分组，不再做别的处理（plain `\halign` 里命令后紧跟这些记号时，命令之后没有源码空格，也没有外层命令要接过记录）。这一判断排在控制序列分支之前，原因见下文「align-safe 分组」。
- **其他控制序列与右花括号**：保留记录，不作废，留给外层命令结束时再检查；clean 标志按上文的规则更新。
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

**认出 `\outer` 记号之后清除 `\l_peek_token`**（本地审查第八轮补充报告的问题）。`\peek_after:Nw`（即 `\futurelet`）让 `\l_peek_token` 等同于这个 `\outer` 记号，它自己也成了 `\outer`；`\@@_boundary_if_peek_outer:TF` 认出它、作废记录之后，`\l_peek_token` 仍是这个含义。之后任何代码只要在宏参数里写着 `\l_peek_token` 这个记号，扫描参数时就报 `Forbidden control sequence`。`A \mbox{}\OA B`（`\OA` 用 `\outer\def` 定义为空）里，`\OA` 展开为空，下一个字符 `B` 触发 Boundary 到 Default 的 interchar 代码 `\peek_meaning_remove:NTF \tex_italiccorrection:D {...}{\token_if_space:NTF \l_peek_token ...}`，它的参数里就写着 `\l_peek_token`。修复前 `e641743e` 与直接输入 `A \OA B` 都不报错。这个问题从 #1103 的第一个提交 `e2c2695f` 起就存在；第四轮以后的用例里 `\outer` 记号之后都是 `}`（列模板末尾的 `\endtemplate`、“empty command followed by an outer macro”一组原有的 `中 \mbox{}\EmptyOuterA` 等），后面没有字符，所以没有发现。

- 现在 `\@@_boundary_if_peek_outer:w` 的真分支先调用 `\@@_boundary_peek_token_clear:`（`\tex_let:D \l_peek_token \scan_stop:`），再 `\prg_return_true:`。清除写在单独的宏里，宏体照常执行，不经过参数扫描，所以清除本身不会报错。
- 删去命令之后的空格时也有同样的问题：`\peek_remove_spaces:n` 删完空格后把 `\l_peek_token` 留成下一个非空格记号（`A \mbox{} \OA B` 里是 `\OA`）。`drop` 为假的分支删去空格之后不再看下一个记号，原来写成 `\peek_remove_spaces:n { }`，第八轮改为在回调里调用 `\@@_boundary_peek_token_clear:`。这个回调在 `\peek_remove_spaces:n` 结束 align-safe 分组之后执行，下一个记号可能是 `&`、`\cr`、`\span`；`\tex_let:D` 本身就读取 `\l_peek_token`，读到等同于对齐记号的值时 TeX 同样插入列模板的结尾：`A \mbox{} & B`（tabular，左侧是西文）报 `Extra alignment tab has been changed to \cr`，plain `\halign` 的 `A \mbox{} \cr` 报 `Missing control sequence inserted`（本地审查第九轮的阻塞问题，相对修复前与 `870661c8` 都是回退）。现在回调写成 `\group_align_safe_begin: \@@_boundary_peek_token_clear: \group_align_safe_end:`。左侧是汉字时 `drop` 为真，不走这个分支，所以第八轮的用例与以前的 tabular 用例都没有覆盖它；`boundary-empty-space01` 的“empty command before cr, crcr and span in halign”一组新增 6 项西文用例，另加“empty command after a latin letter at the end of a tabular cell”一组。`drop` 为真的分支删去空格之后再 peek 一次（`\@@_boundary_after_space_math_test:`），那次的判断函数开头仍先经过上面的 `\outer` 检查。
- 直接输入 `中 \OA 文` 仍报错，与修复前相同：报错来自 xeCJK 汉字之后的前视，不经过命令之后的检查（见 [[../memory/doc-gaps]]）。

规则补充：**`\l_peek_token` 可能是 `\outer` 记号，在交给任何以它为参数的函数之前，先用原语 `\meaning` 排除；认出之后还要把 `\l_peek_token` 改回无害的值，因为后续代码（包括其他模块的 interchar 代码）可能在宏参数里写着它。**

`\peek_remove_spaces:n` 的回调在它自己的 align-safe 分组结束之后执行，回调里不能直接读 `\l_peek_token`；所以删去空格之后的判断要重新 `\group_align_safe_begin:` 再 peek 一次。`\@@_boundary_after_space_brace:w` 与 `\@@_boundary_after_space_ignore_test:` 前的 peek 同样包在 align-safe 分组里。

## xeCJKfntef 的透明内容分支

`\@@_ulem_onin_entry_check_space:nn` 在入口有源码空格、`\g_@@_ulem_onin_transparent_bool` 为真（入口之后排出过颜色等透明命令）时，若入口前（该层 `before` 字段）是 `CJK-space` 或 `CJK-widow`，不解除入口，与没有透明内容时的 `\@@_ulem_onin_entry_keep:nn` 一致。理由来自直接输入的变化：`符 {\color{red}~中} 后` 里颜色命令没有可见输出，按上面的规则只放回 marker，汉字后的空格与 `~` 合为一处，结果与去掉颜色的 `符 {~中} 后` 相同（33.33pt；#1103 前为 36.66pt）。`fntef-entry-space01` 因此有 9 项期望值随直接输入改变，见 [[../reference/build-and-test]]。

## 仍不一致的写法

修复前后相同、或修复前也与直接输入不一致的写法，已接受的回退，plain `\halign` 模板里 `#` 之后有空格时的既有报错，以及 `\numlist{}`／`\unit{}` 部分组合与 master 不同的原因，登记在 [[../memory/doc-gaps]]「没有可见输出的命令两侧都有源码空格」一节。其中以下几项与上文机制直接相关：

- `X{ }\cmd Y`（空格写在花括号里）：**相对修复前是回退**，维护者决定接受（[[../memory/decisions/1103-group-space-before-empty-command]]）。它在命令之前留下的节点列表与 `X{} \cmd Y`、`X\ \cmd Y`、`X\space\cmd Y` 相同（左侧是汉字时，列表末尾都是 `CJK` marker 加一枚词间 glue），`space_glue` 无法区分，按后者处理，删去命令之后的空格：`中{ }\mbox{} 文` 修复前与直接输入都是 26.66pt，现在 23.33pt。后三者修复前多一枚空格，现在正确。用户手册「CJK 文字与命令交互时的间距」一节写明了这一限制与替代写法（把空格写在命令之后的花括号里，或改用 `~`）。
- 空格与空命令之间只有不排出内容的命令或空分组（`A \sbox0{x}\mbox{} B`、`A \def\x{}\mbox{} B`、`A {}\mbox{} B`、`A \stepcounter{foo}\mbox{} B`）：命令之前的节点列表与 `A \mbox{} B` 相同，只能按后者处理，命令后的空格被删去（`xCJKecglue=false` 时 17.91pt，修复前与直接输入 21.24pt；两侧都是汉字时，`xCJKecglue=true` 下与直接输入一致；`xCJKecglue=false` 下同样少一枚空格（`中 \sbox0{x}\mbox{} 文`、`中 {}\mbox{} 文` 为 20.0pt，直接输入 23.33pt），但修复前多一枚（26.66pt），不算回退）。与上一条同属“无法区分”一类，相对修复前也是回退，第六轮的 head `aed1f9d2` 上已是这样（更早的提交没有逐一核对），第七轮登记。用户手册「CJK 文字与命令交互时的间距」一节的已知限制段落写明了这一类（例子 `A \sbox0{x}\mbox{} B`、`A {}\mbox{} B`）。`xCJKecglue=true` 时第一个 `\mbox{}` 在列表里不留节点，`A \mbox{}\sbox0{x}\mbox{} B` 也落入这一类，所以上文 `\sbox` 一段的数值只对 `xCJKecglue=false` 成立。
- 两个空命令之间有空格、左侧也有空格：`xCJKecglue=false` 时，左侧是西文的 `A \mbox{} \mbox{} B`（21.24pt，直接输入 17.91pt）、`A \mbox{} \mbox{} 中`（24.16pt，直接输入 20.83pt）比直接输入多一枚空格，默认间距与可区分间距下相同。修复前更多（24.57pt、27.49pt），不算回退。左侧是汉字，或 `xCJKecglue=true`，或只有一处空格时都与直接输入一致（最终全范围审查 `final-full-110923` 的小问题 RF-M1 实测；以前写成只在 `xCJKecglue=true` 下不一致，写反了）。
- 颜色正文以“汉字 + 空格 + 空命令”结尾（`\textcolor{red}{中 \mbox{}} 文`）：修复前与现在都多一枚空格，上文的配对规则不改变它的结果。`xCJKecglue=false` 时为 26.66pt，直接输入 `{中 } 文` 23.33pt；`xCJKecglue=true` 时同为 26.66pt，直接输入 20.0pt。嵌套的空颜色命令 `中 \textcolor{red}{\textcolor{blue}{}} 文` 与直接输入一致（20.0pt），由“color body ending with a space”一组的 `tc-tc-C` 固定；第五轮曾误记为仍多一枚空格。l3color 的 `\color_group_begin:`…`\color_group_end:` 正文以空格结尾时，修复前与现在都删去命令之后的空格。

测试见 `xeCJK/testfiles/boundary-empty-space01.lvt`，组成见 [[../reference/build-and-test]]。
