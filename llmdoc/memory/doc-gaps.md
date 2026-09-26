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
- 非 ulem 路径的 Boundary→FullLeft／FullRight 不向 capture 报告类别；#1091 只在 ulem 分支的 FullLeft 补了 `CJK` 报告。以全角右标点开头的装饰正文也未处理。

目前没有用户报告这两类写法。可能的补法（**未实施**）：为普通 stream 找到一个在正文首个可见输出之前运行的钩子，复用 `entry` 的 armed／resolved 语义；或在 `\@@_boundary_inline_stream_end:n` 检查本层是否已排出有宽度的内容，再决定入口空格放在哪里（推断，未实测：后者要到结束时才判断，那时内容已在列表里，除非先把已排出的节点取下，否则空格放不到内容之前）。全角标点方向可以在 Boundary→FullLeft／FullRight 的通用转换里报告 `CJK`，但要先确认不会改变非装饰路径的边界结果。接手时先读 `llmdoc/architecture/xecjk-architecture.md` 的「ulem 结束符与入口空格（#1091）」与反思 `llmdoc/memory/reflections/1091-fntef-ulem-terminator-entry-space.md`。
