# Lessons Learned

Curated cross-task rules distilled from archived memory.

## 共享文档基础设施

### 缩放最窄的可变排版对象
**Rule**: 修复复合 coffin 或 table 的溢出时，只缩放实际越界的子盒，保持日期、状态标记和相邻栏不变。
**Why**: Issue #963 首版缩放整个 functions coffin，连带压缩 Added/Updated；改为只处理函数名与 TF 后缀后才稳定。
**Source**: `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 上游私有补丁必须硬失败
**Rule**: 覆盖 l3doc 等上游私有接口时，同时维护最低版本校验、依赖接口清单、专项回归，并用 critical 错误暴露不兼容。
**Why**: ctxdoc 的补丁健康检查证明普通 error 在 nonstop CI 中可能继续执行，而完整重定义还会放大静默漂移风险。
**Source**: `llmdoc/memory/archive/2026-07-12/704-ctxdoc-patch-health-test.md`, `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 用接口证据复核自动审查
**Rule**: 对名称相近的 expl3 控制流或异常分支，必须用 `interface3` 原文、最小实验或失败路径测试验证审查结论。
**Why**: #964 的自动审查曾反转 `\dim_until_do:nNnn` 的真实语义，版本校验也先后出现 ExplSyntax catcode 错位和条件丢失；仅跑正常路径不足以发现这些问题。
**Source**: `llmdoc/memory/archive/2026-07-12/963-ctxdoc-long-function-scaling.md`

### 生成物排序不能反向支配源码组织
**Rule**: `\changes` 等生成源注释应贴近对应实现；生成结果的不连续不能通过挪远源码注释或手改生成物来美化。
**Why**: #975 中把三条记录集中虽让 CHANGELOG 连续，却让 `quanjiao`/`kaiming` 记录脱离实现；最终恢复源码邻近性并接受提取顺序。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`

### 跟踪生成物必须走仓库的 canonical target
**Rule**: 源文件变化影响已跟踪生成物时，先从 Makefile/guide 找唯一生成入口，运行后核对只产生预期 diff；不要手改生成物去追 CI 文本。
**Why**: #991 手工同步的 xeCJK CHANGELOG 与 `\changes` 提取器漂移，`check-changelog-result` 失败；`make changelog` 确定性重建后只有目标文件变化并通过校验。
**Source**: `llmdoc/memory/archive/2026-07-18/991-setref-boundary-fix-and-evidence.md`

### `\changes` 条目里的 makeindex 特殊字符要按两个下游同时验收
**Rule**: `\changes` 条目正文会经 makeindex 处理，`=`（actual）、`!`（quote）、`>`（level）、`|`（encap）在那一层有语法含义。未转义的 `=` 会让条目在该处截断、只剩后半段进 `.gls`，排版时报 `Extra }` 使 `l3build doc` exit 1。但**转义不是好解法**：`!` 会原样漏进 `scripts/extract-changes.py` 生成的 `CHANGELOG.md`，`|&|` 又撞 encap。优先**改写句子绕开这些字符**，判据是同时核对 `.gls` 渲染结果与重新生成的 `CHANGELOG.md`，只看一边会漏。
**Why**: #1054 中 `\changes` 里的 `\catcode`\&!=6` 一处，去掉 `!` 后 makeindex 把条目截断成 `6}）时…`，排版报 `Extra }`；恢复 `!` 能过 makeindex 但 CHANGELOG 里多出一个字符。字符含义的出处是 `gglo.ist` 的 `actual`／`quote`／`level` 指令与 doc 的 encap 设置。细节见 `reference/coding-conventions.md` 的对应一节。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### 看起来像笔误的转义字符，先查它在工具链里有没有语义
**Rule**: 遇到读起来不像句子一部分的孤立符号（`!`、`|`、`=`、`@` 等），不要凭「像是误敲的」就删改；先查它在这条处理链的某一个阶段是否有语法含义——读对应的 `.ist`、配置文件或处理脚本，而不是读上下文语感。这条在改**别人已经写好、且自己并未被要求修改**的内容时尤其要守。
**Why**: #1054 第一次读用户未提交的 diff 时，把 `\changes` 条目里 `\catcode`\&!=6` 的 `!` 判成多余字符删掉，并顺手重新生成了 CHANGELOG；随后 `l3build doc` 报 `Extra }` exit 1。`!` 是 makeindex 的 quote 字符，起实际作用，用户原来的写法是对的。判断依据当时只是「读起来不像句子的一部分」，没有查 `.ist` 里的 quote／actual／level／encap 四个指令。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### 已发布版本不能继续接收新变更条目
**Rule**: 写 `\changes` 前核对最新正式 release tag；发布后的新变更使用下一个未发布版本，不从 `build.lua` 当前值或 CHANGELOG 首节反推。
**Why**: #381 在 ctex 2.6.2 发布两天后落地，首版仍误记为 v2.6.2，合并后才纠正为 v2.6.3。
**Source**: `llmdoc/memory/archive/2026-07-13/381-cjkfntef-backend-boundary.md`

### 测试结论不能超出实际执行的平台分支
**Rule**: 平台条件测试通过后，只陈述该次运行实际执行的分支；配置检查、字体声明、实际字形和度量比较是不同层次的证据，不能互相替代。
**Why**: #994 的 Linux 四引擎回归能检查 `macnew` 生成配置，却没有 Apple 字体，也不会执行 macOS 条件分支；只有 macOS XeTeX/LuaTeX 的运行时探针实际加载并核对了 Regular 字形。
**Source**: `llmdoc/memory/reflections/994-macnew-songti-regular.md`

### 缺陷按代码路径分布，不按报告者用的引擎分布（镜面）
**Rule**: 报告者只在一个引擎下复现，推不出其他引擎不受影响。看到 docstrip 引擎守卫（`%<*engine>`）划出的路径边界时，应把它枚举到的引擎和没枚举到的引擎都实测一遍，而不是只信报告者用的那一个。
**Why**: #1068 的报告只提到 LuaTeX 下 `\selectfont` 重置用户设的 `kanjiskip`；按四引擎逐个实测后发现 upTeX 同样受影响，pdftex/xetex 正常。根因是一段 `\ctex_at_end:n` 重定义被 docstrip 守卫限定在 `pdftex|xetex`，LuaTeX 与 upTeX 都没有它。这是「测试结论不能超出实际执行的平台分支」（#994）在缺陷侧的镜面：那条管的是「测试通过≠已覆盖未执行的分支」，这条管的是「复现≠未复现的引擎不受影响」。
**Source**: `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`

### 字体字形变化必须同步选择、映射和度量
**Rule**: 更换字体集中的正文常规字形时，同时核对各引擎的具名字体、TTC index、zhmap、度量生成源和跟踪数据，并用拥有目标字体的平台验证实际字形与度量。
**Why**: #994 若只把 `Songti SC Light` 改名为 Regular，LaTeX+DVI/upLaTeX 仍会使用旧 index，标点压缩也会继续读取 Light 的 SPA 数据。
**Source**: `llmdoc/memory/reflections/994-macnew-songti-regular.md`

### 本地审查报告是独立的完成校验输入
**Rule**: 运行过本地 code-review 时，在完成或 merge 前用忽略规则外的文件盘点读取全部 `.code-review` 报告，并把每条发现映射到当前树核实。
**Why**: PR #976 只审计 GitHub 活动，漏掉被 `.gitignore` 隐藏的报告中两个有效小问题，合并后不得不用 #978 补修。
**Source**: `llmdoc/memory/archive/2026-07-13/976-978-ignored-local-code-review.md`

### 正式审查必须与实现上下文隔离
**Rule**: 主代理的实现检查只算自检。正式 code review 必须启动不继承主代理设计与实现对话的新子代理，只提供仓库规则、公开目标、完整 base/head SHA、范围和必要公开证据；报告须记录隔离方式、允许输入和固定范围。增量审查可读取上一份正式报告取得截止点，但不能继承主对话。
**Why**: PR #1009 的 `bb14d1a3..2092edad` 审查虽由独立子代理完成，报告却没有记录上下文隔离方式，不能证明审查者未继承实现假设；后续 llmdoc 增量审查因此把“新会话、受限输入、报告留痕”补成可审计校验。
**Source**: `llmdoc/memory/reflections/1002-inline-math-boundary.md`

### APPROVE 总评不覆盖详情中的 finding
**Rule**: 任务要求处理全部审查问题时，按阻塞、重要和小问题的逐项计数闭环；总评为 APPROVE 或建议标为 optional 都不能自动视为已处理。
**Why**: PR #983 第一轮自动审查虽为 APPROVE，仍列出 1 个实现注释小问题；初次收尾跳过后，最终 completion audit 才补上并经增量审查确认 0/0/0。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

### 验证强度按当前增量风险收缩
**Rule**: 主体改动已有完整验证后，仅涉及注释或措辞的后续小改使用差异检查、必要的定向实验和强制 CI；只有增量重新触及语义、解析、生成物或基线时才重跑完整本地校验。
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
**Rule**: 使用临时 MWE 验证工作树生成的 TeX 宏包时，把日志中的实际文件路径列为证据；文件名、输出目录名和运行命令都不能证明加载的是当前实现。这条检查**必须写成每次运行都执行的固定动作**，不能靠「出错会提醒我」兜底：不指定 `TEXINPUTS`、或者它指向的目录不存在时，`xelatex` 既不报错也不警告，而是静默回落到系统安装的同名宏包，编译照样成功、读数照样是一组像样的数字。也就是说这条失效没有任何主动信号，只有主动核对日志里的 `Package:` 行才看得见。
**Why**: #1012 的一次实验实际加载了 TeX Live 中的旧版 `xeCJKfntef.sty`，却把图片标成修复后结果。核对日志确认加载 `xeCJK/build/unpacked/xeCJKfntef.sty` 后，视觉证据才与固定提交对应。这条教训在 #1026、#1047 之后于 #1057 又一次发作（第一次跑 MWE 加载的是系统 TeX Live 的 v3.10.4 而非工作树的 v3.10.5，是后来 `grep` 日志才发现的），共同点都是「以为自己在测工作树」。#1057 结论未被带偏纯属运气——两版在那条路径上行为恰好相同；若不同，判断方向会完全相反。
**Source**: `llmdoc/memory/reflections/1012-fntef-decoration-overlap.md`, `llmdoc/memory/reflections/1057-fntef-nest-linebreak.md`

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

