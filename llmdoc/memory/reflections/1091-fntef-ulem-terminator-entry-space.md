---
name: 1091-fntef-ulem-terminator-entry-space
description: 记录 #1091 修复线型装饰命令把 ulem 结束符 `*` 当作正文字符、以及 stream-ulem 入口空格被排到装饰之后的两层问题；核心教训是只修一层会得到“宽度对、位置错”的中间态，验证必须看节点顺序；新增拦截点要用全角标点开头的正文复核；变异无判别力时要找出是哪条兜底路径掩盖了它；旧基线可能冻结了缺陷值；R1 补修（7a817059）的教训是比对要组合正文首尾的非字符内容、命令两侧空格与后续字符类别，oracle 要确认源码空格确实存在，改右边界重放要检查段末的像素补偿 glue；本地增量审查 R2 后的教训是声称测试保护某性质时，要用只破坏该性质的变异确认测试会失败（R1 用 `\raisebox` 测 `\raise` 位移，根本没走到取下再放回的路径），模仿直接输入的 `\ignorespaces` 要连同分组层级一起模仿；本地增量审查 R3 后改用正文末尾的扫描标记加 peek 判断全角右标点，并修好嵌套内层标点，教训是模仿一个原语前先确认它的完整停止条件（`\ignorespaces` 在第一个非空格记号处停），用直接对应该条件的判据而不是逐个补情况，声称“修复前后相同”前要把有无空格、后接汉字／西文各测一遍；本地增量审查 R4 后补上盒子里的嵌套装饰、嵌套内层“标点＋末尾空格”与三层嵌套中间层，教训是给状态标志加作用域时要把“进入”“新盒子清除”“再次进入”组合起来测、嵌套至少测到三层，新增的 peek 路径要与原有 ulem 分支对空格的处理一致；本地增量审查 R5 后补上 `CheckFullRight=true` 时标点自己先删去空格、peek 看不到这枚空格的情况（`\g_@@_FullRight_space_bool` 记下是否删过空格），教训是模仿一个原语时还要检查用户选项会不会在它之前改变输入，测试矩阵要把 `CheckFullRight` 这类会改变记号流的选项作为一个维度，记录变异时要写实际做的改动而不是意图；本地增量审查 R6 后把 `CheckFullRight` 的空格判断从 `\peek_charcode_remove:NTF` 改为 `\peek_meaning_remove:NTF`（字符码比较会删去 `\verb`、`\obeyspaces` 下字符码为 32 的活动字符），修复过程中又逐提交二分发现嵌套内层全角标点接西文的同根因回退（R6 只修好直接写在内层的三种写法），教训是替换 l3 peek 函数时要确认比较方式（charcode／catcode／meaning）与被替换的函数一致、活动字符这类“看起来像空格”的记号是必测维度，每轮修复后都要把嵌套、盒子、选项等维度与发布版横向比对，而不只比对直接输入；本地增量审查 R7 发现 R6 的补报漏掉全角标点后接汉字与 `\mbox` 变体，还在内层盒子里插入左边界 glue，改用 `\@@_ulem_report_last:n` 在五个全角标点转换的非 ulem 分支只补报 `stream-ulem` 层的末类别，教训是补报类别时要区分“末类别”与“首类别＋左边界”两种副作用，修回退时要把同根因的所有转换一起列出、逐项与 `35bf0adc`、v3.10.6、直接输入比对，声称“已修好”前要把盒子路径等变体也测一遍；本地增量审查 R8 发现 R7 补报的 `tail=char` 暴露了嵌套内层正文不经过片段盒子拦截点的旧缺口（内层最后一个字符之后的 `\hspace*` 等内容不置 `content`），改由 `\@@_ulem_onin_tail_check:` 在内层盒子关闭前检查末节点，教训是新补报的状态会暴露原来被错误值掩盖的缺口，“最后一个字符之后的内容”这一维度要在嵌套内层也测，测试注释里关于日志深度的说法要以 `.tlg` 实际内容为准；本地增量审查 R9 发现 R8 把内层盒子末尾全角左标点自己排出的 `\penalty10000 \glue0pt` 当成正文内容，以及嵌套线型命令的内容与相邻字符之间缺少 `\CJKecglue`，改为以 `tail=left` 处理全角左标点结尾、由 `\@@_ulem_nest_node:` 选择嵌套盒子后的 marker 并在内层开头重放外层末尾的 marker，教训是把一类节点一律当成内容之前要先列出 xeCJK 自己会在同一位置排出的节点，修一侧的连接要同时检查另一侧，发布版总宽度一致也可能是两处错误抵消，写“其余在发布版就正确”前要逐项比对
metadata:
  type: feedback
---

# [Task Reflection]

## Task

Issue #1091：`普通字符 \myfillin{} 后续文字`（`\myfillin` 用 `\CJKunderline` 包住
`\hspace*`、盒子、`\hspace*`，宏定义里带一枚结尾空格）排出的填空线不居中；把命令前的空格
换成 `~` 就居中。v3.9.1 正常；v3.10.0–3.10.3 左侧空格被删（#324 语义）但仍居中；从
v3.10.4（#992 capture 框架）起，左侧空格跑到装饰末尾，还多出一段装饰和一枚间距。

修复在提交 `2fb2a93b`（`xeCJK/xeCJK.dtx`，新测试 `xeCJK/testfiles/fntef-entry-space01.lvt`，
`\changes{v3.10.7}` 三条，用户手册新增 §3.6.2「用线型命令排填空线」）。

## Expected vs Actual

- 预期：bot 分析与我的初步假设都是“入口源码空格没有重新输出”，补回即可。
- 实际：节点列表显示空格不是丢了，而是被搬到装饰末尾；命令前没有空格时同样多出装饰。
  问题分两层，只修第一层后 issue 的 MWE 仍是“左 0 右 2”。

## 两层根因

1. **ulem 结束符 `*` 被 capture 观察到。** ulem 用 `\UL@end *` 标记正文结束。最后一个“词”
   由 `\UL@start` 打开片段盒子，`\UL@end` 吃掉定界符后，`\UL@word`（以及 xeCJK 的
   `\xeCJK_ulem_word:nw`）中的 `\if_meaning:w \UL@end #1` 把参数里第二个 `*` 留在真分支开头，
   它作为普通字符排进随即被丢弃的片段盒子。它不上页面，但触发 Boundary→Default 转换，
   `\@@_boundary_capture_class:n` 把 default 写进所有活跃的 capture 层。
   - 正文没有字符（空参数、只有 `\hspace*` 与盒子）或以全角左标点开头（Boundary→FullLeft
     不报告类别）时，首类别在 `*` 处取得：左边界被补到装饰末尾，借 `\UL@stop … \UL@start`
     把结尾语法空格和空片段盒子画成多余装饰；last=default 又让右侧多一枚 ecglue。
     例：`符\CJKunderline{}后` 29.99pt（应 20pt）。
   - 正文末尾没有可读 marker（嵌套线型命令、全角标点结尾）时，stream end 用观察值
     last=default：`\CJKunderline{中。}文` 句号后多 3.33pt。
2. **stream-ulem 入口空格的位置。** capture_begin 取下入口空格和 marker，等首类别再决定左边界。
   正文若先排出有宽度的内容（盒子、规则、`\hspace*`、`\quad`），ulem 已把它们排到外层列表，
   之后补的 glue 只能落在其后；正文根本没有类别时，stream end 的 `replay_before` 更把 marker
   与空格放到装饰之后。

## 修法要点与取舍

- 第 1 层：重定义 `\UL@end *` 为 capture 暂停，`\@@_ulem_end:` 关闭丢弃盒子后恢复。暂停可嵌套、
  按层保存恢复 last-node 与 pending，所以 `*` 留下的状态一并撤销。选这里是因为 `\UL@end` 只在
  这条结束路径执行（`\UL@onin`／`\UL@onmath` 不经过它），暂停与恢复天然成对。（推断，未实测：
  如果改在观察侧按字符过滤 `*`，会连正文里真实的 `*` 一起过滤掉。）
- 第 2 层：每层 capture 新增 `entry` 字段（armed／resolved／空）。stream-ulem 启动时 armed；
  在 ulem 把内容排出外层的两个拦截点（重写的 `\UL@stop` 在 `\UL@putbox` 前、`\UL@reskip`）
  检查片段盒子是否有宽度、末节点是否为规则（`\hspace*` 的零宽 `\vrule`）或 `\UL@skip` 是否非零，
  满足则在盒子外原样排出入口空格并置 resolved。resolved 之后 `emit_left` 不补左边界、stream end
  不重放、片段级 glue 分支（`use_ulem_glue_outer`）不补 glue。只含颜色 special 的片段不触发，
  保持与直接输入 `符 \color{red}中` 一致。
- 这样选的依据是参照物：新语义与 v3.9.1 和 `~` 写法一致，首字符在可见内容之后不补边界与直接
  输入 `\quad x` 一致。只有 ulem 有“内容排到外层”的拦截点，所以修法只覆盖 stream-ulem。
- 修第 2 层引出回归：`书 \CJKunderline{《红》}的` 的空格被放到标点左侧空白与标点之间。补救是
  ulem 分支的 Boundary→FullLeft 在 `\UL@stop` 前先报告 `CJK`，与直接输入等宽（50pt）。

## 测试设计与变异验证

- 只比总宽区分不出空格在装饰前还是后，所以 TEST 1–3 用节点列表固定
  glue 位于第一个 `\rule … \cleaders` 之前（当时 lvt 写了 `showboxdepth=1`，但随后的 `\loggingoutput`
  把深度设回 `\maxdimen`，`.tlg` 记录的一直是完整深度，见 R8 一节）；每个节点用例独占一页并先打印 `CASE` 行，
  `\pagestyle{empty}` 去掉页码噪声。TEST 4–7 与直接输入比较宽度并打印 PASS／FAIL。每个用例后
  断言 capture depth、active seq、suspend depth、entry depth 归零。
- 变异 M1–M9 逐项只破坏一处（`tmp/i1091/mutate.py`），全部 rc=1（`tmp/i1091/mutation-summary.txt`）。
- **M8（去掉 `emit_left` 的 resolved 判断）起初没有判别力**，原因有两层兜底：resolve 已把
  space_flag 置假，CJK-空格场景下“补左边界”只是重放一枚已经不存在的空格，是空操作；片段级分支
  又被 `use_ulem_glue_outer` 的 resolved 判断拦住。补救是找一条绕开两层兜底的路径：
  `符\CJKunderline{\quad\mbox{x}}后`——首字符在 `\mbox` 里，ulem 在 `\everyhbox` 中恢复了 `\ `
  原义，patch 判断为假，左边界走普通 glue 通道；入口又没有空格。加入后 M8、M2、M9 都在这条上失败。
- 旧基线 `fntef-linebreak01`、`fntef-nest-linebreak01` 把段末 marker 记成 default（13sp），
  修复后为 CJK（11sp）。更新前逐项确认差异来自第 1 层根因，不是新引入的变化。
- 删去一条起初写的用例 `\CJKunderline{中。} x` 对 `中。 x`：两者差 3.33pt，但修复前后相同，
  是全角标点后空格处理的另一既有差异，不属于本 issue。
- xeCJK 124/124、ctex `-e xetex` 186/186、`l3build doc` 通过。

## What Went Wrong

1. **先入为主。** 按“空格没重新输出”的假设动手前，先用逐版本（v3.9.1、3.10.0、3.10.3、3.10.4、
   3.10.5、HEAD）同一 MWE 的节点列表对比才定位到 v3.10.4，再用打印 `capture_class` 参数的探针
   找到 default 来自结尾 `*`。如果只看宽度或只看截图，会补错方向。
2. **只修一层时出现“对 oracle 宽度正确、位置仍错”的中间态。** 宽度断言对这个中间态是绿的。
3. **新增拦截点引出全角左标点回归**，是在补测 CJK 标点开头的正文时才发现的。
4. **M8 第一次变异全绿。** 原因是已有用例都走了兜底路径，而不是被变异的判断多余。
5. 一次 cwd 漂移，把临时文件建在 `xeCJK/` 下，已移走。

## Root Cause

- 代码层：#992 的 capture 框架假定 stream 内所有 interchar 转换都来自正文，没有考虑 ulem 自己在
  丢弃盒子里排出的定界字符；入口空格的“延迟决定”也假定首类别出现前外层列表没有新内容，
  而 ulem 会在首字符之前把盒子、规则、glue 排到外层。
- 过程层：最初的验证手段（宽度、bot 描述）对“位置”这个维度不敏感；变异用例集中在同一条
  代码路径上，兜底逻辑掩盖了被变异的判断。

## Missing Docs or Signals

- `llmdoc/architecture/xecjk-architecture.md` 约 715 行写“由唯一的 stream end 以列表证据校正
  不可见定界字符产生的观察值”，只说了末尾校正，没说首类别同样会被 `*` 污染；本次修复后这句
  已不准确，且缺少 `entry` 字段、`\UL@stop`／`\UL@reskip` 拦截点和“正文先排出可见内容时入口空格
  原样保留”的语义。
- 没有现成提示说明“一般（非 ulem）Boundary→FullLeft/FullRight 不向 capture 报告类别”，这是
  本次标点回归的背景，也是剩余限制之一。

## 已知未覆盖（限制，未修）

- 普通 stream（`符 \href{..}{\usebox\tri} 后`）与独立符号命令（`符 \CJKunderdot{\usebox\tri} 后`）
  正文无类别但有可见输出时，入口状态仍在结束时重放、空格落到命令之后：它们没有 ulem 这样的
  输出拦截点。
- box 策略中末尾是已排好盒子的内容仍按无可见输出处理（#998 既定设计）。
- 非 ulem 的 Boundary→FullLeft/FullRight 不报告类别；全角右标点开头的装饰正文未处理。
- `\CJKunderline{中。} x` 与直接输入在全角标点后空格处理不同。

## Promotion Candidates

- **lessons-learned（新条目）**：修“位置”类缺陷时，断言必须检查节点顺序而不只检查总宽；分层
  根因修了一层时，宽度断言可能已经变绿而位置仍错。可与「可见排版修复需要三类证据」互相引用。
- **lessons-learned（补充「变异要逐项做」）**：某项变异无判别力时，先找出是哪条兜底路径让被变异
  的代码成了空操作（本次是 resolve 已清 space_flag，加上 `use_ulem_glue_outer` 的判断），再构造
  绕开兜底的用例；不要据此认定该判断冗余。
- **lessons-learned（补充「字符分类修改必须检查节点结构」或新条目）**：在 xeCJK 边界机制里新增
  拦截点后，要用全角左标点和右标点开头、结尾的正文各复核一次，因为 Boundary→FullLeft/FullRight
  不经过报告类别的路径。
- **lessons-learned（补充「判断修复是否到位需要三个对照点」）**：逐版本节点列表对比是定位引入版本
  的有效手段；本次三个对照点是 v3.9.1、v3.10.3、v3.10.4。
- **仅留在 memory**：`*` 定界符的具体机制、M8 用例的构造细节、cwd 漂移。它们是本次的实现细节，
  稳定部分应写进架构文档而不是教训条目。

## Follow-up

- recorder：更新 `llmdoc/architecture/xecjk-architecture.md` 的 stream-ulem 与“边界状态与装饰
  盒子隔离”两节：`\UL@end` 暂停与 `\@@_ulem_end:` 恢复、`entry` 字段的三种取值和解除时机、
  两个拦截点的判据、resolved 后三处不再补 glue 的位置、ulem 分支 FullLeft 报告 CJK，以及上面
  列出的四条已知限制。
- recorder：`llmdoc/reference/build-and-test.md` 登记 `fntef-entry-space01` 的覆盖范围，并注明
  `fntef-linebreak01`／`fntef-nest-linebreak01` 段末 marker 从 default 更正为 CJK 的原因。
- 如后续有人报告 `\href`／`\CJKunderdot` 包住盒子时空格落在命令之后，从本反思“已知未覆盖”接手。

## 本地独立审查 R1 后的补修（提交 7a817059）

### 审查结果与自查发现

- 首轮本地盲审（run `20260927T021602Z-r1-first`）报告阻塞问题 1 项、重要建议 1 项、小问题 4 项。
  - 阻塞：正文以字符开头、以 `\hspace*`、盒子、kern、penalty、special 等结尾时，命令后的源码
    空格被按 CJK 规则删去。例：`姓名 \CJKunderline{张三\hspace*{4em}} 学号` 为 100pt，直接输入
    为 103.33pt。这是 `2fb2a93b` 引入的回归：`*` 不再覆盖末类别后，stream end 只看正文最后
    一个字符，没有看它后面还排出了别的内容。
  - 重要：正文以语法空格开头时，入口空格排在已画线的语法空格之后，装饰线从中间断开。
  - 小问题：“片段盒”用词；`build-and-test.md` 中的页数过时；测试注释称“issue 中的写法”，
    实际与 issue 不同；手册“命令前后的源码空格”说得太宽。
- 实现者用 40 多项“装饰写法与直接输入”的宽度比对（`tmp/i1091/fix2/right.tex`）另外发现一处
  盲审没报的回归：`2fb2a93b` 让 `\CJKunderline{中。}x` 在 x 前多出 3.33pt，修复前它与直接输入
  一致（都是 35.28pt）。原因：直接输入时 `\xeCJK_FullRight_and_Boundary:` 排出标点补偿 glue 后
  用 `\ignorespaces` 吃掉空格，列表末尾没有 CJK marker；装饰内同样的处理只作用在正文内部，
  stream end 却按观察到的 CJK 重放 marker。

### 修法要点

- 每层 capture 新增 `tail` 字段（`char`／`content`／`punct`），报告类别时置 `char`。xeCJKfntef
  在以下位置置 `content`：`\UL@reskip` 画非零显式 glue；`\UL@stop` 取到非零 penalty；正文结束处
  （`\@@_ulem_body_end:`，位于 `\UL@on` 正文末、`\xeCJK_ulem_right:` 之前）和每个语法空格之前
  由 `\@@_ulem_tail_check:` 检查片段盒子末节点。末节点是 marker、字符、连字、公式、glue 或
  片段为空时不改；是盒子、规则、kern、special 等时置 `content`。
- 嵌套线型命令（`\UL@onin` 把内层正文装进一个盒子）由 `\@@_ulem_nest_mark:` 记下盒子的宽、高、
  深，末节点尺寸相同时仍算字符；记录在 `\UL@stop` 和 `\UL@hrest`（每个新盒子开头）清除。
- 全角右标点结尾由 `\@@_ulem_FullRight_and_Boundary:` 置 `punct`，结束时换成 `content`，并在
  `\@@_ulem_end:` 末尾执行 `\ignorespaces`，与直接输入一样吃掉命令后的空格。
- stream end 见 `content` 时不重放 marker，改排一个零宽 kern（原因见下文第 2 条坑）。
- 开头语法空格：入口处于 armed 时，`\@@_ulem_syntax_space:` 把宽度记进 `\g_@@_ulem_lead_skip`，
  不画。以下三种时机再补画：首类别排出左边界 glue 时（`use_ulem_glue_outer`）；入口解除后、
  `\UL@stop` 送出片段盒子或 `\UL@reskip` 画 glue 之前；正文结束时（`\@@_ulem_lead_end:` 先解除
  入口、排出入口空格，再补画）。入口空格因此总在这段线之前。

### What Went Wrong（补修过程）

1. **把“片段盒子末尾是 glue”也当成 `content`。** `command-boundary-math01`（96 项 3.33pt 差值
   失败）与 `command-boundary-math05` 失败。原因：公式加尾随空格的重排路径会在片段盒子里留下
   公式后的源码空格 glue，它是边界机制自己补的，不是正文内容。改为 glue 不改 `tail`。
2. **`content` 时起初什么都不排。** `fntef-linebreak01` 中段末以句号结尾的一行宽了一个像素。
   ulem 每段装饰线后跟一枚负的像素补偿 glue，段末 `\par` 会删去行尾 glue；原先重放的 marker
   正好挡住了它。改为排零宽 kern，并加 TEST 12 用段末自然宽度与 `\hbox` 比对来固定。
3. **首轮比对 oracle 有两项无效。** `\usebox\FillBox }` 与 `\kern5pt }` 里的空格被控制词和尺寸
   吃掉，根本不存在“正文末尾空格”。改用 `\usebox{\FillBox} }`、`\kern5pt\relax{} }`，并用
   花括号包住 oracle。
4. **手册 `\changes` 中的短抄录以汉字开头时报错。** `|姓名 ...|` 使 `l3build doc` 报
   Undefined control sequence：changes 索引把 `|` 当作 makeindex 的 encap 符。以反斜杠开头的
   `|\CJKunderline{...}|` 没有问题。
5. **接力时面对半成品补丁。** 上一轮会话只写了一半补丁（引用了未定义的 `\@@_ulem_lead_draw:`
   等）就中断；接手后先读盲审报告和补丁残片，再重新设计，没有在残片上直接续写。
6. **expl3 变体用错。** 条件函数只声明了 T、F 变体却调用了 TF，嵌套用例报 Undefined control
   sequence；`\tl_if_eq:NeF` 不存在，改用 `\str_if_eq:eeF`。

### Root Cause（补修）

- 代码层：`2fb2a93b` 修正了 `*` 对末类别的覆盖，但 stream end 仍只根据“最后报告的类别”决定是否
  重放 marker，没有“最后一个字符之后还有没有别的内容”的信号；`*` 原先恰好掩盖了这一缺口。
  全角右标点结尾的 `\ignorespaces` 语义也没有传到装饰外。
- 过程层：上一轮的比对用例只覆盖了正文开头的非字符内容，没有覆盖正文结尾的非字符内容，也没有
  系统地组合“命令两侧有无空格”和“后面是汉字还是西文”。盲审只报出其中一类，实现者自己的
  组合比对又多找到一处回归。

### 验证

- `fntef-entry-space01` 新增 TEST 8–12：开头语法空格的节点顺序、末尾内容与全角右标点的宽度比对、
  嵌套装饰后的盒子、段末。
- 逐项变异 14 项（reskip、penalty、正文末检查、语法空格前检查、嵌套尺寸判断、`\UL@hrest` 清除、
  punct、`\ignorespaces`、开头空格记账、结束时解除入口、stream end 读 `tail`、kern 标记判断、
  零宽 kern、glue 不改）：13 项使该测试失败，“glue 不改”一项由 `command-boundary-math05` 捕获。
- xeCJK 124／124、ctex `l3build check -e xetex` 186／186、`l3build doc` 通过（xeCJK.pdf 261 页）。

### 仍未覆盖（修复前后相同）

- `符 \CJKunderline{\textit{x}}后` 差 0.54pt（斜体校正）。
- `\CJKunderline{中 }` 这类 CJK 后接正文末尾空格的写法，与带花括号的直接输入差 3.33pt；
  `\CJKunderline{\CJKsout{中} } 后` 属于同类。（最终全范围审查 M1 更正：后者在 `ef49ca4e` 与 v3.10.6 上与直接输入一致，
  自 `2fb2a93b` 起才不一致，是回退，不是同类；最终审查后已修好。）
- 更正：上文“测试设计与变异验证”和“已知未覆盖”中记为既有差异的 `\CJKunderline{中。} x`，
  已随 `punct` 处理修好，不再是限制。

### Promotion Candidates（补修）

- **lessons-learned（新条目或补充「可见排版修复需要三类证据」）**：比对测试要覆盖“正文开头与
  结尾各放一种非字符内容 × 命令两侧有无空格 × 后面是汉字还是西文”的组合。本次盲审只报出其中
  一类，组合比对又多找到一处回归。
