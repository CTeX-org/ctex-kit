# #1008 反思：带选项 `\zhnum`/`\zhdig` 写辅助文件时把计数器名当值写进去

任务：Issue #1008 报告按层级混搭中文数字样式做不到——用户想让 `\section` 用
`\zhnum[style=Normal]{section}`、`\subsection` 用 `\zhnum[style=Financial]{subsection}`，
实测目录编号与正文不一致。手册当时只写「带了选项的命令是不可展开的，在某些场合使用时要
小心」，报告者据此认为这是设计限制。

## 缺陷本身

### 根因一：带选项形式把计数器**名**写进辅助文件

原实现 `\zhnum[opts]{section}` 展开成 `\zhnumwithoptions{opts}{section}`；后者用
`\NewDocumentCommand`（不可展开，因为要用 `\group_begin:`/`\group_end:` 局部改样式）。
于是 `.toc` 里留下的是 `\zhnumwithoptions{style=...}{section}`——**计数器名**，而不是
当时的计数器值。该文件在下次编译的 `\tableofcontents` 处读回时计数器已归零，实测正文
「一／一.壹」而目录「零／零.零」。

修法：在 `\zhnum` 这一层先用 `\exp_args:Nnf` + `\exp_args:Nc \int_use:N` 把计数器取成
数值，再交给处理**数值**的 `\zhnumberwithoptions`；写进辅助文件的成为
`\zhnumberwithoptions{style=...}{7}`，数值已固定，样式留待读回时套用。`\zhdig` 同理
（走 `\zhdigitswithoptions`，星号参数传 `{\BooleanFalse}`）。这两处写法都不是初版就对：
初版用 `\exp_args:Nne` + `\int_use:c`，计数器不存在时会先把 `\c@nosuchcounter` 建成
`\relax` 再 `\the` 它，报出的是难懂的 `You can't use \relax after \the`，而不是
zhnumber 自己的 `is not a LaTeX counter` 诊断；`\zhdig` 那一侧初版传的是 `\c_false_bool`
而不是 `{\BooleanFalse}`，这处笔误后果更隐蔽，见下面「辅助文件往返记号不能含 `_`」。

**没有改成完全可展开，这是有意取舍**：样式靠 `\tl_set_eq:NN` 一类**赋值**实现（见
`\zhnum_reset_style:`），赋值无法在 `\edef` 的展开中生效，硬做只会把「不可展开」换成
「静默用错样式」。

### 根因二：排查中发现的独立 bug

`\zhdigwithoptions` 原写的是 `\zhnum_digits_counter:n #1 {#2}`——多传了一个 `#1`
（选项本身）。`\zhnum_digits_counter:n` 只取一个参数，于是选项被当成计数器名、真正的
计数器名溢出到后面。实测 `\zhdig[style=Financial]{section}` 直接报
`Use of \??? doesn't match its definition` 并把 `tyle=Financialsection` 印到页面上——
带选项的 `\zhdig` 此前**完全不可用**，与根因一无关，单独记 `\changes`、单独测。

### 兼容性

`\zhnumwithoptions`/`\zhdigwithoptions` 保留为转发：v3.1 及以前写下的 `.toc` 里还留着
这两个名字，删掉会让旧文件读回时报 undefined。

## What Went Wrong：测试设计上走的弯路

补测试时在「怎么观察不可展开命令的行为」上反复试错，四次都是死路：

1. **`\typeout{\zhnumwithoptions{...}{...}}` 不行**——这两个命令不可展开，`\typeout`
   只记下它们的**名字**，内部坏掉也看不出来。实测恢复根因二的笔误后，只用 `\typeout`
   的版本仍然全绿。
2. **`\tl_set:Nx` 也不行**——同样只拿到名字。
3. **在 `\TEST` 的参数里切 `\ExplSyntaxOn` 不生效**——参数已被读入，catcode 定死了。
   实测报 `Undefined control sequence` 指向 `\tl_log:N`。同理 `\protected@edef` 含
   `@`，在 `\ExplSyntaxOn` 下直接写会报 `You can't use a prefix with the character @`。
