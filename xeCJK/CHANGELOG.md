## [xeCJK-v3.10.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.10.4)

- 提升版本号至 v3.10.4。
- 在用户手册说明显式 glue 与源码空格的歧义窗口及零宽 `\kern` workaround（#992）。
- 手册歧义窗口说明扩展到 Boundary→CJK 方向：与词间空格同构的显式 glue 也可能被替换为 `CJKglue`（#996）。
- 允许 Boundary 到 Default 的恢复路径暂时移除末尾不含无限阶伸缩、且有收缩量的源码词间 glue；若其下方确有 CJK marker，则将其替换为 `\CJKecglue`，补齐与 Default 到 CJK 方向对称的命令边界处理（#992）。
- 新增 `\@@_glue_check_expire_stale:`：顶层恢复链在空列表上探测时结束过期的 pending 门控，阻止 `\g_@@_glue_check_pending_bool` 跨 `\hbox`/`\setbox` 存活（#996）。
- 由命令边界 framework 接管 `xeCJKfntef`、盒命令和颜色命令，删除按全局 tl 猜测 hlist/whatsit 下方类别的旧回退；glue 分支现在只接受紧邻的可信 marker（#992）。
- Boundary 到 CJK 的源码空格候选校验升级为与 Default 方向同款的 `\@@_skip_if_interword:N` 谓词，自然宽度不等于当前词间空格的显式 glue 不再被替换为 `\CJKglue`（#996）。
- 删除颜色专用 pending boolean；颜色 push/pop 和盒输出改由 transparent/wrapped-box capture 处理（#992）。
- 新增命令边界 capture/register 框架，按实际可见输出的首尾类别统一处理盒子、不透明节点流和无可见输出命令（#992）。
- box/wrapped-box 捕获在盒子有可见墨迹（宽度非零、高度或深度非零、尾节点为现场排版的 char/rule/math/kern）而未观察到任何字符类别时，按 Default 首尾重建边界；math 与 `\vrule` 等不触发 interchar 转换的可见内容不再被误判为“无可见输出”，预排盒与空白占位盒保持透明（#998）。
- 包装内核私有 `\@imakebox` 与 `\@iframebox` 的 `[#1][#2]#3` 签名以注册 `\makebox` / `\framebox`；内核若调整该签名须同步此 wrapper（#992）。
- 把链接 annotation 的入口保存和末尾定点重放迁移到统一 stream capture，按链接实际首尾可见类别恢复两侧边界（#992）。
- 将 `\set@color` 与 `\reset@color` 注册为 transparent capture，删除颜色 push/pop 的专用 marker save/replay 分支（#992）。
- 将 `l3color` 的颜色 push/pop 入口注册为 transparent capture，删除对应专用 marker 保护分支（#992）。
- 把 `\HD@target` 迁移到统一 transparent capture，同时恢复其前后的 marker 与源码空格状态（#992）。
- 新增 `siunitx` 兼容：`\unit`、`\qty`、`\num` 与 v2 旧名 `\si`、`\SI` 注册为固定 Default 首尾的 stream capture，修复 CJK 上下文中单位命令边界的空格丢失（#1000）。
- 用固定 Default 首尾的 stream capture 包围 `\Url@z` 的完整格式化阶段，删除 #880 的专用 drain（#992）。
- 把 `\verb` 从假定西文输出的入口 drain 迁移到统一 stream capture，按 verbatim 实际首尾类别恢复两侧边界（#992）。
- 将 `\eqref` 注册为固定 Default 首尾、将 `\cs` 注册为仅固定 Default 首端的 stream capture； codedoc/doc 的 meta 内部适配器直接包围固定 Default stream，删除专用 drain 并覆盖其所有公共调用方（#992）。
- 将内核 `\@setref`（或 `hyperref` 保存的 `\real@setref`）注册为 auto stream capture，以统一框架取代 #991 的专用 saved-node/replay 补丁。
- 把 `\blx@pagetracker` 从单向清空状态改为 transparent capture，使 write whatsit 对两侧实际可见边界透明（#992）。
- 将 xeCJKfntef 线型命令、原生 `ulem` 入口（如 `\uline`）、`\xeCJKfntefon` 与独立符号命令接入 stream capture，并让内部 pending 通过 framework 的统一辅助函数发布；删除 fntef 专用末状态恢复和 pending 设置（#992）。
- 让嵌套的 `ulem`/xeCJKfntef 线型命令只由最外层启动 stream capture，修复 capture 栈逐次累积的状态泄漏（#992）。
- 改用 framework 的可嵌套暂停区隔离装饰符号测量盒，同时保存、恢复 marker 与 pending 状态（#992）。
- 将 `\lstinline` 的分隔符、活动字符和花括号扫描路径接入 auto stream capture，使颜色切换前后的四种源码空格组合都与直接输入一致（#992）。

