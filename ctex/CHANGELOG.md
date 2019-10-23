# Changelog
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
### Changed
- 操作系统检测移动至载入中文字库处，且不再需要依赖特定引擎。
- 使用环境变量代替绝对路径查找字体。
- `\ctex_if_platform_macos:TF`: 改用 `/System/Library/Fonts/Menlo.ttc` 为特征文件。
- 为 `macnew` 增加粗楷体、隶书和圆体的定义。
- 允许 `macnew` 在 LaTeX 和 upLaTeX 下使用。
- `ubuntu` 改用思源（Noto CJK）和文鼎字库，不再支持使用 pdfLaTeX 编译。

### Deprecated
- 不再支持 Windows XP 系统，`windowsold` 和 `windowsnew` 成为过时字库选项。

## [ctex-v2.4.16] - 2019-05-29
### Changed
- 允许设置 `autoindent` 为 0。
- 更好地兼容 `nameref` 宏包。

### Fixed
- 修正 `part/indent` 和 `chapter/indent` 的实现方法，在其标题内部禁用 `autoindent`。

## [ctex-v2.4.15] - 2019-04-05
### Changed
- 同步 LaTeX3 2019/03/05。
- 显式补丁 upLaTeX的 `\rmfamily` 等字体命令。
- 将 upLaTeX的默认字体由 `mc` 改为 `zhrm`，并启用 `\jfam`。
- 定义 `part/hang` 和 `chapter/hang`。
- 局部指定 `autoindent` 为 `false`，并交换 `\CTEX@XXX@indent` 与 `\CTEX@XXX@format` 的顺序。
- 将 `JY2` 和 `JT2` 编码的字体定义提取到单独的文件中。
- 统一“方正细黑一_GBK”的名称为 `FZXiHeiI-Z08`。

### Fixed
- 修正 `part/indent` 和 `chapter/indent` 的实现方法。

## [ctex-v2.4.14] - 2018-05-01
### Changed
- 区分 `macold` 及 `macnew`。
- 配置 `macnew` 的默认字体设置。
- 为 `macnew` 配置字体命令。

## [ctex-v2.4.13] - 2018-03-23
### Fixed
- 修正导言区 `\selectfont` 钩子位置。

## [ctex-v2.4.12] - 2018-01-27
### Changed
- 同步 LaTeX3 2017/12/16。
- 正确使用 `\ltjsetkanjiskip` 和 `\ltjsetxkanjiskip`。
- `\CTeX`: 不依赖 `\ifincsname`。

### Fixed
- 修正 `\ctexset` 在 `ctexheading` 包中无定义的错误（曾祥东）。

## [ctex-v2.4.11] - 2017-11-21
### Changed
- 不把 Enclosed Alphanumerics 设置为 JAchar。
- 不把希腊和西里尔字母设置为 JAchar。
- 因上游 `l3keys` 变化，重新定义 `format\textvisiblespace+` 等带空格加号的选项。
- `\ps@headings`: 补充页眉空格。

## [ctex-v2.4.10] - 2017-07-23
### Changed
- 使用 `lazy` 函数对 Boolean 表达式 进行最小化运算（LaTeX3 2017/07/19）。
- 定义 `\cht`，`\cdp` 和 `\cwd`。

### Deprecated
- 常数 `\c_minus_one` 已过时。

## [ctex-v2.4.9] - 2017-02-27
### Changed
- 调整 `unicode-math` 补丁的代码顺序。

## [ctex-v2.4.8] - 2017-02-23
### Changed
- `\CTEX@fontfamily`: 解决与 `fontspec` 2017/01/24 v2.5d 的字体族匹配兼容问题。

## [ctex-v2.4.7] - 2016-12-27
### Changed
- 依赖 `pxeverysel` 宏包。

### Fixed
- `\ps@headings`: 修复 `ctexrep` 类的 `\chaptermark` 汉化错误。

## [ctex-v2.4.6] - 2016-11-20
### Changed
- 支持字体属性可选项在后的新语法。
- `\CTEXifname` 初始为假。
- 重新初始化 `\ifthechapter` 等。

## [ctex-v2.4.5] - 2016-10-25
### Added
- 新的标题格式选项 `hang`。
- 新的标题格式选项 `tocline`。
- 新的标题格式选项 `chapter/lofskip` 和 `chapter/lotskip`。

### Fixed
- `\ps@headings`: 修复补丁失败。

## [ctex-v2.4.4] - 2016-09-19
### Added
- 新的标题格式选项 `break`。

