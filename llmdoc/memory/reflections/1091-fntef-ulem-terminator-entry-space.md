---
name: 1091-fntef-ulem-terminator-entry-space
description: 记录 #1091 修复线型装饰命令把 ulem 结束符 `*` 当作正文字符、以及 stream-ulem 入口空格被排到装饰之后的两层问题；核心教训是只修一层会得到“宽度对、位置错”的中间态，验证必须看节点顺序；新增拦截点要用全角标点开头的正文复核；变异无判别力时要找出是哪条兜底路径掩盖了它；旧基线可能冻结了缺陷值；R1 补修（6b197547）的教训是比对要组合正文首尾的非字符内容、命令两侧空格与后续字符类别，oracle 要确认源码空格真的存在，改右边界重放要检查段末的像素补偿 glue；本地增量审查 R2 后的教训是声称测试保护某性质时，要用只破坏该性质的变异确认测试会失败（R1 用 `\raisebox` 测 `\raise` 位移，根本没走到取下再放回的路径），模仿直接输入的 `\ignorespaces` 要连同分组层级一起模仿；本地增量审查 R3 后改用正文末尾的扫描标记加 peek 判断全角右标点，并修好嵌套内层标点，教训是模仿一个原语前先确认它的完整停止条件（`\ignorespaces` 在第一个非空格记号处停），用直接对应该条件的判据而不是逐个补情况，声称“修复前后相同”前要把有无空格、后接汉字／西文各测一遍；本地增量审查 R4 后补上盒子里的嵌套装饰、嵌套内层“标点＋末尾空格”与三层嵌套中间层，教训是给状态标志加作用域时要把“进入”“新盒子清除”“再次进入”组合起来测、嵌套至少测到三层，新增的 peek 路径要与原有 ulem 分支对空格的处理一致
metadata:
  type: feedback
---

# [Task Reflection]

## Task

Issue #1091：`普通字符 \myfillin{} 后续文字`（`\myfillin` 用 `\CJKunderline` 包住
`\hspace*`、盒子、`\hspace*`，宏定义里带一枚结尾空格）排出的填空线不居中；把命令前的空格
换成 `~` 就居中。v3.9.1 正常；v3.10.0–3.10.3 左侧空格被删（#324 语义）但仍居中；从
v3.10.4（#992 capture 框架）起，左侧空格跑到装饰末尾，还多出一段装饰和一枚间距。

修复在提交 `ad8dc88b`（`xeCJK/xeCJK.dtx`，新测试 `xeCJK/testfiles/fntef-entry-space01.lvt`，
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

- 只比总宽区分不出空格在装饰前还是后，所以 TEST 1–3 用 `showboxdepth=1` 的节点列表固定
  glue 位于第一个 `\rule … \cleaders` 之前；每个节点用例独占一页并先打印 `CASE` 行，
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

## 本地独立审查 R1 后的补修（提交 6b197547）

### 审查结果与自查发现

- 首轮本地盲审（run `20260927T021602Z-r1-first`）报告阻塞问题 1 项、重要建议 1 项、小问题 4 项。
  - 阻塞：正文以字符开头、以 `\hspace*`、盒子、kern、penalty、special 等结尾时，命令后的源码
    空格被按 CJK 规则删去。例：`姓名 \CJKunderline{张三\hspace*{4em}} 学号` 为 100pt，直接输入
    为 103.33pt。这是 `ad8dc88b` 引入的回归：`*` 不再覆盖末类别后，stream end 只看正文最后
    一个字符，没有看它后面还排出了别的内容。
  - 重要：正文以语法空格开头时，入口空格排在已画线的语法空格之后，装饰线从中间断开。
  - 小问题：“片段盒”用词；`build-and-test.md` 中的页数过时；测试注释称“issue 中的写法”，
    实际与 issue 不同；手册“命令前后的源码空格”说得太宽。
- 实现者用 40 多项“装饰写法与直接输入”的宽度比对（`tmp/i1091/fix2/right.tex`）另外发现一处
  盲审没报的回归：`ad8dc88b` 让 `\CJKunderline{中。}x` 在 x 前多出 3.33pt，修复前它与直接输入
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

- 代码层：`ad8dc88b` 修正了 `*` 对末类别的覆盖，但 stream end 仍只根据“最后报告的类别”决定是否
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
  `\CJKunderline{\CJKsout{中} } 后` 属于同类。
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

