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

## 未采用（但并非因为它错）：直接删掉 hook 里的字体重选

第一直觉是「量宽 hook 本来就不该重选字体，删掉即可」。本决策**初版声称实测证否，那个判断是
错的**，已由独立审查推翻，这里保留更正后的事实。

初版的依据是：`Latin \xpinyin*{中}` 进入量宽盒子时探针打印 `\TU/lmr/m/n/10`，据此认为当前字体
是西文、不重选会量错。**探针取错了量**——`\TU/lmr/m/n/10` 是 NFSS 状态（`\f@family` 等），而
决定字符实际用什么字体排版、进而决定量出的宽度的是 `\fontname\font`。在同一位置读
`\fontname\font`，得到的已经是 CJK 字体：xeCJK 的 interchar 进入 CJK 类时就切好了字体，本 hook
运行在那之后。已在十余种上下文逐一探测，`\fontname\font` 无一例外已是 CJK 字体。

实测更正后的读数：

- 把 `\@@_reselect_CJK_font:` 函数体置空（等价于总是跳过），`l3build check` **5/5 通过**，
  且 `pinyin-fallback01` 产物与提交基线**逐字节相同**；
- 从 hook 里删掉这次调用，同样 **5/5 通过**；
- 在删掉重选的版本上跑 #997 原始 MWE：`Missing character` 为 0，`zhōng` 跨度 9.96pt，
  与汉字对齐——**删掉重选同样修好了 #997**。

初版写的「删掉后出现 16 处 `x2.8` 并带 `Missing character`」实际是**回退成无条件重选**（即原
缺陷）的读数，两个变异的日志记混了。

所以「删掉」是一个同样正确、且更简单的修复。仍然保留条件式实现，理由是**保守而非必需**：NFSS
参数此时确实还停在西文族，一旦 xeCJK 改变字体切换的时点，那次重选就重新变得必要；保留它在当前
行为下无可观察代价（两种写法产物逐字节相同）。这个理由比「它是必需的」弱得多，如实记下。

代价是：「重选被跳过」这一侧没有任何用例能拦住，记为已接受的覆盖缺口（见
[[../../reference/build-and-test]] 的 #997 一节与 `pinyin-fallback01.lvt` 第 3 项注释）。

## 否决：进入量宽盒子前保存、之后恢复当前字体

issue 评论提到的另一个方向。它能工作，但要引入一套新的状态保存机制（在 xpinyin 侧记下进盒前
的字体、出盒后还原），而 xeCJK 已经有现成的状态量表达同一件事。多一套并行状态就多一处可能与
xeCJK 自身状态失步的地方，收益上也不比现方案多。

## 决策：按后备字体状态跳过重选

`\@@_CJKsymbol_hook:` 改调新增的 `\@@_reselect_CJK_font:`（`xpinyin/xpinyin.dtx:957-970`）：

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
判别力。可用的检查是**回退成无条件重选**（把 `\@@_reselect_CJK_font:` 的函数体换成
`\@@_select_CJK_font:`），确认基线变红。注意「把条件取反」不是一个独立的检查：取反后变红来自
第 1、2 项，与回退同源；而「恒为跳过」这一侧没有用例能拦住（见上文覆盖缺口）。接口一旦改名，
`\cs_if_exist:NTF` 会走 F 分支、退化为无条件重选，这种情形能被第 1、2 项抓到。

## 测试

新增 `xpinyin/testfiles/pinyin-fallback01.lvt`（3 项，XeTeX 路线）。判据是 `\loggingoutput`
节点列表里量宽盒子自身的宽度，**不是整体宽度**——拼音在 `\hbox_overlap_right:n` 零宽盒子里，
缺陷版与修复版的 `\hbox{\xpinyin*{中}}` 同为 10.0pt，外部宽度断言恒真。

变异实测（更正后的读数，初版把两个变异记混了）：

| 变异 | 实测结果 |
|---|---|
| 回退成无条件重选（原缺陷） | 16 处 `x2.8`，带 `Missing character`，变红 |
| T／F 分支互换 | 产物与「无条件重选」逐字节相同，非独立形态 |
| 重选整个删掉（置空或不调用） | **5/5 全绿，产物与基线逐字节相同** |
| 重选切到错误的 CJK 族（`\CJKfamily{\CJKrmdefault}`） | 仅第 3 项变红，第 1、2 项逐字节不变 |

所以「**整支重选被跳过**」是已接受的覆盖缺口。第 3 项固定的是主字体直接命中这条路径的
正常输出：它对「整支被跳过」没有判别力，但**是「重选切到错误 CJK 族」这一形态的唯一防线**
——保持条件结构不动、只在 `\@@_select_CJK_font:` 开头插 `\CJKfamily{\CJKrmdefault}`，实测
只有第 3 项变红（`x10.0`→`x2.8`、缩放比 0.81777→0.22898，新增两条 `Missing character`），
第 1、2 项区域逐字节不变。把对照字体选成与后备字体不同的 `FandolKai` 是这项判别力的前提。
该项用导言区的 `\newCJKfontfamily` 另立一族，因为 `\setCJKmainfont` 是
`\@onlypreamble`（`xeCJK/xeCJK.dtx:10854`），正文里用不了。

字体取 `lmroman10-regular.otf`（`lm`）与 `FandolSong-Regular.otf`（`fandol`），两者已在
`.github/tl_packages`，不需要新增。

`l3build check` 5/5、`l3build check -c test/config-cjk` 1/1 通过。pdfTeX/CJKutf8 路线不受本
修复影响：`\@@_adjust_CJK_hook:` 把 `\@@_CJKsymbol_hook:` 直接设为 `\prg_do_nothing:`
（在 `xpinyin/xpinyin.dtx` 里检索 `\cs_new_eq:NN \@@_CJKsymbol_hook: \prg_do_nothing:`），故 `testfiles-cjk/` 无对应用例。

## 相关

- 反思：[[../reflections/997-xpinyin-fallback-measure-box]]
- 同类判断（报告链上的代码有自己的历史用途）：[[1029-sbox-adapter]]
- 测试建设背景：[[1041-xpinyin-test-adoption]]
- Stable：`llmdoc/architecture/xecjk-architecture.md`「后备字体 (Fallback)」、
  `llmdoc/reference/build-and-test.md`「xpinyin 的注音回归（#1041）」、`xpinyin/MAINTAINING.md`
- 实现：`xpinyin/xpinyin.dtx`（`\@@_reselect_CJK_font:`、`\@@_select_CJK_font:`）、
  `xpinyin/testfiles/pinyin-fallback01.lvt`、`xpinyin/CHANGELOG.md`
