## [ctex-v2.6.4](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.6.4)

- `macnew` 的宋体常规直立字形改用 Songti SC Regular（#994）。

## [ctex-v2.6.3](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.6.3)

- 禁止在 LuaTeX 后端载入不兼容的 `CJKfntef`，并推荐使用 `lua-ul`（#381）。
- 提供按层级查询标题编号、完整标签和编号开关的接口，使 Beamer 主题作者可以通过公开接口读取并响应 CTeX 本地化编号设置，而无需访问私有变量（#275）。
- 说明保留零段首缩进的兼容行为（#402）。
- 按宏包整理第三方兼容说明，并增加与 `babel`、`biblatex` 联用的内容（#986、#987）。

## [ctex-v2.6.2](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.6.2)

- `ubuntu` 字库新增仿宋配置和 `\fangsong` 命令。使用 XeLaTeX 或 LuaLaTeX 编译时，按朱雀仿宋、FandolFang、思源宋体的顺序自动选用（#908）。
- 订正 `ctex-heading-*.def` 中 `\ProvidesExplFile` 使用与实际文件名不匹配的 `ctex-*.def`。
- 将单一 `ctex.dtx` 拆分为 `ctex.dtx`（安装脚本与用户文档）与 `ctex-kernel.dtx`、 `ctex-engine.dtx`、`ctex-scheme.dtx`、`ctex-auxpkg.dtx`、 `ctex-fontset.dtx` 六个源文件，由夏明宇完成重构（#937）。
- 文档字体启用 `Language` 与 `PoZheHaoLigature`，破折号按全角字形合字输出（#382）。
- 文档等宽字体改用朱雀仿宋，意大利体改用霞鹜文楷 GB Lite（#908）。

## [ctex-v2.6.1](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.6.1)

- 补全字库选项 `windows` 的 pdfTeX 分支中， `\ctex_zhmap_case:nnn` 的第三个子分支 `zhmap = false` 缺失的报错。

## [ctex-v2.6.0](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.6.0)

- 替换废弃命令 `\char_to_utfviii_bytes:n`。
- 修复参数签名，`\@@_char_auxi:NNNN` 原误为 `NNN`。
- 4 字节 UTF-8 字符也优先使用 `\DeclareUnicodeCharacter` 的定义（#815）。
- **Breaking:** `\newCJKfontfamily` 定义的字体切换命令改为局部定义，与 `\newcommand` 行为一致。在分组内调用时，命令不再泄漏到分组外（#751）。
- 修复内联 `\verb` 前 `xkanjiskip` 丢失的问题（移植 `lltjcore` 对 `\verb` 和 `\do@noligs` 的修复）。
- **Breaking:** 移除对 LaTeX 2020/10/01 之前版本的字体钩子兼容代码。现在需要 LaTeX 2020/10/01 或更新版本（#746）。
- 修复 `hyperref` 在 `ctex` 之前被加载时 `driverfallback` 选项重复设置的警告（#715）。
- 新增实验性 `experiment/CJKecglue` 选项（#717）。
- `macnew` 增加 macOS 15+ 兼容，字体运行时检测。
- 修复了 TeX tree 字体无法制作 `.spa` 文件的问题。
- 补全 upLaTeX 字体编码 JY2 和 JT2 的 Fallback 机制。
- 提升 LaTeX3 版本至 2022/10/09。
- 提升 LaTeX3 最低版本要求至 2025/10/09。
- 使用 `\l_keys_key_str` 和 `\l_keys_choice_str` 替代已废弃的 `\_tl` 版本（#806）。
- 新增实验性 `experiment/font-size-system` 选项（#543）。
- 将 `experiment/font-size-system` 的 `traditional` 选项更名为 `letterpress`（#813）。
- 文档：在标准字体命令、中文字号表附近提示 `experiment/font-size-system` 的影响；说明 `letterpress` 只是金属活字排印字号体系之一（#871）。
- 文档字体统一为 Noto CJK 系列（#686）。
- 文档说明 `runin` 与 `aftertitle` 的交互（#574）。

## [ctex-v2.5.10](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.10)

- 使用封装好的函数。
- 取消 LaTeX 2022-06-01 对书名号的定义。
- 解决 `CJK` 包与 `\text_uppercase:n` 等转化函数的冲突。
- 更新一些内部函数。
- 不直接依赖 `xparse` 和 `l3keys2e`。
- 展开传递 `pagestyle` 的值。

## [ctex-v2.5.9](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.9)

- 依赖 `chinese-jfm` 宏包。
- 设置消息模块的名字和类型。

## [ctex-v2.5.8](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.8)

