# llmdoc 索引

## overview

- `llmdoc/overview/project-overview.md` — 项目范围、仓库组织、核心/卫星包分类、技术栈与维护状态。

## architecture

- `llmdoc/architecture/package-architecture.md` — `ctex` 与 `xeCJK` 的主干架构、引擎适配策略、第三方包补丁子系统与包间依赖图；现含 xeCJK 对 #407/#800 最终确立的 `\xeCJKchar` + 定点补丁策略。
- `llmdoc/architecture/cleveref-patch.md` — cleveref 兼容补丁机制、挂钩链、`patch/cleveref` 开关与 Issue #725 根因分析。

## reference

- `llmdoc/reference/build-and-test.md` — `l3build`、共享构建配置、测试框架、CI/CD、CTAN 发布与版本管理参考。
- `llmdoc/reference/coding-conventions.md` — expl3 命名、`@@` 私有空间、作用域语义、docstrip 标签、`\CTEX@` 遗留接口与文档排版基础设施。
- `llmdoc/reference/ctex-fontset-mac.md` — `ctex` 中 `fontset=mac` / `macnew` / `macold` 的选择逻辑、macOS 15+ 检测后备、XeTeX/LuaTeX 字体探测差异与回退语义。

## guides

- `llmdoc/guides/release-workflow.md` — release tag 触发条件、构建阶段、release notes 生成、测试门控与 GitHub prerelease 重建流程。

## memory

- `llmdoc/memory/decisions/725-cleveref-patch-toggle.md` — 决策: 不在 ctex 侧修复 cleveref appendix 语义问题，改为提供 `patch/cleveref` 开关。
- `llmdoc/memory/decisions/751-newCJKfontfamily-scope.md` — 记录 #751 / PR #773 中 `\newCJKfontfamily` 从全局命令定义改为局部定义的原因、决策与影响范围。
- `llmdoc/memory/decisions/782-fontset-mac-macos15plus-detection.md` — 决策: 不新增 `mac15plus`，改为在 `fontset=mac` 内增加 macOS 版本检测后备，并按 XeTeX/LuaTeX 分别探测 macOS 15+ downloadable 字体。
- `llmdoc/memory/decisions/746-remove-legacy-font-hooks.md` — 决策: 移除对 LaTeX < 2020/10/01 的字体钩子兼容代码，响应上游移除 `\@rmfamilyhook`。
- `llmdoc/memory/decisions/688-pifont-interchartokenstate-leak.md` — 决策: pifont hook 中先进入水平模式防止 interchartokenstate 泄漏到输出例程。
- `llmdoc/memory/decisions/715-hyperref-driverfallback.md` — 决策: hyperref driverfallback 按加载状态分支处理，避免重复设置警告。
- `llmdoc/memory/decisions/761-ccglue-override.md` — Issue #761 CJKglue 导言区覆盖问题的修复方案演进与确立的引擎延迟重定义模式。
- `llmdoc/memory/doc-gaps.md` — 已知文档与实现缺口追踪。
- `llmdoc/memory/reflections/715-hyperref-driverfallback.md` — 反思: TYPE 展开陷阱、l3build 命令拦截测试技巧。
- `llmdoc/memory/reflections/671-cjkpunct-rglue-nobreak.md` — 反思: CJKpunct #671 修复中的节点级调试技术与 `\unhbox` 测试模式。
- `llmdoc/memory/reflections/704-ctxdoc-patch-health-test.md` — 反思: 为 `support/ctxdoc.cls` 建立 patch 健康检查时，确认 l3build `check` 目标需要用 `checksuppfiles` 显式复制 support 文件，且 nonstop 模式下必须使用 `\msg_critical` 才能把 patch 失败升级为真正终止编译的错误。
- `llmdoc/memory/reflections/735-zhlineskip-split-leading-leak.md` — 反思: zhlineskip #735 split 行距泄漏的根因（TeX 分组层级）、vbox 尺寸回归测试策略与 l3build 框架补建。
- `llmdoc/memory/reflections/465-fntef-font-state-and-underdot-space.md` — 反思: xeCJKfntef #465 中 ulem 下字体状态跨分组丢失 + `\CJKunderdot` 的 `\ignorespaces` 吞空格，及诊断误判的教训。
- `llmdoc/memory/reflections/581-xecjk-zero-width-format-chars.md` — 反思: xeCJK #581 中零宽格式字符应在输入层忽略，而不是进入 interchar 字符分类。
- `llmdoc/memory/reflections/556-verb-xkanjiskip-lltjcore.md` — 反思: ctex #556 中从 autoxspacing 误判修正为”禁用 ltj-latex 后漏掉 lltjcore 的 `\verb` 补丁”，以及基于 `\showbox` 的节点级定位方法。
- `llmdoc/memory/reflections/284-fullwidth-tilde-longpunct.md` — 反思: xeCJK #284 中全角波浪号等连接号的残留问题不在可见空格，而在 MiddlePunct 引入的不必要标点压缩节点；应借助 `\showbox` 对比确认 LongPunct 路径的更干净节点模型。
- `llmdoc/memory/reflections/378-lstinline-hash-doubling.md` — 反思: xeCJK #378 中 `\lstinline` 宏参数 `#` 双写的根因（rescan 的 stringification 再次双写 cat6 `#`）、catcode 12 vs active 的易错点、`\regex_replace_all` catcode class 匹配技巧。
- `llmdoc/memory/reflections/407-char-interchar-bypass.md` — 反思: xeCJK #407 中 `\char` 原语被 interchar 拦截的根因、`\char` vs mathcode 语义差异、测试场景设计偏差。
- `llmdoc/memory/reflections/800-char-let-xint-compat.md` — 反思: xeCJK #800 中 `\char` 重定义必须延迟到 `\AtBeginDocument`，避免破坏 xint 等包在加载期 `\let` 保存原语的假设。
- `llmdoc/memory/reflections/315-252-476-xecjk-ecglue-fixes.md` — 反思: xeCJK #252/#476 的 ecglue 字体度量问题与 #315 一样属于 interchar 边界恢复链，应在正确 CJK 字体上下文中缓存前侧 ecglue，并提前按 CI 依赖链完整验证基线影响。
