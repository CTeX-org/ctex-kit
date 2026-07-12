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

## TeX 节点与输出几何

### leader 相位问题不能只测盒宽
**Rule**: 调查 `\leaders` 线条偏移时，在非零水平起点下同时检查 leader 类型与实际输出坐标，不能只比较命令盒宽。
**Why**: #531/#967 中普通、偏移和图案线型的总宽可以完全相同，根因却是 `\leaders` 以外层列表为相位原点；`subtract` 与内部片段还需分别验证端点和接缝。
**Source**: `llmdoc/memory/archive/2026-07-12/531-underline-leader-phase.md`
