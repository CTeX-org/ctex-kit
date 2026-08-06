---
issue: 997
pr: fix/997-xpinyin-autofallback
head: 1aa872b1
date: 2026-08-04
---

# 反思：#997 AutoFallBack 下的注音量宽盒子

## Task

xpinyin 与 xeCJK 的 `AutoFallBack` 同时使用时注音出错。报告者给了两个 MWE、两张截图，以及终端里两条 `Missing character: There is no 中 (U+4E2D) in font [lmroman10-regular.otf]`。issue 里已有一条 2026-07-21 的 bot 根因分析评论，给出完整调用链和两个修复方向。

本轮工作：逐环实测确认根因，改 `\@@_CJKsymbol_hook:`，新增 `xpinyin/testfiles/pinyin-fallback01.lvt`（3 项）。

## Expected vs Actual

- 预期（从 issue 标题、`Missing character` 警告和截图得到的第一印象）：汉字排不出来，是渲染缺陷。
- 实际：**PDF 里汉字完全正常**。它由量宽盒子之外的 `\@@_save_CJKsymbol:n` 输出，那时后备字体仍然有效。那两条 `Missing character` 来自 `\l_@@_tmpa_box`——一个只用来取宽度、从不放进页面的临时盒子。可见的缺陷是拼音被压缩重叠。

`pdftotext -bbox` 实测：缺陷版 `zhōng` 占 178.05→180.84（2.79pt），修复版 178.05→188.02（9.96pt），与汉字「中」的 178.05→188.01（9.96pt）对齐。

根因与 bot 评论所述一致：`\@@_CJKsymbol_hook:` → `\xeCJK_select_font:` → `\@@_select_font:Nn`，后者第一句 `\xeCJK_clear_fallback_font:` 把后备字体状态清掉；量宽盒子于是在主字体下排版、字形缺失、宽度只剩 2.8pt（正确值 10.0pt），拼音随后被 `\box_resize_to_wd_and_ht:Nnn` 压缩到这个错误宽度。

## What Went Wrong

本轮没有走大的弯路：根因判断一次到位，修复方案没有推翻重做，测试没有出现假绿。值得记的是三处判断上的坑，前两处是当场踩到并当场纠正的，第三处是被上游接口限制挡了一次。

### 1. 表象与实质不一致，差点按「渲染缺陷」立题

警告、截图和 issue 标题三者互相印证，都指向「缺字」。但这三样证据全部产生在同一个**被丢弃的中间产物**上。若按这个方向去查字体查找链或 `\XeTeXglyphbounds`，会离根因越来越远。

真正把方向纠正过来的是最终产物的几何量：PDF bbox 显示汉字宽度正确、拼音宽度是汉字的 28%。

### 2. 整体宽度对这个缺陷零判别力

第一版测试想用 `\hbox{\xpinyin*{中}}` 的宽度做判据。实测缺陷版与修复版**同为 10.0pt**——拼音在 `\hbox_overlap_right:n` 零宽盒子里，不占外部宽度，任何基于外部宽度的断言都恒真。必须用 `\loggingoutput` 看节点列表里量宽盒子自身的 `x2.8` / `x10.0`。

这与 `pinyin-scope01.lvt` 已记的「换读音或整段关掉注音，宽度都不变」是同一条结构性事实（拼音不占位）的另一面。

### 3. `\setCJKmainfont` 是 `\@onlypreamble`

写第 3 项对照时想在正文里 `\begingroup \setCJKmainfont{...} \endgroup`，得到 `LaTeX Error: Can be used only in preamble.`（依据 `xeCJK.dtx` 的 `\@onlypreamble \setCJKmainfont`）。改用导言区 `\newCJKfontfamily` 另立一族、正文里切过去。

## Root Cause

### 缺陷本身的成因

`\xeCJK_reset_fallback_font:` 是 xeCJK 表达「当前是否处于后备字体状态」的唯一状态量。xpinyin 的量宽 hook 无条件重选主 CJK 字体，而重选路径的第一件事就是清掉这个状态。两个包各自的逻辑都自洽：xeCJK 认为「重选字体意味着放弃后备」，xpinyin 认为「量宽必须切到 CJK 字体」，冲突只在两者叠加时出现。

### 为什么诊断信息会误导

TeX 的 `Missing character` 绑定的是**当时正在构造的那个盒子**，而那个盒子可能是随后被丢弃、或只取尺寸的中间产物。警告出现的位置只说明「某处用了缺字形的字体」，不说明可见输出坏在哪。

