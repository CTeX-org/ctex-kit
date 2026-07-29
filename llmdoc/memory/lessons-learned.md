# Lessons Learned

Curated cross-task rules distilled from archived memory.

## 共享文档基础设施

### 缩放最窄的可变排版对象
**Rule**: 修复复合 coffin 或 table 的溢出时，只缩放实际越界的子盒，保持日期、状态标记和相邻栏不变。
**Why**: Issue #963 首版缩放整个 functions coffin，连带压缩 Added/Updated；改为只处理函数名与 TF 后缀后才稳定。
**Source**: `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 上游私有补丁必须硬失败
**Rule**: 覆盖 l3doc 等上游私有接口时，同时维护最低版本门禁、依赖接口清单、专项回归，并用 critical 错误暴露不兼容。
**Why**: ctxdoc 的补丁健康检查证明普通 error 在 nonstop CI 中可能继续执行，而完整重定义还会放大静默漂移风险。
**Source**: `llmdoc/memory/archive/2026-07-12/704-ctxdoc-patch-health-test.md`, `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 用接口证据复核自动审查
**Rule**: 对名称相近的 expl3 控制流或异常分支，必须用 `interface3` 原文、最小实验或失败路径测试验证审查结论。
**Why**: #964 的自动审查曾反转 `\dim_until_do:nNnn` 的真实语义，版本门禁也先后出现 ExplSyntax catcode 错位和条件丢失；仅跑正常路径不足以发现这些问题。
**Source**: `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 生成物排序不能反向支配源码组织
**Rule**: `\changes` 等生成源注释应贴近对应实现；生成结果的不连续不能通过挪远源码注释或手改生成物来美化。
**Why**: #975 中把三条记录集中虽让 CHANGELOG 连续，却让 `quanjiao`/`kaiming` 记录脱离实现；最终恢复源码邻近性并接受提取顺序。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`

### 跟踪生成物必须走仓库的 canonical target
**Rule**: 源文件变化影响已跟踪生成物时，先从 Makefile/guide 找唯一生成入口，运行后核对只产生预期 diff；不要手改生成物去追 CI 文本。
**Why**: #991 手工同步的 xeCJK CHANGELOG 与 `\changes` 提取器漂移，`check-changelog-result` 失败；`make changelog` 确定性重建后只有目标文件变化并通过门禁。
**Source**: `llmdoc/memory/archive/2026-07-18/991-setref-boundary-fix-and-evidence.md`

### 已发布版本不能继续接收新变更条目
**Rule**: 写 `\changes` 前核对最新正式 release tag；发布后的新变更使用下一个未发布版本，不从 `build.lua` 当前值或 CHANGELOG 首节反推。
**Why**: #381 在 ctex 2.6.2 发布两天后落地，首版仍误记为 v2.6.2，合并后才纠正为 v2.6.3。
**Source**: `llmdoc/memory/archive/2026-07-13/381-cjkfntef-backend-boundary.md`

### 测试结论不能超出实际执行的平台分支
**Rule**: 平台条件测试通过后，只陈述该次运行实际执行的分支；配置检查、字体声明、实际字形和度量比较是不同层次的证据，不能互相替代。
**Why**: #994 的 Linux 四引擎回归能检查 `macnew` 生成配置，却没有 Apple 字体，也不会执行 macOS 条件分支；只有 macOS XeTeX/LuaTeX 的运行时探针实际加载并核对了 Regular 字形。
**Source**: `llmdoc/memory/reflections/994-macnew-songti-regular.md`

### 字体字形变化必须同步选择、映射和度量
**Rule**: 更换字体集中的正文常规字形时，同时核对各引擎的具名字体、TTC index、zhmap、度量生成源和跟踪数据，并用拥有目标字体的平台验证实际字形与度量。
**Why**: #994 若只把 `Songti SC Light` 改名为 Regular，LaTeX+DVI/upLaTeX 仍会使用旧 index，标点压缩也会继续读取 Light 的 SPA 数据。
**Source**: `llmdoc/memory/reflections/994-macnew-songti-regular.md`

### 本地审查报告是独立的完成门禁输入
**Rule**: 运行过本地 code-review 时，在完成或 merge 前用忽略规则外的文件盘点读取全部 `.code-review` 报告，并把每条发现映射到当前树核实。
**Why**: PR #976 只审计 GitHub 活动，漏掉被 `.gitignore` 隐藏的报告中两个有效小问题，合并后不得不用 #978 补修。
**Source**: `llmdoc/memory/archive/2026-07-13/976-978-ignored-local-code-review.md`

