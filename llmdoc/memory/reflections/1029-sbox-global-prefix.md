---
name: 1029-sbox-global-prefix
description: 记录 #1029 中 \sbox/\savebox 挂在 cmd/sbox/before 钩子上导致 \global 前缀被静默吃掉、algorithm2e ruled 标题消失的根因，以及把它缩到不含本包的五行 LaTeX 复现的过程
metadata:
  type: feedback
---

# [Task Reflection]

## Task

Issue #1029：`ctexart` + `algorithm2e[ruled]` 下，`algorithm` 环境里 `\caption` 生成的标题整段不显示；发布版 TeX Live 正常，开发版完全没有这一行。报告者已定位到 `cmd/sbox/before`／`cmd/sbox/after` 两个钩子，并给出 `\RemoveFromHook` 变通。

修复：新增 `\@@_boundary_sbox:Nn` 与 `\@@_boundary_prepare_sbox:`，把内部入口 `sbox ` 直接重定义为 `\tex_setbox:D #1 \tex_hbox:D { suspend … \color@setgroup #2 \color@endgroup … resume }`，删掉原来的 `\AddToHook { cmd / sbox / before/after }`，把暂停观察移到盒子内部；这与仓库已有的 `color@b@x`／`@textcolor` 专用适配器是同一套模式。新增回归 `xeCJK/testfiles/boundary-sbox-global01.lvt/.tlg`（6 项），并在 `xeCJK.dtx` 的用户手册（`experiment/boundary-register` 说明附近）与 `\changes` 里补充了这条约束。

## Expected vs Actual

- 预期：既然报告者已经定位到两个钩子并给出可用变通，任务重点应是判断能否直接采纳变通（删钩子）。
- 实际：变通不能直接当修复——两个钩子的存在是 `6ac2839e`（#992 系列）刻意引入的，用来隔离 `\sbox` 内部 scratch box 的测量过程，防止它污染外层边界恢复链；直接删除会撤销这条隔离，需要换一种实现方式保留同一语义。
- 预期：根因可能与 xeCJK 自身的某个状态归零逻辑有关。
- 实际：根因是 LaTeX 命令钩子机制本身的通用陷阱——与本包无关。把复现缩到不加载 xeCJK 的五行纯 LaTeX 后才确认：`\AddToHook{cmd/sbox/before}` 里只要有一条赋值语句（不需要与盒子相关），就会吃掉调用方 `\global\sbox` 的 `\global` 前缀，盒子在分组结束时静默丢失，不报错不警告；只挂 `\relax`（无赋值）则不触发。

## What Went Wrong

未发生需要回退或重写的失误；此处记录的是定位过程中的关键转折，供以后遇到类似“钩子相关但报告已给出定位”的 issue 参考。

1. **报告者的定位是对的，但止步于“删钩子能解决”容易被直接采纳为修复。** 若不去核实两个钩子的历史用途，会在不知不觉中撤销 #992 引入的 scratch box 隔离，重新引入旧问题（`\sbox` 内容污染外层间距、颜色切换泄漏）。
2. **必须把复现缩到不含本包的最小示例，才能确认这是通用陷阱而不是 xeCJK 特有 bug。** 缩小前只知道“xeCJK 的 sbox 钩子导致标题消失”，容易把注意力放在 xeCJK 钩子内容本身；缩小到纯 LaTeX 五行后才看清触发条件是「`cmd/<赋值命令>/before` 钩子里有赋值」这一更一般的机制，这个认识直接决定了修复形态（专用适配器 vs 调整钩子内容）以及要不要在用户接口文档里加警告。
3. **失败完全静默，容易被误判为下游包自身问题。** 没有报错、没有警告，只是盒子变空；如果没有与发布版逐项对比数值（紧接 `\global\sbox` 之后 vs 使用点，308.11221pt 对比 0.0pt），很容易把这个问题归咎于 algorithm2e 而不是 xeCJK。

