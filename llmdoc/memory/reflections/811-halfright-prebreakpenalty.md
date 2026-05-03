# 811 halfright prebreak penalty Reflection

## Task
- 记录 xeCJK issue #811 的实现经验：解决“全角右标点后紧跟半角右标点时，TeX 可在两者之间断行，导致半角右标点出现在行首”的问题。
- 最终在 `xeCJK/xeCJK.dtx` 中新增实验性选项 `experiment/halfright-prebreakpenalty`，用于在相关 interchar 边界前插入禁断 penalty。

## Expected vs Actual
- Expected outcome.
  - 期望用一个可控且最小侵入的开关，禁止 `FullRight` 或一般 CJK 收尾字符后紧跟 `HalfRight` 时在两者之间断行，同时保持现有标点压缩与 glue 行为不被破坏。
- Actual outcome.
  - 初始实现只是在 `FullRight -> HalfRight` 的 interchartoks 末尾追加 penalty，结果对真正的问题场景无效；TeX 仍会在 `\@@_punct_glue:NN` 产生的 glue 处断行。
  - 重新分析后改为区分两类路径：
    - `CJK -> HalfRight` 继续通过 `\xeCJK_app_inter_class_toks:nnn` 追加条件 nobreak；
    - `FullRight -> HalfRight` 改为完整替换 interchartoks，把 penalty 放到 `\@@_punct_glue:NN` 之前，问题才被真正修复。

## What Went Wrong
- 误以为对 `FullRight -> HalfRight` 路径，像一般 interchar 修补一样“在 toks 末尾追加 penalty”就足够。
- 一开始没有把断行点精确定位到 `\@@_punct_glue:NN` 插入的 glue 位置，而是把整段 toks 当成一个整体看待，忽略了 penalty 相对 glue 的前后顺序决定了它是否能抑制该断点。
- 对 experiment keypath 的定义位置也存在潜在误判：如果把 key 写到 `xeCJK / experiment` 而不是 `xeCJK / options / experiment`，`\xeCJKsetup` 不会自动经由 `.meta:nn` 路由过去，接口实际上不可达。

## Root Cause
- 根因一是对 TeX 断行语义的判断不够节点化：本问题不是“边界末尾缺一个禁止断行标记”，而是“真正可断的位置就在 glue 节点处”，因此 penalty 必须出现在 glue 之前，不能事后补到 toks 尾部。
- 根因二是对 xeCJK interchartoks 生成方式的认识不够精确：`\xeCJK_FullRight_and_Default:` 并不是一个适合事后追加小修补的黑盒，它内部已经固定了 `\@@_punct_glue:NN` 的位置；若目标是改变该 glue 之前的断行语义，就必须整体接管这段 toks。
- 根因三是对 l3keys 路径查找细节需要更明确的记忆：`\xeCJKsetup` 走的是 `\keys_set:nn { xeCJK / options }`，带 `/` 的 key 名会直接沿子路径查找，而不是先命中顶层 key 再触发 `.meta:nn` 转发。

## Missing Docs or Signals
- 现有架构文档已经较好说明了 xeCJK 依赖 interchar class 与边界 toks，但还缺一条更具体的实现信号：当问题与“某段 interchartoks 内部已经包含 glue/penalty 次序”有关时，应先确认断行发生在什么节点，再决定是“追加”还是“完整替换”。
- 对 experiment 子路径的文档也缺一个 xeCJK 侧实例。`ctex / experiment` 的决策文档存在，但尚未明确提醒：xeCJK 若通过 `\xeCJKsetup` 暴露实验 key，路径应落在 `xeCJK / options / experiment` 下。
- `HalfRight` 类的语义边界以前没有被单独总结。此次实现确认其 13 个成员整体都是右侧/收尾型标点，适合作为一个整体施加禁则，而不是再细分子类。

## Promotion Candidates
- 可考虑提升到 stable docs 的内容：
  - `guides/` 或 `architecture/`：xeCJK interchar 补丁的判定原则——若修复目标依赖 penalty 与 glue 的相对顺序，先定位真实断点；需要把 penalty 放到既有 glue 之前时，不要机械使用 `\xeCJK_app_inter_class_toks:nnn`，而应改为完整替换对应 class-pair 的 toks。
  - `reference/`：补充 xeCJK keypath 规则，明确 `\xeCJKsetup` 的公开 key 应定义在 `xeCJK / options / ...`，尤其是实验性命名空间应位于 `xeCJK / options / experiment`。
- 更适合先保留在 memory 的内容：
  - `\xeCJK_class_group_end:` 等价于 `\c_group_end_token`，它只结束当前 TeX 分组，不会回滚外层已经设定的 bool；这是本次调试中的具体认知点，但暂不必上升为稳定架构文档。
  - `HalfRight` 的 13 个成员可以整体禁则这一判断，可先作为 issue #811 的局部经验保留；若未来再出现同类规则扩展，再决定是否升格为 reference。

## Follow-up
- 在后续遇到 xeCJK 标点断行或禁则问题时，先按“字符类对 -> interchartoks 展开 -> 真实断点节点”三层顺序排查，不要先默认采用 toks 末尾追加补丁。
- 若后续实验性选项继续增加，考虑补一份 xeCJK experiment key 的路径约定说明，避免再次把 key 误挂到 `xeCJK / experiment`。