4. **让它们真的排版，但放在主 `testfiles/` 里也不行**——排 CJK 需要中文字体：XeTeX 下
   只是 `Missing character` 警告，pdfTeX 下是**硬错误** `Unicode character ... not
   set up for use with LaTeX` 并中止编译。同一个 `.lvt` 的两个引擎基线会分化成
   「报错」与「警告」两种形态，且后者让其后用例静默不执行。

最终解法是**按引擎需求分目录**：

- `testfiles/counter-options01`（三引擎）用记号层面的断言固定「值有没有被冻结」——
  判据是展开结果里出现 `{7}` 而非 `{section}`；
- `testfiles-cjk/legacy-entry01` + `test/config-cjk.lua`（仅 xetex）让兼容入口真的排出
  汉字再量盒子，做法仿 `xpinyin/test/config-cjk.lua`。

另外盒子度量的判别力踩过**两次**，而且第二次是在我以为已经解决之后。第一次：想用
**宽度**，但缺字时宽度会 collapse 成同一个值（实测两者都是 2.8pt），分辨不出内容；改用
**高度**才区分开（`ht=7.33` 的「七」vs `ht=7.75` 的「柒」）。

第二次（第四轮盲审指出）：**高度也不足以固定排出的是哪个字**。实测 FandolSong 下「柒」
「九」「佰」的 `ht` 都是 7.75，于是一个让 Financial 的 7 排成「九」的缺陷能通过全部度量
断言——实测零度量 diff。真正固定字形要让盒子内容本身进基线：`\loggingoutput` +
`\box_use:N` + `\clearpage`（`\loggingoutput` 记的是输出例程送出的页面，不 `\clearpage`
则段落为空；不用 `\showbox` 是因为它报 `! OK.` 会在 `-halt-on-error` 下当场中止，与
`xeCJK/testfiles/verb-ecglue02.lvt` 同一取舍）。汉字在基线里就是字面 UTF-8 汉字，不是
码位数字——l3build 的日志归一化不把 CJK 码位转成 `^^` 形式（我一度写成「表现为字符编号」，
与同一份提交生成的基线相反，第四轮盲审用 hexdump 指出）。

补这一项时还犯了一次「只补一半」：初版只排 `\zhnum` 的三个盒子，而前三项每项都测两个
入口，于是 `\zhdig` 侧仍然只有度量断言、本项声称补掉的盲区原样保留（盲审用一个针对
`\zhdigwithoptions` 的变异实测全绿）。现在六个入口全覆盖。

**这条教训后来在同一份改动里复发过一次**：`counter-options01` 里对
`\zhnumwithoptions`/`\zhdigwithoptions` 的断言用 `\tl_set:Nx` 捕获结果，而这两个命令
是 `\NewDocumentCommand`、protected，捕获只拿到命令名本身，断言恒真——即写下上面这条
教训之后，仍在同一批测试代码里留了一个犯同样错误的断言，直到 da00ad53 才被盲审揪出来
并删除（详见下面「后续发现的另外两个问题」一节）。

## Root Cause

上述四条弯路的共同根源是同一件事：**观察不可展开命令的行为，只有「让它执行」一条路**。
`\typeout`/`\tl_set:Nx`/`\protected@edef` 这类手段面对一个不可展开的宏时，只能拿到它的
**控制序列名**本身（因为宏未被展开），无法看到宏体内部逐步展开、赋值、报错的中间过程；
若内部有笔误（如根因二），这些手段一律看不出来。要观察内部是否正确，必须让宏真正
**执行**（这里是排版出可见节点），再从执行结果（节点、盒子尺寸）反推内部逻辑是否正确。

盒子度量选宽度还是高度也是同一类问题的缩影：缺字时字体会用同一个占位字形，宽度往往
被 collapse 成同一个值，必须先验证候选维度真的会随内容变化，再拿来做判据。

## Missing Docs or Signals

