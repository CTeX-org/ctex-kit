# ctex 架构详解

本文档从整体到局部介绍 ctex 包的设计原理与实现架构。

## 定位与职责

ctex 是中文 LaTeX 排版的统一用户入口，负责：

1. 包装标准 LaTeX 类（article/book/report/beamer），提供开箱即用的中文文档类
2. 提供中文标题方案、字号系统、字体集
3. 跨引擎适配：XeTeX、LuaTeX、pdfTeX、upTeX、apTeX

ctex 不是引擎级实现，而是代理层——它把底层排版能力委托给各引擎对应的后端包：

- XeTeX → xeCJK（interchar 字符间距机制）
- LuaTeX → LuaTeX-ja（节点级 callback 机制）
- pdfTeX → CJK 宏包 + zhmap 字体映射 + CMap
- upTeX → 原生 CJK 支持 + zhmetrics-uptex
- apTeX → 独立适配层

## 源码组织

### 源文件布局（#937 拆分后）

自 #937 起，原本约 10600 行的单体 `ctex.dtx` 按功能区域拆分为 6 个 dtx 文件，避免单文件过大难以维护：

| 源文件 | 承载内容 |
|--------|----------|
| `ctex.dtx` | `.ins`（`\generate` 段）、README、用户手册（driver 用 `\DocInput` 合并其余 dtx 排版） |
| `ctex-kernel.dtx` | 核心宏包/类/heading 的 `.def`（ctex / ctexsize / ctexheading / ctexart / ctexbook / ctexrep / ctexbeamer / c5size / cs4size / heading-*） |
| `ctex-auxpkg.dtx` | 辅助（内部使用）与过时包的遗留部分（ctexcap / ctexhook / ctexpatch） |
| `ctex-engine.dtx` | 引擎配置文件（`ctex-engine-*.def`） |
| `ctex-scheme.dtx` | `scheme = plain/chinese` 配置 + `name` 中文名称 |
| `ctex-fontset.dtx` | 字库、`zhmap`、pTeX 下的 `.fd` 文件 |

`build.lua` 的 `sourcefiles` 列全 6 个 dtx；`unpackfiles` 只列主 `ctex.dtx`——其 `\generate` 段通过 `\from{\jobname-kernel.dtx}{...}` 等跨文件引用取各 dtx 内的 docstrip 段。拆分不改变产物集合，下表的所有产物仍由 docstrip 生成。版本号收敛为 `build.lua` 单一事实源 + `l3build tag` 回写 dtx `$Id:$` stamp，详见 `llmdoc/reference/build-and-test.md` 版本管理章节与 `llmdoc/memory/decisions/937-version-single-source-l3build-tag.md`。

### 产物

通过 docstrip 生成多类产物：

| 产物类别 | 文件 | 标签 |
|----------|------|------|
| 文档类 | `ctexart.cls`, `ctexbook.cls`, `ctexrep.cls`, `ctexbeamer.cls` | `class,article` 等 |
| 主宏包 | `ctex.sty` | `style,ctex` |
| 支撑宏包 | `ctexsize.sty`, `ctexheading.sty`, `ctexpatch.sty`, `ctexhook.sty`, `ctexcap.sty` | 各自标签 |
| 引擎定义 | `ctex-engine-{pdftex,xetex,luatex,uptex,aptex}.def` | `pdftex`, `xetex` 等 |
| 字体集 | `ctex-fontset-{windows,mac,macnew,macold,ubuntu,fandol,adobe,founder,hanyi}.def` | `fontset,<name>` |
| 方案 | `ctex-scheme-{plain,chinese}.def` + 类变体 | `scheme,<name>` |
| 标题 | `ctex-heading-{article,book,report,beamer}.def` | `heading,<class>` |
| 后端配置 | `ctexbackend.cfg` | `config` |

## 分层加载架构

### 加载链

