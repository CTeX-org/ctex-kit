# 决策：`\newCJKfontfamily` 的命令作用域改为局部

## 背景

Issue #751 报告 `\newCJKfontfamily` 在分组内调用时，生成的字体切换命令会泄漏到组外。这与 `fontspec` 的 `\newfontfamily`、以及 LaTeX 用户对 `\newcommand` / `\NewDocumentCommand` 的常见作用域预期不一致。

受影响实现有两处：

- `xeCJK/xeCJK.dtx` 中 XeTeX 路径的 `\newCJKfontfamily`
- `ctex/ctex.dtx` 中 LuaTeX 路径的 `\newCJKfontfamily`（通过 `\ctex_ltj_set_family:nnn` 注册字体族）

PR #773 合入了这一修复，并关闭了 #751。

## 根因

原实现使用 `\cs_new_protected:Npx` 定义用户可见的字体切换命令。该接口具有全局定义语义，等价于 `\gdef` 一类行为，因此即使在组内调用，也会把新命令保留到组外，形成命令泄漏。

需要注意的是，这个问题只发生在“命令定义”这一层；字体族注册本身仍然需要全局持久化，以便后续切换和 NFSS 信息查询能够工作。

## 决策

将 `\newCJKfontfamily` 的命令定义逻辑改为：

- 先用 `\cs_if_exist:NTF` 检查目标命令是否已存在
- 未定义时，使用 `\cs_set_protected:Npx` 进行局部定义
- 字体族注册流程仍分别由 `\xeCJK_set_family:nnn` 与 `\ctex_ltj_set_family:nnn` 负责，并保持全局注册语义

这样可以同时满足两层需求：

1. 用户可见切换命令的作用域与 `fontspec` 的 `\newfontfamily` 保持一致。
2. 底层字体族元数据仍可稳定保存，不破坏既有字体注册机制。

## Breaking change

这是一个有意引入的行为变更：在分组内调用 `\newCJKfontfamily` 时，生成的命令不再泄漏到组外。

依赖旧行为的文档或宏代码需要改为：

- 在组外声明该命令；或
- 若确实需要跨组持久存在，显式使用全局定义策略，而不是依赖 `\newCJKfontfamily` 的副作用。

## 影响范围

- `xeCJK.dtx`
- `ctex.dtx` 中 LuaTeX 相关代码块

## 关联记录

- PR #773
- Closes #751