### TeX 的诊断信息绑定当时正在构造的那个盒子，而它可能是随后被丢弃或只取尺寸的中间产物
**Rule**: `Missing character`、`Overfull` 一类警告只说明「某处用了某个字体／某个盒子排不下」，**不**说明可见输出坏在哪——排版代码里常有只用来取宽高的临时盒子，它从不进入页面，但同样会产生警告。判断缺陷性质要看最终产物的几何量（PDF bbox、节点列表里那个盒子自身的尺寸），不要按警告出现的位置反推可见输出。相应地，写测试时也要先确认判据落在哪个盒子上。
**Why**: #997 的 issue 标题、两张截图和两条 `Missing character: There is no 中 (U+4E2D) in font [lmroman10-regular.otf]` 三者互相印证，都指向「汉字排不出来」，但这三样证据全部产生在 `\l_@@_tmpa_box` 上——一个只用来量宽、从不放进页面的临时盒子。实际 PDF 里汉字完全正常（它由量宽盒子之外的 `\@@_save_CJKsymbol:n` 输出，那时后备字体仍有效），坏的是拼音被压缩：`pdftotext -bbox` 实测缺陷版 `zhōng` 2.79pt、修复版 9.96pt，与汉字「中」的 9.96pt 对齐。若按警告方向去查字体查找链或 `\XeTeXglyphbounds`，会离根因越来越远。
**Source**: `llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

### 字符型装饰要分别验证 PDF 文本与页面视觉
**Rule**: 只用于绘图的字符或数学内容应以空 `ActualText` 排除文本语义；tagged PDF 还要检查内层标记，必要时在最小范围暂停 tagging。验收时分别检查普通／tagged PDF 的文本提取和修复前后页面渲染，不能让其中一项代替另一项。
**Why**: #1017 中波浪线、斜删除线和用户符号虽位于装饰盒与 leaders 中，仍会以 `:`、`/`、`.`、`*` 混入复制结果；单用 Artifact 或外层 `ActualText` 都不能稳定约束 tagged PDF 的内层数学标记。空 `ActualText` 加最小范围 tagging 暂停清除了提取污染，而 300 dpi 的 `AE=0` 独立证明页面外观没有变化。
**Source**: `llmdoc/memory/reflections/1017-fntef-actualtext.md`

### 弹性间距必须验证伸缩量和实际断行
**Rule**: 测试可伸缩间距时，分别核对 natural、stretch 和 shrink，并在有限容差下实际排段检查断行；盒子自然宽度只能作为第一层证据。单个 `\hbox` 或 `\vbox` 不能替代真正断行：其内部的 glue set 会把内外层的可伸缩量一并用掉，两种实现即使内外层收缩量分配不同也会得到相同的宽度或高度，必须把内容放进 document 主垂直列表、让 `\par` 真正决定断行，才能看出内外层区分。
**Why**: #1002 中自然宽度相同的 glue 仍可能具有不同的伸长量和收缩量。只有缩短段宽并比较 badness 与段落高度，才能证明 stream 和已装入盒子的冻结空格都保留了正确的外层断行能力。#1026 中前三版测试分别把正文装进 `\hbox`、`\vbox`，或用 `\def\BODY` 承载正文，均显示缺陷版与修复版数字相同；只有改成“主垂直列表里真正断行，且调用处写字面正文”才第一次测出差异。
**Source**: `llmdoc/memory/reflections/1002-inline-math-boundary.md`, `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 判断修复是否到位需要三个对照点，第三个是未受影响的发布版
**Rule**: 缺陷版、修复版之外，还要测一遍**未受影响的发布版**。只比前两个只能回答「有没有变好」，回答不了「变好到该有的程度了吗」。修复版与发布版数值相同、渲染逐像素一致时，结论是「修回了发布版行为」——这既能排除本次引入新问题，也可能揭示发布版自己就带缺陷。
**Why**: #1026 修复后原 MWE 溢出 18.91pt → 4.47pt，只看这两点像是修好了。加上发布版 v3.10.3 也是 4.47pt、且与修复版渲染逐像素相同（`ImageChops.difference` bbox 为 `None`），才看出 4.47pt 是发布版本来就有的另一半缺陷（#1037），而非终点。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### PR 合并后要回放报告者的原始 MWE，别只看自己的测试基线
**Rule**: 修复上线后，用报告者给的原始 MWE 复验，而不是以自己新增的回归全绿为准。自己的基线可能把残留缺陷冻结成预期值；报告者的 MWE 是外部判据。把非零缺陷量写进基线时，必须注明它为什么不是零、零需要什么条件。
**Why**: #1026 的 `fntef-shrink01` 把「修复后为 3.64pt」写成预期，四个用例各固定一条 3.64pt 的 `Overfull` 行。测试全绿、文档写着预期值，于是同源的另一半缺陷有了一份看起来很正规的校验替它背书，直到报告者追问「这里的 After 是预期的吗」才暴露。这比没有测试更糟——没测试只是没覆盖，冻结残留缺陷是主动声称这是对的。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### `\hbox to` 的实际宽度恒等于目标宽度，量收缩量要用 `\badness`
**Rule**: 断言前先问「这个量在缺陷存在时会变吗」。`\hbox to <dim>` 总会取到目标宽度，`\wd` 减目标恒为 0，与收缩量够不够、在内层还是外层完全无关。要判断弹性量是否可用，观察 `\badness`（够时为小值、不够时 1000000），并加「一定够」「一定不够」两个对照证明取值可达、不恒真。
**Why**: #1037 的第一版 TEST 6 断言 `\hbox to` 压窄后的 `overshoot` 为 0，生成基线后才发现这个断言结构上恒真，真正的信号在旁边那条 `Overfull ... detected` 里。改用 `\badness` 并把压窄量取在 1.11pt 与 2.22pt 之间后，撤销修复会让它由 73 变 1000000。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### `.tlg` 基线不要冻结报告文本里的绝对行号
**Rule**: 当用例的观察量不是警告文本本身时，把警告抑制掉，别让它进基线。`l3build` 归一化的是 `on line %d*`、`on input line %d*`（`l3build-check.lua:210,211`）、`at lines %d*--%d*`（`:217`）与行首的 `l.%d+ `（`:144`）；单数形式的 `detected at line %d`（`\hbox to` 的 Overfull 报告用的就是它）不在其中，进基线就冻结了一个绝对源码行号，任何无关的行数变动都会让该用例失败。抑制 Overfull 要用 `\hfuzz`，不是 `\hbadness`——后者只管 Underfull 警告的阈值。
**Why**: #1037 的 TEST 6 观察量只有 `\badness`，却把 `Overfull ... detected at line 149` 冻进了基线；在 `.lvt` 里插入一行注释即失败。注释里原本还写着 `\hbadness=10000` 抑制 Overfull，实测无效：默认值与 `\hbadness=10000` 都照样输出，只有 `\hfuzz=100pt` 消掉，且三种设置下 `\badness` 不变。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 幂等守卫的观察范围必须覆盖被守卫函数的全部写入范围
**Rule**: 给回写型函数加「已同步就跳过」的守卫时，守卫检查的字段必须涵盖该函数会写的**每一处**。只看其中一处就提前 return，会让其余位置在失同步后永远得不到修复——而且这是相对改造前的**功能回归**，容易被当成「本来就不管」而漏掉。
**Why**: #1041 的共享 `update_tag` 写 `{\ExplFileDate}{<ver>}` 与旧式 `[YYYY/MM/DD v<ver>]` 两处，守卫只看前者。`xpinyin.dtx` 两种写法并存，实测新代码在 `[...]` 行失同步时不再修复它，基线旧代码会修；该包又不在任何版本校验内。改为「算出目标写法后整体比较，内容未变即 no-op」。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 修一个「守卫范围不足」时，检查同一处是否还有别的字段
**Rule**: 把幂等守卫从「只看字段 A」扩到「A 也看」时，要枚举该写入点的**每一个字段**。修好版本号却冻住同一行的日期，是同一缺陷类换了个格子。若某个字段确实决定不再自动修复，那是取舍——必须在代码注释与文档里写明代价，不能让它看起来像纯粹的行为恢复。
**Why**: #1041 我把 `[<日期> v<版本>]` 的版本字段修回可修复，却让日期字段在「版本对、日期陈旧」时不再被修复（基线会修）。盲审用 `zhmetrics/zhmCJK.dtx`（唯一只有 `[...]` 行、没有 `{\ExplFileDate}` 的文件）单独隔离出这一格。取舍本身站得住——基线在已同步的 zhmetrics 上也会把日期刷成今天，那样校验的 diff 永不为零——但我的提交信息把它写成了单纯的行为恢复，没记录代价。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 校验侧的语法必须与写入侧一致（含前缀剥离等所有规范化步骤）
**Rule**: 校验提取某个值时用的模式，不能比写入该值的代码更严格——这包括**写入侧做过的每一步规范化**。写入侧剥了 `v` 前缀、校验侧不剥，等价于两侧对「同一个版本号」的定义不同：合法输入会通过前一道校验却在后一道校验被拒，而给出的修复提示照做不会有任何变化。同一份配置里已有正确写法时（如 `zhlineskip` 那条），照抄另一条更要逐项核对。
**Why**: #1041 三次踩同一类：(1) release 校验假定三段式数字，两段式 `3.11` 过 PR 校验却在 release 报空 stamp；(2) `read_dtx_version` 的 `[%d%.]+` 拒绝 `3.11a` / `0.0-beta`（后者是 release.yml 注释自己列为合法的写法），而 `uploadconfig.version` 是 `l3build upload` 的必填字段；(3) xeCJK case 的 `LUA_VER` 不剥 `v` 前缀，而写入侧 `update_tag` 有 `target:gsub("^v","")`——`version = "v3.10.5"` 时 PR 校验放行、release 校验拒绝。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 项目的语言约定要在动手前读、收尾时按词表自查
**Rule**: 仓库根目录的 `CLAUDE.md` 列了禁用词（「闸门」「实装」「拍板」「对拍」「形态」等）与风格要求（不用「真……」强行强调、中文句子用全角标点、不把名词压成单字）。这类约定不会被任何测试或 CI 拦住，必须在写之前读、收尾时对着词表逐条 grep 自查。自查时要区分「本次引入」与「既有内容」——逐行与 base 比对，别整仓替换，那会让 diff 失焦。`.yml` / `.lua` 注释与 `llmdoc/` Markdown 的标点惯例不同，改前先核对基线。
**Why**: #1041 我写了 26 处「闸／闸门」、12 处「形态」和「真回写」，全部违反 `CLAUDE.md` 明确点名的约定，直到用户提醒才发现。说明我把「读 CLAUDE.md」当成了背景信息而非待执行的检查项。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 放宽模式时要列出该函数全部写入侧的实际写法逐个验证
**Rule**: 把一个提取模式放宽以接纳更多合法写法时，只验证「原先被误拒的那些现在能过」是不够的——还要把该函数**所有**写入侧的实际写法列出来逐个回归。放宽过度会让模式匹配上占位宏、注释等本不该匹配的内容，返回一个「看起来正常」的错误值，这比返回 nil 更危险：nil 会让下游报缺字段，错误字符串会被静默使用。
**Why**: #1041 我把 `read_dtx_version` 的 `[%d%.]+` 放宽成 `[^}]+`，只验证了 `3.11a`／`0.0-beta` 能过。但 ctex 五个拆分 dtx 的版本行是 `{\ExplFileDate}{\ExplFileVersion}{...}`（真实版本在 `$Id:$` 行），新模式在第一条分支就命中并返回字面串 `\ExplFileVersion`，使回退分支永不可达——而函数自己的 docstring 正把 ctex 列为该分支的代表。改成 `[^}\]+` 后八个包实测全部正确。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 把崩溃改成静默返回，往往比崩溃更糟
**Rule**: 修「函数在某输入下崩溃」时，别直接改成静默返回。崩溃难读但可见；静默成功会让调用者以为操作生效。要给出可操作的提示再返回。
**Why**: #1041 我把「未设 `version` 的包漏掉 CLI 参数时 `attempt to concatenate a nil value`」改成静默 `return content`，于是 `cd xpinyin && l3build tag` 打印 `Tagging`、退出 0、什么也不改。这正好违反了我在同一个 PR 里提升的「参数被忽略时要显式告警」规则——只给另一条路径加了告警，却漏了这六个包最可能犯的手滑。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 覆盖矩阵要以「入口枚举」为准对账
**Rule**: 记录「哪些包被校验覆盖」的表，其行集合必须与实际入口的枚举（如 workflow 里 `case` 能识别的全部 tag 前缀）逐项对账，而不是凭印象列举。漏掉的那一行正是这张表想拦住的静默跳过。
**Why**: #1041 我新建的覆盖矩阵漏了 `zhmetrics-uptex`——它能触发 `release.yml` 却不在表里，正是矩阵存在的理由。补它时我用 `grep -oE '[A-Za-z-]+-v\*'` 对账，该模式不含数字，于是**同一次对账又静默漏掉了 `xCJK2uni`**，并把错误的「九个」写进了文档与提交信息。对账脚本自己犯了和被查问题同型的白名单错误。教训延伸：**对账模式要能匹配全部实际取值**（包名含数字与连字符），且对账结果要与独立计数交叉验证。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 诊断信息的来源不能是可被污染的环境变量
**Rule**: 打印路径、目录名一类诊断信息时，用内核态查询（Lua 下 `lfs.currentdir()`）而非 `os.getenv("PWD")`。环境变量可被调用方覆盖，会让「修好的」路径重新变成错的；`PWD` 在 Windows 上还根本不存在。
**Why**: #1041 我把告警里的包路径从 `module`（小写 `xecjk`，与目录 `xeCJK/` 不符）改成 `os.getenv("PWD")`，盲审实测 `PWD=/somewhere/else l3build tag 3.10.6` 打印出 `else/build.lua`——又一个不存在的路径，与这次修复的目的正好相反。改用 `lfs.currentdir()`（texlua 预置全局表，l3build 自身也用）。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 参数被有意忽略时要显式告警，不要静默丢弃
**Rule**: 当实现改为以配置为事实源、从而忽略用户传入的参数时，检测到冲突要打印提示。静默忽略会让命令看起来成功却什么也没做，使用者无从发现自己的参数没生效。
**Why**: #1041 让 `update_tag` 以 `build.lua` 的 `version` 为准后，`l3build tag 3.10.6` 在 xeCJK 下退出码 0、打印 `Tagging`、实际什么也没改。补了一行告警指明事实源。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 白名单式 CI 校验默认放行，未覆盖的包无人察觉
**Rule**: 按包 opt-in 的校验（`paths` filter、`case "${PKG}"` 分支）对未列出的包**静默跳过**，且 `::notice::` 不是 failure、CI 仍全绿。这类校验必须配一份显式覆盖矩阵（或自动对账），并在加新包／某包后来具备条件时同步更新。区分「有意识排除并留 followup」与「无意识从未接入」——后者是缺陷。
**Why**: #1041 之前 xeCJK 从不在版本校验内：`check-tag.yml` 的 `paths` 只列 ctex/zhlineskip，`release.yml` 的三方校验里 xeCJK 落进 `*)` 并打 `::notice::...跳过三方校验`。于是 `xeCJK-v3.10.5-rc2` 发出了一个自报 `v3.10.4` 的包，release workflow 全程绿灯。对照 #935 的 zhspacing：那是有意识排除且留了 followup issue。**同一缺口后来又出现一次**：zhnumber 与 xCJK2uni 也从未被覆盖，而两者的 `.dtx` 都有 `{\ExplFileDate}{<ver>}`、`l3build tag` 确实会回写——那条「不使用 l3build tag 版本 stamp 机制」的 notice 是**错的**。#1041 的反思当时已写下「应当有一条未覆盖清单的对账机制」并留作后续，正因为没做，第二次才又靠人工翻查才发现。**所以这条规则的落实方式是自动对账脚本，不是「记得同步矩阵」**：现由 `scripts/check-version-gate-coverage.py` 在 `check-tag.yml` 的 `gate-coverage` job 里强制执行；它当场又查出第三个漏掉的包（jiazhu）。**同一形态在测试文件层面也发作过**：#1068 里既有的 `ccglue01`／`ccglue02.lvt` 对 LuaTeX 与 upTeX 直接 early-exit 打印 `LuaTeX: not tested yet.`，而 #1068 的缺陷恰好只在这两个引擎上出现——`not tested yet` 与 `::notice::...跳过` 是同一类静默放行，都会让「文件存在」被误读成「覆盖存在」。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`, `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`