```
ctexart.cls
  → 加载标准类 (article.cls)
  → 加载 ctex.sty
    → ctex-engine-*.def      (引擎检测与后端初始化)
    → ctex-fontset-*.def     (OS/字体检测)
    → ctex-scheme-*.def      (方案选择)
    → ctex-heading-*.def     (标题定制)
```

这不是静态 `\input` 序列，而是由运行期选项和引擎检测驱动的条件加载。核心加载宏是 `\ctex_file_input:n`，提供安全的文件输入语义。

### 各层职责

1. **类包装层**：`ctexart.cls` 等先加载对应标准类，再附加中文配置层
2. **引擎层**：第一个运行期分流点，决定底层字体设定与字符边界机制
3. **字体集层**：把"中文主字体/无衬线/等宽"落实到具体操作系统字体名
4. **方案层**：组织 plain/chinese 等文档样式的参数默认值
5. **标题层**：为章节编号和题头格式做最终类级定制

## 键值选项系统

### 底层基础

ctex 的选项系统建立在 l3keys 之上：

- `\keys_define:nn { ctex }` — 运行时选项
- `\keys_define:nn { ctex / option }` — 包/类选项（加载期）
- `\ctexset` = `\ctex_set:n` = `\keys_set:nn { ctex }`

### 键路径分派

标题选项使用 `.meta:nn` 重定向：

```
section .meta:nn = { ctex / section } { #1 }
```

这意味着 `\ctexset{ section/format = ... }` 实际设置的是 `ctex / section / format` 路径。

### 遗留接口

`\CTEXsetup` 和 `\CTEXoptions` 是已废弃的兼容包装，最终都映射到 `\ctexset`。

## 引擎适配策略

### 核心不变量

ctex 不用一套底层实现覆盖所有引擎，而是把统一接口建立在多后端适配之上。引擎检测使用 `\sys_if_engine_pdftex:TF`、`\sys_if_engine_uptex:TF` 等 expl3 原语。

### LuaTeX 路线的特殊约束

ctex 通过 `\@namedef{ver@ltj-latex.sty}{}` 主动屏蔽 `ltj-latex`，避免与 ctex 在 LaTeX 层重复接管同一批接口。

**副作用**：`ltj-latex` 被屏蔽时，`lltjcore.sty` 也一起缺席。后者携带对 LaTeX 原生命令的兼容补丁（如 `\verb` 的 `\null` → `\vadjust{}` 修正）。自 v2.5.12 起，ctex 在 LuaTeX 引擎适配中显式移植了 `lltjcore` 的关键补丁。

### `CJKfntef` 的后端兼容边界（#381）

传统 `CJKfntef` 会载入 `CJK.sty`，其字体族协议与 ctex 的 LuaTeX-ja 后端冲突，会使 `\setCJKmainfont` 的结果依赖加载顺序。`ctex/ctex-engine.dtx:878` 因而在 `\RequirePackage{luatexja}` 前处理两种状态：包已加载则 critical 中止，包未加载则通过 `\@@_disable_package_aux:nnnn` 注册禁载 warning，并推荐 `lua-ul`。

这不是所有 Unicode 引擎共享的禁令。XeTeX 下 `xeCJK/xeCJK.dtx:1896` 会把同名请求替换成兼容的 `xeCJKfntef`；LuaTeX 的 `lua-ul` API 不同，不能采用同样的透明替换。兼容策略以“实际后端协议和 API 是否同构”为准，而不是以宏包名字是否相同为准。

### pdfTeX 路线的 UTF-8 字符处理

pdfTeX 下 ctex 通过 CJK 宏包处理中文字符。UTF-8 编码的多字节字符通过 `\CJK@XX`（2 字节）、`\CJK@XXX`（3 字节）、`\CJK@XXXX`（4 字节）入口分派，内部映射到 `\@@_char:NN`/`\@@_char:NNN`/`\@@_char:NNNN`。

**`\DeclareUnicodeCharacter` 优先查找**：在非 GBK 编码下，ctex 会为 2/3/4 字节 UTF-8 字符优先检查 `\u8:xx`/`\u8:xxx`/`\u8:xxxx`（即 `\DeclareUnicodeCharacter` 的底层定义）。若存在对应定义则直接使用，否则回退到 CJK 子字体路径。4 字节字符（BMP 外，如 emoji）的优先查找自 #815 起添加，与 2/3 字节字符保持一致。

