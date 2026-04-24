# 包架构

## 仓库主干关系

`ctex-kit` 不是单一包，而是围绕中文排版的一组相关包。实际修改中，最重要的主干关系是：

- `ctex` 负责统一用户入口、类封装和跨引擎接口抹平。
- `xeCJK` 负责 XeTeX 路线下的中文字体、空白和标点细节。
- `zhnumber` 是 `ctex` 测试和功能链上的直接依赖之一。
- `support/` 提供整个仓库共享的构建、文档和编码转换基础设施。

从构建依赖看，`ctex/build.lua` 显式声明 `checkdeps = {"../xeCJK", "../zhnumber"}`，因此 `ctex` 的测试工作流会把这两个包解包后的安装文件复制进测试目录，见 `ctex/build.lua:42-69`。

## ctex 的分层加载架构

### 顶层入口

`ctex` 的核心源码集中在 `ctex/ctex.dtx`，通过 docstrip 生成：

- 文档类：`ctexart.cls`、`ctexbook.cls`、`ctexrep.cls`、`ctexbeamer.cls`
- 主宏包：`ctex.sty`
- 支撑宏包：如 `ctexsize.sty`、`ctexheading.sty`
- 多组运行期 `.def` 配置：引擎、字体集、方案、标题等

其中，`ctexart.cls` / `ctexbook.cls` / `ctexrep.cls` 是用户最常见入口；它们本质上包装标准类并引入 `ctex.sty` 及后续配置层。调查显示该体系依赖运行期按变量选择文件，再由安全输入宏 `\ctex_file_input:n` 完成加载。

### 典型加载链

对标准中文文档类，主加载链可概括为：

1. `ctexart.cls`
2. `ctex.sty`
3. `ctex-engine-*.def`
4. `ctex-fontset-*.def`
5. `ctex-scheme-*.def`
6. `ctex-heading-*.def`

这条链不是简单的静态 `\input` 序列，而是由运行期选项与引擎判断驱动：

- 类文件先包装标准类加载流程。
- `ctex.sty` 建立统一选项、中文功能入口与配置变量。
- 引擎层决定后续依赖的底层能力与边界行为。
- 字体集层选择系统/发行版相关默认中文字体映射。
- 方案层控制 plain/chinese 等文档样式方案。
- 标题层对章、节、编号和题头格式作最终注入。

调查中提到的关键关系是：`<class> -> ctex-scheme-<chinese|plain>-<class>.def -> ctex-heading-<class>.def`，并与引擎、字体集层交错组合，见 `ctex/ctex.dtx` 对各类 `.def` 文件的生成结构说明。

### 分层职责

#### 1. 类包装层

`ctexart.cls` 等顶层类通过标准类适配机制加载 LaTeX 原生类，并在此基础上附加中文标题、字号和版式约定。它们不是完全独立实现，而是“标准类 + ctex 配置层”的组合包装。

#### 2. 引擎层

`ctex-engine-pdftex.def`、`ctex-engine-xetex.def`、`ctex-engine-luatex.def`、`ctex-engine-uptex.def`、`ctex-engine-aptex.def` 对不同引擎分别提供字体设定、字符边界与底层兼容逻辑，是整个体系的第一层运行期分流点。

#### 3. 字体集层

`ctex-fontset-{windows,mac,macnew,ubuntu,fandol,adobe,founder,hanyi}.def` 提供默认字体族映射，负责把“中文主字体/无衬线/等宽”等高层概念落到具体发行版或操作系统字体名。

#### 4. 方案层

`ctex-scheme-plain.def` 与 `ctex-scheme-chinese.def` 为不同文档风格组织参数，并细分到具体类变体。它们承接“中文约定默认值”这一职责，而不是处理底层引擎差异。

#### 5. 标题层

`ctex-heading-*.def` 为章、节、编号、目录和标题格式提供最后的类级定制。修改标题行为时，应优先检查 heading/scheme 组合，而不是先改 engine/fontset 层。

## xeCJK 的核心架构

## 单体 `.dtx` 模型

`xeCJK` 的核心几乎全部集中在 `xeCJK/xeCJK.dtx`。它通过 docstrip 生成：

- 主宏包 `xeCJK.sty`
- 配置文件 `xeCJK.cfg`
- 扩展宏包 `xeCJKfntef.sty`、`xeCJK-listings.sty`、`xunicode-addon.sty`
- 示例文档与相关支持文件
- 字符映射相关输出文件

