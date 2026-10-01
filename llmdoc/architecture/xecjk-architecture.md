# xeCJK 架构详解

本文档从整体到局部介绍 xeCJK 的设计原理与实现架构。

## 定位与职责

xeCJK 是 XeLaTeX 下的中文排版引擎，负责：

1. CJK 与西文使用不同字体
2. CJK 字符间自动忽略源码空格
3. 全角标点的压缩与挤压样式
4. CJK 与西文字符之间自动插入间距

它不是一个独立的排版系统，而是构建在 XeTeX 的 interchar token 原语之上的字符间距与字体控制层。在 ctex 体系中，ctex 是统一用户入口，xeCJK 是 XeTeX 后端实现。

## 源码组织

核心几乎全部集中在 `xeCJK/xeCJK.dtx`（约 16000 行），通过 docstrip 生成：

| 产物 | 标签 | 职责 |
|------|------|------|
| `xeCJK.sty` | `package` | 主宏包 |
| `xeCJK.cfg` | `config` | 默认配置 |
| `xeCJKfntef.sty` | `fntef` | 下划线/着重号等文字效果 |
| `xeCJK-listings.sty` | `listings` | listings 宏包兼容层 |
| `xunicode-addon.sty` | `xunicode` | xunicode 符号补充 |

## 核心机制：interchar token

xeCJK 的一切行为都建立在 XeTeX 的 **interchar token 机制**之上。

### 工作原理

XeTeX 允许将每个 Unicode 字符归入一个「字符类」（character class）。当两个相邻字符的类别发生变化时，XeTeX 自动在它们之间插入预定义的 token 序列（`\XeTeXinterchartoks`）。

xeCJK 利用这一机制：
- 在 CJK→西文 边界插入 `\CJKecglue`（中西文间距）
- 在 CJK→CJK 边界插入 `\CJKglue`（字间距）
- 在 CJK→标点 边界触发标点压缩逻辑
- 在进入 CJK 区域时切换到 CJK 字体

### 字符分类体系

xeCJK 定义了以下字符类：

| 类别 | 说明 | 典型字符 |
|------|------|----------|
| `Default` (0) | 西文一般符号 | abc123 |
| `CJK` | CJK 表意符号 | 汉字ぁぃぅ |
| `FullLeft` | 全角左标点 | （《：" |
| `FullRight` | 全角右标点 | ，。）》" |
| `HalfLeft` | 半角左标点 | ( [ { |
| `HalfRight` | 半角右标点 | , . ? ) ] } |
| `NormalSpace` | 前后保持原始间距 | - / \\ |
| `Boundary` (4095) | 边界（空格等） | 空格 |
| `CM` | 组合标识 | 异体字选择符 (IVS) |
| `HangulJamo` | 旧朝鲜文字母类，仅保留兼容入口，不再分配字符 | / |
| `HangulJamoL/V/T` | 朝鲜文字母初声/中声/终声 | ᄻ / ᆟ / ᇫ |
| `CJStarter` | 严格模式下禁止出现在行首的日文小假名等 | ゃっ |
| `PoZheHao` | 支持合字的破折号（opt-in，#382） | U+2014/U+2015 |

XeTeX 0.99994+ 支持最多 4096 个字符类；`Boundary` 固定为最大编号（4095）。

上表"典型字符"为静态举例，非完整枚举。`FullLeft`/`FullRight`/`HalfLeft`/`HalfRight` 的实际成员会随 `LatinPunct` 选项（#389/#431，见下文标点压缩系统一节）动态增减：中西文共用码位的弯引号/间隔号/省略号在 `HalfLeft`/`HalfRight` 与 `FullLeft`/`FullRight` 之间切换归属。

### 特殊 interchar 类：零注入、音节状态机与行首禁则

`PoZheHao` 仍是单类零注入模式：类内不插入任何 interchar token，类间关系复制 `FullRight`，让连续 U+2014 可触发 OpenType 合字；它由 `PoZheHaoLigature` 显式启用，避免不支持合字的字体出现空隙。

#158 证明单个 `HangulJamo` 零注入类不足以表达朝鲜文：它能保持分解音节内部 shaping，却无法区分相邻音节边界，因而会吞掉本应存在的 `CJKglue`。当前实现按 Unicode 17 `Hangul_Syllable_Type` 拆成三类：L 为 `1100..115F`、`A960..A97C`，V 为 `1160..11A7`、`D7B0..D7C6`，T 为 `11A8..11FF`、`D7CB..D7FB`。三类对外复制 `CJK` 转移；仅 UAX #29 的音节延续对 L→L、L→V、V→V、V→T、T→T 清空 interchar toks，其余 L/V/T 组合保留 CJK→CJK 行为。因此音节内连续 shaping，T→L 等音节边界恢复 `CJKglue` 和断行机会。旧 `HangulJamo` 类仅为用户代码兼容保留，不再接收默认字符。

`xeCJK-listings` 对 L 计一个宽度 2 的 CJK 单元，对 V/T 走宽度 0 的组合字符路径；一个分解音节因此与一个预组 Hangul 音节等宽，相邻分解音节仍保留配置的 CJK 字距。

#165 的 `CJStarter` 不是零注入类：它必须复制普通 `CJK` 字距，只在进入该类前增加 `\xeCJK_no_break:`。公开选项 `CJLineBreak=normal|strict` 默认 `normal`，保持历史上把 Unicode `Line_Break=CJ` 当作 `CJK` 的行为；`strict` 把 Unicode 17 CJ 集合改归 `CJStarter` 并插入 penalty 10000。局部布尔 `\l_@@_CJ_strict_bool` 与分组局部的 `\XeTeXcharclass` 状态同步，`\xeCJKResetCharClass` 后按当前选项恢复严格分类。

`FullRight→CJStarter` 必须把 penalty 放在 `\@@_punct_glue:NN` 之前，否则标点胶已经提供断点。该转移封装为 `\xeCJK_FullRight_and_CJStarter:`，并在 `xeCJKfntef` 的 `\@@_ulem_initial:` 交换表中映射到 `\@@_ulem_FullRight_and_CJStarter:`；新增或覆写 CJK 转移时，若 fntef 依赖交换命名 helper 来重写 glue/标点路径，就不能只内联等价 token。`jamo-cj01.lvt` 用 hook 断言严格模式下 `\CJKunderline{。ゃ}` 确实进入 fntef 专用转移。

### 类别间转换矩阵

xeCJK 在 `xeCJK.dtx:3140` 定义了完整的 9×9 类别转换矩阵。核心转换规则：

- **进入 CJK 区域**（`Default/HalfLeft/HalfRight/NormalSpace → CJK`）：开启 CJK 分组、切换字体、输出字符
- **离开 CJK 区域**（`CJK → Default/HalfLeft/HalfRight/NormalSpace`）：关闭分组，后续在 `Boundary → Default` 恢复 ecglue
- **CJK 之间**（`CJK → CJK`）：插入 `\CJKglue`
- **CJK ↔ 标点**（`CJK → FullLeft/FullRight`）：触发标点压缩
- **经过 Boundary**（`CJK → Boundary → Default`）：通过标记 kern 记录边界状态，延迟恢复间距

### 外部分配字符类的 `Others` 兼容层（#336）

xeCJK 在导言区结束时比较 XeTeX allocator 与自身已登记类，发现其他宏包或用户在加载 xeCJK 后新建的 interchar class 后，逐个调用 `\@@_set_others_toks:n`。该函数把外部类临时映射为 `Others`，对每个 `\g_@@_CJK_class_seq` 成员复制 `NormalSpace` 模板，并把用户已定义的 `external ↔ Default` tokens 传播到对应的 `external ↔ CJK-class` 转换；空缺的 Boundary 转换也从 Default 模板补齐。

这是一层兼容机制，不是“任意类继承任意模板”的公开 API。#336 的 URL 场景只需在导言区结束前定义 slash class 与 `slash → Default` 的断行 action，CJK 方向会自动派生；若到正文期才赋 transition，已经错过传播时机。调查既要检查现有能力，也要验证加载顺序：旧 MWE 中手写的五行内部转换不是概念上必需，但在其原始正文期赋值顺序下确实无法被导言区末尾机制看到。决策见 [[../memory/decisions/336-external-interchar-class-others]]。

### 逐字符装进盒子的变换不是局部可加的 class hook（#347）

#347 的 plain XeTeX 原型证明 interchar transition 可以打开盒子、捕获字符并交给旋转或基线移动函数；迁移到 xeCJK 后，所有可能离开特殊类的边界都必须闭合盒子，包括同类→同类与特殊类→`FullRight` 等路径。只实现 `CJK`/`Boundary` 两侧会把相邻同类字符合进一个盒子，并在后接全角标点时留下未闭合分组。

更根本的边界是处理单位：逐个 code point 装进盒子会切断 IVS、Hangul Jamo 和其他 OpenType shaping 序列，hbox 还会遮蔽基于 `\lastkern` 的边界标记。该原型不在当前状态机上产品化；若未来整体重构输入、fallback、标点和节点生成，应把“捕获 shaping 后的字形簇并统一变换”作为正式流水线阶段，而不是继续补 class pair。决策见 [[../memory/decisions/347-boxed-glyph-transform-prototype]]。

### CJK→Boundary handler（`\xeCJK_CJK_and_Boundary:w`）

`\XeTeXinterchartoks` 中 CJK→Boundary 的处理函数。Boundary class 在新引擎是 **4095**、0.99993 之前的旧引擎是 255（xeCJK 按引擎版本分支，见 `xeCJK.dtx` 的 `{ Boundary } { 4095 }`）；注意 4096 是「忽略」类别而非边界类别，属于它的字符对整个机制完全不可见。

Boundary 不是一份可枚举的字符清单，而是「**下一个不可展开记号不是 letter/other 字符**」的统称——完整规则见下一节。常见触发者包括源码空格、显式 `{` / `}`、`\ `（control space）、`$`、`^`、`\relax`、`\kern`、`\unskip`、`\hbox`、`\penalty`、`\vrule`、`\discretionary`，以及 `\bgroup` / `\egroup`。

曾长期记载「`\bgroup` / `\egroup` 是控制序列而非 catcode 1/2 字符，因此**不**触发」——这条是错的，实测 `X\bgroup` 触发 1→4095。但更正后的原因也不是「它被展开成了花括号」：`\bgroup` 是 `\let` 出来的隐式字符记号，本身不可展开（`\meaning` 打印 `begin-group character {`）。它走 Boundary 只是因为 catcode 1 不属于下一节那四个分支。

### 类别是怎么定下来的（实测 + `xetex.web` 对照）

上面那份清单是现象，规则本身要按引擎实际做法理解。XeTeX **没有**专门的「前瞻」步骤：类别选择发生在 `main_control` 主循环——`big_switch` 处用 `get_x_token` 取下一个记号（这是**普通的完全展开取记号**），只有取到的记号落在 `hmode+letter`、`hmode+other_char`、`hmode+char_given`、`hmode+char_num` 四个分支时才进入 `main_loop` 并调用 `check_for_inter_char_toks`，用该字符的类别作为目标；其余任何 `cur_cmd` 走 `othercases`，调用 `check_for_post_char_toks`，目标被**固定写成** `char_class_boundary`。

因此规则是：

> 按常规规则展开，直到得到一个不可展开的记号。若它是**字符记号**（显式或隐式皆可，catcode 为 letter / other，或由 `\chardef` / `\char` 产生），就用该字符的类别；否则一律用 Boundary（4095）。类别 4096 的字符被完全跳过。

两条推论，都有决定性实验：

- **`\protected` 不阻断这个展开。** `b` 属类别 3、`a` 属类别 2 时，`\protected\def\PB{b}` 与普通 `\def\UB{b}` 在 `X\PB`／`X\UB` 下都给出 1→3，与基线 `Xb` 一致；三层嵌套（protected→普通→protected→`b`）同样 1→3。`\protected` 只对 `\edef` / `\write` 一类的记号列表展开有效，对排版流程里的 `get_x_token` 无效。
- **判据是 catcode，不是「显式还是隐式」。** `\let\iLetter=a` 得 1→2、`\let\iOther=!` 得 1→2——隐式本身不构成障碍；反过来显式 `$`（cat 3）、`^`（cat 7）、源码空格、显式 `{` 与 `\let\myLbrace={` 全部走 Boundary。`\bgroup` 走 Boundary 是因为它的 catcode 是 1，不在那四个分支里，与它是隐式记号无关。

所以 Boundary class 实际上是「**下一个不可展开记号不是 letter/other 字符**」的统称，触发它的远不止花括号：`\relax`、`\kern`、`\unskip`、`\hbox`、`\penalty`、`\vrule`、`\discretionary`、`$`、`^`、源码空格都会。

#1038 正是这条规则的后果：`tabular` 里 `\` 被 `\let` 为 `\@tabularcr`，`get_x_token` 展开它（`\protected` 无效），得到替换文本首记号——显式 `{`，catcode 1，于是归 Boundary 并注入 CJK→Boundary handler，而 handler 里的 `\l_peek_token` 就是那个 `{`。

**不要用 `\futurelet` 反推「引擎当初看到了什么」。** 引擎命中 toks 前已经 `back_input` 把触发字符退回，所以 toks 内的 `\futurelet` 看到的是那个被退回的记号；宏展开的情形下它看到的是展开**之后**的结果（`X\PLET` 看到 `the letter a`，原始 `\PLET` 已不在）。要确定规则必须直接观测「触发了哪一对 `N M`」。另注：在 toks 主体里用 `\futurelet` 触碰被退回的字符会破坏引擎的重入保护，导致同一转换无限重复触发——写探针时应先关掉 `\XeTeXinterchartokenstate`。

handler 在执行时会 peek 下一个 token：
- 若 peek token 是 catcode 2（`}`）：说明当前正在退出一个 TeX 分组（如 `前{中} 后` 中的 `}`），分组结束后会恢复局部变量（包括 `\l_peek_token`），因此必须在 `\@@_boundary_group_end:n` **之前**设置 `\g_@@_glue_check_pending_bool`，以确保后续的 inter-word glue 被正确识别
- 若 peek token 是控制序列（如 `\ `）：不设置 boolean，区分于 catcode 2 的情况
- 若 peek token 是 catcode 1（`{`）：走 `\@@_boundary_group_math:w`，用于识别「花括号包住行内公式」（`中{$x$}`，见 #1002）

### 最小吸收原则（#1038）

interchartoks 注入的代码执行在**别的宏正在执行到一半**的位置：注入点之后的记号可能是某个宏替换文本里尚未被 TeX 读取的语法片段。因此这里的代码只能吸收判断所必需的最少记号，其余原样留在输入流里。

`\@@_boundary_group_math:w` 曾用 `n` 型参数把整个花括号组吞掉、再用隐式 `\c_group_begin_token ... \c_group_end_token` 重新发出，只为看组内首记号是不是 `$`。这在 `tabular` 中出错（#1038）：被吞掉的 `{\ifnum0=`}` 是 LaTeX 平衡花括号技巧的一半，该技巧要求反引号紧跟**显式**字符记号 `}`，重发的隐式 group-end 不满足，报 `Improper alphabetic constant`。

现在改为用 `\afterassignment` + `\let` 只把那一枚左花括号当作赋值右值吸收（实测 `\currentgrouplevel` 不变，不开新分组），再 `\peek_after:Nw` 判断下一个记号，最后补发一枚隐式左花括号恢复分组，由源码原有的 `}` 闭合。

写这一层代码时的选择顺序：能用 `\futurelet` / `\peek_after:Nw` 不消费就不消费；必须吸收时用 `\afterassignment` + `\let` 吸收**单个**记号；不要用 `n` 型参数吞组，也不要预展开任意可展开控制序列（后者是 `\@@_boundary_identity:n` 那条既有约束，#1038 把它从「不展开」推广到「不吞组」）。

## 边界恢复状态机

这是 xeCJK 最复杂的子系统。直接相邻字符可由 XeTeX interchar class 转换决定间距；一旦中间出现分组、命令、盒子、math 或 whatsit，恢复链还必须保存边界信息、观察命令的实际输出类别，并在边界节点被遮住后重建等价间距。

### 基础 marker 与 glue 恢复链

`\xeCJK_make_node:n` 用一对微小 kern 编码最近的可见边界。当前恢复链识别 `CJK`、`CJK-space`、`CJK-widow`、`default`、`default-space`、`normalspace`、`math`、`math-space` 和 `math-space-frozen`；#972 曾引入的 `hyperref-default` 已由 annotation stream 吸收并删除。`\g_@@_last_node_tl` 保存语义状态；`\lastkern` / `\lastnodetype` 提供当前列表上的节点证据。两者必须一致，不能只凭可能陈旧的全局 tl 恢复间距。

CJK→Boundary 时，`\@@_boundary_group_end:n` 在仍处于正确 CJK 字体上下文时缓存 `\CJKecglue` 到 `\l_@@_ecglue_skip`；后续恢复使用缓存值，不在命令内部的新字体或字号下重新测量。`\@@_boundary_reserve_space:` 只留下 `CJK-space` marker，不抢先输出会遮蔽 marker 的普通 glue。

Boundary→CJK 的 `\xeCJK_check_for_glue:` 与 Boundary→Default 的 `\xeCJK_check_for_ecglue:` 都先读取 xeCJK 写入的 marker，再处理紧跟在 marker 后面的源码词间 glue。只有显式分组结束或 capture 重放 CJK marker 时，才会设置 `\g_@@_glue_check_pending_bool`，允许下一次恢复过程检查源码空格；颜色、fntef 等旧的专用 pending 已删除。

Boundary→Default 方向由 `\@@_recover_ecglue_source_space:` 暂时移除末尾的候选 glue，再检查其下方节点。候选必须是 finite、带 shrink、自然宽度等于当前词间空格，并且下方确有 `CJK` / `CJK-space` / `CJK-widow` marker；命中后才用缓存的 `\CJKecglue` 替换并清除 pending，未命中则原样还回。该路径补齐了历史上只在 Default→CJK 方向处理源码空格的非对称缺口。

任意 whatsit 或 hlist 都不足以说明前一个可见字符属于哪一类。已知不可见命令使用 transparent capture，盒子命令使用 box/wrapped-box，URL 与 codedoc meta 使用完整 stream；基础恢复链不再看到某种节点就猜测 `\g_@@_last_node_tl`。#803 证明了“看到 whatsit 就信任全局 tl”会在引用内部错误插入 ecglue。

### 命令边界的输出等价契约（#491/#992）

命令包装前后的间距以命令实际排出的首、尾可见字符类别为准，不以命令名、参数写法或历史补丁为准。西文和数字按 Default 处理；CJK 输出按 CJK 处理；混合输出的左右两端分别判断；无可见输出的命令应对相邻可见字符透明。这里的“相同可见内容”还包括排版形式：命令内的行内公式要与直接公式比较，不能换成西文字母作为 oracle。公式测试分别称为“中文—公式—中文”和“西文—公式—西文”，不与普通数字合并。

直接输入是唯一语义 oracle。`10` / `01` 分别表示只在左侧 / 右侧边界有源码空格：

| 源码空格 | CJK–西文–CJK | 西文–CJK–西文 |
| --- | --- | --- |
| `11` | `中文 English 中文` | `English 中文 English` |
| `01` | `中文English 中文` | `English中文 English` |
| `10` | `中文 English中文` | `English 中文English` |
| `00` | `中文English中文` | `English中文English` |

纯 CJK 输出还要分别以 `中文 中文 中文` 和 `中文中文中文` 为有、无源码空格 oracle。理想覆盖是“实际输出首尾类别 × 相邻字符类别 × `00/10/01/11` × `xCJKecglue=false/true`”的全部可表达组合，候选和 oracle 使用相同的选项值。每个选项值还要分别运行默认间距和可区分间距。若引擎机制确实无法区分某些输入，最低保证仍包括有源码空格的中西文切换（如 `中文 \foo{en} 中文`）和无源码空格的纯 CJK（如 `中文\foo{中文}中文`）；其余限制必须给出机制证据与稳定 workaround。

#491 的历史回归通常只覆盖一个命令的一个单元，不能推出整类完成。#992 取代 #491 作为长期状态入口。PR #999 的原型矩阵在固定提交上全绿，但当时只覆盖 `xCJKecglue=false`。2026-07-21 补测 `true` 后发现嵌套盒子、中西混合内容和 `\null` 边界仍有差异，形成 #1003；PR #1005 通过恢复外层 `spacefactor` 和 post-transparent 的有界节点后缀修复这些普通命令单元。该 PR 合并为 `master` `8007e4df` 后，16 个驱动确认四种配置的普通命令均为 320／320 通过，#992 活表第 7、9、15 行随即改为全绿。#992 的活表只记录已合并实现的状态：合并前可在 PR 上保存拟更新预览，不能提前把修复结果写回 issue 活表。

`xCJKecglue=<glue>` 的键处理会同时设置 `CJKecglue=<glue>` 并启用 `xCJKecglue`，因此语义上等价于显式写出这两项设置。测试用一个独立等价性断言保护这个入口，不为它复制完整矩阵。`CJKspace` 影响源码空格的另一条路径，作为独立维度保留，不与 `xCJKecglue` 做全组合。

对行内公式还要保留 `xCJKecglue` 的既有语义：`false` 让源码空格保持普通词间空格，`true` 才把它换成 `CJKecglue`。外层字体、颜色或盒子命令不能改变这项选择。`$x$`、`\(x\)` 和 `\ensuremath{x}` 已接入同一个 `math` 边界类别。测试必须分别检查左右边界，避免一侧多出的间距与另一侧缺少的间距在总宽度中互相抵消。完整决策和当前验证范围见 [[../memory/decisions/1002-inline-math-boundary-oracle]]。

若命令参数以“公式＋源码空格”结束，框架还要区分参数内空格是否继续参与外层断行。普通 `stream` 直接把正文写入外层列表，因此使用 `math-space` marker：参数内的空格仍留在外层列表，marker 前的两对零净宽 kern 分别保存这枚实际空格的伸长量和收缩量（stretch/shrink）。右侧为 CJK 且 `xCJKecglue=true` 时，外层补偿的自然宽度为“`CJKecglue` 自然宽度减入口字体的普通词间距自然宽度”，弹性部分则保留 `CJKecglue` 的伸缩量并扣除这枚实际空格已有的伸缩量。命令内部换字体造成的空格自然宽度差仍属于命令本身，不由边界补偿抹平。

`box`、`wrapped-box` 和 `stream-ulem` 中的参数内空格已经冻结在盒子或装饰内容内，不参与外层断行，因此使用 `math-space-frozen` marker。外层补偿完整保留 `CJKecglue` 的伸长量和收缩量；自然宽度只补 `max(CJKecglue 自然宽度 - 入口普通词间距自然宽度, 0pt)`。目标间距比普通词间距小时不生成负 glue，避免把后续 CJK 文字拉进框线或下划线等装饰范围。两种 marker 都不移动参数内空格；紧接命令的另一枚源码空格仍按连续空格处理，显式 glue 继续由既有词间空格形状检查保护。

普通 stream 的 `math-space` 还有一项物理相邻要求：真实参数空格必须仍紧挨 marker，二者之间只能有 marker 自己用来保存伸缩量的 kern 对。transparent 命令写出的颜色 special，或 post-transparent 命令留下的零尺寸 hbox，都会把空格与 marker 隔开；含有同一不可见命令的直接公式也不会跨过该节点恢复间距，因此框架必须让 marker 过期，不能把补偿间距单独放到节点之后。capture 入口会保存 marker 前真实空格的 skip；transparent 结束时，只有当前列表末尾仍是同值 glue，才重放 `math-space`。

post-transparent 还要处理 marker 与零尺寸盒子之间已有一枚待检查 glue 的情况，例如 `\textnormal{$x$ }\hskip7pt\null`。探测过程会暂时取下 7pt glue 才看到 `math-space`；marker 过期时必须先把这枚 glue 放回，再放回 `\null`，保留直接 oracle 的“真实空格、显式 glue、零尺寸盒子”顺序。其他 marker 不受这一例外影响，仍沿用 #1003 的“盒子、marker、glue”后移顺序。

这枚候选 glue 还必须是有限阶：`\@@_boundary_post_transparent_relocate_glue:` 搬运「marker + 候选 glue」后缀前先用 `\skip_if_finite:nTF` 判断，`\hfill`／`\hfil` 这类无限阶（fil/fill）填充 glue 一律排除、不参与搬运，直接把零尺寸盒子放回原位，保持 marker、glue、盒子的原有相邻顺序（#1085）。这与上一段的 math-space 例外是两个独立维度：那一条管 marker 与零尺寸盒子之间“已有 glue”时的相邻关系判断，这一条管候选 glue 本身的伸缩阶数；这项判断不能收紧成下文「右侧源码空格的机制边界」一节 `\@@_skip_if_interword:N` 那样的 finite+shrink+等宽词间空格判据，否则会误伤本节上面 math-space 场景里无 shrink 的显式 `\hskip`。详见 [[../memory/reflections/1085-hfill-post-transparent-relocate]]。

### ulem 集成层的正文必须以字面记号留在替换文本里（#1026）

`\UL@on` / `\UL@onin` 把正文交给 `ulem` 之前，正文的展开方式本身是一条独立于上面 `math-space` 逻辑的约束：`ulem` 自己扫描正文，按源码空格把它切成固定宽度的装饰片段盒子（每个片段各自一个盒子）。正文只要经过宏参数间接展开，西文词右侧由边界恢复链补出的 `\CJKecglue` 就会落在片段盒子**内部**，其收缩量被盒子固化，无法参与外层段落的断行决策；行尾因此可能溢出右边距。

因此 `\UL@on` / `\UL@onin` 先用 `\@@_boundary_if_ulem_math_reorder:nTF` 判断正文语法：只有当正文以“公式尾＋尾随源码空格”结尾时（即 #1002 需要重排空格才能让确认代码看到公式节点的那一种情况），才用 `\@@_boundary_ulem_math_tail_space:nnn` 重排正文；其余全部情况都保持 `\xeCJK_ulem_left: #1` 的字面展开，把原样的 `#1` 直接留在 `\UL@on` 的替换文本里。原先统一处理两种情况的 `\@@_boundary_ulem_math_body:n` 已被这两个函数取代。

重排路径本身也受同一条约束。它起初仍把正文交给辅助宏的参数，于是在这条路径上完整保留了同一个缺陷：正文只要既含西文词、又以“公式＋尾随空格”结尾，实测溢出量与修复前相同。现在改为先把去掉尾随空格的正文与两端固定记号拼进 `\l_@@_ulem_body_tl`，再用 `\exp_args:NV` 一次展开到 `ulem` 的参数位置，使记号与直接书写 `#1` 等价；`\tl_use:N` 会让正文晚一层展开，不能替代。两端的 `\xeCJK_ulem_left:`／`\xeCJK_ulem_right:` 只有 `\UL@on` 需要，因此由拼装函数作为前后缀参数接收。

两者的分工边界：#1002 的 `math-space`／`math-space-frozen` 解决的是“确认末尾公式候选时空格暂时遮住公式节点”这一种局部重排需求；本节的字面记号约束是更基础的默认规则——`ulem`／`xeCJKfntef` 等自行扫描正文、切片并装进盒子的机制，只应对正文使用字面记号，确需重排某种特殊语法时，重排本身也必须把正文以字面记号送进参数位置。

已接受的既有限制（不在 #1026 修复范围）：调用处把正文写成宏再传入，例如 `\CJKunderline{\BODY}`，收缩量同样进不了外层——宏体在 `ulem` 扫描期间才展开，触发的是同一条“正文经间接展开→收缩量固化在片段盒子内部”的机制，但成因是用户写法而不是替换文本本身。实测发布版本（系统 TeX Live）对这种写法同样得到修复前的溢出宽度，说明它是发布版就有的既有限制而非本次回归，不在修复范围内。

### 西文词前的 ecglue 需要可搬运通道（#1037）

“收缩量固化在片段盒子内部”这条机制在西文词的**两侧各有一处**，#1026 只修了词后那半，词前那半直到 #1037 才修；两者的成因不同，修法也不同。

词前的路径与正文展开方式无关，即使正文是字面记号也会发生：`\@@_ulem_CJK_and_Boundary:w` 用 `\xeCJK_peek_catcode_ignore_spaces:NTF` 前视时吃掉了源码空格，随后 `\@@_ulem_group_end:n` 依次执行 `\UL@stop`（关闭并输出上一个片段盒子）与 `\UL@start`（新开一个盒子），于是 `CJK-space` marker 落在**新盒子内部**。等到西文字符触发 Boundary→Default 转换时，`\@@_check_for_ecglue_aux:` 在该 marker 处补出 ecglue，这枚 glue 也就固化在盒子内部。

注意这条路径不经过 `\CJKecglue`：它直接 `\skip_horizontal:N \l_@@_ecglue_skip`，而 ulem 钩子只重定义 `\CJKecglue`，所以 `\@@_ulem_glue:n` / `\xeCJK_ulem_hskip:n` 一族全部被绕过。没有源码空格时（`虚室hello`）走的才是 `\CJKecglue`，因而本来就落在外层、对称无恙。

修法是把这两处（`CJK`/`CJK-widow` 分支与 `CJK-space` 分支）改成经入口 `\@@_use_ecglue_skip:` 输出。该入口在 `xeCJK` 主体里的默认实现就是原来的 `\skip_horizontal:N`，由 `xeCJKfntef` 加载时改写为「先判断装饰 stream 是否活动，活动才经 `\@@_ulem_glue:n` 输出」——后者先用 `\UL@stop` 关闭盒子、把间距画成外层列表上的 `\leaders`、再用 `\UL@start` 新开一个盒子，收缩量因此回到行上。

三个实现约束：

- **改写必须自己判断是否在装饰中，不能只依赖 `\@@_ulem_glue:n` 自带的 `\xeCJK_if_ulem_patch:TF`。** 那个守卫的判据只是 `\ ` 的含义是否等于 `ulem` 保存的 `\LA@space`：它能识别 `ulem` 自己造成的变化，却无法区分「不在装饰中」与「在装饰外但 `\ ` 被别的宏包改过定义」。因为 `\@@_check_for_ecglue_aux:` 是所有中西文边界都会走的通用路径，一旦在装饰外取到真分支，就会在没有 `\UL@box` 打开的列表里执行 `\UL@stop`，报 `Too many }'s`；`nath`、`morehype` 等重定义 `\ ` 的宏包会让**不含任何装饰命令**的 `中 abc 文` 直接报错。改写因此先测 `\l_@@_ulem_stream_started_bool`——它由 `\@@_ulem_stream_begin:` 置真、`\@@_ulem_end:` 置假。**但该布尔单独还不够**：行内公式里的装饰命令经 `\UL@onmath`／`\UL@onin` 结束，不走 `\@@_ulem_end:`，所以同一个公式内装饰命令之后布尔仍为真、而片段盒子其实已经关闭；此时再叠加 `\ ` 被重定义，仍会执行悬空的 `\UL@stop`（`$\CJKunderline{中}\mbox{中 abc 文}$` 配 `nath`）。因此守卫是两个条件的合取：布尔为真**且** `\UL@start` 已被 `\let` 成 `\@empty`（后者表示片段盒子确实处于打开状态；`\@@_ulem_exp_stop:w` 已用同一判断）。实测三点区分：文档层 `f/f`、装饰内 `T/T`、公式内装饰命令之后 `T/f`——只有第三种会被布尔单独判断漏掉。这条区别在 `base` 上不成立是因为 `\@@_ulem_glue:n` 原先只挂在装饰内部**局部**重定义的 `\CJKglue`／`\CJKecglue` 上，作用域随分组失效；接到全局有效的通用路径后，弱守卫才变成可触发的缺陷。