### 正式审查必须与实现上下文隔离
**Rule**: 主代理的实现检查只算自检。正式 code review 必须启动不继承主代理设计与实现对话的新子代理，只提供仓库规则、公开目标、完整 base/head SHA、范围和必要公开证据；报告须记录隔离方式、允许输入和固定范围。增量审查可读取上一份正式报告取得截止点，但不能继承主对话。
**Why**: PR #1009 的 `bb14d1a3..2092edad` 审查虽由独立子代理完成，报告却没有记录上下文隔离方式，不能证明审查者未继承实现假设；后续 llmdoc 增量审查因此把“新会话、受限输入、报告留痕”补成可审计门禁。
**Source**: `llmdoc/memory/reflections/1002-inline-math-boundary.md`

### APPROVE 总评不覆盖详情中的 finding
**Rule**: 任务要求处理全部审查问题时，按阻塞、重要和小问题的逐项计数闭环；总评为 APPROVE 或建议标为 optional 都不能自动视为已处理。
**Why**: PR #983 第一轮自动审查虽为 APPROVE，仍列出 1 个实现注释小问题；初次收尾跳过后，最终 completion audit 才补上并经增量审查确认 0/0/0。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

### 验证强度按当前增量风险收缩
**Rule**: 主体改动已有完整验证后，仅涉及注释或措辞的后续小改使用差异检查、必要的定向实验和强制 CI；只有增量重新触及语义、解析、生成物或基线时才重跑完整本地门禁。
**Why**: PR #988 在完整 `l3build ctan` 已通过后仍为标题定义名称和一行注释重复全量构建，增加等待且中止时产生局部构建噪声，没有带来相称的新覆盖。
**Source**: `llmdoc/memory/archive/2026-07-15/986-987-third-party-docs-and-proportional-verification.md`

## TeX 节点与输出几何

### 周期装饰先保护既有几何，再按接点分工
**Rule**: 修复重复装饰的局部异常前，先列出当前正确的装饰总长度、居中、端点和相邻命令连接语义；不要把 `ulem` 的 `\UL@pixel` 从整套几何中单独清零。若正文片段、伸缩胶水和命令端点承担不同的几何作用，就分别实现和验证，不能只更换 leader 类型或缩短图案周期。
**Why**: #531/#967 说明 `\leaders`、`\cleaders`、`\xleaders` 的总宽可以相同而相位不同；#1012 又证明 leader 原语不能独自同时处理相位、精确端点和可断行接点。当前实现用随字号缩放的 `1em/4` 图案和普通 `\leaders` 让正文片段、`CJKglue` 与换行后的片段共享相位，再用首末局部裁切控制普通／带 `-` 形式的对称可见范围，并在断点两侧各放半周期连接。
**Source**: `llmdoc/memory/archive/2026-07-12/531-underline-leader-phase.md`, `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`

### 手册中的局部视觉问题先提取精确 MWE
**Rule**: 手册中只有局部示例出现视觉问题时，提取一页 MWE，保留原来的文档字体、数学字体、字号和示例内容，用它做日常调试和修复前后截图；整本手册只做最终集成构建。
**Why**: #1012 的单页 MWE 约一秒即可稳定复现波浪双峰和斜删除线聚集；反复编译 240 页 `xeCJK.pdf` 成本高，而且“PDF 成功生成”本身不会判断局部线条是否连续。机制仍由 `.lvt/.tlg` 固定，视觉结果由同条件高分辨率图确认。
**Source**: `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`

### 从源码树验证时必须核对实际加载文件
**Rule**: 使用临时 MWE 验证工作树生成的 TeX 宏包时，把日志中的实际文件路径列为证据；文件名、输出目录名和运行命令都不能证明加载的是当前实现。
**Why**: #1012 的一次实验实际加载了 TeX Live 中的旧版 `xeCJKfntef.sty`，却把图片标成修复后结果。核对日志确认加载 `xeCJK/build/unpacked/xeCJKfntef.sty` 后，视觉证据才与固定提交对应。
**Source**: `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`

### PDF 绘图回归要分开固定尺寸、节点、坐标和外观
**Rule**: 绘图命令会展开大量 PDF special 时，用真实图形固定关键尺寸，用同尺寸轻量盒子固定 leaders、节点和断行，用 XDV 生成不压缩内容流的 PDF 后读取实际坐标来固定相位、节距和端点，再用精确视觉 MWE 检查曲线、连接与密度；整本文档构建只检查集成路径。
**Why**: #1012 若把完整 `l3draw` 路径写入每项 `.tlg`，基线会增加数千行脆弱输出；若全部改用规则盒子，又无法证明页面坐标和真实图形正确。`fntef-phase01` 的 Lua 后处理能在节点宽度相同的情况下发现周期盒子的断口、重叠或端点偏移。
**Source**: `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`

