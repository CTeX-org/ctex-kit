# 文档缺口

## `linestretch` 无法作类选项且无提示（#1068）

`\documentclass[linestretch=\maxdimen]{ctexart}` 静默失效（实测值仍是默认的 `\ccwd`），
而 `\ctexset{linestretch=\maxdimen}` 生效。原因是 `linestretch` 用 `\ctex_define:n`
（键空间 `ctex`，只认 `\ctexset`），类选项走 `\ctex_define_option:n`（键空间
`ctex/option`）；未知类选项被转发给标准文档类（为了透传 `a4paper` 之类），`article`
不识别便丢弃，不产生任何警告。用户无法从类选项禁用「按行宽自动伸展汉字间距」这一行为，
且完全得不到提示。#1068 只修复了 `\selectfont` 重置用户已设间距这一问题，未处理这一点。

可能的补法（**未实施**）：把 `linestretch` 也注册为类选项，或在 `ctex_define_option:n`
的未知选项转发路径上加一条检测——若某个被转发的选项名同时存在于 `ctex` 键空间，打印
提示告知用户应改用 `\ctexset`。详见反思
`llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`。

## `verify-doc-output.sh` 缺内容级哨兵

`scripts/verify-doc-output.sh:69-88` 的三条判据都是容器级的：PDF 文件存在、前四字节是 `%PDF`、体积 `>= 1024` 字节。它们能抓住「dvipdfmx 中途挂掉留下 stub」这类失败，但对「编译成功、PDF 结构完整、只是正文内容被污染」**完全没有判别力**。

已实证一例（#1054）：l3backend 与 l3kernel 版本错配时，`l3build doc` exit 0，PDF 页数与体积都正常，三条判据全过、检查全部通过，但正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本（`xeCJK.pdf` 的 `\meta` 与 fntef 示例最明显）。同一根因在 regression 路径上会让 12 个 `.tlg` 变红，doc 路径上却不产生任何非零退出码。

当前处置是两条，都不是自动检测：

- **前置预防**：曾有 `scripts/sync-l3backend.sh` 在 `l3build doc` 之前补齐匹配版本的 backend，从源头消除这个已知成因；该脚本已随上游把 l3backend 并入 l3kernel 而在 #1074 撤除。**注意这使本缺口更加裸露**：那条防御针对的是一个已知成因，而本缺口是「任何原因导致的正文污染都检不出」，下一个同类上游问题不会再有前置预防替它挡住。
- **人工检视**：`_check-doc-package.yml` 在成功时也上传 `check-doc-<pkg>-pdf` artifact，可下载后 `pdftotext` 检索泄漏模式。这依赖人记得去看。

可能的补法（**未实施**）：在 verify 阶段对每个 PDF 跑 `pdftotext`，按已知泄漏模式（`gray 0`、`0gray`、`1.0 0.0` 等）检索并断言计数为 0。代价有两条：要维护一份模式清单，且只覆盖已知的泄漏形式——新的上游错配可能产生完全不同的泄漏文本。实现前还需先确认这些模式不会与正常正文冲突（手册里讨论颜色模型时可能正常出现 `gray`）。

详见反思 `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md` 与 `llmdoc/reference/build-and-test.md` 的「文档编译校验」一节。

## 普通 stream 与符号命令在正文无类别但有可见输出时入口空格位置错（#1091 遗留）

#1091 只为 `stream-ulem`（借 `ulem` 扫描的线型命令）修好了入口空格的位置：正文在第一个字符之前先排出盒子、规则或显式 glue 时，命令前的源码空格原样留在这些内容之前。其他 capture 没有同样的处理：

