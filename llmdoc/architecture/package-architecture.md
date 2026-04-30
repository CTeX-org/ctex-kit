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

`ctex-fontset-{windows,mac,macnew,macold,ubuntu,fandol,adobe,founder,hanyi}.def` 提供默认字体族映射，负责把“中文主字体/无衬线/等宽”等高层概念落到具体发行版或操作系统字体名。

`fontset=mac` 仍是自动入口，而不是独立字体集；它会在运行时于 `macnew` 和 `macold` 之间分流。自 PR #782 起，这个分流不再只依赖 `/System/Library/Fonts/PingFang.ttc` 是否存在，而是保留该路径检测作为快速路径，并在其失效时读取 `/System/Library/CoreServices/SystemVersion.plist` 的主版本号作为后备：版本号 `>= 15` 仍进入 `macnew`，`< 15` 进入 `macold`，检测失败则 warning 后回退 `macold`。

更重要的是，`macnew` 内部还要按引擎二次分支：XeTeX 用 `\fontspec_font_if_exist:nTF` 判断字体名是否可见；LuaTeX 则用 Lua 扫描 `/System/Library/AssetsV2` 下的 `com_apple_MobileAsset_Font*` 目录，定位 downloadable 字体的 `AssetData/` 路径，再配合 `Path=` 与 `FontIndex` 显式加载。也就是说，macOS 15+ 的适配发生在“fontset 层的自动分流 + macnew 内的引擎专属字体探测”两级，而不是通过新增 `mac15plus` 一类公开字体集完成。详见 `llmdoc/reference/ctex-fontset-mac.md`。

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

另一个稳定约束是 `\char` 与 interchar 的边界。XeTeX 的 interchar 机制在 token 层面工作，只会看到“将要输出的字符 token”，无法区分这个字符是来自直接 Unicode 输入，还是来自 `\char` 原语；这与 LuaTeX-ja 可在节点级 callback 中区分输出来源的模型根本不同。因此，xeCJK 不可能像 LuaTeX-ja 那样在完全不碰 `\char` 的前提下自动修复 Issue #407。

xeCJK 当前采取的最终路线是“三层策略”而不是重定义 `\char`：

- 提供显式命令 `\xeCJKchar`，其实现是在输出字符前临时关闭 interchar，再调用底层 `\tex_char:D`；它与 `\char` 用法相同，但语义上是“显式绕过 interchar 的字符输出接口”。
- 对已知受影响的第三方包做定点自动补丁。当前 `xeCJK/xeCJK.dtx` 已为 `mtpro2` 的 `\overcbrace` / `\undercbrace` 包装入口分组，并在入口处调用 `\makexeCJKinactive`，确保其内部 `\char` 取字形路径不被 interchar 干预。
- 在文档层明确要求用户对其他类似命令做手动 patch：要么直接把局部 `\char` 调用替换为 `\xeCJKchar`，要么在命令外层用分组加 `\makexeCJKinactive` 包装。

这也解释了为何早先的 `\AtBeginDocument` 方案被撤回：把 `\char` 在正文期延迟重定义虽然能绕开 xint 这类“加载期 `\let` 保存 primitive”的兼容问题，但仍然会改变文档体内 `\char` 的全局身份，不符合 xeCJK 现在确立的低侵入策略。当前架构约束更严格：`\char` 必须始终保持 XeTeX primitive 身份，兼容层只能通过新命令、定点补丁和用户手动包装来表达“这里需要绕过 interchar”。凡是未来再调整 `\char` 或类似原语兼容补丁时，都应把“是否改变 primitive 身份”视为架构级红线，而不是实现细节。

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

## listings 补丁子系统

在 `listings` 兼容层中，xeCJK 会覆写 `\lst@InsideConvert@` 与 `\lst@InlineGJ`，关键内部函数是 `\@@_listings_rescan:Nn`、`\@@_listings_inside_convert:nw`、`\@@_listings_inline_group:w`。这一子系统用 `\tl_set_rescan:Nno`（底层即 `\scantokens`）替代 listings 原生基于 `\lccode` + `\lowercase` 的逐字符转换，目的是避免把 charcode > 255 的 CJK 字符临时设为 active。

这条路径的边界在于 rescan 会先字符串化再重新取 token；Issue #378 说明若 `\lstinline` 位于宏参数中，参数传递保留下来的 catcode 6 `#` 会在 rescan 前被错误双写。当前修复是在 `\@@_listings_rescan:Nn` 内先用 `\regex_replace_all { \cP . } { \cA \x{23} }` 把这类 `#` 转成 active `#`，再进入 rescan，从而保持 listings 原有的输出流水线与盒子结构。

## 第三方包兼容 hook

xeCJK 在 `xeCJK.dtx` 中通过 `\@@_package_hook:nn` 为多个第三方包（如 `pifont`、`listings`、`ulem` 等）注册兼容 hook。这些 hook 在目标包加载后执行，通常重定义目标包的关键命令以避免与 xeCJK 的 interchar token 机制冲突。