- **lessons-learned**：写 oracle 时要确认源码空格真的存在；控制词和尺寸后面的空格会被吃掉，
  这样的 oracle 与被测写法比较没有意义。
- **lessons-learned**：ulem 装饰末尾的像素补偿 glue 依赖后面有非 glue 节点；改动右边界重放时要
  检查段末的行宽。
- **reference（`build-and-test.md`）**：`\changes` 中的短抄录不能以汉字开头（`|` 被 changes 索引
  当作 encap 符），可作为 dtx 文档编写注意事项登记。
- **仅留在 memory**：半成品补丁的接力过程、expl3 变体误用、`tail` 各置位点的具体位置。后者的
  稳定部分应由 recorder 写进 `llmdoc/architecture/xecjk-architecture.md` 的 stream-ulem 一节，
  与上文 Follow-up 一并处理。

## 本地增量审查 R2 后的补修

### 审查发现

- 对 R1 补修的本地增量盲审（R2）报告阻塞问题 1 项、重要建议 1 项、小问题 5 项。
  - R2-B1（阻塞）：正文以分组内的全角右标点结尾时（`\CJKunderline{\textcolor{red}{中。}} x`、
    `\CJKunderline{{中。}} x`、`\CJKunderline{{\color{red}中。}} x`），`\@@_ulem_end:` 末尾的
    `\ignorespaces` 吃掉命令后的空格；直接输入 `{中。} x` 会保留这枚空格，因为 `\ignorespaces`
    只作用在标点所在的分组里，`}` 之后的空格不受影响。
  - R2-I1（重要）：R1 的 `\@@_ulem_tail_check_box:` 用 `\lastbox` 取下末尾盒子，按宽、高、深比对后
    再放回；`\lastbox` 会把 `\raise` 位移清零（`\CJKsout{中}\raise2pt\copy\FillBox`）。R1 的
    TEST 11 用 `\raisebox`，它新建盒子，没有走到这条路径；llmdoc 与测试注释写的“`\raise` 位移不丢”
    不成立。
  - R2-M1：正文以语法空格加全角左标点开头时，补画的线排到标点左侧空白之后。
  - R2-M2：正文以嵌套线型命令结尾、内层以全角右标点结尾（`\CJKunderline{\CJKsout{中。}} x`），
    仍与直接输入 `中。 x` 不同；修复前后相同。
  - R2-M3：尺寸相同的 `\usebox` 被误认为嵌套装饰（R1 按尺寸识别的直接后果）。
  - R2-M4：手册 §3.6.2 一条的短抄录造成 Overfull。
  - R2-M5：lvt 文件头仍写“两处边界缺陷”“判据分两类”，与实际内容不符。

### 修法要点

- B1：新增 `\@@_ulem_tail_punct:`，置 `punct` 时把当前分组层级记入 `\g_@@_ulem_punct_level_int`；
  `\@@_ulem_tail_check:` 发现当前层级比它浅，说明标点所在的分组已关闭，就把 `tail` 改为 `content`
  （命令后的空格保留，西文前不补间距）。
- I1 与 M3：删去按尺寸识别与 `\UL@hrest` 钩子。`\@@_ulem_nest_mark:` 改为在内层命令排出的盒子之后补
  一个新声明的 `ulem-nest` marker（`\xeCJK_declare_node:n { ulem-nest }`），只在
  `\xeCJK_if_ulem_patch:TF` 为真、即外层片段盒子这一层补。末节点检查把它当 marker，按字符处理；
  之后再排出的任何盒子（含 `\usebox`、`\raise\copy`）都按 `content`。检查不再取下盒子。
  `\@@_ulem_body_end:` 检查后若末尾正是这个 marker 就删去，右边界与以前一样取 capture 观察值，
  `fntef-nest-linebreak01` 基线因此不变。
- M1：`\@@_ulem_Boundary_and_FullLeft_glue:N` 的 ulem 分支在 `\UL@stop` 之后调用
  `\@@_ulem_lead_draw:`，线排在标点左侧空白之前。
- M2：未修。dtx 的实现说明记下这一限制，CHANGELOG 与 `\changes` 收窄为“正文直接以全角右标点
  结尾……标点在正文内层分组里时保留分组之后的空格（嵌套线型命令内层的标点尚未处理）”。
- M4：改写该条手册说明，先用文字说清楚，再把短抄录 `第 \CJKunderline{ \hspace*{2em}} 题` 放在
  句末。M5：lvt 文件头改为“以下几类边界缺陷”“判据分三类”。

### What Went Wrong（R2）

1. **把没有验证过的性质当作事实写进文档和测试注释。** R1 补修时认为“取下再放回末尾盒子不丢
   位移”，并写了 TEST 11 作为保护；但 `\raisebox` 会新建盒子，末尾盒子检查从未取下它，这条
   用例对该性质没有判别力。R2 盲审用“删掉放回步骤”的变异证明了这一点；`\raise2pt\copy\FillBox` 这种不新建盒子的写法
   才会真正经过取下再放回，而它的位移确实被清零。R1 的 14 项变异里有“嵌套尺寸判断”，却没有一项只破坏“放回后位移不变”。
2. **模仿直接输入时只模仿了 `\ignorespaces`，没有模仿它的作用范围。** 直接输入的
   `\ignorespaces` 受分组约束，装饰内的等价处理挪到了 `\@@_ulem_end:` 末尾、已在所有内层分组之外，
   于是把本应保留的空格也吃掉了。R1 的 TEST 10 没有分组内的标点用例。
3. **按尺寸识别本身就是启发式。** 用宽、高、深当盒子身份，相同尺寸的无关盒子必然误判；改成
   在确切位置放 marker 后，识别不再依赖巧合，也不再需要取下节点。

### Root Cause（R2）

- 代码层：R1 用“末尾盒子尺寸与内层装饰相同”近似“末尾盒子就是内层装饰”，并为比对取下节点；
  全角右标点的 `\ignorespaces` 语义被移到装饰结束处，丢掉了分组层级这一维。
- 过程层：测试的覆盖声明没有经过变异确认——注释说保护什么，就要有一个只破坏这一点的变异让它失败。

### 验证

- `fntef-entry-space01`：TEST 8 新增 `lead-fullleft`、`lead-fullleft-latin`；TEST 9 新增
  `nested-then-copy`；TEST 10 新增七个分组内全角句号结尾的写法（花括号 `{中。}` 与空格＋西文、空格＋汉字、
  无空格西文、无空格汉字各一项，`\textcolor` 与空格＋西文、无空格西文各一项，分组内 `\color`
  与空格＋西文一项）；TEST 11 改为
  `nested-raisebox` 与 `nested-raise-copy`，后者真正经过末尾盒子检查，节点列表固定
  `shifted -2.0` 与命令后的 `\glue 3.33`。
- 变异 4 项全部被捕获：去掉分组层级规则（TEST 10 四项失败）、去掉 FullLeft 补画
  （`lead-fullleft-latin` 节点改变）、去掉 `ulem-nest` marker（四项失败）、去掉正文末尾删 marker
  （节点改变）。

### Promotion Candidates（R2）

- **lessons-learned（补充「变异要逐项做」）**：声称测试保护某性质时，要用一个只破坏该性质的变异
  确认测试会失败；否则测试可能根本没有经过那条路径（本次 `\raisebox` 新建盒子）。
- **lessons-learned**：`\ignorespaces` 的作用范围受分组约束；在别处模仿直接输入的行为时，要连同
  分组层级一起模仿。
- **仅留在 memory**：`\lastbox` 清零 `\raise` 位移是 TeX 的已知行为，稳定部分已写进架构文档
  「ulem 结束符与入口空格（#1091）」的嵌套装饰一条。

## 本地增量审查 R3 后的补修

### 审查发现

- 对 R2 补修（`275c04d9`）的本地增量盲审（R3）报告的问题如下。
  - R3-B1（阻塞）：全角右标点结尾时，`\@@_ulem_end:` 末尾的 `\ignorespaces` 太宽。标点之后还有
    `\relax`、`{}`、`\hspace{0pt}`、包装宏（`\newcommand\ans[1]{#1\relax}`）、正文末尾空格等不产生
    节点的记号时，命令后的空格仍被吃掉；直接输入的 `\ignorespaces` 碰到第一个非空格记号就停下，
    会保留这枚空格。R2 的分组层级规则只覆盖了“分组结束”这一种情况。
  - R3-I1（重要，与 R2-M2 合并）：`\CJKunderline{\CJKsout{中。}}x`（嵌套内层以全角右标点结尾、
    无空格后接西文）是 `2fb2a93b` 引入的回退，v3.10.6 与直接输入一致；R2 把它写成“修复前后相同”
    是错的。有空格的 `\CJKunderline{\CJKsout{中。}} x` 则修复前后都与直接输入不一致。
  - R3-I2（重要）：`\changes` 里的 `|...|` 进入 `.glo` 后，第一个 `|` 被 makeindex 当作 encap 符，
    后面的文字被当作页码格式命令执行：更改历史出现 `hdclindex…`／`dex…` 文字泄漏，带下划线的
    正文被真正排出，并有 Overfull。以反斜杠开头的 `|\CJKunderline{...}|` 不报错，排版同样出错。
    上文 R1 第 4 条坑和 Promotion Candidates 里“以反斜杠开头的短抄录没有问题”是错的。
  - R3-M1：`llmdoc/state/sync.md` 的水位仍停在 R1 补修提交 `7a817059`，没有随后续提交更新。

### 修法要点

- B1：`\UL@on` 与 `\UL@onin` 在正文 `#1` 之后、`\@@_boundary_math_end:n` 之前多放一个扫描标记
  `\s_@@_ulem_body`（`\scan_new:N`，含义是 `\relax`）。`\@@_ulem_FullRight_and_Boundary:` 里原来的
  `\ignorespaces` 换成 `\@@_ulem_punct_peek:`：`\peek_remove_spaces:n` 跳过空格，下一个记号是 N 型且
  就是这个标记时 `tail` 置 `punct`，否则置 `content`。分组层级规则（`\g_@@_ulem_punct_level_int`、
  `\@@_ulem_tail_punct:`）删除：分组结束的 `}` 不是标记，自然按 `content` 处理。结束处的
  `\@@_ulem_tail_punct_end:` 与 `\@@_ulem_end:` 末尾的 `\ignorespaces` 保留，只在 `tail` 为 `punct`
  （标点紧接正文末尾）时执行。
- I1：`\UL@onin` 的正文开头置 `\l_@@_ulem_onin_bool`（`\UL@hrest` 在每个新盒子开头把它置假，所以
  `\mbox` 里的标点不受影响）；原生 `\xeCJK_FullRight_and_Boundary:` 分支在该布尔为真时也调用 peek；
  `\@@_ulem_nest_mark:` 补 `ulem-nest` marker 后若 `tail` 为 `punct`，就在外层再 peek 一次。这次 peek
  必须放在所有条件分支之外，否则它看到的是条件分支的 `}`。
- I2：本次新增的 `\changes` 不再用 `|...|`，改用 `\texttt{...}`、`\tn{...}` 和文字描述，重新生成
  CHANGELOG。`pdftotext` 检索确认本次条目的 `dex10432191`、`dex9189170` 泄漏消失；仍有三处
  `hdclindex…` 来自旧条目（含 `xeCJK/xeCJK.dtx` 约 536 行 v3.10.4 的 `|CJKglue|`），不在本次范围，
  记入 `llmdoc/memory/doc-gaps.md`。

### What Went Wrong（R3）

1. **只模仿了被模仿原语的一种停止条件。** R2 为分组内的标点补规则时，把 `\ignorespaces` 的作用
   范围理解为“同一分组”，于是只处理了分组结束。实际的停止条件是“第一个非空格记号”，分组结束
   只是其中一种；`\relax`、`{}`、包装宏里的记号都会让它停下。按现象逐个补情况，下一次审查总能再
   找到一种没补的记号。正文末尾标记直接对应这个停止条件：标点后除空格外紧接的就是标记，才等价于
   `\ignorespaces` 能一路吃到命令之外。
2. **“修复前后相同”的判断只测了一种写法。** R2 把嵌套内层标点记为 R2-M2、修复前后相同，只测了
   有空格的 `\CJKunderline{\CJKsout{中。}} x`；无空格后接西文的写法实际是 `2fb2a93b` 引入的回退。
   CHANGELOG 与 `\changes` 据此收窄措辞，等于把一处回退写成了既有限制。
3. **把 `\changes` 里“不报错”当成“没有问题”。** R1 只看 `l3build doc` 是否报错，没有看更改历史
   排出来的文字。

### Root Cause（R3）

- 代码层：R1、R2 的全角右标点处理都在结束处无条件（或只按分组层级）执行 `\ignorespaces`，没有
  记录“标点之后、命令结束之前是否还有别的记号”这一信息；内层 `\UL@onin` 的标点完全没有接入。
- 过程层：模仿原语时没有先查清它的完整停止条件；声称“修复前后相同”前没有把有无空格、后接
  汉字／西文的组合测全；文档构建的验收只看退出码，不看 PDF 文字。

### 验证

- `fntef-entry-space01` TEST 10 新增 19 项（`\relax`、`{}`、`\hspace{0pt}`、包装宏 `\EntryAns`、
  正文内侧空格与末尾空格、`\uline` 加 `\relax`；嵌套内层以句号或引号结尾，无空格与有空格后接西文、
  后接汉字、`\uline` 外层、内层分组、内层 `\relax`、内层 `\mbox`、嵌套之后接 `\relax` 有无空格；
  `\mbox` 里的句号），全文件 90 项 PASS；这 19 项在 `275c04d9` 上有 15 项失败。
- 逐项变异 5 项全部被捕获：peek 的标记比较（3 项失败）、非标记时置 `content`（4 项）、onin 分支
  调用 peek（7 项）、`\UL@hrest` 清除 onin 布尔（1 项，`nested-mbox-period-latin`）、`nest_mark`
  的外层 peek（1 项，`nested-then-relax-space-latin`）。

### 仍未覆盖（修复前后相同）

- 符号型命令以全角右标点结尾：`\CJKunderdot{中。} x`、`\CJKunderline{\CJKunderdot{中。}} x`。
- `\CJKunderline{中$x$ } y`：公式加尾随空格与带花括号的直接输入差 3.33pt。
- 此前记录的 `\textit{x}` 斜体校正与“字符后接正文末尾空格”两项。

### Promotion Candidates（R3）

- **lessons-learned（补充「按根因枚举象限」）**：在别处模仿一个原语的行为时，先查清它的完整
  停止条件，再用直接对应该条件的判据；不要按审查报出的现象逐个补情况。
- **lessons-learned（补充「判断修复是否到位需要三个对照点」）**：声称“修复前后相同”前，要把
  有无空格、后接汉字／西文各测一遍，并与未受影响的发布版比对。
- **reference（`build-and-test.md`）**：更正 `\changes` 短抄录规则（已由 recorder 完成）。
- **仅留在 memory**：peek 必须放在条件分支之外这一实现细节，稳定部分已写进架构文档。

## 本地增量审查 R4 后的补修

### 审查发现

- 对 R3 补修（`aa78cca7`）的本地增量盲审（R4）报告阻塞问题 1 项、重要建议 2 项、小问题 3 项。
  - R4-B1（阻塞）：线型装饰正文里的 `\mbox`／`\fbox` 中又有以全角右标点结尾的线型装饰
    （`\uline{中\mbox{\sout{文。}}} x`）时，外层命令后的空格被吃掉；v3.10.6 与直接输入一致。
    原因：`\mbox` 开头 `\UL@hrest` 已把 `\l_@@_ulem_onin_bool` 置假，盒子里的 `\UL@onin` 却在自己的
    正文开头重新置真，标点处的 peek 于是把外层 `tail` 置为 `punct`。
  - R4-I1（重要）：嵌套内层正文以“标点＋末尾空格”结尾（`\uline{\sout{中。 }} x`）时，onin 路径的
    peek 用 `\peek_remove_spaces:n` 跳过空格后直接看到扫描标记，置 `punct`，外层空格被吃掉；单层写法
    `\CJKunderline{中。 } x` 保留这枚空格。
  - R4-I2（重要）：三层嵌套 `\uline{\sout{\xout{中。}\relax}} x` 中，中间层的 `\@@_ulem_nest_mark:`
    在非 patch 状态下既不 peek 也不改写 `tail`，中间层的 `\relax` 没有被看到。
  - R4-M1：dtx 里“然后照常 `\ignorespaces`”的说明与两条分支的实际行为不符。
  - R4-M2：`llmdoc/state/sync.md` 的 `updated-at` 不是 ISO 8601 时间戳（协调者已改）。
  - R4-M3：macro 环境的 `\changes` 标签取名字列表最后一个名字，R3 把 `\s_@@_ulem_body` 放在末位，
    标签落在扫描标记而不是右边界判断的函数名下。

### 修法要点

- B1：`\UL@onin` 进入时先算新增的 `\l_@@_ulem_onin_enter_bool`：`\xeCJK_if_ulem_patch:TF` 为真
  （直接从外层片段盒子进入）就置真，否则继承当前的 `\l_@@_ulem_onin_bool`；内层正文开头用它设置
  onin 布尔。盒子里的嵌套链继承已被 `\UL@hrest` 清除的状态，不再重新置真。
- I1：`\@@_ulem_punct_peek:` 先用 `\peek_charcode_remove:NTF \c_space_token`（R6 改为按含义比较）判断空格：下一个记号是
  空格就置 `content` 并 `\ignorespaces`；否则按原来的 N 型／标记判断。原生
  `\xeCJK_FullRight_and_Boundary:` 末尾的 `\ignorespaces` 遇到紧随的受保护函数 `\@@_ulem_punct_peek:`
  就停下，所以内层末尾空格同样由 peek 看到。
- I2：`\@@_ulem_nest_mark:` 的非 patch 分支中，若 onin 布尔为真（仍在嵌套链上）且 `tail` 为 `punct`，
  也调用 peek。
- M1：dtx 说明改为分别描述三种情况（标记、空格、其他记号）。M3：`\s_@@_ulem_body` 移到名字列表首位（末位于是变成辅助函数，R5-M3 再次调整，见下文）。

### What Went Wrong（R4）

1. **给状态标志加作用域时只考虑了两种情况。** R3 引入 onin 布尔时，只考虑了“外层片段盒子里的
   嵌套”（应置真）和“盒子里直接出现标点”（`\UL@hrest` 清除），没有考虑“盒子里又有嵌套装饰”——
   这时清除之后又被再次进入的 `\UL@onin` 置真。“进入”“新盒子清除”“再次进入”三件事单独都测过，
   组合起来没有测。
2. **嵌套只测了两层。** 中间层的 `\@@_ulem_nest_mark:` 处在非 patch 状态，这条分支在两层嵌套里
   根本不会出现；R3 的 19 项新用例都只有两层。
3. **新增的 peek 路径没有对齐原有分支对空格的处理。** ulem 分支按空格分词，R3 的
   `\peek_remove_spaces:n` 在那里结果正确；onin 路径的内层正文不分词，末尾空格直接跟在标点后面，
   跳过空格后看到的就是扫描标记，本应保留外层空格的写法被判为 `punct`。

### Root Cause（R4）

- 代码层：onin 布尔的置真没有区分“从外层片段盒子进入”与“从被清除过的盒子里进入”；peek 先跳过空格再看标记，而内层正文不分词，末尾空格直接跟在标点后面，跳过它就看到了标记；中间层 `\@@_ulem_nest_mark:` 的非 patch
  分支是空的。
- 过程层：状态标志的测试只覆盖了单个事件，没有覆盖事件的组合；嵌套深度只测到两层；给一条新路径
  复用判定函数时，没有逐项核对它与原路径的输入差异（这里是空格是否已被分词）。

### 验证

- `fntef-entry-space01` TEST 10 新增 7 项（`\mbox`／`\fbox` 里的嵌套装饰、嵌套内层“标点＋末尾空格”
  后接西文与汉字、三层嵌套加 `\relax`、三层嵌套标点结尾后接西文），全文件 97 项 PASS；这 7 项在
  `aa78cca7` 上有 6 项失败。
- 逐项变异 3 项全部被捕获：进入 onin 时不看 patch 状态（3 项失败）、peek 遇到空格时改为置 `punct`
  （2 项）、中间层不 peek（1 项）。（R5 前这里写成“空格时不置 `content`”，那是意图描述；按字面只删去
  置 `content` 一步只有 1 项失败，见下文 R5 一节。）

### Promotion Candidates（R4）

- **lessons-learned（补充「按根因枚举象限」）**：给状态标志加作用域时，要把“进入”“新盒子清除”
  “再次进入”组合起来测，嵌套层数至少测到三层；新增的判定路径要与原有路径对空格这类分词定界符的
  处理保持一致。
- **reference（`build-and-test.md`）**：macro 环境的 `\changes` 标签取名字列表最后一个名字（已由
  recorder 完成）。
- **仅留在 memory**：三处修改的具体位置，稳定部分已写进架构文档。

## 本地增量审查 R5 后的补修

### 审查发现

- 对 R4 补修（`f8f3f731`）的本地增量盲审（R5）报告重要建议 1 项、小问题 4 项。
  - R5-I1（重要）：打开 `CheckFullRight=true` 时，全角右标点字符本身的
    `\xeCJK_check_FullRight_symbol:Nw` 先用 `\peek_remove_spaces:n` 删去其后的空格再查看下一个记号，
    `\@@_ulem_punct_peek:` 看不到这枚空格、直接看到扫描标记，于是 `\CJKunderline{中。 } x`、
    `\uline{\sout{中。 }} x` 与三层嵌套的“标点＋正文末尾空格”都吃掉了命令后的空格。v3.10.6 与直接
    输入一致；单层自 `7a817059`、嵌套自 `8d1d9a34` 起失败。
  - R5-M1：dtx 与架构文档把 ulem 分词后在词与词之间补回的空格写成“词中空格”，应为“词间空格”。
  - R5-M2：dtx 说明文字折行不当（已在代码侧修正）。
  - R5-M3：R4 把 `\s_@@_ulem_body` 移到名字列表首位后，末位变成辅助函数 `\@@_ulem_punct_peek_aux:N`，
    `\changes` 标签仍没有落在右边界判断的函数名下。
  - R5-M4：llmdoc 把 R4 的一项变异记成“peek 遇到空格时不置 `content`，2 项失败”；按字面做只有 1 项
    失败，实际做的变异是“遇到空格时改为置 `punct`”。

### 修法要点

- I1：`\xeCJK_check_FullRight_symbol:Nw` 改为先 `\peek_charcode_remove:NTF \c_space_token`（R6 改为
  `\peek_meaning_remove:NTF`，见下文 R6 一节）：删去了空格
  就把新布尔 `\g_@@_FullRight_space_bool` 置真，再照旧 `\peek_remove_spaces:n`；没有空格就置假。
  `\@@_ulem_punct_peek:` 见到它为真就按 `content` 处理，否则进入拆出来的
  `\@@_ulem_punct_peek_space:` 走原来的判断。`CheckFullRight=false` 时复位该布尔。
- M1：“词中空格”改为“词间空格”。M3：名字列表改为以 `\@@_ulem_tail_check:` 结尾。M4：改正
  `build-and-test.md` 与本文 R4 一节的变异描述。

### What Went Wrong（R5）

1. **模仿原语时只看了原语本身，没看在它之前运行的用户选项。** R3、R4 让 peek 模仿 `\ignorespaces`
   的停止条件，并让两条路径对空格的处理一致，但都默认“peek 运行时标点后面的空格还在”。
   `CheckFullRight` 让标点字符在 peek 之前就删去了空格，这个前提不成立。