- 普通 stream（如 `符 \href{..}{\usebox\tri} 后`）与独立符号命令（`符 \CJKunderdot{\usebox\tri} 后`）的正文没有字符类别、但有可见输出时，入口 marker 与空格仍在结束时由 `\@@_boundary_replay_before:` 重放，空格落到命令之后。原因是它们没有 `ulem` 的 `\UL@stop`／`\UL@reskip` 这类“内容即将排到外层”的拦截点，`entry` 字段对它们始终为空。
- 非 ulem 路径的 Boundary→FullLeft／FullRight 不向 capture 报告类别；#1091 只在 ulem 分支的 FullLeft 补了 `CJK` 报告。本地审查 R1 后，ulem 分支以全角右标点**结尾**的正文已经与直接输入一致（`tail` 置 `punct`），R9 后以全角左标点结尾的正文（单层与嵌套链上的内层，`tail` 置 `left` 或 `punct`）也与直接输入一致，但以全角右标点**开头**的装饰正文仍未处理；左标点在正文内层分组里的写法也未处理（见下文 R9 一条，R10 补记了原因）。
  - 实测例子（R6 修复过程中记录，修复前后都与直接输入不一致）：正文以全角标点开头、紧接西文时，普通 stream 与 ulem 都有问题，如 `\href{x}{。z} 后`、`\textcolor{red}{。z} 后`、`\uline{。z} 后`。其中 `\uline{。z} 后` 在 v3.10.6 差 6.66pt，现在差 3.33pt。普通 stream 中全角标点之后接西文、西文位于正文末尾时也有同样的问题：`\href{x}{中。z} 后` 在 v3.10.6 与现在都差 3.33pt。
  - 嵌套线型命令内层与盒子里的同类写法（全角标点之后还有字符）是 `ad8dc88b` 引入的回退。R6 只修好了直接写在嵌套内层、标点后紧接西文的三种（`\uline{\sout{中。z}} 后`、`\uline{\sout{中“z}} 后`、`\CJKunderline{\CJKsout{中。z}}x`），而且 R6 的 `\@@_ulem_onin_report_default:` 又引入两处回退：标点后再接汉字时不补报（R7-B1），首类别为空时在内层盒子里补左边界 glue（R7-I1）；`\mbox` 里的变体（R7-I2）也没有修好。R7 后改由 `\@@_ulem_report_last:n` 在五个全角标点转换的非 ulem 分支补报 `default` 或 `CJK`，只写 `stream-ulem` 层（所有外层线型命令，包括隔着 `\mbox` 的外层）的末类别与 `tail=char`，不设首类别；这些写法（含标点后再接标点与汉字、`\mbox` 变体）在内层正文以字符结尾时与直接输入一致。R7 当时写“现在都与直接输入一致”说大了：内层正文由 `\UL@onin` 整段排进盒子，不经过 `\UL@reskip`／`\UL@stop`，最后一个字符之后的 `\hspace*`、`\quad`、`\rule` 等内容不会把 `tail` 改成 `content`，R7 写入的 `tail=char` 于是让 `中 \uline{\sout{中（A）中\hspace*{1em}}} 吗`（77.5pt，直接输入 80.83pt）等五种写法相对 `f289ffa8` 与 v3.10.6 回退（R8-I1）；没有标点的 `中 \uline{\sout{中\hspace*{1em}}} 吗`（40.0pt，直接输入 43.33pt）从 `ad8dc88b` 起就不对，v3.10.6 碰巧正确（结束符 `*` 被当作西文字符），此前也没有记录。R8 在内层正文结束、盒子关闭之前由 `\@@_ulem_onin_tail_check:` 检查内层盒子的末节点，这些写法现由 `fntef-entry-space01` TEST 9 的 25 项固定。R8 的检查把末节点 glue 一律当作内容，也把全角左标点自己排出的 `\penalty10000 \glue0pt` 算了进去，`符 \uline{\sout{中（}} 后` 因此为 43.33pt（直接输入与 `b4f7a25d` 都是 40.0pt，R9-I1）；R9 由 `\@@_ulem_onin_tail_glue:` 在 `tail` 为 `left` 时认出这一对节点，R10 改为只在 penalty 之前正是标点处补的 `ulem-left` marker 时才认（R9 的“再前面不是 glue”把 `中（\mbox{}~` 里用户写的 `~` 也认成了标点的节点，R10-I1），现由 TEST 15 固定。这个补报只写 `stream-ulem` 层，不能直接推广到上面的普通 stream：`\mbox` 等盒子的 capture 层在盒子结束时读取末尾 marker 决定末类别，R7 实测写这一层时 `中 \uline{\sout{\mbox{中（A）}中}} 吗` 多出一枚西文间距；普通 stream 的 capture 层若也写，会不会改变非装饰路径的边界结果，尚未实测。
  - 仍未覆盖（R7 前后与 `b9c023b1` 相同，v3.10.6 也不对）：嵌套内层正文以全角标点开头时首类别为空，外层左侧没有按标点处理：`他说\CJKunderline{\CJKsout{“OK”}}吗`（59.71pt，oracle 65.56pt）、`他说\uline{\sout{（A）}}吗`（51.16pt，oracle 57.5pt）、`中\CJKunderline{\CJKsout{《A》中}}吗`（52.05pt，oracle 57.5pt）、`符\uline{\sout{。z}}后`（34.44pt，oracle 37.77pt）。外层先有内容、内层以全角左标点开头的 `中 \uline{中\hspace{1em}\sout{（A）中}} 吗` 属于同一缺口：R7 后 71.16pt，`b9c023b1` 与 v3.10.6 为 74.49pt，oracle 77.5pt，数值变化来自 FullLeft→Default 现在补报 `default`。补法尚未确定；R7-I1 说明不能在内层盒子里设首类别，否则左边界 glue 会排进盒子。
