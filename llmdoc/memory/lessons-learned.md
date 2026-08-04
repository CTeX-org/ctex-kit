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
**Why**: #1041 之前 xeCJK 从不在版本校验内：`check-tag.yml` 的 `paths` 只列 ctex/zhlineskip，`release.yml` 的三方校验里 xeCJK 落进 `*)` 并打 `::notice::...跳过三方校验`。于是 `xeCJK-v3.10.5-rc2` 发出了一个自报 `v3.10.4` 的包，release workflow 全程绿灯。对照 #935 的 zhspacing：那是有意识排除且留了 followup issue。
**Source**: `llmdoc/memory/reflections/1041-xecjk-version-gate.md`

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
**Why**: #1029 换掉的两个 `cmd/sbox` 钩子是 #992 为隔离 `\sbox` 离线测量而引入的。只看 #1029 自己的算法标题 MWE，无法说明隔离是否在换实现时丢了。补的 sbox 矩阵在 base 与修复后同为 96／96，而删掉 `suspend`／`resume` 的对照组为 72／96——有了这个对照，96／96 才是证据而不是空话。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

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
**Why**: #1029 的第一版回归中，只破坏「暂停深度归零」（去掉 `\int_gdecr:N`）或只撤销隔离，测试都全绿；而还原原缺陷时整个文件变红，让我误以为各项都在守着。逐项变异才暴露出两项完全没有判别力、另两项读的是别人的值。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 每项测试用独立的盒子／寄存器，否则读到的是上一项的遗留值
**Rule**: 断言全局赋值是否生效时，每一项必须使用各自独立的盒子或寄存器。共用一个全局对象时，前一项留下的值会被后一项读到，测试看似通过却什么都没断言。写完后应改变该项的内容重新生成基线，确认读数随之变化。
**Why**: #1029 的第一版回归让三项共用同一个 savebox，其中两项读到的是第一项留下的 21.8pt——把内容换成明显更宽的字符串，读数纹丝不动；`[3cm][l]` 那项的期望值本应是 85.35826pt，却记成了裸文本的 21.8pt。缺陷版下这两项出现 0.0pt 也只是第一项失败的连带结果。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 断言「上游行为已修复」之前，先在不加载本包的环境里测一遍
**Rule**: 声称修复了某个上游命令的行为前，先在纯上游环境（不加载本包）里测同一组样例。若上游本来就不工作，那不是本包的回归，也不该写进修复范围；应把它作为既有限制固定下来并注明成因。
**Why**: #1029 我写了「`\global\savebox` 三种形式跨分组保住内容」，实测纯 LaTeX 下这三种全为 0.0pt——`\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，与本包无关。真正修好的只有 `\global\sbox`。
**Source**: `llmdoc/memory/reflections/1029-sbox-global-prefix.md`

### 顺手做的一致性修改要单独确认有无校验
**Rule**: 同一约束改到多处时，逐处确认哪些有回归覆盖。若某处的症状在结构上无法观察（例如被包进 hbox 后内层弹性不外露），就在文档里如实写明它依赖代码审查而非校验，不要让它蹭进另一处的覆盖声明。
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
**Rule**: 新增或改写回归测试后，故意还原到修复前的实现，确认测试会失败；测试全部显示“通过”不构成“这项测试确实能检测该缺陷”的证据，只能证明测试当前不会误报。同理，声称某测试守护某条行为之前，也要用变异实测确认是它会红——没有任何输出行的 `.tlg` 段落不构成校验，把守护职责写错到文档里会让后来者误以为已有覆盖。
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
**Rule**: 涉及区域字形和 side bearing 时使用独立字体面，并在 `\START` 前预热所有 lazy family，再记录定量基线和渲染证据。预热范围要包括**被测命令自己会切换到的字形**，不只是测试正文显式用到的字体；判断方法是读被测命令的定义体，把它切换的每一种字形都排一遍。
**Why**: #975 中 `Language=` 不能改变 feature-blind 的 glyphbounds 证据，首次按需加载 Noto TC/JP 会污染 `.tlg`；#999 的 FandolFang 也必须预热才能消除三平台 fontspec 尾随日志差异；#1046 的 `\meta` 用 `\meta@font@select`（`\itshape`）排参数、CJK 斜体还要自动伪斜，不预热时同一段内容实测在 54.4378／76.23781／135.92561pt 之间跳。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`, `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`