### 稳定文档必须随实现演进重新核对
**Rule**: 中间方案被后续提交替换时，重新逐项核对 architecture、reference、decision、lessons 和 index；已否决的路线只能作为历史记录，不能继续写成当前合同。
**Why**: #1012 的 `1em/3 + \xleaders/\cleaders` 和 `1em/4 + 默认 \cleaders + 胶水专用图形` 两个中间方案都曾被写入稳定文档；当前合同已经改为“普通 `\leaders` 共享相位＋首末局部裁切＋断点两侧半周期连接”，固定提交的独立审查仍发现旧说明会误导后续实现和测试。代码通过回归不能抵消稳定知识与实现不一致。
**Source**: `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`

### 字符分类修改必须检查节点结构和旧类消费者
**Rule**: 调整或新增 interchar 字符类时，用 `\showbox` 同时验证 glyph、glue、kern、penalty 等节点，并反向审计所有直接判断或枚举旧类的消费者，不能只比较视觉效果或总盒宽。
**Why**: #284 中总宽抵消掩盖了多余标点节点，#382 新增 `PoZheHao` 又因遗漏 `FullRight` 的直接判断重现历史错误；分类标签正确不代表所有下游语义自动正确。
**Source**: `llmdoc/memory/archive/2026-07-13/284-fullwidth-tilde-longpunct.md`, `llmdoc/memory/archive/2026-07-13/382-dash-width-punct-if-right-and-cmap-metrics.md`

### 边界状态必须区分语义与可信来源
**Rule**: 边界恢复不能只信全局语义缓存；必须用当前列表证据，或让 capture 覆盖完整命令并在真实观察点记录首尾类别。
**Why**: #972 的专用 marker 曾证明普通 `default` 可能是陈旧状态；#999 随后用完整 annotation stream 吸收该证据并删除专用 marker，使实际输出类别直接成为恢复依据。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`

### 边界出口必须恢复后续判断所需的完整状态
**Rule**: 状态机在命令或子列表出口不能只重放最终分类；还要列出下一次恢复会读取的引擎状态、pending 标志和物理相邻节点，并逐项恢复。跨节点移动必须同时受注册范围、尺寸条件和真实 marker 证据约束。
**Why**: #1003 中盒子的末类别和 `\null` 前的 marker 都正确，但盒内过期的 `spacefactor` 仍让源码空格比较失败，零尺寸 hbox 也会截断“marker + glue”的相邻关系。PR #1005 同步外层 `spacefactor`，并只跨已注册零尺寸盒子移动由 marker 证明的至多一枚 glue；没有证据时按原节点顺序还原。
**Source**: `llmdoc/memory/reflections/1005-xcjkecglue-right-boundary-recovery.md`

### 可见排版修复需要三类证据
**Rule**: 对间距、字形或线条等可见排版缺陷，同时维护定量宽度、节点结构和同条件渲染三层 oracle；再用会插入节点的 wrapper 组合回归证明状态能传递。
**Why**: #972 的测量、截图和组合用例暴露了普通 `default` 原型缺陷；#999 又证明默认 glue 等宽会让宽度或截图假通过，必须由节点测试区分来源。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 字符型装饰要分别验证 PDF 文本与页面视觉
**Rule**: 只用于绘图的字符或数学内容应以空 `ActualText` 排除文本语义；tagged PDF 还要检查内层标记，必要时在最小范围暂停 tagging。验收时分别检查普通／tagged PDF 的文本提取和修复前后页面渲染，不能让其中一项代替另一项。
**Why**: #1017 中波浪线、斜删除线和用户符号虽位于装饰盒与 leaders 中，仍会以 `:`、`/`、`.`、`*` 混入复制结果；单用 Artifact 或外层 `ActualText` 都不能稳定约束 tagged PDF 的内层数学标记。空 `ActualText` 加最小范围 tagging 暂停清除了提取污染，而 300 dpi 的 `AE=0` 独立证明页面外观没有变化。
**Source**: `llmdoc/memory/reflections/1017-fntef-actualtext.md`