2. **测试矩阵没有把会改变记号流的选项作为维度。** 前四轮的用例都在默认选项下运行；
   `CheckFullRight` 恰好在全角右标点上改变了输入，却从未打开测过。
3. **变异按意图记录，没有按实际改动记录。** R4 的记录写成“不置 `content`”，实际做的是“改为置
   `punct`”；两者失败项数不同，后来者照记录复做会得到不一致的结果。

### Root Cause（R5）

- 代码层：peek 判断“标点后有没有空格”只看当前记号流，而 `CheckFullRight` 已经删去了空格、又没有
  留下任何记录。
- 过程层：确认模仿对象的行为时，没有清点有哪些用户选项会在它之前改变输入；变异记录是事后按意图
  补写的。

### 验证

- `fntef-entry-space01` 新增 TEST 12「trailing full-width right punctuation with CheckFullRight」（14 项，
  原 TEST 12 段末自然宽度改为 TEST 13），全文件 111 项 PASS；新增项在 `f8f3f731` 上有 5 项失败。
- 逐项变异 4 项全部被捕获：删去空格时不置布尔（5 项失败）、peek 不读布尔（5 项）、关闭选项时不复位
  （1 项）、没有空格时不置假（2 项）。R4 的“遇到空格时改为置 `punct`”重做一次，现使 4 项失败，全在
  TEST 10（`inner-spaces-cjk`、`trailing-space-cjk`、`nested-period-trailing-latin`、
  `nested-period-trailing-cjk`）。R5 时这里写的是“新增的 `CheckFullRight` 用例也覆盖到它”，R6 补充报告
  实测 TEST 12 一项都没有失败（打开该选项时空格由 `\g_@@_FullRight_space_bool` 处理，不经过这条分支），
  这个归因不正确；与 R4 记录的 2 项相差的原因未确认。

### Promotion Candidates（R5）

- **lessons-learned（补充「按根因枚举象限」与「命令边界修复必须覆盖输出等价矩阵」）**：模仿原语时还要
  检查用户选项会不会在它之前改变输入；测试矩阵要把 `CheckFullRight` 这类会改变记号流的选项作为一个
  维度。
- **reference（`build-and-test.md`）**：变异记录写实际做的改动；`\changes` 名字列表的最后一个名字
  是 `\@@_ulem_tail_check:`（已由 recorder 完成）。
- **仅留在 memory**：R5 的审查项编号与失败项数。

## 本地增量审查 R6 后的补修

### 审查发现

- 对 R5 补修（`fcfe3b79`／`35bf0adc`）的本地增量盲审（R6）报告阻塞问题 1 项、小问题 1 项。
  - R6-B1（阻塞）：R5 把 `\xeCJK_check_FullRight_symbol:Nw` 改用 `\peek_charcode_remove:NTF \c_space_token`，
    它只比较字符码。打开 `CheckFullRight` 后，全角右标点之后字符码为 32 的活动字符（`\verb`、`\verb*`、
    `\obeyspaces` 下的空格）也被删掉：`\verb|中。 a|` 由 30.5pt 变为 25.25pt。v3.10.6 与 `f8f3f731` 都正确。
  - R6-M1（小）：CHANGELOG 为 `CheckFullRight` 新增的条目写的是内部实现（“删去空格时记下这一点”），
    而它所修的问题只存在于未发布的中间提交，用户看不到。
- R6 补充报告还确认 R5-M4 没有完全解决：R4 那项变异（peek 遇到空格时改为置 `punct`）在 R5 后使 4 项
  失败，R5 记录把它归因于新增的 `CheckFullRight` 用例；实测 4 项全在 TEST 10，TEST 12 一项都没有失败。

### 协调者在 R6 修复过程中发现

- 这一项不是审查报出的。修 B1 时逐版本二分，顺带发现嵌套线型命令的内层正文里全角标点之后紧接西文字符
  （`\uline{\sout{中。z}} 后`、`\uline{\sout{中“z}} 后`、`\CJKunderline{\CJKsout{中。z}}x`）时，外层命令后的
  空格或间距按 CJK 处理，与直接输入和 v3.10.6 不一致。逐提交二分：`2fb2a93b`、`7a817059`、`d16c0aaa`、
  `275c04d9`、`8d1d9a34`、`19774cc7`、`fcfe3b79`、`35bf0adc` 都失败，v3.10.6 与 `ef49ca4e` 正确，即从
  `2fb2a93b` 起就存在。
- 原因：全角标点到 Default 的转换不向 capture 报告类别。单层装饰与普通文字里，西文字符之后另有 marker
  或 ulem 片段说明末类别；嵌套内层整段装在 `\UL@onin` 的盒子里，capture 只看到标点之前的汉字。以前 ulem
  结束符 `*` 被当成西文字符，恰好盖住了这个缺口，`2fb2a93b` 不再观察 `*` 后缺口就露出来了。与第一轮的
  根因相同：`*` 曾替多条路径“报告”过类别，去掉它之后每条依赖它的路径都要补上自己的报告。

### 修法要点

- B1：`\xeCJK_check_FullRight_symbol:Nw` 改用 `\peek_meaning_remove:NTF \c_space_token`，与被替换的
  `\peek_remove_spaces:n` 一样按含义比较，只删显式或隐式的空格记号。xeCJKfntef 的
  `\@@_ulem_punct_peek_space:` 同样改为按含义比较；那一处在测试里没有判别力，属一致性修改。
- M1：删去 `CheckFullRight` 那条 `\changes`，把“打开 `CheckFullRight` 时同样如此”并入右边界那条 `\changes`。
- 嵌套内层：新增 `\@@_ulem_onin_report_default:`，在 `\@@_ulem_FullLeft_and_Default:` 与
  `\@@_ulem_FullRight_and_Default:` 的非 patch 分支（原生转换之后）于 `\l_@@_ulem_onin_bool` 为真时执行
  `\@@_boundary_capture_class:n { default }`；并为它新增一条 `\changes`。（R7 更正：这一修法只修好了直接写在
  嵌套内层、标点后紧接西文的三种写法；`\mbox` 里的变体和“标点后再接标点与汉字”在 R7 才修好，而且这一修法
  本身引入了 R7-B1、R7-I1 两处回退，R7 已删去该函数，见下文 R7 一节。）
- R5-M4：`build-and-test.md` 与本文 R5 一节改为“现使 4 项失败，全在 TEST 10”，删去错误归因。
- TEST 12 的标签全部加 `cfr-` 前缀，避免与 TEST 10 的同名用例（如 `trailing-space-cjk`、
  `inner-spaces-cjk`）混淆；同名时只看 PASS／FAIL 行分不清失败项出自哪个 TEST。

### What Went Wrong（R6）

1. **替换 l3 peek 函数时没有核对比较方式。** R5 需要“删去空格并知道是否删过”，就把
   `\peek_remove_spaces:n` 换成 `\peek_charcode_remove:NTF`，只看了“能不能删”，没看它按字符码比较、原函数
   按含义比较。l3 的 peek 函数按 charcode、catcode、meaning 三种方式成组提供，换函数时比较方式也要一并对上。
2. **测试没有覆盖“看起来像空格、其实不是空格记号”的输入。** 活动字符、`\verb` 里的空格从未进入矩阵，
   所以 R5 的改动在全绿的测试下引入了回退。
3. **同根因回退从第一轮修复一直潜伏到 R5。** 前几轮的比对都以直接输入为 oracle，只在单层装饰上测过“标点接西文”；嵌套
   内层的同类写法没有和 v3.10.6 比对过，直到 R6 修复中逐版本二分才顺带发现。
4. **失败数的归因没有逐项核对。** R5 按“新增了 `CheckFullRight` 用例”解释失败数增加，没有逐项核对失败行
   来自哪个 TEST；TEST 10 与 TEST 12 当时有同名用例，只看 PASS／FAIL 行也分不清出处。

### Root Cause（R6）

- 代码层：R5 选用的 peek 函数比较方式与被替换的函数不同；全角标点到 Default 的原生转换从不报告类别，
  嵌套内层过去依赖 `*` 的误报。
- 过程层：替换实现时只核对了功能，没有核对等价性；每轮只沿审查报出的维度扩展比对，没有定期把嵌套、
  盒子、选项等维度与发布版整体比一遍；测试标签没有按 TEST 区分。

### 验证

- `fntef-entry-space01` 新增 5 项：TEST 10 增加 `nested-period-latin-letter-cjk`、
  `nested-left-quote-latin-letter-cjk`、`nested-period-latin-letter-latin`；TEST 12 增加 `cfr-active-space`
  （用 ``\lccode`\~=32`` 构造的活动字符 `~`，定义为 `z`，`中。~a` 与 `中。za` 比较）与关闭选项后的
  `cfr-off-active-space`。全文件 116 项 PASS。新增项在 `35bf0adc` 上有 4 项失败（3 项嵌套与
  `cfr-active-space`）。
- 逐项变异 2 项全部被捕获：`\xeCJK_check_FullRight_symbol:Nw` 改回按字符码比较（1 项失败）；去掉 onin
  补报 `default`（3 项失败）。这 3 项只覆盖直接写在嵌套内层、标点后紧接西文的写法，不足以支持“嵌套内层
  已修好”的结论（R7 更正）。

### 仍未覆盖（修复前后都不一致）

- 正文以全角标点开头、紧接西文：`\href{x}{。z} 后`、`\textcolor{red}{。z} 后`、`\uline{。z} 后`，普通 stream
  与 ulem 都有；`\uline{。z} 后` 在 v3.10.6 差 6.66pt，现在差 3.33pt。`\href{x}{中。z} 后` 在 v3.10.6 与现在
  都差 3.33pt。它们属于 `doc-gaps.md` 已登记的“非 ulem 路径的 Boundary→FullLeft／FullRight 不向 capture
  报告类别”一类，已补进该节。

### Promotion Candidates（R6）

- **lessons-learned（补充「换掉某段代码的实现方式时，回放它当初为之而生的那个场景」）**：替换 l3 peek
  函数时确认比较方式与被替换的函数一致；活动字符、`\verb` 这类“看起来是空格”的记号是必测维度。
- **lessons-learned（补充「判断修复是否到位需要三个对照点」）**：每轮修复后都把嵌套、盒子、选项等维度
  与发布版横向比对一次，不只比对直接输入。
- **reference（`build-and-test.md`）**：TEST 12 的标签以 `cfr-` 开头；R4 那项变异的失败项全在 TEST 10
  （已由 recorder 完成）。
- **仅留在 memory**：逐提交二分的提交清单与 R6 的审查项编号。

## 本地增量审查 R7 后的补修

### 审查发现

- 对 R6 补修（范围 `35bf0adc..a8a0c05a`）的本地增量盲审（R7，run `20260927T155152Z-r7-incr`）报告阻塞问题
  1 项、重要建议 2 项、小问题 2 项。
  - R7-B1（阻塞）：R6 的 `\@@_ulem_onin_report_default:` 只在“全角标点→Default”补报 `default`，随后的
    “全角标点→CJK”不补报。`中\uline{\sout{中（A）中}}吗`、`中 \CJKunderline{\CJKsout{中（A）中}} 吗`、
    `中\CJKunderline{\CJKsout{中（A）中}}x`、`中\uline{\sout{中“z”中}}x`、`中\uline{\sout{中。z，中}}吗`
    相对 `35bf0adc` 回退，结果与 v3.10.6 相同（都不对）：补报的 `default` 留在末类别里，后面的汉字没有改写它。
  - R7-I1（重要）：补报调用的是 `\@@_boundary_capture_class:n`。首类别为空时它会设首类别并触发
    `\@@_boundary_capture_emit_left:nn`，在 `他说\CJKunderline{\CJKsout{“OK”}}吗` 的内层盒子里、“ 与 OK
    之间插入 3.33pt glue。
  - R7-I2（重要）：嵌套内层用 `\mbox` 包住“标点＋西文”（`符 \uline{\sout{\mbox{中。z}}} 后` 等）仍相对
    v3.10.6 回退。`\UL@hrest` 在 `\mbox` 开头清掉 onin 布尔，补报不执行。llmdoc 写“已在 R6 修好”把修复范围
    说大了。与协调者此前记下的 C6-X1 合并跟踪。
  - R7-M1（小）：R6 新增的 CHANGELOG／`\changes` 描述的问题只存在于未发布的中间提交。
  - R7-M2（小）：lvt 文件头称各 TEST 的标签互不相同，实际 `space`、`quad`、`sout`、`no-space` 仍重名。
- R7 同时确认 R6-B1、R6-M1、R5-M4 已修复；C6-X1 列出的写法已修好，`\mbox` 变体未修。

### 修法要点

- 删去 `\@@_ulem_onin_report_default:`，新增 `\@@_ulem_report_last:n {<类别>}`：capture 活跃且未暂停
  （暂停深度为 0）时，只对 `kind` 为 `stream-ulem` 的各层写 `last=<类别>`、`tail=char`；不设首类别、不触发
  `emit_left`，所以不会在内层盒子里插入 glue（R7-I1）。
- 五个全角标点转换的非 ulem 分支（`\xeCJK_if_ulem_patch:TF` 为假：嵌套内层与 `\mbox` 等盒子里）都调用它：
  `FullLeft_and_Default`、`FullRight_and_Default` 报 `default`；`FullLeft_and_CJK`、`FullRight_and_CJK`、
  `FullRight_and_CJStarter` 报 `CJK`（R7-B1）。不再依赖 onin 布尔，`\mbox` 里也生效（R7-I2）。
- 只写 `stream-ulem` 层：`\mbox` 等盒子的 capture 层在盒子结束时读取末尾 marker 决定末类别；若也写这一层，
  `中 \uline{\sout{\mbox{中（A）}中}} 吗` 把盒子末类别当成西文，多出一枚西文间距（70.83pt，oracle 67.5pt，
  `35bf0adc` 正确）。
- CHANGELOG 与 `\changes` 改为用户可见的描述：相对 v3.10.6，嵌套内层全角标点之后还有汉字或西文时，外层
  命令右侧按正文实际的最后一个字符决定间距。v3.10.6 对这些写法本来就错，所以这是用户可见变化（R7-M1）。
- 重名标签改名：TEST 4 `sout`→`empty-sout`，TEST 6 `space`→`fullleft-space`、`no-space`→`fullleft-no-space`，
  TEST 9 `quad`→`tail-quad`（R7-M2）。

### What Went Wrong（R7）

1. **补报借用了带副作用的通用入口。** R6 需要的只是“末类别改为 default”，却调用了
   `\@@_boundary_capture_class:n`。这个函数同时承担“第一个报告点设首类别、补左边界 glue”的职责，
   在盒子内部调用时这枚 glue 落进盒子。
2. **只修了触发复现的那一种转换。** R6 从“标点＋西文”的三个样例出发，只在两个 Default 转换里补报；
   同一根因（全角标点转换不报告类别）下还有三个转换通向 CJK，标点后再接汉字时末类别停在补报的 `default`
   上，反而把 `35bf0adc` 碰巧正确的写法改坏。
3. **补报条件比根因窄。** onin 布尔表达的是“直接在嵌套链上”，而 capture 看不到后续 marker 的情形还包括
   `\mbox` 等盒子；`\UL@hrest` 清掉布尔后补报不执行。
4. **把局部修复记成“已修好”。** R6 的 llmdoc、doc-gaps 与本文都写“已在 R6 修好”，依据只是 3 项用例；
   没有测盒子路径与“标点后再接字符”的变体就下了结论。

### Root Cause（R7）

- 代码层：五个全角标点转换在非 ulem 分支里都不向 capture 报告类别；R6 只补了其中两个，并且复用了会设首类别
  的函数、以 onin 布尔为条件。
- 过程层：修回退时从复现样例出发而不是从根因出发列举转换；声称修好前没有把 `35bf0adc`、v3.10.6 与直接输入
  三方在盒子、后接汉字／西文等维度上逐项比对。

### 验证

- `fntef-entry-space01`：TEST 10 新增 15 项宽度用例（R7-B1 五项、`\mbox` 变体、`\sbox`、外层先有 `\hspace`、
  `CJLineBreak=strict` 两项等）；新增 TEST 11 节点用例 `nested-leftquote-latin`，原 TEST 11–13 顺延为 12–14。
  全文件 131 项 PASS、0 FAIL。在 `a8a0c05a` 的 `.sty` 上新用例有 13 项失败，节点用例也不同（多出 3.33pt glue）。
- 逐项变异 9 项全部被捕获：去掉 FullLeft→Default 的补报 1 项失败，FullLeft→CJK 2 项，FullRight→Default 5 项，
  FullRight→CJK 6 项，FullRight→CJStarter 2 项（strict）；不写 `tail=char` 1 项（`nested-content-then-comma-cjk`）；
  不限 `stream-ulem` 1 项（`nested-mbox-paren-latin-then-cjk`）；不检查暂停深度 1 项（`nested-sbox-inside`）；
  改为设首类别，宽度 1 项失败且节点用例不同。

### 仍未覆盖（R7 前后与 `35bf0adc` 相同，v3.10.6 也不对）

- 嵌套内层正文以全角标点开头时首类别为空：`他说\CJKunderline{\CJKsout{“OK”}}吗`（59.71pt，oracle 65.56pt）、
  `他说\uline{\sout{（A）}}吗`（51.16／57.5）、`中\CJKunderline{\CJKsout{《A》中}}吗`（52.05／57.5）、
  `符\uline{\sout{。z}}后`（34.44／37.77）。
- 外层先有内容、内层以全角左标点开头：`中 \uline{中\hspace{1em}\sout{（A）中}} 吗`，R7 后 71.16pt，`35bf0adc`
  与 v3.10.6 为 74.49pt，oracle 77.5pt，都不对；数值变化来自 FullLeft→Default 现在补报 `default`，属同一缺口。
- `\href{x}{中。z} 后` 等普通 stream 的既有缺口不变。以上已登记在 `doc-gaps.md`。

### Promotion Candidates（R7）

- **lessons-learned（新条目）**：向状态机补报信息时只写需要的字段，不借用会同时做别的事（设首类别、补 glue）
  的通用入口；先列出该入口的全部副作用，再判断在新调用点（这里是盒子内部）哪些是错的。
- **lessons-learned（补充「确认根因后要枚举全部满足该根因的代码路径」）**：修回退时把同根因的所有转换一起列出，
  逐项比对 `35bf0adc`（上一次正确的提交）、v3.10.6 与直接输入；补报条件要与根因同宽，不能用更窄的状态布尔代替。
- **architecture／doc-gaps／build-and-test**：`\@@_ulem_report_last:n` 的规则、R6 修复范围的更正、TEST 编号与
  变异结果（已由 recorder 完成）。
- **仅留在 memory**：R7 的审查项编号、run 名与 C6-X1 的合并关系。

## 本地增量审查 R8 后的补修

### 审查发现

- 对 R7 补修（范围 `a8a0c05a..b59d2525`）的本地增量盲审（R8，run `20260927T163704Z-r8-incr`）报告阻塞问题
  0 项、重要建议 1 项、小问题 3 项。
  - R8-I1（重要）：嵌套线型命令的内层正文由 `\UL@onin` 整段排进一个盒子，不经过 `\UL@reskip`／`\UL@stop`，
    内层最后一个字符之后的 `\hspace*`、`\quad`、`\rule` 等内容不会把 `tail` 改成 `content`。R7 的
    `\@@_ulem_report_last:n` 在标点之后写 `last=CJK`、`tail=char`，使 `中 \uline{\sout{中（A）中\hspace*{1em}}} 吗`
    （77.5pt，直接输入 80.83pt）等五种写法相对 `a8a0c05a` 与 v3.10.6 回退。没有标点的
    `中 \uline{\sout{中\hspace*{1em}}} 吗`（40.0pt 对 43.33pt）从 `2fb2a93b` 起就与 v3.10.6 不一致（v3.10.6 碰巧对，
    因为结束符 `*` 被当作西文字符），llmdoc 没有记录；doc-gaps 里“这些写法现在都与直接输入一致”说大了。
  - R8-M1（小）：`build-and-test.md` 仍写“R1–R6 后仍为 124／124 通过”。
  - R8-M2（小）：lvt 注释与 `build-and-test.md` 称节点列表“只输出第一层”“以 `\showboxdepth=1` 输出第一层节点”；
    实际 `\loggingoutput`（`regression-test.tex`）把 `\showboxdepth`／`\showboxbreadth` 设为 `\maxdimen`，`.tlg`
    记录完整深度，TEST 11 正依赖这一点（检查内层盒子里的 “ 与 OK）。
  - R8-M3（小）：dtx 注释说 `\@@_ulem_report_last:n` 只写“自己的”层，实际写栈中全部 `stream-ulem` 层（包括隔着
    `\mbox` 的外层）；llmdoc 的“各层”说法是对的。
- 范围外观察（不计数，v3.10.6 已有，未修）：`\mbox`／`\fbox` 里的线型命令左边界本来就错，以前与右侧的错误抵消，
  R7 补好右侧后 `中\mbox{\uline{\sout{中（A）中}}}x` 总宽度为 69.44pt 对 66.11pt；`符\uline{\mbox{“OK”中}}后` 装饰内容
  整段消失（v3.9.1 正常）；另有五种盒子、颜色与并列嵌套的写法在所有版本都不对。已登记在 `doc-gaps.md`。

### 修法要点

- 新增 `\@@_ulem_onin_tail_check:`，在 `\UL@onin` 包装里内层正文 `#1 \s_@@_ulem_body \@@_boundary_math_end:n {#1}`
  之后、盒子关闭之前调用。只在嵌套链上（onin 布尔为真）且有 ulem 入口层时工作；入口层 `tail` 已是 `punct` 时不检查；
  否则末节点是 glue 就置 `content`（内层盒子里的显式 glue 没被 `\UL@reskip` 移出，这是与 `\@@_ulem_tail_check:`
  唯一的区别），其余按 `\@@_ulem_tail_check:` 的规则判断。最后若末节点是 `ulem-nest` marker 就删去（R8-I1）。
- `\@@_ulem_nest_mark:` 的非 patch 分支（嵌套链上的中间层）在末节点是盒子时也补 `ulem-nest` marker，让中间层的
  检查把最内层命令排出的盒子当作字符；marker 由检查删去，不留在中间层盒子里。（R9-M2 更正：只有末节点正是这个
  marker 时才删去；后面还有别的内容时，零宽 marker 留在中间层盒子里。）
- dtx 注释改为“栈中所有 `stream-ulem` 层，也就是所有外层线型命令（包括隔着 `\mbox` 的外层）”（R8-M3），tail 机制
  说明里新增内层正文末尾检查一段。
- lvt 删去无效的 `\showboxbreadth=100`、`\showboxdepth=1`，`\EntryNodes` 注释改为完整深度（R8-M2）；
  `build-and-test.md` 的通过数写到 R8（R8-M1）。
- 不新增 CHANGELOG 条目：新增用例中在 v3.10.6 失败的五项都来自结束符 `*` 被当作西文，已由现有条目覆盖，其余在
  v3.10.6 就正确，R8 修的是未发布中间提交里的回退。（R9 审查更正两处：R9-M3，五项中只有四项来自 `*`，
  `inner-latin-fill` 失败是因为“最后一个字符之后还有内容时右侧仍补边界间距”，属于 CHANGELOG 已有的“最后一个字符
  之后还有空白、盒子、规则等内容”一条；R9-M5，“其余在 v3.10.6 就正确”没有逐项比对，R8 也改变了“内层以西文加
  末尾空格结尾”的发布版行为，`中\uline{\sout{x }}中` 由 35.27pt 变为 31.94pt（等于直接输入），
  `符 \uline{\sout{中（}}x` 的结果也变了，两项当时都没有测试固定。）

