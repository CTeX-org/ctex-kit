# 没有可见输出的命令与命令之后的源码空格（#1103）

本文说明 capture/register 框架里“已注册命令执行后没有可见输出”这一条结束路径：入口空格怎样重放，命令之后紧跟的源码空格由谁删去。框架的整体结构见 [[xecjk-architecture]]「capture/register 框架」；过程与教训见 [[../memory/reflections/1103-empty-output-after-space]]。实现都在 `xeCJK/xeCJK.dtx`。

## 比较基准

oracle 仍是 #992 的直接输入：把命令从源码中删去后的写法（[[../memory/decisions/992-command-boundary-capture-register]]）。没有可见输出时，删去命令会让两侧的源码空格相邻，TeX 把它们读成**一个**空格记号：`中 \cmd 文` 对应 `中  文`，即只有一处空格。

#1103 之前，capture 结束时 `\@@_boundary_replay_before:` 把入口取下的空格放回，命令之后的空格又排出一枚，两枚都留在列表里。两侧都是汉字时多出两枚空格的宽度（`中 \mbox{} 文` 为 26.66pt，直接输入 20.0pt）；入口前不是汉字时多一枚（`A \cmd B`、`$x$ \cmd 文`）。

修法拆成两部分，原因是重放发生在命令的结束钩子里，命令自己的代码这时可能还没执行完，后面的源码空格在这一刻还处理不了：

1. 结束时只决定 marker 与入口 glue（`\@@_boundary_replay_before_empty:`）。
2. 命令真正结束之后，用 peek 检查下一个记号，删去紧跟的空格（`\@@_boundary_after_space_check:`）。

## capture 的两个新字段

每层 capture 在 `\@@_boundary_capture_allocate:n` 时新建：

- `g_@@_boundary_capture_<n>_space_glue_tl`：`\@@_boundary_capture_space:` 刚取下入口 glue 时 `space_flag` 字段的值，表示入口是否取下了一枚真实的词间 glue。不能直接用 `space_flag`：入口前是 `CJK-space` marker 时，`space_flag` 随后会被改为真，两种情形就分不开了。
- `g_@@_boundary_capture_<n>_after_space_tl`：capture 开始时内层留下的记录是否仍然有效（`\@@_boundary_after_space_if_armed:TF`）。用于 `\textcolor{red}{}` 这类嵌套空命令：入口空格由内层的颜色命令记下，实际属于外层命令，外层要能把记录接过来。

`\@@_boundary_capture_begin:` 先读取上述有效性，再清除全局记录 `\g_@@_boundary_after_space_bool`，所以下一个 capture 开始时旧记录总会失效。

## 结束时的重放：`\@@_boundary_replay_before_empty:`

调用点（都是“capture 没有观察到任何类别”的情形）：

- `\@@_boundary_inline_stream_end:n`：首类别为空、`entry` 字段不是 `resolved` 时（`resolved` 时仍按 #1091 的规则只重放 `math` 或调用 `\@@_boundary_resolved_end_hook:`）。
- `\@@_boundary_hmode_transparent_end:`。
- `\@@_boundary_box_end_transparent:n`：取出的盒子宽、高、深之和为零时（`\l_@@_boundary_box_empty_bool`）。

不调用、仍用原来的 `\@@_boundary_replay_before:` 的路径：`\@@_boundary_last_box_end:n` 末节点不是 hlist 的分支，以及尺寸非零的透明盒子。这些情形里命令确实排出了东西，入口空格与命令之后的空格不相邻。

做法分三种：

- 入口前是 `CJK-space` marker、没有取下 glue（`中 \cmd`）：汉字后的源码空格已被前视吃掉，列表里只有 marker。直接输入 `中 X` 也只留 marker，所以只重放 `CJK-space` marker、清除 `\g_@@_glue_check_pending_bool`，不排出空格 glue。
- `space_glue` 为真（`{中} \cmd`、`A \cmd`）：照常调用 `\@@_boundary_replay_before:` 放回 marker 与 glue。
- 以上两种都调用 `\@@_boundary_after_space_arm:` 记下状态。其余情形照常重放；若本层 `after_space` 为真（从内层接过记录），调用 `\@@_boundary_after_space_rearm:` 把记录交给更外一层。

## 记录：arm、rearm 与两个标志

记录是一个全局布尔量加一个 token list：`\g_@@_boundary_after_space_tl` 的内容为“外层层号（当前层号减一）；`\lastnodetype`、`\lastkern`、`\lastskip`”，由 `\@@_boundary_after_space_rearm:` 写入，状态部分由可展开的 `\@@_boundary_after_space_state:` 生成。`\@@_boundary_after_space_arm:` 先调用 rearm，再设置两个标志：

