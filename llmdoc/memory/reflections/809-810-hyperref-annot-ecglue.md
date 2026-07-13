# 809-810 hyperref annotation ecglue Reflection

## 任务

记录 xeCJK issue #809 / #810 的联合修复经验：`hyperref` 链接注释起始处的 whatsit 既可能吃掉本应保留的 CJK 边界信息，也可能错误继承陈旧的 `default` 状态，分别导致正文 `\ref` 前侧 ecglue 丢失与目录链接起始处伪 ecglue 插入。最终修复与回归测试落在 `xeCJK/testfiles/hyperref-ecglue01.lvt` / `.tlg`。

## #972 后的适用范围修正

本文下文“真正的问题不在链接结束端”“只 patch `\Hy@BeginAnnot`”等结论只针对 #809/#810 的**注释进入端状态污染**。#972 后不能把它泛化为所有 hyperref 间距问题：`\url` 的实际末尾 math 节点会被 `\Hy@EndAnnot` 的结束 whatsit 遮蔽，这是独立的**输出端可见节点丢失**，必须在结束端观察末节点并发布可信 `hyperref-default`。两者不冲突：开始端拒绝陈旧普通 `default`，结束端只从真实末尾 math 生成专用可信标记。详见 [[../decisions/972-hyperref-end-annot-trusted-marker]]。

## 现象对照

### #809：正文 `\ref` 在 hyperref 下缺少前侧 ecglue

期望行为是：中文字符后面跟 `\ref` 生成的链接文本时，若链接首字符属于 Default 类，xeCJK 应像普通 CJK→Default 边界一样恢复前侧 ecglue。

实际行为是：开启 `hyperref` 后，`\Hy@BeginAnnot` 内部 `\set@color` 产生的 whatsit 把当前边界状态覆盖成 `default`，导致原本应从前一个 CJK 节点续接出来的 CJK→Default 边界信息丢失，ecglue 不再恢复。

### #810：目录链接注释起始处插入伪 ecglue

期望行为是：目录编号和标题之间的距离只由 titletoc/目录格式本身决定，hyperref 注释起始处不应额外制造中西文空白。

实际行为是：目录链接起始处的 `pdf:bann` whatsit 错误继承了旧的 `default` 节点状态，xeCJK 的 whatsit 恢复路径把它当成可恢复的 Default 边界，于是编号和标题之间凭空多出一段 ecglue。

## 根因

### 真正的问题不在链接结束端，而在注释开始端的状态污染

这次最重要的认知转变是：`hyperref` 相关 ecglue 异常不是“链接结束后没恢复好”，而是“链接一开始就把边界状态改坏了”。`\Hy@BeginAnnot` 是 PDF 注解 whatsit 真正进入节点链的位置，也是 `\set@color` 等逻辑介入并覆盖 xeCJK 最近节点类别缓存的位置。

因此，若只在 `\Hy@endcolorlink` 之类的链接结束端补救：

- 对 #809 来说，已经来不及，因为 ecglue 是否恢复的判定发生在链接内容开始时，缺失的边界信息不会在结束端自动回来。
- 对 #810 来说，也太晚了，因为错误继承的 `default` 状态已经在注释开始时参与过恢复链判断，伪空白已经被插入。

### `default` 不是罪魁祸首，陈旧或误继承的 `default` 才是

一个容易犯的错误是看到 #810 后就想删掉 `\__xeCJK_recover_glue_whatsit:` 里的 `default` 分支。但这会破坏 #807 等既有修复，因为 `color` / `xcolor` 的合法恢复仍依赖 `default` 分支来跨颜色 whatsit 续接边界语义。

真正需要避免的不是“所有 `default` 恢复”，而是“把不应继承的 `default` 重新送进恢复链”。也就是说：

- `default` 分支必须保留，作为通用恢复函数的合法能力之一；
- 但 `hyperref` 补丁必须在 `\Hy@BeginAnnot` 处主动清掉旧状态，并且不要把陈旧 `default` 重放出来。

## 修复决策

### 从 patch `\Hy@endcolorlink` 切换到 patch `\Hy@BeginAnnot`

最终方案放弃了 patch 链接结束端的思路，改为只 patch `\Hy@BeginAnnot`。原因是开始端才同时满足两件事：

