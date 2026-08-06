# 决策：xpinyin 的量宽盒子按后备字体状态跳过字体重选（#997）

## 背景

xpinyin 与 xeCJK 的 `AutoFallBack` 同时使用时，拼音被压缩重叠。

缺陷链：xpinyin 的 `\@@_CJKsymbol_hook:` 在量宽盒子里调 `\xeCJK_select_font:` → 后者经内部
`\@@_select_font:Nn`，而它的第一句就是 `\xeCJK_clear_fallback_font:`（`xeCJK/xeCJK.dtx:10450-10452`）
→ `AutoFallBack` 刚切好的后备字体状态被清掉 → 量宽盒子在主字体下排版、字形缺失、量出的宽度
只剩 2.8pt（正确值 10.0pt）→ 拼音随后被 `\box_resize_to_wd_and_ht:Nnn` 压缩到这个错误宽度。

需要先纠正一个表象：**可见的汉字不受影响**。它由量宽盒子之外的 `\@@_save_CJKsymbol:n` 输出，
那时后备字体仍然有效。issue 里的 `Missing character` 警告与「汉字变方框」的印象都来自
`\l_@@_tmpa_box` 这个只取尺寸、从不进入页面的临时盒子。`pdftotext -bbox` 实测缺陷版 `zhōng`
2.79pt、修复版 9.96pt，与汉字「中」的 9.96pt 对齐。

## 否决：直接删掉 hook 里的字体重选

第一直觉是「量宽 hook 本来就不该重选字体，删掉即可」。**实测证否。**

`Latin \xpinyin*{中}` 进入量宽盒子时，当前字体是 `\TU/lmr/m/n/10`（西文）——调用处的字体状态
并不保证是 CJK 字体。那次重选的作用正是把量宽盒子切到 CJK 字体，在没有后备字体的常规路径上
是必需的。删掉后回归表现为 16 处 `x2.8`（同原缺陷读数）并带 `Missing character`。

也就是说，这段代码的既有职责与本次缺陷无关，不能因为它出现在缺陷链上就删。这与 #1029 是同一
类判断（见 [[1029-sbox-adapter]]）：报告链上的那段代码往往有自己的历史用途，修复形态应当是
保留语义、换实现或加条件。

## 否决：进入量宽盒子前保存、之后恢复当前字体

issue 评论提到的另一个方向。它能工作，但要引入一套新的状态保存机制（在 xpinyin 侧记下进盒前
的字体、出盒后还原），而 xeCJK 已经有现成的状态量表达同一件事。多一套并行状态就多一处可能与
xeCJK 自身状态失步的地方，收益上也不比现方案多。

## 决策：按后备字体状态跳过重选

`\@@_CJKsymbol_hook:` 改调新增的 `\@@_reselect_CJK_font:`（`xpinyin/xpinyin.dtx:940-953`）：

- 判据 `\cs_if_eq:NNTF \xeCJK_reset_fallback_font: \prg_do_nothing:`。
- 已处于后备字体状态（不等于 `\prg_do_nothing:`）→ 跳过重选，当前字体正是应该用来量宽的那一个。
- 否则 → 走 `\@@_select_CJK_font:`，即原逻辑 `\cs_if_exist_use:NF \xeCJK_select_font: { \xeCJK@setfont }`。
- 外层再套一层 `\cs_if_exist:NTF`，xeCJK 版本不提供该状态量时退回原逻辑。

`\xeCJK_reset_fallback_font:` 的语义：未启用后备字体时等于 `\prg_do_nothing:`（`:9881`）；
切换到后备字体后被重定义为「`\the\font` + `\xeCJK_clear_fallback_font:`」（`:9872-9876`）；
`\@@_clear_fallback_font:` 再还原（`:9879-9880`）。它是 xeCJK 表达这件事的唯一状态量。

两个包各自的逻辑都自洽——xeCJK 认为「重选字体意味着放弃后备」，xpinyin 认为「量宽必须切到
CJK 字体」——冲突只在两者叠加时出现，所以修复落在 xpinyin 侧的条件判断上，不改 xeCJK。