### 「跑了但什么也没校验」的 job 比没有 job 更危险
**Rule**: 加一道校验后，必须验证它在**被校验对象出错时确实会失败**，而不只是「加上之后 CI 是绿的」。特别当校验形如「跑某个命令 + 比对 diff」时，要确认那个命令在当前配置下真的会产生写入——命令以 0 退出且什么都不改时，diff 天然为零，job 恒绿却会让覆盖矩阵显示 ✓，比缺这道校验更难发现。
**Why**: 给 zhnumber / xCJK2uni 补 check-tag job 时，两个包都还没有 `build.lua` 的 `version` 字段。未设该字段时不带参数的 `l3build tag` 会打印「未指定版本号, 未作任何修改」并**以 0 退出**，于是照 xpinyin 抄来的 job 跑完 diff 为零、显示通过，实际一无所校。必须同时加 `version` 字段，实测确认「加前不改文件、加后回写且幂等」。
**Source**: `llmdoc/reference/build-and-test.md`（版本管理一节）

### 对账／校验脚本本身也要做判别力实测，它同样会犯被查的那类错
**Rule**: 用来查「有没有漏」的脚本，写完后要对每一处它声称覆盖的接入点各做一次移除实验，确认都能检出。这类脚本最容易犯的是与被查问题**同型**的错误——白名单不全、正则漏一类命名、同一标记在多处出现而只查到其中一处。
**Why**: 两次实例。一是手工对账用 `grep -oE '^ +[A-Za-z-]+-v\*\)'`（不含数字），补 `zhmetrics-uptex` 的同一次对账又静默漏掉了 `xCJK2uni`。二是 `check-version-gate-coverage.py` 初版只用一条正则扫 `check-tag.yml` 全文，而 `<pkg>/**` 在 `paths` 与 `filters` 两段都出现，从 `paths` 里删掉某个包后脚本仍报「已覆盖」；改为取 `paths`／`filters`／`tag-<pkg>` job 三处交集后，三个方向的移除实验才都能检出。
**Source**: `llmdoc/reference/build-and-test.md`（版本管理一节）

### l3build 的 build.lua 里全局名可能已被框架占用，判空要判类型
**Rule**: 在 `build.lua` / `support/*.lua` 里对全局名做「未设置则回退」时，先确认 l3build 没有预定义同名对象。`x or fallback` 只在 `x` 只可能是目标值或 `nil`/`false` 时成立；`x` 可能是别的类型（尤其框架预定义的函数）时必须判类型。
**Why**: #1041 的共享 `update_tag` 写 `local target = version or tagname`，本意是「`build.lua` 设了 `version` 就用它」。但 l3build 自己定义了 `function version()` 供 `--version`（`l3build-help.lua:32`），未设 `version` 的六个包里这个名字是函数，`or` 直接取走函数，报 `attempt to index a function value`。改成 `(type(version) == "string") and version or tagname` 才对。同构先例：`ctex_kit_env_or_nil` 因 GH Actions 空 input 注入 `""` 而必须把空串也当未设置。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 「重新生成 + diff」校验的 diff 范围必须精确等于写入范围
**Rule**: 这类校验的 `git diff` 路径参数只能覆盖生成动作**实际写入**的文件，不能顺手扩大到「相关文件」。扩大范围不增加检出能力，只会在将来某个生成物意外落进那个目录时给出误导性报错。验证 no-op 要在干净 worktree（`git worktree add`）里做——主工作区的未提交改动会被 `git diff` 算进来，结论不可信。
**Why**: #1041 的 `tag-xecjk` job 起初写 `git diff --exit-code -- . ../support`，理由是共享 `update_tag` 在 `support/` 里，而 `l3build tag` 只回写本包 `.dtx`。**注意我当初给的第二个理由是错的**：我写「纳入 `../support` 会让任何改它的 PR 被误判」，后经实测推翻——CI 检出的是已提交的干净树，那份改动不构成 diff，两种写法退出码均为 0；误报只发生在本地有未提交改动时（我把本地现象当成了 CI 行为）。范围应收窄的真实理由是语义精确。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 新增校验要用「复现原事故」验证判别力
**Rule**: 加完一道校验，不能只验证 happy path 通过；要把促使你加它的那个具体事故复现出来，确认校验真的拒绝。这与测试的变异验证是同一条原则——校验的价值完全取决于它对目标缺陷是否有判别力。
**Why**: #1041 把 rc2 事故复现（`\ExplFileDate` 改回 3.10.4）后实测：PR 校验 `l3build tag` 确实回写 → diff 非零 → 拒绝；release 三方校验报 `✗ tag=3.10.5 但 stamp=3.10.4` → 拒绝。另加两个变体：打错 tag（3.10.6）应拒绝、rc 后缀（3.10.5-rc3）应剥离后通过。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

### 事实性陈述的更正以「全仓所有实例」为单位
**Rule**: 改一处计数、页数、文件名、函数名或机制解释后，用 `grep` 扫一遍该说法的所有变体再收工；并把「历史记述」（记录当时事实，保留原值）与「当前事实」（必须统一）分开。同时算上本次改动本身会不会让该数字再变一次。
**Why**: #1038 中「只修一半」连续出现三轮：先只拆被点名的测试而漏掉同类；再更正一句假陈述却只改了两份文档中的一份；最后把测试数从 115 改成 116——而 116 是上一提交的值，本提交又新增一个文件，正确值是 117。每次都是只改了 finding 里出现的那一处。加上收工前的 grep 扫描（计数一遍、指针一遍）后才不再复发。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 会中止编译的用例必须各自独占文件，否则同文件后续用例是假绿
**Rule**: 若一个用例在缺陷版下会以错误中止编译（而不是输出错误的数值），那么同一 `.lvt` 里它后面的所有用例在缺陷版下根本不执行——它们在缺陷版和修复版之间没有可观察差异，是看起来正规实际空转的校验。每个能独立触发该缺陷的用例都要有自己的文件。这不只是排查时的注意事项，而是测试设计约束。
**Why**: #1038 中我把三组用例写进同一个 `tabular01.lvt`。TEST 3（`中文\\`）在缺陷版下报 `Improper alphabetic constant` 并中止编译，实测缺陷版日志里 `TEST 4` 出现 0 次、TEST 5 也一样。我先只拆了 TEST 5，第二轮盲审指出 TEST 4 仍是同样的空壳，并且我在文档里写的「TEST 3／4 各报错」是假的。最终拆成 `tabular01` / `tabular-cr01` / `boundary-bgroup01` 三个文件，逐个实测缺陷版 rc 1。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### XeTeX 的 interchar 类别由「展开后那个不可展开记号的 catcode」决定
**Rule**: 类别选择发生在 `main_control` 主循环：`get_x_token` 正常完全展开取记号，只有 letter / other / `\chardef` / `\char` 四类才按该字符的类别走 `check_for_inter_char_toks`，其余一律固定为 Boundary（4095）。两条推论：`\protected` **不**阻断这个展开（它只对 `\edef`／`\write` 一类记号列表展开有效）；判据是 **catcode** 而非「显式还是隐式」——`\let\iLetter=a` 按字母类别参与，而 `\bgroup`（catcode 1）、`$`、`^`、源码空格、`\relax`、`\kern` 全走 Boundary。不要用 `\futurelet` 反推引擎当初看到了什么：引擎命中 toks 前已 `back_input`，探针看到的是被退回的、且已展开过的记号；要定规则必须直接观测触发了哪一对 `N M`。（在 toks 主体里 `\futurelet` 触碰被退回的字符还会破坏重入保护，导致同一转换无限重复。）
**Why**: #1038 中我据「`\\` 是 `\protected` 宏」推断 group-begin 测试不会为真，与实际相反。纯 XeTeX 对照实测：`\protected\def\PLET{aq}` 后 `X\PLET` 触发的是 Default 类（1→0）而非 Boundary，说明 XeTeX 已把它展开到字母 `a`。`tabular` 里 `\\` 被 `\let` 为 `\@tabularcr`，替换文本 `{\ifnum0=`}\fi...` 的首记号是显式 `{`，于是走进花括号分支并把平衡技巧吞掉一半，报 `Improper alphabetic constant`。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 解释「为什么这个不受影响」要核对那个对象本身，不能从受影响者的特征反面推断
**Rule**: 给出「A 受影响、B 不受影响」的筛选规则前，直接检查 B，确认它确实缺少你归因于 A 的那个特征。从 A 的特征取反得到的规则，很可能把自己的反例列成安全案例——这比不给解释更危险。
**Why**: #1038 中我写「`array` 不受影响是因为它不用 `{\ifnum0=`}\fi` 平衡技巧」。盲审核实：`\@arraycr` 用的正是同一个技巧（`latex.ltx:16818`）。真实判据是替换文本的**首记号**——`\@tabularcr` 以显式 `{` 开头，`\@arraycr` 以 `$` 开头。我当时看到 `\@tabularcr` 有技巧、`array` 没坏，就把「有无技巧」当判据，而两者都有技巧。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### interchartoks 注入的代码遵循最小吸收原则
**Rule**: interchartoks 的代码执行在别的宏正在执行到一半的位置，注入点之后可能是某个替换文本里尚未被 TeX 读取的语法片段。只吸收判断所必需的最少记号：能用 `\futurelet` / `\peek_after:Nw` 不消费就不消费；必须吸收时用 `\afterassignment` + `\let` 吸收单个记号；不要用 `n` 型参数吞整个花括号组，也不要预展开任意可展开控制序列。
**Why**: #1038 中 `\@@_boundary_group_math:w` 为了看组内首记号是不是 `$`，用 `n` 型参数吞掉整组再用隐式分组记号重发。被吞掉的 `{\ifnum0=`}` 是 LaTeX 平衡花括号技巧的一半，该技巧要求反引号紧跟显式字符 `}`；隐式 group-end 不满足，`tabular` 里 `中文\\` 直接报错。改为只吸收那一枚左花括号后，输入流其余部分原样保留，问题消失且 #1002 的行为不变。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 前瞻类状态的探针必须只读且零展开
**Rule**: `\l_peek_token`、`\lastkern`、`\spacefactor` 这类「读一次就可能变」的量，探针不能消费或重新前瞻。包装被测函数自身往往会扰乱它要观察的状态。拿到反直觉结果时先怀疑探针，再怀疑代码；裸 `\futurelet` + `\meaning` 放在被测函数之前是可靠形式。另注意 `\token_to_str:N \l_peek_token` 打印的是变量名而非它持有的记号。
**Why**: #1038 中我先包装 `\xeCJK_CJK_and_Boundary:w` 打印 peek 状态，得到 `gbegin=N`，与真实行为相反——我的插入代码本身重置了 peek 状态；再包装 `\token_if_group_begin:NTF` 只得到无信息的 `[\l_peek_token]`。换成裸 `\futurelet` 探针才看到真相：xeCJK 任何代码运行前，输入流里的下一个记号就已经是 `{`。
**Source**: `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 复用带守卫的函数时，重新验证守卫在新调用点的前置条件
**Rule**: 守卫的强度是相对它原来的调用位置而言的。把函数接到更通用、作用域更长的路径上，等于给它换了一套前置条件——原先到不了它面前的情况现在会到。改动后要问「这个守卫依赖的事实在新位置还成立吗」，并优先改用直接表达目标事实的判据（如状态布尔），而不是从副作用反推的近似判据。凡是「某条件不会发生」的判断，都要主动构造反例编译一次，不能读完代码就归档。
**Why**: #1037 复用 `\@@_ulem_glue:n` 时沿用了「它自带守卫，不在装饰中会退化」的结论。该守卫只比较 `\ ` 的含义是否等于 ulem 保存的 `\LA@space`；它原先只挂在装饰内部局部重定义的 `\CJKglue` 上，作用域随分组失效，所以「`\ ` 被别的宏包改过」根本到不了它面前。接到所有中西文边界都走的全局路径后，加载 `xeCJKfntef` 且重定义 `\ `（`nath`、`morehype`）的文档里，不含任何装饰命令的 `中 abc 文` 直接报 `Too many }'s`。改用 `\l_@@_ulem_stream_started_bool`（「装饰 stream 是否活动」这一事实本身）才正确。该缺陷由本地盲审作为 blocking finding 发现。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 状态布尔为真不等于资源可用；置真点与复位点要成对清点
**Rule**: 状态布尔记录的是「谁开始过」，不是「现在还开着」。判断能否对某资源动手时，直接测那个资源本身的状态，而不是测某个流程是否启动过。写完这类守卫，列出所有能进入该状态的入口与所有能退出的出口，逐一对照——入口比出口多就是缺陷信号。
**Why**: #1037 的守卫先只测 `\l_@@_ulem_stream_started_bool`。该布尔在 `\@@_ulem_stream_begin:` 置真、只在 `\@@_ulem_end:` 置假；而行内公式里的装饰命令经 `\UL@onmath`／`\UL@onin` 结束，不走复位点。于是公式内装饰命令之后布尔仍为真、片段盒已关闭，`$\CJKunderline{中}\mbox{中 abc 文}$` 配 `nath` 报 6 个错误。最终守卫改为「布尔为真且 `\UL@start` 为 `\@empty`（片段盒确实打开）」的合取。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 根因是代码事实，把它写成可 grep 的模式并穷举全部出现位置
**Rule**: 确认根因后，第一件事是把它写成一个可搜索的代码模式（如 `\skip_horizontal:N \l_@@_ecglue_skip`），grep 出全部出现位置形成候选清单，再逐一判断每处是否需要改、不改的理由是什么。不要从复现样例出发反推场景清单——场景枚举永远可能漏，代码位置枚举可以穷尽。
**Why**: #1037 中同一根因共四处补 ecglue 的地方，我分四轮才补齐。穷举时还要注意探针的粒度：「包装函数入口」的探针不区分分支，会把 `\xeCJK_check_for_glue:` 的 math 分支误判为不可达——该处因此又漏了一轮，直到改用「在每个裸调用行直接插桩」才穷尽。原文记为三处（词前、公式象限、字体／颜色声明路径），每轮都由盲审指出。上一轮反思刚写过「按根因枚举象限」，下一轮仍只按新复现样例收工——因为我枚举的是「什么场景会触发」而不是「代码里哪些地方在做同一件事」。后者 grep 一次就能得到十余处完整候选。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 分支级改动需要分支级断言
**Rule**: 同一 `dim_case`／`if` 链里的每个分支是独立路径。改了 N 个分支就要有 N 条断言，并逐分支做变异验证（只撤销该分支，看是否恰好有对应断言失败）。用一条断言宣称覆盖多个分支，通常意味着其余分支可达、实现正确、但完全没有校验。
**Why**: #1037 改了 `\@@_check_for_glue_auxi:` 的 `default` 与 `math` 两个分支，TEST 10 只有 `\mbox{hi}中文` 一条断言（走 `default`）。逐分支变异显示：只撤销 `math` 分支时全套 115 项仍全绿。补上 `\mbox{$x$}中文`（末节点是 math marker）后该分支才有校验。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 穷举的可信度取决于探针粒度与结论粒度一致
**Rule**: 要断言「这一行不会执行」，探针必须钉在那一行上（如在该行插入打印行号的标记），不能包装它所在的函数。函数被调用不等于其中某个分支被执行；用更粗的观测得出更细的结论，等于没验证。
**Why**: #1037 中我 grep 出 12 处候选后，用「包装函数入口」的探针判定 9 处在装饰内不可达，并写成穷举记录。第四轮盲审指出其中 `\xeCJK_check_for_glue:` 的 `\@@_if_last_math:` 真分支确实可达（`$x$中文` 即走到）且仍是裸调用。改用逐行插桩重做后结论才可靠：4 处需改（6 个分支）、10 处确认不可达。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 写「判别力已实测」之前必须真的跑那次变异
**Rule**: 注释或文档里声称某断言有判别力时，必须真的执行过「重新引入缺陷 → 看到测试失败」这一步。照抄句式而不复跑，比不写更糟——它会让后来者放弃复核。
**Why**: #1037 的 TEST 9 第一版用 `\bfseries` 形态断言并写了「判别力已实测」，实际上该形态根本不走被测路径，撤销修复后测试仍通过。同一任务里 TEST 6 第一版用 `\hbox to` 宽度也是恒真断言。两次都是在未验证的情况下认为断言成立。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 按根因枚举象限，而不是按复现样例收工
**Rule**: 确认根因后，把根因写成一句判据，然后枚举所有满足该判据的场景并逐一验证。复现样例消失、全套测试通过、新用例有判别力，都不能证明根因的其他象限已覆盖。同时避免把只在一条路径上验证过的结论写成全局断言。
**Why**: #1037 第一轮修好「布尔为假」象限后，复现消失且新增用例有判别力，但同一根因（在没有 `\UL@box` 打开的列表里执行 `\UL@stop`）的第二个象限——公式路径不复位布尔——仍在，由最终全范围盲审作为第二个 blocking 提出。代码注释与架构文档里「在装饰外恒为假」的断言只对普通文本路径成立。#1026 的反思已记过同类教训，仍复发，说明原则需要配一个可操作动作（清点入口/出口）。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 改通用路径时，「加载了子包但不使用该功能」是独立验证象限
**Rule**: 修改所有用户都会经过的路径时，验证矩阵必须包含「加载了相关子包、但完全不使用被改功能」的文档。这批文档受影响面最大，其作者根本不知道自己用到了这条路径。
**Why**: #1037 的验证集中在装饰内部（节点深度、收缩量、外观像素），漏掉了这一象限，导致 blocking 缺陷要靠盲审才发现——而那个缺陷的复现根本不含装饰命令。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 通用路径里不能直接引用可选子包的函数
**Rule**: 在所有用户都会走的通用代码路径上引用某个可选子包定义的函数，等于把该子包变成必需依赖。应在主包里放默认实现、由子包加载时改写该入口，并立刻用「只加载主包」的最小文档验证。
**Why**: #1037 第一版直接在 `xeCJK` 主体的 `\@@_check_for_ecglue_aux:` 里调用 `xeCJKfntef` 的 `\@@_ulem_glue:n`。这条路径是所有 CJK-西文边界都会走的，不加载 `xeCJKfntef` 的普通文档立刻 `Undefined control sequence`，影响面是全部用户。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 探针没触发时先自证探针有效，再推断调用链
**Rule**: 加了 trace 却没有输出时，不能直接断定「代码不走这条路」。先确认探针本身有效——名字存在、能被调用、在同等条件下确实会打印——再据此推断。
**Why**: #1037 中重定义 `\xeCJK_ulem_hskip:n` 与 `\__xeCJK_ulem_hskip_first:n` 加 trace，一次都没打印，一度以为找错了函数族。真实原因是该路径不经 `\CJKecglue`，而是直接 `\skip_horizontal:N \l_@@_ecglue_skip`，而 ulem 钩子只重定义 `\CJKecglue`，整族函数都被绕过。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 改动装饰机制要同时验收节点结构与渲染像素
**Rule**: 把 glue 从内层盒子搬到外层列表这类改动，`\showbox` 证明的是节点结构，装饰外观必须另外渲染出来比像素。两条通道在节点深度上等效时，画出来可能完全不同。
**Why**: #1037 中 `\@@_boundary_use_ulem_glue:n` 与 `\@@_ulem_glue:n` 都能把收缩量搬到外层，但前者放裸 glue、不画装饰线，在西文词前留下 300dpi 下 7px 的可见断口。选后者后单行样例与修复前逐像素相同。
**Source**: `llmdoc/memory/reflections/1037-ulem-word-front-ecglue.md`