1. 能在注释 whatsit 插入前读到“当前真实边界是什么”；
2. 能在注释开始后立刻决定“哪些状态值得重放，哪些状态必须丢弃”。

这次方案转变本质上是把修复目标从“事后补救输出结果”改成“在状态机入口处保证状态正确”。

### 保存/清空/选择性重放

稳定方案可以概括为三步：

1. 进入 `\Hy@BeginAnnot` 前，先保存当前 xeCJK 节点类别；
2. 立刻清空旧的全局状态，避免注释起始 whatsit 继承到历史残留；
3. 注释开始后只对 `CJK` / `CJK-space` / `CJK-widow` 三类节点选择性重放标记，而显式不重放 `default`。

这种“选择性重放”同时解决了两个方向的问题：

- 需要保住 CJK 类状态，才能修复 #809 中正文 `\ref` 前侧 ecglue 丢失；
- 必须拒绝重放 `default`，才能避免 #810 中目录链接起始处把旧 default 当成真实边界继续恢复。

## 关键约束

### 1. 不删除 `\__xeCJK_recover_glue_whatsit:` 的 `default` 分支

这是本次最关键的约束之一。`default` 分支仍然是 color/xcolor 修复链的一部分；删掉它会把 #807 一类问题重新带回来。hyperref 修复应通过“补丁点上不重放 default”来实现，而不是通过“彻底取消 default 恢复能力”来实现。

### 2. 不 patch `\Hy@endcolorlink`

先前围绕链接结束端的方案最终被替换，是因为它既无法恢复开始时已经丢失的边界信息，也无法阻止开始时已经发生的误恢复。对这类注释起始 whatsit 问题，结束端补丁在架构上就处于错误位置。

### 3. 只 patch `\Hy@BeginAnnot`

把补丁面收缩到单一入口有两个好处：

- 心智模型更清晰：所有与 hyperref 注释起始 whatsit 相关的状态保存/恢复都集中在同一处；
- 回归更稳：不会再让开始端和结束端各自维护一半状态机，减少相互覆盖或顺序依赖。

## 实验方法

### 先在 `./tmp` 用独立 `.sty` 验证，再写回 `.dtx`

这次一个有效的工作流是先在项目内 `./tmp` 放独立实验样式文件，快速验证不同 hook 点和状态重放策略，再把已证实有效的逻辑写回 `xeCJK.dtx`。这样做的价值在于：

- 可以快速比较 patch `\Hy@endcolorlink` 与 patch `\Hy@BeginAnnot` 两条路线，而不必每次都重建完整 `.dtx` 产物；
- 便于隔离“hyperref patch 策略本身”与“docstrip/文档源码改写”带来的干扰；
- 一旦实验结论稳定，再回写 `.dtx` 时更容易保持补丁最小化。

对 xeCJK 这类单体 `.dtx` 项目，先用独立 `.sty` 做最小实验特别有价值，因为它能显著降低迭代成本。

## 测试经验

### 一个回归文件覆盖两种相反症状

`xeCJK/testfiles/hyperref-ecglue01.lvt` 这次之所以重要，是因为它没有只测“有没有少空格”，而是同时覆盖：

- 应恢复而未恢复的场景；
- 不应恢复却被误恢复的场景。

对状态机补丁来说，这比只写单向回归更稳。因为一条恢复链往往既可能“恢复不足”，也可能“恢复过度”；只测其中一边，往往会把补丁推向另一个错误极端。

## 教训

- 只要问题发生在 whatsit 介入边界判定的时刻，优先检查“状态在入口处是否已被污染”，不要先假设需要在结束端补救。
- `default` 分支是否存在，与 `default` 状态是否应在某个补丁点被重放，是两回事；不能因为某个场景里 `default` 造成误恢复，就删掉通用恢复能力。
- 对 hyperref 这类包，链接注释开始端通常比结束端更接近真实根因，因为节点链和颜色/注解 whatsit 都是在这里第一次改变。
- 对单体 `.dtx` 代码库，先在 `./tmp` 里用独立 `.sty` 做实验，再回写正式源码，是一种高性价比的补丁验证方式。
