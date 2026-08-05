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
#1057 新增 `fntef-nest-linebreak01` 后，
当前为 123／123 通过。完整接口契约见
[[../memory/decisions/1010-boundary-register-public-api]]。

### 注册点的字体上下文与锚点出口的覆盖清单（`codedoc-meta-symmetry01`、`hyperref-anchor-ecglue01`，#1046／#1047）

`codedoc-meta-symmetry01.lvt` 用**真实的 `l3doc` 文档类**（不是自己模拟内层函数）固定 12 项断言（9 个 `\TEST` 块）：四种源码空格组合各自与 oracle `左\texttt{$\langle$name$\rangle$}右` 等宽、左右两侧单边贡献相等且均为 13.33pt、左边界带 `plus` 分量（用 `\badness` 正向断言，因为 `\hbox to` 的实际宽度恒等于目标宽度、结构上恒真）、CJK 参数仍保持 `\hbox:n` 隔离（#920 不回退）、`\Arg` 与 `\oarg` 外侧贡献一致、纯西文上下文仍保留源码空格语义。判别力已实测：把注册点改回内层 `\__codedoc_meta:n` 后 8 项失败，数值为 1.92pt（等宽字体 5.25pt 减正文字体 3.33pt）、15.25pt 与 badness 10000。

**既有的 `codedoc-meta-ecglue01` 对 #1046 零判别力**，不要据它判断该场景已覆盖：它自己用 `\cs_new_protected:Npn \__codedoc_meta:n` 模拟内层函数，**没有 `\texttt` 外层**，而 `\texttt` 正是这个缺陷的必要条件。这与 #1038 中既有 `tabular01` 因每行 `\\` 前有空格而零判别力属同一类：测试用简化替身模拟被测对象时，简化掉的那一层可能正是缺陷所在。

`hyperref-anchor-ecglue01.lvt` 固定 12 项断言（10 个 `\TEST` 块，编号与 `.tlg` 块序一致），覆盖 hyperref 行内锚点已注册的三个出口，另含带 CJK 可见内容的目标仍按 CJK–CJK 处理、`\hyperref` 链接间距不受影响、以及一项固定已知缺口的断言。三个出口的判别力实测**互不重叠**——去掉 `\Hy@raisedlink` 注册只有 TEST 1、TEST 2 失败，去掉 `\hyper@anchor` 注册只有 TEST 3、TEST 4、TEST 5 失败，去掉第三处包装只有 TEST 8、TEST 9 失败——这一点本身是「这三处是彼此独立的出口」的证据，分支级改动因此得到分支级断言。判别力说明在 `.lvt` 里按断言文字指代，不用块编号。

但要注意判别力互不重叠**只**能证明「这两处都在路径上」，不能推出「按什么分派」，也不能推出「只有这两处」。本测试的注释曾一度写成「非空目标走 `\Hy@raisedlink`、空目标走 `\hyper@anchor`」，经盲审用计数器包装两个命令实测后更正：空目标、CJK 目标、西文目标、数字目标四种 `\hypertarget` 形式的 `\Hy@raisedlink` 调用次数**均为 0**，两个分支都经 `\hyper@@anchor` 落到 `\hyper@anchor`。真正的区分依据是调用点——`\Hy@raisedlink` 承接无编号标题、caption、公式编号、脚注、`\bibitem` 与下游手工包裹的抬升锚点（ctxdoc 的 `\exptarget` 即属此类，TEST 1、TEST 2 的 `\TestTarget` 就是复刻它）；目录**条目**不走这条路，`\contentsline` 用 `\hyper@linkstart`／`\hyper@linkend`，与抬升锚点无关。要判断某个公开命令走哪条内部路径，必须读分派函数的分支并用计数器实测，不能按参数形态推测。

同一段表述后来又连栽两次，形态相同——都是从一个真实现象推出未经独立验证的解释：

1. 改对分派依据后写成「行内锚点有两个出口」。第二轮盲审用同一手段发现 `\__hyp_target_raise:n`（`\phantomsection`／`\MakeLinkTarget` 走它，编号标题锚点也经过它）是第三个出口。
2. 承认第三个出口后又写成「它不能用现成包装，需要新设计适配器」，把故障归因给 begin 钩子里的赋值，并据此把缺口写成已接受限制。第三轮盲审的隔离实验推翻了它：`\@@_boundary_hmode_transparent_begin:` 体内没有任何 `\spacefactor` 赋值（那个赋值来自 hyperref 自己的 `\Hy@SaveSpaceFactor`）；不挂任何钩子、仅做无花括号透传同样复现故障；把参数改成带花括号转发即回到 oracle。于是新增 `\@@_boundary_wrap_transparent_onearg_braced:NN` 关闭了缺口，原先断言「缺口仍在」的那一项改为正向断言（最终编号为 TEST 8、TEST 9）。

第四轮全范围复核又推翻了第三次修正后写下的「三个出口全部注册」：`\pdfbookmark` 经 `\hyper@anchorstart` 裸调用，四个候选函数里只有它计数为 1，`\pdfbookmark` 右侧仍缺 3.33pt。TEST 10 把这个缺口固定为断言，并且**文档从此不再给出出口总数**，只维护「已覆盖」与「已知未覆盖」两份清单——总数是一个连错四次的穷尽性断言，而两份清单各自都能被单条探针核查。

**写穷尽性断言（「全部」「三个」「只有」）或因果断言（「因为 X 所以坏」）之前，先问自己用什么手段排除了别的可能。** 隔离实验——去掉一个因素看故障是否仍在——往往一次编译就能定论。第三处包装的判别力也按这个标准实测了两种失败形态：去掉包装使三条断言各少 3.33pt，误用无花括号变体则同样三条失败但读数暴涨（42.83pt／15.0pt）。

**「实测过」要说清实测的是什么，并检查探针本身是否够用。** 本任务一处写着「去掉内层 capture 前后节点列表完全相同（实测）」，而当时做的其实是**宽度**比对。补做 `\showbox` 比对时我先用了单入口探针（`\hbox{左\Arg{name}右}`，预热行含 `\meta`），得到「无差异」，据此把「实测节点列表相同」写进了五处文档。收尾复核指出这不对：改用**同一个 `\hbox` 里放两个以上入口**的探针（`\Arg` 加 `\oarg`）即可看到差异——base 每个入口留有一对 `default` marker kern（±0.0002pt），改动后没有。单变量实验（只加回内层 capture）确认那对 kern 正由它产生。宽度与可见排版结果确实不变，所以实现无需改动，但断言必须改成「宽度与可见排版结果相同；节点列表少一对零效果 marker kern」。

两条可复用的教训：宽度相同不能推出节点列表相同；**节点级比对的探针里，预热与单一入口都可能掩盖差异**，同一容器内放多个同类入口才能暴露。

**手写 MWE 前先确认 `TEXINPUTS` 指向的 `.sty` 真的存在且是当前版本。** 本任务有一次把「注册 `\hyper@anchorstart` 会把已修好的两处拖回缺陷状态」写进了五处文档，实际原因是清理 `build/` 之后忘了重新 `l3build unpack`：`TEXINPUTS=.../build/unpacked:` 指向一个不存在的目录时，`xelatex` **不报错**，而是静默回落到系统 TeX Live 里安装的旧版 `xeCJK.sty`——于是所有读数都是修复前的值，看起来就像新注册破坏了已有修复。

这类失效尤其难发现，因为退化后的读数恰好等于该缺陷本身的值（都是 38.33002pt），与「注册引起退化」的预期完全吻合。防办法有两条：跑 MWE 前 `grep` 一个只存在于当前改动里的函数名确认 `.sty` 是新的（例如 `grep -c onearg_braced build/unpacked/xeCJK.sty`）；以及**任何「X 导致 Y」的结论都要跑一次去掉 X 的对照**——这次只要跑一遍不注册 `\hyper@anchorstart` 的版本，就会看到它同样是 38.33002pt，立刻排除因果。

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
修复版三个均为 0。缺陷态的报错条数取决于观察条件与文件形态（门禁带 `-halt-on-error` 只看到
首条；手动 `-interaction=nonstopmode` 则是一长串，且随是否合并、是否走 `regression-test`
框架而变），所以判据只用「缺陷版 rc 非 0、修复版 rc 0」，不引用具体条数。

两条边界必须记住，否则会误改：

- **该门禁固定的是「不报错」，没有固定 `\scan_stop:` 的占位语义。** 把替换值改成 `{ }`
  （删除）或 `{ $ }` 时本文件仍全绿。占位的理由（`&$x$` 的首类别判定）只有直接探针
  能验证，若要上门禁需要新增一个断言首类别结果的用例。
- **`\colorbox` 参数里放裸 `&`（如 `\colorbox{yellow}{&$x$}`）不能写进基线**：这本身就不是
  合法 LaTeX，不加载 xeCJK 也报错。实测**首条**是 `Missing } inserted.`，其后是一串对齐相关
  的连带报错（`Missing \cr inserted.`、`Misplaced \cr.`、
  `Extra alignment tab has been changed to \cr.` 等，具体序列随语境与列数不同；
  `Misplaced alignment tab character &.` 只在某些多列语境下出现，实测还取决于出错单元之后是否仍有可用的对齐列）。写文档时只钉「首条」
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

三项判别力均以变异实测确认，各自 rc 1：还原为两个通用钩子（outside 退化为 0.0pt）；删掉 `suspend`／`resume`（本项自设 `CJKecglue=5pt`／`CJKglue=1pt`，宽度由 63.19998pt 降为 59.19998pt，差 4.0pt；同时 `command-boundary01` 的 `scratch-hidden-CJK` 也失败，那里默认胶下的差值是 3.33pt，两者不是同一个量）；去掉 `\int_gdecr:N`（深度由 0 变 6）。完整决策见 [[../memory/decisions/1029-sbox-adapter]]。

`gh-assets:issues/1002/` 的四套外部矩阵每套包含 272 个单元；当前实现下 `false-default`、`false-custom`、`true-default`、`true-custom` 均为 272／272。#992 第 28 行的四个旧跳过已经改为实际断言。不过 #992 的公开活表仍只记录已合并实现：PR 合并后必须从合并提交重新运行矩阵，才能把对应红叉改成绿勾。完整决策见 [[../memory/decisions/1002-inline-math-boundary-oracle]]。

`xeCJK/testfiles/command-boundary02.lvt` 提供 15 个 paragraph/node oracle，锁定宽度比较看不见的节点语义：段落模式 box、带源码空格的 transparent、CJK link stream、ulem 外层非装饰 CJKglue、普通显式 elastic glue、词间空格同构 glue、`\null` 与赋值型 `\null`、`\cs` 的西文/CJK 末尾，以及 `\kern0pt` 处理方法。新增三项分别确认：盒内末尾大写字母后的源码空格变成 5pt `CJKecglue`；有源码空格时，`\null` 后的恢复链把显式 7pt glue 换成 5pt；没有源码空格时，7pt glue 原样保留。节点测试启用 `\loggingoutput`；FandolFang 等 lazy font family 必须在 `\START` 前预热，否则首次 fontspec Info 会污染规范化日志并在不同平台产生伪 diff。

TeX glue 节点不记录来源。已注册命令右侧若出现显式 `\hskip`，而它的自然宽度和 shrink 与词间空格完全相同，恢复逻辑就无法判断它是源码空格还是显式 glue。需要保留时，可在前面加 `\kern0pt`，也可以改变自然宽度或去掉 shrink。测试必须明确记录这项限制和处理方法；继续向前检查更多节点也无法找回来源信息。

`ref-ecglue01.lvt` 与 `ref-ecglue02.lvt` 继续专门覆盖 #991：无 hyperref 36 次、加载 hyperref 40 次，共 76 个比较，包含数字/西文、CJK、混合末尾、两种外围类别、四种源码空格、starred path、未定义引用和 `CJKspace=true`。每次 oracle/candidate 前只重置当前真实状态：`\g__xeCJK_last_node_tl` 与 `\g__xeCJK_glue_check_pending_bool`；#991 saved-node、颜色 pending 和 hyperref 专用 marker 均已删除。无 hyperref 的 `\@setref` 或 hyperref 的 `\real@setref` 由 auto stream 处理，内核 `\null` 由一般 post-transparent 路径保持透明。

