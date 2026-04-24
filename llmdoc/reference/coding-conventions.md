# 编码约定

## expl3 命名规则与项目命名空间

`ctex-kit` 的现代代码以 expl3 为主，最重要的检索信号是“模块前缀 + 参数签名”。在本仓库中，常见公开命名空间包括：

- `\ctex_`：`ctex` 主模块
- `\xeCJK_`：`xeCJK` 主模块
- `\CJKtu_`：`xCJK2uni` 模块
- `\__ctxdoc_`：`support/ctxdoc.cls` 的内部实现

调查报告确认了以下典型例子：

- `ctex/ctex.dtx` 中存在 `\ctex_define_option:n`
- `xeCJK/xeCJK.dtx` 中存在 `\xeCJK_check_single_env:nnNn`
- `xCJK2uni/xCJK2uni.dtx` 中存在 `\CJKtu_char_to_unicode:n`
- `support/ctxdoc.cls` 中存在 `\__ctxdoc_version_zfill:wnnn`

因此，在搜索符号时，应优先用模块前缀作为入口，而不是先搜通用动词。

## `@@` 私有命名空间

本仓库广泛使用 expl3 的私有命名约定 `\@@_...`。其含义不是“全仓库共享私有名”，而是“当前模块在 docstrip/expl3 语义下的私有占位前缀”。

典型例子包括：

- `ctex/ctex.dtx` 中的大量 `\@@_...` 内部例程
- `xeCJK/xeCJK.dtx` 中处理标点 margin/kerning 的 `\@@_calc_kerning_margin:NN`
- `xCJK2uni/xCJK2uni.dtx` 中的编码转换内部函数

阅读 `.dtx` 时，遇到 `@@` 名称应先把它解释为“该模块内部实现细节”，不要把不同文件里的 `\@@_...` 误认为同一命名空间。

## 参数签名是接口的一部分

本项目 expl3 函数名后缀中的参数签名是稳定检索线索，例如：

- `:n`
- `:nn`
- `:Nn`
- `:nnNn`

修改调用点或迁移实现时，必须同时核对函数名前缀和参数签名；仅靠词干匹配容易误改到重载变体。

## expl3 定义命令的作用域约定

在本仓库维护 expl3 代码时，定义命令不仅要看“是否成功生成控制序列”，还要明确其作用域语义：

- `\cs_new_protected:Npx` 是全局定义，对应 `\gdef` 一类语义；如果在组内调用，定义仍会泄漏到组外。
- `\cs_set_protected:Npx` 是局部定义，对应 `\def` 一类语义；如果在组内调用，分组结束后定义会回退。
- `\newcommand` 与现代 `\NewDocumentCommand` 在组内调用时也都是局部定义，因此用它们声明用户可见命令时，默认应按“受 TeX 分组约束”的行为理解。

这条约定在定义用户可见切换命令时尤其重要：若命令的存在性本身属于用户接口的一部分，就必须先判断它应该是“全局注册”还是“仅在当前组有效”。Issue #751 的修复正是一个典型案例：字体族注册可继续全局保存，但 `\newCJKfontfamily` 生成的用户切换命令需要改为局部定义，才能与 `fontspec` / LaTeX 用户对命令作用域的直觉保持一致。

## docstrip 标签系统

`ctex-kit` 的核心源码大量使用 docstrip 标签在单个 `.dtx` 中生成多个产物。稳定事实包括：

- 一个 `.dtx` 可同时输出 `.sty`、`.cls`、`.def`、示例文件和文档。
- `ctex/ctex.dtx` 是“单体源 + 多运行期配置文件”模式。
- `xeCJK/xeCJK.dtx` 是“单体源 + 主包/扩展包/示例/映射文件”模式。

因此，修改 `.dtx` 前要先判断目标代码属于哪个 docstrip 标签块，否则可能出现：

- 改了文档区，未改实现区
- 改了某个产物对应标签，却遗漏并行产物
- 错判某段代码的实际输出文件

调查报告还指出，`xeCJK` 的 example 文档直接封装在 `xeCJK.dtx` 的剥离块里；这类文件既是示例，也是该包当前重要的验证载体。

## `\CTEX@` 遗留接口与 expl3 共存

`ctex` 不是“纯 expl3、新写一遍”的项目；它保留了部分 `\CTEX@...` 风格的 LaTeX2e 遗留内部接口，与 `\ctex_...` 新接口并存。调查中给出的代表符号是 `\CTEX@char@n`，见 `ctex/ctex.dtx`。

这带来两个稳定约束：

1. 修改 `ctex` 时，不要假设所有内部调用都已迁移到 expl3。
2. 若发现同一功能同时经过 `\CTEX@...` 和 `\ctex_...` 两层包装，要先判断哪一层是兼容桥，哪一层才是实际后端。

通常：

- expl3 层更适合新增逻辑与统一选项处理。
- `\CTEX@...` 层常与旧接口兼容、LaTeX2e 钩子或历史行为保持有关。

## 文档排版类 `support/ctxdoc.cls`

`support/ctxdoc.cls` 是仓库共享的文档排版基础设施，供多个 `.dtx` 文档构建使用；其角色可理解为该项目自己的 `l3doc` 风格文档类。相关构建链会通过：

- 包级 `typesetsuppfiles = {"ctxdoc.cls"}`
- `support/build-config.lua` 的文档流程

把它复制到排版环境中，见 `ctex/build.lua:8-10`、`xeCJK/build.lua:9-12`、`support/build-config.lua:58-66`。

因此，如果文档构建、索引、变更记录排版或 `.dtx` 文档样式出问题，优先检查 `support/ctxdoc.cls`，不要先怀疑业务包逻辑。

## 实际修改时的检索顺序

对现代包代码，推荐按以下顺序检索：

1. 目标包前缀，例如 `\ctex_` 或 `\xeCJK_`
2. 同名私有实现 `\@@_`
3. 若在 `ctex` 中，再补查 `\CTEX@`
4. 再回看对应 `.dtx` 的 docstrip 标签边界与生成产物

这比从生成后的 `.sty`/`.cls` 逆向追踪更稳定，因为真实维护入口通常仍在 `.dtx`。

## `.dtx` 中用户文档与实现文档的区分

`ctex.dtx` 和 `xeCJK.dtx` 中包含两类文档：

- **用户文档**（手册正文）：使用 `\begin{function}...\end{function}` 描述面向用户的接口，排版后出现在手册前半部分。
- **实现文档**（代码实现部分）：使用 `\begin{macro}...\end{macro}` 描述内部机制，排版后出现在手册后半部分。

新增选项或命令时，两处都需要添加说明：`\begin{function}` 面向用户解释用法和效果，`\begin{macro}` 面向开发者说明实现细节。