- 手册原文「带了选项的命令是不可展开的，在某些场合使用时要小心」这句措辞本身塑造了
  报告者「这是设计限制」的判断。「不可展开」和「不能写进辅助文件」是两件不同的事，手册
  没有把这层区分说清楚，直到 42cb1be8 补上「不可展开不妨碍写入辅助文件」一段后，这个
  用法才变得可发现。这是文档缺口而非代码缺口，但直接导致了报告者卡在错误结论上。
- `l3build check` 没有「按 `.lvt` 文件指定引擎」的机制，`build-and-test.md` 里已记过
  这条约束（#1038／xpinyin 系列），本次是第三次撞上同一约束、第二次靠分 testfiledir
  解决，说明这条规则已经足够稳定，值得作为通用判据反复引用而不必每次重新论证。

## 后续发现的致命错误机制（da00ad53，更正了本文件曾经的一处误判）

本文件早先在这里写过：`\@@_counter_error:n` 走 `\msg_expandable_error:nnn` 会留下
`\???` 触发 `Use of \??? doesn't match its definition`，是「与 #1008 无关的既有粗糙
点」，「所以没把它固定进基线（那会把一个无关的既有粗糙点冻结成预期值），测试里只用
`\int_if_exist:cTF` 确认两条路进的是同一个判断分支」——**这个断言是恒真的**：它根本
没调用 zhnumber 的任何代码，只是让 expl3 判断一个不存在的寄存器是否存在，与
`\@@_counter_error:n` 的行为完全无关。盲审查出这一点，实测把
`\@@_counter_with_options:nn`／`\@@_digits_counter_with_options:nn` 里的
`\int_if_exist:cTF` 守卫删掉后，两套测试仍然全绿零 diff。

真正原因是一个更严重的机制问题：`\@@_counter_error:n` 留下的 `\???` 触发的
`Use of \??? doesn't match its definition` 在本仓库是**致命错误**——成因是
`support/build-config.lua:9` 的 `checkopts = "-halt-on-error"`，不是 LaTeX 或 l3build
的默认行为。这一点用四组隔离实验定下来——两个开关（`-interaction=nonstopmode` 有无、
`-halt-on-error` 有无）的四种组合，跑同一个含两个 `\TEST` 的文件，第一个 `\TEST` 触发该
报错。表中「`\scrollmode` 是否生效」指 `regression-test.tex:37` 的
`\ifnum\interactionmode>1 \scrollmode\fi` 这个条件是否成立（注意本仓库里「守卫」一词更多
用于 `\int_if_exist:cTF` 那类代码守卫，这里说的是这个条件判断）：

| `-interaction=nonstopmode` | `-halt-on-error` | `\interactionmode`（读 `regression-test` 前 → 后） | `\scrollmode` 是否生效 | 第二个 `\TEST` 是否执行 |
|---|---|---|---|---|
| 无 | 无 | 3 → 2 | 是 | **是** |
| 有（l3build 默认） | 无 | 1 → 1 | 否 | 是 |
| 无 | 有 | 3 → 2 | 是 | **否** |
| 有 | 有 | 1 → 1 | 否 | **否** |

（本仓库 `l3build check` 实际落到第三行：`checkopts` 被 `support/build-config.lua` 覆盖成
只有 `-halt-on-error`，所以 `\interactionmode` 读作 2、`\scrollmode` 确实切了。）

按列读即可定因：`\scrollmode` 那一列与结果列不相关（第一行生效却不中止），
`-halt-on-error` 那一列与结果列完全一致。所以中止只能归给 `-halt-on-error`。

**我在这里连错两次，第二次是在更正第一次的时候。** 起初把成因归给 `\scrollmode`（盲审
实测证伪）；更正时又写下「`\interactionmode` 实测恒为 1，`\scrollmode` 从未生效」——那是
把对照组（`-interaction=nonstopmode` 那侧确实为 1）的读数当成了实验组的读数，第二轮盲审
再次证伪：`l3build check` 下实测 `\interactionmode` 为 2（`regression-test.tex:37` 的
`\scrollmode` 确已切换）。正确结论是「生效但不中止」，而不是「从未生效」。这恰好落在
本仓库既有规则「成因用隔离实验」的射程内——两次都是只测了一侧就下成因结论。