- 默认实现必须留在主体、改写放在 `xeCJKfntef`。`\@@_check_for_ecglue_aux:` 是所有 CJK-西文边界都走的通用路径，而 `\@@_ulem_glue:n` 定义在 `xeCJKfntef` 里；在主体直接引用它会让不加载该子包的普通文档报 `Undefined control sequence`。
- 不能改用 `\@@_boundary_use_ulem_glue:nn`（#1091 前签名为 `:n`，现在第一个参数是 capture 层号）。它放的是裸 glue，节点深度上同样把收缩量搬到外层，但不画装饰线，会在西文词前留下可见空隙（300dpi 实测断开 7px）。

按深度统计同一段落的 1.11pt ecglue（`depth>=3` 为盒子内部、`depth2` 为行上可用）：#1026 缺陷版 16／0，发布版 v3.10.3 与只修词后时同为 8／6，两半都修好后 0／14。

### 同一根因共四处补 ecglue 的地方（#1037）

Boundary→Default 恢复链上补词前 ecglue 的地方不止一处，四处（共 6 个分支）都必须改用 `\@@_use_ecglue_skip:`：

| 位置 | 何时走这条路 |
|---|---|
| `\@@_check_for_ecglue_aux:` | 源码空格被前视直接吃掉（`虚室 hello`） |
| `\@@_recover_ecglue_source_space_success:` | 空格先被暂存、随后确认可恢复 |
| `\@@_check_for_glue_auxi:` 的 `default`／`math` 分支 | 西文词被字体／颜色声明隔开（`虚室 \color{red}hello`），或被 `\mbox` 等包住 |
| `\xeCJK_check_for_glue:` 的 `\@@_if_last_math:` 真分支 | 公式紧接 CJK、中间无源码空格（`$x$中文`） |

这四处是用「直接在每个裸调用行插桩、以 31 种装饰写法编译」的方式穷举出来的。**不要用「包装函数入口」的探针**：它不区分分支，会把 `\xeCJK_check_for_glue:` 的 math 分支误判为不可达（本任务正是这样漏掉了它，由第四轮盲审指出）。其余 10 处裸 `\skip_horizontal:N` 在同一实测中一次都没执行，可以保留。

### 显式分组包住西文词的收缩量（#1067，已修复）

`\CJKunderline{虚室 {hello} 生白}` 与 `\textbf{hello}` 这类写法，花括号是在词内容交给
`\UL@start` 之后、在片段盒子**内部**才展开成分组的（实测两种写法切出的片段盒子数量相同，
`ulem` 的切分点不受花括号影响）。边界检测因此在盒子内部、且在用户分组内触发；`\@@_ulem_glue:n`
的 group tag 守卫比对保存的 `\l_@@_group_tag_tl`（`T1L4`）与当前的 `\c_@@_group_tag_tl`
（`T1L5`）不相等，走 else 分支——这一步是直接原因。

绕过守卫（无条件走 `\UL@stop … \UL@start`）也解决不了：实测搬出来的 glue 落进
`\cleaders` 内部，仍在盒子内部——`ulem` 打开盒子时开了两层，用户花括号插在中间，用户分组内的
`\UL@stop` 关不掉正确层级，`\UL@start` 重开的盒子又把它包了回去；而且绕过守卫会让分组内
字体设置丢失（`fntef-font01` 失败）。「守卫是直接原因」与「绕过守卫这个具体修法无效」
两件事同时成立——不能从后者推出守卫与问题无关，这两个命题各自需要独立证据。

修法（`\@@_ulem_defer_glue:n` / `\@@_ulem_flush_pending_shrink:`）不动守卫本身，而是把
else 分支的间距拆成两半输出：盒子内部放不可伸缩的 `kern` 占住自然宽度（排版位置与盒子宽度不变），
伸缩量记进全局 `\g_@@_ulem_pending_shrink_skip`，到 `\@@_ulem_loop:nw` 的词尾搬运处
（已在片段盒子外、用户分组外）再补一个零宽带伸缩的 glue。自然宽度为零的间距（如 `\CJKglue`
的 `0pt plus 0.96`，只有伸长没有收缩）必须短路直接输出，否则换成 `kern` 会连伸长量丢掉。
记账是全局量，`\@@_ulem_end:` 在装饰结束时清零，避免串到下一次装饰。

`fntef-shrink01` 的 TEST 11 固定修复后的行为（压窄 2pt badness 由 1000000 变有限值，
与 oracle 一致），TEST 9 的 braced 两行同步更新为固定修复后的读数。详见反思
[[../memory/reflections/1067-ulem-brace-group-ecglue-shrink]]。

### capture/register 框架（#992 / PR #999）

`\@@_boundary_capture_begin:` 在已注册命令入口执行四件事：

1. 在入口字体与选项上下文中缓存普通词间空格、`\CJKecglue`、`\CJKglue`、`CJKspace` 与 `xCJKecglue` 状态。
2. 保存并移除紧邻入口的源码空格和 xeCJK 写入的 marker，清空普通恢复状态。
3. 启动一层 capture；Boundary↔CJK 的 interchar transition 会通过 `\@@_boundary_capture_class:n` 把实际 `CJK` / `default` 类别写入所有未暂停的活跃层。
4. 首次观察记录首类别，随后更新末类别；外层 capture 因而也能观察内层命令，混合输出自然得到不同的首尾类别。

结束路径根据入口前类别、实际首类别和左侧是否有源码空格重建左边界，排回盒子或保留原节点流，再把实际末类别写成 marker，让正常 Boundary→CJK/Default 恢复过程决定右边界。重放 Default 类 marker 时还要把源码空格检查使用的缓存同步为外层列表当前的 `\spacefactor`；盒子内部字符设置的值不会传播到外层。未观察到可见字符时，入口 marker 与源码空格原样恢复。

注册层把命令形状与恢复算法分开：

| 策略 | 节点形状与结束动作 | 当前典型入口 |
| --- | --- | --- |
| `box` | 命令只留下一个末尾 hbox；取出原盒子、重建左边界、原样放回并重放末类别 | `\mbox`、`\fbox`、`\makebox`、`\framebox` |
| `wrapped-box` | 命令可能直接写多个节点；用透明 hbox 收集，若无可见输出则解包 | `\colorbox` / `\fcolorbox` 的 `\color@b@x` |
| `stream` | 内容直接写当前列表；首类别一出现就补左边界，结束时重放末类别 | hyperref annotation、`\@setref` / `\real@setref`、完整 URL、`\verb`、`\eqref`、`\meta`、`\cs`、`\lstinline` |
| `transparent` | 命令只有锚点、write、颜色 push/pop 等不可见节点；结束后完整恢复入口状态 | `\HD@target`、`\Hy@raisedlink`、驱动层 `\hyper@anchor`、`\blx@pagetracker`、`\set@color` / `\reset@color`、l3color 后端 |
| `post-transparent` | 只能使用 after hook；末尾盒子的宽、高、深均为零时，以真实 marker 为证据，把 `marker` 或 `marker + 一枚有限阶候选 glue` 的有界后缀移到盒子后面；无限阶（fil/fill）glue 不搬运 | 一般 `\null` |

水平模式的 transparent 命令前后各有一个默认为 `\prg_do_nothing:` 的钩子（#1091 R12 起）：`\@@_boundary_hmode_transparent_begin:` 在未暂停、处于水平模式时，先调用 `\@@_boundary_transparent_begin_hook:`，再压栈并开始 capture；`\@@_boundary_hmode_transparent_end:` 在本层 active 为 `true` 时，于重放与层号减一之后调用 `\@@_boundary_transparent_end_hook:`。核心本身不使用它们，目前只有 xeCJKfntef 用来在线型命令的正文里区分颜色 whatsit（R12 时只在嵌套装饰里用，`a8b45cf4` 起单层正文也用），见下文「ulem 结束符与入口空格」中的「内层以颜色命令开头」一条。透明盒子另有一对钩子：`\@@_boundary_box_end_transparent:n` 在排出盒子之前调用 `\@@_boundary_transparent_box_begin_hook:`（`c254f535` 起），之后调用 `\@@_boundary_transparent_box_hook:`（`a8b45cf4` 起；`d250e2a7` 起 `\@@_boundary_last_box_end:n` 末节点不是盒子、本层没有观察到字符类别时也调用它），默认都是 `\prg_do_nothing:`，见下文「正文先排出盒子、penalty、公式」。

`auto` 使用实际首尾类别；`default` 固定两端为 Default；`first-default` 只固定首端、末端仍取实际输出。`\eqref` 的括号和 `\meta` 的尖括号决定两端为 Default；`\cs` 只有开头反斜线固定为 Default。box 的 `default` 在结束函数同时覆盖首尾，stream 则在开始 hook 固定首端、结束 hook 固定末端，两条路径的公开语义相同。

#### 注册点的层级与字体上下文（#1046）

除了「注册哪个命令、选哪种策略」，还有第三个必须决定的问题：**在命令的哪一层注册**。`\@@_boundary_capture_begin:` 在 capture **入口**处把 `\CJKecglue`、`\CJKglue` 和词间空格分别排入临时盒子并读成 skip 数值，缓存的度量因此取决于进入命令那一刻生效的字体。

由此得到一条硬约束：**若目标命令的定义体里包含字体切换，capture 必须包住最外层那次切换。** 注册在切换内侧时，左边界重放切换后字体的 `\CJKecglue`，而右边界在 capture 结束、字体已恢复之后求值，两侧必然取到两套度量。这种写法在纯西文和纯中文文档里都看不出问题，只有中西文边界两侧同时出现时才暴露。

`\meta` 是这条约束的实例。l3doc 把它定义为 `\texttt{ \__codedoc_meta:n {#1} }`，早期适配器把 stream capture 包在内层的 `\__codedoc_meta:n` 上，于是左边界得到等宽字体的 `\CJKecglue`（Latin Modern 10pt 下为不可伸缩的 `5.25pt`），右边界得到正文字体的 `3.33pt plus 1.665 minus 1.11`。#1046 把注册点上移到公开的 `\meta`，改用通用注册 `\@@_boundary_register_stream:nn { meta } { default }` 后两端同源。

同一条约束也适用于用户通过 `experiment/boundary-register` 注册自定义命令，手册中已给出对应提醒。

#### 策略选择要看不可见节点的实际次序（#1047）

`transparent` 与 `post-transparent` 的区别不是「有无可见输出」——两者都没有可见输出——而是**marker 与命令排出的节点之间的位置关系**。`post-transparent` 是 after-only 变体，只在命令结束后搬移末尾零尺寸盒子下方的 marker 与候选 glue，要求 marker 与那个盒子**相邻**。命令若在盒子之前还排出别的节点，相邻条件就不成立。

`\Hy@raisedlink` 是这种情形：它在水平模式下先排 `\penalty\@M`，再排 `\smash` 后的 `hbox(0+0)x0`。`penalty` 把 marker 与盒子隔开，`post-transparent` 实测无效；`transparent` 在入口就取走 marker 与可选源码空格、节点排完再原样恢复，因而两种节点次序都能覆盖。选策略前应当先用 `\showbox` 读出命令实际排出的节点序列。

#### 同一类节点可能有多个出口，按调用点而非参数形式区分（#1047）

hyperref 的行内锚点会插入遮蔽 marker 的不可见节点。下面按**调用点**列出**已覆盖**的出口，各注册一次 `transparent`——本节不给出出口总数，理由见末尾：

- 驱动层的 `\hyper@anchor` 承接经 `\hyper@@anchor` 进来的锚点，直接排出裸的 `pdf:dest` whatsit。**`\hypertarget` 的两个分支最终都走这里**——`\@hyper@@anchor` 在 `\ifHy@activeanchor` 为假时统一调用 `\hyper@anchor`，与目标内容是否为空无关。
- `\Hy@raisedlink` 承接需要抬升的锚点：无编号标题（`\section*`、`\chapter*`，以及目录、参考文献等自动生成的无编号标题）、caption、公式编号、脚注、`\bibitem`，以及下游手工包裹的写法，例如 ctxdoc 的 `\exptarget` 定义为 `\Hy@raisedlink{\hypertarget{name}{}}`。它在水平模式下排出 `\penalty\@M` 加一个 `\smash` 后的 `hbox(0+0)x0`。注意目录**条目**不走这条路：`\contentsline` 用 `\hyper@linkstart`／`\hyper@linkend` 做链接，与抬升锚点无关。

`\hyper@anchor` 由驱动定义（`hxetex.def`、`hluatex.def`、`hpdftex.def`、`hdvipdfm.def` 直接定义，`hdvips.def` 经 `\input{pdfmark.def}` 得到同名命令），注册前用 `\cs_if_exist:NT` 守卫；hyperref 在 `\AtEndOfPackage` 阶段载入驱动，因此包尾钩子里的存在性检查时机正确。

- 第三个出口 `\__hyp_target_raise:n`：`\phantomsection` 与 `\MakeLinkTarget` 走它，编号标题的锚点也经过它。它自己排出同构的 `\penalty\@M` 加 `\smash` 抬升盒子，不经过 `\Hy@raisedlink`。它不接受通用命令 hook（LaTeX hook 机制拒绝 expl3 私有函数），故用 `\@@_boundary_wrap_transparent_onearg_braced:NN` 包装。

**包装这类函数要注意参数转发是否保留花括号。** 既有的 `\@@_boundary_wrap_transparent_onearg:NN` 以 `#1 ##1` 转发，适用于原函数只是顺序执行参数内容的情形。`\__hyp_target_raise:n` 会把参数**再次**用作 `\hbox:n` 的内容，丢掉花括号就改变了分组：紧随其后的 `\Hy@SaveSpaceFactor` 被卷进 `\hyper@anchorstart` 的参数，`\spacefactor` 赋值被写进 `pdf:dest` 名字、锚点名 `section*.1` 被排成可见文本。两个读数分别对应两个配置：**不挂任何钩子、仅做无花括号透传**为 81.16002pt（这个对照证明故障与 xeCJK 的钩子无关），**在包装变体里误用无花括号版**为 84.49002pt（回归测试报出的断言差值即 42.83pt／15.0pt）；oracle 为 41.66002pt。因此只需要 `#1 {##1}` 的转发变体，不需要新的适配器。

#### 已知未覆盖：`\hyper@anchorstart` 的裸调用

`\pdfbookmark` 直接写 `\hyper@anchorstart{...}\hyper@anchorend`，既不经 `\hyper@@anchor` 也不经两个抬升出口（计数器实测三者均为 0，只有 `\hyper@anchorstart` 计数为 1），因此右侧仍丢失一枚 `\CJKecglue`（38.33002pt 对 oracle 41.66002pt）。同类裸调用在 hyperref 与各驱动里还有若干处。这不是 #1047 引入的，base 上同样如此。

两种最直接的补法都已实测不可行：注册 `\@pdfm@dest`（`\hyper@anchor` 与 `\hyper@anchorstart` 的共同下游）使盒子宽度暴涨并报出十余处错误，因为它的参数含待展开内容；注册 `\hyper@anchorstart` 本身不报错，但也不生效——`\pdfbookmark` 仍为 38.33002pt，而已覆盖的三处不受影响（包内注册、用户接口注册、两者并存三种配置均如此）。为什么 transparent 在这个入口上无效尚未查明，这条路径需要单独设计适配器，另立议题跟踪。`hyperref-anchor-ecglue01` 的 TEST 10 把这个缺口固定为断言，补上覆盖时会主动失败，强制回来更新两份清单。

#### 为什么这一节不写出口总数

**判据是读分派函数的分支并用计数器实测。** 这一节的机制陈述被独立复核连续推翻**四次**，失败方式相同——都是从一个真实现象推出未经独立验证的更强断言：

1. 先写「非空目标经 `\Hy@raisedlink`、空目标经 `\hyper@anchor`」。计数器实测：四种 `\hypertarget` 形式的 `\Hy@raisedlink` 调用次数**均为 0**。
2. 改对分派依据后又写「行内锚点有两个出口」。计数器实测：`\phantomsection` 使 `\__hyp_target_raise:n` 计数 +1 而另两者均为 0。
3. 承认第三个出口后又写「它不能用现成包装，需要新设计适配器」，把故障归因给 begin 钩子里的赋值，据此放弃覆盖。隔离实验实测：begin 钩子体内没有任何 `\spacefactor` 赋值，那个赋值来自 hyperref 自己的 `\Hy@SaveSpaceFactor`；换成花括号转发即可修复。
4. 覆盖第三个出口后又写「三个出口全部注册」。同样的探针实测：`\pdfbookmark` 经 `\hyper@anchorstart` 裸调用，四个候选函数里只有它计数为 1。

**「注册 A 和 B 都必要」不能推出「只有 A 和 B」，也不能推出「按某条件在 A、B 间分派」；观察到一个故障也不能推出它的成因。** 这些是彼此独立的命题，各需自己的探针：控制流用计数器，穷尽性要说明如何排除下一种，成因用隔离实验。

因此本节改为只维护**已覆盖**与**已知未覆盖**两份清单，不再给出总数——总数是一个反复出错的穷尽性断言，而两份清单各自都可被单条探针核查。给上游包的内部出口计数需要穷举式审计（grep 全部 `\hyper@anchorstart`／`\@pdfm@dest` 调用点并逐一实测），不能从修复效果倒推。

#### 实验性用户注册入口（#1010）

`\xeCJKsetup{experiment/boundary-register=...}` 把上述五种内部策略开放给熟悉
目标命令节点结构的用户。`command` 直接接收一个控制序列；`box` 和
`wrapped-box` 允许 `auto`（默认）或 `default`，`stream` 还允许
`first-default`，`transparent` 与 `post-transparent` 不接受 `mode`。带 `@`、
`_`、`:` 的控制序列由调用方用 `\makeatletter` 或 `\ExplSyntaxOn` 处理类别码，
接口本身不把名称字符串重新解析成控制序列。

用户声明的生命周期与内建注册分开：声明在任何分组中都全局保存，到导言区末尾、
全部内建注册完成后才应用。LaTeX 在普通 `\AtBeginDocument` 代码执行完以后安装
命令 hook；随后 xeCJK 检查目标是否存在。因此，普通 `\AtBeginDocument` 中才
定义的目标仍可注册，正文期才定义的目标会报告未定义；导言区结束后也不能再新增
声明。接口只允许新增，不提供反注册或覆盖内建处理。

“已经由 xeCJK 处理”的不变量不能只由 `\g_@@_boundary_registered_prop` 表示。
通用注册函数写入这张表；`\verb`、`\Url@z`、codedoc、ulem、listings 等必须直接
重定义扫描器或内部排版入口的专用适配器，则写入独立的
`\g_@@_boundary_reserved_prop`。用户声明在保存和导言区末尾应用两个阶段都查询
两张表的并集：前一次尽早拒绝已知冲突，后一次覆盖导言区内后来加载的宏包。
新增内建专用适配器时，必须同时登记其公开入口和实际扫描／排版入口；否则用户
可能叠加通用 hook，直接破坏参数读取，而不只是得到错误间距。

公开入口只复用恢复算法，不会自动获得专用参数语义。尤其是 `auto` 只能使用
capture 可观察的类别；#1002 的参数公式处理还需要在可见正文排完前确认实际 math
节点，特殊扫描器也可能不能安全使用普通命令 hook。这些边界以及完整接口契约见
[[../memory/decisions/1010-boundary-register-public-api]]。

`\g_@@_boundary_registered_prop` 阻止同一命令重复注册。常用前两层 capture 的 box/tl register 在加载时预先分配，第三层起在第一次达到相应 depth 时创建；`\g_@@_boundary_active_seq` 保证 before/after hook 成对，数学模式与暂停状态只压入 inactive 标记。测试已覆盖 12 层盒子嵌套。

`\sbox` 只构造离线 scratch box，不应把测量内容报告成外层命令的可见输出。`\@@_boundary_sbox:Nn` 与 `\@@_boundary_prepare_sbox:` 把内部入口 `sbox ` 直接重定义为 `\tex_setbox:D #1 \tex_hbox:D { suspend … \color@setgroup #2 \color@endgroup … resume }`，在盒子内部执行 `\@@_boundary_capture_suspend:` / `resume:`；暂停深度可嵌套，并按层保存/恢复 `\g_@@_last_node_tl` 与 source-space pending，结束后必须归零。#1029 之前这里挂的是 `cmd/sbox/before` / `after` 两个通用钩子，已被这个专用适配器取代，原因见下文「命令钩子与专用适配器的选择边界」。

#### 语法判断前必须消解参数里的对齐符（#1043）

`\@@_boundary_color_box:nnn`、`\@@_boundary_textcolor:nnn` 这类适配器把**原始**用户参数
交给 `\@@_boundary_if_math_head:n` / `_tail:n` 做语法判断，而后者用 expl3 的
`\tl_if_head_eq_meaning:nNTF` 等条件式实现。

触发条件要分清两件事：`&` 在 LaTeX 下**默认**即为 catcode 4（`latex.ltx`），并非 `\halign`
把它设成 4；要紧的是**扫描发生的位置**——当这些条件式在**对齐环境内**（`eqnarray`／
`align`／`tabular`）读取参数时，catcode 4 的 `&` 会终止它正在读的宏参数，报
`! Argument of \__tl_tl_head:w has an extra }.`。实测同一 token list 在对齐环境**之外**
走同一条件式 0 错误，所以这不是「expl3 条件式对 catcode-4 token 的固有限制」，而是对齐符
在对齐环境里的参数终止语义。不加载 xeCJK 也能用裸
`\tl_if_head_eq_meaning:nNTF {$a&b$} $` 在 `tabular` 内复现。

因此做 head/tail 记号扫描的两个入口（`\@@_boundary_if_math_head:n`、`_tail:n`）都先经
`\@@_boundary_math_set:n` 存副本，并把其中 catcode-4 的 `&` 换成 `\scan_stop:`。
（`_tail_space:n` 不需要：它只做 `\tl_trim_right_spaces:n` 与 `\tl_if_eq:NNTF`，不扫描记号，
含 catcode-4 `&` 时实测 0 错误。替换也只处理顶层对齐符，组内的由递归时的下一次调用消解。）
要点：

- **修在 `_head:n` / `_tail:n` 这一层**，而不是单个适配器里。`\colorbox` 和 `\textcolor`
  分属不同适配器但共用这两个判断入口，逐个适配器修必然漏。
- 判断用的是副本，**实际排版仍使用原始参数**，所以替换不影响输出。
- 用 `\scan_stop:` 占位而非删除，以保住 `&` 的位置语义（否则 `&$x$` 会被误判为首项是公式）。
- 匹配模板必须是 catcode 4 的 `&`。直接写 `{ & }` 恰好可用，但只因 LaTeX 环境默认把 `&`
  设为 4（`latex.ltx`）且 `\ExplSyntaxOn` 不改 38（与 `\c_code_cctab` 无关，那需要 `\cctab_select:N`
  才生效，xeCJK 不选）。字面模式的类别在 dtx 被读取时冻结，**风险在加载期而非调用期**：
  加载后再改 `\catcode` 对两种写法都无影响，但若 `\usepackage` 之前 `&` 已非 4，字面写法
  此后一律静默失配。故实现自行构造 `\c_@@_alignment_tl` 把类别固定下来。相关写法约定见
  `llmdoc/reference/coding-conventions.md`「字面字符当替换模式时必须核对 catcode régime」。

回归测试是 `xeCJK/testfiles/halign-amp-boundary01/02/03.lvt`，分别覆盖 `eqnarray`／
`tabular`／CJK 相邻三种语境。**必须分文件**：`checkopts` 带 `-halt-on-error`，合并成一个
文件时缺陷态下首项报错即中止，其后的 `\TEST` 出现 0 次、判别力为零（首版正是这样写的）。
判别力已逐个实测（缺陷版三个文件 `l3build check` 均 EXIT=1，01 报 `extra }`；修复版均 0）。
两点边界：`\colorbox` 参数里放**裸** `&`（如 `\colorbox{yellow}{&$x$}`）本身就不是合法
LaTeX，不加载 xeCJK 也报错（首条为 `Missing } inserted.`，其后有一串对齐相关的连带报错），不能写进基线；这组测试固定的是
「不报错」，把替换值改成 `{ }` 或 `{ $ }` 时仍全绿，**占位语义没有测试保护**。

#### 命令钩子与专用适配器的选择边界（#1029）

`cmd/<命令>/before`／`after` 这类通用钩子（`\AddToHook`）只适合包装“命令本体不是赋值语句”的场景。`\global`／`\long` 等前缀是 TeX 里“等待下一个赋值”的状态，不是立即生效的操作；钩子代码插在命令本体执行之前运行，只要钩子内容本身包含任意一条赋值（不需要与目标命令相关），这条赋值就会先消耗掉调用方留下的待用前缀，使调用方写的 `\global\sbox` 在真正执行 `\setbox` 时已经没有 `\global`，静默退化为局部赋值，盒子在分组结束时被丢弃——整个过程不产生任何报错或警告。

这是 LaTeX2e `\AddToHook` 机制的通用陷阱，与 xeCJK 或 `\sbox` 本身都无关：最小复现不需要加载 xeCJK，`\AddToHook{cmd/sbox/before}[probe]{\advance\cnt by 1}` 就足以吃掉 `\global\sbox` 的前缀；把钩子内容换成不含赋值的 `\relax` 则不会触发。`\sbox`／`\savebox` 恰好本体就是一条赋值语句——`\savebox` 的四种形式（无可选参数、`[wd]`、`[wd][pos]`，以及 picture 形式 `(x,y)[pos]`）最终都汇入同一个内部入口 `sbox `——而 `\@@_boundary_capture_suspend:` 内部做的是多个 `\int_gincr:N`／`\tl_gset:` 全局赋值，正是会触发这个陷阱的钩子内容。`\global\setbox` 不受影响，因为 `\global` 直接贴在 `\setbox` 原语前面，中间没有钩子代码可以插入的位置；只有像 `\sbox` 这样“包装宏内部才调用 `\setbox`”的命令，才会把钩子插进前缀和赋值之间。

修复方式是专用适配器：直接重定义内部入口 `sbox `，把暂停观察移到盒子构造内部执行，使 `\global` 前缀始终紧邻 `\setbox` 本身。这与已有的 `color@b@x`／`@textcolor` 专用适配器（见下文“兼容性补丁子系统”与“旧边界补丁的吸收结果”，均为重定义内部入口而不是挂通用钩子）属于同一套模式：**注册的目标命令本体是赋值语句时，必须用专用适配器包装内部入口，把副作用移进赋值发生的位置内部；不能用通用 `cmd/.../before` 钩子。** `experiment/boundary-register` 面向用户开放的 `command` 策略存在同一类风险——用户若为自己“本体即赋值语句”的命令注册通用 hook，会踩到同一个坑；已在 `xeCJK.dtx` 用户手册对应段落加入警告。完整决策见 [[../memory/decisions/1029-sbox-adapter]]。

ulem 把正文拆进固定宽度的盒子。普通 stream 若直接在首次观察处排 glue，会把弹性间距和装饰 leader 一起放进内部盒子。`stream-ulem` 仍由 framework 决定 glue 类型和值，但在 ulem 活跃时经 `\@@_boundary_use_ulem_glue:nn {层号}{glue}` 通过 `\UL@stop`、普通 `\hskip`、`\UL@start` 把 glue 排到外层且不画线；独立符号命令使用普通 skip。ulem 结束正文时自己排出的定界字符不属于正文，入口源码空格也可能要在首类别出现之前排出，这两点见下文 xeCJKfntef 的「ulem 结束符与入口空格（#1091）」。包内线型命令在测量装饰符号前请求启动该 stream，原生 `\uline` 等入口由 `\ULon` 补上。两者都只允许最外层启动，因为嵌套路径会走 `\UL@onin`，没有可与重复 begin 配对的独立 end。所有嵌套线型命令复用最外层 stream，并由同一个结束点关闭。

哪些命令占用这条扫描通道由装饰的绘制方式决定：线型命令借 `ulem` 扫描画连续线条（`\CJKunderline`、`\CJKunderdblline`、`\CJKunderwave`、`\CJKsout`、`\CJKxout`、`\CJKunderanyline`），符号型命令逐字放置独立符号、不经 `ulem` 扫描（`\CJKunderdot`、`\CJKunderanysymbol`），因此只有两层都是线型时才会走进 `\UL@onin`。这条分工有一个**用户可见后果**：`\UL@onin` 把内层正文整段装进一个刚性 `\hbox`，盒子内部不再留有断点，两个线型命令相互嵌套时内层正文因此整段无法断行（嵌套顺序不影响结果；原生 `\uline` 嵌本包线型命令同样如此），而任一层为符号型时断行正常。这是 `ulem` 的长期约束、不是本包的回归（发布版 v3.10.4 与工作树行为一致），用户向说明与替代写法见手册 §3.6.1（`\label{subsubsec:fntef-nest-linebreak}`），回归由 `fntef-nest-linebreak01` 双向固定。

`box` 策略通常依靠 interchar transition 报告首尾类别，但公式与 `\vrule` 都不触发这种转换。rule 继续由 `\@@_boundary_if_capture_box_visible:` 根据盒子尺寸和末节点类型按 Default 处理；行内公式使用独立的 `math` 类别。命令参数适配器先检查正文两端的公式语法：开头公式在 math-on 前报告首类别；正文尾部的 `$`、`\)`、`\ensuremath{...}` 或相应外层分组都只产生“可能以公式结束”的候选。任何尾部候选都不能仅凭源码发布 `math`，因为未知宏既可能消费尾部花括号组，也可能把 `$` 或 `\)` 当作分隔参数的终止符。适配器把确认代码放在可见正文参数的末尾，在正文实际排完、外层包装尚未关闭时，只有当前列表末尾仍是真实 math 节点或 xeCJK 的 `math` marker，才确认候选并发布末类别。这样 `中{$x$}` 会得到 `math`；如果未知宏消费 `[q]{$x$}`、末尾 `$` 或末尾 `\)`，实际只排出 CJK“文”，则仍以 CJK 作为末类别。实现不使用全局 `\everymath`，也不展开任意用户宏或扫描任意 hbox 的内部节点。

尾随源码空格会在通用路径中成为遮住公式节点的词间 glue。只有语法候选明确带尾随空格时，确认代码才暂时取下这一枚符合词间空格形状的 glue，检查下方节点后原样放回。ulem 会把它改写为 leaders，故 ulem 适配器在交出尾随空格前确认公式，再把空格交回原装饰流程。两条路径都继续执行实际节点确认，未知宏消费公式后输出 CJK 的反例不会被误判。

以下情况仍恢复进入命令前的状态：宽、高、深均为零的盒子（`\null`、空 `\mbox`）；只用于留白的盒子（空 `\makebox`、strut、零高 rule，包括 ctex 内核 `\[` 使用的 `\makebox[.6\linewidth]{}`）；末尾是另一个已经排好的盒子或填充 glue 的命令（如 thuthesis 的 `\thu@pad`）。capture 无法从 hlist(1) 或 glue(11) 判断里面的字符类别，因此不作推断。