### 改动他人 issue 引入的代码时，重放那个 issue 的资产做无回归证明
**Rule**: 若修复触及某个既有 issue 引入的代码路径，就把该 issue 在 `gh-assets` 留下的 MWE 与视觉资产重新跑一遍，与**本 PR 的父提交**逐像素／逐字节比对，并把结果放进 PR body。基线必须选父提交，不能选早于那个 issue 的发布版——发布版的差异是那个 issue 的预期改进，会掩盖真正的回退。
**Why**: #1026 改的正是 #1002 引入的代码。重放 `issue1002-mwe.tex` 的 24 行数值 oracle 与 `inline-math-showcase.tex` 的 17 页渲染，确认与父提交逐字节／逐像素相同，才排除了回退。若误用 v3.10.3 作基线，会看到 18 行差异并误判为回归——那些差异其实是 #1002 自己的修复效果。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### PR body 要图文并茂地展示修复前后
**Rule**: 视觉类缺陷（间距、装饰、断行）的 PR body 应放修复前后对照图，并画出判据参考线（如正文右边距），配上可复现的量化数值。图片资产提交到 orphan 分支 `gh-assets` 的 `issues/<号>/` 下，用 `raw.githubusercontent.com` 引用；同目录放 `README.md` 说明各文件与复现命令。操作 `gh-assets` 必须用 `git worktree`，不要在主工作区 `checkout --orphan`。
**Why**: #1026 的高亮右边界偏移用文字描述很难判断是否修好；一张带红色边距线的上下对照图，加上「722px → 681px、与发布版逐像素一致」的数值，评审可以直接确认。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 换掉某段代码的实现方式时，回放它当初为之而生的那个场景
**Rule**: 若修复保留语义但更换实现（钩子改适配器、重写内部入口等），除了本 issue 的 MWE，还要回放**引入这段代码的那个 issue** 所关心的场景，并与本 PR 父提交逐项比较。若该 issue 没有现成的独立 MWE，按它的矩阵格式补一份。同时加一个「撤销该语义」的对照组——全绿矩阵不加对照，无法说明它能否发现语义丢失。
**Why**: #1029 换掉的两个 `cmd/sbox` 钩子是 #992 为隔离 `\sbox` 离线测量而引入的。只看 #1029 自己的算法标题 MWE，无法说明隔离是否在换实现时丢了。补的 sbox 矩阵在 base 与修复后同为 96／96，而删掉 `suspend`／`resume` 的对照组为 72／96——有了这个对照，96／96 才是证据而不是空话。（#997 曾被列为第二个实例：以为「回放了 hook 当初为之而生的场景」并据此判定不能删。但那次回放读的是 NFSS 参数而非 `\fontname\font`，场景本身没有成立——实测该 hook 运行时当前字体已是 CJK 字体。这说明「回放旧场景」本身也要选对观察量，否则回放的是一个不存在的场景；实例已撤回。）
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`、`llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

### 说「哪些形式汇入某入口」时读内核定义把分支数清全
**Rule**: 描述某公开命令有几种形式最终汇入同一内部入口时，打开内核定义把 `\@ifnextchar` 的分支逐条数完，不要凭常用形式推断。
**Why**: #1029 我在四份文档里写 `\savebox` 有「三种形式」汇入 `sbox `，漏掉了 picture 形式 `(x,y)[pos]`——`latex.ltx` 的 `\@isavepicbox` 末尾同样是 `\sbox#1{...}`。适配器实际覆盖面比文档所述更宽，属于把自己的成果说小了。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 修正一处错误说法后，全仓搜索同一说法的所有副本
**Rule**: 改掉一句被证伪的描述时，用关键短语在整个 `llmdoc/` 里搜一遍，把摘要索引（`index.md`）和其他文档里的同一说法一并改掉。索引类文件常常复述正文结论，最容易漏。
**Why**: #1029 我把「四种 `\global` 形式跨分组保住内容」在三处改对了，却漏掉 `llmdoc/index.md` 里的同一句摘要，由最终全范围审查查出。那句连验证判据都反了——新测试里 `\global\savebox` 的判据恰恰是 outside 为 0。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 引用差值时要标明它属于哪一组间距设置
**Rule**: 记录「删掉某处后出现多少 pt 差值」时，注明该数值来自哪一组 `CJKecglue`／`CJKglue` 设置。同一现象在默认胶与自设胶下的数值不同，直接从别的测试搬数字会写错。
**Why**: #1029 我把 `command-boundary01` 在默认胶下的 3.33pt 搬到了自设 `CJKecglue=5pt`／`CJKglue=1pt` 的新用例注释里，三处文档同时写错；该场景的实测差值是 4.0pt（63.19998pt 降为 59.19998pt）。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 变异要逐项做：整个文件变红不等于每一项都有判别力
**Rule**: 确认回归判别力时，对每一项各自声称守护的那条行为单独做一次变异，只破坏这一条，看这一项是否变化。整份测试文件 rc 1 可能只是其中一项失败连带压垮了后续各项的读数。
**Why**: #1029 的第一版回归中，只破坏「暂停深度归零」（去掉 `\int_gdecr:N`）或只撤销隔离，测试都全绿；而还原原缺陷时整个文件变红，让我误以为各项都在守着。逐项变异才暴露出两项完全没有判别力、另两项读的是别人的值。#265／PR #977 又犯了同一个错：把 `\bool_set_false:N` 改成 `\bool_gset_false:N` 后 `pinyin-scope01` 确实变红，我据此写下「判别力已实测」，但红的是既有的第 3／7b／7c／8 项，新增那一项逐字节不变——盲审按段落切分比对才查出这是恒真断言。**判据应当是「这一项的那几行输出变了」，不是「这个文件的退出码变了」。**
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`、`llmdoc/memory/decisions/265-disable-pinyin-inside-xpinyin.md`

### 新增测试项后要复查既有项的关键判据是否还在
**Rule**: 往一个共享文档状态的测试文件里加新项时，新项在顶层留下的状态会顺流影响后面所有项。加完后不能只看 `l3build check` 是否绿——绿只说明与**刚重新生成的**基线一致，而基线可能已经把某个既有项的证据丢掉了。做法是 `git show <加之前的提交>:<基线文件>` 与当前基线比对关键判据（特征字符串、数值），确认既有项固定的东西没有消失；新增项应各自用 `{...}` 包住，把状态改动限制在本项内。
**Why**: #265／PR #977 新增三项后，第 9b 项（`footnote=true` 时脚注内注音）的判据 `3.19995pt` 从基线消失，而两套测试都报 All checks passed。根因是 `\enablepinyin` 的第二个块以 `\bool_if:NF \l_@@_enable_bool` 为守卫，新增项在顶层留下 `en=T` 使该守卫不放行，`\@@_restore_footnote:` 未重新执行。把新增项各自包进分组后判据恢复。
**补充：文档里冻结了具体数量的断言，新增用例后必须重跑确认，不能推断。** 这条与上面那条相邻但讲的是另一件事：上面讲基线里的判据会消失，这条讲文档里的计数会过期。重跑一次的成本通常很低，所以也不该因为怕写错就把数字改成模糊表述——那等于丢掉一条实测事实。真正反复出错、维护成本高于价值的穷尽性断言才改为清单（见下文「现象、联系、穷尽性、成因是四个独立命题」）。#997 的实例：`build-and-test.md` 记着「把 `\'` 与 `` \` `` 对调，XeTeX 四个文件全红」，新增第 5 个用例后这个数字不再可信；investigator 明确说自己没有重跑、要求不要凭推断改数，实际重跑该变异得到「五个」（新增的 `pinyin-fallback01` 基线含拼音字形，同一变异同样影响它）。
**Source**: `llmdoc/memory/decisions/265-disable-pinyin-inside-xpinyin.md`、`llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

### 观察点本身会不会把被测状态改回去，要先查一遍
**Rule**: 断言「某个状态在退组／退环境后恢复」时，先确认用来观察的那个命令自己不会重建该状态。若它内部会重新置真（例如调用一个 enable 类命令），那么无论被测赋值是局部还是全局，观察到的输出都一样，断言恒真。同理，测试项之间的执行顺序也可能构成前提：前一项留下的状态会让后一项的恢复路径走另一条分支。这类前提必须写进注释，并在文件里固定住顺序。
**Why**: #265／PR #977 用 `\xpinyin*{语}` 作为退组后的观察点，而 `\xpinyin*` 的星号分支进组后无条件调 `\enablepinyin`，后者把总开关重新置真——它自己修好了泄漏的禁用状态。换成不带星号的形式后仍不够：`\disablepinyin` 的第二个块以 `\l_@@_enable_bool` 为条件，若该布尔在此前已为真，退组时它的局部恢复会连带把总开关拉回真。最终要求该项排在所有 `\enablepinyin`／`\xpinyin*` 之前才有判别力。
**Source**: `llmdoc/memory/decisions/265-disable-pinyin-inside-xpinyin.md`

### 观察量必须只随被断言的那件事变化，混进无关内容会掩盖缺陷
**Rule**: 用尺寸、计数一类聚合量作判据时，被测的那一件事必须是该量的**唯一**变化来源。若盒子里还有别的内容，无关内容的贡献会让比较在缺陷下仍然成立。做法是把被观察的对象单独装盒，并同时对两个方向取证（与「应当相同」的基准比等，与「应当不同」的基准比不等）；基准要另取一个未受影响的对象，不能拿两个都已退化的值互比。
**Why**: #265／PR #977 给 `\disablepinyin*` 补退组恢复的用例时，把禁用分组和组后要观察的字放进同一个盒子再比总高。把局部赋值改成 `\bool_gset_false:N`（禁用泄漏到组外、组后那个字也不再注音）后，该盒仍然更高（8.46454pt vs 8.39754pt）——多出的高度来自盒内其他内容而非拼音，`>` 比较照报通过。改为单独装盒并双向比对后，变异才真的变红。
**Source**: `llmdoc/memory/decisions/265-disable-pinyin-inside-xpinyin.md`

### 每项测试用独立的盒子／寄存器，否则读到的是上一项的遗留值
**Rule**: 断言全局赋值是否生效时，每一项必须使用各自独立的盒子或寄存器。共用一个全局对象时，前一项留下的值会被后一项读到，测试看似通过却什么都没断言。写完后应改变该项的内容重新生成基线，确认读数随之变化。
**Why**: #1029 的第一版回归让三项共用同一个 savebox，其中两项读到的是第一项留下的 21.8pt——把内容换成明显更宽的字符串，读数纹丝不动；`[3cm][l]` 那项的期望值本应是 85.35826pt，却记成了裸文本的 21.8pt。缺陷版下这两项出现 0.0pt 也只是第一项失败的连带结果。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 断言「上游行为已修复」之前，先在不加载本包的环境里测一遍
**Rule**: 声称修复了某个上游命令的行为前，先在纯上游环境（不加载本包）里测同一组样例。若上游本来就不工作，那不是本包的回归，也不该写进修复范围；应把它作为既有限制固定下来并注明成因。
**Why**: #1029 我写了「`\global\savebox` 三种形式跨分组保住内容」，实测纯 LaTeX 下这三种全为 0.0pt——`\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，与本包无关。真正修好的只有 `\global\sbox`。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 「与既有行为一致」不等于「符合设计意图」，回答「这正常吗」要引规范原文

