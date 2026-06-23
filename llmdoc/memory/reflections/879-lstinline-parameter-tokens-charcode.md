---
name: 879-lstinline-parameter-tokens-charcode
description: 反思 #879 `\lstinline` 中 catcode 6 token 字符码丢失的修复——#378 catcode-class regex 方案的隐含"替换端硬编码 codepoint"局限在 `\catcode\`\&=6` 场景被显式触发，改用 token 级 `\tl_map_inline:Nn` + `\token_if_parameter:NTF` + `\char_generate:nn` 保留原字符码
metadata:
  type: feedback
---

# [Task Reflection]

## Task

修复 xeCJK Issue #879：`\lstinline` 中若用户通过 `\catcode\`\&=6` 将其它字符
改为 parameter token，原 `\@@_listings_rescan:Nn` 会把它的字符码丢失为
U+0023（`#`），导致输出错字。

实施位置在 `xeCJK/xeCJK.dtx` L11856-11878 `\@@_listings_rescan:Nn`，方案由
muzimuzhi 在 #799 评论中给出。两个 commit：

- `4875e4dc` fix(xeCJK): `\lstinline` 中保留 catcode 6 token 的原字符码 (#879)
- `e5aa9937` docs(xeCJK): `\@@_drain_ecglue:` false 分支补一行清空意图注释

回归测试：`xeCJK/testfiles/listings-hash01.lvt` 新增 Test 6（`\catcode\`\&=6`
场景）。

## Expected vs Actual

- 预期：`\@@_listings_rescan:Nn` 应对任意被设为 catcode 6 的字符都保留原
  字符码，rescan 后输出为相同字面字符。
- 实际（修复前）：rescan 用
  `\regex_replace_all:nnN { \cP . } { \cA \x{23} } \l_@@_tmp_tl`，
  匹配端正确识别 catcode 6 token，但**替换端硬编码 U+0023**，所有
  parameter token 一律变成 active `#`。`\catcode\`\&=6` 后 `&` 在输出中变成 `#`。

## What Went Wrong

- #378 修复时确立了"catcode-class regex（`\cP`、`\cA`）比 str/tl 字符串替换更
  精确"这条经验，并已回填到 `reference/coding-conventions.md`。该经验仅覆盖
  **匹配端**的精确性，没记录**替换端**的语义局限：
  `\regex_replace_all:nnN { ... } { \cA \x{NN} } ...` 中 `\x{NN}` 是字面 codepoint，
  整个机制把"所有匹配项"映射到"单一目标字符"，天然丢失输入侧的字符身份。
- 在 `\lstinline` 这一具体场景下，#378 当时的输入空间是 `#`（catcode 6 默认仅
  `#`），匹配集与替换目标天然同一字符，局限无法显式暴露。
- 一直到 #879 用户报告"`\catcode\`\&=6` 后 `&` 被改成 `#`"，才显式触发该局限。
  本来如果 #378 反思在 promotion 时把这层"前提：输入侧只可能是 `#`"的边界条件
  也一起写下来，#879 是可以提前一步识别的。

## Root Cause

- **直接根因（代码）**：`\regex_replace_all:nnN` 的替换串里 `\x{23}` 是字面
  codepoint，与匹配端 `\cP .` 捕获到的原字符码完全脱钩。token 流要保持
  字符身份必须依赖 token 级 API，不是 regex 字符类。
- **思维定式（人）**：#378 的方案在当时输入空间下是正确的，但 promotion 阶段
  把"catcode-class regex 优于 str 替换"作为通用经验时，**只描述了好处，没描述
  适用边界**。这是反思上推稳定文档时常见的过度泛化。

正确的 token 级写法：

```latex
\tl_map_inline:Nn \l_@@_tmp_tl
  {
    \token_if_parameter:NTF ##1
      {
        \tl_put_right:Ne \l_@@_tmpb_tl
          {
            \exp_after:wN \exp_after:wN \exp_after:wN \exp_not:N
            \char_generate:nn { \int_value:w `##1 } { 13 }
          }
      }
      { \tl_put_right:Nn \l_@@_tmpb_tl { ##1 } }
  }
```

其中 `` \int_value:w `##1 `` 取出 parameter token 的原字符码，
`\char_generate:nn { ... } { 13 }` 以该 codepoint 生成 active token，
逐 token 重建 `\l_@@_tmpb_tl` 后再交给 `\tl_set_rescan:Nno`。所用接口
（`\tl_map_inline:Nn` / `\token_if_parameter:NTF` / `\char_generate:nn` /
`\int_value:w \``）均为 expl3 稳定接口，是"token 级 catcode 转换且需保留
原字符码"场景的标准写法。

investigator 已确认 `xeCJK.dtx` L11849-11878 是仓内**唯一**"匹配 catcode class
但硬编码 codepoint"位点；`ctex/ctex.dtx` L11331 的 regex 不同型（不涉及
catcode/codepoint 桥接）。

## Missing Docs or Signals

- `reference/coding-conventions.md` 现有"expl3 正则里的 catcode class 记法"
  条目只描述 catcode-class regex 在匹配端的优势，**没写何时不适用**：当替换端
  需要保留输入侧字符码身份时，`\regex_replace_all:nnN` 的替换串是字面
  codepoint，整个机制等价于"任意 catcode N → 固定 codepoint K"，会丢失字符
  身份。此时应改走 token 级路径。
- `architecture/xecjk-architecture.md` xeCJK-listings 段（约 L347-349）目前
  只一句"用 `\tl_set_rescan:Nno` 替代 `\lccode`/`\lowercase`"，没记录
  parameter token 处理路径。从 #378 catcode-class regex 到 #879 token 级 map
  的演化值得作为该段的微小补充。
- `reference/build-and-test.md` listings-hash01 描述（L155）已经提到
  "`\lstinline` 在宏参数中的 `#` catcode 保持"，但没单列 Test 6 覆盖的
  `\catcode\`\&=6` 场景；新增一句即可。
- `memory/reflections/378-lstinline-hash-doubling.md` 的 Follow-up 没有
  显式标注"该方案在替换端硬编码 codepoint 这一前提下成立"。#879 之后应在
  原反思尾部加一行回链，把这条边界条件显式化。

## Promotion Candidates

适合提升到 **`reference/coding-conventions.md`**（由 recorder 落地）：

- 在现有"expl3 正则里的 catcode class 记法"条目下增补一段**反例**：
  > **何时不要用**：当替换端需要保留输入侧 token 的字符码身份时，
  > `\regex_replace_all:nnN { \cP . } { \cA \x{23} }` 这类写法会把所有匹配
  > 项映射到字面 `\x{NN}` codepoint，丢失原字符码。此时应改用
  > `\tl_map_inline:Nn` + `\token_if_parameter:NTF` + `\char_generate:nn { \int_value:w ``##1 } { 13 }`
  > 逐 token 重建。`\@@_listings_rescan:Nn` 的 #378→#879 演化是典型案例。

适合提升到 **`architecture/xecjk-architecture.md`** xeCJK-listings 段
（约 L347-349，由 recorder 落地）：

- 补一句记录 parameter token 处理路径：
  > `\@@_listings_rescan:Nn` 在 rescan 前先用 `\tl_map_inline:Nn` 逐 token
  > 扫描，将 catcode 6 parameter token 通过 `\char_generate:nn { \int_value:w ``##1 } { 13 }`
  > 转换为同字符码的 active token，避免 `\scantokens` 字符串化阶段对
  > catcode 6 token 的二次双写，同时保留用户通过 `\catcode\`\&=6` 等方式
  > 自定义的 parameter token 字符身份（#378 → #879）。

适合在 **`memory/reflections/378-lstinline-hash-doubling.md`** Follow-up
段尾追加一行回链（由 recorder 落地）：

- 该反思 Follow-up 加一句：
  > **2026-06 更新**：#879 暴露了 #378 catcode-class regex 方案的隐含前提
  > "替换端硬编码 codepoint"——当用户用 `\catcode` 把其它字符改为 catcode 6
  > 时该前提被打破，已改为 token 级 map 保留原字符码；详见
  > [[879-lstinline-parameter-tokens-charcode]]。

适合提升到 **`reference/build-and-test.md`** listings-hash01 描述附近
（由 recorder 落地）：

- 在 L155 现有描述后补一句：
  > 其中 Test 6 覆盖用户通过 `\catcode\`\&=6` 把其它字符设为 parameter token
  > 的场景，验证 `\@@_listings_rescan:Nn` 保留原字符码（#879）。

仅保留在本反思（不上推）：

- e5aa9937 的 `\@@_drain_ecglue:` 注释补充本质是顺手补 #880 的 drain 实现意图，
  与 #879 主修复无关，归到 reflection 范畴。
- "promotion 时要把适用边界一起写下来"这条人因教训本身——值得记住，但属于
  反思范畴。

## Follow-up

- 等用户确认后，由 recorder 把上述四处 promotion 落到稳定文档
  （`reference/coding-conventions.md` / `architecture/xecjk-architecture.md` /
  `reference/build-and-test.md` / `378-lstinline-hash-doubling.md` Follow-up）。
- 下次再写 promotion 时显式问一遍："这条经验是否依赖某个未写下的输入空间
  前提？如果输入空间扩大，结论是否仍成立？"——这是 #378→#879 这一类
  "方案正确但边界条件丢失"的预防 checklist。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` `\@@_listings_rescan:Nn` 段（L11856-11878），
  commit `4875e4dc`。
- 注释补充：`\@@_drain_ecglue:` false 分支清空意图，commit `e5aa9937`。
- 回归测试：`xeCJK/testfiles/listings-hash01.lvt` Test 6。
- 上游方案：muzimuzhi 在 PR #799 评论中给出的 token 级写法。
- 前一篇直接相关反思：[[378-lstinline-hash-doubling]]。
