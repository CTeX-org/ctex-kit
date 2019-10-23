# Changelog
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [xeCJK-v3.7.4] - 2019-05-31
### Changed
- 简化行首/尾标点符号宽度的实现。

## [xeCJK-v3.7.3] - 2019-04-15
### Changed
- 补充日文假名扩展。

### Fixed
- 修复 penalty 数值错误。

## [xeCJK-v3.7.2] - 2019-04-07
### Changed
- 同步 LaTeX3 2019/03/05。
- 改用 `xparse` 的新参数类型 `b` 定义 `CJKfilltwosides*` 环境，不再依赖 `environ` 包。
- 解决与 `microtype` 宏包的兼容问题。

### Removed
- 删除定义新字体族时过滤重复选项的功能。

### Fixed
- 简化 `CJKspace` 的实现，并修复错误。
- `\xeCJK_FullLeft_and_Default:`: 再次修正 FullLeft 类字符与西文连用断词失败的问题。
- `\__xeCJK_patch_tuenc_composite:`: 修复补丁错误。

## [xeCJK-v3.7.1] - 2018-04-30
### Fixed
- `\AtEndUTFCommand`: 修复代码重构而引入的新错误。

## [xeCJK-v3.7.0] - 2018-03-18
### Changed
- 不再默认引入 `xunicode` 宏包。
- 对 `\nobreakspace` 的恢复放到 `xunicode-addon` 中处理。
- 补充定义 `\texthyphenationpoint` 和 `\texttwoemdash`。

### Fixed
- 修正长标点被隔开时的压缩处理错误。

## [xeCJK-v3.6.1] - 2018-02-27
### Changed
- 减少 `bool` 运算。
- `\xeCJK_if_last_punct:TF`: 细化判断。

## [xeCJK-v3.6.0] - 2018-01-24
### Added
- 新增 `PunctFamily` 选项支持对汉字标点单独切换字体。

### Changed
- 同步 LaTeX3 2017/12/16。
- 把 TWO-EM DASH (`U+2E3A`) 归入 `FullRight` 类和设为 `LongPunct` 与 `MiddlePunct`。
- 将全角浪线 `U+FF5E` 等连接号归入 `FullRight` 类和设为 `MiddlePunct`。
- 总允许长标点与其他标点之间折行。
- 解决标点中间被隔开的禁则与压缩问题。
- `Default` 类与 `MiddlePunct` 之间不应该有 `\CJKglue`。

### Fixed
- 修正标点同为 `LongPunct` 与 `MiddlePunct` 时的实现错误。

## [xeCJK-v3.5.1] - 2017-11-16
### Fixed
- 修正 fallback 字体后无法忽略空格的错误。

## [xeCJK-v3.5.0] - 2017-07-22
### Changed
- 使用 `lazy` 函数对 Boolean 表达式 进行最小化运算（LaTeX3 2017/07/19）。
- 补充 Ext-F。

### Deprecated
- 常数 `\c_minus_one` 已过时。