- 线型命令右边界还有四项修复前后相同的既有差异未覆盖：正文以 `\textit{x}` 结尾时与直接输入差 0.54pt（斜体校正）；`\CJKunderline{中 }`、`\CJKunderline{\CJKsout{中} }` 这类“字符后接正文末尾空格”与带花括号的直接输入差 3.33pt（R8 复核：正文末尾是 `\relax` 时同样如此，单层 `符 \uline{中\relax} 后`、`符 \CJKunderline{中\relax} 后` 与普通 stream `符 \textcolor{red}{中\relax} 后` 在 v3.10.6 也是 30.0pt 对 33.33pt；嵌套版本 `符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后` 从 `ad8dc88b` 起也差 3.33pt，`ef49ca4e` 与 v3.10.6 碰巧一致，属于同一差异）；符号型命令以全角右标点结尾（`\CJKunderdot{中。} x`、`\CJKunderline{\CJKunderdot{中。}} x`），原因是符号型命令不经 ulem，正文末尾没有扫描标记 `\s_@@_ulem_body`，标点处也不调用 `\@@_ulem_punct_peek:`；公式加尾随空格（`\CJKunderline{中$x$ } y`，嵌套版本 `符 \uline{\sout{中$x$ }} 后` 同样）与带花括号的直接输入差 3.33pt。此前列在这里的“嵌套线型命令内层以全角右标点结尾”（本地审查 R2-M2）已在 R3 修好：`\UL@onin` 的正文开头置 `\l_@@_ulem_onin_bool`，原生 FullRight 分支据此调用 peek，`\@@_ulem_nest_mark:` 再在外层 peek 一次。符号型命令可能的补法（**未实施**，推断未实测）：给符号型命令的正文末尾也放一个扫描标记，并让其中的全角右标点调用同样的 peek；先要确认符号型命令的 capture 层与 `tail` 字段在结束时能被读到。
- 嵌套线型命令与盒子相关的既有差异（本地增量审查 R8 盲审的范围外观察与 R8、R9 复核记下，v3.10.6 已有，#1091 未修）：
  - `\mbox`、`\fbox` 里的线型命令左边界本来就错：`中\mbox{\uline{\sout{中（A）中}}}x` 中“中”与 `\mbox` 之间是 3.33pt 的 `\CJKecglue`，直接输入是 `\CJKglue`。以前右侧也错，两者抵消；R7 补好右侧后总宽度为 69.44pt，直接输入 66.11pt。同一缺口的另一例是盒子外的西文与盒子里的线型命令（R9 复核记下）：`符 x\mbox{\uline{\sout{中}}} 后` 与单层 `符 x\mbox{\uline{中}} 后` 中，x 与 `\mbox` 之间缺少 `\CJKecglue`。v3.10.6 上嵌套写法的总宽度碰巧与直接输入一致，但节点层面两侧都不对：左侧同样缺少这枚间距，`\mbox` 后面又因盒子末尾是 default marker 多补一枚西文间距，两处错误抵消；单层写法在 v3.10.6 上就是 38.61pt 对 41.94pt。现在右侧已经正确，嵌套写法于是显出左侧缺的间距（`ad8dc88b` 起 38.61pt 对 41.94pt），R9 未修。R9 的左侧重放在 `\UL@onin` 进入时读外层列表末尾的 marker；这里 x 在 `\mbox` 外，盒子里读不到它（推断，未单独实测）。
  - `符\uline{\mbox{“OK”中}}后` 的装饰内容整段消失（v3.10.6 已有，v3.9.1 正常），与右边界无关，建议单独立项。
  - 以下写法在所有版本（含 v3.10.6、`ef49ca4e`）都与直接输入不一致：`\uline{\hbox{（A）}}` 带两侧空格、`\uline{\sout{\hbox{…}}}`、`\uline{\textcolor{red}{\sout{中（A）中}}}x`、`\uline{\sout{中}\sout{（A）中}}x`、`\uline{\sout{中（A）中}z}吗`；正文只有 `\hspace*` 的 `符 \uline{\sout{\hspace*{1em}}} 后`（36.66pt，直接输入 33.33pt）；issue 写法的嵌套版本 `普通字符 \uline{\sout{\hspace*{0.5em}xxxx\hspace*{0.5em}}} 后续`（97.78pt，直接输入 94.45pt；v3.9.1 两者都是 97.78pt）。R8 时这里还列有 `符 \uline{\sout{\xout{中}x}} 后`（38.61pt，直接输入 41.94pt，v3.9.1 正确），R9 补上嵌套命令与相邻字符的连接后已与直接输入一致，由 `fntef-entry-space01` TEST 15 的 `three-level-cjk-then-latin` 固定。
