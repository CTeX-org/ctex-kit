# Issue #378 lstinline hash doubling 反思

## Task
- 记录 xeCJK Issue #378 的修复反思：当 `\lstinline` 出现在宏参数中时，参数传递中的 catcode 6 `#` 经 xeCJK 对 listings 的 rescan 补丁后被双写，最终输出成 `##`。

## Expected vs Actual
- Expected outcome.
  - `\passthrough{\lstinline!#!}` 一类输入应与普通 `\lstinline!#!` 一致，只输出单个 `#`，并保持 listings 原有的字符输出路径与盒子结构。
- Actual outcome.
  - xeCJK 对 `\lst@InsideConvert@` 的补丁使用 `\tl_set_rescan:Nno`（底层依赖 `\scantokens`）重扫 token 列表；当 `\lstinline` 位于宏参数中时，参数传递产生的 catcode 6 `#` 在 `\scantokens` 的写伪文件步骤中再次被双写，导致最终输出为 `##`。

## What Went Wrong
- 初始修复思路一度把问题简化为“把 catcode 6 `#` 变成普通字符即可”，先尝试替换成 catcode 12 `#`。这能让 trace 表面看起来接近预期，但没有经过 listings 的正常字符输出机制，最终盒子结构错误、位置错乱。
- 一度尝试用 `\str_replace_all:Nnn { ## } { # }` 处理双写后的 `#`，忽略了 expl3 参数层会先把 `##` 解析成单个参数记号，结果实际上构造不出“只匹配 catcode 6 `#`”的替换条件，代码等价于无操作。
- 排查早期如果只看文本提取结果，容易误判 catcode 12 方案已经足够接近；实际版面结构问题直到 `\showbox` 对比后才被确认。
- 过程中再次印证：用户已明确要求先复现问题，若直接静态读代码而不先编译最小例子，会延迟确认真实触发条件。

## Root Cause
- 对 `\scantokens` / `\tl_set_rescan:Nno` 的语义约束认识不够细：它不是 listings 原生那种逐字符映射，而是先字符串化再重新 token 化；只要输入里含有参数传递保留下来的 catcode 6 `#`，就会在写入阶段按 TeX 规则翻倍。
- 对 listings 原生实现的关键不变量认识不足。`\lst@MakeActive@` 使用 `\lccode` + `\lowercase` 逐字符转换，本质上一次只映射一个 token，不经过 stringification→retokenization，因此不会引入 `#` 翻倍问题；修复必须尽量回到与这条路径兼容的 token 形态。
- 对“能显示出字符”和“能走对输出流水线”这两件事区分不够。对 listings 而言，替换目标不仅要避免双写，还必须让字符继续通过 `\lsthk@OutputBox` 等正常输出机制；因此 catcode 12 不是正确目标，必须转成 active `#`（catcode 13）。

## Missing Docs or Signals
- memory only:
  - 处理 `\tl_set_rescan` / `\scantokens` 相关问题时，要先检查输入 token 中是否含 catcode 敏感字符，尤其是 `#`、`%`、参数记号等；凡是“宏参数里正常、重扫后异常”的现象，都要优先怀疑 stringification→retokenization 副作用。
  - 排查 TeX 输出异常时，pdftotext 只能作为辅助手段；若怀疑字符脱离正常盒子流或输出顺序异常，应尽快用 `\showbox` 看真实盒子结构。
  - l3build 场景中，像 `\lstinline` 这样受参数传递限制的命令，不要直接塞进 `\TEST{}{body}` 一类测试宏参数里；应先在 `\OMIT`/`\TIMO` 或外部 `\setbox` 构造输入，再在断言宏中只比较盒子宽度或已捕获结果。
- promotion candidates:
  - 可在 architecture 文档补一条 xeCJK listings 补丁说明：当前 `\@@_listings_rescan:Nn` 依赖 rescan，而 listings 原生 `\lst@MakeActive@` 依赖 `\lccode` + `\lowercase` 单字符转换，两者在 catcode 敏感字符上的语义差异需要明确记录。
  - 可在 reference/coding-conventions 或相关指南中增加一条 expl3/TeX token 处理经验：涉及 catcode 精确匹配时，`\regex_replace_all` 的 catcode class（如 `\cP`、`\cA`）比普通字符串替换更可靠。
  - 可在 build/test 参考中补充一条测试规则：对 `\verb`、`\lstinline` 等特殊读取型命令，测试输入构造与断言逻辑应分离，优先用盒子宽度或 `\showbox` 验证，而不是直接把命令塞进测试辅助宏参数。

## Promotion Candidates
- `architecture/`:
  - 记录 xeCJK 对 listings 的兼容补丁为何使用 rescan，以及它与 listings 原生 `\lowercase` 单字符映射机制在 catcode 敏感字符上的差异与边界。
- `reference/`:
  - 增加 expl3 token/catcode 操作备忘：`\regex_replace_all` 的 catcode class 匹配适合区分 catcode 6 `#`、active 字符等，普通 `str` 级替换不适合这类问题。
- `guides/`:
  - 增加一条“xeCJK/listings 类问题调试”流程：先复现，再 trace / `\showbox`，最后再决定是字符类别、rescan 还是输出 hook 出错。

## Follow-up
- 后续若再遇到由 `\scantokens`、rescan 或 active 字符引发的 xeCJK/listings 问题，先做三步检查：一是最小例子复现并确认是否与宏参数传递相关；二是确认候选替换 token 是否还能进入原包的正常输出流水线；三是用盒子结构或宽度比较写回归测试，避免只凭日志或文本提取判断修复是否正确。