这意味着 `xeCJK` 更接近“单体源文件 + 多产物”的架构，而不是 `ctex` 那种由大量运行期 `.def` 分层装配的模式。

## 字体与接口层

`xeCJK` 用 `\xeCJKsetup{...}` 作为统一键值接口，并提供 `\setCJKmainfont`、`\setCJKsansfont`、`\setCJKmonofont` 等字体设置命令，底层包裹 `fontspec`。这使其在 XeLaTeX 下成为中文字体选择与字符子集配置的主中枢。

`\newCJKfontfamily` 的行为需要分成“字体族注册”和“切换命令定义”两层理解：底层字体族注册仍通过 `\xeCJK_set_family:nnn` 完成，而该过程会继续把字体族信息写入全局属性表并全局注册 NFSS 族；但它为用户声明的字体切换命令本身现在改为用 `\cs_set_protected:Npx` 做局部定义，而不是全局定义。这一语义与 `fontspec` 的 `\newfontfamily` 保持一致：在分组内调用时，切换命令不会泄漏到组外，但已注册的字体族元数据仍可被后续代码复用。

这一点不仅影响 XeTeX 路径中的 `xeCJK/xeCJK.dtx`，也影响 LuaTeX 路径中 `ctex/ctex.dtx` 的对应实现：LuaTeX 下 `\newCJKfontfamily` 最终走 `\ctex_ltj_set_family:nnn` 注册字体族，而用户可见切换命令同样改为局部定义。因此，遇到“组内声明的新字体切换命令在组外是否仍然存在”这类问题时，应把它视为跨 XeTeX/LuaTeX 两条后端路径共享的接口语义，而不是某一端独有的偶发行为。

## 标点挤压与空白控制

`xeCJK` 的一个核心能力是标点挤压与样式策略。它提供 `PunctStyle` 机制以及 `quanjiao`、`banjiao`、`kaiming`、`hangmobanjiao`、`CCT` 等预设，并允许用 `\xeCJKDeclarePunctStyle` 声明自定义规则。相关内部实现大量使用 `\xeCJK_...` 与私有 `\@@_...` 例程处理 kerning margin、相邻标点压缩与行末位移。

因此，在 XeTeX 路线下如果问题表现为：

- 中文标点宽度或压缩异常
- 句读与边界空白不符合预期
- `listings` 等特殊环境中的中日韩字符处理出错

优先去 `xeCJK/xeCJK.dtx` 查找，而不是从 `ctex` 入手。

## TECkit 映射

`xeCJK/build.lua` 在标准 l3build 配置之外，还在 `unpack_posthook()` 中调用 `make_teckit_mapping()`，动态生成并编译 `.map`/`.tec` 文件。其输入来自 Unicode `Unihan.zip` 中的变体数据，并额外生成全角句号/句点映射。见 `xeCJK/build.lua:28-149`。

这说明 `xeCJK` 的一部分“功能数据”并不完全静态存放在仓库中，而是在构建阶段生成：

- 繁简转换映射
- 句号形态映射
- TECkit 编译产物 `.tec`

修改这部分功能时，要同时考虑源 Lua 逻辑、上游 Unicode 数据格式以及本地 `teckit_compile` 可用性。

## ctex 与 xeCJK 的关系

`ctex` 与 `xeCJK` 的关系不是并列替代，而是“统一入口”与“XeTeX 后端”之间的代理关系。

在 XeTeX/XeLaTeX 下：

- `ctex` 会主动加载 `xeCJK`
- `ctex` 的中文字体与标点相关高层配置最终代理给 `xeCJK` / `xeCJKsetup`
- 用户看到的是 `ctex` 提供的一致接口；真正处理 XeTeX 中文细节的是 `xeCJK`

因此，若某个问题只在 XeLaTeX 发生，应先判断它属于：

- `ctex` 的跨引擎统一层问题
- 还是 `xeCJK` 的 XeTeX 专属实现问题

经验上，标题、方案、类选项更偏 `ctex`；字体选择、标点压缩、空白与特殊环境支持更偏 `xeCJK`。

## 第三方包补丁子系统

ctex 在 `%<*class|heading>` 区段（`ctex/ctex.dtx` 约 7660-9448 行）维护对 varioref、cleveref、hyperref 等第三方包的兼容补丁。补丁通过 `ctex_at_end_package:nn` 延迟到目标包加载后执行，核心工具是 `ctex_patch_cmd_all:NnnnTF`（定义在 ctexpatch 区段），实现命令体内的文本搜索替换。