`listings-color01.lvt` 另有 20 个逐格 direct-input oracle，覆盖 `\lstinline{...}` 的西文、CJK、两种混合首尾，以及 `\lstinline|...|` 的分隔符路径；每格分别比较 `00/10/01/11`，不能要求四个 oracle 宽度彼此相等。首次 CJK inline 的 lazy math 字体加载在 `\START` 前预热。

`colorbox-measure01.lvt` 锁定 #995：`\settowidth{...}{甲\colorbox{yellow}{乙}}` 离线测量前后，各构造两组相同源码的对照盒子（含 `\special` whatsit 的盒子、纯文本盒子）逐次比较 `\wd` 相等，确认颜色 push/pop 改为 `transparent` 注册后不再向 `\g_@@_last_node_tl` 写入可污染后续测量的全局状态。

`boundary-crossbox01.lvt` 检查 #996：`\@@_glue_check_expire_stale:` 在最外层恢复逻辑发现节点列表为空时清除过期的 `\g_@@_glue_check_pending_bool`，阻止它越过 `\hbox` 或 `\setbox` 分组。测试还覆盖同一盒子与不同盒子中的显式 glue、`\kern0pt` 处理方法、两个方向的源码空格处理，以及 `xCJKecglue=true` 下 #996 的两个相同盒子，共 9 个断言（8 个宽度断言和 1 个 pending 状态断言）。与 `command-boundary01` 的 `\BoundaryReset` 一样，这个测试直接读写 `\g__xeCJK_last_node_tl`、`\g__xeCJK_glue_check_pending_bool` 两个内部变量，以隔离各测试并检查变量的生命周期；它们不是公开 API，内部重命名时必须同步修改这些 `.lvt` 文件。

`siunitx-ecglue01.lvt` 锁定 #1000：`\unit`/`\qty`/`\num`/`\si`/`\SI` 五个命令、中文/西文上下文、`\unit` 可选参数变体与 `00/10/01/11` 四种源码空格组成 36 个单元，再分别运行默认/可区分间距和 `xCJKecglue=false/true`，合计 144 次宽度比较；math 内嵌用法另检查 capture 栈归零。预热段（`\OMIT`/`\TIMO`）先消化 siunitx 数学字体加载与旧名 deprecation 消息，避免污染规范化日志。

`xecglue01.lvt` 除了检查 `false/true` 的基本行为，还锁定 `xCJKecglue=<glue>` 与 `CJKecglue=<glue>, xCJKecglue=true` 的等价关系。这个小型断言保护简写入口，不重复整张命令边界矩阵。

证据分三层使用，不能互相替代：

1. `command-boundary01` / `ref-ecglue01/02` 的宽度 oracle 证明边界几何等价。
2. `command-boundary02` 与既有 `.tlg` 的节点 oracle 区分 glue、kern、box、math 和 whatsit。
3. `gh-assets:issues/992/` 的默认/可区分 glue MWE 与截图供人工审阅；它们是 issue 证据，不是包回归基线。

可视 MWE 的说明层不得再经过被测状态机。`\texttt{\detokenize{...}}` 仍受 xeCJK 影响，会让四种源码空格组合看起来相同；`\verb*` 又不能放入普通宏参数。稳定 harness 应让第一阶段从调用点直接扫描 starred verbatim 源码并显式标出空格，分隔符结束后再调用第二阶段测量 oracle/candidate。PR 上可以保存未合并实现的拟更新表；#992 活表必须等实现合并并从合并提交复验后再同步。

### `ctex` 主测试目录当前覆盖面

本轮扩展后的 `ctex` 主测试目录已形成几组稳定覆盖簇：

- `ctexset-*`：覆盖分组作用域、导言区设置、meta key、非法输入、空值重置、多键组合与覆盖顺序，例如 `ctex/test/testfiles/ctexset-scope01.lvt`、`ctex/test/testfiles/ctexset-preamble01.lvt`、`ctex/test/testfiles/ctexset-invalid01.lvt`。
- `cjkfntef-luatex01/02`：分别覆盖 LuaTeX 下后续 `CJKfntef` 请求被禁载且字体仍可配置，以及包先载入时触发 critical 的分支。fatal-path 测试截获目标 `\msg_critical:nnn` 后立即结束，避免继续进入已污染状态产生无关的 LuaTeX-ja 二次错误。
- `heading-*`：集中覆盖 heading key 簇，包括 `break`、`afterskip`、`beforeskip`、`hang`、`runin`、`afterindent`、`numbering`、`fixskip`、`pagestyle`、`aftertitle`、`titleformat`、`tocline`、`starred`、`longtitle`、`defaults`、`name`、`format/+` 追加语法与 `indent` 等；`heading-query01` 另以 `ctexbeamer` 覆盖 part/section/subsection 的编号、完整标签、编号开关、局部动态设置与分组恢复，已从“章节标题可用”扩展到“标题系统各键及公开查询接口的契约级回归”。
- `scheme-*`：覆盖 `scheme=plain` / `scheme=chinese` 的默认行为差异与标题输出差异，例如 `ctex/test/testfiles/scheme-plain01.lvt`、`ctex/test/testfiles/scheme-compare02.lvt`。
- 类与文档结构：`ctexrep01.lvt`、`ctexbeamer01.lvt`、`beamer01.lvt`、`beamer02.lvt`、`matter01.lvt`、`sub3section01.lvt`、`ctex-noheading01.lvt` 等覆盖 `ctexrep` / `ctexbook` / `ctexbeamer` 基础行为、`heading=true`、三级节、`frontmatter` / `mainmatter` / `backmatter`。
- 字体与字号联动：`autoindent01.lvt`、`ccwd-selectfont01.lvt`、`ccwd-zihao01.lvt`、`ziju-scope01.lvt`、`ziju-edge01.lvt`、`ctexsetfont01.lvt`、`zihao-sizes01.lvt`、`zihao-parindent01.lvt`、`fontfamily01.lvt`、`fontfamily02.lvt`、`cjkfamily-default01.lvt`、`cjkfamily-default02.lvt` 等覆盖 `\ccwd`、`\ziju`、`\CTEXsetfont`、`\zihao` 全尺寸、段首缩进与 CJK 字体家族切换；其中 `autoindent01` 以四引擎基线锁定 #402 的零缩进例外：启用非零 `autoindent` 后把 `\parindent` 置零并切换字号，结果仍为 `0pt`。
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

`zhnumber` 的 `pdftex` 输出与标准 XeTeX 基线存在差异，因此测试目录中保留了 `.pdftex.tlg` 专属基线，例如 `zhnumber/testfiles/basic01.pdftex.tlg`。

## 非典型测试模式

仓库中仍有一些老包或历史目录没有统一纳入 l3build 测试框架，但 `xeCJK` 已不再只是依赖 example 文档编译来验证功能。当前较新的独立回归测试覆盖面可以概括为：

- `ctex`：主干测试最完整，含多个测试配置。
- `xeCJK`：已有独立 `testfiles/`，专注 XeTeX 行为回归。
- `zhnumber`：已有独立 `testfiles/`，覆盖多引擎差异。
- `xpinyin`：已有独立 `testfiles/` 加 `testfiles-cjk/` 两套，分别覆盖 XeTeX/xeCJK 与 CJKutf8/pdfTeX 两条互不复用的适配路线（#1041）。

因此，修改 `xeCJK`、`zhnumber` 与 `xpinyin` 时，应优先运行各自目录下的标准 l3build 回归测试，而不是只依赖 `ctex` 的依赖链间接覆盖。

### xpinyin 的注音回归（#1041）

xpinyin 接入按 tag 构建发布包的自动化流程后，此前唯一的验证是 `check-doc.yml` 里 `l3build doc` 编得过手册——那只能说明 PDF 能生成，不能说明注音行为正确。#1041 补上了独立回归测试目录并接入各条 workflow；宏包代码本身未改动。

**引擎覆盖为什么是 xetex + pdftex，且两者都必须跑。** xpinyin 用 `bool_lazy_or:nnF { xetex } { pdftex }` 把 luatex 挡在 `\msg_critical:nn` 上（实测 lualatex 直接以 "Engine `luatex' is not yet supported" 中止），所以只有两条路线。而两条都必须测：包内 `\@@_adjust_xeCJK_hook:` 与 `\@@_adjust_CJK_hook:` 是两套互不复用的适配（字体选择、码位转换、接管 `\CJKsymbol` 的方式都不同），只测 xetex 会让 CJKutf8 那一半零覆盖。

**为什么必须分两个 `testfiledir`。** `l3build check` 把目录下每个 `.lvt` 都拿去跑 `checkengines` 里的每一个引擎，没有按文件指定引擎的机制；两条路线的用例混在一起会互相拿对方的引擎跑，并因缺基线报 "failed to find any reference or expectation file"。因此主目录 `xpinyin/testfiles/` 走 xetex，pdfTeX 那条线单独放进 `xpinyin/test/config-cjk.lua` + `xpinyin/testfiles-cjk/`，仿 `ctex/test/config-cmap.lua` 等既有专项配置的做法（跑法：`l3build check -c test/config-cjk`）。`config-cjk.lua` 把 `checkdeps` 显式清空——CJKutf8 路线不加载 xeCJK，不需要复制它的产物。

四个测试文件按观察通道分工：

- `xpinyin/testfiles/pinyin-tone01.lvt`（31 格）：声调数字到重音命令的映射，oracle 取直接写 `\=`、`\'`、`\v`、`` \` `` 的字面形式，比宽、高、深三个维度。
- `xpinyin/testfiles/pinyin-tone02.lvt`：用 `\loggingoutput` 固定 shipout 的实际字形，是正面证据，与字体度量是否巧合无关。
- `xpinyin/testfiles/pinyin-setup01.lvt`：`\xpinyinsetup` 中能用尺寸观察的六个键（`ratio`／`vsep`／`hsep`／`pysep`／`font`／`format`），用「改前 vs 改后」的差值而非绝对值。
- `xpinyin/testfiles/pinyin-scope01.lvt`：注音的开关与作用域，同样用 `\loggingoutput` 固定节点列表。改变格式而不改变尺寸的键也归这里——`multiple`（只给多音字拼音附加格式）、`format` 的着色效果（作用于全部拼音）与 `footnote`，因为尺寸比较对它们完全不可见。三个键都有「设 vs 不设」两格对照，缺了对照那一半就只固定了缺省值下的输出、而非键的语义：`footnote` 起初只写了缺省 `false` 下脚注不注音，终审盲审据此指出「设了 `footnote=true` 后脚注真的会注音」从未被验证，现补 9b 项（脚注拼音 3.19995pt，与正文注音的 3.99994pt 可区分）。`multiple` 与 `format` 互为对照且都必需：只有前者时，把两者的作用范围搞混（例如让 `format` 也只作用于多音字）不会被任何用例发现；基线用不同颜色（红／蓝）区分两者的 `\special{color push}`。

**按键的可观察量分文件，而不是按「键」这个概念聚在一起。** `multiple` 一度只写在 `pinyin-setup01.lvt` 的覆盖清单里、并由 `pinyin-scope01.lvt` 交叉引用指向它，但两个文件都没有它的用例——盲审把这条列为重要问题：读注释的人会以为该键有回归保护。真实原因是它改的是颜色而非尺寸，放在以宽高比较为手段的 `setup01` 里本就无法断言。现在它落在 `scope01`，判据是 `\special{color push rgb 1 0 0}` 进基线，并用三格对照（多音字「重」着色、单音字「文」同样设了键也不着色、不设键的「重」不着色）保证判别力：只写第一格时，把「是否多音字」的判断去掉也照样通过。变异实测两个方向都会红——无条件套用该格式时红色 push 由 1 变 2，完全忽略该键时变 0。
- `xpinyin/testfiles-cjk/pinyin-cjkutf8-01.lvt`：CJKutf8/pdfTeX 路线，覆盖上述前两类断言的等价内容。**这条线的尺寸断言比 XeTeX 那条弱**：T1 Latin Modern 下锐音、钝音、caron 的合成结果宽高全同（实测 ht 均 6.88875pt、wd 均 13.333pt），只有 macron 与「无重音」可区分，因此尺寸比较拦不住二／三／四声之间的对调——实测把 `\'` 与 `` \` `` 对调，该文件仍全绿而 XeTeX 四个文件全红。故补 TEST 6 用 `\loggingoutput` 固定实际节点作正面证据（T1 下一声／三声走 `\accent`、二声／四声是预组合字形，两者在基线里形态不同）。另注意该 config 的 `stdengine` 是 `pdftex`，基线文件名就是不带引擎后缀的 `.tlg`；早先误存的 `.pdftex.tlg` 从不参与比对，是个悄无声息的空基线。

