# 决策：ulem 正文按语法分派，只在必要时重排，其余保持字面记号

## 背景

`xeCJK-v3.10.5-rc1` 之后，`\CJKunderline`／`\CJKunderwave`／`\CJKunderanyline*` 等装饰在换行时右边界不对齐。真正的引入提交是 `494d5a72`（属于 #1002 系列），不是当时最先被怀疑、时间上更晚的 #1012 周期装饰改动。

`494d5a72` 把 `\UL@on` 的替换文本从字面记号：

```
\xeCJK_ulem_left: #1 \@@_boundary_math_end:n {#1}
```

改成了统一走宏参数间接展开：

```
\xeCJK_ulem_left: \@@_boundary_ulem_math_body:n {#1}
```

这个改动的本意只是为了让“公式尾＋尾随源码空格”这一种边界情况能在正文排完、外层包装尚未关闭时正确确认公式节点（见决策 [[1002-inline-math-boundary-oracle]]）。但它把**全部**正文都改成了参数间接展开，波及了不需要重排的普通场景。

`ulem` 自己扫描正文，按源码空格把它切成固定宽度的装饰片段盒（每个片段各自一个盒子）。正文一旦经过宏参数间接展开，西文词右侧由边界恢复链补出的 `\CJKecglue` 就会落在片段盒**内部**，其收缩量被盒子固化，无法参与外层段落的断行决策。节点证据（`\showbox` 深度）：基线中 ecglue 在深度 1（片段之间）是 `\cleaders 5.32997 plus 1.665 minus 1.11`；缺陷版中同一枚 ecglue 落在深度 2（片段盒内部），变成 `\cleaders 1.99997 plus 0.96002`，没有 `minus`。两者自然宽度相同（328.08pt），深度 1 的可收缩总量从 17.22pt 降到 15.00pt，差值正好等于西文词数 × 每词 1.11pt。

## 为什么不直接回退 `494d5a72`

`494d5a72` 同时也是 #1002 公式尾随空格修复的一部分：把正文改成参数间接展开是让确认代码能在正文排完、外层包装尚未关闭时检查末尾真实公式节点的必要前提。直接回退会同时撤销这项修复，重新让“公式尾＋尾随源码空格”这一种边界情况无法正确确认公式类别。

## 决定

`\UL@on` 与 `\UL@onin` 改为先用新增的 `\@@_boundary_if_ulem_math_reorder:nTF` 判断正文语法，再按语法分派到两条路径：

- 正文以“公式尾＋尾随源码空格”结尾（`\@@_boundary_if_math_tail:nTF` 与 `\@@_boundary_if_math_tail_space:nTF` 同时成立）：用 `\@@_boundary_ulem_math_tail_space:nnn` 重排——先扣掉尾随空格排正文，让公式节点在被空格遮住之前完成确认，再把一枚空格交还 `ulem` 排版。这条路径保留 #1002 的修复。
- 其余全部情况：保持 `\xeCJK_ulem_left: #1 \@@_boundary_math_end:n {#1}` 的字面展开，`#1` 原样留在替换文本里。

关键点是**两条路径都不能让正文多经一层宏参数**。重排路径起初仍把正文交给一个辅助宏的参数，因而在这条路径上原封不动地保留了同一个收缩量缺陷：正文只要既含西文词、又以“公式＋尾随空格”结尾，就同时满足“走重排”和“需要 `\CJKecglue`”两个条件，实测溢出量与修复前完全相同（18.08pt）。现在改为先由 `\@@_boundary_ulem_math_tail_space:nnn` 把去掉尾随空格的正文与两端固定记号拼进 `\l_@@_ulem_body_tl`，再用 `\exp_args:NV` 一次展开到 `ulem` 的参数位置，使记号与直接书写 `#1` 等价。不能改用 `\tl_use:N`，那会让正文晚一层展开而重新触发同一问题。

原来统一处理两种情况的 `\@@_boundary_ulem_math_body:n` 由这两个函数取代。`\UL@onin`（嵌套 ulem 命令入口）采用相同的分派逻辑；由于两端的 `\xeCJK_ulem_left:`／`\xeCJK_ulem_right:` 只有 `\UL@on` 需要，拼装函数把它们作为前后缀参数接收，不写死在 body 里。

这条约束比 #1002 的公式候选确认更基础，属于 ulem 集成层的通用规则：**`ulem`／`xeCJKfntef` 等自行扫描正文并切片装盒的机制，只应对正文使用字面记号；确需重排某种特殊语法时，重排本身也必须把正文以字面记号送进参数位置，不能为了少数情况把这部分正文改成间接展开。**

## 已接受的既有限制

调用处把正文写成宏再传入，例如 `\CJKunderline{\BODY}`，收缩量同样进不了外层：宏体在 `ulem` 扫描期间才展开，触发的是同一条“正文经间接展开→收缩量固化在片段盒内”的机制，只是成因是用户写法而不是 `\UL@on` 的替换文本本身。

判断依据：实测发布版本（系统 TeX Live 的 xeCJK，不含本次改动）对这种写法同样得到修复前的溢出宽度（18.08pt）。这说明它是发布版本本来就有的既有限制，不是本次回归引入的缺陷，因此不在 #1026 的修复范围内。若后续要修复这条限制，需要新开 issue。

这条限制决定了回归测试的写法：测试必须在调用处写字面正文，不能用宏承载正文，否则会把这条已知限制误判成本次修复的验证对象（前三版测试草案正是在这一点和“单盒子测不出断行差异”这一点上都踩了坑，见反思 [[../reflections/1026-ulem-literal-body-outer-shrink]]）。

## 验证

新增 `xeCJK/testfiles/fntef-shrink01.lvt/.tlg`，覆盖 `\CJKunderline`、`\CJKunderwave`、带减号形式，以及“公式＋尾随源码空格”仍走重排路径的反例。测试在 document 主垂直列表里让 `\hsize=200pt` 的段落真正断行，只固定行盒尺寸与 glue set；缺陷存在时首行溢出 18.08pt，修复后为 3.64pt。已用重新引入缺陷的方式确认测试会失败（详见 [[../reflections/1026-ulem-literal-body-outer-shrink]] 的载体选择教训）。xeCJK 全套 114 项通过。

## 相关资料

- Issue：#1026；引入提交：`494d5a72`（属于 #1002 系列）；受影响版本：`xeCJK-v3.10.5-rc1`（未发布的 rc）。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\UL@on`、`\UL@onin`、`\@@_boundary_if_ulem_math_reorder:nTF`、`\@@_boundary_ulem_math_tail_space:n`；`\changes` 记入 v3.10.5。
- 测试：`xeCJK/testfiles/fntef-shrink01.lvt/.tlg`。
- 架构：[[../../architecture/xecjk-architecture]] 「ulem 集成层的正文必须以字面记号留在替换文本里」一节。
- 相关决策与反思：[[1002-inline-math-boundary-oracle]]、[[../reflections/1026-ulem-literal-body-outer-shrink]]、[[1012-fntef-decoration-overlap]]（本次最初被误判为引入点的相关工作）。
