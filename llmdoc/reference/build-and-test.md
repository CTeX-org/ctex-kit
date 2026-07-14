# 构建与测试参考

## 统一构建系统

`ctex-kit` 的现代包大多使用 `l3build`，并通过各自目录下的 `build.lua` 声明模块元数据，再用 `dofile("../support/build-config.lua")` 继承项目级统一行为。见 `ctex/build.lua:71`、`xeCJK/build.lua:151`。

对于理解构建行为，优先区分两层：

- 包级 `build.lua`：描述该包自己的源码、安装文件、测试目录、引擎与额外钩子。
- `support/build-config.lua`：定义整个仓库共享的 l3build 覆写、目标扩展和发布期处理。

## 本地任务入口：根 Makefile

仓库根目录提供一个 `Makefile`（PR #888）作为本地任务统一入口，封装各包的 `l3build` 调用，避免反复 `cd <pkg> && l3build <verb>`。命名约定为：

- `make <verb>`：等价于 `make <verb>-all`，对全部包执行。
- `make <verb>-all`：显式对全部 `l3build` 包执行。
- `make <verb>-<pkg>`：只对指定包执行，例如 `make check-xeCJK`、`make ctan-ctex`。

覆盖的 verb 为 `doc` / `unpack` / `ctan` / `check` / `clean`，分别对应 `l3build doc` / `unpack` / `ctan` / `check` / `clean`。包列表由 `Makefile` 顶部的 `L3BUILD_PKGS` 维护（`xeCJK ctex CJKpunct xCJK2uni xpinyin zhlineskip zhmetrics zhmetrics-uptex zhnumber zhspacing jiazhu`），其中 `gbk2uni` 不走 `l3build`，而是委托到其子 `Makefile`。

此外还有两个 git workflow 入口：

- `make hooks`：一次性安装 git hooks（`git config core.hooksPath .githooks`）。
- `make check-pr-ci`：手动触发 PR CI watch + review 抓取（同 `pre-push` 调用的 `./.githooks/check-pr-ci.sh`）。

以及一个 release 入口：

- `make tag <pkg>-v<ver>[-rc<N>]`：在当前 HEAD 打**本地 annotated tag，不 push**。push 需手动 `git push origin <tag>`，push 后由 `release.yml` 自动跑 CTAN 打包 + GH Release（见 `llmdoc/guides/release-workflow.md`）。不自动 push 是故意设计，让操作者在 push 前最后核对 tag 落点、版本号 / `\changes` 改动是否齐全。tag 名经正则校验为 `<pkg>-v<X>.<Y>[.<Z>][<letter>][-rc<N>]`（`<pkg>` 须是 `L3BUILD_PKGS` 之一，与 `release.yml` tags trigger 对齐），不合法或本地已存在同名 tag 直接报错；远古无 `v` 前缀的历史 tag（`ctex-1.02c` / `jiazhu-beta` / `zhspacing-<date>` 等）不再支持。

注意 `make check`(全包回归)单包动辄 8min+(`make check-ctex` 经 4-engine 并行已从 ~20min 压到 ~8min),本地按需用。hook 的详细说明见 `.githooks/README.md`。

## `support/build-config.lua` 的角色

`support/build-config.lua` 是仓库的构建中枢，主要负责以下稳定机制：

### 1. 工具默认值

它统一设置：

- `supportdir`
- `unpackexe = "luatex"`
- `typesetexe = "xelatex"`
- `makeindexexe = "zhmakeindex"`
- `checkopts` / `typesetopts`
- 二进制文件后缀列表

见 `support/build-config.lua:3-11`。

### 2. 文档排版循环

自定义 `typeset()` 会在多轮 TeX / biber / bibtex / makeindex 之间循环，直到 `.aux`、`.bbl`、`.glo`、`.idx`、`.hd` 的 MD5 不再变化，避免文档尚未收敛就停止。见 `support/build-config.lua:27-57`。

### 3. Git 版本展开

`extract_git_version()`、`expand_git_version()`、`replace_git_id()` 会抽取最近一次 git 提交信息，替换源文件中的 `\GetIdInfo` 区段，并把生成后的 `.id` 信息用于打包。见 `support/build-config.lua:70-115`。

### 4. 测试基线保存

`saveall()` 为所有 `.lvt` 保存验证日志，并在非标准引擎的 `.tlg` 与标准引擎结果一致时删除冗余文件。见 `support/build-config.lua:131-166`。

### 5. 对 l3build 目标的钩子化覆写

它重写并包装了：

- `doc`
- `bundleunpack`
- `install_files`
- `copyctan`

因此很多包级 `*_prehook` / `*_posthook` 逻辑只有结合这个共享文件才能正确理解。见 `support/build-config.lua:170-214`。

### 6. CTAN 上传配置生成器

`ctex_kit_uploadconfig{...}` 为接入 CTAN 投递的包生成 `uploadconfig` 表，`uploader` / `email` 不落 git，而是在 build.lua 加载时通过 `os.getenv("CTAN_UPLOADER")` / `CTAN_EMAIL` 从环境读取。目前 `xeCJK` / `ctex` 的 `build.lua` 已接入，供 `release-ctan-upload.yml`（stage 2 CTAN 投递）的 `l3build upload` 使用。完整投递流程见 `llmdoc/guides/release-workflow.md`。

## 各包 `build.lua` 的标准结构

现代子包的 `build.lua` 通常遵循同一骨架：

1. `module = "..."`
2. 设定 `sourcefiles`、`unpackfiles`、`installfiles`
3. 设定 `typesetsuppfiles`、`gitverfiles` 等文档/版本相关字段
4. 指定 `testfiledir`、`testdir`、`checkengines`、`stdengine`
5. 必要时补充 `checkdeps` 或自定义 hook
6. 末尾 `dofile("../support/build-config.lua")`

例如 `ctex/build.lua` 还声明了：

- `packtdszip = true`
- `tdslocations` 覆盖 engine/fontset/heading/scheme 等安装路径
- `checkdeps = {"../xeCJK", "../zhnumber"}`
- `checkengines = {"pdftex", "xetex", "luatex", "uptex"}`
- `checkinit_hook()` 把依赖包安装文件复制到测试目录

见 `ctex/build.lua:1-71`。

`xeCJK/build.lua` 则在标准骨架之上增加 TECkit 映射生成逻辑，是”共享框架 + 包级特化”的典型例子。见 `xeCJK/build.lua:1-151`。

`zhmetrics-uptex/build.lua` 已从原先的自定义打包脚本迁移为标准 l3build 结构（旧脚本保留为 `build-legacy.lua`）。它声明 `module = “zhmetrics-uptex”`、`packtdszip = true`、`unpackfiles = {}`（无 `.dtx` 需要解包）、`tdslocations` 显式指定 TDS 安装路径。由于该包没有 `.dtx` 文档源且不使用 `support/build-config.lua`，其构建独立于主干共享框架。

## 测试框架

## `.lvt` / `.tlg` 机制