**Rule**: 改动带来的连带变化，用「另一条既有配置下读数相同」只能证明**内部自洽**；要证明该行为**正确**，必须回到手册／规范的原文定义，或找到跨版本、跨平台的独立对照。整个设计若本身有问题，它照样内部自洽——只用内部对照回答用户的「这正常吗」是答不上的。

**Why**: #1068 修好后 `\ccwd` 从 10.53937pt 变 20.53937pt、`\parindent` 从 21.07874pt 变 41.07874pt（首行缩进翻倍）。我用 `\ctexset{linestretch=\maxdimen}`（ctex 既有的、走同一分支的配置）对照，读数逐字节相同，据此在 PR 里写下「这是既有语义而非本次引入」。用户看到截图里 AFTER 第二行多出缩进、问「这正常吗」，我才发现那条对照只回答了「和既有配置一样」，没回答「这样对不对」。补齐的两条依据才是实证：一是手册对 `\ccwd` 的定义原文（「汉字字宽是相邻两个汉字中心之间的距离，**包含字距在内**。因此修改字距会间接修改字宽」，而 `autoindent` 默认取 `2\ccwd`）；二是跨引擎跨版本对照——XeTeX 在**未修改的 v2.6.4** 上 `\parindent` 就已是 41.07874pt，LuaTeX 先前停在 21.07874pt 恰恰是因为间距被错误重置。与「本地测试全绿只证明校验器内部自洽」（复合 Action 那条）同族：都是把「自洽」误当「正确」。

**Source**: `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`

### 顺手做的一致性修改要单独确认有无校验
**Rule**: 同一约束改到多处时，逐处确认哪些有回归覆盖。若某处的症状在结构上无法观察（例如被包进 hbox 后内层弹性不外露），就在文档里如实写明它依赖代码审查而非校验，不要让它蹭进另一处的覆盖声明。
**Why**: #1026 中 `\UL@onin` 的重排分支按同一约束改了，但 `ulem` 用 `\setbox\UL@box\hbox{{#1}}` 包住内容，收缩量丢失在嵌套路径上不显现；重新引入缺陷乃至删掉整段分支，全套 114 项仍全绿。文档原先的措辞读起来像 `\UL@on` 与 `\UL@onin` 都已覆盖。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 「症状不显现」不等于「路径不可测」，换一个可观察量再判断
**Rule**: 说某条路径没法回归保护时，实际说的是「我当前用的那个观察量在这条路径上恒定」——那是观察量的性质，不是路径的性质。挑选候选观察量的判据是它是否依赖那段代码**改变了什么结构**：受该结构影响的量是候选，被该结构屏蔽的量不是。把某条路径记为「不可测」时，必须一并写清当初用的是哪个观察量、为什么它在那里恒定，好让后来者能接上，并把「换观察量」列为待试项，而不是当成永久结论。
**Why**: #1026 记载 `\UL@onin` 无回归保护，理由是 `\setbox\UL@box\hbox{{#1}}` 把正文整体装进盒子、内层收缩量出不来。#1057 换用「能否断行」这个观察量就落在了同一条路径上：正文进刚性盒子这件事对收缩量不可见，对断点却是决定性的（受盒子刚性影响的断点、badness、溢出都是候选，被盒子边界屏蔽的内部收缩量不是）。能接上正是因为原记载写清了理由；另用计数器插桩确认分派确实不同（线型套线型 `\UL@onin` 计数 1、线型套符号型计数 0），而非只凭现象推断机制。
**Source**: `llmdoc/memory/reflections/1057-fntef-nest-linebreak.md`, `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 把既有限制固定成断言需要双向判据
**Rule**: 要固定的不是「某处修好了」而是「某条限制存在」时，只写「触发限制的用例出现症状」是单向的，无法区分「限制只影响某类组合」与「凡此类操作都失败」。必须同时写一组「不触发该限制、症状不出现」的对照，并对两侧各做变异验证；否则不触发的那一侧只是空基线的默认结果，文档里写的适用范围没有任何校验。
**Why**: #1057 的 `fntef-nest-linebreak01` 里 TEST 1／TEST 2 的基线含 Overfull 行（限制存在的证据），TEST 3 到 TEST 6 的基线不含（这些组合确实能断行）。把 TEST 3 内层的符号型 `\CJKunderdot` 换成线型 `\CJKunderwave` 后基线因多出 Overfull 行而失败（rc 1），证明「不含 Overfull」这一侧有判别力。少了后一组，「符号型可以自由嵌套」这句文档结论就无人校验，而它恰好是报告者原样例会推错的那一条。
**Source**: `llmdoc/memory/reflections/1057-fntef-nest-linebreak.md`

### 文档里的肯定性清单必须声明它保证的是哪一个维度
**Rule**: 列举「什么是好的」的清单必须写明它的量纲——「以下命令行为正确」会被读成「以下命令没有问题」，而这两句话的覆盖面差得很远。相邻维度上存在已知限制时，要在同一处交叉引用，不要指望读者自己去找。这类问题没有任何测试能拦住，只在读者外推出错时才暴露。
**Why**: #1057 的报告者先在 `xeCJK.dtx`「已知问题和兼容性」一节读到一份含嵌套组合的「间距行为正确」清单（清单本身没错，只是没说自己只管间距），再看到断行出问题，于是判定为缺陷。修法是在该清单处声明「本节只讨论 CJK 间距，不涉及断行」并交叉引用新增的 §3.6.1，同时在 `\CJKunderdot` 说明处补一句「嵌套后仍然可以正常断行」。
**Source**: `llmdoc/memory/reflections/1057-fntef-nest-linebreak.md`

### 报告者的复合样例不能用来划定支持边界
**Rule**: 报告者的样例只证明「存在一个坏的输入」。要写进文档的支持边界必须由自己设计的、一次只变一个变量的控制实验得出：先测各元素单独使用建立基准，再逐一测各种组合。这在 documentation 类 issue 上比在缺陷类上更要紧——缺陷类修好那一个案例就有实际价值，而文档写错边界会长期误导所有读者。
**Why**: #1057 报告者的 4 个案例同时换了命令、嵌套顺序和正文长度。只跑这 4 个能得到的最强结论是「嵌套就是坏的」，照它写文档会把 `\CJKunderdot` 的嵌套一并说成不能断行——而那是错的，手册里恰好还有一个 `\CJKunderdot` 嵌套的示例。分两步做控制实验（先测六个命令各自单独使用，再测两两嵌套）才得出「线型套线型失败、符号型可以自由嵌套」这条准确边界。
**Source**: `llmdoc/memory/reflections/1057-fntef-nest-linebreak.md`

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
**Rule**: 新增或改写回归测试后，故意还原到修复前的实现，确认测试会失败；测试全部显示“通过”不构成“这项测试确实能检测该缺陷”的证据，只能证明测试当前不会误报。同理，声称某测试守护某条行为之前，也要用变异实测确认是它会红——没有任何输出行的 `.tlg` 段落不构成校验，把守护职责写错到文档里会让后来者误以为已有覆盖。
**Why**: #1026 中连续三版测试草案都显示通过，但都是因为选错了能观察内外层区分的载体（`\hbox`／`\vbox` 抹平差异，宏承载正文触发了另一条既有限制），如果没有主动倒回旧实现验证，很可能把假绿当作“修复已验证”上报。同一 issue 里还出现过一个用例的 `.tlg` 段落其实是空的，却在注释和 llmdoc 里被写成负责固定“重排确实发生、尾随空格仍被装饰”；实测关掉重排、删掉空格交还它都照样通过，真正拦住的是 `command-boundary-math05`。
**Source**: `llmdoc/memory/reflections/1026-ulem-literal-body-outer-shrink.md`

### 「某个变异能让整份文件变红」不等于「某一项用例覆盖了它所声称的失败形态」
**Rule**: 判断单项用例有没有判别力，必须单独让**那一项**所声称的失败形态发生，再看是不是**那一项**的输出变了；多项共处一个文件时，红可以全部来自别的项。给某一项写下「它守住 X」之前，构造只破坏 X 的变异（必要时把其余项临时注掉），确认它确实变红。做不到就如实记为覆盖缺口，不要在文档里给出一个未经单项验证的判别力承诺。
**Why**: #997 的修复是「已处于后备字体状态就跳过字体重选，否则保持原有重选」，看似有两种失败形态，于是第 3 项被写成「专门固定条件写反成总是跳过」，并给出读数 `x0.0`。独立审查复跑推翻了这一整套：把条件取反确实变红，但产物与无条件重选逐字节相同、不是独立形态（探针实测互换后两支都走到——第 1、2 项走跳过支、第 3 项走重选支；产物相同的原因是第 3 项那次重选本身是无操作，而非条件恒成立）；而真正的「总是跳过」（函数体置空，或 hook 里不再调用）实测 **5/5 全绿，产物与基线逐字节相同**，`x0.0` 从未复现。同一教训在 `pinyin-scope01.lvt` 已有一次实例（整文件变红误导了单项判别力判断），本轮又踩一次。**紧接着还犯了对称的错误**：纠正时把话说成「第 3 项没有判别力」，而增量审查换一个变异（保持条件结构、只让重选切到错误的 CJK 族）证明只有第 3 项变红——它是那一形态的唯一防线。所以否定性断言要限定到实际验证过的那个失败形态，不要外推成「该项没有判别力」。
**Source**: `llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