### What Went Wrong（R8）

1. **新补报的状态暴露了原来被掩盖的缺口。** 内层正文不经过片段盒子的两个拦截点，内层最后一个字符之后的
   glue、盒子从来不会把 `tail` 置为 `content`。以前 `*` 被当作西文，末类别恰好是 default，错误的 `tail` 看不出来；`2fb2a93b` 去掉 `*` 之后，没有
   标点的写法已经出错但无人发现，R7 在标点之后写 `tail=char`，才把有标点的写法也带坏。
2. **“最后一个字符之后还有内容”这个维度只在单层测过。** TEST 9 原有的 36 项都是单层，或“嵌套命令之后再接内容”，
   没有“嵌套内层正文里最后一个字符之后还有内容”。R7 的矩阵按标点转换展开，也没有与末尾内容组合。
3. **测试注释写的是意图，不是 `.tlg` 里的事实。** lvt 在 `\loggingoutput` 之前设 `\showboxdepth=1`，被覆盖；注释
   与 llmdoc 照意图写成“只输出第一层”，而 R7 新增的 TEST 11 实际依赖完整深度。
4. **缺口清单里的肯定句没有注明维度。** doc-gaps 写“现在都与直接输入一致”，依据只是以字符结尾的写法。

### Root Cause（R8）

- 代码层：`tail` 的 `content` 判断只挂在 `\UL@reskip`、`\UL@stop` 和片段盒子末尾检查上，嵌套内层盒子没有对应的检查点。
- 过程层：补报一个字段（末类别）时，没有检查与之配对的字段（`tail`）在同一路径上是否也缺失；测试注释与文档对
  日志深度的说法没有对照 `.tlg`。

### 验证

- `fntef-entry-space01`：TEST 9 新增 25 项宽度用例（内层末尾接 glue、盒子、kern、penalty、special，标点之后再接
  汉字与末尾内容，`\CJKunderline{\CJKsout{…}}`、`\uwave` 变体，三层嵌套，内层以颜色或 `\mbox` 结尾），TEST 11 新增
  节点用例 `three-level-no-marker`；全文件 156 项 PASS、0 FAIL。在 `b59d2525` 上新用例有 21 项失败；`ef49ca4e` 与
  v3.10.6 上只有与 `*` 有关的五项失败（R9-M3 更正：其中 `inner-latin-fill` 与 `*` 无关，见上文修法要点末条）。
- 逐项变异 6 项全部被捕获：不调用检查 21 项失败；glue 不置 `content` 15 项；`punct` 时也检查 3 项；中间层不补
  marker 2 项；不删 marker 时宽度全过，但 `three-level-no-marker` 的节点列表多出 marker kern；不检查 onin 布尔 1 项。
- R8 后重跑，xeCJK 124／124、ctex `l3build check -e xetex` 全部通过。

### 仍未覆盖（所有版本都不对，或 v3.10.6 碰巧一致）

- `符 \uline{\sout{\xout{中}x}} 后`（38.61pt 对 41.94pt，v3.9.1 正确；R9 已修好）、`符 \uline{\sout{\hspace*{1em}}} 后`（36.66 对
  33.33）、嵌套版 issue 写法 `普通字符 \uline{\sout{\hspace*{0.5em}xxxx\hspace*{0.5em}}} 后续`（97.78 对 94.45，
  v3.9.1 两者都是 97.78）、`符 \uline{\sout{中$x$ }} 后`。
- `符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后`（30.0 对 33.33）从 `2fb2a93b` 起与直接输入不同，
  `ef49ca4e` 与 v3.10.6 碰巧一致；单层 `符 \uline{中\relax} 后` 等在 v3.10.6 也差 3.33pt，属同一既有差异。
- 以上与范围外观察都已登记在 `doc-gaps.md`。

### Promotion Candidates（R8）

- **lessons-learned（新条目）**：补上一处缺失的状态后，要检查与它配对、原来被错误值掩盖的其他状态在同一路径上
  是否也缺失，并把“修好一侧、另一侧的错误随之显现”作为回归比对的一项。
- **lessons-learned（补充「引入会改全局状态的测试原语前先读它的定义」）**：同一个 `\loggingoutput` 覆盖顺序问题在
  #1091 再次出现；这次完整深度正是 TEST 11 需要的，错的只是注释与文档的说法。测试注释要以 `.tlg` 实际内容为准。
- **architecture／build-and-test／doc-gaps**：`\@@_ulem_onin_tail_check:` 与中间层 marker 规则、TEST 9／11 的新增用例
  与变异结果、doc-gaps 肯定句的更正与新增未覆盖清单（已由 recorder 完成）。
- **仅留在 memory**：R8 的审查项编号与 run 名。

## 本地增量审查 R9 后的补修

### 审查发现

- 对 R8 补修（范围 `b59d2525..cf9a1744`）的本地增量盲审（R9，run `20260927T172127Z-r9-incr`）报告阻塞问题 0 项、
  重要建议 2 项、小问题 5 项。历史补充：R8-I1、R8-M1、R8-M2、R8-M3 已修复（R8-I1 的修法引入的回退另记为 R9-I1），
  没有发现消失的早先问题。
  - R9-I1（重要，本范围引入）：R8 的 `\@@_ulem_onin_tail_check:` 把内层盒子末尾全角左标点之后 xeCJK 自己排出的
    `\penalty10000 \glue0pt` 当成正文内容，`符 \uline{\sout{中（}} 后` 为 43.33pt（直接输入与 `b59d2525` 都是
    40.0pt）；`\CJKunderline{\CJKsout{中《}}`、三层嵌套、`\uwave{中“}` 同样如此。
  - R9-I2（重要，`2fb2a93b` 引入）：嵌套线型命令的内容与相邻字符之间的 `\CJKecglue` 丢失，
    `符 \uline{\sout{\xout{x}中}} 后` 为 38.61pt 对 41.94pt。`ef49ca4e` 与 v3.10.6 正确，但 v3.10.6 是碰巧：结束符 `*`
    多出的间距抵消了缺少的间距。两层写法 `符 \uline{\xout{x}中} 后`、`符 \uline{中\xout{x}中} 后` 在 v3.10.6 上也不对，
    v3.9.1 正确。
  - R9-M1：dtx 与 architecture 仍写“中间层不补 marker”（R8 起中间层也补）。
  - R9-M2：“marker 检查后删去、不留在中间层盒子里”说得过满：只有末节点正是它时才删；后面还有内容时零宽 marker
    留在中间层盒子里。
  - R9-M3：R8 记述里 `inner-latin-fill`（`中\uline{\sout{x\hspace*{1em}}}中`）在 `ef49ca4e`／v3.10.6 上失败的原因
    不是结束符 `*`，而是“最后一个字符之后还有内容时右侧仍补边界间距”（CHANGELOG 已有条目覆盖）。
  - R9-M4：R8 使 TEST 1 的 `nested`（`符 \uline{\CJKsout{\usebox{\FillBox}}} 后`）基线新增一行 `\kern 0.0`（内层以
    盒子结尾按 `content` 处理，stream end 排零宽 kern），宽度不变，文档没有记。
  - R9-M5：`中\uline{\sout{x }}中`（`b59d2525` 与 v3.10.6 为 35.27pt，R8 后 31.94pt，等于直接输入）与
    `符 \uline{\sout{中（}}x` 的变化没有测试固定；R8 反思说“其余在 v3.10.6 就正确”不对。
- 范围外观察（登记到 doc-gaps）：`符 \uline{\sout{\xout{中} 中}} 后`（43.33 对 40.0）中间层里嵌套命令与汉字之间的
  空格没有按 CJK 规则删去，所有版本都不对，仍未修。审查时列出的 `符 \uline{\sout{中（}} x` 在 R9 修复后已正确。

### 修法要点

- **全角左标点结尾（R9-I1）。** `\@@_ulem_FullLeft_and_Boundary:` 的 ulem 分支把 `\tex_ignorespaces:D` 换成
  `\@@_ulem_left_punct_peek:`，非 ulem 分支在嵌套链上也调用它。下一个记号是扫描标记 `\s_@@_ulem_body` 时置 `punct`
  （并复位 `\g_@@_FullRight_space_bool`），命令后的空格被吃掉；否则置新值 `left`，空格照常吃掉。`left` 之后再报告
  字符类别改回 `char`；`\UL@reskip` 画零宽显式 glue 时由 `\@@_ulem_tail_left_content:` 改为 `content`；结束时
  `\@@_ulem_tail_punct_end:` 把 `left` 换成 `content`，`\@@_ulem_end:` 在外层重放标点 marker 与
  `\penalty10000 \glue0pt`，与直接输入 `中（\relax{} 后` 一致。内层盒子里末节点是 glue 时由新函数
  `\@@_ulem_onin_tail_glue:` 判断：`tail` 为 `left`、glue 前是 `\penalty10000`、再前面不是 glue，就认作标点自己排出
  的一对节点，不置 `content`。
- **嵌套命令与相邻字符的连接（R9-I2）。** 右侧：`\@@_ulem_nest_mark:` 补的 marker 由 `\@@_ulem_nest_node:` 选择，
  `tail` 为 `char` 且末类别是 CJK 或 default 时用这个类别的 marker，外层后面的字符按普通类别转换补 `\CJKecglue`，
  否则仍用 `ulem-nest`；`\l_@@_ulem_nest_node_tl` 记下用了哪一种，`\@@_ulem_onin_tail_check:` 只在末节点正是它时由
  `\@@_ulem_nest_node_remove:` 删去，删去后末节点若不是盒子就放回（说明挡住的是前面字符自己的 marker）。左侧：
  `\UL@onin` 进入前读当前列表末尾的 CJK／default marker（`\l_@@_ulem_onin_lead_tl`），在内层正文开头重放。
- dtx 注释改正“中间层不补 marker”（R9-M1）与“删去”的说法（R9-M2），新增全角左标点结尾与左右连接的说明；
  build-and-test 更正 R8 变异记述的归因（R9-M3）并补记基线变化（R9-M4）。
- **新增 CHANGELOG 条目**：“线型命令的正文以全角左标点结尾时，命令后的空格与直接输入一样在汉字前删去，西文前也
  不再多补间距；嵌套线型命令的内容与它前后相邻的汉字或西文之间，与直接输入一样补上间距（#1091）。”这是相对
  v3.10.6 的用户可见变化：TEST 15 有 27 项在 v3.10.6 上失败。

### What Went Wrong（R9）

1. **把一类节点一律当成“内容”之前，没有列出 xeCJK 自己会在同一位置排出的节点。** R8 规定内层盒子末尾的 glue
   都算正文内容，理由是内层盒子里的显式 glue 没有被 `\UL@reskip` 移出；但全角左标点在 Boundary 前也排出
   `\penalty10000 \glue0pt`，它不是用户写的内容。R8 的矩阵只按“最后一个字符之后接什么”展开，没有包含“以全角左
   标点结尾”这一行。
2. **只修了一侧的连接。** R2 起用 `ulem-nest` marker 识别嵌套装饰，只关心“外层能否认出这是字符”，没有检查外层
   后面的字符能否与它按类别转换补间距；左侧（内层第一个字符能否看到外层前一个字符的 marker）也从未检查。三层写法在 v3.10.6 上碰巧正确，两层写法在 v3.10.6 上本来就错、没有被当作回退报出，两侧的缺口因此一直没有显出来。
3. **R8 的反思说“其余在 v3.10.6 就正确”，没有逐项比对。** 写这句话时只核对了失败的五项，没有把新增用例以外、
   但被本次修改影响的写法（内层以西文加末尾空格结尾、以全角左标点结尾后接西文）与发布版比对；五项的归因也有一项
   写错。
4. **盒子两侧的错误可能抵消。** `符 x\mbox{\uline{\sout{中}}} 后` 起初被当成相对发布版的回退；节点比对才看出
   v3.10.6 上左侧同样缺少 `\CJKecglue`，只是 `\mbox` 后面多补了一枚西文间距，两处抵消。总宽度一致不能说明两侧都对。

### Root Cause（R9）

- 代码层：`tail` 的 `content` 判断按节点类型下结论，没有区分用户内容与标点转换自己排出的节点；嵌套装饰排出的
  盒子两侧都没有参与普通的类别转换。
- 过程层：设计判定规则时从“用户可能写什么”出发，没有从“这个位置上可能出现哪些节点、分别由谁排出”出发；
  修一侧的连接时没有同时检查另一侧；回归比对只针对失败项，没有覆盖被修改影响的全部写法。

### 验证

- `fntef-entry-space01`：新增 TEST 15（45 项宽度用例：单层与嵌套的全角左标点结尾，后接汉字、西文、空格、
  `\relax`、`\hspace{0pt}`、`\nobreak\hspace{0pt}`、`\hspace*`、`\kern`、内层末尾空格、两个左标点、
  `CheckFullRight`；`中\uline{\sout{x }}中`；嵌套命令的左右连接，含两层、三层、并列、`\mbox` 内与 `\relax` 之后），
  TEST 11 新增节点用例 `three-level-keep-char-marker`；全文件 201 项 PASS、0 FAIL。在 `cf9a1744` 上 32 项失败
  （新节点用例的输出也不同），在 `b59d2525` 上 35 项失败，在 v3.10.6 上 TEST 15 有 27 项失败。
- 逐项变异 14 项，全部被本文件捕获：ulem 分支不 peek 9 项；嵌套链不 peek 10 项；非扫描标记不置 `left` 3 项；空格
  不置 `left` 1 项；`\UL@reskip` 零宽 glue 不改 `content` 1 项；结束时不处理 `left` 3 项；不重放标点节点 3 项；
  glue 一律 `content` 2 项；不看 penalty 之前 1 项；nest marker 一律用 `ulem-nest` 11 项；只重放 CJK 不重放
  default 4 项；不复位 `\g_@@_FullRight_space_bool` 1 项；删除时固定按 `ulem-nest` 查找与删除后不检查盒子，宽度全过
  但节点列表不同（前者由 `three-level-no-marker`、后者由 `three-level-keep-char-marker` 捕获）。
- R9 后重跑：xeCJK 124／124、ctex `l3build check -e xetex` 186／186、`l3build doc` 成功。

### 仍未覆盖（R9 修复后）

- 分组里的全角左标点 `符 \uline{{中（}} 后`（43.33 对 40.0，所有版本都不对，v3.9.1 更差）。
- `符 \uline{\sout{\xout{中} 中}} 后`（43.33 对 40.0）。
- 三层并列的连接：`符 \uline{\sout{\xout{x}}\sout{中}} 后` 等三种（38.61 对 41.94，v3.10.6 对其中一种）。
- 公式后接嵌套命令 `符 \uline{$x$\sout{中}} 后`。
- `符 x\mbox{\uline{\sout{中}}} 后`：`2fb2a93b` 起 38.61 对 41.94。不是相对发布版的回退：v3.10.6 上总宽度碰巧一致，
  节点层面两侧都不对（左侧缺 `\CJKecglue`，`\mbox` 后多一枚西文间距）；单层 `符 x\mbox{\uline{中}} 后` 在 v3.10.6
  上就是 38.61 对 41.94。现在右侧已经正确，左侧仍缺间距，与 R8 范围外观察“盒子里的线型命令左边界本来就错”属于
  同一既有缺口。
- 既有的 `\uline{\sout{中 }}`、`\uline{\sout{中\relax}}` 嵌套版（`2fb2a93b` 起），以及 R7 记下的首类别为空的写法。
- 以上都已登记在 `doc-gaps.md`。

### Promotion Candidates（R9）

- **lessons-learned（新条目）**：把某类节点一律当成“用户内容”之前，先列出 xeCJK 自己会在同一位置排出的节点
  （标点转换的 penalty 与 glue、marker、像素补偿 glue 等），逐个决定归属。
- **lessons-learned（补充「补上一处缺失的状态后……」）**：修一侧的连接时同时检查另一侧；盒子两侧的错误可能相互
  抵消，发布版总宽度一致时也要比对节点。
- **lessons-learned（补充「三个对照点」）**：写“其余在发布版就正确”之前，要把被修改影响的写法逐项与发布版比对，
  不只核对失败项。
- **architecture／build-and-test／doc-gaps**：全角左标点结尾与嵌套命令左右连接的机制、TEST 11／15 与变异结果、
  R9-M1 至 R9-M5 的更正、未覆盖清单（已由 recorder 完成）。
- **仅留在 memory**：R9 的审查项编号与 run 名。

## 本地增量审查 R10 后的补修

### 审查发现

- 对 R9 补修（范围 `cf9a1744..43fe6df9`）的本地增量盲审（R10，run `20260927T190226Z-r10-incr`）报告阻塞问题 0 项、
  重要建议 2 项、小问题 4 项。历史补充：R9-I1 至 R9-M5 七项都已修复（R9-I1 的修法判断过宽另记为 R10-I1；R9-I2 左侧
  重放的副作用另记为 R10-I2、R10-M4），没有发现消失的早先问题。
  - R10-I1（重要，本范围引入）：R9 的 `\@@_ulem_onin_tail_glue:` 只看“glue 前是 `\penalty10000`、再前面不是 glue”。
    全角左标点之后若先有盒子、kern、规则、special、`\label`，再有用户写的 `~` 或 `\nobreak\hspace`，用户的这对节点
    被误认成标点自己的，`符 \uline{\sout{中（\mbox{}~}} 后` 为 43.33pt，直接输入 46.66pt（`cf9a1744` 与 v3.10.6 正确）。
  - R10-I2（重要，本范围引入）：`\UL@onin` 在内层开头重放 CJK marker 后，内层正文开头的空格被按 CJK 规则删去，
    `\uline{中\sout{ 中}}` 为 20.0pt，直接输入 23.33pt（审查基线、v3.10.6、v3.9.1 都正确）。
  - R10-M1：CHANGELOG、`\changes` 与 lvt 注释把“分组结束”也算进全角左标点结尾已处理的情况，实际
    `\uline{{中（}} 后`、`\uline{\textbf{中（}} 后` 仍差 3.33pt（审查基线相同）。
  - R10-M2：“重放的 marker 在类别转换时被取走，不留在盒子里”说得过满：正文为空或以规则、盒子开头时 marker 留在
    内层盒子里。
  - R10-M3：左侧重放只加在 `\UL@onin` 的非重排分支，内层以公式加空格结尾时仍缺间距。
  - R10-M4：左侧补出的 `\CJKecglue` 排在内层盒子里，会被内层装饰画上、不能在此断行，与右侧不对称，文档没有说明。
- 范围外观察（都与审查基线相同，登记到 doc-gaps）：`CJKspace=true` 时 `符 \uline{（}x`（28.61 对 25.28，审查基线与
  v3.10.6 为 31.94，差距已缩小）；两层 `\uline{\sout{中} 中}` 等四种写法（23.33 对 20.0，v3.10.x 都如此，此前只登记了
  三层版本）；`\uline{中{ 中}}`（20.0 对 23.33，v3.9.1 正确）。

### 修法要点

- **用本包自己的 marker 认出标点的节点（R10-I1）。** 新增 `\@@_ulem_left_punct_mark:`：嵌套链上的全角左标点刚排出
  `\penalty10000 \glue0pt` 时，取下这两个节点，在 penalty 之前补一个 `ulem-left` marker，再放回。
  `\@@_ulem_onin_tail_glue:` 只在 penalty 之前正是这个 marker 时才认作标点自己的节点，否则置 `content`。
- **内层正文以空格开头时不重放（R10-I2）。** 左侧读取拆为 `\@@_ulem_onin_lead_get:n` 与 `\@@_ulem_onin_lead_put:`；
  `\@@_ulem_onin_if_lead_space:n` 判断内层正文是否以空格记号、控制空格 `\ ` 或分组里的空格开头，是则不记录 marker。
  （R11 删去了这个判断，见下文 R11 一节。）
- **重排分支同样重放（R10-M3）。** `\@@_ulem_onin_lead_get:n` 移到重排判断之前，重排分支把
  `\@@_ulem_onin_lead_put:` 作为前缀传给 `\@@_boundary_ulem_math_tail_space:nnn`。
- **说法更正（R10-M1、R10-M2、R10-M4）。** CHANGELOG 与 `\changes` 改为“正文以全角左标点结尾、标点不在正文内的分组
  里时……”；lvt 注释删去“分组结束”并注明分组情形尚未处理；dtx 补写分组情形的原因（直接输入 `{中（} 后` 里标点处的
  `\ignorespaces` 在分组结束处停下，分组之后的空格仍被边界处理删去），把 marker 的去向改为“正文第一个字符的类别转换
  会取走它；正文为空，或第一个字符之前先排出了规则、盒子、glue、kern 等节点时，零宽 marker 留在内层盒子里”
  （R11-M1 补上 glue、kern 开头的情形），并写明左侧补出的 `\CJKecglue` 位于内层盒子里、
  会被内层装饰画上、不能断行，与命令左边界原有机制（`x\uline{\sout{中}}`）的位置相同。

### What Went Wrong（R10）

1. **用排除法认“本包自己排出的节点”。** R9 为了区分 `中（\nobreak\hspace{0pt}`，规定“penalty 再前面不是 glue”
   就算标点的节点。这条规则只排除了测过的那一种用户写法；标点和用户的 `~` 之间只要隔着一个非 glue 节点（盒子、
   kern、规则、special、`\label`），用户的节点就被认成标点的。R9 的矩阵里，标点之后的用户内容都紧接标点（`\nobreak\hspace{0pt}`、`\hspace*`、`\kern`），
   没有在标点与用户的 `~` 之间插入其他节点。
2. **补 marker 时只看了它对后面字符的影响，没有看对后面空格的影响。** R9 在内层开头重放 CJK marker，是为了让内层
   第一个字符补上 `\CJKecglue`；但 marker 也决定了紧随其后的源码空格按什么规则处理，内层以空格开头时这枚空格被按
   CJK 规则删去。R9 的左侧用例全部是“外层字符后直接接内层字符”，没有包含内层以空格开头的写法。
3. **只改了一个分支。** `\UL@onin` 有重排与非重排两个分支，R9 只在非重排分支加了重放；#1026 已经记下重排分支
   是“条件更窄的同类路径”，这次又漏了一次。
4. **写 CHANGELOG 时把“下一个记号不是扫描标记”的所有情况当成同一类。** `left` 覆盖了 `\relax`、`\hspace` 和分组
   结束，但分组结束时直接输入的结果不同（分组之后的空格仍被删去），R9 没有为分组情形单独比对，就写进了用户可见的
   说明。

### Root Cause（R10）

- 代码层：标点节点的识别依赖节点类型的排除，而不是本包自己放下的标记；左侧重放没有考虑 marker 对后续空格处理
  的作用；重放只接在一个分支上。
- 过程层：判定规则按“已知的反例”收窄，而不是按“这个节点是谁排出的”来确认；新增 marker 时只列出了想要的效果，
  没有列出这个 marker 在后续转换中还会影响哪些判断；写用户可见说明时没有把其中列举的每种情形都与直接输入比对。

### 验证

- `fntef-entry-space01`：TEST 15 新增 13 项（以 git diff 核对；标点之后先有盒子、kern、规则、special 再有 `~` 或
  `\nobreak\hspace` 的四项与三层一项、`nested-left-tie`，内层以空格、`\ `、分组里的空格开头的五项，内层以公式加空格
  结尾的两项），全文件 214 项 PASS、0 FAIL；新增的 13 项在 `43fe6df9` 上有 12 项失败（`nested-left-tie` 通过），新 lvt 在 `cf9a1744` 上共 36 项失败。