回归测试主要使用 LaTeX3/l3build 的标准测试模型：

- `.lvt`：测试输入
- `.tlg`：期望日志输出
- 引擎差异时可使用 `name.<engine>.tlg`

`ctex/test/testfiles/` 仍是该仓库最完整的回归测试目录。测试文件使用 `\START`、`\END`、`\TEST{...}{...}` 之类标准测试宏组织案例；运行 `l3build check` 后会把实际日志与 `.tlg` 对比。若某引擎结果与标准引擎一致，`saveall()` 会清理重复的引擎专属 `.tlg`。

截至 #275，排除 `build.lua` 中两个已知不兼容用例后，`ctex/test/testfiles/` 有 184 个会运行的 `.lvt` 回归测试输入，形成仓库中密度最高的中文排版主干测试集。与此前约 69 个测试的状态相比，`ctex` 已从“若干关键路径抽样覆盖”提升为“主类、标题、字号、版式、兼容补丁与跨引擎行为的系统性回归网”。

以下包接入了独立的 `testfiles/` 回归目录：

- `ctex`
- `xeCJK`
- `zhnumber`
- `CJKpunct`
- `zhlineskip`

这意味着这些子包已不再只依赖主包依赖链覆盖，修改它们时可以直接在各自目录运行 `l3build check`。

### `ctex` 主测试目录当前覆盖面

本轮扩展后的 `ctex` 主测试目录已形成几组稳定覆盖簇：

- `ctexset-*`：覆盖分组作用域、导言区设置、meta key、非法输入、空值重置、多键组合与覆盖顺序，例如 `ctex/test/testfiles/ctexset-scope01.lvt`、`ctex/test/testfiles/ctexset-preamble01.lvt`、`ctex/test/testfiles/ctexset-invalid01.lvt`。
- `cjkfntef-luatex01/02`：分别覆盖 LuaTeX 下后续 `CJKfntef` 请求被禁载且字体仍可配置，以及包先载入时触发 critical 的分支。fatal-path 测试截获目标 `\msg_critical:nnn` 后立即结束，避免继续进入已污染状态产生无关的 LuaTeX-ja 二次错误。
- `heading-*`：集中覆盖 heading key 簇，包括 `break`、`afterskip`、`beforeskip`、`hang`、`runin`、`afterindent`、`numbering`、`fixskip`、`pagestyle`、`aftertitle`、`titleformat`、`tocline`、`starred`、`longtitle`、`defaults`、`name`、`format/+` 追加语法与 `indent` 等；`heading-query01` 另以 `ctexbeamer` 覆盖 part/section/subsection 的编号、完整标签、编号开关、局部动态设置与分组恢复，已从“章节标题可用”扩展到“标题系统各键及公开查询接口的契约级回归”。
- `scheme-*`：覆盖 `scheme=plain` / `scheme=chinese` 的默认行为差异与标题输出差异，例如 `ctex/test/testfiles/scheme-plain01.lvt`、`ctex/test/testfiles/scheme-compare02.lvt`。
- 类与文档结构：`ctexrep01.lvt`、`ctexbeamer01.lvt`、`beamer01.lvt`、`beamer02.lvt`、`matter01.lvt`、`sub3section01.lvt`、`ctex-noheading01.lvt` 等覆盖 `ctexrep` / `ctexbook` / `ctexbeamer` 基础行为、`heading=true`、三级节、`frontmatter` / `mainmatter` / `backmatter`。
- 字体与字号联动：`ccwd-selectfont01.lvt`、`ccwd-zihao01.lvt`、`ziju-scope01.lvt`、`ziju-edge01.lvt`、`ctexsetfont01.lvt`、`zihao-sizes01.lvt`、`zihao-parindent01.lvt`、`fontfamily01.lvt`、`fontfamily02.lvt`、`cjkfamily-default01.lvt`、`cjkfamily-default02.lvt` 等覆盖 `\ccwd`、`\ziju`、`\CTEXsetfont`、`\zihao` 全尺寸、段首缩进与 CJK 字体家族切换。
- 行距与间距：`linespread01.lvt` 至 `linespread03.lvt`、`linespread-scope01.lvt`、`linestretch-interact01.lvt`、`punct.lvt`、`punct-width01.lvt`、`cjkglue-width01.lvt`、`ccglue01.lvt`、`ccglue02.lvt` 覆盖 `linestretch` / `linespread` 交互、标点宽度与 CJK glue 宽度。
- 章节外围组件：`caption-names01.lvt`、`caption-names02.lvt`、`footnote01.lvt`、`part-format01.lvt`、`abstract01.lvt`、`toc.lvt`、`toc-book01.lvt`、`lof-lot01.lvt`、`bibliography01.lvt`、`index01.lvt` 覆盖 caption 名称、本地化名称、脚注、part、摘要、目录、图表目录、参考文献与索引标题路径。
- 版式与接口兼容：`geometry01.lvt`、`numberline01.lvt`、`thesection01.lvt`、`twocolumn01.lvt`、`list01.lvt`、`verbatim01.lvt`、`quote01.lvt`、`minipage01.lvt`、`maketitle01.lvt` 覆盖常见环境、双栏与目录编号接口。
- 第三方包和交叉引用兼容：`hyperref01.lvt`、`hyperref-driverfallback.lvt`、`hyperref-headings.lvt`、`hyperref-pdfstringdef01.lvt` 至 `03`、`amsmath01.lvt`、`label-ref01.lvt` 等覆盖 `hyperref` / `amsmath`、书签字符串与 `label` / `ref` 兼容。
- 环境、版本与引擎分流：`encoding01.lvt`、`fontset01.lvt`、`ctex-version01.lvt`、`engine-detect01.lvt`、`today01.lvt`、`today-format01.lvt`、`parskip01.lvt`、`fontsize-c5size01.lvt`、`depth-counter01.lvt`、`counter01.lvt`、`zhnumber*.lvt` 等覆盖编码、fontset/version、引擎检测、日期格式、`parskip`、`c5size`、`secnumdepth` / `tocdepth`、`zhnumber` 与计数器行为。
- 综合配置回归：`ctexset-full01.lvt` 作为全套 `ctexset` 综合配置入口，用于验证多个 key 组合时的整体输出契约。

### `ctex` 新增回归测试的稳定技术模式

这一轮扩展形成了几条值得保留的测试约束：