### 弹性间距必须验证伸缩量和实际断行
**Rule**: 测试可伸缩间距时，分别核对 natural、stretch 和 shrink，并在有限容差下实际排段检查断行；盒子自然宽度只能作为第一层证据。单个 `\hbox` 或 `\vbox` 不能替代真正断行：其内部的 glue set 会把内外层的可伸缩量一并用掉，两种实现即使内外层收缩量分配不同也会得到相同的宽度或高度，必须把内容放进 document 主垂直列表、让 `\par` 真正决定断行，才能看出内外层区分。
**Why**: #1002 中自然宽度相同的 glue 仍可能具有不同的伸长量和收缩量。只有缩短段宽并比较 badness 与段落高度，才能证明 stream 和已装入盒子的冻结空格都保留了正确的外层断行能力。#1026 中前三版测试分别把正文装进 `\hbox`、`\vbox`，或用 `\def\BODY` 承载正文，均显示缺陷版与修复版数字相同；只有改成“主垂直列表里真正断行，且调用处写字面正文”才第一次测出差异。
**Source**: `llmdoc/memory/reflections/1002-inline-math-boundary.md`, `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 改动他人 issue 引入的代码时，重放那个 issue 的资产做无回归证明
**Rule**: 若修复触及某个既有 issue 引入的代码路径，就把该 issue 在 `gh-assets` 留下的 MWE 与视觉资产重新跑一遍，与**本 PR 的父提交**逐像素／逐字节比对，并把结果放进 PR body。基线必须选父提交，不能选早于那个 issue 的发布版——发布版的差异是那个 issue 的预期改进，会掩盖真正的回退。
**Why**: #1026 改的正是 #1002 引入的代码。重放 `issue1002-mwe.tex` 的 24 行数值 oracle 与 `inline-math-showcase.tex` 的 17 页渲染，确认与父提交逐字节／逐像素相同，才排除了回退。若误用 v3.10.3 作基线，会看到 18 行差异并误判为回归——那些差异其实是 #1002 自己的修复效果。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### PR body 要图文并茂地展示修复前后
**Rule**: 视觉类缺陷（间距、装饰、断行）的 PR body 应放修复前后对照图，并画出判据参考线（如正文右边距），配上可复现的量化数值。图片资产提交到 orphan 分支 `gh-assets` 的 `issues/<号>/` 下，用 `raw.githubusercontent.com` 引用；同目录放 `README.md` 说明各文件与复现命令。操作 `gh-assets` 必须用 `git worktree`，不要在主工作区 `checkout --orphan`。
**Why**: #1026 的高亮右边界偏移用文字描述很难判断是否修好；一张带红色边距线的上下对照图，加上「722px → 681px、与发布版逐像素一致」的数值，评审可以直接确认。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 引用差值时要标明它属于哪一组间距设置
**Rule**: 记录「删掉某处后出现多少 pt 差值」时，注明该数值来自哪一组 `CJKecglue`／`CJKglue` 设置。同一现象在默认胶与自设胶下的数值不同，直接从别的测试搬数字会写错。
**Why**: #1029 我把 `command-boundary01` 在默认胶下的 3.33pt 搬到了自设 `CJKecglue=5pt`／`CJKglue=1pt` 的新用例注释里，三处文档同时写错；该场景的实测差值是 4.0pt（63.19998pt 降为 59.19998pt）。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 变异要逐项做：整个文件变红不等于每一项都有判别力
**Rule**: 确认回归判别力时，对每一项各自声称守护的那条行为单独做一次变异，只破坏这一条，看这一项是否变化。整份测试文件 rc 1 可能只是其中一项失败连带压垮了后续各项的读数。
**Why**: #1029 的第一版回归中，只破坏「暂停深度归零」（去掉 `\int_gdecr:N`）或只撤销隔离，测试都全绿；而还原原缺陷时整个文件变红，让我误以为各项都在守着。逐项变异才暴露出两项完全没有判别力、另两项读的是别人的值。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 每项测试用独立的盒子／寄存器，否则读到的是上一项的遗留值
**Rule**: 断言全局赋值是否生效时，每一项必须使用各自独立的盒子或寄存器。共用一个全局对象时，前一项留下的值会被后一项读到，测试看似通过却什么都没断言。写完后应改变该项的内容重新生成基线，确认读数随之变化。
**Why**: #1029 的第一版回归让三项共用同一个 savebox，其中两项读到的是第一项留下的 21.8pt——把内容换成明显更宽的字符串，读数纹丝不动；`[3cm][l]` 那项的期望值本应是 85.35826pt，却记成了裸文本的 21.8pt。缺陷版下这两项出现 0.0pt 也只是第一项失败的连带结果。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 断言「上游行为已修复」之前，先在不加载本包的环境里测一遍
**Rule**: 声称修复了某个上游命令的行为前，先在纯上游环境（不加载本包）里测同一组样例。若上游本来就不工作，那不是本包的回归，也不该写进修复范围；应把它作为既有限制固定下来并注明成因。
**Why**: #1029 我写了「`\global\savebox` 三种形式跨分组保住内容」，实测纯 LaTeX 下三种全为 0.0pt——`\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，与本包无关。真正修好的只有 `\global\sbox`。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 顺手做的一致性修改要单独确认有无门禁
**Rule**: 同一约束改到多处时，逐处确认哪些有回归覆盖。若某处的症状在结构上无法观察（例如被包进 hbox 后内层弹性不外露），就在文档里如实写明它依赖代码审查而非门禁，不要让它蹭进另一处的覆盖声明。
**Why**: #1026 中 `\UL@onin` 的重排分支按同一约束改了，但 `ulem` 用 `\setbox\UL@box\hbox{{#1}}` 包住内容，收缩量丢失在嵌套路径上不显现；重新引入缺陷乃至删掉整段分支，全套 114 项仍全绿。文档原先的措辞读起来像 `\UL@on` 与 `\UL@onin` 都已覆盖。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 引入会改全局状态的测试原语前先读它的定义，生成基线后复查体积
**Rule**: 像 `\loggingoutput` 这类原语会覆盖全局参数（它把 `\showboxbreadth`／`\showboxdepth` 设为 `\maxdimen`），必须先调用它、再设回本文件需要的值。生成 `.tlg` 后核对行数与内容是否正是想固定的对象，不要只看 `l3build check` 是否为绿。
**Why**: #1026 中顺序写反使前四项也倒出完整节点列表，`.tlg` 从预期百余行涨到 3279 行、含 880 处 PDF 绘图 `special`，直接违反同文件声明的“只固定行盒尺寸与 glue set”；补 `\clearpage` 并调换顺序后降到 145 行。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### l3build 测试里不能用 \showbox，它会静默截断其后所有用例
**Rule**: `support/build-config.lua` 把 `checkopts` 设为 `-halt-on-error`，而 `\showbox` 会抛出 `! OK.`，编译因此当场终止：该行之后的 `\TEST` 全部不执行，`.tlg` 也只记到那一行，但 `l3build check` 仍然报绿。需要把盒子内容写进基线时，用 `\loggingoutput` 配合 `\box` 加 `\clearpage`（见 `command-boundary-math02.lvt`、`verb-ecglue02.lvt`），并在文件层设好 `\showboxbreadth`／`\showboxdepth`。
**Why**: #1026 有一版 `fntef-shrink01` 用 `\showbox` 打印装饰盒，之后新增的用例从未运行过而 check 一直全绿；在 `\END` 前插一个探针 `\TEST` 并确认它没有进入日志，才暴露出这一点。`verb-ecglue02.lvt` 早已把这条坑写成注释，说明它会反复出现。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 断言强度要匹配所声称的行为，宽度相等不等于结构相同
**Rule**: 用尺寸做 oracle 时，先问“有没有一种实现能让尺寸不变而所声称的行为已经错了”。若有，就必须把结构本身（节点列表、片段宽度）纳入基线，或把注释与文档里的职责表述降级到尺寸真能证明的范围。
**Why**: #1026 中只固定装饰盒总宽度的用例，命名与注释都称“尾随空格仍被装饰”，但把空格换成等宽 `kern`（宽度完全相同、装饰实际消失）时它照常通过；把末段 `\cleaders` 纳入基线后才真正拦住。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 确认根因后要枚举全部满足该根因的代码路径
**Rule**: 定位到根因后，把它当作判据去检查所有满足它的路径，而不是只修触发当前复现样例的那一条。同一函数里往往还留着条件更窄的同类路径。
**Why**: #1026 的根因是“正文经宏参数间接展开会让 `\CJKecglue` 固化在装饰片段盒内”。第一版修复把非重排路径改回字面展开就收工，却漏掉被保留的重排分支——它同样走参数间接展开，只是触发条件更窄（正文需同时含西文词并以公式加空格结尾），实测溢出量与修复前完全相同。这一残留是独立审查发现的，不是自检发现的。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 回归测试必须用重新引入缺陷的方式确认会失败
**Rule**: 新增或改写回归测试后，故意还原到修复前的实现，确认测试会失败；测试全部显示“通过”不构成“这项测试确实能检测该缺陷”的证据，只能证明测试当前不会误报。同理，声称某测试守护某条行为之前，也要用变异实测确认是它会红——没有任何输出行的 `.tlg` 段落不构成门禁，把守护职责写错到文档里会让后来者误以为已有覆盖。
**Why**: #1026 中连续三版测试草案都显示通过，但都是因为选错了能观察内外层区分的载体（`\hbox`／`\vbox` 抹平差异，宏承载正文触发了另一条既有限制），如果没有主动倒回旧实现验证，很可能把假绿当作“修复已验证”上报。同一 issue 里还出现过一个用例的 `.tlg` 段落其实是空的，却在注释和 llmdoc 里被写成负责固定“重排确实发生、尾随空格仍被装饰”；实测关掉重排、删掉空格交还它都照样通过，真正拦住的是 `command-boundary-math05`。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 命令边界修复必须覆盖输出等价矩阵
**Rule**: 验证命令边界间距时，以相同可见内容的直接输入为 oracle，按实际输出首尾类别、`00/10/01/11` 和会改变边界语义的选项值记录精确单元，并用可区分 glue 与节点证据排除默认宽度假通过。公式必须与直接公式比较，候选与 oracle 必须使用相同的 `xCJKecglue` 设置。
**Why**: #491 按命令各抽一个场景，未暴露同一命令更换输出类别或源码空格后的异常；#992 最初只覆盖 `xCJKecglue=false`，补测 `true` 后又在嵌套盒子和 `\null` 边界发现 #1003；#1002 还证明把 `$x$` 换成字母 `x` 会改变比较问题本身。单点或单一选项通过都不能推出整类已修复。
**Source**: `llmdoc/memory/archive/2026-07-18/992-command-boundary-oracle-matrix.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`, `llmdoc/memory/reflections/1005-xcjkecglue-right-boundary-recovery.md`