推断出的 Default 通过 `\@@_boundary_capture_report_first:n` 只补上尚未取得的首类别，不直接改写外层已经观察到的末类别。嵌套命令结束时写入的 marker 会留在它实际输出的列表末尾；外层盒子或 stream 结束时读取这个 marker，再更新本层 `last_tl`。因此 `\mbox{中\fbox{中$x$}}` 能逐层得到 `math` 末类别，原语 `\setbox` 中没有输出到当前列表的公式则不会成为外层末类别；`\sbox` 仍由 suspend/resume 隔离。`\mbox{\vrule...}` 按 Default 检查，公式命令以直接公式为 oracle。详见 [[../memory/decisions/992-command-boundary-capture-register]]「机制边界」和 [[../memory/decisions/1002-inline-math-boundary-oracle]]。

右边界后续恢复所需的状态不只有末类别。盒子内部末尾的大写字母会把全局 `\g_@@_space_factor_int` 留成 999，但外层列表的 `\spacefactor` 仍是 1000；因此 `\@@_boundary_replay_node:n` 重放 `default`、`default-space` 或 `normalspace` 时，以当前外层值同步缓存，避免盒子外的源码空格与过期规格严格比较。post-transparent 则先确认末尾盒子为零尺寸，再用 `\@@_boundary_pop_node:N` 检查盒子是否直接盖住 marker；未命中时只暂存至多一枚 glue，再检查其下方 marker。除上述 `math-space` 过期例外外，命中后按“盒子、marker、glue”重放；未命中则按原来的“glue、盒子”顺序还原，包括 0pt glue。`\@@_boundary_post_transparent_relocate_glue:` 在搬运这枚候选 glue 之前还会先 `\skip_if_finite:nTF` 判断阶数：`\hfill`／`\hfil` 等无限阶填充 glue 不搬运，直接把零尺寸盒子放回末尾，保持 marker、glue、盒子原有顺序不变，避免 `\hfill 中 \hfill\null` 这类居中写法里 `\null` 被排到 fill 之前而破坏两侧对称（#1085，见上文 math-space 段落末尾）。该路径不扫描第二枚 glue、任意 hbox 或 whatsit。#1003 的根因和节点证据见 [[../memory/reflections/1005-xcjkecglue-right-boundary-recovery]]；#1085 的根因和节点证据见 [[../memory/reflections/1085-hfill-post-transparent-relocate]]。

### 右侧源码空格的机制边界

TeX 节点列表不保存 glue 的来源。注册命令结束后，如果用户显式写出的 glue 与当前词间空格自然宽度相同，并且带有 shrink，`\@@_recover_ecglue_source_space:` 就无法判断它是源码空格还是显式 `\hskip`。

框架因此只在已知路径设置 pending 后检查末尾 glue。这枚 glue 必须 finite、带 shrink、自然宽度与词间空格相同，下方还必须有 xeCJK 写入的 CJK marker。如果需要原样保留这样的显式 glue，可在前面加 `\kern0pt`，也可以改变自然宽度或去掉 shrink。这样检查不会继续向前找到 marker。`command-boundary02` 同时记录这个限制和两种处理方法，防止以后误以为它只是偶发现象。

Boundary→Default 与 Boundary→CJK 现在使用相同的检查（#996，PR #1001）：`\@@_check_for_glue_skip:` 在 Boundary→CJK 方向也调用 `\@@_skip_if_interword:N` 判断函数。新增的 `\@@_glue_check_expire_stale:` 还会在顶层恢复逻辑发现节点列表为空时清除过期 pending，避免它越过 `\hbox` 或 `\setbox` 分组；capture 活跃时不清除，因为 ulem 等 stream 仍要把这个状态带到命令外的边界。如果显式 glue 与词间空格在节点列表中没有区别，两个方向仍然都无法判断来源，处理方法仍是在前面加 `\kern0pt`。决策与复现证据见 [[../memory/decisions/992-command-boundary-capture-register]]「机制边界」。

### 旧边界补丁的吸收结果

#999 的完成条件是删除生效的逐命令边界恢复算法，而不只是让它们与 framework 并存。当前分工如下：

- `\@setref`（无 hyperref）或 `\real@setref`（hyperref 保存的内核副本）直接注册为 `auto` stream；一般 `\null` 仍用 post-transparent。#991 的 `\null\fi` 文本替换、saved-node 与源码空格专用 replay 已删除。
- hyperref 从 `\Hy@BeginAnnot` 到顶层 `\Hy@EndAnnot` 使用 `auto` stream；URL 等内部末尾 math 仍按可信 Default 输出处理，显式链接正文两端的行内公式则由参数适配器报告 `math`。入口 save/replay、结束端专用 `hyperref-default` marker 均已删除。
- URL 在完成花括号/分隔符扫描后的完整 `\Url@z` 外包围 `default` stream；不再按“当前是否已有 capture”分支，也没有 URL drain。
- `\verb` 使用 `auto` stream；`\@@_flush_language_whatsit:` 只负责让延迟 language whatsit 在 stream 结束前真实进入列表，不判断或恢复边界。`\verb*` 与 shortvrb 共用入口和出口。
- codedoc/doc 的 meta 保留参数 hbox，只为阻断尖括号与 CJK 参数之间不应有的内部 ecglue；完整外侧由 `default` stream 处理，旧 drain 已删除。#1046 起 l3doc 分支的 stream 注册点是**公开的 `\meta`**（走通用 `cmd/meta/before|after` hook），不再是内层的 `\__codedoc_meta:n`——`\meta` 定义里的 `\texttt` 必须落在 capture 之内，否则左右边界取到两套字体度量，理由见上文「注册点的层级与字体上下文」。因此 `meta` 也从专用适配器保留表移入通用注册表；`\Arg`、`\marg`、`\oarg`、`\parg` 仍留在保留表，它们在内层两侧各排出等宽的 `{`、`[`、`(` 实字符，本身就构成正常的 CJK→Default 边界，实测不需要这层 capture。`doc` 宏包的 `\meta` 没有 `\texttt` 外层，本来对称，实现未改。
- color/xcolor 的 `\set@color` / `\reset@color` 与 l3color 后端使用 transparent capture，`\color@b@x` 使用 wrapped-box；颜色专用 saved marker、hlist/whatsit fallback 与 pending 已删除。l3color 包装器只保留原参数签名。
- biblatex 在 preamble 结束后把最终 `\let` 目标 `\blx@pagetracker` 注册为 transparent；旧的单向 clear 逻辑已删除。
- xeCJKfntef、原生 ulem 与独立 under-symbol 入口使用 `stream-ulem` / stream；旧的 saved-last-node、颜色状态隔离和直接 pending 设置由 capture suspend/replay 取代。ulem 外层 glue callback 只解决装饰与断行节点位置。
- `\lstinline` 的分隔符和花括号扫描入口都启动 `auto` stream，并在共同 `\lst@DeInit` 结束；listings 的 parameter-token rescan 修正属于内容扫描语义，不承担边界恢复。

剩余适配器只处理第三方私有签名、扫描时机、加载时序或命令内部排版语义，均复用共享 begin/end 和 marker/glue 原语。详细决策见 [[../memory/decisions/992-command-boundary-capture-register]]；测试方法见 [[../reference/build-and-test]]。#873/#880/#910/#931/#972、#826/#830/#831 与 #991 的旧 decision/reflection 记录演进路径，不能再当作当前实现说明。

## 字体管理

### 分层设计

```
用户接口层:  \setCJKmainfont, \setCJKsansfont, \setCJKmonofont
             \newCJKfontfamily, \setCJKfamilyfont
                      ↓
xeCJK 内部:  \xeCJK_set_family:nnn  →  NFSS 字体族注册
                      ↓
fontspec:    底层字体加载与 OpenType 特性处理
```

### 字体切换时机

字体切换发生在 interchar token 触发的 CJK 分组入口处（`\xeCJK_select_font:`）。即：只有当 XeTeX 检测到字符类从非 CJK 切换到 CJK 时，才会执行字体切换。CJK 区域内部字符间不重复切换。

### 字体选择与间距语义并非引擎级绑定（#553）

XeTeX 虽然规定每个字符只能属于一个 `\XeTeXcharclass`，但字符类本身只选择一组 `\XeTeXinterchartoks`，不会在引擎层把“使用哪套字体”与“插入哪种间距”绑定。#553 的普通文本原型新建混合类，复制 `Default` 的全部相邻类转换，并只在进入/离开该类时增加 `\xeCJK_select_font:` 的分组开关；节点列表确认 ASCII 数字可用 CJK 字体输出，同时在 CJK–数字边界保留 `\CJKecglue`、在字母–数字边界不产生 glue。因此，类似需求不能简单判定为“XeTeX 无法实现”。

这项可行性不等于现有架构适合公开混合类。`\g_@@_non_CJK_class_seq` 与 `\g_@@_CJK_class_seq` 把字体选择、标点转换、Boundary 恢复、listings 单元和 fntef 转换建立在 CJK/非 CJK 二分上；“字体语义属于 CJK、间距语义属于 Default”的类无法自然归入任何一边。正式实现前必须反向审计所有直接枚举旧类或复制旧类转换的位置，并覆盖数学、verbatim/listings、fntef/ulem、fallback、字体族/字重切换、颜色、链接和外部分配字符类等路径。

若目标内容可在源文件中明确标记，低风险方案是保持字符的 `Default` 类，只用局部 `\newfontfamily` 命令切换所需数字；这会自然复用现有间距转换。若要求全局按字符范围自动选字体，真实问题属于 range-to-font/composite-font 路由，还必须先明确数学、计数器、页码、引用、URL、代码以及字体族/字形跟随规则，不能收窄成 ASCII 数字特例。#553 因证据不足且产品化影响面过广，以 `not planned` 关闭；决策见 [[../memory/decisions/553-mixed-font-spacing-class-not-planned]]。

### 后备字体 (Fallback)

xeCJK 支持为 CJK 字符范围设置后备字体链。当主字体不包含某字符时，按优先级尝试后备字体。实现基于 `\setCJKfallbackfamilyfont` 和内部的 `\xeCJK_fallback_symbol:NN` 检测机制。

#### 「重选 CJK 字体」会清除已切好的后备字体状态

这是对下游可见的一条陷阱，任何要在 CJK 输出路径上插钩子的宏包都会碰到。

`\xeCJK_select_font:` 经内部的 `\@@_select_font:Nn`，而后者的**第一句**就是 `\xeCJK_clear_fallback_font:`（`xeCJK/xeCJK.dtx:10450-10452`）；块级的 `\@@_select_font:Nnn`（`:10541-10543`）同理。也就是说，xeCJK 把「重选 CJK 字体」定义为「放弃当前的后备字体」——这在它自己的逻辑里是自洽的，重选主字体本来就意味着要从头走一遍字形探测。

正常路径不出问题，靠的是次序。Boundary→CJK 的 interchartoks（`:4064-4069`）依次是 `\xeCJK_select_font:` → `\xeCJK_fallback_symbol:NN` → `\CJKsymbol`：先选主字体，再探字形，缺字才切到后备字体。在 `\CJKsymbol` 这一层**之后**再调 `\xeCJK_select_font:`，就是逆着这个次序走，会把刚切好的后备字体清掉。

#### 判断「当前是否处于后备字体状态」

可以直接读取的判据是 `\xeCJK_reset_fallback_font:` 是否等于 `\prg_do_nothing:`：

- 未启用后备字体时它本就是 `\prg_do_nothing:`（`:9881`）。
- `\@@_fallback_symbol_aux:nnNN` 切换到后备字体后，把它重定义为「`\the\font`（恢复该字体）+ `\xeCJK_clear_fallback_font:`（清除标记）」（`:9872-9876`）。
- `\@@_clear_fallback_font:` 再把它 `\cs_set_eq:NN` 回 `\prg_do_nothing:`（`:9879-9880`）。

所以它既是恢复动作，也是唯一的状态标记。

#### 稳定性与下游指引

`\xeCJK_reset_fallback_font:` 与 `\xeCJK_clear_fallback_font:` 在 dtx 里**没有独立的 `\begin{macro}` 条目**，只夹在 `\xeCJK_fallback_symbol:NN` 那一块里，属于内部量；相比有 `[int]` 条目的 `\xeCJK_select_font:` 更容易在上游重构中改名。目前已知有下游依赖它（xpinyin），因此 xeCJK 侧改名或改语义时要同步通知。

给下游的指引：**CJK 输出路径上的钩子若要重选字体，先判断是否已处于后备字体状态**；已在后备字体里时当前字体正是应该用的那一个，重选反而会退回主字体。实例是 xpinyin 的 `\@@_reselect_CJK_font:`（定义在 `xpinyin/xpinyin.dtx`，检索 `\cs_new_protected:Npn \@@_reselect_CJK_font:`；#997）——它的量宽盒子原先无条件重选，启用 `AutoFallBack` 时量出的是主字体下缺字形的错误宽度。取舍见 [[../memory/decisions/997-xpinyin-fallback-reselect]]。

### AutoFakeBold / AutoFakeSlant

当 CJK 字体没有对应粗体/斜体变体时，xeCJK 可通过 XeTeX 的 `embolden` / `slant` 特性自动伪造。通过 `AutoFakeBold` 和 `AutoFakeSlant` 选项控制。

## 标点压缩系统

### 核心依赖

标点压缩依赖 XeTeX 的 `\XeTeXglyphbounds` 原语获取字符的左右边距（side bearings），从而计算需要压缩的空白量。

### 标点样式 (PunctStyle)

xeCJK 预定义了多种标点样式：

| 样式 | 说明 |
|------|------|
| `quanjiao` | 全角：标点占一个汉字宽 |
| `banjiao` | 半角：标点压缩到半个汉字宽 |
| `kaiming` | 开明：句末标点全角，其他半角 |
| `hangmobanjiao` | 行末半角：行末标点压缩 |
| `CCT` | CCT 风格 |
| `plain` | 无压缩，原样输出 |

可通过 `\xeCJKDeclarePunctStyle` 自定义。

### 标点间 kern 计算

相邻标点的压缩量通过 `\xeCJKsetkern` 手动设置或由样式规则自动计算。内部通过 `g_@@_punct/kern/<char1>/<char2>/tl` 属性表存储。

标点函数的结果按 `(标点字体, PunctStyle 风格, 字符)` 三元组缓存（`\@@_punct_csname:n` 生成的属性表键名）。这意味着任何对压缩公式本身的修改，一经合入即对全部非 `plain` 风格（`quanjiao`/`banjiao`/`kaiming`/`hangmobanjiao`/`CCT`）自动生效，无需分别适配。

### 破折号（U+2014）宽度算法（#382）

CLReq（《中文排版需求》）要求连续破折号总宽随连用数量线性增长（n 个连用 U+2014 占 n 个汉字宽），但破折号所属的 `LongPunct` 类原始压缩公式只保证"中间连续无缝"，不保证总宽不变量。`\@@_long_punct_kerning:N` 与 `\xeCJK_punct_margin_process:NN` 两处联动修复覆盖了这一缺口，两者都要应对同一个根源问题：**不同字库对"破折号字面（glyph ink，`dimen`）"与"破折号字框（advance width，`width`）"的关系定义差异巨大**——中易系字库字面窄于字框、方正兰亭黑字面溢出字框、微软雅黑字框本身宽于字号。任何单一公式都无法同时兼容三类字库。

**中间压缩量（`\@@_long_punct_kerning:N`）**：原公式 `kern = -max(bound_l + bound_r, 0)` 只用两侧 side bearing 之和，仅对"字面居中于字框、字框等于字号"的理想字体成立。修复为 U+2014 专用三路取大（`width` 为字框宽，`dimen` 为字面宽，`F` 为当前字号 `\f@size`，取值下界为 0 因为破折号边界可能为负，如方正新书宋）：

```
kern = -max( bound_l + bound_r,
             dimen + width - 2F,
             2*width - 2F,
             0 )
```

注意 `0` 下界在代码中不是显式的第四路取大：第一路 `bound_l + bound_r` 在进入三路取大之前已被 `\dim_max:nn { ... } { \c_zero_dim }` clamp 为非负，外层 max 含有一个 ≥ 0 的操作数，故结果必然 ≥ 0（kern ≤ 0），不会产生扩张 kern。

三项分别覆盖：`bound 和` 对应字面窄于字框（中易系），`dimen+width-2F` 对应字面溢出字框（方正兰亭黑），`2*width-2F` 对应字框本身宽于字号（微软雅黑）。省略号 U+2025/U+2026 连用不需要压缩，保持零 kern；其余长标点（U+2E3A 二の字点、全角浪线等）行为不变，仍走原 bound 和压缩公式。

**两端补偿 margin（`\xeCJK_punct_margin_process:NN`）**：破折号属于 `MiddlePunct`，原公式两端各补偿 `(目标宽 - dimen) / 2`（各半份空白，使标点在其目标宽度内居中）。但对未启用合字的 U+2014，连用时中间被上面的 kern 挤掉的空白，恰好等于单个字符两端总空白（而非半份），若仍按半份补偿，连用总宽会系统性偏差。修复为新增条件 `\@@_punct_if_full_margin_dash:N`（判定：字符是 U+2014 且未被归入 `PoZheHao` 类），成立时补偿两端**各一整份**（不除以 2）。该条件同时作用于 margin 计算本身与它传给 `\@@_save_punct_skip:nNNnnn` 的 glue plus（stretch）分量——两处必须保持同一份"是否除以 2"的判断，否则自然宽度与弹性分量会不一致。

代价（相对 CLReq 理想值的已知偏差，均在可接受范围）：单个 U+2014 略超 1 字宽（约 1.087 ccwd），三连略欠 1 字宽（约 2.913 ccwd）——这是"仅调整两个自由度（kern、margin）去满足两个不变量（中间无缝、总宽正确）"必然存在的近似残差，测试 `dashwidth01.lvt` 对此按已知值断言而非要求精确 2.0/3.0。

### PoZheHao 字符类（合字 opt-in，#382）

阶段 1 的公式修正只解决"未合字"场景的宽度问题。对提供 OpenType 破折号合字特性的字体（如思源宋体、思源黑体：连续两个 U+2014 被替换为一个两倍字宽的合字字形），interchar 机制默认会在标点处理时于两个 U+2014 之间注入 token，从而阻断 OpenType shaping 层看到"相邻"两个字符、无法触发合字。

修复采用零注入字符类模式（见上文字符分类体系）：新建 `PoZheHao` 类，类内（U+2014↔U+2014、U+2014↔U+2015）不插入任何 interchar token，交由字体自身的合字特性处理；类间关系复制自 `FullRight`，保证破折号与其他标点/CJK 相邻时仍按全角右标点语义处理。

工程细节与踩坑记录：

- **`\@@_punct_if_right:N` 必须承认 `PoZheHao` 类**：若不修改，「标点+破折号」相邻（如“爱。——”）时，该函数误判 U+2014 不是全角右标点，导致下游取用不存在的 `dim/glue/left/—/tl` 一类缓存键报 `Missing number`。这是 2018 年该功能原型中就已踩过的坑（回归测试 `dashwidth01.lvt` 专门覆盖"标点后接破折号"场景以固化此教训）。
- **`\xeCJKResetPunctClass` 与状态恢复**：该命令会重新声明 `FullRight` 类，导致 U+2014 被重新拉回 `FullRight`（覆盖掉 `PoZheHao` 归类）。为此 `PoZheHaoLigature` 的开关状态记录在布尔 `\l_@@_pozhehao_ligature_bool`（局部，见下文 #431 影子布尔作用域一致性说明）中，`\xeCJKResetPunctClass` 执行尾部按该布尔值自动恢复 `PoZheHao` 类声明，避免用户重置标点类后合字状态跟着丢失。
- **`PoZheHaoLigature=false` 的恢复目标**：U+2014 → `FullRight`，U+2015 → `Default`（普通类，编号 0）。注意 U+2015（水平线）自 v3.3.3 起已不属于 `FullRight`，这一点在本次修复中被实测验证，不能想当然认为两个字符对称恢复到同一个类。
- **为什么是用户 opt-in 而非自动探测**：合字能力完全取决于字体（多数国产字库不提供），XeTeX 没有可靠原语能在不实际 shape 的情况下探测某字体是否具备特定 OpenType 合字特性；对不支持合字的字体启用 `PoZheHaoLigature` 会让连续破折号中间露出空隙（因为零注入类不再提供任何补偿）。因此设计为显式 `\xeCJKsetup{PoZheHaoLigature}` 键控制，且需要用户自行配合开启 `fwid`/`locl` 等 OpenType 特性以获得全角字形。

### LatinPunct 选项：中西文共用码位标点的字体切换（#389/#431）

部分 Unicode 码位是中西文共用的：弯引号 U+2018/U+2019/U+201C/U+201D、间隔号 U+00B7、省略号 U+2025/U+2026/U+2027。xeCJK 默认把它们归入全角标点类（`FullLeft`/`FullRight`），用 CJK 字体输出全角字形。在以西文为主的文档中，这会导致夹在英文单词内部的撇号（如 `Children's` 中的 U+2019——输入法/编辑器的 smart quotes 默认产生这一码位）被排成突兀的全角形式（Issue #431，原型讨论见 #389）。

`\xeCJKsetup{LatinPunct}` 提供归类切换：

| 值 | 归类 | 效果 |
|---|---|---|
| `true`（默认） | U+2018/U+201C → `HalfLeft`；U+00B7/U+2019/U+201D/U+2025/U+2026/U+2027 → `HalfRight` | 西文字体输出，不参与标点压缩 |
| `false` | 对应码位恢复 `FullLeft`/`FullRight` | CJK 字体输出全角字形，参与标点压缩 |

字符集选择归入 `Half*` 而非 `Default`（编号 0）：`Half*` 类保留了半角标点固有的 interchar 间距语义（如与 CJK 字符相邻时的 `\CJKecglue` 处理），`Default` 类语义更泛化、不专属于标点。字符集范围与 `true`/`false` 的处理动作沿用 Issue #389 中 `RuixiZhang42` 提出的 `\xeCJKUseLatinPunct` switch 原型。

**与 `PoZheHaoLigature` 的正交性**：破折号 U+2014、二の字点 U+2E3A 与半字线 U+2013 刻意排除在 `LatinPunct` 字符集之外——它们属于上文 `PoZheHaoLigature`/CLReq 两字宽处理语义，两个选项分别控制不同的字符子集，互不干扰（`dashwidth01.lvt` 与 `latinpunct01.lvt` 均覆盖"破折号不受另一选项影响"的断言）。

**`\xeCJKResetPunctClass` 恢复链**：与 `PoZheHaoLigature` 并列，`\xeCJKResetPunctClass` 重新声明 `FullLeft`/`FullRight` 会覆盖 `LatinPunct` 的归类调整；重置尾部按 `\l_@@_latin_punct_bool` 用 `\keys_set:nn { xeCJK / options } { LatinPunct = true }` 重放（`PoZheHaoLigature` 走同样的重放模式）。目前标点压缩系统里有两个选项走这一恢复模式。

#### 影子布尔的作用域必须与被控资源的作用域一致（#431 工程教训，回溯修正 #382）

初版 `LatinPunct` 状态记录沿用 `PoZheHaoLigature` 既有写法，用全局布尔 `\g_@@_latin_punct_bool`。实测暴露 bug：`\XeTeXcharclass` 赋值本身是 **TeX 分组局部**的——`{\xeCJKsetup{LatinPunct=false} ... }` 退出分组后字符类自动恢复为分组前的值，但全局布尔不会随分组恢复。此后一旦在分组外调用 `\xeCJKResetPunctClass`，就会按已经过时（不再反映当前字符类真实状态）的全局布尔值错误重放。

修复为局部布尔 `\l_@@_latin_punct_bool`，使"记录当前配置"的影子状态与被记录的 `\XeTeXcharclass` 赋值同处于同一 TeX 分组作用域，开组切换、退组恢复能同步生效。

**同一提交顺带修正了 `PoZheHaoLigature`**：`\g_@@_pozhehao_ligature_bool` 存在完全相同的作用域不一致问题，只是此前没有"分组内切换"的测试场景覆盖，未被触发。本次一并改为局部 `\l_@@_pozhehao_ligature_bool`。

**通用教训**：任何"记录某个局部资源（TeX 分组局部生效的原语赋值）当前配置"的影子状态变量，其作用域必须与被记录资源本身的作用域一致——用全局变量记录局部状态，在跨分组场景下必然产生状态与实际不符的窗口期。这一教训同样适用于未来任何基于 `\XeTeXcharclass`/`\catcode` 等分组局部原语的 opt-in 开关设计。

详见决策 [[431-latinpunct-option]]。

### 标点度量的 feature-blind 限制（架构级边界，#382 复测发现）

xeCJK 所有标点尺寸（`dimen`/`width`/`bound` 等）均通过 `\fontcharwd` 与 `\XeTeXglyphbounds n \XeTeXcharglyph` 获取。`\XeTeXcharglyph` 是**基于 cmap 的直接字符→字形编号查找**，不经过 OpenType shaping 管线，因此 `locl`（区域本地化替换）、`fwid`（全角变体替换）等 GSUB 特性替换掉原字形后，xeCJK 拿到的度量仍然是替换前那个"幻影字形"的度量，不会随特性生效而更新。

这是一个已知且当前无法绕过的架构限制：没有原语能取得"shaped 后"的字符度量——advance width 尚可通过临时 `\hbox` 实测宽度间接获得，但 side bearing（字形左右边距，标点压缩公式的关键输入）没有对应的原语或测量手段。

已知表现（本次修复中实测确认）：裸 Noto Serif CJK SC（未显式开启 `RawFeature=+fwid`）的连用破折号总宽仍是修复前的 1.78 ccwd 而非 CLReq 要求的 2.0，因为 `\XeTeXglyphbounds` 拿到的是全角替换前的窄字形边界；显式开启 `fwid`/`locl` 后（如 `\setCJKmainfont{Noto Serif CJK SC}[RawFeature=+fwid]`）度量与视觉字形一致，总宽达标 2.0。诊断这类问题时，`fontcharwd`/`\XeTeXglyphbounds` 在同一字体、开关某 OpenType 特性前后返回值恒定不变，本身就是"此路径 feature-blind"的直接证据，无需深入 shaping 引擎即可确认根因。

### #975 的预设修正与方向性标点对策略（#443、#481、#488、#511）

xeCJK v3.10.3 用三项窄修覆盖了 #443、#481、#488，同时保留现有 `PunctStyle`、显式字符对设置和禁则行为。#511 所讨论的完整标点模型重构仍是长期边界。

| Issue | v3.10.3 行为 | 实现与回归证据 |
|---|---|---|
| #443 开明式句末点号宽度 | `kaiming` 的 `mixed-punct-ratio` 从 `0.8` 改为 `1.0`；FandolSong 10pt 下 `字。字` 的句号贡献 10pt，`字，字` 的句内标点仍为 5pt | 只修改 `kaiming` 预设；`punctuation-model-975.lvt` 同时断言句末、句内和相邻标点，既有 `kaimingpunct01`/`punctstyle01` 固化节点基线 |
| #481 港台/日文居中标点相邻时过度挤压 | `quanjiao` 默认启用 `optimize-kerning`，用两枚标点的实际边界下限约束通用 pair kern | 专用 Noto Serif CJK TC 字体面下 `。』？！` 从旧路径 26.04pt 恢复为 31.82pt，JP 字体面从 25pt 恢复为 27.19pt；不能用 `Language=` 替代专用字体面，因为 `\XeTeXglyphbounds` 不观察 GSUB 后字形 |
| #488 `FullLeft→FullRight` 不应压掉自然空白 | 新增 `enabled-left-right-kerning` 样式键，默认 `true`；`quanjiao` 设为 `false`，只取消左标点后接右标点的自动压缩 | Noto Serif CJK SC 下 `（？` 与插入零 kern 阻断自动压缩的自然参考等宽；显式 `\xeCJKsetkern`、`enabled-global-setting=false`、`banjiao`、nobreak 调用、`FullRight→FullLeft` 与 `）（` 均有独立断言 |
| #511 标点模型重构讨论 | 当前实现仍使用 `FullLeft`/`FullRight`、special-punct 列表、单个 `PunctStyle` 实例和 feature-blind 度量 | #975 修正三个具体默认值/策略，不处理语义化句末传播、文种/书写方向 profile、竖排、GSUB 后度量或通用有向 pair matrix |

方向策略落在标点样式层，而不是直接改 `FullLeft→FullRight` transition。`\@@_save_punct_kerning:NN` 必须先 `\UseInstance` 载入当前样式，再判断字符对方向；只有前标点不是 `FullRight` 且后标点是 `FullRight` 时进入 `\@@_save_left_right_kerning:NN`，反方向和同侧组合仍走通用计算。关闭自动压缩时保存零 kern，但原 transition 中的 `\xeCJK_no_break:` 不变，因此自然空白不会变成可断点。

这一层次还保留了两个既有优先级。若 `enabled-global-setting=true` 且该具体字符对存在 `\xeCJKsetkern` 记录，显式设置仍进入通用计算并优先生效；若全局设置关闭，则忽略该记录并保留自然空白。`banjiao`、`kaiming`、`CCT` 和未改写此键的自定义样式继承默认 `true`，保持历史压缩。若在 transition 中无条件跳过 kern，这些样式与显式覆盖都会被一并破坏。

#443 的比例修正只解决“被列入 `KaiMingPunct` 的单个字符宽度”。#511 指出的“真・开明”还包括句末语义跨越右引号等标点传播，因此不能把该比例改动描述成完整的开明式重构。完整方案仍应把 opening/closing 禁则角色与字面位置/可压缩性分离，由文种和书写方向 profile 选择字符属性，再以有方向的 pair matrix 生成 glue/kern/penalty；迁移时保留现有 `PunctStyle` 与 `\xeCJKsetkern` 作为兼容层。

### 长标点断点的两侧禁则检查（`\@@_punct_kern:NN` / `\@@_punct_kern_break:NN`，#456）

v3.6.0（2018/01/23）起，长标点（`LongPunct`，如 U+2014 破折号、U+2026 省略号）与其他标点相邻时的断点策略是"只要一侧是长标点就总允许折行"（`\@@_punct_if_long:NTF #1 { breakable }`）。这只保证了"长标点内部不误断"，未检查断点另一侧是否违反通常的标点禁则，导致三类硬性违规：

- `“——`：可在左引号（`FullLeft`）后断行 → 全角左标点悬于行尾
- `——，` / `——。`：可在逗号/句号（`FullRight`）前断行 → 全角右标点落于行首
- `——……`：可在省略号前断行 → `NoBreakLongPunct`（见 #681）落于行首；v3.10.0（2026/04/27）只修了"右侧是长标点"这一支，"右侧是 `NoBreakLongPunct` 但左侧是长标点"的组合依然漏判

修复重写 `\@@_punct_kern:NN` 的决策树：外层先用 `\bool_lazy_or:nnTF { long_p #1 } { long_p #2 }` 快速筛掉"两侧都不是长标点"的常规情形（保持原有 nobreak 行为不变），只要有一侧是长标点，才进入新增的 `\@@_punct_kern_break:NN` 做两侧禁则联合判断：

- 断点之前（`#1`）必须是全角右标点（`\@@_punct_if_right:NTF`，`PoZheHao` 类也被承认为 right，见上文 #382）或长标点——否则全角左标点会悬于行尾；
- 断点之后（`#2`）必须是全角左标点，或者是长标点且**非** `NoBreakLongPunct`——否则全角右标点或省略号等会落于行首。

两条件同时满足才走 `\@@_punct_breakable_kern:NN`，否则走 `\@@_punct_nobreak_kern:NN`。合法断点保留：`，——`、`……——`、`——（` 仍可断（右侧是长标点或左标点，左侧是全角右标点）。

