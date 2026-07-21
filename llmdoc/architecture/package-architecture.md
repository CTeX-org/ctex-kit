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

`ctex` 自 #937 起由六个 `.dtx` 分工：`ctex.dtx` 保留安装脚本与用户手册，`ctex-kernel.dtx` 承载类和主宏包，`ctex-auxpkg.dtx` 承载内部辅助包，`ctex-engine.dtx`、`ctex-scheme.dtx`、`ctex-fontset.dtx` 分别承载引擎、方案和字体集。主 `ctex.dtx` 的 docstrip 安装段跨文件取出各标签并生成：

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

关键关系是：`<class> -> ctex-scheme-<chinese|plain>-<class>.def -> ctex-heading-<class>.def`，并与引擎、字体集层交错组合；生成入口见 `ctex/ctex.dtx`，实现分别见 `ctex/ctex-kernel.dtx`、`ctex/ctex-scheme.dtx`、`ctex/ctex-engine.dtx`、`ctex/ctex-fontset.dtx`。

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

这一点不仅影响 XeTeX 路径中的 `xeCJK/xeCJK.dtx`，也影响 LuaTeX 路径中 `ctex/ctex-engine.dtx` 的对应实现：LuaTeX 下 `\newCJKfontfamily` 最终走 `\ctex_ltj_set_family:nnn` 注册字体族，而用户可见切换命令同样改为局部定义。因此，遇到“组内声明的新字体切换命令在组外是否仍然存在”这类问题时，应把它视为跨 XeTeX/LuaTeX 两条后端路径共享的接口语义，而不是某一端独有的偶发行为。

## 标点挤压与空白控制

`xeCJK` 的一个核心能力是标点挤压与样式策略。它提供 `PunctStyle` 机制以及 `quanjiao`、`banjiao`、`kaiming`、`hangmobanjiao`、`CCT` 等预设，并允许用 `\xeCJKDeclarePunctStyle` 声明自定义规则。相关内部实现大量使用 `\xeCJK_...` 与私有 `\@@_...` 例程处理 kerning margin、相邻标点压缩与行末位移。

xeCJK 的字距控制还依赖 XeTeX 的 interchar 机制：字符先被分入 `Default`、`CJK`、`FullLeft`、`FullRight`、`Boundary` 等预定义类，以及 xeCJK 额外建立的 `HalfLeft`、`HalfRight`、`NormalSpace`、`CM` 等类，再由 `\XeTeXinterchartoks` 在类边界插入 `CJKglue` / `CJKecglue` 与相关分组 token。这里的关键不变量是：只有真正参与版面边界判定的可见字符，才应进入 class 序列；零宽格式字符若被当作普通字符参与分类，就会打断原本连续的 CJK 或 CJK↔Latin 边界，触发错误的 `CJKecglue` 或其他 inter-class toks 插入。

Issue #811 在这套 interchar 分类上新增了实验性选项 `experiment/halfright-prebreakpenalty`。该选项默认关闭；打开后，xeCJK 会在 `CJK -> HalfRight` 与 `FullRight -> HalfRight` 两类过渡中条件性插入 `\xeCJK_no_break:`，也就是 penalty 10000，阻止半角右标点出现在行首。这里的 `HalfRight` 不是一个为 #811 临时拆出来的新类，而是 xeCJK 既有的“半角右标点”整体类别，当前固定包含 13 个成员：`!`、`"`、`%`、`'`、`)`、`,`、`.`、`:`、`;`、`?`、`]`、`}` 与 `U+232A`，全部都属于收尾型右侧标点，因此实现上直接针对整个类施加统一禁则，而不是再细分字符类。

Issue #382 修复了破折号（U+2014）连用宽度不符合 CLReq 要求的问题：`\@@_long_punct_kerning:N` 的中间压缩量改为兼容三类字库（字面窄于字框/溢出字框/字框宽于字号）的三路取大公式，`\xeCJK_punct_margin_process:NN` 对未合字的破折号两端各补偿一整份空白而非半份；同时新增零注入字符类 `PoZheHao`（opt-in，`\xeCJKsetup{PoZheHaoLigature}`），使支持 OpenType 破折号合字的字体（如思源宋体/黑体）能正常触发合字。这也暴露了一条架构级限制：xeCJK 的标点度量经 `\XeTeXcharglyph`（cmap 直查）获取，不经过 OpenType shaping，`locl`/`fwid` 等字形替换特性生效后度量不会更新。详见 `llmdoc/architecture/xecjk-architecture.md` 标点压缩系统一节。