### 源码语法只产生候选，实际输出决定语义
**Rule**: 当宏可能消费参数末尾的分组或分隔记号时，源码扫描只能登记候选；必须在可见内容排完后检查实际节点，再发布首尾类别等输出语义。
**Why**: #1002 中未知宏可能消费末尾 `{$x$}`、`$` 或 `\)`，只凭源码形状会把没有排出公式的命令误记为 math。采用“语法候选＋实际节点确认”后，公式边界才能与直接输入保持一致。
**Source**: `llmdoc/memory/reflections/1002-inline-math-boundary.md`

### 状态表中的绿色单元才进入通过基线
**Rule**: 矩阵出现部分失败时，为已经通过的精确单元增加回归测试；失败单元留在跟踪 issue 中，既不写成 `.tlg` 通过基线，也不通过跳过整个场景丢失邻近的绿色单元。
**Why**: #992 的 `xCJKecglue=true` 补测中，同一个命令常只有 `01/11` 或 `10/11` 失败。如果按场景整体跳过，会让 `00/10` 或 `00/01` 的既有正确行为失去保护；如果接受当前输出，又会把 #1003 的缺陷固化为规范。
**Source**: `llmdoc/memory/decisions/992-command-boundary-capture-register.md`

### 先穷举机制维度再抽象公共原语
**Rule**: 面对不断增长的边界 edge case，先用完整矩阵和节点探针证明失败可归入有限节点形状，再按形状设计注册策略；不要从一个成功 MWE 直接泛化实现。
**Why**: #999 把 #491 看似分散的命令问题收敛为 box、wrapped-box、stream、transparent、post-transparent 五类，并用同一 capture 状态机覆盖实际首尾类别和嵌套。
**Source**: `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 替换旧框架必须审计全部真实入口
**Rule**: 删除旧 helper 后，从每个公共命令追到真实扫描分支和共同结束点，并为每条入口补矩阵与状态归零断言；不能只验证最显眼的包装宏。
**Why**: #999 复查时发现原生 `\uline` / `\xeCJKfntefon` 绕过包内 fntef 入口，`\lstinline{...}` 也绕过分隔符路径；补齐 `\ULon` 与 `\lst@InlineG` 后共享 framework 才真正涵盖旧补丁的支持面。
**Source**: `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 节点不可判源时必须声明机制边界
**Rule**: 当两种输入产生完全同构节点时，记录不可区分的机制证据、最窄风险窗口和稳定 workaround，不用更宽的启发式扫描假装能够判源。
**Why**: 已注册命令右侧的源码空格与同参数显式 `\hskip` 没有来源标签；#999 只在 pending 已设置且下方有可信 marker 时暂时移除候选 glue，并用 `\kern0pt` 提供可测试的保护方法。
**Source**: `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 证据说明层不能再经过被测状态机
**Rule**: 可视 MWE 的输入标签、源码转录和标尺应在被测排版路径之外生成；若无法隔离，就显式编码状态并把差异字符可视化。
**Why**: #991 的第一版 MWE 用 `\texttt{\detokenize{...}}` 展示源码，但该文本仍被 xeCJK 处理，四种源码空格组合看起来相同；显式 `00/10/01/11` 与 call-site `\verb*` 直接扫描才恢复可审计性。
**Source**: `llmdoc/memory/archive/2026-07-18/991-setref-boundary-fix-and-evidence.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 原型预览与已合并状态必须分层
**Rule**: 未合并实现的状态表只作为固定提交的 PR 预览；面向用户的 issue 活表必须等合并后从合并提交复验再更新。
**Why**: #999 的矩阵可以提前辅助 review，但若同步到 #992 就会把原型误报成主线事实，并失去对后续 rebase 或审查修订的可追溯性。
**Source**: `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 方向性标点策略必须保留样式与覆盖优先级
**Rule**: 修复单向标点对时，把政策放在可配置的样式计算层，并分别回归反方向、其他样式、显式字符对、全局设置和禁则；不要在 transition 中无条件短路。
**Why**: #975 若直接跳过 `FullLeft→FullRight` kern，会破坏 `banjiao` 和 `\xeCJKsetkern`；样式键只让 `quanjiao` 改默认且保持 nobreak。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`