实测编译就地中止，其后所有 `\TEST` 一律不执行。观察判据是「后面的 `\TEST` 段落有没有
进基线」，而不是日志里的 `Fatal error occurred, no output PDF file produced!`——那一行
只有 pdftex/luatex 打印，xetex（这两个测试的 `stdengine`，也是上面那张表的实验引擎）
并不打印，而且它从不进入 `.tlg`——它排在
`Here is how much of ...TeX's memory you used:` 之后，l3build 读日志时读到那一行即
`break`（`l3build-check.lua:339-341`），其后内容一律截掉（不是被归一化规则删掉，措辞上
我一度写错）。我一度把它当成判据写进三个文件，
第三轮盲审指出。

**关于「删掉守卫零 diff」的成因，我写过一个与提交历史相反的说法，这里更正。** 我曾写成
「报错断言原先排在 `counter-options01` 中间（TEST 5），于是后面的 TEST 6 从未运行过、
基线里没有它的段落」。核对提交即可否证：`29f3649b` 那一版的 TEST 5 是
`\int_if_exist:cTF { c@nosuchcounter }` 探针，它**不触发**可展开报错、不中止编译，同版
`.lvt` 与 `.tlg` 的段落数都是 6、TEST 6 段落内容完整。可展开报错的断言是 `da00ad53` 才
引入的，而且引入时就在文件末位——「排在中间因而截断后续用例」这个状态**从未存在过**。

所以「删掉守卫零 diff」只有一个成因，就是那条恒真断言本身（`\int_if_exist:cTF` 探针根本
没调用 zhnumber 的代码）；把 `29f3649b` 全量取出、只删守卫，在没有任何中止的情况下就已
经全绿零 diff（第四轮盲审实测）。中止机制是真实存在的约束，但它是我在 `da00ad53` 加入
报错断言后才需要处理的问题，不是当初假绿的原因——我把后来学到的机制回溯成了当初的成因。
这是本仓库既有规则「现象、联系、穷尽性、成因是四个独立命题」的又一个实例：观察到故障，
不等于对成因的解释也成立。

由此得到两条硬约束：**一个 `.lvt` 只能断言一次可展开报错，且该断言必须放在文件最末**。
`\zhnum` 与 `\zhdig` 各有一条独立守卫（`\@@_counter_with_options:nn` 与
`\@@_digits_counter_with_options:nn`），两条都要覆盖，所以拆成了两个文件：
`counter-options01`（覆盖 `\zhnum` 那条，该断言自加入起就在文件最末）和新增的
`counter-options02.lvt`（专门覆盖 `\zhdig` 那条）。报错文本本身进了基线，代价是多份基线：
`counter-options01` 三份、`counter-options02` 两份——两者都因 luatex 在该错误后打印的
help 行比 xetex/pdftex 少四行而需要 `.luatex.tlg`；而 `.pdftex.tlg` 只有
`counter-options01` 需要——差别在日志**编码**：它的断言里有汉字，pdfTeX 把它们记成
`^^e4^^b8^^83` 而 xetex 记成 `七`。**不是**因为 pdfTeX 排 CJK 会硬错误：这里的汉字只经
`\tl_log:x` 进日志、没有真的排版，实测 `l3build check -e pdftex counter-options01` 全绿、
零 `Unicode character` 命中。（把两件事混起来是我改这段时新引入的错误，第三轮盲审指出；
`build-and-test.md` 原本的「字节形式」措辞是准确的。真正会因 pdfTeX 排 CJK 硬错误而必须
分目录的是 `testfiles-cjk/`，见 `test/config-cjk.lua` 的说明。）`counter-options02` 的
pdftex 输出与 stdengine 逐字节相同，不留冗余基线。

同时记一条更一般的教训：**基线文件的长度/段落数本身就是证据**——如果某个 `\TEST` 的
段落在 `.tlg` 里根本不存在，说明它没跑，而不是「它通过了」。写完 `.lvt` 后应核对基线
里的 TEST 段落数与文件里的 `\TEST` 个数是否一致，而不是只看 l3build 报的绿/红。

## 后续发现的另外两个问题（da00ad53）

