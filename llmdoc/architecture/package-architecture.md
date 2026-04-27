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

xeCJK 的字距控制还依赖 XeTeX 的 interchar 机制：字符先被分入 `Default`、`CJK`、`FullLeft`、`FullRight`、`Boundary` 等预定义类，以及 xeCJK 额外建立的 `HalfLeft`、`HalfRight`、`NormalSpace`、`CM` 等类，再由 `\XeTeXinterchartoks` 在类边界插入 `CJKglue` / `CJKecglue` 与相关分组 token。这里的关键不变量是：只有真正参与版面边界判定的可见字符，才应进入 class 序列；零宽格式字符若被当作普通字符参与分类，就会打断原本连续的 CJK 或 CJK↔Latin 边界，触发错误的 `CJKecglue` 或其他 inter-class toks 插入。

从维护视角看，xeCJK 的这套 interchar 逻辑更适合被理解成一个“边界恢复状态机”，而不是若干零散的 glue 宏：

- 第一层是边界判定。xeCJK 会在 `\xeCJK_make_node:n` 时插入内部标记 kern，后续主要通过 `\lastkern` 判断上一边界上保存的标记类型，以决定当前是否需要恢复 `CJKglue` 或 `CJKecglue`。
- 第二层是异常回退。若边界标记与当前待处理位置之间夹入 `\special` 产生的 whatsit，则 `\lastkern` 观察链会被打断，需要额外的 whatsit 回退路径跨越节点干扰继续恢复。
- 第三层是取值时机。前侧 `CJKecglue` 不是固定常量，而默认来自 `~` 的字体相关 glue，因此状态机除了判断“该不该恢复”，还必须保证“恢复时用的是哪一个已经在正确字体上下文里测得的值”。

因此，xeCJK 的边界问题若表现为“glue 丢失”或“glue 数值不对”，都应优先从同一条 interchar 恢复链来理解，而不是拆成互不相关的字符类、字体或颜色子问题。

Issue #581 暴露了这一点：U+200B ZERO WIDTH SPACE、U+200C ZERO WIDTH NON-JOINER、U+200D ZERO WIDTH JOINER 与 U+2060 WORD JOINER 虽然本身零宽，但若保留普通 catcode，仍会进入 xeCJK 的字符分类路径，导致原本不应变化的间距发生改变。当前实现选择在 `xeCJK/xeCJK.dtx` 的类设定初始化阶段，直接将这些字符与既有的 U+FEFF（BOM）一起设为 `\char_set_catcode_ignore:n`，使其在 TeX 输入层被忽略，不再触发 interchar 分类与 token 插入。

Issue #315 则暴露了另一类更隐蔽的边界恢复问题：即使参与排版的字符本身没有分类错误，`\textcolor`、`color`/`xcolor` 以及 PDF 注解等机制仍可能通过 `\special` 在节点链中插入 whatsit 节点（`\lastnodetype = 9`）。xeCJK 旧实现把“上一类边界标记是否存在”主要建模为 `\lastkern` 上的标记 kern；一旦 Boundary→Default 或 Boundary→CJK 过渡之间夹入 whatsit，这条检测链就会被打断，导致本应恢复的 `CJKecglue` / `CJKglue` 丢失。

当前修复在 `xeCJK/xeCJK.dtx` 中增加了一条“whatsit 回退”路径：

- 新增全局变量 `\g_@@_last_node_tl`，在 `\xeCJK_make_node:n` 创建内部标记节点时同步保存标记类型。
- 新增 `\@@_if_last_whatsit:TF`，以 `\lastnodetype = 9` 判断上一节点是否为 whatsit。
- 新增 `\@@_recover_ecglue_whatsit:` 与 `\@@_recover_glue_whatsit:`，当常规 `\lastkern` 检测失败但上一节点是 whatsit 时，回看 `\g_@@_last_node_tl` 决定是否恢复 `CJKecglue` 或 `CJKglue`。
- `\@@_check_for_ecglue:` 与 `\xeCJK_check_for_glue:` 在标准检测链末尾追加上述回退逻辑。
- `\xeCJK_remove_node:` 在消费完内部标记节点后清空保存的节点类型，避免跨边界误判。