### 字体度量回归要隔离 shaping 与首次初始化
**Rule**: 涉及区域字形和 side bearing 时使用独立字体面，并在 `\START` 前预热所有 lazy family，再记录定量基线和渲染证据。
**Why**: #975 中 `Language=` 不能改变 feature-blind 的 glyphbounds 证据，首次按需加载 Noto TC/JP 会污染 `.tlg`；#999 的 FandolFang 也必须预热才能消除三平台 fontspec 尾随日志差异。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

## Feature request 评估

### 先验证真实任务是否已被现有机制覆盖
**Rule**: 复核长期 feature request 时，先检查当前源码、加载时序、上游生态和语义化公开接口，分别记录“原始故障已解决”“仍有兼容边界”和“需要新功能”，不要直接实现 issue 当年的 workaround。
**Why**: #336 已有 `Others` 自动传播，#510 的 crash 已由禁载冲突包解决且有 PXrubrica，#808 已有 `\xeCJKVerbAddon`；三者都不需要表面请求中的更宽 API，但各自仍有明确的时序、旧协议或断行边界。
**Source**: `llmdoc/memory/archive/2026-07-13/336-347-510-808-553-feature-request-triage.md`

### 把技术可行性与产品化决策分开
**Rule**: 先把 feature request 重述为真实需求并用最小原型验证可能性，再独立审计作用域、架构假设、兼容面和低风险替代方案；原型成功不等于应增加稳定接口。
**Why**: #553 的混合类原型推翻了“XeTeX 无法分离字体与间距”的判断，#347 的装盒原型也证明局部机制可行；两者一旦接入完整 class/shaping/Boundary 状态机都会跨越多个子系统，因此仍应 `not planned`。
**Source**: `llmdoc/memory/archive/2026-07-13/336-347-510-808-553-feature-request-triage.md`