### 回答「当前用什么字体排版」要读 `\fontname\font`，不是 NFSS 参数
**Rule**: `\f@family`／`\f@series`／`\f@size` 等 NFSS 参数描述的是 LaTeX 字体选择状态，`\fontname\font` 才是 TeX 当下实际装载、用来排字并决定盒子尺寸的那个字体。CJK 场景下两者会系统性地不一致：xeCJK 的 interchar 在进入 CJK 类时直接切换实际字体，NFSS 参数可能仍停在西文族。凡是要回答「这里量出的宽度是按哪个字体算的」，探针必须读 `\fontname\font`。
**Why**: #997 初版在量宽 hook 入口读到 `\TU/lmr/m/n/10`，据此断定「当前字体是西文，不重选就会量出西文宽度，所以那次重选不能删」。同一位置读 `\fontname\font` 得到的已是 CJK 字体；十余种上下文（紧跟西文／标点／`\emph`／数学／各类盒子／`tabular`／`minipage`／`\section`／脚注／切族）无一例外。误读直接支撑了一个错误的方案取舍结论——「删掉重选」其实同样能修好 #997 且更简单。
**Source**: `llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

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
**Rule**: 涉及区域字形和 side bearing 时使用独立字体面，并在 `\START` 前预热所有 lazy family，再记录定量基线和渲染证据。预热范围要包括**被测命令自己会切换到的字形**，不只是测试正文显式用到的字体；判断方法是读被测命令的定义体，把它切换的每一种字形都排一遍。
**Why**: #975 中 `Language=` 不能改变 feature-blind 的 glyphbounds 证据，首次按需加载 Noto TC/JP 会污染 `.tlg`；#999 的 FandolFang 也必须预热才能消除三平台 fontspec 尾随日志差异；#1046 的 `\meta` 用 `\meta@font@select`（`\itshape`）排参数、CJK 斜体还要自动伪斜，不预热时同一段内容实测在 54.4378／76.23781／135.92561pt 之间跳。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`, `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`

### 既有测试全绿只说明测试覆盖的场景没问题
**Rule**: 把「既有测试全绿」当作「缺陷不存在」的证据之前，必须先核对那些测试的**构造**是否真的覆盖了报告的场景——尤其当测试用简化替身模拟被测对象时，简化掉的那一层可能正是缺陷所在。核对成本通常很低，就是打开 `.lvt` 看关键条件在不在。
**Why**: #1046 的自动分析引用 `codedoc-meta-ecglue01` 全绿，把可复现的代码事实（左侧恒 5.25pt、右侧恒 3.33pt）归因成「尖括号与斜体字形造成的视觉差异」；而那个测试自己模拟内层 `\__codedoc_meta:n` 时没有 `\texttt` 外层，`\texttt` 正是缺陷的必要条件。#1038 的既有 `tabular01` 因每行 `\\` 前有空格而零判别力是同一条规则的前一次发作——那次简化掉的是空白，这次是外层字体切换命令。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`, `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 否定性结论要说明搜索了什么模式、为什么能穷尽
**Rule**: 「未发现相关代码路径」「没有这样的实现」这类结论，必须给出搜索的具体模式以及该模式为何能穷尽目标空间；否则它只是「我没找到」，不能当作「不存在」写进结论。
**Why**: 把代码事实归因成视觉错觉是这条失效的典型后果（#1046）。同一任务里还有第二个例子，而且它自己就栽在这条规则上：hyperref 的行内锚点出口数我先后写错了四次——先误写按「目标是否为空」在 `\hyper@anchor` 与 `\Hy@raisedlink` 之间分派（计数器实测四种 `\hypertarget` 形式的 `\Hy@raisedlink` 均为 0），改对后误写「只有两个出口」（同一手段随即找出 `\__hyp_target_raise:n`），承认第三个出口后又为「它套不上现成包装」编了一个隔离实验一测就倒的成因，覆盖第三个出口后再误写「三个出口全部注册」（`\pdfbookmark` 经 `\hyper@anchorstart` 裸调用绕过全部三处）。「若干处注册的判别力互不重叠」只证明这些处都在路径上，既不证明按什么分派、也不证明只有这些处，更不能替你解释故障成因。反复出错的穷尽性断言应当换成「已覆盖／已知未覆盖」两份清单。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`

### 现象、联系、穷尽性、成因是四个独立命题
**Rule**: 「A 缺了会坏、B 缺了也会坏」只证明 A 与 B 都在路径上。它**既不**证明「按某个条件在 A 与 B 之间分派」，**也不**证明「只有 A 和 B」；而观察到一个故障也**不**证明你对它成因的解释。这些是彼此独立的命题，各需自己的探针：控制流用计数器（给候选函数各加 `\newcount` 跑一次），穷尽性要能说明用什么手段排除了下一种可能，成因用隔离实验（去掉你认定的那个因素，看故障是否仍在）。若某个穷尽性断言反复出错，**改为维护「已覆盖」与「已知未覆盖」两份清单，不写总数**——清单的每一条都能被单条探针核查，总数不能。同理，「实测过」要说清实测的是什么（宽度相同不能推出节点列表相同），并检查探针本身够不够用——节点级比对时，预热行与「同一容器只放一个入口」都可能掩盖差异，需在同一 `\hbox` 里放两个以上同类入口。准备把机制陈述提升为跨任务判据时尤其要先补实测；写下「全部」「只有」「因为 X 所以坏」之前先自问一遍。另有一种情形是**观察点本身就落在错的对象上**——诊断信息可能来自一个随后被丢弃的中间产物，那时连「现象」这一层都还没立住，见上文「TeX 的诊断信息绑定当时正在构造的那个盒子」。
**Why**: #1047 的机制陈述被独立复核连续推翻四次，形态相同——都是从一个真实现象推出未经独立验证的解释。第一次：两个 transparent 注册确实都必要、判别力也确实互不重叠，但据此推断的「非空目标走 `\Hy@raisedlink`、空目标走 `\hyper@anchor`」是错的，计数器实测显示四种 `\hypertarget` 形式的 `\Hy@raisedlink` 调用次数均为 0。第二次：改对分派依据后又写成「行内锚点有两个出口」并把「两个」写进架构文档与本文件，同一手段随即发现第三个出口 `\__hyp_target_raise:n`。第三次：承认第三个出口后，把「现成包装套不上去」归因给 xeCJK 的 begin 钩子把赋值卷进了参数展开，并据此把缺口写成已接受限制——隔离实验推翻了它，那个钩子体内根本没有 `\spacefactor` 赋值（赋值来自 hyperref 自己的 `\Hy@SaveSpaceFactor`），不挂任何钩子仅做无花括号透传同样复现，把参数改成带花括号转发即回到 oracle，缺口本可直接关闭。第四次：覆盖第三个出口后又写成「三个出口全部注册」，同款探针发现 `\pdfbookmark` 经 `\hyper@anchorstart` 裸调用绕过全部三处——于是文档改为只维护「已覆盖」与「已知未覆盖」两份清单，不再给出总数。四次错误各传播进四到六份文档，而推翻各只需一次编译。这与 #1043 的「事实、原因、后果各自都要验证」同源，本次多出三层：事实之间的联系、事实的穷尽性、以及你为故障编的成因，都要各自验证。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`
**Source（镜面发作）**: `llmdoc/memory/reflections/1067-ulem-brace-group-ecglue-shrink.md`
**Why（镜面发作）**: #1067 中同一条规则以相反方向发作——不是把「可达」误当成因，而是把「改掉某个环节、现象没变」误当成「这个环节不是原因」。变异测试显示绕过 group tag 守卫后 braced 形态的 badness 仍是 1000000，据此判定「守卫与本问题无关」，但真实情况是守卫确实是直接原因，只是「绕过它」这个具体修法本身在用户分组内做不到（搬出来的 glue 仍落进 `\cleaders` 内部）。「A 是直接原因」与「绕开 A 这个动作失败」是独立命题，可以同时成立；本次因为跳过了对后者单独验证，把「修法失败」直接读成了「解释错误」，导致过早判定不可修复并开出一个后来被关闭的纯文档 PR。

### 手写 MWE 要先确认 `TEXINPUTS` 指向的包真的是当前版本
**Rule**: 用 `TEXINPUTS=<builddir>:` 跑手写 MWE 前，先确认该目录存在且内容是当前改动——例如 `grep` 一个只在本次改动里出现的函数名。目录不存在时 `xelatex` 不报错，而是静默回落到系统安装的旧版宏包。
**Why**: #1047 有一次把「注册 `\hyper@anchorstart` 会把已修好的两处拖回缺陷状态」写进五处文档，实际原因是清理 `build/` 后忘了重新 `l3build unpack`，MWE 用的是系统里的旧 `xeCJK.sty`，于是所有读数都是修复前的值。这类失效格外难察觉：退化后的读数恰好等于该缺陷本身的值（都是 38.33002pt），与「新注册破坏了已有修复」的预期完全吻合。**任何「X 导致 Y」的结论都要跑一次去掉 X 的对照**——这次只要跑一遍不注册的版本就会看到同样是 38.33002pt，立刻排除因果。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`

### 测量类用例一律用具名 box 寄存器
**Rule**: `.lvt` 里存放宽度测量结果时用 `\newbox` 具名寄存器，不要用 `\setbox0`--`\setbox15`——被测命令用掉哪个 scratch 寄存器不在你的控制范围内。
**Why**: l3doc 的 `\meta` 内部经 `\ensuremath` 排尖括号会占用 `\box10`、`\box11`，#1046 最初用 `\setbox10`／`\setbox11` 读到 `0.0pt` 与被污染的 `108.87561pt`，一度被误判成实现缺陷——失败表现看起来像被测代码有问题，而不像测试自己有问题。#1029 的「每项测试用独立寄存器」是同一类，但那次是自己的用例之间互相覆盖。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`, `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 判断测试失败归属要在同一环境跑 master 并逐字节比对
**Rule**: 判断一批测试失败是否由本次改动引起，方法是在同一环境下跑 master 并逐字节 `diff` 两边的 `.diff` 文件，而不是看 diff 内容像不像自己改的地方。另外 `tlmgr update` 报 `no updates available` 不等于本地各包之间自洽。
**Why**: #1046／#1047 期间 `l3kernel` 已到 revision 79868 而 `l3backend` 停在 78544，其间 expl3 把后端接口从 `\__color_backend_select_<model>:n` 改成 `:nN`，`\use:c` 找不到目标就把颜色参数当文本排了出来。`\special{pdf:bc [1.0 0.0 0.0]}` 变成可见的 `1.0 0.0 0.0` 文本，看起来很像间距类改动的后果；逐字节比对确认 15 项失败全部与改动无关。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`

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
**Why**: PR #1030 中 `timeout-minutes` 只在 job step 合法，写进复合 Action 会被 runner 在加载 `action.yml` 时判 `TemplateValidationException`；本仓库的校验曾把这个字段误判为复合 Action 合法字段，本地测试却全绿。PR #1031 中复合 Action 的 `run` 默认带 `pipefail`，与不带 `pipefail` 的 job step 相比，同一句管道右侧提前 `exit` 的 awk 会有不同的退出码，字面相同的代码在两种 step 类型里行为不一致。
**Source**: `llmdoc/memory/reflections/1030-1031-composite-action-semantics.md`

### 加载期失败会遮蔽同一 Action 内的运行期缺陷
**Rule**: 一处加载期失败（manifest 校验、字段解析）会让同一 Action 内后续所有代码路径都从未真正执行过；修好第一个失败点后，应预期还有第二批此前未被执行到的路径可能出错，不能把“这次能加载了”当作整体验证完成。
**Why**: PR #1030 修好 `timeout-minutes` 导致的加载期失败后，Action 才走到工具安装阶段，随即在 PR #1031 暴露出此前从未执行过的 awk 管道在 `pipefail` 下会以 SIGPIPE 终止 step 的独立缺陷。
**Source**: `llmdoc/memory/reflections/1030-1031-composite-action-semantics.md`