**四条判别力教训**（本节最有价值的部分，均由「重新引入缺陷、确认它会变红」实测确认）：

1. **oracle 未切到候选同一字体族会让全部单元恒报 DIFF。** `\pinyin` 内部按 `font` 键选字体，若 oracle 用的裸重音命令沿用文档主字体，两者字体不同时比的就是两种字体的度量差，而不是「数字到重音的映射是否正确」——初版漏了这一步，当时的全部 24 格都报 DIFF。
2. **拼音字体缺字时会假通过。** 文档默认的 Latin Modern 缺 U+01D6（ǖ，lü 的一声）；候选与 oracle 同时缺同一个字符，尺寸仍然相等，该格看着通过、实际什么都没验证。改用 `DejaVuSerif.ttf` 后实测零 "Missing character"。
3. **只测带声调数字的 v 会漏掉 `\@@_replace_v:n`。** v 到 ü 的转换由两个各自判断 l/n 的函数分担：`\@@_num_to_tone_v:Nn`（带声调数字时）与 `\@@_replace_v:n`（不带数字时）。只写带数字的用例不够——实测把 `\@@_replace_v:n` 的 l/n 守卫整段删掉，前四组仍全绿。需要补「前面有数字音节、末音节不带数字」的写法（如 `ma1lv`）才能真正触发这条路径。
4. **`\xpinyin{长}{zhang3}` 要的正是数据库首选值，没有判别力。** 「长」在数据库里的首选读音正是 zhǎng，指定它与不指定读音的对照项输出完全相同，等于什么都没验证。必须挑非首选读音（cháng）才构成真正的对照。

**两条结构性事实**（一并写进注释，避免日后重蹈）：

- **注音汉字的宽度看不出拼音内容。** `\@@_make_pinyin_box:nnn` 把拼音放进 `\hbox_overlap_right:n` 这个零宽盒里，换读音乃至整段关掉注音，整盒宽度都不变（实测 `\xpinyin{长}{chang2}` 与 `\xpinyin{长}{zhang3}` 同为 10pt）。因此「用了哪个读音」「注音有没有生效」这类内容断言一律交给节点列表（`pinyin-scope01.lvt`），宽度维度只能确认「尺寸不受读音影响」这条不变量本身。
- **CJK 环境必须开在盒子内部。** 写成 `\begin{CJK}` 包住 `\hbox_set:Nn` 时，出环境后读到的三项宽高深全为 0pt（成因是 `\hbox_set:Nn` 的局部赋值被环境分组还原成 void——实测环境**内**读同一个盒子是正常的 12.75551pt，改用 `\hbox_gset:Nn` 则环境外也读到该值；不是汉字排不进盒子）——而 0pt = 0pt 会让「宽度不变」这条断言照样报 unchanged，看着像通过。CJKutf8 路线的测试因此把 `\begin{CJK}...\end{CJK}` 整体写在 `\hbox_set:Nn` 的参数内部。

**`\showbox`／`\box_log:N` 在 `-halt-on-error` 下会当场中止。** 三者都抛 `! OK.`，而 xpinyin 的 `checkopts` 带 `-halt-on-error`，会当场终止编译，其后用例静默不执行而 `check` 仍可能报绿。这个坑在 xeCJK 的 `verb-ecglue02.lvt`／`fntef-shrink01.lvt` 注释里也记着；xpinyin 的解法同样是一律用 `\loggingoutput` 读取 shipout 的实际节点列表。

**`checkdeps` 单独声明不够，必须配 `checkinit_hook`。** `xpinyin/build.lua` 的 `checkdeps = {"../xeCJK"}` 只保证依赖包先被 `unpack`，产物留在依赖包自己的 `build/unpacked/` 里，kpse 搜不到——`\usepackage{xeCJK}` 仍会命中系统 TeX Live 的版本。实测不加 `checkinit_hook` 时，测试日志里的路径是 `texmf-dist/tex/xelatex/xecjk/xeCJK.sty`。修法是用 `checkinit_hook` 手工把依赖包产物复制进本包的测试目录。`checkinit_hook` 与「本地 TeX Live usertree 同步」一节里 `localdir` 注入手段的目标不同，不要混用：这里是永久性的构建配置，让测试稳定使用工作树的依赖包而非系统 TeX Live；`localdir` 注入是临时的对照实验手段，用来一次性判定某个上游漂移的根因。

**复制清单必须取依赖包自己的 `installfiles`，照抄 `ctex/build.lua` 会漏文件。** `ctex/build.lua:72-80` 的钩子遍历的是**本包**的 `installfiles`；那里能工作纯属巧合——`ctex` 自己的 `installfiles` 恰好覆盖了各依赖的**运行时**产物类型。（按字面并不是超集：`ctex` 只有 `ct*.tex`／`zh*.tex`，接不住 `xeCJK` 的 `*.tex`，实测漏掉 `xunicode-symbols.tex` 与 12 个 `xeCJK-example-*.tex`；那些是手册示例，不参与运行时加载，所以 `ctex` 侥幸没被这一点咬到。）xpinyin 照抄后就漏了：本包是 `{"*.sty","*.def","*.ins"}`，而 `xeCJK` 还装 `"*.cfg"`，于是出现只复制了一半的分裂状态——`xeCJK.sty` 用工作树版本（日志显示 `./xeCJK.sty`），`xeCJK.cfg` 却仍命中 `texmf-dist/tex/xelatex/xecjk/xeCJK.cfg`，而那份是 v3.10.4、工作树是 v3.10.5，`\GetIdInfo` 与版本号行都不同。**这恰好破坏了该钩子声称要消除的「测的其实是本机装了什么」**，且症状隐蔽：测试全绿，只有对比日志里两个文件的路径才看得出来。这类缺陷是盲审在终审轮以 blocking 级查出的。现行做法是用 `loadfile` 在独立环境里读依赖包的 `build.lua`、取它自己的 `installfiles`（用 `loadfile` 而非 `dofile`：后者在全局环境执行，既无法隔离也无法用 `pcall` 兜住），并设两道**拒绝**判据——读不到或不是表则 `error`、空表则 `error`；`pcall` 的错误对象不构成判据（它不拒绝任何东西），而是在这两道判据触发时随 `error` 一并报出，作为线索；不硬编码第二份清单，否则依赖包将来新增产物类型时会再次静默漏掉。`xeCJK` 现在必然在 `require("zip")` 处中断（空环境里 `require` 为 nil），这是预期的，`installfiles` 在那之前已赋值；但错误必须可见，否则将来失败点前移到赋值之前时无从发现。

**已接受的残留缺口有两个**，都如实记下：（1）若依赖包改成分步构造 `installfiles`（先赋字面表、中途出错、之后再追加），得到的残缺表会同时通过「是表」与「非空」两道判据，只复制一半而不报错；（2）判据只看这张表，**不看每条 glob 是否真的匹配到文件**——`xeCJK` 的 `"*.map"`／`"*.tec"` 在 `check` 路径下必然零匹配（那两类产物由 `unpack_posthook` 在 `install_files_bool` 为真时才经 TECkit 生成，而该标志只在 `install_files` 里置真），`cp` 静默复制零个文件并返回 0。缺口二今天不触发，因为 xpinyin 现有测试都不用 `Mapping=` 一类需要 `.tec` 的写法；但将来加了就会命中系统 TeX Live 的那份。两者都实测确认。不再收紧的理由：更严的判据要么预设依赖包的写法、反而更脆，要么（对缺口二加零匹配 `error`）现网就会当场失败。`cp` 的 errorlevel 现已检查（复制真失败即 `error`，而非静默继续拿系统那份去测）。防线是失败时随 `error` 一并报出的 `pcall` 错误，加上「新增依赖、依赖包重构、或新增用到 `.map`／`.tec` 的测试时，逐个核对测试目录里每类产物的实际加载路径」这条人工步骤。

**盒高比较取「总高」时容易写成恒真断言（#265 / PR #977）。** 给 `\disablepinyin*` 补退组恢复的用例时，初版把「禁用用的子分组」和「组后要观察的那个字」放进同一个盒子，再与单个未注音汉字比总高。实测把 `\bool_set_false:N` 改成 `\bool_gset_false:N`（即禁用泄漏到组外、组后那个字也不再注音）时，该盒**仍然更高**（8.46454pt vs 8.39754pt）——多出的高度来自盒内其他内容而不是拼音，于是 `>` 比较照报 `restored`，这一项等于没有断言。修法是让被观察的字**单独装盒**，并同时对两个方向取证：与「从未禁用过」的盒子比**等高**、与「未注音」的盒子比**更高**。基准也必须取另一个从未禁用过的盒子——拿变异后的两个值互比，它们会同为 8.39754pt 而仍然相等。这与「注音汉字宽度看不出拼音内容」是同一类问题：**观察量必须只随被断言的那一件事变化**，混进无关内容就会被无关内容的贡献掩盖。（另一个坑同源于上文 CJK 环境那条：`\hbox_set:Nn` 写在 CJK 环境内部时该盒 `ht = 0pt`，也会让比较失去意义。）

### xeCJKfntef 的相位、装饰单元与视觉验证（#531/#967/#1012）

xeCJKfntef 的线条问题要区分三件事：leader 原语怎样排列装饰盒、`ulem` 怎样决定片段和端点几何，以及最终页面怎样渲染。`\leaders`、`\cleaders` 与 `\xleaders` 可以拥有完全相同的 glue、盒宽和命令总宽，却把重复盒画在不同横坐标；节点宽度相同不能证明相位相同。

#1012 用普通 `\leaders` 统一默认波浪和斜线的相位，再分别处理可见端点和断行接点。两个图案都由 `l3draw` 按 `1em/4` 绘制，常规全角字符约容纳四个单元；正文片段、固定或伸缩后的 `CJKglue` 和换行后的片段共享同一个 leader 网格。首段和真正的末段通过局部 PDF 裁切精确限定可见范围：普通形式左右各外伸半周期，带 `-` 形式左右各内缩半周期。相邻带 `-` 命令之间因而恰有一个周期断口；首段后的可断 `CJKglue` 用断点两侧各一个净宽为零的半周期连接。普通 `\quad` 和显式 `\hskip` 仍按 `ulem` 原路径装饰，自定义 `underwave/symbol` 保留历史 `\xleaders` 路径。默认斜线约高 `.93em`，使用时下移 `.09em`，使图案同时覆盖常见汉字的 height 和 depth。

含 PDF 绘图路径的可见问题用四类专项证据验证，再做一次整本文档集成构建。不要把完整绘图 special 全部写入节点基线，也不要为每次局部调整反复编译整本手册：

1. `fntef-underline-offset.lvt` 直接构造真正的 `l3draw` 波浪和斜线盒子，固定 8pt、10.53937pt、15pt 下的宽、高、深。这一层证明实际周期宽度确实是 `1em/4`、斜线约高 `.93em`，并随字号缩放；还检查普通／带 `-` 形式的空参数和不产生节点的正文保持零宽、零高、零深，避免 `ulem` 的结尾语法空格被裁切结构变成可见装饰。四组波浪／斜线、普通／带 `-` 的嵌套组合把单片段内层命令放在外层末尾；测试拦截 `\@@_ulem_periodic_right_skip_aux:`，要求只有已经产生后续片段的外层命令触发一次末段重画，从而固定嵌套状态的压栈和恢复。
2. 节点和换行回归把波浪和斜线临时换成同尺寸的轻量规则盒子，检查默认普通 `\leaders`、自定义波浪的 `\xleaders`、裁切结构、普通与带 `-` 形式、相邻命令、标点、换行、实际伸缩的 `CJKglue`，以及普通 `\quad` 仍被装饰。换行测试还比较正文字符和盒子、断点、行宽、glue set 及 PDF 图形状态在断点两侧分别闭合。规则盒子避免 `.tlg` 被数千行 PDF 绘图 special 淹没，但不能证明页面上的实际坐标。
3. `fntef-phase01.lvt` 先生成 XDV；`xeCJK/build.lua` 的 `runtest_tasks` 再调用 `xdvipdfmx -z 0` 生成不压缩内容流的 PDF，随后由 `testfiles/support/fntef-phase-check.lua` 读取标记、裁切边界和图案盒的实际横坐标。32 行校验固定所有周期盒处在同一个普通 leaders 网格；普通形式左右各外伸半周期，带 `-` 形式左右各内缩半周期，两种形式命令宽度一致；每个普通命令只有一段连续覆盖；固定和伸缩 `CJKglue` 连续；相邻带 `-` 命令之间恰有一个周期断口；普通显式跳距仍被装饰。Lua 检查将五项 PASS 写回日志，由 `.tlg` 固定结果。
4. 从手册示例提取精确单页 MWE，保留 Noto Serif CJK SC Regular、TeX Gyre Pagella、约 10.53937pt 正文字号及原示例内容；再用字体、字重、8pt／10.53937pt／15pt 和实际伸缩胶水的补充矩阵检查装饰长度、居中、连接和视觉密度。高分辨率图是这一层的主要证据。