## 审查发现的自检缺口

第一版回归和随之写下的文档都有实质问题，全部由独立盲审发现：

1. **三项共用同一个 savebox，两项因此没有断言任何东西。** 它们读到的是第一项留下的 21.8pt；把内容换成明显更宽的字符串，读数纹丝不动。`[3cm][l]` 那项的期望值本应是 85.35826pt。缺陷版下这两项出现 0.0pt，也只是第一项失败的连带结果。
2. **「四种 `\global` 形式跨分组保住内容」这句话是错的。** 实测纯 LaTeX 下三种 `\global\savebox` 全为 0.0pt——`\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，与本包无关；加载修复后的本包结果完全相同。真正修好的只有 `\global\sbox`（以及内部入口的前缀透明性）。我没有在不加载本包的环境里先测一遍，就把上游的既有限制写成了本次修复的成果，三处文档同时错了。而且「四种」里的 `[wd]` 单参数形式在 `.lvt` 里根本没测。
3. **两项声称的判别力都不存在。** 去掉 `\int_gdecr:N`（深度永不归零）后测试仍全绿，因为该项只报盒子尺寸、从未打印深度；删掉整对 suspend／resume 后 TEST 6 也全绿，因为 `\sbox{english}` 不改变末类别。真正能拦住撤销隔离的是既有的 `command-boundary01` 的 `scratch-hidden-CJK`——scratch box 里必须藏与外层不同的类别才有判别力。

这三条与 #1026 的教训同源但更进一步：那次学到「要用变异实测确认测试会红」，这次的问题是**变异确实让整个文件变红了，但红的是另一项**。共用全局对象时，一项失败会连带压垮其后各项的读数，整体 rc 1 掩盖了「每一项各自是否有判别力」这个更细的问题。逐项变异（只破坏该项声称守护的那一条）才能暴露它。

## Root Cause

`\global` 在 TeX 里是「等待下一个赋值」的前缀状态，不是立即生效的操作。`cmd/<命令>/before` 钩子的代码插在命令本体（这里是 `\setbox`）执行之前运行；如果钩子内容本身包含任何赋值（`\int_gincr:N`、`\tl_gset:` 等），这条赋值会先消耗掉调用方留下的待用 `\global` 前缀，于是调用方写的 `\global\sbox` 实际执行时已经没有 `\global` 了，退化为局部赋值。盒子在分组结束时按局部赋值规则被丢弃，整个过程不产生任何诊断信息。

xeCJK 的 `cmd/sbox/before` 钩子内容是 `\@@_boundary_capture_suspend:`，其中做了多个全局赋值，正是这类触发条件。

`\savebox` 的三种形式（无可选参数、`[wd]`、`[wd][pos]`）最终都汇入同一个 `sbox ` 内部入口，因此同样受影响；`\global\setbox` 不受影响，因为 `\global` 直接贴在 `\setbox` 前面，中间没有钩子代码插入的空间。

algorithm2e 的触发路径：`\algocf@makecaption@ruled` 用 `\global\sbox\algocf@capbox{...}` 在浮动体分组内保存标题，随后在分组外用 `\box\algocf@capbox` 输出；`\global` 被吃掉后标题盒子随分组一起消失。

## Missing Docs or Signals

- 在本次修复之前，`xecjk-architecture.md` 只记录了 `\sbox` 的 suspend/resume 隔离机制本身，没有说明「命令本身就是一条赋值语句」这类命令为什么不能用通用 `AddToHook` 注册——这条约束不是 xeCJK 特有的，是 LaTeX 命令钩子机制的通用陷阱，值得作为一条独立的机制边界记录，而不是只出现在 `\sbox` 这一个具体案例的注释里。
- `experiment/boundary-register` 面向专家用户开放了注册入口，但在这次修复之前没有提醒用户「如果你要注册自己的‘保存盒子’类命令（命令本身即赋值语句），通用注册会踩同一个坑」。本次已在 `xeCJK.dtx` 用户手册对应段落补了一句提醒，需要 recorder 同步到 `xecjk-architecture.md`（如果该文档以后要收录这类接口限制清单）。
- `build-and-test.md` 目前列出的 `boundary-register-api01/02` 等测试条目里没有 `\sbox` 这条注册策略专用适配器的入口，本次新增的 `boundary-sbox-global01` 尚未被主文档引用（仅在本反思和 CHANGELOG 中提及）。

## Promotion Candidates

- **通用命令钩子（`cmd/<命令>/before`）不能用于命令本体自身就是赋值语句的场景。** 钩子代码在命令执行前运行；钩子内任何赋值都会消耗调用方待用的 `\global`／`\long` 等前缀，使调用方的前缀静默失效，不产生任何诊断信息。这是 LaTeX2e `\AddToHook` 机制的通用性质，不限于 `\sbox` 或 xeCJK，值得写进 `reference/coding-conventions.md` 或架构文档的机制边界小节，供任何未来用命令钩子包装赋值类命令的场景参考。
- **专用适配器（直接重定义内部入口）是命令钩子的正确替代方案，且仓库已有先例可以复用。** `color@b@x`／`@textcolor` 已经采用「保留原内部入口 + 包装重定义」模式；本次 `\sbox` 用同一模式解决了钩子不适用的场景，说明这是命令边界注册框架里「通用钩子 vs 专用适配器」两种策略选择的一条通用判据：命令本体是赋值语句时选后者。
- **诊断这类静默失败，要在紧接赋值之后与实际使用点分别取值对比，并与发布版逐项核对。** 没有报错信号时，唯一可靠证据是数值本身（这里是 308.11221pt vs 0.0pt）；仅靠现象描述容易把问题误判到调用方（algorithm2e）身上。
- **报告者给出的可用变通不能替代对该代码历史用途的核实。** 变通（`\RemoveFromHook`）能让当前场景可用，但会撤销 #992 刻意引入的 scratch box 隔离；正确流程是先确认该代码的既有职责（读决策文档或提交历史），再判断是保留语义换实现，还是采纳变通。

## Follow-up

- recorder 同步 `xecjk-architecture.md` 时，补充「命令本身即赋值语句的场景不能用通用 `AddToHook` 钩子，需要专用适配器包装内部入口」这条机制边界，并关联本反思与决策 `992-command-boundary-capture-register`（钩子历史用途）。
- recorder 补充 `build-and-test.md`，把 `boundary-sbox-global01.lvt/.tlg` 的覆盖范围（四种 `\global` 形式、不带 `\global` 仍局部、嵌套 `\sbox`、暂停观察语义）纳入 xeCJK 测试清单。
- 若后续要为 `experiment/boundary-register` 的用户手册系统整理「哪些命令模式不适合通用注册」的清单，可以把「命令本身是赋值语句」列为第一条，本次已在手册里补了单段提醒。

## 相关

- Issue：#1029；受影响路径：`ctexart` + `algorithm2e[ruled]` 下的 `\caption`；发现的通用机制：LaTeX2e `\AddToHook` 前缀消耗陷阱。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_boundary_sbox:Nn`、`\@@_boundary_prepare_sbox:`（取代 `cmd / sbox / before` / `after` 两个 `\AddToHook`）；`\changes` 记入 v3.10.5。
- 测试：`xeCJK/testfiles/boundary-sbox-global01.lvt/.tlg`。
- 架构：`llmdoc/architecture/xecjk-architecture.md` 「边界状态与装饰盒隔离（#826/#830/#992）」一节（`\sbox` 隔离机制的既有记录）。
- 相关决策：`llmdoc/memory/decisions/992-command-boundary-capture-register.md`（钩子的历史引入原因）、`llmdoc/memory/decisions/1010-boundary-register-public-api.md`（用户可见注册入口的边界）。