工程坑位：

- **两类条件函数的参数形式不同**：`\@@_punct_if_right:N`（`prg_new_conditional`，内部用 `\xeCJKtoken_value_class:N` 查询 `\XeTeXcharclass`）要求参数是**字符记号**；而 `\@@_punct_if_long:N`（special punct clist 机制生成，内部 `\if_cs_exist:w` 判断缓存 csname 是否存在）可以直接吃 **tl 变量**作为 `#`-参数。`\@@_punct_kern_break:NN` 的 `#1` 来自 `\g_@@_last_punct_tl`（tl 类型），参与 `\@@_punct_if_right:NTF` 前必须先 `\exp_after:wN` 展开成字符记号，而参与 `\@@_punct_if_long_p:N` 判断时可以直接传 tl，不需要展开。混用这两类条件时必须先确认各自的参数形式要求。
- **`\@@_punct_kern_break:NN` 延续"选函数再喂参数"的既有模式**：函数体只做条件判断、留下 `\@@_punct_breakable_kern:NN` 或 `\@@_punct_nobreak_kern:NN` 这个函数名，真正的 `#1 #2` 参数由外层 `\@@_punct_kern:NN` 尾部统一喂给最终留下的函数——与原 `\@@_punct_kern:NN` 的既有结构一致，未引入新模式。

基线联动：ctex `punct.tlg`（180+ 测试的大文件）中 `……」` 组合从 `\rule(0pt) + \glue`（可断）变为 `\penalty 10000 + \glue`（禁则保护）——这正是本修复的目标行为，属预期变化，直接 `l3build save punct` 更新基线。

测试：新增 `xeCJK/testfiles/longpunct-kinsoku01.lvt`，用 `\hsize=9em` 窄版面 + `\loggingoutput` 让断行真实发生，覆盖三类禁则违反场景（左引号/括号+破折号、破折号+逗号/句号、破折号+省略号）与两个合法断点保留场景（逗号后断、省略号后断）。

详见决策 [[456-longpunct-kinsoku-both-sides]] 与反思 [[456-longpunct-kinsoku-both-sides]]。

### 标点补偿 glue 的边界保护（`\@@_punct_boundary_guard:`）

全角标点的压缩量通过补偿 glue 实现。但在某些上下文中，`\unskip` 会移除水平列表末尾的 glue，吞掉标点补偿 glue，导致宽度计算错误。`\@@_punct_boundary_guard:` 函数在补偿 glue 之后插入保护节点，防止被 `\unskip` 移除。

- **Inner mode**（`\env{tabular}` 单元格、`\tn{hbox}` 等，#827）：在 glue 之后插入 `\penalty 0`，使最后节点不再是 glue，从而保护补偿 glue 不被 `\\` 触发的 `\unskip` 移除。
- **段落模式**（`experiment/punct-measure-fix` 选项，#859）：LaTeX 的 `\para_end:` 在执行 `\tex_par:D` 之前会通过 `\unskip` 移除水平列表末尾的 glue。如果段末恰好是全角标点，其补偿 glue 也会被移除，导致 `tabularray` 等使用 `\par` 结束测量段落的宏包得到不正确的宽度。

  启用 `experiment/punct-measure-fix` 后，xeCJK 通过以下机制补偿：
  - `\g_@@_par_guard_bool`：全局标志，记录段末是否存在需要保护的标点补偿 glue。
  - `\g_@@_par_guard_dim`：全局尺寸，记录被保护的标点补偿 glue 的自然宽度（`\lastskip`）。
  - `para/begin` 钩子：重置 `\g_@@_par_guard_bool`，避免跨段落残留状态。
  - `para/end` 钩子：若标志为真，插入等宽 `\kern` 补偿被 `\unskip` 移除的 glue 自然宽度。
  - inter-class tokens 重置：当 `Boundary` 之后紧跟其他字符类（`Default`、`CJK`、`FullLeft` 等）时，说明标点不在段末，重置标志。

  **设计权衡**：使用 `\kern` 而非 `\hskip`——`\kern` 不会被 `\unskip` 移除（无需额外保护），也不构成合法断行点。但 `\kern` 只保留了原 glue 的自然宽度，丢弃了弹性分量（stretch/shrink）。对于段末最后一行，`\parfillskip` 的 `0pt plus 1fil` 拉伸量会吸收所有剩余空间，因此弹性丢失在绝大多数情况下无视觉影响。

  使用示例：`\xeCJKsetup{experiment/punct-measure-fix}`

## 间距系统

| 间距类型 | 作用位置 | 默认值 | 配置方式 |
|----------|----------|--------|----------|
| `\CJKglue` | CJK ↔ CJK | `0pt plus 0.08\baselineskip` | `\xeCJKsetup{CJKglue=...}` |
| `\CJKecglue` | CJK ↔ 西文 | `~`（当前字体空格） | `\xeCJKsetup{CJKecglue=...}` |
| 标点 kern | 标点 ↔ 标点/CJK | 由 PunctStyle 决定 | `\xeCJKsetkern` |

### 行内代码语义与 `\xeCJKVerbAddon`（#808）

`\texttt` 只切换字体族，不表达代码语义；同一等宽字体也可能用于允许断行的普通正文。#808 所需的“片段内部取消 CJK–Latin 可见间距并保持半角/全角网格，外部仍有正常正文边界”已由公开命令 `\xeCJKVerbAddon` 提供：它在当前等宽字体度量下校准 CJK 单元、调整 CJK–CJK/CJK–Latin 间距，并禁止作用域内部自动断行。

对可作为普通宏参数读取的短代码，应先切换 `\ttfamily`，再在同一局部分组执行 `\xeCJKVerbAddon`；需要 verbatim 扫描时使用 `\verb`、`\lstinline` 等既有集成。不能把 addon 无条件挂到所有 `\ttfamily`/`\texttt`，否则长篇等宽普通文字会失去断行并产生 overfull。由此不增加“按字体族设置 `CJKecglue`”功能；决策见 [[../memory/decisions/808-inline-code-verb-addon]]。

## 兼容性补丁子系统

xeCJK 通过 `\@@_package_hook:nn` 为第三方包注册延迟加载的兼容补丁：

| 目标包 | 补丁内容 |
|--------|----------|
| `color`/`xcolor` | `\set@color` / `\reset@color` 注册为 `transparent`；`\color@b@x` 注册为 `wrapped-box`（#831/#992） |
| `hyperref` | `\Hy@BeginAnnot` 启动 `auto` stream；顶层 `\Hy@EndAnnot` 报告末尾 math 为 Default 后结束 capture（#809/#810/#972/#992）；行内锚点已覆盖三个出口为 `transparent`——驱动层 `\hyper@anchor` 承接全部 `\hypertarget`，`\Hy@raisedlink` 承接无编号标题、caption、公式编号、脚注、`\bibitem` 与下游手工包裹的抬升锚点，`\__hyp_target_raise:n` 承接 `\phantomsection`／`\MakeLinkTarget` 与编号标题锚点（需用带花括号转发的包装变体）；已知未覆盖 `\hyper@anchorstart` 的裸调用如 `\pdfbookmark`（#1047） |
| `ulem` | 通过 `stream-ulem` 观察实际首尾；framework 决定外侧 glue，`\UL@stop` / `\UL@start` 保证它位于装饰区间外 |
| `pifont` | 输出前先进入水平模式，防止 interchartokenstate 泄漏 |
| `listings` | 用 `\scantokens` 替代 `\lowercase` 字符转换；`\lstinline` 两类扫描入口使用 `auto` stream |
| `url` | 在完整 `\Url@z` 格式化阶段外包围 `default` stream（#880/#992） |
| `hypdoc` | `\HD@target` 注册为 `transparent`；`\meta` / `\cs` 按固定首尾语义注册 stream（#873/#992）；`\meta` 的注册点自 #1046 起为公开命令而非内层参数排版函数 |
| `biblatex` | preamble 结束后把最终 `\let` 目标 `\blx@pagetracker` 注册为 `transparent`（#931/#992） |
| `siunitx` | `\unit`/`\qty`/`\num` 注册为固定 Default 首尾的 `stream`；v2 旧名 `\si`/`\SI` 先检查命令是否存在，再分别注册；`\ang` 的比较对象尚未确定，暂不注册（#1000/#992） |
| `microtype` | 包装 `\MT@get@slot@`，为被重定义为受保护宏的歧义字符查回槽位，`\MT@char` 与 `\MT@char@` 同时设置（#1104）；microtype 完成设置时把 `\MT@ltx@pickupfont` 加入 xeCJK 的字体初始钩子 |

### microtype 的歧义字符槽位（#1104）

xeCJK 在导言区结束时把 `\TS1\textperiodcentered`、`\TU\textendash`、`\TU\textquoteleft` 等歧义字符重定义为受保护的宏，交给西文字体排版，并在 `\g_@@_ambiguous_slot_prop` 里按 `<编码>-<命令>` 记下槽位。microtype 读 `\SetProtrusion` 等配置时不能再从这些宏解析出槽位，`\MT@get@slot` 留下 `\MT@char@ = -1` 并复制给 `\MT@char`。`\xeCJK@microtype@get@slot` 在调用原来的 `\MT@get@slot@` 之前，用 `\@@_get_ambiguous_slot:` 查回记录的槽位。

查回的槽位必须**同时**写进 `\MT@char` 和 `\MT@char@`。microtype 在 XeTeX 下测量字符宽度的 `\MT@get@charwd`（`microtype-xetex.def`）依据 `\MT@char@` 分支：负值表示字形序号，测量 `\XeTeXglyph-\MT@char@`。#1104 之前只设置 `\MT@char`，于是测量的是 1 号字形：TFM 字体（如 NFSS 回退到的 `TS1/cmr`）不允许 `\XeTeXglyph`，报 `Cannot use XeTeXglyph`；microtype 对 TFM 字体的检查写在 `\MT@get@slot@` 里、依据的是 `\MT@char`，此时它已是有效槽位，检查不起作用。OpenType 字体则按 1 号字形的宽度算出错误的突出量，不报错。xunicode-addon 的 `\xunadd@microtype@is@charx` 设置的是 `\MT@char@`，再由 microtype 复制给 `\MT@char`，两者一致。

只有在 microtype 按字符宽度计算的配置下才看得出数值差别。Latin Modern 等有专用配置的字体，`\lpcode`/`\rpcode` 修复前后可能相同；回归测试 `microtype-slot01` 因此用没有专用配置的 TeX Gyre Termes（见 [[../reference/build-and-test]]「microtype 突出量回归」一节）。

传统 `CJK.sty` 与 xeCJK 不可同时加载。xeCJK 通过 `\ctex_disable_package:n` 拦截 `CJK` 等冲突包，因此 #510 中旧 `ruby.sty` 的 `\RequirePackage{CJK}` 现在只产生预期 warning，不再触发 `\CJKglue already defined`。这只是阻止加载冲突，不代表 xeCJK 实现了旧 CJK 的私有 kern-marker 协议；简单 MWE 能编译也不能据此声称完整语义兼容。XeLaTeX 的一般 ruby 推荐加载 PXrubrica，只有出现具体可复现的边界问题时才增加定点兼容，不在 xeCJK 中模拟整套旧协议。决策见 [[../memory/decisions/510-ruby-compatibility-boundary]]。

### 补丁模式

典型兼容补丁遵循同一模式：

```latex
\@@_package_hook:nn { <package> }
  {
    % 在目标包加载后执行
    % 通常重定义目标包的关键命令
    % 在命令内临时 \makexeCJKinactive 关闭 interchar
    % 由 TeX 分组自动恢复
  }
```

## `\char` 原语约束

XeTeX 的 interchar 机制工作在 token 层，无法区分字符来自 Unicode 输入还是 `\char` 原语。这是一个架构级红线：

- `\char` **必须始终保持 XeTeX primitive 身份**
- xeCJK 提供 `\xeCJKchar` 作为「绕过 interchar 的字符输出」接口
- 对已知受影响的包做定点自动补丁（如 `mtpro2`）
- 其他场景需用户手动用 `\makexeCJKinactive` 分组包装

## 扩展子包

### xeCJKfntef

提供 `\CJKunderline`、`\CJKunderdot`、`\CJKsout` 等中文文字效果命令。基于 `ulem` 机制重实现，处理 CJK 字符的下划线位置和连续性。

**线型命令的 leader 相位（#531/#967）**：`ulem` 的 `\leaders` 会把重复的盒子对齐到外层水平列表的相位，而不是当前装饰文字的起点。段首缩进或前置水平位移因而会改变首尾丢弃的不完整盒子，使装饰相对正文等长平移；盒子总宽度保持不变，仅比较 `\wd` 无法捕获。规则型的 `\CJKunderline`、`\CJKunderdblline`、`\CJKsout` 和 `\CJKunderanyline` 在各自 ulem 局部分组内把 `\ULleaders` 设为 `\cleaders`，让每个 leader 区域独立均分余量。#1012 后，默认 `\CJKunderwave` 与 `\CJKxout` 则刻意使用普通 `\leaders`，让正文片段、`CJKglue` 和换行后的片段共享同一个相位网格；首尾是否对称由局部裁切另行保证。只有用户通过 `underwave/symbol` 指定的自定义波浪符号保留 `\xleaders`。逐字放置的 `\CJKunderdot`、`\CJKunderanysymbol` 不走该 leader 路径，`\xeCJKfntefon` 和 ulem 全局状态也不修改。

**周期和斜向装饰的几何（#1012）**：默认波浪与斜删除线均由 `l3draw` 绘制宽 `1em/4` 的图案，尺寸和线宽随当前 `em` 缩放；常规全角字符每字约容纳四个单元，斜删除线不再依赖数学字体。两个默认图案都用普通 `\leaders`，把同一行的所有内部片段固定在一个相位网格上。

普通 `\leaders` 只放置完整的装饰盒子，不能独自精确命中任意端点。首段和真正的末段因此把底层 leaders 区间向两侧各扩展一个周期，再用局部 PDF 裁切限制可见范围：普通形式相对正文左右各外伸半周期，带 `-` 形式左右各内缩半周期；两种形式都保持命令宽度不变，相邻带 `-` 命令之间留下一个完整周期的断口。带 `-` 形式首段后的第一个 `CJKglue` 在可断点两侧各放一个净宽为零的半周期连接；不换行时两半拼合，换行时各自在本行闭合。裁切内部的 leaders 前有 penalty 10000，避免 PDF `gsave`／`grestore` 跨行。

`CJKglue`、普通 `\quad` 和显式 `\hskip` 都继续走 `ulem` 的普通 leaders 路径，不再为波浪另画水平线或为斜线留空。`\UL@spfactor` 哨兵用来区分正文中的真实空格和 `ulem` 追加后又删除的结尾语法空格；首个片段还比较 `\UL@skip` 与正文盒子宽度，避免空参数、`\relax` 或空分组把结尾语法空格改造成不可由 `\unskip` 删除的裁切结构。这样单片段命令只裁切一次，不产生节点的正文仍保持零尺寸，真正的源码空格仍按一个词间空格装饰。`underwave/symbol` 只有保持默认值时才进入上述周期路径；用户自定义符号继续使用历史 `\xleaders` 行为。

末段裁切还需要记录本层是否已经产生后续片段。这个状态按周期装饰的嵌套层压入和
弹出全局序列；内层命令只修改自己的栈顶，结束时不会覆盖外层状态。共享全局布尔在
“外层已有后续片段、末尾嵌入单片段周期装饰”时会让外层漏画末段，不能用于这里。

`l3draw` 会把负纵坐标归一化成盒子高度，所以斜线绘图盒子本身的 depth 为零。默认斜线约高 `.93em`，使用时整体下移 `.09em`，实际覆盖约为基线下 `.09em` 至基线上 `.84em`；这与常见全角汉字的深度和高度相符，避免斜线只覆盖基线以上。

`1em/3` 加原 leaders、没有裁切的朴素普通 `\leaders`，以及 `\cleaders` 加胶水专用图形，都是已经被当前分工替换的中间路线。当前方案保留普通 `\leaders` 的共享相位优势，再把可见端点和断行接点交给独立机制。这一约定由 `fntef-phase01` 的页面坐标检查与节点、视觉回归测试共同保护。

**边界状态与装饰盒子隔离（#826/#830/#992）**：`\xeCJK_fntef_sbox:n` 渲染装饰符号时调用可嵌套的 capture suspend/resume，按层保存并恢复 `\g_@@_last_node_tl` 与 source-space pending，同时阻止 scratch glyph 被外层 stream 当作正文。原生 ulem 与 xeCJKfntef 线型命令相互嵌套时，只有最外层拥有 `stream-ulem`；内层复用该层，不能重复 begin，因为 `\UL@onin` 路径没有独立 end（线型／符号型的分类与「内层因此无法断行」这一用户可见后果见上文 `stream-ulem` 小节）。ulem 结束时把内部真实末尾 marker 移到外层列表，由唯一的 stream end 读取并更新本层末类别。ulem 在丢弃的片段盒子里排出的结束定界符 `*` 不被观察：`\UL@end *` 吃掉定界符时暂停 capture，`\@@_ulem_end:` 关闭该片段盒子后恢复（#1091，见下文「ulem 结束符与入口空格」）。因此只要正文末尾确实是字符（含嵌套线型命令排出的盒子），即使列表末尾没有 marker，末类别也仍来自正文实际的最后一个字符，不会被 `*` 覆盖成 default；正文末尾是空白、盒子等其他内容或全角右标点时，末类别改由 capture 的 `tail` 字段决定（见下文「ulem 结束符与入口空格」的右边界一条）。旧的 fntef saved-last-node 与颜色方向专用 save/restore 均已删除。

**PDF 文本语义隔离（#1017）**：波浪线、斜删除线、着重号和用户自定义符号可能由真实字符、数学内容或绘图组成，再由 `ulem` 的 leaders 重复排出。它们虽然只承担视觉装饰作用，仍需明确排除 PDF 文本语义。`\xeCJK_fntef_sbox:n` 因此用空的 `ActualText` 包住装饰盒子；在 LaTeX tagging 接口存在时，还在构造盒子的最小范围内调用 `\tag_suspend:n` 和 `\tag_resume:n`。后一步不可省略：字符或数学装饰产生的内层标记可能穿过外层 `ActualText`，重新暴露装饰内容。这里的 PDF 语义隔离、boundary capture 暂停／恢复和 #1012 的默认图案几何分别解决文本提取、命令边界状态和装饰外观，三者不能互相替代。

**外侧 glue 不参与装饰**：首次可见类别出现时，`stream-ulem` 让 framework 统一选择 `CJKglue`、`CJKecglue` 或源码空格的数值；若此时处于 ulem 扫描状态，就先 `\UL@stop`，排普通 elastic skip，再 `\UL@start`。这样 glue 保留伸缩与断行位置，不变成 underline 的 `\leaders`。本层 `entry` 已为 resolved 时这一步只关闭再重开片段盒子、不补 glue（见下一段）。`command-boundary01` 覆盖 `\CJKunderline`、`\CJKunderdot`、`\CJKsout` 与原生 `\uline` 的四种源码空格，并覆盖原生 ulem 与 fntef 线型/符号命令的双向嵌套；逐格 idle-stack 断言要求 capture depth、active stack 与 suspend depth 全部归零。`command-boundary02` 以节点日志确认 `\uline` 左右的 1pt CJKglue 位于装饰区间外；`fntef-color01` 的 12 项继续覆盖 fntef(color) 与 color(fntef) 两个方向。

**ulem 结束符与入口空格（#1091）**：这里有几层问题，要分开处理：结束定界符、入口空格的位置、全角左标点开头，本地审查 R1–R9 后补修的右边界与开头语法空格，嵌套内层与盒子里全角标点之后还有字符时的类别报告，嵌套内层正文最后一个字符之后还有内容时的 `tail` 判断，以及 R9 后补修、R10 与 R11 后改进判断方法的全角左标点结尾与嵌套命令左右两侧的连接（R11 起内层开头总是重放 marker，并由核心钩子 `\@@_boundary_emit_left_hook:nn` 处理内层以非字符内容开头的左边界；R12 起核心在 transparent 命令前后另有两个钩子，使内层以颜色命令开头时颜色 whatsit 不算内容，并把是否清除重放后的源码空格检查改为读进入命令时保存的 `xCJKecglue`；R13 起“入口之后排出过透明命令”的布尔量跟随入口的生命周期，`ulem-transparent` marker 仍在列表末尾时删去（被其他内容压住时留在颜色命令所在的内层盒子里）；R15 起中间层在更深一层装饰之前排出的内容同样不补左边界；`a8b45cf4` 起这些检查不再限于嵌套链，单层正文与嵌套命令之前的外层正文同样检查第一个字符之前排出的盒子、penalty 与公式，核心另有透明盒子钩子，见下文「正文先排出盒子、penalty、公式」一条）。

- **结束定界符 `*`。** ulem 用 `\UL@end *` 标记正文结束。最后一个“词”由 `\UL@start` 打开片段盒子后，`\UL@word`（及 `\xeCJK_ulem_word:nw`）中的 `\if_meaning:w \UL@end #1` 会把参数里的第二个 `*` 留在真分支开头，它作为普通字符排进随即被丢弃的片段盒子，触发 Boundary→Default 转换。修复前 capture 把它当成正文字符：正文没有字符或以全角左标点开头时首类别在 `*` 处取得，左边界被补到装饰末尾，并借 `\UL@stop … \UL@start` 把结尾语法空格和空片段盒子画成多余装饰（`符\CJKunderline{}后` 29.99pt，应为 20pt）；正文末尾没有 marker 时末类别被写成 default（`\CJKunderline{中。}文` 句号后多 3.33pt）。现在 xeCJKfntef 把 `\UL@end *` 重定义为 `\@@_boundary_capture_suspend:`，`\@@_ulem_end:` 在关闭丢弃盒子的两个 group end 之后调用 `\@@_boundary_capture_resume:`；暂停可嵌套，并按层保存、恢复 `\g_@@_last_node_tl` 与 pending，`*` 留下的状态一并撤销。`\UL@onin`／`\UL@onmath` 不经过 `\UL@end`，暂停与恢复总是成对。ulem 的每个线型命令还调用 `\UL@setULdepth`，在 `\ULdepth` 仍为 `\maxdimen` 时把 `(j` 排进一个原始 `\hbox` 量装饰线深度；`(` 触发 Boundary→Default 转换，外层 capture 会把 `default` 记为首类别，`x\mbox{\uline{中}}` 因此丢失 `\mbox` 前的 `\CJKecglue`（v3.10.6 同样）。`a8b45cf4` 起 xeCJKfntef 把 `\UL@setULdepth` 包成“`\@@_boundary_capture_suspend:`、原定义 `\@@_ulem_orig_set_depth:`、`\@@_boundary_capture_resume:`”，与 `\UL@end` 吃掉定界符时的处理相同。
- **入口空格的位置。** capture_begin 取下入口源码空格与 marker，等首类别再决定左边界；但正文若在第一个字符之前先排出有宽度的内容（盒子、规则、`\hspace*`、`\quad`），ulem 已把它们排到外层列表，之后补的 glue 只能落在其后，正文没有类别时 stream end 的 `\@@_boundary_replay_before:` 更会把空格放到装饰之后。为此每层 capture 新增字段 `g_@@_boundary_capture_<n>_entry_tl`（allocate 时新建、capture_begin 时清空），取值 `armed`、`resolved` 或空；只有 `stream-ulem` 使用。`\@@_ulem_stream_begin:` 启动 stream 后由 `\@@_ulem_entry_arm:` 在 active 时把本层置为 armed，并记录 `\g_@@_ulem_entry_depth_int`（`\@@_ulem_end:` 清零）。
  - 判断点有两处，都在 ulem 把内容排到外层之前。一是重写的 `\UL@stop`（除插入 `\@@_ulem_entry_box:`、下文的 tail 与开头语法空格处理外与 ulem 2019/11/18 相同），在调用 `\UL@putbox` 前检查片段盒子：宽度非零，或末节点为规则（`\hspace*` 用零宽 `\vrule` 保住间距，`\lastnodetype`=3），才算可见；只含颜色 special、锚点等不可见节点的片段不算，因此 `符 \CJKunderline{\color{red}中} 后` 仍按首字符规则处理，与直接输入一致。二是 `\UL@reskip`（现为 `\UL@stop`、tail 判断、`\@@_ulem_entry_skip:`、`\@@_ulem_lead_draw:`、`\UL@leaders`、`\UL@start`），`\UL@skip` 非零即算可见。ulem 词间的语法空格不在这里判断：开头的语法空格若随后跟着字符，入口空格仍要按首类别处理，所以它改为先记账（见下文「开头语法空格」一条）。旧文档曾写“因为正文末尾那一枚会被 `\unskip` 删去”，这不准确：被 `\@@_ulem_end:` 的三个 `\unskip` 删去的是 ulem 在 `\UL@end` 前自己补的那枚语法空格，不是正文里的空格。
  - 满足判据时 `\@@_ulem_entry_resolve:n` 把本层置为 resolved；入口 marker 不是 `math-space`／`math-space-frozen` 且 space_flag 为真时，直接 `\skip_horizontal` 排出入口空格（此时已在片段盒子之外，不能走 ulem 通道），再把 space_flag 置假。
  - resolved 之后有三处不再补 glue 或重放：`\@@_boundary_capture_emit_left:nn` 不补左边界（无论是否补，首类别出现时都清空 `entry`）；`\@@_boundary_inline_stream_end:n` 在没有首类别时不调用 `\@@_boundary_replay_before:`；`\@@_boundary_use_ulem_glue:nn` 的片段级分支 `\@@_boundary_use_ulem_glue_outer:nn` 在 `\UL@stop` 之后检查（可能正是这次 `\UL@stop` 触发了 resolve，如 `\usebox\tri中`），resolved 则不补 glue、直接 `\UL@start`。
  - 新语义与 v3.9.1 和 `~` 写法一致：正文先排出可见内容时，命令前的源码空格原样留在装饰之前；首字符在这段内容之后不再补左边界，与直接输入 `\quad x` 不补 ecglue 一致；右侧不再重放入口 marker。用户向说明见手册 §3.6.2「用线型命令排填空线」（`\label{subsubsec:fntef-fill-in}`）。