### ~~修复不能是「删掉那次重选」~~（**本小节已撤回，结论是错的**）

> **撤回说明**：以下两段是本反思初版的内容，结论与依据均已被独立审查推翻，保留原文仅为记录当时的判断。更正后的事实见紧随其后的「探针取错了量」一节。

~~第一直觉是「hook 不该重选字体，删掉就好」。实测证否：`Latin \xpinyin*{中}` 进入量宽盒子时当前字体是 `\TU/lmr/m/n/10`（西文），不重选会量出西文字体下的宽度。那次重选在无后备字体的常规路径上是**必需**的——它的作用是把量宽盒子切到 CJK 字体。~~

实际采用的修复仍是加一个条件：`\@@_CJKsymbol_hook:` 改调新增的 `\@@_reselect_CJK_font:`，判据是 `\xeCJK_reset_fallback_font:` 是否等于 `\prg_do_nothing:`；已在后备字体状态就跳过重选，否则保持原有重选。但保留「否则重选」这一支的理由是**保守**，不是上面那段所说的「必需」。

### 探针取错了量，由此推出的「不能删」与「双向变异」两个结论都不成立

**本节初版的内容是错的，独立审查在变异复跑中推翻了它，这里保留更正后的事实与出错原因。**

初版声称：「加一个条件」有两种失败方式（条件失效、条件写反），第 3 项专门覆盖后者，读数分别是 `x2.8` 与 `x0.0`。实测三点都不成立：

| 变异 | 实测结果 |
|---|---|
| 回退成无条件重选（原缺陷） | 16 处 `x2.8`，带 `Missing character`，变红 |
| 把 T／F 分支互换 | 产物与「无条件重选」**逐字节相同**，不是独立形态 |
| 重选整个删掉（函数体置空，或 hook 里不调用） | **5/5 全绿，产物与基线逐字节相同** |

初版写的「删掉后出现 16 处 `x2.8`」实际是**回退成无条件重选**的读数，两个变异的日志记混了。文档里的 `x0.0` 从来没有被复现过。

出错的根源是**探针读了 NFSS 状态而不是实际字体**。我在 hook 入口打印到 `\TU/lmr/m/n/10`，据此认为「当前字体是西文，不重选会量错」。但那是 `\f@family` 等 NFSS 参数；决定字符实际用什么字体排版、进而决定量出宽度的是 `\fontname\font`。同一位置读后者，得到的已经是 CJK 字体——xeCJK 的 interchar 进入 CJK 类时就切好了，hook 运行在那之后。在十余种上下文（紧跟西文／标点／`\emph`／数学／`\textsf`／字号变化／`\mbox`／`\sbox`／`\hbox`／`\vbox`／`tabular`／`minipage`／`\section`／`pinyinscope`／嵌套注音／脚注／切换 CJK 族）逐一探测，`\fontname\font` 无一例外已是 CJK 字体。

连带的实质影响：**「删掉重选」是一个同样正确、且更简单的修复**——在删掉重选的版本上跑 #997 原始 MWE，`Missing character` 为 0、`zhōng` 跨度 9.96pt 与汉字对齐。仍保留条件式实现，但理由从「它是必需的」降级为「保守」：NFSS 参数此时确实还停在西文族，若 xeCJK 改变切换时点，重选会重新变得必要，而保留它在当前行为下无可观察代价。

真正该记的教训因此是两条，而不是初版那条「条件式修复要双向变异」：

1. **回答「当前用什么字体排版」必须读 `\fontname\font`，不能读 `\f@family` 一类 NFSS 参数**。两者在 CJK 场景下会系统性地不一致。
2. **「某个变异能让测试变红」不等于「这一组用例覆盖了该变异对应的失败形态」**。条件取反之所以变红，是第 1、2 项回到原缺陷所致，与「第 3 项守住了另一个方向」无关。判断某一项有没有判别力，要单独让**那一项**所声称的失败形态发生，而不是看整份文件红不红。这一点与 `pinyin-scope01.lvt` 里已记的「整文件变红不足以判定单项判别力」是同一条，本轮又踩了一次。

