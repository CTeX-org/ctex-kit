# 决策：西文词前的 `\CJKecglue` 改用可搬运通道（#1037）

## 背景

`ulem` 按源码空格把装饰正文切成定宽片段盒。落在盒内的 glue，收缩量被盒子固化，外层断行取不到，装饰段落因此溢出右边距。

这条机制在西文词两侧各有一处，#1026／PR #1035 只修了词后那半：

- 词后：正文经宏参数间接展开时，词右侧的 `\CJKecglue` 进片段盒。修法是保持正文为字面记号。
- 词前（本次）：`\@@_ulem_CJK_and_Boundary:w` 的前视吃掉源码空格后，`\@@_ulem_group_end:n` 依次执行 `\UL@stop`（关闭并输出上一片段盒）与 `\UL@start`（打开新盒），`CJK-space` marker 因此落在**新盒内部**；随后 `\@@_check_for_ecglue_aux:` 在该 marker 处补出的 ecglue 也就固化在盒内。

同一段落按深度统计 1.11pt ecglue（`depth>=3` 盒内／`depth2` 行上可用）：#1026 缺陷版 16／0，发布版 v3.10.3 与含 #1035 的 master 同为 8／6，本次修复后 0／14。#1026 资产里的 MWE 溢出量相应为 18.91pt → 4.47pt → 无溢出。

master 与发布版对该 MWE 的渲染逐像素相同，说明 #1035 没有引入新问题，它修回的发布版行为本身就带这条缺陷。

## 决定

新增入口 `\@@_use_ecglue_skip:`，替换 `\@@_check_for_ecglue_aux:` 中两处 `\skip_horizontal:N \l_@@_ecglue_skip`（`CJK`/`CJK-widow` 分支与 `CJK-space` 分支）。

- `xeCJK` 主体的默认实现就是原来的 `\skip_horizontal:N \l_@@_ecglue_skip`，行为不变。
- `xeCJKfntef` 加载时用 `\cs_gset_protected:Npn` 把它改写为经 `\@@_ulem_glue:n` 输出。

`\@@_ulem_glue:n` 在下划线状态下先 `\UL@stop` 关闭当前片段盒、把间距画成外层列表上的 `\leaders`、再 `\UL@start` 开新盒，收缩量因此回到行上；它自带 `\xeCJK_if_ulem_patch:TF` 与 group tag 守卫，不在装饰中时退化为普通 `\skip_horizontal:n`，所以非 ulem 路径不受影响。

## 为什么不用 `\@@_boundary_use_ulem_glue:n`

它同样能把 glue 搬到外层（放裸 glue），节点深度上与 `\@@_ulem_glue:n` 等效。但裸 glue 不画装饰线，会在西文词前留下可见空隙——300dpi 下实测断开 7px。

改用 `\@@_ulem_glue:n` 后，单行样例与修复前渲染逐像素相同（差异 bbox 为 `None`），即收缩量搬出去而外观不变。

## 为什么默认实现放在主体、改写放在 xeCJKfntef

`\@@_ulem_glue:n` 定义在 `xeCJKfntef` 里。`\@@_check_for_ecglue_aux:` 是**所有** CJK-西文边界都走的通用路径，若在主体里直接引用该函数，不加载 `xeCJKfntef` 的普通文档会立刻 `Undefined control sequence`（已实测）。因此主体只放默认实现，由子包改写入口。

## 测试

`fntef-shrink01` 的判据从「溢出恰为 3.64pt」改为「无 `Overfull` 记录」。原判据把残留缺陷冻结成了预期基线——四个用例各固定一条 3.64pt 的 `Overfull` 行，等于替同源的另一半缺陷背书。注释同时写明溢出量随修复进度的三个取值（18.08pt / 3.64pt / 无）。

新增 TEST 6 作正向断言：`\badness` 观察压窄后的可收缩量。**不能用 `\hbox to` 的实际宽度**——它恒等于目标宽度，与收缩量在哪里无关，是结构上恒真的断言。压窄 2pt 落在「只修词后」的 1.11pt 与「两半都修」的 2.22pt 之间，正好分开两种实现；另加 1pt／5pt 对照证明 0 不恒真、1000000 可达。

判别力已实测（rc 1）：把 `\@@_use_ecglue_skip:` 改回 `\skip_horizontal:N` 后，TEST 6 的 2pt badness 由 73 变 1000000，且前四项的 `Overfull` 行全部回到基线。

## 已接受的限制

#1026 记录的「重排交还的那枚空格仍在片段盒内」（1.11pt）不在本次范围。本次只改补 ecglue 的通道，不涉及重排路径剥离／交还源码空格的逻辑；TEST 5 的节点列表与宽度差在修复前后逐字节相同，可佐证重排路径未被触及。该限制的可观察影响仍按 #1026 的判断为零。

`\UL@onin` 分支仍无回归保护，本次未改变。

## 验证

- xeCJK 115／115、ctex 四引擎 185／185。
- #1026 资产 MWE：4.47pt → 无溢出；首行右端 ink 由 681px 回到与其余行一致的 671px。
- 跨 issue 重放：#992 的四个矩阵驱动共 573 单元在修复前后逐项相同（含 7 项既有的 `ref/` 失败，两侧为同一批）。
- 只加载 `xeCJK`（无 `xeCJKfntef`）的最小文档无错误。

## 相关资料

- 反思：[[../reflections/1037-ulem-word-front-ecglue]]
- 前半修复：[[1026-ulem-literal-body]]；重排语义来源：[[1002-inline-math-boundary-oracle]]
- 实现：`xeCJK/xeCJK.dtx` 的 `\@@_use_ecglue_skip:`、`\@@_check_for_ecglue_aux:`、`\@@_ulem_glue:n`
