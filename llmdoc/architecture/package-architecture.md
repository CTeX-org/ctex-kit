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

从维护视角看，xeCJK 的这套 interchar 逻辑更适合被理解成一个“边界恢复状态机”，而不是若干零散的 glue 宏：

- 第一层是边界判定。xeCJK 会在 `\xeCJK_make_node:n` 时插入内部标记 kern，后续主要通过 `\lastkern` 判断上一边界上保存的标记类型，以决定当前是否需要恢复 `CJKglue` 或 `CJKecglue`。
- 第二层是异常回退。若边界标记与当前待处理位置之间夹入 `\special` 产生的 whatsit，则 `\lastkern` 观察链会被打断，需要额外的 whatsit 回退路径跨越节点干扰继续恢复。
- 第三层是取值时机。前侧 `CJKecglue` 不是固定常量，而默认来自 `~` 的字体相关 glue，因此状态机除了判断“该不该恢复”，还必须保证“恢复时用的是哪一个已经在正确字体上下文里测得的值”。
- 还有一个与 whatsit 不同、但症状同样表现为“`\lastkern` 看不到边界标记”的遮蔽模式：若 `CJK -> Boundary` 过渡在写下 `CJK-space` 标记 kern 之后，又立刻输出一个普通 glue，那么最后可观察节点同样不再是标记 kern，后续恢复判定会像遭遇 whatsit 一样失效。

因此，xeCJK 的边界问题若表现为“glue 丢失”或“glue 数值不对”，都应优先从同一条 interchar 恢复链来理解，而不是拆成互不相关的字符类、字体或颜色子问题。

Issue #581 暴露了这一点：U+200B ZERO WIDTH SPACE、U+200C ZERO WIDTH NON-JOINER、U+200D ZERO WIDTH JOINER 与 U+2060 WORD JOINER 虽然本身零宽，但若保留普通 catcode，仍会进入 xeCJK 的字符分类路径，导致原本不应变化的间距发生改变。当前实现选择在 `xeCJK/xeCJK.dtx` 的类设定初始化阶段，直接将这些字符与既有的 U+FEFF（BOM）一起设为 `\char_set_catcode_ignore:n`，使其在 TeX 输入层被忽略，不再触发 interchar 分类与 token 插入。

Issue #315 则暴露了另一类更隐蔽的边界恢复问题：即使参与排版的字符本身没有分类错误，`\textcolor`、`color`/`xcolor` 以及 PDF 注解等机制仍可能通过 `\special` 在节点链中插入 whatsit 节点（`\lastnodetype = 9`）。xeCJK 旧实现把“上一类边界标记是否存在”主要建模为 `\lastkern` 上的标记 kern；一旦 Boundary→Default 或 Boundary→CJK 过渡之间夹入 whatsit，这条检测链就会被打断，导致本应恢复的 `CJKecglue` / `CJKglue` 丢失。

PR #791 对 #315 的修复曾把这条恢复链泛化为“只要上一节点是 whatsit，就根据 `\g_@@_last_node_tl` 恢复 glue”。这条通用 whatsit 恢复链虽然修复了 `\textcolor` 导致的 ecglue 丢失，但后来在 #803 中暴露出边界定义过宽的问题：如果 biblatex 的 `gb7714-2015` 样式把引用括号包进 `\raise\hbox{[}`，而 `hyperref` 又在括号与数字之间插入 PDF 注解 whatsit，那么 xeCJK 会把“hbox 后的任意 whatsit”误判成可恢复的 CJK→Default 边界，错误地在 `[` 与 `1` 之间补入 ecglue，生成可见的 `[ 1]` 类间距。

当前 xeCJK 对 whatsit 的稳定约束因此已经收窄为“定点恢复，而不是通用恢复”：