- 对 R2 补修（`7f9e968f`）的本地增量盲审（R3）报告的问题如下。
  - R3-B1（阻塞）：全角右标点结尾时，`\@@_ulem_end:` 末尾的 `\ignorespaces` 太宽。标点之后还有
    `\relax`、`{}`、`\hspace{0pt}`、包装宏（`\newcommand\ans[1]{#1\relax}`）、正文末尾空格等不产生
    节点的记号时，命令后的空格仍被吃掉；直接输入的 `\ignorespaces` 碰到第一个非空格记号就停下，
    会保留这枚空格。R2 的分组层级规则只覆盖了“分组结束”这一种情况。
  - R3-I1（重要，与 R2-M2 合并）：`\CJKunderline{\CJKsout{中。}}x`（嵌套内层以全角右标点结尾、
    无空格后接西文）是 `ad8dc88b` 引入的回退，v3.10.6 与直接输入一致；R2 把它写成“修复前后相同”
    是错的。有空格的 `\CJKunderline{\CJKsout{中。}} x` 则修复前后都与直接输入不一致。
  - R3-I2（重要）：`\changes` 里的 `|...|` 进入 `.glo` 后，第一个 `|` 被 makeindex 当作 encap 符，
    后面的文字被当作页码格式命令执行：更改历史出现 `hdclindex…`／`dex…` 文字泄漏，带下划线的
    正文被真正排出，并有 Overfull。以反斜杠开头的 `|\CJKunderline{...}|` 不报错，排版同样出错。
    上文 R1 第 4 条坑和 Promotion Candidates 里“以反斜杠开头的短抄录没有问题”是错的。
  - R3-M1：`llmdoc/state/sync.md` 的水位仍停在 R1 补修提交 `6b197547`，没有随后续提交更新。

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
   有空格的 `\CJKunderline{\CJKsout{中。}} x`；无空格后接西文的写法实际是 `ad8dc88b` 引入的回退。
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
  `\mbox` 里的句号），全文件 90 项 PASS；这 19 项在 `7f9e968f` 上有 15 项失败。
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

- 对 R3 补修（`f66ee63d`）的本地增量盲审（R4）报告阻塞问题 1 项、重要建议 2 项、小问题 3 项。
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
- I1：`\@@_ulem_punct_peek:` 先用 `\peek_charcode_remove:NTF \c_space_token` 判断空格：下一个记号是
  空格就置 `content` 并 `\ignorespaces`；否则按原来的 N 型／标记判断。原生
  `\xeCJK_FullRight_and_Boundary:` 末尾的 `\ignorespaces` 遇到紧随的受保护函数 `\@@_ulem_punct_peek:`
  就停下，所以内层末尾空格同样由 peek 看到。
- I2：`\@@_ulem_nest_mark:` 的非 patch 分支中，若 onin 布尔为真（仍在嵌套链上）且 `tail` 为 `punct`，
  也调用 peek。
- M1：dtx 说明改为分别描述三种情况（标记、空格、其他记号）。M3：`\s_@@_ulem_body` 移到名字列表首位。

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
  `f66ee63d` 上有 6 项失败。
- 逐项变异 3 项全部被捕获：进入 onin 时不看 patch 状态（3 项失败）、空格时不置 `content`（2 项）、
  中间层不 peek（1 项）。

### Promotion Candidates（R4）

- **lessons-learned（补充「按根因枚举象限」）**：给状态标志加作用域时，要把“进入”“新盒子清除”
  “再次进入”组合起来测，嵌套层数至少测到三层；新增的判定路径要与原有路径对空格这类分词定界符的
  处理保持一致。
- **reference（`build-and-test.md`）**：macro 环境的 `\changes` 标签取名字列表最后一个名字（已由
  recorder 完成）。
- **仅留在 memory**：三处修改的具体位置，稳定部分已写进架构文档。

## 相关

- Issue：#1091。关联：#992（capture 框架）、#324（入口空格语义）、#998（box 策略）。
- 实现：`xeCJK/xeCJK.dtx` 中 `\@@_boundary_capture_emit_left:nn`、`\@@_boundary_inline_stream_end:n`、
  `\UL@end`、`\@@_ulem_end:`、`\UL@stop`、`\UL@reskip`、`\@@_ulem_entry_*`、
  `\@@_boundary_use_ulem_glue_outer:nn`、`\@@_ulem_Boundary_and_FullLeft_glue:N`。
- 过程材料（本地）：`.llmdoc-tmp/investigations/1091-fntef-entry-space.md`、`tmp/i1091/`。
- 相关反思：[[1067-ulem-brace-group-ecglue-shrink]]（同一 ulem 片段盒子结构上的另一类问题）、
  [[1029-sbox-global-prefix]]（逐项变异的原始教训）、[[324-boundary-reserve-space-glue]]（入口空格语义）、
  [[1085-hfill-post-transparent-relocate]]（自动分析方向对、定位错的同型经历）。
