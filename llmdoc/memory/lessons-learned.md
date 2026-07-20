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

### 本地审查报告是独立的完成门禁输入
**Rule**: 运行过本地 code-review 时，在完成或 merge 前用忽略规则外的文件盘点读取全部 `.code-review` 报告，并把每条发现映射到当前树核实。
**Why**: PR #976 只审计 GitHub 活动，漏掉被 `.gitignore` 隐藏的报告中两个有效小问题，合并后不得不用 #978 补修。
**Source**: `llmdoc/memory/archive/2026-07-13/976-978-ignored-local-code-review.md`

### APPROVE 总评不覆盖详情中的 finding
**Rule**: 任务要求处理全部审查问题时，按阻塞、重要和小问题的逐项计数闭环；总评为 APPROVE 或建议标为 optional 都不能自动视为已处理。
**Why**: PR #983 第一轮自动审查虽为 APPROVE，仍列出 1 个实现注释小问题；初次收尾跳过后，最终 completion audit 才补上并经增量审查确认 0/0/0。
**Source**: `llmdoc/memory/archive/2026-07-14/275-heading-query-interfaces.md`

### 验证强度按当前增量风险收缩
**Rule**: 主体改动已有完整验证后，仅涉及注释或措辞的后续小改使用差异检查、必要的定向实验和强制 CI；只有增量重新触及语义、解析、生成物或基线时才重跑完整本地门禁。
**Why**: PR #988 在完整 `l3build ctan` 已通过后仍为标题定义名称和一行注释重复全量构建，增加等待且中止时产生局部构建噪声，没有带来相称的新覆盖。
**Source**: `llmdoc/memory/archive/2026-07-15/986-987-third-party-docs-and-proportional-verification.md`

## TeX 节点与输出几何

### leader 相位问题不能只测盒宽
**Rule**: 调查 leader 线条偏移时，在非零水平起点下同时检查 leader 类型、实际输出坐标和 mark 的跨片段连续性，不能只比较命令盒宽；规则型与周期型 mark 应分别选择原语。
**Why**: #531/#967 中 `\leaders`、`\cleaders`、`\xleaders` 的总宽可以完全相同，但前者端点随外层相位漂移，`\cleaders` 又会使周期波浪线在 CJK 分片间产生双峰；只有分开验证端点和接缝才能选出正确方案。
**Source**: `llmdoc/memory/archive/2026-07-12/531-underline-leader-phase.md`

### 字符分类修改必须检查节点结构和旧类消费者
**Rule**: 调整或新增 interchar 字符类时，用 `\showbox` 同时验证 glyph、glue、kern、penalty 等节点，并反向审计所有直接判断或枚举旧类的消费者，不能只比较视觉效果或总盒宽。
**Why**: #284 中总宽抵消掩盖了多余标点节点，#382 新增 `PoZheHao` 又因遗漏 `FullRight` 的直接判断重现历史错误；分类标签正确不代表所有下游语义自动正确。
**Source**: `llmdoc/memory/archive/2026-07-13/284-fullwidth-tilde-longpunct.md`, `llmdoc/memory/archive/2026-07-13/382-dash-width-punct-if-right-and-cmap-metrics.md`

### 边界状态必须区分语义与可信来源
**Rule**: 边界恢复不能只信全局语义缓存；必须用当前列表证据，或让 capture 覆盖完整命令并在真实观察点记录首尾类别。
**Why**: #972 的专用 marker 曾证明普通 `default` 可能是陈旧状态；#999 随后用完整 annotation stream 吸收该证据并删除专用 marker，使实际输出类别直接成为恢复依据。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`

### 可见排版修复需要三类证据
**Rule**: 对间距、字形或线条等可见排版缺陷，同时维护定量宽度、节点结构和同条件渲染三层 oracle；再用会插入节点的 wrapper 组合回归证明状态能传递。
**Why**: #972 的测量、截图和组合用例暴露了普通 `default` 原型缺陷；#999 又证明默认 glue 等宽会让宽度或截图假通过，必须由节点测试区分来源。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

### 命令边界修复必须覆盖输出等价矩阵
**Rule**: 验证命令边界间距时，以相同可见字符的直接输入为 oracle，按实际输出首尾类别和 `00/10/01/11` 记录精确单元，并用可区分 glue 与节点证据排除默认宽度假通过。
**Why**: #491 按命令各抽一个场景，未暴露同一命令更换输出类别或源码空格后的异常；#992 的完整矩阵和 #991 的 CJK 引用证明单点通过不能推出整类已修复。
**Source**: `llmdoc/memory/archive/2026-07-18/992-command-boundary-oracle-matrix.md`, `llmdoc/memory/archive/2026-07-20/999-command-boundary-capture-framework.md`

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