- 兼容 LaTeX 2021/11/15。
- 简化部分 `Lua` 函数。
- 兼容 `microtype`。
- 兼容 `titlesec` 包和 `\CTEXifname`。

## [ctex-v2.5.7](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.7)

- 重新应用 `l3cctab`。
- 使用 `\disable@package@load` 禁止宏包载入。
- 更好地兼容 `cmap` 包。
- 确保 cmap 文件存在。
- 应用 `\pdfnobuiltintounicode`。
- 禁用 驱动的 `unicode` 书签设置。
- 兼容 LaTeX 2021/06/01 的字体钩子。
- 同时兼容 `cleveref` 和 `beamer`。

## [ctex-v2.5.6](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.6)

- 使用正确的导言区末尾钩子。
- 更新 `fancyhdr` 宏包的补丁。

## [ctex-v2.5.5](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.5)

- 不再通过旧的钩子命令来定义。
- 进一步应用 LaTeX 2020/10/01 的新钩子。
- 放弃应用 `l3cctab`。

## [ctex-v2.5.4](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.4)

- 兼容 LaTeX 2020/10/01 的钩子机制。
- 更新 `LuaTeX-ja` 支持（20200808.0）。
- 修正主要字体命令补丁。
- 应用 `l3cctab`。
- 同时兼容 `cleveref` 和 `hyperref`。

## [ctex-v2.5.3](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.3)

- 不再依赖 `xunicode`，单独补丁 `tuenc.def`。
- 正确关闭和恢复 LaTeX3 语法环境。
- 兼容 `cleveref`。

## [ctex-v2.5.2](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.2)

- 兼容 LaTeX 2020-02-02 之前的版本。
- 修正 `macnew` 和 `ubuntu` 字库的 `CJKpunct` 标点信息。
- `zhadobefonts.tex` 等字体映射文件更名为 `ctex-zhmap-*.tex`。
- `ctexmakespa.tex` 更名为 `ctex-spa-make.tex`。
- `ctexspamacro.tex` 更名为 `ctex-spa-macro.tex`。
- 新增标题选项 `secnumdepth` 和 `tocdepth`。

## [ctex-v2.5.1](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5.1)

- `zhconv` 更名为 `ctex-zhconv`。

## [ctex-v2.5](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.5)

- 增加宏包开头钩子。
- 给 LaTeX 和 upLaTeX 下的文档类指定驱动为 。
- 更新 `LuaTeX-ja` 支持（20200412.0）。
- 删除 `fontspec` 补丁。
- 重构字体选项 `AlternateFont`。
- 操作系统检测移动至载入中文字库处，且不再需要依赖特定引擎。
- 不再自动载入 `CJKfntef` 或 `xeCJKfntef` 宏包。
- 移除 `\CTEXunderdot`、`\CTEXunderline`、 `\CTEXunderdblline`、`\CTEXunderwave`、`\CTEXsout`、`\CTEXxout`、 `CTEXfilltwosides` 等命令和环境。
- 兼容 `KOMA-Script` 的 `\selectfont` 补丁。
- 为 `macnew` 增加粗楷体、隶书和圆体的定义。
- 允许 `macnew` 在 LaTeX 和 upLaTeX 下使用。
- `ubuntu` 改用思源（Noto CJK）和文鼎字库，不再支持使用 pdfLaTeX 编译。
- 使用环境变量代替绝对路径查找字体。
- 不再支持 Windows XP 系统，`windowsold` 和 `windowsnew` 成为过时字库选项。
- 增加字体映射文件 `zhmacfonts.tex`。
- 处理 `\ctex_file_input:n` 在 `ctexsize` 中未定义的错误。
- 在 `ctexsize` 也载入 `fix-cm`。
- 所有引擎下默认编码均设为 UTF-8。
- 仅在该选项启用时会载入 `CJKfntef` 或 `xeCJKfntef` 宏包。
- 重构标题选项 `indent` 和 `hang`。
- 标题选项 `format` 也可以接受参数。
- 兼容 `titletoc` 宏包。
- 应用新内核中的 `\labelformat`。
- 改用 `/System/Library/Fonts/Menlo.ttc` 为特征文件。

## [ctex-v2.4.16](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.16)

- 允许设置 `autoindent` 为 $0$。
- 修正 `part/indent` 和 `chapter/indent` 的实现方法，在其标题内部禁用 `autoindent`。
- 更好地兼容 `nameref` 宏包。

## [ctex-v2.4.15](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.15)