Issue #158 将旧的单一 `HangulJamo` 零注入类拆为 Unicode 17 L/V/T 三类：只清空 UAX #29 音节延续转移，其他组合复制 CJK→CJK，从而同时保留分解音节 shaping 和相邻音节的 `CJKglue`；listings 只给 L 计一个 CJK 单元，V/T 计零宽。Issue #165 新增 `CJStarter` 与 `CJLineBreak=normal|strict`：默认保持普通 CJK 行为，strict 在 Unicode CJ 字符前加入 penalty 10000 而不改变字距。`FullRight→CJStarter` 的 penalty 必须在标点胶之前，且该专用 helper 必须加入 xeCJKfntef 的宏交换表，不能以内联 token 绕过 ulem 路径。

这个选项的实现还确立了一个重要顺序约束：`FullRight -> HalfRight` 过渡不能只是在原有 interchartoks 后面追加 penalty，而必须完整覆写该过渡的 interchartoks 定义。原因是 xeCJK 原有这一路径会先执行 `\@@_punct_glue:NN`；如果 penalty 放在 glue 之后，断行点已经落在 glue 之前，无法真正阻止半角右标点被排到下一行的行首。因此新的定义必须把 penalty 放在 `\@@_punct_glue:NN` 之前，再接续原有标点胶逻辑。相比之下，`CJK -> HalfRight` 路径原本没有同样的前置 glue 顺序约束，因此可以在既有定义上条件追加禁则。

Issue #859 新增了另一个实验性选项 `experiment/punct-measure-fix`，解决段落模式下 `\unskip` 吞掉段末标点补偿 glue 的问题。LaTeX 的 `\para_end:` 在执行 `\tex_par:D` 之前会通过 `\unskip` 移除水平列表末尾的 glue；如果段末恰好是全角标点，其补偿 glue 也会被移除，导致 `tabularray` 等使用 `\par` 结束测量段落的宏包得到不正确的宽度。启用该选项后，xeCJK 在 `\@@_punct_boundary_guard:` 的段落模式分支中记录补偿 glue 的自然宽度到 `\g_@@_par_guard_dim`，并通过 `para/end` 钩子插入等宽 `\kern` 补偿。这与 v3.10.0 为 #827 引入的 inner mode 分支（插入 `\penalty 0` 保护 `\env{tabular}` 中的补偿 glue）互补，两者共同构成 `\@@_punct_boundary_guard:` 的完整保护策略。

另一个稳定约束是 `\char` 与 interchar 的边界。XeTeX 的 interchar 机制在 token 层面工作，只会看到“将要输出的字符 token”，无法区分这个字符是来自直接 Unicode 输入，还是来自 `\char` 原语；这与 LuaTeX-ja 可在节点级 callback 中区分输出来源的模型根本不同。因此，xeCJK 不可能像 LuaTeX-ja 那样在完全不碰 `\char` 的前提下自动修复 Issue #407。

xeCJK 当前采取的最终路线是“三层策略”而不是重定义 `\char`：

- 提供显式命令 `\xeCJKchar`，其实现是在输出字符前临时关闭 interchar，再调用底层 `\tex_char:D`；它与 `\char` 用法相同，但语义上是“显式绕过 interchar 的字符输出接口”。
- 对已知受影响的第三方包做定点自动补丁。当前 `xeCJK/xeCJK.dtx` 已为 `mtpro2` 的 `\overcbrace` / `\undercbrace` 包装入口分组，并在入口处调用 `\makexeCJKinactive`，确保其内部 `\char` 取字形路径不被 interchar 干预。
- 在文档层明确要求用户对其他类似命令做手动 patch：要么直接把局部 `\char` 调用替换为 `\xeCJKchar`，要么在命令外层用分组加 `\makexeCJKinactive` 包装。

