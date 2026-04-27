# Issue #407 char/interchar 绕过修复反思

## Task
- 记录 xeCJK Issue #407 的修复反思：`mtpro2` 的 `\overcbrace` 在 XeTeX 下被 xeCJK 的 interchar 机制误拦截，输出成中文间隔号。

## Expected vs Actual
- Expected outcome.
  - `\char` 作为底层原语，应始终从当前字体直接取字形；`mtpro2` 在 `\hbox` 中通过 `\char"00B7` 访问 `mt2exe` 字体 183 号位时，不应被 xeCJK 改写字体。
- Actual outcome.
  - `U+00B7` 被 xeCJK 归入 `FullRight` interchar 类后，只要 `\XeTeXinterchartokenstate = 1`，`\char"00B7` 也会触发 interchartoks，导致进入 CJK 字体切换路径，最终把原本的数学花括号字形变成中文间隔号。

## What Went Wrong
- 最初没有先明确区分“直接字符输入”和“`\char` 原语输出”两条路径，容易把两者都当成同一种 interchar 触发问题来设计测试。
- 第一版测试把数学模式中的 `\char` 与直接输入字符 `·` 并列比较，隐含假设两者在 math 模式下会走相同机制；这个假设不成立。
- 调查早期如果没有充分利用 issue 讨论，很容易重复维护者已经完成的分析与补丁设计。

## Root Cause
- 对 XeTeX interchar 机制的认识不够细：`\XeTeXinterchartokenstate` 对文本与数学都生效，但数学模式里的“直接字符输入”通常走 mathcode / 数学族选择路径，而 `\char` 仍然是“从当前字体直接取字形”的底层原语。
- xeCJK 的字符分类表把 U+00B7 当作中文边界控制对象处理，这对普通文本输入成立，但不应外推到 `\char` 这种明确要求绕过 NFSS、高层字符语义和自动边界处理的低层接口。
- 测试设计时没有先回到真实触发场景：`mtpro2` 的问题出现在数学中的 `\hbox`，而不是裸数学原子输入。

## Missing Docs or Signals
- memory only:
  - 需要在反思中明确记住：排查 xeCJK interchar 问题时，先区分“直接 Unicode 字符输入”“数学字符输入”“`\char` 原语输出”“盒子内文本字体输出”这几条路径，避免测试对象选错。
  - 需要记住 issue 评论往往已经包含维护者对 TeX 原语语义的定性判断，尤其是兼容性补丁类问题，应优先吸收再验证。
- promotion candidates:
  - 可考虑在 `llmdoc/guides/` 或 `llmdoc/reference/` 增补一条 xeCJK interchar 调试准则：`\char` 属于底层取字形原语，兼容补丁原则上不应拦截；若某补丁会影响 `\char`，必须单独论证。
  - 可考虑在 `llmdoc/reference/build-and-test.md` 或 xeCJK 相关指南中补充测试经验：数学模式中的直接字符与 `\hbox{\char...}` 不等价，涉及字体切换问题时应尽量复现真实盒子上下文。

## Promotion Candidates
- `guides/`:
  - 增加“xeCJK interchar/字体切换问题排查”指南，明确先判断输入路径，再决定看字符分类、mathcode、或兼容 hook。
- `reference/`:
  - 增加一条事实性说明：`\XeTeXinterchartokenstate` 虽然在数学模式也开启，但直接数学字符与 `\char` 的字体来源和边界副作用不同。
- `must/`:
  - 若后续再次出现类似误测，可把“回归测试必须贴近真实触发场景，不得用语义不同的最小例子替代”提升为稳定要求。

## Follow-up
- 将本次经验沉淀为一条可复用检查清单：遇到 xeCJK 字体误切换问题时，先确认触发对象是否为 `\char` 原语；若是，优先检查是否应在输出该字符前临时关闭 `\XeTeXinterchartokenstate`，并用真实场景对应的盒子结构编写回归测试。