### Changed
- 解决 `zhmap` 文件的 `\catcode` 问题。
- 不再默认设置 `xeCJK` 的伪粗体。
- 提供 `\partmark`。
- 提供 `\CTEXifname`。
- 改进 `hyperref` 宏包的标题锚点设置。
- 使用 `titlesec` 时，章节目录也使用 CTeX 的编号。

## [ctex-v2.4.3] - 2016-08-26
### Added
- 新的标题格式选项 `fixskip`。

### Changed
- 简化 `fontspec` 补丁。
- 更新 `unicode-math` 补丁。
- 确保 `\proofname` 非空。

### Removed
- 删除选项 `part/fixbeforeskip` 和 `chapter/fixbeforeskip`。

## [ctex-v2.4.2] - 2016-05-15
### Changed
- 恢复 `luatexja` 对 `\emshape` 和 `\eminnershape` 的重定义。
- `\em`: 兼容 upLaTeX 2016/05/07u00 的定义。

## [ctex-v2.4.1] - 2016-05-14
### Added
- 新的标题格式选项 `part/fixbeforeskip` 和 `chapter/fixbeforeskip`。

### Changed
- `zihao`: 不允许无参 `zihao` 选项。
- 正确更新 upLaTeX 的 `\CJKfamilydefault`。
- `\ccwd`: 正确设置 upTeX 下的 `\ccwd`。
- 随字体更新 upTeX 的 `\xkanjiskip`。
- `\chinese`: 支持 `\pagenumbering`。
- `beamer` 不调整默认字体大小。
- `beamer` 不调整默认行距。
- 使用 `bootfont.bin` 判断 Windows XP 以避免 权限问题。

## [ctex-v2.4] - 2016-04-25
### Changed
- 加强 `beamer` 宏包支持。
- 初步支持 upLaTeX。
- 正确设置 upTeX 下字体命令。
- 正确更新 `CJK` 包的 `\CJKfamilydefault`。
- 提供 upLaTeX 的 NFSS 字体定义。
- 提供 `translator` 宏包的中文定理名称翻译。

### Fixed
- `\ctex_parse_name:NN`: 修复宏名解析错误。

## [ctex-v2.3] - 2016-01-05
### Changed
- 与 LaTeX3 (2015/12/20) 同步。
- 代码实现避免使用 `\lowercase` 技巧（Joseph Wright）。
- 更新 `LuaTeX-ja` 支持（20150922.0）。
- 更新 `unicode-math` 宏包补丁。
- 兼容 `titleps` 宏包。

### Deprecated
- `.value_required:` 和 `.value_forbidden:` 已过时。

### Fixed
- 修复 `nameformat` 作用域问题。

## [ctex-v2.2] - 2015-06-30
### Added
- 新的标题格式选项 `numbering`。
- 新的标题格式选项 `afterindent`。
- 新的标题格式选项 `runin`。
- 新增子宏包 `ctexpatch` 实现给宏打补丁功能。

### Changed
- 不再依赖 `etoolbox` 宏包。
- 给 `enumitem` 宏包注册 `\chinese` 和 `\zhnum`。
- `beforeskip` 和 `afterskip` 选项的符号 不再有特殊意义。
- `beforeskip`、`afterskip` 和 `indent` 选项支持表达式。
- 非 `ctexart` 类的 `part/beforeskip` 和 `part/afterskip` 选项有意义。
- 将中文版式下的 `part` 和 `chapter` 标题的 `nameformat` 和 `titleformat` 选项的初值合并到 `format` 中。
- 将文档开头和宏包末尾钩子提取到 `ctexhook` 宏包中。

### Removed
- 删去 `etoolbox` 与 `breqn` 的兼容补丁。

## [ctex-v2.1] - 2015-06-19
### Added
- 新的标题格式选项 `aftertitle`。

### Changed
- 将章节标题设置功能提取到可以独立使用的宏包 `ctexheading` 中。
- 不依赖 `ifpdf` 宏包。
- `hyperref`: 补充定义 `\hypersetup`。
- 给 pdfLaTeX 下的非 UTF8 编码 CJK 字体族加上 CMap。
- 不再设置 `hyperref` 宏包的 `colorlinks` 选项。
- `nameformat` 可以接受章节名字为参数。
- `format+`, `nameformat+` 等带加号的选项， 加号与前面的文字之间可以有可选的空格。
- `\ctex_if_platform_macos:TF`: 改用 `/Library/Fonts/Songti.ttc` 为特征文件。

### Fixed
- 修复 `ctexbook` 和 `ctexrep` 类的中文 `part/number` 选项初值为空的错误。