- **全角左标点开头。** Boundary→FullLeft 不经过报告类别的 Boundary→CJK 转换，入口判据会把标点左侧空白当成“先排出的可见内容”，空格于是落在该空白与标点之间。因此 `\@@_ulem_Boundary_and_FullLeft_glue:N` 的 ulem 分支在 `\UL@stop` 之前先 `\@@_boundary_capture_class:n { CJK }`，使 `书 \CJKunderline{《红》}的` 与直接输入等宽（50pt）、左边界位于标点左侧空白之前。
- **右边界看正文怎样结尾（`tail` 字段，#1091 本地审查 R1 后补修）。** 结束符 `*` 不再覆盖末类别后，stream end 只剩 capture 观察到的最后一个字符；正文在这个字符之后还有空白、盒子等内容时（`姓名 \CJKunderline{张三\hspace*{4em}} 学号`），命令后的源码空格被按 CJK 规则删去，而直接输入时这枚空格前面是 glue、会原样保留。为此每层 capture 新增 `g_@@_boundary_capture_<n>_tail_tl`（allocate 时新建、capture_begin 时清空），取值 `char`／`content`／`punct`，R9 起还有表示“最后排出的是全角左标点”的 `left`（见下文「全角左标点结尾」一条）：
  - **置 `char`**：`\@@_boundary_capture_class:n` 每次报告类别时，以及公式结尾被确认、末类别记为 math 时。
  - **置 `content`**（经 `\@@_ulem_tail_content:`，只在 `\g_@@_ulem_entry_depth_int` 非零、即本层是实际启动的 `stream-ulem` 时生效）：`\UL@reskip` 画非零显式 glue（`\hspace`、`\quad`、控制空格等）；`\UL@stop` 从片段盒子末尾取到非零 penalty；`\@@_ulem_tail_check:` 在正文结束处（`\@@_ulem_body_end:`）和 `\@@_ulem_loop:nw` 每个语法空格之前检查当前片段盒子的末节点；R8 起，嵌套内层正文结束处还由 `\@@_ulem_onin_tail_check:` 检查内层盒子的末节点（见下文「内层正文末尾检查」）。末节点是 marker（相互抵消的一对 kern）、字符、连字、公式或 glue，以及片段盒子为空（只剩 ulem 开头的 `\kern-3sp\kern3sp`）时不改；其余节点（盒子、规则、零宽或不成对的 kern、special、penalty 等）都置 `content`。glue 不改，是因为正文里的显式 glue 都经 `\UL@reskip` 排到片段盒子之外，留在片段盒子里的只有“公式尾＋尾随源码空格”重排路径补回的那类边界机制自己的空格（去掉这一条时 `command-boundary-math05` 的 `stream-ulem` correction 变 0、badness 变 1000000）。字符之后的颜色切换、`\mbox` 不触发判断，因为边界机制已在它们之后重放了 marker。
  - **嵌套线型命令用 `ulem-nest` marker 识别（R2 后）**：`\UL@onin` 把内层正文装进一个盒子，外层片段盒子的末节点因此是盒子，但内容是文字。`\@@_ulem_nest_mark:` 在内层命令排出的盒子之后补一个 `ulem-nest` marker（`\xeCJK_declare_node:n { ulem-nest }` 声明，与其他 marker 一样是相互抵消的一对 kern）。它在 `\xeCJK_if_ulem_patch:TF` 为真、即外层片段盒子这一层补，`\mbox` 等盒子内部不补；R8 起，嵌套链上的中间层（非 patch 分支、`\l_@@_ulem_onin_bool` 为真、末节点是盒子）也在更深一层命令排出的盒子之后补，中间层的 `\@@_ulem_onin_tail_check:` 按字符处理；只有末节点正是这个 marker 时才删去它，后面还有别的内容时零宽 marker 留在中间层盒子里（R9-M2 改正了“检查后删去、不留在中间层盒子里”的旧说法）。R9 起补哪一种 marker 由 `\@@_ulem_nest_node:` 选择，不一定是 `ulem-nest`，见下文「嵌套命令左右连接」一条。末节点检查（`\@@_ulem_tail_check_kern:`）把它当作 marker，按字符处理；之后再排出的任何盒子都成为新的末节点，按 `content` 处理，包括 `\hbox{中}`、与内层盒子尺寸相同的 `\usebox`，以及 `\raise\copy` 这类不新建盒子的写法。检查只读末节点，不取下盒子。`\@@_ulem_body_end:` 检查后若末尾正是 `ulem-nest` marker，就用两次 `\unkern` 删去；R9 起补的若是 CJK／default marker，`\@@_ulem_body_end:` 不删它，它与普通字符的 marker 一样留在片段盒子末尾；右边界仍取 capture 观察到的末类别，所以 `fntef-nest-linebreak01` 的基线不变。
    - R1 曾按宽、高、深识别内层盒子：检查时用 `\lastbox` 取下末尾盒子比对再放回，记录在 `\UL@stop` 和 `\UL@hrest` 处清除。R2 审查发现这种做法有两个问题：`\lastbox` 会把盒子的 `\raise` 位移清零（`\CJKsout{中}\raise2pt\copy\FillBox`，R1 的测试用 `\raisebox` 新建盒子，没有经过这条路径）；尺寸相同的 `\usebox` 会被误认为嵌套装饰。marker 方案不取下任何节点，这两个问题都不再出现。
  - **`\@@_ulem_body_end:` 之后不再改 `tail`**：它检查完正文末尾后置 `\g_@@_ulem_body_end_bool`，ulem 随后补的语法空格和结束符都不是正文。
  - **stream end 见 `content`**：`\@@_boundary_inline_stream_end:n` 把末类别改为不在重放列表中的 `content`，不重放 marker，命令后的空格按普通空格保留、后面的字符也不补边界 glue；并改排一个零宽 kern 代替 marker。原因是 ulem 画完每段装饰后都跟一个负的像素补偿 glue，装饰在段末时若列表以它结尾，`\par` 会当作行尾 glue 删掉，线就多出一个像素；marker 原来挡住了这一点，零宽 kern 起同样作用而不影响后面的判断（`fntef-linebreak01` 段末因此由一对 marker kern 变为 `\kern 0.0`）。
  - **全角右标点结尾：正文末尾的扫描标记加 peek（R3 后）**：直接输入时 `\xeCJK_FullRight_and_Boundary:` 排出标点补偿 glue 后用 `\ignorespaces` 吃掉后面的空格，列表末尾没有 CJK marker，西文前也不补 `\CJKecglue`；装饰正文里同样的处理只作用于正文内部，命令外仍按 CJK 处理，于是 `2fb2a93b` 让 `\CJKunderline{中。}x` 在 x 前多出一枚间距（修复前与直接输入一致）。`\ignorespaces` 碰到第一个非空格记号就停下，所以只有标点之后除空格外再没有别的记号时，命令后的空格才应被吃掉。为此 `\UL@on` 与 `\UL@onin` 在正文 `#1` 之后、`\@@_boundary_math_end:n` 之前多放一个扫描标记 `\s_@@_ulem_body`（`\scan_new:N` 声明，含义是 `\relax`，不产生节点）；`\@@_ulem_FullRight_and_Boundary:` 里原来的 `\ignorespaces` 换成 `\@@_ulem_punct_peek:`。R4 后它先看下一个记号是不是空格（R6 起用 `\peek_meaning_remove:NTF \c_space_token` 按含义比较，理由见下一条）：是空格（正文末尾的空格，或 ulem 分词后在词与词之间补回的词间空格）就置 `content` 并照常 `\ignorespaces`（R5 后这一段拆为 `\@@_ulem_punct_peek_space:`）；不是空格时，下一个记号是 N 型且就是这个标记才置 `punct`，否则置 `content`（`\@@_ulem_punct_peek_aux:N` 用 `\token_to_str:N` 比较后把记号放回）。R3 用 `\peek_remove_spaces:n` 先跳过空格再看标记，单层写法 `\CJKunderline{中。 } x` 的结果正确；但嵌套内层的正文不按空格分词，“标点＋末尾空格”在跳过空格后直接看到标记，被误置为 `punct`（见下文嵌套一条）。空格优先判断让两条路径对空格的处理一致。
    - **`CheckFullRight=true` 时标点自己先删去空格（R5 后）**：打开该选项后，全角右标点字符本身的 `\xeCJK_check_FullRight_symbol:Nw` 先删去其后的空格再查看下一个记号，`\@@_ulem_punct_peek:` 看不到这枚空格、直接看到扫描标记，于是 `\CJKunderline{中。 } x`、`\uline{\sout{中。 }} x` 及三层嵌套的同类写法都吃掉了命令后的空格（v3.10.6 与直接输入一致；单层自 `7a817059`、嵌套自 `8d1d9a34` 起失败）。现在 `\xeCJK_check_FullRight_symbol:Nw` 先用 `\peek_meaning_remove:NTF \c_space_token` 判断：删去了空格就把新布尔 `\g_@@_FullRight_space_bool` 置真，再照旧 `\peek_remove_spaces:n`；没有空格就置假（每个标点都重新设置，所以 `中。 {}中。` 里后一个标点不受前一个影响）。`\@@_ulem_punct_peek:` 见到它为真就直接置 `content`，否则进入 `\@@_ulem_punct_peek_space:` 走原来的判断，结果与不打开选项时相同。`CheckFullRight=false` 时复位该布尔，以免残留值影响之后的标点。
      - **比较方式必须按含义（R6 后）**：R5 起初用 `\peek_charcode_remove:NTF`，它只比较字符码，字符码为 32 的活动字符（`\verb`、`\verb*` 与 `\obeyspaces` 下的空格都是这样的记号）也被当成空格删去；打开 `CheckFullRight` 后 `\verb|中。 a|` 由 30.5pt 变为 25.25pt（v3.10.6 与 `f8f3f731` 都正确）。被替换的 `\peek_remove_spaces:n` 按含义比较，只删显式或隐式的空格记号，R6 改用 `\peek_meaning_remove:NTF` 与它一致。`\@@_ulem_punct_peek_space:` 同样改为按含义比较；这一处目前没有能区分两种比较方式的用例，属一致性修改。
    - `tail` 为 `punct` 时，`\@@_ulem_end:` 中 `\@@_ulem_tail_punct_end:` 把它换成 `content`（stream end 不重放 marker）并置 `\l_@@_ulem_tail_punct_bool`，`\@@_ulem_end:` 最后据此执行 `\ignorespaces`，吃掉命令后的空格。为 `content` 时命令后的空格保留、西文前不补间距，与直接输入 `中。\relax{} x` 一致。标点在内层分组里时下一个记号是 `}`，不是标记，按 `content` 处理，与 `{中。} x` 一致。标点后若还有字符或其他内容，`tail` 会被随后的判断改写。
    - **R2 的分组层级规则已删除**：R2 用 `\@@_ulem_tail_punct:` 记下标点所在分组层级（`\g_@@_ulem_punct_level_int`），`\@@_ulem_tail_check:` 发现层级变浅时改为 `content`。它只模仿了“分组结束”这一种停止条件；标点后是 `\relax`、`{}`、`\hspace{0pt}`、包装宏（`\newcommand\ans[1]{#1\relax}`）或正文末尾空格等不产生节点的记号时，命令后的空格仍被吃掉（R3-B1）。扫描标记直接对应 `\ignorespaces` 的停止条件，不再逐个补情况。
    - **嵌套线型命令的内层以全角右标点结尾（R3 后）**：`\UL@onin` 把内层正文排进盒子，不经 ulem 扫描，其中的标点走原生 `\xeCJK_FullRight_and_Boundary:`（`\xeCJK_if_ulem_patch:TF` 为假的分支）。`2fb2a93b` 使 `\CJKunderline{\CJKsout{中。}}x` 与直接输入不同（v3.10.6 与直接输入一致），有空格的 `\CJKunderline{\CJKsout{中。}} x` 则修复前后都不一致。现在 `\UL@onin` 的正文开头置 `\l_@@_ulem_onin_bool`，原生分支在它为真时也调用 `\@@_ulem_punct_peek:`；`\UL@hrest` 在每个新盒子开头把它置假，所以 `\mbox{文。}` 里的标点不受影响。`\@@_ulem_nest_mark:` 补 `ulem-nest` marker 后，若 `\g_@@_ulem_entry_depth_int` 所指那一层的 `tail` 为 `punct`（说明标点紧接内层正文末尾），就在外层再调用一次 `\@@_ulem_punct_peek:`，看内层命令之后的记号。这次调用先经 `\l_@@_ulem_nest_punct_bool` 记下结果、放在所有条件分支之外执行，否则 peek 看到的是条件分支的 `}`。
      - **onin 布尔只在直接从外层片段盒子进入时置真（R4 后）**：R3 在内层正文开头无条件置真，`\uline{中\mbox{\sout{文。}}} x` 里 `\mbox` 开头 `\UL@hrest` 已把布尔置假，盒子里的 `\UL@onin` 又把它重新置真，标点处的 peek 把外层 `tail` 置为 `punct`，外层命令后的空格被吃掉（v3.10.6 与直接输入一致）。现在 `\UL@onin` 进入时先算 `\l_@@_ulem_onin_enter_bool`：`\xeCJK_if_ulem_patch:TF` 为真（直接从外层片段盒子进入）就置真，否则继承当前的 `\l_@@_ulem_onin_bool`；内层正文开头用它设置 onin 布尔。盒子里的嵌套链因此继承已清除的状态，按普通内容处理；三层以上的连续嵌套仍在链上，布尔保持为真。
      - **内层“标点＋末尾空格”（R4 后）**：`\uline{\sout{中。 }} x` 中原生 `\xeCJK_FullRight_and_Boundary:` 末尾的 `\ignorespaces` 遇到紧随其后的受保护函数 `\@@_ulem_punct_peek:` 就停下，末尾空格留给 peek；peek 的空格优先判断把 `tail` 置为 `content` 后再吃掉空格，外层命令后的空格保留，与单层写法 `\CJKunderline{中。 } 后` 一致。
      - **三层嵌套的中间层（R4 后）**：`\uline{\sout{\xout{中。}\relax}} x` 中，中间层 `\@@_ulem_nest_mark:` 所在的盒子里 `\xeCJK_if_ulem_patch:TF` 为假；R3 在这一分支什么都不做，中间层标点之后的 `\relax` 没有被看到。现在非 patch 分支中，若 onin 布尔为真（仍在嵌套链上）且当前层 `tail` 为 `punct`，同样经 `\l_@@_ulem_nest_punct_bool` 在条件分支外调用 peek。R4 时这一分支不补 marker，R8 起它也在更深一层命令排出的盒子后补 marker（见上文 marker 一条与下文「内层正文末尾检查」）；R9 前 dtx 注释与本条仍写“中间层不补 marker”，R9-M1 改正。
  - **全角左标点结尾（R9 后，R10 补修）**：直接输入时，Boundary 前的全角左标点排出 `\penalty10000 \glue0pt` 后 `\ignorespaces`，后面的空格被吃掉，列表末尾没有类别 marker，所以 `符 中（ 后` 的“（”与“后”之间没有空格、`符 中（x` 在 x 前也不补间距。装饰正文里原来只有 ulem 分支 `\tex_ignorespaces:D`，吃掉的是正文内部的空格，命令外仍按 CJK 结尾处理；单层写法在 v3.10.6 上同样与直接输入不一致。R8 的 `\@@_ulem_onin_tail_check:` 又把内层盒子末尾这枚 `\glue0pt` 当成正文内容，置 `content`，于是 `符 \uline{\sout{中（}} 后` 为 43.33pt（直接输入与 `b59d2525` 都是 40.0pt），`\CJKunderline{\CJKsout{中《}}`、三层嵌套与 `\uline{\uwave{中“}}` 同样如此（R9-I1）。现在的做法：
    - `\@@_ulem_FullLeft_and_Boundary:` 的 ulem 分支把 `\tex_ignorespaces:D` 换成 `\@@_ulem_left_punct_peek:`；非 ulem 分支在嵌套链上（onin 布尔为真）也调用它。它看下一个记号：是空格就置 `tail=left` 并 `\ignorespaces`；是 N 型记号且正是扫描标记 `\s_@@_ulem_body`（`\@@_ulem_left_punct_peek_aux:N` 用 `\token_to_str:N` 比较后放回记号），就复位 `\g_@@_FullRight_space_bool` 并置 `punct`，命令后的空格由 `\@@_ulem_end:` 的 `\ignorespaces` 吃掉；其他记号置 `left`。复位是因为前面的全角右标点可能在 `CheckFullRight=true` 下把它置真，不复位时 `cfr-nested-right-left-space-latin`（`符 \uline{\sout{中。 中（}} x`）失败。
    - `left` 表示“最后排出的是全角左标点”，标点自己的 `\penalty10000 \glue0pt` 还在列表里。之后再报告字符类别时，`\@@_boundary_capture_class:n` 照常改回 `char`；`\UL@reskip` 画零宽显式 glue（`\hspace{0pt}`）时，`\@@_ulem_tail_left_content:` 在 `tail` 为 `left` 时改为 `content`（非零 glue 本来就置 `content`）。
    - 结束时 `\@@_ulem_tail_punct_end:` 把 `left` 换成 `content`（stream end 不重放 marker）并置 `\l_@@_ulem_tail_left_bool`；`\@@_ulem_end:` 据此在外层用 `\xeCJK_punct_node:N` 重放 `\g_@@_last_punct_tl` 的标点 marker，再用 `\@@_nobreak_zero_glue:` 排 `\penalty10000 \glue0pt`，与直接输入 `中（\relax{} 后` 一致：后面的空格按标点之后的空格处理，西文前不补间距。
    - 嵌套链上的内层正文里，标点之后这两个节点留在内层盒子里。R10 起，非 ulem 分支在嵌套链上先调用 `\@@_ulem_left_punct_mark:`，再调用 `\@@_ulem_left_punct_peek:`。`\@@_ulem_left_punct_mark:` 见到末节点是 glue、glue 前是 `\penalty10000` 时，取下这两个节点，补一个 `ulem-left` marker（`\xeCJK_declare_node:n { ulem-left }` 声明，零宽），再把两者放回，内层盒子里于是依次是标点、`ulem-left` marker、`\penalty10000`、`\glue0pt`。`\@@_ulem_onin_tail_check:` 见到末节点是 glue 时调用 `\@@_ulem_onin_tail_glue:`：`tail` 为 `left`、glue 前是 `\penalty10000`、penalty 之前正是 `ulem-left` marker 时，才认作标点自己排出的一对节点，不置 `content`；其余情况都置 `content`。
    - **R9 的排除法判断过宽（R10-I1）**：R9 的判据是“glue 前是 `\penalty10000`、再前面不是 glue”，本意是区分 `中（\nobreak\hspace{0pt}`（那里 `\hspace{0pt}` 的 glue 前面也是 `\penalty10000`，再前面是标点的 glue，`nested-left-nobreak-hspace0`）。但标点之后若先有盒子、kern、规则、special 或 `\label`，再有用户写的 `~` 或 `\nobreak\hspace`，“再前面”就不是 glue，用户的节点被误认成标点自己的，`符 \uline{\sout{中（\mbox{}~}} 后` 为 43.33pt，直接输入 46.66pt（`cf9a1744` 与 v3.10.6 正确）。改为认本包自己放的 marker 后，这类写法按 `content` 处理，与直接输入 `中（\mbox{}~ 后` 一致。
    - **标点在正文内的分组里时仍未处理（R10-M1 更正说法）**：`\uline{{中（}} 后`、`\uline{\textbf{中（}} 后` 中标点的下一个记号是分组结束，置为 `left`，结束时按 `中（\relax{} 后` 处理，命令后的空格保留；直接输入 `{中（} 后` 里标点处的 `\ignorespaces` 在分组结束处停下，但分组之后的空格仍被边界处理删去，两者差 3.33pt（所有版本都不对）。R9 的 CHANGELOG、`\changes` 与 lvt 注释把“分组结束”也算进已处理的情况，R10 改为“正文以全角左标点结尾、标点不在正文内的分组里时……”，lvt 注释注明分组情形尚未处理，dtx 补写了上述原因。
  - **嵌套命令左右连接（R9 后，R10 补修）**：`\UL@onin` 把内层正文装进盒子，盒子两侧与外层字符之间的类别转换原来都断开了：盒子后面补的是 `ulem-nest` marker，外层下一个字符不按普通类别转换补 `\CJKecglue`；盒子里第一个字符也看不到外层前一个字符的 marker。`2fb2a93b` 起 `符 \uline{\sout{\xout{x}中}} 后` 为 38.61pt，直接输入 41.94pt（R9-I2）；`ef49ca4e` 与 v3.10.6 正确，但 v3.10.6 是碰巧：结束符 `*` 被当成西文字符，多出的一枚间距抵消了这里缺少的一枚。两层写法 `符 \uline{\xout{x}中} 后`、`符 \uline{中\xout{x}中} 后` 在 v3.10.6 上也不对，v3.9.1 正确。
    - 右侧：`\@@_ulem_nest_mark:` 补的 marker 改由 `\@@_ulem_nest_node:` 选择。入口层 `tail` 为 `char` 且末类别是 `CJK` 或 `default` 时，补这个类别的 marker，外层后面的字符按普通类别转换与它连接；其余情况仍补 `ulem-nest`。`\l_@@_ulem_nest_node_tl` 记下补了哪一种，删除规则见上文「内层正文末尾检查」。
    - 左侧：`\UL@onin` 进入前读当前列表末尾的 `CJK`、`CJK-space` 或 `default` marker（按这个顺序逐个比较，取第一个匹配的；`a8b45cf4` 起末节点是公式时记为 `math`，见下文「正文先排出盒子、penalty、公式」），记在 `\l_@@_ulem_onin_lead_tl`，在内层正文开头用 `\xeCJK_make_node:n` 重放一次，`\uline{x\sout{中}}` 的 x 与“中”之间因此与直接输入一样有间距；`\mbox` 里的 `\uline{x\mbox{x\sout{中}}}` 同样如此。`CJK-space` 是 R12 补上的：汉字后接源码空格时外层末尾是这种 marker，R11 只认 `CJK`、`default`，`中\uline{中 \sout{\mbox{a}中}}中`（48.33pt，直接输入 51.66pt）与 `CJKspace=true` 下的 `中\uline{中 \sout{中}}中`（40.0pt，直接输入 43.33pt）因此都缺一枚间距，现在与直接输入一致。R10 起读取与重放拆成两个函数：`\@@_ulem_onin_lead_get:n` 在 `\@@_boundary_if_ulem_math_reorder:nTF` 分支之前调用，`\@@_ulem_onin_lead_put:` 在非重排分支的内层正文开头调用。正文第一个字符的类别转换会取走这个 marker；正文为空，或第一个字符之前先排出了规则、盒子、glue、kern 等节点时，这个零宽 marker 留在内层盒子里（R10-M2 更正了 R9 “不留在盒子里”的说法，R11-M1 补上 glue、kern 开头的情形）。
    - **内层正文以空格开头：总是重放，由类别转换按选项处理（R11 后）**：直接输入 `中{ 中}` 时，这枚空格在 `xCJKecglue=false` 下按普通空格保留，在 `xCJKecglue=true` 下被换成 `\CJKecglue`。R10 曾用 `\@@_ulem_onin_if_lead_space:n` 按记号形式判断内层正文是否以空格开头（空格记号、`\ `、一层分组里的空格），是则不重放；它漏掉了 `\space` 与多层分组（`\uline{中\sout{\space 中}}`、`\uline{中\sout{{{ 中}}}}` 仍为 20.0pt，直接输入 23.33pt），又使 `xCJKecglue=true` 下与直接输入不一致（R11-I1、R11-I2），R11 删去了这个判断。现在 `\@@_ulem_onin_lead_get:n` 只读外层末尾的 marker，`\@@_ulem_onin_lead_put:` 总是重放；重放后若进入装饰命令时的 `xCJKecglue` 为假，就清除 `\g_@@_glue_check_pending_bool`，内层开头的空格按普通空格保留；为真时保留这次检查，空格由后面字符的类别转换换成 `\CJKecglue`，与直接输入一致。ulem 正文里 `xCJKecglue` 固定为假，所以不能读当前选项：`\xeCJK_hook_for_ulem:` 在首次调用 `\@@_ulem_hook:`（它把 `xCJKecglue` 改为假）之前，把 `\l_@@_xecglue_bool` 存入 `\l_@@_ulem_xecglue_bool`，`\@@_ulem_onin_lead_put:` 读这个值。R11 读的是入口 capture 层（`\g_@@_ulem_entry_depth_int` 指向的那一层）的 `xecglue_flag` 字段，只在层号大于零时才可能清除；`\sbox` 等暂停 capture 的环境里 `\@@_ulem_entry_arm:` 把层号置为 0，pending 于是保留，`\sbox\SB{\uline{中\sout{ 中}}}` 为 20.0pt，直接输入 `\sbox\SB{中{ 中}}` 与 v3.10.6 都是 23.33pt（R12-I2）。R12 改读 `\l_@@_ulem_xecglue_bool` 后不再依赖 capture 层。空格写成空格、`\ `、`\space` 还是多层分组里的空格，都走同一条路径。
      - **例外：内层命令前的字符在分组里（R12-M1，未改）**：直接输入 `{中}{ 中}` 时，分组结束触发的 CJK→Boundary 转换开启检查（#831），空格被删去，为 20.0pt；`\uline{{中}\sout{ 中}}` 到达 `\@@_ulem_onin_lead_put:` 时 pending 同样为真、lead 同样是 `CJK`，与 `\uline{中\sout{ 中}}` 无法区分，于是仍按普通空格保留（23.33pt），与 v3.10.6 相同。`\uline{{中}\sout{\space 中}}` 与 `\uline{{中}\sout{{{ 中}}}}` 在 R10 的代码（`bb321f36`）上碰巧与直接输入一致，R11 起也是 23.33pt。dtx 注释写明了这一点，登记在 [[../memory/doc-gaps]]。
    - **内层盒子里的词间空格随当前字体（R11 后）**：xeCJKfntef 在 ulem 初始化里重定义 `\xeCJK_space_glue:`：在 ulem 片段盒子里（`\xeCJK_if_ulem_patch:TF` 为真）用 `\@@_ulem_glue:n \l_@@_space_skip`，否则用保存的原定义 `\@@_ulem_orig_space_glue:`。R11 前内层盒子里也用进入命令时缓存的 `\l_@@_space_skip`，`CJKspace=true` 时 `\uline{中\sout{\textbf{ 中}}}` 为 23.33pt，直接输入 23.83pt。
    - **内层以非字符内容开头时不补左边界（R11 后，核心新增钩子）**：内层正文由 `\UL@onin` 排进盒子，不经过 `\UL@stop` 与 `\UL@reskip`，正文开头的 `~`、`\hspace`、`\kern`、规则、special 在第一个字符之前排出时，外层入口仍是 `armed`，第一个字符出现时左边界补在这些内容之后，`x\uline{\sout{~中}x}x` 为 35.83pt，直接输入 32.5pt。这个缺口从 `2fb2a93b` 起就存在，以前右侧恰好少一枚间距，两处抵消；R9 补好右侧后才显露出来。核心在 `\@@_boundary_capture_emit_left:nn` 开头调用新增的 `\@@_boundary_emit_left_hook:n {层号}`（R20 后改为 `:nn`，第二个参数是首类别，默认 `\use_none:nn`）。xeCJKfntef 覆写它：`\l_@@_ulem_onin_bool` 为真、该层 `entry` 为 `armed` 时，若末节点是 `ulem-transparent` marker 就删去它、不改入口（见下一条）；否则调用 `\@@_ulem_onin_entry_check_space:nn`。后者在入口 `space_flag` 不是 `true` 时直接调用 `\@@_ulem_onin_entry_check:n`：当前列表（内层盒子）末节点的 `\lastnodetype` 是 vlist（2，即 `\vbox` 一类的竖直盒子）、规则（3）、whatsit（9）、glue（11）、kern（12）或 penalty（13）时，调用 `\@@_ulem_entry_resolve:n` 把入口改为 `resolved`，不再补左边界，`x\uline{\sout{~中}}x` 与 `x{~中}x` 一致。入口有源码空格时一般不做这个检查，那枚空格走 resolve 以外的路径，结果与 `x {~中}x` 一致（`符 \uline{\sout{\textcolor{red}{中}}} 后`、`符 \uline{\sout{\hspace*{1em}中}} 后` 两项专门检查这一条件）；R12 起的例外见下一条。重放的外层 marker 让第一个字符按字符间的类别转换处理，不经过这里。原型曾有“末节点是重放 marker 时不改”的例外，变异测不出，插桩确认这个分支从不触发，已删去。R12 前 vlist、规则、penalty 三个分支没有测试（逐项删去后本文件仍全过，R12-M3），现由 `\vbox{}`、`\strut`、`\nobreak` 开头的用例各自固定。R11–R15 的列表里没有 hlist（1）；`a8b45cf4` 起判断移到 `\@@_ulem_if_last_content:`，hlist 也算内容，透明盒子靠其后的 `ulem-transparent` marker 排除，入口检查也不再只在嵌套链上做，见下文「正文先排出盒子、penalty、公式」。
    - **内层以颜色命令开头：颜色 whatsit 不算内容（R12 后，核心新增 transparent 钩子）**：R11 的钩子把所有 whatsit 都当作正文先排出的内容，但核心把 `\set@color`／`\reset@color` 注册为 transparent，直接输入 `x{\textcolor{red}{中}}x` 两侧都有间距，于是 `x\uline{\sout{\textcolor{red}{中}}}x` 为 23.89pt，直接输入 27.22pt（R12-I1；相对 R10 的代码回退，`…中}x`、`中\uline{\sout{\textcolor{red}{x}}}中` 相对 v3.10.6 也回退）。lvt 当时唯一的颜色用例带入口空格，不进入这个检查。现在 xeCJKfntef 覆写核心在 transparent 命令前后调用的两个钩子（见上文 capture 策略表之后一段）：
      - `\@@_boundary_transparent_begin_hook:`：在嵌套链上、入口仍为 `armed`（`\@@_ulem_if_entry_armed:T`）时，若末节点是上一个透明命令留下的 `ulem-transparent` marker，就用两次 `\unkern` 删去它，不做末节点检查（R13 起；R12 在这种情况下什么也不做，marker 留下）；否则以 `\g_@@_ulem_entry_depth_int` 为层号调用 `\@@_ulem_onin_entry_check_space:nn`，先检查颜色命令之前已经排出的内容，与第一个字符出现时的检查相同。`a8b45cf4` 起这一步改为调用 `\@@_ulem_level_check:`（`a8b45cf4` 至 `c254f535` 在 `\g_@@_ulem_transparent_tail_bool` 为真时跳过；`d250e2a7` 删去该布尔量，同一情形改由 `\@@_ulem_if_outside_box:nT` 返回假，见下文「`d250e2a7` 的补修」），不再要求在嵌套链上。这样 `x\uline{\sout{\special{x}\textcolor{red}{中}}}x` 里的 `\special` 仍按内容处理。
      - `\@@_boundary_transparent_end_hook:`：命令排出的末节点是 whatsit（类型 9）且入口仍为 `armed` 时，总是把 `\g_@@_ulem_onin_transparent_bool` 置真，外层正文（单层 `\UL@on` 的正文，`\l_@@_ulem_onin_bool` 为假）里的颜色命令也设置它；只有在嵌套链上（`\l_@@_ulem_onin_bool` 为真）才放一个 `ulem-transparent` marker（`\xeCJK_declare_node:n { ulem-transparent }` 声明，零宽的一对 kern）。外层正文不需要 marker，那里的入口判断走 `\UL@stop`／`\UL@reskip`。**以上是 R12–R15 的做法，`a8b45cf4` 已改**：end 钩子改为在 `\g_@@_ulem_transparent_tail_bool` 为假时调用 `\@@_ulem_transparent_mark:`（`d250e2a7` 起不再有这个条件，直接调用 `\@@_ulem_transparent_mark:n {0}`），它在入口为 `armed` 且入口层首类别为空时置布尔量并放 marker，不再区分是否在嵌套链上；外层正文同样需要 marker，因为外层片段盒子里的 `\@@_ulem_level_check:` 要据此区分颜色 whatsit 与 `\special`。
      - **marker 仍在列表末尾时删去（R13-M1 后；R14-M1 改正说法）**：第一个字符出现时，`\@@_boundary_emit_left_hook:nn` 看到末节点是这个 marker，就删去它，不改入口。R12 只有这一处删除，而 end 钩子每遇到一次 whatsit 就放一个 marker，连续两个颜色命令（`x\uline{\sout{\color{red}\color{blue}中}}x`）、颜色之后接更深一层装饰（`x\uline{\sout{\color{red}\xout{中}}}x`，marker 留在 `\sout` 盒子里）、正文只有颜色（`x\uline{\sout{\textcolor{red}{}}}x`，留下两对）时，零宽 marker 留在盒子里，宽度不变，与说明不符。现在另有三处删除：begin 钩子先删去上一个 marker（见上），新增的 `\@@_ulem_transparent_node_remove:`（末节点是 `ulem-transparent` marker 时两次 `\unkern`）在 `\@@_ulem_onin_lead_get:n` 读外层末尾之前、以及 `\@@_ulem_onin_tail_check:` 末尾各调用一次。节点用例 `nested-color-no-marker`、`nested-two-color-no-marker`、`nested-color-deeper-no-marker`、`nested-color-only-no-marker` 固定这一点。颜色之后若还有 `~`、`\hspace`、`\kern`、`\special` 等内容，末节点不是 marker，照常检查；这时 marker 被压在这些内容之下，三处删除都看不到它，零宽 marker 留在颜色命令所在的那一层内层盒子里（不一定是最内层），不影响宽度与断行，与 `ulem-nest` marker 的情形相同。节点用例 `nested-color-hspace-keeps-marker`（`x\uline{\sout{\color{red}\hspace{1em}中}}x`）固定这一点。若要求它也不留下，需要改为不放节点、用全局状态记录“最后一个 whatsit 是透明命令排出的”，未实施。`\special`、`\label` 排出的 whatsit 不透明，没有 marker，仍按内容处理。
      - 入口有源码空格时，`\@@_ulem_onin_entry_check_space:nn` 在 `\g_@@_ulem_onin_transparent_bool` 为真、即入口之后排出过透明命令时做末节点检查（R20 后，透明布尔为假时另有两条路径：末节点是公式时见下文 R19、R20 两条，入口前不是紧跟汉字的空格时由 `\@@_ulem_onin_entry_keep:nn` 检查，见「R20 后的补修」）：`符 \uline{\sout{\color{red}~中}} 后` 直接输入时，入口空格先遇到的是透明的颜色命令，后面的 `~` 仍算正文开头的内容，入口要改为 `resolved`。**这个布尔量跟随入口的生命周期（R13-I1 后）**：由 `\@@_ulem_entry_arm:` 在把入口置为 `armed` 时清零。R12 让 `\@@_ulem_onin_lead_put:` 在每个内层正文开头清零，end 钩子也只在嵌套链上设置它；但入口状态属于整条嵌套链（最外层 `stream-ulem` 那一层），颜色与后面的 `~`、`\hspace` 不在同一层内层正文里时，布尔量已被清零或从未设置，入口空格仍按字符类别处理，少一枚空格（33.33pt，直接输入 36.66pt，相对 v3.10.6 回退）。现在颜色写在外层正文（`符 \uline{\color{red}\sout{~中}} 后`、`符 \uline{\textcolor{red}{\sout{~中}}} 后`）、中间层（`符 \uline{\sout{\color{red}\xout{~中}}} 后`）或前一个兄弟装饰里（`符 \uline{\sout{\color{red}}\sout{~中}} 后`）时，都与直接输入一致，由 TEST 15 的五项 `*-cjk-spaced` 用例固定。外层正文里 `\special` 之后接嵌套命令、前一个兄弟装饰只有 `~` 等写法 R13 后仍不一致，`a8b45cf4` 已修好，见下文「正文先排出盒子、penalty、公式」。
      - dtx 里单层路径的说明（“只含颜色 special、锚点等不可见节点的片段不算”）与这里一致；R11 的 dtx 注释把节点类型写成“glue、kern、penalty、规则或 special”，漏了 vlist，也把全部 whatsit 写成 special（R12-M4），已改正。
    - **重排分支同样重放（R10-M3）**：内层正文以公式加空格结尾时走 `\@@_boundary_ulem_math_tail_space:nnn` 重排分支，R9 只在非重排分支重放，`\uline{x\sout{中$a$ }中}` 等写法左侧仍缺间距。现在重排分支把 `\@@_ulem_onin_lead_put:` 作为前缀参数传给 `\@@_boundary_ulem_math_tail_space:nnn`，排在重排后的正文之前。R12 起这个前缀还先用 `\l_@@_ulem_onin_enter_bool` 设置 `\l_@@_ulem_onin_bool`（`\l_@@_ulem_onin_enter_bool` 的计算移到分支之前，两条分支共用）：R11 的钩子第一步就检查 onin 布尔量，重排分支没有设置它，`x\uline{\sout{~中$a$ }}x` 为 39.17pt、`x\uline{\sout{\kern1pt 中$a$ }x}x` 为 42.12pt，直接输入 35.84pt、38.79pt（R12-M2，基线与 v3.10.6 也不对，不是回退）。
    - **左侧补出的间距位于内层盒子里（R10-M4 补记）**：与右侧不同，左侧重放 marker 后补出的 `\CJKecglue` 由内层第一个字符的类别转换排出，位于内层盒子里，会被内层装饰画上，也不能在这里断行；右侧的间距排在外层，只画外层装饰。命令左边界原有的机制（`x\uline{\sout{中}}`）同样把间距放进最内层盒子，R9 的左侧重放沿用这个位置，R10 只补写说明，行为未改。
    - 同一修改也让 R8 记为“所有版本都不对”的 `符 \uline{\sout{\xout{中}x}} 后` 与直接输入一致（`three-level-cjk-then-latin`）。嵌套装饰之后若又排出盒子（`fntef-entry-space01` TEST 12 的两条节点用例），盒子前的 marker 由 `ulem-nest` 变为 CJK marker，宽度不变。
    - 仍未覆盖：三层并列（`符 \uline{\sout{\xout{x}}\sout{中}} 后` 等）、公式后接嵌套命令（`符 \uline{$x$\sout{中}} 后`）、嵌套命令与汉字之间的空格（三层的 `符 \uline{\sout{\xout{中} 中}} 后`，以及 R10 复核记下的两层 `\uline{\sout{中} 中}` 等写法）、单层分组开头的空格（`\uline{中{ 中}}`），以及盒子外的字符与盒子里的线型命令（`符 x\mbox{\uline{\sout{中}}} 后`）；R11 后又记下嵌套内层以未注册的盒子开头（原始 `\hbox{}`、`\rule`、`\phantom`、`\raisebox` 等）时仍多补一枚左边界间距：钩子看到的末节点是 hbox，与透明的 `\mbox{}` 在节点上无法区分，所以没有列入上面的节点类型。R12 后又记下（在 `14e3415f` 上实测，v3.10.6 与直接输入一致）：内层以源码空格或 `~` 加西文开头、后接汉字的 `符 \uline{\sout{ x}中} 后`（45.27pt，直接输入 41.94pt，自 R9 的 `5b271e96` 起）；外层正文以分组或公式结束后接嵌套命令的 `x\uline{{中}\sout{$a$中}}x`、`中\uline{$a$\sout{中}}中`（自 `2fb2a93b` 起）；单层以 `\fbox{}`、`\mbox{\hspace{1em}}` 开头的 `x\uline{\fbox{}中}x` 等少 3.33pt（自 `2fb2a93b` 起）；以及上文 R12-M1 的 `{中}` 前缀写法。R13 后又记下（在 `6a52751a` 上实测，v3.10.6 与直接输入一致，自 `2fb2a93b` 起）：外层正文里 `\special` 之后接嵌套命令（`x\uline{\special{x}\sout{中}}x`、`x\uline{\color{red}\special{x}\sout{中}}x`、`符 \uline{\color{red}\special{x}\sout{中}} 后`），以及外层正文里前一个兄弟装饰只有 `~`（`x\uline{\sout{~}\sout{中}}x`、`x\uline{\sout{~}\sout{\color{red}中}}x`）。**`a8b45cf4` 已修好**其中的公式后接嵌套命令、`\mbox` 里的线型命令、嵌套内层以未注册盒子开头、单层以注册盒子开头、外层正文里 `\special` 之后接嵌套命令与前一个兄弟装饰只有 `~` 这几类（见下文「正文先排出盒子、penalty、公式」）；`符 \uline{\sout{ x}中} 后` 按维护者决定不改；外层正文以分组结束后接嵌套命令（`x\uline{{中}\sout{$a$中}}x`）仍未修。清单见 [[../memory/doc-gaps]]。
