# Issue #800 char let xint 兼容修复反思

## Task
- 记录 xeCJK Issue #800 的修复反思：xeCJK 为修复 #407 在包加载时重定义 `\char`，导致随后加载的 xint 在 `\let\xint:\char` 时保存到宏而不是 TeX 原语，进而破坏 xint 的内部字符数据编码。

## Expected vs Actual
- Expected outcome.
  - xeCJK 需要继续保留 #407 的效果：文档正文中的 `\char` 输出应绕过 xeCJK 的 interchar 干预路径，避免再次把底层取字形操作误送入 CJK 边界处理。
  - 同时，xeCJK 不应在导言区破坏其他包对 `\char` 原语的加载期假设，特别是不应影响会在包加载时 `\let` 保存该原语的第三方库。
- Actual outcome.
  - xeCJK v3.10.0 在加载时执行 `\cs_set_eq:NN \char \xeCJK_default_char:w`，把 `\char` 立即替换成了受保护宏。
  - xint 通过 `xintkernel.sty` 的 `\let\xint:\char` 保存到了这个宏副本；后续 `xinttrig.sty` 中 fully-expandable 解析链在内部把 `\xint:` 当作字符编码原语使用时失效，最终报出 `! Argument of \XINT_mul_pre_b has an extra }.` 之类与真实根因距离较远的展开错误。

## What Went Wrong
- 起初把问题误判成 xeCJK 自己的分组 token 实现细节，先尝试把 `\c_group_begin_token` / `\c_group_end_token` 改成 `\begingroup` / `\endgroup`，但这并没有触及真正的不变量。
- 初次本地复现失败，因为环境中系统安装的是 xeCJK v3.9.1，未优先使用 `build/unpacked/` 中的当前构建产物验证 unreleased 改动，导致一开始对“问题是否真实存在”判断不稳定。
- 调查早期过于关注“protected 宏是否会妨碍展开”，差点把问题缩小成 `\protected` 属性；实际上即便换成普通宏，只要 `\char` 不再是原语，xint 这种依赖 `\let` 保存原语语义的包仍会损坏。
- 错误栈从 `xinttrig.sty` 的 `\xintdefvar` 处爆出，容易让人继续深挖 xint 算术实现；但真正值得优先确认的是 xint 在加载期保存了哪个 token，以及该 token是不是原语。

## Root Cause
- 根因不是 xint 的表达式求值本身，而是 xeCJK 在包加载阶段改变了全局 `\char` 的语义身份：从“引擎级原语”变成了“宏包装层”。
- 对依赖 `\let` 保存原语的包来说，时间点决定了一切。若它们在导言区看到的是原语，后续内部逻辑仍可正常工作；若在加载期看到的是宏，就会把宏语义永久冻结进自己的内部接口。
- `\let` 复制原语与复制宏并不等价。原语拥有引擎级行为与可展开/不可展开边界特征，宏包装即使最终调用 `\tex_char:D`，也不能替代“被 `\let` 时就是原语”这一事实。
- #407 的需求实际上只针对文档正文中的字形输出路径，不要求在第三方包仍在导言区建立内部原语副本时就提前修改 `\char`。因此，原先的立即重定义属于时机过早。

## Missing Docs or Signals
- memory only:
  - 以后凡是修改 TeX 原语（如 `\char`、`\par`、`\shipout` 一类）时，要先单独检查“是否有包会在加载期 `\let` 保存它”，并把“加载期可见身份”和“正文期可见身份”分开思考。
  - 调试涉及 unreleased 回归时，应优先用 `build/unpacked/` 或等价构建产物复现，而不是默认相信系统安装版本能代表当前源码状态。
  - 看到 xint 这类 fully-expandable 包报出远离根因的展开错误时，先检查其加载期保存的 primitive aliases，而不是直接从报错位置向下钻解析器细节。
- promotion candidates:
  - 可在 `llmdoc/guides/` 增补一条 xeCJK/ctex 兼容补丁设计准则：若补丁需要改写 TeX 原语，先评估是否应延迟到 `\AtBeginDocument` 或更晚阶段，以避免破坏其他包在导言区保存原语的假设。
  - 可在 `llmdoc/reference/` 增补一条事实性说明：对第三方包兼容而言，“原语被宏包装后再 `\let` 保存”与“直接 `\let` 原语”不是等价状态，尤其对 fully-expandable/编码类包需要格外谨慎。
  - 可考虑在 xeCJK 相关调试指南中加入“报错位置位于下游 expandable parser，不代表根因在下游；优先核对上游是否改写了其依赖的 primitives”。

## Promotion Candidates
- `guides/`:
  - 增加“原语重定义的时机选择”指南，要求在兼容补丁中先区分导言区依赖与正文依赖，再决定是否延迟到 `\AtBeginDocument`。
  - 增加“下游 expandable 包异常的上游排查顺序”指南，把 primitive alias 污染列为首批检查项。
- `reference/`:
  - 补充一条原语兼容事实：宏即使语义上包装同一底层操作，也不能替代“被 `\let` 保存时仍是原语”这一契约。
- `must/`:
  - 若后续再次出现类似问题，可提升为稳定要求：任何会改写 TeX 原语身份的补丁，在提交前必须至少评估一个“第三方包加载期 `\let` 保存原语”的兼容场景。

## Follow-up
- 最终修复路线比“延迟到 `\AtBeginDocument`”又后退了一步，形成了更稳妥的检查清单：遇到需要为 #407 一类问题绕过 interchar 时，先验证三个问题——是否真的需要改写全局 `\char`、是否存在下游包会在导言区或正文中 `\let` / 比较其 primitive 身份、以及能否改用显式新命令 + 定点补丁 + 文档化手动 patch 达成目标。
- 本次最终决策是彻底撤回对 `\char` 的重定义，包括 `\AtBeginDocument` 延迟重定义方案；改为新增 `\xeCJKchar` 供显式绕过 interchar 使用，并对 `mtpro2` 的 `\overcbrace` / `\undercbrace` 做自动补丁。xint 暴露的问题因此被重新表述为更强的不变量：不仅“加载期 `\let` 保存 primitive 的包不能看到宏包装层”，而且 `\char` 的 primitive 身份本身不应再被 xeCJK 全局改写。
- 后续若再出现下游 expandable 包报错，应先检查上游是否改变了其依赖 primitive 的身份；若答案是“需要为兼容性去改 primitive”，默认优先寻找更局部的替代接口，而不是把延迟重定义当成终点方案。
