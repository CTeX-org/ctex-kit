# [Task Reflection]

## Task
- 为 xeCJK issue #531 记录一次修复反思，聚焦 `\CJKunderline-{...}\CJKunderline-{...}` 两组拼接时接缝处约 2pt 下划线间隙的问题。
- 总结从初始误判到最终定位 `\leaders` 对齐语义的分析过程，并沉淀后续处理 xeCJKfntef / ulem 下划线边界问题时可复用的检查点。

## Expected vs Actual
- 预期结果：
  - `\CJKunderline-` 的连续拼接应与单个更长分组得到一致的下划线覆盖，接缝处不应出现可见空隙。
  - `\xeCJK_ulem_var_leaders:` 的首次 leaders 变体应与标准 `\UL@leaders` 一样，能够覆盖 leaders 区域边界盒。
- 实际结果：
  - 两个相邻的 `\CJKunderline-` 分组在接缝处会跳过一个 leader box 宽度，形成约 2pt 的间隙。
  - xdvipdfmx 输出坐标本身没有漂移；真正的问题发生在 TeX 侧 leaders 区域构造与对齐条件不满足，而不是驱动层数值误差。

## What Went Wrong
- 初期过早把问题归因为 ulem 通用的“kern-back overlay 浮点累积误差”，围绕 `\rlap` 叠加、PDF stream 坐标抽取、showbox 对比做了很多验证，但这一假设本身方向就错了。
- 一开始更关注“为什么下划线画出来后位置不连贯”，却没有先对照标准 `\UL@leaders` 与 `\xeCJK_ulem_var_leaders:` 的边界构造差异，导致忽略了首次变体少了左侧 `-\UL@pixel` 这一关键事实。
- 早期实验里把 `\rlap` 叠加结果当成对 overlay 路径的直接证明，但 `\CJKunderline` 在 hbox 内的行为与当时假设并不等价，造成了错误的“这是 ulem 普遍问题”的结论。

## Root Cause
- 根因不是 xdvipdfmx 的浮点累计误差，而是 `\leaders` 的标准对齐语义与 xeCJK subtract 模式的边界裁剪共同造成的边界漏覆盖。
- `\CJKunderline-` 走 subtract 模式时，`\xeCJK_ulem_var_leaders:` 首次变体原先没有像标准 `\UL@leaders` 那样先执行左侧 `\skip_horizontal:n { - \UL@pixel }`，因此 leaders 区域左边界被收窄。
- 与此同时，上一组收尾的 `\@@_ulem_right_skip:` 会对末字右侧做一个 `\UL@pixel` 的修剪。到了两组拼接接缝处，新组首个 leader box 的理论起点恰好落在 leaders 区域起始位置左侧一个极小量之外，不满足“完整嵌入 leaders 区域”的条件。
- 对标准 `\leaders` 而言，box 会对齐到外层 hbox 左边缘的整数倍位置，若首个 box 不能完整落入区域，就会直接跳到下一个对齐点，于是产生一个 box 宽度的空隙。当前回归中该 box 宽度约为 `1.99997pt`，正对应用户观察到的接缝 gap。
- `\CJKunderline`（不带 `-`）没有同类问题，是因为标准 `\UL@leaders` 具备双侧 pixel 溢出，边界盒始终能被覆盖。

## Missing Docs or Signals
- memory only:
  - 这次最值得记住的误判链路是：先怀疑 overlay / 驱动浮点误差，再经 PDF 坐标排除驱动，最后才回到 `\leaders` 对齐语义本身。此类“看起来像坐标误差，实则是 TeX 盒对齐条件”的案例适合保留在 memory 中。
  - `\rlap` 叠加测试在下划线路径上并不总能代表真实 leaders 行为，尤其当命令内部还会插入 glue、leaders 与边界修剪时，不能把 overlay 视觉结果直接当根因证据。
- promotion candidates:
  - 可考虑在 `guides/` 或 `reference/` 增补一条 xeCJK/ulem 排障准则：凡是涉及 `\leaders`、pixel 溢出和边界修剪的下划线问题，先检查 leaders 区域是否覆盖边界盒，再讨论驱动层坐标误差。
  - 可考虑在 `reference/` 中明确记录：标准 `\leaders` 会把 leader box 对齐到外层盒左边缘的整数倍位置，且只显示完整嵌入指定区域的 box；这对分析边界漏线和“少一个 box 宽度”的 gap 很关键。
  - 可考虑在 `build-and-test` 或相关指南里补充一种诊断方法：通过解压 PDF content stream 提取线段坐标，可直接确认 gap 是来自 TeX 侧节点布局还是驱动输出误差。

## Promotion Candidates
- `memory`:
  - 保留本次“从浮点误差假设转向 leaders 对齐语义”的纠偏过程，以及 `\rlap` 叠加测试误导调查方向的具体教训。
- `guides/`:
  - 增加 xeCJKfntef / ulem 下划线边界问题的排障清单，优先对比标准 `\UL@leaders` 与定制 leaders 变体的左右 pixel 扩展是否对称。
  - 增加一条诊断建议：当 showbox 只能看到 glue/leaders 结构而难以解释肉眼 gap 时，直接抽取 PDF 线段坐标验证实际缺口位置。
- `reference/`:
  - 记录 `\leaders` 的对齐与“完整嵌入”语义，说明边界少一个 `\UL@pixel` 就可能导致整个首个 leader box 被跳过。

## Follow-up
- 后续若再修改 xeCJKfntef / ulem 的 leaders 逻辑，优先逐项核对：
  - 首次 leaders 变体是否与标准 `\UL@leaders` 保持同样的双侧 pixel 扩展；
  - 收尾修剪宏是否会与下一段的 leaders 起始区域发生叠加效应；
  - 拼接多组与单组长串的盒宽和线段覆盖是否一致。
- 若后续整理稳定文档，优先把“先验证 leaders 区域覆盖边界盒，再怀疑驱动误差”提升为 xeCJK 下划线类问题的通用诊断规则。