- 逐项变异在 R9 的 14 项之外新增：不检查开头空格 5 项；不识别分组内开头空格 1 项；不识别 `\ ` 1 项；重排分支不重放
  2 项；不插 `ulem-left` marker 2 项；glue 前任意节点都认作标点 7 项，全部被捕获；R9 的 14 项仍全部被捕获。
- 约 500 项合并矩阵：相对 `43fe6df9`、`cf9a1744`、`b59d2525` 无回退。R10 时这里还写“相对 v3.10.6 仍是三项既有
  差异”，这只是该矩阵上的结果；R11 盲审用 4104 项矩阵找到 135 项相对 v3.10.6 的差异（R11-I3，见下文 R11 一节）。
- R10 后重跑：xeCJK 124／124、ctex `l3build check -e xetex` 186／186、`l3build doc` 成功。

### 仍未覆盖（R10 修复后）

- 分组里的全角左标点（`符 \uline{{中（}} 后`、`符 \uline{\textbf{中（}} 后`，原因已分析，未修）。
- `符 \CJKunderline{\CJKsout{中$a$ }} 后`：公式加尾随空格后接空格，所有版本都差 3.33pt，属既有“公式加尾随空格”一类。
- 上面的范围外观察，以及 R9 修复后仍未覆盖的各项。
- 以上都已登记在 `doc-gaps.md`。

### Promotion Candidates（R10）

- **lessons-learned（补充「把一类节点一律当成“用户内容”之前……」）**：识别本包自己排出的节点，要用本包自己在
  那里放下的标记，而不是用“前面不是某类节点”这类排除法；排除法只挡住测过的反例。
- **lessons-learned（补充「补上一处缺失的状态后……」）**：在一侧补 marker 时，要检查它对紧随其后的空格处理的影响，
  测试矩阵要包含“补 marker 的位置后面紧接空格”的写法；改动 `\UL@onin` 这类有多个分支的入口时逐个分支确认。
- **architecture／build-and-test／doc-gaps**：`ulem-left` marker、左侧空格例外、重排分支、左侧间距的位置与断行、
  TEST 15 新增项与变异、未覆盖清单（已由 recorder 完成）。
- **仅留在 memory**：R10 的审查项编号与 run 名。

## 本地增量审查 R11 后的补修

### 审查发现

- 对 R10 补修（范围 `43fe6df9..bb321f36`）的本地增量盲审（R11，run `20260927T194907Z-r11-incr`）报告阻塞问题 0 项、
  重要建议 3 项、小问题 2 项；历史补充确认 R10-I1、R10-M1、R10-M3、R10-M4 已修复，R10-I2、R10-M2 并入 R11 跟踪。
  - R11-I1：R10 按记号形式判断内层开头是否为空格，漏掉 `\space` 与多层分组，`\uline{中\sout{\space 中}}`、
    `\uline{中\sout{{{ 中}}}}` 为 20.0pt，直接输入 23.33pt（`cf9a1744`、v3.10.6、v3.9.1 都正确）；`CJKspace=true` 时
    `\uline{中\sout{\textbf{ 中}}}` 的空格按进入命令时的字体排出。
  - R11-I2：`xCJKecglue=true` 时直接输入 `中{ 中}` 本身删去这枚空格，R10 不重放后反而与直接输入不一致（`43fe6df9` 一致）。
  - R11-I3：llmdoc 三处写“相对 v3.10.6 只剩三项差异”“约 500 项合并矩阵没有新差异”；盲审的 4104 项矩阵找到 135 项，
    其中 68 项自 R9 起出现，另 67 项更早。
  - R11-M1：“marker 留在内层盒子里”的说法漏列 glue、kern 开头；R11-M2：dtx 一段注释断行不规则。

### 修法要点

- **总是重放，空格交给类别转换（R11-I1、R11-I2）。** `\@@_ulem_onin_lead_put:` 总是重放外层 marker；入口层缓存的
  `xecglue_flag` 不是 `true` 时清除 `\g_@@_glue_check_pending_bool`，空格按普通空格保留，否则由后面字符的类别转换换成
  `\CJKecglue`。内层盒子里 `\xeCJK_space_glue:` 改为按当前字体排出。
- **左边界钩子。** 修好右侧以后，外层左边界补在内层开头的 `~`、`\hspace`、`\kern` 等内容之后这一处多出的间距显露出来
  （以前两侧一多一少，恰好抵消）。核心新增 `\@@_boundary_emit_left_hook:n`，xeCJKfntef 在嵌套链上、入口为 `armed`
  且没有源码空格、内层盒子末节点是 glue、kern、penalty、规则、vlist 或 special 时把入口改为 `resolved`。
- **说法更正（R11-I3、R11-M1、R11-M2）。** 差异结论改为限定在所用矩阵（647 项 r9big）的说法；marker 的去向改为
  “正文为空，或第一个字符之前先排出了规则、盒子、glue、kern 等节点时”；注释重新断行。

### What Went Wrong（R11）

1. **按记号形式猜测排版结果。** 空格可以写成空格记号、`\ `、`\space`、任意层分组，也可以藏在 `\textbf{ 中}` 里；
   逐一列举形式总会漏掉一种。R10 还把“直接输入会保留这枚空格”当成不随选项变化的事实，没有在 `xCJKecglue=true`
   下比对。改为让 marker 照常起作用、由类别转换按选项处理后，所有写法走同一条路径。
2. **一侧修好后另一侧的错误显露出来。** R9 补上右侧间距时没有同时检查左侧；左侧多补的一枚间距以前被右侧少的一枚
   抵消，直到 R11 盲审的矩阵才发现。
3. **变异测不出的分支。** 原型里“末节点是重放 marker 时不改 `entry`”的例外，变异后没有任何用例失败。插桩确认这个
   分支在所有用例里从不触发，于是删去，而不是为它硬造测试。教训是变异测不出时，先插桩看分支是否可达，再决定删去
   还是补测试。
4. **把某个矩阵的结论写成全称结论。** “只剩三项差异”只在 R10 的约 500 项矩阵上成立，文档没有写明矩阵与规模。

### Root Cause（R11）

- 代码层：在排版之前按源码形状推断排版结果，而不是看类别转换时的实际状态。
- 过程层：差异结论没有标明所用矩阵；变异测不出时没有先区分“测试缺判别力”与“分支不可达”。

### 验证

- `fntef-entry-space01`：TEST 15 新增 21 项，全文件 235 项 PASS、0 FAIL；新增项在 `a4e94c5d` 上 16 项失败。
- 逐项变异 23 项（R11 提交说明误写为 22 项）（`tmp/i1091/fix2/mutate14.py`）全部使本文件失败，`nest-remove-fixed`、`nest-no-box-check` 由节点列表捕获。
- 647 项 r9big 矩阵：相对 `a4e94c5d` 33 项由不一致变为一致、无回退；相对 r9base、r8base 无回退；当前代码与直接输入
  不一致而 v3.10.6 一致的 4 项见 `doc-gaps.md`。这一结论只对 r9big 矩阵成立，没有在 4104 项矩阵上逐项复核。
- xeCJK `l3build check`、`l3build doc`、ctex `l3build check -e xetex` 全部通过。

### 仍未覆盖（R11 修复后）

- 嵌套内层以未注册的盒子开头（原始 `\hbox`、`\rule`、`\phantom`、`\raisebox`）时多补一枚左边界间距，自 `2fb2a93b`
  起就存在；钩子只凭节点无法把它与透明的 `\mbox{}` 区分。已登记在 `doc-gaps.md`，附探测文件与可能的补法。

### Promotion Candidates（R11）

- **lessons-learned（新条目）**：差异结论要写明所用矩阵与规模。
- **lessons-learned（补充「源码语法只产生候选，实际输出决定语义」）**：不要按记号形式推断空格等排版结果。
- **仅留在 memory**：变异测不出时先插桩确认分支是否可达，再决定删去还是补测试（与「症状不显现不等于路径不可测」
  互为反向，暂不单列）；R11 的审查项编号与 run 名。

## 本地增量审查 R12 后的补修

### 审查发现

- 对 R11 补修（范围 `bb321f36..94bd84d5`）的本地增量盲审（R12，run `20260927T212204Z-r12-incr`）报告阻塞问题 0 项、
  重要建议 2 项、小问题 5 项；历史补充确认 R11-I1、R11-I2、R11-M1、R11-M2、R10-M2 已修复，R11-I3、R10-I2 仍 open。
  - R12-I1：左边界钩子把颜色 whatsit 当作正文先排出的内容，`x\uline{\sout{\textcolor{red}{中}}}x` 为 23.89pt，
    直接输入 27.22pt，相对 R10 的代码回退，部分写法相对 v3.10.6 也回退。
  - R12-I2：`\sbox` 里入口层号为 0，重放 marker 后没有清除 pending，`\sbox\SB{\uline{中\sout{ 中}}}` 为 20.0pt，
    直接输入与 v3.10.6 都是 23.33pt。
  - R12-M1：`\uline{{中}\sout{ 中}}` 与直接输入 `{中}{ 中}` 不一致；R12-M2：重排分支不设 onin 布尔量，钩子不起作用；
    R12-M3：钩子的 penalty、规则、vlist 分支没有测试；R12-M4：dtx 列出的节点类型与代码不一致；
    R12-M5：`CJKspace=true` 下 `\mbox` 里词间空格宽度的变化没有写进 CHANGELOG。

### 修法要点

- **颜色 whatsit（R12-I1）。** 核心在 transparent 命令前后新增两个默认为空的钩子；xeCJKfntef 用前者先检查此前排出的
  内容，用后者在颜色 whatsit 之后放 `ulem-transparent` marker，第一个字符出现时删去 marker、不改入口。
- **`xCJKecglue` 另存（R12-I2）。** `\xeCJK_hook_for_ulem:` 在改写选项之前存入 `\l_@@_ulem_xecglue_bool`，
  `\@@_ulem_onin_lead_put:` 不再读 capture 层。
- **其余。** 重排分支设置 onin 布尔量（M2）；左侧重放加上 `CJK-space`，顺带修好盲审范围外观察中的两类写法；
  `{中}` 前缀保持 v3.10.6 的结果并在 dtx 写明（M1）；补测试、改注释、补 CHANGELOG（M3–M5）。

### What Went Wrong（R12）

1. **把一类节点一律当作内容时，漏了核心对这类节点的既有约定。** R11 的钩子把所有 whatsit 都当作内容，但核心早已把
   颜色命令注册为 transparent，直接输入时它们对边界透明。这与 R8、R10 的教训同型，只是这次“本包自己的约定”在核心，
   不在 xeCJKfntef。
2. **依赖 capture 层号的状态在 capture 暂停时失效。** R11 按入口层的 `xecglue_flag` 决定是否清除 pending，`\sbox`
   等暂停 capture 的环境里层号为 0，这一步不执行。
3. **测试没有进入被改的分支。** R11 的测试用例都带入口空格，lvt 里唯一的颜色用例也带入口空格，按设计不进入钩子的
   末节点检查；vlist、规则、penalty 三个分支逐项删去后本文件仍全过。
4. **oracle 本身受前一用例影响。** 在用例里现场排的 `\sbox{中{ 中}}` 会读到前一个写法留下的源码空格检查状态，宽度随
   用例顺序变化；矩阵 r12m 的 `i2-sp` 因此显示为变差，单独运行时一致。

### Root Cause（R12）

- 代码层：新判据没有与核心已有的节点分类（transparent）对齐；用 capture 层号间接表示“进入命令时的选项”。
- 过程层：新增分支没有各自让它生效的用例；比对结果不一致时没有先单独运行，确认 oracle 未受状态影响。

### 验证

- `fntef-entry-space01`：TEST 15 新增 25 项宽度用例、TEST 11 新增节点列表用例 `nested-color-no-marker`，全文件
  260 项 PASS、0 FAIL；新增项在 `94bd84d5` 上 14 项失败。
- 逐项变异 35 项全部使本文件失败，三项由节点列表捕获。原型中 transparent begin 钩子对重放的 lead marker 的例外，
  变异测不出，插桩确认不可达后删去。
- 探测矩阵 r9big 646、r12box2 56、r12m 202、r12u 180、r12t 260、r12v 84、r12oos 7 项，相对 `94bd84d5` 没有回退；
  当前代码与直接输入不一致而 v3.10.6 一致的写法见 `doc-gaps.md`，结论只对这些矩阵成立。
- xeCJK `l3build check`、`l3build doc`、ctex `l3build check -e xetex` 全部通过。

### 仍未覆盖（R12 修复后）

- `符 \uline{\sout{ x}中} 后`（自 `5b271e96`）、外层以分组或公式结束后接嵌套命令、单层 `\fbox{}`／`\mbox{\hspace{1em}}`
  开头（自 `2fb2a93b`）、`{中}` 前缀、`\sbox` 里的状态泄漏（核心既有），都登记在 `doc-gaps.md`。

### Promotion Candidates（R12）

- **lessons-learned（已补充到「每项测试用独立的盒子／寄存器」）**：宽度 oracle 若用 `\sbox`，先确认它不受前一用例状态
  影响；比对不一致时先单独运行。
- **仅留在 memory**（已有条目覆盖，这次只是实例）：新增的每个分支至少有一项让它生效的用例（「分支级改动需要分支级断言」）；
  把一类节点当作内容前先查核心已有的分类，如 transparent（「把一类节点一律当成“用户内容”之前……」）；原型里变异测不出的
  例外，插桩确认不可达后删去（R11 已记）；用 capture 层号间接表示进入命令时的选项，在 capture 暂停时失效；R12 的审查项
  编号与 run 名。

## 本地增量审查 R13 后的补修

### 审查发现

- 对 R12 补修（范围 `94bd84d5..101a5adc`）的本地增量盲审（R13，run `20260927T230900Z-r13-incr`）报告阻塞问题 0 项、
  重要建议 1 项、小问题 2 项；历史补充确认 R12-I1～R12-M5 已修复或按原建议关闭，R10-I2 可关闭，R11-I3 与 R13-I1 合并跟踪。
  - R13-I1：“入口之后排出过透明命令”的布尔量在每层内层正文开头清零，外层正文里的颜色也不设置它；颜色与后面的 `~`
    不在同一层时入口空格少一枚，`符 \uline{\color{red}\sout{~中}} 后` 为 33.33pt，直接输入与 v3.10.6 为 36.66pt。
  - R13-M1：end 钩子每次放一个 `ulem-transparent` marker，第一个字符出现时只删一个，连续颜色、颜色后接更深一层装饰、
    正文只有颜色时 marker 留在盒子里，与文档写的“不留在盒子里”不符。R13-M2：lvt 注释“现存”用词不当。

### 修法要点

- 布尔量改由 `\@@_ulem_entry_arm:` 清零；end 钩子在入口为 `armed` 时总是设置它，只在嵌套链上放 marker。
- begin 钩子先删去上一个 marker；新增 `\@@_ulem_transparent_node_remove:`，在 `\@@_ulem_onin_lead_get:n` 读外层末尾之前、
  `\@@_ulem_onin_tail_check:` 末尾调用。

### What Went Wrong（R13）

1. **状态量的生命周期与它服务的状态不一致。** R12 把“是否排出过透明命令”做成按内层正文清零的状态，而它服务的入口状态
   `armed` 属于整条嵌套链。R12 的用例都把颜色与 `~` 写在同一层，跨层写法没有测试。
2. **文档写的不变量没有测试。** marker 每次放一个、只删一个；“不留在盒子里”只由单个颜色的节点用例覆盖，多次出现与
   没有字符的情形都没测。marker 宽度为零，宽度用例看不出来。

### Root Cause（R13）

- 代码层：新增状态量时没有写明它跟随哪一层的生命周期；marker 的放下与删除不成对。
- 过程层：测试只覆盖“同一层里”的写法；不变量只对最简单的一种出现方式做了断言。

### 验证

- `fntef-entry-space01`：TEST 15 新增 5 项宽度用例、TEST 11 新增 3 项节点列表用例，全文件 265 项 PASS、0 FAIL；
  新增项在 `101a5adc` 上 5 项宽度失败、3 项节点列表留有 marker。
- 逐项变异 40 项全部被发现，其中六项由节点列表发现。探测矩阵含新增的 r13m（80 项）、r13rest（7 项），相对 `101a5adc`
  没有回退。xeCJK `l3build check`、`l3build doc`、ctex `l3build check -e xetex` 全部通过。

### 仍未覆盖（R13 修复后）

- 外层正文里 `\special` 之后接嵌套命令、前一个兄弟装饰只有 `~`（都自 `2fb2a93b`），以及 R13 盲审的范围外观察，都登记在
  `doc-gaps.md`。

### Promotion Candidates（R13）

- **仅留在 memory**（已有条目覆盖，这次只是实例）：新增状态量要写明它跟随哪一层的生命周期，并测试跨层写法（R4 的
  “给状态标志加作用域时要把‘进入’‘新盒子清除’‘再次进入’组合起来测”）；文档里“不留在盒子里”这类不变量要有节点列表用例，覆盖
  多次出现与没有字符的情形（「声称测试保护某性质时，要用只破坏该性质的变异确认测试会失败」）。

## 本地增量审查 R14 后的说法修正

- 对 R13 补修（范围 `101a5adc..cb84336b`）的本地增量盲审（R14，run `20260927T234528Z-r14-incr`）报告阻塞 0、重要 0、
  小问题 1：R13 把“`ulem-transparent` marker 不留在盒子里”写成普遍性质，但颜色之后、第一个字符之前先排出 `~`、
  `\hspace`、`\special` 等内容时，marker 被压在这些节点之下，三处删除都只看末节点，它留在颜色命令所在的那一层内层盒子里。宽度为零，
  不影响排版。R13 修 marker 残留时只补了“多次出现”“没有字符”两类节点用例，没有补“被其他内容压住”这一类。
- 处理：不改代码，改正 dtx、lvt 注释与 architecture、build-and-test、index 的说法，写成与 `ulem-nest` marker 相同的
  “仍在列表末尾时删去，被压住时留下”；TEST 11 增节点用例 `nested-color-hspace-keeps-marker` 固定留下的行为。
- 教训：写“某节点不会留下”这类性质前，先列出放下它之后可能接的所有节点类别，逐类用节点列表确认；R9-M2、R10-M2、R11-M1、
  R14-M1 同一类说法已经四次过满（R14-M1 所指的说法是 R13 的补修写下的）。

## R16 前：与 v3.10.6 比对的回退修复

### 起因与修法

- R15 之后，协调者把 `tmp/i1091/fix2/` 下的探测矩阵同时在当前代码与 v3.10.6 上运行，逐项找“当前与直接输入不一致而
  v3.10.6 一致”的写法，而不是只和上一提交比。找到的几类（单层以 `\fbox{}`、`\mbox{\hspace{1em}}` 开头，外层正文先排出
  原始盒子、`\nobreak`、`\special` 或只有 `~` 的兄弟装饰再接嵌套命令，外层正文以公式结束后接嵌套命令，`\mbox` 里的线型
  命令）连同同一原因、v3.10.6 本来就不对的写法，一起由 `a8b45cf4` 修好。
- 修法要点：核心新增 `\@@_boundary_transparent_box_hook:`，让透明盒子后面也有 `ulem-transparent` marker；
  `\@@_ulem_level_check:` 等检查不再限于嵌套链；`\@@_ulem_if_last_content:` 把 hlist 算作内容；`\@@_ulem_raw_box_check:n`
  处理第一个字符在原始盒子里的情形；`\UL@stop` 排出 penalty 后解除入口；`\UL@onin` 前末尾是公式时重放 math marker；
  `\UL@setULdepth` 测量期间暂停 capture。机制见 architecture 的「正文先排出盒子、penalty、公式」一条。

### 经验

1. **同时比对 HEAD 与 v3.10.6，才能区分回退与“两处错误抵消”。** 只和上一提交比，只能看出本轮有没有改坏；和发布版比，
   才能看出哪些写法是这个分支引入的差异。但发布版一致不等于发布版正确：`符 \uline{\sout{ x}中} 后`、
   `符 \uline{\sout{中 }} 后` 与 sym 矩阵的 `前 \uline{\sout{\hbox{a}中}} 后` 在 v3.10.6 上等宽，都是碰巧：前一例与第三例是一侧多补、
   另一侧少补，第二例是结束符 `*` 被当作西文字符。判断是否回退前，要把两侧拆开各测一次（去掉命令前或命令后的空格），再看节点。
2. **消融实验确认每处改动都有必要。** 原型通过后，逐项撤回其中一处改动（`tmp/i1091/fix2/abl1.txt`、`abl2.txt` 的 a01–a20），
   同时跑 lvt 与全部矩阵。多数撤回在当时的 lvt 上全过、只在矩阵上失败，说明 lvt 对这些分支没有判别力；据此把矩阵里能区分
   的写法补进 TEST 16／17，最终 69 项变异全部被发现。撤回后仍然全过的改动，要么删去，要么补出能让它生效的用例。
3. **隐藏的测量盒子也会污染 capture。** ulem 的 `\UL@setULdepth` 在一个原始 `\hbox` 里排出 `(j` 量深度，这个盒子不进入
   输出，但 `(` 触发的 interchar 转换照样报告类别，外层 capture 把它记为首类别。R9 曾把 `x\mbox{\uline{中}}` 的缺口推断为
   “盒子里读不到外层 marker”，没有实测，方向错了。排查首类别来源时，要把宏包内部为测量而排的盒子也列进去；这类盒子
   与 `\UL@end` 的定界符一样，应在排出期间暂停 capture。
4. **“与直接输入等宽”与“填空线对称”冲突时，以维护者的决定为准。** 修复过程中试过让嵌套内层按直接输入删去入口空格，
   `符 \uline{\sout{ x}中} 后` 因此与直接输入等宽，但嵌套的 issue 填空线 `普通字符 \uline{\sout{\hspace*{0.5em}xxxx\hspace*{0.5em}}} 后续`
   变成 94.45pt，`~` 写法为 97.78pt，两侧不再对称，已撤回。两个判据都合理时，不能由代理自己挑一个；应列出两种结果，
   交维护者决定，并在 dtx、doc-gaps 与测试 oracle 里写明采用哪一个。本例的决定是保留入口空格，TEST 16 的 `-tie` 用例
   以 `~` 写法为 oracle。
5. **marker 残留的节点列表用例要覆盖所有结束路径。** 宽度用例看不出零宽 marker。这次加 marker 放置点后，残留出现在三条
   宽度用例碰不到的路径上：片段盒子以 penalty 结尾（`\UL@stop` 要先取下 penalty 再删 marker）、正文只有颜色或只有
   `\fbox{}`、前一个兄弟装饰只有颜色（内层盒子关闭前的 `\reset@color` 会再放一个）。TEST 17 的 9 项节点列表逐一覆盖；
   消融记录里有两项撤回（`\UL@stop` 不删 marker、不因 penalty 解除入口）在当时的 lvt 上全过；后一项有 4 项矩阵宽度用例
   失败，前一项所有矩阵都没有发现，只有节点列表能发现。

### 验证

- `fntef-entry-space01`：TEST 16 新增 41 项宽度用例、TEST 17 新增 9 项节点列表、TEST 2 新增一项节点列表，全文件 315 项
  PASS；新增宽度用例在上一提交 `25a466af` 上 24 项失败。逐项变异 69 项全部被发现（13 项由节点列表）。