## [ctex-v2.0.2] - 2015-05-16
### Fixed
- 修复加载 `ctex` 宏包后章节标题后第一段 无段首缩进的问题。

## [ctex-v2.0.1] - 2015-05-15
### Fixed
- 修复 `10pt`、`11pt` 等选项无效的问题。

## [ctex-v2.0] - 2015-05-06
### Added
- 新增 `zihao` 选项。
- 新增 `linespread` 选项。
- 新增 `autoindent` 选项。
- 新增 `fontset` 选项。
- 新增 `zhmCJK` 支持选项。
- `ctex` 宏包新增 `heading` 选项。
- 新增 `scheme` 选项，并将 `cap` 和 `nocap` 列为过时选项。
- 新增统一设置接口 `\ctexset`。
- 新增 `linestretch` 选项。
- 标题设置新增 `pagestyle` 选项。

### Changed
- 应用 LaTeX3 重新整理代码。
- `punct` 选项可以设置标点格式。
- 兼容 `extsizes` 宏包、`beamer`、`memoir` 等提供的更多字号选项。
- `\CJK@surr`: 解决与 `\nouppercase` 的冲突。
- 通过 `LuaTeX-ja` 宏包支持 LuaLaTeX。
- 自动检测操作系统，载入对应的字体配置。
- 默认关闭 `CJKfntef` 或 `xeCJKfntef` 的彩 色设置。
- 将标题汉化功能加入 `ctex.sty`。
- 将中文字号功能提取到可以独立使用的 `ctexsize`。
- 中文字号不再采用近似值。
- 调整 `\footnotesep` 的大小，以适合行距的变化。
- 解决 `etoolbox` 与 `breqn` 关于 `\end` 的冲突。

### Deprecated
- `\CTEXsetup`, `\CTEXoptions` 是过时命令。
- `c5size`, `cs4size` 是过时选项。
- `indent`, `noindent` 是过时选项。
- `nofonts`, `adobefonts`, `winfonts` 是过时选项。
- `nozhmap` 是过时选项。
- `nopunct` 是过时选项。
- `nospace` 是过时选项。
- `hyperref` 成为过时选项，原选项功能总是打开。
- `fancyhdr` 成为过时选项，原选项功能总是打开。
- `fntef` 成为过时选项，原选项功能总是打开。
- `\CTEXunderdot`, `\CTEXunderline`, `\CTEXunderdblline`, `\CTEXunderwave`, `\CTEXsout`, `\CTEXxout` 是过 时命令；`CTEXfilltwosides` 是过时环境。
- `\CTEXsetup`, `\CTEXoptions` 是过时命令。
- `\CTEXindent`, `\CTEXnoindent` 是过时命令。
- `captiondelimiter` 是过时选项。

### Removed
- 删除 `c19gbsn.fd` 和 `c19gkai.fd`。

[Unreleased]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.16...HEAD
[ctex-v2.4.16]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.15...ctex-v2.4.16
[ctex-v2.4.15]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.14...ctex-v2.4.15
[ctex-v2.4.14]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.13...ctex-v2.4.14
[ctex-v2.4.13]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.12...ctex-v2.4.13
[ctex-v2.4.12]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.11...ctex-v2.4.12
[ctex-v2.4.11]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.10...ctex-v2.4.11
[ctex-v2.4.10]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.9...ctex-v2.4.10
[ctex-v2.4.9]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.8...ctex-v2.4.9
[ctex-v2.4.8]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.7...ctex-v2.4.8
[ctex-v2.4.7]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.6...ctex-v2.4.7
[ctex-v2.4.6]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.5...ctex-v2.4.6
[ctex-v2.4.5]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.4...ctex-v2.4.5
[ctex-v2.4.4]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.3...ctex-v2.4.4
[ctex-v2.4.3]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.2...ctex-v2.4.3
[ctex-v2.4.2]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4.1...ctex-v2.4.2
[ctex-v2.4.1]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.4...ctex-v2.4.1
[ctex-v2.4]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.3...ctex-v2.4
[ctex-v2.3]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.2...ctex-v2.3
[ctex-v2.2]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.1...ctex-v2.2
[ctex-v2.1]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.0.2...ctex-v2.1
[ctex-v2.0.2]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.0.1...ctex-v2.0.2
[ctex-v2.0.1]: https://github.com/CTeX-org/ctex-kit/compare/ctex-v2.0...ctex-v2.0.1
[ctex-v2.0]: https://github.com/CTeX-org/ctex-kit/releases/tag/ctex-v2.0