## 接受的代价：跨包依赖内部量

`\xeCJK_reset_fallback_font:` 在 `xeCJK.dtx` 里**没有独立的 `\begin{macro}` 条目**，只夹在
`\xeCJK_fallback_symbol:NN` 那块代码里；相比有 `[int]` 条目的 `\xeCJK_select_font:`，它更容易
在上游重构中改名或改语义。

接受它的理由有两条。一是语义清晰且无替代：它是 xeCJK 表达后备字体状态的唯一状态量。二是这不是
开新的耦合面——xpinyin 本来就依赖 `\makexeCJKinactive`、`\xeCJK_select_font:` / `\xeCJK@setfont`、
`\l_xeCJK_current_font_tl`、`\xeCJK@family`、`\CJKsymbol`，这次是在既有耦合面上加了一项。

代价是要在两侧都留记录，让它们互相可达：

- xpinyin 侧记「依赖了什么」——`xpinyin/MAINTAINING.md` 的「依赖的 xeCJK 内部接口」一节，
  以及 dtx 里 `\@@_reselect_CJK_font:` 的注释。
- xeCJK 侧记「这个机制有此陷阱」——`llmdoc/architecture/xecjk-architecture.md` 的
  「后备字体 (Fallback)」一节，含「改名或改语义要通知下游」。

xeCJK 升级或上述任一接口改名时，除了跑两条测试路线，还要核对 `pinyin-fallback01` 是否仍有
判别力（把条件取反，确认基线会变红）——接口改名可能让条件变成恒真或恒假而测试照旧全绿。

## 测试

新增 `xpinyin/testfiles/pinyin-fallback01.lvt`（3 项，XeTeX 路线）。判据是 `\loggingoutput`
节点列表里量宽盒子自身的宽度，**不是整体宽度**——拼音在 `\hbox_overlap_right:n` 零宽盒子里，
缺陷版与修复版的 `\hbox{\xpinyin*{中}}` 同为 10.0pt，外部宽度断言恒真。

条件式修复要双向变异，两种失败形态各有一组用例：

| 变异 | 基线读数 |
|---|---|
| 回退成无条件重选（原缺陷） | 16 处 `x2.8`，带 `Missing character` |
| 条件写反成总是跳过（过度修复） | `x0.0`（在西文字体下量宽） |

第 3 项（主字体自带 CJK 字形、紧跟在西文之后）专门固定后一种；缺它则「总是跳过」不会被任何
用例发现。该项用导言区的 `\newCJKfontfamily` 另立一族，因为 `\setCJKmainfont` 是
`\@onlypreamble`（`xeCJK/xeCJK.dtx:10854`），正文里用不了。

字体取 `lmroman10-regular.otf`（`lm`）与 `FandolSong-Regular.otf`（`fandol`），两者已在
`.github/tl_packages`，不需要新增。

`l3build check` 5/5、`l3build check -c test/config-cjk` 1/1 通过。pdfTeX/CJKutf8 路线不受本
修复影响：`\@@_adjust_CJK_hook:` 把 `\@@_CJKsymbol_hook:` 直接设为 `\prg_do_nothing:`
（`xpinyin/xpinyin.dtx:973` 附近），故 `testfiles-cjk/` 无对应用例。

## 相关

- 反思：[[../reflections/997-xpinyin-fallback-measure-box]]
- 同类判断（报告链上的代码有自己的历史用途）：[[1029-sbox-adapter]]
- 测试建设背景：[[1041-xpinyin-test-adoption]]
- Stable：`llmdoc/architecture/xecjk-architecture.md`「后备字体 (Fallback)」、
  `llmdoc/reference/build-and-test.md`「xpinyin 的注音回归（#1041）」、`xpinyin/MAINTAINING.md`
- 实现：`xpinyin/xpinyin.dtx`（`\@@_reselect_CJK_font:`、`\@@_select_CJK_font:`）、
  `xpinyin/testfiles/pinyin-fallback01.lvt`、`xpinyin/CHANGELOG.md`