- 14 个矩阵（rg、r9big、r12box2、r12m、r12u、r12t、r12v、r12oos、r13m、r13rest、r15mid、r15exp、r16math、sym，共 3293 项）
  相对 `25a466af` 没有回退。相对 v3.10.6 仍不同的写法列在 doc-gaps 的「与 v3.10.6 比对后的回退修复」一条。

### 仍未覆盖（`a8b45cf4` 后）

- 相对 v3.10.6 有差异、仍未修：`符 \uline{\sout{中 }} 后`、`符 \uline{\sout{中\relax}} 后`（30.0pt 对 33.33pt），
  `x\uline{{中}\sout{$a$中}}x`（49.17pt 对 45.84pt）；按维护者决定不改的单层／嵌套入口空格差异。
- v3.10.6 同样不对：单层正文以零宽内容开头、前面是西文（`x\uline{\hbox{}中}x`、`x\uline{\special{x}中}x`，27.22pt 对
  23.89pt）。`a8b45cf4` 的 CHANGELOG 条目曾把原始 `\hbox`、`\special` 写成已处理，对这几种单层写法说得过宽，随后的提交已改正；写 CHANGELOG 时应按探测矩阵逐类核对“单层／嵌套”两种结构，不要从嵌套结构的结果推出单层也成立。

### Promotion Candidates（R16 前）

- **lessons-learned 候选**：判断“是否回退”时，比对基准要同时包括上一提交与发布版；发布版一致的写法也要拆开两侧确认不是
  错误抵消（第 1 条）。宏包为测量而排、不进入输出的盒子也会触发 interchar 转换，排查类别来源时要列入（第 3 条）。
- **仅留在 memory**（已有条目覆盖，这次只是实例）：消融确认每处改动有判别力（「声称测试保护某性质时，要用只破坏该性质的
  变异确认测试会失败」）；marker 残留要用节点列表覆盖各结束路径（R13、R14 的同类教训）；两个合理判据冲突时交维护者决定。

## R16：透明盒子与正文里的盒子

### 起因与修法

- 本地独立审查 R16（对 `a8b45cf4` 与其后更正提交）指出三类问题，都与 `a8b45cf4` 新加的“透明盒子”分类和不限嵌套链的检查有关：
  透明盒子之后以全角左标点开头时多一枚 `\CJKecglue`（`x\uline{\fbox{}（中）}x` 为 50.69pt，直接输入 47.36pt，相对 v3.10.6 与
  `8e557076` 回退；没有盒子的 `x\uline{（中）}x` 自分支早期起就多这一枚）；透明盒子之前已有 `\kern`、`\hbox{}`、`\special`、
  `\rule` 或正文以语法空格开头时，看到 marker 仍清除入口（`x\uline{\kern1pt\fbox{}中}x`、`x\uline{ \fbox{}中}x`）；
  `\@@_ulem_level_check:` 不看 capture 层号，正文里 `\fbox`、`\mbox` 内部的内容也会解除外层入口（`x\uline{\fbox{\sout{中}}}x`
  为 30.69pt，直接输入 34.02pt）。另有注释与更改记录的措辞问题。
- `c254f535` 的修法：核心新增 `\@@_boundary_transparent_box_begin_hook:`，与颜色命令的 begin 钩子共用
  `\@@_ulem_transparent_begin:n`；`\@@_ulem_transparent_clear:n` 在 `\g_@@_ulem_lead_skip` 非零时也不清除入口；
  `\l_@@_ulem_fullleft_bool` 与 `\@@_ulem_fullleft_check:n` 处理“西文后接全角左标点”；`\@@_ulem_if_outside_box:nT`
  让正文里另起的盒子内部既不检查也不放 marker。机制见 architecture「正文先排出盒子、penalty、公式」下的「`c254f535` 的补修」。

### 经验

1. **把一种盒子加入“透明”分类时，要同时检查它之前与之后。** `a8b45cf4` 只在透明盒子之后放 marker，没有像颜色命令那样
   在排出之前检查此前已排出的内容，于是 `\kern1pt\fbox{}` 里的 `\kern` 被 marker 掩盖。盒子之后也不只有汉字与西文：全角左标点
   在 ulem 分支里被报告成 `CJK`，“西文后接汉字”的 `\CJKecglue` 就补了出来。新增一种透明对象时，应列出它前面可能已有的内容
   （kern、原始盒子、special、规则、开头语法空格）和后面首字符的各种类型（汉字、西文、全角左标点、左引号），与已有的颜色命令
   逐项对称地比对。
2. **放宽检查范围时，要限定它作用在哪一层列表上。** `a8b45cf4` 让 `\@@_ulem_level_check:` 不再只在嵌套链上工作，却没有限定
   列表层级，正文里另起的 `\fbox`、`\mbox` 内部的 kern 也会解除外层入口。同一提交里 `\@@_ulem_raw_box_check:n` 有“当前层等于
   入口层”的限制，`\@@_ulem_level_check:` 没有；同类检查一个有层号限制、一个没有，就是应当复查的信号。
3. **变异里不可达的检查，要插桩确认后删去。** 原型在嵌套链上的左边界钩子里也加了 `\@@_ulem_if_outside_box:nT`，撤回它时
   全部用例仍通过。插桩在 r16x、rg、r9big 上确认这个分支在盒子里从不触发：`\UL@hrest` 在盒子开头清除 onin 布尔。确认
   不可达后删去它，而不是为保留它另造用例；判断依据写进 dtx 说明。
4. **“同宽不同位置”只有节点列表能区分。** `CJKglue` 是 0pt 可伸长的 glue，宽度用例看不出它在不在；入口空格排在片段盒子里
   还是外面、左边界 glue 排在正文里的盒子内还是外，总宽也一样。这次 83 项变异里有 17 项只由节点列表发现。另外，
   `x \uline` 与 `x\ \uline` 的入口状态不同。在 `\@@_ulem_fullleft_check:n` 插桩（`tmp/i1091/fix2/fc73-before.tex`）实测：
   `x \uline{（中}x` 到达检查时 `space_flag` 为 `false`、`before` 为空；`x\ \uline{（中}x` 是 `space_flag` 为 `true`、`before`
   为 `default`；只有 `x\uline{（中}x`（`space_flag` 为 `false`、`before` 为 `default`）解除入口。前两者都不解除入口，但走的是
   不同的条件。选测试写法前要实测入口状态，不能凭写法相近推定走同一条路径（`latin-ctrl-space-then-leftparen` 就是为此选的）。

### 验证

- `fntef-entry-space01`：TEST 16 新增 19 项宽度用例、TEST 17 新增 4 项节点列表，全文件 334 项 PASS；新增项在 `21ac8c10` 的
  代码上 17 项宽度失败、1 项节点列表留有 marker。逐项变异 83 项（`tmp/i1091/fix2/mutate17.py`，含两项核心变异）全部被发现，
  17 项只由节点列表发现。提交说明写 TEST 16 新增 20 项，按 lvt 与 `.tlg` 逐行核对是 19 项（315 + 19 = 334）。
- 15 个矩阵约 4900 项（新增 r16x 1632 项）相对 `21ac8c10` 只有 `前 \uline{\fbox{\sout{\mbox{}（中}}} 后` 与左引号版本两项由一致
  变为不一致；它们在 `8e557076` 与 v3.10.6 上同样不一致，`21ac8c10` 上的一致是碰巧。

### 仍未覆盖（`c254f535` 后）

- 见 doc-gaps「与 v3.10.6 比对后的回退修复」一条下的「`c254f535` 后新记下、仍未修的写法」：正文里的盒子让左边界 glue 排在
  盒子里（同宽不同位置）；`前 \uline{\mbox{\color{red}\kern1pt\color{blue}中}} 后` 的入口空格按 CJK 规则删去；核心既有的
  `x\mbox{\kern1pt\color{red}中}x` 两侧间距消失。`x \uline{（中）} x` 右侧的差异按既定设计，不算缺陷。

### Promotion Candidates（R16）

- **lessons-learned 候选**：新增“透明”对象时前后两侧都要与已有透明对象对称地检查（第 1 条）；放宽检查范围时限定列表层级，
  同类检查的限制条件不对称是复查信号（第 2 条）。
- **仅留在 memory**：不可达分支插桩确认后删去（与 R11 删去“末节点是重放 marker”例外的做法相同）；节点列表区分同宽不同位置
  （R1 以来的同类教训）。

## R17：全角左标点分支与原始盒子

### 起因与修法

- 本地独立审查 R17（对 `c254f535` 与其后的文档提交）指出：`c254f535` 在 `\@@_boundary_emit_left_hook:n` 里把全角左标点检查与
  原有的 marker 检查写成二选一，入口前是汉字时 `\@@_ulem_fullleft_check:n` 什么也不做，marker 仍在、入口仍为 `armed`，随后
  `\UL@stop` 把透明盒子当作内容解除入口，`中\uline{\fbox{}（中）}中` 的汉字与盒子之间丢掉 `\CJKglue`；`syntax-space-then-fbox-latin`
  （`中\uline{ \fbox{}x}中`）只在默认 `CJKecglue` 下碰巧与直接输入等宽；doc-gaps 对 `前 \uline{\fbox{\sout{\mbox{}（中}}} 后`
  只写“与 v3.10.6 同样不一致”，没有写出当前偏差更大（R17-M2）。R16 补充核对指出 R16-M5 只修好了注册盒子，正文里的原始
  `\hbox`、`\raisebox`、`\vbox` 内部仍留下 marker。范围外观察：`x\uline{\mbox{\color{red}\fbox{}}中}x` 丢掉 `\CJKecglue`。
- `d250e2a7` 的修法：钩子先做全角左标点检查，入口仍为 `armed` 时照常检查 marker；核心 `\@@_boundary_last_box_end:n` 不取回
  盒子的分支在本层没有观察到字符类别时也调用 `\@@_boundary_transparent_box_hook:`；`\@@_ulem_if_outside_box:nT` 在
  `\xeCJK_if_ulem_patch:TF` 与 `\l_@@_ulem_onin_bool` 都为假时也返回假；`\g_@@_ulem_transparent_tail_bool` 因此删去；删去
  `syntax-space-then-fbox-latin` 并写明语法空格一条只在入口前是西文时成立。机制见 architecture「正文先排出盒子、penalty、公式」
  下的「`d250e2a7` 的补修」。

### 经验

1. **给钩子加新的早退分支时，要确认原有分支里对共享状态的清理不会被跳过。** `c254f535` 的全角左标点分支只处理“入口前是西文”
   这一种情形，却用 `\bool_if:NTF` 把原有分支整个挡在外面；原有分支里删去 `ulem-transparent` marker、经
   `\@@_ulem_transparent_clear:n` 清除入口这两步，在新分支的其余情形里都没有执行。新分支只改变部分情形时，应写成“先做新检查，
   共享状态（这里是入口与 marker）没有变化时继续原有检查”，并对新分支不处理的每种情形确认原有清理仍然发生。
2. **宽度用例在默认 glue 下可能碰巧通过。** 默认 `\CJKglue` 的自然宽度为 0，丢掉它只少伸长量：`中\uline{\fbox{}（中）}中` 在默认
   选项下与直接输入等宽，`CJKglue={\hskip 1pt}` 时才看出差 1pt。默认 `\CJKecglue` 等于一个词间空格，“把空格画成装饰线”与
   “删去空格再补一枚 `\CJKecglue`”总宽相同：`syntax-space-then-fbox-latin` 在默认选项下通过，`CJKecglue={\hskip 0.5em}` 下不等。
   关键用例要用节点列表固定，或把 glue 设成可见、且不等于词间空格的宽度再比较。R16 经验 4 讲的是 0pt 可伸长 glue，本轮又一个
   实例，并扩展到“两种 glue 默认宽度相等”这一种碰巧。
3. **用状态条件取代专门的布尔量后，原来为特例设的布尔量成了冗余，变异测试能发现这一点。** 给 `\@@_ulem_if_outside_box:nT`
   加上“patch 与 onin 布尔都为假”之后，内层正文分组结束后经 `\aftergroup` 执行的 `\reset@color` 已落在这个条件里，
   `\g_@@_ulem_transparent_tail_bool` 要处理的情形不再出现。删去之前的变异结果（`tmp/i1091/fix2/mut18b.txt`）里，与它相关的
   `tbegin-no-tail`、`tend-no-tail`、`tail-no-bool` 三项都不再被发现。一组相关变异同时不被发现时，先检查它们保护的代码是否已被
   新代码覆盖；若是，应删去这段代码，而不是为保留它另造用例。删去后再用矩阵确认结果不变（11 个矩阵中留有 marker 的用例集合相同）。
4. **等价变异要写明为什么等价。** `fullleft-flag-stuck`（不复位 `\l_@@_ulem_fullleft_bool`）没有被发现，理由是这个布尔量只在
   `\@@_boundary_emit_left_hook:n` 里读取，而钩子只在入口为 `armed` 时起作用，第一次补左边界之后入口已不再是 `armed`。写出
   理由所依赖的不变量，以后这个不变量改变时（例如钩子在入口 resolved 之后也要工作），就知道这项变异需要重新检查。
5. **“各版本都不对”一类说法要列出实测过的版本。** 记录本轮缺口时，按 `tmp/i1091/fix2/r17rec.tex` 在六个版本上实测：
   `x\uline{\hspace{0pt}\fbox{}中}x` 在 `8e557076` 与 `25a466af` 上与直接输入一致，`a8b45cf4` 起才回到 v3.10.6 的值，不是“各版本
   都不对”（`b0e44c48` 进一步查明：没有盒子的 `x\uline{\hspace{0pt}中}x` 在 v3.10.6、`8e557076`、`d250e2a7` 上都不对，
   v3.9.1 上一致——当时写成“在所有版本上都不对”，同样犯了本条要避免的错误，R18-M2 指出；带 `\fbox` 的写法在
   `8e557076` 上一致只是被 `\UL@stop` 掩盖，已修好）；`中\uline{（中）}中` 在 `CJKglue={\hskip 1pt}` 下的 51.0pt 对 52.0pt 只在分支提交上成立，v3.10.6 为 59.99pt。
   提交说明里“17 项只由节点列表发现”按最后一次运行结果 `mut18c.txt` 核对是 16 项（R16 也有一次 20 项对 19 项）。数字与全称
   说法都要回到最后一次运行的原始结果核对。

### 验证

- `fntef-entry-space01`：TEST 16 删去一项、新增 `mbox-color-fbox-then-cjk`，TEST 17 新增节点用例 `cjk-then-fbox-leftparen`、
  `hbox-mbox-no-marker`、`hbox-color-no-marker`，全文件 334 项 PASS。逐项变异 82 项（`tmp/i1091/fix2/mutate18.py`，含三项核心
  变异）中 81 项被发现，16 项只由节点列表发现（提交说明写 17 项，见上面第 5 条），`fullleft-flag-stuck` 为等价变异。
- 提交说明记录：15 个探测矩阵在默认选项下相对 `c254f535` 没有变化；rg 与 r16x 在 `CJKglue={\hskip 1pt}`、
  `CJKecglue={\hskip 5pt}` 下相对 `21ac8c10` 只有已登记的两项 `\fbox{\sout{\mbox{}（中}}` 写法不同。

### 仍未覆盖（`d250e2a7` 后）

- 见 doc-gaps「与 v3.10.6 比对后的回退修复」一条下的「`d250e2a7` 后新记下、仍未修的写法」：入口前是汉字、正文以语法空格开头再接
  透明盒子；正文以语法空格开头的 `x\uline{ 中}x` 一类；嵌套内层正文以全角左标点开头时 marker 留在标点之前。当时这里还列着
  `x\uline{\hspace{0pt}\fbox{}中}x`（`a8b45cf4` 起的回退），已由 `b0e44c48` 修好。

### 可写入稳定文档的内容（R17）

- **lessons-learned 候选**：新增早退分支时确认原有分支的共享状态清理不被跳过（第 1 条）；宽度用例要避开“默认 glue 为 0 或
  两种 glue 默认等宽”造成的碰巧通过（第 2 条）；一组相关变异同时不被发现时先检查代码是否已冗余（第 3 条）。
- **仅留在 memory**：等价变异写明理由与所依赖的不变量（第 4 条）；数字与全称说法回到原始结果核对（第 5 条，R16 同类实例）。
- 已写入：architecture「`d250e2a7` 的补修」、doc-gaps、build-and-test 的 `fntef-entry-space01` 一节。

## R18：last 方式捕获的盒子、零宽 glue 的位置与正文里的公式

### 起因与修法

- 本地独立审查 R18（对 `d250e2a7`、`b0e44c48` 与 `1b72e7c9`）指出两项重要问题：
  - R18-I1：`d250e2a7` 让核心不取回盒子的分支调用盒子之后的钩子，却没有补上盒子之前的检查，`x\uline{\kern1pt\mbox{\color{red}}中}x`
    多补 `\CJKecglue`，嵌套写法相对 v3.10.6 回退。
  - R18-I2：`b0e44c48` 的 `hspace0-then-cjk-spaced` 只在默认 `\CJKglue` 下等宽，未画线的 `\CJKglue` 排在装饰中间，architecture 的说法与实际不符。
- 四项小问题：llmdoc 在 `b0e44c48` 后没有同步（R18-M1）；“在所有版本上都不对”与 v3.9.1 不符（R18-M2）；核心注释没写 last 分支（R18-M3）；
  lvt 注释断行（R18-M4）。
- 范围外观察里的 `x\uline{\color{red}$a$中}x`（29.18pt 对 32.51pt）相对 v3.10.6 不一致，协调者二分到 `2fb2a93b`，按回退一并修复。
- 修法：
  - 核心在 last 方式捕获的盒子开始时调用新的 `\@@_boundary_last_box_begin_hook:`，结束时只对包装方式的盒子调用 begin 钩子。
  - 入口有源码空格时零宽 glue 排成普通 glue。
  - `\@@_boundary_use_ulem_glue_outer:nn` 在片段盒子以公式结尾、入口因此解除、首类别是汉字时画一段 `\CJKecglue`；
    嵌套内层把公式节点算作内容。

### 经验

1. **“事后补调钩子”要确认钩子读到的状态和原来的调用点一样。** `d250e2a7` 在不取回盒子的分支里补调盒子之后的钩子时，
   没有问“盒子之前的检查在哪里做”。在那个分支里盒子已经留在列表里，事后调用 begin 钩子会读到盒子本身；原型 p47 把它挪到
   盒子开始时，又因结束时再调用一次，删掉 marker 之后把前一个 `\fbox` 当成内容（`fbox-then-fbox` 失败）。给一条路径补钩子时，
   要逐个写出钩子依赖的状态（这里是“列表末尾是盒子之前的内容”“marker 还在”），并确认每条路径上这些状态只被消费一次。（R19 补记：R18 的修法自己也没有做到这一点，开始时删去 marker 消耗了盒子里第一个字符的钩子还要读的状态，见 R19 第 1 条。）
2. **宽度相等不等于位置正确，默认 glue 下尤其如此。** R17 已把“默认 glue 为 0 时宽度用例可能碰巧通过”列为教训，`b0e44c48`
   仍新增了一项只看默认宽度的用例 `hspace0-then-cjk-spaced`，并在 architecture 里据此写出错误的结论。本轮 r19g 里
   `中\uline{\kern1pt\mbox{中}（中}中` 由通过变为失败，查节点列表才发现以前的“通过”是 `\CJKglue` 错排进 `\mbox` 里、
   恰好补足了另一处缺失。新增用例前先看一次节点列表，再决定用宽度还是节点列表固定；记录“某写法一致”时也要说明是在哪组
   glue 下比较的。
3. **一致变为不一致时，先分清是引入缺陷还是失去巧合。** `x\uline{\color{red}$a$中}x` 在 v3.10.6 上一致，只因入口按“西文到汉字”
   补的 `\CJKecglue` 恰好落在公式与汉字之间；命令前换成汉字（`中\uline{\kern1pt$a$中}中`）时各版本都不一致。判断回退时
   要把前后的字符类别都换一遍：只在一种上下文里一致的写法，多半是巧合。这类写法仍按回退处理并修好，因为用户看到的是
   宽度变了。
4. **在 `\UL@stop` 前后传递状态要用全局量。** 原型 p53 先用局部布尔量记“片段盒子以公式结尾”，`\UL@stop` 结束分组后
   这个值就丢了，修复完全不起作用，只有矩阵结果没有变化才暴露出来。R16 前（p22）也犯过同样的错误。凡是跨 `\UL@stop`、
   `\UL@start` 的状态，定义时就用 `\g_` 变量，并加一项在值丢失时会失败的变异（`math-last-never`）。
5. **在两种都说得通的设计之间选择时，优先保留正式版在所有选项下的宽度。** 零宽 `\hspace` 加入口空格可以像非零 `\hspace`
   那样把空格排在装饰之前（与 v3.9.1 相同），也可以像 `\nobreak` 那样按首类别处理、只改 glue 的位置（与 v3.10.6 的宽度相同）。
   前者默认选项下比 v3.10.6 宽一个空格，后者只改节点位置、消除断线。选了后者，并在 architecture 写明理由。

### 验证

- `fntef-entry-space01`：TEST 3 增 1 项节点用例，TEST 16 删 1 项、增 10 项宽度用例，TEST 17 增 1 项节点用例，全文件 348 项 PASS；
  新增宽度用例中 9 项在 `1b72e7c9` 上失败。逐项变异 94 项（`tmp/i1091/fix2/mutate20.py`）中 93 项被发现，22 项只由节点列表发现，
  `fullleft-flag-stuck` 仍为等价变异。
- 探测矩阵：原有 15 个矩阵与 r16g、rgg、r18z 相对 `1b72e7c9` 没有变化；新增的 r19（2160 项）、r19g、r19m（312 项）、r19mg 上
  没有由一致变为不一致的用例，r19g 里 3 项例外，是失去巧合（见第 2 条）；r19m、r19mg 相对 v3.10.6 也没有。
- xeCJK 全部 `l3build check` 通过，`l3build doc` 通过，ctex `l3build check -e xetex` 通过。

### 仍未覆盖（R18 后）

- 见 doc-gaps「R18 后新记下、仍未修的写法」：marker 留在公式与 `\usebox` 之前；`\mbox{中}` 后接全角左标点少一枚 `\CJKglue`；
  嵌套内层 `\mbox` 里有颜色时直接输入本身不一致（与 R17-X2 同类）；正文里的公式另有 41 项与 v3.10.6 同样不一致。

### 可写入稳定文档的内容（R18）

- **lessons-learned 候选**：补调钩子前写出它依赖的状态并确认只消费一次（第 1 条）；跨 `\UL@stop` 的状态用全局量（第 4 条）。
- **仅留在 memory**：宽度一致不等于位置正确（第 2 条，R16、R17 同类）；区分引入缺陷与失去巧合（第 3 条）；设计取舍的依据（第 5 条）。
- 已写入：architecture「R18 后的补修」、doc-gaps、build-and-test 的 `fntef-entry-space01` 一节。

## R19：marker 的消耗时机、盒子后的全角左标点与嵌套内层

### 起因与修法

- 本地独立审查 R19（对 `df9bbf1e`、`654f1c52`、`8e1a46db`）指出：
  - R19-I1：`df9bbf1e` 在 `\mbox` 开始时删去 `ulem-transparent` marker，嵌套内层随后以全角左标点开头的盒子前丢掉 `\CJKecglue`，
    相对 `1b72e7c9` 与 v3.10.6 回退。
  - R19-I2：`\changes` 说“包括嵌套内层”的公式之后汉字已修好，命令前有空格的嵌套写法却没有。
  - 三项小问题：零宽内容加公式的空格写法未登记（M1）；`\mbox{中}` 后接全角左标点只登记了 3 项、与反思第 3 条的原则矛盾（M2）；
    注释与 architecture 里“不改变结果”的说法不成立（M3）。
