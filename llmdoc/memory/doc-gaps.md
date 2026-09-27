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
- 非 ulem 路径的 Boundary→FullLeft／FullRight 不向 capture 报告类别；#1091 只在 ulem 分支的 FullLeft 补了 `CJK` 报告。本地审查 R1 后，ulem 分支以全角右标点**结尾**的正文已经与直接输入一致（`tail` 置 `punct`），但以全角右标点**开头**的装饰正文仍未处理。
  - 实测例子（R6 修复过程中记录，修复前后都与直接输入不一致）：正文以全角标点开头、紧接西文时，普通 stream 与 ulem 都有问题，如 `\href{x}{。z} 后`、`\textcolor{red}{。z} 后`、`\uline{。z} 后`。其中 `\uline{。z} 后` 在 v3.10.6 差 6.66pt，现在差 3.33pt。普通 stream 中全角标点之后接西文、西文位于正文末尾时也有同样的问题：`\href{x}{中。z} 后` 在 v3.10.6 与现在都差 3.33pt。
  - 嵌套线型命令内层与盒子里的同类写法（全角标点之后还有字符）是 `ad8dc88b` 引入的回退。R6 只修好了直接写在嵌套内层、标点后紧接西文的三种（`\uline{\sout{中。z}} 后`、`\uline{\sout{中“z}} 后`、`\CJKunderline{\CJKsout{中。z}}x`），而且 R6 的 `\@@_ulem_onin_report_default:` 又引入两处回退：标点后再接汉字时不补报（R7-B1），首类别为空时在内层盒子里补左边界 glue（R7-I1）；`\mbox` 里的变体（R7-I2）也没有修好。R7 后改由 `\@@_ulem_report_last:n` 在五个全角标点转换的非 ulem 分支补报 `default` 或 `CJK`，只写 `stream-ulem` 层（所有外层线型命令，包括隔着 `\mbox` 的外层）的末类别与 `tail=char`，不设首类别；这些写法（含标点后再接标点与汉字、`\mbox` 变体）在内层正文以字符结尾时与直接输入一致。R7 当时写“现在都与直接输入一致”说大了：内层正文由 `\UL@onin` 整段排进盒子，不经过 `\UL@reskip`／`\UL@stop`，最后一个字符之后的 `\hspace*`、`\quad`、`\rule` 等内容不会把 `tail` 改成 `content`，R7 写入的 `tail=char` 于是让 `中 \uline{\sout{中（A）中\hspace*{1em}}} 吗`（77.5pt，直接输入 80.83pt）等五种写法相对 `f289ffa8` 与 v3.10.6 回退（R8-I1）；没有标点的 `中 \uline{\sout{中\hspace*{1em}}} 吗`（40.0pt，直接输入 43.33pt）从 `ad8dc88b` 起就不对，v3.10.6 碰巧正确（结束符 `*` 被当作西文字符），此前也没有记录。R8 在内层正文结束、盒子关闭之前由 `\@@_ulem_onin_tail_check:` 检查内层盒子的末节点，这些写法现由 `fntef-entry-space01` TEST 9 的 25 项固定。这个补报只写 `stream-ulem` 层，不能直接推广到上面的普通 stream：`\mbox` 等盒子的 capture 层在盒子结束时读取末尾 marker 决定末类别，R7 实测写这一层时 `中 \uline{\sout{\mbox{中（A）}中}} 吗` 多出一枚西文间距；普通 stream 的 capture 层若也写，会不会改变非装饰路径的边界结果，尚未实测。
  - 仍未覆盖（R7 前后与 `b9c023b1` 相同，v3.10.6 也不对）：嵌套内层正文以全角标点开头时首类别为空，外层左侧没有按标点处理：`他说\CJKunderline{\CJKsout{“OK”}}吗`（59.71pt，oracle 65.56pt）、`他说\uline{\sout{（A）}}吗`（51.16pt，oracle 57.5pt）、`中\CJKunderline{\CJKsout{《A》中}}吗`（52.05pt，oracle 57.5pt）、`符\uline{\sout{。z}}后`（34.44pt，oracle 37.77pt）。外层先有内容、内层以全角左标点开头的 `中 \uline{中\hspace{1em}\sout{（A）中}} 吗` 属于同一缺口：R7 后 71.16pt，`b9c023b1` 与 v3.10.6 为 74.49pt，oracle 77.5pt，数值变化来自 FullLeft→Default 现在补报 `default`。补法尚未确定；R7-I1 说明不能在内层盒子里设首类别，否则左边界 glue 会排进盒子。