### 引擎延迟重定义模式

`ctex.sty` 以 `{style,ctex}` 标签生成，不含引擎标签。引擎 `.def` 代码段通过 `\ctex_at_end:n`（= `\AtEndOfPackage`）延迟到包加载末尾执行重定义，覆写公共区域的默认实现，实现引擎特化。

这一模式的典型用例：各引擎的 `.def` 覆写 `\@@_update_stretch_auxii:` 以添加 `\ctex_if_ccglue_touched:TF` 守卫——这段重定义自 #1068 起对全部引擎生效，此前被 docstrip 守卫限定在 pdftex/xetex，luatex/uptex 因而缺守卫，用户设置的 CJKglue/kanjiskip 会被 `\selectfont` 覆盖。详见 `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`。

## 字体集系统

### 自动检测逻辑

- Windows → `windows`
- macOS → `mac`（分发器，非独立字体集）
- Linux → `fandol`

### macOS 分流

`fontset=mac` 在运行时路由到 `macnew` 或 `macold`：

- 快速路径：检查 `/System/Library/Fonts/Menlo.ttc`
- 后备路径：读取 `SystemVersion.plist` 主版本号
- `macnew` 内部还按引擎二次分支：XeTeX 用 `\fontspec_font_if_exist:nTF`，LuaTeX 用 Lua 扫描 AssetData 目录

### 引擎分支宏

`\ctex_fontset_case:nnn` 在字体集文件内提供三路引擎分支（XeTeX/LuaTeX/其他）。

### ubuntu 字库仿宋 fallback

`fontset=ubuntu` 的 `zhfs`（仿宋）在 XeTeX/LuaTeX 分支按朱雀仿宋（`lxgw-fonts` 包）→ FandolFang → Noto 宋体三级 `\fontspec_font_if_exist:nTF` 运行时探测选用，与 `\setCJKmonofont` 共用同一次探测结果；pdfTeX(DVI)/upTeX 分支无法运行时探测，走静态映射（Noto 宋体）。详见 `llmdoc/memory/decisions/908-ubuntu-fontset-fangsong.md`。

## 中文字号系统

### 数据存储

字号数据存储在 `\c_@@_font_size_prop`，映射字号名到 `{fontsize}{baselineskip}` 对。

### 使用接口

`\zihao{-4}` → 查 prop → `\fontsize{...}{...}\selectfont`

### 字号表切换

`experiment/font-size-system` 控制数据源：

| 值 | 含义 |
|----|------|
| `word` | 默认，现代 Word 字号体系 |
| `letterpress` | 金属活字排印字号体系**之一**（原名 `traditional`，#813 更名） |
| 自定义名 | 尝试加载 `ctex-fontsize-<name>.def` |

自定义字号表通过 `\ctex_save_font_size:nn` 写入数据。

#### `letterpress` 的语义边界（#871 文档勘误）

`letterpress` 仅是历史上多种金属活字字号约定中**一种**严格倍数体系（初号/二号/五号/七号 ×2 等比；一号/四号 ×2；三号/六号/八号 ×2），并**不是**唯一定义。`ctex.dtx` 的字号映射表（标准字号 ↔ 字号名）与中文字号表附近的说明文档都明确提示：默认 `word` 字号与 `letterpress` 字号在「初号/二号/五号/七号」六个尺寸上数值不同，用户切换字号体系时这些字号会变化。该提示通过 #871 的文档补丁加入，对应 `ctex.dtx` `\changes` v2.6.0 2026/06/23。

### 冻结语义

字号表在类/宏包选项解析期冻结为常量 prop，不支持运行时通过 `\ctexset` 切换。后续 `\zihao` 与数学字号声明直接读取这份编译期常量。

## 字间距与行距控制

### 调用链

