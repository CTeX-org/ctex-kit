---
name: 1091-fntef-ulem-terminator-entry-space
description: 记录 #1091 修复线型装饰命令把 ulem 结束符 `*` 当作正文字符、以及 stream-ulem 入口空格被排到装饰之后的两层问题；核心教训是只修一层会得到“宽度对、位置错”的中间态，验证必须看节点顺序；新增拦截点要用全角标点开头的正文复核；变异无判别力时要找出是哪条兜底路径掩盖了它；旧基线可能冻结了缺陷值
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

## 相关

- Issue：#1091。关联：#992（capture 框架）、#324（入口空格语义）、#998（box 策略）。
- 实现：`xeCJK/xeCJK.dtx` 中 `\@@_boundary_capture_emit_left:nn`、`\@@_boundary_inline_stream_end:n`、
  `\UL@end`、`\@@_ulem_end:`、`\UL@stop`、`\UL@reskip`、`\@@_ulem_entry_*`、
  `\@@_boundary_use_ulem_glue_outer:nn`、`\@@_ulem_Boundary_and_FullLeft_glue:N`。
- 过程材料（本地）：`.llmdoc-tmp/investigations/1091-fntef-entry-space.md`、`tmp/i1091/`。
- 相关反思：[[1067-ulem-brace-group-ecglue-shrink]]（同一 ulem 片段盒子结构上的另一类问题）、
  [[1029-sbox-global-prefix]]（逐项变异的原始教训）、[[324-boundary-reserve-space-glue]]（入口空格语义）、
  [[1085-hfill-post-transparent-relocate]]（自动分析方向对、定位错的同型经历）。