这说明 xeCJK 的 glue 恢复机制不能只理解成“检查上一项是否有特定 kern”，而要理解成“围绕 interchar 边界标记的一个小状态机”：正常路径依赖标记 kern，异常路径需要跨越 whatsit 节点恢复之前保存的边界类型。遇到 xcolor、hyperref 注解或其他 `\special` 参与时出现的 CJK-Latin / CJK-CJK 间距丢失，首查的就不应只是 glue 参数或字符类，而应直接检查 `xeCJK/xeCJK.dtx` 中这条 whatsit 回退链是否被覆盖。

Issue #252 / #476 进一步说明，这条状态机不仅要解决“能否恢复”的问题，还要解决“恢复时取哪个 glue 值”的问题。`\CJKecglue` 默认是 `~`，其宽度、stretch、shrink 取决于当前字体的 `\fontdimen`；因此如果在 `\texttt`、`\textbf`、`\textit`、`\zihao` 或其他局部分组里切换了字体，再在边界恢复时直接重新展开 `\CJKecglue`，就会错误地使用组内字体的空格度量，而不是外层 CJK 字体的度量。

当前实现为此前侧 ecglue 恢复增加了“缓存值”这一层状态：

- 在 `\@@_boundary_group_end:n`，也就是 CJK→Boundary 过渡时，先把当时正确 CJK 字体上下文中的 `\CJKecglue` 缓存到 `\l_@@_ecglue_skip`。
- 后续所有前侧边界恢复路径统一使用这个缓存 skip，而不再在恢复点重新测量 `\CJKecglue`。
- 这样即使 Boundary 区间内部出现局部字体切换，真正恢复出来的 ecglue 仍保持离开 CJK 区域时的度量。

这个设计刻意选择“CJK→Boundary 时缓存”，而不是初始化时缓存或每个字符都缓存：初始化时拿到的值会随着后续字体/字号切换而过期；每字符缓存则频率过高、状态复杂度也更大。CJK→Boundary 正好是离开正确 CJK 字体上下文前的最后稳定时机，既保证度量正确，也把缓存成本限制在边界级别。

因此，修复后的 xeCJK interchar 状态机应整体理解为：

1. 用 `\lastkern` 标记 kern 判定上一边界类型；
2. 若被 whatsit 打断，则通过 `\lastnodetype` 与保存的节点类型走回退路径；
3. 若需要恢复前侧 ecglue，则不在恢复点重新展开 `\CJKecglue`，而是使用先前在 CJK→Boundary 时缓存的 `\l_@@_ecglue_skip`。

也就是说，#315 解决的是“边界恢复判定链会被 whatsit 打断”，#252 / #476 解决的是“边界恢复时重新测量 ecglue 会拿错字体度量”，二者共同构成当前 xeCJK 边界恢复机制的完整心智模型。

这个决策刻意没有采用另外两条看似直观的路线：

- 把零宽字符归入 `NormalSpace` 类并不安全，因为它会打断 CJK class 序列，反而破坏 `CJKglue`、字体选择和边界判定。
- 把零宽字符归入 XeTeX 256 透明类也不安全；`xeCJK.dtx` 已记录透明类在 `\bgroup` / `\egroup` 型 interchartoks 场景下会因为行尾或边界状态导致分组不匹配，这是已知限制。

因此，遇到“不可见 Unicode 格式字符影响 xeCJK 间距或边界行为”的问题时，应优先把它视为输入层字符过滤问题，而不是单纯的标点样式或 glue 参数问题，首查 `xeCJK/xeCJK.dtx` 中 catcode ignore 与字符分类初始化区段。

因此，在 XeTeX 路线下如果问题表现为：

- 中文标点宽度或压缩异常
- 句读与边界空白不符合预期
- `listings` 等特殊环境中的中日韩字符处理出错

优先去 `xeCJK/xeCJK.dtx` 查找，而不是从 `ctex` 入手。

## 第三方包兼容 hook

xeCJK 在 `xeCJK.dtx` 中通过 `\@@_package_hook:nn` 为多个第三方包（如 `pifont`、`listings`、`ulem` 等）注册兼容 hook。这些 hook 在目标包加载后执行，通常重定义目标包的关键命令以避免与 xeCJK 的 interchar token 机制冲突。

典型模式是在命令中临时调用 `\makexeCJKinactive`（将 `\XeTeXinterchartokenstate` 设为 0），执行目标操作后由 TeX 分组恢复状态。但在垂直模式下调用这些命令时，需要先进入水平模式（`\mode_leave_vertical:`），否则分页可能导致局部赋值泄漏到输出例程。

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