- 线型命令右边界还有四项修复前后相同的既有差异未覆盖：正文以 `\textit{x}` 结尾时与直接输入差 0.54pt（斜体校正）；`\CJKunderline{中 }`、`\CJKunderline{\CJKsout{中} }` 这类“字符后接正文末尾空格”与带花括号的直接输入差 3.33pt（R8 复核：正文末尾是 `\relax` 时同样如此，单层 `符 \uline{中\relax} 后`、`符 \CJKunderline{中\relax} 后` 与普通 stream `符 \textcolor{red}{中\relax} 后` 在 v3.10.6 也是 30.0pt 对 33.33pt；嵌套版本 `符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后` 从 `ad8dc88b` 起也差 3.33pt，`ef49ca4e` 与 v3.10.6 碰巧一致，属于同一差异）；符号型命令以全角右标点结尾（`\CJKunderdot{中。} x`、`\CJKunderline{\CJKunderdot{中。}} x`），原因是符号型命令不经 ulem，正文末尾没有扫描标记 `\s_@@_ulem_body`，标点处也不调用 `\@@_ulem_punct_peek:`；公式加尾随空格（`\CJKunderline{中$x$ } y`，嵌套版本 `符 \uline{\sout{中$x$ }} 后` 同样）与带花括号的直接输入差 3.33pt。此前列在这里的“嵌套线型命令内层以全角右标点结尾”（本地审查 R2-M2）已在 R3 修好：`\UL@onin` 的正文开头置 `\l_@@_ulem_onin_bool`，原生 FullRight 分支据此调用 peek，`\@@_ulem_nest_mark:` 再在外层 peek 一次。符号型命令可能的补法（**未实施**，推断未实测）：给符号型命令的正文末尾也放一个扫描标记，并让其中的全角右标点调用同样的 peek；先要确认符号型命令的 capture 层与 `tail` 字段在结束时能被读到。
- 嵌套线型命令与盒子相关的既有差异（本地增量审查 R8 盲审的范围外观察与 R8 复核记下，v3.10.6 已有，#1091 未修）：
  - `\mbox`、`\fbox` 里的线型命令左边界本来就错：`中\mbox{\uline{\sout{中（A）中}}}x` 中“中”与 `\mbox` 之间是 3.33pt 的 `\CJKecglue`，直接输入是 `\CJKglue`。以前右侧也错，两者抵消；R7 补好右侧后总宽度为 69.44pt，直接输入 66.11pt。
  - `符\uline{\mbox{“OK”中}}后` 的装饰内容整段消失（v3.10.6 已有，v3.9.1 正常），与右边界无关，建议单独立项。
  - 以下写法在所有版本（含 v3.10.6、`ef49ca4e`）都与直接输入不一致：`\uline{\hbox{（A）}}` 带两侧空格、`\uline{\sout{\hbox{…}}}`、`\uline{\textcolor{red}{\sout{中（A）中}}}x`、`\uline{\sout{中}\sout{（A）中}}x`、`\uline{\sout{中（A）中}z}吗`；`符 \uline{\sout{\xout{中}x}} 后`（38.61pt，直接输入 41.94pt，v3.9.1 正确）；正文只有 `\hspace*` 的 `符 \uline{\sout{\hspace*{1em}}} 后`（36.66pt，直接输入 33.33pt）；issue 写法的嵌套版本 `普通字符 \uline{\sout{\hspace*{0.5em}xxxx\hspace*{0.5em}}} 后续`（97.78pt，直接输入 94.45pt；v3.9.1 两者都是 97.78pt）。

目前没有用户报告这几类写法。可能的补法（**未实施**）：为普通 stream 找到一个在正文首个可见输出之前运行的钩子，复用 `entry` 的 armed／resolved 语义；或在 `\@@_boundary_inline_stream_end:n` 检查本层是否已排出有宽度的内容，再决定入口空格放在哪里（推断，未实测：后者要到结束时才判断，那时内容已在列表里，除非先把已排出的节点取下，否则空格放不到内容之前）。全角标点方向可以在 Boundary→FullLeft／FullRight 的通用转换里报告 `CJK`，但要先确认不会改变非装饰路径的边界结果。接手时先读 `llmdoc/architecture/xecjk-architecture.md` 的「ulem 结束符与入口空格（#1091）」与反思 `llmdoc/memory/reflections/1091-fntef-ulem-terminator-entry-space.md`。

## 更改历史中旧 `\changes` 条目的 `|` 短抄录泄漏（#1091 R3 发现，未处理）

`\changes` 说明文字进入 `.glo` 后，makeindex 把第一个 `|` 当作 encap 符，后面的文字被当作页码格式命令执行，更改历史里因此出现文字泄漏。#1091 R3 把本次新增条目改为 `\texttt`、`\tn` 和文字描述后，`pdftotext` 检索中本次条目的 `dex10432191`、`dex9189170` 已消失；但仍有三处 `hdclindex8526159`、`hdclindex163`、`hdclindex193354` 来自此前版本的旧条目，其中之一是 `xeCJK/xeCJK.dtx` 约 536 行 v3.10.4 条目里的 `|CJKglue|`。它们不在 #1091 的范围内，未处理。

可能的补法（**未实施**）：逐条把旧 `\changes` 里的 `|...|` 改为 `\texttt{...}`、`\cs{...}` 或 `\tn{...}`，运行 `make changelog` 重新生成 CHANGELOG，并按 `llmdoc/reference/build-and-test.md`「文档排版循环」一节的方法用 `pdftotext` 检索 `hdclindex` 与 `dex[0-9]`，确认计数为 0。已发布版本的条目改动只涉及排版，但要确认重新生成的 CHANGELOG 只有预期的文字变化。
