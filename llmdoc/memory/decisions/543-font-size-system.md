# 决策: 将字号系统切换保持为实验性编译期选择

- 日期: 2026-05-04
- 关联: Issue #543

## 上下文

`ctex` 现有中文字号表长期内建为单一一套数据，`\zihao`、数学字号声明与默认字号初始化都直接读取这份内部 prop/seq。Issue #543 需要在现有“公文式”字号体系之外，补充一套传统倍数体系，并给用户留出自定义扩展入口。

与此同时，维护者已在 #717 中确立 `ctex / experiment` 作为“统一接口已暴露，但语义边界仍需观察”的命名空间。字号系统切换同样涉及新增用户接口、预设方案与后续可扩展性，因此需要先明确其放置位置、切换时机与扩展契约。

## 决策

1. 新接口命名为 `experiment/font-size-system`，放在 `ctex / experiment` 命名空间下，而不是直接提升为主选项。
2. 该接口仅作为类/宏包选项使用，不支持通过 `\ctexset` 在运行时切换。
3. 内建提供两套预设字号系统：默认 `word` 与可选 `letterpress`。
4. `letterpress` 的字号数据采用 issue #543 中 tanukihee 提出的传统倍数体系方案，并在 Issue #813 后将原名 `traditional` 更名为更准确的 `letterpress`，明确指向金属活字排印（letterpress printing）时代的字号体系。
5. 用户自定义字号系统的扩展机制固定为：提供 `ctex-fontsize-<name>.def` 文件，并在其中通过公开 API `\ctex_save_font_size:nn` 写入字号数据。

## 理由

- 命名空间一致性：#717 已确认实验性统一接口应集中放在 `experiment/` 下；字号系统切换同样属于新增接口与可演进语义的组合，沿用这一约束可降低主 keypath 的承诺强度。
- 初始化时机限制：字号数据在初始化阶段写入临时 prop/seq，随后被冻结为常量 `\c_@@_font_size_prop` 与 `\c_@@_font_size_seq`；后续 `\zihao`、`\ctex_declare_math_sizes:nnnn` 等路径都直接读取这组常量，因此运行时重切换没有稳定语义，也不能靠 `\ctexset` 局部重建。
- 传统体系来源需要可追溯：`letterpress` 不是随意调参，而是明确采用 #543 中 tanukihee 提出的传统倍数体系，并在 #813 后用更准确的命名指向金属活字排印语境，便于后续讨论其合理性与兼容性。
- 自定义接口要最小而明确：用 `ctex-fontsize-<name>.def` 约定发现机制，再用 `\ctex_save_font_size:nn` 作为单一写入口，既避免把内部临时变量暴露给用户，也让未来扩展新的字号表时不必修改主分派结构。

## 约束

- 新增字号系统预设时，应继续通过 `\g_@@_font_size_system_tl` 的初始化分派进入同一构建链，而不是在运行时修改 `\c_@@_font_size_prop`。
- 任何文档或接口说明都不应把 `experiment/font-size-system` 描述成可被 `\ctexset` 动态切换的运行时选项。
- 用户自定义 `.def` 文件必须通过 `\ctex_save_font_size:nn` 填充数据；不应依赖 `\l_@@_font_size_temp_prop`、`\l_@@_font_size_temp_seq` 等内部实现细节。
- 当请求的自定义系统不存在时，应维持当前契约：报出 `fontsize-system-not-found`，并回退到 `word`。

## 相关

- 源码: `ctex/ctex.dtx`
- 测试: `ctex/test/testfiles/fontsize-system01.lvt`
- 关联决策: `llmdoc/memory/decisions/717-experiment-cjkecglue.md`