### 既有测试全绿只说明测试覆盖的场景没问题
**Rule**: 把「既有测试全绿」当作「缺陷不存在」的证据之前，必须先核对那些测试的**构造**是否真的覆盖了报告的场景——尤其当测试用简化替身模拟被测对象时，简化掉的那一层可能正是缺陷所在。核对成本通常很低，就是打开 `.lvt` 看关键条件在不在。
**Why**: #1046 的自动分析引用 `codedoc-meta-ecglue01` 全绿，把可复现的代码事实（左侧恒 5.25pt、右侧恒 3.33pt）归因成「尖括号与斜体字形造成的视觉差异」；而那个测试自己模拟内层 `\__codedoc_meta:n` 时没有 `\texttt` 外层，`\texttt` 正是缺陷的必要条件。#1038 的既有 `tabular01` 因每行 `\\` 前有空格而零判别力是同一条规则的前一次发作——那次简化掉的是空白，这次是外层字体切换命令。
**Source**: `llmdoc/memory/reflections/1046-1047-meta-anchor-font-context.md`, `llmdoc/memory/reflections/1038-tabular-cr-group-peek.md`

### 否定性结论要说明搜索了什么模式、为什么能穷尽
**Rule**: 「未发现相关代码路径」「没有这样的实现」这类结论，必须给出搜索的具体模式以及该模式为何能穷尽目标空间；否则它只是「我没找到」，不能当作「不存在」写进结论。
**Why**: 把代码事实归因成视觉错觉是这条失效的典型后果（#1046）。同一任务里还有第二个例子：`\hypertarget` 看起来只有一条实现路径，实际按目标是否为空分派到 `\Hy@raisedlink` 与驱动层 `\hyper@anchor` 两个出口，只注册前者时空目标形式仍缺间距——判据是读分派函数的分支，而不是看公开命令名。
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
**Rule**: 面对上游宏包版本漂移导致的 `.tlg` diff，先判断根因属于哪一类，再决定要不要刷基线：TL 打包侧暂时没跟上 CTAN（会随 tlnet 同步自愈）的漂移不刷——刷了等于把上游当前滞后快照里的错误数值固化下来，等 TL 同步后还要改回来；上游有意修正且不会回退的漂移必须刷。这与「状态表中的绿色单元才进入通过基线」是同一族但不同粒度：那条管的是「矩阵内哪些单元可以写进基线」，这条管的是「整批 diff 该不该刷」的前置分类。
**Why**: #1048/#1050 中 l3backend 的漂移是 tlnet 落后 CTAN 五个月（会自愈），pgf 的舍入修正是上游明确的、不会回退的行为变更；两者的 `.tlg` diff 表现类似，但处置方式相反——一个该等 TL 同步，一个必须刷。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### 关掉断言不是刷基线
**Rule**: 刷新一个测试的基线，前提是让测试在正确环境下重新跑出真实结果；把断言本身改弱或删除（例如把具体的 `PASS: ...` 输出换成一个占位字符串），即使 `l3build check` 变绿，也不是刷基线，而是删除了校验本身。判断某次「基线更新」是否合法，要看改动前后测试是否仍然观察同一件事。
**Why**: #1048/#1050 中 `fntef-phase01` 曾被改成把五条 `PASS: ...` 换成 `PHASE-CHECK-PENDING`，这等于删除了校验；而它在配对版本（backend 与 pgf 都是当时应有的版本）下本来是全绿的，本不需要放弃断言。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### 注入类实验必须有可核实的生效判据
**Rule**: 用替代版本的文件（宏包、依赖、配置等）临时覆盖某个路径来做对照实验时，必须有一个独立于实验结论的判据，能核实注入本身确实生效，而不是仅凭实验结果推断。没有这个判据，「注入没生效、测的还是旧版本」与「注入生效了、新版本确实不行」在结果上会完全相同，容易把环境错误误判为结论。
**Why**: #1048/#1050 中两次尝试用新版 l3backend 替换测试环境都放错了位置（先后误写进会被 `cleandir` 清空的 `testdir`、试图通过 `TEXINPUTS` 覆盖但被 l3build 写死的设置盖过），两次都得到「仍然报错」的结果，若不核实测试目录里实际文件的日期戳，会顺势得出「新版本也修不好」这个错误结论。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

### 排查上游问题前先查本仓库 `llmdoc/` 是否已有根因记录
**Rule**: 怀疑某个失败源于第三方宏包或上游机制时，先在本仓库 `llmdoc/architecture/` 与相关反思里搜索是否已经记录过同一类问题的根因链，再决定是否需要直接去读上游源码。本仓库对已知的上游问题通常已经做过一次调研并沉淀成文档；跳过这一步直接读上游源码，等于重新做一遍已经做过的工作，还可能在对外沟通中给出「根因未定位」这类不准确的中间结论。
**Why**: #1048/#1050 排查 `cleveref02/03` 的 4 个 `.tlg` diff 时，第一版评论判定为「根因未定位」，走的是直接读上游 `latex2e-first-aid-for-external-files.ltx` 源码这条路；而 `llmdoc/architecture/cleveref-patch.md` 早就把根因链（LaTeX firstaid 的 `\firstaid@cref@updatelabeldata` 缺 appendix 特判、上游 `latex2e#2049` 明确不修）记录完整，直接查阅即可，不需要重新排查。
**Source**: `llmdoc/memory/reflections/1048-1050-upstream-l3backend-pgf-baseline-drift.md`

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
