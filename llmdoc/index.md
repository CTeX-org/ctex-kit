# llmdoc 索引

## overview

- `llmdoc/overview/project-overview.md` — 项目范围、仓库组织、核心/卫星包分类、技术栈与维护状态。

## architecture

- `llmdoc/architecture/package-architecture.md` — `ctex` 与 `xeCJK` 的主干架构、引擎适配策略、第三方包补丁子系统与包间依赖图。
- `llmdoc/architecture/cleveref-patch.md` — cleveref 兼容补丁机制、挂钩链、`patch/cleveref` 开关与 Issue #725 根因分析。

## reference

- `llmdoc/reference/build-and-test.md` — `l3build`、共享构建配置、测试框架、CI/CD、CTAN 发布与版本管理参考。
- `llmdoc/reference/coding-conventions.md` — expl3 命名、`@@` 私有空间、作用域语义、docstrip 标签、`\CTEX@` 遗留接口与文档排版基础设施。

## guides

- 当前暂无指南文档。

## memory

- `llmdoc/memory/decisions/725-cleveref-patch-toggle.md` — 决策: 不在 ctex 侧修复 cleveref appendix 语义问题，改为提供 `patch/cleveref` 开关。
- `llmdoc/memory/decisions/751-newCJKfontfamily-scope.md` — 记录 #751 / PR #773 中 `\newCJKfontfamily` 从全局命令定义改为局部定义的原因、决策与影响范围。
- `llmdoc/memory/decisions/746-remove-legacy-font-hooks.md` — 决策: 移除对 LaTeX < 2020/10/01 的字体钩子兼容代码，响应上游移除 `\@rmfamilyhook`。
- `llmdoc/memory/decisions/688-pifont-interchartokenstate-leak.md` — 决策: pifont hook 中先进入水平模式防止 interchartokenstate 泄漏到输出例程。
- `llmdoc/memory/decisions/715-hyperref-driverfallback.md` — 决策: hyperref driverfallback 按加载状态分支处理，避免重复设置警告。
- `llmdoc/memory/reflections/715-hyperref-driverfallback.md` — 反思: TYPE 展开陷阱、l3build 命令拦截测试技巧。
- `llmdoc/memory/reflections/671-cjkpunct-rglue-nobreak.md` — 反思: CJKpunct #671 修复中的节点级调试技术与 `\unhbox` 测试模式。
- `llmdoc/memory/reflections/704-ctxdoc-patch-health-test.md` — 反思: 为 `support/ctxdoc.cls` 建立 patch 健康检查时，确认 l3build `check` 目标需要用 `checksuppfiles` 显式复制 support 文件，且 nonstop 模式下必须使用 `\msg_critical` 才能把 patch 失败升级为真正终止编译的错误。
- `llmdoc/memory/reflections/735-zhlineskip-split-leading-leak.md` — 反思: zhlineskip #735 split 行距泄漏的根因（TeX 分组层级）、vbox 尺寸回归测试策略与 l3build 框架补建。
- `llmdoc/memory/reflections/581-xecjk-zero-width-format-chars.md` — 反思: xeCJK #581 中零宽格式字符应在输入层忽略，而不是进入 interchar 字符分类。
- `llmdoc/memory/reflections/556-verb-xkanjiskip-lltjcore.md` — 反思: ctex #556 中从 autoxspacing 误判修正为“禁用 ltj-latex 后漏掉 lltjcore 的 `\verb` 补丁”，以及基于 `\showbox` 的节点级定位方法。
