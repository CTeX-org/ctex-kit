# 反思：#1038 `tabular` 中 CJK 紧邻 `\\` 报 `Improper alphabetic constant`

## 任务

zepinglee 报告：加载 xeCJK v3.10.4 后，`tabular` 里 CJK 后紧接 `\\` 就报错，并指认引入提交 `c8923052`（#1002 的行内公式边界修复）。

## 结论

指认准确。`c8923052` 在 `\xeCJK_CJK_and_Boundary:w` 里新增了一条 group-begin 分支，用来修复 `中{$x$}` 丢失 `\CJKecglue` 的问题。该分支选中的 `\@@_boundary_group_math:w` 用 `n` 型参数把整个花括号组吞掉、再用**隐式**的 `\c_group_begin_token`／`\c_group_end_token` 重新发出。

`tabular` 里 `\\` 已被 `\let` 为 `\@tabularcr`，其替换文本是 `{\ifnum0=`}\fi\@ifstar\@xtabularcr\@xtabularcr`（`latex.ltx:16825`）——LaTeX 用来平衡花括号的经典技巧，要求反引号紧跟**显式**字符记号 `}`。xeCJK 把 `{\ifnum0=`}` 整个吞掉后重发，反引号读到的是隐式 group-end 控制序列，于是 `! Improper alphabetic constant.`。

修法：不再抓参数，改用 `\afterassignment` 加 `\let` 只把那一枚左花括号当作赋值右值吸收（这不开分组），前瞻其后第一个记号判断是否 `$`，再补发一枚隐式左花括号恢复分组。除这一枚花括号外，输入流原样保留，`` `} `` 的相邻关系因此不被破坏。

## 最核心的认知错误：`\protected` 挡不住 XeTeX 的字符类前瞻

我一开始的推理是：`\\` 是 `\protected` 宏，`\protected` 就是为了防止在展开语境里被展开，所以 `\l_peek_token` 应该是宏 `\\` 本身，`\token_if_group_begin:NTF` 该返回假。这个推理错了，而且我花了好几轮探针才接受它错了。

实测（纯 XeTeX、不加载 LaTeX 与 expl3）：

| 输入 | 触发的类别转换 | 前瞻看到的记号 |
|---|---|---|
| `X{q}` | 1→4095 (Boundary) | `begin-group character {` |
| `X\PBRACE`（`\protected\def\PBRACE{{q}}`） | 1→4095 (Boundary) | `begin-group character {` |
| `X\PLET`（`\protected\def\PLET{aq}`） | **1→0 (Default)** | `the letter a` |
| `X\relax` | 1→4095 (Boundary) | `\relax` |

第三行是决定性的：`\PLET` 是 `\protected` 的，XeTeX 却触发了 Default 类——要判断出下一个「字符」是字母 `a`，它必须先把 `\PLET` 展开掉。

**`\protected` 只对 `\edef`／`\write` 一类的完全展开语境有效。** XeTeX 并没有专门的「前瞻」步骤：类别选择就发生在 `main_control` 主循环，`get_x_token` 正常完全展开取记号，`\protected` 在这条路上不起作用。（这个更精确的表述是第二轮盲审逼出来的，见下文「同一个『为什么』我连答错两次」。）

教训：**「这个宏是 `\protected` 的，所以不会被展开」是一个需要按语境验证的断言，不是通用事实。** 语境有两类——完全展开（`\edef`）与逐步展开（`\expandafter`／类别前瞻）——`\protected` 只管前者。判断某个记号在 interchartoks 触发时刻的身份，必须用裸 `\futurelet` 探针实测，不能从宏的属性反推。

## 探针一再给出误导结论

这次探针踩了三个坑，都值得记：

1. **包装 `\xeCJK_CJK_and_Boundary:w` 自身会扰乱 peek 状态。** 我在它开头插 `\iow_term:e` 打印 `\l_peek_token`，得到 `macro=N gbegin=N`——与真实行为相反。原因是我的插入代码本身消费／重置了 peek 状态。
2. **包装 `\token_if_group_begin:NTF` 得到的是 `[\l_peek_token]` 这种无信息输出**，因为 `\token_to_str:N` 打印的是变量名而不是它持有的记号。
3. 真正有效的探针是**裸 `\futurelet` + `\meaning`**，放在被测函数之前、不做任何展开。

教训：**探针的侵入性本身会改变被测语义时，探针结论比没有结论更危险。** 前瞻状态（`\l_peek_token`、`\lastkern`、`\spacefactor`）这类「读一次就可能变」的量，探针必须只读且零展开；拿到反直觉结果时，先怀疑探针，再怀疑代码。

## 在 interchartoks 里抓参数是危险动作

`c8923052` 用 `n` 型参数抓花括号组，本意只是想看「花括号后第一个记号是不是 `$`」。但 interchartoks 的注入点是**别的宏正在执行到一半的位置**——`\@tabularcr` 的替换文本刚吐出第一个 `{`，后面的 `\ifnum0=` 和 `` ` `` 还等着按原样被 TeX 读取。抓参数把这段语法整体搬走再吐回，破坏了记号之间的相邻关系。

`\@@_boundary_group_math:w` 其实只需要**一个记号的信息**，却吞掉了任意长的一整组。

教训：**interchartoks 注入的代码要按「最小吸收」原则写：只吸收判断所必需的那几个记号，其余原样留在输入流里。** 需要看某个记号的身份时，优先用 `\futurelet`／`\peek_after:Nw` 这类不消费的手段；不得不吸收时，用 `\afterassignment` + `\let` 吸收单个记号，而不是用 `n` 型参数吞组。同一条原则也解释了 `\@@_boundary_identity:n` 那条既有注释——「不展开任意可展开控制序列」——本次只是把它从「不展开」推广到「不吞组」。

## 既有测试对本缺陷零判别力，原因在空白

`xeCJK/testfiles/tabular01.lvt` 早就存在，且正是测 `tabular` 里的 CJK。它没能拦住这个缺陷：四行内容每行 `\\` 前都有一个源码空格（`姓名 & 年龄 \\`）。有空格时走的是 CJK→NormalSpace 路径，根本不进 `\@@_boundary_group_math:w`。实测缺陷版下 `tabular01` 全绿。

教训：**测试样例里的空白不是排版细节，它决定了走哪条代码路径。** 写 xeCJK 的用例时，「CJK 紧邻 X」与「CJK 空格 X」是两个必须分别覆盖的象限；同理还有行尾（可能被吃掉的空格）与行内。补用例时我特意把两种写法并列，并在注释里写明既有两项对本缺陷零判别力，避免后来者以为已覆盖。

## 触发面比报告的更窄，也需要实测

报告只给了 `tabular`。我逐个隔离测了 10 种换行/对齐写法（每种单独一个文件——**同一文件里多个用例会因前一个报错而中止，导致后面的假绿**，这一点自己先踩了一次）：

- 失败并被修复：`tabular`、`tabular` 带可选参数 `\\[2pt]`、`tabular` 中 `&` 之后
- 从未失败：`array`、`align`、`pmatrix`、`tabularx`、`array` 宏包的 `>{...}` 列型、`\halign`、`center`、`minipage`

我最初把原因写成「数学与 `\halign` 路径不用这个平衡技巧」——**这条解释是错的**，盲审指出后核实：`\@arraycr` 用的正是同一个技巧（`latex.ltx:16818`）。真实原因是首记号不同：`\@tabularcr` 以显式 `{` 开头，`\@arraycr` 以 `$` 开头。教训：**给「为什么这个不受影响」写解释时，要核对那个「不受影响」的对象本身，而不是从受影响者的特征反面推断。**我当时看到 `\@tabularcr` 有平衡技巧、`array` 没坏，就把「有无技巧」当成了判据，实际上两者都有技巧、差别在首记号。这种「反面推断」得到的筛选规则会把自己的反例列成安全案例，比没有解释更危险。

### 同一个「为什么」我连答错两次

第一轮盲审指出「`\bgroup`/`\egroup` 不触发 Boundary」这条记载是错的。我核实、更正，并写上了原因：「XeTeX 前瞻会展开宏，`\bgroup` 被展开到它 `\let` 的隐式 begin-group 记号」。第二轮盲审指出**这个原因也是错的**——`\bgroup` 是隐式字符记号，本身不可展开（`\meaning` 印 `begin-group character {`，`expandable=N`）。

真实机制（这次对着 `xetex.web` 核了）：类别选择就发生在 `main_control` 主循环，`get_x_token` 正常展开取记号；只有 letter / other / `\chardef` / `\char` 四类走 `check_for_inter_char_toks` 用字符自身类别，其余任何 `cur_cmd` 走 `check_for_post_char_toks`，目标被**硬编码**为 Boundary。所以判据是 **catcode**，`\bgroup` 因 catcode 1 不在那四类里而走 Boundary，与展开无关；`\relax`、`\kern`、`$`、`^`、源码空格同理。

为什么会连错两次：我把上一个结论（`\protected` 不阻止展开）**外推**成了通用解释。那个结论本身是对的，但它解释的是「`\@tabularcr` 为什么会被展开出 `{`」，不解释「`\bgroup` 为什么归 Boundary」——后者根本没有展开这一步。我拿一个刚验证过的机制去套一个表面相似的现象，没重新做实验。

**这与本轮我自己刚写下的那条教训是同型错误**：「不要从受影响者的特征反面推断」。这次是「不要把刚验证过的机制外推到表面相似的现象」。两者的共同点是——**用推理代替了那次本该重做的实验**，而且推理的起点恰好是自己刚刚确认为真的东西，所以格外容易信。

教训：**更正一条错误陈述时，新写上的解释和被更正的事实要分别验证。** 我第一轮验证了「会触发」（做了实验），却没验证「因为被展开」（只是推理）。改文档时事实与解释是两个断言，各自需要证据。

### 探针会破坏引擎的重入保护

顺带记一个坑：在 `\XeTeXinterchartoks` 的 toks 主体里用 `\futurelet` 触碰那个被 `back_input` 退回的触发字符，会破坏引擎的重入保护（非边界那一支没有 `token_type<>backed_up_char` 检查，靠重置 `prev_class` 防重入），导致同一转换无限重复触发——实测日志涨到 3.2 GB。写这类探针要先 `\XeTeXinterchartokenstate=0`。

这也解释了我早期几次「没有任何转换触发」的怪结果：很可能就是这类失控运行的表象，而不是类别赋值没生效。

### 拆文件这件事我做了两次才做对

第一轮盲审让我把附带改善的用例（TEST 5）拆出去，理由是它在缺陷版下不执行。我拆了 TEST 5，**却没检查同一文件里的 TEST 4 是不是同样情况**——它是。第二轮盲审指出这一点，同时指出我在文档里写的「还原后 TEST 3／4 各报 `Improper alphabetic constant`」是假陈述：实测缺陷版日志里 `TEST 4` 出现 0 次。

我当时的动作是「按 finding 说的那一项去修」，而 finding 描述的是一个**类**的问题。判据其实很明确——「这个用例在缺陷版下会中止编译吗」——一旦成立，同文件里它之后的所有用例都要检查。我只检查了被点名的那一个。

教训：**收到一个 finding 时，先判断它描述的是单点还是一类，再决定修的范围。** 具体做法是把 finding 的判据写成一句可检验的话，然后拿它扫一遍同类对象；而不是只修 finding 里出现的那个名字。这与前面「按根因枚举位置」是同一条原则在审查环节的应用。

### 「只修一半」出现了三次，最后我加了一个机械动作

同一个毛病连续三轮：

1. 第一轮拆了被点名的 TEST 5，没检查同文件的 TEST 4 是否同类。
2. 第二轮更正「TEST 3/4 各报错」这句假陈述时，只改了决策文档，漏了 `build-and-test.md`。
3. 同一轮把计数从 115 改成 116——而 116 是上一提交的数字，本提交自己又加了一个文件，正确值是 117。

三次的共同点是**我改的是「finding 里出现的那一处」，而不是「这条错误说法在仓库里的所有实例」**。第三次尤其说明问题：计数这种东西天然会出现在多个地方，而我连自己这次改动会不会让它再变一次都没算。

最后加的动作很土但有效：改完任何事实性陈述后，用 `grep` 扫一遍该说法的所有变体（计数扫一遍、指针扫一遍），并把「历史记述」与「当前事实」分开——前者保留原值（如 #1029／#1037 文档里的 115／116 是当时事实），后者必须统一。这一步花不到一分钟，而它拦住的东西前面已经漏了三次。

教训：**事实性陈述的更正要以「全仓该说法的所有实例」为单位，不是以 finding 指出的那一处为单位。** 计数、页数、文件名、函数名这类会重复出现的事实尤其如此；改动本身会不会让计数再变，也要一并算进去。

## Promotion Candidates

- **XeTeX 的 interchar 类别由「展开后那个不可展开记号的 catcode」决定**：letter/other/`\chardef`/`\char` 用字符自身类别，其余固定为 Boundary。`\protected` 不阻断该展开；判据是 catcode 而非显式/隐式。
- **更正一条错误陈述时，新写上的解释与被更正的事实要分别验证**——我这次验证了「会触发」却只推理了「为什么」，于是连错两次。
- **不要把刚验证过的机制外推到表面相似的现象**；起点是自己刚确认为真的东西时尤其危险。
- **interchartoks 的 toks 主体里用 `\futurelet` 会破坏引擎重入保护**，导致同一转换无限重复；探针需先关 `\XeTeXinterchartokenstate`。
- **interchartoks 注入的代码遵循最小吸收原则**：能 `\futurelet` 就不消费，必须吸收时用 `\afterassignment` + `\let` 吸收单个记号，不用 `n` 型参数吞组。
- **前瞻类状态的探针必须只读零展开**；反直觉结果先怀疑探针。
- **测试样例的空白决定代码路径**，「紧邻」与「空格分隔」是两个独立覆盖象限。
- **会中止编译的用例必须各自独占文件**，否则同文件后续用例在缺陷版下不执行，是空转的门禁；这是测试设计约束而非排查提示。
- **收到 finding 时先判断它是单点还是一类**，把判据写成可检验的话再扫一遍同类对象。

## 相关

- Issue：#1038；引入点 `c8923052`（属 #1002）；受影响版本 v3.10.4。
- 实现：`xeCJK/xeCJK.dtx` 的 `\@@_boundary_group_math:w`、`\@@_boundary_group_math_peek:`、`\@@_boundary_group_math_branches:`。
- 测试：`xeCJK/testfiles/tabular01.lvt`（新增 TEST 3）、`tabular-cr01.lvt`、`boundary-bgroup01.lvt`（后两者独立成文件的理由见上文）。
- 相关决策：[[../decisions/1038-tabular-cr-group-peek.md]]、[[../decisions/1002-inline-math-boundary-oracle.md]]。