3. **纠正一个过强的否定断言时，容易顺势把话说得太满**。上一条查明第 3 项不覆盖「整支重选被跳过」之后，我在四份文档里写成「第 3 项没有变异判别力」「没有任何用例能拦住」。增量审查再做一个我没想到的变异——保持条件结构、只让重选切到**错误的 CJK 族**——证明只有第 3 项会变红，它是这一形态的唯一防线。教训是：否定性断言要限定到实际验证过的那个形态（这里是「整支被跳过」），不要外推成「该项没有判别力」；穷尽性断言出错两次的位置往往是同一处（参见 lessons-learned 里「否定性结论要说明搜索了什么模式与为何能穷尽」）。

## Missing Docs or Signals

- `llmdoc/architecture/xecjk-architecture.md` 的「后备字体 (Fallback)」一节只有三句话，只记 `\setCJKfallbackfamilyfont` 与 `\xeCJK_fallback_symbol:NN`，没有记录「`\xeCJK_reset_fallback_font:` 是状态量」「`\xeCJK_select_font:` 会清掉它」这条对下游可见的陷阱。查这个机制全靠读 `xeCJK.dtx`。
- `llmdoc/reference/build-and-test.md` 的 xpinyin 一节记了「注音宽度看不出拼音内容」，但没记它的推论：以外部宽度为判据的断言在这类缺陷上恒真。写第一版测试时我是重新踩了一遍才想起来。
- `lessons-learned.md` 里没有「诊断信息可能来自被丢弃的盒子」这一型条目。逐条核对过 109-112（三类证据）、284-287（探针自证）、434-437（测试全绿）、444-447（四个独立命题）、224-227（为什么不受影响），最接近的是 444-447，但它讲的是「不要为观察到的现象编成因」，没有覆盖「观察点本身位于被丢弃的中间产物上」。
- `lessons-learned.md` 379-382 只要求单方向变异（重新引入缺陷）。340 行提到的「双向」指的是基准比对，不是变异方向。条件式修复的两种失败方式没有对应规则。

## Promotion Candidates

以下落点已由 investigator 逐条核对既有条目，可直接执行。