- 显式补丁 upLaTeX 的 `\rmfamily` 等字体命令。
- 将 upLaTeX 的默认字体由 `mc` 改为 `zhrm`，并启用 `\jfam`。
- 统一“方正细黑一\_GBK”的名称为 `FZXiHeiI-Z08`。
- 将 `JY2` 和 `JT2` 编码的字体定义提取到单独的文件中。
- 修正 `part/indent` 和 `chapter/indent` 的实现方法。
- 定义 `part/hang` 和 `chapter/hang`。
- 局部指定 `autoindent` 为 `false`，并交换 `\CTEX@XXX@indent` 与 `\CTEX@XXX@format` 的顺序。
- 同步 LaTeX3 2019/03/05。

## [ctex-v2.4.14](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.14)

- 区分 `macold` 及 `macnew`。
- 配置 `macnew` 的默认字体设置。
- 为 `macnew` 配置字体命令。

## [ctex-v2.4.13](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.13)

- 修正导言区 `\selectfont` 钩子位置。

## [ctex-v2.4.12](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.12)

- 正确使用 `\ltjsetkanjiskip` 和 `\ltjsetxkanjiskip`。
- 修正 `\ctexset` 在 `ctexheading` 包中无定义的错误（曾祥东）。
- 不依赖 `\ifincsname`。
- 同步 LaTeX3 2017/12/16。

## [ctex-v2.4.11](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.11)

- 不把 Enclosed Alphanumerics 设置为 JAchar。
- 不把希腊和西里尔字母设置为 JAchar。
- 因上游 `l3keys` 变化，重新定义 `format+` 等带空格加号的选项。
- 补充页眉空格。

## [ctex-v2.4.10](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.10)

- 定义 `\cht`，`\cdp` 和 `\cwd`。
- 常数 `\c_minus_one` 已过时。
- 使用 `lazy` 函数对 Boolean 表达式进行最小化运算（LaTeX3 2017/07/19）。

## [ctex-v2.4.9](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.9)

- 调整 `unicode-math` 补丁的代码顺序。

## [ctex-v2.4.8](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.8)

- 解决与 `fontspec` 2017/01/24 v2.5d 的字体族匹配兼容问题。

## [ctex-v2.4.7](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.7)

- 依赖 `pxeverysel` 宏包。
- 修复 `ctexrep` 类的 `\chaptermark` 汉化错误。

## [ctex-v2.4.6](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.6)

- 支持字体属性可选项在后的新语法。
- `\CTEXifname` 初始为假。
- 重新初始化 `\ifthechapter` 等。

## [ctex-v2.4.5](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.5)

- 新的标题格式选项 `hang`。
- 新的标题格式选项 `tocline`。
- 新的标题格式选项 `chapter/lofskip` 和 `chapter/lotskip`。
- 修复补丁失败。

## [ctex-v2.4.4](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.4)

- 解决 `zhmap` 文件的 `\catcode` 问题。
- 不再默认设置 `xeCJK` 的伪粗体。
- 新的标题格式选项 `break`。
- 提供 `\partmark`。
- 提供 `\CTEXifname`。
- 改进 `hyperref` 宏包的标题锚点设置。
- 使用 `titlesec` 时，章节目录也使用 的编号。

## [ctex-v2.4.3](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.3)

- 简化 `fontspec` 补丁。
- 更新 `unicode-math` 补丁。
- 确保 `\proofname` 非空。
- 新的标题格式选项 `fixskip`。
- 删除选项 `part/fixbeforeskip` 和 `chapter/fixbeforeskip`。

## [ctex-v2.4.2](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.2)

- 恢复 `luatexja` 对 `\emshape` 和 `\eminnershape` 的重定义。
- 兼容 upLaTeX 2016/05/07u00 的定义。

## [ctex-v2.4.1](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4.1)

- 正确更新 upLaTeX 的 `\CJKfamilydefault`。
- 正确设置 upTeX 下的 `\ccwd`。
- 随字体更新 upTeX 的 `\xkanjiskip`。
- 使用 `bootfont.bin` 判断 Windows XP 以避免权限问题。
- 不允许无参 `zihao` 选项。
- 支持 `\pagenumbering`。
- 新的标题格式选项 `part/fixbeforeskip` 和 `chapter/fixbeforeskip`。
- `beamer` 不调整默认字体大小。
- `beamer` 不调整默认行距。

## [ctex-v2.4](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.4)

- 提供 `translator` 宏包的中文定理名称翻译。
- 修复宏名解析错误。
- 初步支持 upLaTeX 。
- 正确设置 upTeX 下字体命令。
- 正确更新 `CJK` 包的 `\CJKfamilydefault`。
- 提供 upLaTeX 的 NFSS 字体定义。
- 加强 `beamer` 宏包支持。

## [ctex-v2.3](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.3)