专项验证通过后再运行一次 `l3build doc`，确认修改没有破坏整本文档的集成构建。当前实现的 xeCJK 标准测试为 123／123，文档构建生成 249 页 `xeCJK.pdf` 和 51 页 `xunicode-symbols.pdf`（页数随 `\changes` 条目增长，属预期漂移）。整本文档构建只能证明 PDF 能生成，不能自动判断局部装饰是否连续。

从源码树编译 MWE 时，必须检查日志实际加载的 `xeCJKfntef.sty` 路径，确认它来自当前工作树的生成目录，而不是系统 TeX Live 中的旧版同名文件。输出目录名和运行命令不能替代这项检查。

常见全角 CJK 字体和字重在同字号下通常不改变一 em 字宽及 leaders 几何，主要影响异常是否醒目；字号、非一 em 字宽、标点、特殊盒子和实际伸缩胶水则会改变片段宽度或余数。因此，自动回归不必复制完整字体矩阵，但必须覆盖真实字号、单元比例和实际使用伸缩量的断行；视觉抽样再加入 Serif／Sans、Regular／Black 等少量对照。xeCJK 标准测试当前为 123 项。

### tabular 中的 CJK 与换行命令（`tabular01`，#1038）

`tabular01.lvt` 的 TEST 1／2 早已存在，却对 #1038 **零判别力**——它们每行 `\\` 前都有一个源码空格（`姓名 & 年龄 \\`），走的是 CJK→NormalSpace 路径，不进 `\@@_boundary_group_math:w`；实测缺陷版下该文件全绿。TEST 3（#1038 新增）补上「`\\` 紧邻 CJK」的写法，判别力实测 rc 1：还原抓参数形式后 TEST 3 报 `Improper alphabetic constant`，TEST 1／2 零命中。

#1038 共新增两个独立文件。`tabular-cr01` 固定 `\\` 的相邻写法（`&` 之后、`\\[2pt]`、末行）；`boundary-bgroup01` 固定同一修复的附带改善：`中\bgroup $x$\egroup 文` 由 29.04527pt 变为 32.37527pt，与显式花括号形态及无分组 oracle 一致（判别力实测 rc 1，缺陷版回到 29.04527pt）。

**两者都必须独立成文件。** 起初它们是 `tabular01` 的 TEST 4／TEST 5，但 `tabular01` 的 TEST 3 在缺陷版下以 `Improper alphabetic constant` 中止编译，同一文件里其后的用例根本不执行——实测缺陷版日志里 `TEST 4` 出现 0 次。那样的用例在缺陷版里连输出都没有，判别力无法观察，是看起来正规实际空转的校验。

**「多个复现用例必须分文件跑」不只是排查时的注意事项，而是测试设计约束**：每个能独立触发该缺陷的用例都要有自己的文件，否则第一个报错就把其余全部变成假绿。三个文件现各自具备判别力（逐个实测缺陷版 rc 1）。

顺带更正一条长期记错的事实——`\bgroup` / `\egroup` **同样**触发 Boundary class。原因不是它被展开成花括号（它是隐式字符记号、不可展开），而是 XeTeX 的判据是 `get_x_token` 展开后那个不可展开记号的 catcode：只有 letter / other / `\chardef` / `\char` 用字符自身类别，其余一律 Boundary，catcode 1 不在其中。

**测试样例里的空白决定走哪条代码路径**，不是排版细节。写 xeCJK 用例时「CJK 紧邻 X」与「CJK 空格 X」是两个必须分别覆盖的象限。

另有两条与复现方法有关：

- **多个复现用例要分文件跑。** 同一文件里前一个用例报错会中止编译，后面的用例静默不执行而看起来「无错误」。#1038 排查时一个 10 用例的单文件矩阵曾因此显示 master 上 0 错误，逐个拆开后才看到 3 个真实失败。
- **触发面要逐写法实测，不能按名义推广。** 本缺陷只影响 `tabular` 系（含 `\\[2pt]` 与 `&` 之后）；`array`、`align`、`pmatrix`、`tabularx`、`array` 宏包列型、`\halign`、`center`、`minipage` 从未受影响，因为数学与 `\halign` 路径直接用 `\cr`，不经过 `{\ifnum0=`}\fi` 这个平衡技巧。

### ulem 正文外层收缩量回归（`fntef-shrink01`，#1026）

`fntef-shrink01.lvt` 固定 `\UL@on` 把正文交给 `ulem` 前必须保留字面记号这条约束（注意只覆盖 `\UL@on`，`\UL@onin` 见本节末尾）（架构见 [[../architecture/xecjk-architecture]] 「ulem 集成层的正文必须以字面记号留在替换文本里」一节）。测试覆盖 `\CJKunderline`、`\CJKunderwave`、带减号形式，以及重排路径的两个不同侧面；前四组都在 `document` 主垂直列表里让 `\hsize=200pt` 的段落真正断行，只固定行盒尺寸与 glue set，不比对装饰图形。TEST 5 是例外：它用 `\setbox` 加 `\box` 而非段落断行，并固定完整节点列表，因此会对装饰结构与 PDF 标记的改动敏感（实测改 `ActualText` 值只会让 TEST 5 失败，是它独有的敏感面；改装饰线粗细则五项全失败，因为线粗会改变行盒高深，不算 TEST 5 专属）。这是必要代价，只有节点列表能拦住“宽度不变而装饰已消失”的实现。

判据在 #1037 后改为「无 `Overfull` 记录」。溢出量随修复进度有三个取值：#1026 缺陷版 18.08pt、只修词后 3.64pt、词前词后都修好后无溢出。原先的判据写作「修复后为 3.64pt」，把残留缺陷冻结成了预期基线——四个用例各固定一条 3.64pt 的 `Overfull` 行，等于替同源的另一半缺陷（#1037）背书，使它长期看起来「有校验在管」。**把一个非零的缺陷量写进基线时，必须在注释里说明它为什么不是零、以及零需要什么条件**，否则观测值会被后来者当成规格。

重排路径需要两项各自独立的用例，缺一不可：

- **含西文词的“公式尾＋尾随空格”正文**，用来量重排路径本身有没有保住外层收缩量。只写 `\CJKunderline{中文 $x$ }` 分辨不出这一点：没有西文词就不会补出 `\CJKecglue`，把重排条件恒置为假也照样通过。
- **不含西文词的“公式尾＋尾随空格”正文**，用来固定尾随空格仍被装饰。这一项不能依赖 overfull 报告：内容短、不触发溢出，基线会是空的，等于什么都没固定。它改为两层观察：先报同一正文在有／无尾随空格下的宽度差（3.33pt），再把盒子交给 `\loggingoutput` 输出完整节点列表。只报宽度不够——把空格换成等宽 `kern` 时宽度完全相同，必须让末段 `\cleaders` 本身进入基线才能证明那一段确实被装饰。漏掉交还空格时总宽从 32.37527pt 降到 29.04527pt、末段 `\cleaders` 从 11.04524pt 缩到 7.71524pt（片段数不变，都是 5 段），两种变异实测都会让基线失败。注意此处不能用 `\showbox`：`checkopts` 带 `-halt-on-error`，`\showbox` 抛出的 `! OK.` 会当场终止编译，其后用例静默不执行而 check 仍报绿（同一个坑记在 `verb-ecglue02.lvt` 的注释里）。

「重排是否发生」由上述节点列表一并固定：把重排条件恒置为假时该项基线失败（实测 rc 1），`command-boundary-math05` 的 `stream-ulem` 末状态也失败，两者互为交叉验证。需要强调的是这条归属经历过两次修正——起初该用例的 `.tlg` 是空的、什么都没固定，中途只固定总宽度时也仍分辨不出；只有把节点列表纳入基线后它才真正守住。为一条行为指定守护测试时，必须用变异实测确认是哪个测试真的会红，而不是按测试名义职责推断，且每次调整观察通道后都要重新确认一遍。

这个测试的设计约束具有可复用性，不止适用于本次缺陷：

- **必须让段落真正断行，不能只装进单个 `\hbox` 或 `\vbox`。** 单个盒子内部的 glue set 会把内外层的可伸缩量一并用掉，缺陷版与修复版会得到完全相同的数字；只有把正文放进主垂直列表、让 `\par` 真正决定断行时，内层片段盒固化的收缩量差异才会体现为不同的行盒尺寸。
- **调用处必须写字面正文，不能用宏承载正文（如 `\CJKunderline{\BODY}`）。** 宏体在 `ulem` 扫描期间才展开，触发的是“调用处写宏”这条已被接受的既有限制，而不是本次要验证的回归；发布版本（系统 TeX Live）对这种写法同样得到修复前的溢出宽度。用宏承载正文会让缺陷版和修复版再次得到相同数字，把两条不同的收缩链路混为一谈。
- **必须用重新引入缺陷的方式确认测试会失败，通过本身不构成证据。** 该测试的前三版草案（`\hbox` 量 badness、`\vbox` 排段落、`\def\BODY` 承载正文）都显示“通过”，但都是因为选错了载体而抹平了内外层区分；只有在改回旧实现后主动看到测试失败，才证明新增回归确实能检测这个缺陷。回归测试写完后应当养成“故意还原到修复前状态，确认它会红”的检查步骤。

TEST 6（#1037 新增）是词前 ecglue 的正向断言。前四项以「没有 `Overfull` 行」为判据，这是必要的但偏弱——它不能区分「收缩量回到了外层」与「行恰好因别的原因不溢出」。TEST 6 直接测量可收缩量：把含「源码空格 + 西文词」的正文压窄，用 `\badness` 观察。

**不能用 `\hbox to` 的实际宽度作判据**：`\hbox to` 总会取到目标宽度，`\wd` 减目标宽度恒为 0，与收缩量在哪里无关，是结构上恒真的断言（第一版 TEST 6 正是这么写的，生成基线后才发现真正的信号在旁边那条 `Overfull ... detected` 里）。压窄 2pt 落在「只修词后」的 1.11pt 与「两半都修」的 2.22pt 之间，正好把两种实现分开；另加压窄 1pt／5pt 两个对照，证明 badness 0 不是恒真、1000000 可达。判别力已实测 rc 1：把 `\@@_use_ecglue_skip:` 改回 `\skip_horizontal:N` 后，2pt badness 由 73 变 1000000，前四项的 `Overfull` 行全部回到基线。

TEST 7（同样 #1037 新增）固定的是**守卫**而非收缩量：在装饰之外重定义 `\ `（模拟 `nath`／`morehype`），再排普通中西文混排 `中 abc 文`。因为词前 ecglue 的入口位于所有中西文边界都会走的通用路径上，改写若只依赖 `\@@_ulem_glue:n` 自带的 `\xeCJK_if_ulem_patch:TF`，就会在装饰外的普通正文里执行 `\UL@stop` 而报 `Too many }'s`——与是否使用装饰命令无关。判别力已实测 rc 1：去掉 `\l_@@_ulem_stream_started_bool` 守卫后**只有** TEST 7 失败（基线出现 `\UL@stop ... \egroup \egroup` 报错行），前六项全部照常通过。这是「同一入口的两种失效方式需要各自的用例」的具体例子：TEST 6 管收缩量搬没搬出去，TEST 7 管搬的时机对不对。