### 本机能复现推不出 CI 会复现，要断言 CI 行为就直接查 CI 侧证据
**Rule**: 本机环境与 CI 环境是两个独立的软件快照，没有共同的时间基准；本机复现了某个失败，只能说明本机当前环境处于某种状态，推不出 CI（哪怕是同一个 commit）也会给出相同结果。要对 CI 的行为下结论，必须直接查 CI 侧证据——重跑记录、缓存 key、缓存创建时间与体积等，而不是拿本机结果替代任一侧的 CI 结果。
**Why**: #1050 排查时在本机 worktree 复现了 master 同一 commit 的失败，据此发出了「master 上重跑也会红」的结论；实际查证后，master 在 CI 上重跑（attempt 2）是全绿的——本机的 TL 已经漂移，与 CI 命中的缓存快照完全不是同一个版本。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### CI 各次运行之间也可能因缓存分叉而不一致，此时某一侧的绿不构成判据
**Rule**: 「CI 是已知良好基线，本地与 CI 的差异是第一信号」这条既有规则默认 CI 结果在同一时间窗口内是一致的。当 CI 自身的缓存 key 因某个文件改动（例如改了缓存 key 里 `hashFiles` 覆盖的文件）而分叉时，这个前提不成立：master 与 PR 可能分别命中两个不同时间点写入的缓存快照，一侧绿只说明它命中的是旧快照，不能作为「代码在当前上游环境下仍然通过」的证据。这种场景下要先比较两侧的缓存 key、创建时间与体积，确认缓存是否分叉，而不是直接沿用旧规则把绿的那一侧当基准。
**Why**: #1050 给 `.github/tl_packages` 加了三行依赖，让 TL bypass cache key（含 `hashFiles('.github/tl_packages')`）改变；该 PR 侧 cache miss、拿到当前上游版本，master 继续命中改动前的旧快照。同一个 commit `2dd5af66`，master 绿、PR 红，绿是旧缓存挡住了漂移，不是代码在新 TL 下仍然通过。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### 刷 `.tlg` 基线前先按上游根因分类：会自愈的不刷，上游不会回退的必须刷
**Rule**: 面对上游宏包版本漂移导致的 `.tlg` diff，先判断根因属于哪一类，再决定要不要刷基线：TL 打包侧暂时没跟上 CTAN（会随 tlnet 同步自愈）的漂移不刷——刷了等于把上游当前滞后快照里的错误数值固化下来，等 TL 同步后还要改回来；上游有意修正且不会回退的漂移必须刷。这与「状态表中的绿色单元才进入通过基线」是同一族但不同粒度：那条管的是「矩阵内哪些单元可以写进基线」，这条管的是「整批 diff 该不该刷」的前置分类。**判定「必须刷」之后还要再逐份核对 diff 的内容形态**（净宽为零的 kern、纯文件名行增删是安全信号；节点缺失、数值变化则必须先查本包补丁是否仍成立），否则「刷基线」会把上游同时引入的新缺陷一起冻结进去——分类判据只回答「要不要刷」，不回答「刷了会不会带进新问题」。
**Why**: #1048/#1050 中 l3backend 的漂移是 tlnet 落后 CTAN 五个月（会自愈），pgf 的舍入修正是上游明确的、不会回退的行为变更；两者的 `.tlg` diff 表现类似，但处置方式相反——一个该等 TL 同步，一个必须刷。#1080 补两个「必须刷」的实例：`tocloft` v2.3i→v3.0a 新增的 kern 对净宽为零、`fontspec` 不再显式加载 `xparse` 只是文件清单变化，两者都先核对了 diff 只含这类安全信号才敢 save。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`, `llmdoc/memory/reflections/1080-upstream-tocloft-fontspec.md`

### 失败集合的分布差异是成因数量的线索
**Rule**: 同一批 CI 红（或同一批测试失败）若在不同引擎、不同用例上呈现不同的受影响范围，应当把这当成「不止一个成因」的信号，分别排查；不要把第一个找到的成因，套到分布不同的另一组失败观察上。判据很直接：同一个成因通常在同一维度（引擎、平台、用例类型）上产生同一种分布；出现两种分布，大概率是两条独立路径。
**Why**: #1080 中 `github472-03/04` 四引擎全红，`files01/02` 只 XeTeX／LuaTeX 两引擎红——分布不同。找到第一个成因（`tocloft` 主版本跳变）后，一度把 `files01/02` 也挂到它名下找原因，还去查了「`tocloft` 是否间接影响 fontspec 加载链」，实际两者毫无关系，真正原因是 `fontspec` 不再显式加载 `xparse`。这条规则与「现象、联系、穷尽性、成因是四个独立命题」相关但角度不同：那条管的是「同一个观察对应的因果解释要逐层单独验证」（观察→联系→穷尽性→成因，四层各自证明），这条管的是「多个失败观察本身要不要被当成同一件事来解释」——先按分布特征把观察集合拆开，再对每一份分别走那四层验证，两条规则分别作用在拆分观察集合之前与之后。
**Source**: `llmdoc/memory/reflections/1080-upstream-tocloft-fontspec.md`

### 关掉断言不是刷基线
**Rule**: 刷新一个测试的基线，前提是让测试在正确环境下重新跑出真实结果；把断言本身改弱或删除（例如把具体的 `PASS: ...` 输出换成一个占位字符串），即使 `l3build check` 变绿，也不是刷基线，而是删除了校验本身。判断某次「基线更新」是否合法，要看改动前后测试是否仍然观察同一件事。
**Why**: #1048/#1050 中 `fntef-phase01` 曾被改成把五条 `PASS: ...` 换成 `PHASE-CHECK-PENDING`，这等于删除了校验；而它在配对版本（backend 与 pgf 都是当时应有的版本）下本来是全绿的，本不需要放弃断言。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### 注入类实验必须有可核实的生效判据
**Rule**: 用替代版本的文件（宏包、依赖、配置等）临时覆盖某个路径来做对照实验时，必须有一个独立于实验结论的判据，能核实注入本身确实生效，而不是仅凭实验结果推断。没有这个判据，「注入没生效、测的还是旧版本」与「注入生效了、新版本确实不行」在结果上会完全相同，容易把环境错误误判为结论。
**Why**: #1048/#1050 中两次尝试用新版 l3backend 替换测试环境都放错了位置（先后误写进会被 `cleandir` 清空的 `testdir`、试图通过 `TEXINPUTS` 覆盖但被 l3build 写死的设置盖过），两次都得到「仍然报错」的结果，若不核实测试目录里实际文件的日期戳，会顺势得出「新版本也修不好」这个错误结论。

**否命题形态：「反证失败」不等于「假设错误」。** 上面那条问的是「实验做成了吗」，这条问的是「这个环境有能力区分两种结论吗」。做反证或对照实验时，若结果是「仍然失败」或「未复现」，先证伪两件事再采纳结论：一是**装置无效**（探针／注入本身没起作用），二是**环境不具备复现前提**（无论假设真假，这个环境都给出同一个结果）。#1054 的实例：第一次就正确判断出 `mktexlsr` 缺失是根因，随后在本地做「去掉 `mktexlsr` 看是否失败」的反证，没能复现，据此撤回了一个**正确的**修复，绕两条弯路后靠 CI 日志才重新确认。真实原因是本地 `TEXMFHOME`（`~/texmf`）不在 `TEXMFDBS` 里、不带 `!!` 前缀，走磁盘搜索，不受 ls-R 约束——这个环境改不改 `mktexlsr` 都不会失败。另一个同族实例是 #1043 的坏探针（见 `reference/coding-conventions.md:118-125`）：`\char_value_catcode:n` 加了 `\the` 前缀读出废数据，「实验有输出」被当成「实验有效」。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`, `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`, `llmdoc/memory/reflections/1043-halign-alignment-tab-in-boundary-args.md`, `llmdoc/memory/reflections/1067-ulem-brace-group-ecglue-shrink.md`

**用于驳回他人 finding 时，举证责任更重（#1067）**: 同一条 blocking 被 bot 审查报了两轮。第一轮我用 `CJKecglue={0pt minus 1pt}` 实测「oracle／plain／braced 三者 badness 都是 37」，据此回复「经实测不成立」——那个写法没真正生效，是上面「装置无效」的又一次发作。第二轮 bot 给出 `CJKecglue={\hskip 0pt minus 1pt}` 才复现（直接输入 18、分组形态 1000000），finding 是对的。**接受一条错的 finding，代价是多改一点无害代码；驳回一条对的 finding，代价是缺陷留在仓库里，而且驳回理由会写进回复与提交信息、变成后来者信赖的「已验证」结论。** 所以实测结果与 finding 相反时，第一反应应当是「我的用例真的复现了对方描述的条件吗」（打印实际取到的值确认选项生效），而不是「对方错了」。

### 对照实验不要用 `sed`／`perl` 删真实脚本的片段
**Rule**: 对照实验的前提是只改一个变量。用 `sed`／`perl` 从真实脚本里删掉一段代码，同时也改了脚本的语法完整性与后续步骤的前提，等于一次改了两个变量，得到的结果无效。正确做法是写一个最小独立复现，直接测被怀疑的那个机制本身。
**Why**: #1054 两次这样做：一次删出语法错误让脚本 exit 2，一次把末尾的生效校验整段删掉（于是「没报错」根本不能说明问题不存在），两次结论都无效。改用最小复现——在 `!!` 树上放一个文件，刷新／不刷新 ls-R 各查一次 `kpsewhich`——一次就拿到干净结果。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### 命令退出码为 0 不等于产物合格，每一步都要在发生处校验
**Rule**: 下载、解包、代码生成这类会产出文件的步骤，退出码为 0 不构成「产物可用」的判据，必须紧接着校验产物本身（非空、格式完整、数量符合预期）。中间步骤不要把输出丢 `/dev/null`，裸 glob 换成 `nullglob` 加显式计数。否则失败会被推迟到末尾的总校验，而总校验只能报出它自己那一种结论，与真实原因无关，把排查方向带偏。
**Why**: #1054 中 `curl -fsSL --retry` 在 `mirrors.ctan.org` 重定向到实际镜像后三次 `curl: (28) Timeout`、重试耗尽，仍返回 0 且 `-o` 只写出空文件。脚本因此走进成功分支并 `break`，`unzip -oq` 静音失败，docstrip 在空目录无输出，`cp` 收到未匹配的 glob 字面量——一路静默到末尾被 kpsewhich 生效校验拦下，报出的却是「注入未生效」，真实原因（网络）完全看不见。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### 抽出被多个调用点共用的脚本时，触发白名单与 job filter 属于「调用点」的一部分
**Rule**: 把逻辑从某个 workflow 抽成共享脚本时，除了改各处 `run:`，还要更新「哪些文件改动会触发这些路径」——触发白名单与各包 job 的 filter。这些地方不改，改坏脚本时 CI 不会告警。而且不同 workflow 的失效机制不同，只查一处不够：`on.paths` 白名单不含该文件时 workflow **根本不触发**；`paths-ignore` 型 workflow **会触发**，但各包 job 的 `if` 取自 `_all` filter，全为 false 导致整体 skip、汇总 job 把 skipped 算作 OK 而呈现为绿。由此还有一条判读约束：**「看 job 有没有启动」不能作为门禁生效的证据**，前者 run 缺席、后者 run 在但内容为空，都可能被误读成「已经跑过了」。
**Why**: #1054 把 workaround 抽成 `scripts/sync-l3backend.sh` 时更新了三处 `run:`，却漏了触发面，由两个 bot 独立指出；核实成立，已补 `check-doc.yml` 的 `on.paths` 与 `_all` filter、`test.yml` 的 `_all` filter 三处。这与「复合 Action 与 job step 是两套字段与默认值语义」同属 CI 结构类：同一份配置在不同 workflow 机制下语义不同。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### kpse 能不能看见文件取决于那棵树有没有 `!!`，刷索引反而可能关掉回退
**Rule**: 把文件拷进某棵 texmf 树，不等于 kpse 找得到它。`TEXMFDBS` 里带 `!!` 前缀的树语义是**只查 ls-R、绝不扫磁盘**；不带 `!!` 的树有「ls-R 比目录旧就回退扫盘」的宽容行为。因此往 `!!` 树里拷文件后必须**无条件** `mktexlsr`（该树没有 ls-R 时等于什么都找不到，「仅在已存在时刷新」是错的）。反直觉的一面是：**刷过索引反而会关掉扫盘回退**，所以「刚刷过索引」的环境比「索引陈旧」的更容易找不到随后拷入的文件。另外 `TEXMFHOME` 在本地通常是普通树、在 CI 上（setup-texlive-action）解析到带 `!!` 的 `texmf-local`，所以这类可见性问题**本地默认不具备复现前提**。
**Why**: #1054 中同批 8 个 doc job 只有 `doc-zhmetrics` 失败，恰恰因为它在拷入 `.def` 之前跑过 `mktexlsr "$TEXMFHOME"`（`_check-doc-package.yml:251`，为它自己生成的 `zhmCJK.tfm/map`），索引是新的却不含随后拷入的文件，回退被关掉，解析回落到 `texmf-dist` 的旧版本；其他 job 靠回退扫盘侥幸成功。完整机制见 `reference/kpse-path-resolution.md`。
**Source**: `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`

### 排查上游问题前先查本仓库 `llmdoc/` 是否已有根因记录
**Rule**: 怀疑某个失败源于第三方宏包或上游机制时，先在本仓库 `llmdoc/architecture/` 与相关反思里搜索是否已经记录过同一类问题的根因链，再决定是否需要直接去读上游源码。本仓库对已知的上游问题通常已经做过一次调研并沉淀成文档；跳过这一步直接读上游源码，等于重新做一遍已经做过的工作，还可能在对外沟通中给出「根因未定位」这类不准确的中间结论。

**适用范围不止于「排查」，同样适用于「写文档与写记忆」**：往个人或项目记忆文件（如 `CLAUDE.md`）写入某条规则之前，先查 `llmdoc/` 是否已有该内容，有则对齐而不是重写。否则新写的版本很可能比既有记录弱，还多出一处需要同步的副本。
**Why**: #1048/#1050 排查 `cleveref02/03` 的 4 个 `.tlg` diff 时，第一版评论判定为「根因未定位」，走的是直接读上游 `latex2e-first-aid-for-external-files.ltx` 源码这条路；而 `llmdoc/architecture/cleveref-patch.md` 早就把根因链（LaTeX firstaid 的 `\firstaid@cref@updatelabeldata` 缺 appendix 特判、上游 `latex2e#2049` 明确不修）记录完整，直接查阅即可。#1054 是同一条规则换了对象的复发：把推送纪律写进 `CLAUDE.md` 时，llmdoc 里已有三份记录（`guides/push-and-pr-review-workflow.md`、`memory/decisions/repo-push-hook-discipline.md`、`reference/repo-git-conventions.md`），而新写的版本缺 `post-push: ✔ push succeeded` 这个明确判据、也缺 rc 75 的语义（CI 已过但存在未确认 review 活动或未解决 thread）。**第三个实例把对象从「文档」换成「代码实现」**：#1068 分析 `\selectfont` 重置用户 `kanjiskip` 时，第一版结论是「`auxiii` 分支缺少 `ctex_if_ccglue_touched:` 守卫，应当新写」，据此设计了两套在 kernel 层新增等价逻辑的方案；`grep -n "ctex_if_ccglue_touched"` 全仓一搜就能看到该守卫早已存在于 `ctex-engine.dtx` 的 engine 层（三引擎各有实现），只是被 docstrip 条件 `%<*pdftex|xetex>` 挡在 LuaTeX／upTeX 之外——真实修法是删两行守卫标记，不是新写代码。发现「某处缺少某个检查」时，先在全仓搜索该检查是否已在别处存在，再决定是调用既有实现还是新写一份；否则会得到两份语义重复、日后可能分叉的实现。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`, `llmdoc/memory/reflections/1054-l3backend-defense-scope-and-kpse-lsr.md`, `llmdoc/memory/reflections/1068-selectfont-resets-ccglue.md`