1. 默认优先 `fontset=fandol`。新增测试普遍显式传入 `fontset=fandol`，以避免依赖 CI 或本地系统字体；这已经是 `ctex` 回归测试的首选基线模式。
2. `ctex` 必须按四引擎维护回归视图。`ctex/build.lua` 固定 `checkengines = {"pdftex", "xetex", "luatex", "uptex"}`，因此新增测试时应预期可能需要保存引擎专属 `.tlg`，尤其是 `\loggingoutput`、字号/度量与本地化输出相关场景。
3. LuaTeX 字体缓存噪声要先预热再比对。凡测试涉及 `\zihao`、`\ccwd`、字体切换或 `1em`/盒子宽度日志时，应像 `ctex/test/testfiles/ccwd-selectfont01.lvt`、`ctex/test/testfiles/zihao-sizes01.lvt`、`ctex/test/testfiles/linestretch-interact01.lvt` 那样，在 `\OMIT ... \TIMO` 区间先做一次字体实例化，避免 LuaTeX 首次加载字体缓存时把一次性噪声写进基线。
4. `\loggingoutput` 场景要按引擎看待基线。像 `ctex/test/testfiles/heading-break01.lvt`、`ctex/test/testfiles/ctexset-preamble01.lvt` 这类依赖分页、纵向列表或输出例程日志的测试，不同引擎更容易产生结构性差异；保存基线时不要假定单一 `.tlg` 足够。
5. 避免不安全展开的日志写法。新增测试不应使用 `\tl_log:x { \f@family }` 或 `\dim_log:n { \f@size pt }` 这类展开不安全模式；若要记录字体家族或字号相关状态，优先用 `\cs_log:c` 读取稳定控制序列，或用 `\dim_log:n { 1em }`、盒子宽度、`\ccwd` 等可比度量替代。
6. 新测试进入并行快照前必须先变成 git 已跟踪路径。`scripts/check-parallel.sh` 以 `git ls-files` 构造每个引擎的独立包快照；完全未跟踪的 `.lvt` / `.tlg` 不会进入 `make check-ctex`。运行前应确认 `git ls-files -- <path>` 能列出新文件，或直接用不经过快照的包内 `l3build check` 做定向验证。
7. `l3build` 选项必须放在测试名之前。定向静默检查应使用 `l3build check -q <testname>`；`l3build check <testname> -q` 会把尾部 `-q` 当成另一个测试名。

这些模式说明：`ctex` 回归测试不只是“补一些 .lvt 文件”，而是已经沉淀出一套面向多引擎中文排版的可复用测试方法学。

此外，现在还维护多个专项测试配置：

- `ctex/test/config-cmap.lua`：CMap 相关测试
- `ctex/test/config-contrib.lua`：contrib 目录相关测试
- `ctex/test/config-ctxdoc.lua`：`support/ctxdoc.cls` patch 健康检查，测试目录为 `ctex/test/testfiles-ctxdoc/`

其中 `config-ctxdoc` 使用 `testfiledir = "./test/testfiles-ctxdoc"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，并通过 `checksuppfiles = {"ctxdoc.cls"}` 把本地 `support/ctxdoc.cls` 复制到 check 目录，确保测试覆盖仓库中的当前实现，而不是系统安装版本。该配置现有两类测试：`patch-health.lvt` 传入 `fontset=fandol` 后加载 ctxdoc，验证 patch 在 nonstop 模式下也能以致命错误暴露失败；`resize-function.lvt` 使用 `\loggingoutput` 固定函数条目的节点结构，覆盖 Added 日期、rEXP、pTF 与长函数名的等差档位/极端自适应水平压缩，防止日期行被连带缩放或可展性标记越过边注宽度。

ctxdoc 自 #963 起明确要求 l3doc 2026-06-18；本地 `config-ctxdoc` 在更旧版本上会经 `\ctex_patch_failure:N` 直接终止。l3doc 由 TeX Live 的 `l3kernel` 包提供，遇到该门禁时应更新 `l3kernel`，并按下文 usertree 双步同步流程重建 `xelatex` format，避免新类文件与旧 format 中的 expl3 支持层不匹配。

`config-contrib` 也是 monorepo 中检验跨包模板回归的稳定下游入口。xeCJK 只要修复了可能影响实际排版输出的行为，就应在 `ctex/` 目录补跑 `l3build check -c test/config-contrib -q`；若失败，先检查 diff，通常意味着需要用 `l3build save -c test/config-contrib -e xetex <testname>` 同步更新受影响模板的基线。xeCJK #803 后 `pkuthss` 基线更新已验证这是常见联动，而非无关失败。

## 引擎矩阵

`ctex` 的标准测试引擎是：

- `pdftex`
- `xetex`
- `luatex`
- `uptex`

其中 `stdengine = "xetex"`，见 `ctex/build.lua:44-53`。因此：

- XeTeX 结果是主基线
- 其他引擎只在确有差异时保留独立 `.tlg`

新增的卫星包测试矩阵如下：

- `xeCJK`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，见 `xeCJK/build.lua`。现有回归已覆盖字体命令作用域、第三方包 hook、零宽格式字符过滤、`\lstinline` 在宏参数中的 `#` catcode 保持，以及 `\special`/颜色 whatsit 对 glue 恢复链的影响等 XeTeX 专属行为；例如 `xeCJK/testfiles/zwchars01.lvt` 用 6 个宽度对比用例验证 U+200B/U+200C/U+200D/U+2060/U+FEFF 不会打断字符分类，也不会额外插入 `CJKglue` / `CJKecglue`；`xeCJK/testfiles/color01.lvt` 则用 5 个盒子宽度对比用例验证 `\textcolor` 包裹 Default、单个 CJK、单个数字、混合 Latin 内容与嵌套颜色组时，Boundary→Default 和 Boundary→CJK 过渡中的 `CJKecglue` / `CJKglue` 都能在 whatsit 节点后被正确恢复。`xeCJK/testfiles/jamo-cj01.lvt` 覆盖 Hangul L/V/T 分类、音节内 shaping 与音节间 `CJKglue`、分解音节 listings 单元宽度、CJ strict 分组/reset 语义、penalty 顺序及 fntef 专用转移；`listings-hash01.lvt` Test 6 则覆盖非 `#` 的 catcode 6 token 保留原字符码（#879）。

  标点模型的专门入口是 `xeCJK/testfiles/punctuation-model-975.lvt`：它用独立 TC/JP/SC 字体面覆盖 Kaiming 宽度、居中标点优化、`FullLeft→FullRight` 自然空白、显式 kern 与 global-setting 优先级、nobreak、旧样式和反方向不变量。`\newCJKfontfamily` 的字体实例化应在 `\START` 前预热；否则 `fontspec` 首次按需载入字体族时产生的一次性 Info 会混入规范化日志，形成依赖环境的 `.tlg` 噪声。