1. **`llmdoc/memory/lessons-learned.md`，「TeX 节点与输出几何」一节内新开一条**（建议排在 109 行「可见排版修复需要三类证据」附近）：*诊断警告绑定的是当时正在构造的盒子，不是可见输出*。Rule 要点是判断缺陷性质须看最终产物的几何量（PDF bbox／节点列表），不能按警告出现的位置推断可见输出坏在哪。Why 用 #997 的 `Missing character` 来自 `\l_@@_tmpa_box`、PDF 里汉字正常、bbox 2.79pt vs 9.96pt。
2. **`llmdoc/memory/lessons-learned.md` 379-382「回归测试必须用重新引入缺陷的方式确认会失败」，扩写；或紧随其后新开一条**：判断某一项用例有没有判别力，必须单独让**那一项**所声称的失败形态发生，不能看整份文件红不红——多项共处一个文件时，红可能全部来自别的项。实例用 #997：条件取反后变红来自第 1、2 项回到原缺陷，而第 3 项声称覆盖的「总是跳过」实测 5/5 全绿、产物与基线逐字节相同。（初版这一条写的是「条件式修复要双向变异」，依据 `x0.0` 读数，该读数无法复现，已作废。）
3. **`llmdoc/memory/lessons-learned.md` 新开一条**：回答「当前用什么字体排版」必须读 `\fontname\font`，NFSS 参数（`\f@family` 等）在 CJK 场景下会与实际字体系统性地不一致——#997 初版正是据 `\TU/lmr/m/n/10` 误判「不重选会量错」，进而得出「重选不能删」这个不成立的结论。~~原计划给 550-553 与 304-307 各追加「删掉重选经实测证否」作为实例~~：该实例本身已被推翻（删掉重选实测 5/5 全绿且同样修好 #997），**不可作为那两条的实例**。
4. **`llmdoc/reference/build-and-test.md:420`，改数字**：「XeTeX 四个文件全红」改为「五个」。本轮已实际重跑该变异（`\@@_tone:nn` 里 `\or:` 分支的 `\'` 与 `` \` `` 对调），5 个 XeTeX 文件全部变红，含新增的 `pinyin-fallback01`（它的基线含拼音字形，同一变异同样影响它）。
5. **`llmdoc/reference/build-and-test.md:412` 与 `llmdoc/memory/decisions/1041-xpinyin-test-adoption.md:15`、`llmdoc/index.md:70`，改数字并补条目**：「四个测试文件按观察通道分工」的计数已过期（`xpinyin/testfiles/` 现有 5 个 `.lvt`，加 `testfiles-cjk/` 共 6 个）。同时给分工清单加 `pinyin-fallback01.lvt` 一条：观察通道是 `\loggingoutput` 下量宽盒子自身的宽度。
6. **`llmdoc/reference/build-and-test.md` 的 xpinyin 一节，扩写既有的「注音宽度看不出拼音内容」**：补上推论——以 `\hbox{\xpinyin*{...}}` 外部宽度为判据的断言恒真（缺陷版与修复版同为 10.0pt），须看节点列表里量宽盒子的宽度。同节再补一条测试写法约束：`\setCJKmainfont` 是 `\@onlypreamble`，正文里换 CJK 主字体要用导言区 `\newCJKfontfamily` 另立一族。
7. **`llmdoc/architecture/xecjk-architecture.md` 的「后备字体 (Fallback)」一节，扩写**：记录 `\xeCJK_reset_fallback_font:` 未启用后备字体时等于 `\prg_do_nothing:`、切换后被重定义为「恢复该字体并清除标记」，因此它同时是状态标记；并记录下游陷阱——在后备字体状态下调 `\xeCJK_select_font:` 会经 `\xeCJK_clear_fallback_font:` 丢掉该状态，需要在后备字体下量宽或排版的下游代码必须先判断这个状态。
8. **新建 `llmdoc/memory/decisions/997-xpinyin-fallback-measure-box.md`**：记录跨包依赖内部实现的取舍（见下节），以及否决「删掉重选」方案的实测理由。

### 跨包耦合面的取舍（决策文档要记的内容）

`\xeCJK_reset_fallback_font:` 在 `xeCJK.dtx` 里**没有独立的 `\begin{macro}` 条目**，只夹在 `\xeCJK_fallback_symbol:NN` 那块里；相比 `\xeCJK_select_font:`（有 `[int]` 条目）更容易在上游重构中改名。

接受它的理由：它是 xeCJK 表达后备字体状态的唯一状态量，语义清晰；xpinyin 本来就依赖 `\xeCJK_select_font:`、`\xeCJK@setfont`、`\l_xeCJK_current_font_tl`、`\xeCJK@family`、`\makexeCJKinactive`、`\CJKsymbol`，这次是在既有耦合面上加了一项，不是开新面。

代价：要在两侧留记录——xpinyin 侧记「依赖了什么」（已在 dtx 注释里写明），xeCJK 侧记「这个机制有此陷阱」（即上面第 7 条）。

## Follow-up

1. 执行上列 8 条 promotion，其中第 4、5 条是既有文档里已过期的数字，优先。
2. 第 7 条落地后，在 xpinyin 的 dtx 注释里加一句指向 xeCJK 架构文档的说明，让两侧记录互相可达。

### 一条方法记录

investigator 指出 `build-and-test.md:420` 的「XeTeX 四个文件全红」在新增第 5 个用例后不可信，并明确说它没有重跑、要我不要凭推断改数。我实际重跑了该变异，得到「五个」。

这条本身值得记：文档里冻结了具体数量的断言，在新增用例后必须重跑确认，不能推断；也不该因为怕错就改成模糊表述——重跑一次的成本很低。它与 329 行「新增测试项后要复查既有项的关键判据是否还在」相邻但不同：那条讲基线里的判据会消失，这条讲文档里的计数会过期。可作为 329 的补充写入。

## 相关

- Issue #997；分支 `fix/997-xpinyin-autofallback`，HEAD `1aa872b1`。
- 实现：`xpinyin/xpinyin.dtx`（`\@@_reselect_CJK_font:`、`\@@_select_CJK_font:`）、`xpinyin/testfiles/pinyin-fallback01.lvt`、`xpinyin/CHANGELOG.md`。
- 验证：`l3build check` 5/5，`l3build check -c test/config-cjk` 1/1。pdfTeX/CJKutf8 路线不受影响，`\@@_adjust_CJK_hook:` 把该 hook 设为 `\prg_do_nothing:`。
- 相关反思：[[1041-xecjk-version-gate]]（同一包的测试建设背景）、[[1029-sbox-global-prefix]]（「变通可用不等于正确修复」的前一次实例）、[[1026-ulem-literal-body-outer-shrink]]（变异验证）。
- 相关决策：[[../decisions/1041-xpinyin-test-adoption]]、[[../decisions/265-disable-pinyin-inside-xpinyin]]。