## [xeCJK-v3.10.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.10.3)

- 提升版本号至 v3.10.3。
- 新增 `enabled-left-right-kerning` 标点格式选项（#975）。
- 将朝鲜文字母分为 L/V/T 三类，在音节内保持 shaping，在相邻音节间恢复 `\CJKglue`（#158）。
- 新增 `CJStarter` 类和可选严格行首禁则，保持小假名的普通 CJK 字距（#165）。
- 新增 `CJLineBreak` 选项，为日文小假名提供可选严格行首禁则（#165）。
- 全角格式启用相邻标点边界优化，并保留左标点后接右标点的自然空白（#975）。
- 开明式句末点号的宽度由 `0.8em` 改为全角（#975）。
- 在顶层 `\Hy@EndAnnot` 结束前检测 URL 的数学节点，并在链接结束 whatsit 后放置可信的西文边界标记，修复 `\url` 右侧的 `CJKecglue` 丢失问题（#972）。
- 使用 `\cleaders` 使下划线相对正文居中，避免起始位置改变时产生水平偏移（#531）。
- 使用 `\xleaders` 使波浪线相对正文对齐，同时保持字间连接连续（#967）。
- 使用 `\cleaders` 使双下划线相对正文居中（#967）。
- 使用 `\cleaders` 使删除线相对正文居中（#967）。
- 使用 `\cleaders` 使斜删除线相对正文居中（#967）。
- 使用 `\cleaders` 使自定义线相对正文居中（#967）。

## [xeCJK-v3.10.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.10.2)

- 文档字体启用 `Language` 与 `PoZheHaoLigature`，破折号按全角字形合字输出（#382）。
- 文档等宽字体改用朱雀仿宋，意大利体改用霞鹜文楷 GB Lite（#908）。
- 提升版本号至 v3.10.2。
- 增加 `PoZheHao` 字符类，支持字体的破折号合字功能（#382）。
- 重置后恢复 `PoZheHaoLigature` 的设置（#382）。
- 重置后恢复 `LatinPunct` 的设置（#389）。
- 长标点与其他标点之间折行时检查断点两侧的禁则：左标点不得悬于行尾，右标点与 `NoBreakLongPunct` 不得落于行首（#456）。
- 新增 `PoZheHaoLigature` 选项，支持字体的破折号合字功能（#382）。
- 新增 `LatinPunct` 选项，中西文共用的弯引号、间隔号与省略号可以切换为西文标点（#389、#431）。
- `PoZheHao` 类字符同样按全角右标点处理（#382）。
- 破折号中间的压缩量改为多路取大，保证两个 `U+2014` 的总宽不超过两个汉字宽（#382）。
- 新增判断，配合破折号占两个汉字宽的空白补偿（#382）。
- 未启用合字的破折号两端各补偿一整份空白，保证连用的破折号占两个汉字宽（#382）。
- `\verb` 组关闭时用 `\setlanguage` 主动排出 language whatsit，修复 `\verb` 右侧源码空格场景下 `CJKecglue` 双倍的问题（#919）。
- 为 `doc` 的 `\meta` 添加补丁，将参数内容包入 `\hbox:n`，修复 `\meta` 内首字符前出现多余 `CJKecglue` 的问题（#951）。

## [xeCJK-v3.10.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.10.1)

- 提升版本号至 v3.10.1。
- 为 LaTeX 核心命令 `\verb` 添加补丁，在进入 verb 内容前 drain 缓存的 `CJKecglue`，修复 CJK 文字与 `\verb`（或 `shortvrb` 的短记号）之间间距丢失的问题（#910）。
- 为 `l3doc` 的 `\__codedoc_meta:n` 添加补丁，将参数内容包入 `\hbox:n`，修复 `\meta` 内首字符前出现多余 `CJKecglue` 的问题（#920）。
- 为 `biblatex` 的 `\blx@pagetracker` 添加补丁，清空 `\g_@@_last_node_tl`，修复中文参考文献条目首字符前出现多余 `CJKecglue` 的问题（#931）。

## [xeCJK-v3.10.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.10.0)