```
\selectfont → \ctex_update_size: → \ctex_update_stretch:
  → \@@_update_stretch_auxi:   (linestretch 禁用路径)
  → \@@_update_stretch_auxii:  (linestretch 启用路径)
    → \@@_update_stretch_auxiii:  (计算逻辑)
      → \ctex_update_ccglue:
```

### 核心概念

- `\ccwd`：中文字符宽度，是间距计算的基本单位
- `linestretch`：计算每行剩余空间并分配为字间弹性胶
- `autoindent`：默认让已有的非零段首缩进随字号更新为 `2\ccwd`
- `\ziju`：字符间距控制，含 stretch/shrink 计算
- CJKglue 默认：`0pt plus (linewidth - n*ccwd)/n`（自适应）

### `autoindent` 的零缩进边界（#402）

`\ctex_update_parindent:` 在字号变化时先检查 `\l_@@_autoindent_tl` 是否非空，再只在
当前 `\parindent` 非零时写入配置值。`autoindent=false` 清空该 tl，完全关闭自动更新；
零 `\parindent` 则是启用状态下仍需保留的兼容哨兵。

这一边界兼容早期尚无 `autoindent=false` 时通过 `\parindent=0pt` 关闭自动缩进的文档，
也保护 `minipage`、居中段落等主动使用零缩进的 LaTeX 结构，避免其中的字号变化重新
引入段首缩进。#402 因而只把既有语义写入用户手册并增加回归，不改运行实现。

## 方案系统

### scheme=chinese

设置一系列中文排版默认值：

- pagestyle → headings
- today 格式 → small
- autoindent → true
- normalsize → 五号
- linespread → 1.3
- 加载 indentfirst
- 加载中文名称配置

### scheme=plain

最小干预，不设置中文特有默认值。

### 类变体

方案文件有类特定变体：`ctex-scheme-chinese-article.def`、`ctex-scheme-chinese-book.def` 等，承接各文档类的细分约定。

## 标题结构系统

### 标题键定义

通过 `\@@_def_heading_keys:n` 为每个标题层级（part, chapter, section, ...）定义完整的键集。

### 可用键

| 键 | 作用 |
|----|------|
| `name` | 逗号分隔对 `{prefix, suffix}`，如 `{第,章}` |
| `number` | 编号格式 |
| `format` / `format+` | 整体格式（`+` 后缀为追加） |
| `nameformat` / `numberformat` / `titleformat` | 各部分独立格式 |
| `aftername` / `aftertitle` | 名称/标题后内容 |
| `beforeskip` / `afterskip` | 前后间距 |
| `indent` | 缩进量 |
| `numbering` | 是否编号 |
| `afterindent` | 标题后是否缩进 |
| `fixskip` / `hang` / `runin` | 排版模式控制 |
| `tocline` / `break` / `pagestyle` | 目录行/换页/页面样式 |

### 中文标题名

存储在 `\CTEX@pre<heading>`、`\CTEX@post<heading>`、`\CTEX@the<heading>` 三类宏中。

### 公开标题查询接口（#275）

`ctex/ctex-kernel.dtx`（`\CTEXheadingnumber`、`\CTEXheadinglabel`、
`\CTEXifheadingnumbering`）把标题键的数据层按层级参数化暴露出来：

| 接口 | 数据来源与语义 |
|------|----------------|
| `\CTEXheadingnumber{<level>}` | 当前 `<level>/number` 的结果，不含 `name` |
| `\CTEXheadinglabel{<level>}` | `name` 前缀 + 编号 + 后缀，等价于 `\CTEXthe<level>` |
| `\CTEXifheadingnumbering{<level>}{<true>}{<false>}` | 只按当前 `<level>/numbering` 布尔值选择分支 |

三者都是可展开的使用时查询，因此能响应后续及分组内的 `\ctexset`，并在分组
结束后随底层键值恢复。可用层级由文档类的 heading 序列决定；`ctexbeamer`
提供 `part`、`section`、`subsection`。