- `\@@_check_for_ecglue:` 的最后回退分支不再调用 `\@@_recover_ecglue_whatsit:`；也就是说，xeCJK 不再因为“上一节点是任意 whatsit”就恢复前侧 ecglue。
- `\g_@@_last_node_tl` 仍然保留，用于记录最近一次 `\xeCJK_make_node:n` 创建的 xeCJK 内部标记类型；但这份状态不再被 `\@@_check_for_ecglue:` 当作全局后备。
- 真正需要跨 whatsit 续接边界语义的场景，目前按已知调用方定点补丁：
  - `color` / `xcolor` 的 `\set@color`：在颜色切换 whatsit 插入后，如果 `\g_@@_last_node_tl` 非空，就立即重放对应的 xeCJK 标记节点；而在 no-node 分支则必须先清空 `\g_@@_last_node_tl`，避免把初始化阶段或前序调用残留的 `default` 送进后续恢复链。
  - `color` / `xcolor` 的 `\reset@color`（#831）：在 color-pop whatsit 插入后，重新放置 kern pair 标记并设置 `\g_@@_ulem_pending_bool`，使后续 `\@@_check_for_glue_skip:` 能正确处理 `\textcolor` 结束端的 glue-on-kern-pair。
  - `hyperref` 的 `\Hy@BeginAnnot`：进入链接注释前先保存当前 xeCJK 节点类别并清空旧状态，待注释起始 whatsit 插入后，只对 `CJK` / `CJK-space` / `CJK-widow` 三类节点选择性重放标记，而显式不重放 `default`。
  - `hyperref` 的 `\Hy@EndAnnot`（#972）：在顶层 annotation 结束前若实际最后节点为 math，则在原始结束 whatsit 后发布专用 `hyperref-default`；它表示已验证的西文末边界，可跨随后颜色或 annotation 包装，而普通 `default` 仍按 #810 排除。
  - `l3color`（expl3 内置）的 `\__color_select:N` 和 `\__color_backend_reset:`（#832）：l3color 的颜色机制使用独立的后端代码路径，不经过 `\set@color`/`\reset@color`。`\__color_select:N` 负责颜色推入（调用后端 select 并注册 aftergroup reset），`\__color_backend_reset:` 负责颜色弹出。此处对这两个函数施加与 `\set@color`/`\reset@color` 相同的 kern 对保护，使 l3color 接口的颜色切换也能正确保持 xeCJK 间距。
- 这等价于把“跨 whatsit 恢复 glue”改写成“在已知安全的 whatsit 之后补回 xeCJK 自己的标记 kern”，让后续 `\lastkern` 检测继续工作，而不是让恢复函数去猜测任意 whatsit 后面应不应该补 glue。

这一变化把 Issue #315、#803、#807、#809、#810、#832 与 #972 统一到同一条更精确的心智模型里：并不是所有 whatsit 都代表“合法的边界中断”，只有 xeCJK 明确认识、并能在其后立即重建有证据的内部标记的 whatsit 才能参与边界恢复。当前已知的安全场景包括 `color` / `xcolor` 的 `\set@color`/`\reset@color`、`l3color` 的 `\__color_select:N`/`\__color_backend_reset:`，以及 `hyperref` 的 `\Hy@BeginAnnot` 与受末尾 math + 顶层 annotation 双重约束的 `\Hy@EndAnnot`；其他 whatsit 不能使用通用恢复逻辑。此外，`\set@color` 补丁依赖 `\g_@@_last_node_tl` 决定重建哪种 kern pair，因此任何在 hbox 内触发 interchar toks 全局修改该状态的代码路径（如 `\xeCJK_fntef_sbox:n`）都必须在 hbox 前后隔离状态。

`hyperref` 的开始端与结束端处理不同事件，不能再泛化为“只 patch 某一端”：

- #809 的缺前侧 ecglue，根因是 `\Hy@BeginAnnot` 内部 `\set@color` 生成的 whatsit 把原本应保留的 `CJK` 边界标记覆盖成 `default`，使 CJK→Default 边界不再触发 ecglue。
- #810 的目录伪空白，根因则是链接注释起始处的 `pdf:bann` whatsit 错误继承旧 `default` 状态，通过 whatsit 恢复路径补出了本不该存在的 ecglue。
- 对 #809/#810，补丁必须在进入注释前完成“保存真实状态 + 清空陈旧状态”，开始后选择性重放；结束端无法挽回已经发生的入口污染。
- #972 是独立的输出端故障：`\url` 内容末尾的 math 节点本来足以触发右侧 ecglue，但 `\Hy@EndAnnot` 的 whatsit 把它遮蔽。此时结束端能在 whatsit 插入前观察真实末节点，因此以专用 `hyperref-default` 发布可信的西文边界是正确修复点。

