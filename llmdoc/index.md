# llmdoc 索引

## overview

- `llmdoc/overview/project-overview.md` — 项目范围、仓库组织、核心/卫星包分类、技术栈与维护状态。

## architecture

- `llmdoc/architecture/package-architecture.md` — `ctex` 与 `xeCJK` 的主干架构、引擎适配策略、第三方包补丁子系统与包间依赖图。
- `llmdoc/architecture/cleveref-patch.md` — cleveref 兼容补丁机制、挂钩链、`patch/cleveref` 开关与 Issue #725 根因分析。

## reference

- `llmdoc/reference/build-and-test.md` — `l3build`、共享构建配置、测试框架、CI/CD、CTAN 发布与版本管理参考。
- `llmdoc/reference/coding-conventions.md` — expl3 命名、`@@` 私有空间、docstrip 标签、`\CTEX@` 遗留接口与文档排版基础设施。

## guides

- 当前暂无指南文档。

## memory

- `llmdoc/memory/decisions/725-cleveref-patch-toggle.md` — 决策: 不在 ctex 侧修复 cleveref appendix 语义问题，改为提供 `patch/cleveref` 开关。