TEST 10（#1037 新增）覆盖第四处路径（`\xeCJK_check_for_glue:` 的 math 分支，`$x$中文`）以及 `\@@_check_for_glue_auxi:` 的两个分支。**一个 `dim_case` 里的每个分支各自需要一条断言**：`default`（末节点是 Default 类，`\mbox{hi}中文`）与 `math`（末节点是 math marker，`\mbox{$x$}中文`）是两条独立路径，只写前者时后者可达且实现正确却毫无校验——逐分支变异实测，只改回 math 分支时全套 115 项仍全绿。三条断言现各自具备判别力（逐分支变异均 rc 1，TESTs 1-9 零命中）。

TEST 9（#1037 新增）覆盖同一根因的第三条路径：`\@@_recover_ecglue_source_space_success:` 与 `\@@_check_for_glue_auxi:`（西文词被字体／颜色声明隔开时走这两处）。**必须用 `\color` 形态**——实测 `\bfseries` 形态在这两处改动前后都是 2.22pt（根本不走这条路径），拿它做断言会得到恒真的测试；第一版 TEST 9 正是这么写的，撤销修复后仍通过。改用 `\color` 后判别力实测 rc 1（badness 73→1000000），且 TESTs 1-8 零命中。该用例同时把显式分组写法的已接受限制固定下来（`braced-shrink-by-2pt-badness=1000000`、`1pt=73`）。

两条与 `.tlg` 基线写法有关的坑，都是在 #1037 的审查中踩到的：

- **`l3build` 不归一化单数形式的 `detected at line %d`。** `l3build` 归一化的是 `on line %d*`、`on input line %d*`（`l3build-check.lua:210,211`）、`at lines %d*--%d*`（`:217`）与行首的 `l.%d+ `（`:144`），Overfull 的单数形式不在其中。`\hbox to` 触发的 Overfull 报告用的正是单数形式，一旦进基线就冻结了一个绝对源码行号——在 `.lvt` 里插入一行无关注释即失败。因此凡是观察量不是报告文本本身的用例，都应当把报告抑制掉，不要让它进基线。
- **抑制 Overfull 报告要用 `\hfuzz`，不是 `\hbadness`。** `\hbadness` 只管 Underfull 警告的阈值；实测默认值与 `\hbadness=10000` 都照样输出 Overfull，`\hfuzz=100pt` 才消掉，而三种设置下 `\badness` 都不变（即观察量不受影响）。

重排路径交还的那枚尾随空格仍落在最后一个片段盒内部，外层收缩量因此比发布版少 1.11pt（发布版 9.44pt、回归基线 8.33pt、修复后 8.33pt+2.22pt 中属于西文词的部分已恢复）。改走 `\@@_boundary_use_ulem_glue:n` 外层通道能补上这 1.11pt，但会让该空格对边界机制变得可见而被计算两次，实测 `command-boundary-math01` 报 3.33pt boundary delta 失败、`command-boundary-math05` 的 `stream-ulem` previous 从 0.0pt 变 3.33pt，故不采用。这是已接受的限制，详见决策 [[../memory/decisions/1026-ulem-literal-body]]。#1037 未改变这一点：它只改补 ecglue 的通道，不涉及重排路径剥离／交还源码空格的逻辑，TEST 5 的节点列表与宽度差在 #1037 修复前后逐字节相同，可佐证重排路径未被触及。

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

xeCJK 标准测试因本文件从 122 项增至 123 项，当前为 123／123 通过。

### xeCJKfntef 的 PDF 文本语义（#1017）

`fntef-actualtext01.lvt` 覆盖下划线、双下划线、波浪线、删除线、交叉删除线、自定义线条、着重号和自定义符号八类入口，检查每个装饰盒都使用空 `ActualText`，并在 tagged PDF 下成对暂停、恢复 tagging。这个回归固定的是实现机制；它不能单独证明实际阅读器或提取工具得到的文本正确。

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
- `.github/workflows/release-ctan-upload.yml`：CTAN 正式投递工作流（stage 2），仅 `workflow_dispatch`，按包进 `ctan-release-<module>` environment 门控，详见 `llmdoc/guides/release-workflow.md`
- `.github/workflows/agentic-pr-review.yml`：本地 PR 自动审查实现，由 `pull_request_target` 触发；Draft PR 不会被跳过，打开、推送新提交或重新打开时与普通 PR 一样进入审查；Codex `gpt-5.6-sol` 是主链路，Claude Code `claude-opus-5` 是独立 runner 上的兜底，不运行 Agent 的发布 job（publisher）代发评论
- `.github/workflows/agentic-issue-dispatch.yml`：本地新 Issue 分派实现，只监听 `issues.opened`，按内容选择 bug 分析、需求评审或问题回答；它不再承担周期 CI 和积压 Issue 巡检
- `.github/workflows/agentic-llmdoc-updater.yml`：本地 llmdoc 更新实现，每天北京时间 05:00 或手动触发，Agent 只生成候选，独立的校验 job（validator）和 publisher 验证并创建／更新 PR
- `.github/workflows/check-agentic-workflows.yml`：PR 校验，离线检查三个 Agent workflow 的触发、job 拓扑、固定事件提交、权限、结果合同、本地 Action 和运行时脚本；它还明确对 pre-push hook、Agent shell 脚本和 PR history 脚本运行 ShellCheck

#### agentic 工作流的本地运行时与触发约束

三条 workflow、`.github/actions/`、`.github/scripts/agentic/` 和 `.claude/skills/` 都由本仓库维护，运行时不检出或调用远端模板。最初展开自 `Lightspeed-Intelligence/agentic-workflow-template` 的提交 `2a0bb28e6583d869645e0a0522568df4a5d4d921`；这个 SHA 是来源基线，不是调用点。吸收上游变化时，应比较该基线和新提交，选择性搬运，再按本仓库的权限、事件提交和缓存规则审查，不能整体覆盖。

Issue 分派和 llmdoc 更新在 job 级使用 `if: ${{ github.repository == 'CTeX-org/ctex-kit' }}` 限制主仓库执行（#875 / PR #876）。这是 job 级 `if`，能在分配 runner 前挡住 fork 上的定时、手动或 Issue 事件。llmdoc 仍保持每天一次；原 `agentic-patrol.yml` 已由 `issues.opened` 驱动的分派取代，因此不再有巡检频率。历史原因见 [[874-876-agentic-fork-shielding-cron]]，本轮取舍见 [[agentic-template-reuse]]。

**Agent 执行权限（#1032 简化后的形态）**：三条 workflow 共六个实际运行 Agent 的 job（每条各一条 Codex 和 Claude 链路），全部以 runner 默认用户运行，拥有完整本地执行权限——审查排版 PR 需要 Agent 自己跑 `l3build`、编译 MWE、把 PDF 转成图片比对。Codex 用 `--dangerously-bypass-approvals-and-sandbox`，Claude 用 `--dangerously-skip-permissions`，与上游模板 `agentic-workflow-template` 一致。约束 Agent 影响面的是权限边界而非进程沙箱：Agent job 只持有只读 `GITHUB_TOKEN`，checkout 后立即移除 Git 凭据；外部写入集中在不运行 Agent、也不接收模型 API key 的 publisher job；PR Review 的可信运行时来自 `pull_request_target` 的 base SHA，被审查的 head checkout 只作为数据；Claude 保留 `--bare` 禁用 `CLAUDE.md` 自动发现，避免被审查仓库向 Agent 注入项目指令。详见 `.github/agentic-runtime.md`。

已接受的风险：这套边界不阻止仓库代码读取 Agent 进程环境中的模型 API key。判断依据是当前贡献者都是仓库协作者，近 40 个 PR 中跨仓库 PR 为 0。注意 `pull_request_target` 与 `pull_request` 不同，它对 fork PR 同样提供 secrets；当前的保护来自可信运行时固定在 base SHA，而不是来自 fork 拿不到 secrets。由于 Agent 拥有完整本地执行权限，它一旦按审查需要运行 head checkout 中的测试或构建脚本，那些脚本就能读到密钥。因此若将来接受 fork PR 的自动审查，必须重新引入凭据隔离（例如此前的专用用户加 root 模型代理方案），或改用不携带 secrets 的触发方式。判断依据与被否决方案见决策 [[1032-agent-runtime-simplification]]。

**工具安装**：不再使用复合 Action，改为单个脚本 `.github/scripts/agentic/setup-agent-tools.sh`，由六个 Agent job 各自以普通 step 调用（`bash <prefix>/.github/scripts/agentic/setup-agent-tools.sh`，`<prefix>` 依 workflow 分别是 PR Review 的 `.trusted-base`、Issue Dispatch 的 `consumer`、llmdoc Updater 的 `runtime`）。脚本安装或恢复 TeX Live 2026、Noto CJK、HanaMinB、Noto Sans Symbols 2、Poppler、ImageMagick、Ghostscript 和 ShellCheck；`actionlint` 由脚本用 `go install` 单独固定版本安装；`zhmakeindex` 从 `Liam0205/zhmakeindex` 的最新 release 取 Linux 二进制，安装方式与 `_check-doc-package.yml`、`release.yml` 一致，但改用匿名 REST API 查版本号，因为 Agent job 的脚本不持有 `GH_TOKEN`。ctex 手册的索引依赖 `zhmakeindex`，缺它时 `l3build doc` 会在生成 PDF 之后才失败，Agent 只能把它记成环境限制而无法完整验证文档编译。脚本自身校验：TeX Live 缺失时 fail closed（`::error::TeX Live 不可用`）、CJK 字体缓存必须同时含 Noto Sans CJK 和 Noto Serif CJK、xeCJK 文档字体缓存必须含 HanaMinB 和 Noto Sans Symbols 2，最后逐个 `command -v` 检查全部工具并打印版本。

为什么不用复合 Action：复合 Action 的 step 字段合法范围严格小于 job step（`timeout-minutes` 只在 job step 合法），`run` 默认 shell 还带 `pipefail`，管道右侧提前 `exit` 的命令会让整个 step 以非零退出终止——这正是 #1030/#1031 两次连环故障的成因，且没有一次出自审查逻辑本身。普通 job step 调脚本没有这一类字段和默认值差异问题。这条规则本身仍然有效，只是不再约束工具安装：仓库里的 `.github/actions/run-agent`（Codex/Claude CLI 调用）和 `.github/actions/feishu-notify`（通知）仍是复合 Action，`scripts/validate-action-metadata.py` 与合同测试仍要求它们的 composite step 字段表以 GitHub 实际支持范围为准，`run` 里的管道也仍不能在右侧用提前 `exit` 的 `awk`。详见 [[1030-1031-composite-action-semantics]]。

**缓存**：仍留在 workflow 里，因为 cache action 无法在脚本内调用。每个 Agent job 有 TeX Live、CJK 字体、xeCJK 文档字体三类缓存共六个 `actions/cache/restore@v6` 步骤，全部只恢复不保存；未命中时由 `TeX-Live/setup-texlive-action@v4`（TL）或安装脚本自身（字体）当场下载。TL 缓存 key 与 `test.yml` 的 `warmup-tl` 一致（`tl-bypass-<os>-2026-<ISO week>-<tl_packages hash>`），两组字体缓存 key 也复用既有 CI 命名，因此大多数情况下能直接命中已经填好的共享缓存；实际写入共享缓存的仍是可信 CI 的既有流程，Agent job 本身不再触发缓存保存。

**保留的边界（不受本轮简化影响）**：

