# 543 font-size-system Reflection

## Task
- 为 ctex 的字号体系实现 `experiment/font-size-system` 选项，在默认 `word` 与 `traditional` 两套预设之间切换，并允许用户通过 `ctex-fontsize-<name>.def` 提供自定义字号表。

## Expected vs Actual
- 预期结果：在不改动 `\zihao`、`.clo`、math sizes、文档类默认字号消费者代码的前提下，把原先硬编码的字号表抽象成可切换的数据源；默认行为保持现状，`traditional` 仅改动 6 个字号值，行距公式继续保持统一，用户还能通过公开 API 注册自定义系统。
- 实际结果：实现最终放在 `ctex / option / experiment` 子路径，用 `experiment / font-size-system .tl_gset:N` 保存选项值；字号 prop 的构建从原硬编码 clist 改为由 `\str_case:onF` 在加载期分派 `word`、`traditional` 或外部 `ctex-fontsize-<name>.def`；消费者继续通过统一 key 查表，因此 `.clo`、math sizes 与 `\zihao` 等路径无需改写。该能力仅作为包/类选项生效，不支持 `\ctexset` 运行时切换。

## What Went Wrong
- 最容易误判的点是把 `font-size-system` 套用到 `fontset` 那种“两阶段模式”上，直觉上会以为既然是 key，就也应该支持 `\ctexset` 在运行时切换。但字号 prop 在加载阶段即被构造成常量，后续大量消费者都假定它是稳定查表源；若事后再切换，等于要求重建一整套尺寸表、相关派生尺寸与类级默认设置，代价和破坏面都远大于表面上的“换个 key 值”。
- 另一个易错点是实现位置。维护者已明确要求像 #717 的 `CJKecglue` 一样放在 `experiment` 命名空间下，而不是直接暴露为主 key；若忽略这一要求，后续文档和接口稳定性承诺都会被提前锁死。
- expl3 语法层面也有一个容易过度修正的地方：在顶层代码里使用 `\str_case:onF` 分派时，分支代码中的 `#1` 不是嵌套定义体参数，不需要写成 `##1`。如果机械套用“见到参数就双写”的经验，反而会把顶层分派代码写坏。
- 测试方面不能只保存一份通用基线。字号/盒子度量在四个引擎上本来就可能不同，尤其是 `\zihao`、盒宽、字体切换后日志输出这类观测值；如果预先没有把这件事当成约束，就容易把正常的引擎差异误认为实现不一致。

## Root Cause
- 根因一是把“接口看起来像已有选项”误当成“生命周期也应与已有选项相同”。`fontset` 的切换模型包含运行时路径，但 `font-size-system` 的核心数据结构是加载期一次性构建的常量 prop，二者并不对称。
- 根因二是缺少对“实验性统一接口应先落在 `ctex / experiment` 子路径”这一维护约束的显式记忆，容易在实现初期仍按常规正式 key 设计。
- 根因三是对 expl3 顶层代码与宏定义体中参数记号规则的边界不够警觉，导致 `#` 双写规则容易被误用到不该使用的场景。

## Missing Docs or Signals
- 缺少一份稳定文档，明确哪些 `ctex` 选项属于“加载期构建常量、不可运行时重配”的类别，并说明判断标准。`font-size-system` 这次清楚表明：只要下游消费者广泛依赖加载期查表结果，该选项就不应承诺 `\ctexset` 运行时切换。
- 缺少一份 `ctex` 实验性接口命名约束的稳定说明。虽然 #717 已在 memory 中记录了模式，但像 `font-size-system` 这种新统一接口仍然需要靠维护者口头要求来决定是否进入 `experiment/`。
- 缺少一份面向维护者的 expl3 书写提示，强调“顶层控制流里的参数 token 不等于嵌套宏定义参数”，避免把 `##` 规则机械化。
- 测试文档虽已说明 `ctex` 要维护四引擎基线，但可以更直白地补一句：凡涉及字号、盒子度量、`\loggingoutput` 或字体尺寸日志的测试，应直接预期需要分别保存四引擎基线。

## Promotion Candidates
- 可提升到 `reference/` 或 `architecture/`：新增 `ctex` 统一接口时，如果底层数据在加载期即构造为常量并被多个消费者共享，应明确标记为“仅包/类选项，不支持 `\ctexset` 运行时切换”。
- 可提升到 `reference/`：`ctex / experiment` 应作为维护中的稳定命名空间规则，用于承载语义或后端契约尚未完全冻结的统一接口；`font-size-system` 与 `CJKecglue` 可作为并列例子。
- 可提升到 `reference/coding-conventions.md`：在 expl3 顶层控制流（如 `\str_case:onF`）中使用参数时，不要把宏定义体里的 `#` 双写规则机械迁移过来。
- 可提升到 `reference/build-and-test.md`：字号/盒子度量类测试默认按四引擎分别保存基线，因为不同引擎的度量日志差异属于预期行为。
- 仅保留在 memory：`traditional` 相比 `word` 恰好改动的 6 个具体字号值，以及自定义文件名固定为 `ctex-fontsize-<name>.def`、公开 API 为 `\ctex_save_font_size:nn`，这些更像此功能的实现细节与接口清单，后续若要沉淀，应进入专门的字号系统参考文档，而不是先写进通用架构说明。

## Follow-up
- 下一步应考虑在稳定文档中补两条规则：一是 `ctex / experiment` 的接口落位准则，二是“加载期常量型选项不支持 `\ctexset` 运行时切换”的判断标准；同时在测试参考中补充字号/度量类场景的四引擎基线预期。