接口边界是“标题编号数据”，不是“标题渲染结果”：不应用 `format`、
`nameformat`、`numberformat`、字体、颜色或间距，也不提供标题文本。Beamer 主题
继续用 `\insertpart`、`\insertsection`、`\insertsubsection` 取得标题文本并控制
视觉样式，只通过这些查询读取 CTeX 的本地化编号与编号开关。这样可替代
SJTUBeamer 等下游对 `\CTEX@...` 私有变量的直接访问，而不让 ctex 接管 Beamer
模板层。

### fixskip 与紧跟标题的浮动体（#1100）

`fixskip=true` 时，`ctex/ctex-kernel.dtx`（`\CTEX@fixheadingskip`）在 beforeskip／afterskip
处执行 `\par`，把 `\prevdepth` 设为 -1000pt（TeX 的 `ignore_depth`，下一个盒子前不加行间胶），
并从间距中减去 `\parskip`。-1000pt 本应只作用于标题后的第一行，但 LaTeX 的 `\end@float` 在
竖直模式下保存并恢复 `\prevdepth`，就地放置时输出例程也不改主竖直列表的 `\prevdepth`。于是紧跟
标题、就地放置的 `[h]` 浮动体之后的第一行仍不加行间胶，与浮动体的距离比 `fixskip=false` 少一段行间胶。

v2.6.6 的修法（`1ab213e4`）：

- `\CTEX@fixheadingskip` 记下当时的 `\prevdepth` 和 `\@afterheading` 的执行次数，并置全局标记；
  `\CTEX@setheadingskip` 清除标记。
- 导言区结束时（`\ctex_at_end_preamble:n`，以免被之后载入的宏包覆盖）用 ctexpatch 加三个钩子：
  - `\CTEX@fixskip@afterheading@hook`（`\@afterheading` 开头）：执行次数加一。
  - `\CTEX@fixskip@float@begin@hook`（`\@xfloat` 开头）：全局标记为真、外部竖直模式、
    `\prevdepth` 为 -1000pt、`\lastnodetype` 不为 3（最后节点不是标尺，排除标题后的
    `\hrule`／`\titlerule`），并且满足“`@nobreak` 为真且次数差为 1”或“`@noskipsec` 为真且次数差
    小于 2”之一时，才认为 -1000pt 是 ctex 刚留下的。后一条对应 runin 标题：它执行
    `\@nobreakfalse`；差为 0 是它自己的 beforeskip 留下的，差为 1 是沿用前一个标题的。
  - `\CTEX@fixskip@float@end@hook`（`\end@float` 末尾）：`\@currbox` 已空时恢复记下的深度。
    只有就地放置时，`\@addtocurcol` 才用 `\box` 取空 `\@currbox`；浮动体被推到页顶、页底或后面的
    页面时不作改动。
- 恢复后的 `\prevdepth` 等于同一写法在 `fixskip=false` 时的值，测试也以此为判据。

为什么要靠旁证：-1000pt 是 TeX 与 LaTeX 共用的哨兵值，`\hrule`、`\nointerlineskip` 也会留下这个值，
而且都不清 `@nobreak`。`titlesec` 接管的标题不经过 `\CTEX@setheadingskip`，不会清除标记。LaTeX 的
`\addpenalty` 等代码直接比较 `\prevdepth = -1000pt`，所以也不能换成 ctex 私有的值。ctex 标题先
调用 `\CTEX@fixheadingskip`，再调用 `\@afterheading`，因此紧跟 ctex 标题时次数差为 1，中间隔着别的
标题时大于 1。只凭全局标记、`@nobreak` 和 -1000pt 判断的第一版（`5c35e236`）在 `ctexbook` +
`titlesec` 下相对 v2.6.5 回退。

已知限制见 `llmdoc/memory/doc-gaps.md`“fixskip”两节：标题后直接 `\nointerlineskip`，或 `\hrule`
后接 `\vspace`，仍会恢复深度；标题与就地放置的浮动体之间少一个 `\parskip` 是既有行为，#1100 未处理。
测试见 `ctex/test/testfiles/heading-fixskip02.lvt`、`heading-fixskip03.lvt`，过程见
`llmdoc/memory/reflections/1100-fixskip-float-prevdepth.md`。