- `pull_request_target` 的可信 checkout 固定在 PR base SHA（分叉点，见下），被审查的 head 只是数据。
- 结构化 `review_status` 校验（`COMPLETE` / `INCOMPLETE`）：本轮已证明其价值——Agent 环境损坏时返回 `INCOMPLETE` 会被校验拒收，不会变成假绿。
- publisher 权限隔离：三条 workflow 都把 Agent 与外部写入分开。PR Agent 只读，publisher 独占 `pull-requests: write`；Issue Agent 固定事件 `github.sha` 且只读，dispatch job 独占 `issues: write`；llmdoc prepare 固定 master SHA，Agent 只打包 `llmdoc/` 候选，独立 validator 从同一 SHA 验证，publisher 才取得 `contents: write` 和 `pull-requests: write`。
- Claude 的 `--bare`：禁用 `CLAUDE.md` 自动发现，避免被审查仓库注入 Agent 指令。
- llmdoc Updater 的 `package-base` 重新检出：仍重新把固定 master 提交检出到 `package-base`，只复制 `consumer/llmdoc/` 文件树，比较和补丁生成都在这个新仓库中完成，不读取 Agent 控制的 `.git`。这一层解决的是“Agent 可能通过 `assume-unchanged`、本地提交或 `.git/config`（如 `core.fsmonitor`）让工作区 Git 状态失真”的问题，与本轮删除的三层隔离无关，未改动。

llmdoc prepare 生成的 `task.json` 包含 `since_period`，`recent-commits.txt` 包含精确候选提交；两个候选 prompt 在生成时展开这两个文件的实际绝对路径，并要求 Agent 先读取，不依赖裸文件名。

PR Review publisher 用认证 marker 中的 head SHA 区分评论：同一 head 重跑时更新原评论，不同 head 则新建评论，既避免同一提交的重复评论，也保留不同提交的审查记录。pre-push 必须用 `gh api --paginate --slurp` 读取并展平全部 Issue 评论页；检查维护者是否确认 Bot 评论时，以评论的 `updated_at` 为时间边界，缺失时才回退 `created_at`。只有 OWNER、MEMBER 或 COLLABORATOR 在 Bot 最后更新之后的回复，才算确认当前正文。这样，后续页的审查评论不会被漏掉，维护者在旧正文后的回复也不会掩盖同一 head 重跑产生的新 finding。

`scripts/test-agentic-workflow-contract.py` 固定触发、权限、六处工具安装脚本调用、restore-only 缓存、事件提交、publisher 隔离和结构化结果语义；它还用预期失败的错误样例验证零 finding 的 `COMMENT`、损坏的 `runs.using`、拼错的 composite step 字段、注入 `timeout-minutes` 的复合 Action step、字体 staging 中预置或不完整的内容、同／异 head 评论发布、第二页 Bot 评论、维护者回复早于 Bot `updated_at`。PR Review 的合同现在只固定两件事：提示词指向 base 固定的规范路径（`$GITHUB_WORKSPACE/.trusted-base/.claude/skills/{pr-review,github-comment}/SKILL.md`），以及 Claude 保留 `--bare`；恢复为读取工作树规范或让 Claude 丢掉 `--bare` 的反例都必须失败。llmdoc 通知也必须区分公开结果中的 `blocked` 与 job 执行成功。PR Review 的可信 sparse checkout 还要覆盖 `run-agent` Action 的全部仓库内运行时依赖；合同测试从实际的 `.trusted-base/...` 引用反推依赖闭环（允许 sparse-checkout 的目录前缀覆盖具体文件），并用删除依赖路径的反例确认校验会失败。新增或移动本地 Action 的运行时文件时，必须同时更新所有固定提交 checkout，不能只修改 Action 本身。合同 workflow 的 `pull_request.paths` 必须覆盖合同测试读取或执行的全部仓库文件；独立 shell 文件还要由明确的 ShellCheck 命令检查，不能把 actionlint 对 workflow 内嵌 `run:` 的检查当作替代。修改本地 Agent runtime 后运行合同测试、`scripts/validate-action-metadata.py`、actionlint 和 ShellCheck。设计与教训见 [[1025-agentic-local-runtime-toolchain]]、[[1030-1031-composite-action-semantics]]、[[1032-agent-runtime-simplification]]。

`agentic-pr-review.yml` 由 `pull_request_target` 触发，其工作流定义本身取自 base 分支（`master`）当前状态；但用于可信 checkout 的 `github.event.pull_request.base.sha` 是该 PR 的分叉点（merge base），不是 base 分支当前 HEAD。因此 Agent runtime（本节描述的三条 workflow 与 `.github/scripts/agentic/`）发生改动后，所有分叉点早于该改动的存量 PR 都会持续加载旧运行时，其 Agent job 会在可信 checkout 或工具安装阶段反复失败，直到该分支 rebase 到 `master` 或合并 `master` 为止；close/reopen PR 与单独重跑都不会改变分叉点，因此都不能恢复。这是刻意的安全设计：保证可信运行时的版本与被审查的 diff 有一致基线，代价是运行时改动不会对已存在、分叉点落后的 PR 自动生效。诊断步骤见 `llmdoc/guides/push-and-pr-review-workflow.md`。设计与教训见 [[1030-1031-composite-action-semantics]]。

### 测试工作流：`.github/workflows/test.yml`

当前稳定事实如下：