### 同名依赖必须核对实际解析与协议
**Rule**: 跨后端判断宏包兼容性时，先核对实际载入文件、协议和输出证据；只有替代实现 API 同构时才可透明替换，否则应明确拒绝并给出迁移路径。
**Why**: #381 中 XeTeX 的 `CJKfntef` 实际被替换为 `xeCJKfntef`，而 LuaTeX 会载入传统 `CJK.sty` 并破坏字体族状态；`lua-ul` 虽功能相近但 API 不同，不能静默冒充。
**Source**: `llmdoc/memory/archive/2026-07-13/381-cjkfntef-backend-boundary.md`

### 下游模板只应取得稳定数据，不应被上游接管样式
**Rule**: 下游模板依赖私有状态时，按真实调用点提炼最小的数据与 predicate 接口，同时把标题文本和视觉样式留给下游现有模板系统。
**Why**: #275 中 SJTUBeamer 的六个私有变量依赖可收敛为三个按层级查询；若新增 insert 命令或公开样式宏，反而会复制 Beamer 接口并冻结 ctex 内部组织。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

### 功能变化与无回归迁移需要不同视觉 oracle
**Rule**: 新接口既改变部分行为又替换下游私有依赖时，分别验证“目标行为确实变化”和“等价迁移像素不变”。
**Why**: #275 的自定义 MWE 证明 `numbering=false` 会移除标签布局，SJTUBeamer 9 页 `AE=0` 则证明从私有宏迁移到公开接口不改变既有主题输出。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

### 无运行变化的文档修复要分离说明差异与行为证据
**Rule**: 只补充既有兼容契约时，用手册前后图证明信息缺口已修复，另用 MWE 展示稳定行为；不要虚构运行时“修复前后”。
**Why**: #402 没有修改 `autoindent` 实现，真正变化是手册新增零缩进例外；同页手册对比与三场景 MWE 分别回答“说明变了什么”和“所述行为是否真实”。
**Source**: `llmdoc/memory/archive/2026-07-14/402-autoindent-documentation-contract.md`

### 并行测试快照前先确认新文件已被 git 看见
**Rule**: 使用基于 `git ls-files` 的隔离测试脚本前，确认新测试已进入索引；否则全量测试数量和结果都不会包含它。
**Why**: #275 的新测试完全未跟踪时，`make check-ctex` 的四引擎快照仍各运行 183 项，进入索引后才运行 184 项。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

## CI 与 Agent workflow

