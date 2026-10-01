---
name: 1092-siunitx-range-auto-stream
description: 记录 #1092 修复 siunitx 区间、列表等命令左侧缺 \CJKecglue 时，第一版固定 Default 首尾被审查推翻、改为 auto stream 加 \siunitx_print_math:n 补报的过程，以及命令清单、可配置首尾、逐项回退比较和缺字用例四条教训
metadata:
  type: feedback
---

# [Task Reflection]

## Task

#1092 报告 siunitx 的 `\qtyrange`、`\numrange` 等区间命令左侧紧接汉字时缺 `\CJKecglue`，右侧正常。#1000 只给 `\unit`、`\qty`、`\num`、`\si`、`\SI` 注册了固定 Default 首尾的 `stream` capture。按 `siunitx.sty` 实测，同样受影响的命令有 12 个：`\qtyrange`、`\numrange`、`\qtylist`、`\numlist`、`\qtyproduct`、`\numproduct`、`\complexnum`、`\complexqty`、`\duration`、`\ang`、`\SIrange`、`\SIlist`。

根因与 #1000 相同：siunitx 在宏内部进入数学模式。源码直接写 `中$30$` 时，xeCJK 在 CJK→Boundary 处向后查看到 `$`，在 `\mathon` 之前补 `\CJKecglue`；汉字后面是宏时，只留下一对 kern 标记，随后宏内部的 `\mathon` 盖住了这对标记。每个 siunitx 排版命令都是独立的顶层入口，不经过 `\qty` 等命令的 cmd hook，所以要逐个注册。

- 第一版 `9c9400e3`：把 17 个命令都注册为固定 Default 首尾的 `stream`。
- 第二版 `4b360ae9`（审查方给出原型，已采纳；另有 `c5ec78d3` 只调整 `\changes` 的断行）：17 个命令改为 `auto` stream，并包装 siunitx 公开函数 `\siunitx_print_math:n`：不在数学模式时，先调用 `\@@_boundary_capture_class:n { default }`，再调用原函数。数学段不触发 interchar 转换，需要补报 Default；文本段由 interchar 转换报告实际类别。siunitx v2（`[=v2]`）没有这个函数，用 `\cs_if_exist:NT` 跳过；v2 直接写 `$...$`，由公式边界处理报告类别，实测结果正确。

## Expected vs Actual

- 预期：沿用 #1000 的做法，把新命令一并注册为固定 Default 即可。
- 实际：对抗式审查推翻了第一版。siunitx 的输出两端可以是汉字：`range-open-phrase=从`、`mode=text` 下的 `\DeclareSIUnit\yuan{元}`、`\text{元}` 单位、设为汉字的 `duration-unit-*`、`angle-symbol-degree=度`。固定 Default 会在汉字一侧多补一个 `\CJKecglue`。这些命令在 master 上没有注册时，那一侧本来是正确的，所以第一版带来了回退。
- 测试：`siunitx-ecglue01` 由 144 次比较增至 496 次，新增 6 组输出以汉字开头或结尾的用例（文本模式，或用 `\text` 包住汉字单位）。变异实验：改回固定 `default` 时，6 组汉字边缘用例各失败 16 次；去掉 `\siunitx_print_math:n` 的补报或不做包装时，所有输出数学内容的命令都失败。

## What Went Wrong

1. **命令范围以 issue 为准，没有对照上游的命令清单。** issue 只列出三个区间命令，同族的另外 9 个是实测才找到的。
2. **“输出必然以西文开始和结束”是没有验证的假设。** 第一版的 dtx 注释直接写了这句话，并据此选了固定 Default。siunitx 的连接词、单位、符号和 `mode` 都可以配置，输出首尾并不固定。
3. **注释里有两句错误的说明。** “连接词排在命令内部、不改变两端类别”对 `range-open-phrase` 不成立；“汉字单位多补 `\CJKecglue` 是 `\qty` 已有的限制，沿用即可”只对 #1000 已注册的命令成立，对本次新注册的命令是新的回退。把旧命令的已知限制直接套到新注册的命令上，没有检查这些命令在 master 上原来的行为。
4. **按总数比较会掩盖个别用例的回退。** 修复后通过的用例总数增加了，但这无法说明 master 上通过的用例是否仍然通过。应当逐个用例列出“master 通过、修复后失败”的集合。
5. **用例本身可能无效。** 汉字单位直接用在数学模式（不加 `mode=text`，也不用 `\text`）时，lmr 字体没有该字形，排出的是缺字占位，日志报 `Missing character`。这类用例的宽度比较没有意义。
6. **工具误伤。** `pkill -f` 的匹配模式也匹配到执行它的 shell 自己的命令行，结果把自己的 shell 杀掉了。

## Root Cause

- 注册方式的选择依赖“输出首尾类别固定”这个前提，但没有列出能改变首尾字符的选项去验证它。#992 的框架本来就按实际首尾类别工作，固定首尾的注册只适合输出首尾确实不可配置的命令。这是 lessons-learned 中“判据要贴着真正的原因写，不要用一个更粗的条件代替”（#550）在注册方式上的又一次出现：真正的原因是“输出这一端是什么字符”，而“命令属于 siunitx”只是一个更粗的条件。
- 范围判断以报告内容为界，而不是以代码路径为界，与“缺陷按代码路径分布，不按报告者用的引擎分布”（#1068、#994）同属一类。
- 缺字导致用例无效，与 `build-and-test.md` 中 xpinyin“拼音字体缺字时会假通过”是同一类问题的第二次出现：测试有效性的前提是被测字形真的排了出来。

## Missing Docs or Signals