- `zhnumber`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"pdftex", "xetex", "luatex"}`，见 `zhnumber/build.lua`。
- `CJKpunct`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `CJKpunct/build.lua`。CJKpunct 仅工作在 pdfTeX (CJK 宏包) 路线下。
- `zhlineskip`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `zhlineskip/build.lua`。zhlineskip 已完成 DocStrip & L3 重构（PR #892 / #373），现以 `zhlineskip.dtx` 为单一源：`unpackfiles = {"zhlineskip.dtx"}` 解包出 `.sty`、`installfiles = {".sty", ".ins"}`、`sourcefiles = {".dtx", "*.pdf"}`、`demofiles = {"zhlineskip-test.tex"}`，版本号集中在 `build.lua` 顶部由 `update_tag` 钩子回写 `.dtx` 的 `\GetIdInfo` 行。测试使用 vbox 尺寸捕获策略验证行距行为。

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。

因此，修改 `xeCJK` 与 `zhnumber` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

xeCJKfntef 的线条类问题还要区分“节点尺寸”和“shipout 相位”。`\leaders`、`\cleaders` 与 `\xleaders` 可以拥有完全相同的 glue、盒宽和总命令宽度，却因重复盒的对齐或余量分配方式不同而画在不同横坐标；所以宽度比较不能单独作为 #531/#967 一类回归的 oracle。稳定测试至少应在非零水平起点下用节点日志断言 leader 类型，并用 XDV/PDF 坐标或高分辨率栅格图确认线条首尾相对正文对齐；`subtract` 要单独确认两端等量缩短，周期图案还要检查相邻 CJK 片段接缝。`xeCJK/testfiles/fntef-underline-offset.lvt` 探测 `\CJKunderline` 的非零起点节点，并断言其余五个线型命令普通/`subtract` 路径选择 8 次 `\cleaders` 与 2 次 `\xleaders`；另以多汉字普通/`subtract` 节点链约束 `\CJKunderwave` 在 CJK→CJK 分片间保持 `\xleaders`。既有 `fntef-underline01`、`fntef-linebreak01` 基线继续约束标点和换行节点结构。

## CI/CD 配置

GitHub Actions 工作流当前包含以下主线：

- `.github/workflows/test.yml`：跨平台测试工作流
- `.github/workflows/check-doc.yml`：PR 门禁 workflow, 跑 `l3build doc` 抓文档 dtx→PDF 可编译性 (#935); 与 test.yml 分工 (后者只跑 `l3build check`, 不 typeset dtx), 覆盖 9 个包 (zhspacing 因深层依赖问题暂不覆盖, 见下), 单 engine 单 OS. TL bypass cache key 与 test.yml 完全共享; 详见 [[935-check-doc-vs-ctan]]
- `.github/workflows/check-tag.yml`：PR 门禁 workflow, 对支持 l3build tag 的包 (zhlineskip / ctex) 跑 `l3build tag` + `git diff --exit-code`, 验证源文件版本 stamp 与 build.lua 的 version 同步 (#937); 与 release.yml 的三方版本校验构成双闸, 详见 [[937-version-single-source-l3build-tag]] 与下方"版本管理"章节
- `.github/workflows/check-changelog.yml`：PR 门禁 workflow, 校验 5 个包 (ctex/xeCJK/zhlineskip/zhmetrics/zhnumber) 的 `CHANGELOG.md` 与 `.dtx` 的 `\changes` 条目是否同步 (#961); 与 `check-tag.yml` 同一「生成物新鲜度校验」模式, 详见下方"生成物新鲜度校验模式"小节与 [[961-changelog-gate-no-write-perm]]
- `.github/workflows/lint-test-files.yml`：`.lvt` 测试文件 lint，PR 触发（`paths` 限定 `**/*.lvt` 及检查脚本本身），检查新增行在 `\ExplSyntaxOff` 段的 `\TEST`/`\BEGINTEST`/`\TYPE` 大括号内是否误用 `~`（#893）；与 `.githooks/pre-commit` 共用 `.githooks/check-test-tilde.sh`，约定细节见 `llmdoc/reference/coding-conventions.md`
- `.github/workflows/release.yml`：按发布 tag 构建并创建 GitHub prerelease 的自动化工作流（stage 1）
- `.github/workflows/release-ctan-upload.yml`：CTAN 正式投递工作流（stage 2），仅 `workflow_dispatch`，按包进 `ctan-release-<module>` environment 门控，详见 `llmdoc/guides/release-workflow.md`
- `.github/workflows/agentic-pr-review.yml`：PR 自动审查工作流，由 `pull_request_target` 事件触发，使用 Claude Code 执行代码审查并发表评论；含并发控制，同一 PR 仅保留最新 run
- `.github/workflows/agentic-llmdoc-updater.yml`：llmdoc 文档自动更新工作流，每天北京时间 5:00 定时触发或手动触发；会先关闭已有的过期 llmdoc PR 并扩展时间范围
- `.github/workflows/agentic-patrol.yml`：仓库巡查工作流，每天北京时间 08:00 (UTC 0:00) 触发一次，监控 CI 状态、扫描未处理 Issue 并自动分发处理

#### agentic 工作流的来源与频率约束

所有 `agentic-*.yml` 在 job 级使用 `if: ${{ github.repository == 'CTeX-org/ctex-kit' }}` 把 fork 仓库的定时 / `workflow_dispatch` 调度直接挡在 runner 分配之前（#875 / PR #876）。这是 job 级 if，不是 step 级——只有 job 级才能避免 fork 主消耗 Actions 配额并避免误向真实仓库写入 issue/comment。

`agentic-patrol.yml` 的 `schedule` 频率在 #874 中从“每 4 小时一次”调整为“每天一次北京时间 08:00”。新增 agentic 工作流时，频率默认值应取“每天一次”而非更高频；除非有不能等一天的工程动机，否则不要回到 4 小时级或更密。详见反思 [[874-876-agentic-fork-shielding-cron]]。

### 测试工作流：`.github/workflows/test.yml`

当前稳定事实如下：

- 触发条件：`pull_request`、`push`、定时 `schedule`、`workflow_dispatch`
- 操作系统矩阵：`ubuntu-latest`、`macos-latest`、`windows-latest`
- TeX Live 安装：`TeX-Live/setup-texlive-action@v4`
- 依赖包清单：`.github/tl_packages`
- 当前 CI 拆为 5 个独立 caller job（`test-ctex` / `test-xeCJK` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip`），各自 `uses: ./.github/workflows/_test-package.yml` 在 3 个 OS 上并行测试；`changes` 阶段用 paths-filter 决定 PR 上跑哪些 caller

见 `.github/workflows/test.yml`。

#### CI 字体策略

当前 CI 已把“字体可用性”视为稳定基础设施，而不是临时环境细节。工作流中实际依赖的字体层次包括：

- `Source Han Serif` OTC：主 CJK 文档字体，供 xeCJK / 文档 driver 使用。
- `Noto Sans CJK` / `Noto Serif CJK` OTC：跨平台 CJK 基础字体。
- `HanaMinB`：作为 `SimSun-ExtB` 缺失时的 Ext-B fallback，覆盖扩展 B 区字符。
- `Noto Sans Symbols 2`：`xunicode-symbols.tex` 五级符号字体回退链的第二级（参见下文）。
- `FreeSerif`：通过 `apt install fonts-freefont-ttf` 提供，作为 `xunicode-symbols` 驱动的**主字体**与符号字体回退链起点。
- `FandolSong` / `FandolFang`：由 TeX Live 自带，主要作为无需系统字体下载时的稳定后备。

Linux CI 在手工安装或解压字体后，必须执行 `fc-cache -f` 刷新 fontconfig 缓存；否则即使字体文件已落盘，XeTeX / fontspec 仍可能在同一 job 中看不到新字体。

这套策略对应最近文档驱动兼容性修复的两个关键约束：

- `xeCJK/xeCJK.dtx` driver 不再假定 CI 上一定存在 `SimSun-ExtB`，而是通过 `\IfFontExistsTF` 回退到 `HanaMinB`。
- `xunicode-symbols.tex` 不再使用“整段单字体 if-else”模式，而是采用**逐字符多级字体回退链** `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans`（#878 / PR #886）：每个 codepoint 通过 `\tex_iffontchar:D \tex_font:D #1` 测试当前字体，未命中则 `\cs_if_exist_use:N` 切下一级候选。CI 端的 `fonts-freefont-ttf` 与下载的 `Noto Sans Symbols 2` 是回退链的**最低保证**而非全部，确保发布产物 PDF 完整；用户机器只要装有链上任意覆盖目标字符的字体即可正常排版。设计细节见 [[architecture/xecjk-architecture]] 中 `xunicode-symbols.tex` 一节与反思 [[878-xunicode-symbols-multilevel-fallback]]。

#### `.github/tl_packages` 维护约束

`.github/tl_packages` 是 CI 中 TeX Live 依赖的显式白名单。新增或扩展回归测试时，如果测试输入引入了新的 LaTeX 宏包依赖，必须同步更新这个文件；否则本地环境可能因为已有完整 TeX Live 而通过，但 GitHub Actions 会在精简安装环境里因缺包失败。

PR #799 暴露了一个稳定信号：`xeCJK/testfiles/listings-hash01.lvt` 新增 `\usepackage{listings}` 后，如果 `.github/tl_packages` 中未加入 `listings`，则 CI 会在 `-H`（halt-on-error）模式下于缺包处立即终止。此时生成的测试日志可能是空的 `.xetex.log`，后续表现为 `.tlg` 基线比对失败，但真正根因并不是输出差异，而是编译根本没有继续到产生日志内容的阶段。

因此，遇到“CI 中 `.log` 为空 / `.tlg` 比对失败，但本地看起来不像回归输出差异”的现象时，应优先检查两件事：

- 新增测试是否加载了 CI 尚未安装的宏包；
- `.github/tl_packages` 是否遗漏了相应依赖。

CI 现在的结构 (PR #899 后):

**阶段 0 — `changes` job (paths filter):**
PR 触发时跑 `dorny/paths-filter@v4`, 检测哪些包目录被改, 输出 5 个 bool (ctex / xeCJK / zhnumber / CJKpunct / zhlineskip). push / schedule / workflow_dispatch 触发时 filter 不影响, 全跑. 同时把 `TL_VERSION` (顶层 env, 如 `'2026'`) 作 `tl-version` output 透传给 caller (workflow_call inputs 不能直接引用顶层 env).

依赖反查: ctex 依赖 xeCJK + zhnumber, 所以改 xeCJK 或 zhnumber 同样会让 ctex job 跑. 公共改动 (`.github/workflows/test.yml`, `.github/workflows/_test-package.yml`, `scripts/check-parallel.sh`, `support/**`, `Makefile`) 让所有 5 个包都跑.

**阶段 0.5 — `warmup-tl` job (cache 预热):**
`needs: changes`, `matrix.os = [ubuntu, macos, windows]` 3 job 并行. 每 OS 1 个 job 跑 setup-texlive-action 装 + update, 把 cache 填到当前 TLnet 最新 baseline. 这是**唯一会真装 install-tl** 的地方 — 收敛 mirror 请求, 避免 5 caller × 3 OS = 15 路并发轰炸 mirror 触发 ETIMEDOUT.

3 次 retry 换不同 mirror: try 1 `ctan.math.illinois.edu` (timeout 10min), try 2 `ftp.fau.de` (timeout 10min), try 3 `mirror.ctan.org` 自动重定向 (timeout 30min). try 1/2 短超时让换 mirror 反应快.

历史: 早期尝试 `SETUP_TEXLIVE_ACTION_FORCE_UPDATE_CACHE=1` 让 warmup 把 update 后的 TL 保到 uniqueKey (= primaryKey + uuid), 让 caller 跳过 update 省 70s/caller. 实测**不生效** — GH actions/cache 在 restoreCache 时按 restoreKeys 数组的 primaryKey 精确匹配优先, caller 命中老的纯 primaryKey entry (无 uuid), 跳过 warmup 的 uniqueKey. 现在 caller 端仍 `update-all-packages: true` 自己跑 update 才能与仓库 `.tlg` baseline 一致. 见 `_test-package.yml` head 注释.

**阶段 1 — 5 个 caller job 并行 (uses reusable workflow):**
`test-ctex` / `test-xeCJK` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip` 五个 caller job, 各自 `uses: ./.github/workflows/_test-package.yml`, 传 `pkg` / `event-name` / `tl-version` 输入. 各 caller `needs: [changes, warmup-tl]` + `if: needs.changes.outputs.<pkg> == 'true'` 控是否跑.

每个 reusable workflow 实例内部 `strategy.matrix.os = [ubuntu-latest, macos-latest, windows-latest]`, 三个 OS 并行. `fail-fast: false` 一个失败不取消其它.

之所以拆 5 caller job 而非用 `matrix.pkg` 维度, 是为了消除 GH Actions 在动态 name (`${{ matrix.pkg }} on ...`) strategy expansion 前注册 placeholder check 用未渲染模板作 name 然后 cancel 的"幽灵 job"行为.

每个实例步骤:
- 装 TL: 2 次 retry 换 mirror (try 1 illinois, try 2 fau.de), 各 timeout 15min. 即便 cache hit, setup-texlive 在 `Updating packages` 阶段仍会联网拉 tlmgr db checksum, 单 mirror 网络抖动时这步可能失败 — PR #899 实测 windows 命中. retry 2 次降低这种 transient failure 让 job 挂的概率.
- 装字体 (`actions/cache@v6` 缓存 `$GITHUB_WORKSPACE/.font-cache/`, key 含 `_test-package.yml` hash; zip 解完即删只留 ttc)
- 跑 `Test <pkg>` (case 分支):
  - `ctex`: `../scripts/check-parallel.sh` + `CONFIGS` 三个 config, 4 engine 并行. wall-clock ~5–8min.
  - `zhlineskip`: 失败时 dump `build/test/*.log` 前 80 行.
  - 其他 (xeCJK / zhnumber / CJKpunct): `l3build check -q` 直接跑.

**阶段 2 — `test-result` job (汇总):**
`needs: [warmup-tl, test-ctex, test-xeCJK, test-zhnumber, test-CJKpunct, test-zhlineskip]`, 检查每个 caller 结果(success / skipped 都 OK; 其他 fail). 把 warmup-tl 也算进去, 避免 warmup 失败 → 5 caller skipped → test-result 误绿. branch protection 只盯这一个 status check 即可.

失败时 artifact 上传 (`actions/upload-artifact@v7`): `${{ inputs.pkg }}/build/**/*.diff`, artifact name 含 pkg 名 + OS 区分.

### 文档编译门禁：`.github/workflows/check-doc.yml`

PR 阶段专用门禁 (#935), 补 test.yml 的"文档 dtx→PDF 可编译性"维度. 只在 `pull_request` 触发. 结构:

- **`changes` job**: 精简版 paths-filter, 9 个 bool (ctex/xeCJK/CJKpunct/zhnumber/xCJK2uni/xpinyin/zhmetrics/zhmetrics-uptex/zhlineskip). **无依赖传递** — `l3build doc` 只 typeset 自身 `typesetfiles`, xeCJK 变动不会跑 ctex 的 doc.
- **9 个 caller job**: 每包一个 `uses: ./.github/workflows/_check-doc-package.yml`, job 级 if 保证未受影响包不启动 runner (仿 test.yml + _test-package.yml 的 caller-per-pkg 结构, 避开 matrix.pkg 幽灵 cancelled job).
- **`check-doc-result` 汇总**: 与 test-result 同构, branch protection 单点盯.

TL cache 共享: 用同一个 `tl-bypass-<os>-<ver>-<week>-<hash>` key (与 test.yml warmup-tl / release.yml 完全一致). PR 触发时 test.yml warmup-tl 同 head sha 并行填 cache, 本 workflow 大多数情况 100% cache hit; cache miss 走 setup-texlive-action fallback (单 mirror illinois pin, 抖动时 rerun --failed).

Verify 层: `scripts/verify-doc-output.sh` 按 `typesetfiles` 逐 PDF 检查 `build/doc/*.pdf` 存在 + `%PDF` magic + `>= 1024` 字节最小大小 (防 dvipdfmx fatal 后残留 stub `%PDF` header). `typesetfiles={}` 的包 (zhmetrics-uptex) 期望零 PDF 单独短路通过.

#### 3 个包的 CI-only 特殊处理

首轮 CI 暴露 3 包 typeset 缺陷 (从未在 CI 上被 typeset 过), 已在同 PR 一并修复:

- **xpinyin**: `xpinyin.dtx:179` `\newfontfamily{TeX Gyre Adventor}` 走 fontconfig friendly name. TL 装了 tex-gyre 但字体不在 fontconfig 索引 → workflow 加 `/etc/fonts/conf.d/09-texlive-opentype.conf` 让 fc-cache 扫 TL opentype/truetype 目录. 无条件执行, 别的包只是索引多几百字体.
- **zhmetrics**: TL zhmetrics 包只装 gbk/unicode 分片 tfm, **不含**顶层 `zhmCJK.tfm`/`.map` — 这两个是 `zhmCJK.lua map` 在 `copyctan_posthook` 里生成后 CTAN admin 手工上传独立文件, TL 打包时未纳入. `zhmCJK.dtx` typeset 请求 `zhm35b` 走 fontname map 失败. 修法: workflow 加 `pkg==zhmetrics` pre-doc step, 用包内 `zhmCJK.lua` 生成 tfm/map, 装到 `TEXMFHOME` 并 `mktexlsr`. `.github/tl_packages` 补 `fontware` (提供 `pltotf`). build.lua 不变. `zhmCJK-test.pdf` 从 verify expected 移除 — `zhmCJK-test.tex` 硬编码 simsun.ttc/simhei.ttf 文件名 fontconfig alias 救不了, 是包内部字体安装 demo 与文档 CI 目标无关.
- **zhspacing** (暂不覆盖): 从 caller 里删除. `zhfont.sty`/`zhmath.sty`/`zhspacing.sty` 硬依赖 SimSun/SimHei/KaiTi/FangSong/Sun-Ext*/Times New Roman 商业字体, 且深挖后发现 `zhspacing.sty` 自身有时序 bug (`\@iforloop`/`\@nil` undefined, 之前被 SimSun 早退错误掩盖). 上次 tag `zhspacing-20160514` 后 10 年未维护, `release.yml` 也从未真正验证过它的 typeset 链路. 属于包本身 CI 改造范畴, 不合适塞进"新增 workflow 门禁"这类 infra PR. followup issue 单独跟. 详见 [[935-check-doc-zhspacing-blockers]].