## [xeCJK-v3.4.8] - 2017-05-15
### Changed
- 转义 `\lstinline` 参数中的 `\`(12)。

## [xeCJK-v3.4.7] - 2017-03-20
### Changed
- 简化 `CheckSingle` 的实现，不再展开宏。

## [xeCJK-v3.4.6] - 2017-02-23
### Changed
- `\xeCJK@fontfamily`: 将族名参数完全展开，以解决与 `fontspec` 2017/01/24 v2.5d 的兼容问题。

## [xeCJK-v3.4.5] - 2017-01-02
### Changed
- 更新 LaTeX3 的过时用法。

## [xeCJK-v3.4.4] - 2016-11-30
### Changed
- 不压缩长标点与其他标点的间距。

## [xeCJK-v3.4.3] - 2016-11-18
### Changed
- `\__xeCJK_long_punct_kerning:N`: 考虑破折号边界为负值的情况。
- `\setCJKfallbackfamilyfont`: 允许字体属性可选项在后的新语法。
- `\setCJKmonofont`: 允许字体属性可选项在后的新语法。
- `\CJKfontspec`: 允许字体属性可选项在后的新语法。
- `\setCJKmathfont`: 允许字体属性可选项在后的新语法。

## [xeCJK-v3.4.2] - 2016-10-19
### Changed
- `\xeCJK_clear_Boundary_and_CJK_toks:`: 提高效率，避免重复循环。
- 避免在破折号之间折行。

## [xeCJK-v3.4.1] - 2016-08-18
### Added
- 新的下划线选项 `textformat`。

### Changed
- 补充 Unicode 9.0.0 的西夏文。

### Fixed
- 修复 `CJKspace` 功能失效。

## [xeCJK-v3.4.0] - 2016-05-13
### Added
- `RubberPunctSkip` 选项有新的值 `plus` 和 `minus`。

### Changed
- 改进 `xCJKecglue` 的实现。
- 标点符号的压缩量能伸长到原始空白，能收缩到较小边距。
- `\xeCJK_set_mathfont:`: CJKmath 的字符范围遵从 `\xeCJKDeclareCharClass` 的设置。
- CJKmath 功能也支持分区字体。

## [xeCJK-v3.3.4] - 2016-02-07
### Changed
- 兼容 XeTeX 0.99994 的边界字符类。

## [xeCJK-v3.3.3] - 2016-02-01
### Added
- 使用新的 Unicode 编码名称 `TU`。

### Changed
- 更新 LaTeX3 代码。
- 兼容 LaTeX2e 2016/02/01 的字符类设置。
- 把 EN DASH（`U+2013`）作为半字线连接号归入 `FullRight` 类。
- 不再把 `U+2015` 和 `U+2500` 归入 `FullRight` 类。
- 补充 Ext-E。
- 解决与 `microtype` 宏包的兼容问题。
- `CJKfilltwosides`: 确保进入水平模式。

## [xeCJK-v3.3.2] - 2015-05-15
### Changed
- 随 Unicode 7.0.0 更新简繁汉字映射。
- `\g__xeCJK_xetex_allocator_int`: `\xe@alloc@intercharclass` 总是有定义的。

## [xeCJK-v3.3.1] - 2015-05-08
### Changed
- `IVS` 字符类更名为 `CM`。
- `\c__xeCJK_CM_chars_clist`: 补充音调符号。
- 新选项 `WidowPenalty`。
- `\xeCJK_check_single_cs:NNn`: 补充可能遗漏的空格。
- `LoadFandol`: 为方便 MacTeX 用户，Fandol 字体改用文件名。
- `\__xeCJK_math_robust:N`: 兼容 LaTeX2e 2015。
- `\g__xeCJK_xetex_allocator_int`: 兼容 LaTeX2e 2015。
- `\CJKaddEncHook`: 应用 `0.99992` 版的新原语 `\Ucharcat`。
- `\__xeCJK_listings_initial_hook:`: 解决 `prebreak` 和 `postbreak` 功能失效的问题。
- `\__xeCJK_listings_process_Default:nN`: 对 `listings` 的字符扩展不影响到其符号表中的 七位或八位字符。

### Removed
- 删去 `fixltx2e` 和 `amsthm` 的冲突补丁。

### Fixed
- `\xeCJK_token_value_charcode:N`: `0.99992` 版修复了 `\meaning` 的 Bug。

## [xeCJK-v3.3.0] - 2014-12-26
### Changed
- `\c__xeCJK_PR_chars_clist`: 不把 `U+20A9` 归入 CJK 的 PR 类。
- 不把 NS 类中的一些有禁则的日文归入 `FullRight` 类。
- 不把小写日文假名归入 `FullRight` 类。

## [xeCJK-v3.2.16] - 2014-12-16
### Changed
- 不再依赖 `everypage` 宏包。
- 整理 `xCJKecglue` 的部分代码。

### Fixed
- `\hbar`: 修复 `\hbar`。

## [xeCJK-v3.2.15] - 2014-11-10
### Changed
- 增加 `HangulJamo` 字符类。
- 把 REVERSE SOLIDUS（`U+005C`）、HYPHEN-MINUS（`U+002D`）和 EN DASH（`U+2013`）归入 `NormalSpace` 类。
- `xeCJKfntef` 增加 `hidden` 选项。
- `\xeCJKfntefon`: 完善选项。
- `\CJKunderanyline`: 完善选项。

### Fixed
- `\__xeCJK_listings_initial_hook:`: 修正 `breaklines` 无效的问题。

## [xeCJK-v3.2.14] - 2014-11-03
### Changed
- 完善 `\varCJKunderline` 的实现。
- 解决下划线前后没有 `\CJKglue` 或 `\CJKecglue` 的问题。
- `xeCJKfntef` 不再依赖 `CJKfntef`。

## [xeCJK-v3.2.13] - 2014-06-20
### Changed
- 自动调整 `\CJKfamilydefault` 时，只将 `\familydefault` 展开一次。

### Fixed
- `\xeCJK_set_mathfont:`: 修复参数类型错误。

## [xeCJK-v3.2.12] - 2014-05-12
### Added
- 新增 `RubberPunctSkip` 选项。

### Changed
- 更新 `\int_to_Hex:n`。

## [xeCJK-v3.2.11] - 2014-04-10
### Changed
- `\xeCJK_add_to_shipout:n`: 不再使用内部名字。
- 左右角括号 `U+2329` 和 `U+232A` 是西文标点符号。
- `\CJK@family`: 引入 `\CJK@family` 保存实际的字体族名。
- `indentfirst`: 放弃 `indentfirst` 和 `CJKnumber` 选项。

### Removed
- 删除 `\xeCJKcaption`。

## [xeCJK-v3.2.10] - 2014-03-01
### Changed
- `LoadFandol`: 当没有设置字体时，使用 Fandol 字体系列。
- `\CJKaddEncHook`: 使用 `CJKnumb` 时，让 `\Unicode` 有定义。
- `\DeclareUTFDoubleEncodedAccent`: 改进 `\t` 等的定义方式。
- `\DeclareUTFDoubleEncodedSymbol`: 改进 `\sliding` 等的定义方式。
- `\DeclareUTFTIPACommand`: 检查 `\t` 和 `\sliding` 的参数是否以 `\textipa` 开头。

## [xeCJK-v3.2.9] - 2013-12-08
### Changed
- `\c__xeCJK_middle_dot_prop`: 完整处理 `encguide.pdf` 的编码符号表中，与旧编码的 `U+00B7` 冲突。
- 文档部分增加 `xunicode` 定义的符号表。
- 增加 `xunicode-extra.def` 中，用于加入 `puenc.def` 中的符号定义。

### Fixed
- `\DeclareEncodedCompositeAccents`: 修正 `xunicode` 中的错误定义。

## [xeCJK-v3.2.8] - 2013-12-05
### Changed
- `\__xeCJK_nobreak_skip:`: 禁止在 `\verb` 中断行。
- `\xeCJKVerbAddon`: 增加是否是等宽字体的判断。
- 启用 `xunicode` 中的带圈数字和字母设置。

### Fixed
- `\DeclareUTFmathsymbols`: 修正 `\UseMathAsText` 的功能，恢复 `\hbar` 和增加以 `text` 打头的文本符号命令。

## [xeCJK-v3.2.7] - 2013-11-09
### Changed
- 使用 `everypage` 往 `\shipout` 盒子里加钩子。
- `\__xeCJK_punct_glue:NN`: 标点符号左/右空白的伸展值不超过原始边界，收缩值不小于另一侧边界。
- 处理 `AllowBreakBetweenPuncts` 与 `xeCJKfntef` 的兼容问题。
- `\__xeCJK_check_single_aux:nNNw`: 与 `\CJKspace` 兼容。
- 实现自定义行首/尾标点符号宽度功能。
- 标点宽度设置禁用比例选项的值改为 `nan`。
- `\xeCJK_set_mathfont:`: 将 CJK 字符的数学归类由 7 改为 0，解决汉字路径的问题。
- `\Url@MathSetup`: 使通过 `\UrlFont` 等命令设置的 CJK 字体生效。

### Fixed
- 修正 `unicode-letters.tex` 中谚文符号 `\catcode` 不准的问题。

## [xeCJK-v3.2.6] - 2013-08-15
### Changed
- `case` 类函数的用法与 LaTeX3 同步。
- `\xeCJK_CJK_and_Boundary:w`: 更好的处理边界是 `\relax` 的情况。
- `\xeCJK_set_mathfont:`: 设置粗体时先检查对应字体是否存在。
- `\mathrm`: 为 `\mathrm` 减少一个可能的数学字体族。
- `\__xeCJK_math_robust:N`: 考虑 `ulem` 对 `\MakeRobust` 的不当定义。
- `\__xeCJK_math_robust:N`: 考虑 `\math` 和 `\ensuremath`。
- `\AtEndUTFCommand`: 可以指定特定符号命令使用的钩子。

### Fixed
- `AutoFakeBold` 和 `AutoFakeSlant` 选项直接使用 `fontspec` 的设置，修正不能调用相应实际字体的问题。

## [xeCJK-v3.2.5] - 2013-07-25
### Changed
- `\__xeCJK_Boundary_and_FullLeft_glue:N`: 细化全角左标点是否位于段首的判断。
- `\__xeCJK_Boundary_and_FullLeft_glue:N`: 增加对 `enumitem` 宏包修改的 `\item` 的判断。
- `Verb`: 微调定义。
- `\xeCJKVerbAddon`: 禁止自动换行，与西文一致。
- `\xeCJK_visible_space:`: 可视空格考虑传统 TeX字体的情况。
- `\__xeCJK_math_robust:N`: 解决汉字后紧跟 `\(``...``\)` 形式的行内数学公式时，不能加入间距的问题。
- 解决 `fixltx2e` 和 `amsthm` 的冲突。
- 恢复 `\nobreakspace` 的原始定义。
- 增加小宏包 `xunicode-addon`，为 `xunicode` 提供判断字符是否存在的功能。

### Fixed
- 修正 `CJK` 和 `NormalSpace` 字符类之间因为边界造成的间距不正确的问题。

## [xeCJK-v3.2.4] - 2013-07-06
### Changed
- 遵循 LaTeX3 变量需要预先声明的原则。
- `\xeCJK_tl_remove_outer_braces:n`: 去掉外层分组括号时，移除空格，避免死循环。
- `\xeCJK_token_value_charcode:N`: 考虑 `charcode` 超出 BMP 的情况。
- 尽量移除用作判断标志的 `\kern`。
- 使用 `AllowBreakBetweenPuncts` 时，相应标点符号仍能与边界对齐。
- `\__xeCJK_Boundary_and_FullLeft_glue:N`: 细化边界与全角左标点之间是否压缩空白的判断。
- 解决使用 `CheckSingle` 时，某些 `\CJKglue` 不能被正确加入的问题。
- `\xeCJK_fallback_loop:Nn`: 使 `\CJKfamilydefault` 的 `FallBack` 设置全局可用。
- 内部调整分区字体的设置方法。
- 改进获取分区字体属性的办法。
- `\addCJKfontfeatures`: 可以单独增加当前各个分区字体的属性。
- `\__xeCJK_set_verb_exspace:`: 当计算得出的间距为负时，缩小 CJK 字体。
- 不再使用 `CJKnumber` 选项，可以在 `xeCJK` 之后直接使用 `CJKnumb` 宏包得到中文数字。
- `CJKfilltwosides`: 改用 `minipage` 和 LaTeX表格（`tabular`）来实现。
- 使 `listings` 的 `breaklines` 选项对 CJK 字符类可用，并保持标点符号的禁则。

### Fixed
- 修正 `xeCJKfntef` 与 `natbib` 等的冲突。

## [xeCJK-v3.2.3] - 2013-06-11
### Added
- `\xeCJKVerbAddon`: 新增 `\xeCJKOffVerbAddon` 用于局部取消 `\xeCJKOffVerbAddon` 的影响；并解决 跨页使用时影响到页眉页脚的问题。

### Changed
- 提供四个 TECkit 映射文件用于句号转换和简繁互换。
- 根据 XeTeX的脚本重新整理全角标点符号。
- 不再改变 CJK 字符类的 `\catcode`。
- 解决 `CheckSingle` 选项与 `tablists` 宏包的冲突。
- `\__xeCJK_restore_shipout_CJKsymbol:`: 解决 `\CJKunderdot` 跨页使用时影响到页眉页脚的问题。
- 完善对 `listings` 宏包的支持。
- `\__xeCJK_listings_initial_hook:`: 解决 `listings` 坏境中代码行号输出不正确的问题，并解决在其中跨页时对页眉 和页脚的影响。
- `\__xeCJK_listings_process_Default:nN`: 在 `listings` 坏境中对 `\charcode` 大于 255 的字符根据其 `\catcode` 区分 `letter` 和 `other`。

### Fixed
- `\__xeCJK_ulem_FullLeft_and_CJK:`: 修正全角左标点后下划线与 `\CJKunderdot` 连用时结果不正常的问题。

## [xeCJK-v3.2.2] - 2013-06-04
### Changed
- 增加小宏包 `xeCJK-listings`，用于支持 `listings` 宏包。

### Fixed
- 修正某些重音不能正确显示的问题。
- `\__xeCJK_ulem_CJK_and_FullRight_glue:N`: 修正下划线不能跳过全角右标点的问题。

## [xeCJK-v3.2.1] - 2013-05-29
### Changed
- 调整 `Verb` 选项：在命令 `\verb` 里使用时， 不破坏标点禁则，增加值 `env+`。

## [xeCJK-v3.2.0] - 2013-05-22
### Changed
- `\c_xeCJK_space_skip_tl`: 字间空格考虑到 `\spacefactor` 和 `\xspaceskip` 的情况。
- 增加 `IVS` 字符类用于处理异体字选择符。
- `\__xeCJK_Boundary_and_FullLeft_glue:N`: 当全角左标点前面是 `hlist`、`none`、 `glue` 和 `penalty` 等节点时，压缩其左空白。
- `\l_xeCJK_family_tl`: 不将其初始化为 `\CJKfamilydefault`。
- `\setCJKmonofont`: 定义中加入 `\normalfont`。
- 增加 `Verb` 选项。

### Fixed
- `\xeCJK_FullLeft_and_Default:`: 修正 `xeCJK` 使西文在部分情况下无法断词的问题。

## [xeCJK-v3.1.2] - 2013-01-01
### Changed
- `\__xeCJK_check_single_space:NN`: 使用 `\xeCJK_if_CJK_class:NTF` 来代替 `\int_case:nnn` 判断是否是 CJK 字符类。
- `\__xeCJK_family_unknown_warning:n`: 在没有定义任何 CJK 字体的情况下，不再重复给出字体没有定义的警告。
- `\xeCJK@fontfamily`: 不将参数完全展开。
- 解决在下划线状态下使用 `\makebox` 时的错误。

### Fixed
- 修正重定义 `\CJKfamilydefault` 无效的问题，恢复容错能力。
- 修正非 `\UTFencname` 编码下面 `xunicode` 重定义的 `\nobreakspace` 会失效的问题。

## [xeCJK-v3.1.1] - 2012-12-13
### Added
- `\xeCJK_peek_catcode_ignore_spaces:NTF`: 新增有省略空格标识的 `peek` 函数。

### Changed
- 不再依赖 `xpatch` 宏包。
- `\xeCJK_save_class:nn`: 使用 `\xeCJK_save_class:nn` 保存 XeTeX预定义的字符类别。
- `\xeCJK_set_char_class:nnn`: 在文档中设置字符类别时不重复设置 `\catcode`。
- `\__xeCJK_set_char_class_eq:nn`: 交换参数的顺序。
- `CheckFullRight`: 处理全角右标点之后的断行问题。
- `\xeCJKnobreak`: 增加 `\nobreak` 的 `xeCJK` 版本。
- `\__xeCJK_check_single_aux:nNNw`: 改进定义，减少使用 `peek` 函数的次数。
- `PlainEquation`: 增加 `PlainEquation` 选项。
- `\__xeCJK_check_single_space:NN`: `CheckSingle` 支持段末“汉字 + 汉字 + 空格 + 汉字/标点”的形式。
- 增加 `NewLineCS` 和 `EnvCS` 选项。
- `InlineEnv`: 改变行内环境的设置方式，从而使用 `\str_case_x:nnn` 代替原来的 `\clist_if_in:NnTF` 来判断是否是行内环境。
- `\__xeCJK_set_verb_exspace:`: 调整间距的计算方法。
- 对于与 `xltxtra` 的冲突给出错误警告。
- `\xeCJK@fontfamily`: 修改主要 `CJK` 字体族的自动更新方式。
- 增加小宏包 `xeCJKfntef`，用于处理下划线的问题。
- `\xeCJK_hook_for_ulem:`: 完全处理下划线里的标点符号的有关问题。

## [xeCJK-v3.1.0] - 2012-11-21
### Added
- `\xeCJKVerbAddon`: 新增 `\xeCJKVerbAddon` 用于抄录环境中的间距调整。

### Changed
- 放弃对 `\outer` 宏的特殊处理。
- `\xeCJK_glyph_if_exist:N`: 改进 `fontspec` 宏包中定义的 `\font_glyph_if_exist:NnTF`。
- `\c_xeCJK_space_skip_tl`: 字间空格考虑 `\spaceskip` 不为零的情况。
- 使用 `xtemplate` 宏包的机制来组织标点符号的处理。
- `\xeCJK_fallback_loop:Nn`: 调整备用字体的循环方式。
- `\__xeCJK_switch_font:nn`: 改进定义，加快切换速度。
- 放弃使用放缩字体大小的方式，而只采用调整间距的方式 与西文等宽字体对齐。并且只适用于与抄录环境下。
- `\xeCJK_visible_space_fallback:`: 调整 `fontspec` 的后备可视空格符号，以便于使用时对齐。
- `LocalConfig`: 增加 `LocalConfig` 选项用于载入本地配置文件。
- 改用 `indentfirst` 宏包处理缩进的问题。
- 取消 `\cprotect` 的外部宏限制。
- `\xeCJK_hook_for_ulem:`: 简化对 `ulem` 宏包的兼容补丁。

### Removed
- 删除多余的 `default-itcorr` 结点。

### Fixed
- `\xeCJK@fix@penalty`: 采用通过不修改原语 `\/` 的方式对修复倾斜校正。

[Unreleased]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.7.4...HEAD
[xeCJK-v3.7.4]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.7.3...xeCJK-v3.7.4
[xeCJK-v3.7.3]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.7.2...xeCJK-v3.7.3
[xeCJK-v3.7.2]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.7.1...xeCJK-v3.7.2
[xeCJK-v3.7.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.7.0...xeCJK-v3.7.1
[xeCJK-v3.7.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.6.1...xeCJK-v3.7.0
[xeCJK-v3.6.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.6.0...xeCJK-v3.6.1
[xeCJK-v3.6.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.5.1...xeCJK-v3.6.0
[xeCJK-v3.5.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.5.0...xeCJK-v3.5.1
[xeCJK-v3.5.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.8...xeCJK-v3.5.0
[xeCJK-v3.4.8]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.7...xeCJK-v3.4.8
[xeCJK-v3.4.7]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.6...xeCJK-v3.4.7
[xeCJK-v3.4.6]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.5...xeCJK-v3.4.6
[xeCJK-v3.4.5]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.4...xeCJK-v3.4.5
[xeCJK-v3.4.4]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.3...xeCJK-v3.4.4
[xeCJK-v3.4.3]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.2...xeCJK-v3.4.3
[xeCJK-v3.4.2]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.1...xeCJK-v3.4.2
[xeCJK-v3.4.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.4.0...xeCJK-v3.4.1
[xeCJK-v3.4.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.3.4...xeCJK-v3.4.0
[xeCJK-v3.3.4]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.3.3...xeCJK-v3.3.4
[xeCJK-v3.3.3]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.3.2...xeCJK-v3.3.3
[xeCJK-v3.3.2]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.3.1...xeCJK-v3.3.2
[xeCJK-v3.3.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.3.0...xeCJK-v3.3.1
[xeCJK-v3.3.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.16...xeCJK-v3.3.0
[xeCJK-v3.2.16]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.15...xeCJK-v3.2.16
[xeCJK-v3.2.15]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.14...xeCJK-v3.2.15
[xeCJK-v3.2.14]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.13...xeCJK-v3.2.14
[xeCJK-v3.2.13]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.12...xeCJK-v3.2.13
[xeCJK-v3.2.12]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.11...xeCJK-v3.2.12
[xeCJK-v3.2.11]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.10...xeCJK-v3.2.11
[xeCJK-v3.2.10]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.9...xeCJK-v3.2.10
[xeCJK-v3.2.9]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.8...xeCJK-v3.2.9
[xeCJK-v3.2.8]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.7...xeCJK-v3.2.8
[xeCJK-v3.2.7]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.6...xeCJK-v3.2.7
[xeCJK-v3.2.6]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.5...xeCJK-v3.2.6
[xeCJK-v3.2.5]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.4...xeCJK-v3.2.5
[xeCJK-v3.2.4]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.3...xeCJK-v3.2.4
[xeCJK-v3.2.3]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.2...xeCJK-v3.2.3
[xeCJK-v3.2.2]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.1...xeCJK-v3.2.2
[xeCJK-v3.2.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.2.0...xeCJK-v3.2.1
[xeCJK-v3.2.0]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.1.2...xeCJK-v3.2.0
[xeCJK-v3.1.2]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.1.1...xeCJK-v3.1.2
[xeCJK-v3.1.1]: https://github.com/CTeX-org/ctex-kit/compare/xeCJK-v3.1.0...xeCJK-v3.1.1
[xeCJK-v3.1.0]: https://github.com/CTeX-org/ctex-kit/releases/tag/xeCJK-v3.1.0