典型模式是在命令中临时调用 `\makexeCJKinactive`（将 `\XeTeXinterchartokenstate` 设为 0），执行目标操作后由 TeX 分组恢复状态。但在垂直模式下调用这些命令时，需要先进入水平模式（`\mode_leave_vertical:`），否则分页可能导致局部赋值泄漏到输出例程。

## TECkit 映射与文档 driver 约束

`xeCJK/build.lua` 在标准 l3build 配置之外，还在 `unpack_posthook()` 中调用 `make_teckit_mapping()`，动态生成并编译 `.map`/`.tec` 文件。其输入来自 Unicode `Unihan.zip` 中的变体数据，并额外生成全角句号/句点映射。见 `xeCJK/build.lua:28-149`。

这说明 `xeCJK` 的一部分“功能数据”并不完全静态存放在仓库中，而是在构建阶段生成：

- 繁简转换映射
- 句号形态映射
- TECkit 编译产物 `.tec`

修改这部分功能时，要同时考虑源 Lua 逻辑、上游 Unicode 数据格式以及本地 `teckit_compile` 可用性。

另一个稳定约束是：xeCJK 的文档 driver 不能再假定 CI 或 Linux 环境拥有 Windows 专有字体。当前 driver 已把字体兼容性写成显式条件链：

- 主字体仍使用 `Source Han Serif`。
- `Ext-B` 字体通过 `\IfFontExistsTF{SimSun-ExtB}` 条件化选择；若缺失，则回退到 `HanaMinB`。
- `xunicode-symbols.tex` 中的符号字体也不再直接写死 `Segoe UI Symbol`，而是条件化回退到 `Noto Sans Symbols 2`。

这使文档构建从“依赖某个特定操作系统字体集合”转为“依赖一组可在 CI 中稳定安装的字体族”。因此，未来若再调整 xeCJK 文档示例或 driver，优先延续这种 `\IfFontExistsTF` + 明确 fallback 的模式，而不要重新引入未声明的系统字体硬依赖。

此外，xeCJK driver 内部还有两个与构建稳定性直接相关的约束：

- `\PrintPunctList` 内部访问的内部常量必须显式写成 `c__xeCJK_...` 形式；driver 代码不处在模块替换区间，不能依赖 `c_@@_...` 自动展开。
- `\changes` 条目中的字面字符说明若包含竖线包裹形式，如 `|U+04AA|`，可能与 MakeIndex 解析发生冲突；当前稳定写法改为 `\texttt{U+04AA}`。

因此，xeCJK 的文档构建应被视为“源码实现 + driver 文档程序 + CI 字体环境”共同组成的系统，而不是单纯排版主包文档。

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

### LuaTeX 路线的特殊点：ctex 会主动屏蔽 `ltj-latex`

LuaTeX 路线并不是”原样加载 LuaTeX-ja 全家桶”，而是由 `ctex` 在自己的引擎适配层中接管一部分接口，并通过 `\@namedef{ver@ltj-latex.sty}{}` 主动阻止 `ltj-latex` 再次进入标准加载链。这样做的直接目的，是避免 `ctex` 与 LuaTeX-ja 在 LaTeX 层包装上重复接管同一批接口。

但这个设计有一个重要副作用：`ltj-latex` 被屏蔽时，依赖它进入加载链的 `lltjcore.sty` 也会一起缺席。后者不只是”普通底层文件”，还携带若干对 LaTeX 原生命令的兼容补丁，因此在排查 LuaLaTeX 专属异常时，不能只看 `ctex-engine-luatex.def` 是否设置了某个参数，还要检查 ctex 是否因此漏接了原本由 `lltjcore` 提供的行为修正。

### v2.5.12 补回 `lltjcore` 的 `\verb`/`\do@noligs` 补丁

Issue #556 暴露了这个副作用的具体实例：LuaLaTeX 下 `\verb` 前 xkanjiskip 被吞掉，并不是因为 `autoxspacing` 选项被关闭，而是因为 `ctex` 禁用 `ltj-latex` 后，连带漏掉了 `lltjcore.sty` 对 `\verb` 和 `\do@noligs` 的关键补丁。

`lltjcore` 的核心修正是把 `\verb` 流程里的 `\null`（空 `\hbox{}`）替换为 `\vadjust{}`。对 luatexja 而言，空 `\hbox{}` 会插入一个真实盒节点，打断相邻字符边界的观察，从而阻断 xkanjiskip 自动插入；改成 `\vadjust{}` 后则不会在水平列表里留下这个阻断点。

因此，自 v2.5.12 / PR #792 起，`ctex/ctex.dtx` 的 LuaTeX 引擎适配中显式移植了 `lltjcore` 对 `\verb` 与 `\do@noligs` 的相关补丁。这个案例说明：LuaTeX 适配层不仅负责”选择后端”，还要补齐因屏蔽上游入口包而丢失的细粒度兼容行为。

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