### 辅助文件往返记号不能含 `_`

初版给 `\zhdigitswithoptions` 的星号参数传 `\c_false_bool`。这一整串会被写进 `.toc`，
再在下次编译时重新 tokenise，而那时 `_` 不是 letter（catcode 8），名字在**写出时**就
断成 `\c _false_bool`，读回即出错。具体报什么错取决于写法，实测两种：初版不带花括号的
`\exp_args:NNne ... \c_false_bool` 把断开的 `_` 当成键名，报
`The key 'zhnum/options/_' is unknown` 之类一串错误；带花括号的
`{ \c_false_bool }` 报 `Missing $ inserted.`。两者都是「名字在写出那一刻断开」的后果，
但把某一种当成这条约束的唯一表征会让后来者复核时以为机制不成立（盲审指出这一点）。
第一遍编译正常、第二遍才炸——等于把 #1008 那种「跨编译才暴露」的失败换到了另一个命令上，
是盲审查出来的。

修法：改用 `{\BooleanFalse}`（expl3 为此提供的、名字里没有 `_` 的记号），与
`\zhdigits` 的无计数器版本对齐。

一般化：**凡是会被写进辅助文件的 expl3 记号，都要检查名字里有没有 `_`**；判据是跑两遍
编译，而不是一遍。这与 #1043、以及本反思已有的 catcode 讨论同属「catcode 在 tokenise
那一刻决定」这一机制族，但场景是新的（辅助文件往返，不是对齐环境）。

### protected 命令用 `\tl_set:Nx` 捕获恒真（旧教训复发）

`counter-options01` 里原有一项对兼容入口 `\zhnumwithoptions`/`\zhdigwithoptions` 的
断言用 `\tl_set:Nx` 捕获结果——但它们是 `\NewDocumentCommand`，因而 protected，捕获
只得到命令名本身（实测基线里就是 `\zhdigwithoptions {style=Financial}{section}`
原样）。该断言对这两个命令的行为恒真，已删除；这一面由
`testfiles-cjk/legacy-entry01` 量盒子覆盖。

这与本文件下面 What Went Wrong 里已经记的「死路 1、2」（观察不可展开命令只有让它执行
一条路）是同一根源，但这次的教训更严重一层：**我在已经写下那条教训之后，仍然在同一
份改动里留下了一个犯同样错误的断言**。写下一条教训不等于已经把它应用到手头所有代码上——
补完教训后要回头扫一遍同一批产物里是否还有同型问题。

### `scripts/extract-changes.py` 的占位符漏出（配套发现，非 zhnumber 缺陷本身）

`\texttt{Use of \cs{???} doesn't match its definition}` 这类**嵌套**里，`\cs`/`\tn`
先被替换成 `\x00..\x01` 占位符，随后整段被 `_save_verbatim` 收进 `verbatim_blocks`，于
是 `_restore_combined_code` 再也扫不到内层占位符，原始控制字符直接落进
`CHANGELOG.md`——已提交的 zhnumber v3.2 条目里就是 `Use of ^@???^A`。

关键教训：**这类漏出是确定性的，`check-changelog.yml` 的「重新生成 + git diff」新鲜度
校验抓不到**——生成物两边一致，只是两边都错。所以另加了一道占位符校验（实测：旧脚本下
失败退出 1，新脚本下通过）。一般化为：**「生成物与源同步」和「生成物本身正确」是两个
独立命题**，同步性校验对确定性缺陷零判别力。这与 lessons-learned 里已有的「跑了但什么
也没校验的 job 比没有 job 更危险」相邻但不同。

另外：修的是**共享**脚本，所以重新生成了所有包的 CHANGELOG 并确认只有 zhnumber 一个
文件变化，以此界定影响面。

### dtx 注释里的 Markdown 星号（小）

dtx 注释里写 `**...**` 是 Markdown 习惯，在手册里会原样排出星号。已改为 `\emph{}`，并
用 `pdftotext` 核对成品 PDF 里不再有 `**`。

## 判别力实测结果