- 本地增量审查 R9 修复后仍未覆盖（#1091 未修）：
  - 全角左标点在正文内层分组里：`符 \uline{{中（}} 后`、`符 \uline{\textbf{中（}} 后`，43.33pt，直接输入 40.0pt，差 3.33pt，所有版本都不对，v3.9.1 更差。R10 分析了原因：标点的下一个记号是分组结束，`tail` 置为 `left`，结束时按 `中（\relax{} 后` 处理，命令后的空格保留；直接输入 `{中（} 后` 里标点处的 `\ignorespaces` 在分组结束处停下，分组之后的空格仍被边界处理删去。R9 的 CHANGELOG、`\changes` 与 lvt 注释把这种情形写成已处理（“分组结束”），R10 已更正为“标点不在正文内的分组里时”。可能的补法（**未实施**，推断未实测）：在 `left` 之外区分“标点之后是分组结束”，结束时不按 `中（\relax{}` 处理，改为按直接输入的分组结尾删去命令后的空格；要先确认分组之后还有 `\relax` 等记号时的直接输入结果。
  - 中间层里嵌套命令与汉字之间的空格：`符 \uline{\sout{\xout{中} 中}} 后`，43.33pt，直接输入 40.0pt，所有版本都不对。这枚空格没有按 CJK 规则删去。
  - 三层并列的连接：`符 \uline{\sout{\xout{x}}\sout{中}} 后` 等三种写法，38.61pt，直接输入 41.94pt；v3.10.6 上其中一种正确。
  - 公式后接嵌套命令：`符 \uline{$x$\sout{中}} 后`。R9 的左侧重放只处理外层列表末尾是 CJK／default marker 的情况，公式之后是否有可读的 marker 尚未确认。
  - 盒子外的西文与盒子里的线型命令 `符 x\mbox{\uline{\sout{中}}} 后`，属于上面 `\mbox` 左边界一条。
  - 此外仍有上文记下的 `\uline{\sout{中 }}`、`\uline{\sout{中\relax}}` 嵌套版（`ad8dc88b` 起差 3.33pt）与 R7 记下的嵌套内层首类别为空的写法。