这里还有一个关键约束不能丢：`\@@_recover_glue_whatsit:` 内部的 `default` 分支不能删除，因为 `color` / `xcolor` 的修复仍依赖它恢复合法边界；同时也不能让 #972 复用普通 `default`，否则下一次 `\Hy@BeginAnnot` 会按 #810 正确地拒绝它。专用 marker 的名称同时编码 Default-like 语义与可信来源。

Issue #252 / #476 进一步说明，这条状态机不仅要解决“能否恢复”的问题，还要解决“恢复时取哪个 glue 值”的问题。`\CJKecglue` 默认是 `~`，其宽度、stretch、shrink 取决于当前字体的 `\fontdimen`；因此如果在 `\texttt`、`\textbf`、`\textit`、`\zihao` 或其他局部分组里切换了字体，再在边界恢复时直接重新展开 `\CJKecglue`，就会错误地使用组内字体的空格度量，而不是外层 CJK 字体的度量。

Issue #324 则补上了另一条前置约束：在 `\@@_boundary_reserve_space:` 这条 CJK→Boundary 宏路径里，旧实现会先经 `\@@_boundary_group_end:n { CJK-space }` 留下 `CJK-space` 标记 kern，再立即执行 `\xeCJK_space_or_xecglue:` 输出一个普通空格 glue。这样一来，后续 `Boundary -> CJK` / `Boundary -> Default` 恢复逻辑再做 `\lastkern` 检查时，看到的最后节点已经变成这段 glue，而不是刚写下的 `CJK-space` 标记；症状上与 whatsit 打断恢复链相同，都是”标记不再是 `\lastkern` 可见的最后节点”，但根因不同：#315 一类问题来自第三方插入的 whatsit，#324 则是 xeCJK 自己在宏路径上额外输出了不该提前出现的 glue。

Issue #826 揭示了同一类遮蔽模式的第三个变体：xeCJKfntef 命令（`\CJKsout`、`\CJKunderdot` 等）的内容在 ulem 的 hbox 中排版，不在主 hlist 上。当 hbox 关闭后，XeTeX 的 interchar 机制看到的不是 CJK 字符类，源码空格因此产生 finite inter-word glue，叠在先前写下的 CJK kern pair 标记上方。`\xeCJK_check_for_glue:` 的 `\@@_if_last_glue:TF` 分支原来只做了简单回退，没有尝试”揭开 glue 查看下方是否有 kern pair 标记”的探测。修复通过新增 `\@@_check_for_glue_skip:` 函数完成：先做 finite/shrink 前置检查过滤 fil 级 glue 和 `\quad`，再分两条路径处理——kern 路径由 `\g_@@_ulem_pending_bool` 门控保存并移除 finite glue 后探测下方标记 kern；hlist 路径不依赖 boolean，通过 `\g_@@_last_node_tl` 判断 hbox 内容类型（如 `\mbox` 产生的 hbox）。`\g_@@_ulem_pending_bool` 作为 kern 路径的门控，目前有三个 set 点：(1) `\@@_ulem_group_end:n`（ulem hbox 关闭），(2) `\@@_under_symbol_auxii:nnnnnn`（着重号独立模式），(3) CJK→Boundary handler 中 peek token 为 catcode 2（显式 `}`，#831）。此外，`\reset@color` 补丁在 color-pop whatsit 后也会设置该 boolean（#831）。

Issue #831 揭示了相同 glue-on-kern-pair 模式的非 fntef 触发场景：`前{中} 后` 中显式 `}`（catcode 2）触发 Boundary class，分组结束后源码空格同样产生 inter-word glue。修复复用了 #826 的 `\@@_check_for_glue_skip:` 消费端，只需在 CJK→Boundary handler 中对 catcode 2 的 peek token 新增 boolean set 点。后续进一步解决了 `\textcolor` 和 `\mbox` 两个原先标记为已知限制的场景：(1) 新增 `\reset@color` 定点补丁，在 color-pop whatsit 后重放 kern pair 并设置 boolean；(2) 新增 hlist 回退路径，通过 `\g_@@_last_node_tl` 穿透 hbox 判断内容类型。这将 `\g_@@_ulem_pending_bool` 的语义从”fntef 专属标记”扩展为”已知会产生 glue-on-kern-pair 的场景标记”。