- **正文先排出盒子、penalty、公式（R16 前与 v3.10.6 比对后补修，`a8b45cf4`）。** R11–R15 的左边界检查只在嵌套链上起作用，也不把 hlist 算作内容。与 v3.10.6 逐项比对探测矩阵后发现，单层正文与嵌套命令之前的外层正文同样会在第一个字符之前排出 `\UL@stop`／`\UL@reskip` 看不到的内容：单层以 `\fbox{}`、`\mbox{\hspace{1em}}` 开头时 `\UL@stop` 把透明盒子当作有宽度的内容，丢了盒子之后的 `\CJKecglue`；外层正文先排出原始 `\hbox`、`\phantom`、`\raisebox`、`\vbox`、`\nobreak`、`\special`、`\kern` 或只有 `~` 的兄弟装饰时多补一枚左边界；外层正文以公式结束后接嵌套命令时少一枚。以 dtx 为准，分工如下：
  - **核心的透明盒子钩子。** `\@@_boundary_box_end_transparent:n`（box capture 没有观察到字符类别、按透明盒子排出时）在排出盒子之后、`\@@_boundary_replay_before:` 之前调用 `\@@_boundary_transparent_box_hook:`，默认 `\prg_do_nothing:`。xeCJKfntef 令它调用 `\@@_ulem_transparent_mark:n {1}`（`a8b45cf4` 为不带参数的 `\@@_ulem_transparent_mark:`，`c254f535` 加上参数），注册盒子命令排出的透明盒子后面于是跟着 `ulem-transparent` marker，与原始 `\hbox` 区分。这正是 R11 记下的难点（两者的末节点都是 hbox）的补法。`c254f535` 起排出盒子之前还有 `\@@_boundary_transparent_box_begin_hook:`，见下文「`c254f535` 的补修」；`d250e2a7` 起 `\@@_boundary_last_box_end:n` 不取回盒子的分支（末节点不是盒子）在本层没有观察到字符类别时也调用 `\@@_boundary_transparent_box_hook:`，见下文「`d250e2a7` 的补修」。
  - **放 marker 的条件（`\@@_ulem_transparent_mark:n`）。** 只在入口为 `armed`（`\@@_ulem_if_entry_armed:T`）且入口层首类别为空时放，同时置 `\g_@@_ulem_onin_transparent_bool`；不区分是否在嵌套链上。transparent end 钩子（命令排出的末节点是 whatsit 时，参数 0；`d250e2a7` 前还要求 `\g_@@_ulem_transparent_tail_bool` 为假）与透明盒子钩子（参数 1）都调用它；`c254f535` 起还要求 `\@@_ulem_if_outside_box:nT` 为真，正文里另起的注册盒子（`\mbox`、`\fbox` 等建 `box` 类 capture 层的盒子）内部不放；`d250e2a7` 起正文里的原始 `\hbox`、`\raisebox`、`\vbox` 内部也不放，见下文「`d250e2a7` 的补修」。首类别出现后不放：框架为排左边界 glue 调用 `\UL@stop` 时执行的 `\reset@color` 会把 marker 留在片段盒子里。外层正文也要放，因为外层片段盒子里的检查要靠它把颜色 whatsit、透明盒子与 `\special`、原始盒子区分开。
  - **末节点算不算内容（`\@@_ulem_if_last_content:`）。** `\lastnodetype` 为 1（hlist）、2（vlist）、3（规则）、9（whatsit）、11（glue）、12（kern）、13（penalty）时为真。hlist 是这次新加的。
  - **检查不限于嵌套链（`\@@_ulem_level_check:`；`c254f535` 起拆为带盒子检查的外壳 `\@@_ulem_level_check:` 与原来的检查 `\@@_ulem_level_check_aux:`，下面说的是后者）。** 入口层首类别为空时才检查（只检查一次）。在嵌套链上照旧调用 `\@@_ulem_onin_entry_check_space:nn`；在外层片段盒子里，末节点是 ulem 片段开头的 `\kern3sp`（片段盒子还是空的）或 `ulem-nest` marker（前一个兄弟装饰已在它自己的内层盒子里检查过）时不查，其余同样调用 `\@@_ulem_onin_entry_check_space:nn`。调用点：transparent begin 钩子（末节点不是 marker 时；`d250e2a7` 前还要求 `\g_@@_ulem_transparent_tail_bool` 为假）；`\@@_ulem_onin_lead_check:`（`\@@_ulem_onin_lead_get:n` 进入更深一层之前，现在不论是否在嵌套链上，覆盖 `x\uline{\special{x}\sout{中}}x`）；`\@@_ulem_onin_tail_check:`（嵌套链上的内层正文结束、入口仍为 `armed`、末节点不是 marker 时，覆盖 `x\uline{\sout{~}\sout{中}}x`）。
  - **`\@@_boundary_emit_left_hook:nn`（第一个字符出现时）。** 入口为 `armed` 时（`c254f535` 起先看 `\l_@@_ulem_fullleft_bool`，为真时改走 `\@@_ulem_fullleft_check:n`、不做下面的检查；`d250e2a7` 起两者不再二选一：先做全角左标点检查，入口仍为 `armed` 时再做下面的检查，见下文「`d250e2a7` 的补修」）：末节点是 `ulem-transparent` marker 就删去它；此时若不在嵌套链上、入口也没有源码空格，还清除该层 `entry`（`c254f535` 起改由 `\@@_ulem_transparent_clear:n` 做，并多一个条件），框架随后为排左边界 glue 调用 `\UL@stop` 时就不会把片段盒子里的透明盒子当作内容解除入口，左边界 glue 排在透明盒子之后（`x\uline{\fbox{}中}x`）；入口有源码空格时不清除，`\UL@stop` 把入口空格排在盒子之前，与 `符 \uline{\hspace*{1em}中} 后` 一样。末节点不是 marker 时，在嵌套链上照旧调用 `\@@_ulem_onin_entry_check_space:nn`；不在嵌套链上且 `\xeCJK_if_ulem_patch:TF` 为假时调用 `\@@_ulem_raw_box_check:n`。
  - **第一个字符在原始盒子里（`\@@_ulem_raw_box_check:n`）。** `中\uline{\hbox{a}中}中`，以及 `\phantom`、`\raisebox`、`\vbox`；嵌套内层正文里也是如此，因为 `\UL@hrest` 在这些盒子里清除 onin 布尔。左边界 glue 若照常补，会排进这个盒子，而直接输入时原始盒子挡住两侧的类别转换。因此当前 capture 层就是入口层、处于水平模式、入口没有源码空格、首类别不是 `math` 时解除入口。公式例外：ulem 排公式时 `\xeCJK_if_ulem_patch:TF` 同样为假，但直接输入 `中{$a$中}中` 的汉字与公式之间有 `\CJKecglue`。
  - **penalty（重写的 `\UL@stop`）。** 从片段盒子末尾取下 penalty 后先调用 `\@@_ulem_transparent_node_remove:`，再关闭片段盒子；把 penalty 排到外层（`\LA@penalty \UL@pe`）之后，入口仍 `armed` 且没有源码空格时 `\@@_ulem_entry_resolve:`（`x\uline{\nobreak 中}x`）。有源码空格时不解除，penalty 不可见，入口空格仍按首类别处理（`前 \uline{\nobreak 中} 后`）。
  - **公式后接嵌套命令。** `\@@_ulem_onin_lead_get:n` 读外层末尾时，末节点是公式（`\lastnodetype`=10）就记 `math`，`\@@_ulem_onin_lead_put:` 在内层开头重放 math marker，公式与内层第一个字符之间与直接输入一样有间距（`中\uline{$a$\sout{中}}中`）。
  - **`\UL@setULdepth` 暂停 capture**，见上文「边界状态与装饰盒子隔离」一段。
  - **marker 的删除点。** 下一个透明命令开始前（begin 钩子）、第一个字符出现时（`\@@_boundary_emit_left_hook:nn`）、`\@@_ulem_onin_lead_get:n` 读外层末尾之前、`\UL@stop` 关闭片段盒子之前（先取下 penalty）、`\@@_ulem_body_end:` 正文结束检查之前，以及 `\@@_ulem_onin_tail_check:` 末尾（`d250e2a7` 起调用 `\@@_ulem_transparent_node_remove:`）。兄弟装饰只有颜色（`\sout{\color{red}}`）时，内层盒子关闭前还会执行颜色命令经 `\aftergroup` 留下的 `\reset@color`，这时既不能把颜色 whatsit 当作内容检查，也不能再放 marker，否则 marker 留在内层盒子里。`a8b45cf4` 至 `c254f535` 为此在最后一处删去 marker 后置 `\g_@@_ulem_transparent_tail_bool`，由 `\@@_ulem_nest_mark:` 在内层盒子关闭之后清除；`d250e2a7` 删去这个布尔量：`\reset@color` 执行时内层正文的分组已经结束，其中对 `\l_@@_ulem_onin_bool` 的局部设置随之失效，`\xeCJK_if_ulem_patch:TF` 也为假，`\@@_ulem_if_outside_box:nT` 因此返回假，钩子不检查也不放 marker。被其他内容压住的 marker 仍会留下，与上文 R14 的说法相同；嵌套内层正文以全角左标点开头（`x\uline{\sout{\color{red}（中}}x`）时 marker 也留在标点之前，因为内层的全角左标点不向 capture 报告类别，第一个字符出现时的钩子不运行（零宽，与 doc-gaps 里“嵌套内层正文以全角标点开头”同源）。正文里的盒子内部不放 marker：`c254f535` 起覆盖注册盒子，`d250e2a7` 起覆盖原始 `\hbox`、`\raisebox`、`\vbox`，所以这些盒子内部也没有需要删除的 marker。
  - **测试。** `fntef-entry-space01` TEST 16 的 41 项宽度用例（以 `-tie` 结尾的以 `~` 写法为 oracle）；TEST 17 的 9 项节点列表确认 marker 不残留，覆盖单层颜色（含入口空格、颜色后接空格或 `\nobreak`，后者走 penalty 结尾的 `\UL@stop`）、单层 `\fbox{}`（含后接空格）、正文只有颜色或只有 `\fbox{}`、兄弟装饰只有颜色；TEST 2 另加 `fbox-spaced` 节点列表。提交说明记录新增宽度用例在上一提交上 24 项失败，逐项变异 69 项全部被发现（13 项靠节点列表）。
  - **`c254f535` 的补修（本地独立审查 R16）。** R16 指出 `a8b45cf4` 的三处问题：透明盒子之后以全角左标点开头时多一枚 `\CJKecglue`（`x\uline{\fbox{}（中）}x` 为 50.69pt，直接输入 47.36pt，相对 v3.10.6 与 `8e557076` 回退；没有盒子的 `x\uline{（中）}x` 自分支早期起就多这一枚，同一原因）；透明盒子之前已有 `\kern`、`\hbox{}`、`\special`、`\rule` 或正文以语法空格开头时，看到 marker 仍清除入口（`x\uline{\kern1pt\fbox{}中}x`、`x\uline{ \fbox{}中}x`，相对 `8e557076` 回退）；`\@@_ulem_level_check:` 不看 capture 层号，正文里 `\fbox`、`\mbox` 内部的内容也会解除外层入口（`x\uline{\fbox{\sout{中}}}x` 为 30.69pt，直接输入 34.02pt）。以 dtx 为准，分工如下：
    - **透明盒子之前的内容（核心新钩子 `\@@_boundary_transparent_box_begin_hook:`）。** 核心在透明盒子排出之前调用它，默认 `\prg_do_nothing:`。xeCJKfntef 让它与颜色命令的 begin 钩子共用 `\@@_ulem_transparent_begin:n`：transparent begin 钩子传 0，透明盒子 begin 钩子传 1，参数是交给 `\@@_ulem_if_outside_box:nT` 的跳过层数（透明盒子的两个钩子在盒子 capture 结束、层号减一之前调用，要跳过正在结束的这一层）。入口为 `armed` 且不在正文里的盒子内时：末节点是 `ulem-transparent` marker 就删去；否则调用 `\@@_ulem_level_check_aux:`（`c254f535` 还要求 `\g_@@_ulem_transparent_tail_bool` 为假，`d250e2a7` 删去这个条件）。`x\uline{\kern1pt\fbox{}中}x` 因此在 `\kern` 处就解除入口，盒子之后不再放 marker。
    - **单层看到 marker 时清除入口的条件（`\@@_ulem_transparent_clear:n`）。** 入口没有源码空格（`space_flag` 不是 `true`）且 `\g_@@_ulem_lead_skip` 为零时才清除。正文以语法空格开头（`x\uline{ \fbox{}中}x`）时这段空格已经记账、要画成装饰线；直接输入时它挡在 x 与盒子之间，不补 `\CJKecglue`。不清除入口时，`\UL@stop` 解除入口后补画这段线，左边界 glue 也就不排了。这条理由只在入口前是西文时成立，入口前是汉字的写法见下文「`d250e2a7` 的补修」的「仍未处理」一条。
    - **首字符是全角左标点（`\l_@@_ulem_fullleft_bool` 与 `\@@_ulem_fullleft_check:n`）。** `\@@_ulem_Boundary_and_FullLeft_glue:N` 的 ulem 分支把标点作为 `CJK` 报告给 capture，框架于是按“西文后接汉字”补 `\CJKecglue`；直接输入时西文与全角左标点之间没有这枚间距，标点的左侧空白另由标点规则决定。报告期间置 `\l_@@_ulem_fullleft_bool`，`\@@_boundary_emit_left_hook:nn` 见到它就改为调用 `\@@_ulem_fullleft_check:n`：入口没有源码空格、入口前（该层 `before` 字段）是 `default` 或 `default-space` marker 时解除入口，不补左边界的 `\CJKecglue`。入口前是汉字或有源码空格时不改动，仍按首类别处理（插桩实测：`x \uline{（中}x` 到达检查时 `before` 为空，`x\ \uline{（中}x` 的 `space_flag` 为 `true`、`before` 为 `default`，两者都不解除；节点用例 `cjk-then-leftparen`、`latin-ctrl-space-then-leftparen-nodes` 固定 `\CJKglue` 与控制空格留在原处）。`c254f535` 的这条路径不删透明 marker，`x\uline{\fbox{}（中}x` 里的 marker 由随后的 `\UL@stop` 删去（节点用例 `fbox-leftparen-no-marker`）；但入口前是汉字时入口仍为 `armed`、marker 也还在，`\UL@stop` 把透明盒子当作内容解除入口，`中\uline{\fbox{}（中）}中` 的汉字与盒子之间丢掉 `\CJKglue`。`d250e2a7` 起全角左标点检查之后入口仍为 `armed` 时照常检查 marker，见下文「`d250e2a7` 的补修」；入口前是西文、检查已解除入口时，marker 仍由 `\UL@stop` 删去。
    - **正文里的盒子（`\@@_ulem_if_outside_box:nT {跳过的层数}`）。** 从入口层（`\g_@@_ulem_entry_depth_int`）的下一层数到当前层（`\g_@@_boundary_capture_depth_int` 减去参数），其间有一层的 `kind` 是 `box` 就为假；`d250e2a7` 起 `\xeCJK_if_ulem_patch:TF` 与 `\l_@@_ulem_onin_bool` 都为假时也为假（覆盖不建 capture 层的原始盒子，见下文「`d250e2a7` 的补修」）。为假时 `\@@_ulem_level_check:`、transparent 命令的两个钩子与透明盒子的两个钩子都不检查，也不放 marker。原因：`x\uline{\fbox{\sout{中}}}x` 里 `\@@_ulem_onin_lead_get:n` 在 `\fbox` 的盒子 capture 里执行，末节点是盒子里的 `\fboxsep` kern，它只影响这个盒子；据此解除外层入口，就会丢掉 x 与盒子之间的 `\CJKecglue`。这时左边界 glue 仍像 `8e557076` 与 v3.10.6 一样排在盒子里第一个字符之前，宽度与直接输入相同，位置不同（登记在 [[../memory/doc-gaps]]）。嵌套链上的左边界钩子（`\@@_boundary_emit_left_hook:nn` 调用 `\@@_ulem_onin_entry_check_space:nn` 的分支）不需要这项检查：`\mbox`、`\fbox` 等盒子开头的 `\UL@hrest` 清除 `\l_@@_ulem_onin_bool`，盒子里的内层命令也不会再把它置真。原型在那里也加了检查，插桩在 r16x、rg、r9big 三个矩阵上确认该分支在盒子里从不触发，已删去。对照：`a8b45cf4` 的 `\@@_ulem_raw_box_check:n` 一开始就要求当前层等于入口层，`\@@_ulem_level_check:` 却没有层级限制，R16 指出的问题就出在后者。
    - **测试。** TEST 16 新增 19 项宽度用例（透明盒子后接全角左标点、透明盒子之前已有内容或语法空格、命令前是西文且正文以全角左标点开头、正文里的 `\fbox`／`\mbox`），TEST 17 新增 4 项节点列表（盒子里的颜色不留 marker、全角左标点路径删去 marker、`\CJKglue` 与控制空格的位置），全文件 334 项 PASS；逐项变异 83 项全部被发现，17 项只由节点列表发现。明细见 `llmdoc/reference/build-and-test.md` 的 `fntef-entry-space01` 一节。
  - **`d250e2a7` 的补修（本地独立审查 R17）。** R17 指出 `c254f535` 的两处问题，并补充核对了 R16 的一项：全角左标点分支不再处理 `ulem-transparent` marker，入口前是汉字时 `\@@_ulem_fullleft_check:n` 什么也不做，marker 仍在、入口仍为 `armed`，随后 `\UL@stop` 把透明盒子当作内容解除入口，`中\uline{\fbox{}（中）}中` 的汉字与盒子之间丢掉 `\CJKglue`（默认 `\CJKglue` 的自然宽度为零，只少了伸长量；`CJKglue={\hskip 1pt}` 时为 56.80pt，`21ac8c10` 为 57.80pt）；`syntax-space-then-fbox-latin`（`中\uline{ \fbox{}x}中`）只在默认 `CJKecglue` 下碰巧与直接输入等宽；R16 只让注册盒子内部不放 marker，正文里的原始 `\hbox`、`\raisebox`、`\vbox` 内部仍会留下（`x\uline{\hbox{\mbox{}}中}x`）。另有范围外观察：`x\uline{\mbox{\color{red}\fbox{}}中}x` 为 30.69pt，直接输入与 v3.10.6 为 34.02pt，`8e557076` 上已如此。以 dtx 为准，分工如下：
    - **全角左标点检查之后照常检查 marker（`\@@_boundary_emit_left_hook:nn`）。** 入口为 `armed` 时，先在 `\l_@@_ulem_fullleft_bool` 为真时调用 `\@@_ulem_fullleft_check:n`；之后入口仍为 `armed`（入口前是汉字或有源码空格，检查没有解除入口）时，与没有全角左标点时一样检查末尾的 `ulem-transparent` marker：删去它，单层时经 `\@@_ulem_transparent_clear:n` 清除入口，`\UL@stop` 就不会把透明盒子当作内容，`中\uline{\fbox{}（中）}中` 的汉字与盒子之间仍补 `\CJKglue`（节点用例 `cjk-then-fbox-leftparen`）。
    - **末节点不是盒子时同样调用透明盒子钩子（核心 `\@@_boundary_last_box_end:n`）。** `\mbox` 等以 last 方式捕获的盒子（capture 结束时从列表末尾取回盒子）里有颜色命令时（`\mbox{\color{red}\fbox{}}`），分组结束时的 `\reset@color` 排在盒子之后，capture 结束时末节点不是这个盒子，核心走不取回盒子的分支。这个分支同样表示盒子里没有观察到字符类别，所以本层首类别为空时也在 `\@@_boundary_replay_before:` 之前调用 `\@@_boundary_transparent_box_hook:`，`x\uline{\mbox{\color{red}\fbox{}}中}x` 因此与直接输入一致（34.02pt，用例 `mbox-color-fbox-then-cjk`）。
    - **原始盒子内部不检查、不放 marker（`\@@_ulem_if_outside_box:nT`）。** 正文里的原始 `\hbox`、`\raisebox`、`\vbox` 不建 capture 层，逐层检查 `kind` 看不到它们；但 ulem 在这些盒子开头执行 `\UL@hrest`，此时 `\xeCJK_if_ulem_patch:TF` 为假，`\l_@@_ulem_onin_bool` 也为假。两者都为假时这个条件同样返回假，`\@@_ulem_level_check:`、transparent 命令的两个钩子与透明盒子的两个钩子都不检查、不放 marker（节点用例 `hbox-mbox-no-marker`、`hbox-color-no-marker`）。外层片段盒子里 patch 为真，嵌套链上的内层盒子里 onin 布尔为真，都不受这一条影响。
    - **删去 `\g_@@_ulem_transparent_tail_bool`。** 兄弟装饰只有颜色时，内层正文分组结束后经 `\aftergroup` 执行的 `\reset@color` 正好落在上一条的条件里：分组结束使 onin 布尔的局部设置失效，patch 也为假。专门的布尔量因此不再需要：begin 钩子与 end 钩子对它的判断、`\@@_ulem_onin_tail_check:` 对它的设置、`\@@_ulem_nest_mark:` 对它的清除一并删去。提交说明记录删去前后 11 个矩阵中留有 marker 的用例集合相同。
    - **语法空格一条的适用范围。** 删去 `syntax-space-then-fbox-latin`；dtx 与 lvt 写明“正文以语法空格开头时不清除入口”只在入口前是西文时与直接输入一致。**仍未处理**：入口前是汉字时，直接输入 `中{ \fbox{}x}中` 删去这枚空格、在盒子与 x 之间补 `\CJKecglue`，这里则把空格画成线、排在“中”与盒子之间；默认选项下 `\CJKecglue` 等于一个词间空格，两者碰巧等宽，`CJKecglue={\hskip 0.5em}` 下不等。`c254f535` 之前清除入口的做法也不对（多排一枚 `\CJKecglue`）。数值见 [[../memory/doc-gaps]]。
    - **测试。** TEST 16 删去 `syntax-space-then-fbox-latin`、新增 `mbox-color-fbox-then-cjk`；TEST 17 新增节点用例 `cjk-then-fbox-leftparen`、`hbox-mbox-no-marker`、`hbox-color-no-marker`。全文件仍为 334 项 PASS。逐项变异 82 项中 81 项被发现，未被发现的 `fullleft-flag-stuck` 是等价变异。明细见 `llmdoc/reference/build-and-test.md` 的 `fntef-entry-space01` 一节。
  - **`b0e44c48` 的补修（零宽 glue）。** `\@@_ulem_entry_skip:`（`\UL@reskip` 画显式 glue 之前）原来只在 glue 不为零时解除入口；现在 glue 为零、入口没有源码空格时也解除。直接输入 `x{\hspace{0pt}中}x` 时零宽 glue 挡住两侧的类别转换，不补 `\CJKecglue`；入口有源码空格时仍按首类别处理，与正文以 `\nobreak` 开头时相同（`1b72e7c9` 的 architecture 曾写“与直接输入一样删去空格”，不对，见下一条）。`x\uline{\hspace{0pt}\fbox{}中}x` 在 `8e557076` 上一致只因 `\UL@stop` 把随后有宽度的 `\fbox` 当作内容解除入口，`a8b45cf4` 让透明盒子不再解除入口后这层掩盖消失；没有盒子的 `x\uline{\hspace{0pt}中}x` 在 v3.10.6、`8e557076`、`d250e2a7` 上都是 27.22pt 对 23.89pt，v3.9.1 与直接输入一致（23.89pt）。测试为 TEST 16 的 `hspace0-*` 四项与 TEST 3 的 `hspace0-spaced`。
  - **未改动的差异。** 嵌套内层先排出空格、`~`、`\hspace*` 等而命令前有源码空格时入口空格仍保留（`符 \uline{\sout{ x}中} 后`），按维护者决定与单层、v3.9.1、`~` 写法一致；单层正文以零宽内容开头、前面是西文（`x\uline{\hbox{}中}x`、`x\uline{\special{x}中}x`）仍多一枚间距，v3.10.6 同样。`c254f535` 后又记下：正文里的盒子让左边界 glue 排在盒子里（同宽不同位置）、`前 \uline{\mbox{\color{red}\kern1pt\color{blue}中}} 后` 的入口空格按 CJK 规则删去、`x \uline{（中）} x` 右侧与带花括号的直接输入不同（按既定设计，不算缺陷）。`d250e2a7` 后又记下：入口前是汉字、正文以语法空格开头再接透明盒子（`中\uline{ \fbox{}x}中`、`中\uline{ \fbox{}中}中`），正文以语法空格开头的 `x\uline{ 中}x` 一类（各版本相同），以及嵌套内层正文以全角左标点开头时零宽的透明 marker 留在标点之前（`x\uline{\hspace{0pt}\fbox{}中}x` 当时也列在这里，已由 `b0e44c48` 修好）。这些都见 [[../memory/doc-gaps]]。
  - **R18 后的补修（`\mbox` 开始时的检查、零宽 glue 的位置、正文里公式之后的汉字）。**
    - **last 方式捕获的盒子在开始时检查。** `\mbox`、`\fbox`、`\makebox` 等以 last 方式捕获：盒子直接排进列表，结束时若末节点是盒子就取回，否则（`\mbox` 里有颜色命令，分组结束时的 `\reset@color` 排在盒子之后）只能把盒子留在列表里。`d250e2a7` 让不取回盒子的分支也调用 `\@@_boundary_transparent_box_hook:` 放 marker，却没有像包装方式那样先检查盒子之前的内容，`x\uline{\kern1pt\mbox{\color{red}}中}x` 因此多补 `\CJKecglue`（28.22pt 对 24.89pt）。这时盒子已经在列表里，事后检查会读到盒子本身。`df9bbf1e` 让核心在 `\@@_boundary_inline_last_box_begin:` 进入本层之后调用新的 `\@@_boundary_last_box_begin_hook:`。R19 后的做法见下一条“R19 后的补修”：盒子开始时只检查此前的内容、不动 marker，结束时的 begin 钩子照旧对两种捕获方式都调用。（`df9bbf1e` 曾让开始时的钩子等于 `\@@_ulem_transparent_begin:n {1}`，遇到 marker 就删去，并让结束时只对包装方式调用 begin 钩子；当时写的“提前解除入口不改变结果”没有验证，R19-I1、R19-M2 找到了反例。）
    - **入口有源码空格时零宽 glue 排成普通 glue。** `前 \uline{\hspace{0pt}中} 后` 的入口空格按首类别换成 `\CJKglue`（与 `\nobreak`、颜色命令开头时相同，也与 v3.10.6 的宽度相同），但这枚 glue 排在 `\UL@reskip` 已画成 leaders 的零宽 glue 之后，自己没有装饰线：`CJKglue={\hskip 1pt}` 时装饰线在那里断开，默认选项下行被拉伸时也一样。`\@@_ulem_entry_skip:` 在这种情形下置 `\l_@@_ulem_skip_plain_bool`，`\UL@reskip` 改排普通 glue，不画 leaders，左边界 glue 于是排在第一个 ulem 片段之前。另一种做法是像非零 `\hspace` 那样解除入口、把入口空格排在装饰之前（与 v3.9.1 相同），但默认选项下宽度会比 v3.10.6 多一个空格；零宽 glue 不可见，按不可见内容处理更一致，所以没有采用。
    - **正文里公式之后的汉字。** 公式只有写在正文开头时，`\@@_boundary_math_begin:n` 才向 capture 报告类别 `math`；写在颜色命令、`\fbox`、`\kern` 之后就不报告，后面的汉字成了首类别。首类别出现时框架为左边界调用 `\UL@stop`，片段盒子有宽度，入口解除，左边界 glue 不排，公式与汉字之间的 `\CJKecglue` 随之丢失（`x\uline{\color{red}$a$中}x` 29.18pt 对 32.51pt）。二分到 `2fb2a93b`：`ef49ca4e` 与 v3.10.6 上命令前是西文时，入口按西文到汉字补了一枚 `\CJKecglue`，恰好排在公式与汉字之间；命令前是汉字时（`中\uline{\kern1pt$a$中}中`）各版本都少这一枚。现在 `\@@_boundary_use_ulem_glue_outer:nn` 在关闭片段盒子之前记下末节点是不是公式（`\g_@@_ulem_math_last_bool`，`\UL@stop` 结束分组，只能用全局布尔量）；入口因此解除、首类别是汉字时把 `\CJKecglue` 画成一段装饰线（与 `\UL@reskip` 画显式 glue 相同）。首类别来自全角左标点时（`\l_@@_ulem_fullleft_bool`）不补，直接输入时公式与全角左标点之间也没有这枚间距。嵌套内层由 `\@@_ulem_if_last_content:T` 把公式节点（`\lastnodetype` 为 10）算作内容，入口解除后，核心在 Boundary 到 CJK 的转换里照常补 `\CJKecglue`。
    - **测试。** TEST 3 新增节点用例 `hspace0-spaced`；TEST 16 删去 `hspace0-then-cjk-spaced`，新增 `kern-then-mbox-color`、`special-then-mbox-color-fbox`、`rule-then-mbox-color`、`kern-then-makebox-color-latin`、`nested-kern-then-mbox-color` 与 `color-then-math-cjk`、`fbox-then-math-cjk`、`kern-then-math-cjk`、`kern-then-math-leftparen`、`nested-kern-then-math-cjk`；TEST 17 新增 `fbox-mbox-color-no-marker`。全文件 348 项 PASS。明细见 `llmdoc/reference/build-and-test.md`。
  - **R19 后的补修（marker 留到盒子结束、盒子后接全角左标点、嵌套内层里的公式与 `\mbox{（中}`）。**
    - **last 方式捕获的盒子开始时不删 marker。** `\@@_boundary_last_box_begin_hook:` 改为自己的定义：入口仍为 `armed`、不在正文里的盒子中、列表末尾不是 `ulem-transparent` marker 时调用 `\@@_ulem_level_check_aux:`，末尾是 marker 时什么都不做。原因（R19-I1）：开始时还不知道盒子里有没有字符。盒子里第一个字符是全角左标点时（`\mbox{（中}`），标点不向 capture 报告类别，嵌套内层随后要靠这个 marker 判断“此前只有透明内容”，在盒子之前补 `\CJKecglue`；`df9bbf1e` 在开始时删去 marker，`中\uline{\sout{\color{red}\mbox{（中}x}}中` 于是比直接输入、`1b72e7c9`、v3.10.6 少 3.33pt。结束时的 `\@@_boundary_transparent_box_begin_hook:` 恢复为两种捕获方式都调用（取回了盒子时它在盒子之外，能删去前一个 marker，`fbox-fbox-no-marker` 固定这一点）。代价是 `\mbox` 里有颜色命令、不取回盒子时，前一个透明内容的 marker 压在盒子之下，与 `1b72e7c9` 相同。
    - **Boundary 到全角左标点时看前面的 `CJK` marker。** 核心在以汉字结尾的盒子之后重放 `CJK` marker，直接输入 `中{\mbox{中}（中}中` 由 `\@@_bound_type_12_glue:Nn` 在盒子与“（”之间补 `\CJKglue`。`\@@_ulem_Boundary_and_FullLeft_glue:N` 原来不看这个 marker，各版本（含 v3.10.6）都少这一枚；`1b72e7c9` 上前面有 `\kern` 等内容时恰好等宽，是因为 `\CJKglue` 错排进了 `\mbox`（R19-M2 列出 20 项）。现在关闭片段盒子之前，末节点是 `CJK` 或 `CJK-space` marker 就删去它、记在 `\g_@@_ulem_cjk_last_bool` 里，之后像汉字到全角左标点一样画一段 `\CJKglue`。
    - **嵌套内层入口有空格、公式之后是汉字。** `\@@_ulem_onin_entry_check_space:nn`（R20 前名为 `:n`）在入口有源码空格、`\g_@@_ulem_onin_transparent_bool` 为假、末节点是公式时调用 `\@@_ulem_onin_entry_math:nn`：入口前是 `CJK-space` 或 `CJK-widow`（空格紧跟在汉字之后）时先把 `space_flag` 置为假（直接输入删去汉字后、`\kern` 前的空格），再解除入口，核心随后在公式与汉字之间补 `\CJKecglue`。入口前只是 `CJK` 时（`{中} `、`\mbox{中} `、`前\ `，空格前面是分组结束、盒子或控制空格）直接输入保留空格，`bf34c7ee` 曾把 `CJK` 也算进去而删掉了它，R20-I1 指出后改正。`前 \uline{\sout{\kern1pt$a$中}} 后` 自 `2fb2a93b` 起比直接输入与 v3.10.6 少 3.33pt（R19-I2），现在一致。先有颜色命令或透明盒子的写法（`前 \uline{\sout{\color{red}$a$中}} 后`）走 transparent 分支，没有改，宽度回到 v3.10.6 的值，仍与直接输入不一致，见 doc-gaps。`\changes` 的说法相应限定。
    - **嵌套内层以 `\mbox{（中}` 这类盒子结尾。** 盒子里第一个字符是全角左标点时，核心按“有可见内容、没有观察到类别”把盒子首尾都记为 `default`，并在盒子后重放 `default` marker；直接输入 `x{{\mbox{（中}}}x` 在盒子与 x 之间不补间距。嵌套写法里，R7 的 `\@@_ulem_report_last:n` 把盒子里“中”的类别写进外层线型命令，外层按汉字结尾补 `\CJKecglue`（`x\uline{\sout{\mbox{（中}}}x` 自 `7a3713db`，即 R7 加上这一补报起，比直接输入与 v3.10.6 多 3.33pt）；内层先有汉字时（`x\uline{\sout{中\mbox{（中}}}x`）外层的末类别本来就是 `CJK`。现在 `\@@_ulem_onin_tail_check:` 在内层正文结束时，末节点是 `default` marker 就把各外层的末类别改为 `default`。这是在 r20 矩阵里发现的，不在 R19 盲审的发现里。原型里还试过让 `\@@_ulem_report_last:n` 遇到首类别为空的盒子层就停下，矩阵上与只改末尾检查的结果完全相同，没有能区分的写法，按 R17 反思第 3 条删去。
    - **测试。** TEST 16 新增 `kern-then-math-latin`、`nested-kern-then-math-cjk-spaced`、`nested-kern-then-math-latin-spaced`、`nested-color-then-mbox-leftparen`、`nested-fbox-then-mbox-leftparen`、`nested-mbox-leftparen-end`、`nested-cjk-mbox-leftparen-end`，以及 `CJKglue={\hskip 1pt}` 下的 `cjkglue-*` 三项；TEST 17 删去 `fbox-mbox-color-no-marker`（这个 marker 现在按设计保留），新增 `fbox-fbox-no-marker`、`mbox-cjk-leftparen-no-marker`。全文件 358 项 PASS。
  - **R20 后的补修（嵌套内层入口前不是紧跟汉字的空格、正文以公式结尾）。** R20 盲审的范围外观察指出 `\mbox{中} \uline{\sout{\kern1pt中}} 后` 比直接输入与 v3.10.6 少 3.33pt。协调者用 r24、r25 矩阵（按入口前的写法 `前 `、`\mbox{中} `、`{中} `、`前\ `、`前{} `、`\mbox{x} `、`$a$ ` 等展开）查出这是自 `2fb2a93b` 起的一整类回退：嵌套内层入口有源码空格时，正文先排出的 `\kern`、`~`、`\hspace*`、规则等内容不解除入口，第一个汉字按首类别把空格换成 `\CJKglue`。直接输入只在空格紧跟汉字（`CJK-space`、`CJK-widow`）时删去它；空格前面是分组结束、盒子、控制空格或西文时，`\kern` 等内容之前的空格原样保留。
    - **内容在前时保留空格。** `\@@_ulem_onin_entry_check_space:nn`（第二个参数是首类别，从 `\@@_boundary_emit_left_hook:nn` 传入；`\@@_ulem_level_check_aux:` 调用时为空）在入口有空格、没有透明内容、末节点不是公式时调用 `\@@_ulem_onin_entry_keep:nn`：入口前不是 `CJK-space`、`CJK-widow`，末节点是内容（`\@@_ulem_if_last_content:TF`）时解除入口，由 `\@@_ulem_entry_resolve:n` 排出空格。空格排在这些内容之后、内层盒子里，位置与直接输入不同，总宽度相同。只在嵌套链上（`\l_@@_ulem_onin_bool` 为真）这样做：单层写法经 `\@@_ulem_level_check_aux:` 也会走到这里，去掉这个条件时 `\mbox{中} \uline{\kern1pt\mbox{中}} 后` 由 31.0pt 变为与直接输入相同的 34.33pt，但空格排进了装饰线下的片段盒子；这一写法在所有版本都是 31.0pt，属于单层设计里未处理的一类，登记在 doc-gaps，没有在这里改。
    - **第一个字符直接出现时看核心的检查状态。** `前\ `、`前{} ` 与 `{中} `、`\mbox{中} ` 的 `before` 都是 `CJK`，但直接输入前两者保留空格、后两者在汉字前删去。区别在 `\g_@@_glue_check_pending_bool`：分组结束与盒子之后为真，下一个汉字检查并删去空格；控制空格、空分组之后为假。核心在 capture 开始、清除这个布尔之前把它记进新的 `space_check_flag` 字段。`\@@_ulem_onin_entry_keep:nn` 在没有内容、首类别非空（只由第一个字符的钩子调用）、`before` 为 `CJK`、`space_check_flag` 与 `xecglue_flag` 都为假时解除入口保留空格，后接西文时也保留空格本身，不再按首类别换成 `\CJKecglue`；`xCJKecglue=true` 时直接输入两者都删去空格。只在首类别非空时这样做：`\@@_ulem_level_check_aux:` 在颜色命令、`\mbox` 等透明内容开始时也会调用，这时直接输入由颜色命令或盒子开启检查、删去空格，原型里曾因此让 `前\ \uline{\sout{\color{red}中}} 后` 等 18 项由一致变为不一致。
    - **公式之后的汉字。** `\@@_ulem_onin_entry_math:nn` 在入口前不是 `CJK-space`、`CJK-widow` 时保留空格（R20-I1 后的做法），但空格排在公式之后，核心看到 glue 而不再补 `\CJKecglue`；首类别是 `CJK` 时现在再补一枚（`\mbox{x} \uline{\sout{\kern1pt$a$中}} 后` 自 `2fb2a93b` 起少 3.33pt，`{中} \uline{\sout{\kern1pt$a$中}} 后` 在 v3.10.6 上也少）。原型里在这之前加过“末节点仍是公式时不补”的判断，但入口前是公式时 `space_flag` 本来就是假，走不到这里，逐项变异与矩阵都区分不出，删去。
    - **正文以公式结尾、前面只有内容。** 正文先排出内容、公式不在正文开头时不报告首类别，结尾确认末类别为 `math`；stream end 见首类别为空、入口为 `resolved`，就不重放任何 marker，`x\uline{\kern1pt$a$}后` 因此少了公式与汉字之间的 `\CJKecglue`（自 `2fb2a93b` 起，v3.10.6 一致）。现在这时末类别是 `math` 就重放 `math` marker。r26 矩阵（2250 项，四组选项）上相对 v3.10.6 由一致变为不一致的用例由 240 项降为 0 项。原型里还加过“末节点是 whatsit 时不重放”的判断，想让颜色声明仍有效时与直接输入一样不补，实测 stream end 时末节点是装饰盒子而不是颜色的 whatsit，这个判断从不成立，删去。颜色声明一类（`x\uline{\color{red}$a$}后`，直接输入 20.57pt）因此回到 v3.10.6 的 23.90pt；首类别非空的同类写法（`x\uline{\color{red}中$a$}后`）在所有版本都多这一枚，登记在 doc-gaps。
    - **测试。** 新增 TEST 18（20 项宽度用例）：`nested-mbox-space-then-kern` 等五项内容在前；`nested-ctrl-space-then-cjk` 等三项第一个字符直接出现，另有 `xCJKecglue=true` 下一项；`nested-ctrl-space-then-color-cjk`、`nested-ctrl-space-then-mbox-cjk` 两项固定“只在首类别非空时判断”（去掉这个条件的变异只由它们发现）；`CJKecglue={\hskip 5pt}` 下两项确认保留的是空格本身而不是 `\CJKecglue`；两项公式之后接汉字；五项以公式结尾。其中 15 项在 `59e356b9` 上失败。全文件 381 项 PASS。
  - **R21 后的补修（嵌套内层保留入口空格时以公式结尾、外层正文先有内容再接嵌套命令）。**
    - **内层正文以公式结尾。** `\@@_ulem_onin_tail_check:` 在内层正文结束时置 `\l_@@_ulem_onin_tail_bool` 再调用 `\@@_ulem_level_check:`。已知副作用（R22-M2）：命令后接 `\mbox`、`\textcolor` 时，这个 marker 让它们按“公式后接汉字”补上 `\CJKecglue`，`{中} \uline{\sout{\kern1pt$a$}}\mbox{后}` 由 29.62pt 变为 32.95pt（直接输入 29.62pt，v3.10.6 36.28pt），与单层的同类写法一起登记在 doc-gaps。`\@@_ulem_onin_entry_math:nn` 保留入口空格时，这个布尔为真就在空格之后放一个 `math` marker：这时还不知道内层盒子之后是什么，由后面的字符按“公式后”的类别转换处理。R21-I1 指出，以前首类别为空、没有补 `\CJKecglue`，空格又排在公式之后，`{中} \uline{\sout{\kern1pt$a$}}后` 比直接输入少 3.33pt；`a522e35a` 的 stream end 重放 `math` marker 只在入口没有保留空格时有效（末类别在空格之后已变为 `content`）。原型里先试过“首类别为空就放 marker”，内层正文里颜色命令之前的检查也会走到这里，`{中} \uline{\sout{\kern1pt$a$\color{red}中}}后` 多一枚间距，改为只在内层正文结束时放。
    - **外层正文先有内容再接嵌套命令（R21 当时的做法，R22 已改写，见下一条）。** R21-I2 指出，`\mbox{中} \uline{\kern1pt\sout{中}} 后` 自 `2fb2a93b` 起比直接输入与 v3.10.6 少 3.33pt：外层片段盒子里的 `\kern` 在进入嵌套命令时没有解除入口，内层第一个汉字按首类别换掉了空格。R21 当时让 `\@@_ulem_onin_lead_check:` 置一个布尔量，只在进入嵌套命令之前的这一处调用 `\@@_ulem_onin_entry_keep:nn`，当场排出空格，空格因此落在外层片段盒子里、`\kern` 之后。R22 改为记下空格、送出片段盒子之前排出，删去了那个布尔量；R23 为公式路径另加的 `\l_@@_ulem_onin_lead_bool` 用途不同，见「R23 后的补修」。
    - **范围外观察的两类没有修。** 嵌套内层先有内容、再接全角左标点（`{中} \uline{\sout{\kern1pt（中}}x`），与嵌套内层以公式开头后接汉字、命令后接西文（`前 \uline{\sout{$a$中}}x`）。原型里试过让 stream end 在首类别为空时按末类别重放 marker、在嵌套内层的全角左标点之前先检查入口，r19、r20 上分别有 33、25 项由一致变为不一致，没有采用，见 doc-gaps「R21 后补记」。
    - **测试。** TEST 18 增 8 项（嵌套内层保留入口空格时以公式结尾后接汉字或西文、外层正文先有 `\kern`、规则再接一个或两个嵌套命令，以及 `CJKecglue={\hskip 5pt}` 下两项），7 项在 `a522e35a` 上失败。全文件 389 项 PASS。
  - **R22 后的补修（外层正文里保留的入口空格排在装饰之前）。**
    - **记下空格、送出片段盒子之前排出。** R22-I2 指出，R21 在进入嵌套命令之前当场排出空格，空格落在外层片段盒子里、装饰线之下：`{中} \CJKunderline{\kern1em\CJKsout{中中}\kern1em} 后` 宽度与直接输入相同，但装饰线包住了左侧空格，填空线又不居中。现在 `\@@_ulem_onin_entry_keep:nn` 在外层正文里（`\l_@@_ulem_onin_bool` 为假）末节点是内容时调用 `\@@_ulem_entry_defer:n`：把入口改为 `resolved`、记下空格（`\g_@@_ulem_space_defer_bool`、`\g_@@_ulem_space_defer_skip`），由 `\@@_ulem_entry_box:` 在 `\UL@stop` 送出这个片段盒子之前排出（`\@@_ulem_space_defer_flush:`），与正文以 `\hspace*` 开头时一样排在装饰之前。正文结束时 ulem 也经 `\UL@stop` 送出最后一个片段盒子，所以不必在 `\@@_ulem_end:` 里再排一次（原型里加过，逐项变异显示去掉它没有差别，调试输出也证实记下的空格总在 `\@@_ulem_entry_box:` 里排出）。
    - **不再只在进入嵌套命令之前判断。** R22-I1 指出，外层内容与嵌套命令之间隔着颜色命令，或外层内容是 penalty 时，R21 的 `\l_@@_ulem_onin_lead_bool` 路径不起作用，入口空格仍被删去。空格排在装饰之前以后，单层写法也不再有“空格落进片段盒子”的问题（R23-B1 指出，第一个字符在用户分组里时仍会落进去，见「R23 后的补修」），于是去掉这个布尔量，`\@@_ulem_onin_entry_check_space:nn` 总调用 `\@@_ulem_onin_entry_keep:nn`；颜色命令、`\mbox` 开始时的 `\@@_ulem_level_check_aux:` 与进入嵌套命令之前的检查都走这一条。
    - **penalty。** `\UL@stop` 从片段盒子末尾取出 penalty 时，入口有空格、入口前不是 `CJK-space`、`CJK-widow` 就在排出 penalty 之前解除入口，空格排在 penalty 之前（`\mbox{中} \uline{\nobreak\sout{中}} 后`、单层 `\mbox{中} \uline{\nobreak 中} 后`）；入口前是紧跟汉字的空格时仍按首类别处理，与直接输入 `前 {\nobreak 中}` 删去空格一致。
    - **范围。** 单层写法 `\mbox{中} \uline{\kern1pt\mbox{中}} 后`、`前\ \uline{\kern1pt\textcolor{red}{中}} 后` 由此也与直接输入一致（v3.10.6 同样少 3.33pt）。R22-M3 指出 build-and-test 说去掉嵌套链条件“只改变节点位置”不对，那时单层宽度也会变；现在这些单层写法由 TEST 18 的 `single-*` 用例固定。
    - **测试。** TEST 2 增 `group-space-kern-then-nested`、`mbox-space-kern-then-mbox` 两项节点用例（空格在装饰之前）；TEST 18 增 9 项宽度用例（外层隔着颜色命令、`\nobreak`、`\penalty0` 再接嵌套命令，单层 `\nobreak`、`\kern` 加 `\mbox`、`\textcolor`，以及 `前 \uline{\nobreak\sout{中}} 后`）。其中 8 项宽度用例在 `9105ba1e` 上失败，两项节点用例在 `9105ba1e` 上的节点列表不同。全文件 398 项 PASS。
  - **R23 后的补修（记下的空格只在片段盒子本层排出，原始盒子、用户分组与公式路径）。**
    - **用户分组里的 `\UL@stop`。** R23-B1 指出，R22 的做法在第一个字符写在用户分组里时（`\textcolor{red}{中中}`、`{\color{red}中}`、`{\nobreak 中}`）把空格排错位置：`\@@_ulem_entry_box:` 在分组里的 `\UL@stop` 中排出了记下的空格，而那时两个 `\c_group_end_token` 关闭的是用户分组与 ulem 的内层分组，片段盒子还开着，空格落进片段盒子、装饰线之下。`{中} \CJKunderline{\kern1em\textcolor{red}{中中}\kern1em} 后` 宽度与直接输入相同，但两个红色汉字之间多出 3.33pt。只比宽度的用例（`single-ctrl-space-kern-then-textcolor`）因此带着错误位置通过。现在 `\@@_ulem_entry_box:` 先看 `\UL@start`：ulem 打开片段盒子后把它设为 `\@empty`，片段盒子本层的 `\UL@stop` 关闭两层分组后它恢复原义，分组里的 `\UL@stop` 关闭之后它仍是 `\@empty`。仍是 `\@empty` 时什么都不做，空格留给片段盒子本层。`\UL@stop` 的 penalty 分支同样在 `\UL@start` 仍是 `\@empty` 时只记下空格；入口之后先有颜色命令（`\g_@@_ulem_onin_transparent_bool` 为真）时的末节点检查在外层正文里也改为记下空格（`\mbox{中} \uline{\color{red}\kern1pt\sout{中}} 后`）。
    - **原始盒子。** R23-I1 指出，第一个字符在正文里的 `\hbox`、`\raisebox` 等原始盒子里时，`\@@_ulem_raw_box_check:n` 在入口有源码空格时什么都不做，第一个字符按首类别换掉了空格：`{中} \uline{\kern1pt\hbox{中}}后` 31.0pt，直接输入与 v3.10.6 34.33pt，自 `2fb2a93b` 起。直接输入里原始盒子挡住源码空格检查，空格保留；现在入口前不是 `CJK-space`、`CJK-widow` 时记下空格，紧跟汉字的空格仍按首类别处理。
    - **用户分组与字体命令。** 第一个字符在正文里的用户分组或 `\textbf` 等字体命令里时，`\xeCJK_if_ulem_patch:TF` 仍为真，左边界钩子原来不检查；左边界 glue 由 `\@@_boundary_use_ulem_glue:nn` 的 group tag 守卫挡住，排在分组里。`\mbox{中} \uline{\kern1pt{中}} 后`、`\mbox{中} \uline{\kern1pt\textbf{中}} 后` 因此 31.0pt，直接输入 34.33pt（v3.10.6 同样）。现在 group tag 与当前分组不同时，左边界钩子同样按上面“外层正文先排出内容”的规则检查片段盒子末节点；末节点是 ulem 片段开头的 `\kern-3sp\kern3sp` 或 `ulem-nest` marker 时不检查，`\mbox{中} \uline{{中}} 后` 仍与直接输入一样删去空格（去掉这个排除的变异由 `single-mbox-space-then-group` 发现）。
    - **外层先有内容、写公式、再接嵌套命令或分组。** 原型逐步展开后，r30 矩阵（外层先排出 `\kern`、规则或 `\fbox{}`、写公式，再接嵌套命令、`\textcolor`、`\mbox`、分组、`\hbox` 或汉字）显出 `\@@_ulem_onin_entry_math:nn` 在外层正文里也当场排出空格，`{中} \uline{\kern1pt$a$\sout{中}} 后` 空格落在片段盒子里、公式之后。现在外层正文里同样记下空格。进入嵌套命令之前的检查（`\@@_ulem_onin_lead_check:` 置 `\l_@@_ulem_onin_lead_bool`）不再在外层补 `\CJKecglue`，改放 `math` marker，由 `\@@_ulem_onin_lead_get:n`（候选列表加上 `math`）带进内层，内层第一个字符按公式之后的类别转换补间距；否则外层与内层各补一枚。
    - **范围与遗留。** r29（2592 项 × 5 组选项：9 种入口前写法、4 种先排出的内容、12 种原始盒子与分组写法、3 种命令后内容、单层与嵌套）与 r30（3888 项 × 5 组选项）是这一轮新加的矩阵。相对 p76（`3de877f2`），r29 默认选项下 480 项由不一致变为一致，r30 下 582 项；r24–r28 与 r16g、rgg、r18z、r19*、r20* 上宽度逐项不变。r29 上有 2 项由一致变为不一致：`x\uline{\kern1pt\textbf{中}} 后`、`x\uline{\rule{1pt}{1pt}\textbf{中}} 后`（29.61pt 变为 26.28pt，直接输入与 v3.10.6 29.61pt）。p76 上左侧多补一枚 `\CJKecglue`、右侧删去命令后的空格，两处抵消；修好左侧以后，右侧“`\textbf` 以斜体校正留下的 `\kern0pt` 结尾时，直接输入保留命令后的空格”这一既有缺口显露出来。原型里试过在正文末尾识别这个 kern 并恢复核心的源码空格检查状态，r29 上修好 30 项、又让 4 项由一致变为不一致，没有采用；这一类与相对 v3.10.6 的其余遗留登记在 doc-gaps「R23 后补记」。
    - **测试。** TEST 2 增 9 项节点用例：`group-space-kern-then-textcolor`（R23-B1 的填空线）、`ctrl-space-kern-then-textcolor`、`mbox-space-kern-then-color-group`、`mbox-space-group-nobreak`、`group-space-kern-then-hbox`、`mbox-space-kern-then-group`、`group-space-kern-math-then-nested`、`mbox-space-color-kern-then-nested`、`mbox-space-textcolor-kern-then-cjk`，都确认入口空格在第一个装饰片段之前（在 `3de877f2` 上 9 项都不在）。TEST 3 增 `hspace0-math-spaced`，TEST 18 增 17 项宽度用例（原始盒子、用户分组、`\textbf`、`\special` 之后接分组、公式之后接嵌套命令或 `\textcolor`，以及 `CJKecglue={\hskip 5pt}` 下两项）。全文件 416 项 PASS。
  - **R24 后的补修（带进内层的 `math` marker、用户分组里的 `\UL@reskip` 与只有 penalty 的分组）。**
    - **`math` marker 只管紧跟着的第一个字符。** R24 阻塞问题指出，R23 让外层写公式之后进入嵌套命令时把 `math` marker 带进内层，内层第一个字符之前先有颜色命令、`\mbox` 或 `\fbox` 时仍按“公式后接汉字”补 `\CJKecglue`，`{中} \uline{\kern1pt$a$\sout{\color{red}中}} 后` 比直接输入多 3.33pt；直接输入 `x$a$\textcolor{red}{中}x`、`x$a$\mbox{中}x` 都不补这枚间距。现在 `\@@_ulem_onin_lead_put:` 放下 `math` marker 时置 `\l_@@_ulem_onin_lead_marker_bool`：颜色命令开始的钩子（`\@@_boundary_transparent_begin_hook:`）见到它就删去末尾的 `math` marker；以 last 方式捕获的盒子开始的钩子（`\@@_boundary_last_box_begin_hook:`）把盒子 capture 已记下的 `before`（`math`）清空，盒子里的第一个汉字就不补左边界；第一个字符出现时（`\@@_boundary_emit_left_hook:nn`）清除这个布尔量。`\fbox` 与 `\mbox` 一样由 `\@@_boundary_register_box:nn` 注册、以 last 方式捕获，同样由盒子开始的钩子处理（R25-I2 更正：此前这里误写成 `\fbox` 走 wrapped 盒子的路径、靠 `\UL@hrest` 清除布尔量；只关掉盒子开始钩子里的这一分支，`outer-group-space-kern-math-then-nested-fbox` 就失败）。原型里先试过换成一个独立的“公式之后”标记、在第一个字符的钩子里直接补 `\CJKecglue`，r31 上内层以全角左标点开头的写法（`{中} \uline{\kern1pt$a$\sout{（中}}后`）由一致变为不一致，没有采用。
    - **用户分组里的 `\UL@reskip`。** R24 重要建议第 3 条指出，R23-B1 的修法只处理了 `\UL@stop` 的片段盒子送出与 penalty 两处，用户分组里的 `\UL@reskip`（正文里的 `\hspace*` 等）仍经 `\@@_ulem_entry_skip:` 当场排出空格，`前 \CJKunderline{\textbf{\hspace*{1em}xx\hspace*{1em}}} 后` 的入口空格落进片段盒子。这一类在 v3.10.6 上同样如此。现在三处都调用新的 `\@@_ulem_entry_resolve_here:`：`\UL@start` 仍是 `\@empty`（片段盒子还开着）且入口有空格、入口前不是 `math-space` 类时记下空格，否则当场解除。`\@@_ulem_entry_skip:` 遇到零宽 glue、入口有空格、入口前不是紧跟汉字或公式（不是 `CJK-space`、`CJK-widow`、`math-space` 类）时也解除入口：在用户分组里记下空格，否则当场排出（R25-M4 更正），`{中} \uline{\hspace{0pt}中} 后` 由此与直接输入一致（v3.10.6 与 `3de877f2` 都少 3.33pt）。
    - **只有 penalty 的用户分组。** R24 重要建议第 2 条指出，用户分组里的 penalty 分支记下的空格，在最后一个片段盒子为空时不会排出：片段盒子本层的 `\UL@stop` 在盒子为空时不调用 `\@@_ulem_entry_box:`，`{中} \uline{{\nobreak}} 后` 丢了空格，全局布尔量一直为真。现在 `\@@_ulem_end:` 关闭最后一个片段盒子之后再调用一次 `\@@_ulem_space_defer_flush:`。这正是 R22 原型里有过、因为变异区分不出而删去的那一处；当时的用例都没有空的最后片段。
    - **范围与遗留。** 新矩阵 r31（2322 项 × 5 组选项）上相对 `a89246f6` 默认选项下 417 项由不一致变为一致，没有由一致变为不一致；r24–r30 与原有矩阵宽度逐项不变。R24 重要建议第 1 条（用户分组之后在正文内部接空格加汉字，修好入口一侧后显露的既有缺口）试过一个原型，r31 上修好 167 项、又让 22 项由一致变为不一致，没有采用，与单层 `\fbox{}` 之后接只含 `\nobreak` 的分组一类一起登记在 doc-gaps「R24 后补记」。
    - **测试。** TEST 2 增 `group-fill`、`group-fill-tie` 两项节点用例（`\textbf` 里的填空线，以 `~` 写法为位置对照）；TEST 18 增 12 项宽度用例（公式之后的嵌套命令以颜色命令、`\textcolor`、`\mbox`、`\fbox`、全角左标点开头，只含 `\nobreak`、`\penalty0` 的分组，分组与不分组的 `\hspace{0pt}`）。
  - **替换的最终审查后的补修（正文只有注册盒子）。** 替换的最终全范围审查（`ef49ca4e..0e9d9169`，2026-09-29）指出一项相对 v3.10.6 的回退，自 `2fb2a93b` 起，`6d7c9aa9` 修好：正文只有 `\fbox`、`\makebox`、`\colorbox` 等注册盒子、没有字符、命令两侧都不写空格时，`x\CJKunderline{\makebox[3em]{}}后` 少一枚 `\CJKecglue`（45.28pt，直接输入与 v3.10.6 48.61pt）。直接输入里注册盒子对边界透明，盒子之后重放 x 的 `default` marker；线型命令里盒子有宽度，`\UL@stop` 送出片段时解除入口，首类别一直为空，结束时入口已是 `resolved`，框架不再重放入口 marker。v3.10.6 碰巧正确，是因为结束符 `*` 被当成西文字符。
    - **做法。** 核心在 stream 结束、入口已解除、首类别为空、末类别不是 `math` 时调用新钩子 `\@@_boundary_resolved_end_hook:`（默认什么都不做）。xeCJKfntef 在透明盒子的钩子里（首类别为空、入口仍为 `armed`）由 `\@@_ulem_box_only_note:` 置 `\g_@@_ulem_box_only_bool`，并在 `\g_@@_ulem_box_only_tl` 记下刚排出的盒子的宽、高、深；嵌套命令的内层盒子排进外层片段后，`\@@_ulem_box_only_nest:`（由 `\@@_ulem_nest_mark:` 调用）改记内层盒子。`\UL@stop` 删去透明 marker 之后调用 `\@@_ulem_box_only_stop:`：末节点是尺寸相同的盒子，或是盒子命令自己（`\colorbox`，钩子看到的末节点不是盒子，没有记尺寸）、包住盒子的颜色命令（`\textcolor`，透明命令结束的钩子清空记下的尺寸）留下的 whatsit，并且入口没有源码空格、正文开头没有语法空格（`\g_@@_ulem_lead_skip` 为零），就在 `\g_@@_ulem_box_entry_tl` 记下本层层号。`\UL@reskip`、语法空格和之后不满足条件的有宽度片段清除这个层号；stream 开始与 `\@@_ulem_end:` 也清除。结束钩子在层号相同时调用 `\@@_boundary_replay_before:`。只比较尺寸是为了排除 `\rule` 这类不经注册、同样排出盒子的命令，尺寸碰巧相同时仍会误判。未注册的 `\hbox`、`\usebox` 在直接输入里不透明，不走这条路径。
    - **矩阵。** r36（`tmp/i1091/fix2/gen36.py`，2592 项 × 4 组选项：6 种命令前上下文 × 3 种命令 × 24 种只有盒子或盒子加其他内容的正文 × 6 种命令后上下文）上，默认选项下相对 `0e9d9169` 修好 135 项。其中 27 项是回退（v3.10.6 一致、修改前不一致），这类回退共 51 项；剩下的 24 项是 `中 \uline{\fbox{}中}后` 一类，正文以盒子开头、命令前有空格，按既定设计保留空格，与 `~` 写法一致。没有由一致变为不一致的用例；r24–r35 与原有矩阵逐项不变。
    - **测试。** 新增 TEST 20：9 项“正文只有盒子”的宽度用例与 8 项对照（盒子之后有 `\hspace*`、`\hspace`、`\kern`、`\rule`、`\special`、`\nobreak` 再接盒子、正文末尾空格，或正文以语法空格开头）。逐项变异 12 项全部被发现（`tmp/i1091/fix2/mut36.py`）。TEST 17 的 `single-fbox-only-no-marker`（`x\uline{\fbox{}}x`）节点列表在装饰之后多出一个 `default` marker，与直接输入 `x{\fbox{}}x` 相同，宽度不变。
    - **同一轮的文档修改。** 手册 §3.6.2 说明只有盒子的正文与直接输入一样不挡住两侧的间距，两条注意事项里的长抄录改成单独成行的 `verbatim`，消除两处 Overfull；lvt 文件头的判据清单补全 TEST 编号、注明以 `~` 写法为 oracle 的四项用例，TEST 17 的节点用例改名为 `latin-ctrl-space-then-leftparen-nodes`，与 TEST 16 的同名宽度用例区分。
  - **最终审查后的补修（盒子里的全角左标点、正文以盒子等结尾加末尾空格）。** 最终全范围审查（2026-09-29，按维护者收窄的范围）指出两项相对 v3.10.6 的回退，都自 `2fb2a93b` 起，`6848575c` 修好：
    - **全角左标点报告的 `CJK` 写进外层盒子。** `\@@_ulem_Boundary_and_FullLeft_glue:N` 为让入口空格排在标点左侧空白之前，调用 `\@@_boundary_capture_class:n { CJK }`，它写栈中每一层，包括线型命令外面 `\mbox`、`\fbox` 的 `box` 层；直接输入时 Boundary→FullLeft 不报告类别，盒子对边界没有类别。`第 \mbox{\CJKunderline{\hspace*{1em}（1）\hspace*{1em}}} 题` 两侧的空格因此都丢了（65.00pt，直接输入 71.66pt）。现在报告前由 `\@@_ulem_box_layers_save:` 记下各 `box` 层的 `first`、`last`、`tail`，报告后恢复，与 `\@@_ulem_report_last:n` 跳过盒子层一致。副作用：`\mbox{\CJKunderline{（中}}中` 由 30.00pt 变为 33.33pt（直接输入 26.99pt，v3.10.6 30.00pt），盒子与后面汉字之间的间距由 `\CJKglue` 变为词间空格；这一写法修改前后都与直接输入不一致，差异来自盒子里的片段结构。
    - **正文以盒子、stream 或嵌套命令结尾，后面还有正文末尾空格。** `\@@_ulem_loop:nw` 在语法空格前调用 `\@@_ulem_tail_check:`；字符之后的空格让末节点成为 `CJK-space` 一类，而 `\mbox`、`\textcolor`、嵌套线型命令结束时核心重放的是 `CJK`／`default` marker，空格不改变它，stream 结束时就按“正文以汉字结尾”删去命令后的空格（`姓名 \CJKunderline{\textcolor{blue}{张三} } 学号` 63.33pt，直接输入 66.66pt）。现在末节点仍是这两种 marker 时把 `tail` 记为 `content`。r35 矩阵（`gen35.py`，5280 项 × 4 组选项）上相对 `ad22fb6f` 修好 380 项；8 项由与直接输入一致变为不一致（`前 \CJKunderline{\hspace*{1em}\mbox{中} } 后` 一类），它们与 `~` 写法一致，属于“命令前空格保留”的既定设计，修改前是两处误差抵消。
    - **测试。** 新增 TEST 19：10 项宽度用例（`box-uline-leftparen-*`、`trailing-*-then-space-*`）与 `known-makebox-width-then-latin` 节点用例。逐项变异 4 项中 2 项被发现；“`tail` 只认 `CJK` marker”与“只恢复 `first`”两项区分不出，说明 `default` 与 `last`／`tail` 的恢复是防御性的。
    - **手册。** §3.6.2 把“盒子”限定为原始盒子或没有字符的盒子，补上定宽 `\makebox` 与嵌套线型命令两条注意事项（最终审查 I3、M2、M3）。
  - **R25 后的补修（公式之后的空盒子与全角左标点、空片段里记下的空格）。**
    - **空盒子之后的全角左标点。** R25 阻塞问题指出，R24 在以 last 方式捕获的盒子开始时清空 `before`（`math`），盒子为空、按透明盒子排出时重放的是空值；标点所在的内层片段盒子里，这个空盒子是第一个节点，`\@@_Boundary_and_FullLeft_glue:N` 把零宽盒子当作段首缩进盒子，压缩了标点的左侧空白：`x\uline{$a$\sout{\mbox{}（中}}x` 32.84pt，直接输入与 `0d76971c` 39.18pt。只把 `before` 恢复成 `math` 不行：`x\uline{$a$\sout{\mbox{}中}}x` 又会多补一枚 `\CJKecglue`（直接输入 `x$a$\mbox{}中x` 不补）。现在盒子开始的钩子清空类别时在 `\g_@@_ulem_lead_box_tl` 记下盒子的 capture 层号；`\@@_boundary_transparent_box_hook:` 在层号相同时排一个零宽 `\kern`，标点看到它就按前面已有内容处理。同一处缺口还出现在颜色命令之后再嵌套（`x\uline{$a$\sout{\color{red}\xout{（中}}}x`，`0d76971c` 起就少 6.34pt）：删去 `math` marker 或排出这个 `\kern` 后，在 `\g_@@_ulem_lead_drop_tl` 记下层号，`\@@_ulem_onin_lead_get:n` 在同一层进入更深一层装饰、末节点是盒子、whatsit 或 kern 时改带一个零宽 `\kern` 进内层，并逐层传下去。中间先有 glue、penalty 时不带：`\hfill` 与盒子之后的 `\penalty0` 在直接输入里同样压缩，结果一致；有限宽的 glue、`\nobreak` 等在直接输入里保留左侧空白，这里仍压缩，与没有公式的 `x\uline{x\hspace{1pt}\sout{（中}}x` 一样尚未处理（R26-I1 更正：此前写成“与直接输入一样压缩”，只对 `\hfill` 一类成立）。盒子里有公式、不走透明分支时，记录留在原处；后面同层或更浅一层的盒子开始时清除它（`\sout{\mbox{$b$}}\hbox{\mbox{}（中}`）。两个记录在最外层线型命令开始与结束时清除（R26-M1：结束时原来不清除，`\@@_boundary_transparent_box_hook:` 在装饰之外也会调用，装饰之后普通正文里的 `\colorbox{red}{\colorbox{red}{}中}` 多出一个零宽 `\kern`，由 TEST 18 的 `records-cleared-after-decoration` 固定）；第一个字符出现后不清除，这时再带零宽 `\kern` 不影响结果。
    - **空片段里记下的空格。** R25 重要建议第 1 条指出，R24 只在 `\@@_ulem_end:` 补排记下的空格，正文中间遇到空片段时（`{中} \uline{{\nobreak} 中} 后`），下一段先画出的语法空格或 `\hspace*` 的线排在空格之前，空格落在两段装饰线之间。现在片段盒子本层的 `\UL@stop` 在片段为空、`\UL@start` 不是 `\@empty` 时也排出。`\@@_ulem_end:` 的那一次保留为兜底：插桩实测在 lvt、r28–r34 与 4800 项穷举里都没有走到；lvt 的 `\EntryAssertIdle` 改为同时断言 `\g_@@_ulem_space_defer_bool` 为假（R24-I2 建议）：两处排出都去掉时，三项 `*-penalty-only` 除宽度不对之外还报告状态残留；只去掉片段为空时的排出，由 `empty-group-then-*` 的节点列表发现。
    - **范围与遗留。** 新矩阵 r32（空盒子、颜色命令、`\fbox` 等之后接全角左标点、汉字或引号，3150 项 × 7 组选项）、r33（中间内容之后再嵌套，1440 项 × 3 组）、r34（三层嵌套，960 项 × 2 组）上，相对 `94414fd3`（p106）没有由一致变为不一致的用例，分别修好 476、144、126 项（默认选项）；r24–r31 与原有矩阵逐项不变。R24-B1 补充指出的 `{中} \uline{\kern1pt$a$\sout{（中}} 后`（命令后有空格）仍多 3.33pt：命令后的空格没有在汉字前删去，因为入口已解除、正文末尾的 marker 不在列表末尾，stream 结束时不重放末类别。命令后紧接西文时同一原因少一枚 `\CJKecglue`（`x\uline{\kern1pt$a$\sout{（中}}x` 36.85pt 对 40.18pt），命令前没有空格时也是如此（R26-I2）。内层先有颜色命令时这相对 v3.10.6 是回退，R27 的矩阵上共 30 项（包括命令前是普通空格的 `前 \uline{\fbox{}$a$\sout{\color{red}（中}}x`），维护者决定登记、接受为已知限制，范围见 doc-gaps「R25 后补记」。本轮修好左侧空白以后，`x\uline{\kern1pt$a$\sout{\mbox{}（中}} 后`（38.56pt→44.90pt，直接输入 41.57pt）、`{中} \uline{\kern1pt$a$\sout{\mbox{}（中}}x`（38.56pt→44.90pt，直接输入 48.23pt）一类由左右两处误差变为只剩右侧这一处，前者离直接输入更远。原型里试过在这时按末类别重放 `CJK`，r27 上又有 15 项由一致变为不一致（`前 \uline{\sout{\kern1pt（中}}x` 等，左侧入口一侧的既有差异原先与它抵消），没有采用，登记在 doc-gaps「R25 后补记」，并由 TEST 18 的 `known-*` 两项节点用例固定当前行为。
    - **测试。** TEST 2 增 `empty-group-then-*` 四项节点用例（空片段之后接语法空格或 `\hspace*`，以 `~` 写法为位置对照）；TEST 18 增 14 项宽度用例（`*-math-then-nested-empty-*`、`*-nested-leftparen`、`three-level-leftparen`、`nested-color-glue-nested-leftparen`、`nested-glue-empty-nested-leftparen`、`empty-mbox-after-decoration`、`math-mbox-then-hbox-empty-mbox`、`latin-math-color-then-next-decoration-in-hbox`）与两项 `known-*` 节点用例。