- 本地增量审查 R10 的范围外观察与修复后仍未覆盖（#1091 未修）：
  - `CJKspace=true` 时 `符 \uline{（}x`：28.61pt，直接输入 25.28pt；审查基线与 v3.10.6 为 31.94pt，现在差距由 6.66pt 缩小到 3.33pt，仍不一致，原因未分析。
  - 两层嵌套命令与汉字之间的空格：`\uline{\sout{中} 中}`、`\uline{\sout{中}\ 中}`、`\uline{\sout{中} \sout{中}}`、`\CJKunderline{\CJKsout{中} 中}` 都是 23.33pt，直接输入 20.0pt，v3.10.x 都如此。这枚空格没有按 CJK 规则删去，现象与上文三层的 `符 \uline{\sout{\xout{中} 中}} 后` 相同；此前只登记了三层版本。
  - 单层分组开头的空格：`\uline{中{ 中}}` 为 20.0pt，直接输入 23.33pt（审查基线相同，v3.9.1 正确）。分组里的空格被按 CJK 规则删去，现象与 R10-I2 相同；R10 只处理了嵌套内层（`\UL@onin`）正文开头的空格，这里是单层正文里的分组，两者是否同一原因尚未确认。
  - `符 \CJKunderline{\CJKsout{中$a$ }} 后`：公式加尾随空格结尾后接命令外的空格，所有版本都差 3.33pt，属于上文“公式加尾随空格”一类既有差异。
  - R10 时这里写“相对 v3.10.6 的已知差异仍是三项，约 500 项合并矩阵没有发现新的差异”，把一个矩阵上的结论写成了全称结论（R11-I3）。R11 盲审用 4104 项矩阵找到 135 项在 `9c6bd737` 上与直接输入不一致、而 v3.10.6 一致的写法，其中 68 项自 R9 起出现（`\space` 与多层分组开头的空格 20 项，外层左边界加内层以非字符内容开头 48 项），另 67 项在 R9 前的 `35ab5fe7` 上也不一致（如 `x\uline{\sout{ 中}}x`）。这些主要是内层开头空格与左边界的问题，已由 `28afedc1` 处理，但没有在 4104 项矩阵上逐项复核，下一条的结论只对 r9big 矩阵成立。
- 本地增量审查 R11 修复（`28afedc1`）后：
  - 相对 v3.10.6 的差异，限于 `tmp/i1091/fix2/r9big.tex` 这个 647 项的合并矩阵：当前代码与直接输入不一致、而 v3.10.6 一致的有 4 项，`符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后`（`ad8dc88b` 起）、`符 x\mbox{\uline{\sout{中}}} 后`（v3.10.6 两侧错误抵消），以及下一条的 `x\uline{\sout{\rule{1pt}{1pt}中}}x`。其他矩阵上的结果以实测为准，不能从这一句推出。
  - **嵌套内层以未注册的盒子开头时多补左边界。** 内层正文以原始 `\hbox{}`、`\hbox to 1em{}`、`\hbox{中}`、`\rule{..}{..}`、`\rule{0pt}{1em}`、`\phantom`、`\raisebox` 开头时，第一个字符出现时内层盒子的末节点是 hbox，`\@@_boundary_emit_left_hook:n` 不处理 hbox，入口仍为 `armed`，于是在盒子之后补左边界，比直接输入多一枚 `\CJKecglue`（3.33pt）：`x\uline{\sout{\rule{1pt}{1pt}中}}x` 为 28.22pt，直接输入 24.89pt；`中\uline{\sout{\hbox{a}中}}x` 为 36.94pt，直接输入 33.61pt。前面是汉字时，以 `\vbox{\hbox{a}}` 开头的 `中\uline{\sout{\vbox{\hbox{a}}中}}x` 同样多 3.33pt（`ad8dc88b` 起；在 `6090b885` 上仍为 36.94pt，直接输入 33.61pt，v3.10.6 一致，探测文件 `tmp/i1091/fix2/r12vb.tex`）。R11 时写“去掉 vlist 后结果不变，原因尚未查明”，R12 查明：`\vbox{}` 开头（`x\uline{\sout{\vbox{}中}}x`）现在由钩子的 vlist 分支处理，并有测试；上面这个写法里，正文的第一个字符是 `\vbox` 里 `\hbox` 中的 a，它出现、触发左边界时，onin 布尔量已被这个 `\hbox` 开头的 `\UL@hrest` 清掉，钩子不在嵌套链上，不起作用，原因与 hbox 开头一类相近。探测文件 `tmp/i1091/fix2/r12box2.tex`（56 项，单层以 `S-`、嵌套以 `N-` 开头）。这类差异自 `ad8dc88b` 起就存在，在 `ad8dc88b`、`6b197547`、`07a27a93`、`27613fed`、`d0539362`、`cd4aa3c2`、`35ab5fe7`、`c1b1411c` 上结果都相同，以前右侧恰好少一枚间距抵消。同一批写法中以注册盒子命令开头的嵌套写法（`\mbox{}`、`\mbox{a}`、`\fbox{}`、`\mbox{\hspace{1em}}` 等）在 v3.10.6 与 `ef49ca4e` 上不对、现在正确。单层写法 `x\uline{\hbox{}中}x`、`中\uline{\hbox{a}中}x`、`中\uline{\phantom{a}中}x` 在 v3.10.6 上本来就多一枚间距。难点是：钩子看到的节点列表里，原始 `\hbox{}` 与透明的 `\mbox{}` 都表现为末节点是零宽 hbox、后面没有 marker，只凭节点无法区分；直接输入时 `\mbox` 走 box capture，内容不可见时重放入口 marker。可能的补法（**未实施**，推断未实测）：box capture 以“没有可见输出”结束时留下一个标记，钩子据此区分这两种盒子。
  - R11 历史补充的范围外观察（在 `9c6bd737` 上测得，与 `c1b1411c`、`35ab5fe7` 相同，`28afedc1` 后未复核）：内层走公式重排分支、外层正文随后以字符结尾时差 3.33pt，如 `\uline{x\sout{中$a$ }中}x` 为 45.84pt，直接输入 49.17pt，`\uline{x\sout{中$a$ }x}中` 同样如此。这些写法后面没有命令外的空格，是否属于上文“公式加尾随空格”一类尚未确认。R12 历史补充在 `50452dbc` 上复核，两项仍为 45.84pt，与登记内容一致。