v3.10.0 起，`\@@_boundary_reserve_space:` 不再在宏路径中立即输出这段空格 glue，而是与非宏路径保持一致，只保留 `CJK-space` 标记，把是否恢复以及恢复什么间距继续交给后续 interchar 边界状态机统一决定。也就是说，源码中的空格是否最终转化为可见间距，不应在 `\@@_boundary_reserve_space:` 阶段抢先决定；该阶段真正需要保留的是供后续恢复链读取的边界标记。

当前实现为此前侧 ecglue 恢复增加了“缓存值”这一层状态：

- 在 `\@@_boundary_group_end:n`，也就是 CJK→Boundary 过渡时，先把当时正确 CJK 字体上下文中的 `\CJKecglue` 缓存到 `\l_@@_ecglue_skip`。
- 后续所有前侧边界恢复路径统一使用这个缓存 skip，而不再在恢复点重新测量 `\CJKecglue`。
- 这样即使 Boundary 区间内部出现局部字体切换，真正恢复出来的 ecglue 仍保持离开 CJK 区域时的度量。

这个设计刻意选择“CJK→Boundary 时缓存”，而不是初始化时缓存或每个字符都缓存：初始化时拿到的值会随着后续字体/字号切换而过期；每字符缓存则频率过高、状态复杂度也更大。CJK→Boundary 正好是离开正确 CJK 字体上下文前的最后稳定时机，既保证度量正确，也把缓存成本限制在边界级别。

因此，修复后的 xeCJK interchar 状态机应整体理解为：

1. 用 `\lastkern` 标记 kern 判定上一边界类型；
2. 若被 whatsit 打断，则通过 `\lastnodetype` 与保存的节点类型走回退路径；`\reset@color` 的定点补丁在 color-pop whatsit 后重建标记 kern 并设置 boolean；
3. 若需要恢复前侧 ecglue，则不在恢复点重新展开 `\CJKecglue`，而是使用先前在 CJK→Boundary 时缓存的 `\l_@@_ecglue_skip`；
4. 若上一节点是 glue，则通过 `\@@_check_for_glue_skip:` 判断 glue 性质，分两条路径：kern 路径（boolean 门控）移除 finite glue 后探测下方 kern pair 标记；hlist 路径（不依赖 boolean）通过 `\g_@@_last_node_tl` 穿透 hbox 判断 CJK 内容类型。fil 级 glue 和无 shrink 的 `\quad` 在前置检查中直接跳过。
5. 在 fntef 子系统中，`\g_@@_last_node_tl` 的全局状态隔离有两个方向：
   - fntef(color)：fntef 包裹 textcolor 时，`\xeCJK_fntef_sbox:n` 的 `\hbox_set:Nn` 内 interchar toks 全局修改该状态——修复为 hbox 前后保存/恢复。
   - color(fntef)：textcolor 包裹 ulem 类 fntef 命令时，ulem `\UL@end` 的 `*` 字符触发 Default→Boundary interchar 转换污染该状态——修复为 `\xeCJK_ulem_right:` / `\__xeCJK_ulem_end:` 前后 save/restore（#830）。

也就是说，#315 解决的是”边界恢复判定链会被 whatsit 打断”，#252 / #476 解决的是”边界恢复时重新测量 ecglue 会拿错字体度量”，#324 解决的是”宏路径中的 `\@@_boundary_reserve_space:` 额外输出 glue，先把 `CJK-space` 标记自身遮蔽掉”，#826 解决的是”xeCJKfntef 命令右侧的 inter-word space glue 叠在 kern pair 标记上方导致 CJKglue 恢复失败”，#831 进一步解决了显式 `}`、`\textcolor` color-pop whatsit、`\mbox` hbox 三种 glue-on-kern-pair 变体，五者共同构成当前 xeCJK 边界恢复机制的完整心智模型。

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