这也解释了为何早先的 `\AtBeginDocument` 方案被撤回：把 `\char` 在正文期延迟重定义虽然能绕开 xint 这类“加载期 `\let` 保存 primitive”的兼容问题，但仍然会改变文档体内 `\char` 的全局身份，不符合 xeCJK 现在确立的低侵入策略。当前架构约束更严格：`\char` 必须始终保持 XeTeX primitive 身份，兼容层只能通过新命令、定点补丁和用户手动包装来表达“这里需要绕过 interchar”。凡是未来再调整 `\char` 或类似原语兼容补丁时，都应把“是否改变 primitive 身份”视为架构级红线，而不是实现细节。

从维护视角看，xeCJK 的 interchar 间距由两层机制协作：

- 基础恢复链在 CJK→Boundary 时写入 marker kern 并缓存当时字体上下文中的 `\CJKecglue`，Boundary→CJK/Default 时用列表节点证据恢复 `\CJKglue` 或 `\CJKecglue`。只有 `\g_@@_glue_check_pending_bool` 已设置时，恢复链才会暂时移除末尾的源码词间 glue，并检查其下方的 marker；通用 whatsit 恢复仍被禁止。
- 命令边界 capture/register 层把分组、盒子、annotation、verbatim、锚点和 write 等会遮住边界节点的情况交给一组共用的恢复函数处理。interchar transition 在运行时报告实际首尾 `CJK` / `default` 类别，出口按直接输入语义重建两侧边界。

#992 的契约不是“某命令永远属于某类”，而是命令包装与相同可见字符的直接输入等价。西文/数字输出按 Default，中文输出按 CJK，混合输出左右分别判断，无可见输出应透明；`00/10/01/11` 四种源码空格必须逐格验证。#491 那种每个命令抽一个成功场景的证据不能推出整类已修复。

注册策略按节点形式分为五类：`box` 取出命令留下的末尾 hbox；`wrapped-box` 收集会写出多个节点的盒子命令；`stream` 直接观察当前列表；`transparent` 完整恢复不可见命令的入口状态；`post-transparent` 处理只能在 after hook 观察到的末尾盒子，且该盒子的宽、高、深均为零。`auto`、`default`、`first-default` 再声明首尾类别是实际观察还是由可见包装固定。

每层 capture 保存入口 marker、源码空格、`\CJKglue` / `\CJKecglue` 和相关选项，在结束时重建左边界，并把末类别写成 marker 交给普通恢复逻辑。嵌套的 box 如果以只能推断为 Default 的内容结束，该命令写入的 marker 会留在外层盒子的节点列表末尾；外层盒子结束时读取它，便能逐层更新末类别，而不必直接改写所有外层 capture。前两层 register 预先分配，更深层按需创建；`\sbox` 暂停观察并保存、恢复基础 marker 与 pending 状态，避免离线测量污染外层命令。该模型覆盖普通盒子、12 层嵌套、混合输出、hyperref、verb、URL、引用、codedoc/doc、color/l3color、biblatex、listings、xeCJKfntef、原生 ulem 与一般 `\null`，细节集中在 `llmdoc/architecture/xecjk-architecture.md`。

#999 已删除这一问题族中生效的逐命令 save/replay/drain/pending 算法：`\@setref` / `\real@setref`、完整 `\Url@z`、hyperref annotation、`\verb`、codedoc/doc meta、color/l3color、biblatex、fntef/ulem 与 `\lstinline` 都进入共享 capture。仍保留的代码只解决控制序列签名、分隔符扫描、加载时序或命令内部排版语义，例如 meta 参数的 hbox 规范化、`\verb` 的 language whatsit 主动落盘、ulem 的外层非装饰 glue 通道；它们不再各自实现边界恢复状态机。#873/#880/#910/#931/#972 与 #991 的旧方案仅作为演进历史保留。

TeX 节点不记录 glue 的来源。显式 `\hskip` 如果与普通词间空格具有相同的自然宽度和 shrink，恢复逻辑就无法判断它是源码空格还是用户写出的 glue。若必须保留这种 glue，可在前面加 `\kern0pt`，也可以改变自然宽度或去掉 shrink。继续向前检查更多节点仍无法补回来源信息，因此不应靠猜测处理。