- 提升版本号至 v3.10.0。
- 文档字体从 Source Han Serif 统一为 Noto Serif CJK（#686）。
- 修复 `\textcolor` 包裹 `ulem` 类下划线命令时 CJK 字间距异常的问题（#830）。
- 提升 LaTeX3 最低版本要求至 2025/10/09。
- 将全角浪线等连接号从 `MiddlePunct` 改为 `LongPunct`，消除不必要的标点压缩间距。
- 同步 Unicode 15.0。
- 同步 Unicode 15.1。
- 同步 Unicode 17.0。
- 移除通用 whatsit 恢复，避免 `hyperref` 链接注释等 whatsit 节点导致 `CJKecglue` 在错误位置插入（#803）。配合 `\set@color` 定点补丁保持 `\textcolor` 场景的正确性（#315）。
- 新增 glue 分支处理，修复 `xeCJKfntef` 命令右侧空格问题。
- 当 glue 下方是 hlist（`\mbox` 等命令产生的 hbox）时，不依赖 boolean，直接通过 `\g_@@_last_node_tl` 判断前方内容类型，修复 `\mbox`、`\colorbox` 等 hbox 命令右侧多余 inter-word glue（#831）。
- 修复 `xCJKecglue` 错误。
- 修复 `\xeCJKnobreak` 错误。
- 修复 `\textcolor` 等 whatsit 节点导致 `CJKecglue` 丢失的问题。
- 修复字体切换组（如 `\texttt`、`\zihao`）导致 `CJKecglue` 使用错误字体度量的问题。
- 改正拼写错误 `\@@_glue_node:n`。
- 新增 `\g_@@_glue_check_pending_bool` 用于标记 `xeCJKfntef` 组结束后的首次 glue 探测。
- 新增 `\g_@@_reset_color_pending_bool` 用于标记 `\reset@color` 在 hlist 上下文中触发，延迟到 `\@@_check_for_glue_skip:` 中处理 `\colorbox` 等命令右侧的 color pop whatsit（#831）。
- 修复 CJK 字符后行尾空格在宏命令前未被消除的问题，不再立即输出空格 glue，改为只留标记由后续恢复路径决定间距（#324）。
- 当显式 `}` 触发 CJK→Boundary 转换时，设置 `\g_@@_glue_check_pending_bool` 以启用后续的 glue 检查，修复 `前{中} 后` 类型排版中多余的 `\CJKecglue`（#831）。
- 新增实验性 `experiment/halfright-prebreakpenalty` 选项（#811）。
- 修复 `tabular` 中 `\unskip` 吞掉标点补偿 glue 的问题（#827）。
- 新增 `experiment/punct-measure-fix` 选项：段落模式下通过 para/end 钩子恢复被 `\unskip` 移除的标点补偿 glue（#859）。
- `NoBreakLongPunct` 在右侧时禁止折行。
- 新增 `NoBreakLongPunct` 属性，禁止在省略号等长标点前断行。
- **Breaking:** `\newCJKfontfamily` 定义的字体切换命令改为局部定义，与 `\newcommand` 行为一致。在分组内调用时，命令不再泄漏到分组外（#751）。
- **Deprecated:** `\xeCJKsetcharclass` 已弃用，调用时报错并提示改用 `\xeCJKDeclareCharClass`（#709）。
- **Breaking:** 移除对 LaTeX2e 2020/10/01 之前版本的字体钩子兼容代码（#746）。
- 在 `\Pifont` 中先进入水平模式，防止 `\makexeCJKinactive` 在垂直模式下通过分页泄漏到输出例程（#688）。
- 新增 `\xeCJKchar`，绕过 interchar 机制（#407）。
- 撤回对 `\char` 的重定义，改为提供 `\xeCJKchar` 新命令，避免破坏依赖 `\let` 保存 `\char` 原语的宏包（#800）。
- 为 `mtpro2` 提供兼容补丁，使大花括号内部的 `\char` 不被 interchar 拦截（#407）。
- 通过在 `\Hy@BeginAnnot` 中保存并选择性恢复 xeCJK 节点标记，同时清除旧标记，解决目录中链接注释起始处的虚假 `ecglue`（#810），并为 `\ref` 提供前侧 `ecglue`（#809）。
- 为 `color`/`xcolor` 添加兼容补丁，在颜色切换 whatsit 后重放 xeCJK 节点标记，修复 `\textcolor` 后 `CJKecglue` 丢失的问题（#315, #803）。
- 修复 `\set@color` 补丁在无真实节点标记时未清除全局状态，导致首次 `\textcolor` 在标点或段首后插入虚假 `ecglue` 的问题（#807）。
- 补丁 `\reset@color` 以在颜色弹出 whatsit 之后重新放置 xeCJK 节点标记，修复 `\textcolor` 命令右侧多余 inter-word glue 的问题（#831）。
- `\reset@color` 补丁增加 hlist 回退路径，当 color pop 后最后节点为 hlist 时设置 `\g_@@_reset_color_pending_bool`，延迟到 `\@@_check_for_glue_skip:` 中处理 `\colorbox` 等命令右侧间距（#831）。
- 修复颜色补丁在 `\g_@@_last_node_tl` 被无关的 `\set@color` 清空后仍尝试重放节点导致 `Missing number` 错误的问题，影响 `listings` 与 `\rulecolor` 组合（#836）。
- 使用 `\l_keys_key_str` 和 `\l_keys_choice_str` 替代已废弃的 `\_tl` 版本（#806）。
- 补丁 `l3color` 后端的 `\__color_select:N` 和 `\__color_backend_reset:`，使 `l3color` 接口的颜色切换也能正确保持 xeCJK 间距（#832）。
- 为 `hypdoc` 的 `\HD@target` 添加补丁，在它产生的 hbox 之后重放 xeCJK 节点标记，修复 `l3doc` 中 `\cs`、`\meta` 等命令后 `CJKecglue` 丢失或保留为原始空格的问题（#873）。
- 为 `url` 的 `\Url@FormatString` 添加补丁，在进入数学模式前 drain 缓存的 `CJKecglue`，修复 CJK 文字与 `\url` 命令之间间距丢失的问题（#880）。
- 在下划线内 CJK 分组切换时保存/恢复字体状态（#465）。
- 保存并恢复 `\g_@@_last_node_tl`，避免 hbox 内渲染装饰符号时 interchar toks 污染全局节点标记，修复 `xeCJKfntef` 与 `\textcolor` 组合使用时多余的 `CJKecglue`。
- 移除 `\ignorespaces`，修复命令后空格丢失（#465）。
- 在独立模式的末尾设置 `\g_@@_glue_check_pending_bool`，修复 `\CJKunderdot` 等命令右侧空格问题（#826）。
- 修复在 `\lstinline` 参数中使用非 `#` 的 catcode 6 字符（如 ``\catcode`\&=6``）时输出错字的问题（#879）。
- 修复 `\textsbleftarrow` 的定义。
- 修复拼错的命令名， `\cyreref` $\to$ `\cyrerev` 和 `\textDiamandSolid` $\to$ `\textDiamondSolid`。
- 修复 `\textnleqslant` 的定义，修复 `\textnbacksim` 和 `\textnlessapprox` 定义里的自引。
- 修复组合符号 `U+04AA` 的定义。
- `xunicode-symbols.tex` 改为按 `Noto Sans Symbols 2`/`Symbola`/`Segoe UI Symbol`/`DejaVu Sans` 逐字符尝试的多级 fallback，缓解 Windows 等仅有 `Segoe UI Symbol` 时部分字符缺失的问题（#878）。

## [xeCJK-v3.9.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.9.1)

- 简化部分内部实现。
- 修复下划线中数学公式的错误处理。

## [xeCJK-v3.9.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.9.0)

- 不直接依赖 `xparse` 和 `l3keys2e`。
- 修复西文的 character protrusion 功能。

## [xeCJK-v3.8.9](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.9)

- 增加位于段首的支架盒子判断。
- 修正居中标点悬挂错误。

## [xeCJK-v3.8.8](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.8)

- 同步 Unicode 14.0。
- 补充女书。

## [xeCJK-v3.8.7](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.7)

- 应用 `\disable@package@load` 和 `\declare@file@substitution`。
- 将 `CJKfntef` 包替换为 `xeCJKfntef` 包。
- 更好地兼容 `CJKnumb`。

## [xeCJK-v3.8.6](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.6)

- 正确还原标点符号后的 penalty 状态。
- 兼容 LaTeX 2020/10/01 的 `NFSS` 钩子机制。

## [xeCJK-v3.8.5](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.5)

- 增加盒子高度判断。
- 进一步兼容 `microtype`。

## [xeCJK-v3.8.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.4)

- 不缓存 `\nullfont`。
- 重构后备字体的实现，修正标点符号无后备字体的问题。

## [xeCJK-v3.8.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.3)

- 删除 `\_nopar`。
- 依赖 `ctexhook` 宏包。
- 同步 Unicode 13.0。
- 补充 `U+02EA` 和 `U+02EB`。
- 修复 `xCJKecglue` 选项。
- 重构 `PunctStyle` 选项，完全展开参数。
- 兼容 `unicode-math` 和 `CJKmath` 选项。
- `hidden` 选项保留原内容的高度和深度。
- 取消 `xeCJKfntef` 的初始彩色设置。

## [xeCJK-v3.8.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.2)

- 修复分区字体错误。
- 避免导言区字体警告。

## [xeCJK-v3.8.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.1)

- 修复 `\l_xeCJK_current_font_tl` 标记错误。
- 应用 `\shapedefault`。

## [xeCJK-v3.8.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.8.0)

- 兼容 LaTeX2e 2020/02/02 对 `NFSS` 的修改。
- 清理过时的兼容性补丁代码。
- 应用 `\peek_remove_spaces:n`。
- 应用 `\fp_if_nan:nTF`。
- 更新可视空格补丁。
- 删除 `\hbar` 补丁。
- 删除 `\mathrm` 补丁。
- 删除 `realscripts` 补丁。
- 删除 `CJKfntef` 补丁。

## [xeCJK-v3.7.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.7.4)

- 简化行首/尾标点符号宽度的实现。

## [xeCJK-v3.7.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.7.3)

- 补充日文假名扩展。
- 修复 penalty 数值错误。

## [xeCJK-v3.7.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.7.2)

- 同步 LaTeX3 2019/03/05。
- 简化 `CJKspace` 的实现，并修复错误。
- 再次修正 FullLeft 类字符与西文连用断词失败的问题。
- 删除定义新字体族时过滤重复选项的功能。
- 修复补丁错误。
- 改用 `xparse` 的新参数类型 `b` 定义 `CJKfilltwosides*` 环境，不再依赖 `environ` 包。
- 解决与 `microtype` 宏包的兼容问题。

## [xeCJK-v3.7.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.7.1)

- 修复代码重构而引入的新错误。

## [xeCJK-v3.7.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.7.0)

- 修正长标点被隔开时的压缩处理错误。
- 不再默认引入 `xunicode` 宏包。
- 对 `\nobreakspace` 的恢复放到 `xunicode-addon` 中处理。
- 补充定义 `\texthyphenationpoint` 和 `\texttwoemdash`。

## [xeCJK-v3.6.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.6.1)

- 减少 `bool` 运算。
- 细化判断。

## [xeCJK-v3.6.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.6.0)

- 同步 LaTeX3 2017/12/16。
- 把 TWO-EM DASH (`U+2E3A`) 归入 `FullRight` 类和设为 `LongPunct` 与 `MiddlePunct`。
- 将全角浪线 `U+FF5E` 等连接号归入 `FullRight` 类和设为 `MiddlePunct`。
- 总允许长标点与其他标点之间折行。
- 解决标点中间被隔开的禁则与压缩问题。
- 修正标点同为 `LongPunct` 与 `MiddlePunct` 时的实现错误。
- `Default` 类与 `MiddlePunct` 之间不应该有 `\CJKglue`。
- 新增 `PunctFamily` 选项支持对汉字标点单独切换字体。

## [xeCJK-v3.5.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.5.1)

- 修正 fallback 字体后无法忽略空格的错误。

## [xeCJK-v3.5.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.5.0)

- 常数 `\c_minus_one` 已过时。
- 使用 `lazy` 函数对 Boolean 表达式进行最小化运算（LaTeX3 2017/07/19）。
- 补充 Ext-F。

## [xeCJK-v3.4.8](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.8)

- 转义 `\lstinline` 参数中的 $\backslash_{12}$。

## [xeCJK-v3.4.7](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.7)

- 简化 `CheckSingle` 的实现，不再展开宏。

## [xeCJK-v3.4.6](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.6)

- 将族名参数完全展开，以解决与 `fontspec` 2017/01/24 v2.5d 的兼容问题。

## [xeCJK-v3.4.5](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.5)

- 更新 LaTeX3 的过时用法。

## [xeCJK-v3.4.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.4)

- 不压缩长标点与其他标点的间距。

## [xeCJK-v3.4.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.3)

- 考虑破折号边界为负值的情况。
- 允许字体属性可选项在后的新语法。

## [xeCJK-v3.4.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.2)

- 提高效率，避免重复循环。
- 避免在破折号之间折行。

## [xeCJK-v3.4.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.1)

- 补充 Unicode 9.0 的西夏文。
- 修复 `CJKspace` 功能失效。
- 新的下划线选项 `textformat`。

## [xeCJK-v3.4.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.4.0)

- 改进 `xCJKecglue` 的实现。
- `RubberPunctSkip` 选项有新的值 `plus` 和 `minus`。
- 标点符号的压缩量能伸长到原始空白，能收缩到较小边距。
- CJKmath 的字符范围遵从 `\xeCJKDeclareCharClass` 的设置。
- CJKmath 功能也支持分区字体。

## [xeCJK-v3.3.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.3.4)

- 兼容 XeTeX 0.99994 的边界字符类。

## [xeCJK-v3.3.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.3.3)

- 更新 LaTeX3 代码。
- 兼容 LaTeX2e 2016/02/01 的字符类设置。
- 把 EN DASH（`U+2013`）作为半字线连接号归入 `FullRight` 类。
- 不再把 `U+2015` 和 `U+2500` 归入 `FullRight` 类。
- 补充 Ext-E。
- 解决与 `microtype` 宏包的兼容问题。
- 确保进入水平模式。
- 使用新的 Unicode 编码名称 `TU`。

## [xeCJK-v3.3.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.3.2)

- 随 Unicode 7.0 更新简繁汉字映射。
- `\xe@alloc@intercharclass` 总是有定义的。

## [xeCJK-v3.3.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.3.1)

- `0.99992` 版修复了 `\meaning` 的 Bug。
- `IVS` 字符类更名为 `CM`。
- 补充音调符号。
- 新选项 `WidowPenalty`。
- 补充可能遗漏的空格。
- 为方便 MacTeX 用户，Fandol 字体改用文件名。
- 兼容 LaTeX2e 2015。
- 删去 `fixltx2e` 和 `amsthm` 的冲突补丁。
- 应用 `0.99992` 版的新原语 `\Ucharcat`。
- 解决 `prebreak` 和 `postbreak` 功能失效的问题。
- 对 `listings` 的字符扩展不影响到其符号表中的七位或八位字符。

## [xeCJK-v3.3.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.3.0)

- 不把 `U+20A9` 归入 CJK 的 PR 类。
- 不把 NS 类中的一些有禁则的日文归入 `FullRight` 类。
- 不把小写日文假名归入 `FullRight` 类。

## [xeCJK-v3.2.16](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.16)

- 不再依赖 `everypage` 宏包。
- 整理 `xCJKecglue` 的部分代码。
- 修复 `\hbar`。

## [xeCJK-v3.2.15](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.15)

- 增加 `HangulJamo` 字符类。
- 把 REVERSE SOLIDUS（`U+005C`）、HYPHEN-MINUS（`U+002D`）和 EN DASH（`U+2013`）归入 `NormalSpace` 类。
- `xeCJKfntef` 增加 `hidden` 选项。
- 完善选项。
- 修正 `breaklines` 无效的问题。

## [xeCJK-v3.2.14](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.14)

- 完善 `\varCJKunderline` 的实现。
- 解决下划线前后没有 `\CJKglue` 或 `\CJKecglue` 的问题。
- `xeCJKfntef` 不再依赖 `CJKfntef`。

## [xeCJK-v3.2.13](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.13)

- 自动调整 `\CJKfamilydefault` 时，只将 `\familydefault` 展开一次。
- 修复参数类型错误。

## [xeCJK-v3.2.12](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.12)

- 新增 `RubberPunctSkip` 选项。
- 更新 `\int_to_Hex:n`。

## [xeCJK-v3.2.11](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.11)

- 不再使用内部名字。
- 左右角括号 `U+2329` 和 `U+232A` 是西文标点符号。
- 引入 `\CJK@family` 保存实际的字体族名。
- 放弃 `indentfirst` 和 `CJKnumber` 选项。
- 删除 `\xeCJKcaption`。

## [xeCJK-v3.2.10](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.10)

- 当没有设置字体时，使用 Fandol 字体系列。
- 使用 `CJKnumb` 时，让 `\Unicode` 有定义。
- 改进 `\t` 等的定义方式。
- 改进 `\sliding` 等的定义方式。
- 检查 `\t` 和 `\sliding` 的参数是否以 `\textipa` 开头。

## [xeCJK-v3.2.9](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.9)

- 完整处理 `encguide.pdf` 的编码符号表中，与旧编码的 `U+00B7` 冲突。
- 文档部分增加 `xunicode` 定义的符号表。
- 修正 `xunicode` 中的错误定义。
- 增加 `xunicode-extra.def` 中，用于加入 `puenc.def` 中的符号定义。

## [xeCJK-v3.2.8](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.8)

- 禁止在 `\verb` 中断行。
- 增加是否是等宽字体的判断。
- 修正 `\UseMathAsText` 的功能，恢复 `\hbar` 和增加以 `text` 打头的文本符号命令。
- 启用 `xunicode` 中的带圈数字和字母设置。

## [xeCJK-v3.2.7](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.7)

- 使用 `everypage` 往 `\shipout` 盒子里加钩子。
- 修正 `unicode-letters.tex` 中谚文符号 `\catcode` 不准的问题。
- 标点符号左/右空白的伸展值不超过原始边界，收缩值不小于另一侧边界。
- 处理 `AllowBreakBetweenPuncts` 与 `xeCJKfntef` 的兼容问题。
- 与 `\CJKspace` 兼容。
- 实现自定义行首/尾标点符号宽度功能。
- 标点宽度设置禁用比例选项的值改为 `nan`。
- 将 CJK 字符的数学归类由 $7$ 改为 $0$，解决汉字路径的问题。
- 使通过 `\UrlFont` 等命令设置的 CJK 字体生效。

## [xeCJK-v3.2.6](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.6)

- `case` 类函数的用法与 LaTeX3 同步。
- 更好的处理边界是 `\relax` 的情况。
- `AutoFakeBold` 和 `AutoFakeSlant` 选项直接使用 `fontspec` 的设置，修正不能调用相应实际字体的问题。
- 设置粗体时先检查对应字体是否存在。
- 为 `\mathrm` 减少一个可能的数学字体族。
- 考虑 `ulem` 对 `\MakeRobust` 的不当定义。
- 考虑 `\math` 和 `\ensuremath`。
- 可以指定特定符号命令使用的钩子。

## [xeCJK-v3.2.5](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.5)

- 修正 `CJK` 和 `NormalSpace` 字符类之间因为边界造成的间距不正确的问题。
- 细化全角左标点是否位于段首的判断。
- 增加对 `enumitem` 宏包修改的 `\item` 的判断。
- 微调定义。
- 禁止自动换行，与西文一致。
- 可视空格考虑传统 TeX 字体的情况。
- 解决汉字后紧跟 `\(...\)` 形式的行内数学公式时，不能加入间距的问题。
- 解决 `fixltx2e` 和 `amsthm` 的冲突。
- 恢复 `\nobreakspace` 的原始定义。
- 增加小宏包 `xunicode-addon`，为 `xunicode` 提供判断字符是否存在的功能。

## [xeCJK-v3.2.4](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.4)

- 遵循 LaTeX3 变量需要预先声明的原则。
- 去掉外层分组括号时，移除空格，避免死循环。
- 考虑 `charcode` 超出 BMP 的情况。
- 尽量移除用作判断标志的 `\kern`。
- 使用 `AllowBreakBetweenPuncts` 时，相应标点符号仍能与边界对齐。
- 细化边界与全角左标点之间是否压缩空白的判断。
- 解决使用 `CheckSingle` 时，某些 `\CJKglue` 不能被正确加入的问题。
- 使 `\CJKfamilydefault` 的 `FallBack` 设置全局可用。
- 内部调整分区字体的设置方法。
- 改进获取分区字体属性的办法。
- 可以单独增加当前各个分区字体的属性。
- 当计算得出的间距为负时，缩小 CJK 字体。
- 不再使用 `CJKnumber` 选项，可以在 `xeCJK` 之后直接使用 `CJKnumb` 宏包得到中文数字。
- 修正 `xeCJKfntef` 与 `natbib` 等的冲突。
- 改用 `minipage` 和 LaTeX 表格（`tabular`）来实现。
- 使 `listings` 的 `breaklines` 选项对 CJK 字符类可用，并保持标点符号的禁则。

## [xeCJK-v3.2.3](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.3)

- 提供四个 TECkit 映射文件用于句号转换和简繁互换。
- 根据 XeTeX 的脚本重新整理全角标点符号。
- 不再改变 CJK 字符类的 `\catcode`。
- 解决 `CheckSingle` 选项与 `tablists` 宏包的冲突。
- 新增 `\xeCJKOffVerbAddon` 用于局部取消 `\xeCJKOffVerbAddon` 的影响；并解决跨页使用时影响到页眉页脚的问题。
- 修正全角左标点后下划线与 `\CJKunderdot` 连用时结果不正常的问题。
- 解决 `\CJKunderdot` 跨页使用时影响到页眉页脚的问题。
- 完善对 `listings` 宏包的支持。
- 解决 `listings` 环境中代码行号输出不正确的问题，并解决在其中跨页时对页眉和页脚的影响。
- 在 `listings` 环境中对 `\charcode` 大于 $255$ 的字符根据其 `\catcode` 区分 `letter` 和 `other`。

## [xeCJK-v3.2.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.2)

- 修正某些重音不能正确显示的问题。
- 修正下划线不能跳过全角右标点的问题。
- 增加小宏包 `xeCJK-listings`，用于支持 `listings` 宏包。

## [xeCJK-v3.2.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.1)

- 调整 `Verb` 选项：在命令 `\verb` 里使用时，不破坏标点禁则，增加值 `env+`。

## [xeCJK-v3.2.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.2.0)

- 字间空格考虑到 `\spacefactor` 和 `\xspaceskip` 的情况。
- 增加 `IVS` 字符类用于处理异体字选择符。
- 修正 `xeCJK` 使西文在部分情况下无法断词的问题。
- 当全角左标点前面是 `hlist`、`none`、 `glue` 和 `penalty` 等节点时，压缩其左空白。
- 不将其初始化为 `\CJKfamilydefault`。
- 定义中加入 `\normalfont`。
- 增加 `Verb` 选项。

## [xeCJK-v3.1.2](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.1.2)

- 使用 `\xeCJK_if_CJK_class:NTF` 来代替 `\int_case:nnn` 判断是否是 CJK 字符类。
- 在没有定义任何 CJK 字体的情况下，不再重复给出字体没有定义的警告。
- 修正重定义 `\CJKfamilydefault` 无效的问题，恢复容错能力。
- 修正非 `\UTFencname` 编码下面 `xunicode` 重定义的 `\nobreakspace` 会失效的问题。
- 不将参数完全展开。
- 解决在下划线状态下使用 `\makebox` 时的错误。

## [xeCJK-v3.1.1](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.1.1)

- 不再依赖 `xpatch` 宏包。
- 新增有省略空格标识的 `peek` 函数。
- 使用 `\xeCJK_save_class:nn` 保存 XeTeX 预定义的字符类别。
- 在文档中设置字符类别时不重复设置 `\catcode`。
- 交换参数的顺序。
- 处理全角右标点之后的断行问题。
- 增加 `\nobreak` 的 `xeCJK` 版本。
- 改进定义，减少使用 `peek` 函数的次数。
- 增加 `PlainEquation` 选项。
- `CheckSingle` 支持段末“汉字$+$汉字$+$空格$+$汉字/标点”的形式。
- 增加 `NewLineCS` 和 `EnvCS` 选项。
- 改变行内环境的设置方式，从而使用 `\str_case_x:nnn` 代替原来的 `\clist_if_in:NnTF` 来判断是否是行内环境。
- 调整间距的计算方法。
- 对于与 `xltxtra` 的冲突给出错误警告。
- 修改主要 `CJK` 字体族的自动更新方式。
- 增加小宏包 `xeCJKfntef`，用于处理下划线的问题。
- 完全处理下划线里的标点符号的有关问题。

## [xeCJK-v3.1.0](https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.1.0)

- 放弃对 `\outer` 宏的特殊处理。
- 改进 `fontspec` 宏包中定义的 `\font_glyph_if_exist:NnTF`。
- 字间空格考虑 `\spaceskip` 不为零的情况。
- 删除多余的 `default-itcorr` 结点。
- 使用 `xtemplate` 宏包的机制来组织标点符号的处理。
- 调整备用字体的循环方式。
- 改进定义，加快切换速度。
- 放弃使用放缩字体大小的方式，而只采用调整间距的方式与西文等宽字体对齐。并且只适用于与抄录环境下。
- 新增 `\xeCJKVerbAddon` 用于抄录环境中的间距调整。
- 增加 `LocalConfig` 选项用于载入本地配置文件。
- 改用 `indentfirst` 宏包处理缩进的问题。
- 采用通过不修改原语 `\/` 的方式对修复倾斜校正。
- 取消 `\cprotect` 的外部宏限制。
- 简化对 `ulem` 宏包的兼容补丁。