关键约束: **`l3build ctan` 不能作为 PR 门禁的等价替代**, 因为它内部硬编码调 `l3build check` (`l3build-ctan.lua:123`), 整套 regression 会重跑, ctex 单包 20+ min 与 test.yml 完全重复. 用 `l3build doc` 精确对应"文档编译性"维度是取舍后的选择, 见 [[935-check-doc-vs-ctan]].

#### fontconfig alias 对 XeTeX/fontspec 无效

尝试过 `<alias binding=strong>` / `<match target=scan>` / `<match target=pattern>` 三种 fontconfig alias 姿势给 CI 上不存在的商业字体 (SimSun/SimHei) 提供 Noto CJK 替代, 均对 XeTeX/fontspec **无效** — `fc-match SimSun → Noto Serif CJK SC` 生效, `fc-list :family=SimSun` 有输出, 但 `xelatex \newfontfamily{SimSun}` 依然报 "cannot be found". XeTeX 内部字体查找路径不完全走 fontconfig, alias 层拦不住 fontspec. **CI 上要给不存在的字体提供替代, 唯一稳定办法是直接 patch dtx/sty 里的字体名** (workspace 内 sed 就地修改, 不改仓库源文件).

### Release 工作流：`.github/workflows/release.yml`

release 自动化在以下 tag 推送时触发：