初版曾在这里写「三个方向的变异都能让相应用例变红」，其中「zhdig 退回写计数器名 →
`counter-options01` 红」这一条的证据基础不牢——当时判据里混着上面已更正的那条恒真
断言，看到的红未必来自该断言本身。da00ad53 按修好的测试布局重新做了一遍**逐条隔离**
的变异测试，结果是：

- 删 `\@@_counter_with_options:nn` 的守卫（`\int_if_exist:cTF`） → 仅
  `counter-options01` 红（三引擎），报 `You can't use \relax after \the`；
- 删 `\@@_digits_counter_with_options:nn` 的守卫 → 仅**新增的**
  `counter-options02` 红（三引擎），`counter-options01` 全绿零 diff（它的致命错误
  发生在更早的位置，见上面「后续发现的致命错误机制」）；
- 复现 `\zhdigwithoptions` 笔误（多传一个参数） → `testfiles-cjk/legacy-entry01` 红。

每条变异只让对应的那一个测试文件变红，其余文件零 diff——这确认了拆成
`counter-options01`／`counter-options02`／`legacy-entry01` 三个文件之后，三者的判别
力互不重叠，各自只覆盖自己名下的那条代码路径。

**`legacy-entry01` 这一条曾长期抓不到**，正是上面 what-went-wrong 那四条弯路的后果——
主目录里无论用 `\typeout` 还是 `\tl_set:Nx` 都只能记下名字。这是补 CJK 那一组的真正
理由。

## 版本管理

加了 `\changes` 条目就必须 bump `build.lua` 的 `version`（3.1 → 3.2），否则会被
PR #1055 补的 `check-tag` 拒绝。CHANGELOG 由 `make changelog-zhnumber` 生成。

## Promotion Candidates

以下几条具有跨包复用价值，建议提升到 `lessons-learned.md` 或 `reference/`：

1. **观察不可展开命令的行为，只有「让它执行」一条路**：`\typeout`/`\tl_set:Nx`/
   `\protected@edef` 都只能拿到名字。若测试判据只依赖这些手段，对该命令内部的缺陷
   完全没有判别力。这条与 #1043 反思里「探针先自证有效」同属一类——先确认观察手段本身
   有没有能力看到你要断言的东西。
2. **测试文件的 catcode régime 要一次定好**，不能在 `\TEST` 参数里临时切换
   `\ExplSyntaxOn`/`\ExplSyntaxOff`（参数已被读入，catcode 已冻结）。这条与 #1043
   「字面模式的类别在 tokenise 那一刻冻结」是同一机制在不同场景的重现，值得在
   `coding-conventions.md` 里合并成一条通用规则。
3. **引擎需求不同的测试必须分目录**，`l3build check` 没有按文件指定引擎的机制；这是
   本仓库第三次撞上同一约束（此前见 #1038、xpinyin 系列），应作为稳定判据在
   `build-and-test.md` 里保持醒目位置，不必每次重新论证。
4. **盒子度量选哪一维要先验证它真的会变**：缺字时宽度可能 collapse 到同一个值，高度
   往往才有判别力；一般化为「用度量做判据前，先用已知的两个不同输入分别测一次候选维度，
   确认它们不同」。
5. **手册措辞会塑造用户对「这是不是限制」的判断**：本次报告者正是被「不可展开」这句话
   引导到「这是设计限制」的结论上。修复代码缺陷之外，若手册的既有措辞会让同类误读复现，
   应当同时补一段说明用法边界，而不只是改代码。
6. **修一个问题时发现的独立 bug（根因二）要单独记 `\changes`、单独设计测试用例**，不要
   混进主问题的叙述和判据里，否则后续想单独复核某个 bug 是否修复时会难以拆分证据。
7. **`-halt-on-error` 下任何会抛错的断言都会让同文件内后续 `\TEST` 静默不执行**：
   本仓库 `support/build-config.lua:9` 设了 `checkopts = "-halt-on-error"`，
   `\msg_expandable_error:nnn` 留下的 `\???` 因而让编译当场中止；一个 `.lvt` 只能断言
   一次这类报错，且必须放在文件最末。**基线段落数是判断测试是否真的跑过的证据**——
   `\TEST` 数量应与 `.tlg` 里的段落数一一对应，只看绿/红不够。注意 #1026 已用 `\showbox`
   撞过同一机制并记下规则，所以本条应并入那一条、按「任何抛错的断言」记，而不是新立一条
   按具体命令记的规则；也不要把成因写成 l3build 或 LaTeX 的默认行为。