- 更新 `LuaTeX-ja` 支持（20150922.0）。
- 更新 `unicode-math` 宏包补丁。
- 与 LaTeX3 (2015/12/20) 同步。
- 代码实现避免使用 `\lowercase` 技巧（Joseph Wright）。
- `.value_required:` 和 `.value_forbidden:` 已过时。
- 修复 `nameformat` 作用域问题。
- 兼容 `titleps` 宏包。

## [ctex-v2.2](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.2)

- 将文档开头和宏包末尾钩子提取到 `ctexhook` 宏包中。
- 新增子宏包 `ctexpatch` 实现给宏打补丁功能。
- 给 `enumitem` 宏包注册 `\chinese` 和 `\zhnum`。
- 新的标题格式选项 `numbering`。
- `beforeskip` 和 `afterskip` 选项的符号不再有特殊意义。
- 新的标题格式选项 `afterindent`。
- 新的标题格式选项 `runin`。
- `beforeskip`、`afterskip` 和 `indent` 选项支持表达式。
- 非 `ctexart` 类的 `part/beforeskip` 和 `part/afterskip` 选项有意义。
- 删去 `etoolbox` 与 `breqn` 的兼容补丁。
- 将中文版式下的 `part` 和 `chapter` 标题的 `nameformat` 和 `titleformat` 选项的初值合并到 `format` 中。
- 不再依赖 `etoolbox` 宏包。

## [ctex-v2.1](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.1)

- 给 pdfLaTeX 下的非 UTF-8 编码 CJK 字体族加上 CMap。
- 不依赖 `ifpdf` 宏包。
- 补充定义 `\hypersetup`。
- 不再设置 `hyperref` 宏包的 `colorlinks` 选项。
- `nameformat` 可以接受章节名字为参数。
- `format+`, `nameformat+` 等带加号的选项，加号与前面的文字之间可以有可选的空格。
- 新的标题格式选项 `aftertitle`。
- 改用 `/Library/Fonts/Songti.ttc` 为特征文件。
- 修复 `ctexbook` 和 `ctexrep` 类的中文 `part/number` 选项初值为空的错误。
- 将章节标题设置功能提取到可以独立使用的宏包 `ctexheading` 中。

## [ctex-v2.0.2](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.0.2)

- 修复加载 `ctex` 宏包后章节标题后第一段无段首缩进的问题。

## [ctex-v2.0.1](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.0.1)

- 修复 `10pt`、`11pt` 等选项无效的问题。

## [ctex-v2.0](https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.0)

- 解决与 `\nouppercase` 的冲突。
- 通过 `LuaTeX-ja` 宏包支持 LuaLaTeX 。
- 自动检测操作系统，载入对应的字体配置。
- 默认关闭 `CJKfntef` 或 `xeCJKfntef` 的彩色设置。
- `\CTEXunderdot`、`\CTEXunderline`、 `\CTEXunderdblline`、`\CTEXunderwave`、`\CTEXsout`、`\CTEXxout` 是过时命令；`CTEXfilltwosides` 是过时环境。
- 新增 `zihao` 选项。
- `c5size`, `cs4size` 是过时选项。
- 新增 `linespread` 选项。
- 新增 `autoindent` 选项。
- `indent`, `noindent` 是过时选项。
- 新增 `fontset` 选项。
- `nofonts`, `adobefonts`, `winfonts` 是过时选项。
- 新增 `zhmCJK` 支持选项。
- `nozhmap` 是过时选项。
- `punct` 选项可以设置标点格式。
- `nopunct` 是过时选项。
- `nospace` 是过时选项。
- `ctex` 宏包新增 `heading` 选项。
- 新增 `scheme` 选项，并将 `cap` 和 `nocap` 列为过时选项。
- `hyperref` 成为过时选项，原选项功能总是打开。
- `fancyhdr` 成为过时选项，原选项功能总是打开。
- `fntef` 成为过时选项，原选项功能总是打开。
- 兼容 `extsizes` 宏包、`beamer`、`memoir` 等提供的更多字号选项。
- 新增统一设置接口 `\ctexset`。
- `\CTEXsetup`, `\CTEXoptions` 是过时命令。
- 新增 `linestretch` 选项。
- `\CTEXindent`, `\CTEXnoindent` 是过时命令。
- 将标题汉化功能加入 `ctex.sty`。
- 标题设置新增 `pagestyle` 选项。
- 将中文字号功能提取到可以独立使用的 `ctexsize`。
- 中文字号不再采用近似值。
- 调整 `\footnotesep` 的大小，以适合行距的变化。
- `captiondelimiter` 是过时选项。
- 解决 `etoolbox` 与 `breqn` 关于 `\end` 的冲突。
- 应用 LaTeX3 重新整理代码。
- 删除 `c19gbsn.fd` 和 `c19gkai.fd`。