- `ctex-v*`
- `xeCJK-v*`
- `CJKpunct-v*`
- `zhnumber-v*`
- `xCJK2uni-v*`
- `xpinyin-v*`
- `zhmetrics-v*`
- `zhmetrics-uptex-v*`
- `zhspacing-v*`

工作流按 tag 前缀解析目标包，再依次完成：

- 安装 TeX Live
- 安装 `zhmakeindex`
- 安装 CJK 字体并在 Linux 上执行 `fc-cache -f`
- 针对 `xeCJK` 预下载 `support/Unihan.zip`
- 在目标子目录运行 `l3build ctan`
- 把 `<module>-ctan.zip` 改名为发布资产 `<module>-v<ver>.zip`
- 生成 release notes
- 在真正创建 release 前等待 `test.yml` 对同一 `head_sha` 成功
- 删除已存在的同名 release 并重建为 `prerelease`

门控机制的关键点是：构建、asset 准备与 notes 生成可以先完成，只有最后 `Create GitHub Release` 之前才轮询 `actions/workflows/test.yml/runs?head_sha=<sha>`，确认测试 CI 通过。这避免了在 release 任务最前面空等测试，同时保持发布出口受测试结果保护。

release notes 的稳定优先级是：

1. 优先从目标 `.dtx` 中提取 `\changes{v<ver>}{...}{...}` 条目；
2. 若不存在对应 `\changes`，则回退到上一版本 tag 与当前 tag 之间、限定到目标目录的 git log；
3. 若仍无内容，则写入最小占位说明。

