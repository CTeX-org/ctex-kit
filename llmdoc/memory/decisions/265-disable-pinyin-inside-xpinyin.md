# 决策：应用 `\enablepinyin`/`\disablepinyin` 的作用域到 `\xpinyin` 内

## 背景

Issue #265 报告，由于控制注音逻辑的布尔变量在 `\xpinyin` 宏内的应用机制不完善，导致 `\enablepinyin` 和 `\disablepinyin` 在 `pinyinscope` 环境（或 TeX 分组）内调用时，其作用域无法被正确限制，产生了跨组泄漏的问题。这与用户对 LaTeX 环境/分组局部作用域的预期不符。

PR #977（基于提交 `a12c4dda`）合入了这一修复，并关闭了 #265。

## 根因

在原实现中，控制注音开启状态的内部布尔变量在 `\xpinyin` 中未被正确分支应用，且缺乏一个能够在顶层无分组初始化、而在组内又可安全进行局部赋值（`\bool_set_*:N`）的变量机制。

若直接使用全局变量（`g_` 前缀）进行局部赋值，不仅违反了 `expl3` 的变量命名与使用约定，还会误导后续维护者，甚至在改为全局赋值后彻底破坏 `pinyinscope` 环境内局部切开关的语义。此外，本仓库 `coding-conventions.md` 明确规定：“影子布尔的作用域必须与被控资源的作用域一致”（源自 #431 规则），此前实现未能很好地契合这一原则。

## 决策

引入并重新规范布尔控制链，对 `\xpinyin` 的执行逻辑和作用域约束进行如下调整：

1. **变量规范与初始化**：
  - 弃用不符合命名规范的全局标识，新定义局部影子布尔变量 `\l_@@_enable_outer_bool`，用以显式声明其主要作为局部状态受 TeX 分组约束。
  - 在 `\ExplSyntaxOn` 顶层（此时无分组）使用 `\bool_gset_true:N` 进行合法初始化，确保默认开启。
2. **作用域受控的分支切换**：
  - 将 `\enablepinyin` 与 `\disablepinyin` 内部对该变量的操作定性为局部赋值（使用 `\bool_set_true:N` / `\bool_set_false:N`）。当在 `pinyinscope` 环境或局部组内调用时，退出分组后状态会自动恢复。
  - 在 `\xpinyin` 宏中应用 `\bool_if:NTF \l_@@_enable_outer_bool` 进行分支控制。
3. **保持底层行为一致性**：
  - 为了防止在禁用（disabled）路径下破坏原有的垂直模式行为，将 `\mode_leave_vertical:` 移至 `\bool_if:NTF` 分支判断之前。确保即使在段落起始位置且拼音被禁用时，`\xpinyin` 仍能无条件退出垂直模式，与原始代码行为绝对一致。
  - 在禁用路径下，非星号形式正确使用 `\use_i:nn {#3}` 消费并丢弃后续拼音参数，星号形式则直接输出原始文本 `#3`。

## Breaking change

控制拼音开关命令的作用域现在严格受 TeX 分组（如 `pinyinscope` 环境）约束。

依赖旧有泄漏副作用的文档或宏代码需要调整：
- 将 `\enablepinyin` / `\disablepinyin` 移至环境或分组外部调用；或者
- 在组内调用后，若需跨组生效，需显式在组外重新声明状态。

## 影响范围

- `xpinyin/xpinyin.dtx`
- `Makefile`（同步更新了 `CHANGELOG_PKGS` 接入与相关注释）
- `CHANGELOG.md`

## 关联记录

- PR #977
- Closes #265