部分补丁提供用户开关（如 `\ctexset{ patch/cleveref }`），允许在补丁与上游更新冲突时关闭。详见 `llmdoc/architecture/cleveref-patch.md`。

## 引擎适配策略

`ctex` 的整体策略是对外提供统一中文接口，对内按引擎切到不同技术路线：

- XeTeX → `xeCJK`
- LuaTeX → `LuaTeX-ja`
- pdfTeX → `CJK` / `zhmCJK`
- upTeX → 专用中文度量与字体支持
- apTeX → 独立引擎适配层

这是整个仓库最关键的架构不变量之一：`ctex` 不试图用一套底层实现覆盖所有引擎，而是把统一接口建立在多后端适配之上。调查中明确指出，XeTeX、LuaTeX、pdfTeX、upTeX 各自对应不同的底层机制，见 `ctex/ctex.dtx` 的 engine support 段落与 `ctex/build.lua:46-53` 的多引擎测试配置。

### 引擎条件代码的延迟重定义模式

`ctex.sty` 以 `{style,ctex}` 标签从 `ctex.dtx` 生成，不含引擎标签（`pdftex`、`xetex` 等）。这意味着在 `ctex.sty` 对应的公共代码区域中直接使用 `%<*pdftex|xetex>` docstrip 守卫会被剥离，实际无效。

正确的引擎条件化方案是：在引擎 `.def` 代码段（以 `{pdftex}`、`{xetex}` 等标签生成）中，用 `\ctex_at_end:n`（= `\AtEndOfPackage`）延迟到包加载末尾执行重定义。这样，引擎 `.def` 的代码在包加载链后期覆写公共区域中定义的默认实现，实现引擎特化。

这一模式在 linestretch/CJKglue 子系统的修复中被确立。详见 `llmdoc/memory/decisions/761-ccglue-override.md`。

## Linestretch 与 CJKglue 子系统

### 调用链

`\selectfont` → `\ctex_update_size:` → `\ctex_update_stretch:` → 分支到 `\@@_update_stretch_auxi:` 或 `\@@_update_stretch_auxii:`。

- `\@@_update_stretch_auxi:`：linestretch 禁用时的路径。一开始就含有 `\ctex_if_ccglue_touched:TF` 守卫。
- `\@@_update_stretch_auxii:`：linestretch 启用时的默认路径。在公共区域定义为直接调用 `\@@_update_stretch_auxiii:`。
- `\@@_update_stretch_auxiii:`：提取出的 linestretch 计算逻辑，计算弹性胶并调用 `\ctex_update_ccglue:`。

### 引擎特化覆写

pdftex/xetex 的引擎 `.def` 中通过 `\ctex_at_end:n` 重定义 `\@@_update_stretch_auxii:`，加入 `\ctex_if_ccglue_touched:TF` 检查：用户已设置 CJKglue 时仅更新 `\ccwd`，不覆盖用户的 `\CJKglue` 定义。

luatex/uptex 保持原始行为（直接调用 `auxiii:`），因为其 `\ctex_if_ccglue_touched:` 检测机制存在预存缺陷（`\l_@@_ccglue_skip` 未初始化），需另行修复。

### 涉及源码

`ctex/ctex.dtx` 中的 linestretch 函数定义（公共区域）和引擎 `.def` 代码段（pdftex/xetex 特化）。回归测试 `ctex/test/testfiles/ccglue01.lvt`。

## 包间依赖图

从发布、构建和运行三个层面看，可以用下面的检索图理解依赖关系：

- 发布聚合：`ctan.lua` -> `CJKpunct | ctex | xCJK2uni | xeCJK | xpinyin | zhmetrics | zhmetrics-uptex | zhnumber | zhspacing`
- 构建共享：`*/build.lua` -> `support/build-config.lua`
- 文档共享：`.dtx` 文档排版 -> `support/ctxdoc.cls`
- ctex 测试依赖：`ctex/build.lua` -> `../xeCJK`, `../zhnumber`
- XeTeX 运行时：`ctex` -> `xeCJK`
- pdfTeX 运行时：`ctex` -> `CJK` / `zhmCJK` / `xCJK2uni` 一类传统路径
- upTeX 运行时：`ctex` -> `zhmetrics-uptex` 一类度量支持

如果要修改仓库中的核心中文排版行为，首选检索顺序通常是：

1. `ctex/ctex.dtx`
2. `xeCJK/xeCJK.dtx`
3. 对应包的 `build.lua`
4. `support/build-config.lua`

这四处覆盖了绝大多数主干行为与构建入口。