### 复合 Action 与 job step 是两套字段与默认值语义
**Rule**: 复合 Action（`runs.using: composite`）的合法 step 字段和 `run` 默认 shell 都与 job step 不同；不能把 job step 的经验直接套用到复合 Action，也不能反过来套用。自建校验器（如 `scripts/validate-action-metadata.py`）的允许表必须以目标平台（GitHub Actions）实际拒绝行为为准，新增字段前先确认它在当前上下文里到底合不合法；本地测试全绿只证明校验器内部自洽，不证明平台会接受。
**Why**: PR #1030 中 `timeout-minutes` 只在 job step 合法，写进复合 Action 会被 runner 在加载 `action.yml` 时判 `TemplateValidationException`；本仓库的门禁曾把这个字段误判为复合 Action 合法字段，本地测试却全绿。PR #1031 中复合 Action 的 `run` 默认带 `pipefail`，与不带 `pipefail` 的 job step 相比，同一句管道右侧提前 `exit` 的 awk 会有不同的退出码，字面相同的代码在两种 step 类型里行为不一致。
**Source**: `llmdoc/memory/reflections/1030-1031-composite-action-semantics.md`

### 加载期失败会遮蔽同一 Action 内的运行期缺陷
**Rule**: 一处加载期失败（manifest 校验、字段解析）会让同一 Action 内后续所有代码路径都从未真正执行过；修好第一个失败点后，应预期还有第二批此前未被执行到的路径可能出错，不能把“这次能加载了”当作整体验证完成。
**Why**: PR #1030 修好 `timeout-minutes` 导致的加载期失败后，Action 才走到工具安装阶段，随即在 PR #1031 暴露出此前从未执行过的 awk 管道在 `pipefail` 下会以 SIGPIPE 终止 step 的独立缺陷。
**Source**: `llmdoc/memory/reflections/1030-1031-composite-action-semantics.md`

## LaTeX2e 命令钩子机制

### 通用命令钩子不能包装命令本体即赋值语句的场景
**Rule**: 用 `cmd/<命令>/before`／`after` 这类 `\AddToHook` 钩子包装某个命令时，先确认该命令本体是否就是一条赋值语句（如 `\setbox`）。若是，钩子代码里的任何赋值都会消耗调用方留在原地待用的 `\global`／`\long` 等前缀，使调用方前缀静默失效——不报错、不警告，只是行为退化为局部/非长命令语义。这类命令必须改用专用适配器：直接重定义其内部入口，把原本挂在钩子里的副作用移到赋值发生的位置内部，让前缀始终紧邻真正的赋值原语。
**Why**: #1029 中 `cmd/sbox/before` 钩子里的 `\@@_boundary_capture_suspend:` 做了多个全局赋值，吃掉了 `\global\sbox` 的 `\global`，导致 algorithm2e 的 `\global\sbox\algocf@capbox{...}` 在浮动体分组结束时静默丢失整段标题。最小复现不需要加载 xeCJK：`\AddToHook{cmd/sbox/before}[probe]{\advance\cnt by 1}` 单独就会触发同一问题，换成 `\relax`（无赋值）则不触发，证明这是 LaTeX2e 命令钩子机制的通用陷阱，不是任何具体宏包的缺陷。修复用 `\@@_boundary_sbox:Nn` 重定义内部入口 `sbox `，与仓库已有的 `color@b@x`／`@textcolor` 专用适配器同属一类。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`、`llmdoc/memory/decisions/1029-sbox-adapter.md`

### 报告者给出的可用变通不能替代对代码历史用途的核实
**Rule**: 报告者已定位到具体代码并给出能让当前场景可用的变通（如删除某个钩子）时，先核实这段代码的既有职责，再决定是直接采纳变通，还是保留语义、更换实现方式。变通可用不代表它是正确修复。
**Why**: #1029 中删除 `cmd/sbox/before`／`after` 两个钩子确实能让 algorithm2e 的标题恢复，但这两个钩子是 #992 系列刻意引入的，用来隔离 `\sbox` 内部 scratch box 的测量过程，防止测量用的盒子与其中的颜色切换污染外层 capture 与恢复链；直接删除会撤销这条隔离，重新引入旧问题。最终改为专用适配器，把暂停观察移到盒子内部，同时保留隔离语义和 `\global` 前缀完整性。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 缩小复现到不含本包的最小样例，才能确认是上游机制的通用陷阱
**Rule**: 怀疑某个缺陷可能是上游机制的通用性质而非本包特有时，把复现缩到不加载本包的最小 LaTeX/TeX 样例。确认为通用陷阱后，修复形态和文档警告的落点都会随之改变——不能只在具体案例的代码注释里说明，还要在架构文档里记录为独立的机制边界。
**Why**: #1029 若只盯着 xeCJK 的 `\@@_boundary_capture_suspend:` 内容，容易把注意力放在这条钩子本身该不该做全局赋值上；缩小到不含 xeCJK 的五行纯 LaTeX 后，才确认触发条件是「`cmd/<赋值命令>/before` 钩子里有赋值」这一更一般的机制，这直接决定了要用专用适配器而不是调整钩子内容，也决定了要在 `experiment/boundary-register` 用户手册里为「命令本体即赋值语句」这类场景加一条通用警告。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`
