---
name: ctex-architecture-doc
description: 反思: ctex 架构独立文档的创建过程、源码阅读方法与已知文档缺口
type: reflection
---

# ctex-architecture-doc Reflection

## Task
- 研究 ctex 包完整架构并创建独立文档 `llmdoc/architecture/ctex-architecture.md`（约 260 行），覆盖加载链、字号系统、引擎适配、标题结构、ctexpatch 基础设施等核心子系统。

## Expected vs Actual
- 预期结果：产出一份与 `xecjk-architecture.md` 平行的、可独立阅读的 ctex 架构参考，从总览到各子系统均有清晰入口。
- 实际结果：文档按计划完成。内容从 `ctex/ctex.dtx`（13114 行）直接提取结构化，并与已有 `package-architecture.md` 中的 ctex 段落保持互补而非重复。

## What Went Wrong
- 最初尝试通过 investigator 子代理完成源码阅读，但代理在处理 13114 行的大文件时触发了 524 超时错误。最终回退到主对话中分段 `Read` 文件的方式完成。
- 对 docstrip guard 的跟踪需要额外注意力。`ctex.dtx` 使用 `%<*class|ctex>`、`%<*pdftex>` 等大量条件编译标签来控制同一源码输出到不同产物文件；只阅读源码文本不跟踪当前活跃 guard 栈，容易误判某段代码属于哪个产物。

## Root Cause
- 子代理超时的直接原因是 ctex.dtx 文件体量极大（13000+ 行），单次请求内很难在有效时间内完成全文读取加摘要。对于这类大文件，直接在主对话中以分段 offset/limit 方式阅读更可靠。
- docstrip 组织方式是 LaTeX 项目的标准做法，但对 LLM 来说不如 one-file-per-module 易于解析。需要维护者提前记录关键 guard 与产物的对应关系。

## Missing Docs or Signals
- 新文档未深入覆盖 pdfTeX 引擎细节（CMap 选择、zhmap 字体映射、CJK 编码切换）。这在 ctex 的现代使用中优先级较低，但对理解遗留兼容层仍有价值。
- `ctex-engine-xetex.def` 与 xeCJK 的协作边界（ctex 在 xeCJK 加载前/后分别设置什么）尚未文档化。若后续涉及 xeCJK 与 ctex 联动问题（如 #324 类跨包基线影响），需要补充这层关系。
- 缺少一份 docstrip guard 与输出产物的快速对照表。目前新架构文档中有基础表格，但 guard 嵌套组合（如 `%<*class&!beamer>`）的完整说明仍在源码注释中。

## Promotion Candidates
- 可提升到 `reference/`：docstrip guard 与产物文件的精确对照表，包含嵌套/排除组合，便于后续源码修改时快速定位影响范围。
- 可提升到 `guides/`：大文件（10000+ 行 dtx）的 LLM 辅助阅读策略——用 offset/limit 分段、以代码节标题行定位跳转点、避免委托子代理处理全文。
- 仅保留在 memory：investigator 代理对大文件的 524 超时行为属于工具层限制，不适合写入面向维护者的稳定文档。
- 仅保留在 memory：`experiment/` 命名空间"不是暂存区而是表达引擎间语义不同构"的设计意图已在 #717、#543 反思中记录，此处仅做确认。

## Follow-up
- 后续可补充 `ctex-engine-xetex.def` 与 xeCJK 的协作时序文档，特别是 ctex 设置 `\xeCJKsetup` 的时机和参数来源。
- 若需要支持 pdfTeX 相关 issue，应优先补充 pdfTeX 引擎层的架构段落（CMap、zhmap、CJK 编码模型）。
- 考虑为 `architecture/ctex-architecture.md` 新增一节 "docstrip guard 快速对照"，将当前散落在源码中的标签组合系统化。
