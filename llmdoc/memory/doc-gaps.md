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

`scripts/verify-doc-output.sh:69-88` 的三条判据都是容器级的：PDF 文件存在、前四字节是 `%PDF`、体积 `>= 1024` 字节。它们能抓住「dvipdfmx 中途挂掉留下 stub」这类失败，但对「编译成功、PDF 结构完整、只是正文内容被污染」**零判别力**。

已实证一例（#1054）：l3backend 与 l3kernel 版本错配时，`l3build doc` exit 0，PDF 页数与体积都正常，三条判据全过、门禁全绿，但正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本（`xeCJK.pdf` 的 `\meta` 与 fntef 示例最明显）。同一根因在 regression 路径上会让 12 个 `.tlg` 变红，doc 路径上却不产生任何非零退出码。

当前处置是两条，都不是自动检测：

- **前置预防**：`scripts/sync-l3backend.sh` 在 `l3build doc` 之前补齐匹配版本的 backend，从源头消除这个已知成因。
- **人工检视**：`_check-doc-package.yml` 在成功时也上传 `check-doc-<pkg>-pdf` artifact，可下载后 `pdftotext` 检索泄漏模式。这依赖人记得去看。

可能的补法（**未实施**）：在 verify 阶段对每个 PDF 跑 `pdftotext`，按已知泄漏模式（`gray 0`、`0gray`、`1.0 0.0` 等）检索并断言计数为 0。代价有两条：要维护一份模式清单，且只覆盖已知形态——新的上游错配可能产生完全不同的泄漏文本。落地前还需先确认这些模式不会与正常正文冲突（手册里讨论颜色模型时可能正常出现 `gray`）。

详见反思 `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md` 与 `llmdoc/reference/build-and-test.md` 的「文档编译校验」一节。