- 协调者为核对 I1、M2 另建 r20 矩阵（5040 项），又找到嵌套内层以 `\mbox{（中}` 结尾时多补 `\CJKecglue`，二分到 `7a3713db`。
- 修法：
  - 盒子开始时的钩子不再删 marker，结束时的 begin 钩子恢复为两种捕获方式都调用。
  - Boundary 到全角左标点的转换看盒子之后的 `CJK` marker。
  - 嵌套内层入口有空格、末节点是公式时解除入口。
  - 嵌套内层结束时末节点是 `default` marker 就改写外层的末类别。

### 经验

1. **“提前检查”与“提前消耗”要分开。** R18 把盒子之前的检查挪到盒子开始时，这一步本身没有问题；同时删去 marker 却消耗了
   后面还要读的状态。marker 是“此前只有透明内容”的记录，它的读者不止开始时的这一次检查，还有盒子里第一个字符出现时的钩子。
   把一段逻辑挪到更早的时机时，只挪只读的检查，不挪会改变共享状态的操作，除非能列出这个状态的全部读者。
2. **“不改变结果”这类不变量要用专门的矩阵验证。** R18 的 architecture 写“提前解除入口不改变结果”，依据只是当时的矩阵
   没有变化；那些矩阵里盒子的内容都会向 capture 报告类别。R19 的反例都落在“盒子里第一个字符不报告类别”（全角左标点）这一维上。
   写不变量之前，先列出它依赖的前提，再让矩阵覆盖前提不成立的情形。
3. **更宽的矩阵会找到更早的回退。** r20 的 5040 项里有一类 `7a3713db`（R7）引入的回退，此前 17 个矩阵都没有覆盖“嵌套内层以
   第一个字符不报告类别的盒子结尾”。所以文档里“相对 v3.10.6 没有回退”必须带上矩阵名，R16 起坚持的适用范围写法是必要的。
4. **两种修法结果相同时删去多余的一种。** 修嵌套内层以 `\mbox{（中}` 结尾时，原型里同时改了 `\@@_ulem_report_last:n`（遇到首类别
   为空的盒子层就停下）和末尾检查（末节点是 `default` marker 就改写末类别）。变异测试显示前者去掉后没有任何用例变化，r19、r20
   矩阵与专门构造的变体上也没有差别，按 R17 第 3 条删去，只留末尾检查。
5. **改正上一轮的说法时，同时检查依据它写出的其他文字。** R18 的“不改变结果”写进了 dtx 注释、architecture 与反思第 1 条；
   这次一并改掉，并在 architecture 里保留“当时这样写、后来找到反例”的记录，免得读者只看到结论变化而不知道原因。

### 验证

- `fntef-entry-space01`：TEST 16 新增 10 项宽度用例，TEST 17 删 1 项、增 2 项节点用例，全文件 358 项 PASS；新增宽度用例中 9 项在
  `8e1a46db` 上失败。逐项变异 99 项（`tmp/i1091/fix2/mutate22.py`）中 98 项被发现，24 项只由节点列表发现，`fullleft-flag-stuck` 仍为等价变异（原先写“全部被发现”，是比较脚本把编译时间算进了节点列表，见 R20 一节）。
- 探测矩阵：相对 `1b72e7c9`，全部矩阵上由一致变为不一致的用例都在命令前有源码空格的上下文里，已按既定设计登记；相对 v3.10.6，
  新增的 r20 上只有 22 项入口空格保留的既定设计。
- xeCJK 全部 `l3build check` 通过，`l3build doc` 通过，ctex `l3build check -e xetex` 通过。

### 仍未覆盖（R19 后）

- 见 doc-gaps「R18 后新记下、仍未修的写法」：`\mbox{（中}中` 的内容不排出（v3.10.6 同样）；嵌套内层以公式结尾、外层随后接汉字；
  入口有空格、嵌套内层先有颜色命令或透明盒子再写公式；公式其余 41 项；marker 的三种残留。

### 可写入稳定文档的内容（R19）

- **lessons-learned 候选**：提前检查与提前消耗分开（第 1 条）；不变量要列出前提并让矩阵覆盖前提不成立的情形（第 2 条）。
- **仅留在 memory**：更宽的矩阵找到更早的回退（第 3 条）；删去结果相同的多余修法（第 4 条，R17 第 3 条的又一实例）；改正说法时连带检查（第 5 条）。
- 已写入：architecture「R19 后的补修」、doc-gaps、build-and-test 的 `fntef-entry-space01` 一节。

## R20：入口前类别的含义与比较脚本的误报

### 起因与修法

- 本地独立审查 R20（对 `bf34c7ee`、`0982496e`、`46ffd92c`）指出一项重要问题：`\@@_ulem_onin_entry_math:n` 在入口前记为 `CJK` 时也删去
  入口空格。`{中} `、`\mbox{中} `、`前{} `、`前\ ` 都记为 `CJK`，直接输入保留这枚空格，于是 `{中} \uline{\sout{\kern1pt$a$x}} 后`
  这类在 v3.10.6、v3.9.1、`8e1a46db` 上都一致的写法少 3.33pt。另有三项小问题：两条 `\changes` 的说法与相对 v3.10.6 的可见变化
  不符，doc-gaps 一处括注不通顺。
- 修法：只在入口前是 `CJK-space`、`CJK-widow` 时删去空格；两条 `\changes` 按相对 v3.10.6 的可见变化改写；补 3 项宽度用例。
- 协调者核对变异结果时另发现：比较脚本把日志首行的编译时间算进了节点列表，R19 的“99 项全部被发现、`fullleft-flag-stuck` 不再是
  等价变异”是误报，实际为 98 项、仍是等价变异。

### 经验

1. **用状态值写条件之前，先把它在各种源码上下文里的取值打印出来。** `CJK` 与 `CJK-space` 的区别是“空格是否紧跟在汉字之后”，
   R19 按字面把三种都当作“入口前是汉字”。审查者的做法是直接输出 `before` 在 `前 `、`{中} `、`\mbox{中} `、`前\ ` 下的值，
   一眼就看出区别。凡是按类别名写分支，都应先做这样一张表。
2. **验证工具本身也要有阴性对照。** 变异测试的“节点列表不同”来自与 ref 日志的逐字比较；脚本以为自己去掉了日志开头，实际没有，
   编译时间跨分钟就会产生假阳性。加一个“与 ref 完全相同的变异”作为阴性对照，或检查裁剪标记确实出现在日志里，就能及早发现。
   重算 mutate18 至 mutate23 后，只有 R19 这一次受影响。
3. **面向用户的更改记录按相对正式版的可见变化写。** 分支内引入又修好的问题（如 `7a3713db` 的多补间距）对用户不可见，写进
   `\changes` 反而误导；而相对 v3.10.6 真实改变的行为（外层接着还有内容时不再少补间距、嵌套写法里公式之后是西文时入口空格
   的处理）却漏记了。写 `\changes` 前先用 v3.10.6 跑一遍点名的写法。

### 验证

- `fntef-entry-space01`：TEST 16 增 3 项，全文件 361 项 PASS；两项在 `46ffd92c` 上失败。逐项变异 100 项（`mutate23.py`）中 99 项
  被发现，24 项只由节点列表发现，`fullleft-flag-stuck` 为等价变异。
- 原有 24 个探测矩阵相对 `46ffd92c` 没有变化（这些矩阵没有 `{中} `、`\mbox{中} ` 开头的上下文）；R20 列出的 12 种写法都与直接输入一致。
- xeCJK 全部 `l3build check`、`l3build doc`、ctex `l3build check -e xetex` 通过。

### 可写入稳定文档的内容（R20）

- **lessons-learned 候选**：按类别名写分支前先打印各上下文的取值（第 1 条）；验证工具要有阴性对照（第 2 条）。
- **仅留在 memory**：`\changes` 按相对正式版的可见变化写（第 3 条）。

## R20 范围外观察之后：一类回退从 `2fb2a93b` 起就在

### 起因与修法

- R20 盲审的范围外观察只列了一个写法：`\mbox{中} \uline{\sout{\kern1pt中}} 后` 比直接输入与 v3.10.6 少 3.33pt，审查者注明“早于本范围”。协调者没有把它当作范围外的零星差异，而是按入口前的写法（`前 `、`\mbox{中} `、`{中} `、`前\ `、`前{} `、`\mbox{x} `、`$a$ `、`（ `、`中） `）与正文开头的内容展开成 r24 矩阵（600 项，四组选项），相对 v3.10.6 找到 66 项回退，全部自 `2fb2a93b` 起。之后的 r25、r26 又找到两类：正文先有内容、以公式结尾、命令后紧接汉字（r26 上 240 项），以及 `前\ `、`前{} ` 之后直接写汉字。
- 修法见 architecture「R20 后的补修」：入口前不是 `CJK-space`、`CJK-widow` 时，正文先有内容就保留空格；第一个字符直接出现时，看核心新记下的 `space_check_flag`；公式之后是汉字时补 `\CJKecglue`；stream end 在首类别为空、末类别为公式时重放 `math` marker。
- 过程中两次改错：原型 p63 让“第一个字符直接出现”一条也在 `\@@_ulem_level_check_aux:` 的调用里生效，颜色命令、`\mbox` 开始时就解除了入口，18 项由一致变为不一致，改为只在首类别非空时判断；p64 为颜色声明加了“末节点是 whatsit 时不重放”的判断，调试输出显示 stream end 时末节点是装饰盒子，这个判断从不成立，删去。

### 经验

1. **审查者标为“范围外”的写法，要先确认它是不是更早的分支提交引入的。** 增量审查的范围只是最近几个提交，审查者据此把差异标为“早于本范围”；但对整个任务来说，`2fb2a93b` 也是本分支的提交。这一个写法背后是 66 项、三类回退。以后收到范围外观察，先对照 `ef49ca4e`（任务基线）与 v3.10.6 各跑一次，再决定登记还是修。
2. **按“入口前的写法”展开矩阵。** 此前的矩阵只用 `前 `、`x`、`中` 三种上下文，`前 ` 恰好是唯一会删去空格的一类（`CJK-space`），`{中} `、`\mbox{中} `、`前\ ` 这些同样常见的写法一个都没有。上下文维度要覆盖核心区分的每一种 `before` 取值以及 `\g_@@_glue_check_pending_bool` 的两种状态。
3. **变异比较脚本要在干净的目录里运行。** 新变异的目录里没有 `.aux`，日志多出一行 `No file ….aux`，于是被算成“节点列表不同”；R20 的时间戳问题之后，这是同一个脚本的第二种噪声。每次运行前删去辅助文件，并用 `ref` 的第二次运行作为阴性对照。
4. **加判断条件之前，先确认它在实际输入上会成立。** whatsit 判断与公式之后 `\CJKecglue` 的“末节点仍是公式”判断都是按推测加的，逐项变异显示去掉它们没有任何差别，调试输出也证实条件从不成立。没有用例能区分的条件应当删去（与 R17 反思第 3 条相同）。

### 验证

- `fntef-entry-space01`：新增 TEST 18（20 项），全文件 381 项 PASS；15 项在 `59e356b9` 上失败。逐项变异见 build-and-test 的 R20 补充一条。
- 相对 `59e356b9`：r24、r25 上没有由一致变为不一致的用例；r26 上 24 项、r19／r19m／r20 上 10／3／5 项由一致变为不一致，前者是单层入口空格保留的既定设计，后者是颜色声明一类（v3.10.6 同样不一致），都已登记在 doc-gaps。（R21 补充：命令后接 `\mbox`、`\textcolor` 的写法也由一致变为不一致，不在这些矩阵里，这里原来的“只有”说大了。）相对 v3.10.6，r26 上的回退由 240 项降为 0 项，r24 上由 66 项降为单层既定设计的 9 项。（R21 更正：这只对 r24 成立。r24 只有“内容写在嵌套内层”的写法，“外层正文先有内容、再接嵌套命令”的同类回退（R21-I2）不在矩阵里；另外，命令后接 `\mbox`、`\textcolor` 的写法由一致变为不一致，也不在原有矩阵里，见 R21 一节。）

### 可写入稳定文档的内容（R20 范围外观察之后）

- **lessons-learned 候选**：范围外观察先对照任务基线与正式版（第 1 条）；矩阵的上下文维度按 `before` 取值与检查状态展开（第 2 条）。
- **仅留在 memory**：变异脚本在干净目录里运行（第 3 条）；删去没有用例能区分的条件（第 4 条，已有 R17 同类条目）。

## R21：两个新机制的组合与内容写在外层的同类写法

### 起因与修法

- R21 盲审（`46ffd92c..dfe37d4e`）有 2 项重要建议、5 项小问题：
  - I1：嵌套内层保留入口空格、正文又以公式结尾、命令后紧接汉字，仍少一枚 `\CJKecglue`。R20 的两个修法各自有效，组合起来不对：公式之后的 `\CJKecglue` 只在第一个字符是汉字时补，stream end 重放 `math` marker 又只在入口没有保留空格时有效。
  - I2：同一根因里，内容写在外层正文、嵌套命令在后（`\mbox{中} \uline{\kern1pt\sout{中}} 后`）仍少 3.33pt，r24 矩阵没有这一组。
  - M1–M5：命令后接 `\mbox`、`\textcolor` 的写法由一致变为不一致，没有登记；新 `\changes` 把分支内引入又修好的问题写成相对 v3.10.6 的变化，与 R20 反思第 3 条自相矛盾；单层 `前\ \uline{中} 后` 与嵌套写法不一致，没有登记；llmdoc 仍用改名前的 `:n`；CHANGELOG 多一个半角空格。
- 修法见 architecture「R21 后的补修」。范围外观察的两类（内层先有内容再接全角左标点、内层以公式开头命令后接西文）试过两种原型，都会让 r19、r20 上几十项由一致变为不一致，没有采用，登记在 doc-gaps。
- `\changes` 按相对 v3.10.6 的可见变化重写：删去 v3.10.6 上本来就一致的写法，只留公式之后的 `\CJKecglue` 与 `CJKecglue` 不等宽时的空格。

### 经验

1. **两个修法各自正确，组合时还要再测。** R20 的矩阵按“入口前的写法 × 正文开头”展开，“正文结尾”只取了 `中` 与 `x`，没有公式结尾，于是没看到“保留空格”与“公式结尾补间距”叠加的情形。给某个维度加新机制时，要把其他新机制涉及的维度一起交叉。
2. **“内容在内层”与“内容在外层”是同一类写法的两半。** R20 修的是 `\uline{\sout{\kern1pt中}}`，没有测 `\uline{\kern1pt\sout{中}}`。r27 矩阵把两者并列（`I-*` 与 `O-*`），以后同类改动都应这样成对测试。
3. **写 `\changes` 前逐句用 v3.10.6 核对。** R20 反思已经写了这一条，fix24 的 `\changes` 仍然违反。原因是先写了改动描述、再补测试，没有回头对照正式版；现在的做法是写完后把条目里点名的每个写法在 v3.10.6 上各跑一次。
4. **变异的改写本身也要检查。** `lead-check-onin-only` 的第一版把 `\bool_if:NT` 的条件放错了位置，改写后的代码与原来等价，被记成“未被发现”；打印改写后的函数后才看出来。以后新增变异时，先确认改写后的函数确实与原来不同。

### 验证

- `fntef-entry-space01`：TEST 18 增 8 项，7 项在 `a522e35a` 上失败，全文件 389 项 PASS。逐项变异 126 项中 119 项被发现（见 build-and-test）。
- 相对 `a522e35a`：原有全部矩阵与 r24、r25、r26 上没有由一致变为不一致的用例；新矩阵 r27 上只有内层以公式结尾、命令后接 `\mbox` 一类（每组选项 25 至 30 项，v3.10.6 同样不一致，登记在 doc-gaps）。相对 v3.10.6，r27 默认选项下由 61 项降为 43 项，剩下的是登记的两类范围外观察。

### 可写入稳定文档的内容（R21）

- **lessons-learned 候选**：新机制与其他新机制涉及的维度交叉测试（第 1 条）；内层、外层成对测试（第 2 条）。
- **仅留在 memory**：`\changes` 逐句对照正式版（第 3 条，重复 R20 第 3 条）；新增变异先确认改写有效（第 4 条）。

## R22：空格保留下来了，位置却不对

### 起因与修法

- R22 盲审（`dfe37d4e..2744d3eb`）有 2 项重要建议、3 项小问题：
  - I1：R21 的外层修法只在进入嵌套命令之前生效；外层内容与嵌套命令之间隔着颜色命令，或外层内容是 `\nobreak`、`\penalty0` 时，入口空格仍被删去，v3.10.6 与 `ef49ca4e` 都正确。
  - I2：R21 的外层修法当场排出空格，空格落在外层装饰线之下。宽度与直接输入相同，但 `{中} \CJKunderline{\kern1em\CJKsout{中中}\kern1em} 后` 的装饰线包住了左侧空格，正是 #1091 的“填空线不居中”。R21 拒绝单层方案时给出的理由恰好也是“空格落进片段盒子”，两处自相矛盾。
  - M1：`\changes` 漏了外层修法相对 v3.10.6 的可见变化；M2：R21 的 `math` marker 让嵌套写法后接 `\mbox` 多一枚间距，doc-gaps 只归因于更早的提交；M3：build-and-test 说 `keep-single-too` 变异“只改变节点位置”，实测单层宽度也会变。
- 修法见 architecture「R22 后的补修」：外层正文里先记下空格，由 `\@@_ulem_entry_box:` 在片段盒子送出之前排出，空格与正文以 `\hspace*` 开头时一样排在装饰之前；于是去掉“只在嵌套链上”的限制，颜色命令与 penalty 的路径也都生效，单层写法一并修好。
- 统计变异时发现 R21 的“127 项中 120 项”把 `ref` 一行也算了进去，实为 126 项中 119 项；`9105ba1e` 的提交说明已无法改动，更正写在 build-and-test。

### 经验

1. **比宽度只能证明“空格还在”，不能证明“空格在对的地方”。** #1091 的主症状就是空格位置不对（宽度一样，填空线不居中），R21 却只用宽度用例验证外层修法。凡是修改入口空格排出时机的改动，都要加节点列表用例，确认空格在第一个装饰片段之前。
2. **拒绝某个方案的理由，要检查它是否同样适用于自己采用的方案。** R21 以“空格落进片段盒子”否决了去掉嵌套链条件，采用的外层修法却产生同样的结果。写下否决理由时，应当对采用的方案做同一项检查。
3. **修一条路径时，列出所有能到达同一状态的路径。** 入口在第一个字符之前被“先排出的内容”解除，可以经过进入嵌套命令、透明命令开始、`\UL@stop` 取出 penalty、`\UL@reskip` 等多处。R21 只改了其中一处；这次把判断放进进入嵌套命令、透明命令开始与第一个字符出现时都会调用的 `\@@_ulem_onin_entry_keep:nn`，再由排出时机统一处理位置。（R23 更正：原先写“所有路径都会调用”不对。第一个字符在原始盒子里时走 `\@@_ulem_raw_box_check:n`，在用户分组里时左边界钩子根本不检查，公式路径 `\@@_ulem_onin_entry_math:nn` 也不经过它；排出时机也不是“统一”的，用户分组里的 `\UL@stop` 同样调用 `\@@_ulem_entry_box:`。见下文 R23 一节。）
4. **统计脚本的输出要逐行核对表头。** 变异结果里 `ref` 与各项变异格式相同，按行计数就会多算一项。以后统计时排除 `ref` 行，并把总数与脚本里的变异字典长度对照。

### 验证

- `fntef-entry-space01`：TEST 2 增 2 项节点用例、TEST 18 增 9 项宽度用例，8 项宽度用例在 `9105ba1e` 上失败，全文件 398 项 PASS。逐项变异 128 项中 122 项被发现。
- 相对 `9105ba1e`（p68）：原有全部矩阵与 r24 至 r27 上没有由一致变为不一致的用例；新矩阵 r28（1584 项 × 4 组选项）上三组选项各有 264 至 288 项由不一致变为一致（`CJKspace=true` 下没有变化），没有由一致变为不一致的。相对 v3.10.6，r28 默认选项下由 106 项降为 42 项，剩下的是单层入口空格保留的既定设计（30 项）与 `\fbox{}` 开头的一类既有差异（12 项，自 `2fb2a93b` 起），都已登记。

### 可写入稳定文档的内容（R22）

- **lessons-learned 候选**：改动入口空格排出时机时加节点列表用例（第 1 条）；否决理由要对采用的方案同样检查（第 2 条）；列出到达同一状态的所有路径（第 3 条）。
- **仅留在 memory**：统计变异时排除 `ref` 行（第 4 条）。

## R23：记下的空格排进了用户分组里的片段盒子

### 起因与修法

- R23 盲审（`2744d3eb..ee1a3e32`）有 1 项阻塞问题、1 项重要建议、3 项小问题：
  - B1：R22 的“记下空格、送出片段盒子之前排出”在第一个字符写在 `\textcolor{…}{…}`、`{\color{…}…}` 里时，由用户分组里的 `\UL@stop` 排出，而那时片段盒子还开着，空格落进片段盒子、装饰线之下。`{中} \CJKunderline{\kern1em\textcolor{red}{中中}\kern1em} 后` 两个红色汉字之间多 3.33pt，宽度与直接输入相同。R22 的 CHANGELOG、`\changes`、代码注释与 architecture 都写成“排在装饰之前”。TEST 18 的 `single-ctrl-space-kern-then-textcolor` 只比宽度，带着错误位置通过。
  - I1：第一个字符在原始盒子（`\hbox`、`\raisebox`）或用户分组、`\textbf` 里时，入口空格仍被删去；R22 却在 doc-gaps 写“已修好”，反思第 3 条写“所有路径都会调用”。
  - M1：`\changes` 的“命令右侧的间距”说法不对；M2：architecture 一条用现在时描述已删去的布尔量；M3：doc-gaps 一行两个例子共用一组数值。
- 修法见 architecture「R23 后的补修」：`\@@_ulem_entry_box:` 以 `\UL@start` 是否仍为 `\@empty` 判断片段盒子是否还开着，只在本层排出；原始盒子与用户分组两条路径同样记下空格；外层先排出内容、写公式、再接嵌套命令时，改放 `math` marker 由内层补 `\CJKecglue`。
- 新加 r29、r30 两个矩阵，并写了一个按节点列表判断“入口空格是否在片段盒子里”的检查脚本（`tmp/i1091/fix2/pos.py`），在所有矩阵上与 v3.10.6 比对位置。

### 经验