## LaTeX2e 命令钩子机制

### 验证一个用途，要检查它的产物，而不是「没报错」
**Rule**: 声称某个能力可用于某个场景时，必须端到端看该场景的实际产物——写文件的看文件字节，排版的看节点或 PDF，排序的跑一遍排序工具。「编译没报错」只证明没有致命错误，不证明产物正确；命令被原样吞掉时同样不报错。
**Why**: #550 整个预生成方案是为了让查询命令能写进 `\index` 的排序键，我测过「`\index` 里放查询命令不报错」就认为可用。审查时端到端验证发现：`\index` 先 `\@sanitize` 再原样写进 `.idx`，存进去的是 `\xpinyinvalue{汉}` 这串命令本身，跑 makeindex 得到的顺序既非拼音序也非码位序。同一场景下报错也不出现，因为报错命令是 `protected` 的、命令没展开就不触发——缺少 `query` 选项的文档会零错误编译并静默产出错误索引。
**Why（其二，同一任务内复发）**: #550 第一轮把这条定为阻塞并据此重写了手册配方，但**新配方本身又没有端到端验证**，于是同一处再犯两次：配方用 `\@tempa` 而正文里 `@` 不是字母，排序键多出一个空格；配方承诺「缺选项时立刻发现问题」，而报错命令是 `protected` 的，在 `\edef` 里不报错也不展开，静默写出坏键——**被判为阻塞的失效方式在「修好」之后依然存在**。修一个「没验证产物」的缺陷时，修法本身尤其要验证产物。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 可展开上下文里的报错要用 `\msg_expandable_error:`
**Rule**: 供 `\edef` 或其他可展开场景使用的命令，其错误分支不能用 `\msg_error:`——后者是 `protected` 的，在 `\edef` 里既不报错也不展开，会把自己整条原样留在结果里，于是错误值被静默写进产物。改用 `\msg_expandable_error:`（本仓库 `zhnumber` 已有用法）。
**Why**: #550 未加 `query` 选项时，`\edef\x{\xpinyinvalue{汉}}` 得到的是 `\__xpinyin_query_missing:n {汉}`，文档零错误编译并把这串东西当排序键写进 `.idx`。
**测试上的配套约束（注意归因）**: 断言报错的用例里，报错之后不能再放别的项——但中断来自 `checkopts` 的 `-halt-on-error`，**不是**该命令的语义（实测不加该选项时后续断言照常执行）。#550 一度把它记成「可展开报错必然中断后续」，据此把排版类基线搬到报错之后，那一节从此从未执行，两个变异都变成全绿，覆盖被静默删除。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 反复重构后要扫一遍死代码，尤其别把教训注释留在死代码上
**Rule**: 多轮重构收尾时，用哨兵注入或调用点检索确认每个函数都还被调用。删除死代码前先检查它身上有没有承载「为什么必须这样写」的注释——若有，把注释迁到活代码的对应位置。
**Why**: #550 收尾时留下 7 个从未被调用的函数（含一个中途放弃方案的残留），其中「声母永远不带声调」这条实测得来的教训只作为注释挂在死掉的 `\@@_query_affix_aux:nnn` 上。按那条注释去改代码的人会发现改了没反应、测试也不红。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 移动测试项的位置等于改变它的执行条件，搬完要复核它是否仍然运行
**Rule**: 把断言从一个 `.lvt` 搬到另一个、或在同一文件里改变顺序时，要复核它在新位置仍然会被执行。判据是搬完后重新生成基线，确认该项的输出还在 `.tlg` 里；再对它所声称覆盖的缺陷注入一次变异，确认仍然变红。
**Why**: #550 把 `tone=mark` 的排版节点基线搬进了一个报错断言之后的位置，而 `checkopts` 带 `-halt-on-error`，第一处错误即终止编译。那一节从此从未执行，`.tlg` 只剩 12 行止于报错，星号去重与标调两处变异都变成全绿——修一个问题的同时静默删掉了既有覆盖，而 check 一直是绿的。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 写下一条机制规则前，先查仓库里是否已有正确版本
**Rule**: 要在 llmdoc 或代码注释里断言「某机制会导致某现象」时，先检索仓库是否已记录过同一机制。若已有记录而自己的观察与之不符，优先怀疑自己的归因，而不是另写一条新规则。
**Why**: #550 把 `-halt-on-error` 造成的中断记成了 `\msg_expandable_error:nnn` 的语义，据此改动测试布局并删掉了覆盖。而仓库里本来就有正确记录——`pinyin-tone02.lvt` 的注释与 `build-and-test.md` 都写明「`\showbox`／`\box_log:N` 抛 `! OK.`，而 checkopts 带 `-halt-on-error`，当场终止编译，其后的用例静默不执行而 check 仍可能报绿」，我甚至在同一批改动的另一个 `.lvt` 注释里引用过它。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 表驱动的字符转换要用全量数据逐条比对，抽样只能证明主路径
**Rule**: 把字符按对照表做转换时（去声调、正规化、音译一类），验证要跑完整数据集，并与独立实现逐条比对，不能抽查几个代表字。Unicode 里「恰好缺少某个预组合形式」的字符会以裸组合符出现，按整字符查表就会漏掉，而这类字往往罕见到抽样必然错过。
**Why**: #550 把拼音转成「字母加声调数字」，用一张 29 项的预组合字符对照表实现。抽查「中女绿安行么」六个字全对；全量校验 50325 条、57493 个读音后发现一个例外——「呣」的读音 `m̀` 是裸的 `m` 加 U+0300，因为 Unicode 有 `ḿ`（U+1E3F）却没有 `m` 加钝音符的预组合形式。修法是在对照表之外单独认出裸组合符。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 不要把自己环境或工具链的状态当成被观察对象的性质
**Rule**: 判断「外部数据长什么样」或「某个工具的行为是什么」时，要排除自己引入的中间步骤与残留状态。统计脚本里的正规化、构建目录里的上一轮产物、环境变量指向的旧文件，都会让观察到的现象不属于被观察对象。做结论前先问：这个现象是它的性质，还是我的环境造成的？
**Why（其二）**: #550 还因此写错了一条构建结论——「漏掉 `unpacksuppfiles` 时 unpack 不报错」。实际 `build/` 干净时它以退出码 1 加 `! Cannot find file` 明确失败；我观察到的「静默产出空表」来自 `build/` 里上一轮的残留产物，而我据此在文档里写了「不要只看退出码」这条反向指导。排查生成式构建的问题前先 `rm -rf build/`。
**Why**: #550 调研阶段每次统计 Unihan 拼音都调了 Python 的 `unicodedata.normalize('NFD', ...)`，于是认为数据是分解形式，据此写了「遇到组合符就取声调」的 Lua 代码。实跑后输出与输入完全一样：`zhōng` 只有 5 个码位，`ō` 是单独的 U+014D，数据本身是预组合形式。`texlua` 也没有正规化函数，最终改用显式对照表。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 变异实验后先确认变异真的进了生成产物，再解读绿色
**Rule**: 在 `.dtx` 这类需要 unpack／生成的项目里做变异实验，注入之后要先核对生成出来的 `.sty`／`.def` 里确实含有该变异（`grep` 一下），然后才能把「测试仍然全绿」解读为「用例没有判别力」。
**Why**: #550 验证「两种切分模式合一」这个变异时第一次跑出全绿，据此差点判定用例缺乏判别力。实际是注入前误用 `cp` 把 `.dtx` 恢复了，变异根本没写进文件。重新注入并 `grep` 确认后，用例正常变红。这与「注入类实验必须有可核实的生效判据」是同一条规则在生成式项目上的具体写法。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 写可展开命令前先逐个实测候选函数，不要凭印象判断
**Rule**: 要让命令能用在 `\edef`、`\index` 排序键或 `bib2gls` 字段里，整条链上不能有不可展开的东西。expl3 里哪些函数可展开不能靠印象——用一个最小 `.tex` 把每个候选放进 `\edef` 试一遍，确认能落成文本再写进实现。
**Why**: #550 实测 `\str_if_in:nnTF` 与 `protected` 条件式不可展开，`\char_to_nfd:N` 嵌在 `\edef` 里直接报 100 个错。**同时也踩了反向的坑**：初版把 `\str_case:nnF` 和 `\prg_new_conditional` 的 `TF` 形式也记成不可展开，审查时被证否——它们可展开，当初失败的真正原因是判据参数里嵌了未展开的函数调用，没先用 `\exp_args:Nf` 展开。所以「试」的时候要把判据也展开，否则会把自己的展开错误记成函数的限制。这个结果决定了整个实现形状：去声调必须在生成数据库时预先算好，运行时只查表。在完整实现里调试这些要反复重跑 unpack 加编译，改用独立最小文件后一轮就能定位。可展开的替代与具体写法记在 `llmdoc/reference/coding-conventions.md`。
**Source**: `llmdoc/memory/reflections/550-xpinyin-pinyin-query.md`

### 通用命令钩子不能包装命令本体即赋值语句的场景
**Rule**: 用 `cmd/<命令>/before`／`after` 这类 `\AddToHook` 钩子包装某个命令时，先确认该命令本体是否就是一条赋值语句（如 `\setbox`）。若是，钩子代码里的任何赋值都会消耗调用方留在原地待用的 `\global`／`\long` 等前缀，使调用方前缀静默失效——不报错、不警告，只是行为退化为局部/非长命令语义。这类命令必须改用专用适配器：直接重定义其内部入口，把原本挂在钩子里的副作用移到赋值发生的位置内部，让前缀始终紧邻真正的赋值原语。
**Why**: #1029 中 `cmd/sbox/before` 钩子里的 `\@@_boundary_capture_suspend:` 做了多个全局赋值，吃掉了 `\global\sbox` 的 `\global`，导致 algorithm2e 的 `\global\sbox\algocf@capbox{...}` 在浮动体分组结束时静默丢失整段标题。最小复现不需要加载 xeCJK：`\AddToHook{cmd/sbox/before}[probe]{\advance\cnt by 1}` 单独就会触发同一问题，换成 `\relax`（无赋值）则不触发，证明这是 LaTeX2e 命令钩子机制的通用陷阱，不是任何具体宏包的缺陷。修复用 `\@@_boundary_sbox:Nn` 重定义内部入口 `sbox `，与仓库已有的 `color@b@x`／`@textcolor` 专用适配器同属一类。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`、`llmdoc/memory/decisions/1029-sbox-adapter.md`

### 报告者给出的可用变通不能替代对代码历史用途的核实
**Rule**: 报告者已定位到具体代码并给出能让当前场景可用的变通（如删除某个钩子）时，先核实这段代码的既有职责，再决定是直接采纳变通，还是保留语义、更换实现方式。变通可用不代表它是正确修复。
**Why**: #1029 中删除 `cmd/sbox/before`／`after` 两个钩子确实能让 algorithm2e 的标题恢复，但这两个钩子是 #992 系列刻意引入的，用来隔离 `\sbox` 内部 scratch box 的测量过程，防止测量用的盒子与其中的颜色切换污染外层 capture 与恢复链；直接删除会撤销这条隔离，重新引入旧问题。最终改为专用适配器，把暂停观察移到盒子内部，同时保留隔离语义和 `\global` 前缀完整性。（#997 一度被当作本条的第二个实例——「删掉 hook 里那次 `\xeCJK_select_font:`」看似应当被证否——但该证否本身建立在误读 NFSS 参数上：实测删掉后全部用例通过、#997 同样修好，删除是可行方案。该实例已撤回，教训另见「回答『当前用什么字体排版』要读 `\fontname\font`」。）
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`、`llmdoc/memory/reflections/997-xpinyin-fallback-measure-box.md`

### 缩小复现到不含本包的最小样例，才能确认是上游机制的通用陷阱
**Rule**: 怀疑某个缺陷可能是上游机制的通用性质而非本包特有时，把复现缩到不加载本包的最小 LaTeX/TeX 样例。确认为通用陷阱后，修复形态和文档警告的落点都会随之改变——不能只在具体案例的代码注释里说明，还要在架构文档里记录为独立的机制边界。
**Why**: #1029 若只盯着 xeCJK 的 `\@@_boundary_capture_suspend:` 内容，容易把注意力放在这条钩子本身该不该做全局赋值上；缩小到不含 xeCJK 的五行纯 LaTeX 后，才确认触发条件是「`cmd/<赋值命令>/before` 钩子里有赋值」这一更一般的机制，这直接决定了要用专用适配器而不是调整钩子内容，也决定了要在 `experiment/boundary-register` 用户手册里为「命令本体即赋值语句」这类场景加一条通用警告。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`