- **嵌套内层与盒子里全角标点之后还有字符（R6 修复过程中由协调者发现，R7 后改写，R8 后补上内层正文末尾检查）。** 全角标点与后面字符之间的转换（全角标点到 Default、到 CJK）不向 capture 报告类别。外层片段盒子里，ulem 片段和末尾 marker 会补上这一信息；嵌套线型命令的内层正文整段装在 `\UL@onin` 的盒子里，`\mbox` 等盒子里也一样，capture 只看到标点之前的字符。以前 ulem 结束符 `*` 被当成西文字符，恰好把末类别写成 default：标点后面是西文时结果碰巧正确，后面是汉字时本来就错（v3.10.6 同样错）。`2fb2a93b` 不再观察 `*` 之后，`\uline{\sout{中。z}} 后`、`\uline{\sout{中“z}} 后`、`\CJKunderline{\CJKsout{中。z}}x` 外层命令后的空格或间距都按 CJK 处理，与直接输入和 v3.10.6 不一致（逐提交二分：`2fb2a93b` 至 `35bf0adc` 的八个提交都失败，v3.10.6 与 `ef49ca4e` 正确）。
  - **现在的做法（R7 后）**：五个全角标点转换的非 ulem 分支（`\xeCJK_if_ulem_patch:TF` 为假，也就是嵌套内层与 `\mbox` 等盒子里）在原生转换之后调用 `\@@_ulem_report_last:n`：`\@@_ulem_FullLeft_and_Default:`、`\@@_ulem_FullRight_and_Default:` 报 `default`；`\@@_ulem_FullLeft_and_CJK:`、`\@@_ulem_FullRight_and_CJK:`、`\@@_ulem_FullRight_and_CJStarter:` 报 `CJK`。它只在 capture 活跃（`\g_@@_boundary_capture_depth_int` 大于零）且未暂停（`\g_@@_boundary_suspend_depth_int` 为零）时生效，只对 `kind` 为 `stream-ulem` 的各层写 `last`（报告的类别）和 `tail=char`。不再以 onin 布尔为条件，所以 `\mbox` 里也生效。
  - **不设首类别、不补左边界**：首类别由 `\@@_boundary_capture_class:n` 在第一个报告点设置，并在那里经 `\@@_boundary_capture_emit_left:nn` 补左边界 glue。补报发生在内层盒子里，若借用这个函数，首类别为空时 glue 会排进盒子（`他说\CJKunderline{\CJKsout{“OK”}}吗` 的 “ 与 OK 之间多出 3.33pt，R7-I1），所以 `\@@_ulem_report_last:n` 直接写字段。
  - **只写 `stream-ulem` 层**：`\mbox` 等盒子的 capture 层在盒子结束时读取节点列表末尾的 marker 决定末类别；若也写这一层，`中 \uline{\sout{\mbox{中（A）}中}} 吗` 会把盒子末类别当成西文，在盒子与后面的汉字之间多出一枚西文间距（不加这条限制时实测 70.83pt，oracle 67.5pt，`35bf0adc` 正确）。
  - **同时写 `tail=char`**：外层在嵌套命令之前已排出显式 glue 时 `tail` 为 `content`（`中 \uline{中\hspace{1em}\sout{，中}} 吗`），内层以字符结尾后要恢复为 `char`。
  - **检查暂停深度**：capture 暂停期间（如 `\mbox{中\sbox0{中。z}}` 里 `\sbox` 排出的内容）排出的字符不属于正文，不能改写外层的末类别。
  - **内层正文末尾检查（R8 后）**：`tail=char` 让 R7 的补报暴露了一个从 `2fb2a93b` 起就存在的缺口。内层正文由 `\UL@onin` 整段排进一个盒子，不经过 `\UL@reskip` 与 `\UL@stop`，最后一个字符之后的 `\hspace*`、`\quad`、`\rule` 等内容不会把 `tail` 改成 `content`。R7 在标点之后写 `tail=char`，于是 `中 \uline{\sout{中（A）中\hspace*{1em}}} 吗` 的命令后空格按 CJK 规则被删去（77.5pt，直接输入 80.83pt），相对 `a8a0c05a` 与 v3.10.6 回退，共五种写法（R8-I1）；没有标点的 `中 \uline{\sout{中\hspace*{1em}}} 吗`（40.0pt，直接输入 43.33pt）从 `2fb2a93b` 起就不对，v3.10.6 碰巧正确，是因为结束符 `*` 被当成西文字符。现在 `\UL@onin` 的包装在内层正文 `#1 \s_@@_ulem_body \@@_boundary_math_end:n {#1}` 之后、盒子关闭之前调用 `\@@_ulem_onin_tail_check:`：
    - 只在嵌套链上（`\l_@@_ulem_onin_bool` 为真）且有 ulem 入口层（`\g_@@_ulem_entry_depth_int` 大于零）时工作；`\mbox` 里的嵌套链布尔已被 `\UL@hrest` 清除，不检查（去掉这个条件时 `mbox-nested-period-latin` 失败）。
    - 入口层的 `tail` 已是 `punct` 时不检查，标点后的补偿 glue 由 `\@@_ulem_punct_peek:` 处理（去掉这个条件时 `nested-period-space-latin` 等三项失败）。
    - 否则末节点是 glue（`\lastnodetype`=11）就置 `content`：内层盒子里的显式 glue 没有被 `\UL@reskip` 移出，与片段盒子不同，这是与 `\@@_ulem_tail_check:` 唯一的区别。R9 起这一步改由 `\@@_ulem_onin_tail_glue:` 做，并排除全角左标点自己排出的 glue，R10 起靠 `ulem-left` marker 认出这枚 glue（见上文「全角左标点结尾」）。其余节点按 `\@@_ulem_tail_check:` 的规则判断：marker、字符、公式算字符，kern 看是否 marker，其余（盒子、规则、penalty、special 等）算 `content`。
    - 三层嵌套时，最内层命令排出的盒子是中间层盒子的末节点。中间层的 `\@@_ulem_nest_mark:` 在它后面补 marker（见上文 marker 一条），中间层的检查因此按字符处理；检查完如果末节点正是这个 marker，就删去它，`\uline{\sout{\xout{中}}} 后` 仍按汉字结尾处理，中间层盒子末尾也不残留 marker。R9 起删除由 `\@@_ulem_nest_node_remove:` 做，只找 `\l_@@_ulem_nest_node_tl` 记下的那一种 marker；删去后末节点若不是盒子，说明删掉的是前面字符自己的 marker（中间层正文以字符结尾、补的又是同类别 marker 时两者无法区分），就把它放回（`符 \uline{\sout{\xout{中}中}} 后`，节点用例 `three-level-keep-char-marker`）。
  - **沿革**：R6 的 `\@@_ulem_onin_report_default:` 只在两个 Default 转换里、`\l_@@_ulem_onin_bool` 为真时调用 `\@@_boundary_capture_class:n { default }`。它只修好了直接写在嵌套内层的三种写法，还引入两处回退：全角标点之后再接汉字时没有补报 `CJK`，`中\uline{\sout{中（A）中}}吗` 等五种写法回到 v3.10.6 的错误结果（R7-B1）；首类别为空时补报设了首类别并补左边界 glue（R7-I1）。`\UL@hrest` 在每个新盒子开头清掉 onin 布尔，`\mbox` 里的“标点＋西文”（`符 \uline{\sout{\mbox{中。z}}} 后`）因此没有补报（R7-I2）。R7 删去该函数，改用 `\@@_ulem_report_last:n`。