1. **R22 第 1 条写下了规则，却没有用在自己新加的用例上。** R22 反思第 1 条说“凡是修改入口空格排出时机的改动，都要加节点列表用例”，同一轮新加的 `single-*`、`outer-*-textcolor-*` 仍只比宽度，TEST 2 的两项节点用例只覆盖 `\sout` 与 `\mbox`。写下的规则要在同一轮就检查一次：新用例里凡是涉及空格位置的，都要有节点列表，或者在矩阵上跑位置检查。这次把位置检查做成脚本，在 r24–r30 全部矩阵上与 v3.10.6 逐项比对，新发现的空格落进片段盒子的写法都来自这个脚本。
2. **“所有路径”要逐条列出来，而不是凭印象。** R22 第 3 条的结论本身正确，但“所有路径都会调用”没有核对。第一个字符出现时可能走四条路径（嵌套链、`\xeCJK_if_ulem_patch:TF` 为真的片段盒子、用户分组、原始盒子），还有公式与 penalty 两个分支。这次在代码里逐一找到调用点，再为每一条写矩阵维度。
3. **排出时机的“同一个函数”不等于“同一个层级”。** `\@@_ulem_entry_box:` 由每一次 `\UL@stop` 调用，包括用户分组里那些只关闭用户分组的调用。本文件 15279 行附近早就写明“在用户分组内 `\UL@stop` 关不掉正确的层级”，R22 设计时没有对照这条已知限制。依赖某个钩子“总在某个时刻调用”时，要先查这个钩子还会在哪些时刻被调用。
4. **修好一侧可能让另一侧的既有缺口显露。** `x\uline{\kern1pt\textbf{中}} 后` 原来左侧多一枚、右侧少一枚，宽度碰巧一致；修好左侧后变成不一致。提交说明据“宽度矩阵没有由一致变为不一致”下结论时，没有先把 r29 与 p76 的比较跑完，写错了一句，只能事后另写更正。结论要等全部比较跑完再写进提交说明。

### 验证

- `fntef-entry-space01`：TEST 2 增 9 项节点用例、TEST 3 增 1 项、TEST 18 增 17 项宽度用例，全文件 416 项 PASS。新增的 9 项节点用例在 p76（`3de877f2`）上空格都不在第一个装饰片段之前（在片段盒子里，或被删去），14 项宽度用例在 p76 上失败。xeCJK `l3build check` 124/124、`l3build doc`、ctex `l3build check` 186/186 通过。
- 逐项变异 140 项（`tmp/i1091/fix2/mutate29.py`，以 p88 即 `a89246f6` 的代码为基准，不含 `ref`）中 134 项被发现，32 项只由节点列表发现。未被发现的 6 项：`fullleft-flag-stuck`、`keep-pend-any-before`、`keep-content-onin-check`、`tail-bool-not-reset`、`defer-not-reset-at-begin` 同 R22；`r23-lead-bool-not-reset`（进入嵌套命令之前的检查结束后不清除 `\l_@@_ulem_onin_lead_bool`）在矩阵与探针上都区分不出，布尔量是局部的，检查所在的分组结束时随之失效。
- 矩阵：相对 p76，r29 默认选项下 480 项、r30 下 582 项由不一致变为一致；r24–r28 与原有矩阵上宽度逐项不变；r29 上 2 项由一致变为不一致（`\textbf` 结尾一类，见 doc-gaps「R23 后补记」）。位置检查：r24–r30 上入口空格落进片段盒子的用例都不多于 v3.10.6，r30 上另有 48 项被标记，逐项核对是公式与汉字之间的 `\CJKecglue`，不是入口空格。

### 可写入稳定文档的内容（R23）

- **lessons-learned 候选**：写下的规则当轮就对新用例检查一次（第 1 条）；依赖钩子的调用时刻前先查它还在哪些时刻被调用（第 3 条）。
- **仅留在 memory**：逐条列出路径（第 2 条，R22 第 3 条的补充）；结论等全部比较跑完再写进提交说明（第 4 条）。

## R24：修一处路径时漏掉同一根因的第三条路径，新 marker 越过了透明命令

### 起因与修法

- R24 盲审（`ee1a3e32..0d76971c`）有 1 项阻塞问题、3 项重要建议、3 项小问题：
  - B1：R23 带进内层的 `math` marker 在内层第一个字符前面先有颜色命令、`\mbox`、`\fbox` 时仍起作用，多补一枚 `\CJKecglue`，48 项相对 `ee1a3e32` 与 v3.10.6 回退。
  - I1：修好入口一侧后，用户分组之后内部“空格加汉字”的既有缺口不再被抵消，35 项回退，doc-gaps 没有记录。
  - I2：用户分组里的 penalty 分支记下的空格，最后一个片段盒子为空时不会排出。
  - I3：用户分组里的 `\UL@reskip` 仍当场排出空格，填空线写在 `\textbf{…}` 里时不对称。
  - M1：`{\hspace{0pt}中}` 一类在 `ee1a3e32` 上碰巧一致，本范围回退；M2、M3：CHANGELOG 两个分句几乎重复，注释里有提前断开的短行。
- 修法见 architecture「R24 后的补修」。I1 试过原型但没有采用，与另一类一起登记在 doc-gaps「R24 后补记」。

### 经验

1. **R23 第 3 条（依赖钩子的调用时刻前，先查它还在哪些时刻被调用）只用在了一个函数上。** R23 找到了用户分组里的 `\UL@stop`，却没有沿着同一个问题去找用户分组里还会“当场排出空格”的其他函数：`\UL@reskip` 调用的 `\@@_ulem_entry_skip:` 正是第三条路径。这次把三处合并到 `\@@_ulem_entry_resolve_here:`，以后再有“当场排出入口空格”的地方都应该经过它。
2. **新放的 marker 要像直接输入一样被挡住。** 直接输入里颜色 whatsit、`\mbox` 挡住公式之后的类别转换；R23 放进内层的 `math` marker 没有对应的“挡住”机制。R22-M2 已经记录过同一种副作用（结尾 `math` marker 让后面的 `\mbox` 多补间距），这次在开头路径上重犯。以后放 marker 之前，先列出直接输入里哪些东西会挡住它，再逐项确认它们在装饰里也会移走或让 marker 失效。
3. **“不变量总成立”的注释要配一个断言或一个反例搜索。** R23 注释写“记下的空格总会在片段盒子本层排出”，R24 用只含 `\nobreak` 的分组找到了反例；R22 的原型里其实有过 `\@@_ulem_end:` 那一次排出，因为当时没有用例能区分而删去。变异区分不出就删掉的代码，要先想想是不是缺了用例，而不是代码冗余。

### 验证

- `fntef-entry-space01`：TEST 2 增 2 项节点用例，TEST 18 增 12 项宽度用例，全文件 428 项 PASS。其中 11 项宽度用例在 p84（`a89246f6` 的代码）上失败（`outer-group-space-kern-math-then-nested-leftparen` 在 p84 上同样通过，它防止原型里的另一种做法），`group-fill` 在 p84 上入口空格在片段盒子里。
- 逐项变异 150 项（`tmp/i1091/fix2/mutate30.py`，以 p106 为基准，不含 `ref`）中 142 项被发现，35 项只由节点列表发现。未被发现的 8 项：R23 的 6 项；`r24-here-math-space-defer`（`\@@_ulem_entry_resolve_here:` 在入口前是 `math-space` 类时也记下空格）与 `r24-marker-not-reset-emit`（第一个字符出现时不清除 `\l_@@_ulem_onin_lead_marker_bool`），在 r24–r31 与原有矩阵上都区分不出。前者是因为实测里 `math-space` 类的入口从不带 `space_flag`（公式之后的源码空格由核心留在列表里），后者是因为布尔量是局部的、只在内层正文里设置，内层结束时随分组失效。
- 矩阵：r24–r30 与原有矩阵上相对 `a89246f6` 宽度逐项不变；r31 上默认选项 417 项由不一致变为一致，没有由一致变为不一致的。

### 可写入稳定文档的内容（R24）

- **lessons-learned 候选**：放 marker 之前列出直接输入里会挡住它的东西（第 2 条）；变异区分不出的代码先找缺失的用例（第 3 条）。
- **仅留在 memory**：同一根因的路径合并到一个函数（第 1 条）。

## R25：删掉一条信息时，要列出还有谁在读它

### 起因与修法

- R25 盲审（`0d76971c..4acf2932`）有 1 项阻塞问题、2 项重要建议、5 项小问题：
  - B1：R24 在盒子开始时清空 `before`，空盒子之后的全角左标点丢了左侧空白（`x\uline{$a$\sout{\mbox{}（中}}x` 少 6.34pt），m2 矩阵默认选项 48 项相对 `0d76971c` 回退。
  - I1：R24 只在正文末尾补排记下的空格，正文中间的空片段让空格落在两段装饰线之间。
  - I2：architecture 把 `\fbox` 写成走 wrapped 盒子、靠 `\UL@hrest` 清除布尔量，实际与 `\mbox` 一样以 last 方式捕获。
  - M1–M5：用例数写成 13（实为 12）、多一个逗号、lvt 注释通配写法不准、零宽 `\hspace` 不在分组里时“记下”应为“当场排出”、dtx 零宽分支说明未同步。
- R25 补充另指出：R24-B1 点名的命令后有空格的全角左标点一例仍未解决；R24-I1 没有加固定当前行为的用例；R24-I2 建议的断言没有加；`xeCJK.dtx` 里又留下一行短行。
- 修法见 architecture「R25 后的补修」。命令后有空格的全角左标点一例试过原型但没有采用，登记在 doc-gaps「R25 后补记」。

### 经验

1. **删掉一条信息之前，列出所有读它的地方。** R24 为了让盒子里的汉字不补 `\CJKecglue` 清空了 `before`，只想到了“盒子里的第一个字符”这一个读者；透明盒子的重放、全角左标点的左侧空白规则也在读“前面有没有内容”。修法没有恢复 `math`（那会让汉字多补间距），而是只补上标点需要的那一部分信息（一个零宽 `\kern`）。R24 第 2 条讲的是“新放的 marker 要被挡住”，这一条是它的反面：拿掉 marker 时，被它顺带挡住或提供的东西也要照顾到。
2. **原型的净效果要按“离直接输入更近还是更远”分类，不能只数 PASS/FAIL。** 命令后有空格的全角左标点一例的原型在 PASS/FAIL 上修好 3000 多项（各组选项合计），只回退 15 项；但 FAIL→FAIL 里还有 137 项离直接输入更远，15 项回退正是原先两侧抵消的写法。最后没有采用。
3. **R24 第 3 条的落实：给“不变量”加断言。** 这次把 `\g_@@_ulem_space_defer_bool` 加进 `\EntryAssertIdle`。插桩显示 `\@@_ulem_end:` 的那一次排出在所有矩阵里都没有走到，但没有删：它现在由断言守着，以后若有写法走到它，测试会先报出来。
4. **小问题的修法也要跑变异。** 两个清除记录的位置（ulem 开始、盒子开始时的过期清除）起初没有用例能区分，补了 `latin-math-color-then-next-decoration-in-hbox`、`math-mbox-then-hbox-empty-mbox` 之后才被覆盖；另有三处清除在所有用例里都区分不出，按第 3 条先确认原因再删：ulem 结束时的清除与 ulem 开始时的清除重复；透明盒子钩子里用过记录后的清除，由后面盒子开始时的过期清除代替；第一个字符出现时的清除不影响结果，因为这以后标点前面本来就有字符。

### 验证

- `fntef-entry-space01`：TEST 2 增 4 项节点用例，TEST 18 增 14 项宽度用例与 2 项节点用例，全文件 442 项 PASS。
- 逐项变异 13 项（`tmp/i1091/fix2/mut32.list`）中 12 项被发现（其中 1 项靠补加的用例）；`q15-empty-flush-nogate` 区分不出，理由见 build-and-test「R25 的补充」。
- 矩阵：r24–r31 与原有矩阵相对 `94414fd3` 逐项不变；新矩阵 r32、r33、r34 上没有由一致变为不一致的用例。

### 可写入稳定文档的内容（R25）

- **lessons-learned 候选**：删掉一条信息之前列出所有读它的地方（第 1 条）；原型按离 oracle 的远近分类（第 2 条）。
- **仅留在 memory**：第 3、4 条。

## R26：说明写成“与直接输入相同”之前，先把同类节点逐个测一遍

- R26 盲审（`4acf2932..e9360899`）0 项阻塞、2 项重要建议、2 项小问题。I1：R25 新写的说明声称公式之后隔着 glue、penalty 再嵌套时“与直接输入相同”，只测了 `\hfill`，有限宽 glue、`\nobreak` 在直接输入里保留标点左侧空白，装饰里仍压缩。I2：登记的遗留差异只写了“命令后有空格再接汉字”一种表现，漏了命令后接西文时少 `\CJKecglue`（其中一例相对 v3.10.6 回退），也没说明本轮修法让哪些写法由两处误差抵消变为只剩一处。M1：两个新记录装饰结束后残留。M2：lvt 注释通配名重叠。
- 修法：I1、I2 改说明并登记 doc-gaps、加 known 节点用例；M1 在 `\@@_ulem_end:` 清除记录，加节点用例；M2 写出完整用例名。
- **经验 1**：写“与直接输入相同”这类全称说法时，按节点类型列出同类写法（`\hfill`、有限 glue、零宽 glue、`\nobreak`、`\penalty0`、`\penalty10000`），逐个与直接输入比较；用例只放一种写法时，说法只能限定到这一种。
- **经验 2**：登记遗留差异时按“机制”列出所有表现（命令后接空格、接西文、命令前有无空格），不只写被点名的那一个写法。R25 反思第 2 条（按离直接输入更近还是更远分类）同样要用在提交的修法上，不只用在原型上。
- **经验 3**：核心钩子在装饰之外也会调用；新加的全局记录要在装饰开始与结束时都清除，R25 反思第 4 条删去结束时的清除，是因为当时的用例都在装饰里。
- 验证：442 项 PASS；去掉结束时的清除，`records-cleared-after-decoration` 的节点列表不同；r24–r34 矩阵与 `e69e0263` 逐项相同。

## R27：审查不收敛时，先回到任务范围

- R27 盲审（`e9360899..711dffd2`）0 项阻塞、1 项重要建议、2 项小问题。重要建议：同一机制下相对 v3.10.6 的回退有 30 项，登记只写了 1 项。
- 维护者看了 R1–R27 的问题数后判断审查者在不断构造边界写法，决定（2026-09-29）收窄范围：公式、空盒子、颜色命令、三层嵌套、全角左标点叠在一起的组合写法，差异（包括这 30 项回退）登记为已知限制，不再修代码。
- **经验 1**：审查判据是“与直接输入等宽”，而 ulem 的片段盒子结构决定了不可能在所有组合上做到；这时每轮都能找到新的一类，问题数不会收敛。协调者应该在问题数连续几轮不降、修法开始补上一轮补丁的副作用时（R24→R25→R26），主动把取舍交给维护者，而不是默认都修。
- **经验 2**：最终审查的审查包要写明范围（计入问题的类别、只作观察的类别），范围是任务定义的一部分，写进审查包不违反盲审规则。
- 处理：doc-gaps 写全 30 项的范围并注明维护者决定；加 `known-space-fbox-math-then-nested-color-leftparen-latin` 节点用例；两处注释改正。

## 最终全范围审查：写明范围以后，找到的是常见写法

- 维护者同意跳过 R27 之后的增量审查，直接做最终全范围审查（`ef49ca4e..ad22fb6f`），审查包写明收窄后的范围。结果 0 项阻塞、3 项重要建议、3 项小问题；范围外的写法只作观察，不计入。
- I1、I2 都是相对 v3.10.6 的回退，写法都很常见：`第 \mbox{\CJKunderline{\hspace*{1em}（1）\hspace*{1em}}} 题`（填空线放进 `\mbox` 防止断行，正文是带括号的题号）、`姓名 \CJKunderline{\textcolor{blue}{张三} } 学号`（正文末尾多一个空格）。I3 是定宽 `\makebox` 的既有限制（v3.10.6 相同），写进手册与 doc-gaps。小问题是 doc-gaps 把一项回退写成既有差异、手册把 `\mbox` 与原始盒子混在一起、嵌套命令入口空格的例外没有写进手册。
- 修法：I1 在全角左标点报告 `CJK` 前后保存、恢复外层 `box` 层的 `first`、`last`、`tail`；I2 在正文末尾空格之前末节点仍是 `CJK`／`default` marker 时把 `tail` 记为 `content`。
- **经验 1**：R1–R27 的审查包没有写范围，审查者在“与直接输入等宽”这个判据下自然会去构造越来越深的组合；写明范围以后，同一个判据找到的是填空线里最常见的写法。范围应当从第一轮就写进审查包，而不是问题数不收敛以后再补。
- **经验 2**：一个函数写“所有层”时，要对照同类函数确认它是否应当跳过某类层。`\@@_ulem_report_last:n` 从 R7 起就只写 `stream-ulem` 层（architecture 里写了原因），`\@@_boundary_capture_class:n` 写所有层；`2fb2a93b` 在 FullLeft 分支调用后者，R7 写前者时没有回头比较两者，盒子层被改写这件事留到了最终审查。
- **经验 3**：修法让一项已经不一致的写法离直接输入更远（`\mbox{\CJKunderline{（中}}中`，30.00pt→33.33pt，直接输入 26.99pt）时，按 R25 经验 2 如实写进说明，不因为“修改前也不对”就不提。r35 矩阵上逐项比较离直接输入的远近：p135→p138 有差别的不一致用例在四组选项下都更近（12、172、12、12 项），这一项不在矩阵里，是手工用例测到的。
- 验证：lvt 452 项 PASS；r24–r34 与原有矩阵相对 p135 逐项不变；r35 修好 380 项，8 项由一致变为不一致、都与 `~` 写法一致；逐项变异 4 项中 2 项被发现，另两项（`tail` 只认 `CJK` marker、只恢复 `first`）区分不出，在说明里注明是防御性写法。

## 替换的最终审查：判据只看结构时要找出“长得一样”的反例

- 替换的最终全范围审查（`ef49ca4e..0e9d9169`）0 项阻塞、1 项重要建议、4 项小问题。I1 是相对 v3.10.6 的回退：正文只有注册盒子（`x\CJKunderline{\makebox[3em]{}}后`）时少 `\CJKecglue`。小问题是两层写法里靠误差抵消才一致的三组用例未登记、手册两处 Overfull、lvt 文件头的重名标签与不全的 TEST 清单、index 停在 R22。
- 修法：结束时入口已解除、首类别为空的分支新增核心钩子，xeCJKfntef 记下“片段里只有注册盒子”时重放入口 marker。
- **经验 1**：第一版判据用“片段末节点是盒子”，`\rule` 也排出盒子，r36 矩阵上立刻多出 20 项由一致变为不一致（`\fbox{}\rule` 与正文以语法空格开头的 ` \fbox{}` 两类）；第二版加上钩子记下的盒子尺寸，又漏掉嵌套命令的内层盒子（外层片段的末节点是 `\UL@onin` 的盒子）和 whatsit 结尾的 `\colorbox`；第三版接受任何 whatsit，又让 `\fbox{}\special{x}` 回退。每一版都是矩阵或手工反例先发现的。判据按节点类型设计时，要为每种类型列出“同类型但含义不同”的写法（盒子：注册盒子、`\rule`、`\hbox`、嵌套命令的盒子；whatsit：颜色、`\special`），先写进矩阵再改代码。
- **经验 2**：第一版变异 10 项里有 4 项没被发现，补的对照用例（`\hspace`、`\nobreak` 再接盒子、正文末尾空格、`\textcolor`）都是只用宽度就能区分的普通写法；lvt 当时只放了“修好的写法”，没有放“不该改变的邻近写法”。新增修法时，对照用例与修好的用例一起写。
- **经验 3**：doc-gaps 里写“两者 v3.10.6 上同样多补”之前实测了一次，其中一项（颜色命令里盒子之后还有规则）其实与直接输入一致，推断是错的。登记遗留差异时每一项都要有实测数值。
- 验证：lvt 469 项 PASS；r24–r35 与原有矩阵逐项不变；r36 默认选项修好 135 项，没有由一致变为不一致；逐项变异 12 项全部被发现。

## 相关

- Issue：#1091。关联：#992（capture 框架）、#324（入口空格语义）、#998（box 策略）。
- 实现：`xeCJK/xeCJK.dtx` 中 `\@@_boundary_capture_emit_left:nn`、`\@@_boundary_inline_stream_end:n`、
  `\UL@end`、`\@@_ulem_end:`、`\UL@stop`、`\UL@reskip`、`\@@_ulem_entry_*`、
  `\@@_boundary_use_ulem_glue_outer:nn`、`\@@_ulem_Boundary_and_FullLeft_glue:N`；R5 起还有
  `\xeCJK_check_FullRight_symbol:Nw`（`\g_@@_FullRight_space_bool`）与 `\@@_ulem_punct_peek_space:`；R6 起还有
  `\@@_ulem_onin_report_default:`（R7 删去，改为 `\@@_ulem_report_last:n`）；R8 起还有 `\@@_ulem_onin_tail_check:`；
  R9 起还有 `\@@_ulem_left_punct_peek:`、`\@@_ulem_tail_left_content:`、`\@@_ulem_onin_tail_glue:`、
  `\@@_ulem_nest_node:`、`\@@_ulem_nest_node_remove:` 与 `\l_@@_ulem_onin_lead_tl`；R10 起还有
  `\@@_ulem_left_punct_mark:`（`ulem-left` marker）、`\@@_ulem_onin_lead_get:n`、`\@@_ulem_onin_lead_put:` 与
  `\@@_ulem_onin_if_lead_space:n`（R11 删去）；R11 起还有核心的 `\@@_boundary_emit_left_hook:n` 与
  `\@@_ulem_orig_space_glue:`；R12 起还有核心的 `\@@_boundary_transparent_begin_hook:`、
  `\@@_boundary_transparent_end_hook:`，以及 `\@@_ulem_onin_entry_check_space:n`、`\@@_ulem_onin_entry_check:n`、
  `ulem-transparent` marker、`\g_@@_ulem_onin_transparent_bool` 与 `\l_@@_ulem_xecglue_bool`；R13 起还有
  `\@@_ulem_transparent_node_remove:`；`a8b45cf4` 起还有核心的 `\@@_boundary_transparent_box_hook:`，以及
  `\@@_ulem_transparent_mark:`、`\@@_ulem_level_check:`、`\@@_ulem_raw_box_check:n`、`\@@_ulem_if_last_content:`、
  `\g_@@_ulem_transparent_tail_bool`（`d250e2a7` 删去）与包装后的 `\UL@setULdepth`（`\@@_ulem_orig_set_depth:`）；`c254f535` 起还有核心的
  `\@@_boundary_transparent_box_begin_hook:`，以及 `\@@_ulem_transparent_begin:n`、`\@@_ulem_transparent_mark:n`（取代
  `\@@_ulem_transparent_mark:`）、`\@@_ulem_transparent_clear:n`、`\@@_ulem_fullleft_check:n`、`\l_@@_ulem_fullleft_bool`、
  `\@@_ulem_if_outside_box:nT` 与 `\@@_ulem_level_check_aux:`；最终全范围审查后还有 `\@@_ulem_box_layers_save:`、
  `\@@_ulem_box_layers_restore:`、`\@@_ulem_box_layer_restore:nnnn` 与 `\c_@@_ulem_tail_box_nodes_clist`；替换的最终审查后
  还有核心的 `\@@_boundary_resolved_end_hook:`，以及 `\@@_ulem_box_only_note:`、`\@@_ulem_box_only_nest:`、
  `\@@_ulem_box_only_stop:`、`\@@_ulem_box_entry_set:`、`\g_@@_ulem_box_only_bool` 与 `\g_@@_ulem_box_entry_tl`。
- 过程材料（本地）：`.llmdoc-tmp/investigations/1091-fntef-entry-space.md`、`tmp/i1091/`。
- 相关反思：[[1067-ulem-brace-group-ecglue-shrink]]（同一 ulem 片段盒子结构上的另一类问题）、
  [[1029-sbox-global-prefix]]（逐项变异的原始教训）、[[324-boundary-reserve-space-glue]]（入口空格语义）、
  [[1085-hfill-post-transparent-relocate]]（自动分析方向对、定位错的同型经历）。