## 命令补丁子系统 (ctexpatch)

### 核心接口

| 函数 | 行为 |
|------|------|
| `\ctex_patch_cmd_once:NnnnTF` | 替换命令体中第一个匹配 |
| `\ctex_patch_cmd_all:NnnnTF` | 替换所有匹配 |
| `\ctex_preto_cmd:NnnTF` | 在命令前追加钩子 |
| `\ctex_appto_cmd:NnnTF` | 在命令后追加钩子 |
| `\ctex_patch_cmd:Nnn` | 简化接口，含 ExplSyntax 处理 |

### 工作原理

将命令体字符串化 → 文本搜索替换 → 重新 rescan 定义。能处理 `\DeclareRobustCommand`、`\newcommand` 含可选参数等情形。

`\ctex_preto_cmd:NnnTF`／`\ctex_appto_cmd:NnnTF`（`ctex/ctex-auxpkg.dtx`，`\@@_hookto_cmd:Nnnnw`）按宏有无参数走两条路径：

- 无参数宏走 `\@@_hookto_cmd_parameterless:Nnnnw`，用 `\tex_edef:D` 直接拼接，原定义和钩子都不重新读入。
- 带参数宏走 `\@@_hookto_cmd_parameter:Nnnnw`，把钩子作为字符串接到替换文本上，再按调用者给出的 catcode 设置（第二个参数，例如 `\ExplSyntaxOff` 加 `@` 为字母）用 `\scantokens` 重建整个定义。所以钩子代码在这个设置下也必须读得出来：给 `\@xfloat` 这类带参数的宏加钩子时，钩子名要写成 `\CTEX@...@hook` 形式，不能含 `_` 和 `:`（#1100）。

## 第三方包兼容

### 延迟补丁模式

通过 `\ctex_at_end_package:nn` 在目标包加载后执行兼容补丁。

### 已知补丁目标

- varioref：中文 refname 本地化
- cleveref：附录编号语义兼容，提供 `patch/cleveref` 开关
- hyperref：driverfallback 按加载状态分支处理

### 用户开关

部分补丁通过 `\ctexset{ patch/<name> = false }` 允许用户关闭。

### 文档化的组合边界

Babel 与 biblatex 不属于上述运行时补丁目标。CTeX 不载入或检测这两个包，也不改写
它们的私有命令；
用户手册第 11 节提供的是只使用公开接口的组合方法：Babel 保存语言状态，用户可在
`\extraschinese`、`\extrasenglish` 等语言钩子中用 `\ctexset` 切换章节标签、编号
和图表名称；biblatex 则继续
拥有 locale strings 与 heading，按需求使用 `title`、`\DefineBibliographyStrings`
或 `\defbibheading`。CTeX 的 `bibname` 面向标准 `thebibliography`，不是所有
biblatex 标题的总开关。

这一区分意味着“手册给出可编译 MWE”不等于新增运行时集成。Polyglossia 使用不同的
语言接口，还可能与 xeCJK 的字符间机制冲突，不能从 Babel 示例类推兼容承诺。

## 实验性接口

ctex 使用 `experiment/` 命名空间暴露尚未在所有引擎间拥有完全等价语义的功能：

| 接口 | 说明 |
|------|------|
| `experiment/font-size-system` | 字号数据源选择 |
| `experiment/CJKecglue` | 统一跨引擎 CJKecglue：XeTeX→xeCJK CJKecglue，LuaTeX/upTeX→xkanjiskip，pdfTeX→warning |
| `experiment/halfright-prebreakpenalty` | xeCJK 专属：HalfRight 类行首禁则 |

### 设计哲学

功能若不能在全部引擎下提供等价的可观察行为，则保持在 `experiment/` 命名空间中，不提前承诺为正式主接口。这允许 ctex 渐进扩展能力而不破坏跨引擎接口契约。
