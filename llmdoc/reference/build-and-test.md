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

注意 `make check`（全包回归）单包即需 20min+，本地慎用，默认仍由 CI 跑。hook 的详细说明见 `.githooks/README.md`。

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

截至本轮扩展，`ctex/test/testfiles/` 已包含 180 个 `.lvt` 回归测试输入，形成仓库中密度最高的中文排版主干测试集。与此前约 69 个测试的状态相比，这一轮新增约 109 个测试后，`ctex` 已从“若干关键路径抽样覆盖”提升为“主类、标题、字号、版式、兼容补丁与跨引擎行为的系统性回归网”。

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
- `heading-*`：集中覆盖 heading key 簇，包括 `break`、`afterskip`、`beforeskip`、`hang`、`runin`、`afterindent`、`numbering`、`fixskip`、`pagestyle`、`aftertitle`、`titleformat`、`tocline`、`starred`、`longtitle`、`defaults`、`name`、`format/+` 追加语法与 `indent` 等；现有约 30 个测试文件，已从“章节标题可用”扩展到“标题系统各键的契约级回归”。
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

这些模式说明：`ctex` 回归测试不只是“补一些 .lvt 文件”，而是已经沉淀出一套面向多引擎中文排版的可复用测试方法学。

此外，现在还维护多个专项测试配置：

- `ctex/test/config-cmap.lua`：CMap 相关测试
- `ctex/test/config-contrib.lua`：contrib 目录相关测试
- `ctex/test/config-ctxdoc.lua`：`support/ctxdoc.cls` patch 健康检查，测试目录为 `ctex/test/testfiles-ctxdoc/`

其中 `config-ctxdoc` 使用 `testfiledir = "./test/testfiles-ctxdoc"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，并通过 `checksuppfiles = {"ctxdoc.cls"}` 把本地 `support/ctxdoc.cls` 复制到 check 目录，确保测试覆盖仓库中的当前实现，而不是系统安装版本。对应测试 `patch-health.lvt` 会先传入 `fontset=fandol` 以避免系统字体依赖，再加载 `ctxdoc` 验证全部 patch 在 nonstop 模式下也能以致命错误暴露失败。

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

- `xeCJK`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，见 `xeCJK/build.lua`。现有回归已覆盖字体命令作用域、第三方包 hook、零宽格式字符过滤、`\lstinline` 在宏参数中的 `#` catcode 保持，以及 `\special`/颜色 whatsit 对 glue 恢复链的影响等 XeTeX 专属行为；例如 `xeCJK/testfiles/zwchars01.lvt` 用 6 个宽度对比用例验证 U+200B/U+200C/U+200D/U+2060/U+FEFF 不会打断字符分类，也不会额外插入 `CJKglue` / `CJKecglue`；`xeCJK/testfiles/color01.lvt` 则用 5 个盒子宽度对比用例验证 `\textcolor` 包裹 Default、单个 CJK、单个数字、混合 Latin 内容与嵌套颜色组时，Boundary→Default 和 Boundary→CJK 过渡中的 `CJKecglue` / `CJKglue` 都能在 whatsit 节点后被正确恢复。其中 `xeCJK/testfiles/listings-hash01.lvt` 的 Test 6 覆盖用户通过 `\catcode\`\&=6` 把其它字符设为 parameter token 的场景，验证 `\@@_listings_rescan:Nn` 用 token-level map 保留原字符码，不会把非 `#` 的 catcode 6 token 映射为 `#`（\#879）。
- `zhnumber`：`testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"pdftex", "xetex", "luatex"}`，见 `zhnumber/build.lua`。
- `CJKpunct`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `CJKpunct/build.lua`。CJKpunct 仅工作在 pdfTeX (CJK 宏包) 路线下。
- `zhlineskip`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `zhlineskip/build.lua`。zhlineskip 是独立 `.sty`（无 `.dtx` unpack），`unpackfiles = {}`。测试使用 vbox 尺寸捕获策略验证行距行为。

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。

因此，修改 `xeCJK` 与 `zhnumber` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

## CI/CD 配置

GitHub Actions 工作流当前包含以下主线：

- `.github/workflows/test.yml`：跨平台测试工作流
- `.github/workflows/release.yml`：按发布 tag 构建并创建 GitHub prerelease 的自动化工作流
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
- 当前 CI 在同一 job 中依次进入 `ctex/`、`xeCJK/`、`zhnumber/`、`CJKpunct/`、`zhlineskip/` 运行测试，而不再只停留在 `ctex/`

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

CI 中当前执行的测试步骤是：

- `Test ctex`：在 `./ctex` 运行 `../scripts/check-parallel.sh`,**4 engine 并行**,`CONFIGS` env 透传 `test/config-cmap test/config-contrib test/config-ctxdoc` 让 4 个 engine 各跑主测 + 3 个 config. 实测 wall-clock ~5–7min(串行 ~20min). 失败时自动 dump 各 engine 的 `patch-health.log`.
- `Test xeCJK`：在 `./xeCJK` 运行 `l3build check -q`(单 engine xetex, 不需并行)
- `Test zhnumber`：在 `./zhnumber` 运行 `l3build check -q`
- `Test CJKpunct`：在 `./CJKpunct` 运行 `l3build check -q`
- `Test zhlineskip`：在 `./zhlineskip` 运行 `l3build check -q`

`Test xeCJK`、`Test zhnumber`、`Test CJKpunct` 都带有 `if: ${{ !cancelled() }}`，因此只要工作流未被取消，就会继续执行，不会因为前一个测试步骤失败而自动跳过。卫星包步骤还会在运行前检测 `testfiles` 目录或 `build.lua` 中的 `testfiledir` 配置；若未发现测试配置，则安全输出跳过信息，而不是直接失败。

失败时，artifact 上传范围也已扩展为：

- `ctex/build/**/*.diff`
- `xeCJK/build/**/*.diff`
- `zhnumber/build/**/*.diff`
- `CJKpunct/build/**/*.diff`
- `zhlineskip/build/**/*.diff`

另外，`ctex` 测试步骤的 step id 已由 `test` 调整为 `test-ctex`，以便与新增的 `test-xecjk`、`test-zhnumber`、`test-cjkpunct` 一起在后续 artifact 条件表达式中区分引用。

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

因此，维护发布说明时，首选入口仍是各包 `.dtx` 中的 `\changes` 记录，而不是依赖提交历史临时拼装。

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