因此，维护发布说明时，首选入口仍是各包 `.dtx` 中的 `\changes` 记录，而不是依赖提交历史临时拼装。每条 `\changes` 应贴近它描述的实现；提取器按源码顺序生成 `CHANGELOG.md`，生成结果中同一 issue 的条目不连续是可接受的，不能为了 Markdown 排列而把源码注释集中到无关位置，更不能只手改生成文件。

详见 `llmdoc/guides/release-workflow.md`。

## CTAN 发布流程

CTAN 打包现已完全由 `.github/workflows/release.yml` 自动化驱动。原根级 `ctan.lua` 脚本已删除，发布入口统一为 tag 推送触发的 GitHub Actions 工作流。

当前 release 自动化覆盖全部 9 个 CTAN 发布单元：`CJKpunct`、`ctex`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`。工作流按 tag 前缀解析包名与目标目录，在对应子目录运行 `l3build ctan` 完成打包。

每个包是否生成 TDS zip、安装哪些文件、如何排版文档，最终仍由该包目录下的 `build.lua` 决定。

## 版本管理

## `.dtx` 内联版本信息

该仓库不依赖单独的 `CHANGELOG.md`。版本与变更信息主要嵌入 `.dtx`：

- 包头使用 `\ExplFileDate`、`\ExplFileVersion`
- 变更历史使用 `\changes{版本号}{日期}{说明}`

调查在 `ctex/ctex.dtx` 中确认了这套机制。文档排版时，这些信息会进入最终文档输出。

## 版本单一事实源与 l3build tag（zhlineskip / ctex）

完成 DocStrip & L3 重构的包（zhlineskip 自 PR #892，ctex 自 PR #937）采用统一的版本管理模式，详见决策 [[937-version-single-source-l3build-tag]]：

- **`build.lua` 顶部 `version` 字段是唯一手改的版本事实源**（ctex 还有 `date` 等价物走 git 元数据；zhlineskip 是 `version` + `date` 两字段）。`uploadconfig`（CTAN 投递）直接引用它。
- dtx 源文件的版本行是 `\GetIdInfo $Id: <file> <ver> <date> ...$` stamp，被 `\ProvidesExplPackage{...}{\ExplFileDate}{\ExplFileVersion}{...}` 消费——dtx 里没有第二处硬编码版本。
- 本地手跑 `cd <pkg> && l3build tag`，包级重写的 `update_tag`（`ctex/build.lua` / `zhlineskip/build.lua`）把 version 回写进 stamp。**ctex 的 update_tag 带幂等守卫**：stamp 版本已等于 version 时原样保留（不动 date/sha），否则"回写产生新 commit → 新 sha → 又要回写"永不收敛。
- 注意 `make tag <pkg>-vX.Y.Z` 是打 **git tag**（触发 release.yml），与 `l3build tag`（回写源文件 stamp）是两回事。
- ctex 的 `update_tag` 在处理主 `ctex.dtx` 时还会额外固化手册首页页脚的 shorthash：取 `git log -1 --format='%h' *.dtx` 回写进 `ctex.dtx` 里的 `\GetFileId[<hash>]{ctex.sty}`（消费方是 `support/ctxdoc.cls` 的 `\GetFileId { O{} m }`，可选参数即固化 hash）。运行时**不**依赖 `\sys_get_shell` / `--shell-escape` 现取 git 信息——曾经的运行时方案已被否决，详见决策 [[937-version-single-source-l3build-tag]] 「手册页脚 shorthash」小节。

### 发版 SOP（ctex 拆分后）

```
1. ctex/build.lua:2       version = "X.Y.Z"           （手改，唯一）
2. 相应 ctex-*.dtx        补 \changes{vX.Y.Z}{...}     （随功能 PR）
3. cd ctex && l3build tag 回写 5 个拆分 dtx 的 $Id:$ 行（自动）
4. commit + PR            （check-tag.yml 验证 stamp 同步）
5. merge 后 make tag ctex-vX.Y.Z[-rcN] && git push origin <tag>
                          （release.yml 三方校验通过才发版）