Issue #581 属于输入层而非 command capture：U+200B、U+200C、U+200D、U+2060 与 U+FEFF 被设为 `\char_set_catcode_ignore:n`，避免零宽格式字符进入 class 序列并打断本来连续的边界。

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

Issue #717 新增的 `\ctexset{ experiment/CJKecglue = ... }` 是这种“统一入口 + XeTeX 代理后端”关系的直接例子。该接口没有把 `CJKecglue` 提升为主 key，而是在 `ctex` keypath 下先建立 `experiment` 子路径，再按引擎分派：XeTeX 把用户传入的 skip 值转成 xeCJK 可接受的 `CJKecglue` 设置，LuaTeX / upTeX 映射到 `xkanjiskip`，pdfTeX 则只发出不支持警告。也就是说，`ctex` 对外暴露的是统一名字，对内承认三条后端语义并不完全同构，因此把该能力显式约束在实验性命名空间中。

Issue #543 的 `experiment/font-size-system` 进一步扩展了这个命名空间的用途：它不对应某个后端包的单一开关，而是控制 `ctex/ctex-kernel.dtx` 内部 `\c_@@_font_size_prop` 的构建数据源。当前预设有 `word`（默认）与 `letterpress` 两套字号表；初始化阶段会对 `\g_@@_font_size_system_tl` 做 `\str_case:onF` 分派，若值不是这两个预设之一，则尝试载入 `ctex-fontsize-<name>.def`，并要求该文件通过公开 API `\ctex_save_font_size:nn` 写入字号数据。Issue #813 将原名 `traditional` 更名为 `letterpress`，以避免与 Traditional Chinese 混淆，并把语义明确收窄到金属活字排印时代的字号体系。找不到对应定义文件时，ctex 会发出 `fontsize-system-not-found` 错误并回退到 `word`。这里还有一个稳定边界：该选项只在类/宏包选项解析期生效，不支持用 `\ctexset` 在运行时切换，因为字号表最终被冻结为常量 prop/seq，后续 `\zihao` 与数学字号声明都直接读取这份编译期常量。

## 第三方包补丁子系统

ctex 在 `ctex/ctex-kernel.dtx` 的 class/heading 区段维护对 varioref、cleveref、hyperref 等第三方包的兼容补丁。补丁通过 `ctex_at_end_package:nn` 延迟到目标包加载后执行，核心工具是 `ctex_patch_cmd_all:NnnnTF`（定义在 ctexpatch 区段），实现命令体内的文本搜索替换。

部分补丁提供用户开关（如 `\ctexset{ patch/cleveref }`），允许在补丁与上游更新冲突时关闭。详见 `llmdoc/architecture/cleveref-patch.md`。

## 引擎适配策略

`ctex` 的整体策略是对外提供统一中文接口，对内按引擎切到不同技术路线：

- XeTeX → `xeCJK`
- LuaTeX → `LuaTeX-ja`
- pdfTeX → `CJK` / `zhmCJK`
- upTeX → 专用中文度量与字体支持
- apTeX → 独立引擎适配层

这是整个仓库最关键的架构不变量之一：`ctex` 不试图用一套底层实现覆盖所有引擎，而是把统一接口建立在多后端适配之上。XeTeX、LuaTeX、pdfTeX、upTeX 各自对应不同的底层机制，见 `ctex/ctex-engine.dtx` 与 `ctex/build.lua:46` 的多引擎测试配置。

### 同名宏包不代表同一实现：`CJKfntef` 边界（#381）

XeTeX 下，`xeCJK/xeCJK.dtx:1896` 会把用户请求的 `CJKfntef` 透明替换为 API 基本一致的 `xeCJKfntef`，所以不会载入传统 `CJK.sty`。LuaTeX 没有同构替代：`lua-ul` 提供相近效果，但命令接口和实现模型不同，不能静默冒充 `CJKfntef`。