- **开头语法空格的记账。** 正文以语法空格开头（`符 \CJKunderline{ \hspace*{2em}} 后`）时，ulem 先把这段空格画成装饰线，入口空格若要保留只能排在它之后，线从中间断开；但也不能像盒子那样直接解除入口，因为 `符 \CJKunderline{ 中} 后` 的入口空格仍要按首类别处理。`\@@_ulem_loop:nw` 因此把 `\UL@leaders` 换成 `\@@_ulem_syntax_space:`：入口仍为 armed 时只把宽度记进 `\g_@@_ulem_lead_skip`、不画。`\@@_ulem_lead_flush:`（在分组内临时把 `\UL@skip` 设为记账宽度后调用 `\UL@leaders`）在以下时刻补画：首类别出现、`\@@_boundary_use_ulem_glue_outer:nn` 排出左边界 glue 之后；入口已不再 armed 时，`\UL@stop` 送出片段盒子或 `\UL@reskip` 画 glue 之前（`\@@_ulem_lead_draw:`）；正文结束时仍有记账，说明正文只有语法空格和不可见内容，`\@@_ulem_lead_end:` 先 `\@@_ulem_entry_resolve:` 排出入口空格再补画。入口空格因此总在这段线之前。正文以语法空格加全角左标点开头（`符 \CJKunderline{ 《中》} 后`、`x \CJKunderline{ 《中》} z`）时，R1 的补画会落到标点左侧空白之后；R2 后 `\@@_ulem_Boundary_and_FullLeft_glue:N` 的 ulem 分支在 `\UL@stop` 之后、排标点左侧空白之前调用 `\@@_ulem_lead_draw:`，这段线因此排在标点左侧空白之前。`\g_@@_ulem_body_end_bool` 为真后，ulem 在 `\UL@end` 前自己补的那枚语法空格照常直接画出，随后被 `\@@_ulem_end:` 的 `\unskip` 删去，不记账。

已知未覆盖（#1091 未修）：普通 stream（如 `符 \href{..}{\usebox\tri} 后`）与独立符号命令（`符 \CJKunderdot{\usebox\tri} 后`）在正文无类别但有可见输出时，入口状态仍在结束时重放、空格落到命令之后，因为它们没有 ulem 这样的输出拦截点；非 ulem 路径的 Boundary→FullLeft／FullRight 仍不向 capture 报告类别；以全角右标点开头的装饰正文未处理。正文以全角标点开头、紧接西文时，普通 stream 与 ulem 都与直接输入不一致，修复前（v3.10.6）也不一致：`\href{x}{。z} 后`、`\textcolor{red}{。z} 后`、`\uline{。z} 后`（后者在 v3.10.6 差 6.66pt，现在差 3.33pt）；普通 stream 中全角标点之后接西文、位于正文末尾的 `\href{x}{中。z} 后` 在 v3.10.6 与现在都差 3.33pt，同属这一类。以下四项修复前后相同，属既有差异：正文以 `\textit{x}` 结尾时与直接输入差 0.54pt（斜体校正）；`\CJKunderline{中 }` 这类“字符后接正文末尾空格”与带花括号的直接输入差 3.33pt（此前这里还列了 `\CJKunderline{\CJKsout{中} }`，它自 `2fb2a93b` 起才不一致，是回退，最终审查后已修好，见上文「最终审查后的补修」）；符号型命令以全角右标点结尾（`\CJKunderdot{中。} x`，以及嵌在线型命令里的 `\CJKunderline{\CJKunderdot{中。}} x`），符号型命令不经 ulem，没有扫描标记与 peek；公式加尾随空格（`\CJKunderline{中$x$ } y`）与带花括号的直接输入差 3.33pt。嵌套线型命令内层以全角右标点结尾（R2-M2）已在 R3 修好，R4 又补上盒子里的嵌套、内层“标点＋末尾空格”与三层嵌套，R5 补上 `CheckFullRight=true` 下的“标点＋末尾空格”，R6 把其中的空格判断改为按含义比较（不再删去字符码为 32 的活动字符），不再列入。嵌套内层全角标点之后还有字符的写法，R6 只修好了直接写在内层、标点后紧接西文的三种，R7 补上标点后再接汉字、再接标点与汉字以及 `\mbox` 里的变体（见上一条），也不再列入。R8 补上嵌套内层正文最后一个字符之后还有 glue、盒子、规则等内容的写法，同样不再列入；R8 盲审与复核另记了一批 v3.10.6 就已存在的差异（`\mbox` 里的线型命令左边界（`a8b45cf4` 已修好）、`符\uline{\mbox{“OK”中}}后` 装饰内容整段消失、嵌套版本的末尾空格与 `\relax` 等；其中 `\uline{\sout{\xout{中}x}}` 已在 R9 修好），R9 又记下分组里的全角左标点结尾（`符 \uline{{中（}} 后`、`符 \uline{\textbf{中（}} 后`，43.33pt 对 40.0pt，所有版本都不对；R10 分析了原因并更正 CHANGELOG 的说法，见上文「全角左标点结尾」一条）与嵌套命令连接的几种剩余写法，R10 复核又记下 `CJKspace=true` 下的 `符 \uline{（}x` 与两层嵌套命令后接空格与汉字等写法，清单见 [[../memory/doc-gaps]]。仍未覆盖的同类问题是嵌套内层正文以全角标点开头、首类别为空：`他说\CJKunderline{\CJKsout{“OK”}}吗`（59.71pt，oracle 65.56pt）、`他说\uline{\sout{（A）}}吗`（51.16pt，oracle 57.5pt）、`中\CJKunderline{\CJKsout{《A》中}}吗`（52.05pt，oracle 57.5pt）、`符\uline{\sout{。z}}后`（34.44pt，oracle 37.77pt），以及外层先有内容、内层以全角左标点开头的 `中 \uline{中\hspace{1em}\sout{（A）中}} 吗`（R7 后 71.16pt，`35bf0adc` 与 v3.10.6 为 74.49pt，oracle 77.5pt，都不对；数值变化来自 FullLeft→Default 现在补报 `default`，属于同一缺口）。前四种在 R7 前后与 `35bf0adc` 相同，五种在 v3.10.6 都不对。box 策略中末尾是已排好盒子的内容仍按无可见输出处理，是 #998 的既定设计。根因与验证过程见 [[../memory/reflections/1091-fntef-ulem-terminator-entry-space]]，测试见 `llmdoc/reference/build-and-test.md` 的 `fntef-entry-space01` 一节。

**正文传给 ulem 前必须是字面记号（#1026）**：`\UL@on` / `\UL@onin` 只在正文是“公式尾＋尾随源码空格”时才用 `\@@_boundary_ulem_math_tail_space:nnn` 重排，其余情况保持字面 `#1` 展开；否则西文词右侧补出的 `\CJKecglue` 会被固定宽度的装饰片段盒子固化收缩量，无法参与外层断行。详见上文“边界恢复状态机”一节的同名小节。

**西文词前的 ecglue 走 `\@@_use_ecglue_skip:`（#1037）**：同一条固化机制在词前还有一处，与正文展开方式无关——源码空格被前视吃掉后，`CJK-space` marker 落在 `\UL@start` 刚打开的片段盒子内部，`\@@_check_for_ecglue_aux:` 补出的 ecglue 随之固化。该入口在主体里默认为普通 `\skip_horizontal:N`，由 `xeCJKfntef` 改写为「装饰 stream 活动**且** `\UL@start` 为 `\@empty` 时才经 `\@@_ulem_glue:n` 输出」，使收缩量回到外层。因为该入口位于所有中西文边界的通用路径上，这个布尔判断不可省——`\xeCJK_if_ulem_patch:TF` 单独不足以证明当前在装饰中。详见上文同名小节。

### xeCJK-listings

重写 `listings` 的字符转换机制，使 CJK 字符不再需要设为 active catcode。核心是用 `\tl_set_rescan:Nno`（即 `\scantokens`）替代 `\lccode` + `\lowercase` 路线。

`\@@_listings_rescan:Nn`（`xeCJK.dtx` L11856-11878）在 rescan 前用 `\tl_map_inline:Nn` 逐 token 扫描 `\l_@@_tmp_tl`，对 catcode 6 parameter token 通过 `\char_generate:nn { \int_value:w ``##1 } { 13 }` 转换为**同字符码**的 active token，避免 `\scantokens` 字符串化阶段对 catcode 6 token 的二次双写，同时保留用户通过 `\catcode\`\&=6` 等方式自定义的 parameter token 原字符身份。该模式由 \#378 → \#879 演化而来：\#378 用 catcode-class regex 修双写（替换端硬编码 codepoint），\#879 在 `\catcode\`\&=6` 场景下显式暴露其局限，改为 token-level map 保留原 codepoint。

`\lstinline` 的正文不由公开命令参数直接读取：分隔符路径经过 `\lstinline@`，花括号路径直接进入 `\lst@InlineG`。两处都启动 `auto` stream，并在共同的 `\lst@DeInit` 通过 `\aftergroup` 结束；因此颜色 push/pop、CJK/Default 混合内容与左右源码空格都进入统一边界恢复。`listings-color01` 用 braced Latin、braced CJK、两种混合方向与 delimiter Latin 共 20 个 direct-input oracle 验证，`listings-hash01` 独立保护 rescan/catcode 行为。

### xunicode-addon

为 xunicode 补充额外的 Unicode 符号命令定义。

#### `xunicode-symbols.tex` 驱动的逐字符多级字体回退（#878）

`xunicode-symbols.tex` 是 `xunicode-addon` 用于演示其覆盖字符集合的驱动文件，由 `l3build install --full` 排版生成 `xunicode-symbols.pdf`。该集合横跨多个 Unicode 区段（符号、几何形状、CJK Stroke 等），**不存在**在主流 Windows / Linux / macOS 上都默认装且覆盖完整的单一字体；此前版本采用“整段单字体 if-else”的回退策略时，凡是被选中字体未覆盖的字符都会以 `Missing character` 警告出现。

PR #886（fix #878）将驱动改为“逐字符多级字体回退链”：

1. 用 fontspec 的 `\IfFontExistsTF` 条件声明候选 NFSS 字体家族 `\xunsymNoto`、`\xunsymSymbola`、`\xunsymSegoe`、`\xunsymDejaVu`，主字体仍为 `FreeSerif`。
2. `\UnicodeTextSymbol` 在排出每个 codepoint 前，使用 `\reverse_if:N \tex_iffontchar:D \tex_font:D #1 \exp_stop_f:` 测试当前激活字体是否含该字符；不命中则通过 `\cs_if_exist_use:N` 切换到下一级候选家族后再次测试，形成 `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans` 五级嵌套链。
3. `\cs_if_exist_use:N` 用于在“候选字体在本机不存在 ⇒ `\newfontfamily` 未定义该家族”时静默跳过、由外层 `\reverse_if:N` 继续向下级落，避免 `! Undefined control sequence`。

该模式只适用于“演示性符号目录”驱动文件，**不应**推广到 xeCJK 正文 / CJK 字体路径（后者属于字符分类驱动的字体切换，不是 codepoint glyph 级缺失）。详细根因、嵌套顺序选择理由与适用边界见反思 [[878-xunicode-symbols-multilevel-fallback]]；驱动新增段对应 `xeCJK.dtx` `\changes` v3.10.0 2026/06/23。

## TECkit 映射

xeCJK 在构建时通过 `xeCJK/build.lua` 中的 `make_teckit_mapping()` 从 Unicode Unihan 数据生成 `.map`/`.tec` 字体映射文件，用于繁简转换和句号形式映射。这部分功能数据在构建阶段动态生成，不完全静态存储。