- 没有一条明文规则要求在选择 `stream` 的固定首尾模式之前，先确认输出首尾不可配置。`xecjk-architecture.md` 兼容补丁表里 siunitx 那一行写的是“固定 Default 首尾”，容易被当成可以照搬的先例。
- 没有说明给第三方宏包注册命令时，应按上游的公开命令清单逐个核对（例如 grep `siunitx.sty` 中的 `\NewDocumentCommand`）。
- 文本 oracle 与公式 oracle 的差别没有记录：`xCJKecglue=false` 且命令两侧有源码空格时，已注册命令两端报告了固定类别，源码空格会变成 `\CJKecglue`，结果与裸写 `$5$` 不同。所以 product、complex、ang 用首尾字符相同的文本作为 oracle。
- 维护者决定没有落到稳定文档：issue 中提供的、用户自己注册这些命令的规避写法，升级后会因为 `boundary-register-conflict` 报错。保持报错，只在 `\changes` 和 CHANGELOG 中写明需要删去这些注册。
- 已知遗留没有登记：输出为空时（`\numlist{}`、`\ang{;;}`、`\unit{}`），只有“汉字 空格 命令 空格 汉字”这一种写法出错，多出两枚 `\CJKecglue`（默认间距下 6.66pt），而直接输入是两个汉字直接相接。原因是命令内部没有字符，入口与出口各补一次。与 master 相比，`\unit{}` 是改进（master 上四种空格组合都错）；`\numlist{}` 与 `\ang{;;}` 是变差（master 上只在 `xCJKecglue=false` 时差一枚）。复核时审查方指出了这一点，第一次登记时误写成“与 `\unit{}` 的既有行为相同”。

## Promotion Candidates

- `architecture/xecjk-architecture.md` 兼容补丁表中 siunitx 那一行：改为 17 个命令注册为 `auto` stream，并包装 `\siunitx_print_math:n`，在数学段之前补报 Default；`\ang` 已经注册；v2 没有该函数时跳过包装。
- `reference/build-and-test.md` 中 `siunitx-ecglue01` 的描述：144 次比较改为 496 次；补充 6 组以汉字开头或结尾的用例、文本 oracle 与公式 oracle 的选择理由，以及两项变异实验的结果。
- `memory/decisions/992-command-boundary-capture-register.md`：“`\ang` 暂不注册”“注册为固定 Default 首尾”两处已经过期，需要追加 #1092 的更正，不改写原有历史记录。
- `memory/doc-gaps.md`：登记空输出在“汉字 空格 命令 空格 汉字”时多两枚 `\CJKecglue` 的遗留，写明 `\unit{}` 相对 master 是改进、`\numlist{}` 与 `\ang{;;}` 是变差；同时登记维护者对用户规避写法“保持报错”的决定。
- `memory/lessons-learned.md`（建议新增，属通用规则）：
  - “选固定首尾类别之前，先列出所有能改变首尾字符的选项”：对输出可配置的命令，枚举连接词、单位、符号、文本或数学模式等选项，确认首尾不可配置后才能用固定模式，否则用 `auto` 并在不触发 interchar 的段落补报。
  - “比较修复前后要按用例逐项列出回退集合”：总数增加不能证明 master 上通过的用例仍然通过。
  - “给第三方宏包注册命令时以上游的公开命令清单为准，不以 issue 列出的命令为准”。
- `reference/build-and-test.md` 的测试通用注意事项（可考虑）：宽度比较用例要先确认日志里没有 `Missing character`；这是缺字导致假通过的第二次出现，可以和 xpinyin 那一条合并成通用规则。
- 只留在 memory、不提升：`pkill -f` 匹配到自身 shell 的问题。这是一次性的工具使用失误，与项目机制无关；如果再次出现，再考虑写进本地操作说明（例如改用 `pgrep` 先确认目标，或用 `[x]yz` 这类写法避免匹配到自身）。

## Follow-up

- 第二版提交后，由 recorder 按上面的提升候选更新 `xecjk-architecture.md`、`build-and-test.md`、`992` 决策记录和 `doc-gaps.md`，并在 `llmdoc/index.md` 的反思列表中加入本文件。
- 以后给第三方宏包注册命令时，先 grep 上游 `.sty` 的 `\NewDocumentCommand` 列出全部公开命令，再逐个确认它的输出首尾能不能被选项改变。
- 修复前后对比测试时，保存 master 上每个用例的通过与失败状态，与修复后逐项求差，再报告总数。

## 相关引用

- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_boundary_register_siunitx:` 与对 `\siunitx_print_math:n` 的包装。
- 测试：`xeCJK/testfiles/siunitx-ecglue01.lvt/.tlg`。
- 前序：[[1001-boundary-capture-gap-fixes]]（#1000 的首次注册）、[[../decisions/992-command-boundary-capture-register.md]]、[[../../architecture/xecjk-architecture.md]]。

## 更正（#1103 之后追加）

上文“Missing Docs or Signals”与“Promotion Candidates”把空输出（`\numlist{}`、`\ang{;;}`、`\unit{}`）两侧都有源码空格时多出两枚 `\CJKecglue` 记为已知遗留，`memory/doc-gaps.md` 当时也写明维护者决定本 PR 不改框架、另开 #1103。维护者后来改为要求彻底修复，#1103 已在同一 PR（#1102）中修复，`\changes` 与 CHANGELOG 里 #1092 条目的“已知回退”一句随之删去。修复机制见 `llmdoc/architecture/xecjk-empty-output-space.md`，过程见 [[1103-empty-output-after-space]]。本节之外的正文保持原样，作为当时的记录。