- 触发条件：`pull_request`、`push`、定时 `schedule`、`workflow_dispatch`
- 操作系统矩阵：`ubuntu-latest`、`macos-latest`、`windows-latest`
- TeX Live 安装：`TeX-Live/setup-texlive-action@v4`
- 依赖包清单：`.github/tl_packages`
- 当前 CI 拆为 6 个独立 caller job（`test-ctex` / `test-xeCJK` / `test-xpinyin` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip`；`test-ctex-luatex` 是 ctex 的 luatex 专属子 job，另计），各自 `uses: ./.github/workflows/_test-package.yml` 在 3 个 OS 上并行测试；`changes` 阶段用 paths-filter 决定 PR 上跑哪些 caller。`test-xpinyin` 额外传两个输入：`configs: test/config-cjk`（串行加跑 CJKutf8/pdfTeX 那条线）与 `needs-unihan: true`（unpack 阶段要生成拼音数据库）

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

核对要**逐个走一遍**，不能只补自己意识到的那几个。同一批改动里，pdfTeX 那条线新引入的 `CJKutf8`、`lmodern` 和 `gbsn` 字体族当时并未逐个核对归属，事后查明恰好已被既有的 `cjk`（提供 `CJKutf8.sty` 与 `c70gbsn.fd`）、`lm`、`arphic` 覆盖——也就是说那次没出问题是运气，而不是流程起了作用。核对方式是对每个新引入的 `\usepackage`、字体文件名和字体族分别跑 `tlmgr search --file --global`，再用 `grep -qx` 确认包名真在白名单里；漏掉的后果是本地完整 TeX Live 通过而 CI 在精简环境里缺包失败（`.log` 为空、`.tlg` 比对失败，根因不在输出差异）。

**改动 `.github/tl_packages` 本身等价于一次强制 CI 缓存失效。** TL bypass cache key 含 `hashFiles('.github/tl_packages')`（见下方 `warmup-tl` job 一节）；只要这个文件的内容变了，key 就变了。#1050 给 `dejavu`／`gnu-freefont` 加了三行触发的正是这条路径：该 PR 侧的 cache miss、当场全新安装，拿到的是当前上游最新版本；而未改这个文件的 `master` 继续命中改动前写入的旧快照，两侧使用的其实是两个不同时间点的上游环境。

后果：**同一个 commit 在 master 上重跑可能是绿的，在 PR 上却是红的，且 master 的绿不能作为「代码在当前上游下仍然通过」的证据**——它只说明 master 这次跑的是旧快照，没有真正验证当前上游。旧快照最迟会在 cache key 里的 `%G-W%V`（ISO 年-周）翻周时失效，届时 master 自己也会开始暴露同样的漂移。

判读方法是比较两次运行各自命中的缓存 key、`actions/cache` 记录里的缓存创建时间与体积，而不是只看 job 颜色。#1050 的实证：master 侧缓存创建于 08-03 00:44、319MB；PR 侧创建于 08-04 11:59、328MB——不同的创建时间和体积就是两份不同快照的直接证据。

CI 现在的结构 (PR #899 后):

**阶段 0 — `changes` job (paths filter):**
PR 触发时跑 `dorny/paths-filter@v4`, 检测哪些包目录被改, 输出 6 个 bool (ctex / xeCJK / xpinyin / zhnumber / CJKpunct / zhlineskip). push / schedule / workflow_dispatch 触发时 filter 不影响, 全跑. 同时把 `TL_VERSION` (顶层 env, 如 `'2026'`) 作 `tl-version` output 透传给 caller (workflow_call inputs 不能直接引用顶层 env).

依赖反查: ctex 依赖 xeCJK + zhnumber, 所以改 xeCJK 或 zhnumber 同样会让 ctex job 跑; xpinyin 的 XeTeX 路线以工作树里的 xeCJK 为运行时依赖 (`checkdeps` + `checkinit_hook`), 所以改 `xeCJK/**` 也会让 xpinyin job 跑. 公共改动 (`.github/workflows/test.yml`, `.github/workflows/_test-package.yml`, `.github/font-urls.txt`, `scripts/check-parallel.sh`, `scripts/sync-l3backend.sh`, `support/**`, `Makefile`) 让所有 6 个包都跑.

#### 新增被多个 workflow 共用的脚本时要一起改触发白名单

把逻辑抽成共享脚本时，「哪些文件改动会触发这些路径」是调用点的一部分，必须一起更新，否则改坏脚本时 CI 不会告警。`scripts/sync-l3backend.sh` 在 #1054 被漏掉过，由两个 bot 独立指出；已补三处：`check-doc.yml` 的 `on.pull_request.paths` 与 `_all` filter、`test.yml` 的 `_all` filter。

**两个 workflow 的失效机制不同，只查一处不够：**

- `check-doc.yml` 用 `on.pull_request.paths` 白名单。文件不在里面，workflow **根本不会触发**，Actions 页面上看不到这个 run。
- `test.yml` 用 `paths-ignore`。workflow **会触发**，但各包 job 的 `if` 取自 `changes` job 的 `_all` filter，该 filter 不含这个文件时全部为 false，于是每个包的 job 都被 skip，`test-result` 把 skipped 算作 OK，整体呈现为绿。

由此得到一条判读约束：**「看 job 有没有启动」不能作为门禁生效的证据。** 前一种机制下 run 缺席，后一种机制下 run 在但内容为空，两者都可能被误读成「已经跑过了」。要确认，得看 `changes` job 的 filter 输出，或直接读两个 workflow 里的路径清单。

**阶段 0.5 — `warmup-tl` job (cache 预热):**
`needs: changes`, `matrix.os = [ubuntu, macos, windows]` 3 job 并行. 每 OS 1 个 job 跑 setup-texlive-action 装 + update, 把 cache 填到当前 TLnet 最新 baseline. 这是**唯一会真装 install-tl** 的地方 — 收敛 mirror 请求, 避免 6 caller × 3 OS = 18 路并发轰炸 mirror 触发 ETIMEDOUT.

3 次 retry 换不同 mirror: try 1 `ctan.math.illinois.edu` (timeout 10min), try 2 `ftp.fau.de` (timeout 10min), try 3 `mirror.ctan.org` 自动重定向 (timeout 30min). try 1/2 短超时让换 mirror 反应快.

历史: 早期尝试 `SETUP_TEXLIVE_ACTION_FORCE_UPDATE_CACHE=1` 让 warmup 把 update 后的 TL 保到 uniqueKey (= primaryKey + uuid), 让 caller 跳过 update 省 70s/caller. 实测**不生效** — GH actions/cache 在 restoreCache 时按 restoreKeys 数组的 primaryKey 精确匹配优先, caller 命中老的纯 primaryKey entry (无 uuid), 跳过 warmup 的 uniqueKey. 现在 caller 端仍 `update-all-packages: true` 自己跑 update 才能与仓库 `.tlg` baseline 一致. 见 `_test-package.yml` head 注释.

**阶段 1 — 6 个 caller job 并行 (uses reusable workflow):**
`test-ctex` / `test-xeCJK` / `test-xpinyin` / `test-zhnumber` / `test-CJKpunct` / `test-zhlineskip` 六个 caller job, 各自 `uses: ./.github/workflows/_test-package.yml`, 传 `pkg` / `event-name` / `tl-version` 输入. 各 caller `needs: [changes, warmup-tl]` + `if: needs.changes.outputs.<pkg> == 'true'` 控是否跑. `test-xpinyin` 另传 `configs: test/config-cjk` 与 `needs-unihan: true` 两个输入, 分别对应 CJKutf8/pdfTeX 那条线和拼音数据库生成 (见下文).

每个 reusable workflow 实例内部 `strategy.matrix.os = [ubuntu-latest, macos-latest, windows-latest]`, 三个 OS 并行. `fail-fast: false` 一个失败不取消其它.

之所以拆 caller job 而非用 `matrix.pkg` 维度, 是为了消除 GH Actions 在动态 name (`${{ matrix.pkg }} on ...`) strategy expansion 前注册 placeholder check 用未渲染模板作 name 然后 cancel 的"幽灵 job"行为.

每个实例步骤:
- 装 TL: 2 次 retry 换 mirror (try 1 illinois, try 2 fau.de), 各 timeout 15min. 即便 cache hit, setup-texlive 在 `Updating packages` 阶段仍会联网拉 tlmgr db checksum, 单 mirror 网络抖动时这步可能失败 — PR #899 实测 windows 命中. retry 2 次降低这种 transient failure 让 job 挂的概率.
- 装字体 (`actions/cache@v6` 缓存 `$GITHUB_WORKSPACE/.font-cache/`, key 含 `_test-package.yml` hash; zip 解完即删只留 ttc)
- (仅 `needs-unihan: true` 的 caller, 目前只有 xpinyin) 缓存并下载 `support/Unihan.zip`: unpack 阶段的 `texlua xpinyin.lua` 要用它生成拼音数据库, weekly cache key 与 `_check-doc-package.yml`（xeCJK 用）完全一致, 两条 workflow 互相填对方的缓存.
- 跑 `Test <pkg>` (case 分支):
  - `ctex`: `../scripts/check-parallel.sh` + `CONFIGS` 三个 config, 4 engine 并行. wall-clock ~5–8min.
  - `zhlineskip`: 失败时 dump `build/test/*.log` 前 80 行.
  - 其他 (xeCJK / xpinyin / zhnumber / CJKpunct): `l3build check -q` 直接跑; 若传了 `configs` (目前只有 xpinyin 传 `test/config-cjk`), 主 check 跑完后再逐个串行跑 `l3build check -q -c <cfg>` — 与 ctex 的 configs 走 `check-parallel.sh` 并行不同, 这些小包的额外 config 是秒级到分钟级, 不值得铺并行基础设施.

**阶段 2 — `test-result` job (汇总):**
`needs: [warmup-tl, test-ctex, test-ctex-luatex, test-xeCJK, test-xpinyin, test-zhnumber, test-CJKpunct, test-zhlineskip]`, 检查每个 caller 结果(success / skipped 都 OK; 其他 fail). 把 warmup-tl 也算进去, 避免 warmup 失败 → caller 全部 skipped → test-result 误绿. branch protection 只盯这一个 status check 即可.

失败时 artifact 上传 (`actions/upload-artifact@v7`): `${{ inputs.pkg }}/build/**/*.diff`, artifact name 含 pkg 名 + OS 区分.

### 文档编译校验：`.github/workflows/check-doc.yml`

PR 阶段专用校验 (#935), 补 test.yml 的"文档 dtx→PDF 可编译性"维度. 只在 `pull_request` 触发. 结构:

- **`on.pull_request.paths` 白名单**: 除 9 个包目录外, 还含公共依赖与基础设施——`support/**`、`scripts/verify-doc-output.sh`、`scripts/sync-l3backend.sh`、`check-doc.yml` 与 `_check-doc-package.yml` 本体、`.github/tl_packages`、`.github/font-urls.txt`. 不在这份清单里的文件改动**不会触发本 workflow**.
- **`changes` job**: 精简版 paths-filter, 9 个 bool (ctex/xeCJK/CJKpunct/zhnumber/xCJK2uni/xpinyin/zhmetrics/zhmetrics-uptex/zhlineskip). 其 `_all` filter 需与上面的 `on.paths` 保持一致（同样含 `scripts/sync-l3backend.sh`）. **无依赖传递** — `l3build doc` 只 typeset 自身 `typesetfiles`, xeCJK 变动不会跑 ctex 的 doc.
- **9 个 caller job**: 每包一个 `uses: ./.github/workflows/_check-doc-package.yml`, job 级 if 保证未受影响包不启动 runner (仿 test.yml + _test-package.yml 的 caller-per-pkg 结构, 避开 matrix.pkg 幽灵 cancelled job).
- **`check-doc-result` 汇总**: 与 test-result 同构, branch protection 单点盯.

TL cache 共享: 用同一个 `tl-bypass-<os>-<ver>-<week>-<hash>` key (与 test.yml warmup-tl / release.yml 完全一致). PR 触发时 test.yml warmup-tl 同 head sha 并行填 cache, 本 workflow 大多数情况 100% cache hit; cache miss 走 setup-texlive-action fallback (单 mirror illinois pin, 抖动时 rerun --failed).

Verify 层: `scripts/verify-doc-output.sh` 按 `typesetfiles` 逐 PDF 检查 `build/doc/*.pdf` 存在 + `%PDF` magic + `>= 1024` 字节最小大小 (防 dvipdfmx fatal 后残留 stub `%PDF` header). `typesetfiles={}` 的包 (zhmetrics-uptex) 期望零 PDF 单独短路通过.

**这三条判据都是容器级的，对「编译成功但正文被污染」零判别力**（`scripts/verify-doc-output.sh:69-88`）。#1054 的实证：l3backend 版本错配下 `l3build doc` exit 0、PDF 页数与体积都正常，三条判据全过，只有版面上散落 `0gray 0` 一类泄漏文本。这是已登记的技术债，见 `memory/doc-gaps.md` 的「`verify-doc-output.sh` 缺内容级哨兵」。

#### 成功时也上传 PDF artifact

`_check-doc-package.yml` 在 `steps.doc.outcome == 'success'` 时上传 `check-doc-<pkg>-pdf`，path 为 `<pkg>/build/doc/**/*.pdf`，`if-no-files-found: ignore`。它与既有的失败版 `check-doc-<pkg>-failed`（同时含 `.log` 与 `.pdf`）条件互斥，不会重复上传。

理由是上面那条盲区：排版类问题（溢出行、字形缺失、颜色 special 泄漏）退出码都是 0，只能看版面，所以要让 PR 编出来的 PDF 可以直接下载做目视检查。

成功路径只传 PDF 不传 log——成功的 log 没有诊断价值，而 `xeCJK.log` 有近百 KB。存储方面：公开仓库的 Actions 存储不计费，保留期取仓库默认 90 天到期自动删除，且与 TL／字体 cache 是两套独立配额，不互相挤占（后者当前已用 9.71 GB，接近 10 GB 上限，这也是不把 PDF 塞进 cache 的原因）。

验收方式可参考 #1054 的做法：下载 artifact 后 `pdftotext` 再检索泄漏模式（`gray 0`、`0gray`、`1.0 0.0`），当时 `xeCJK.pdf`（249 页）与 `xunicode-symbols.pdf` 的计数均为 0。

#### 3 个包的 CI-only 特殊处理

首轮 CI 暴露 3 包 typeset 缺陷 (从未在 CI 上被 typeset 过), 已在同 PR 一并修复:

- **xpinyin**: `xpinyin.dtx:179` `\newfontfamily{TeX Gyre Adventor}` 走 fontconfig friendly name. TL 装了 tex-gyre 但字体不在 fontconfig 索引 → workflow 加 `/etc/fonts/conf.d/09-texlive-opentype.conf` 让 fc-cache 扫 TL opentype/truetype 目录. 无条件执行, 别的包只是索引多几百字体.
- **zhmetrics**: TL zhmetrics 包只装 gbk/unicode 分片 tfm, **不含**顶层 `zhmCJK.tfm`/`.map` — 这两个是 `zhmCJK.lua map` 在 `copyctan_posthook` 里生成后 CTAN admin 手工上传独立文件, TL 打包时未纳入. `zhmCJK.dtx` typeset 请求 `zhm35b` 走 fontname map 失败. 修法: workflow 加 `pkg==zhmetrics` pre-doc step, 用包内 `zhmCJK.lua` 生成 tfm/map, 装到 `TEXMFHOME` 并 `mktexlsr`. `.github/tl_packages` 补 `fontware` (提供 `pltotf`). build.lua 不变. `zhmCJK-test.pdf` 从 verify expected 移除 — `zhmCJK-test.tex` 硬编码 simsun.ttc/simhei.ttf 文件名 fontconfig alias 救不了, 是包内部字体安装 demo 与文档 CI 目标无关.
- **zhspacing** (暂不覆盖): 从 caller 里删除. `zhfont.sty`/`zhmath.sty`/`zhspacing.sty` 硬依赖 SimSun/SimHei/KaiTi/FangSong/Sun-Ext*/Times New Roman 商业字体, 且深挖后发现 `zhspacing.sty` 自身有时序 bug (`\@iforloop`/`\@nil` undefined, 之前被 SimSun 早退错误掩盖). 上次 tag `zhspacing-20160514` 后 10 年未维护, `release.yml` 也从未真正验证过它的 typeset 链路. 属于包本身 CI 改造范畴, 不合适塞进"新增 workflow 校验"这类 infra PR. followup issue 单独跟. 详见 [[935-check-doc-zhspacing-blockers]].

关键约束: **`l3build ctan` 不能作为 PR 校验的等价替代**, 因为它内部硬编码调 `l3build check` (`l3build-ctan.lua:123`), 整套 regression 会重跑, ctex 单包 20+ min 与 test.yml 完全重复. 用 `l3build doc` 精确对应"文档编译性"维度是取舍后的选择, 见 [[935-check-doc-vs-ctan]].

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
| `jiazhu` | 无 | `{\ExplFileDate}{0.0-beta}` | 共享 | ✗ | ✗（走 `*)`）——但 `release.yml` **没有** `jiazhu-v*` 触发器，发不出版，属潜在缺口 |
| `zhmetrics` | `build.lua` `version`（本次补） | `[<日期> v<版本> setup CJK fonts dynamically]`（`zhmCJK.dtx`，**旧式**写法，非 `{\ExplFileDate}`） | 共享 | ✓ | ✓ |
| `CJKpunct` | 无 | **两种写法都没有** — 共享 `update_tag` 对它恒为空操作 | 共享（不生效） | ✗ | ✗（走 `*)`） |
| `zhmetrics-uptex` | 无 | 无 `.dtx` | 不适用（有自己的 `build.lua`、`dir=zhmetrics-uptex`，但不 `dofile` 共享配置） | ✗ | ✗（走 `*)`）|
| `zhspacing` | — | — | — | ✗ | ✗ |

**这张表的行必须覆盖 `release.yml` 的 `Parse tag` 能识别的全部 tag 前缀**（当前十个：`CJKpunct`、`ctex`、`xCJK2uni`、`xeCJK`、`xpinyin`、`zhlineskip`、`zhmetrics`、`zhmetrics-uptex`、`zhnumber`、`zhspacing`），否则漏掉的那一行正是矩阵想拦住的「静默跳过」。`zhmetrics-uptex` 就是这样漏过一次的——它能触发 `release.yml` 却不在表里。

**对账现在由 `scripts/check-version-gate-coverage.py` 自动完成**，接在 `check-tag.yml` 的 `gate-coverage` job 上（无 `paths` 过滤，总是跑——用 `paths` 过滤自己就会重现同一类漏报）。它扫全部 `*/build.lua` 同目录的 `.dtx`，凡含 `l3build tag` 会回写的版本槽位（`{\ExplFileDate}{...}` 或 `$Id: <file> <ver>`）就要求该包同时出现在两个 workflow 里，否则失败并指出该补哪一处。

判据刻意选「**有没有版本槽位**」而不是「有没有 release tag」或「有没有 `version` 字段」：后两者都是可以补的，而前者决定了忘同步会不会发出错版的包。

按「可发版 / 不可发版」分级：`release.yml` 有对应 `<pkg>-v*` 触发器的包漏校验就硬失败；没有触发器的（当前只有 `jiazhu`）发不出版，只打 `::notice::`。让一个当下无法造成事故的项长期报红，等于把这个检查训练成噪声。

脚本本身的判别力已实测：分别从 `paths`、`filters`、`tag-<pkg>` job 三处各移除一个包，三次都 EXIT=1。**早期版本只用一条正则扫全文，因为 `<pkg>/**` 在 `paths` 与 `filters` 两段都出现，从 `paths` 删掉后仍显示已覆盖**——这个假阴性是实测发现的，现改为取三处交集。

脚本的判据必须跟着 `update_tag` **实际写入的位置**走，不能凭印象列举：初版只列了 `{\ExplFileDate}{...}` 与 `$Id:$` 两种槽位，漏掉旧式 `[<日期> v<版本>]`——而 `zhmetrics` 只有旧式写法，且它**有** `zhmetrics-v*` 触发器（能发版），于是两道校验都放行、对账脚本也扫不到它，是 #1041 的完整重演。盲审实测 `cd zhmetrics && l3build tag 9.9.9` 确实回写 `zhmCJK.dtx` 一行才查出来。现补第三条 pattern 并把 zhmetrics 一并接入。

脚本核对的是**四处**接入点的交集（`paths` / `changes` job 的 `outputs:` 映射 / `filters` / `tag-<pkg>` job），少查任何一处都会漏报：`outputs:` 里删掉一行会让 `needs.changes.outputs.<pkg>` 恒为空、对应 job 永不运行，而前三处看着都在。

**`gate-coverage` job 无 `if:` 条件，但 workflow 级的 `on.pull_request.paths` 仍是白名单**，所以「总是跑」只在 workflow 被触发的前提下成立。给某个包新加 `<pkg>-v*` 触发器（即它从「发不出版、只 notice」变成「能发版、必须校验」的那次跃迁）只改 `release.yml`，而它原先不在 `paths` 里，于是最需要对账的那一刻恰好不触发——又是同型缺口。现已把 `release.yml` 与对账脚本自身加进 `paths`。

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
- **提取版本号的模式必须锚到行首的结构标记，而不是只匹配形状**；两个包的锚点还不一样：`zhnumber.dtx` 的版本行带 `%<package|config>` docstrip 守卫，锚它即可；`xCJK2uni.dtx` 的版本行**没有**守卫（行首只有缩进空白），只能锚 `^[[:space:]]*` 加完整形状——而该文件另有一处 `\ExplFileDate` 出现在 `\date{...}` 里，完整形状恰好能排除它（实测不会误匹配）。两者的 fail-closed 都实测过：删掉真行、追加一句引用该形状的注释，提取结果均为空。
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

`.github/workflows/check-changelog.yml` 在 PR 改到以下路径时触发：任意 `**.dtx`（故意放宽到全部包——不参与 CHANGELOG 的包触发后生成 + diff 秒级必 pass，换来新包接入零 workflow 改动）、任意 `**/CHANGELOG.md`、`scripts/extract-changes.py`、`Makefile`、workflow 自身。单 job `check-changelog-result` 直接跑 `make changelog`（包列表以 `Makefile` 的 `CHANGELOG_PKGS` 为单一事实源，等价于对每个包执行）：

```bash
cd <pkg> && python3 ../scripts/extract-changes.py "*.dtx" all -o CHANGELOG.md
```

再 `git add -N -- '*/CHANGELOG.md'`（覆盖新包首次生成、CHANGELOG.md 尚未被 git 跟踪的场景，否则 `git diff` 看不到差异）+ `git diff --exit-code -- '*/CHANGELOG.md'`。fail 时按上述三通道贴出期望内容。

`CHANGELOG_PKGS`（单一事实源：`Makefile` 的 `CHANGELOG_PKGS` 变量，workflow 经 `make changelog` 间接消费，无需同步第二处）：`ctex xeCJK xpinyin zhlineskip zhmetrics zhnumber`。xpinyin 随 #1041 测试接入补写了首条 `\changes{v3.2}{...}` 后加入这份列表。其余 3 个含 `.dtx` 的包（`CJKpunct`/`jiazhu`/`xCJK2uni`）目前没有写任何 `\changes` 条目，暂不参与；补写 `\changes` 后只需把包名加入 `Makefile` 的 `CHANGELOG_PKGS` 一行。

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

### 基线处置的分类判据

判断某个上游漂移触发的 `.tlg` 基线 diff 该不该刷，先分类根因：

- **会自愈的漂移不刷基线**。l3backend 这一类是 TL 打包侧暂时没跟上 CTAN，本质是「旧快照」而不是「上游改了行为」；一旦 tlnet 同步，数值会自己变回去。如果现在刷基线，等于把上游当前这个滞后快照里的（相对新版本而言）错误数值固化下来，TL 同步后又要改回来，白做一次。
- **上游有意修正且不会回退的漂移必须刷**。pgf 的舍入修正属于这一类：源码注释写明了动机，是一次明确的、面向未来的修正，不会被撤销。

这条判据是 `## LaTeX2e 格式依赖声明` 那句「升级声明日期通常意味着一次成批的 `.tlg` 基线更新；这类基线 PR 不应被当成业务回归处理」在「单个宏包独立漂移」场景下的推广——后者针对的是本仓库主动声明的内核版本整体上调，这里针对的是本仓库没有主动做任何声明、纯粹因为上游各宏包各自的发布节奏不同步而出现的局部漂移，判据从「声明变了就该刷」细化为「先分辨会不会自愈」。

