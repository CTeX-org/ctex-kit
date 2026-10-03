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

`\changes` 中不能使用 `|...|` 短抄录，改用 `\texttt{...}`、`\cs{...}`、`\tn{...}` 或文字描述。说明文字会进入 `.glo`，经 makeindex 处理，第一个 `|` 被当作 encap 符，它后面的文字被当作页码格式命令执行。#1091 R1 实测以汉字开头的短抄录（如 `|姓名 \CJKunderline{...}|`）让 `l3build doc` 报 `Undefined control sequence`；R3 实测以反斜杠开头的 `|\CJKunderline{...}|` 虽不报错，排版同样出错：更改历史里出现 `hdclindex…`／`dex…` 一类文字泄漏，带下划线的正文被真正排出，并有 Overfull。R1 时记下的“以反斜杠开头没有问题”是错的。验证方式：`l3build doc` 后对 PDF 运行 `pdftotext`，检索 `hdclindex` 与 `dex[0-9]`，结果应为空（当前仍有三处来自旧条目的泄漏，见 `llmdoc/memory/doc-gaps.md`）。其他 makeindex 特殊字符见 `llmdoc/reference/coding-conventions.md` 的「`\changes` 与索引条目里的 makeindex 特殊字符（#1054）」。

写在 `macro` 环境里的 `\changes`，更改历史中的标签取环境名字列表的最后一个名字。列表里有多个函数时，要把最能代表这条修改的函数放在最后。#1091 的这条 `\changes` 所在的名字列表，最后一个名字是 `\@@_ulem_tail_check:`（右边界判断的入口）。R4 只把 `\s_@@_ulem_body` 从末位移到首位，末位于是变成辅助函数 `\@@_ulem_punct_peek_aux:N`，标签仍不对，R5 才调整为以 `\@@_ulem_tail_check:` 结尾。改动名字列表后，要到 PDF 的更改历史里确认标签落在哪个名字下。

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

截至 #994，排除 `build.lua` 中两个已知不兼容用例后，`ctex/test/testfiles/` 有 185 个会运行的 `.lvt` 回归测试输入，形成仓库中密度最高的中文排版主干测试集。与此前约 69 个测试的状态相比，`ctex` 已从“若干关键路径抽样覆盖”提升为“主类、标题、字号、版式、兼容补丁与跨引擎行为的系统性回归网”。

以下包接入了独立的 `testfiles/` 回归目录：

- `ctex`
- `xeCJK`
- `zhnumber`
- `CJKpunct`
- `zhlineskip`
- `xpinyin`

这意味着这些子包已不再只依赖主包依赖链覆盖，修改它们时可以直接在各自目录运行 `l3build check`。

### `macnew` 平台条件字体测试（#994）

`ctex/test/testfiles/fontset-macnew01.lvt` 使用 `fontset=none`，再单独设置本次修改的
核心字体 `Songti SC Regular`。这样可以验证正文宋体，而不会同时触发与本项无关、
可能需要另行下载的 macOS 可选字体。完整 `macnew` 的生成结果由同一测试中的静态
断言检查。

这项测试分成两类证据：

- 所有平台都检查生成的 `macnew` 字体名、`Songti.ttc` index、zhmap 映射和 SPA
  生成源。Linux 等没有 Apple 字体的平台只能提供这一层证据。
- macOS XeTeX 直接加载 Regular，并现场重测标点边界数据；macOS LuaTeX 实际排出
  一个中文字形，再从字形（glyph）节点核对字体的 `fullname` 或 PostScript 字体名。

静态配置检查不能证明字体已加载，平台运行时检查也不能代替各后端生成配置的检查。
测试结论必须说明实际执行了哪个条件分支：Linux 上四引擎通过不能用于声称 Apple
字体加载成功；LaTeX+DVI 与 upLaTeX 当前只覆盖 TTC index 和 zhmap 配置，也不等于
已经验证完整的 `dvipdfmx` 加载流程。

字体系统可能按需加载字体，因此只执行 `\setCJKmainfont` 一类声明不够。运行时测试
必须至少实际排出字形，并核对该字形对应字体的元数据。检查 LuaTeX 节点时还要
先确认实际节点结构；LuaTeX-ja 可能把 CJK 字形放进嵌套的 `hlist` 或 `vlist`，
只遍历外层列表会漏掉目标字形。

### xeCJK 命令边界矩阵（#992）

命令边界回归以去掉命令包装后的直接输入为 oracle。候选的实际首、尾可见字符分别是什么类别，就与相同字符直接出现在该边界时比较；数字和西文属于 Default，CJK 输出属于 CJK，混合内容左右分别判断，无可见输出检查透明性。每个可表达场景展开 `00/10/01/11` 四种源码空格，并分别设置 `xCJKecglue=false` 和 `xCJKecglue=true`。候选与直接输入必须使用相同的选项值；否则比较的不是命令包装是否改变行为，而是两个不同配置的结果。

每种 `xCJKecglue` 设置都要检查默认间距和可区分间距。后者使用 `CJKecglue={\hskip 5pt}`、`CJKglue={\hskip 1pt}`，避免默认词间空格与 `CJKecglue` 等宽或默认 `CJKglue` 自然宽度为零而产生假通过。`xCJKecglue=<glue>` 等价于 `CJKecglue=<glue>, xCJKecglue=true`，不复制第三张完整矩阵，只用独立回归测试锁定这项等价关系。`CJKspace` 是另一项独立设置，不与 `xCJKecglue` 做全组合。

`xeCJK/testfiles/command-boundary01.lvt` 是统一框架的宽度校验：

- 当前有 100 组普通 `\BoundaryMatrix`，分别在默认/可区分间距和 `xCJKecglue=false/true` 的四种配置下运行；第 28 行另用直接公式 `$x$` 作为 oracle。矩阵中 1616 个可表达单元现已全部执行宽度比较；再加 `CJKspace` 和分隔符扫描 `\verb` 的 52 个比较，合计 1668 个通过断言。测试先扣除待测命令与直接输入分别排版时固有的宽度差，再只比较外围间距，容差为 0.01pt。
- 覆盖展开宏、显式分组、字体/颜色、xeCJKfntef 与原生 `\uline`、box/wrapped-box、mixed 首尾、hyperref/URL/reference、hypdoc、`\verb`、transparent/post-transparent、biblatex write，以及 `CJKspace` / `xCJKecglue`。
- 嵌套测试覆盖到 12 层盒子；`\sbox` scratch 测量用于确认 capture suspend/resume 不会污染外层实际输出。
- ulem/fntef 双向嵌套覆盖原生 `\uline` / `\sout` 与 `\CJKunderline` / `\CJKunderdot`；每格的 idle-stack 断言同时防止内层重复启动却没有对应结束所造成的 capture 泄漏。
- 分隔符扫描的 `\verb` 不能放进矩阵宏参数，因此使用等价的四次显式盒子调用。
- 每个候选单元之后都运行 `\BoundaryAssertIdle`，要求 capture depth、active stack count、suspend depth 同时归零；宽度正确但遗留活跃层仍算失败。

#992 的 2026-07-21 补测最初表明，排除由 #1002 单独跟踪的公式后，`xCJKecglue=false` 在默认间距和可区分间距下均为 320／320 通过；`xCJKecglue=true` 分别为 318／320 和 312／320 通过。失败由 #1003 跟踪。PR #1005 恢复外层 `spacefactor`，并让 post-transparent 以真实 marker 为证据移动 `marker + 至多一枚 glue` 的有界后缀；合并为 `master` `8007e4df` 后，从该提交运行 16 个驱动，普通命令在四种配置下均为 320／320 通过，#992 活表第 7、9、15 行及对应图片已经更新。仓库回归只固化绿色单元；红叉必须留作 issue 证据，不能把当前错误输出写成 `.tlg` 基线，也不能为了让整组通过而丢掉同一场景中的绿色单元。

公式的比较基准必须保留公式形式。比如 `\mbox{$x$}` 应与直接公式 `$x$` 比较，不能与字母 `x` 比较；二者在 xeCJK 中具有不同的源码空格语义。`xCJKecglue=false` 时，公式旁的源码空格保留为普通词间空格；`true` 时才改用 `CJKecglue`。外层命令不能改变这项选择。

#1002 的公式矩阵覆盖中文—公式—中文、西文—公式—西文和两个混合方向，分别检查直接 `$x$`、`\(x\)`、`\ensuremath{x}` 以及字体、颜色、盒子、链接、ulem 和独立符号命令中的公式。左右两侧必须分别检查，不能只比较总宽度；否则一侧多出的间距可能与另一侧缺少的间距抵消。`command-boundary-math01.lvt` 在默认/可区分间距和 `xCJKecglue=false/true` 四种配置下执行 5504 次比较，包含公式位于命令开头、位于 CJK 后缀末尾、整个正文由外层分组包围、CJK 前缀后接分组公式、嵌套命令和原语 `\setbox` 离线测量；每个候选还检查 capture、active 和 suspend 状态归零。尾随源码空格矩阵另覆盖 box、wrapped-box、stream、stream-ulem、参数内外连续空格、后接注册命令和显式 glue。所有尾部公式语法检查都只产生候选，适配器还要在可见正文实际排完时检查当前列表末节点，才能把末类别发布为 `math` 或 `math-space`。反例覆盖带可选参数的双参数宏、普通双参数宏和分隔参数宏消费末尾 `{$x$}` 的三种情况，并增加未知宏分别把 `$`、`\)` 当作分隔参数终止符的两种情况；尾随空格版本还在 box 和 ulem 中重复检查消费分组与 `$` 的路径。这些宏实际都只排出 CJK“文”，用来防止框架把被消费的尾部记号误认成可见公式。`command-boundary-math02.lvt` 用节点日志确认 glue 位于盒子、链接 annotation 和 ulem 装饰区间之外，`03` 检查宏包加载顺序、移动参数和对齐扫描器，`04` 单独检查只加载标准 `color` 的路径。

`command-boundary-math05.lvt` 专门检查尾随空格的弹性，而不是重复宽度矩阵。普通 stream 的参数内空格仍在外层列表，`math-space` marker 以两对零净宽 kern 保存实际伸长量和收缩量；测试用字体不同的 `\textbf`、嵌套 `\emph{\textbf{...}}` 确认，外层补偿会扣除实际空格已有的弹性，同时保留内部字体造成的自然宽度差。box、wrapped-box、嵌套 `\mbox` 和 ulem 使用 `math-space-frozen`，内部空格不参与外层断行，外层补偿完整保留 `CJKecglue` 的弹性。另一组把 `CJKecglue` 设为比普通词间距更窄且不带伸缩量的 1pt glue，确认冻结路径的自然差额取零，不会用负 glue 把后续 CJK 拉进框线或装饰范围。段落断言还分别测出 direct、box、wrapped-box、stream 和 stream-ulem 的自然宽度，再把段宽缩短 1pt；五条路径的 badness 都是 12，证明 2pt 的外层收缩量都能被段落装箱实际使用，而不是只存在于节点日志中。

同一测试还锁定 `math-space` 的物理相邻边界。transparent 颜色命令和 post-transparent `\null` 分别在真实参数空格与 marker 之间留下 9 型 special 和 1 型零尺寸 hbox；此时 marker 应当过期。`null-explicit` 再检查 `\textnormal{$x$ }\hskip7pt\null`：探测 marker 时暂存的 7pt glue 必须恢复到 `\null` 之前，保留“真实空格、显式 glue、零尺寸盒子”的直接 oracle 顺序。三项末节点类型分别为 9／1／1；候选与含同一不可见节点的直接公式 oracle 宽度差均为 0，在段宽 10pt、容差 100 下排段，段落高度差也均为 0。这证明框架既没有把补偿 glue 单独放到不可见节点之后，也没有把显式 glue 错移到盒子之后。

`loading01.tlg` 现在固定两种 marker 常量，以及补偿计算使用的四个 skip 和四个尺寸（dim）寄存器，防止加载期分配基线无意漂移。

### 实验性命令边界注册接口（#1010）

`boundary-register-api01.lvt` 固定公开入口的可观察行为。测试为 `box`、
`wrapped-box`、`stream`、`transparent`、`post-transparent` 五种策略选择合适
的最小命令，并覆盖 `auto`、`default`、`first-default` 三种允许的模式。每个
矩阵除了 `00/10/01/11` 四种源码空格，还分别运行 `left-0`、`left-1`、
`right-0`、`right-1`，防止左右两侧的误差在总宽度中抵消；整组再分别设置
`xCJKecglue=false` 和 `xCJKecglue=true`。18 组矩阵共执行 288 项比较，失败数
为 0，每项还检查 capture depth、active stack 和 suspend depth 均已归零。

同一测试还固定以下生命周期和控制序列语法：分组内的声明仍全局生效；带 `@` 的
命令由 `\makeatletter` 管理类别码；带 `_`、`:` 的 LaTeX3 命令由
`\ExplSyntaxOn` 管理；普通 `\AtBeginDocument` 中才定义的命令也能在正文开始时
取得 hook。这里测试的是通用策略能观察到的 CJK／Default 边界，不把 #1002 的
参数公式适配算作 `auto` 的一般能力。

`boundary-register-api02.lvt` 固定公共诊断和拒绝路径：非控制序列、非法策略或
模式、策略与模式的非法组合、缺少必填项、重复用户声明、通用内建冲突、专用
适配器冲突、未定义目标和正文期声明。测试把 begin-document 的存在性检查在
`\START` 后再执行一次，确保用户实际看到的 `boundary-register-undefined` 消息
进入 `.tlg`，而不只是内部属性表状态正确；初始化输出则用 `\OMIT`／`\TIMO`
隔开。`\verb` 和 `\Url@z` 证明专用适配器保留表也参与冲突判断；拒绝重复注册
`\verb` 后还实际调用其扫描器，确认通用 hook 没有破坏原参数读取。正文中才
定义的目标保持未注册，正文期再次声明也不会改变待应用记录数。

这两个测试曾使 xeCJK 标准测试总数增加到 111 项；#1017 新增
`fntef-actualtext01`、#1012 新增 `fntef-phase01`、#1026 新增
`fntef-shrink01`、#1029 新增 `boundary-sbox-global01`、#1038 新增
`tabular-cr01` 与 `boundary-bgroup01`、#1043 新增 `halign-amp-boundary01/02/03`、
#1046 新增 `codedoc-meta-symmetry01`、#1047 新增 `hyperref-anchor-ecglue01`、
#1057 新增 `fntef-nest-linebreak01`、#1091 新增 `fntef-entry-space01`、
#1104 新增 `microtype-slot01`、#1103 新增 `boundary-empty-space01` 与 `boundary-empty-space02` 后，当前为 127／127 通过。完整接口契约见
[[../memory/decisions/1010-boundary-register-public-api]]。

### 没有可见输出的命令两侧的源码空格（`boundary-empty-space01`，#1103）

`boundary-empty-space02.lvt` 固定 #1103 对 beamer 的兼容：文档类为 beamer，在只有一张幻灯片的框架里比较 5 项宽度。带覆盖说明的 `\hypertarget<1>{t}{B}` 与直接写 `B` 同宽（`overlay-L`、`overlay-C`），`\hypertarget{t}{}` 两侧都有源码空格时与删去命令的直接输入同宽（`empty-L`、`empty-C`），第二个参数不为空时保留两侧空格（`nonempty-C`）。在 `349f9f77`（按 `#1#2` 包装 beamer 的命令）上 `overlay-*` 两项失败（排出 `>{t}{B}`），在修复前 `e641743e` 上 `empty-*` 两项失败。覆盖说明只写 `<1>`：写 `<2>` 会让框架排两次，第 1 张上隐藏的内容由 beamer 处理，不比较。

`boundary-empty-space01.lvt` 固定 #1103：已注册命令没有可见输出、两侧都有源码空格时只保留一枚空格（机制见 [[../architecture/xecjk-empty-output-space]]）。全文件 4156 项比较（本地审查第一轮前为 2305 项，第一轮后为 3803 项，第二轮后为 3824 项，最终全范围审查第四轮后为 3848 项，本地审查第五轮后为 3871 项，第六轮后为 3898 项，第七轮后为 3903 项，第八轮后为 3907 项，第九轮后为 3914 项，第十轮后为 3922 项，最终全范围审查 `final-full-110923` 后为 3970 项，本地审查第二十四轮后为 3998 项，第二十五轮后为 4014 项，第二十六轮后为 4032 项，第二十七轮后为 4040 项，最终全范围审查 `final2-full-175113` 后为 4048 项，第三十轮后为 4052 项，最终全范围审查 `final3-full-190620` 后为 4064 项，第三十二轮后为 4070 项，最终全范围审查 `final6-full-015816` 后为 4100 项，第三十七轮后为 4116 项，第三十八轮后为 4118 项，最终全范围审查 `final7-full-052308` 后为 4130 项，第四十二轮后为 4136 项，最终全范围审查 `final8-full-064537` 后为 4156 项），失败数为 0；每个候选之后还断言 capture depth 归零。

- **oracle 是删去命令后的直接输入**，不是推出来的关系。曾用“11 组合应等于 10 或 01”辅助判断，最后改回以实际排版的直接输入为准。
- **命令**：用户注册的空 `stream`、`transparent`、`box` 命令，`\mbox{}`、`\textcolor{red}{}`、`\hypertarget{a}{}`、`\uline{}`、`\numlist{}`、`\unit{}`，共 9 个；`\EmptyLeftForCommands` 另加 `\color{red}`，共 10 个。
- **组成**：16 个 TEST，另有一行不属于任何 TEST 的颜色命令。下面的编号以当前 `.tlg` 为准；各条括号里“第 N 轮前为 TEST M”记的是旧编号。
  - `\START` 之后、所有 `\TEST` 之外写 `\color{red}\normalcolor`（第七轮后新增），确认分组层数 0 的颜色推入命令不读取不存在的来源编号变量（以前报 `Erroneous variable`）。`\TEST` 自己开一个分组，写在 `\TEST` 里面层数就不是 0，所以只能放在外面；它不计入比较项数。
  - TEST 1–4 为默认间距／可区分间距 × `xCJKecglue=false/true`，每个 TEST 952 项（第二轮后 950 + 2）：16 组左右文字只比较两侧都有空格的写法（`\EmptyBothForCommands`，9 × 16 = 144）；21 组比较 `00/10/01/11` 四种写法（`\EmptyForCommands`，9 × 21 × 4 = 756），其中第一轮审查后新增的 9 组是左侧紧贴 `~`、`\nobreakspace{}` 的 `tie-C`、`tie-L`、`tie-math`、`tie-hbox`、`Ltie-L`、`nbsp-C`，以及命令之后是花括号或颜色命令的 `C-groupC`、`C-colorC`、`groupC-colorC`；`C-groupmath`（`中` 与 `{$y$}`）、`C-colormath`（`中` 与 `\color{red}$y$`）只比较左侧有空格的 `10/11`（`\EmptyLeftForCommands`，10 × 2 × 2 = 40）；`\color{red}` 本身另有 `C-C/color`、`C-groupC/color` 两组四种写法与 `groupC-math/color` 的 `10/11`（10 项）；`color-math-direct` 的 `10/11` 把 `中 \color{red}$y$` 与不含颜色命令的 `中 $y$` 比较（2 项，第二轮后新增：`C-colormath` 的 oracle 也含 `\color`，`\color` 本身在公式之前丢失间距时两边一起出错，捕获不到）。
  - TEST 5 单独比较 `A \phantomsection{} 文` 与 `A {} 文`（不带 `{}` 时命令名后的空格在读取控制序列名时就被跳过）。
  - TEST 6 在 `tabular` 单元格末尾放 `\mbox{}`、`\textcolor{red}{}`、`\hypertarget{t}{}`、`\uline{}`、`\unit{}`（`中 \mbox{} & 文`），与删去命令的表格比较整表宽度，1 项；以前报 `Extra alignment tab`。
  - TEST 7（第九轮后新增）比较左侧是西文的单元格，第十轮后改为每个命令单独排一张表（`\EmptyTabCell`），9 项：`\mbox{}`、`\textcolor{red}{}`、transparent、box 命令留下的节点挡住 `l` 列模板末尾的 `\unskip`，比较对象是命令之后不写空格的同一行（`A \mbox{}& B`）；`\hypertarget{t2}{}`、`\uline{}`、`\unit{}`、`\numlist{}`、stream 命令不留节点，比较对象是删去命令的直接输入（`A  & B`）。第九轮时这组只有一张 6 行的表，整表宽度由 `\mbox{}` 那一行决定，测不出其他行的宽度（审查第十轮的小问题）。`45e4a2f7` 上报 `Extra alignment tab`；修复前 `e641743e` 上后 5 项宽度失败（多一枚空格）。
  - TEST 8（本地审查第二轮后新增，第九轮前为 TEST 7）在 plain `\halign{#&#\cr ...}` 里比较命令之后紧跟 `\cr`、`\crcr`、`\span` 的写法，与删去命令的对齐比较整个 `\vbox` 的宽度，10 项：`\cr` 之前分别放 `\mbox{}`、`\RegStream{}`、`\RegTrans{}`、`\textcolor{red}{}`、`\unit{}`、`\hypertarget{a}{}`（左侧 `中 `）与左侧 `A ` 的 `\mbox{}`，另有 `\crcr`、`\span` 各一项与 `中 \mbox{} \cr`（命令与 `\cr` 之间有空格）一项。第九轮后另增 6 项左侧是西文、命令之后有空格的写法：`A \mbox{} &C\cr`、`A \mbox{} \cr`、`A \mbox{} \crcr`、`A \mbox{} \span C\cr`、`A \textcolor{red}{} &C\cr`、`A \uline{} &C\cr`，共 16 项。
  - TEST 9（第四轮后新增，第九轮前为 TEST 8）比较列模板以命令结尾的 plain `\halign`，7 项：命令经宏 `\EmptyTemplateCmd` 放在模板末尾（`\halign{#\EmptyTemplateCmd\cr 中 \cr}`），使命令之后紧接 TeX 插入的 `\endtemplate`，与 `\halign{#\cr 中 \cr}` 比较整个 `\vbox` 的宽度；命令为 `\mbox{}`、`\RegStream{}`、`\textcolor{red}{}`、`\unit{}`、`\hypertarget{z}{}`、`\uline{}`，第五轮后另加 `tmpl-mbox-space`（模板末尾是 `\mbox{} `，删去空格之后再看下一个记号时遇到 `\endtemplate`）。
  - TEST 10（第五轮后新增，第九轮前为 TEST 9）比较空命令之后紧跟 `\outer` 宏，9 项。原有 5 项的 `\outer` 宏之后都是 `}`：`中 \mbox{}\EmptyOuterA`、`中 \mbox{}\EmptyOuterB`、`中 \mbox{}\EmptyOuterC`、`中 \mbox{}\EmptyOuterD`（四个宏分别用 `\outer\def`、`\long\outer\def`、`\protected\outer\def`、`\protected\long\outer\def` 定义为空；`outer-D` 为第六轮后新增）与 `中 \color{red}\EmptyOuterB`。`\outer` 宏不能出现在宏参数里，所以这个 TEST 用 `\BEGINTEST`／`\ENDTEST` 而不是 `\TEST{...}{...}`，每项直接写出。oracle 写成宽度相同的 `中 `，不是删去命令的 `中 \EmptyOuterA`：后者在 xeCJK 汉字之后的前视里也报 `Forbidden control sequence`（修复前 `e641743e` 就如此，登记在 [[../memory/doc-gaps]]）。第八轮后新增 4 项，`\outer` 宏之后还有文字或命令之后有空格，比较对象是删去命令的直接输入：`outer-text-L`（`A \mbox{}\EmptyOuterA B`，比较 `A \EmptyOuterA B`）、`outer-space-L`（`A \mbox{} \EmptyOuterD B`，命令之后的空格被删去之后遇到 `\outer` 宏）、`outer-text-tc`（`A \textcolor{red}{}\EmptyOuterB B`），这两项也比较 `A \EmptyOuterA B`；`outer-text-C`（`中 \mbox{}\EmptyOuterC 文`）比较宽度相同的 `中 \relax 文`，因为直接输入 `中 \EmptyOuterC 文` 在汉字之后的前视里报错（同上）。这 4 项确认认出 `\outer` 记号之后、删去空格之后都清除了 `\l_peek_token`，后面字符触发的 interchar 代码不再报 `Forbidden control sequence`。
  - TEST 11（第四轮后新增，第五轮前为 TEST 9，第九轮前为 TEST 10）比较颜色正文以空格结尾的写法，30 项 × `xCJKecglue=false/true` = 60 项，oracle 是删去颜色命令、保留分组的直接输入：`\textcolor{red}{A } B`、`{\color{red}red } text`、`{\color{red}A } 中`、`\textcolor{red}{A\ } B`、`\textcolor{red}{A } $y$`、`\textcolor{red}{A } ~B`、`\uline{\textcolor{red}{A } B}`；`中 \textcolor{red}{} 文`、`A \textcolor{red}{} B` 两项确认 `\set@color` 留下的记录仍由 `\reset@color` 转交。第五轮后新增 9 项（每种设置），其中 8 项正文以“空格 + 空命令”结尾，确认 `\reset@color` 不转交正文里其他命令的记录：`tc-mbox-L`（`\textcolor{red}{A \mbox{}} B`）、`color-mbox-L`（`{\color{red}A \mbox{}} B`）、`tc-tc-L`（内层 `\textcolor{blue}{}`）、`tc-ht-L`（`\hypertarget{x}{}`）、`tc-ps-L`（`\phantomsection`）、`tc-unit-L`（`\unit{}`）、`tc-uline-L`（`\uline{}`）、`ul-tc-mbox-L`（`\uline{\textcolor{red}{A \mbox{}} B}`），oracle 都是 `{A } B` 一类；另有用户分组 `group-color-L`（`A {\color{red}} B`，oracle `A {} B`）。第六轮后新增 12 项（每种设置）：正文里另有颜色命令的 `tc-color-L`（`\textcolor{red}{A \color{blue}} B`）、`tc-color-mbox-L`（`\textcolor{red}{A \color{blue}\mbox{}} B`）、`tc-normal-L`（`\textcolor{red}{A \normalcolor} B`），oracle 都是 `{A } B`，确认正文里的 `\set@color` 不覆盖 `\textcolor` 自己存下的来源编号；正文为空的颜色命令里嵌套空命令的 `tc-tc-C`（`中 \textcolor{red}{\textcolor{blue}{}} 文`）、`tc-uline-C`、`tc-xout-C`、`tc-uwave-C`、`tc-uuline-C`、`tc-dashuline-C`、`tc-dotuline-C`（oracle `中  文`）与 `tc-xout-L`、`tc-uline-empty-L`（`A \textcolor{red}{\xout{}} B` 一类，oracle `A  B`），确认线型命令在测量或丢弃用的盒子里排出的字符不让内层交给外层的记录丢失。
  - TEST 12（第六轮后新增，第七轮改写，第九轮前为 TEST 11）比较空命令之后紧跟替换文本以 `\outer...` 开头的普通宏（`\EmptyNotOuter` 定义为 `\outerEmpty`），3 项：`not-outer-C`（`中 \textcolor{red}{\mbox{}\EmptyNotOuter} 文`，比较 `中  文`）、`not-outer-L`（`A \textcolor{red}{\mbox{}\EmptyNotOuter} B`，比较 `A  B`）、`not-outer-tail`（`中 \textcolor{red}{\mbox{}\EmptyNotOuter}`，比较 `中 `）。第五轮的 `\outer` 检查在含义的前 22 个字符里查找 `\outer`，会把这类宏误判为 `\outer` 记号、作废记录。宏放在颜色命令正文末尾，记录必须交给外层的颜色命令，误判时颜色命令之后多一枚空格。第六轮的写法（`中 \mbox{}\EmptyNotOuter 文` 与 `not-outer-space`）在 `aed1f9d2`（子串查找版本）上也通过：记录不论作废与否，宏展开之后排出的汉字都会清除它，所以抓不到误判（第七轮的小问题）。
  - TEST 13（第七轮后新增，第九轮前为 TEST 12）比较 `\sbox` 夹在两个空命令之间，只在 `xCJKecglue=false` 下比较，6 项：`mbox-sbox-mbox`（`A \mbox{}\sbox0{x}\mbox{} B`，比较 `A \sbox0{x} B`）、`mbox-sbox-tc`（第二个命令为 `\textcolor{red}{}`）、`mbox-savebox-mbox`（`\savebox\EmptySaveBox{x}`，`\newsavebox` 让 `.tlg` 多一行 `\EmptySaveBox=\box...`）、`mbox-sbox-uline`（`A \mbox{}\sbox0{}\uline{} B`），以及带参数的用户宏夹在两个空命令之间的 `mbox-usehook-mbox`、`mbox-gobble-mbox`（第二十六轮后新增）。确认 `\sbox` 适配器恢复暂停前的记录之后，第二个命令不再删去第一个命令之后的空格。`xCJKecglue=true` 时第一个 `\mbox{}` 不在列表里留下节点，这些写法属于用户手册说明的无法区分的写法，不比较。
  - TEST 14（最终全范围审查 `final-full-110923` 后新增）比较“stale record after an empty command”，在 `xCJKecglue=false` 与 `true` 下各 96 项：空命令之后紧跟 `\rule`、`\special`、`{\rule...}`、`\textbf{\rule...}` 再接空命令（`rule-mbox`、`special-tc` 等），确认记录不会留给后面左侧没有源码空格的命令；`\EmptyStale` 先在一个丢弃的 `\vbox` 里排出 `\hbox{A \mbox{}\rule{1pt}{1pt}}` 或一个段落，再比较下一个盒子（`hbox-hbox`、`par-hbox`）；另有 `A \mbox{}\mbox{} B`、`\textcolor{red}{\mbox{}\mbox{}}`、展开为空的用户宏 `\EmptyNop` 等仍应交接的写法。在 `79222a0d` 上 13 项失败。第二十四轮新增 14 项：`\textcolor{red}{\hypertarget{h}{}}`、`\textcolor{red}{\phantomsection}`、`\phantomsection` 之后接空命令（hyperref 的内部代码不能当作用户宏），以及 `\color{red}\EmptyNop $x$`、`\mbox{}\EmptyId{$x$}` 等宏展开之后紧跟公式（`\EmptyId` 为 `\newcommand\EmptyId[1]{#1}`）；在 `6a5e4dd7` 上 18 项失败，在 `79222a0d` 上另有 `mbox-id-math`、`color-id-math` 共 4 项失败。第二十五轮新增 8 项：`\csname rule\endcsname`、`\expandafter\rule`、`\ifhmode\special{x}\fi` 这类可展开原语开头、排出内容的写法（`csname-rule` 等），以及颜色正文以用户宏加公式开头的 `tc-nop-math-L`、`tc-nop-display-L` 和 `\EmptyId{\EmptyNop $x$}`；在 `6cfeee80` 上 11 项失败。第二十六轮新增 8 项：恒等宏参数里的用户宏（`id-nop-L`、`id-sp-L`）、`\noexpand`（`noexpand-L`、`tc-noexpand-L`）、颜色正文以公式加空格结尾（`tc-nop-math-space-L`、`tc-relax-math-space-L`）、可展开原语之后紧跟公式（`ifhmode-math`、`csname-math`）；另在“sbox between empty commands”一组加带参数的用户宏 `mbox-usehook-mbox`、`mbox-gobble-mbox`（该组只比较 `xCJKecglue=false`）。在 `879a9261` 上 18 项失败。第二十七轮新增 4 项：恒等宏参数以可展开原语或 `\NewDocumentCommand` 命令开头再接公式（`id-ifhmode-math`、`id-nd-math`），以及展开为空的 `\NewDocumentCommand` 命令、展开为 `\@empty` 的宏夹在两个空命令之间（`nd-mbox-L`、`atempty-mbox-L`）；在 `7cc9629b` 上 6 项失败。`final2-full-175113` 之后新增 4 项：`\the`、`\expandafter` 展开出的空格（`the-space-L`、`the-space-tc-L`、`expandafter-space-L`、`the-space-C`）；在 `ef57af77` 上 7 项失败。第三十轮新增 2 项：宏的替换文本以 `\fi` 结尾时其后的源码空格照常删去（`macro-fi-L`、`macro-fi-C`），去掉条件原语例外后这 3 项比较失败。`final3-full-190620` 之后新增 6 项：`\obeyspaces` 之下的活动空格（`obey-mbox-L`、`obey-mbox-C`、`obey-tc-C`、`obey-mbox-mbox-L`、`obey-color-L`，所用的宏在 `\obeyspaces` 分组里预先定义），以及写在花括号里的内部命令（`brace-internal-L`）；在 `dc180f7b` 上报 30 个错误、7 项失败。第三十二轮新增 3 项：活动空格被 `\let` 成控制空格（`obey-let-mbox-L`、`obey-let-tc-C`、`obey-let-color-L`；活动空格的含义在使用时才查，所以在比较的分组里用 `\EmptyObeyLet` 改）；在 `349f9f77` 上报 18 个错误。`final6-full-015816` 之后新增 9 项：stream 命令的正文只排出规则、盒子、glue、kern（`link-rule-L`、`link-fbox-L`、`link-hspace-L`、`link-mbox-rule-L`，以及用户注册的 `\RegStreamBody` 的 `reg-rule-L`、`reg-kern-L`、`reg-hspace-L`），与正文为空的 `reg-empty-L`、`reg-empty-C`；在 `ed9d7dc4` 上前 7 项失败（各 2 次，共 14 项）。同时新增 6 项正文里嵌套空命令的写法（`link-mbox-L`、`link-tc-L`、`reg-mbox-L`、`reg-mbox-C`、`reg-tc-L`、`uline-mbox-C`），确认内层留下的空盒子、颜色 whatsit 不算外层的输出。第三十七轮新增 8 项：正文以颜色 whatsit 结尾（`link-tc-rule-L`、`link-rule-nc-L`、`reg-tc-rule-L`）、先有空 `\mbox{}` 再排出内容（`link-mbox-then-rule-L`、`link-mbox-then-fbox-L`）、命令之前是盒子（`mbox-x-reg-rule`）、正文只有 `\special`（`link-special-L`、`reg-special-L`）；在 `91b0e0a2`（比较节点类型、kern、glue 的第一版）上失败。`loading01.tlg` 随之多一行 `\c__xeCJK_stream-begin_node_dim=\dimen...`（哨兵常量）。第三十八轮新增 TEST 16“verb whose body is only spaces”2 项：`\verb| |`、`\verb|  |` 两侧有空格（`verb-space-L`、`verb-2space-L`），`\verb` 不能写在宏参数里，所以用 `\BEGINTEST`/`\ENDTEST` 直接排盒子比较；在 `e1952979` 上 2 项失败。两侧是汉字、正文只有 `\special` 的 `中 \hyperlink{a}{\special{x}} 文` 与修复前相同（26.66pt），但直接输入 `中 {\special{x}} 文` 的 special 会挡住汉字之间的空格处理（23.33pt），不在本测试比较。`\EmptyReset` 同时改为清除 `\g__xeCJK_boundary_after_space_bool`。最终全范围审查 `final7-full-052308` 之后新增 TEST 17“stream body reading the node before the command”，在两种 `xCJKecglue` 下各 6 项：已注册 stream 命令的正文以全角标点开头、命令之前是全角标点（`reg-comma-paren`、`reg-period-paren`、`reg-period-quote`、`reg-rparen-paren`），以及正文以 `\unskip\footnote`、`\unkern` 开头（`reg-unskip-footnote-L`、`reg-unkern-L`）；在 `e1952979`（一律在列表里放哨兵节点）上 TEST 17 有 11 项失败（`reg-unskip-footnote-L` 只在 `xCJKecglue=false` 下失败）。第四十二轮补上 3 项（`reg-kern9-box-L`、`reg-kern9-box-C`、`reg-kern9-rule-L`）：命令之前是盒子或规则、正文只有一枚 `\kern9sp`，固定哨兵检查要核对那一对 kern 的两个值；在 `5d9017a9`（哨兵检查只比较一枚 kern）上 6 项失败，去掉第二次比较的变异版本上 4 项失败（`reg-kern9-rule-L` 在变异版本上通过）。`final8-full-064537` 之后再补 8 项：盒子开头与段首的全角左标点（`box-reg-paren`、`box-reg-book`、`mbox-reg-paren`，以及排进 `\vbox` 取最后一行比较的 `par-reg-paren`、`par-reg-quote`、`par-noindent-reg-paren`、`par-reg-mbox-paren`，辅助命令 `\EmptyParStart`），以及列表为空时正文开头读 `\lastnodetype` 的 `box-reg-lastnodetype`。在 `55c98ce1` 上前 7 项都失败；去掉 `\@@_Boundary_and_FullLeft_glue:N` 开头取下哨兵的变异版本上 3 项段首用例失败，把列表为空移出 `state` 的变异版本上 `box-reg-lastnodetype` 失败。另补 `reg-unkern-box-L`、`reg-unkern-C`：命令之前是盒子或汉字、正文以 `\unkern` 开头，比较对象是去掉 `\unkern` 的同一写法（直接输入的 `{\unkern x}` 会删去汉字之后的 marker，与修复前也不同）；在 `e26c0697` 上两项都窄 9sp。`Text \RegStreamBody{\unskip x} B`、`中。\RegStreamBody{（中}文` 一类在修复前就与直接输入不同，没有列入。脚注用到的数学字体在 `\START` 之前用 `\footnotesize $x^x$` 预先加载，`.tlg` 开头因此少了一行 cmex10 的 5pt 字体信息。
  - TEST 15 比较零尺寸盒子（第二轮前为 TEST 7，第四轮前为 TEST 8，第五轮前为 TEST 10，第六轮前为 TEST 11，第七轮前为 TEST 12，第九轮前为 TEST 13，`final-full-110923` 后之前为 TEST 14），4 项：有可见内容的 `A \mbox{\smash{\rlap{\rule{2pt}{1pt}}}} B`；第二轮后新增的 `disc/11`，即 `A \mbox{\discretionary{}{}{\kern0pt}} B`（末尾节点属于 `\discretionary` 的不断行文本，删不掉）；以及只有两枚相同 fil glue、没有输出的 `\makebox[0pt]{}`（`makebox0/11`、`makebox0-L/11`）。后两项来自同一处修改：空盒子探测最初用“删除前后末尾状态相同”判断删不掉，`\makebox[0pt]{}` 删去一枚 fil glue 后末尾状态也不变，被误判为有输出，审查者矩阵上 858 项回到修复前的结果；改为限制删除次数。
  - 修复前后相同、或修复前也与直接输入不一致的组合不列入；已接受的回退 `中{ }\cmd 文`（维护者决定，见 [[../memory/decisions/1103-group-space-before-empty-command]]）与第七轮登记的同类写法（空格与命令之间只有不排出内容的命令或空分组，`A \sbox0{x}\mbox{} B`、`A {}\mbox{} B`）也不列入。这些都登记在 [[../memory/doc-gaps]]。
- **判别力**（这一段的 TEST 编号是当时的编号，对应关系见上面“组成”各条括号）：第一轮审查前的 head 上，tie 类 216 项失败，`C-groupmath` 80 项失败（`C-colormath` 0 项，原因见上），TEST 6 报错。第二轮新增的用例在上一提交 `52217645` 上报错：TEST 7 报 `Forbidden control sequence found while scanning use of \__xeCJK_boundary_after_space_hook:N`，`disc/11` 报 `TeX capacity exceeded`（空盒子探测无限递归）。第四轮新增的用例在上一 head `410f365d` 上：当时的 TEST 9（现 TEST 11）失败 14 项，TEST 8 报 `Forbidden control sequence`。第五轮新增的用例在上一 head `be7e530c` 上：TEST 9（`\outer` 宏）报 `Forbidden control sequence`；去掉该 TEST 后，TEST 10 的新用例失败 18 项（9 项 × 两种设置）。第六轮新增的用例在上一 head `aed1f9d2` 上：TEST 10 的 `tc-color-L`、`tc-color-mbox-L`、`tc-normal-L`、`tc-uline-C`、`tc-xout-C`、`tc-uwave-C`、`tc-uuline-C`、`tc-dashuline-C`、`tc-uline-empty-L` 失败，各 2 次，共 18 次（当时还没有 `tc-dotuline-C` 与 `tc-xout-L`）。第七轮：在上一 head `61c313bd` 上，`\START` 之后那行分组层数 0 的 `\color` 报 `Erroneous variable`；注释掉那一行后，TEST 12 的 4 项失败；改写后的 TEST 11 在 `aed1f9d2`（子串查找版本）上 3 项都失败（TEST 11 只在默认设置下执行一次）。第八轮：TEST 9 的 4 项新用例在上一 head `61c313bd` 上报 `Forbidden control sequence`。修复 #1103 之前（PR 原 head 1008 项、master 1070 项失败）的数字是对 2305 项的旧版测试计算的。
- **oracle 的空格单独给出。** 用宏参数拼写法时，作为参数传入的两个空格记号不会像源码那样合并成一个，所以 oracle 的空格由第七个参数单独提供，两侧都有空格时只放一个。左侧以控制空格 `\ ` 结尾时，源码里紧跟的空格会被跳过，用记号拼出的写法却保留它，这类左侧因此只比较两侧都有空格的写法。
- **每次排版前重置全局状态。** 候选与 oracle 排版前都清空 `\g__xeCJK_last_node_tl`、把 `\g__xeCJK_glue_check_pending_bool` 置假，否则前一项留下的状态会带进下一项，产生假失败；构造外部矩阵（本地 `tmp/i1103/gen`）时曾因此出现假失败。外部矩阵重构后，先单独运行几个失败单元确认不是状态泄漏。
- **外部矩阵全对不能代替全量 `l3build check`。** 外部矩阵（9 左 × 9 右 × 10 命令 × 4 空格组合 × 4 间距设置）全部与直接输入一致时，全量检查仍发现 `hyperref-anchor-ecglue01` 与 `fntef-entry-space01` 失败；前者是给 `\hypertarget` 挂的检查删去了非空 `\hypertarget{t5}{锚}` 之后的间距，改为只在第二参数为空时检查。外部矩阵只覆盖设计时想到的命令与写法。
- **审查者的独立矩阵更宽。**（这一段的 TEST 编号按当前 `.tlg`。） 本地审查第一轮的审查者用 110448 组的外部矩阵比对，发现了本文件当时没有覆盖的表格单元格末尾、左侧 `~`、`\color` 后接公式等写法。修复后这个矩阵上相对修复前 base 的回退由 298 项降为 3 项，剩下 3 项都是 `中 \phantomsection{}$y$`（`10` 写法）：矩阵的 oracle 写成 `中 $y$`，但 `\phantomsection` 不读参数，删去命令后应是 `中 {}$y$`，base 与新代码都是 15.26pt，不是回退。用宏拼 oracle 时，删去不读参数的命令要保留它后面的 `{}`。这个矩阵的左侧没有 `{ }` 这类写在花括号里的空格，所以没有暴露 `X{ }\cmd Y` 的回退；第二轮审查者的矩阵包含它，在每种间距设置下各有 126 项（9 个命令 × 14 种右侧，`01` 写法），维护者决定接受，见 [[../memory/doc-gaps]]。第二轮审查还发现了 plain `\halign` 与 `\discretionary` 两类问题，即上面的 TEST 8 与 TEST 15 的 `disc/11`。各轮矩阵（含审查者的）都只把颜色命令当作被删去的命令本身来测，没有“颜色正文末尾有空格”这种由颜色命令隐式插入 `\reset@color` 的写法，也没有列模板以命令结尾的 `\halign`；最终全范围审查第四轮发现这两类，即上面的 TEST 11 与 TEST 9。本地审查第五轮又发现颜色正文以“空格 + 空命令”结尾、空命令之后紧跟 `\long\outer`／`\protected\outer` 宏两类，即 TEST 11 的新增项与 TEST 10。第六轮发现正文里另有 `\color`／`\normalcolor`、颜色命令里嵌套空线型命令、替换文本以 `\outer...` 开头的普通宏三类，即 TEST 11 的第六轮新增项与 TEST 12；TEST 10 的 `outer-D` 来自修复过程（第一版用 `\tl_to_str:n` 生成比较串，漏检 `\protected\long\outer` 宏）。第七轮发现分组层数 0 的 `\color` 报错（以前所有颜色用例都在 `\hbox` 或 `\TEST` 的分组里）与 `\sbox` 夹在两个空命令之间两类，即 `\START` 之后那一行与 TEST 13，并指出 TEST 12 在被替换的版本上也通过，没有判别力。第八轮的补充报告发现 `\outer` 宏之后还有文字时报错（TEST 10 原有的写法都以 `}` 结尾），即 TEST 10 的第八轮新增项。第九轮发现西文、命令之后有空格再接对齐记号时报错，即 TEST 8 的第九轮新增项与 TEST 7；第十轮指出 TEST 7 只比较整表宽度，改为按命令分表。

`fntef-entry-space01` 有 9 项期望值随直接输入改变：oracle 里的颜色命令本身是已注册的透明命令，#1103 后 `符 {\color{red}~中} 后` 由 36.66pt 变为 33.33pt，与 `符 {~中} 后` 一致（同组还有 `\hspace{1em}` 版 43.33→40.0、公式加尾随空格的两项各少 3.33pt）；另有一处节点列表在颜色 push 之后多出一对 marker kern。本地审查第五轮后，`sibling-color-then-nested-tie-cjk-spaced`（`符 \uline{\sout{\color{red}}\sout{~中}} 后`）的比较对象由 `符 {\color{red}}{~中} 后` 改为删去颜色命令的 `符 {}{~中} 后`：用户分组里的空颜色命令 `{\color{red}}` 本身修复前后都多一枚空格（doc-gaps 已登记），候选为 33.33pt，与新的比较对象相同。

### 注册点的字体上下文与锚点出口的覆盖清单（`codedoc-meta-symmetry01`、`hyperref-anchor-ecglue01`，#1046／#1047）

`codedoc-meta-symmetry01.lvt` 用**真实的 `l3doc` 文档类**（不是自己模拟内层函数）固定 12 项断言（9 个 `\TEST` 块）：四种源码空格组合各自与 oracle `左\texttt{$\langle$name$\rangle$}右` 等宽、左右两侧单边贡献相等且均为 13.33pt、左边界带 `plus` 分量（用 `\badness` 正向断言，因为 `\hbox to` 的实际宽度恒等于目标宽度、结构上恒真）、CJK 参数仍保持 `\hbox:n` 隔离（#920 不回退）、`\Arg` 与 `\oarg` 外侧贡献一致、纯西文上下文仍保留源码空格语义。判别力已实测：把注册点改回内层 `\__codedoc_meta:n` 后 8 项失败，数值为 1.92pt（等宽字体 5.25pt 减正文字体 3.33pt）、15.25pt 与 badness 10000。

**既有的 `codedoc-meta-ecglue01` 对 #1046 没有判别力**，不要据它判断该场景已覆盖：它自己用 `\cs_new_protected:Npn \__codedoc_meta:n` 模拟内层函数，**没有 `\texttt` 外层**，而 `\texttt` 正是这个缺陷的必要条件。这与 #1038 中既有 `tabular01` 因每行 `\\` 前有空格而没有判别力属同一类：测试用简化替身模拟被测对象时，简化掉的那一层可能正是缺陷所在。

`hyperref-anchor-ecglue01.lvt` 固定 12 项断言（10 个 `\TEST` 块，编号与 `.tlg` 块序一致），覆盖 hyperref 行内锚点已注册的三个出口，另含带 CJK 可见内容的目标仍按 CJK–CJK 处理、`\hyperref` 链接间距不受影响、以及一项固定已知缺口的断言。三个出口的判别力实测**互不重叠**——去掉 `\Hy@raisedlink` 注册只有 TEST 1、TEST 2 失败，去掉 `\hyper@anchor` 注册只有 TEST 3、TEST 4、TEST 5 失败，去掉第三处包装只有 TEST 8、TEST 9 失败——这一点本身是「这三处是彼此独立的出口」的证据，分支级改动因此得到分支级断言。判别力说明在 `.lvt` 里按断言文字指代，不用块编号。

但要注意判别力互不重叠**只**能证明「这两处都在路径上」，不能推出「按什么分派」，也不能推出「只有这两处」。本测试的注释曾一度写成「非空目标走 `\Hy@raisedlink`、空目标走 `\hyper@anchor`」，经盲审用计数器包装两个命令实测后更正：空目标、CJK 目标、西文目标、数字目标四种 `\hypertarget` 形式的 `\Hy@raisedlink` 调用次数**均为 0**，两个分支都经 `\hyper@@anchor` 落到 `\hyper@anchor`。真正的区分依据是调用点——`\Hy@raisedlink` 承接无编号标题、caption、公式编号、脚注、`\bibitem` 与下游手工包裹的抬升锚点（ctxdoc 的 `\exptarget` 即属此类，TEST 1、TEST 2 的 `\TestTarget` 就是复刻它）；目录**条目**不走这条路，`\contentsline` 用 `\hyper@linkstart`／`\hyper@linkend`，与抬升锚点无关。要判断某个公开命令走哪条内部路径，必须读分派函数的分支并用计数器实测，不能按参数形式推测。

同一段表述后来又连续出错两次，错误方式相同——都是从一个真实现象推出未经独立验证的解释：

1. 改对分派依据后写成「行内锚点有两个出口」。第二轮盲审用同一手段发现 `\__hyp_target_raise:n`（`\phantomsection`／`\MakeLinkTarget` 走它，编号标题锚点也经过它）是第三个出口。
2. 承认第三个出口后又写成「它不能用现成包装，需要新设计适配器」，把故障归因给 begin 钩子里的赋值，并据此把缺口写成已接受限制。第三轮盲审的隔离实验推翻了它：`\@@_boundary_hmode_transparent_begin:` 体内没有任何 `\spacefactor` 赋值（那个赋值来自 hyperref 自己的 `\Hy@SaveSpaceFactor`）；不挂任何钩子、仅做无花括号透传同样复现故障；把参数改成带花括号转发即回到 oracle。于是新增 `\@@_boundary_wrap_transparent_onearg_braced:NN` 关闭了缺口，原先断言「缺口仍在」的那一项改为正向断言（最终编号为 TEST 8、TEST 9）。

第四轮全范围复核又推翻了第三次修正后写下的「三个出口全部注册」：`\pdfbookmark` 经 `\hyper@anchorstart` 裸调用，四个候选函数里只有它计数为 1，`\pdfbookmark` 右侧仍缺 3.33pt。TEST 10 把这个缺口固定为断言，并且**文档从此不再给出出口总数**，只维护「已覆盖」与「已知未覆盖」两份清单——总数是一个连错四次的穷尽性断言，而两份清单各自都能被单条探针核查。

**写穷尽性断言（「全部」「三个」「只有」）或因果断言（「因为 X 所以坏」）之前，先问自己用什么手段排除了别的可能。** 隔离实验——去掉一个因素看故障是否仍在——往往一次编译就能定论。第三处包装的判别力也按这个标准实测了两种失败情况：去掉包装使三条断言各少 3.33pt，误用无花括号变体则同样三条失败但读数暴涨（42.83pt／15.0pt）。

**「实测过」要说清实测的是什么，并检查探针本身是否够用。** 本任务一处写着「去掉内层 capture 前后节点列表完全相同（实测）」，而当时做的其实是**宽度**比对。补做 `\showbox` 比对时我先用了单入口探针（`\hbox{左\Arg{name}右}`，预热行含 `\meta`），得到「无差异」，据此把「实测节点列表相同」写进了五处文档。收尾复核指出这不对：改用**同一个 `\hbox` 里放两个以上入口**的探针（`\Arg` 加 `\oarg`）即可看到差异——base 每个入口留有一对 `default` marker kern（±0.0002pt），改动后没有。单变量实验（只加回内层 capture）确认那对 kern 正由它产生。宽度与可见排版结果确实不变，所以实现无需改动，但断言必须改成「宽度与可见排版结果相同；节点列表少一对零效果 marker kern」。

两条可复用的教训：宽度相同不能推出节点列表相同；**节点级比对的探针里，预热与单一入口都可能掩盖差异**，同一容器内放多个同类入口才能暴露。

**手写 MWE 前先确认 `TEXINPUTS` 指向的 `.sty` 真的存在且是当前版本。** 本任务有一次把「注册 `\hyper@anchorstart` 会把已修好的两处拖回缺陷状态」写进了五处文档，实际原因是清理 `build/` 之后忘了重新 `l3build unpack`：`TEXINPUTS=.../build/unpacked:` 指向一个不存在的目录时，`xelatex` **不报错**，而是静默回落到系统 TeX Live 里安装的旧版 `xeCJK.sty`——于是所有读数都是修复前的值，看起来就像新注册破坏了已有修复。

这类失效尤其难发现，因为退化后的读数恰好等于该缺陷本身的值（都是 38.33002pt），与「注册引起退化」的预期完全吻合。防范办法有两条：跑 MWE 前 `grep` 一个只存在于当前改动里的函数名确认 `.sty` 是新的（例如 `grep -c onearg_braced build/unpacked/xeCJK.sty`）；以及**任何「X 导致 Y」的结论都要跑一次去掉 X 的对照**——这次只要跑一遍不注册 `\hyper@anchorstart` 的版本，就会看到它同样是 38.33002pt，立刻排除因果。

这两个测试还固定了三条测量类用例的设计约束：

- **一律用 `\newbox` 具名寄存器，不要用 `\setbox0`--`\setbox15`。** l3doc 的 `\meta` 内部经 `\ensuremath` 排尖括号，会用掉低位 scratch 寄存器；用 `\setbox10`／`\setbox11` 存测量结果会读到 `0.0pt` 与被污染的数值，失败表现看起来像实现缺陷而不像测试问题。
- **字体预热要覆盖被测命令自己切换到的字形**，不只是测试正文显式用到的字体。`\meta` 的参数用 `\meta@font@select`（`\itshape`）排版，CJK 斜体还要经过自动伪斜；不预热时 `左\meta{中文}右` 实测在 54.4378／76.23781／135.92561 之间跳。判断方法是读被测命令的定义体，把它切换的每一种字形都在 `\START` 前排一遍。
- **不要用依赖 `.aux` 的量做宽度比较。** `l3build` 只编译一遍，`\ref`／`\pageref`／`\cite`／`\nameref` 取到的是占位符——`\ref` 排出两字符的 `??`，与最终编号差 5.86pt。需要测引用命令周围的间距时，改用不依赖 `.aux` 的等价入口，例如 `\hyperref[...]{显式文字}`。

### halign 语境下参数含对齐符（`halign-amp-boundary01`，#1043）

`halign-amp-boundary01/02/03.lvt` 固定 boundary 语法判断在 `\halign` 语境下不被 catcode-4 的
`&` 打断（机制见 [[../architecture/xecjk-architecture]]「语法判断前必须消解参数里的对齐符（#1043）」）。
**三种语境各自独立成文件**：01 是 `eqnarray` 内 `\colorbox` 参数含 `&`，02 是 `tabular` 内同写法，
03 是与 CJK 相邻时 ecglue 仍照常插入。必须分文件——`checkopts` 带 `-halt-on-error`，
合在一个文件里时缺陷态下首项一报错即中止，实测其后的 `TEST 2`／`TEST 3` 出现 0 次、
判别力无法观察（首版正是这样写的，等于两项空转）。这与本文档下方「每个能独立触发该缺陷的
用例都要有自己的文件」以及 #1038 的先例一致。

判别力已逐个实测：删除 `\@@_boundary_math_set:n` 体内的替换（还原缺陷）后，三个文件
`l3build check` 退出码均为 1（01 报 `! Argument of \__tl_tl_head:w has an extra }.`）；
修复版三个均为 0。缺陷态的报错条数取决于观察条件与文件结构（`l3build check` 带 `-halt-on-error`，只能看到
首条；手动 `-interaction=nonstopmode` 则是一长串，且随是否合并、是否走 `regression-test`
框架而变），所以判据只用「缺陷版 rc 非 0、修复版 rc 0」，不引用具体条数。

两条边界必须记住，否则会误改：

- **该测试固定的是「不报错」，没有固定 `\scan_stop:` 的占位语义。** 把替换值改成 `{ }`
  （删除）或 `{ $ }` 时本文件仍全绿。占位的理由（`&$x$` 的首类别判定）只有直接探针
  能验证，若要纳入测试，需要新增一个断言首类别结果的用例。
- **`\colorbox` 参数里放裸 `&`（如 `\colorbox{yellow}{&$x$}`）不能写进基线**：这本身就不是
  合法 LaTeX，不加载 xeCJK 也报错。实测**首条**是 `Missing } inserted.`，其后是一串对齐相关
  的连带报错（`Missing \cr inserted.`、`Misplaced \cr.`、
  `Extra alignment tab has been changed to \cr.` 等，具体序列随语境与列数不同；
  `Misplaced alignment tab character &.` 只在某些多列语境下出现，实测还取决于出错单元之后是否仍有可用的对齐列）。写文档时只固定「首条」
  这种可复现的弱断言，不要声称某个串「不出现」——它们多半作为连带错误在后面出现。
  首版基线曾误把这串报错固定下来，等于把上游限制冻结成本包预期。

`\textcolor` 走另一个适配器但共用同一判断入口，故不需要单独用例。实测判据只取可复现的
那一条：**`tabular` 语境下 `\textcolor` 参数含 `&` 时，缺陷版报错、修复版为 0，而不加载
xeCJK 也是 0**——三档齐全才说明是本包修好的，不是「修回发布版」。具体错误条数随样例
写法浮动（我的样例缺陷版为 25），所以判据用「非 0 → 0」而不是某个具体数字。
`eqnarray*` 语境不能作判据——该写法本身不合法，不加载 xeCJK 也报 26 个错，修复后仍为 26。
同理 `\uline` 同场景在不加载 xeCJK 时亦失败，属上游 `ulem` 限制，不在范围内。
（这三档必须分文件跑：合并在一个文件里前一个报错会污染后面的计数。）

### `\sbox`／`\savebox` 全局前缀回归（`boundary-sbox-global01`，#1029）

`boundary-sbox-global01.lvt` 固定 `\@@_boundary_sbox:Nn` 把暂停观察移进盒子内部之后，`\global` 前缀必须始终紧邻 `\setbox` 这条约束（机制见 [[../architecture/xecjk-architecture]] 「命令钩子与专用适配器的选择边界（#1029）」一节）。测试覆盖：

每一项使用**各自独立的 savebox**。共用一个盒子会让前一项留下的全局值被后一项读到，测试看似通过却没有断言任何东西——这个坑在本次审查中真实发生过。

- `\global\sbox` 跨分组保住内容（21.8pt）：缺陷版下退化为 0.0pt。
- 直接对内部入口加前缀：`\expandafter\global\csname sbox \endcsname`（57.85pt），单独固定适配器本身的前缀透明性。
- `\global\savebox` 跨分组**仍为 0.0pt**。这不是本包的缺陷：`\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，未加载本包的原版 LaTeX 亦然。把这条既有限制一并固定，避免日后误判为回归；上游若修好，该项会提示更新。
- 不带 `\global` 的普通 `\sbox` 仍是局部赋值：退出分组后应恢复为分组前的内容，确认修复没有把局部赋值意外提升为全局。
- 嵌套 `\sbox`：外层 `\global\sbox` 内部再离线测量，并**显式打印** `\g_@@_boundary_suspend_depth_int`（前后均为 0）。只报盒子尺寸发现不了深度泄漏。
- 暂停观察语义：`\hbox{中\fbox{\sbox\tb{中文}Alpha}文}` 与 `\hbox{中\fbox{Alpha}文}` 同宽（63.19998pt）。scratch box 里必须藏**与外层不同的类别**（西文正文中藏 CJK）才有判别力；写 `\sbox{english}` 不改变末类别，删掉隔离也照样通过。

`gh-assets:issues/1029/` 另存一份按 #992 矩阵格式补的 sbox 专项矩阵（`command-boundary-sbox-matrix.tex`，6 场景 × `00/10/01/11` × 四种配置 = 96 单元），用于证明换实现没有丢掉 #992 引入的隔离语义：base `05baf1e0` 与修复后同为 96／96，而删掉 `suspend`／`resume` 的对照组为 72／96（失败集中在 `scratch-in-fbox`、`scratch-hidden-CJK`，delta 3.33pt／4.0pt）。回放这类「引入被改代码的那个 issue」的场景时必须带上撤销语义的对照组，否则全绿矩阵不能说明自己有判别力。

三项判别力均以变异实测确认，各自 rc 1：还原为两个通用钩子（outside 退化为 0.0pt）；删掉 `suspend`／`resume`（本项自设 `CJKecglue=5pt`／`CJKglue=1pt`，宽度由 63.19998pt 降为 59.19998pt，差 4.0pt；同时 `command-boundary01` 的 `scratch-hidden-CJK` 也失败，那里默认 glue 下的差值是 3.33pt，两者不是同一个量）；去掉 `\int_gdecr:N`（深度由 0 变 6）。完整决策见 [[../memory/decisions/1029-sbox-adapter]]。

`gh-assets:issues/1002/` 的四套外部矩阵每套包含 272 个单元；当前实现下 `false-default`、`false-custom`、`true-default`、`true-custom` 均为 272／272。#992 第 28 行的四个旧跳过已经改为实际断言。不过 #992 的公开活表仍只记录已合并实现：PR 合并后必须从合并提交重新运行矩阵，才能把对应红叉改成绿勾。完整决策见 [[../memory/decisions/1002-inline-math-boundary-oracle]]。

`xeCJK/testfiles/command-boundary02.lvt` 提供 15 个 paragraph/node oracle，锁定宽度比较看不见的节点语义：段落模式 box、带源码空格的 transparent、CJK link stream、ulem 外层非装饰 CJKglue、普通显式 elastic glue、词间空格同构 glue、`\null` 与赋值型 `\null`、`\cs` 的西文/CJK 末尾，以及 `\kern0pt` 处理方法。新增三项分别确认：盒子内部末尾大写字母后的源码空格变成 5pt `CJKecglue`；有源码空格时，`\null` 后的恢复链把显式 7pt glue 换成 5pt；没有源码空格时，7pt glue 原样保留。节点测试启用 `\loggingoutput`；FandolFang 等 lazy font family 必须在 `\START` 前预热，否则首次 fontspec Info 会污染规范化日志并在不同平台产生伪 diff。

同一文件新增 TEST 16–19 固定 post-transparent 的 `\@@_boundary_post_transparent_relocate_glue:` 在候选 glue 为无限阶（fil/fill）时不搬运这条判断条件（#1085）：TEST 16（`\hfill`）与 TEST 17（`\hfil`）直接固定 `\hfill CJK文字 \hfill\null` 类居中写法里节点序须为「marker、glue、盒子」，撤掉修复会红；TEST 19 在 `\begingroup`／`\endgroup` 包住正文时复核同一断言。TEST 18 用 finite 的 `\hskip 30pt` 覆盖判断条件不收紧成 `\@@_skip_if_interword:N` 那种 finite+shrink+等宽词间空格判据这一条边界，但对 #1085 本身无判别力——finite glue 在新旧逻辑下都照常搬运，撤掉修复重跑该测试不在 diff 里，只作正向锚点。四项均未增删测试文件，`command-boundary02.lvt` 仍是同一个文件，标准测试数不变，仍为 123／123。

TeX glue 节点不记录来源。已注册命令右侧若出现显式 `\hskip`，而它的自然宽度和 shrink 与词间空格完全相同，恢复逻辑就无法判断它是源码空格还是显式 glue。需要保留时，可在前面加 `\kern0pt`，也可以改变自然宽度或去掉 shrink。测试必须明确记录这项限制和处理方法；继续向前检查更多节点也无法找回来源信息。

`ref-ecglue01.lvt` 与 `ref-ecglue02.lvt` 继续专门覆盖 #991：无 hyperref 36 次、加载 hyperref 40 次，共 76 个比较，包含数字/西文、CJK、混合末尾、两种外围类别、四种源码空格、starred path、未定义引用和 `CJKspace=true`。每次 oracle/candidate 前只重置当前真实状态：`\g__xeCJK_last_node_tl` 与 `\g__xeCJK_glue_check_pending_bool`；#991 saved-node、颜色 pending 和 hyperref 专用 marker 均已删除。无 hyperref 的 `\@setref` 或 hyperref 的 `\real@setref` 由 auto stream 处理，内核 `\null` 由一般 post-transparent 路径保持透明。

`listings-color01.lvt` 另有 20 个逐格 direct-input oracle，覆盖 `\lstinline{...}` 的西文、CJK、两种混合首尾，以及 `\lstinline|...|` 的分隔符路径；每格分别比较 `00/10/01/11`，不能要求四个 oracle 宽度彼此相等。首次 CJK inline 的 lazy math 字体加载在 `\START` 前预热。

`colorbox-measure01.lvt` 锁定 #995：`\settowidth{...}{甲\colorbox{yellow}{乙}}` 离线测量前后，各构造两组相同源码的对照盒子（含 `\special` whatsit 的盒子、纯文本盒子）逐次比较 `\wd` 相等，确认颜色 push/pop 改为 `transparent` 注册后不再向 `\g_@@_last_node_tl` 写入可污染后续测量的全局状态。

`boundary-crossbox01.lvt` 检查 #996：`\@@_glue_check_expire_stale:` 在最外层恢复逻辑发现节点列表为空时清除过期的 `\g_@@_glue_check_pending_bool`，阻止它越过 `\hbox` 或 `\setbox` 分组。测试还覆盖同一盒子与不同盒子中的显式 glue、`\kern0pt` 处理方法、两个方向的源码空格处理，以及 `xCJKecglue=true` 下 #996 的两个相同盒子，共 9 个断言（8 个宽度断言和 1 个 pending 状态断言）。与 `command-boundary01` 的 `\BoundaryReset` 一样，这个测试直接读写 `\g__xeCJK_last_node_tl`、`\g__xeCJK_glue_check_pending_bool` 两个内部变量，以隔离各测试并检查变量的生命周期；它们不是公开 API，内部重命名时必须同步修改这些 `.lvt` 文件。

`siunitx-ecglue01.lvt` 锁定 #1000 与 #1092：31 组 `\BoundaryMatrix`，每组比较 `00/10/01/11` 四种源码空格，再分别运行默认／可区分间距和 `xCJKecglue=false/true`；另有 5 组 `\BoundarySides` 分别比较左侧与右侧，合计 576 次宽度比较；math 内嵌的 `\unit`、`\qtyrange` 另检查 capture 栈归零。31 组的组成如下：

- #1000 的 9 组：`\unit`/`\qty`/`\num`/`\si`/`\SI`、中文与西文上下文、`\unit` 可选参数变体。
- #1092 的 16 组：区间、列表、乘积、复数、时长、角度与 `\SIrange`/`\SIlist` 的中文上下文（区间另有西文上下文），以及中文 `range-phrase=至` 与 `range-units=bracket` 两种写法。
- #1092 的 6 组输出以汉字开头或结尾的矩阵：`range-open-phrase=从`、汉字单位（`\qty`、`\qtyrange`、`mode=text` 下的 `\qtylist`）、汉字 `duration-unit-*`、`angle-symbol-degree=度`。汉字单位用 `mode=text` 或 `\text{元}` 包住；直接在数学模式里排汉字时数学字体没有该字形，日志报 `Missing character`，宽度比较没有意义。
- #1092 的 5 组单侧比较（`\BoundarySides`）：以 `\text{元}` 开头、以数学字母结尾的单位（`\qty{5}{\TextYuan\per\kilogram}` 等）只在公式前报告 Default 时，右侧少补 `\CJKecglue`。`\BoundaryMatrix` 只比较“中 命令 文”的总宽度，一侧多一枚、另一侧少一枚会互相抵消，所以这类写法要分开比较两侧。

oracle 用首尾字符相同的文本，而不是裸写 `$5$`：`xCJKecglue=false` 且两侧有源码空格时，注册命令两端报告 Default，源码空格变成 `\CJKecglue`，与公式边界的结果不同。变异结果：改回固定 Default 首尾时，6 组汉字边缘矩阵各失败 16 次；去掉 `\siunitx_print_math:n` 的补报时，所有输出数学内容的命令都失败；注册列表退回 #1000 时，14 组中文上下文矩阵各失败 16 次（`d78b1bbf` 时的结果）；去掉公式之后的补报时，3 组 `\text{元}` 加数学单位的右侧各失败 8 次，把“末项是 `\text`”判断恒置为假时，汉字单位结尾的矩阵失败。

本地 TeX Live 的 siunitx 可能比 CI 旧（#1092 时本地 3.5.5，CI 3.6.3）。l3build 不读外部 `TEXINPUTS`；要用另一版本的 siunitx 复现，先跑一次 `l3build check` 生成 `build/test/`，再把该版本的 `.sty`/`.cfg` 复制进去，在该目录直接 `xelatex` 编译 `.lvt`，用完删除复制的文件。预热段（`\OMIT`/`\TIMO`）先消化 siunitx 数学字体加载与旧名 deprecation 消息，避免污染规范化日志。

`xecglue01.lvt` 除了检查 `false/true` 的基本行为，还锁定 `xCJKecglue=<glue>` 与 `CJKecglue=<glue>, xCJKecglue=true` 的等价关系。这个小型断言保护简写入口，不重复整张命令边界矩阵。

### microtype 突出量回归（`microtype-slot01`，#1104）

`microtype-slot01.lvt` 固定 xeCJK 为 microtype 查回歧义字符槽位时同时设置 `\MT@char` 与 `\MT@char@`（机制见 [[../architecture/xecjk-architecture]]「与 microtype 的兼容（#1104）」一节）。断言是 `\lpcode`/`\rpcode` 的数值，参照值取自把 xeCJK 换成 fontspec 的同一文档，两者逐项一致。

- 正文字体用 TeX Gyre Termes：它没有专用的 microtype 配置，突出量按字符宽度计算，修复前后的数值才会不同。Latin Modern 有专用配置，修复前后的 TU 数值相同，没有判别力。
- 在 XeTeX 里，OpenType 字体的 `\lpcode`/`\rpcode` 按字形序号保存，查询时要写 `\lpcode\font U"2014`；写 `\lpcode\font"2014` 得到的是 8212 号字形的值（通常为 0）。TFM 字体只能直接写槽位。
- l3build 遇到第一个错误就停止编译。修复前 `TS1/cmr` 那一项会报 `Cannot use XeTeXglyph`，所以放在最后，前面 TU 字体的错误数值在修复前也能出现在日志里。修复前与修复后的差异是 U+2013 67/67 → 100/100、U+2014 50/50 → 150/150、U+201C/U+201D 100/100 → 133/133，以及最后一项的报错 → 183 号槽位 83/111；U+2018/U+2019 和逗号对照项前后相同。
- 测试加载 microtype，因此 `.github/tl_packages` 加入了 `microtype`。`TS1/cmr` 用到的 `tcrm1000` 来自已有的 `ec`，`mt-cmr.cfg` 随 microtype 安装。

`gh-assets:issues/1104/` 存放 issue 的 MWE、节点列表（第一行两端 margin kern：修复前 `-1.0`/`-0.5`，参照与修复后 `-1.33`/`-1.5`）和对比图。对比图里的引号和破折号必须用 `\textquotedblleft`、`\textemdash` 等文本命令输入：直接输入的“—”等字符在 xeCJK 中默认按 CJK 字符排版，不经过 microtype 的这条路径。此外，xeCJK 会在 `\linebreak` 或段落结束之前、西文字符之后留下一对 `\kern -0.0002pt`/`\kern 0.0002pt`，挡住该行行尾的右侧突出（只加载 fontspec 时没有）；对比图因此在行尾的空格处自然断行，不用 `\linebreak` 或 `\parfillskip=0pt`。这一现象作为已知限制记在 [[../architecture/xecjk-architecture]]「与 microtype 的兼容（#1104）」一节。

证据分三层使用，不能互相替代：

1. `command-boundary01` / `ref-ecglue01/02` 的宽度 oracle 证明边界几何等价。
2. `command-boundary02` 与既有 `.tlg` 的节点 oracle 区分 glue、kern、box、math 和 whatsit。
3. `gh-assets:issues/992/` 的默认/可区分 glue MWE 与截图供人工审阅；它们是 issue 证据，不是包回归基线。

可视 MWE 的说明层不得再经过被测状态机。`\texttt{\detokenize{...}}` 仍受 xeCJK 影响，会让四种源码空格组合看起来相同；`\verb*` 又不能放入普通宏参数。稳定 harness 应让第一阶段从调用点直接扫描 starred verbatim 源码并显式标出空格，分隔符结束后再调用第二阶段测量 oracle/candidate。PR 上可以保存未合并实现的拟更新表；#992 活表必须等实现合并并从合并提交复验后再同步。

### `ctex` 主测试目录当前覆盖面

本轮扩展后的 `ctex` 主测试目录已形成几组稳定覆盖簇：

- `ctexset-*`：覆盖分组作用域、导言区设置、meta key、非法输入、空值重置、多键组合与覆盖顺序，例如 `ctex/test/testfiles/ctexset-scope01.lvt`、`ctex/test/testfiles/ctexset-preamble01.lvt`、`ctex/test/testfiles/ctexset-invalid01.lvt`。
- `cjkfntef-luatex01/02`：分别覆盖 LuaTeX 下后续 `CJKfntef` 请求被禁止载入且字体仍可配置，以及包先载入时触发 critical 的分支。fatal-path 测试截获目标 `\msg_critical:nnn` 后立即结束，避免继续进入已污染状态产生无关的 LuaTeX-ja 二次错误。
- `heading-*`：集中覆盖 heading key 簇，包括 `break`、`afterskip`、`beforeskip`、`hang`、`runin`、`afterindent`、`numbering`、`fixskip`、`pagestyle`、`aftertitle`、`titleformat`、`tocline`、`starred`、`longtitle`、`defaults`、`name`、`format/+` 追加语法与 `indent` 等；`heading-query01` 另以 `ctexbeamer` 覆盖 part/section/subsection 的编号、完整标签、编号开关、局部动态设置与分组恢复，已从“章节标题可用”扩展到“标题系统各键及公开查询接口的契约级回归”。`heading-fixskip02`（`ctexbook`）、`heading-fixskip03`（`ctexart` + `titlesec`）与 `heading-fixskip04`（`ctexart` + `caption`／`subcaption`，`belowskip=-12pt`，固定 caption 包住 `\@xfloat` 后 ctex 的钩子仍然生效）覆盖 #1100：紧跟 fixskip 标题、就地放置的 `[h]` 浮动体之后 `\prevdepth` 等于 `fixskip=false` 时的值；`t`／`b`／被推迟的浮动体、标题后先有盒子／段落／`\hrule`、中间隔着不开启 fixskip 的标题时保持 -1000pt 或原值；另覆盖 runin 标题、`\part`、`titlesec` 接管的 `\section`（带 `\titlerule`）及其后接 runin 标题。机制见 `llmdoc/architecture/ctex-architecture.md`「fixskip 与紧跟标题的浮动体」。
- `scheme-*`：覆盖 `scheme=plain` / `scheme=chinese` 的默认行为差异与标题输出差异，例如 `ctex/test/testfiles/scheme-plain01.lvt`、`ctex/test/testfiles/scheme-compare02.lvt`。
- 类与文档结构：`ctexrep01.lvt`、`ctexbeamer01.lvt`、`beamer01.lvt`、`beamer02.lvt`、`matter01.lvt`、`sub3section01.lvt`、`ctex-noheading01.lvt` 等覆盖 `ctexrep` / `ctexbook` / `ctexbeamer` 基础行为、`heading=true`、三级节、`frontmatter` / `mainmatter` / `backmatter`。
- 字体与字号联动：`autoindent01.lvt`、`ccwd-selectfont01.lvt`、`ccwd-zihao01.lvt`、`ziju-scope01.lvt`、`ziju-edge01.lvt`、`ctexsetfont01.lvt`、`zihao-sizes01.lvt`、`zihao-parindent01.lvt`、`fontfamily01.lvt`、`fontfamily02.lvt`、`cjkfamily-default01.lvt`、`cjkfamily-default02.lvt` 等覆盖 `\ccwd`、`\ziju`、`\CTEXsetfont`、`\zihao` 全尺寸、段首缩进与 CJK 字体家族切换；其中 `autoindent01` 以四引擎基线锁定 #402 的零缩进例外：启用非零 `autoindent` 后把 `\parindent` 置零并切换字号，结果仍为 `0pt`。
- 行距与间距：`linespread01.lvt` 至 `linespread03.lvt`、`linespread-scope01.lvt`、`linestretch-interact01.lvt`、`punct.lvt`、`punct-width01.lvt`、`cjkglue-width01.lvt`、`ccglue01.lvt`、`ccglue02.lvt`、`ccglue03.lvt` 覆盖 `linestretch` / `linespread` 交互、标点宽度与 CJK glue 宽度。`ccglue01`／`ccglue02` 对 LuaTeX 与 upTeX early-exit（`not tested yet.`），只覆盖 pdftex/xetex；`ccglue03`（#1068）专测这两个被跳过的引擎，固定 `\selectfont` 不再重置用户已设的 `kanjiskip`（LuaTeX 走 `\ltjsetparameter`、upTeX 走原语 `\kanjiskip`），三个文件不重复覆盖同一引擎组合，见下方「`\selectfont` 重置用户汉字间距（#1068）」一节。
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
8. 测试文件里的引擎 early-exit（`LuaTeX: not tested yet.` 一类）是覆盖缺口的标记，不是覆盖已完成的证明。`ccglue01`／`ccglue02.lvt` 对 LuaTeX／upTeX 打这行字符串直接跳过整个文件；#1068 的缺陷恰好只在这两个引擎上出现，说明四引擎目标下若某个主题的测试对某些引擎恒为 early-exit，应当反过来问「这些引擎是否真的不需要测」，而不是把 `not tested yet.` 当成暂时性占位默认忽略。
9. 排版过程的日志随引擎变化时，用 `\OMIT`／`\TIMO` 包住排版，把判据结果（写成 `same-as-nofixskip` 这类分类字符串，而不是具体尺寸）先存进序列，在 `\TIMO` 之后统一 `\TYPE` 输出，这样一份 `.tlg` 就能通过四个引擎。例子见 `heading-fixskip02.lvt`（`\test_log:n`、`\test_report:`，#1100）。
10. 用例之间不要共享状态。参照用例不要放进分组：标题设置的 `\everypar` 是局部的，会随分组结束丢失，而 `\if@nobreak`／`\if@noskipsec` 是全局的，会留下来污染后面的用例。多个用例用 `\ctexset` 切换同一选项时，每个用例都要显式设定这个选项，不依赖前一个用例留下的值。#1100 中参照用例设了 `fixskip=false`，后面的用例没有设回 `true`，“去掉次数判断”这一变异起初因此没有被检出。

这些模式说明：`ctex` 回归测试不只是“补一些 .lvt 文件”，而是已经沉淀出一套面向多引擎中文排版的可复用测试方法学。

### `\selectfont` 重置用户汉字间距（`ccglue03`，#1068）

`ctex/ctex-engine.dtx` 里给 `\@@_update_stretch_auxii:` 补 `\ctex_if_ccglue_touched:`
守卫的那段 `\ctex_at_end:n`，原先被 docstrip 守卫限定在 `%<*pdftex|xetex>`，LuaTeX 与
upTeX 都没有它。`\ctex_update_stretch:` 按 `linestretch` 是否为 `\maxdimen` 二分：
等于时走 `\@@_update_stretch_auxi:`（自带守卫），默认值 `\ccwd` 下走
`\@@_update_stretch_auxiii:`（当时无守卫），于是这两个引擎下用户设的
`kanjiskip`／`\CJKglue` 会被每次 `\selectfont` 覆盖。判据是解包产物里
`\@@_update_stretch_auxii:` 重定义的出现次数：修好前 xetex 侧 1 处、luatex／uptex
侧 0 处；修好后五个引擎（含 aptex）均 1 处。

修法是去掉那段的 `%<*pdftex|xetex>` / `%</pdftex|xetex>` 守卫标记，让它对所有引擎
生效；三套引擎各自的 `\ctex_if_ccglue_touched:` 判断逻辑本身早已存在（未新增代码）。

`ccglue03.lvt` 专测 LuaTeX 与 upTeX：默认（未设置）时间距仍随字号更新
（实测 0.60931 → 2.89365 → 0.60931pt），用户设置后 `\selectfont`／`\zihao` 均不再
覆盖它；`linestretch` 的两个取值也各有断言（`\ccwd` 走 `auxiii`、`\maxdimen` 走
`auxi`）。测试用绝对单位写死间距（`10pt plus 1pt minus 1pt`），不用 `em`／`\ccwd`
一类相对单位——`\linespread` 改字号后相对单位的期望值本身会变，读数无法区分
「被重置」与「随字号正常缩放」。

已确认但本次未处理的既有行为：`\ccwd = kanjiskip + \zw`（`\ctex_update_ccwd:`），
修好后用户设置生效会连带改变 `\ccwd`／`\parindent` 的数值，这是既有语义，不是本次
修复的副作用（用 `\ctexset{linestretch=\maxdimen}` 这条早已支持、走 `auxi` 分支的
配置对照，读数逐字节相同）。`linestretch` 不能作类选项
（`\documentclass[linestretch=\maxdimen]{ctexart}` 静默失效，`\ctexset{...}` 生效）
这一点同样未处理，见 `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`。

此外，现在还维护多个专项测试配置：

- `ctex/test/config-cmap.lua`：CMap 相关测试
- `ctex/test/config-contrib.lua`：contrib 目录相关测试
- `ctex/test/config-ctxdoc.lua`：`support/ctxdoc.cls` patch 健康检查，测试目录为 `ctex/test/testfiles-ctxdoc/`

其中 `config-ctxdoc` 使用 `testfiledir = "./test/testfiles-ctxdoc"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，并通过 `checksuppfiles = {"ctxdoc.cls"}` 把本地 `support/ctxdoc.cls` 复制到 check 目录，确保测试覆盖仓库中的当前实现，而不是系统安装版本。该配置现有两类测试：`patch-health.lvt` 传入 `fontset=fandol` 后加载 ctxdoc，验证 patch 在 nonstop 模式下也能以致命错误暴露失败；`resize-function.lvt` 使用 `\loggingoutput` 固定函数条目的节点结构，覆盖 Added 日期、rEXP、pTF 与长函数名的等差档位/极端自适应水平压缩，防止日期行被连带缩放或可展性标记越过边注宽度。

ctxdoc 自 #963 起明确要求 l3doc 2026-06-18；本地 `config-ctxdoc` 在更旧版本上会经 `\ctex_patch_failure:N` 直接终止。l3doc 由 TeX Live 的 `l3kernel` 包提供，遇到该校验时应更新 `l3kernel`，并按下文 usertree 双步同步流程重建 `xelatex` format，避免新类文件与旧 format 中的 expl3 支持层不匹配。

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
- `xpinyin`：主目录 `testfiledir = "./testfiles"`、`stdengine = "xetex"`、`checkengines = {"xetex"}`，见 `xpinyin/build.lua`；另有 `test/config-cjk.lua` 把 `testfiledir` 换成 `./testfiles-cjk`、`stdengine`／`checkengines` 换成 `pdftex`，专门覆盖 CJKutf8/pdfTeX 路线。为什么要拆两套见下方「xpinyin 的注音回归（#1041）」一节。
- `zhlineskip`：`stdengine = "pdftex"`、`checkengines = {"pdftex"}`，见 `zhlineskip/build.lua`。zhlineskip 已完成 DocStrip & L3 重构（PR #892 / #373），现以 `zhlineskip.dtx` 为单一源：`unpackfiles = {"zhlineskip.dtx"}` 解包出 `.sty`、`installfiles = {".sty", ".ins"}`、`sourcefiles = {".dtx", "*.pdf"}`、`demofiles = {"zhlineskip-test.tex"}`，版本号集中在 `build.lua` 顶部由 `update_tag` 钩子回写 `.dtx` 的 `\GetIdInfo` 行。测试使用 vbox 尺寸捕获策略验证行距行为。

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。`zhnumber` 另有 `test/config-cjk.lua`（仅 xetex），把 `testfiledir` 换成 `./testfiles-cjk`，专门覆盖 `\zhnumwithoptions`／`\zhdigwithoptions` 兼容入口的实际排版行为（见下文「zhnumber 的计数器选项回归（#1008）」）与算筹 `\zhrod`／`\zhrodbox` 的实际输出（见下文「zhnumber 的算筹数字回归（#366）」）。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。
- `xpinyin`：已有独立 `testfiles/` 加 `testfiles-cjk/` 两套，分别覆盖 XeTeX/xeCJK 与 CJKutf8/pdfTeX 两条互不复用的适配路线（#1041）。

因此，修改 `xeCJK`、`zhnumber` 与 `xpinyin` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

### xpinyin 的注音回归（#1041）

xpinyin 接入按 tag 构建发布包的自动化流程后，此前唯一的验证是 `check-doc.yml` 里 `l3build doc` 编得过手册——那只能说明 PDF 能生成，不能说明注音行为正确。#1041 补上了独立回归测试目录并接入各条 workflow；宏包代码本身未改动。

**引擎覆盖为什么是 xetex + pdftex，且两者都必须跑。** xpinyin 用 `bool_lazy_or:nnF { xetex } { pdftex }` 把 luatex 挡在 `\msg_critical:nn` 上（实测 lualatex 直接以 "Engine `luatex' is not yet supported" 中止），所以只有两条路线。而两条都必须测：包内 `\@@_adjust_xeCJK_hook:` 与 `\@@_adjust_CJK_hook:` 是两套互不复用的适配（字体选择、码位转换、接管 `\CJKsymbol` 的方式都不同），只测 xetex 会让 CJKutf8 那一半完全没有覆盖。

**为什么必须分两个 `testfiledir`。** `l3build check` 把目录下每个 `.lvt` 都拿去跑 `checkengines` 里的每一个引擎，没有按文件指定引擎的机制；两条路线的用例混在一起会互相拿对方的引擎跑，并因缺基线报 "failed to find any reference or expectation file"。因此主目录 `xpinyin/testfiles/` 走 xetex，pdfTeX 那条线单独放进 `xpinyin/test/config-cjk.lua` + `xpinyin/testfiles-cjk/`，仿 `ctex/test/config-cmap.lua` 等既有专项配置的做法（跑法：`l3build check -c test/config-cjk`）。`config-cjk.lua` 把 `checkdeps` 显式清空——CJKutf8 路线不加载 xeCJK，不需要复制它的产物。

测试文件按观察通道分工（新增用例时在此登记，不在文档里冻结总数）：

- `xpinyin/testfiles/pinyin-tone01.lvt`（31 格）：声调数字到重音命令的映射，oracle 取直接写 `\=`、`\'`、`\v`、`` \` `` 的字面形式，比宽、高、深三个维度。
- `xpinyin/testfiles/pinyin-tone02.lvt`：用 `\loggingoutput` 固定 shipout 的实际字形，是正面证据，与字体度量是否巧合无关。
- `xpinyin/testfiles/pinyin-setup01.lvt`：`\xpinyinsetup` 中能用尺寸观察的六个键（`ratio`／`vsep`／`hsep`／`pysep`／`font`／`format`），用「改前 vs 改后」的差值而非绝对值。
- `xpinyin/testfiles/pinyin-scope01.lvt`：注音的开关与作用域，同样用 `\loggingoutput` 固定节点列表。改变格式而不改变尺寸的键也归这里——`multiple`（只给多音字拼音附加格式）、`format` 的着色效果（作用于全部拼音）与 `footnote`，因为尺寸比较对它们完全不可见。三个键都有「设 vs 不设」两格对照，缺了对照那一半就只固定了缺省值下的输出、而非键的语义：`footnote` 起初只写了缺省 `false` 下脚注不注音，终审盲审据此指出「设了 `footnote=true` 后脚注真的会注音」从未被验证，现补 9b 项（脚注拼音 3.19995pt，与正文注音的 3.99994pt 可区分）。`multiple` 与 `format` 互为对照且都必需：只有前者时，把两者的作用范围搞混（例如让 `format` 也只作用于多音字）不会被任何用例发现；基线用不同颜色（红／蓝）区分两者的 `\special{color push}`。
- `xpinyin/testfiles/pinyin-fallback01.lvt`（3 项，#997）：xeCJK 的 `AutoFallBack` 与注音量宽盒子的交互。主字体故意取没有 CJK 字形的 `lmroman10-regular.otf`，后备字体取 `FandolSong-Regular.otf`，逼出后备字体这条路径。三项分别是：后备字体下的自动注音、显式指定非首选读音（同样经过量宽盒子）、以及「主字体自带 CJK 字形、紧跟在西文之后」的对照项。**判据是 `\loggingoutput` 节点列表里量宽盒子自身的宽度，不是整体宽度**——整体宽度对这个缺陷没有判别力，见下文。
- `xpinyin/testfiles-cjk/pinyin-cjkutf8-01.lvt`：CJKutf8/pdfTeX 路线，覆盖上述前两类断言的等价内容。**这条线的尺寸断言比 XeTeX 那条弱**：T1 Latin Modern 下锐音、钝音、caron 的合成结果宽高全同（实测 ht 均 6.88875pt、wd 均 13.333pt），只有 macron 与「无重音」可区分，因此**尺寸**比较拦不住二／三／四声之间的对调——实测把 `\'` 与 `` \` `` 对调，XeTeX 那五个文件全红，本文件也会红，但红的是下面 TEST 6 的节点证据、尺寸断言本身照旧通过（#1041 原文写成「该文件仍全绿」，是把「尺寸断言拦不住」误记成「整份文件拦不住」，#997 复跑时更正；「五个」含 #997 新增的 `pinyin-fallback01`，它的基线含拼音字形、同一变异同样影响它，该数字是新增用例后重跑所得而非按文件数推算）。故补 TEST 6 用 `\loggingoutput` 固定实际节点作正面证据（T1 下一声／三声走 `\accent`、二声／四声是预组合字形，两者在基线里的节点结构不同）。另注意该 config 的 `stdengine` 是 `pdftex`，基线文件名就是不带引擎后缀的 `.tlg`；早先误存的 `.pdftex.tlg` 从不参与比对，是个悄无声息的空基线。

**按键的可观察量分文件，而不是按「键」这个概念聚在一起。** `multiple` 一度只写在 `pinyin-setup01.lvt` 的覆盖清单里、并由 `pinyin-scope01.lvt` 交叉引用指向它，但两个文件都没有它的用例——盲审把这条列为重要问题：读注释的人会以为该键有回归保护。真实原因是它改的是颜色而非尺寸，放在以宽高比较为手段的 `setup01` 里本就无法断言。现在它落在 `scope01`，判据是 `\special{color push rgb 1 0 0}` 进基线，并用三格对照（多音字「重」着色、单音字「文」同样设了键也不着色、不设键的「重」不着色）保证判别力：只写第一格时，把「是否多音字」的判断去掉也照样通过。变异实测两个方向都会红——无条件套用该格式时红色 push 由 1 变 2，完全忽略该键时变 0。

**四条判别力教训**（本节最有价值的部分，均由「重新引入缺陷、确认它会变红」实测确认）：

1. **oracle 未切到候选同一字体族会让全部单元恒报 DIFF。** `\pinyin` 内部按 `font` 键选字体，若 oracle 用的裸重音命令沿用文档主字体，两者字体不同时比的就是两种字体的度量差，而不是「数字到重音的映射是否正确」——初版漏了这一步，当时的全部 24 格都报 DIFF。
2. **拼音字体缺字时会假通过。** 文档默认的 Latin Modern 缺 U+01D6（ǖ，lü 的一声）；候选与 oracle 同时缺同一个字符，尺寸仍然相等，该格看着通过、实际什么都没验证。改用 `DejaVuSerif.ttf` 后实测零 "Missing character"。
3. **只测带声调数字的 v 会漏掉 `\@@_replace_v:n`。** v 到 ü 的转换由两个各自判断 l/n 的函数分担：`\@@_num_to_tone_v:Nn`（带声调数字时）与 `\@@_replace_v:n`（不带数字时）。只写带数字的用例不够——实测把 `\@@_replace_v:n` 的 l/n 守卫整段删掉，前四组仍全绿。需要补「前面有数字音节、末音节不带数字」的写法（如 `ma1lv`）才能真正触发这条路径。
4. **`\xpinyin{长}{zhang3}` 要的正是数据库首选值，没有判别力。** 「长」在数据库里的首选读音正是 zhǎng，指定它与不指定读音的对照项输出完全相同，等于什么都没验证。必须挑非首选读音（cháng）才构成真正的对照。

**两条结构性事实**（一并写进注释，避免日后重犯）：

- **注音汉字的宽度看不出拼音内容。** `\@@_make_pinyin_box:nnn` 把拼音放进 `\hbox_overlap_right:n` 这个零宽盒子里，换读音乃至整段关掉注音，整个盒子的宽度都不变（实测 `\xpinyin{长}{chang2}` 与 `\xpinyin{长}{zhang3}` 同为 10pt）。因此「用了哪个读音」「注音有没有生效」这类内容断言一律交给节点列表（`pinyin-scope01.lvt`），宽度维度只能确认「尺寸不受读音影响」这条不变量本身。
- **CJK 环境必须开在盒子内部。** 写成 `\begin{CJK}` 包住 `\hbox_set:Nn` 时，出环境后读到的三项宽高深全为 0pt（成因是 `\hbox_set:Nn` 的局部赋值被环境分组还原成 void——实测环境**内**读同一个盒子是正常的 12.75551pt，改用 `\hbox_gset:Nn` 则环境外也读到该值；不是汉字排不进盒子）——而 0pt = 0pt 会让「宽度不变」这条断言照样报 unchanged，看着像通过。CJKutf8 路线的测试因此把 `\begin{CJK}...\end{CJK}` 整体写在 `\hbox_set:Nn` 的参数内部。

**`\showbox`／`\box_log:N` 在 `-halt-on-error` 下会立刻中止。** 三者都抛 `! OK.`，而 xpinyin 的 `checkopts` 带 `-halt-on-error`，会立刻终止编译，其后用例静默不执行而 `check` 仍可能报绿。这个坑在 xeCJK 的 `verb-ecglue02.lvt`／`fntef-shrink01.lvt` 注释里也记着；xpinyin 的解法同样是一律用 `\loggingoutput` 读取 shipout 的实际节点列表。

**`checkdeps` 单独声明不够，必须配 `checkinit_hook`。** `xpinyin/build.lua` 的 `checkdeps = {"../xeCJK"}` 只保证依赖包先被 `unpack`，产物留在依赖包自己的 `build/unpacked/` 里，kpse 搜不到——`\usepackage{xeCJK}` 仍会命中系统 TeX Live 的版本。实测不加 `checkinit_hook` 时，测试日志里的路径是 `texmf-dist/tex/xelatex/xecjk/xeCJK.sty`。修法是用 `checkinit_hook` 手工把依赖包产物复制进本包的测试目录。`checkinit_hook` 与「本地 TeX Live usertree 同步」一节里 `localdir` 注入手段的目标不同，不要混用：这里是永久性的构建配置，让测试稳定使用工作树的依赖包而非系统 TeX Live；`localdir` 注入是临时的对照实验手段，用来一次性判定某个上游漂移的根因。

**复制清单必须取依赖包自己的 `installfiles`，照抄 `ctex/build.lua` 会漏文件。** `ctex/build.lua:72-80` 的钩子遍历的是**本包**的 `installfiles`；那里能工作纯属巧合——`ctex` 自己的 `installfiles` 恰好覆盖了各依赖的**运行时**产物类型。（按字面并不是超集：`ctex` 只有 `ct*.tex`／`zh*.tex`，接不住 `xeCJK` 的 `*.tex`，实测漏掉 `xunicode-symbols.tex` 与 12 个 `xeCJK-example-*.tex`；那些是手册示例，不参与运行时加载，所以 `ctex` 侥幸没受这一点影响。）xpinyin 照抄后就漏了：本包是 `{"*.sty","*.def","*.ins"}`，而 `xeCJK` 还装 `"*.cfg"`，于是出现只复制了一半的分裂状态——`xeCJK.sty` 用工作树版本（日志显示 `./xeCJK.sty`），`xeCJK.cfg` 却仍命中 `texmf-dist/tex/xelatex/xecjk/xeCJK.cfg`，而那份是 v3.10.4、工作树是 v3.10.5，`\GetIdInfo` 与版本号行都不同。**这恰好破坏了该钩子声称要消除的「测的其实是本机装了什么」**，且症状隐蔽：测试全绿，只有对比日志里两个文件的路径才看得出来。这类缺陷是盲审在终审轮以 blocking 级查出的。现行做法是用 `loadfile` 在独立环境里读依赖包的 `build.lua`、取它自己的 `installfiles`（用 `loadfile` 而非 `dofile`：后者在全局环境执行，既无法隔离也无法用 `pcall` 接住错误），并设两道**拒绝**判据——读不到或不是表则 `error`、空表则 `error`；`pcall` 的错误对象不构成判据（它不拒绝任何东西），而是在这两道判据触发时随 `error` 一并报出，作为线索；不硬编码第二份清单，否则依赖包将来新增产物类型时会再次静默漏掉。`xeCJK` 现在必然在 `require("zip")` 处中断（空环境里 `require` 为 nil），这是预期的，`installfiles` 在那之前已赋值；但错误必须可见，否则将来失败点前移到赋值之前时无从发现。

**已接受的残留缺口有两个**，都如实记下：（1）若依赖包改成分步构造 `installfiles`（先赋字面表、中途出错、之后再追加），得到的残缺表会同时通过「是表」与「非空」两道判据，只复制一半而不报错；（2）判据只看这张表，**不看每条 glob 是否真的匹配到文件**——`xeCJK` 的 `"*.map"`／`"*.tec"` 在 `check` 路径下必然零匹配（那两类产物由 `unpack_posthook` 在 `install_files_bool` 为真时才经 TECkit 生成，而该标志只在 `install_files` 里置真），`cp` 静默复制零个文件并返回 0。缺口二今天不触发，因为 xpinyin 现有测试都不用 `Mapping=` 一类需要 `.tec` 的写法；但将来加了就会命中系统 TeX Live 的那份。两者都实测确认。不再收紧的理由：更严的判据要么预设依赖包的写法、反而更脆，要么（对缺口二加零匹配 `error`）现有配置下就会立刻失败。`cp` 的 errorlevel 现已检查（复制确实失败时即 `error`，而非静默继续拿系统那份去测）。防线是失败时随 `error` 一并报出的 `pcall` 错误，加上「新增依赖、依赖包重构、或新增用到 `.map`／`.tec` 的测试时，逐个核对测试目录里每类产物的实际加载路径」这条人工步骤。

**盒子高度比较取「总高」时容易写成恒真断言（#265 / PR #977）。** 给 `\disablepinyin*` 补退组恢复的用例时，初版把「禁用用的子分组」和「组后要观察的那个字」放进同一个盒子，再与单个未注音汉字比总高。实测把 `\bool_set_false:N` 改成 `\bool_gset_false:N`（即禁用泄漏到组外、组后那个字也不再注音）时，该盒子**仍然更高**（8.46454pt vs 8.39754pt）——多出的高度来自盒子里的其他内容而不是拼音，于是 `>` 比较照报 `restored`，这一项等于没有断言。修法是让被观察的字**单独装进一个盒子**，并同时对两个方向取证：与「从未禁用过」的盒子比**等高**、与「未注音」的盒子比**更高**。基准也必须取另一个从未禁用过的盒子——拿变异后的两个值互比，它们会同为 8.39754pt 而仍然相等。这与「注音汉字宽度看不出拼音内容」是同一类问题：**观察量必须只随被断言的那一件事变化**，混进无关内容就会被无关内容的贡献掩盖。（另一个问题同源于上文 CJK 环境那条：`\hbox_set:Nn` 写在 CJK 环境内部时该盒子 `ht = 0pt`，也会让比较失去意义。）

**`AutoFallBack` 与量宽盒子的交互，判据只能落在量宽盒子自身（#997）。** 这一轮的三条约束按「判据选什么、变异做几个方向、测试写法有什么上游限制」分三层。

第一层是判据。**整体宽度对这类缺陷没有判别力**：拼音在 `\hbox_overlap_right:n` 这个零宽盒子里，不占外部宽度，实测缺陷版与修复版的 `\hbox{\xpinyin*{中}}` 同为 10.0pt，任何以外部宽度为判据的断言都恒真。这是上文「注音汉字的宽度看不出拼音内容」那条结构性事实的另一面——它讲的是「换读音看不出来」，这里是「量宽量错了也看不出来」。必须用 `\loggingoutput` 读节点列表里量宽盒子自身的宽度：缺陷版 `x2.8`、修复版 `x10.0`。可见输出的最终证据是 PDF bbox（`pdftotext -bbox`）：缺陷版 `zhōng` 2.79pt、修复版 9.96pt，与汉字「中」的 9.96pt 对齐。

第二层是变异方向，**这里有一条本轮自己踩过的反例，值得原样留着**。修复方式是「给原有的字体重选加一个条件」，看起来应当有两种失败方式，各要一组用例。实测只有一种能被观察到：

| 变异 | 实测结果 |
|---|---|
| 回退成无条件重选（即原缺陷） | 16 处 `x2.8`，并带 `Missing character`，用例变红 |
| 把 `\cs_if_eq:NNTF` 的 T／F 分支互换 | 产物与「无条件重选」**逐字节相同**，不是独立的失败方式 |
| 把重选整个删掉（函数体置空，或 hook 里不再调用） | **5/5 全绿，产物与基线逐字节相同** |

也就是说「**整个重选分支被跳过**」这一侧没有用例能拦住，是已接受的覆盖缺口。注意这个否定要限定在「整个分支被跳过」上：第 3 项确实是另一种失败方式的唯一防线——保持条件结构不动、只让 `\@@_select_CJK_font:` 重选到**错误的 CJK 族**（例如在它开头插一句 `\CJKfamily{\CJKrmdefault}`），实测只有第 3 项变红（`x10.0`→`x2.8`、缩放比 0.81777→0.22898，并新增两条 `Missing character`），第 1、2 项区域逐字节不变。把第 3 项的对照字体换成与后备字体不同的 `FandolKai` 正是它获得这项判别力的前提。原因是进入 `\@@_CJKsymbol_hook:` 时**实际当前字体**（`\fontname\font`）已经是 CJK 字体——xeCJK 的 interchar 进入 CJK 类时就切好了，hook 运行在那之后；只有 NFSS 参数（`\f@family`）还停在西文族 `lmr`，而决定量宽的是前者。已在十余种上下文（紧跟西文／标点／`\emph`／数学／`\textsf`／字号变化／`\mbox`／`\sbox`／`\hbox`／`\vbox`／`tabular`／`minipage`／`\section`／`pinyinscope`／嵌套注音／脚注／切换 CJK 族）逐一探测，`\fontname\font` 无一例外已是 CJK 字体。

**教训是探针取错了量**：本轮初版判断「不重选会量出西文宽度」，依据是探针打印的 `\TU/lmr/m/n/10`——那是 NFSS 状态，不是实际字体。用 `\f@family` 一类 NFSS 参数回答「当前用什么字体排版」会得到系统性错误的结论，必须读 `\fontname\font`。这条错误进而支撑了「重选不能删」以及「第 3 项覆盖第二个方向」两个不成立的说法，两者都由独立审查在变异复跑中推翻。

因此第 3 项对照的准确定位是：它固定另一条路径（主字体直接命中）的正常输出，**对「整个重选分支被跳过」没有判别力**，但**是「重选切到错误 CJK 族」的唯一防线**。`.lvt` 注释里按这个界限写明，既不要把它当成前一种失败方式的防线，也不要因此认为它没有价值。保留「否则重选」这一分支，是考虑到 xeCJK 内部切换字体的时机可能变化而做的保守选择，而非已观察到它必需。

第三层是测试写法的上游限制。**`\setCJKmainfont` 是 `\@onlypreamble`**（`xeCJK/xeCJK.dtx:10854`），正文里 `\begingroup \setCJKmainfont{...} \endgroup` 会得到 `LaTeX Error: Can be used only in preamble.`。要在正文里换到另一个 CJK 字体做对照，得在导言区用 `\newCJKfontfamily` 另立一族，再在正文里切过去。

另外，pdfTeX/CJKutf8 那条线不受本修复影响，`\@@_adjust_CJK_hook:` 把 `\@@_CJKsymbol_hook:` 直接设为 `\prg_do_nothing:`（`xpinyin/xpinyin.dtx` 里检索 `\cs_new_eq:NN \@@_CJKsymbol_hook: \prg_do_nothing:`；行号会漂移，早先记的 990 已失效），所以 `testfiles-cjk/` 不需要对应用例。机制侧见 [[../architecture/xecjk-architecture]] 的「后备字体 (Fallback)」一节，取舍见 [[../memory/decisions/997-xpinyin-fallback-reselect]]。

### 拼音查询命令的回归（`pinyin-query01`～`04` 与 `pinyin-query-cjkutf8-01`，#550）

#550 新增四个查询命令（`\xpinyinvalue`／`\xpinyininitial`／`\xpinyinshengmu`／`\xpinyinyunmu`），测试上有两点与本包其他用例不同。

**判据不能用盒子尺寸。** 查询命令返回字符串、不参与排版，宽高类断言在这里恒真。改为用 `\TYPE` 把结果写进日志逐字比对。

**但只有一部分结果能这样比对。** `tone=mark` 的输出要经过 `\@@_pinyin:n`，它是 `protected` 的，而且把内容**排版出来**而不是返回字符串（经 `\l_@@_item_tl` 等变量逐段拼装输出）。因此 `\TYPE` 只会记下 `\__xpinyin_query_mark:n {zhong1}` 这样的未展开形式，`\tl_set:Ne` 同样留不下文本。带星号的形式也不可展开（去重要用逗号列表变量）。这两类改为排进页面、用 `\loggingoutput` 固定节点列表。

**新增由 `xpinyin.lua` 生成的数据文件时，必须同时改两处**：`.ins` 的 `\file{...}{\from{...}}`，以及 `build.lua` 的 `unpacksuppfiles`。漏掉后者时 docstrip 找不到数据文件，产出的 `.def` 只含版权头——#550 实测 `xpinyin-query.def` 只有 1129 字节，而正常应为 1.07 MB。

`l3build unpack` 在 `build/` 干净时会**明确失败**：退出码 1，日志里有 `! Cannot find file xpinyin-query.db.` 与 `! Emergency stop.`。但如果 `build/` 里留着上一次的产物，unpack 可能读到旧文件而看不出问题。所以既要看退出码，也要核对生成文件的大小；排查这类问题时先 `rm -rf build/` 再跑，避免被残留产物误导。

**断言报错的用例，报错之后不能再放任何东西。** 原因是 `checkopts` 带 `-halt-on-error`（`support/build-config.lua`），第一处错误就终止编译，其后的断言静默不执行而 check 仍可能报绿——与 `\showbox`／`\box_log:N` 抛 `! OK.` 的那个问题同源（见 `pinyin-tone02.lvt` 的注释）。

**注意归因**：中断来自这个编译选项，**不是** `\msg_expandable_error:nnn` 的语义。同一文件不加 `-halt-on-error` 跑，报错之后的断言全部照常执行（#550 实测）。把它记成「可展开报错必然中断后续」会导出错误的做法——#550 正因此把 `tone=mark` 的节点基线搬到了一个报错之后的位置，那一节从此从未执行，星号去重与标调两处变异都变成全绿，覆盖被静默删除。

因此：每个报错场景各占一个 `.lvt`，且该文件里报错断言之后不放别的项；需要与排版类判据共存的项，放在不含报错断言的文件里。#550 的分法是 `pinyin-query01`（取值、切分、可展开性、`tone=mark` 节点基线）、`pinyin-query02`（参数校验，汉字存在宏里）、`pinyin-query03`（查不到读音）、`pinyin-query04`（参数校验，花括号包一层），四者的变异各自变红。

`query02` 与 `query04` 覆盖同一个校验但必须分开：两种输入都是「多记号而看似单字符」，同处一个文件时第二格被第一处报错挡住。拆分的非冗余性经**双向**变异确认：把校验阈值放宽到 `< 4` 时只有 `query04` 变红；把 `\str_count:n` 换成 `\str_count:e` 时只有 `query02` 变红。

（判断两个用例是否冗余，要两个方向都试。只做一个方向只能证明「其中一个不可省」，不能证明「两个都不可省」。）

**判据要落在最终产物上，不是中间产物。** 第 8 项一度只断言 `\edef` 之后的字面值，而缺陷出在交给 `\index` 的那串字节上：手册配方用 `\@tempa` 作中间变量时，正文里 `@` 不是字母，`\edef\@tempa{...}` 定义到的并不是 `\@tempa`，排序键会多出一个空格（`han @汉字`），makeindex 按字面比较会把它与手写的 `han@汉字` 分成两个条目。现在改为把 `\index` 换成一个只记录参数的命令（`\index` 写外部 `.idx`，内容不进日志、基线看不到），并保留一格含 `@` 名字的对照，使手册那条说明有判据支撑。

**恒真断言的又一种写法**：第 8 项（可展开性）初版写 `\index{\xpinyinvalue{中}@中}` 后跟一句 `\TYPE{index: no error}`。`\TYPE` 无条件执行，这行无论实现对不对、无论查询表有没有载入都会打出来；而 `\index` 根本不展开参数，所以它对自己声称覆盖的场景没有判别力，反而把缺陷冻结成了预期基线。已改为断言 `\edef` 之后的字面值与 `\meaning\XPYkey`，并用「把 `\@@_query_tone_apply:n` 改成 `protected`」这个变异验证会变红。

**pdfTeX 那条线也要有用例。** `query` 选项在 pdfTeX 下必须报错（取码位靠 `` `#1 ``，CJKutf8 路线上一个汉字是多个字节）。这条行为写进了决策与手册，却一度没有任何用例固定——把那句 `\msg_error:nn` 删掉后两条线都全绿。`testfiles-cjk/pinyin-query-cjkutf8-01.lvt` 补上了它。

写这个用例有个容易出错的地方：**报错发生在宏包加载阶段，`\START` 必须放在 `\usepackage` 之前**。放在 `\begin{document}` 之后的话，编译在到达 `\START` 之前就中止，`l3build save` 写出的基线只有两行说明文字，而 check 照常报绿。

**变异判别力**（双向实测）：把生成脚本里 `ǚ` 的字母部分从 `v` 写成 `u`，`nv3` 变 `nu3`、排出的字形由 `nǚ` 变 `nǔ`，变红；让 `official` 的声母表也收 `y`／`w`（两种切分模式合一），第 4 项全部变红。

第二个变异第一次跑时是绿的，原因是注入前误用 `cp` 把 `.dtx` 恢复了，变异根本没生效——**做变异实验后要先确认变异真的进了生成产物**（`grep` 一下生成的 `.sty`），再判断绿色的含义。这与「新增测试项后要复查既有项判据」是同一类问题的两个方向。

### xpinyin 的「升级式解包」是 CI 覆盖不到的一条路径（PR #1051）

`xpinyin` 的 `.ins` 里有一段 `\directlua`，判断是否需要跑 `xpinyin.lua` 重建数据库。#550 新增 `xpinyin-query.db` 之后，这个判断一度仍只检查 `xpinyin.db`：

```latex
if not kpse.find_file("xpinyin.db") then dofile(...) end
```

于是**在以前解包过 xpinyin 的目录里升级**时，旧 `xpinyin.db` 让生成器被跳过，而 `xpinyin-query.db` 尚不存在，docstrip 随即以 `! Cannot find file xpinyin-query.db` 退出（实测 rc 1）。改为任一缺失都重建。

**为什么 CI 拦不住它。** `xpinyin/build.lua` 的 `unpack_prehook` 第一句就是 `cleandir(unpackdir)`，所以 `l3build unpack` 永远在干净目录里跑，走不到「旧 db 存在、新 db 不存在」这个状态。这是一处**结构性覆盖缺口**，不是漏写用例——要覆盖它得在 CI 里另建一个「预置旧 db」的目录，代价与收益需要另行权衡。

手工复现步骤（改动那段 `\directlua` 或新增数据库文件时应当跑一遍）：

```sh
mkdir /tmp/upg && cd /tmp/upg
cp <repo>/xpinyin/xpinyin.dtx .
cp <repo>/xpinyin/build/local/xpinyin.ins .      # 由 l3build unpack 生成, 改 .dtx 后要重新生成
cp <repo>/xpinyin/build/local/xpinyin.id .
cp <repo>/support/ctxdocstrip.tex .
cp <repo>/xpinyin/build/local/xpinyin.db .       # 只放旧 db, 不放 xpinyin-query.db
cp <repo>/support/Unihan.zip .
luatex xpinyin.ins                                # 修复前 rc 1; 修复后 rc 0
```

判据是**两个 `.db` 与两个 `.def` 都产出**，且 `xpinyin-query.def` 远大于 1129 字节（1129 是只有版权头的空表）。排查时注意两个陷阱：手工拼 `.ins` 容易漏掉 install 段的第二块（`\endbatchfile` 在那里）与 `\input docstrip`，会引出与本缺陷无关的失败；`xpinyin.ins` 由 `.dtx` 生成，改完 `.dtx` 必须重跑 `l3build unpack` 再取，否则测的还是旧逻辑。

**`\directlua` 的实参里不能写 Lua 的 `--` 行注释。** TeX 把实参折成一行后，`--` 会把其后的全部代码都变成注释——实测整个 `if` 被注释掉、生成器静默不执行，症状与没改一样（`xpinyin.db` 的 md5 不变是判断「生成器没跑」的可靠信号）。说明只能写在 `.dtx` 的注释里。

### 直接输入 `ü` 的回归与「两条路线症状不同」（#1069）

xpinyin 支持把拼音里的 `ü` 直接写出来（等价于既有的 `v` 写法）。这处缺陷的诊断值得记：**同一根因在两条引擎路线上症状完全不同**，只看一条会低估问题。

- XeTeX：输出错误。`ü` 不在声调落点表（`\c_@@_v_tl` 一系只有 ASCII 字母），`\@@_pinyin_aux:n` 认不出它是元音，整个音节走「原样输出」分支，`\pinyin{nü3}` 排出字面的 `nü3`。
- pdfTeX/CJKutf8：**编译立即中止**。`ü` 是两个字节，逐记号取到半个字符，`` `#1 `` 求值报 `Improper alphabetic constant`，rc 1。

因此这条线的用例除了固定输出，还同时固定「能编译」——修复前把那一组加进 `pinyin-cjkutf8-01.lvt` 会直接跑不完。相应地，两侧的变异规模差一个量级：去掉折叠后 `pinyin-tone01` 是 TEST 4／5 的 12 个断言全红，而 `pinyin-cjkutf8-01` 因编译中止导致**整个基线失配**（不是若干断言变红，而是从报错点起后续断言全部不执行）。

（**报红量不要写成 diff 的确切行数**：同一批断言在 context diff 里每格占两行，行数还随呈现方式变化。按「哪些断言变红」记录才稳定。另外 `NU-umlaut-caps` 那一格在这个变异下**按设计不变红**——去掉 `ü`→`v` 之后 `Ü`→`V` 仍然生效，`NÜ3` 与 `NV3` 同为字面 `NV3`，两侧依旧相等；它是 `Ü`→`v` 那个变异的判据，不是这个。清点覆盖时把它算进「应变红」会得出偏大的数。）

覆盖分布：`pinyin-tone01` 的 TEST 4（`ü` 与 `v` 逐项同尺寸，含首字母大写与多音节）、TEST 5（`jqxy` 之后按规范不带分音符，与 `v` 写法一致）、TEST 6（无声调数字时原样输出）；`pinyin-cjkutf8-01` 的 TEST 3；`pinyin-query01` 末尾固定 `\setpinyin` 写 `ü` 时存进查询表的值要折成 `v`。

三条测试设计上的教训：

**大写那格的判据一度不存在。** 「`Ü` 折成 `V` 而不是 `v`」原本用 `\pinyin{Nü3}` 断言——里面的 `ü` 是小写，走 `ü`→`v` 规则，碰不到 `Ü` 那条，于是 `Ü`→`v` 的变异全绿。断言名与注释都像是在测大写规则，只有输入里那个字符不对。现由 `\pinyin{NÜ3}` 与 `\pinyin{NV3}` 的对照固定（`\CmpPinyinPair`）。顺带记录一条既有限制：全大写音节本就排不出调号（`\pinyin{NV3}` 得字面的 `NV3`，`HAN4` 同理），声调落点表里只有小写元音。

**手拼 oracle 一度把 DIFF 冻进基线。** 多音节那格的 oracle 写成字面重音 `n\v{\"u}h\'aizi`，漏了 `\pinyin` 在音节之间插的 `pysep`（缺省一个空格），宽度必然不等，`l3build save` 把 `wd=DIFF 43.30566 vs 36.94824` 存进了 `.tlg`。该格要断言的本就是「两种写法结果相同」，改为直接对比两条 `\pinyin`——**oracle 需要复刻被测实现的内部细节（这里是 `pysep`）时，通常说明判据选错了**。

**`l3build save` 之后要读一遍新基线里自己那几行。** 它不会因为断言结果是 DIFF 而拒绝保存。上面那处正是 save 之后 grep 基线才发现的。

### zhnumber 的计数器选项回归（#1008）

`zhnumber` 的 `\zhnum[opts]{counter}`／`\zhdig[opts]{counter}` 原实现把计数器**名**写进
`.toc` 一类辅助文件（`\zhnumwithoptions{style=...}{section}`），读回时计数器已归零；
修法是在 `\zhnum`／`\zhdig` 这一层先把计数器展开为**数值**再交给处理数值的实现。回归分
两个 `testfiledir`，主目录下又按「可展开报错必须各占一个文件」拆成两个 `.lvt`：

- `zhnumber/testfiles/counter-options01.lvt`（三引擎；`.tlg` + `.pdftex.tlg` +
  `.luatex.tlg`，pdftex 基线因 CJK 字节形式不同而必需）用记号层面断言固定「值有没有被
  冻结」——判据是展开结果里出现 `{7}` 而非 `{section}`，同时覆盖 #1008 排查中发现的
  独立笔误：`\zhdigwithoptions` 原把选项多传了一个 `#1` 给 `\zhnum_digits_counter:n`，
  带选项的 `\zhdig` 此前直接报错。文件**最后一项**断言 `\zhnum` 带选项在计数器不存在时
  报 zhnumber 自己的错误（见下面「可展开报错在本仓库的 `checkopts` 下是致命错误」）。
- `zhnumber/testfiles/counter-options02.lvt`（三引擎；只需 `.tlg` + `.luatex.tlg`，
  pdftex 与 stdengine 逐字节相同故不留冗余基线）专门覆盖 `\zhdig` 那条独立守卫
  （`\@@_digits_counter_with_options:nn`）在计数器不存在时的同类报错——**必须**单独
  成文件，理由见下一节。
- `zhnumber/testfiles-cjk/legacy-entry01.lvt` + `zhnumber/test/config-cjk.lua`（仅
  xetex）覆盖兼容入口 `\zhnumwithoptions`／`\zhdigwithoptions` 本身——这两个命令**不可
  展开**（用 `\NewDocumentCommand` 实现，要用 `\group_begin:`／`\group_end:` 局部改样
  式），只能让它们实际排出汉字再量盒子才能验证内部逻辑。主目录里对这两个兼容入口的
  `\tl_set:Nx` 捕获式断言是恒真的（它们是 `\NewDocumentCommand`、protected，捕获只拿到
  命令名本身，实测基线里就是 `\zhdigwithoptions {style=Financial}{section}` 原样），
  已删除；兼容入口的行为完全由本文件量盒子覆盖。

**为什么必须分两个 `testfiledir`**：兼容入口不可展开，观察它们的行为只有「让它执行」
一条路；而排 CJK 需要中文字体，pdfTeX 下没有 CJK 设置时是硬错误 `Unicode character
... not set up for use with LaTeX` 并中止编译，XeTeX 下只是 `Missing character` 警告
——同一个 `.lvt` 放两个引擎跑，基线会分化成「报错」与「警告」两种不可共存的结果。做法
仿 `xpinyin/test/config-cjk.lua`。

**观察不可展开命令的行为，只有「让它执行」一条路。** 排查中试过四种手段，全部只能拿到
命令的**名字**、看不到内部逐步展开与赋值是否正确：

1. `\typeout{\zhnumwithoptions{...}{...}}`——不可展开的命令只被记下名字，内部坏掉也看
   不出来；实测恢复 `\zhdigwithoptions` 的笔误后，只用 `\typeout` 的版本仍然全绿。
2. `\tl_set:Nx`——同样只拿到名字。
3. 在 `\TEST` 的参数里切换 `\ExplSyntaxOn`——不生效，参数已被读入、catcode 已冻结（实测报
   `Undefined control sequence` 指向 `\tl_log:N`）。
4. `\protected@edef`——含 `@`，在 `\ExplSyntaxOn` 下直接写会报 `You can't use a prefix
   with the character @`，须放进 `\makeatletter` 块并用 `\cs_set_eq:NN` 起一个 expl3
   名字的别名再用。

**盒子度量选哪一维要先验证它真的会变，而且度量本身不足以固定排出的是哪个字。**
缺字时字体会用同一个占位字形，宽度往往变成同一个值——实测「七」与「柒」的宽度
都是 2.8pt，分辨不出内容；改用**高度**才区分开这两个字（`ht=7.33` 的「七」vs `ht=7.75`
的「柒」）。但高度同样不足以固定字形：实测 FandolSong 下「柒」「九」「佰」的 `ht` 都是
7.75，一个让 Financial 的 7 排成「九」的缺陷能通过全部度量断言（实测度量没有任何 diff）。
所以 `legacy-entry01` 的 TEST 4 用 `\loggingoutput` + `\box_use:N` + `\clearpage` 把
盒子内容本身写进基线，汉字在基线里就是字面 UTF-8 汉字（l3build 的日志归一化不把 CJK
码位转成 `^^` 形式）；度量只作旁证。该项必须覆盖前面测过的**全部**入口——只排 `\zhnum`
的盒子时，`\zhdig` 侧仍只有度量断言，盲区原样保留（实测）。而且必须同时用**多位数**跑
一遍：计数器为一位数时 `\zhnum` 与 `\zhdig` 的输出恒等（都是单个汉字），把 digits 路径
接成整数路径这类接线错误看不出来（实测把 `\zhdigwithoptions` 里的
`\zhnum_digits_counter:n` 换成 `\zhnum_counter:n` 后全绿）；123 下 `\zhdig` 逐位排
「壹贰叁」而 `\zhnum` 排「壹佰贰拾叁」，位数与字形都不同。用 `\loggingoutput` 而非
`\showbox`，因为后者报 `! OK.` 会在 `-halt-on-error` 下立即中止；不加 `\clearpage` 则
页面不 ship out、TEST 段落是空的（两点均实测）。

**可展开报错在本仓库的 `checkopts` 下是致命错误，这是本节最重要的约束。**
`\@@_counter_error:n` 用 `\msg_expandable_error:nnn`，它在展开中报错的方式是留下一个
`\???` 控制序列，触发 `Use of \??? doesn't match its definition`——该错误实测让**编译
立即中止**，其后所有 `\TEST` 一律不执行。判断是否中止要看「后面的 `\TEST` 段落有没有进
基线」，**不要**用日志里的 `Fatal error occurred, no output PDF file produced!` 那一行：
它只有 pdftex/luatex 打印，xetex 不打印（而 xetex 正是这两个测试的 `stdengine`），并且
它从不进入 `.tlg`——它排在
`Here is how much of ...TeX's memory you used:` 之后，而 l3build 读日志时读到那一行就
`break`（`l3build-check.lua:339-341`），其后内容一律被截掉。
成因是 `support/build-config.lua:9` 的 `checkopts = "-halt-on-error"`，
**不是** LaTeX 或 l3build 本身的行为：l3build 默认 `-interaction=nonstopmode`，那种设置
下同一个错误只记进日志、后面的 `\TEST` 照常执行（实测）。因此下面两条硬约束是**本仓库
的**约束，往用默认 `checkopts` 的项目推断前要先核对那边的设置。这也是 #1026 用
`\showbox` 碰到过的同一个机制（见 `lessons-learned.md` 里 `\showbox` 那条），本次是它的
第二个触发源。这条报错文本**必须**固定进基线，因为那是唯一可行的判据（曾试过只固定
「两条路是否进同一判断分支」来回避报错文本，但断言执行不到那一步就已经中止）；代价是
`counter-options01` 需三份基线、`counter-options02` 需两份——luatex 在该错误后打印的
help 行比 xetex/pdftex **少四行**（`counter-options02` 的 pdftex 输出与 stdengine 逐字节
相同，故不留冗余的 `.pdftex.tlg`；`counter-options01` 则因日志里汉字的字节形式不同而必需
——pdfTeX 记成 `^^e4^^b8^^83`、xetex 记成 `七`。注意这只是**日志编码**差异，与「pdfTeX 排
CJK 是硬错误」无关：`counter-options01` 里的汉字只经 `\tl_log:x` 进日志、没有实际排版，
实测 `l3build check -e pdftex counter-options01` 全绿）。由此得到两条
硬约束：

- **一个 `.lvt` 只能断言一次可展开报错，且该断言必须放在文件最末。** `\zhnum` 与
  `\zhdig` 各有一条独立守卫（`\@@_counter_with_options:nn` 与
  `\@@_digits_counter_with_options:nn`），两条都要覆盖，所以拆成
  `counter-options01`（`\zhnum` 那条，断言在文件最末）与
  `counter-options02`（`\zhdig` 那条，独立成文件）。
- **验收判据是基线里的 TEST 段落数必须与 `.lvt` 里的 `\TEST` 个数一致。** 段落不存在
  意味着该项没跑，而不是通过了；把报错断言挪到文件中间即可复现（其后用例全部不执行而
  check 仍报绿）。当前三个文件都对得上：`counter-options01` 5／5、`counter-options02`
  1／1、`legacy-entry01` 4／4。（另一处假绿——「删掉守卫零 diff」——的成因不是中止，而是
  一条恒真断言：`\int_if_exist:cTF` 探针根本没调用 zhnumber 的代码。两件事容易混为
  一谈，见 `1008-...` 反思里的更正段。）

**判别力实测结果（逐条隔离）**：删 `\@@_counter_with_options:nn` 的守卫
（`\int_if_exist:cTF`）→ 仅 `counter-options01` 红（三引擎），报 `You can't use \relax
after \the`；删 `\@@_digits_counter_with_options:nn` 的守卫 → 仅
`counter-options02` 红（三引擎），`counter-options01` 全绿零 diff（它的致命错误发生在
更早的位置）；复现 `\zhdigwithoptions` 笔误（多传一个参数）→ 仅
`testfiles-cjk/legacy-entry01` 红。三份文件的判别力互不重叠，各自只覆盖自己名下的
代码路径。「兼容入口断言恒真」这个问题**曾长期抓不到**，正是上面四条弯路的后果——主
目录里无论用 `\typeout` 还是 `\tl_set:Nx` 都只能记下名字，这正是补 CJK 那一组的真正
理由。

### zhnumber 的算筹数字回归（#366）

`zhnumber` 新增算筹（中国古代记数符号）`\zhrod`（可展开，只输出字符，供 `.toc`／PDF 书签
使用）与 `\zhrodbox`（不可展开，切换字体、收紧字距，负责排版效果）。回归同样按引擎需求
分两处，理由与「为什么必须分两个 `testfiledir`」一节相同——算筹码位（U+1D360 起）在
pdfTeX／upTeX 下无法表示（8-bit 引擎，实测 `\char_generate:nn` 报 `Charcode requested
out of engine range`），而 `l3build check` 没有按文件指定引擎的机制，同一个 `.lvt`
的三引擎基线会分化成不可共存的两种。这与本节已记的 `zhnumber/test/config-cjk.lua`
（#1008）是同一类约束，此处就近记录，不重开一节。

- `zhnumber/testfiles/rod-engine01.lvt` 与 `rod-engine02.lvt`（四引擎，含 upTeX）：只测引擎判定与报错，不测实际
  输出。判定依据是新增的 `\c_@@_rod_engine_bool`（只含 xetex/luatex），不是既有的
  `\c_@@_unicode_engine_bool`——后者把 upTeX 也算作真，而 upTeX 恰好不能表示算筹码位。
  报错断言放在文件末位（同「可展开报错在本仓库的 `checkopts` 下是致命错误」那段的
  约束），并用 `\token_if_protected_long_macro_p:N` 而非 `\token_if_expandable_p:N` 判断
  `\zhrod` 是否为报错版本——后者对 `\protected\long macro` 也返回 yes，会让两个引擎读数
  相同、该项成为恒真断言。捕获报错路径必须真的执行 `\zhrod`，`\tl_set:Ne` 只会把
  `\zhrod {12}` 原样存进变量而不触发报错，对该路径没有判别力。pdfTeX 有独立基线，读数与
  xetex/luatex 不同。
  拆成两个文件是因为 `checkopts = "-halt-on-error"` 下一个 `.lvt` 只能断言一次抛错：
  `rod-engine01` 那一次给了 `\zhrodbox`，`\zhrod` 的报错分支只能另开 `rod-engine02`
  （否则它完全没有测试覆盖——把该分支改成静默的 `\typeout` 两套 check 仍全绿，
  实测）。与 #1008 的 `counter-options01/02` 拆分同源。
- `zhnumber/testfiles-cjk/rod01.lvt`（仅 xetex）：测算筹实际输出。开头几项用
  `\zhrod` 的可展开性把字符序列捕获进基线（`\tl_set:Ne` + `\tl_log:N`），逐字固定「排的
  是哪个码位」——判据是字符序列本身而非长度，`units=vertical` 时个位实际取的是 Unicode
  的 `TENS DIGIT` 区（U+1D369 起，纵画），`UNIT DIGIT` 区（U+1D360 起）反而是横画，与
  区名字面相反。末项用 `\loggingoutput` 把盒子内容本身写进基线，固定实际
  排出的字形与字距（未压缩 50.0pt vs 压缩后 44.4pt）——只有度量不足以固定「排的是哪个
  字」，这与 `legacy-entry01` 已记的教训同源。负号 `overlay` 的回归还覆盖默认
  `zero=fill` 下的单独 `-` 与 `zerochar={}` 下的 `-0`：只有确有可叠字符时才追加
  U+20E5，避免输出孤立组合字符；把守卫退回只检查 `zero=omit` 的旧实现时，这两项各自
  变红。

`\zhrod` 与 `\zhrodbox` 的分工基于「可展开性与排版效果互斥」——`\zhrod` 只输出字符（不可
展开的实现会破坏 `.toc`／PDF 书签），`\zhrodbox` 才切换字体、收紧字距；这是 #1008 反思里
「教训确实被下一个任务复用」的一个正例，判据仍是「`.toc` 里是字符还是命令名」加
「`Token not allowed` 警告数」。

### zhnumber 的天干地支键绑定回归（#1077）

`zhnumber` 用 `\zhtiangan`（天干）／`\zhdizhi`（地支）／`\zhganzhi`（干支，由天干与
地支两个变量组合而成）三个命令，配 `Tn`／`Dn`／`GZn` 三组同构的 l3keys 键分别定制
第 `n` 个天干／地支／干支的输出。修复前 `testfiles/` 对这三个命令与三组键**完全零
覆盖**；#1077 的笔误——`Tn` 键的 `.tl_set:N` 目标抄成了 `GZn` 的目标（`l_@@_ganzhi_
#1_tl`），使 `\zhnumsetup{T1=...}` 实际改的是 `\zhganzhi{1}` 而非 `\zhtiangan{1}`——
因此能一直潜伏到用户报告。

新增 `zhnumber/testfiles/tiandi01.lvt`（7 个 TEST，三引擎 + `.pdftex.tlg`）覆盖：
默认值、`Tn` 只影响天干并连带影响由天干组合出的干支、`Dn` 侧对照、`Tn`+`Dn` 组合
（报告者原始用例）、`GZn` 独立于 `Tn`／`Dn`、显式 `GZn` 优先于 `T1`+`D1` 组合出的结果、
以及设置不泄漏出分组。判别力已实测：把 `Tn` 的绑定改回 `l_@@_ganzhi_ #1 _tl`，
`custom-T1-tiangan` 由「我的甲」变回「甲」、`custom-T1-ganzhi` 由「我的甲子」变成
「我的甲」（整个被替换而非组合）。

**该问题不是「代码报错」而是「代码能跑，但接到了错误的目标」，判别方式是组间对照，
不是组内自查。** `Tn` 那两行单独审查是完全自洽的——`\int_step_inline:nn { 10 }` 的
步数 10 正好是天干个数，`.groups:n = { user , pre , tiandi } ` 里的分组名 `tiandi`
也对，只有目标变量名错，而且错的那个值恰好是另一组键（`GZn`）的正确值，看起来完全
不像笔误。要发现它，必须把 `Tn`／`Dn`／`GZn` 三组键并排放在一起比对，而不是逐组
检查各自的内部逻辑是否成立。

`tiandi01.pdftex.tlg` 是本文件的第三份专属 pdfTeX 基线（前两份见上文
`counter-options01`／`rod-engine01/02`）：pdfTeX 是 8-bit 引擎，中文在日志里按字节
转义（如 `^^e7^^94^^b2`），xetex／luatex／uptex 直接记中文字符。这份基线人眼读不出
内容，`.lvt` 注释里写明了实测的字节-汉字对照表（甲=`^^e7^^94^^b2`、子=`^^e5^^ad^^90`、
我的=`^^e6^^88^^91^^e7^^9a^^84`），并提示改动本文件后若只有 pdftex 报红、其余三引擎
通过，应先怀疑是不是忘了重新生成这份基线，而不是怀疑实现——与 `counter-options01` 一样，
这里的汉字只经 `\tl_log:x` 进日志、没有实际排版，与「pdfTeX 排 CJK 是硬错误」无关，
纯属日志编码差异。

### xeCJKfntef 的相位、装饰单元与视觉验证（#531/#967/#1012）

xeCJKfntef 的线条问题要区分三件事：leader 原语怎样排列装饰盒子、`ulem` 怎样决定片段和端点几何，以及最终页面怎样渲染。`\leaders`、`\cleaders` 与 `\xleaders` 可以拥有完全相同的 glue、盒子宽度和命令总宽，却把重复的盒子画在不同横坐标；节点宽度相同不能证明相位相同。

#1012 用普通 `\leaders` 统一默认波浪和斜线的相位，再分别处理可见端点和断行接点。两个图案都由 `l3draw` 按 `1em/4` 绘制，常规全角字符约容纳四个单元；正文片段、固定或伸缩后的 `CJKglue` 和换行后的片段共享同一个 leader 网格。首段和真正的末段通过局部 PDF 裁切精确限定可见范围：普通形式左右各外伸半周期，带 `-` 形式左右各内缩半周期。相邻带 `-` 命令之间因而恰有一个周期断口；首段后的可断 `CJKglue` 用断点两侧各一个净宽为零的半周期连接。普通 `\quad` 和显式 `\hskip` 仍按 `ulem` 原路径装饰，自定义 `underwave/symbol` 保留历史 `\xleaders` 路径。默认斜线约高 `.93em`，使用时下移 `.09em`，使图案同时覆盖常见汉字的 height 和 depth。

含 PDF 绘图路径的可见问题用四类专项证据验证，再做一次整本文档集成构建。不要把完整绘图 special 全部写入节点基线，也不要为每次局部调整反复编译整本手册：

1. `fntef-underline-offset.lvt` 直接构造真正的 `l3draw` 波浪和斜线盒子，固定 8pt、10.53937pt、15pt 下的宽、高、深。这一层证明实际周期宽度确实是 `1em/4`、斜线约高 `.93em`，并随字号缩放；还检查普通／带 `-` 形式的空参数和不产生节点的正文保持零宽、零高、零深，避免 `ulem` 的结尾语法空格被裁切结构变成可见装饰。四组波浪／斜线、普通／带 `-` 的嵌套组合把单片段内层命令放在外层末尾；测试拦截 `\@@_ulem_periodic_right_skip_aux:`，要求只有已经产生后续片段的外层命令触发一次末段重画，从而固定嵌套状态的压栈和恢复。
2. 节点和换行回归把波浪和斜线临时换成同尺寸的轻量规则盒子，检查默认普通 `\leaders`、自定义波浪的 `\xleaders`、裁切结构、普通与带 `-` 形式、相邻命令、标点、换行、实际伸缩的 `CJKglue`，以及普通 `\quad` 仍被装饰。换行测试还比较正文字符和盒子、断点、行宽、glue set 及 PDF 图形状态在断点两侧分别闭合。规则盒子避免 `.tlg` 被数千行 PDF 绘图 special 淹没，但不能证明页面上的实际坐标。
3. `fntef-phase01.lvt` 先生成 XDV；`xeCJK/build.lua` 的 `runtest_tasks` 再调用 `xdvipdfmx -z 0` 生成不压缩内容流的 PDF，随后由 `testfiles/support/fntef-phase-check.lua` 读取标记、裁切边界和图案盒子的实际横坐标。32 行校验固定所有周期盒子处在同一个普通 leaders 网格；普通形式左右各外伸半周期，带 `-` 形式左右各内缩半周期，两种形式命令宽度一致；每个普通命令只有一段连续覆盖；固定和伸缩 `CJKglue` 连续；相邻带 `-` 命令之间恰有一个周期断口；普通显式跳距仍被装饰。Lua 检查将五项 PASS 写回日志，由 `.tlg` 固定结果。
4. 从手册示例提取精确单页 MWE，保留 Noto Serif CJK SC Regular、TeX Gyre Pagella、约 10.53937pt 正文字号及原示例内容；再用字体、字重、8pt／10.53937pt／15pt 和实际伸缩胶水的补充矩阵检查装饰长度、居中、连接和视觉密度。高分辨率图是这一层的主要证据。

专项验证通过后再运行一次 `l3build doc`，确认修改没有破坏整本文档的集成构建。当前实现的 xeCJK 标准测试为 126／126（#1104、#1103 后），文档构建生成 `xeCJK.pdf` 和 `xunicode-symbols.pdf`；#1091 本地审查 R1 后实测分别为 261 页和 51 页。页数随 `\changes` 条目和手册示例增长，属预期漂移，核对时以当次构建为准，不要把某次的页数当成判据。整本文档构建只能证明 PDF 能生成，不能自动判断局部装饰是否连续。

从源码树编译 MWE 时，必须检查日志实际加载的 `xeCJKfntef.sty` 路径，确认它来自当前工作树的生成目录，而不是系统 TeX Live 中的旧版同名文件。输出目录名和运行命令不能替代这项检查。

常见全角 CJK 字体和字重在同字号下通常不改变一 em 字宽及 leaders 几何，主要影响异常是否醒目；字号、非一 em 字宽、标点、特殊盒子和实际伸缩胶水则会改变片段宽度或余数。因此，自动回归不必复制完整字体矩阵，但必须覆盖真实字号、单元比例和实际使用伸缩量的断行；视觉抽样再加入 Serif／Sans、Regular／Black 等少量对照。xeCJK 标准测试当前为 126 项（#1104、#1103 后）。

### tabular 中的 CJK 与换行命令（`tabular01`，#1038）

`tabular01.lvt` 的 TEST 1／2 早已存在，却对 #1038 **没有判别力**——它们每行 `\\` 前都有一个源码空格（`姓名 & 年龄 \\`），走的是 CJK→NormalSpace 路径，不进 `\@@_boundary_group_math:w`；实测缺陷版下该文件全绿。TEST 3（#1038 新增）补上「`\\` 紧邻 CJK」的写法，判别力实测 rc 1：还原抓参数形式后 TEST 3 报 `Improper alphabetic constant`，TEST 1／2 零命中。

#1038 共新增两个独立文件。`tabular-cr01` 固定 `\\` 的相邻写法（`&` 之后、`\\[2pt]`、末行）；`boundary-bgroup01` 固定同一修复的附带改善：`中\bgroup $x$\egroup 文` 由 29.04527pt 变为 32.37527pt，与显式花括号写法及无分组 oracle 一致（判别力实测 rc 1，缺陷版回到 29.04527pt）。

**两者都必须独立成文件。** 起初它们是 `tabular01` 的 TEST 4／TEST 5，但 `tabular01` 的 TEST 3 在缺陷版下以 `Improper alphabetic constant` 中止编译，同一文件里其后的用例根本不执行——实测缺陷版日志里 `TEST 4` 出现 0 次。那样的用例在缺陷版里连输出都没有，判别力无法观察，是看起来正规实际空转的校验。

**「多个复现用例必须分文件跑」不只是排查时的注意事项，而是测试设计约束**：每个能独立触发该缺陷的用例都要有自己的文件，否则第一个报错就把其余全部变成假绿。三个文件现各自具备判别力（逐个实测缺陷版 rc 1）。

顺带更正一条长期记错的事实——`\bgroup` / `\egroup` **同样**触发 Boundary class。原因不是它被展开成花括号（它是隐式字符记号、不可展开），而是 XeTeX 的判据是 `get_x_token` 展开后那个不可展开记号的 catcode：只有 letter / other / `\chardef` / `\char` 用字符自身类别，其余一律 Boundary，catcode 1 不在其中。

**测试样例里的空白决定走哪条代码路径**，不是排版细节。写 xeCJK 用例时「CJK 紧邻 X」与「CJK 空格 X」是两个必须分别覆盖的象限。

另有两条与复现方法有关：

- **多个复现用例要分文件跑。** 同一文件里前一个用例报错会中止编译，后面的用例静默不执行而看起来「无错误」。#1038 排查时一个 10 用例的单文件矩阵曾因此显示 master 上 0 错误，逐个拆开后才看到 3 个真实失败。
- **触发面要逐写法实测，不能按名义推广。** 本缺陷只影响 `tabular` 系（含 `\\[2pt]` 与 `&` 之后）；`array`、`align`、`pmatrix`、`tabularx`、`array` 宏包列型、`\halign`、`center`、`minipage` 从未受影响，因为数学与 `\halign` 路径直接用 `\cr`，不经过 `{\ifnum0=`}\fi` 这个平衡技巧。

### ulem 正文外层收缩量回归（`fntef-shrink01`，#1026）

`fntef-shrink01.lvt` 固定 `\UL@on` 把正文交给 `ulem` 前必须保留字面记号这条约束（注意只覆盖 `\UL@on`，`\UL@onin` 见本节末尾）（架构见 [[../architecture/xecjk-architecture]] 「ulem 集成层的正文必须以字面记号留在替换文本里」一节）。测试覆盖 `\CJKunderline`、`\CJKunderwave`、带减号形式，以及重排路径的两个不同侧面；前四组都在 `document` 主垂直列表里让 `\hsize=200pt` 的段落真正断行，只固定行盒子的尺寸与 glue set，不比对装饰图形。TEST 5 是例外：它用 `\setbox` 加 `\box` 而非段落断行，并固定完整节点列表，因此会对装饰结构与 PDF 标记的改动敏感（实测改 `ActualText` 值只会让 TEST 5 失败，是它独有的敏感面；改装饰线粗细则五项全失败，因为线粗会改变行盒子的高深，不算 TEST 5 专属）。这是必要代价，只有节点列表能拦住“宽度不变而装饰已消失”的实现。

判据在 #1037 后改为「无 `Overfull` 记录」。溢出量随修复进度有三个取值：#1026 缺陷版 18.08pt、只修词后 3.64pt、词前词后都修好后无溢出。原先的判据写作「修复后为 3.64pt」，把残留缺陷冻结成了预期基线——四个用例各固定一条 3.64pt 的 `Overfull` 行，等于替同源的另一半缺陷（#1037）背书，使它长期看起来「有校验在管」。**把一个非零的缺陷量写进基线时，必须在注释里说明它为什么不是零、以及零需要什么条件**，否则观测值会被后来者当成规格。

重排路径需要两项各自独立的用例，缺一不可：

- **含西文词的“公式尾＋尾随空格”正文**，用来量重排路径本身有没有保住外层收缩量。只写 `\CJKunderline{中文 $x$ }` 分辨不出这一点：没有西文词就不会补出 `\CJKecglue`，把重排条件恒置为假也照样通过。
- **不含西文词的“公式尾＋尾随空格”正文**，用来固定尾随空格仍被装饰。这一项不能依赖 overfull 报告：内容短、不触发溢出，基线会是空的，等于什么都没固定。它改为两层观察：先报同一正文在有／无尾随空格下的宽度差（3.33pt），再把盒子交给 `\loggingoutput` 输出完整节点列表。只报宽度不够——把空格换成等宽 `kern` 时宽度完全相同，必须让末段 `\cleaders` 本身进入基线才能证明那一段确实被装饰。漏掉交还空格时总宽从 32.37527pt 降到 29.04527pt、末段 `\cleaders` 从 11.04524pt 缩到 7.71524pt（片段数不变，都是 5 段），两种变异实测都会让基线失败。注意此处不能用 `\showbox`：`checkopts` 带 `-halt-on-error`，`\showbox` 抛出的 `! OK.` 会立刻终止编译，其后用例静默不执行而 check 仍报绿（同一个坑记在 `verb-ecglue02.lvt` 的注释里）。

「重排是否发生」由上述节点列表一并固定：把重排条件恒置为假时该项基线失败（实测 rc 1），`command-boundary-math05` 的 `stream-ulem` 末状态也失败，两者互为交叉验证。需要强调的是这条归属经历过两次修正——起初该用例的 `.tlg` 是空的、什么都没固定，中途只固定总宽度时也仍分辨不出；只有把节点列表纳入基线后它才真正起到把关作用。为一条行为指定守护测试时，必须用变异实测确认是哪个测试真的会红，而不是按测试名义职责推断，且每次调整观察通道后都要重新确认一遍。

这个测试的设计约束具有可复用性，不止适用于本次缺陷：

- **必须让段落真正断行，不能只装进单个 `\hbox` 或 `\vbox`。** 单个盒子内部的 glue set 会把内外层的可伸缩量一并用掉，缺陷版与修复版会得到完全相同的数字；只有把正文放进主垂直列表、让 `\par` 真正决定断行时，内层片段盒子固化的收缩量差异才会体现为不同的行盒子尺寸。
- **调用处必须写字面正文，不能用宏承载正文（如 `\CJKunderline{\BODY}`）。** 宏体在 `ulem` 扫描期间才展开，触发的是“调用处写宏”这条已被接受的既有限制，而不是本次要验证的回归；发布版本（系统 TeX Live）对这种写法同样得到修复前的溢出宽度。用宏承载正文会让缺陷版和修复版再次得到相同数字，把两条不同的收缩链路混为一谈。
- **必须用重新引入缺陷的方式确认测试会失败，通过本身不构成证据。** 该测试的前三版草案（`\hbox` 量 badness、`\vbox` 排段落、`\def\BODY` 承载正文）都显示“通过”，但都是因为选错了载体而抹平了内外层区分；只有在改回旧实现后主动看到测试失败，才证明新增回归确实能检测这个缺陷。回归测试写完后应当养成“故意还原到修复前状态，确认它会红”的检查步骤。

TEST 6（#1037 新增）是词前 ecglue 的正向断言。前四项以「没有 `Overfull` 行」为判据，这是必要的但偏弱——它不能区分「收缩量回到了外层」与「行恰好因别的原因不溢出」。TEST 6 直接测量可收缩量：把含「源码空格 + 西文词」的正文压窄，用 `\badness` 观察。

**不能用 `\hbox to` 的实际宽度作判据**：`\hbox to` 总会取到目标宽度，`\wd` 减目标宽度恒为 0，与收缩量在哪里无关，是结构上恒真的断言（第一版 TEST 6 正是这么写的，生成基线后才发现真正的信号在旁边那条 `Overfull ... detected` 里）。压窄 2pt 落在「只修词后」的 1.11pt 与「两半都修」的 2.22pt 之间，正好把两种实现分开；另加压窄 1pt／5pt 两个对照，证明 badness 0 不是恒真、1000000 可达。判别力已实测 rc 1：把 `\@@_use_ecglue_skip:` 改回 `\skip_horizontal:N` 后，2pt badness 由 73 变 1000000，前四项的 `Overfull` 行全部回到基线。

TEST 7（同样 #1037 新增）固定的是**守卫**而非收缩量：在装饰之外重定义 `\ `（模拟 `nath`／`morehype`），再排普通中西文混排 `中 abc 文`。因为词前 ecglue 的入口位于所有中西文边界都会走的通用路径上，改写若只依赖 `\@@_ulem_glue:n` 自带的 `\xeCJK_if_ulem_patch:TF`，就会在装饰外的普通正文里执行 `\UL@stop` 而报 `Too many }'s`——与是否使用装饰命令无关。判别力已实测 rc 1：去掉 `\l_@@_ulem_stream_started_bool` 守卫后**只有** TEST 7 失败（基线出现 `\UL@stop ... \egroup \egroup` 报错行），前六项全部照常通过。这是「同一入口的两种失效方式需要各自的用例」的具体例子：TEST 6 管收缩量搬没搬出去，TEST 7 管搬的时机对不对。

TEST 10（#1037 新增）覆盖第四处路径（`\xeCJK_check_for_glue:` 的 math 分支，`$x$中文`）以及 `\@@_check_for_glue_auxi:` 的两个分支。**一个 `dim_case` 里的每个分支各自需要一条断言**：`default`（末节点是 Default 类，`\mbox{hi}中文`）与 `math`（末节点是 math marker，`\mbox{$x$}中文`）是两条独立路径，只写前者时后者可达且实现正确却毫无校验——逐分支变异实测，只改回 math 分支时全套 115 项仍全绿。三条断言现各自具备判别力（逐分支变异均 rc 1，TESTs 1-9 零命中）。

TEST 9（#1037 新增）覆盖同一根因的第三条路径：`\@@_recover_ecglue_source_space_success:` 与 `\@@_check_for_glue_auxi:`（西文词被字体／颜色声明隔开时走这两处）。**必须用 `\color` 写法**——实测 `\bfseries` 写法在这两处改动前后都是 2.22pt（根本不走这条路径），拿它做断言会得到恒真的测试；第一版 TEST 9 正是这么写的，撤销修复后仍通过。改用 `\color` 后判别力实测 rc 1（badness 73→1000000），且 TESTs 1-8 零命中。该用例的 braced 两行原先固定的是「显式分组包住西文词」这条已接受的限制（`braced-shrink-by-2pt-badness=1000000`、`1pt=73`），#1067 把这条限制修掉后已同步更新为固定修复后的行为（`=73`），成因与测试见下方 TEST 11。

### 花括号分组内的收缩量回到外层列表（TEST 11，#1067）

`\CJKunderline{虚室 {hello} 生白}` 里，花括号是在词内容传给 `\UL@start` 之后、在片段盒子**内部**才展开成分组的（实测两种写法切出的片段盒子数量相同，`ulem` 的切分点不受影响），于是 `\@@_ulem_glue:n` 的 group tag 守卫在盒子内部、用户分组内检测到不匹配，走 else 分支把间距固化在盒子内部。修法是 `\@@_ulem_defer_glue:n` / `\@@_ulem_flush_pending_shrink:`：盒子内部放不可伸缩的 `kern` 占自然宽度，伸缩量记进全局 skip，到词尾搬运处（已在盒子和分组之外）再补一个零宽带伸缩的 glue；守卫本身未改动。

TEST 11 覆盖 `{hello}`、`\textbf{hello}`、`{{hello}}` 三种写法（压窄 2pt 由 1000000 变有限值，与 oracle 一致，自然宽度不变），并加一条 `\CJKglue`（自然宽度为零、只有伸长没有收缩）的零宽短路断言——漏掉短路会让 `kern` 替换连伸长量一起丢掉，`fntef-font01` 的盒子宽度随之从 `40.0pt` 变 `39.00002pt`。三个变异（去掉记账、去掉 flush 调用、去掉零宽短路）均实测有判别力。

**必须先确认改的是生效的那份定义**：`\@@_use_ecglue_skip:` 在主体与 `xeCJKfntef` 各有一份定义（后者用 `\cs_gset_protected:Npn` 覆盖前者），装饰状态下生效的是后一份；改错位置会得到虚假的「变异全绿」结果。这与 `\@@_ulem_defer_glue:n`／`\@@_ulem_flush_pending_shrink:` 本身无此问题（只有一份定义），但改动同一区域时应养成核对生效定义的习惯。

`\CJKunderline{虚室 {文字} 生白}`（纯汉字）不在本项范围：它的 oracle 本身就是 1000000（汉字之间只有 `\CJKglue`，没有可收缩间距），与编组、装饰命令都无关。详见反思 [[../memory/reflections/1067-ulem-brace-group-ecglue-shrink]]。

两条与 `.tlg` 基线写法有关的坑，都是在 #1037 的审查中踩到的：

- **`l3build` 不归一化单数形式的 `detected at line %d`。** `l3build` 归一化的是 `on line %d*`、`on input line %d*`（`l3build-check.lua:210,211`）、`at lines %d*--%d*`（`:217`）与行首的 `l.%d+ `（`:144`），Overfull 的单数形式不在其中。`\hbox to` 触发的 Overfull 报告用的正是单数形式，一旦进基线就冻结了一个绝对源码行号——在 `.lvt` 里插入一行无关注释即失败。因此凡是观察量不是报告文本本身的用例，都应当把报告抑制掉，不要让它进基线。
- **抑制 Overfull 报告要用 `\hfuzz`，不是 `\hbadness`。** `\hbadness` 只管 Underfull 警告的阈值；实测默认值与 `\hbadness=10000` 都照样输出 Overfull，`\hfuzz=100pt` 才消掉，而三种设置下 `\badness` 都不变（即观察量不受影响）。

重排路径交还的那枚尾随空格仍落在最后一个片段盒子内部，外层收缩量因此比发布版少 1.11pt（发布版 9.44pt、回归基线 8.33pt、修复后 8.33pt+2.22pt 中属于西文词的部分已恢复）。改走 `\@@_boundary_use_ulem_glue:nn`（#1091 前签名为 `:n`）外层通道能补上这 1.11pt，但会让该空格对边界机制变得可见而被计算两次，实测 `command-boundary-math01` 报 3.33pt boundary delta 失败、`command-boundary-math05` 的 `stream-ulem` previous 从 0.0pt 变 3.33pt，故不采用。这是已接受的限制，详见决策 [[../memory/decisions/1026-ulem-literal-body]]。#1037 未改变这一点：它只改补 ecglue 的通道，不涉及重排路径剥离／交还源码空格的逻辑，TEST 5 的节点列表与宽度差在 #1037 修复前后逐字节相同，可佐证重排路径未被触及。

`\UL@on` 与 `\UL@onin` 两条入口现在**各由一个测试覆盖，但用的是不同的可观察量**，不要把两者混为一谈：`fntef-shrink01` 以「外层收缩量」为观察量覆盖 `\UL@on`；`fntef-nest-linebreak01`（#1057，见下一节）以「能否断行」为观察量覆盖 `\UL@onin`。

必须换观察量的理由是结构性的：`ulem` 的 `\UL@onin` 用 `\setbox\UL@box\hbox{{#1}}` 把内容整体装进一个 hbox，内层收缩量本来就出不了这个盒子，因此「收缩量丢失」这一症状在嵌套路径上恒定不显现。实测在该分支重新引入同一缺陷（改回 `\tl_use:N` 间接展开），乃至整段删掉重排分支，xeCJK 全套都保持全绿；嵌套 `\uline` 盒子的宽高深在修复版与缺陷版下逐位相同。同一句 `\setbox\UL@box\hbox{{#1}}` 对收缩量不可见，对断点却是决定性的——`fntef-nest-linebreak01` 正是从这里接上的。

仍未覆盖的部分要如实记住：`\UL@onin` 重排分支**内部的逻辑**（#1026 顺手做的一致性修改）的正确性依然依赖代码审查。新观察量能证明该路径被执行（计数器插桩实测：线型套线型时 `\UL@onin` 计数为 1，线型套符号型时为 0）、能证明正文进了刚性盒子，但不能区分该分支内部重排逻辑的对错。

视觉与跨 issue 无回归资产放在 `gh-assets` 的 `issues/1026/`：`issue1026-before-after.png` 是带正文右边距参考线的修复前后对照（722px → 681px，与 v3.10.3 逐像素一致）；`issue1002-no-regression.png` 与两份 `issue1002-*.txt` 记录重放 #1002 资产的结果——数值 oracle 24 行与本 PR 父提交逐字节相同，`inline-math-showcase.tex` 全部 17 页逐像素相同。重放这类资产时基线要取本 PR 的父提交，不能取早于该 issue 的发布版。

#1037 的资产在 `gh-assets` 的 `issues/1037/`。它给上一段补了一条：父提交是「有没有变好」的基线，但判断「变好到该有的程度了吗」还需要第三个对照点——**未受影响的发布版**。#1026 修复后该 MWE 为 4.47pt，与 TeX Live v3.10.3 逐像素相同；只看父提交（18.91pt）会认为修复到位，加上发布版这一点才看出 4.47pt 是发布版本来就有的缺陷、而非本次修复的终点。

### 装饰命令嵌套时的断行边界（`fntef-nest-linebreak01`，#1057）

`fntef-nest-linebreak01.lvt` 固定的是一条**既有限制**而非回归缺陷：`ulem` 只允许最外层的线型命令启动扫描，内层线型命令走 `\UL@onin` 复用外层已打开的扫描过程，正文被整段装进一个刚性 `\hbox`（探索 MWE 实测 107.22pt，盒子内部没有 discretionary），于是整段无法断行。发布版 v3.10.4（系统 TeX Live）与工作树 v3.10.5 行为完全一致，同一个 10cm 页宽的 MWE 在两版下溢出量同为 276.99pt，这是「长期约束而非本版本回归」的证据（本文件自己用 `\hsize=200pt`，基线里记的是 276.16pt；引用这个数字时要连页宽一起说）。固定它的理由与 `boundary-sbox-global01` 固定 `\global\savebox` 那条上游限制相同：避免日后有人把它误判为回归，而一旦将来确实绕开了这条限制，该项会失败并提示更新文档。用户向说明见 `xeCJK.dtx` 的 §3.6.1（`\label{subsubsec:fntef-nest-linebreak}`）。

判断谁占用扫描通道要按**装饰的绘制方式**分类，这是理解全部对照项的前提：线型命令借 `ulem` 扫描画连续线条（`\CJKunderline`、`\CJKunderdblline`、`\CJKunderwave`、`\CJKsout`、`\CJKxout`、`\CJKunderanyline`），符号型命令逐字放置独立符号、不经 `ulem` 扫描（`\CJKunderdot`、`\CJKunderanysymbol`）。因此 `\CJKunderanyline` 自嵌套失败不是独立现象，而是「它属于线型」的推论。

6 个 `\TEST` 的覆盖如下：TEST 1 线型套线型（`\CJKunderline`／`\CJKsout` 正反两向，顺序不影响结果）；TEST 2 原生 `\uline` 与本包线型命令相互嵌套，以及 `\CJKunderanyline*` 套 `\CJKunderline`；TEST 3 符号型与线型的双向嵌套；TEST 4 两个符号型相互嵌套；TEST 5 手册给出的替代写法（按语义分段、每段只用一个线型命令）确实能断行——文档若在教用户走不通的路，这一项会红；TEST 6 单独使用线型命令的基准。

**判据是双向的**：TEST 1、TEST 2 的基线**含** Overfull 行，作为限制存在的证据；TEST 3 到 TEST 6 的基线**不含** Overfull 行，因为这些组合确实能断行。没有后一组时，前一组只是空基线的默认结果，文档里「符号型可以自由嵌套」那句话也没有任何校验。变异验证针对的正是不触发限制这一侧：把 TEST 3 内层的 `\CJKunderdot` 换成线型 `\CJKunderwave`，基线因多出 Overfull 行而失败（实测 rc 1），说明「不含 Overfull」确实有判别力。另用计数器插桩确认分派机制而非只凭现象推断：TEST 1 的线型套线型使 `\UL@onin` 计数为 1，TEST 3 的线型套符号型计数为 0。

三条测试设计约束写进了文件注释：

- **只有主垂直列表里真正的段落断行才显现。** 装进单个 `\hbox` 或 `\vbox` 都测不出，那里的 glue set 会把内外层收缩一并用掉（与 `fntef-shrink01` 的同名约束同源）。
- **正文必须在调用处写成字面记号。** 写成 `\CJKunderline{\BODY}` 会触发「调用处用宏承载正文」那条另一条既有限制。这里的复核不可省略：两条限制在同一个探索 MWE 上给出**同一个数字** 276.99pt，不用字面正文重测一遍就分不清量到的是哪一条，也就无法断言该数字由嵌套造成。
- **判据本身是「Overfull 行在不在基线里」**，因此正文长度与 `\hsize` 都是判据的一部分，改动样例正文需要重新确认两侧仍各自成立。

xeCJK 标准测试因本文件从 122 项增至 123 项；#1091 新增 `fntef-entry-space01` 后为 124／124；#1104 新增 `microtype-slot01` 后为 125／125；#1103 新增 `boundary-empty-space01` 后为 126／126。

#1091 更新了本文件基线中的段末 marker：TEST 1、TEST 2 共四个段落末尾的 `\kern -0.0002`／`\kern 0.0002`（default，13sp）更正为 `\kern -0.00017`／`\kern 0.00017`（CJK，11sp）。旧值是缺陷值：正文以嵌套线型命令结尾时外层列表末尾没有可读 marker，末类别取自 ulem 结束定界符 `*` 被观察到的 default；修复后末类别来自正文实际的末字符“止”。`fntef-linebreak01` 的 TEST 2（`\CJKsout*[...]{虚室生白，吉祥止止。}`，以全角句号结尾）同样更正一处，成因相同。更新前已逐项确认差异都来自这一根因（见下文 `fntef-entry-space01` 一节）。本地审查 R1 后，全角右标点结尾改由 `tail` 字段置 `punct`、结束时不重放 marker，`fntef-linebreak01` 这一处由一对 marker kern 变为一个 `\kern 0.0`（零宽 kern 代替 marker，防止 `\par` 删掉装饰末尾的像素补偿 glue），几何不变。

### 线型命令的结束符与入口空格（`fntef-entry-space01`，#1091）

`fntef-entry-space01.lvt` 固定 #1091 的修复：ulem 结束定界符 `*` 不再被 capture 观察；正文先排出可见内容时入口源码空格留在装饰之前；本地审查 R1 后补修的右边界（正文末尾是空白、盒子等内容或全角右标点时命令后的空格与直接输入一致）与开头语法空格（入口空格排在它画成的线之前），R2 后补修的嵌套装饰识别与空格加全角左标点开头，以及 R3 后改用扫描标记判断的全角右标点结尾（含嵌套线型命令的内层，R4 后补上盒子里的嵌套、内层“标点＋末尾空格”与三层嵌套，R5 后补上 `CheckFullRight=true` 下的同类写法），以及 R6 后改为按含义比较的空格判断（字符码为 32 的活动字符不再被当作空格删去）与嵌套内层全角标点之后紧接西文，R7 后改写的嵌套内层与盒子里全角标点之后还有字符时的类别补报（`\@@_ulem_report_last:n`），以及 R8 后补上的嵌套内层正文末尾检查（`\@@_ulem_onin_tail_check:`，内层正文最后一个字符之后还有 glue、盒子等内容时置 `content`），以及 R9 后补修的全角左标点结尾（`tail=left`，结束时在外层重放标点节点）与嵌套命令左右两侧的连接（`\@@_ulem_nest_node:` 选择 marker、`\UL@onin` 在内层开头重放外层末尾的 marker），以及 R10 后的补修（嵌套内层用 `ulem-left` marker 认出全角左标点自己的节点、内层正文以空格开头时不重放左侧 marker、公式重排分支同样重放），以及 R11 后的改写（内层开头总是重放 marker、按入口层缓存的 `xCJKecglue` 决定是否保留源码空格检查，内层盒子里的词间空格随当前字体，内层以 glue、kern、penalty、规则、special 等开头时不再补左边界）。机制见 [[../architecture/xecjk-architecture]] xeCJKfntef 的「ulem 结束符与入口空格（#1091）」。共 17 个 `\TEST`，按判据分三类（与 lvt 文件头一致；R7 新增 TEST 11，原 TEST 11–13 顺延为 12–14，下文 R5、R6 记述中的 TEST 12、TEST 13 分别是现在的 TEST 13、TEST 14；R9 在末尾新增 TEST 15，编号不再顺延；R10 只在 TEST 15 里加用例）：

- **节点列表判位置（TEST 1、2、3、8、11、12、17）。** 只比总宽分不出空格在装饰前还是后——只修第一层时 issue 的 MWE 宽度已经与 oracle 相等，但空格仍在装饰之后。因此输出节点列表，固定 glue 位于第一个 `\rule(*+*)x0.0 \penalty 10000 \cleaders`（ulem 片段）之前。节点列表由 `\loggingoutput`（l3build 的 `regression-test.tex`）输出，它把 `\showboxdepth`、`\showboxbreadth` 设为 `\maxdimen`，`.tlg` 记录的是完整深度，嵌套盒子里的节点也在内；R8 前 lvt 在 `\loggingoutput` 之前写的 `\showboxbreadth=100`、`\showboxdepth=1` 被它覆盖，没有作用，lvt 注释与本节却据此写成“只输出第一层”（R8-M2），R8 后删去这两行并改正注释。TEST 11 正依赖完整深度，检查的是内层盒子里的节点。每个节点用例独占一页并先 `\TYPE` 一行 `CASE:`，`\pagestyle{empty}` 去掉页码噪声。TEST 1–3 覆盖仿 issue 的写法（`\myfillin`，用 `\CJKunderline` 与规则盒子）、issue 的原样写法（`\issuefillin`，`\CJKunderline*` 包住西文 `xxxx`）及二者的 `~` 写法、盒子、`\hspace*`、`\hspace`、盒子后接汉字、`\quad`、`\CJKsout`、原生 `\uline` 与嵌套，以及开头只有颜色 special（仍按首字符规则）和无空格的对照。TEST 8 固定正文开头的语法空格画成的 `\cleaders` 位于入口空格之后（盒子、`\hspace*`、汉字、西文开头，只有空格的正文，原生 `\uline`，以及 R2 新增的空格加全角左标点开头 `lead-fullleft`、`lead-fullleft-latin`）。TEST 11（R7 新增）固定嵌套内层以全角左标点开头时补报类别不在内层盒子里插入左边界 glue：`nested-leftquote-latin`（`他说\CJKunderline{\CJKsout{“OK”}}吗`）在 `a8a0c05a` 上 “ 与 OK 之间多出 3.33pt glue。这个写法的总宽度仍与直接输入不一致（首类别为空，属既有缺口，见 [[../memory/doc-gaps]]），所以用节点列表而不是宽度比对固定它。R8 后 TEST 11 新增 `three-level-no-marker`（`符 \uline{\sout{\xout{中}}} 后`），固定中间层盒子末尾不残留为识别最内层盒子临时补的 `ulem-nest` marker（不删 marker 时宽度用例全部通过，只有这条节点列表多出一对 marker kern）。R9 后 TEST 11 再增 `three-level-keep-char-marker`（`符 \uline{\sout{\xout{中}中}} 后`），固定中间层正文以字符结尾时，字符自己的 CJK marker 不被当成临时 marker 删掉（R9 起临时 marker 可能与它同类，删除后末节点不是盒子就放回；去掉这一步时宽度全过，只有这条节点列表不同）。TEST 12（R7 前为 TEST 11）固定嵌套装饰之后的盒子保留 `\raise` 位移、命令后的空格保留：`nested-raisebox` 用 `\raisebox`，它新建盒子，**不经过**末尾盒子检查；`nested-raise-copy`（`\CJKsout{中}\raise2pt\copy\FillBox`）不新建盒子，实际经过这条路径，基线固定 `shifted -2.0` 与命令后的 `\glue 3.33`。R9 后这两条的基线里，嵌套装饰与后面盒子之间的 marker 由 `ulem-nest`（`\kern -0.00032`／`\kern 0.00032`）变为 CJK（`\kern -0.00017`／`\kern 0.00017`），因为 `\@@_ulem_nest_node:` 在内层以汉字结尾时改补 CJK marker；宽度与其他节点不变，页码因 TEST 11 新增一页而顺延。另记 R8 引起、当时没有写进文档的一处基线变化（R9-M4）：TEST 1 的 `nested`（`符 \uline{\CJKsout{\usebox{\FillBox}}} 后`）新增一行 `\kern 0.0`，因为内层以盒子结尾，`\@@_ulem_onin_tail_check:` 置 `content`，stream end 改排零宽 kern 代替 marker，宽度不变。
- **与直接输入比较宽度（TEST 4–7、9、10、13、15、16）**，打印 PASS／FAIL：空正文（含 `\relax`、`\uline`、`\CJKsout`、西文两侧）不增加宽度；嵌套装饰结尾与全角句号结尾的右边界跟随实际的最后一个字符；全角左标点开头（含源码空格、`\uline`）与直接输入等宽；普通 CJK／西文首字符不受影响。TEST 9 是末尾内容的宽度比对（R7 后 36 项，R8 后 61 项，见本条末尾）：`\hspace*`、盒子、`\phantom`、`\kern`、`\penalty`、`\special`、`\hbox`、`\rule`、`\quad`、控制空格、公式后接空白、嵌套线型命令后接空白或盒子（R2 新增 `nested-then-copy`：嵌套装饰之后接一个同为 `\CJKsout{中}` 排出、尺寸相同的 `\usebox`）、正文末尾空格前的盒子与 kern、两侧无空格且后接汉字或西文，以及仍按末字符处理的对照（字符、颜色、`\mbox`、嵌套装饰、`\CJKunderdot`）。TEST 10 是全角右标点结尾（15 项：句号、右引号、间隔号，后接汉字或西文、有无空格，`\uline`，标点后再接空白；R2 新增七个标点在正文内层分组里的写法：花括号 `{中。}` 与“空格＋西文”“空格＋汉字”“无空格西文”“无空格汉字”各一项，`\textcolor{red}{中。}` 与“空格＋西文”“无空格西文”各一项，分组内 `{\color{red}中。}` 与“空格＋西文”一项，oracle 保留同样的分组）。R3 后 TEST 10 增至 34 项，新增 19 项：标点之后还有不产生节点的记号（`\relax` 后接空格与西文、汉字，`{}`，`\hspace{0pt}`，包装宏 `\EntryAns`，即 `\newcommand\EntryAns[1]{#1\relax}`），正文内侧空格与末尾空格，`\uline` 加 `\relax`；嵌套线型命令内层以句号或右引号结尾，无空格或有空格后接西文、后接汉字、`\uline` 作外层、内层分组、内层 `\relax`、内层 `\mbox`，嵌套之后接 `\relax` 有无空格两种；以及 `\mbox` 里的句号（`mbox-period-latin`）。oracle 写成 `中。\relax{} x`、`{中。} x` 等，与装饰正文中标点之后的记号对应。R3 后全文件 90 项 PASS。R4 后 TEST 10 增至 41 项，新增 7 项：`\mbox`／`\fbox` 里的嵌套装饰（`mbox-nested-period-space-latin`、`fbox-nested-period-space-latin`，即 `\uline{中\mbox{\sout{文。}}} x` 一类，以及 `mbox-nested-period-latin`）、嵌套内层“标点＋末尾空格”后接西文与汉字（`nested-period-trailing-latin`、`nested-period-trailing-cjk`，oracle 为 `{中。 } x`）、三层嵌套加 `\relax`（`three-level-relax-space-latin`）与三层嵌套标点结尾后接西文（`three-level-period-latin`）；全文件 97 项 PASS。R5 新增 TEST 12「trailing full-width right punctuation with CheckFullRight」（14 项），原来的段末自然宽度改为 TEST 13：先 `\xeCJKsetup{CheckFullRight=true}`，覆盖单层“标点＋末尾空格”后接西文与汉字、正文内侧空格、两层与三层嵌套的末尾空格、句号结尾有无空格后接西文／汉字、`\relax`、两层嵌套句号、词间空格，以及“先有带空格的标点、再有不带空格的标点”（单层 `中。 {}中。`、嵌套 `中。 中。`，固定没有空格时布尔置假）；最后关闭选项再测一项，固定关闭时复位布尔。全文件 111 项 PASS。R6 后 TEST 10 增至 44 项，新增 3 项嵌套内层全角标点之后紧接西文：`nested-period-latin-letter-cjk`（`\uline{\sout{中。z}} 后`）、`nested-left-quote-latin-letter-cjk`（`\uline{\sout{中“z}} 后`）、`nested-period-latin-letter-latin`（`\CJKunderline{\CJKsout{中。z}}x`），oracle 为 `中。z 后` 等直接输入。TEST 12 增至 16 项，新增 `cfr-active-space` 与关闭选项后的 `cfr-off-active-space`：文件头用 ``\lccode`\~=32`` 加 `\lowercase` 构造字符码为 32 的活动字符 `~`，定义为 `z`，`\EntryActiveSpaceCase` 即 `中。~a`，与直接输入 `中。za` 比较（`\verb` 与 `\obeyspaces` 下的空格就是这类记号）。TEST 12 的标签以 `cfr-` 开头（如 `cfr-trailing-space-latin`、`cfr-off-period-space-latin`），避免与 TEST 10 的同名用例混淆、PASS／FAIL 行分不清出处。全文件 116 项 PASS。R7 后 TEST 10 增至 59 项，新增 15 项：全角标点之后再接汉字或再接标点与汉字的五项（`nested-paren-latin-cjk` 即 `中\uline{\sout{中（A）中}}吗`、有空格的 `nested-paren-latin-cjk-space`、后接西文的 `nested-paren-latin-cjk-latin`、`nested-quote-latin-cjk-latin` 即 `中\uline{\sout{中“z”中}}x`、`nested-period-latin-comma-cjk` 即 `中\uline{\sout{中。z，中}}吗`）；`\mbox` 变体（`nested-mbox-period-latin-cjk`、`nested-cjk-mbox-period-latin-cjk`、`nested-mbox-period-latin-latin`，即 `\uline{\sout{\mbox{中。z}}}` 一类；`nested-mbox-paren-latin-then-cjk` 即 `中 \uline{\sout{\mbox{中（A）}中}} 吗`；`nested-mbox-latin-leftquote-cjk`）；西文后接全角左引号再接汉字的 `nested-latin-leftquote-cjk-latin`；capture 暂停期间的 `nested-sbox-inside`（`\mbox{中\sbox0{中。z}}`，oracle 为 `\mbox{中}`）；外层先有 `\hspace` 的 `nested-content-then-comma-cjk`；以及在 `CJLineBreak=strict` 下经 FullRight→CJStarter 转换的 `strict-nested-paren-latin-starter` 与后接西文的 `strict-nested-paren-latin-starter-latin`（用例后恢复 `CJLineBreak=normal`）。同时改掉重名标签，使各 TEST 的标签互不相同：TEST 4 的 `sout` 改为 `empty-sout`，TEST 6 的 `no-space`、`space` 改为 `fullleft-no-space`、`fullleft-space`，TEST 9 的 `quad` 改为 `tail-quad`。全文件 131 项 PASS、0 FAIL。R8 后 TEST 9 增至 61 项，新增 25 项嵌套内层正文最后一个字符之后还有内容的写法，oracle 为同样内容的直接输入：内层以汉字结尾后接 `\hspace*`（命令两侧有空格的 `inner-fill`、后接西文的 `inner-fill-latin`）、`\hspace`、`\quad`、盒子（`inner-fillbox`、`inner-fillbox-latin`）、`\kern`、`\penalty`、`\special`；内层以西文结尾（`inner-latin-fill`）；全角标点之后再接汉字与末尾内容（`inner-period-cjk-fill`，R8-I1 的 `inner-paren-fill` 即 `中 \uline{\sout{中（A）中\hspace*{1em}}} 吗`，以及 `inner-paren-fill-latin`、`inner-paren-quad`、`inner-paren-rule`、`inner-leftquote-fill-latin`）；`\CJKunderline{\CJKsout{…}}` 与 `\uline{\uwave{…}}` 变体（`inner-cjkul-paren-fill`、`inner-wave-fill`）；三层嵌套（中间层末尾有内容的 `three-level-inner-fill`、最内层末尾有内容的 `three-level-innermost-fill`，以及仍按汉字结尾处理的 `three-level-last-cjk`、`three-level-last-latin`）；内层以颜色切换中的字符或 `\mbox` 结尾时仍按字符处理（`inner-last-color`、`inner-last-mbox`），`\mbox` 之后再接 `\hspace*`（`inner-mbox-then-fill`）。全文件 156 项 PASS、0 FAIL。R9 新增 TEST 15「trailing full-width left punctuation and nested boxes」（45 项），oracle 为同样内容的直接输入：
  - 全角左标点结尾，单层：后接西文、空格加西文、空格加汉字（`left-latin`、`left-space-latin`、`left-space-cjk`），`\CJKunderline{中《}x`，正文只有标点（`left-only-latin`），右标点后接左标点（`left-after-right-space-latin`）、两个左标点（`left-left-space-latin`），标点后接 `\relax`（`left-relax-space-cjk`、`left-relax-latin`，oracle 为 `中（\relax{} 后`）与 `\hspace{0pt}`（`left-hspace0-space-cjk`）。
  - 全角左标点结尾，嵌套：`nested-left-space-cjk`（R9-I1 的 `符 \uline{\sout{中（}} 后`）、`nested-left-latin`、`nested-left-space-latin`，`\CJKunderline{\CJKsout{中《}}` 与 `\uline{\uwave{中“}}` 变体，三层嵌套两项，内层 `\relax` 两项，内层末尾空格（`nested-left-inner-space-cjk`，oracle 为 `{中（ } 后`），`\nobreak\hspace{0pt}`（`nested-left-nobreak-hspace0`）、`\hspace*{1em}`、`\kern1pt`，两个左标点（`nested-two-left`），西文后接左标点（`nested-latin-left`）。
  - 内层以西文加末尾空格结尾：`nested-latin-space-cjk`（`中\uline{\sout{x }}中`，R9-M5，见下文 R9 一段）。
  - `CheckFullRight=true`：`cfr-left-space-latin` 与先有带空格的右标点、再以左标点结尾的 `cfr-nested-right-left-space-latin`（`符 \uline{\sout{中。 中（}} x`），之后关闭选项。
  - 嵌套命令与相邻字符的连接：三层（`three-level-latin-then-cjk` 即 R9-I2 的 `符 \uline{\sout{\xout{x}中}} 后`、无空格版、`\CJKunderline{\CJKsout{\CJKxout{x}中}}` 版，`three-level-cjk-then-latin`、`three-level-cjk-mid-latin`、`three-level-sibling-cjk-latin`），两层（`nested-latin-then-cjk`、`nested-cjk-then-latin`、`nested-cjk-then-cjk`、`nested-latin-then-latin`、`nested-cjk-mid-latin`），左侧（`latin-then-nested-cjk` 即 `符 \uline{x\sout{中}} 后`、`cjk-then-nested-latin`），并列（`sibling-latin-cjk`、`sibling-cjk-latin`），`\mbox` 内（`mbox-latin-then-nested-cjk`，即 `符 \uline{x\mbox{x\sout{中}}} 后`）与 `\relax` 之后（`latin-relax-then-nested-cjk`）。
  - 全文件 201 项 PASS、0 FAIL；lvt 头注释的宽度 TEST 列表已加上 TEST 15。
  - R10 后 TEST 15 增至 58 项，新增 13 项（以 git diff 核对）：标点之后先有其他节点、再有用户写的 `~` 或 `\nobreak\hspace`（R10-I1 的 `nested-left-box-tie` 即 `符 \uline{\sout{中（\mbox{}~}} 后`，以及 `nested-left-kern-nobreak`、`nested-left-rule-nobreak`、`nested-left-special-nobreak`、三层的 `three-level-left-box-tie`），标点后直接接 `~` 的 `nested-left-tie`；内层正文以空格开头（R10-I2 的 `cjk-then-nested-space-cjk` 即 `\uline{中\sout{ 中}}`，oracle 为 `中{ 中}`，以及 `\CJKunderline{中\CJKsout{ 中}}` 版 `cjkul-cjk-then-nested-space-cjk`、控制空格 `cjk-then-nested-ctrl-space-cjk`、分组里的空格 `cjk-then-nested-group-space-cjk`、命令两侧有空格的 `cjk-then-nested-space-cjk-spaced`）；内层以公式加空格结尾、走重排分支（R10-M3 的 `latin-then-nested-math-space` 即 `\uline{x\sout{中$a$ }中}`，以及 `latin-then-nested-math-space-latin`）。`\CJKunderline{中\CJKsout{ 中}}` 在 `.tlg` 里带一行 `Nesting is not supported` 警告，与基线里其他 fntef 线型命令互嵌的用例相同。lvt 中 TEST 15 的注释删去了“分组结束”，并注明标点在正文内的分组里时尚未处理。全文件 214 项 PASS、0 FAIL。
  - R11 后 TEST 15 增至 79 项，新增 21 项（以 git diff 核对）：内层以 `\space` 开头（`cjk-then-nested-cs-space-cjk` 与带上下文的 `cjk-then-nested-cs-space-cjk-context`）与两层分组里的空格开头（`cjk-then-nested-two-group-space-cjk`）；`\xeCJKsetup{xCJKecglue=true}` 下的一组五项（`xecglue-` 开头：空格、`\ `、分组里的空格、命令两侧有空格、`\CJKunderline{中\CJKsout{ 中}}`），之后恢复为假；`CJKspace=true` 下的粗体 `cjkspace-cjk-then-nested-bold-space-cjk`（`\uline{中\sout{\textbf{ 中}}}`）；内层以非字符内容开头时的左边界：`~`（`latin-then-nested-tie-cjk` 即 `x\uline{\sout{~中}}x`、`latin-then-nested-tie-cjk-latin`、`cjk-then-nested-tie-cjk`、三层 `latin-then-three-level-tie-cjk`）、空格、`\hspace{1em}`、`\kern1pt`、`\special{x}`、`\mbox{}`（`latin-then-nested-mbox-cjk`），以及入口有源码空格的 `latin-space-then-nested-tie-cjk`；最后两项 `nested-color-then-cjk-spaced`（`符 \uline{\sout{\textcolor{red}{中}}} 后`）与 `nested-lead-fill-cjk-spaced`（`符 \uline{\sout{\hspace*{1em}中}} 后`）专门检查“入口有源码空格时不改 `entry`”这一条件。lvt 中 TEST 15 的注释改为内层开头的空格与直接输入一样处理（包括 `\space`、多层分组、`xCJKecglue` 与 `CJKspace` 的情形），并写明内层先排出 `~`、`\hspace`、`\kern` 等内容时外层左边界不再补在这些内容与字符之间。全文件 235 项 PASS、0 FAIL。
  - R12 后 TEST 15 新增 25 项宽度用例、TEST 11 新增一项节点列表用例（以 git diff 核对）。宽度用例：内层以颜色命令开头且入口没有源码空格（`latin-then-nested-color-cjk` 即 `x\uline{\sout{\textcolor{red}{中}}}x`，以及 `-mid`、`cjk-then-nested-color-latin`、`{\color{red}中}` 形式、三层、`\special` 在颜色前或颜色里的两项）；`~` 后接颜色（`latin-then-nested-tie-color-cjk`、带入口空格的 `nested-tie-color-cjk-spaced`）；入口有源码空格、颜色后接 `~` 或 `\hspace`（`nested-color-switch-tie-cjk-spaced` 即 `符 \uline{\sout{\color{red}~中}} 后`、`nested-color-switch-hspace-cjk-spaced`）；钩子的 penalty、规则、vlist 分支（`\nobreak`、`\strut`、`\vbox{}` 开头各一项）；公式重排分支的 `~`、`\kern`、颜色开头三项；`\sbox` 里的三项（其中一项在 `xCJKecglue=true` 下）与 `xCJKecglue=true` 下的颜色开头；`CJKspace=true` 下 `\mbox` 改字号（`cjkspace-cjk-then-mbox-large-space`）与嵌套装饰改字号；外层末尾是 `CJK-space` marker 的两项（`cjk-space-then-nested-mbox-cjk` 即 `中\uline{中 \sout{\mbox{a}中}}中`，以及 `CJKspace=true` 下的 `中\uline{中 \sout{中}}中`）。节点列表用例 `nested-color-no-marker` 确认颜色命令后放下的 `ulem-transparent` marker 在第一个字符出现时删去、不留在内层盒子里。新增项在 `94bd84d5` 的代码上 14 项失败。全文件 260 项 PASS、0 FAIL。
  - R13 后 TEST 15 新增 5 项宽度用例、TEST 11 新增 3 项节点列表用例（以 git diff 核对）。宽度用例都带入口源码空格，颜色与后面的 `~`、`\hspace` 不在同一层内层正文里：`outer-color-then-nested-tie-cjk-spaced`（`符 \uline{\color{red}\sout{~中}} 后`）、`outer-textcolor-nested-tie-cjk-spaced`（`符 \uline{\textcolor{red}{\sout{~中}}} 后`）、`mid-color-then-deeper-tie-cjk-spaced`（`符 \uline{\sout{\color{red}\xout{~中}}} 后`）、`mid-color-then-deeper-hspace-cjk-spaced`（同上，`\hspace{1em}`）、`sibling-color-then-nested-tie-cjk-spaced`（`符 \uline{\sout{\color{red}}\sout{~中}} 后`）。节点列表用例固定 `ulem-transparent` marker 仍在列表末尾时会被删去：`nested-two-color-no-marker`（`x\uline{\sout{\color{red}\color{blue}中}}x`）、`nested-color-deeper-no-marker`（`x\uline{\sout{\color{red}\xout{中}}}x`）、`nested-color-only-no-marker`（`x\uline{\sout{\textcolor{red}{}}}x`）。新增项在 `101a5adc` 的代码上 5 项宽度失败，3 项节点列表留有 marker（0.00032pt 的 kern 对）。lvt 注释里“现存的结果”改为“现场排出的结果”。全文件 265 项 PASS、0 FAIL。R14 小问题后 TEST 11 再增节点用例 `nested-color-hspace-keeps-marker`（`x\uline{\sout{\color{red}\hspace{1em}中}}x`），固定颜色之后先排出其他内容时 marker 留在内层盒子里这一行为；宽度用例数不变，仍为 265 项 PASS。
  - **`\sbox` 用例的 oracle 在导言区预先存好。** oracle 写成导言区的 `\sbox\EntryBoxOracle{中{ 中}}`，`xCJKecglue=true` 下另存 `\EntryBoxEcOracle`。原因是前一个写法留下的 `\g_@@_glue_check_pending_bool` 会进入 `\sbox`，在用例里现场排的 `\sbox{中{ 中}}` 宽度随用例顺序变化（v3.10.6 同样如此，v3.9.1 没有这个问题），这是核心的既有问题，登记在 `llmdoc/memory/doc-gaps.md`。探测矩阵 r12m 里唯一变差的 `i2-sp` 就是这样：oracle 受前一用例影响，单独运行时当前代码与 `94bd84d5` 都是 23.33pt。
- **R15 与 a8b45cf4 的补充（TEST 15–17）**：R15 后（`25a466af`，三层嵌套中间层先排出的内容）全文件 274 项 PASS。`a8b45cf4` 新增 TEST 16「leading boxes, penalties and math before the first character」（41 项宽度用例：单层以 `\fbox{}`、`\mbox{\hspace{1em}}` 开头，第一个字符在原始 `\hbox`、`\phantom`、`\raisebox`、`\vbox` 里，`\nobreak`，公式；嵌套命令之前的外层正文、兄弟装饰、内层与中间层先排出原始盒子、`\special`、`\kern`；`\mbox`、`\fbox` 里的线型命令；公式重排分支；以 `-tie` 结尾的用例以 `~` 写法为 oracle，固定嵌套填空线与 `~` 写法对称）与 TEST 17「no transparent marker left in a decoration」（9 项节点列表，确认 `ulem-transparent` marker 不留在输出里，含 penalty 结尾、只有颜色、兄弟装饰只有颜色），TEST 2 新增节点用例 `fbox-spaced`。全文件 315 项 PASS、0 FAIL；新增宽度用例在 `5ee4898c` 上 24 项失败。逐项变异 69 项（`tmp/i1091/fix2/mutate16.py`，含一项核心变异）全部被发现，13 项只由节点列表发现。
- **c254f535 的补充（本地独立审查 R16，TEST 16、17）**：TEST 16 新增 19 项宽度用例（提交说明写 20 项，按 lvt 与 `.tlg` 逐行核对是 19 项）：透明盒子后接全角左标点或左引号（`fbox-then-leftparen`、`fbox-then-leftquote`、`cjkul-fbox-then-leftparen`），命令前是西文、正文以全角左标点开头（`latin-then-leftparen`、`latin-then-color-leftparen`、`latin-ctrl-space-then-leftparen`），透明盒子之前已有内容或开头语法空格（`kern-then-fbox`、`hbox-then-fbox`、`special-then-fbox`、`kern-then-mbox`、`syntax-space-then-fbox`、`syntax-space-then-fbox-latin`、`fbox-then-fbox`），以及正文里的盒子（`fbox-nested-in-body` 即 `x\uline{\fbox{\sout{中}}}x`、`fbox-nested-in-body-latin`、`mbox-kern-nested-in-body`、`mbox-tie-nested-in-body`、`mbox-special-nested-in-body`、`fbox-kern-color-in-body`）。TEST 17 新增 4 项节点列表：`mbox-color-no-marker`（正文里的 `\mbox` 内部不放 marker）、`fbox-leftparen-no-marker`（全角左标点路径下透明 marker 由 `\UL@stop` 删去）、`cjk-then-leftparen` 与 `latin-ctrl-space-then-leftparen-nodes`（最终审查后改名，与 TEST 16 的同名宽度用例区分；汉字与标点之间的 `\CJKglue`、命令前的控制空格留在原处，宽度用例看不出 0pt 可伸长的 glue 在不在）。全文件 334 项 PASS、0 FAIL；新增项在 `21ac8c10` 的代码上 17 项宽度失败、1 项节点列表留有 marker。逐项变异 83 项（`tmp/i1091/fix2/mutate17.py`，含两项核心变异）全部被发现，17 项只由节点列表发现。
- **d250e2a7 的补充（本地独立审查 R17，TEST 16、17）**：TEST 16 删去 `syntax-space-then-fbox-latin`（`中\uline{ \fbox{}x}中` 只在默认 `CJKecglue` 下碰巧与直接输入等宽，入口前是汉字的写法尚未处理，见 `llmdoc/memory/doc-gaps.md`），新增 `mbox-color-fbox-then-cjk`（`x\uline{\mbox{\color{red}\fbox{}}中}x`，核心不取回盒子的分支也调用透明盒子钩子）。TEST 17 新增 3 项节点列表：`cjk-then-fbox-leftparen`（`中\uline{\fbox{}（中}中`，汉字与透明盒子之间的 `\CJKglue` 保留、marker 删去；默认 `\CJKglue` 的自然宽度为 0，宽度用例看不出它在不在）、`hbox-mbox-no-marker`（`x\uline{\hbox{\mbox{}}中}x`）与 `hbox-color-no-marker`（`x\uline{\hbox{\color{red}\hspace{1em}}中}x`），后两项确认正文里的原始盒子内部不留 marker。PASS 行只来自宽度用例，TEST 16 删一项、增一项，全文件仍为 334 项 PASS、0 FAIL。逐项变异 82 项（`tmp/i1091/fix2/mutate18.py`，79 项 xeCJKfntef 变异加三项核心变异 `core-lastbox-no-hook`、`core-no-box-hook`、`core-no-box-begin-hook`）中 81 项被发现；未被发现的 `fullleft-flag-stuck`（删去全角左标点报告之后复位 `\l_@@_ulem_fullleft_bool` 的一行）按提交说明是等价变异：这个布尔量只在 `\@@_boundary_emit_left_hook:nn` 里读取，而钩子只在入口为 `armed` 时起作用；第一次补左边界之后入口已不再是 `armed`，布尔量是否复位不影响结果。提交说明写 17 项只由节点列表发现；按删去 `\g_@@_ulem_transparent_tail_bool` 之后的结果 `tmp/i1091/fix2/mut18c.txt` 核对是 16 项。差别在 `outside-box-no-raw-gate`：删去布尔量之前（`mut18b.txt`）它只由节点列表发现，删去之后 `sibling-color-then-nested` 的宽度用例也会失败。删去布尔量之前，`tbegin-no-tail`、`tend-no-tail`、`tail-no-bool` 三项与这个布尔量相关的变异都不再被发现（`mut18b.txt`），这是删去它的依据之一，见反思的 R17 一节。
- **b0e44c48 的补充（TEST 16）**：新增 5 项宽度用例 `hspace0-then-cjk`（`x\uline{\hspace{0pt}中}x`）、`hspace0-then-fbox`、`hspace0-then-latin`、`hspace0-then-nested` 与 `hspace0-then-cjk-spaced`（`前 \uline{\hspace{0pt}中} 后`，本意是固定“入口有源码空格时零宽 glue 不解除入口”）；前 4 项在 `d250e2a7` 上失败。全文件 339 项 PASS、0 FAIL。逐项变异 84 项（`mutate18.py` 新增 `skip0-no-resolve`、`skip0-ignore-space`）中 83 项被发现，17 项只由节点列表发现，`fullleft-flag-stuck` 仍为等价变异。另有 672 项的零宽 glue 组合矩阵 `tmp/i1091/fix2/r18z.tex`。`hspace0-then-cjk-spaced` 只在默认 `\CJKglue`（自然宽度为 0）下等宽，看不出首类别补的 `\CJKglue` 排在已画线的零宽 glue 之后（R18-I2），R18 后删去，改由 TEST 3 的节点用例固定。
- **R18 的补充（TEST 3、16、17）**：TEST 3 新增节点用例 `hspace0-spaced`（`前 \uline{\hspace{0pt}中} 后`：零宽 glue 排成普通 glue，`\CJKglue` 排在第一个 ulem 片段之前）。TEST 16 删去 `hspace0-then-cjk-spaced`，新增 10 项宽度用例：正文先排出 `\kern`、`\special`、规则再接有颜色命令的 `\mbox`／`\makebox`（`kern-then-mbox-color`、`special-then-mbox-color-fbox`、`rule-then-mbox-color`、`kern-then-makebox-color-latin`、`nested-kern-then-mbox-color`），正文先排出颜色命令、盒子、`\kern` 再写公式、后接汉字或全角左标点（`color-then-math-cjk`、`fbox-then-math-cjk`、`kern-then-math-cjk`、`kern-then-math-leftparen`、`nested-kern-then-math-cjk`）。TEST 17 新增节点用例 `fbox-mbox-color-no-marker`（`x\uline{\fbox{}\mbox{\color{red}\fbox{}}中}x`，前一个透明盒子的 marker 不压在 `\mbox` 之下）。全文件 348 项 PASS、0 FAIL。新增宽度用例中 `1b72e7c9` 上失败 9 项（`kern-then-mbox-color` 等 5 项与 `color-then-math-cjk`、`fbox-then-math-cjk`、`kern-then-math-cjk`、`nested-kern-then-math-cjk`；`kern-then-math-leftparen` 用来固定“全角左标点前不补”）。逐项变异 94 项（`tmp/i1091/fix2/mutate20.py`，新增 `core-no-lastbox-begin-hook`、`core-lastbox-begin-at-end`、`fntef-lastbox-begin-noop`、`skip-plain-*` 三项、`math-last-*` 三项与 `last-content-no-math`）中 93 项被发现，22 项只由节点列表发现，`fullleft-flag-stuck` 仍为等价变异。新增探测矩阵 r19、r19g、r19m、r19mg（见 `llmdoc/memory/doc-gaps.md` 的适用范围一条）。
- **R19 的补充（TEST 16、17）**：TEST 16 新增 10 项宽度用例：`kern-then-math-latin`（公式之后是西文时不补 `\CJKecglue`），`nested-kern-then-math-cjk-spaced`、`nested-kern-then-math-latin-spaced`（命令前有空格的嵌套写法里公式之后的字符），`nested-color-then-mbox-leftparen`、`nested-fbox-then-mbox-leftparen`（嵌套内层先有透明内容、再接以全角左标点开头的 `\mbox`，R19-I1），`nested-mbox-leftparen-end`、`nested-cjk-mbox-leftparen-end`（内层以 `\mbox{（中}` 结尾），以及分组里设 `CJKglue={\hskip 1pt}` 的 `cjkglue-mbox-cjk-leftparen`、`cjkglue-kern-mbox-cjk-leftparen`、`cjkglue-special-fbox-cjk-leftparen`（以汉字结尾的盒子后接全角左标点，默认 `\CJKglue` 自然宽度为 0，看不出差别）。TEST 17 删去 `fbox-mbox-color-no-marker`（这个 marker 按 R19 的设计保留），新增 `fbox-fbox-no-marker`（结束时的 begin 钩子删去前一个 marker）与 `mbox-cjk-leftparen-no-marker`（盒子后的 `CJK` marker 删去、`\CJKglue` 的位置）。全文件 358 项 PASS、0 FAIL；新增宽度用例中 9 项在 `8e1a46db` 上失败（`kern-then-math-latin` 用来固定“公式后接西文不补”）。逐项变异 99 项（`tmp/i1091/fix2/mutate22.py`）中 98 项被发现，24 项只由节点列表发现，`fullleft-flag-stuck` 仍为等价变异。（`bf34c7ee` 的提交说明与这里原先写“全部被发现，25 项只由节点列表发现，fullleft-flag-stuck 不再是等价变异”，是比较脚本的误报：脚本本应去掉日志开头，但定位用的 `\START` 并不出现在日志里，于是连带比较了首行的编译时间，ref 与这一项跨了分钟，被算成“节点列表不同”。R20 后改为删去 `This is XeTeX` 一行再比较，重算 mutate18 至 mutate20 的结果与当时记录的一致，只有这一次受影响。）新增探测矩阵 r20、r20g（见 `llmdoc/memory/doc-gaps.md` 的适用范围一条）。
- **R20 的补充（TEST 16）**：新增 `nested-group-space-then-math-latin`（`{中} \uline{\sout{\kern1pt$a$x}} 后`）、`nested-mbox-space-then-math-latin`（`\mbox{中} ` 开头）两项，固定入口前只是 `CJK`、空格前面是分组结束或盒子时保留入口空格（R20-I1，两项在 `46ffd92c` 上失败）；`nested-mbox-leftparen-then-cjk`（`x\uline{\sout{\mbox{（中}}中}x`）固定相对 v3.10.6 的可见变化（v3.10.6 少一枚间距，`bf34c7ee` 起一致）。全文件 361 项 PASS、0 FAIL。逐项变异 100 项（`tmp/i1091/fix2/mutate23.py`，新增 `onin-math-drop-cjk`）中 99 项被发现，24 项只由节点列表发现，`fullleft-flag-stuck` 为等价变异；比较脚本改为删去日志首行的编译时间再比较节点列表。
- **R20 范围外观察之后的补充（TEST 18）**：新增 TEST 18（20 项宽度用例），固定嵌套内层入口前不是紧跟汉字的空格（`\mbox{中} `、`{中} `、`前\ `、`前{} `、`\mbox{x} `）在 `\kern`、`\hspace*`、`~`、规则之前与公式之后的处理、`前\ `／`前{} ` 之后直接写汉字（含 `xCJKecglue=true`、汉字前先有颜色命令或 `\mbox`、`CJKecglue={\hskip 5pt}` 各项），以及正文先有内容、以公式结尾、命令后紧接汉字。15 项在 `59e356b9` 上失败。全文件 381 项 PASS、0 FAIL。逐项变异 119 项（`tmp/i1091/fix2/mutate25.py`，以 p67 原型为基准，比 mutate23 多 19 项）中 115 项被发现，25 项只由节点列表发现；未被发现的 4 项里，`fullleft-flag-stuck` 为等价变异，`keep-content-onin-check` 用同一条件再判断一次、按构造等价，`keep-pend-any-before`（入口前不限于 `CJK`）在矩阵上也没有差别，`keep-single-too`（去掉只在嵌套链上判断的条件）只改变单层写法 `\mbox{中} \uline{\kern1pt\mbox{中}} 后`（所有版本都与直接输入不同，见 doc-gaps）。`keep-pend-any-class`（去掉“首类别非空”）由上面两项颜色命令、`\mbox` 用例发现，加这两项用例之前未被发现。比较脚本另一处噪声：新变异的目录里没有 `.aux`，日志多出 `No file ….aux` 一行，被算成“节点列表不同”；现在每次运行前删去 `.aux`，重跑 mutate23 的结果与记录一致（99／100、24 项只由节点列表发现）。新增探测矩阵 r24、r25、r26（见 `llmdoc/memory/doc-gaps.md` 的适用范围一条）。
- **R21 的补充（TEST 18）**：TEST 18 增 8 项：`nested-group-space-then-math-end-cjk`、`nested-mbox-latin-space-then-math-end-cjk`、`nested-group-space-then-math-end-latin`（嵌套内层保留入口空格时以公式结尾，R21-I1）；`outer-mbox-space-kern-then-nested`、`outer-group-space-rule-then-nested`、`outer-mbox-space-kern-then-two-nested`（外层正文先排出内容再接嵌套命令，R21-I2）；`CJKecglue={\hskip 5pt}` 下两项。7 项在 `a522e35a` 上失败（`...-math-end-latin` 固定“后接西文不补”），全文件 389 项 PASS、0 FAIL。逐项变异 126 项（`tmp/i1091/fix2/mutate26.py`，以 p68 原型为基准，新增 8 项）中 119 项被发现，25 项只由节点列表发现。未被发现的 7 项：`fullleft-flag-stuck`、`keep-content-onin-check`、`keep-pend-any-before` 同 R20；`keep-single-too`（去掉只在嵌套链上判断的两个条件）当时在测试上看不出来（R22-M3 更正：原先写“只改变单层的节点位置”不对，单层 `\mbox{中} \uline{\kern1pt\mbox{中}} 后`、`前\ \uline{\kern1pt\textcolor{red}{中}} 后` 的宽度也会由 31.0pt 变为 34.33pt，只是没有用例覆盖；R22 后这个条件已删去）；`lead-bool-not-reset`、`tail-bool-not-reset`（布尔量不在检查后复位）按构造等价，这两个布尔量都在检查前刚刚置位、只在检查里读取，下一次检查前又会被重新设置；`math-tail-always-marker`（不论是否在内层正文结尾都放 `math` marker）在测试与矩阵上没有差别，那条路径只在第一个字符是汉字、公式紧挨在前时走到，这时 marker 会被随后的类别转换取走。`lead-check-onin-only`（只在内层正文里做进入嵌套命令前的检查）的第一版改写没有改变代码（条件放错了位置），被记为“未被发现”；改正后由 `outer-*-then-nested` 等 7 项发现。新增探测矩阵 r27（见 doc-gaps 的适用范围一条）。（R22 更正：这里与 index 原先写“127 项中 120 项”，统计时把 `ref` 那一行也算成了一项变异，应为 126 项中 119 项；未被发现的 7 项不变。R20 的 100 项与 R20 范围外观察之后的 119 项没有多算。）
- **R22 的补充（TEST 2、18）**：TEST 2 增 `group-space-kern-then-nested`、`mbox-space-kern-then-mbox` 两项节点用例，固定外层正文里保留的入口空格排在第一个装饰片段之前（`9105ba1e` 上前者的空格在 `\cleaders` 之后）。TEST 18 增 9 项宽度用例：`outer-kern-textcolor-then-nested`、`outer-kern-color-then-nested`、`outer-rule-textcolor-then-nested`、`outer-mbox-space-nobreak-then-nested`（R22 时与 TEST 16 的同名用例重名，最终审查后改名）、`outer-penalty-then-nested`（R22-I1），`single-mbox-space-nobreak`、`single-mbox-space-kern-then-mbox`、`single-ctrl-space-kern-then-textcolor`（单层写法，R22-M3），`single-cjk-space-nobreak`（入口前是汉字加空格时 `\nobreak` 之后仍删去空格）。8 项宽度用例在 `9105ba1e` 上失败，全文件 398 项 PASS、0 FAIL。逐项变异 128 项（`tmp/i1091/fix2/mutate28.py`，以 p76 原型为基准）中 122 项被发现，27 项只由节点列表发现。未被发现的 6 项：`fullleft-flag-stuck`、`keep-pend-any-before`、`keep-content-onin-check`、`math-tail-always-marker`、`tail-bool-not-reset` 同 R21；`defer-not-reset-at-begin`（新的装饰命令开始时不清除“记下的空格”）按构造等价，记下的空格总在同一个装饰命令的 `\UL@stop` 里排出并清除。原型里另有 `\@@_ulem_end:` 排出记下的空格、`\@@_ulem_entry_defer:n` 清除 `space_flag` 两处，变异显示去掉它们没有差别，已删去。
- **R23 的补充（TEST 2、3、18）**：TEST 2 增 9 项节点用例（`group-space-kern-then-textcolor`、`ctrl-space-kern-then-textcolor`、`mbox-space-kern-then-color-group`、`mbox-space-group-nobreak`、`group-space-kern-then-hbox`、`mbox-space-kern-then-group`、`group-space-kern-math-then-nested`、`mbox-space-color-kern-then-nested`、`mbox-space-textcolor-kern-then-cjk`），固定第一个字符在用户分组、原始盒子里，或外层先有颜色命令、公式时，入口空格仍在第一个装饰片段之前；9 项在 `3de877f2` 上都不对。TEST 3 增 `hspace0-math-spaced`（以 `~` 写法为 oracle）；TEST 18 增 17 项宽度用例（原始盒子、用户分组、`\textbf`、`\special` 之后接分组、`\mbox{中} \uline{{中}} 后`，外层先有内容、写公式再接嵌套命令、分组或 `\textcolor`，`CJKecglue={\hskip 5pt}` 下两项），14 项在 `3de877f2` 上失败。全文件 416 项 PASS、0 FAIL。逐项变异 140 项（`tmp/i1091/fix2/mutate29.py`，以 p88 即 `a89246f6` 为基准，不含 `ref` 行）中 134 项被发现，32 项只由节点列表发现；未被发现的 6 项是 R22 的 5 项与 `r23-lead-bool-not-reset`（局部布尔量随分组结束失效，按构造等价）。R23 另写了位置检查脚本 `tmp/i1091/fix2/pos.py`：把矩阵里每个装饰写法的节点列表输出，标记入口空格（3.33pt 的词间 glue）出现在片段盒子里的用例，与 v3.10.6 逐项比较。它会把片段盒子里公式与汉字之间的 `\CJKecglue`（同样是 3.33pt）也标出来，结果要逐项核对。新矩阵 r29（`gen29.py`，原始盒子与用户分组）、r30（`gen30.py`，外层先排出内容再写公式）各 5 组选项（默认、`CJKecglue={\hskip 5pt}`、`CJKglue={\hskip 1pt}` 或 `xCJKecglue=true`、`CJKspace=true`、`CheckFullRight=true`）。`a89246f6` 的提交说明写“r24 至 r30 相对 p76 没有由一致变为不一致的用例”，r29 上其实有 2 项，更正记在 `.code-review/closure-20260927T021602Z/commits/fix27/correction.md` 与 doc-gaps「R23 后补记」。
- **R24 的补充（TEST 2、18）**：TEST 2 增 `group-fill`、`group-fill-tie` 两项节点用例（`\textbf` 里的填空线，以 `~` 写法为位置对照；`a89246f6` 上入口空格在片段盒子里）；TEST 18 增 12 项宽度用例：`outer-*-math-then-nested-{color,textcolor,mbox,fbox,leftparen}`、`outer-latin-math-then-nested-{color,mbox}`（公式之后的嵌套命令以颜色命令、盒子或全角左标点开头），`group-nobreak-penalty-only`、`group-penalty0-penalty-only`、`mbox-group-nobreak-penalty-only`（只含 penalty 的分组，记下的空格要在正文结束时排出），`group-space-hspace0-then-cjk`、`group-space-hspace0-ungrouped`（零宽 `\hspace`）。其中 11 项在 `a89246f6` 上失败，全文件 428 项 PASS。逐项变异 150 项（`tmp/i1091/fix2/mutate30.py`，以 p106 为基准，不含 `ref`）中 142 项被发现，35 项只由节点列表发现，未被发现的 8 项的理由见反思 R24 一节。新矩阵 r31（`gen31.py`，2322 项，5 组选项）。
- **R25 的补充（TEST 2、18）**：TEST 2 增 `empty-group-then-space`、`empty-group-then-space-tie`、`empty-group-then-fill`、`empty-group-then-fill-tie` 四项节点用例；TEST 18 增 14 项宽度用例与 `known-*` 两项节点用例（见 architecture「R25 后的补修」）。`\EntryAssertIdle` 改为同时断言 `\g__xeCJK_ulem_space_defer_bool` 为假。全文件 442 项 PASS。逐项变异 13 项（`tmp/i1091/fix2/mut32.list`，以 p122 为基准）中 11 项被发现；`q1-stream-reset`（ulem 命令开始时不清除两个记录）由后加的 `latin-math-color-then-next-decoration-in-hbox` 发现；`q15-empty-flush-nogate`（片段为空时排出不检查 `\UL@start`）区分不出：插桩显示这一分支在用户分组里走到时从没有记着的空格。新矩阵 r32（`gen32.py`）、r33（`gen33.py`）、r34（`gen34.py`）。R26 后 TEST 18 再增 `known-group-space-kern-math-then-nested-color-leftparen-latin`、`records-cleared-after-decoration` 两项节点用例，全文件 442 项 PASS；去掉装饰结束时的记录清除，后者的节点列表不同。
- **最终全范围审查后的补充（TEST 19）**：新增 TEST 19（放在文件末尾，不改动已有 TEST 编号），10 项宽度用例固定外层 `\mbox`、`\fbox` 里线型命令正文含全角左标点时盒子两侧的空格与间距（`box-uline-leftparen-mbox-spaced`、`box-uline-leftparen-fbox-spaced`、`box-uline-leftquote-mbox-spaced`、`box-uline-leftparen-fbox-cjk`、`box-uline-leftparen-fbox-latin`），以及正文以 `\textcolor`、`\mbox` 或嵌套线型命令结尾、花括号前还有空格时命令后的空格与间距（`trailing-textcolor-then-space-cjk`、`trailing-mbox-then-space-cjk`、`trailing-mbox-then-space-latin`、`trailing-nested-then-space-cjk`、`trailing-nested-then-space-latin`）；节点用例 `known-makebox-width-then-latin` 固定定宽 `\makebox` 的既有限制（见 architecture「最终审查后的补修」）。全文件 452 项 PASS。逐项变异 4 项中 2 项被发现，另两项是防御性写法。
- **替换的最终审查后的补充（TEST 17、20）**：新增 TEST 20（17 项宽度用例）：9 项正文只有注册盒子（`box-only-*`：`\makebox`、`\fbox`、两个盒子、`\colorbox`、`\color` 或 `\textcolor` 包住的盒子、嵌套命令里的盒子），8 项对照（`box-then-*`：盒子之后有 `\hspace*`、`\hspace`、`\kern`、`\rule`、`\special`、`\nobreak` 再接盒子、正文末尾空格；`space-then-box-cjk-latin`：正文以语法空格开头）。TEST 17 的 `latin-ctrl-space-then-leftparen` 节点用例改名为 `latin-ctrl-space-then-leftparen-nodes`，`single-fbox-only-no-marker` 的节点列表在装饰之后多出与直接输入相同的 `default` marker。文件头的判据清单补全 TEST 编号，注明 TEST 16 以 `~` 写法为 oracle 的四项。全文件 469 项 PASS，没有重名标签。逐项变异 12 项（`tmp/i1091/fix2/mut36.py`）全部被发现。新矩阵 r36（`gen36.py`）。
- **#1103 后的期望值变化（TEST 15 等）**：用例数不变，9 项宽度期望值随直接输入改变（`nested-color-switch-tie-cjk-spaced` 等 `*-cjk-spaced` 由 36.66pt 变为 33.33pt，`\hspace{1em}` 版由 43.33pt 变为 40.0pt，`nested-color-tie-math-space-cjk-spaced`、`nested-color-hspace-math-space-cjk` 各少 3.33pt），另有一处节点列表在颜色 push 之后多出一对 marker kern。原因是 oracle 里的颜色命令本身没有可见输出，见上文「没有可见输出的命令两侧的源码空格」一节。
- **段末自然宽度（TEST 14）**：把装饰放在段末排版，取出最后一行，比较行内容的自然宽度与同一内容的 `\hbox`，确认 `\par` 删除行尾 glue 时没有删掉装饰末尾的像素补偿 glue（stream end 改排零宽 kern 的理由）。
- 每个用例后都断言 capture depth、active seq、suspend depth 与 `\g_@@_ulem_entry_depth_int` 归零，防止暂停／恢复或 entry 状态泄漏到后续用例。

**变异验证**：第一轮 M1–M9 各只破坏一处，全部使本文件失败（rc=1）——M1 去掉 `\UL@end` 暂停与恢复、M2 不 arm、M3 去掉全角左标点的 CJK 类别报告、M4 去掉 `use_ulem_glue_outer` 的 resolved 判断、M5 去掉 stream end 的 resolved 判断、M6 去掉“末节点为规则”判据、M7 把不可见片段也当可见、M8 去掉 `capture_emit_left` 的 resolved 判断、M9 去掉 `\UL@reskip` 判断。

**M8 需要 `符\CJKunderline{\quad\mbox{x}}后` 才有判别力。** 起初 M8 全绿，原因是两层兜底：resolve 已把 space_flag 置假，CJK-空格场景下“补左边界”只是重放一枚已不存在的空格，是空操作；片段级分支又被 `use_ulem_glue_outer` 的 resolved 判断拦住。这条用例绕开两者：首字符在 `\mbox` 里，ulem 在 `\everyhbox` 中恢复了 `\ ` 的原义，`\xeCJK_if_ulem_patch:TF` 为假，左边界走普通 glue 通道；入口又没有空格，于是 `\quad` 与 `x` 之间是否多出 `\CJKecglue` 只取决于 `emit_left` 的判断。M2、M9 也在这条上失败。变异无判别力时应先找出是哪条兜底路径让被变异的代码成了空操作，不要据此认定该判断冗余。

R1 后的补修逐项变异 14 项，其中 13 项使本文件失败；余下的“片段盒子末节点是 glue 时不改 `tail`”由 `command-boundary-math05` 捕获：去掉这一条后公式加尾随空格重排路径被误判为 `content`，`stream-ulem` 的 correction 变 0、badness 变 1000000。

R2 后的补修变异 4 项，全部被本文件捕获：去掉分组层级规则，TEST 10 四项失败；去掉 FullLeft 分支的 `\@@_ulem_lead_draw:`，`lead-fullleft-latin` 的节点列表改变；去掉 `ulem-nest` marker，四项失败；去掉 `\@@_ulem_body_end:` 删除末尾 marker 的一步，节点列表改变。（分组层级规则已在 R3 删除，由扫描标记代替。）

R3 新增的 19 项在 R2 补修提交 `275c04d9` 上有 15 项失败。R3 的补修逐项变异 5 项，全部被本文件捕获：破坏 peek 的标记比较，3 项失败；去掉“下一个记号不是标记时置 `content`”，4 项失败；原生 FullRight 分支不再因 `\l_@@_ulem_onin_bool` 调用 peek，7 项失败；`\UL@hrest` 不再清除该布尔，1 项失败（`nested-mbox-period-latin`）；去掉 `\@@_ulem_nest_mark:` 在外层的 peek，1 项失败（`nested-then-relax-space-latin`）。

R4 新增的 7 项在 R3 补修提交 `aa78cca7` 上有 6 项失败。R4 的补修逐项变异 3 项，全部被本文件捕获：`\UL@onin` 进入时不看 `\xeCJK_if_ulem_patch:TF`、总把 onin 布尔置真，3 项失败；peek 遇到空格时改为置 `punct`，2 项失败；中间层 `\@@_ulem_nest_mark:` 不 peek，1 项失败。（R5 前这里写成“peek 遇到空格时不置 `content`”，那是意图描述；按字面只删去置 `content` 一步，只有 1 项失败。）

R5 新增的 14 项在 R4 补修提交 `f8f3f731` 上有 5 项失败。R5 的补修逐项变异 4 项，全部被本文件捕获：`\xeCJK_check_FullRight_symbol:Nw` 删去空格时不置 `\g_@@_FullRight_space_bool`，5 项失败；`\@@_ulem_punct_peek:` 不读该布尔，5 项失败；关闭 `CheckFullRight` 时不复位，1 项失败；没有空格时不置假，2 项失败。R4 的“peek 遇到空格时改为置 `punct`”这一变异在 R5 后重做一次，现使 4 项失败，全在 TEST 10（`inner-spaces-cjk`、`trailing-space-cjk`、`nested-period-trailing-latin`、`nested-period-trailing-cjk`），TEST 12 没有一项失败：打开 `CheckFullRight` 时标点后的空格由 `\g_@@_FullRight_space_bool` 处理，不经过这条分支。R5 时曾把 4 项归因于新增的 `CheckFullRight` 用例，这不正确；与 R4 时记录的 2 项相差的原因未确认。记录变异时写实际做的改动，不要写成意图描述。

R6 新增的 5 项在 R5 文档提交 `35bf0adc` 上有 4 项失败：3 项嵌套内层全角标点接西文与 `cfr-active-space`；`cfr-off-active-space` 通过。R6 的补修逐项变异 2 项，全部被本文件捕获：`\xeCJK_check_FullRight_symbol:Nw` 改回 `\peek_charcode_remove:NTF`，1 项失败（`cfr-active-space`）；去掉 `\@@_ulem_onin_report_default:` 的补报，3 项失败（该函数已在 R7 删去，见下一段）。`\@@_ulem_punct_peek_space:` 同样改为按含义比较，但本文件没有能区分两种比较方式的用例，属一致性修改，依赖代码审查。

R7 新增的 15 项宽度用例在 R6 文档提交 `a8a0c05a` 的 `.sty` 上有 13 项失败：R7-B1 的五项、三项 `\mbox` 变体（`nested-mbox-period-latin-cjk`、`nested-cjk-mbox-period-latin-cjk`、`nested-mbox-period-latin-latin`）、`nested-latin-leftquote-cjk-latin`、`nested-mbox-latin-leftquote-cjk`、`nested-content-then-comma-cjk` 与两项 strict；TEST 11 的节点列表在 `a8a0c05a` 上也不同（多出 3.33pt glue）。R7 的补修逐项变异 9 项，全部被本文件捕获：去掉 `\@@_ulem_FullLeft_and_Default:` 的补报，1 项失败；去掉 `\@@_ulem_FullLeft_and_CJK:` 的，2 项；去掉 `\@@_ulem_FullRight_and_Default:` 的，5 项；去掉 `\@@_ulem_FullRight_and_CJK:` 的，6 项；去掉 `\@@_ulem_FullRight_and_CJStarter:` 的，2 项（两项 strict）；`\@@_ulem_report_last:n` 不写 `tail=char`，1 项（`nested-content-then-comma-cjk`：外层先有 `\hspace`，`tail` 为 `content`，内层 `，中` 结束后要恢复为 `char`）；不限于 `stream-ulem` 层、各层都写，1 项（`nested-mbox-paren-latin-then-cjk`）；不检查暂停深度，1 项（`nested-sbox-inside`）；改为调用 `\@@_boundary_capture_class:n`（会设首类别），宽度 1 项失败且 TEST 11 的节点列表不同。去掉五个转换中任何一个的补报都有用例失败，说明每个转换都需要各自的用例，不能只测其中一两个。

R8 新增的 25 项宽度用例在 R7 文档提交 `b59d2525` 上有 21 项失败。在 `ef49ca4e` 与 v3.10.6 上只有 `inner-latin-fill`、`three-level-last-cjk`、`three-level-last-latin`、`inner-last-color`、`inner-last-mbox` 五项失败，已由现有 CHANGELOG 条目覆盖。（R9-M3 更正：R8 时写成“五项都是 ulem 结束符 `*` 被当成西文导致的”，不准确。四项来自 `*`；`inner-latin-fill`（`中\uline{\sout{x\hspace*{1em}}}中`）失败的原因是“最后一个字符之后还有内容时右侧仍补边界间距”，属于 CHANGELOG 里“最后一个字符之后还有空白、盒子、规则等内容”那一条。R8 时还写“其余在 v3.10.6 就正确，所以 R8 没有新增 CHANGELOG 条目”，这句没有逐项比对（R9-M5）：R8 也改变了“内层以西文加末尾空格结尾”的发布版行为，`中\uline{\sout{x }}中` 在 `b59d2525` 与 v3.10.6 上为 35.27pt，R8 后为 31.94pt，等于直接输入；`符 \uline{\sout{中（}}x` 的结果也被 R8 改变。这两项当时都没有测试固定，R9 由 TEST 15 的 `nested-latin-space-cjk` 与 `nested-left-latin` 固定。）R8 的补修逐项变异 6 项，全部被本文件捕获：不调用 `\@@_ulem_onin_tail_check:`，21 项失败；末节点是 glue 时不置 `content`，15 项；`tail` 为 `punct` 时也检查，3 项（`nested-period-space-latin`、`cfr-nested-period-space-latin`、`cfr-nested-space-then-no-space`）；中间层不补 `ulem-nest` marker，2 项（`three-level-last-cjk`、`three-level-last-latin`）；检查后不删 marker，宽度用例全部通过，但 TEST 11 的 `three-level-no-marker` 节点列表多出 marker kern；不检查 onin 布尔，1 项（`mbox-nested-period-latin`）。

R9 新增的用例（TEST 15 的 45 项与 TEST 11 的 `three-level-keep-char-marker`）在 R8 文档提交 `cf9a1744` 上有 32 项宽度失败，新节点用例的输出也不同；在 `b59d2525` 上有 35 项失败；在 v3.10.6 上 TEST 15 有 27 项失败，所以 R9 新增了一条 CHANGELOG 条目（全角左标点结尾与嵌套命令的连接）。R9 的补修逐项变异 14 项，记录为除一项外均被本文件捕获：ulem 分支不 peek（仍 `\ignorespaces`），9 项；嵌套链上的非 ulem 分支不 peek，10 项；下一个记号不是扫描标记时不置 `left`，3 项；遇到空格时不置 `left`，1 项；`\UL@reskip` 画零宽 glue 时不改 `content`，1 项；结束时不处理 `left`，3 项；结束时不重放标点节点，3 项；内层末尾的 glue 一律置 `content`（即 R8 的做法），2 项；不看 penalty 之前的节点，1 项（`nested-left-nobreak-hspace0`）；嵌套 marker 一律用 `ulem-nest`，11 项；只重放 CJK、不重放 default 的外层末尾 marker，4 项；不复位 `\g_@@_FullRight_space_bool`，1 项（`cfr-nested-right-left-space-latin`）。删除时固定按 `ulem-nest` 查找，宽度全部通过，由 `three-level-no-marker` 的节点列表捕获；删除后不检查末节点是否为盒子，宽度全部通过，由 `three-level-keep-char-marker` 的节点列表捕获。

R10 新增的 13 项在 R9 补修提交 `5b271e96`（`43fe6df9` 的代码与它相同）的 `.sty` 上有 12 项失败，只有 `nested-left-tie` 通过；新 lvt 在 R9 之前的 `cf9a1744` 上共 36 项失败（R9 与 R10 新增用例中的回退项）。R10 的补修逐项变异在 R9 的 14 项之外新增以下 6 项（共 20 项），全部被本文件捕获：不检查内层开头的空格（总是重放），5 项失败；不识别分组里的开头空格，1 项；不识别控制空格 `\ `，1 项（这三项针对的 `\@@_ulem_onin_if_lead_space:n` 已在 R11 删去）；重排分支不重放，2 项；不插 `ulem-left` marker，2 项；glue 前任意节点都认作标点自己的节点（`\@@_ulem_onin_tail_glue:` 不看 penalty 之前），7 项。R9 的 14 项重新执行后仍全部被捕获，其中删除时固定按 `ulem-nest` 查找与删除后不检查盒子两项仍由节点列表捕获。另跑约 500 项的合并矩阵：相对 `43fe6df9`、`cf9a1744`、`b59d2525` 没有回退。R10 时这里还写“相对 v3.10.6 仍有三项差异”，这只是那个矩阵上的结果，却写成了全称结论（R11-I3）：R11 盲审用 4104 项矩阵在 `bb321f36` 上找到 135 项与直接输入不一致、而 v3.10.6 一致的写法，详见 [[../memory/doc-gaps]]。

R11 新增的 21 项在 R10 补修提交 `a4e94c5d` 上有 16 项失败。R11 的补修逐项变异 23 项（R11 提交说明误写为 22 项）（`tmp/i1091/fix2/mutate14.py`），全部使本文件失败，其中 `nest-remove-fixed`、`nest-no-box-check` 两项宽度全过，由节点列表捕获。变异中曾有一项“入口层末节点是重放的 marker 时不改 `entry`”的例外，在所有用例里都观察不到；插桩确认这个分支从不触发后，从代码里删去，没有为它补测试。合并矩阵 `tmp/i1091/fix2/r9big.tex` 现为 647 项：相对 `a4e94c5d`（r10fix）有 33 项由不一致变为一致，没有回退；相对 r9base（R9 前的代码，同 `cf9a1744`）与 r8base（R8 前的代码，同 `b59d2525`）也没有回退。在这个矩阵里，当前代码与直接输入不一致、而 v3.10.6 一致的有 4 项：`符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后`、`符 x\mbox{\uline{\sout{中}}} 后`、`x\uline{\sout{\rule{1pt}{1pt}中}}x`。这一结论只对 r9big 矩阵成立；4104 项矩阵上找到的差异主要是内层开头空格与左边界的问题，已由 `b16e41d5` 处理，但没有在那个矩阵上逐项复核。R11 后重跑 xeCJK `l3build check`、`l3build doc` 与 ctex `l3build check -e xetex`，均通过。

R12 的补修（`14e3415f`）逐项变异 35 项（`tmp/i1091/fix2/mutate14.py`；与 R11 时保存的 `mutate14-r11.py` 相比新增 12 项，针对 transparent 两个钩子、`ulem-transparent` marker 与 `\g_@@_ulem_onin_transparent_bool`、`xCJKecglue` 的保存、重排分支的 onin 布尔量、`CJK-space` 重放以及钩子的 vlist、规则、penalty 分支），全部使本文件失败，其中 `nest-remove-fixed`、`nest-no-box-check`、`transparent-mark-keep`（不删 `ulem-transparent` marker）三项宽度全过，由节点列表捕获。原型阶段 transparent begin 钩子有一处“末节点是重放的 lead marker 时不检查”的例外，变异后没有任何用例失败；插桩确认不可达后删去。探测矩阵都在 `tmp/i1091/fix2/`：r9big 646 项（按不重复的标签计；输出 647 行，`r10-i1c` 出现两次，R11 时记为 647 项）、r12box2 56 项、r12m 202 项、r12u 180 项、r12t 260 项、r12v 84 项、r12oos 7 项，相对 `94bd84d5` 没有回退（r12m 的 `i2-sp` 是 oracle 受前一用例状态影响，见上文 R12 一条）。在 r9big、r12box2、r12oos 上，当前代码与直接输入不一致、而 v3.10.6 一致的写法分别有 4、12、4 项，清单见 `llmdoc/memory/doc-gaps.md`；这一结论只对这三个矩阵成立。xeCJK `l3build check`、`l3build doc` 与 ctex `l3build check -e xetex` 均通过。

R13 的补修（`6a52751a`）逐项变异 40 项（`tmp/i1091/fix2/mutate14.py`；比 R12 多 5 项：`transparent-flag-lead-reset`、`transparent-flag-onin-only` 分别把清零放回 `\@@_ulem_onin_lead_put:`、只在嵌套链上设置布尔量，`tbegin-keep-prev-marker`、`leadget-keep-marker`、`tailcheck-keep-marker` 分别去掉 begin 钩子、`\@@_ulem_onin_lead_get:n`、`\@@_ulem_onin_tail_check:` 三处删除 marker；原有的 `transparent-flag-not-reset` 改为去掉 `\@@_ulem_entry_arm:` 里的清零），全部使本文件失败。其中 `nest-remove-fixed`、`nest-no-box-check`、`transparent-mark-keep`、`tbegin-keep-prev-marker`、`leadget-keep-marker`、`tailcheck-keep-marker` 六项宽度全过，由节点列表捕获：`ulem-transparent` marker 宽度为零，留在盒子里不改变任何宽度，只能由 TEST 11 的节点用例发现。探测矩阵（`tmp/i1091/fix2/`）r9big、r12box2、r12m、r12u、r12t、r12v、r12oos 与新增的 r13m（80 项）、r13rest（7 项）相对 `101a5adc` 没有回退，r13m 有 7 项由不一致变为一致。在 r13m 与 r13rest 上当前代码与直接输入不一致、而 v3.10.6 一致的写法，清单见 `llmdoc/memory/doc-gaps.md`，这一结论同样只对这些矩阵成立。xeCJK `l3build check`、`l3build doc` 与 ctex `l3build check -e xetex` 均通过。

**测试要实际经过被声称保护的路径。** R1 的 TEST 11（现为 TEST 12）用 `\raisebox`，文档与测试注释据此写“检查末尾盒子时取下再放回，`\raise` 位移不丢”；但 `\raisebox` 会新建盒子，末尾盒子检查根本没有取下它，R2 盲审用“删掉放回步骤”的变异证明这条用例保护不了该性质，而 `\raise2pt\copy\FillBox` 确实会被 `\lastbox` 清零位移。现在的 `nested-raise-copy` 不新建盒子，在 marker 方案下经过末节点检查。声称某条用例保护某个性质时，要用只破坏该性质的变异确认它会失败。

**oracle 里的源码空格要确认真的存在。** `\usebox\FillBox }`、`\kern5pt }` 中的空格会被控制词或尺寸读取吃掉，直接输入那一侧根本没有这枚空格，比对就失去意义。要写成 `\usebox{\FillBox} }`、`\kern5pt\relax{} }`；空格位于内容末尾时还要给 oracle 加花括号（`符 {中\usebox{\FillBox} } 后`），与装饰正文的分组对应。

第一轮写过的 `\CJKunderline{中。} x` 对 `中。 x` 一项当时因“修复前后相同、属既有差异”删去；R1 的全角右标点处理已把它修好，现由 TEST 10 的 `period-space-latin` 覆盖。R2 曾把正文以嵌套线型命令结尾、内层以全角右标点结尾（R2-M2）记为“修复前后相同”，实际无空格的 `\CJKunderline{\CJKsout{中。}}x` 是 `2fb2a93b` 引入的回退，R3 已修好，由 TEST 10 的 `nested-period-latin` 等覆盖。仍未覆盖、修复前后相同的四项是正文以 `\textit{x}` 结尾时差 0.54pt（斜体校正）；`\CJKunderline{中 }` 这类“字符后接正文末尾空格”与带花括号的直接输入差 3.33pt（最终审查 M1 更正：此前这里还列了 `\CJKunderline{\CJKsout{中} }`，它自 `2fb2a93b` 起才不一致，是回退，最终审查后已修好，由 TEST 19 的 `trailing-nested-then-space-*` 覆盖）；符号型命令以全角右标点结尾（`\CJKunderdot{中。} x`、`\CJKunderline{\CJKunderdot{中。}} x`）；公式加尾随空格（`\CJKunderline{中$x$ } y`）与带花括号的直接输入差 3.33pt。R7 后另记一类既有缺口：嵌套内层正文以全角标点开头时首类别为空（`他说\CJKunderline{\CJKsout{“OK”}}吗` 等），宽度与直接输入不一致，本文件只用 TEST 11 的节点列表固定内层盒子里不多出 glue，不比较宽度；详见 [[../memory/doc-gaps]]。R8 盲审与复核又记下一批所有版本都与直接输入不一致、本文件不比较的写法（嵌套版本的末尾空格与 `\relax`、只有 `\hspace*` 的嵌套正文、`\mbox` 里的线型命令左边界等；当时同列的 `\uline{\sout{\xout{中}x}}` 已在 R9 修好，由 TEST 15 的 `three-level-cjk-then-latin` 固定），同样列在 doc-gaps。R9 后仍未覆盖、本文件不比较的有：分组里的全角左标点 `符 \uline{{中（}} 后`（R10 另记 `\textbf{中（}` 版，并把 CHANGELOG 改为不包括这种情形）、中间层里嵌套命令与汉字之间的空格 `符 \uline{\sout{\xout{中} 中}} 后`、三层并列的连接（如 `符 \uline{\sout{\xout{x}}\sout{中}} 后`）、公式后接嵌套命令 `符 \uline{$x$\sout{中}} 后`，以及盒子外的西文与盒子里的线型命令 `符 x\mbox{\uline{\sout{中}}} 后`；R10 后又记下 `符 \CJKunderline{\CJKsout{中$a$ }} 后`（公式加尾随空格后接空格，属既有“公式加尾随空格”一类）、两层的 `\uline{\sout{中} 中}` 等写法、单层的 `\uline{中{ 中}}` 与 `CJKspace=true` 下的 `符 \uline{（}x`；R11 后又记下嵌套内层以未注册的盒子开头（原始 `\hbox`、`\rule`、`\phantom`、`\raisebox`）时多补一枚左边界间距，详见 doc-gaps。本文件使 xeCJK 标准测试增至 124 项；R1–R10 后仍为 124／124 通过（R10 后重跑），ctex `l3build check -e xetex` R10 后重跑，186／186 通过；`l3build doc` 成功；R11 没有新增测试文件，重跑结果见上文 R11 一段。

### xeCJKfntef 的 PDF 文本语义（#1017）

`fntef-actualtext01.lvt` 覆盖下划线、双下划线、波浪线、删除线、交叉删除线、自定义线条、着重号和自定义符号八类入口，检查每个装饰盒子都使用空 `ActualText`，并在 tagged PDF 下成对暂停、恢复 tagging。这个回归固定的是实现机制；它不能单独证明实际阅读器或提取工具得到的文本正确。

涉及字符型装饰时，应把 PDF 文本语义与页面视觉分开验收：普通 PDF 和启用 `\DocumentMetadata{tagging=on}` 的 tagged PDF 都要实际运行文本提取，确认只保留正文；再对修复前后页面做同条件的高分辨率栅格或坐标比对，确认装饰位置和形状没有改变。#1017 的独立验证中，两种 PDF 的 `pdftotext -layout`／`-raw` 都排除了 `:`、`/`、`.`、`*` 等装饰字符，300 dpi 栅格的 `magick compare -metric AE` 为 `0 (0)`。文本提取通过不能证明页面视觉不变，像素相同也不能证明复制、搜索结果正确。

#1012 的同一最小样例覆盖默认波浪、默认斜删除线、自定义 `underwave/symbol` 和 `\CJKunderanysymbol`。普通 PDF 与启用 tagging 的 PDF 在 `pdftotext -raw` 和 `-layout` 下都只得到正文，没有装饰字符，说明周期几何修改没有使 #1017 的文本语义退化。

这类测试还会扩大精简 CI 的依赖面。#1017 为 `xeCJKfntef` 增加运行时依赖 `accsupp`，tagged PDF 回归另需要 `latex-lab`、`pdfmanagement` 和 `tagpdf`；四项都必须同步写入 `.github/tl_packages`。凡新增 `\RequirePackage` 或启用 `\DocumentMetadata` 的测试，都应同时反查包级依赖声明和 CI 白名单，不能用本地完整 TeX Live 的通过结果代替这项检查。

## CI/CD 配置

GitHub Actions 工作流当前包含以下主线：

- `.github/workflows/test.yml`：跨平台测试工作流
- `.github/workflows/check-doc.yml`：PR 校验 workflow, 跑 `l3build doc` 抓文档 dtx→PDF 可编译性 (#935); 与 test.yml 分工 (后者只跑 `l3build check`, 不 typeset dtx), 覆盖 9 个包 (zhspacing 因深层依赖问题暂不覆盖, 见下), 单 engine 单 OS. TL bypass cache key 与 test.yml 完全共享; 详见 [[935-check-doc-vs-ctan]]
- `.github/workflows/check-tag.yml`：PR 校验 workflow, 对支持 l3build tag 的包 (zhlineskip / ctex / xeCJK / xpinyin / zhnumber / xCJK2uni) 跑 `l3build tag` + `git diff --exit-code`, 另有 `gate-coverage` job 跑 `scripts/check-version-gate-coverage.py` 对账白名单, 验证源文件版本与 build.lua 的 version 同步 (#937, xeCJK 自 #1041, xpinyin 随 #1041 测试接入同批补上); 与 release.yml 的三方版本校验构成两道校验, 详见 [[937-version-single-source-l3build-tag]]、[[1041-xecjk-version-gate]] 与下方"版本管理"章节的覆盖矩阵
- `.github/workflows/check-changelog.yml`：PR 校验 workflow, 校验 6 个包 (ctex/xeCJK/xpinyin/zhlineskip/zhmetrics/zhnumber) 的 `CHANGELOG.md` 与 `.dtx` 的 `\changes` 条目是否同步 (#961, xpinyin 随 #1041 测试接入同批补写首条 `\changes` 后加入); 与 `check-tag.yml` 同一「生成物新鲜度校验」模式, 详见下方"生成物新鲜度校验模式"小节与 [[961-changelog-gate-no-write-perm]]
- `.github/workflows/lint-test-files.yml`：`.lvt` 测试文件 lint，PR 触发（`paths` 限定 `**/*.lvt` 及检查脚本本身），检查新增行在 `\ExplSyntaxOff` 段的 `\TEST`/`\BEGINTEST`/`\TYPE` 大括号内是否误用 `~`（#893）；与 `.githooks/pre-commit` 共用 `.githooks/check-test-tilde.sh`，约定细节见 `llmdoc/reference/coding-conventions.md`
- `.github/workflows/release.yml`：按发布 tag 构建并创建 GitHub prerelease 的自动化工作流（stage 1）
- `.github/workflows/release-ctan-upload.yml`：CTAN 正式投递工作流（stage 2），仅 `workflow_dispatch`，按包由 `ctan-release-<module>` environment 控制是否执行，详见 `llmdoc/guides/release-workflow.md`
- `.github/workflows/agentic-pr-review.yml`：本地 PR 自动审查实现，由 `pull_request_target` 触发；Draft PR 不会被跳过，打开、推送新提交或重新打开时与普通 PR 一样进入审查；Claude Code `claude-opus-5-5` 是主链路，Codex `gpt-6.1-sol` 是在独立 runner 上运行的后备链路（2026-10 起，此前两者相反），不运行 Agent 的发布 job（publisher）代发评论
- `.github/workflows/agentic-issue-dispatch.yml`：本地新 Issue 分派实现，只监听 `issues.opened`，按内容选择 bug 分析、需求评审或问题回答；它不再承担周期 CI 和积压 Issue 巡检。**注意 test.yml 的 `file-issue-on-schedule-failure` 用默认 `GITHUB_TOKEN` 开的 Issue 不会触发本工作流**——GitHub 刻意不为 `GITHUB_TOKEN` 产生的事件再启动 workflow（防递归），所以定时失败开出的 Issue 只作提醒、不会自动进入分析；要接入需给本工作流加 `workflow_dispatch`／`repository_dispatch` 入口并用能产生事件的身份触发，但那会推翻契约测试刻意设立的「issue dispatch 无主动触发入口」约束（见 `scripts/test-agentic-workflow-contract.py` 中 `assert "workflow_dispatch:" not in issue`，与 `schedule` 成对），属独立议题
- `.github/workflows/agentic-llmdoc-updater.yml`：本地 llmdoc 更新实现，每天北京时间 05:00 或手动触发，Agent 只生成候选，独立的校验 job（validator）和 publisher 验证并创建／更新 PR
- `.github/workflows/check-agentic-workflows.yml`：PR 校验，离线检查三个 Agent workflow 的触发、job 拓扑、固定事件提交、权限、结果契约、本地 Action 和运行时脚本；它还明确对 pre-push hook、Agent shell 脚本和 PR history 脚本运行 ShellCheck

#### agentic 工作流的本地运行时与触发约束

三条 workflow、`.github/actions/`、`.github/scripts/agentic/` 和 `.claude/skills/` 都由本仓库维护，运行时不检出或调用远端模板。最初展开自 `Lightspeed-Intelligence/agentic-workflow-template` 的提交 `2a0bb28e6583d869645e0a0522568df4a5d4d921`；这个 SHA 是来源基线，不是调用点。吸收上游变化时，应比较最近一次吸收的上游提交（记录在 `.github/agentic-runtime.md`）和新提交，选择性搬运，再按本仓库的权限、事件提交和缓存规则审查，不能整体覆盖。

Issue 分派和 llmdoc 更新在 job 级使用 `if: ${{ github.repository == 'CTeX-org/ctex-kit' }}` 限制主仓库执行（#875 / PR #876）。这是 job 级 `if`，能在分配 runner 前挡住 fork 上的定时、手动或 Issue 事件。llmdoc 仍保持每天一次；原 `agentic-patrol.yml` 已由 `issues.opened` 驱动的分派取代，因此不再有巡检频率。历史原因见 [[874-876-agentic-fork-shielding-cron]]，本轮取舍见 [[agentic-template-reuse]]。

**Agent 执行权限（#1032 简化后的做法）**：三条 workflow 共六个实际运行 Agent 的 job（每条各一条 Claude 和 Codex 链路），全部以 runner 默认用户运行，拥有完整本地执行权限——审查排版 PR 需要 Agent 自己跑 `l3build`、编译 MWE、把 PDF 转成图片比对。Codex 用 `--dangerously-bypass-approvals-and-sandbox`，Claude 用 `--dangerously-skip-permissions`，与上游模板 `agentic-workflow-template` 一致。约束 Agent 影响面的是权限边界而非进程沙箱：Agent job 只持有只读 `GITHUB_TOKEN`，checkout 后立即移除 Git 凭据；外部写入集中在不运行 Agent、也不接收模型 API key 的 publisher job；PR Review 的可信运行时来自 `pull_request_target` 的 base SHA，被审查的 head checkout 只作为数据；Claude 保留 `--bare` 禁用 `CLAUDE.md` 自动发现，避免被审查仓库向 Agent 注入项目指令。详见 `.github/agentic-runtime.md`。

已接受的风险：这套边界不阻止仓库代码读取 Agent 进程环境中的模型 API key。判断依据是当前贡献者都是仓库协作者，近 40 个 PR 中跨仓库 PR 为 0。注意 `pull_request_target` 与 `pull_request` 不同，它对 fork PR 同样提供 secrets；当前的保护来自可信运行时固定在 base SHA，而不是来自 fork 拿不到 secrets。由于 Agent 拥有完整本地执行权限，它一旦按审查需要运行 head checkout 中的测试或构建脚本，那些脚本就能读到密钥。因此若将来接受 fork PR 的自动审查，必须重新引入凭据隔离（例如此前的专用用户加 root 模型代理方案），或改用不携带 secrets 的触发方式。判断依据与被否决方案见决策 [[1032-agent-runtime-simplification]]。

**工具安装**：不再使用复合 Action，改为单个脚本 `.github/scripts/agentic/setup-agent-tools.sh`，由六个 Agent job 各自以普通 step 调用（`bash <prefix>/.github/scripts/agentic/setup-agent-tools.sh`，`<prefix>` 依 workflow 分别是 PR Review 的 `.trusted-base`、Issue Dispatch 的 `consumer`、llmdoc Updater 的 `runtime`）。脚本安装或恢复 TeX Live 2026、Noto CJK、HanaMinB、Noto Sans Symbols 2、Poppler、ImageMagick、Ghostscript 和 ShellCheck；`actionlint` 由脚本用 `go install` 单独固定版本安装；`zhmakeindex` 从 `Liam0205/zhmakeindex` 的最新 release 取 Linux 二进制，安装方式与 `_check-doc-package.yml`、`release.yml` 一致，但改用匿名 REST API 查版本号，因为 Agent job 的脚本不持有 `GH_TOKEN`。ctex 手册的索引依赖 `zhmakeindex`，缺它时 `l3build doc` 会在生成 PDF 之后才失败，Agent 只能把它记成环境限制而无法完整验证文档编译。脚本自身校验：TeX Live 缺失时 fail closed（`::error::TeX Live 不可用`）、CJK 字体缓存必须同时含 Noto Sans CJK 和 Noto Serif CJK、xeCJK 文档字体缓存必须含 HanaMinB 和 Noto Sans Symbols 2，最后逐个 `command -v` 检查全部工具并打印版本。

**主链路→fallback 的状态契约（2026-08 建立，2026-10 主备对调）**：三条 Agent workflow 的主链路自 2026-10 起是 Claude Code（`claude_review`／`claude_analyze`／`claude_candidate` 加 `validate_claude`），fallback 是 Codex（`codex_*` 加 `validate_codex`）；job ID 与 artifact 名跟随 provider，主备关系由 job 顺序与 `needs` 决定。主链路的 CLI 及后续规范化／导入／打包步骤标为 `continue-on-error: true`，由 `if: always()` 的汇总 step 检查各步骤的 `outcome`，将 `status=success|failure` 写入 job output；失败只发 `::warning::` 和 step summary，随后由 Codex fallback 接手。下游必须读取 `needs.<主链路 job>.outputs.status`，不能读取带 `continue-on-error` 后恒为 `success` 的 `needs.<主链路 job>.result`。llmdoc Updater 的候选生成与独立 `validate_claude` job 各自有 status，fallback 和 publisher 要同时判断两个 status；只有两条链路都没有通过结果时，最终 job 才以非零状态结束。契约测试会检查状态 output、关键步骤标记、汇总来源和所有 `.result` 残留，并用反例验证这些检查的判别力。状态契约最初为 Codex 主链路建立，见 [[../memory/reflections/2026-08-13-agentic-codex-fallback-status]]；对调只换了 provider，契约本身不变。

模型与 CLI 版本（2026-10 吸收上游 `4f9cc66`）：Claude Code 2.1.282 + `claude-opus-5-5`，Codex 0.159.3 + `gpt-6.1-sol`。模型 ID 同时出现在 workflow 的 run-agent 输入、规范化／打包脚本参数、publisher 的 jq 校验和 `publish-change.sh`／`validate-change-artifact.sh` 的白名单里；契约测试 `test_model_ids_are_consistent` 从 workflow 推出唯一的 Codex／Claude 模型，要求其他所有位置与之相等，换模型时漏改一处会直接失败。run-agent 的 Claude 分支在 CLI 失败（退出码非零或 `is_error=true`）时把退出码、`api_error_status`、`subtype` 和截断后的 `result` 压成一行 `::error::` 打印，因为 CLI 的失败原因只在 stdout JSON 里、stderr 为空；`%`、CR、LF 先转义，防止 Issue/PR 派生文本另起一行伪造 workflow 命令，`test_claude_failure_diagnostics` 用假 `node` 覆盖网关 400、注入、非 JSON、空输出、退出码 0 的软失败和成功路径。

`.github/actions/run-agent` 的 Codex 默认 endpoint 是 `https://api.openai.com`，可由 `OPENAI_BASE_URL` 覆盖；生成的 `config.toml` 同时设置 `service_tier = "priority"` 和 `model_reasoning_effort = "high"`。这三项是运行时默认参数，不改变 publisher 的权限边界。上游模板在换到 `gpt-6.1-sol` 时把推理强度显式锁为 `medium`（该模型在 Codex 0.159.3 中默认是 `low`），本仓库保留自己的 `high`，同样是显式写入，不受模型默认值变化影响。

为什么不用复合 Action：复合 Action 的 step 字段合法范围严格小于 job step（`timeout-minutes` 只在 job step 合法），`run` 默认 shell 还带 `pipefail`，管道右侧提前 `exit` 的命令会让整个 step 以非零退出终止——这正是 #1030/#1031 两次连环故障的成因，且没有一次出自审查逻辑本身。普通 job step 调脚本没有这一类字段和默认值差异问题。这条规则本身仍然有效，只是不再约束工具安装：仓库里的 `.github/actions/run-agent`（Codex/Claude CLI 调用）和 `.github/actions/feishu-notify`（通知）仍是复合 Action，`scripts/validate-action-metadata.py` 与契约测试仍要求它们的 composite step 字段表以 GitHub 实际支持范围为准，`run` 里的管道也仍不能在右侧用提前 `exit` 的 `awk`。详见 [[1030-1031-composite-action-semantics]]。

**缓存**：仍留在 workflow 里，因为 cache action 无法在脚本内调用。每个 Agent job 有 TeX Live、CJK 字体、xeCJK 文档字体三类缓存共六个 `actions/cache/restore@v6` 步骤，全部只恢复不保存；未命中时由 `TeX-Live/setup-texlive-action@v4`（TL）或安装脚本自身（字体）直接下载。TL 缓存 key 与 `test.yml` 的 `warmup-tl` 一致（`tl-bypass-<os>-2026-<ISO week>-<tl_packages hash>`），两组字体缓存 key 也复用既有 CI 命名，因此大多数情况下能直接命中已经填好的共享缓存；实际写入共享缓存的仍是可信 CI 的既有流程，Agent job 本身不再触发缓存保存。

**保留的边界（不受本轮简化影响）**：

- `pull_request_target` 的可信 checkout 固定在 PR base SHA（分叉点，见下），被审查的 head 只是数据。
- 结构化 `review_status` 校验（`COMPLETE` / `INCOMPLETE`）：本轮已证明其价值——Agent 环境损坏时返回 `INCOMPLETE` 会被校验拒收，不会变成假绿。
- publisher 权限隔离：三条 workflow 都把 Agent 与外部写入分开。PR Agent 只读，publisher 独占 `pull-requests: write`；Issue Agent 固定事件 `github.sha` 且只读，dispatch job 独占 `issues: write`；llmdoc prepare 固定 master SHA，Agent 只打包 `llmdoc/` 候选，独立 validator 从同一 SHA 验证，publisher 才取得 `contents: write` 和 `pull-requests: write`。
- Claude 的 `--bare`：禁用 `CLAUDE.md` 自动发现，避免被审查仓库注入 Agent 指令。
- llmdoc Updater 的 `package-base` 重新检出：仍重新把固定 master 提交检出到 `package-base`，只复制 `consumer/llmdoc/` 文件树，比较和补丁生成都在这个新仓库中完成，不读取 Agent 控制的 `.git`。这一层解决的是“Agent 可能通过 `assume-unchanged`、本地提交或 `.git/config`（如 `core.fsmonitor`）让工作区 Git 状态失真”的问题，与本轮删除的三层隔离无关，未改动。

llmdoc prepare 生成的 `task.json` 包含 `since_period`，`recent-commits.txt` 包含精确候选提交；两个候选 prompt 在生成时展开这两个文件的实际绝对路径，并要求 Agent 先读取，不依赖裸文件名。

PR Review publisher 用认证 marker 中的 head SHA 区分评论：同一 head 重跑时更新原评论，不同 head 则新建评论，既避免同一提交的重复评论，也保留不同提交的审查记录。pre-push 必须用 `gh api --paginate --slurp` 读取并展平全部 Issue 评论页；检查维护者是否确认 Bot 评论时，以评论的 `updated_at` 为时间边界，缺失时才回退 `created_at`。只有 OWNER、MEMBER 或 COLLABORATOR 在 Bot 最后更新之后的回复，才算确认当前正文。这样，后续页的审查评论不会被漏掉，维护者在旧正文后的回复也不会掩盖同一 head 重跑产生的新 finding。

`scripts/test-agentic-workflow-contract.py` 固定触发、权限、六处工具安装脚本调用、restore-only 缓存、事件提交、publisher 隔离和结构化结果语义；它还用预期失败的错误样例验证零 finding 的 `COMMENT`、损坏的 `runs.using`、拼错的 composite step 字段、注入 `timeout-minutes` 的复合 Action step、字体 staging 中预置或不完整的内容、同／异 head 评论发布、第二页 Bot 评论、维护者回复早于 Bot `updated_at`。PR Review 的契约现在只固定两件事：提示词指向 base 固定的规范路径（`$GITHUB_WORKSPACE/.trusted-base/.claude/skills/{pr-review,github-comment}/SKILL.md`），以及 Claude 保留 `--bare`；恢复为读取工作树规范或让 Claude 丢掉 `--bare` 的反例都必须失败。llmdoc 通知也必须区分公开结果中的 `blocked` 与 job 执行成功。PR Review 的可信 sparse checkout 还要覆盖 `run-agent` Action 的全部仓库内运行时依赖；契约测试从实际的 `.trusted-base/...` 引用反推依赖闭环（允许 sparse-checkout 的目录前缀覆盖具体文件），并用删除依赖路径的反例确认校验会失败。新增或移动本地 Action 的运行时文件时，必须同时更新所有固定提交 checkout，不能只修改 Action 本身。契约 workflow 的 `pull_request.paths` 必须覆盖契约测试读取或执行的全部仓库文件；独立 shell 文件还要由明确的 ShellCheck 命令检查，不能把 actionlint 对 workflow 内嵌 `run:` 的检查当作替代。修改本地 Agent runtime 后运行契约测试、`scripts/validate-action-metadata.py`、actionlint 和 ShellCheck。设计与教训见 [[1025-agentic-local-runtime-toolchain]]、[[1030-1031-composite-action-semantics]]、[[1032-agent-runtime-simplification]]。

`agentic-pr-review.yml` 由 `pull_request_target` 触发，其工作流定义本身取自 base 分支（`master`）当前状态；但用于可信 checkout 的 `github.event.pull_request.base.sha` 是该 PR 的分叉点（merge base），不是 base 分支当前 HEAD。因此 Agent runtime（本节描述的三条 workflow 与 `.github/scripts/agentic/`）发生改动后，所有分叉点早于该改动的存量 PR 都会持续加载旧运行时，其 Agent job 会在可信 checkout 或工具安装阶段反复失败，直到该分支 rebase 到 `master` 或合并 `master` 为止；close/reopen PR 与单独重跑都不会改变分叉点，因此都不能恢复。这是刻意的安全设计：保证可信运行时的版本与被审查的 diff 有一致基线，代价是运行时改动不会对已存在、分叉点落后的 PR 自动生效。诊断步骤见 `llmdoc/guides/push-and-pr-review-workflow.md`。设计与教训见 [[1030-1031-composite-action-semantics]]。

### 测试工作流：`.github/workflows/test.yml`

当前稳定事实如下：

- 触发条件：`pull_request`、`push`、定时 `schedule`、`workflow_dispatch`
- 操作系统矩阵：`ubuntu-latest`、`macos-latest`、`windows-latest`
- TeX Live 安装：`TeX-Live/setup-texlive-action@v4`
- 依赖包清单：`.github/tl_packages`
- 当前 CI 拆为 6 个独立 caller job（`test-ctex` / `test-xeCJK` / `test-xpinyin` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip`；`test-ctex-luatex` 是 ctex 的 luatex 专属子 job，另计），各自 `uses: ./.github/workflows/_test-package.yml` 在 3 个 OS 上并行测试；`changes` 阶段用 paths-filter 决定 PR 上跑哪些 caller。`test-xpinyin` 额外传两个输入：`configs: test/config-cjk`（串行加跑 CJKutf8/pdfTeX 那条线）与 `needs-unihan: true`（unpack 阶段要生成拼音数据库）；`test-zhnumber` 也传 `configs: test/config-cjk`（#1008 起，实际排出汉字再量盒子的那条线只跑 xetex），但不需要 `needs-unihan`
- 主仓自家分支的 PR 会同时触发 push 与 pull_request 两次 `test.yml` 运行。pull_request 那次按设计跳过全部包测试（见 `.github/workflows/test.yml:59-86` 的注释），在 PR 页面上显示为成功。判断测试是否通过要看 push 那次运行：用 `gh run list --branch <分支> --workflow test.yml` 查看 event 列。

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

这条约束不仅适用于宏包依赖，测试用到的字体同样要同步这份白名单。#1041 的 xpinyin 测试用 `DejaVuSerif.ttf`（避开 Latin Modern 缺 U+01D6 的问题）和 `FreeSerif.otf`（`pinyin-setup01.lvt` 的 `font` 键对照字体），因此 `.github/tl_packages` 补了 `dejavu` 与 `gnu-freefont`——这两个 TeX Live 包分别提供上述字体文件，新增测试字体前应先核对是哪个包提供。

核对的结论也包括「不需要新增」这一种，同样要留下痕迹。#997 的 `pinyin-fallback01.lvt` 用 `lmroman10-regular.otf`（主字体，故意选没有 CJK 字形的）与 `FandolSong-Regular.otf`（后备字体），逐个核对后确认它们由 `lm` 与 `fandol` 提供，两者已在 `.github/tl_packages`（分别是第 39、24 行），因此这次没有改这个文件——顺带也没有触发下文那条「改动该文件等价于强制 CI 缓存失效」的路径。

核对要**逐个走一遍**，不能只补自己意识到的那几个。同一批改动里，pdfTeX 那条线新引入的 `CJKutf8`、`lmodern` 和 `gbsn` 字体族当时并未逐个核对归属，事后查明恰好已被既有的 `cjk`（提供 `CJKutf8.sty` 与 `c70gbsn.fd`）、`lm`、`arphic` 覆盖——也就是说那次没出问题是运气，而不是流程起了作用。核对方式是对每个新引入的 `\usepackage`、字体文件名和字体族分别跑 `tlmgr search --file --global`，再用 `grep -qx` 确认包名确实在白名单里；漏掉的后果是本地完整 TeX Live 通过而 CI 在精简环境里缺包失败（`.log` 为空、`.tlg` 比对失败，根因不在输出差异）。

**改动 `.github/tl_packages` 本身等价于一次强制 CI 缓存失效。** TL bypass cache key 含 `hashFiles('.github/tl_packages')`（见下方 `warmup-tl` job 一节）；只要这个文件的内容变了，key 就变了。#1050 给 `dejavu`／`gnu-freefont` 加了三行触发的正是这条路径：该 PR 侧的 cache miss、直接全新安装，拿到的是当前上游最新版本；而未改这个文件的 `master` 继续命中改动前写入的旧快照，两侧使用的其实是两个不同时间点的上游环境。

后果：**同一个 commit 在 master 上重跑可能是绿的，在 PR 上却是红的，且 master 的绿不能作为「代码在当前上游下仍然通过」的证据**——它只说明 master 这次跑的是旧快照，没有真正验证当前上游。旧快照最迟会在 cache key 里的 `%G-W%V`（ISO 年-周）进入新的一周时失效，届时 master 自己也会开始暴露同样的漂移。

判读方法是比较两次运行各自命中的缓存 key、`actions/cache` 记录里的缓存创建时间与体积，而不是只看 job 颜色。#1050 的实证：master 侧缓存创建于 08-03 00:44、319MB；PR 侧创建于 08-04 11:59、328MB——不同的创建时间和体积就是两份不同快照的直接证据。

CI 现在的结构 (PR #899 后):

**阶段 0 — `changes` job (paths filter):**
PR 触发时跑 `dorny/paths-filter@v4`, 检测哪些包目录被改, 输出 6 个 bool (ctex / xeCJK / xpinyin / zhnumber / CJKpunct / zhlineskip). push / schedule / workflow_dispatch 触发时 filter 不影响, 全跑. 同时把 `TL_VERSION` (顶层 env, 如 `'2026'`) 作 `tl-version` output 透传给 caller (workflow_call inputs 不能直接引用顶层 env).

依赖反查: ctex 依赖 xeCJK + zhnumber, 所以改 xeCJK 或 zhnumber 同样会让 ctex job 跑; xpinyin 的 XeTeX 路线以工作树里的 xeCJK 为运行时依赖 (`checkdeps` + `checkinit_hook`), 所以改 `xeCJK/**` 也会让 xpinyin job 跑. 公共改动 (`.github/workflows/test.yml`, `.github/workflows/_test-package.yml`, `.github/font-urls.txt`, `scripts/check-parallel.sh`, `support/**`, `Makefile`) 让所有 6 个包都跑.

#### 新增被多个 workflow 共用的脚本时要一起改触发白名单

把逻辑抽成共享脚本时，「哪些文件改动会触发这些路径」是调用点的一部分，必须一起更新，否则改坏脚本时 CI 不会告警。`scripts/sync-l3backend.sh`（已于 #1074 随上游合并撤除）在 #1054 被漏掉过，由两个 bot 独立指出；当时补了三处：`check-doc.yml` 的 `on.pull_request.paths` 与 `_all` filter、`test.yml` 的 `_all` filter。**撤除该脚本时同样要清点这几处**——#1074 删的就是它们。

**两个 workflow 的失效机制不同，只查一处不够：**

- `check-doc.yml` 用 `on.pull_request.paths` 白名单。文件不在里面，workflow **根本不会触发**，Actions 页面上看不到这个 run。
- `test.yml` 用 `paths-ignore`。workflow **会触发**，但各包 job 的 `if` 取自 `changes` job 的 `_all` filter，该 filter 不含这个文件时全部为 false，于是每个包的 job 都被 skip，`test-result` 把 skipped 算作 OK，整体呈现为绿。

由此得到一条判读约束：**「看 job 有没有启动」不能作为检查生效的证据。** 前一种机制下 run 缺席，后一种机制下 run 在但内容为空，两者都可能被误读成「已经跑过了」。要确认，得看 `changes` job 的 filter 输出，或直接读两个 workflow 里的路径清单。

**阶段 0.5 — `warmup-tl` job (cache 预热):**
`needs: changes`, `matrix.os = [ubuntu, macos, windows]` 3 job 并行. 每 OS 1 个 job 跑 setup-texlive-action 装 + update, 把 cache 填到当前 TLnet 最新 baseline. 这是**唯一会实际运行 install-tl** 的地方 — 收敛 mirror 请求, 避免 6 caller × 3 OS = 18 路并发轰炸 mirror 触发 ETIMEDOUT.

3 次 retry 换不同 mirror: try 1 `ctan.math.illinois.edu` (timeout 10min), try 2 `ftp.fau.de` (timeout 10min), try 3 `mirror.ctan.org` 自动重定向 (timeout 30min). try 1/2 短超时让换 mirror 反应快.

历史: 早期尝试 `SETUP_TEXLIVE_ACTION_FORCE_UPDATE_CACHE=1` 让 warmup 把 update 后的 TL 保到 uniqueKey (= primaryKey + uuid), 让 caller 跳过 update 省 70s/caller. 实测**不生效** — GH actions/cache 在 restoreCache 时按 restoreKeys 数组的 primaryKey 精确匹配优先, caller 命中老的纯 primaryKey entry (无 uuid), 跳过 warmup 的 uniqueKey. 现在 caller 端仍 `update-all-packages: true` 自己跑 update 才能与仓库 `.tlg` baseline 一致. 见 `_test-package.yml` head 注释.

**阶段 1 — 6 个 caller job 并行 (uses reusable workflow):**
`test-ctex` / `test-xeCJK` / `test-xpinyin` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip` 六个 caller job, 各自 `uses: ./.github/workflows/_test-package.yml`, 传 `pkg` / `event-name` / `tl-version` 输入. 各 caller `needs: [changes, warmup-tl]` + `if: needs.changes.outputs.<pkg> == 'true'` 控是否跑. `test-xpinyin` 另传 `configs: test/config-cjk` 与 `needs-unihan: true` 两个输入, 分别对应 CJKutf8/pdfTeX 那条线和拼音数据库生成 (见下文); `test-zhnumber` 也传 `configs: test/config-cjk` (#1008 起), 但不需要 `needs-unihan`.

每个 reusable workflow 实例内部 `strategy.matrix.os = [ubuntu-latest, macos-latest, windows-latest]`, 三个 OS 并行. `fail-fast: false` 一个失败不取消其它.

之所以拆 caller job 而非用 `matrix.pkg` 维度, 是为了消除 GH Actions 在动态 name (`${{ matrix.pkg }} on ...`) strategy expansion 前注册 placeholder check 用未渲染模板作 name 然后 cancel 的"幽灵 job"行为.

每个实例步骤:
- 装 TL: 2 次 retry 换 mirror (try 1 illinois, try 2 fau.de), 各 timeout 15min. 即便 cache hit, setup-texlive 在 `Updating packages` 阶段仍会联网拉 tlmgr db checksum, 单 mirror 网络抖动时这步可能失败 — PR #899 实测 windows 命中. retry 2 次降低这种 transient failure 让 job 挂的概率.
- 装字体 (`actions/cache@v6` 缓存 `$GITHUB_WORKSPACE/.font-cache/`, key 含 `_test-package.yml` hash; zip 解完即删只留 ttc)
- (仅 `needs-unihan: true` 的 caller, 目前只有 xpinyin) 缓存并下载 `support/Unihan.zip`: unpack 阶段的 `texlua xpinyin.lua` 要用它生成拼音数据库, weekly cache key 与 `_check-doc-package.yml`（xeCJK 用）完全一致, 两条 workflow 互相填对方的缓存.
  - `Unihan.zip` 不固定版本: CI 每周下载最新版, 本地构建也会重新下载, 所以断言具体汉字数据库读音的用例会随上游数据变化 (例如 Unihan 18.0 把「噷」的首选读音从 hm 改成 xin1). 要测的是规则本身而不是某个字的收录读音时, 用 `\setpinyin` 固定输入 (实例见 `xpinyin/testfiles/pinyin-query01.lvt` 第 5d 项的注释, 以及 `llmdoc/memory/lessons-learned.md` 的「上游数据变化让被测规则失去数据载体时，用受控输入固定被测值」).
- 跑 `Test <pkg>` (case 分支):
  - `ctex`: `../scripts/check-parallel.sh` + `CONFIGS` 三个 config, 4 engine 并行. wall-clock ~5–8min.
  - `zhlineskip`: 失败时 dump `build/test/*.log` 前 80 行.
  - 其他 (xeCJK / xpinyin / zhnumber / CJKpunct): `l3build check -q` 直接跑; 若传了 `configs` (目前 xpinyin 与 zhnumber 各传 `test/config-cjk`), 主 check 跑完后再逐个串行跑 `l3build check -q -c <cfg>` — 与 ctex 的 configs 走 `check-parallel.sh` 并行不同, 这些小包的额外 config 是秒级到分钟级, 不值得铺并行基础设施.

**阶段 2 — `test-result` job (汇总):**
`needs: [warmup-tl, test-ctex, test-ctex-luatex, test-xeCJK, test-xpinyin, test-zhnumber, test-CJKpunct, test-zhlineskip]`, 检查每个 caller 结果(success / skipped 都 OK; 其他 fail). 把 warmup-tl 也算进去, 避免 warmup 失败 → caller 全部 skipped → test-result 误绿. branch protection 只盯这一个 status check 即可.

失败时 artifact 上传 (`actions/upload-artifact@v7`): `${{ inputs.pkg }}/build/**/*.diff` 与
`tmp/parallel-check/**/build/**/*.diff` 两条路径都要传 (#1080), artifact name 含 pkg 名 + OS
区分. 前者对应串行 `l3build check` 写入的 `<pkg>/build/check/`（或 `build/test/`); 后者对应
`scripts/check-parallel.sh` 给每个引擎在 `tmp/parallel-check/<engine>/<pkg>/` 下各开的独立
工作区——ctex 走并行脚本, diff 落在那里面. #1080 之前只有前者, 并行路径失败时 artifact 恒为
空 (`No files were found`), 排查只能靠猜.

`Test <pkg>` 步骤失败后还先跑一个纯诊断步骤 `Show test diffs`, 把两条路径下找到的 `.diff` 正文
直接打进 job 日志 (每份截断 200 行并提示总行数): 下载 artifact 要多一步, 而 artifact 只在
job 失败时才生成, 路径不匹配时 (即上面这个坑) 完全没有诊断信息. 该步骤不设 `set -e`——它是
纯诊断, 任何一环失败都不该盖掉真正的测试失败; 用临时列表文件而非 `< <(...)` 进程替换收集
`.diff` 路径, 避开 windows matrix (`C:\msys64\usr\bin\bash.exe -e {0}`) 的 shell 差异.

#### 定时失败自动开 Issue 哨兵：`file-issue-on-schedule-failure`

test.yml 的 weekly `schedule`（周一 UTC 12:00）触发时若 TL bypass cache miss，会走完整 `setup-texlive`（install + update-all），引入上游最新更新——所以定时任务是上游漂移导致回归时最先撞上的地方（#1080 的 tocloft／fontspec、#1048/#1050 的 l3backend／pgf 都是经定时或缓存路径发现的）。PR／push 触发的失败已经有红叉和 PR 评论提醒维护者，不需要额外开 Issue；只有无人盯着的定时失败才需要主动开 Issue。

`file-issue-on-schedule-failure` job 的三重守卫：`if: always() && github.event_name == 'schedule' && github.repository == 'CTeX-org/ctex-kit' && needs.test-result.result == 'failure'`。`github.event_name == 'schedule'` 把 PR／push 排除在外；`github.repository` 守卫与 #874/#875 的 fork 屏蔽是同一种做法——fork 上的 schedule 仍会照常跑测试，只是不会开 Issue（fork 的 Issue 区无人看，也没有本仓的 `upstream` label，agentic 分派也只在主仓运行）。`needs` 列出 `test-result`、`warmup-tl` 以及各包 caller job（`test-ctex`／`test-ctex-luatex`／`test-xeCJK`／`test-xpinyin`／`test-zhnumber`／`test-CJKpunct`／`test-zhlineskip`），用于在 Issue 正文里列出具体是哪个阶段失败。`warmup-tl` 必须纳入：`test-result` 把 TeX Live 预热失败同样计为失败，此时各包 caller 因 `needs: warmup-tl` 全部 `skipped`，若清单不含 `warmup-tl` 就只剩「未能判定」、指不出真正的失败阶段（cache miss 时 `setup-texlive` 装包失败是定时任务的常见失败模式）；清单为空时还会退回到用 `test-result` 自身状态说明失败。权限为 `issues: write`（开 Issue／评论）、`actions: read`（`gh run download` 拉本次 run 的 diff artifact）、`contents: read`。

去重按周粒度：标题固定为 `weekly test failure (YYYY-Www)`（`YYYY-Www` 取自 `date -u +%G-W%V`），命中已有同标题的 open Issue 则追加评论，否则新建；label 用仓库已有的 `upstream`（注意仓库里没有 `ci` 这个 label）。这样同一周内的多次失败（`schedule` 每周一只跑一次，但对失败的 run 重跑 failed jobs 会以同一 `schedule` 事件再次进入本 job）只在同一个 Issue 下累积评论，跨周才新开。注意本 job 守卫要求 `github.event_name == 'schedule'`，手动 `workflow_dispatch` 不会进入开 Issue 路径，因此同周去重不含手动触发场景。标题**刻意不含「疑似上游漂移」之类结论**：定时那次是否真的 cache miss、是否引入了上游更新，`file-issue` job 拿不到可靠信号（预热 `warmup-tl` 是 3-OS 矩阵 job，给它加单一 cache-hit output 有「哪个矩阵实例胜出不确定」的竞态），因此 Issue 正文改为条件化表述（`若 cache miss 则…；若命中则更可能是抖动或本仓问题`），把归因交给人看失败 diff 与失败分布判断（呼应 #1080「失败集合的分布差异才是成因线索」），不由标题或正文武断下结论。

Issue／评论正文尽量给够排查起点：失败包清单；`gh run download --pattern 'ctex-kit-diff-*'` 拉本次 run 的 diff artifact，把每个 `.diff` 正文（单文件截断到 120 行、总量上限 40000 字节）贴进 fenced code block——这是判断“上游漂移还是本仓回归”最直接的信号，参见 #1080 的教训；环境指纹检查表和 #1080／#1048／#1074 上游根因反思的排查入口（见上方“上游宏包版本漂移的识别与基线处置”一节）；本地复现命令；以及“刷基线前先按上游根因分类”的提醒。拉不到 diff artifact 时退化为只给这次 run 的链接。

Issue 用默认 `GITHUB_TOKEN` 创建，因此**不会**自动触发 `agentic-issue-dispatch.yml`：GitHub 刻意不为 `GITHUB_TOKEN` 产生的 `issues.opened` 事件再启动 workflow（防止 workflow 相互递归触发）。定时失败的 Issue 只承担「主动提醒维护者 + 附带诊断」的角色，后续分析需人工进行或另行接入。让它自动进入 agentic 分析需要给 dispatch 工作流加显式触发入口并改用能产生事件的身份，会触及 agentic runtime 的稳定性约束（契约测试刻意断言 issue dispatch 无 `workflow_dispatch`／`schedule` 入口），留作独立议题。这条 `GITHUB_TOKEN` 不触发下游的限制在设计前未被识别，是 PR #1087 review 阶段才由 bot 指出的，教训见反思 [[../memory/reflections/weekly-issue-heredoc-indent]]。

### 文档编译校验：`.github/workflows/check-doc.yml`

PR 阶段专用校验 (#935), 补 test.yml 的"文档 dtx→PDF 可编译性"维度. 只在 `pull_request` 触发. 结构:

- **`on.pull_request.paths` 白名单**: 除 9 个包目录外, 还含公共依赖与基础设施——`support/**`、`scripts/verify-doc-output.sh`、`check-doc.yml` 与 `_check-doc-package.yml` 本体、`.github/tl_packages`、`.github/font-urls.txt`. 不在这份清单里的文件改动**不会触发本 workflow**.
- **`changes` job**: 精简版 paths-filter, 9 个 bool (ctex/xeCJK/CJKpunct/zhnumber/xCJK2uni/xpinyin/zhmetrics/zhmetrics-uptex/zhlineskip). 其 `_all` filter 需与上面的 `on.paths` 保持一致. **无依赖传递** — `l3build doc` 只 typeset 自身 `typesetfiles`, xeCJK 变动不会跑 ctex 的 doc.
- **9 个 caller job**: 每包一个 `uses: ./.github/workflows/_check-doc-package.yml`, job 级 if 保证未受影响包不启动 runner (仿 test.yml + _test-package.yml 的 caller-per-pkg 结构, 避开 matrix.pkg 幽灵 cancelled job).
- **`check-doc-result` 汇总**: 与 test-result 同构, branch protection 单点盯.

TL cache 共享: 用同一个 `tl-bypass-<os>-<ver>-<week>-<hash>` key (与 test.yml warmup-tl / release.yml 完全一致). PR 触发时 test.yml warmup-tl 同 head sha 并行填 cache, 本 workflow 大多数情况 100% cache hit; cache miss 走 setup-texlive-action fallback (单 mirror illinois pin, 抖动时 rerun --failed).

Verify 层: `scripts/verify-doc-output.sh` 按 `typesetfiles` 逐 PDF 检查 `build/doc/*.pdf` 存在 + `%PDF` magic + `>= 1024` 字节最小大小 (防 dvipdfmx fatal 后残留 stub `%PDF` header). `typesetfiles={}` 的包 (zhmetrics-uptex) 期望零 PDF 单独短路通过.

**这三条判据都是容器级的，对「编译成功但正文被污染」完全没有判别力**（`scripts/verify-doc-output.sh:69-88`）。#1054 的实证：l3backend 版本错配下 `l3build doc` exit 0、PDF 页数与体积都正常，三条判据全过，只有版面上散落 `0gray 0` 一类泄漏文本。这是已登记的技术债，见 `memory/doc-gaps.md` 的「`verify-doc-output.sh` 缺内容级哨兵」。

#### 成功时也上传 PDF artifact

`_check-doc-package.yml` 在 `steps.doc.outcome == 'success'` 时上传 `check-doc-<pkg>-pdf`，path 为 `<pkg>/build/doc/**/*.pdf`，`if-no-files-found: ignore`。它与既有的失败版 `check-doc-<pkg>-failed`（同时含 `.log` 与 `.pdf`）条件互斥，不会重复上传。

理由是上面那条盲区：排版类问题（溢出行、字形缺失、颜色 special 泄漏）退出码都是 0，只能看版面，所以要让 PR 编出来的 PDF 可以直接下载做目视检查。

成功路径只传 PDF 不传 log——成功的 log 没有诊断价值，而 `xeCJK.log` 有近百 KB。存储方面：公开仓库的 Actions 存储不计费，保留期取仓库默认 90 天到期自动删除，且与 TL／字体 cache 是两套独立配额，不互相挤占（后者当前已用 9.71 GB，接近 10 GB 上限，这也是不把 PDF 塞进 cache 的原因）。

验收方式可参考 #1054 的做法：下载 artifact 后 `pdftotext` 再检索泄漏模式（`gray 0`、`0gray`、`1.0 0.0`），当时 `xeCJK.pdf`（249 页，是 #1054 时的页数）与 `xunicode-symbols.pdf` 的计数均为 0。

#### 3 个包的 CI-only 特殊处理

首轮 CI 暴露 3 包 typeset 缺陷 (从未在 CI 上被 typeset 过), 已在同 PR 一并修复:

- **xpinyin**: `xpinyin.dtx` 的 `\newfontfamily\PinYinFont{TeX Gyre Adventor}` 走 fontconfig friendly name. TL 装了 tex-gyre 但字体不在 fontconfig 索引 → workflow 加 `/etc/fonts/conf.d/09-texlive-opentype.conf` 让 fc-cache 扫 TL opentype/truetype 目录. 无条件执行, 别的包只是索引多几百字体.
- **zhmetrics**: TL zhmetrics 包只装 gbk/unicode 分片 tfm, **不含**顶层 `zhmCJK.tfm`/`.map` — 这两个是 `zhmCJK.lua map` 在 `copyctan_posthook` 里生成后 CTAN admin 手工上传独立文件, TL 打包时未纳入. `zhmCJK.dtx` typeset 请求 `zhm35b` 走 fontname map 失败. 修法: workflow 加 `pkg==zhmetrics` pre-doc step, 用包内 `zhmCJK.lua` 生成 tfm/map, 装到 `TEXMFHOME` 并 `mktexlsr`. `.github/tl_packages` 补 `fontware` (提供 `pltotf`). build.lua 不变. `zhmCJK-test.pdf` 从 verify expected 移除 — `zhmCJK-test.tex` 硬编码 simsun.ttc/simhei.ttf 文件名 fontconfig alias 救不了, 是包内部字体安装 demo 与文档 CI 目标无关.
- **zhspacing** (暂不覆盖): 从 caller 里删除. `zhfont.sty`/`zhmath.sty`/`zhspacing.sty` 硬依赖 SimSun/SimHei/KaiTi/FangSong/Sun-Ext*/Times New Roman 商业字体, 且深挖后发现 `zhspacing.sty` 自身有时序 bug (`\@iforloop`/`\@nil` undefined, 之前被 SimSun 早退错误掩盖). 上次 tag `zhspacing-20160514` 后 10 年未维护, `release.yml` 也从未真正验证过它的 typeset 链路. 属于包本身 CI 改造范畴, 不合适塞进"新增 workflow 校验"这类 infra PR. followup issue 单独跟. 详见 [[935-check-doc-zhspacing-blockers]].

关键约束: **`l3build ctan` 不能作为 PR 校验的等价替代**, 因为它内部硬编码调 `l3build check` (`l3build-ctan.lua:123`), 整套 regression 会重跑, ctex 单包 20+ min 与 test.yml 完全重复. 用 `l3build doc` 精确对应"文档编译性"维度是取舍后的选择, 见 [[935-check-doc-vs-ctan]].

#### fontconfig alias 对 XeTeX/fontspec 无效

尝试过 `<alias binding=strong>` / `<match target=scan>` / `<match target=pattern>` 三种 fontconfig alias 写法给 CI 上不存在的商业字体 (SimSun/SimHei) 提供 Noto CJK 替代, 均对 XeTeX/fontspec **无效** — `fc-match SimSun → Noto Serif CJK SC` 生效, `fc-list :family=SimSun` 有输出, 但 `xelatex \newfontfamily{SimSun}` 依然报 "cannot be found". XeTeX 内部字体查找路径不完全走 fontconfig, alias 层拦不住 fontspec. **CI 上要给不存在的字体提供替代, 唯一稳定办法是直接 patch dtx/sty 里的字体名** (workspace 内 sed 就地修改, 不改仓库源文件).

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

等待测试结果这一步的关键点是：构建、asset 准备与 notes 生成可以先完成，只有最后 `Create GitHub Release` 之前才轮询 `actions/workflows/test.yml/runs?head_sha=<sha>`，确认测试 CI 通过。这避免了在 release 任务最前面空等测试，同时保持发布出口受测试结果保护。

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

调查在 `ctex/ctex.dtx` 中确认了这套机制。文档排版时，版本与变更信息会进入最终文档输出；`ctex.pdf` 与 `xeCJK.pdf` 的标题日期则统一使用 `\ctexkitbuilddate`，以 `YYYY/MM/DD` 格式表示 GitHub Actions 生成正式 PDF 的日期，不再借用某个 `.sty` 的源文件 stamp 日期。

## 版本单一事实源与 l3build tag（zhlineskip / ctex / xeCJK / xpinyin）

完成 DocStrip & L3 重构或接入共享 `update_tag` 的包（zhlineskip 自 PR #892，ctex 自 PR #937，xeCJK 自 #1041，xpinyin 随 #1041 的测试接入同批补上）采用统一的版本管理模式，详见决策 [[937-version-single-source-l3build-tag]] 与 [[1041-xecjk-version-gate]]：

### 覆盖矩阵

两道校验都是**白名单**（`check-tag.yml` 用 `paths` filter、`release.yml` 用 `case "${DIR}"`），未列出的包**静默跳过**且不产生 failure——`release.yml` 只打一条 `::notice::...跳过三方校验`。因此这份矩阵必须与两个 workflow 同步维护：

| 包 | `version` 事实源 | dtx 版本位置 | `update_tag` | PR 校验 | release 三方校验 |
|---|---|---|---|---|---|
| `ctex` | `build.lua` `version` | `$Id:$` stamp（6 个拆分 dtx，均含 stamp） | 包级覆写 | ✓ | ✓ |
| `zhlineskip` | `build.lua` `version` + `date` | `$Id:$` stamp | 包级覆写 | ✓ | ✓ |
| `xeCJK` | `build.lua` `version`（#1041） | `{\ExplFileDate}{<ver>}` | **共享** | ✓ | ✓ |
| `xpinyin` | `build.lua` `version`（#1041 后续） | 两处：`{\ExplFileDate}{<ver>}`（`\ProvidesExplPackage`）与 `[<日期> v<ver>]`（`xpinyin-database.def` 的 `\ProvidesFile`） | 共享 | ✓ | ✓ |
| `zhnumber` | `build.lua` `version`（本次补） | `{\ExplFileDate}{<ver>}`（带 `%<package|config>` 守卫） | 共享 | ✓ | ✓ |
| `xCJK2uni` | `build.lua` `version`（本次补） | `{\ExplFileDate}{<ver>}`（**无** docstrip 守卫，行首只有缩进） | 共享 | ✓ | ✓ |
| `jiazhu` | 无 | `{\ExplFileDate}{0.0-beta}` | 共享 | ✗ | ✗（走 `*)`）——但 `release.yml` **没有** `jiazhu-v*` 触发器，无法发版，属潜在缺口 |
| `zhmetrics` | `build.lua` `version`（本次补） | `[<日期> v<版本> setup CJK fonts dynamically]`（`zhmCJK.dtx`，**旧式**写法，非 `{\ExplFileDate}`） | 共享 | ✓ | ✓ |
| `CJKpunct` | 无 | **两种写法都没有** — 共享 `update_tag` 对它恒为空操作 | 共享（不生效） | ✗ | ✗（走 `*)`） |
| `zhmetrics-uptex` | 无 | 无 `.dtx` | 不适用（有自己的 `build.lua`、`dir=zhmetrics-uptex`，但不 `dofile` 共享配置） | ✗ | ✗（走 `*)`）|
| `zhspacing` | — | — | — | ✗ | ✗ |

**这张表的行必须覆盖 `release.yml` 的 `Parse tag` 能识别的全部 tag 前缀**（当前十个：`CJKpunct`、`ctex`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zhlineskip`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`），否则漏掉的那一行正是矩阵想拦住的「静默跳过」。`zhmetrics-uptex` 就是这样漏过一次的——它能触发 `release.yml` 却不在表里。

**对账现在由 `scripts/check-version-gate-coverage.py` 自动完成**，接在 `check-tag.yml` 的 `gate-coverage` job 上（无 `paths` 过滤，总是跑——用 `paths` 过滤自己就会重现同一类漏报）。它扫全部 `*/build.lua` 同目录的 `.dtx`，凡含 `l3build tag` 会回写的版本槽位（`{\ExplFileDate}{...}` 或 `$Id: <file> <ver>`）就要求该包同时出现在两个 workflow 里，否则失败并指出该补哪一处。

判据刻意选「**有没有版本槽位**」而不是「有没有 release tag」或「有没有 `version` 字段」：后两者都是可以补的，而前者决定了忘同步会不会发出错版的包。

按「可发版 / 不可发版」分级：`release.yml` 有对应 `<pkg>-v*` 触发器的包漏校验就硬失败；没有触发器的（当前只有 `jiazhu`）无法发版，只打 `::notice::`。让一个当下无法造成事故的项长期报红，等于把这个检查训练成噪声。

脚本本身的判别力已实测：分别从 `paths`、`filters`、`tag-<pkg>` job 三处各移除一个包，三次都 EXIT=1。**早期版本只用一条正则扫全文，因为 `<pkg>/**` 在 `paths` 与 `filters` 两段都出现，从 `paths` 删掉后仍显示已覆盖**——这个假阴性是实测发现的，现改为取三处交集。

脚本的判据必须跟着 `update_tag` **实际写入的位置**走，不能凭印象列举：初版只列了 `{\ExplFileDate}{...}` 与 `$Id:$` 两种槽位，漏掉旧式 `[<日期> v<版本>]`——而 `zhmetrics` 只有旧式写法，且它**有** `zhmetrics-v*` 触发器（能发版），于是两道校验都放行、对账脚本也扫不到它，是 #1041 的完整重演。盲审实测 `cd zhmetrics && l3build tag 9.9.9` 确实回写 `zhmCJK.dtx` 一行才查出来。现补第三条 pattern 并把 zhmetrics 一并接入。

脚本核对的是**四处**接入点的交集（`paths` / `changes` job 的 `outputs:` 映射 / `filters` / `tag-<pkg>` job），少查任何一处都会漏报：`outputs:` 里删掉一行会让 `needs.changes.outputs.<pkg>` 恒为空、对应 job 永不运行，而前三处看着都在。

**`gate-coverage` job 无 `if:` 条件，但 workflow 级的 `on.pull_request.paths` 仍是白名单**，所以「总是跑」只在 workflow 被触发的前提下成立。给某个包新加 `<pkg>-v*` 触发器（即它从「无法发版、只 notice」变成「能发版、必须校验」的那次跃迁）只改 `release.yml`，而它原先不在 `paths` 里，于是最需要对账的那一刻恰好不触发——又是同型缺口。现已把 `release.yml` 与对账脚本自身加进 `paths`。

**这套对账查不到「job 存在但被掏空」**：`tag-<pkg>` job 里把 `l3build tag` 换成别的命令、`if:` 指向别的包的 output、汇总的 `needs`／`env` 漏包，三者脚本都报绿。不再往下做语义检查是有意取舍——再深就要解析 shell 与表达式，脚本自身的脆弱性会超过它防住的问题，而会静默失效的对账比没有更糟。这部分靠 review 人眼核对，脚本 docstring 里也如实列了这条边界。

这一版之前是手工对账（`grep -oE '^ +[A-Za-z0-9-]+-v\*\)' .github/workflows/release.yml`）。首次补 `zhmetrics-uptex` 时那条模式写成 `[A-Za-z-]+`（不含数字），于是同一次对账又静默漏掉了 `xCJK2uni`——**对账手段自己犯了和被查问题同型的白名单错误**。这正是把它换成带判别力实测的脚本的理由。

`zhspacing` 是**有意识**排除（商业字体依赖 + 包自身时序 bug，见 [[935-check-doc-zhspacing-blockers]]）；xeCJK 曾是**无意识**从未接入——`v3.10.5-rc2` 因此发出了一个自报 `v3.10.4` 的包，两道检查都没拦住。加新包或让某个包具备条件时，务必回到这张表和两个 workflow 一起改。

- **`build.lua` 顶部 `version` 字段是唯一手改的版本事实源**（ctex 还有 `date` 等价物走 git 元数据；zhlineskip 是 `version` + `date` 两字段）。`uploadconfig`（CTAN 投递）直接引用它。
- dtx 源文件的版本行是 `\GetIdInfo $Id: <file> <ver> <date> ...$` stamp，被 `\ProvidesExplPackage{...}{\ExplFileDate}{\ExplFileVersion}{...}` 消费——dtx 里没有第二处硬编码版本。
- 本地手跑 `cd <pkg> && l3build tag`，`update_tag` 把 version 回写进源文件。ctex / zhlineskip 在各自 `build.lua` 里**包级覆写**该函数（回写 `$Id:$` stamp）；xeCJK 用 `support/build-config.lua` 的**共享**版本（回写 `{\ExplFileDate}{<ver>}`）。**三者都带幂等守卫**：目标版本已一致时原样返回，否则"回写产生新 commit → 新 sha → 又要回写"永不收敛，且 PR 校验的 diff 检查会恒 fire。
- 共享 `update_tag` 的三个坑（#1041，第三个在 xpinyin 接入测试时补上）：
  - **`version` 这个全局名可能是函数**。l3build 自己定义了 `function version()` 供 `--version` 用（`l3build-help.lua:32`），所以未设 `version` 的包里它不是 `nil`。写 `version or tagname` 会取到那个函数并报 `attempt to index a function value`，必须 `type(version) == "string"` 判断。
  - **`\ExplFileDate` 装的不是版本号**。`\ProvidesExplPackage` 的参数顺序是 `{name}{date}{version}{desc}`，所以 `{\ExplFileDate}{3.10.5}{\ExplFileDescription}` 里 `\ExplFileDate` 是日期占位宏（由 `\GetIdInfo$Id:$` 从 git stamp 取 commit 日期），大括号里的 `3.10.5` 才是版本。`update_tag` 只改后者；日期随打包时的 `replace_git_id` 自动跟进，硬写会让每次 tag 都产生 diff。
  - **幂等守卫的观察范围必须覆盖全部写入范围**。`xpinyin.dtx` 同时存在两种版本写法：`\ProvidesExplPackage` 后的 `{\ExplFileDate}{<ver>}`，与 `xpinyin-database.def` 里 `\ProvidesFile` 的 `[<日期> v<ver> xpinyin database]`。早期版本的守卫只看前者，一旦两处失同步而只有后者过期，该行永远不会被修复。修法是先算出两处各自的目标写法，再整体比较；`[<日期> v<ver>]` 这种写法**只在版本号需要改时才连日期一起重写，版本号已对则整段原样保留**（包括陈旧日期），因为持续把已同步文件的日期刷成当天会让 PR 校验的 diff 永不为零。
- **给一个包补 check-tag job 时，必须同时给它加 `build.lua` 的 `version` 字段，否则那个 job 是恒绿的。** 未设 `version` 的包跑不带参数的 `l3build tag` 时，共享 `update_tag` 会打印「未指定版本号, 未作任何修改」并**以 0 退出**；于是 job 跑完 `git diff --exit-code` 天然为零，看着通过，实际什么也没校验。zhnumber / xCJK2uni 接入时实测确认：加字段前 `l3build tag` 不改任何文件，加后回写并保持幂等。这类「跑了但没检查」的 job 比没有 job 更危险——它会让覆盖矩阵显示 ✓。
- **提取版本号的模式必须锚到行首的结构标记，而不是只匹配形状**；两个包的锚点还不一样：`zhnumber.dtx` 的版本行带 `%<package|config>` docstrip 守卫，锚它即可；`xCJK2uni.dtx` 的版本行**没有**守卫（行首只有缩进空白），只能锚 `^[[:space:]]*` 加完整形状——而该文件另有一处 `\ExplFileDate` 出现在 `\date{...}` 里，完整形状恰好能排除它（实测不会误匹配）。两者的 fail-closed 都实测过：删掉真正的版本行、追加一句引用该形状的注释，提取结果均为空。
- 注意 `make tag <pkg>-vX.Y.Z` 是打 **git tag**（触发 release.yml），与 `l3build tag`（回写源文件 stamp）是两回事。
- ctex 的 `update_tag` 在处理主 `ctex.dtx` 时还会额外固化手册首页页脚的 shorthash：取 `git log -1 --format='%h' *.dtx` 回写进 `ctex.dtx` 里的 `\GetFileId[<hash>]{ctex.sty}`（消费方是 `support/ctxdoc.cls` 的 `\GetFileId { O{} m }`，可选参数即固化 hash）。运行时**不**依赖 `\sys_get_shell` / `--shell-escape` 现取 git 信息——曾经的运行时方案已被否决，详见决策 [[937-version-single-source-l3build-tag]] 「手册页脚 shorthash」小节。
- `\GetFileId` 仍为标题页提供版本号和 revision hash，但不再提供标题日期。`ctex` 拆分后，`ctex.sty` 的 `\filedate` 只反映 `ctex-kernel.dtx` 的 stamp，可能早于手册和其他拆分源文件；因此 `ctex` 与 `xeCJK` 的标题日期统一改用 `\ctexkitbuilddate`，按 `YYYY/MM/DD` 格式排印构建当天日期。正式 PDF 由 GitHub Actions 集中构建，版本号负责标识内容，日期只表示该 PDF 的构建日。

### 发版 SOP（ctex 拆分后）

```
1. ctex/build.lua:2       version = "X.Y.Z"           （手改，唯一）
2. 相应 ctex-*.dtx        补 \changes{vX.Y.Z}{...}     （随功能 PR）
3. cd ctex && l3build tag 回写 6 个拆分 dtx 的 $Id:$ 行（自动）
4. commit + PR            （check-tag.yml 验证 stamp 同步）
5. merge 后 make tag ctex-vX.Y.Z[-rcN] && git push origin <tag>
                          （release.yml 三方校验通过才发版）
```

### 发版 SOP（xeCJK，#1041 起）

```
1. xeCJK/build.lua        version = "X.Y.Z"           （手改，唯一）
2. xeCJK/xeCJK.dtx        补 \changes{vX.Y.Z}{...}     （随功能 PR）
3. cd xeCJK && l3build tag 回写 {\ExplFileDate}{X.Y.Z}（自动，幂等）
4. make changelog-xeCJK   同步 CHANGELOG.md            （check-changelog.yml 验证）
5. commit + PR            （check-tag.yml 验证版本同步）
6. merge 后 make tag xeCJK-vX.Y.Z[-rcN] && git push origin <tag>
                          （release.yml 三方校验通过才发版）
```

第 3 步漏掉的后果就是 `v3.10.5-rc2`：包自报版本落后于 git tag。现在第 5、6 步各有一道校验拦住它。

### 发版 SOP（xpinyin，随 #1041 测试接入同批）

```
1. xpinyin/build.lua      version = "X.Y.Z"           （手改，唯一）
2. xpinyin/xpinyin.dtx    补 \changes{vX.Y.Z}{...}     （随功能 PR）
3. cd xpinyin && l3build tag 回写两处版本写法（自动，幂等）：
                          {\ExplFileDate}{X.Y.Z} 与
                          [<日期> vX.Y.Z xpinyin database]
4. make changelog-xpinyin 同步 CHANGELOG.md            （check-changelog.yml 验证）
5. commit + PR            （check-tag.yml 验证两处版本同步）
6. merge 后 make tag xpinyin-vX.Y.Z[-rcN] && git push origin <tag>
                          （release.yml 三方校验通过才发版，两处 dtx 版本都要与
                           git tag / build.lua 一致）
```

xpinyin 目前只在测试接入 PR（#1041 后续）里补了一条 `\changes{v3.2}{...}`，尚未真正发过新版本；上面的 SOP 是接入两道校验后的完整流程，供下一次 bump 版本时参照。

**因此现在 `xpinyin/build.lua` 的 `version = "3.1"` 与 `CHANGELOG.md` 首节的 `v3.2` 是不一致的，这是本节上文那条约定要求的正常状态，不是缺陷**：已发布的 tag 是 `xpinyin-v3.1`，所以新 `\changes` 必须写下一个未发布版本 `v3.2`，而 `build.lua` 只在真正发版准备阶段才 bump（见下文「Git 信息注入」小节，以及 #381 把 `\changes` 误记为已发布版本的反例）。两道 PR 校验都不会因此报错，各自的判据是自洽的：`check-tag.yml` 比的是 `build.lua` 与 dtx 两处 stamp（都是 3.1，`l3build tag` 为 no-op），`check-changelog.yml` 比的是 `CHANGELOG.md` 与 `\changes` 条目（都是 v3.2，重新生成后字节一致）。真正会拦住的是发版出口：按 SOP 打 `xpinyin-v3.2` 前若忘了第 1 步，`release.yml` 会以 `LUA_VER(3.1) != BASE_VER(3.2)` 拒绝发版——这正是该校验的设计意图。审查这个包时不要把这条正常状态当成失同步。

### 两道 CI 校验

- **`check-tag.yml`（PR 校验）**：对 zhlineskip / ctex / xeCJK / xpinyin，PR 上跑 `l3build tag` + `git diff --exit-code`。diff 非零 = 作者 bump 了 version 没跑 tag，fail 并提示本地补跑。TL 最小安装（`l3build latex-bin`）。四个 job 的差异：ctex 需 `fetch-depth: 0`（其 `update_tag` 取 `git log -1`），xeCJK 与 xpinyin 都不需要（共享 `update_tag` 只改 dtx 内的版本写法，不读 git）。
  - **`paths` 必须含 `support/build-config.lua`**：共享 `update_tag` 在那里，改它要重跑校验。
  - **diff 范围只能是本包目录**（`git diff -- .`），因为「重新生成 + diff」型校验的 diff 范围应精确等于生成动作的**写入**范围，而 `l3build tag` 只回写本包 `.dtx`。
    - 澄清：写成 `-- . ../support` 在 CI 里**不会**误报——CI 检出的是已提交的干净树，`support/` 的改动不构成 diff（两种写法实测退出码均为 0）。误报只发生在本地有未提交改动时。限定范围的真实理由是语义精确：纳入非写入目标不增加检出能力，只会在将来某个生成物意外落进 `support/` 时给出误导性的「stamp 不同步」报错。
  - 本地验证这类校验要用干净 worktree（`git worktree add`）：主工作区有未提交改动时 `git diff` 会把它们算进来，no-op 结论不可信。
- **`release.yml` 三方一致性校验**：打 release tag 时验证 `strip_rc(git tag) == build.lua version == dtx stamp`，不一致拒绝发版。**RC 后缀（`-rcN`/`-pre`/`-alpha`/`-beta`）只存在于 git tag**，build.lua 与 stamp 均写 base version——发 rc 前 build.lua 必须已 bump 到目标版本并 stamp。未接入的包（见上方覆盖矩阵）走 `*)` 分支跳过校验并打 `::notice::`——注意那**不是** failure，CI 仍全绿。
  - **xpinyin 的 `xpinyin)` case 要同时校验两处 dtx 版本写法**（`{\ExplFileDate}{<ver>}` 与 `xpinyin-database.def` 的 `[<日期> v<ver> xpinyin database]`），只校验其中一处会漏掉另一处失同步的情况——这正是共享 `update_tag` 幂等守卫早期只看 `{\ExplFileDate}` 时踩过的坑（见上文「共享 `update_tag` 的三个坑」）。两处版本号合并去重后必须唯一，否则报错。两种失败模式（只 bump `build.lua`；两处只同步其一）均已实测能被拦住。

## 生成物新鲜度校验模式（"CI 只校验不回写"）

`check-tag.yml`（#937，版本 stamp）与 `check-changelog.yml`（#961，`CHANGELOG.md`）是同一套仓库级架构模式的两个独立实例，值得作为通用解法记住：**当某个产物必须由脚本/工具从源文件确定性生成、且要求与源文件保持同步时，PR 校验应"重新生成 + `git diff --exit-code`"，而不是让 CI 直接 commit 回写**。后者需要 write 权限，前者不需要。两个实例的共同结构：

- 校验只在改到相关源文件（dtx / 生成脚本 / 产物自身）时触发，用 `paths` filter 限定。
- 生成 + diff 都是秒级操作，全部涉及包合一个 job 串行跑，不需要按包拆 caller job（区别于 test.yml / check-doc.yml 的 caller-per-pkg 模式，那是因为跨引擎/跨 OS 测试本身耗时）。
- 汇总 job 名固定风格（`check-tag-result` 无独立汇总因单 job 即汇总；`check-changelog-result`），供 branch protection 单点盯。
- 本地都有对应的 `make` 入口把生成动作暴露给贡献者（`l3build tag` / `make changelog`）。

差异点在于校验对象的"大小"决定了 fail 时的可操作性设计：`check-tag.yml` 校验单行 stamp，提示"本地跑 `l3build tag`"即可；`check-changelog.yml` 校验整份 Markdown 文件，还需要在 fail 分支把期望的完整文件内容通过三个通道暴露（`::group::` 折叠的 job log、`$GITHUB_STEP_SUMMARY` 的 `<details>` 折叠块、`actions/upload-artifact`），确保没有本地 Python 环境的 contributor 也能直接复制粘贴通过校验。

**任何"字节级 diff 做校验"的生成物，必须由生成脚本自己控制 encoding/newline，不能依赖 shell 重定向**：Windows PowerShell 5 的 `>` 默认产出 UTF-16LE + CRLF，与 Linux/macOS 上 UTF-8 + LF 字节不同，即使内容语义相同也会被 `git diff --exit-code` 判为不同步。`scripts/extract-changes.py` 因此新增 `-o <file>` 参数，脚本自己以 `encoding="utf-8"` + `newline="\n"` 写文件；`l3build tag` 走 Lua io 库不存在这个问题，此前未暴露过这个坑。

### `check-changelog.yml` 校验细节

`.github/workflows/check-changelog.yml` 在 PR 改到以下路径时触发：任意 `**.dtx`（故意放宽到全部包——不参与 CHANGELOG 的包触发后生成 + diff 秒级必 pass，换来新包接入时无需改动 workflow）、任意 `**/CHANGELOG.md`、`scripts/extract-changes.py`、`Makefile`、workflow 自身。单 job `check-changelog-result` 直接跑 `make changelog`（包列表以 `Makefile` 的 `CHANGELOG_PKGS` 为单一事实源，等价于对每个包执行）：

```bash
cd <pkg> && python3 ../scripts/extract-changes.py "*.dtx" all -o CHANGELOG.md
```

再 `git add -N -- '*/CHANGELOG.md'`（覆盖新包首次生成、CHANGELOG.md 尚未被 git 跟踪的场景，否则 `git diff` 看不到差异）+ `git diff --exit-code -- '*/CHANGELOG.md'`。fail 时按上述三通道贴出期望内容。

`CHANGELOG_PKGS`（单一事实源：`Makefile` 的 `CHANGELOG_PKGS` 变量，workflow 经 `make changelog` 间接消费，无需同步第二处）：`ctex xeCJK xpinyin zhlineskip zhmetrics zhnumber`。xpinyin 随 #1041 测试接入补写了首条 `\changes{v3.2}{...}` 后加入这份列表。其余 3 个含 `.dtx` 的包（`CJKpunct`/`jiazhu`/`xCJK2uni`）目前没有写任何 `\changes` 条目，暂不参与；补写 `\changes` 后只需把包名加入 `Makefile` 的 `CHANGELOG_PKGS` 一行。

**占位符校验与新鲜度校验互补而非重叠（da00ad53）**：`check-changelog.yml` 在「重新生成 + diff」这道新鲜度校验之前，另加一道「`CHANGELOG.md` 不得含 `extract-changes.py` 的内部占位符（`\x00`–`\x05`）」校验。两者不是同一件事：`\texttt{... \cs{???} ...}` 这类嵌套里，内层 `\x00..\x01` 占位符被整段收进 `verbatim_blocks` 后再也扫不到，原始控制字符会直接写进 `CHANGELOG.md`（当时提交的 zhnumber 条目里就是 `Use of ^@???^A`）。这类漏出是**确定性**的——新鲜度 diff 对它没有判别力，因为两边生成物一致、只是两边都错。占位符校验实测：旧脚本下退出 1（含占位符），修好 `extract-changes.py` 后通过。

本地重新生成入口：`make changelog`（全部包）或 `make changelog-<pkg>`（单包，如 `make changelog-xeCJK`）。

已知接受的缺憾：详见 [[961-changelog-gate-no-write-perm]]。

## LaTeX2e 格式依赖声明

`ctex`、`xeCJK`、`zhlineskip` 在 `\NeedsTeXFormat{LaTeX2e}[...]` 中统一声明依赖 LaTeX2e 2026-06-01（PR #883）。该日期对应当时 LaTeX2e kernel 的发布快照；当 LaTeX2e 升级、kernel 在某些 token、命令钩子或字体接口上发生兼容性变化时，`testfiles` 基线会同步刷新（PR #882 为 2026-06-01 这批基线的批量更新）。

由此衍生的稳定约束：

- 当用户报告“同一份 dtx 在旧 TeX Live 上失败”时，先看其 `\NeedsTeXFormat` 行——本仓库声明的下限即是 2026-06-01，旧 TeX Live 直接不应被当作支持目标。
- 升级声明日期（如未来到下一个 LaTeX2e 快照）通常意味着一次成批的 `.tlg` 基线更新；这类基线 PR 不应被当成业务回归处理。

## 上游宏包版本漂移的识别与基线处置

#1048/#1050 排查 CI 红时发现两个独立的上游根因，都不是 LaTeX2e 内核整体升级（上一节覆盖的场景），而是单个宏包相对自己的发布节奏各自漂移：

- **l3backend 落后 l3kernel**：同属 expl3 的两个包本该同步发布，但当时 l3kernel 是 rev 79868／`2026-07-20`，l3backend 是 rev 78544／`2026-02-18`，相差五个月。CTAN 上的 l3backend 已经是 `2026-07-20`（与 l3kernel 同日），而 tlnet（TeX Live 网络仓库，`tlmgr update` 拉取的源）仍停在 rev 78544，所以 `tlmgr update` 拿不到新版本，只能等 tlnet 自己同步。注意 revision 号是 TeX Live 的打包序号，CTAN 侧没有这个号，两边只能靠包内日期戳对齐。
- **pgf**：`\pgfversiondate` 已是 `2026-08-01`，但 TeX Live 打包的 `cat-version` 元数据仍标 `3.1.11a`。

由此得到一条重要事实：**TeX Live 打包元数据会滞后于实际文件内容**。判断一个宏包的真实版本要看包内的日期戳或版本占位宏（如 `\pgfversiondate`、`\ExplFileDate`），不能只看 `tlmgr info <pkg>` 报的 `cat-version`——后者只是打包时写入的标签，可能已经过期。

pgf 这条漂移的机制：`pgfsys.code.tex:54-55` 的 `\pgf@sys@bp@correct` 改用整数运算 `(2*bp)*400/803` 并按符号补 1sp，源码注释说明动机是原先的换算「rounded to 0.99627 but that incurs a rounding error」，改为参照 l3kernel 的 `\dim_to_decimal_aux:w` 的做法。产出点是 `pgfsys-dvipdfmx.def:86` 的 `\pgfsys@hboxsynced` 中的 `\special{pdf:btrans matrix ...}`——即最终写进 PDF 的坐标数值。

**#1080 补两个同类实例，且这次是两个互不相干的根因同时撞在同一批 CI 红上：**

- **`tocloft`**：从 v2.3i（2017/08/31）跳到 v3.0a（2026-08-12），主版本号跳变，是发布方主动的版本升级而非 TL 打包滞后。影响 `ctex/test/testfiles/github472-03.lvt`／`github472-04.lvt`——仓库里唯一两个 `\usepackage{tocloft}` 的用例，四引擎全红。差异是每个页码后多出一对 `\kern -1.0` / `\kern 1.0`（LuaTeX 写作 `\kern-1.0` 无空格，形式相同），净宽度为零、相邻立即抵消，排版结果不变。
- **`fontspec`**：某版本起不再显式加载 `xparse.sty`（不再依赖它，改为直接使用 `xparse` 提供的能力而不 `\RequirePackage`，或已并入其它加载路径）。影响 `ctex/test/testfiles/files01.lvt`／`files02.lvt`——它们用 `\listfiles` 固定「加载了哪些文件」这份清单，只在 XeTeX／LuaTeX 上红（两者经 `fontspec` 加载字体；pdfTeX／upTeX 不经 `fontspec`，不受影响）。四份 diff 各只少一行 `xparse.sty`。

**两个成因在失败集合上呈现不同的引擎分布**（`github472-*` 四引擎全红，`files0*` 只两个引擎红），这本身就是「不止一个成因」的信号，排查时不能先找到一个成因就把另一组失败也挂在它名下——分布不同大概率是路径不同。详见反思 [[1080-upstream-tocloft-fontspec]]。

### 基线处置的分类判据

判断某个上游漂移触发的 `.tlg` 基线 diff 该不该刷，先分类根因：

- **会自愈的漂移不刷基线**。l3backend 这一类是 TL 打包侧暂时没跟上 CTAN，本质是「旧快照」而不是「上游改了行为」；一旦 tlnet 同步，数值会自己变回去。如果现在刷基线，等于把上游当前这个滞后快照里的（相对新版本而言）错误数值固化下来，TL 同步后又要改回来，白做一次。
- **上游有意修正且不会回退的漂移必须刷**。pgf 的舍入修正、`tocloft` 的主版本升级、`fontspec` 改变依赖加载方式都属于这一类：都是发布方主动的、面向未来的变更，不会被撤销。

这条判据是 `## LaTeX2e 格式依赖声明` 那句「升级声明日期通常意味着一次成批的 `.tlg` 基线更新；这类基线 PR 不应被当成业务回归处理」在「单个宏包独立漂移」场景下的推广——后者针对的是本仓库主动声明的内核版本整体上调，这里针对的是本仓库没有主动做任何声明、纯粹因为上游各宏包各自的发布节奏不同步而出现的局部漂移，判据从「声明变了就该刷」细化为「先分辨会不会自愈」。

**判定「必须刷」之后，还要逐份核对 diff 的具体内容，否则会把上游的新缺陷一起冻结进基线。** #1080 的两个实例都先确认了 diff 的内容性质才敢 save：`tocloft` 侧新增的**只有**净宽为零的 kern 对（8 份 diff 各 4 行新增、0 行删除，无任何非 kern 的新增行）；`fontspec` 侧**只有**文件名行删除（4 份 diff 各少一行，无其它变化）。没有节点丢失、没有数值变化、没有 ctex 补丁失效的迹象。若某份 diff 里除了这类「安全信号」还夹带节点缺失或数值变化，要先查本包对该上游包的补丁在新版下是否仍成立，不能直接 `l3build save`。

### 上游激活弃用（#1095）

l3kernel 2026-09-09（上游提交 `03b50f7e`、`17c031ed`）激活了两组早已宣布的弃用：`\cs_argument_spec:N` → `\cs_parameter_spec:N`，`\keys_set_filter:*` → `\keys_set_exclude_groups:*`。激活后，开启 `\debug_on:n { deprecation }` 或 `{ all }` 的测试一用到旧名就立即报错：xeCJK 的 `loading01` 用 `{ all }`，zhnumber 的 `deprecation01` 用 `{ deprecation }`。ctex 经 `checkdeps`（`ctex/build.lua:31`）加载仓库里的 zhnumber，因此 ctex 也跟着红。

识别方法：

- **不要只看 l3kernel CHANGELOG 的 Deprecated 条目。** 2026-09-09 条目里列出的 `\exp_after:wN` 在 `l3deprecation.dtx` 里的 patch 是注释掉的，调用它并不报错；只看 CHANGELOG 会把它误当成根因。
- **以已发布标签的 `l3deprecation.dtx` 为准。** 找出其中未被注释的 `\__kernel_patch_deprecation:nnNNpn` 行，按这些行里的旧名在全仓 `git grep`。#1095 这样查了 65 个旧名，只命中两处真正的问题，以及 `ctex/test/support/cleveref-body.tex` 里的 `\seq_set_map_x:NNn`，后者不会导致测试失败。

处置：

- 这类漂移不属于上一节判据里的两类：激活弃用是上游有意的变更，不是 TL 打包滞后，所以不会自愈；diff 的内容是报错而不是新的正确输出，所以也不该刷基线。正确做法是改用新名。
- 旧名只是新名的别名，改名不改变行为。
- 改之前核对新名的引入日期早于包声明的最低版本，否则在最低版本的环境里新名未定义。
- 修在 `master` 上：所有分支都受影响，不要只在某个功能分支里顺手改。
- 要写 `\changes` 并随新版发布。普通编译虽然不报错，但下游宏包若在开启调试检查的测试里加载本仓库的包，会与本仓库 CI 一样失败，而且下游自己修不了；上游将来删除旧名后，普通编译也会报错。#1095 中 xeCJK 记在 v3.10.7，zhnumber 记在尚未发布的 v3.1。

本地复现需要新版 l3kernel 的格式文件，做法见「往 check 环境注入替代版本的上游宏包（localdir）」一节末尾。详见反思 [[1095-l3kernel-activated-deprecations]]。

### 两条操作细节

- **不能靠正则替换数字更新 `.tlg`，必须让 l3build 重新生成**。实证是 `beamer01` 的 `2000.0` 出现次数从基线 8 次降到 4 次，成对的 push/pop 数量也随之变化——手工改几个数字看起来能让 diff 变小，但改不出正确的节点结构。
- **关掉断言不是刷基线**。`fntef-phase01` 曾被改成把五条 `PASS: ...` 换成 `PHASE-CHECK-PENDING`，这等于删除了校验，而它在配对版本（backend 与 pgf 都是当时应有的版本）下本来是全绿的。刷基线的前提是让测试在正确环境下重新跑出真实结果，不是让测试不再报告结果。
- **同一包目录下 `l3build check` 不能并发跑。** #1080 排查时在跑全套 `check` 的同时另起了单用例 `check`，两者共用 `build/` 目录，先跑的那个报 `./build/check/part-format01.log: No such file or directory` 并 traceback 退出——看起来像测试失败，实际是自己造成的干扰；#1026 反思里记录过同族的坑（并行跑 `l3build save` 与 `l3build check` 互相清掉共享的 `build/test` 目录）。要真正并行，用 `scripts/check-parallel.sh`——它给每个引擎在独立子工作目录里跑，不共享 `build/`。

### 已撤除：`scripts/sync-l3backend.sh`（#1048/#1050/#1051/#1054 → #1074）

上游已把 `l3backend` 并入 `l3kernel`（latex3#1948，CTAN 2026-08-10 的 `l3kernel` 起生效），
错配从此不可能发生，脚本与三处调用已在 #1074 删除。这一小节保留下来，是因为其中几条机制
与具体上游问题无关、下次遇到同类情形要照用。

撤除时的实测依据（两种环境都成立）：

| 环境 | `kpsewhich l3backend-pdftex.def` 命中 | 两个日期 |
| --- | --- | --- |
| 只有新版 `l3kernel` | `tex/latex/l3kernel/` 那份 | 都是 2026-08-10 |
| 新旧两包共存（TL 尚未撤下旧包时的过渡态） | 仍是 `l3kernel` 那份（优先） | 都是 2026-08-10 |

也就是说无论 TL 有没有撤下旧 `l3backend` 包，脚本都恒空转并打出撤除 `::notice::`。**判断
撤除条件是否成立，要看 `kpsewhich` 实际命中哪一份，而不是看旧包在不在**——两份同名 `.def`
可以共存，日期还不一样。

另外 CTAN 的 `l3kernel.zip` 里只有 `.dtx` 与 `l3backend.ins`，`l3backend-*.def` 是 **TeX Live
打包时由 `.ins` 生成**的。所以「`.def` 文件名会不会消失」取决于 TL 怎么打包，不取决于 CTAN；
判断这类问题要看 tlnet 的 TDS 包，不能只看 CTAN 的公告或 zip。

删除范围共四类（同类措施撤除时照此清点）：脚本本身、三处 `run:` 调用（`_test-package.yml`、
`_check-doc-package.yml`、`release.yml`）、四处触发路径条目（`check-doc.yml` 的
`on.pull_request.paths` 与 `_all` filter、`test.yml` 的 `_all` filter）、以及本文档与
`guides/release-workflow.md` 的相应记载。

#### 仍然适用的部分

**同一个上游错配在两类路径上的表现完全不同，这决定了防御必须覆盖到哪些地方。**
regression 路径（`l3build check`）上它表现为 `.tlg` 红：`\special{pdf:bc [...]}` 从基线里消失，
变成 `\TU/lmr/m/n/10 1.0` 一类字符节点，12 个测试变红（见 `d7457624`）。doc／ctan 路径
（`l3build doc`、`l3build ctan` 的 typeset 部分）上它**不产生任何非零退出码**：编译成功，PDF
页数与体积正常，只在正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本。所以两类路径都要防御，但
**只有前者会自己报警**；后者事后无法从构建状态发现（#1051 就是这样漏到本地产物里的）。

**同类问题若再出现（例如另一对上游包版本错配），四步都不能省**：
比较版本 → 补齐并就地校验产物 → 让 kpse 看得见 → 核对生效。

- **注入位置选 `TEXMFHOME` 而不是各包的 `localdir`**。kpse 中 `TEXMFHOME` 优先于
  `texmf-dist`，一步覆盖所有包与所有引擎，且不往仓库工作树里写文件。`localdir` 注入
  （见「往 check 环境注入替代版本的上游宏包」一节）适合本地一次性对照实验；要在 CI 里覆盖
  test 的 6 个 caller、check-doc 的 9 个 doc job 与 release 那一处，就得每个包都处理一遍。
- **「让 kpse 看得见」这一步不能省，而且不能加条件**。往 `TEXMFHOME` 拷文件之后 kpse 未必
  看得见——CI 上 `TEXMFHOME` 解析到一棵带 `!!` 前缀的树，语义是只查 ls-R、绝不扫磁盘，所以
  必须无条件 `mktexlsr "$TEXMFHOME"`。完整机制、以及「刷过索引的那个 job 反而失败」这个
  反直觉后果，见 [[kpse-path-resolution]]。
- **把版本比较作为前置条件，而不是无条件安装**。上游追平后这一步自动变成空操作并打一条
  `::notice::` 提示可以删除，不需要靠人记得「上游修好了要来撤」。**撤除判据就是这条
  notice** ——这个设计在本次撤除时确实生效了。

**末尾那次核对不能是唯一防线。** 它确实挡住过坏产物，但它只能报出「注入未生效」这一种
结论——网络故障、zip 残缺、索引陈旧全都被归成同一句话，与真实原因无关，会把排查方向带偏。
#1054 的实证：`mirrors.ctan.org` 重定向到实际镜像后三次 `curl: (28) Timeout`，curl 最终仍
返回 0、`-o` 只写出空文件，脚本一路静默走到末尾才被 kpsewhich 拦下，报的却是「注入未生效」。
所以每一步都要在**发生处**校验自己的产物。

**下载失败要区分「资源已不存在」与「网络故障」。** 这一条是撤除过程中补记的：脚本对下载失败
一律报「这是网络/镜像问题, 重跑本 job 即可」。#1074 期间 CTAN 已移除 `l3backend`
（`l3backend.zip` 返回 **HTTP 404**），若那时 tlnet 恰好处于「`l3kernel` 已更新而 `l3backend`
仍旧」的过渡态，脚本会进入下载分支、三个 mirror 必然全部 404，然后报出那句误导性的「重跑即可」
——让人反复重跑徒劳的 job，而真相是「包已经不存在了，该删脚本」。实际因为 kpse 优先命中
`l3kernel` 那份而没撞上，但这种失败情况对任何「从上游下载单个资源」的步骤都成立：404／410 意味着
改代码，超时／5xx 才意味着重跑。

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

本节讲的是「怎么把文件装进 usertree」。装进去之后 **kpse 能不能看见它**是另一件事，取决于那棵树在 `TEXMFDBS` 里有没有 `!!` 前缀，且本地与 CI 的解析结果有结构性差异——见 [[kpse-path-resolution]]。

`tlmgr --usermode` 的边界：

- 不能更新 `tlmgr` 自身、不能更新引擎包（`xetex` / `luaotfload` / `latex-bin` 会显示 `mentioned, but neither new nor forcibly removed`，这是预期行为）。
- 引擎相关包要等冻结发行版（Homebrew 等）的 formula 升级，或者另装一份官方 install-tl。

### 本地测试失败的环境指纹检查表

这张表原先隐含的前提是「本地失败、而最新 master CI 全绿」；#1048/#1050 证伪了这条前提本身可能不成立——master 的绿有时只是因为它命中了一份比 PR 更旧的 CI 缓存快照，并不代表当前上游环境下代码仍然通过（详见前面 `.github/tl_packages` 维护约束一节里的 CI 缓存 key 语义）。因此更准确的说法是：**当本地 `l3build check` 失败、且已确认 master 与 PR 两侧 CI 缓存未分叉时**，先看 `.tlg` diff 的指纹：

| 指纹 | 含义 |
|------|------|
| 前几行出现 `LaTeX Warning: You have requested release '<日期>' of LaTeX` | 本地 LaTeX2e 内核 < 仓库声明的最低日期（通常即 #883 的 2026-06-01）|
| diff 出现 `\mathon` / `\mathoff` 节点 或 `$[]$` 风格 Overfull 标记 | 本地 LaTeX / hyperref / graphics 的 `\showbox` 实现旧版 |
| 引擎 banner 一致（如 `XeTeX 3.141592653-2.6-0.999998`）但包级 diff 大 | 不是引擎差异，是 LaTeX / hyperref / graphics 等包差异 |
| `\cleaders` + `\glue` 几何数值出现差异（如间距、周期宽度对不上） | 疑 l3backend 与 l3kernel 版本不匹配。`fntef` 用 `\cleaders` 铺重复图案，间距经 pt→bp 换算落到网格，对 backend 的舍入实现敏感 |
| `\special{pdf:btrans matrix ...}` 坐标末位变化（如 `0.3985 w`→`0.39851 w`、`2000.02579`→`2000.0`），或 luatex 下 `\pdfliteral origin` 输出变化 | pgf ≥ 3.1.12 的 `\pgf@sys@bp@correct` 舍入修正生效，这是上游有意变更，**不会回退** |
| `.tlg` diff 显示整份 `.log` 为空（`index ...e69de29`，所有行都是删除） | 编译在 `\START` 之前就出错，l3build 不保留 `\START` 之前的输出，diff 里看不到错误。先读 build 目录（ctex 是 `build/check/`，多数包是 `build/test/`）里对应的完整 `.log`，找第一个 `!`。测试若开了 `\debug_on:n`，优先怀疑上游激活了弃用（见「上游激活弃用（#1095）」一节） |
| 颜色、图形等后端 special 变成可见文本（如 `\special{pdf:bc [1.0 0.0 0.0]}` 变成排出来的 `1.0 0.0 0.0`） | `l3kernel` 与 `l3backend` 版本错配，后端函数签名不匹配使 `\use:c` 找不到目标。**同一根因在 doc／ctan 路径上不出现任何 `.tlg` diff**：编译 exit 0、PDF 体积正常，只在正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本（`xeCJK.pdf` 的 `\meta` 与 fntef 示例最明显），判别方式是 `pdftotext` 后检索 `gray 0`／`0gray`／`1.0 0.0` 并断言计数为 0，而不是看 `.tlg` |

出现前三条指纹应优先按“本地 usertree 同步”流程修，而不是当作业务回归排查。

出现第四、第五条（`\cleaders`＋`\glue` 几何、`btrans matrix` 坐标）时，先按上一节「上游宏包版本漂移的识别与基线处置」判断这次漂移该刷基线还是该等 TL 同步，而不是直接假定是本地环境问题。

最后一条要单独处置：它属于本地各包之间不自洽（详见下文），**并且没有基线可刷**——doc 路径上根本不存在 `.tlg`，而 regression 路径上的 diff 是错配造成的错误输出，刷进基线等于把缺陷固化。唯一的处置是补齐匹配版本的 backend（本地按「往 check 环境注入替代版本的上游宏包」或等 TL 同步）。CI 侧曾有 `scripts/sync-l3backend.sh` 负责这件事，已随上游把 l3backend 并入 l3kernel 而在 #1074 撤除；**若将来出现另一对上游包版本错配，照「已撤除」那一节记的四步重建即可**。

详见反思 [[873-880-meta-url-hbox-math-boundary]]、[[1048-1050-upstream-l3backend-pgf-baseline-drift]]。

### 往 check 环境注入替代版本的上游宏包（localdir）

要在不碰系统 TeX Live 安装的前提下，用某个替代版本的上游宏包重跑 `l3build check`（例如验证「上游某个版本是否已经修复某个问题」），必须把替代版本放进 `localdir`（即 `build/local`）。`l3build-check.lua:74-76` 的 `checkinit()` 会在每轮 check 开头把 `localdir` 里的文件复制进 `testdir`；这是唯一的注入点。

两个常见的放错位置都会导致假阴性：

- **直接写 `testdir`（ctex 是 `build/check`，多数包是 `build/test`）不行**：`checkinit()` 在复制 `localdir` 之前先执行 `cleandir(testdir)`（除非带 `--dirty` 选项），每轮开头都会把 `testdir` 清空，写进去的文件立刻被删。
- **设 `TEXINPUTS` 环境变量也不行**：`l3build-check.lua:850` 在拼编译命令的 preamble 时写死了 `TEXINPUTS=.` 加 `localtexmf()`，会覆盖调用环境里已设置的 `TEXINPUTS`，外部设置不生效。

**生效判据（这是本节的核心，缺了它「放错位置导致的假阴性」与「新版本确实修不好」在结果上完全一样）**：跑完 `l3build check` 后，核对测试目录里对应文件的日期戳或版本占位宏。例如验证 l3backend 时，核对 `build/test/l3backend-xetex.def`（ctex 因 `testdir = "./build/check"` 是 `build/check/l3backend-xetex.def`）里的日期戳，确认它确实变成了替代版本的日期，而不是停留在系统安装版本的日期。没有这一步核对，「注入没生效、测试其实还在用旧版本」与「注入生效了、新版本确实没修好」这两种情况的表现完全相同——都是「仍然报错」。

可复现的最小步骤（以验证某个 l3backend 候选版本为例）：

```bash
# 1. 从 CTAN 取目标版本的 l3backend 源码
#    注意路径是 required/ 而不是 contrib/（后者返回 404）
curl -sSL -o l3backend.zip https://mirrors.ctan.org/macros/latex/required/l3backend.zip
unzip -oq l3backend.zip

# 2. 解包出各引擎的 .def
cd l3backend && tex l3backend.ins

# 3. 复制进目标包的 localdir（该目录可能还不存在）
mkdir -p <pkg>/build/local
cp l3backend-*.def <pkg>/build/local/

# 4. 跑 check，然后核对日期戳（见上）
cd <pkg> && l3build check
# .def 里没有 \GetIdInfo，日期戳是 \ProvidesExplFile 的 {YYYY-MM-DD} 参数：
grep -m1 -oE "\{[0-9]{4}-[0-9]{2}-[0-9]{2}\}" build/test/l3backend-xetex.def   # ctex 看 build/check/
```

`checkinit_hook`（见「xpinyin 的注音回归（#1041）」一节）与本节手段目标不同，不要混用：`checkinit_hook` 是永久性的构建配置，让测试稳定使用工作树里的依赖包而不是系统 TeX Live（每次 check 都生效，是仓库长期维护的一部分）；本节的 `localdir` 注入是临时的对照实验手段，用于一次性判定某个上游漂移的根因，验证完成后通常就会移除注入的文件。
`tlmgr update` 报 `no updates available` **不等于**本地各包之间自洽：TLnet 上游包之间也可能处于不一致状态。#1046／#1047 期间遇到 `l3kernel` 已到 revision 79868 而 `l3backend` 停在 78544，其间 expl3 把后端接口从 `\__color_backend_select_<model>:n` 改成了 `:nN`，本地 l3backend 只有 `:n` 版本，`\use:c` 找不到就把颜色参数当文本排了出来，连带 11 项既有测试失败。这种情形只能等上游发布配套版本，或改用 `texmf-dist/tex/latex-dev/` 树里的对应文件核对。

**`localdir` 注入只对运行时才加载的文件有效**（如 l3backend 的 `.def`）。l3kernel（expl3）预载在格式文件里，放进 `localdir` 不会生效。要在本地用新版 l3kernel 复现（#1095），做法是从 CTAN 下载 l3kernel 的 TDS 包解到临时目录，把 `TEXMFHOME`、`TEXMFVAR`、`TEXMFCONFIG` 指向临时目录后用 `fmtutil-user` 重建格式，再在同样的环境变量下跑 `l3build check`。格式和缓存都写进临时目录，不改本机安装。要重建的格式与「本地 TeX Live usertree 同步」一节列的相同（latex、xelatex、lualatex、uplatex）；zhnumber 的 pdftex 还需要 pdflatex。`ctex/build.lua` 给 pdftex 指定 `format = "latex"`，漏编 latex 会让 ctex 的 pdftex 用例几乎全部报 `Mismatched LaTeX support files`。

```bash
tmp=$(mktemp -d); mkdir -p "$tmp/texmf" "$tmp/var"
curl -sSL -o "$tmp/l3kernel.tds.zip" https://mirrors.ctan.org/install/macros/latex/required/l3kernel.tds.zip
unzip -oq "$tmp/l3kernel.tds.zip" -d "$tmp/texmf"
export TEXMFHOME="$tmp/texmf" TEXMFVAR="$tmp/var" TEXMFCONFIG="$tmp/var"
for f in latex xelatex lualatex uplatex; do fmtutil-user --byfmt "$f"; done  # zhnumber 另加 pdflatex
cd <pkg> && l3build check   # 必须在同一个设了上述变量的 shell 里跑
```

验证顺序：先在未修改的代码上复现出与 CI 相同的失败，证明新格式确实生效，再验证修复。跳过第一步时，「环境没生效所以一直绿」与「修复有效」无法区分。

### 判断测试失败是否由本次改动引起
不要凭 diff 内容像不像自己改的地方来判断——颜色 special 变成可见文本，看起来就很像间距类改动的后果。可靠方法是**在同一环境下跑 master 并逐字节比对 diff 文件**：
# 1. 保存当前改动下的 diff
cp build/test/<name>.xetex.diff /tmp/after-<name>.diff
# 2. 暂存改动，跑同一组测试
git stash push -- <改动文件>
l3build check -q <name>
# 3. 逐字节比对（跳过前两行的文件名与时间戳）
diff <(tail -n +3 /tmp/after-<name>.diff) <(tail -n +3 build/test/<name>.xetex.diff)
# 4. 恢复
git stash pop
输出为空即证明该失败与本次改动无关。#1046／#1047 用这个方法确认了 xeCJK 侧 11 项、ctex 侧 3 项 beamer、`config-contrib` 的 elegantbook 共 15 项失败全部与改动无关。
详见反思 [[873-880-meta-url-hbox-math-boundary]] 与 [[../memory/reflections/1046-1047-meta-anchor-font-context]]。