- `\g_@@_boundary_after_space_drop_bool`：只重放了 `CJK-space` marker（没有 glue）时为真。删去空格时还要把列表末尾的 glue `\unskip` 掉并关掉源码空格检查，因为直接输入 `中  X` 不开启这项检查。
- `\g_@@_boundary_after_space_unchecked_bool`：放回了真实 glue、入口前是 `CJK` 或 `CJK-space` marker、capture 开始时 pending 为假（`中{} \cmd`、`中\ \cmd`）时为真。直接输入不检查这枚空格、后面的汉字保留它，所以删去命令之后的空格时同样关掉检查。本层 `after_space` 为真（记录来自内层）时保留内层设置的值。

## 检查：`\@@_boundary_after_space_check:`

只在记录有效、且记录里的层号与列表末尾状态都与当前一致时动作；不一致说明命令在重放之后又排出了内容，后面的空格不再与入口空格相邻，记录作废。

调用点在各类结束路径的最后：

- 核心：`\@@_boundary_inline_box_end:n`、`\@@_boundary_inline_last_box_end:n`、`\@@_boundary_inline_stream_end:n`、`\@@_boundary_hmode_transparent_end:`。
- xeCJKfntef：`\@@_ulem_end:` 末尾、`\@@_under_symbol_auxii:nnnnnn` 末尾。
- 颜色：`\@@_boundary_textcolor:nnn` 的非公式分支（正文两端不是公式时 `\textcolor` 不启动 capture，`\reset@color` 的钩子之后还有 `\textcolor` 自己的结束分组）。
- hyperref：`\phantomsection`、`\MakeLinkTarget` 的 `cmd/.../after` 钩子；`\hypertarget` 的包装在第二个参数为空时调用。第二个参数不为空时会排出可见内容，由字符一侧的检查处理；曾经无条件调用，结果 `\hypertarget{t5}{锚}` 之后的间距也被删去（`hyperref-anchor-ecglue01` 发现）。

外层这几处要再调用一次的原因：内层被注册的命令（`\hyper@anchor`、`\__hyp_target_raise:n`、`\set@color`／`\reset@color`）结束时，外层命令的代码还在后面，内层的检查看到的下一个记号不是源码。

## peek 规则

`\@@_boundary_after_space_peek:` 在 `\group_align_safe_begin:`／`end:` 之间用 `\peek_after:Nw` 看下一个记号，不展开它，由 `\@@_boundary_after_space_test:` 分派：

- **空格**：作废记录并删去连续的空格（`\peek_remove_spaces:n`）。`drop` 为真时先 `\unskip` 末尾 glue、清 pending；`unchecked` 为真时清 pending。
- **名字以 `__hook` 开头的控制序列**（`\@@_boundary_after_space_hook:nN`）：展开一层再 peek。LaTeX 命令钩子在 `after` 钩子之后紧跟 `\__hook_next …` 一类宏，钩子里看到的不是源码的下一个记号。判断用 `\str_range:nnn` 取名字前 6 个字符，名字先经 `\exp_args:Ne` 求出。
- **其他控制序列与花括号**：保留记录，不作废，留给外层命令结束时再检查。
- **其他记号**：作废记录。

`drop` 为真时，删去空格之后或“其他记号”分支里，若下一个记号是 `$`，`\@@_boundary_after_space_math:` 删去末尾的 `CJK-space` marker、清 pending 并补 `\xeCJK_space_or_xecglue:`，与直接输入 `中 $x$` 在公式之前补的间距一致。

## xeCJKfntef 的透明内容分支

`\@@_ulem_onin_entry_check_space:nn` 在入口有源码空格、`\g_@@_ulem_onin_transparent_bool` 为真（入口之后排出过颜色等透明命令）时，若入口前（该层 `before` 字段）是 `CJK-space` 或 `CJK-widow`，不解除入口，与没有透明内容时的 `\@@_ulem_onin_entry_keep:nn` 一致。理由来自直接输入的变化：`符 {\color{red}~中} 后` 里颜色命令没有可见输出，按上面的规则只放回 marker，汉字后的空格与 `~` 合为一处，结果与去掉颜色的 `符 {~中} 后` 相同（33.33pt；#1103 前为 36.66pt）。`fntef-entry-space01` 因此有 9 项期望值随直接输入改变，见 [[../reference/build-and-test]]。

## 仍不一致的写法

修复前后相同、仍与直接输入不一致的写法，以及 `\numlist{}`／`\unit{}` 部分组合与 master 不同的原因，登记在 [[../memory/doc-gaps]]「没有可见输出的命令两侧都有源码空格」一节。测试见 `xeCJK/testfiles/boundary-empty-space01.lvt`。
