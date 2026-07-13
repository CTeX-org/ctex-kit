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

### 已发布版本不能继续接收新变更条目
**Rule**: 写 `\changes` 前核对最新正式 release tag；发布后的新变更使用下一个未发布版本，不从 `build.lua` 当前值或 CHANGELOG 首节反推。
**Why**: #381 在 ctex 2.6.2 发布两天后落地，首版仍误记为 v2.6.2，合并后才纠正为 v2.6.3。
**Source**: `llmdoc/memory/archive/2026-07-13/381-cjkfntef-backend-boundary.md`

### 本地审查报告是独立的完成门禁输入
**Rule**: 运行过本地 code-review 时，在完成或 merge 前用忽略规则外的文件盘点读取全部 `.code-review` 报告，并把每条发现映射到当前树核实。
**Why**: PR #976 只审计 GitHub 活动，漏掉被 `.gitignore` 隐藏的报告中两个有效小问题，合并后不得不用 #978 补修。
**Source**: `llmdoc/memory/archive/2026-07-13/976-978-ignored-local-code-review.md`

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
**Rule**: 节点恢复链若要区分历史缓存与当前可见证据，应使用专用 marker，并在实际改变或观察状态的固定点发布；不能因输出类别相同就复用可能陈旧的通用状态。
**Why**: #972 的普通 `default` 原型能修直接 URL MWE，却无法穿过 #810 正确拒绝陈旧状态的下一 annotation；只有从顶层 `\Hy@EndAnnot` 的真实末尾 math 发布 `hyperref-default` 才能安全组合。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`

### 可见排版修复需要三类证据
**Rule**: 对间距、字形或线条等可见排版缺陷，同时提供可执行 MWE、定量测量和同条件前后渲染；再用会插入节点的 wrapper 组合回归证明状态能传递。
**Why**: #972 的 3.33pt 测量证明几何差异，并排截图让审查者直接看到右侧间距恢复，而颜色和下一链接用例暴露了最初普通 `default` 原型的组合缺陷。
**Source**: `llmdoc/memory/archive/2026-07-13/972-hyperref-end-annot-trusted-marker.md`

### 方向性标点策略必须保留样式与覆盖优先级
**Rule**: 修复单向标点对时，把政策放在可配置的样式计算层，并分别回归反方向、其他样式、显式字符对、全局设置和禁则；不要在 transition 中无条件短路。
**Why**: #975 若直接跳过 `FullLeft→FullRight` kern，会破坏 `banjiao` 和 `\xeCJKsetkern`；样式键只让 `quanjiao` 改默认且保持 nobreak。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`

### 字体度量回归要隔离 shaping 与首次初始化
**Rule**: 涉及区域字形和 side bearing 时使用独立字体面，并在 `\START` 前预热所有 lazy family，再记录定量基线和渲染证据。
**Why**: #975 中 `Language=` 不能改变 feature-blind 的 glyphbounds 证据，首次按需加载 Noto TC/JP 又会把 fontspec Info 混入 `.tlg`。
**Source**: `llmdoc/memory/archive/2026-07-13/975-punctuation-policy-and-font-baselines.md`

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