- 本地增量审查 R12 修复（`6090b885`）后。下面各项都在 `6090b885` 上实测，v3.10.6 与直接输入一致、当前代码不一致，#1091 未修：
  - **内层以空格或 `~` 加西文开头、后接汉字**：`符 \uline{\sout{ x}中} 后` 为 45.27pt，直接输入 41.94pt，`符 \uline{\sout{~x}中} 后` 同样如此；自 R9 的修复 `0387c937` 起（`35ab5fe7` 与 v3.10.6 正确）。与之相对，`符 \uline{\sout{x}中} 后`、`x \uline{\sout{ x}中} 后` 在 v3.10.6 上不对、现在正确；单层写法 `符 \uline{ x中} 后` 在 v3.9.1、v3.10.6 与现在都不对。R12 盲审报告还列了 `\sout{\space x}`、`\sout{{ x}}`、`\sout{\hspace{1em}x}`、`\sout{\kern1pt x}`、`\sout{\special{x}x}` 等同类写法（在 `50452dbc` 上测得，`6090b885` 后未逐项复核）。
  - **外层正文以分组或公式结束后接嵌套命令**：`x\uline{{中}\sout{$a$中}}x` 为 49.17pt，直接输入 45.84pt；`中\uline{$a$\sout{中}}中` 为 38.62pt，直接输入 41.95pt；都自 `ad8dc88b` 起。左侧重放与右侧 marker 在这两种前缀下的处理不对，具体哪一步出错尚未分析。R9 一条记下的 `符 \uline{$x$\sout{中}} 后` 可能属于同一类（未确认）。
  - **单层以注册盒子命令开头**：`x\uline{\fbox{}中}x`、`x\uline{\mbox{\hspace{1em}}中}x` 少 3.33pt（30.69pt 对 34.02pt，33.89pt 对 37.22pt），自 `ad8dc88b` 起；前面是汉字时一致。探测文件 `tmp/i1091/fix2/r12s.tex`。
  - **`{中}` 前缀后接内层开头的空格（R12-M1，决定不改）**：直接输入 `{中}{ 中}` 时分组结束触发的转换开启源码空格检查，空格被删去（20.0pt）；`\uline{{中}\sout{ 中}}` 到达 `\@@_ulem_onin_lead_put:` 时的状态与 `\uline{中\sout{ 中}}` 相同，无法区分检查是分组结束还是外层命令开启的，于是按普通空格保留（23.33pt），与 v3.10.6 相同；`\uline{{中}\sout{\space 中}}`、`\uline{{中}\sout{{{ 中}}}}` 在 `9c6bd737` 上碰巧一致，R11 起也是 23.33pt。dtx 注释与 architecture 写明了这一点。可能的补法（**未实施**，推断未实测）：在分组结束开启检查时另记一个来源标记，`\@@_ulem_onin_lead_put:` 据此决定是否清除。
  - **`\sbox` 里的源码空格检查受前一个写法影响（核心既有问题）**：前一个写法留下的 `\g_@@_glue_check_pending_bool` 会进入随后的 `\sbox`，现场排的 `\sbox{中{ 中}}` 宽度随它前面是什么写法而变化；v3.10.6 同样如此，v3.9.1 没有这个问题。`fntef-entry-space01` 因此把 `\sbox` 用例的 oracle 放在导言区预先存好，探测矩阵 r12m 的 `i2-sp` 也因此在矩阵里显示为不一致、单独运行时一致。可能的补法（**未实施**，推断未实测）：`\sbox` 等 capture 暂停的入口保存并清除 pending，结束时恢复；要先确认这不会改变 #992 对 `\sbox` 隔离的既有结果。
  - **相对 v3.10.6 的差异，限于三个矩阵**：r9big（646 项）有 4 项，即上文 R11 一条已登记的 4 项；r12box2（56 项）有 12 项，10 项是嵌套内层以未注册盒子开头（`N-hbox0-l`、`N-hboxa-c`、`N-hboxc-l`、`N-hboxto-l`、`N-phant-c`、`N-raise-c`、`N-rule-l`、`N-rulec-l`、`N-rulex-c`、`N-strut0-l`），另 2 项是单层 `\fbox{}`、`\mbox{\hspace{1em}}` 开头（`S-fbox-l`、`S-mboxh-l`）；r12oos（7 项）有 4 项，即上面第一、二条的四个写法。另有不在这三个矩阵里的 `中\uline{\sout{\vbox{\hbox{a}}中}}x`（见上文 R11 一条）。这一结论只对这些矩阵成立。R13 后又在 r13m、r13rest 两个矩阵上比对，结果见下文 R13 一节。
  - **R12 盲审的范围外观察中已修复的两类**：`中\uline{中 \sout{\mbox{a}中}}中`（`50452dbc` 上 48.33pt，直接输入 51.66pt）与 `CJKspace=true` 下的 `中\uline{中 \sout{中}}中`（40.0pt，直接输入 43.33pt，盲审称同类共 12 项）由 `6090b885` 的 `CJK-space` 重放修好，现由 `fntef-entry-space01` TEST 15 固定。