因此 `ctex/ctex-engine.dtx:878` 在 LuaTeX 后端加载 LuaTeX-ja 前建立硬边界：已经载入 `CJKfntef` 时发出 critical 并中止；尚未载入时注册禁载回调，后续请求只加载失败并得到迁移到 `lua-ul` 的 warning。pdfTeX 保留传统 CJK 路线，XeTeX 保留上述透明替换。判定第三方包兼容性时必须核对实际解析到的 `.sty` 和后端协议，不能只看用户输入的包名。

Issue #717 的 `experiment/CJKecglue` 进一步把这条策略具体化为一个稳定模式：新增跨引擎接口时，可先在 `ctex` keypath 下通过 `.meta:nn` 建立 `experiment` 子路径，再把同一个 key 名映射到各引擎最接近的既有能力。当前 `CJKecglue` 的映射关系是 XeTeX → xeCJK `CJKecglue`，LuaTeX / upTeX → `xkanjiskip`，pdfTeX → warning。这个例子说明，`ctex` 的“统一接口”并不要求所有后端都拥有完全同构的语义；当某个能力只在部分引擎可表达、且观测面本身不同，就应保留实验性命名空间，而不是提前承诺为正式主接口。

### LuaTeX 路线的特殊点：ctex 会主动屏蔽 `ltj-latex`

LuaTeX 路线并不是”原样加载 LuaTeX-ja 全家桶”，而是由 `ctex` 在自己的引擎适配层中接管一部分接口，并通过 `\@namedef{ver@ltj-latex.sty}{}` 主动阻止 `ltj-latex` 再次进入标准加载链。这样做的直接目的，是避免 `ctex` 与 LuaTeX-ja 在 LaTeX 层包装上重复接管同一批接口。

但这个设计有一个重要副作用：`ltj-latex` 被屏蔽时，依赖它进入加载链的 `lltjcore.sty` 也会一起缺席。后者不只是”普通底层文件”，还携带若干对 LaTeX 原生命令的兼容补丁，因此在排查 LuaLaTeX 专属异常时，不能只看 `ctex-engine-luatex.def` 是否设置了某个参数，还要检查 ctex 是否因此漏接了原本由 `lltjcore` 提供的行为修正。

### v2.5.12 补回 `lltjcore` 的 `\verb`/`\do@noligs` 补丁

Issue #556 暴露了这个副作用的具体实例：LuaLaTeX 下 `\verb` 前 xkanjiskip 被吞掉，并不是因为 `autoxspacing` 选项被关闭，而是因为 `ctex` 禁用 `ltj-latex` 后，连带漏掉了 `lltjcore.sty` 对 `\verb` 和 `\do@noligs` 的关键补丁。

`lltjcore` 的核心修正是把 `\verb` 流程里的 `\null`（空 `\hbox{}`）替换为 `\vadjust{}`。对 luatexja 而言，空 `\hbox{}` 会插入一个真实盒节点，打断相邻字符边界的观察，从而阻断 xkanjiskip 自动插入；改成 `\vadjust{}` 后则不会在水平列表里留下这个阻断点。

因此，自 v2.5.12 / PR #792 起，`ctex/ctex-engine.dtx` 的 LuaTeX 引擎适配中显式移植了 `lltjcore` 对 `\verb` 与 `\do@noligs` 的相关补丁。这个案例说明：LuaTeX 适配层不仅负责”选择后端”，还要补齐因屏蔽上游入口包而丢失的细粒度兼容行为。

### 引擎条件代码的延迟重定义模式

`ctex.sty` 以 `{style,ctex}` 标签从 `ctex-kernel.dtx` 生成，不含引擎标签（`pdftex`、`xetex` 等）。这意味着在 `ctex.sty` 对应的公共代码区域中直接使用 `%<*pdftex|xetex>` docstrip 守卫会被剥离，实际无效。

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

`ctex/ctex-kernel.dtx` 中的 linestretch 函数定义（公共区域）和 `ctex/ctex-engine.dtx` 的引擎 `.def` 代码段（pdftex/xetex 特化）。回归测试 `ctex/test/testfiles/ccglue01.lvt`。

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

1. `ctex/ctex-kernel.dtx` 或对应职责的 `ctex-*.dtx`
2. `xeCJK/xeCJK.dtx`
3. 对应包的 `build.lua`
4. `support/build-config.lua`

这四处覆盖了绝大多数主干行为与构建入口。