8. **写进辅助文件（`.toc`／`.aux` 一类）的 expl3 记号名字不能含 `_`**：`_` 在辅助文件
   被重新 tokenise 时不是 letter（catcode 8），记号名会在写出那一刻就断开，读回后报
   一串 key/undefined 错误，且症状是「第一遍编译正常、第二遍才炸」。判据是跑两遍
   编译，而不是一遍。
9. **对 protected 命令（`\NewDocumentCommand` 定义的宏）用 `\tl_set:Nx`／`\tl_set:Nn`
   一类捕获结果的断言恒真**——只能拿到命令名本身，这与本文件已有的「观察不可展开命令
   只有让它执行一条路」是同一条规则；本次的额外教训是**这条规律会在同一批改动里复发**：
   写下一条教训后仍需要回头检查同一批产物是否还有同型问题，不能假设写过一次就不会再犯。

   **这条「回头扫一遍」本身又复发了一次**，值得单独记下：更正「删掉守卫零 diff 的成因
   是中止截断」这个错误归因时，我改了三份 llmdoc，却漏掉这句话最原始的出处——
   `counter-options01.lvt` 自己的注释，于是同一个文件里相邻几行自相矛盾（第五轮盲审
   指出）。可操作的做法是：更正一处事实性表述前，先用 `grep -rn` 把该说法的**所有**出现
   位置列出来，按列表逐个改并回头核对，而不是凭记忆枚举「应该在哪几个文件里」。
10. **测试输入的取值本身要能区分被测的各条路径**：`legacy-entry01` 的字形断言一开始只
    用 `\setcounter{section}{7}`，而一位数下 `\zhnum` 与 `\zhdig` 的输出恒等（都是单个
    汉字），于是「把 digits 路径接成整数路径」这类接线错误零判别力（实测全绿）。选测试
    输入时要问「这个取值下，我要区分的两条路径的输出真的不同吗」——`123` 才使逐位与整数
    读法分开。这与「聚合度量选哪一维要先验证它真的会变」是同一类问题的输入侧版本。
11. **「生成物与源同步」和「生成物本身正确」是两个独立命题**：`check-changelog.yml` 的
    「重新生成 + git diff」新鲜度校验只能证明前者，对确定性缺陷（生成脚本本身有 bug，
    两次生成结果一致但都错）零判别力，需要单独一道校验源内容本身是否正确。

## Follow-up

- recorder 视情况把「测试文件 catcode régime 一次定好，不能在 `\TEST` 参数里切换」补进
  `reference/coding-conventions.md`（可与 #1043 已有的相邻小节合并，避免重复）。
- recorder 把「引擎需求不同必须分 testfiledir」在 `build-and-test.md` 里补上 zhnumber
  这第三个实例（`counter-options01` 三引擎 / `legacy-entry01` 仅 xetex），巩固这条已
  反复验证的规则。
- 若后续再有宏包遇到「不可展开命令是否需要真排版才能验证」的场景，可直接引用本反思
  的四条死路，避免重走弯路。
- recorder 把「可展开报错触发的致命错误使同文件后续 `\TEST` 静默不执行，须核对基线
  段落数」补进 `build-and-test.md` 或 `coding-conventions.md`，并把「写入辅助文件的
  记号名字不能含 `_`」补进 `coding-conventions.md`（与 #1043 的 catcode-in-tokenise
  机制族相邻）。
- recorder 在 `lessons-learned.md` 补一条「protected 命令捕获恒真」的复发实例，并明确
  记录「写下教训不等于已应用到当前改动全部代码」这一元教训。
- recorder 视情况把「生成物同步性校验 ≠ 生成物正确性校验」补进 `lessons-learned.md`，
  与已有的「跑了但什么也没校验的 job」一条相邻但独立列出。