- 本地增量审查 R13 修复（`17de9314`）后。R13-I1 指出的颜色写在外层正文、中间层或前一个兄弟装饰里的写法（`符 \uline{\color{red}\sout{~中}} 后` 等）已修好，由 TEST 15 固定。下面前两项在 `17de9314` 上实测，v3.10.6 与直接输入一致、当前代码不一致，都自 `ad8dc88b` 起，#1091 未修：
  - **外层正文里 `\special` 之后接嵌套命令**：`x\uline{\special{x}\sout{中}}x`（27.22pt，直接输入 23.89pt）；先有颜色的 `x\uline{\color{red}\special{x}\sout{中}}x`（27.22pt 对 23.89pt）与 `符 \uline{\color{red}\special{x}\sout{中}} 后`（30.0pt 对 33.33pt）。前两项在 `ad8dc88b`、`6b197547`、`cd4aa3c2`、`35ab5fe7`、`0387c937`、`bebac723` 上结果相同；第三项在 `ad8dc88b` 与 `35ab5fe7` 上核对过，结果相同。单层的 `x\uline{\special{x}中}x`、`x\uline{\color{red}\special{x}中}x`（27.22pt 对 23.89pt）在 v3.10.6 上同样不对，不算回退。
  - **外层正文里前一个兄弟装饰只有 `~`**：`x\uline{\sout{~}\sout{中}}x`、`x\uline{\sout{~}\sout{\color{red}中}}x`，30.55pt，直接输入 27.22pt，在上一项所列六个提交上结果相同。与之相对，前一个兄弟装饰只有颜色的 `符 \uline{\sout{\color{red}}\sout{~中}} 后` 已由 R13 修好。
  - **R13 盲审的范围外观察**（当前代码、`50452dbc` 与 v3.10.6 都与直接输入不一致，不是回退）：`x\uline{\sout{\hypertarget{a}{}中}}x`、`x\uline{\sout{\phantomsection 中}}x`（23.89pt，直接输入 27.22pt）；`x\mbox{\uline{中}}`（15.28pt 对 18.61pt）；`符 \uline{\sout{~中$a$ }} 后`（45.28pt 对 48.61pt）；`x\uline{\sout{“中”$a$ }x}x`。
  - **相对 v3.10.6 的差异，补上 R13 的两个矩阵**：r13m（80 项）上当前代码有 3 项不一致，`outer-color-spec-sp`、`outer-color-spec-xx`、`sib-tie-then-color-xx`，即上面前两项里的写法，v3.10.6 都一致；r13rest（7 项）上 `o-s`、`o-cs`、`sib-tie`、`sib-tie-c` 四项 v3.10.6 一致、当前不一致，`s-cs`、`s-s` 两项（上面的单层写法）各版本都不一致。r9big、r12box2、r12oos 的结论不变（见上文 R12 一节）。这一结论同样只对这些矩阵成立。
  - **R14 盲审的范围外观察**（`65708cec` 上测得，与 `1fbda2f1`、v3.10.6 相同，不是回退）：`CJKspace=true` 时单层 `符 \uline{~中} 后` 与嵌套 `符 \uline{\sout{~中}} 后` 都是 39.99pt，直接输入 `符 {~中} 后` 为 36.66pt，v3.9.1 同样；`中\uline{\sout{\color{red}{ }中}}中` 为 33.33pt，直接输入 30.0pt（v3.10.6 为 36.66pt），与上文“`{中}` 前缀后接内层开头的空格”同属分组里的空格一类；内层以空的嵌套装饰开头，如 `x\uline{\sout{\xout{}中}}x` 为 23.89pt，直接输入 `x{{}中}x` 为 27.22pt，三个版本都一样。
  - **R11-I3 的状态**：R11、R12、R13 各轮审查点名的写法，已全部修好或登记在本文件，R11-I3 与 R13-I1 合并跟踪；不在这些矩阵里的写法仍以实测为准。

