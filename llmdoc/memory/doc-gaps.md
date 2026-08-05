# 文档缺口

## luatex/uptex CJKglue touched 检测缺陷

luatex/uptex 的 `\ctex_if_ccglue_touched:` 检测机制中 `\l_@@_ccglue_skip` 未初始化，导致该分支无法正确判断用户是否已设置 CJKglue。Issue #761 修复仅覆盖 pdftex/xetex，luatex/uptex 需理解 luatexja 等包的初始化时序后另行处理。相关决策见 `llmdoc/memory/decisions/761-ccglue-override.md`。

## `verify-doc-output.sh` 缺内容级哨兵

`scripts/verify-doc-output.sh:69-88` 的三条判据都是容器级的：PDF 文件存在、前四字节是 `%PDF`、体积 `>= 1024` 字节。它们能抓住「dvipdfmx 中途挂掉留下 stub」这类失败，但对「编译成功、PDF 结构完整、只是正文内容被污染」**零判别力**。

已实证一例（#1054）：l3backend 与 l3kernel 版本错配时，`l3build doc` exit 0，PDF 页数与体积都正常，三条判据全过、门禁全绿，但正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本（`xeCJK.pdf` 的 `\meta` 与 fntef 示例最明显）。同一根因在 regression 路径上会让 12 个 `.tlg` 变红，doc 路径上却不产生任何非零退出码。

当前处置是两条，都不是自动检测：

- **前置预防**：`scripts/sync-l3backend.sh` 在 `l3build doc` 之前补齐匹配版本的 backend，从源头消除这个已知成因。
- **人工检视**：`_check-doc-package.yml` 在成功时也上传 `check-doc-<pkg>-pdf` artifact，可下载后 `pdftotext` 检索泄漏模式。这依赖人记得去看。

可能的补法（**未实施**）：在 verify 阶段对每个 PDF 跑 `pdftotext`，按已知泄漏模式（`gray 0`、`0gray`、`1.0 0.0` 等）检索并断言计数为 0。代价有两条：要维护一份模式清单，且只覆盖已知形态——新的上游错配可能产生完全不同的泄漏文本。落地前还需先确认这些模式不会与正常正文冲突（手册里讨论颜色模型时可能正常出现 `gray`）。

详见反思 `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md` 与 `llmdoc/reference/build-and-test.md` 的「文档编译校验」一节。