### 两条操作细节

- **不能靠正则替换数字更新 `.tlg`，必须让 l3build 重新生成**。实证是 `beamer01` 的 `2000.0` 出现次数从基线 8 次降到 4 次，成对的 push/pop 数量也随之变化——手工改几个数字看起来能让 diff 变小，但改不出正确的节点结构。
- **关掉断言不是刷基线**。`fntef-phase01` 曾被改成把五条 `PASS: ...` 换成 `PHASE-CHECK-PENDING`，这等于删除了校验，而它在配对版本（backend 与 pgf 都是当时应有的版本）下本来是全绿的。刷基线的前提是让测试在正确环境下重新跑出真实结果，不是让测试不再报告结果。

### CI 侧的临时 workaround：共享脚本 `scripts/sync-l3backend.sh`

会自愈的漂移既然不刷基线，CI 在上游同步之前就会一直红。这段时间的处置是在 workflow 里临时补齐匹配版本，而不是改基线。

**同一个错配在两类路径上的表现完全不同，这决定了防御必须覆盖到哪些地方。** regression 路径（`l3build check`）上它表现为 `.tlg` 红：`\special{pdf:bc [...]}` 从基线里消失，变成 `\TU/lmr/m/n/10 1.0` 一类字符节点，12 个测试变红（见 `d7457624`）。doc／ctan 路径（`l3build doc`、`l3build ctan` 的 typeset 部分）上它**不产生任何非零退出码**：编译成功，PDF 页数与体积正常，只在正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本。所以两类路径都要防御，但**只有前者会自己报警**；后者事后无法从构建状态发现（#1051 就是这样漏到本地产物里的）。

原先内联在 `_test-package.yml` 的 workaround 已在 #1054 抽成共享脚本 `scripts/sync-l3backend.sh`，三处调用：

| 调用点 | 位置 | 保护的产物 |
|--------|------|------------|
| `_test-package.yml` | `Test <pkg>` 之前 | `.tlg` 回归基线 |
| `_check-doc-package.yml` | `l3build doc` 之前 | 手册 PDF 正文 |
| `release.yml` | `l3build ctan` 之前 | CTAN zip 里的 PDF |

步骤名统一为 `Sync l3backend to l3kernel (upstream version skew)`。三处都写成 `bash ./scripts/sync-l3backend.sh` 而不是 `./scripts/sync-l3backend.sh`：`_test-package.yml` 也跑 `windows-latest`，git 在 Windows checkout 上不保证还原 exec 位，直接 `./` 会 permission denied。

`release-ctan-upload.yml` **不接入**：它只把 `release.yml` 已经打好的 zip 原样转发到 CTAN，不重新排版，没有可污染的产物。

脚本本身做五件事（`scripts/sync-l3backend.sh`）：

1. 比较 `expl3.sty` 的 `\ExplFileDate` 与 `l3backend-pdftex.def` 的日期戳，一致就打 `::notice::` 并 exit 0。
2. 不一致时逐 mirror 下载 `l3backend.zip`，**每个 mirror 下载后就地校验产物**（`-s` 非空 + `unzip -tq`，另加 `--max-time 300`），不合格当作失败换下一个。
3. `tex l3backend.ins` 解包，输出保留在日志里（不丢 `/dev/null`）；用 `nullglob` + 显式计数替代裸 glob，「一个 `.def` 都没解出来」立刻失败在发生处。
4. `cp` 进 `TEXMFHOME`，随后**无条件** `mktexlsr "$TEXMFHOME"` 让 kpse 看得见新文件。
5. 核对 `kpsewhich l3backend-pdftex.def` 解析到的确实是新装那份、日期与 l3kernel 一致，否则 `::error::` 退出。

三个设计选择值得说明：

- **装进 `TEXMFHOME` 而不是各包的 `localdir`**。kpse 中 `TEXMFHOME` 优先于 `texmf-dist`，一步覆盖所有包与所有引擎，且不往仓库工作树里落文件。`localdir` 注入（见「往 check 环境注入替代版本的上游宏包」一节）适合本地一次性对照实验，要在 CI 里覆盖 test 的 6 个 caller、check-doc 的 9 个 doc job 与 release 那一处，就得每个包都处理一遍。
- **第 4 步不能省，而且不能加条件**。往 `TEXMFHOME` 拷文件之后 kpse 未必看得见——CI 上 `TEXMFHOME` 解析到一棵带 `!!` 前缀的树，语义是只查 ls-R、绝不扫磁盘。完整机制、以及「刷过索引的那个 job 反而失败」这个反直觉后果，见 [[kpse-path-resolution]]。
- **日期比较作为前置条件，而不是无条件安装**。tlnet 追上以后，这一步自动变成空操作并打一条 `::notice::` 提示可以删除；不需要靠人记得「上游修好了要来撤」。**撤除判据就是这条 notice。** 撤除时要删的东西共三类：脚本本身、三处 `run:` 调用、以及三处触发路径条目（`check-doc.yml` 的 `on.pull_request.paths` 与 `_all` filter、`test.yml` 的 `_all` filter）。

同类问题若再出现（例如另一对上游包版本错配），照这个形状加一步即可，四点都不能省：**比较版本 → 补齐并就地校验产物 → 让 kpse 看得见 → 核对生效**。

**末尾那次核对不能是唯一防线。** 它确实挡住了坏产物，但它只能报出「注入未生效」这一种结论——网络故障、zip 残缺、索引陈旧全都被归成同一句话，与真实原因无关，会把排查方向带偏。#1054 的实证：`mirrors.ctan.org` 重定向到实际镜像后三次 `curl: (28) Timeout`，curl 最终仍返回 0、`-o` 只写出空文件，脚本一路静默走到末尾才被 kpsewhich 拦下，报的却是「注入未生效」。所以每一步都要在**发生处**校验自己的产物。

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
| 颜色、图形等后端 special 变成可见文本（如 `\special{pdf:bc [1.0 0.0 0.0]}` 变成排出来的 `1.0 0.0 0.0`） | `l3kernel` 与 `l3backend` 版本错配，后端函数签名不匹配使 `\use:c` 找不到目标。**同一根因在 doc／ctan 路径上不出现任何 `.tlg` diff**：编译 exit 0、PDF 体积正常，只在正文里散落 `0gray 0`、`1.0 0.0` 一类泄漏文本（`xeCJK.pdf` 的 `\meta` 与 fntef 示例最明显），判别方式是 `pdftotext` 后检索 `gray 0`／`0gray`／`1.0 0.0` 并断言计数为 0，而不是看 `.tlg` |

出现前三条指纹应优先按“本地 usertree 同步”流程修，而不是当作业务回归排查。

出现第四、第五条（`\cleaders`＋`\glue` 几何、`btrans matrix` 坐标）时，先按上一节「上游宏包版本漂移的识别与基线处置」判断这次漂移该刷基线还是该等 TL 同步，而不是直接假定是本地环境问题。

最后一条要单独处置：它属于本地各包之间不自洽（详见下文），**并且没有基线可刷**——doc 路径上根本不存在 `.tlg`，而 regression 路径上的 diff 是错配造成的错误输出，刷进基线等于把缺陷固化。唯一的处置是补齐匹配版本的 backend（本地按「往 check 环境注入替代版本的上游宏包」或等 TL 同步，CI 上由 `scripts/sync-l3backend.sh` 负责）。

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