目前没有用户报告这几类写法。可能的补法（**未实施**）：为普通 stream 找到一个在正文首个可见输出之前运行的钩子，复用 `entry` 的 armed／resolved 语义；或在 `\@@_boundary_inline_stream_end:n` 检查本层是否已排出有宽度的内容，再决定入口空格放在哪里（推断，未实测：后者要到结束时才判断，那时内容已在列表里，除非先把已排出的节点取下，否则空格放不到内容之前）。全角标点方向可以在 Boundary→FullLeft／FullRight 的通用转换里报告 `CJK`，但要先确认不会改变非装饰路径的边界结果。接手时先读 `llmdoc/architecture/xecjk-architecture.md` 的「ulem 结束符与入口空格（#1091）」与反思 `llmdoc/memory/reflections/1091-fntef-ulem-terminator-entry-space.md`。

## 更改历史中旧 `\changes` 条目的 `|` 短抄录泄漏（#1091 R3 发现，未处理）

`\changes` 说明文字进入 `.glo` 后，makeindex 把第一个 `|` 当作 encap 符，后面的文字被当作页码格式命令执行，更改历史里因此出现文字泄漏。#1091 R3 把本次新增条目改为 `\texttt`、`\tn` 和文字描述后，`pdftotext` 检索中本次条目的 `dex10432191`、`dex9189170` 已消失；但仍有三处 `hdclindex8526159`、`hdclindex163`、`hdclindex193354` 来自此前版本的旧条目，其中之一是 `xeCJK/xeCJK.dtx` 约 536 行 v3.10.4 条目里的 `|CJKglue|`。它们不在 #1091 的范围内，未处理。

可能的补法（**未实施**）：逐条把旧 `\changes` 里的 `|...|` 改为 `\texttt{...}`、`\cs{...}` 或 `\tn{...}`，运行 `make changelog` 重新生成 CHANGELOG，并按 `llmdoc/reference/build-and-test.md`「文档排版循环」一节的方法用 `pdftotext` 检索 `hdclindex` 与 `dex[0-9]`，确认计数为 0。已发布版本的条目改动只涉及排版，但要确认重新生成的 CHANGELOG 只有预期的文字变化。