```

### 双闸 CI

- **`check-tag.yml`（PR 门禁）**：对 zhlineskip / ctex，PR 上跑 `l3build tag` + `git diff --exit-code`。diff 非零 = 作者 bump 了 version 没跑 tag，fail 并提示本地补跑。TL 最小安装（`l3build latex-bin`），ctex job 需 `fetch-depth: 0`（update_tag 取 `git log -1`）。
- **`release.yml` 三方一致性校验**：打 release tag 时验证 `strip_rc(git tag) == build.lua version == dtx stamp`，不一致拒绝发版。**RC 后缀（`-rcN`/`-pre`/`-alpha`/`-beta`）只存在于 git tag**，build.lua 与 stamp 均写 base version——发 rc 前 build.lua 必须已 bump 到目标版本并 stamp。非该机制的包（xeCJK 等）跳过校验打 notice。

## 生成物新鲜度校验模式（"CI 只校验不回写"）

`check-tag.yml`（#937，版本 stamp）与 `check-changelog.yml`（#961，`CHANGELOG.md`）是同一套仓库级架构模式的两个独立实例，值得作为通用解法记住：**当某个产物必须由脚本/工具从源文件确定性生成、且要求与源文件保持同步时，PR 门禁应"重新生成 + `git diff --exit-code`"，而不是让 CI 直接 commit 回写**。后者需要 write 权限，前者不需要。两个实例的共同结构：

- 门禁只在改到相关源文件（dtx / 生成脚本 / 产物自身）时触发，用 `paths` filter 限定。
- 生成 + diff 都是秒级操作，全部涉及包合一个 job 串行跑，不需要按包拆 caller job（区别于 test.yml / check-doc.yml 的 caller-per-pkg 模式，那是因为跨引擎/跨 OS 测试本身耗时）。
- 汇总 job 名固定风格（`check-tag-result` 无独立汇总因单 job 即汇总；`check-changelog-result`），供 branch protection 单点盯。
- 本地都有对应的 `make` 入口把生成动作暴露给贡献者（`l3build tag` / `make changelog`）。

差异点在于校验对象的"大小"决定了 fail 时的可操作性设计：`check-tag.yml` 校验单行 stamp，提示"本地跑 `l3build tag`"即可；`check-changelog.yml` 校验整份 Markdown 文件，还需要在 fail 分支把期望的完整文件内容通过三个通道暴露（`::group::` 折叠的 job log、`$GITHUB_STEP_SUMMARY` 的 `<details>` 折叠块、`actions/upload-artifact`），确保没有本地 Python 环境的 contributor 也能直接复制粘贴过闸。

**任何"字节级 diff 做门禁"的生成物，必须由生成脚本自己控制 encoding/newline，不能依赖 shell 重定向**：Windows PowerShell 5 的 `>` 默认产出 UTF-16LE + CRLF，与 Linux/macOS 上 UTF-8 + LF 字节不同，即使内容语义相同也会被 `git diff --exit-code` 判为不同步。`scripts/extract-changes.py` 因此新增 `-o <file>` 参数，脚本自己以 `encoding="utf-8"` + `newline="\n"` 写文件；`l3build tag` 走 Lua io 库不存在这个问题，此前未暴露过这个坑。

### `check-changelog.yml` 门禁细节

`.github/workflows/check-changelog.yml` 在 PR 改到以下路径时触发：任意 `**.dtx`（故意放宽到全部包——不参与 CHANGELOG 的包触发后生成 + diff 秒级必 pass，换来新包接入零 workflow 改动）、任意 `**/CHANGELOG.md`、`scripts/extract-changes.py`、`Makefile`、workflow 自身。单 job `check-changelog-result` 直接跑 `make changelog`（包列表以 `Makefile` 的 `CHANGELOG_PKGS` 为单一事实源，等价于对每个包执行）：

```bash
cd <pkg> && python3 ../scripts/extract-changes.py "*.dtx" all -o CHANGELOG.md
```

再 `git add -N -- '*/CHANGELOG.md'`（覆盖新包首次生成、CHANGELOG.md 尚未被 git 跟踪的场景，否则 `git diff` 看不到差异）+ `git diff --exit-code -- '*/CHANGELOG.md'`。fail 时按上述三通道贴出期望内容。

`CHANGELOG_PKGS`（单一事实源：`Makefile` 的 `CHANGELOG_PKGS` 变量，workflow 经 `make changelog` 间接消费，无需同步第二处）：`ctex xeCJK zhlineskip zhmetrics zhnumber`。其余 4 个含 `.dtx` 的包（`CJKpunct`/`jiazhu`/`xCJK2uni`/`xpinyin`）目前没有写任何 `\changes` 条目，暂不参与；补写 `\changes` 后只需把包名加入 `Makefile` 的 `CHANGELOG_PKGS` 一行。

本地重新生成入口：`make changelog`（全部包）或 `make changelog-<pkg>`（单包，如 `make changelog-xeCJK`）。

已知接受的缺憾：详见 [[961-changelog-gate-no-write-perm]]。

## LaTeX2e 格式依赖声明

`ctex`、`xeCJK`、`zhlineskip` 在 `\NeedsTeXFormat{LaTeX2e}[...]` 中统一声明依赖 LaTeX2e 2026-06-01（PR #883）。该日期对应当时 LaTeX2e kernel 的发布快照；当 LaTeX2e 升级、kernel 在某些 token、命令钩子或字体接口上发生兼容性变化时，`testfiles` 基线会同步刷新（PR #882 为 2026-06-01 这批基线的批量更新）。

由此衍生的稳定约束：

- 当用户报告“同一份 dtx 在旧 TeX Live 上失败”时，先看其 `\NeedsTeXFormat` 行——本仓库声明的下限即是 2026-06-01，旧 TeX Live 直接不应被当作支持目标。
- 升级声明日期（如未来到下一个 LaTeX2e 快照）通常意味着一次成批的 `.tlg` 基线更新；这类基线 PR 不应被当成业务回归处理。

## Git 信息注入

发布/打包过程中，`support/build-config.lua` 会借助 git 历史展开 `\GetIdInfo`，把最近提交标识写入相应 `.id` 文件及输出产物。见 `support/build-config.lua:70-115`。

因此，修改版本相关内容时，要同时区分三件事：

- `.dtx` 中声明的公开版本号
- `\changes` 中的人类可读变更记录
- 打包阶段自动注入的 git 标识

还要先核对最新 release tag：一个版本已经发布后，新提交的 `\changes` 必须写入
下一个未发布版本，即使 `build.lua` 的当前包版本尚未在发版准备阶段 bump。不能从
`build.lua` 当前值或生成后 CHANGELOG 的首节反推新条目版本；#381 曾在
`ctex-v2.6.2` 发布后误记为 v2.6.2，最终改为 v2.6.3 并重新生成 CHANGELOG。

## 本地 TeX Live usertree 同步

仓库在 PR #883 中声明了 LaTeX2e 2026-06-01 作为最低依赖。CI 通过 `setup-texlive-action@v4 + update-all-packages: true` 每次拉 TLnet 最新版（含最新 LaTeX2e 内核与 hyperref / graphics 等包），所以 CI 始终对齐。本地若用冻结发行版（如 Homebrew TeX Live），需要靠 `tlmgr` 的 **usermode** 维护一个用户树跟进。

### 双步同步流程

```bash
# 1. 同步包到 usertree（前提：已 init 过 ~/texmf + ~/.texlive2026/）
tlmgr --usermode update --all

# 2. 重生成 fmt（必须，否则启动时仍加载老内核）。要按你跑的引擎一个个来：
#    ctex 默认跨 4 个 engine 测试，全部都要 rebuild
fmtutil-user --byfmt latex      # pdftex
fmtutil-user --byfmt xelatex
fmtutil-user --byfmt lualatex
fmtutil-user --byfmt uplatex    # ctex 要这个，别漏了；漏了会全 49 个 uptex 测试 fail
```

仅做第 1 步是常见坑：xelatex 启动加载的是预编译 `xelatex.fmt`，里面 dump 的 `latex.ltx` 是包升级**前**的版本，新 `.ltx` / `.sty` 文件即使已落盘也不会生效。**只 rebuild 部分 engine fmt** 也是常见坑——漏掉的 engine 全部 fail 同一种 `expl3.sty Mismatched LaTeX support files` 错。

`tlmgr --usermode` 的边界：

- 不能更新 `tlmgr` 自身、不能更新引擎包（`xetex` / `luaotfload` / `latex-bin` 会显示 `mentioned, but neither new nor forcibly removed`，这是预期行为）。
- 引擎相关包要等冻结发行版（Homebrew 等）的 formula 升级，或者另装一份官方 install-tl。

### 本地测试失败的环境指纹检查表

当本地 `l3build check` 失败而最新 master CI 全绿时，先看 `.tlg` diff 的指纹：

| 指纹 | 含义 |
|------|------|
| 前几行出现 `LaTeX Warning: You have requested release '<日期>' of LaTeX` | 本地 LaTeX2e 内核 < 仓库声明的最低日期（通常即 #883 的 2026-06-01）|
| diff 出现 `\mathon` / `\mathoff` 节点 或 `$[]$` 风格 Overfull 标记 | 本地 LaTeX / hyperref / graphics 的 `\showbox` 实现旧版 |
| 引擎 banner 一致（如 `XeTeX 3.141592653-2.6-0.999998`）但包级 diff 大 | 不是引擎差异，是 LaTeX / hyperref / graphics 等包差异 |

出现以上任一指纹应优先按“本地 usertree 同步”流程修，而不是当作业务回归排查。

详见反思 [[873-880-meta-url-hbox-math-boundary]]。
