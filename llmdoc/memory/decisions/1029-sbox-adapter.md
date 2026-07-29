# 决策：`\sbox`／`\savebox` 改用专用适配器重定义内部入口，不再挂通用命令钩子

## 背景

Issue #1029：`ctexart` 加载 `algorithm2e[ruled]` 后，`algorithm` 环境里 `\caption` 生成的标题整段消失；发布版 TeX Live 正常，开发版完全没有这一行。报告者已定位到问题出在 xeCJK 注册的 `cmd/sbox/before`／`cmd/sbox/after` 两个 `\AddToHook` 钩子上，并给出 `\RemoveFromHook` 变通。

根因：`\global` 在 TeX 里是「等待下一个赋值」的前缀状态，不是立即生效的操作。`cmd/sbox/before` 钩子的代码插在命令本体（`\setbox`）执行之前运行；钩子内容 `\@@_boundary_capture_suspend:` 做了多个 `\int_gincr:N`／`\tl_gset:` 全局赋值，这些赋值先消耗掉调用方留下的待用 `\global` 前缀，于是调用方写的 `\global\sbox` 实际执行时已经没有 `\global`，退化为局部赋值。盒子在分组结束时按局部赋值规则被丢弃，全程不产生任何诊断信息。

`\savebox` 的三种形式（无可选参数、`[wd]`、`[wd][pos]`）最终都汇入同一个内部入口 `sbox `，因此适配器同样覆盖它们的排版路径；`\global\setbox` 不受影响，因为 `\global` 直接贴在 `\setbox` 原语前面，中间没有钩子代码可以插入的位置。

但要分清一件事：**`\global\savebox` 跨分组本来就不生效，与本包无关。** `\savebox` 是 robust 命令，`\global` 在它自己的 `\@ifnextchar` 前瞻阶段就被消耗，前缀根本到不了 `sbox `。实测未加载本包的原版 LaTeX 中三种形式全为 `0.0pt`（参考宽度分别为 57.85pt、142.26378pt、199.16928pt），加载修复后的本包结果完全相同。直接对内部入口加前缀可以区分两者：`\expandafter\global\csname sbox \endcsname` 成功，`\expandafter\global\csname savebox \endcsname` 仍失败。因此本次修复解决的是 `\global\sbox`（以及内部入口的前缀透明性）；`\global\savebox` 的失效是上游既有限制，不在修复范围内。

algorithm2e 的触发路径：`\algocf@makecaption@ruled` 用 `\global\sbox\algocf@capbox{...}` 在浮动体分组内保存标题，随后在分组外用 `\box\algocf@capbox` 输出；`\global` 被吃掉后标题盒子随分组一起消失。紧接 `\global\sbox` 之后取值是 308.11221pt，到使用点变成 0.0pt；发布版两处都是 308.11221pt。

最小复现不需要加载 xeCJK：`\AddToHook{cmd/sbox/before}[probe]{\advance\cnt by 1}` 单独就会触发同一问题；把钩子内容换成不含赋值的 `\relax` 则不会触发。这证明这是 LaTeX2e 命令钩子机制的通用陷阱，不是 xeCJK 或 `\sbox` 的特有缺陷。

## 为什么不采纳报告者的变通（删除两个钩子）

`cmd/sbox/before`／`cmd/sbox/after` 是 `6ac2839e`（#992 系列）刻意引入的：`\sbox` 只构造离线 scratch box 做测量，不应把测量内容报告成外层命令的可见输出；这两个钩子调用 `\@@_boundary_capture_suspend:`／`resume:`，暂停 capture 观察，防止测量用的盒子及其中的颜色切换污染外层的边界恢复链。

直接删除这两个钩子确实能让 algorithm2e 的标题恢复（因为不再有钩子代码消耗 `\global` 前缀），但会同时撤销 #992 引入的这层隔离，重新让 `\sbox` 内部的测量过程污染外层可见输出的间距判断。这不是可接受的代价——变通解决了报告的症状，却引入了曾经修复过的旧问题。

## 决定

保留 suspend/resume 隔离的语义，但换掉承载它的机制：新增 `\@@_boundary_sbox:Nn` 与 `\@@_boundary_prepare_sbox:`，把内部入口 `sbox ` 直接重定义为：

```
\tex_setbox:D #1 \tex_hbox:D { suspend … \color@setgroup #2 \color@endgroup … resume }
```

暂停观察被移到盒子构造内部执行，`\global` 前缀因此始终紧邻 `\setbox` 本身，中间不再插入任何钩子代码，也就不会有机会消耗前缀。原来的两个 `\AddToHook { cmd / sbox / before/after }` 被删除。

这与仓库已有的 `color@b@x`／`@textcolor` 专用适配器是同一套模式：命令边界注册框架里，`box`／`wrapped-box`／`stream`／`transparent`／`post-transparent` 五种策略默认走通用命令钩子，但对少数命令直接重定义其内部排版入口而不是挂钩子。这次确立的判据是：**注册的目标命令本体是赋值语句时，必须用专用适配器包装内部入口，不能用通用 `cmd/.../before` 钩子。**

## 受影响命令范围

- `\sbox`、`\savebox`（三种形式）：内部入口 `sbox `，本次直接修复。
- 理论上任何「命令本体自身是赋值语句」的命令都会踩同一坑，不限于取盒子相关的命令；但当前 xeCJK 内部注册的命令里，只有 `\sbox`／`\savebox` 属于这一类。

## 用户接口 `experiment/boundary-register` 的同类风险

`experiment/boundary-register` 的 `command` 策略允许用户把任意控制序列交给通用命令钩子注册。如果用户注册的目标命令本体也是赋值语句（例如用户自己包装的另一个取盒子宏），会复现同一坑：钩子里的赋值消耗掉调用方的 `\global`／`\long` 前缀，且不产生任何诊断。

已在 `xeCJK/xeCJK.dtx` 用户手册 `experiment/boundary-register` 选项说明处补充一段警告，提醒命令本体即赋值语句时不能用通用注册，需要用户自己实现专用适配器。接口本身没有新增检测机制去自动拒绝这类注册——通用钩子无法在注册时判断目标命令是否是赋值语句，也无法探测钩子内容是否含赋值；这是文档层警告而非代码层防护。

## 验证

- 新增回归 `xeCJK/testfiles/boundary-sbox-global01.lvt/.tlg`（6 项，各项使用独立的 savebox——共用一个盒子时前一项留下的全局值会被后一项读到，测试看似通过却没有断言任何东西）：
  - `\global\sbox` 跨分组保住内容（21.8pt）；
  - 直接对内部入口 `\csname sbox \endcsname` 加 `\global` 也保住内容（57.85pt），单独固定适配器的前缀透明性；
  - `\global\savebox` 跨分组**仍为** `0.0pt`，把上游既有限制一并固定，避免日后误判为本包回归；
  - 不带 `\global` 的普通 `\sbox` 仍是局部赋值；
  - 嵌套 `\sbox` 场景显式打印 `\g_@@_boundary_suspend_depth_int`（前后均为 0）；只报盒子尺寸发现不了深度泄漏；
  - `\hbox{中\fbox{\sbox\tb{中文}Alpha}文}` 与 `\hbox{中\fbox{Alpha}文}` 同宽（63.19998pt）。scratch box 里必须藏与外层不同的类别（西文正文里藏 CJK）才有判别力；写 `\sbox{english}` 不改变末类别，删掉隔离也照样通过。
- 三项判别力均以变异实测确认（各自 rc 1）：还原为两个通用钩子（outside 退化为 0.0pt）；删掉 `suspend`／`resume`（隐藏 CJK 场景出现 3.33pt 差值）；去掉 `\int_gdecr:N`（深度由 0 变 6）。
- 原 MWE（algorithm2e ruled 标题）验证恢复。
- xeCJK 全套 115 项、ctex 四引擎 185 项、`l3build doc`（244 页）通过。

## 相关资料

- Issue：#1029；受影响路径：`ctexart` + `algorithm2e[ruled]` 下的 `\caption`；发现的通用机制：LaTeX2e `\AddToHook` 前缀消耗陷阱。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\@@_boundary_sbox:Nn`、`\@@_boundary_prepare_sbox:`（取代 `cmd / sbox / before` / `after` 两个 `\AddToHook`）；`\changes` 记入 v3.10.5。
- 测试：`xeCJK/testfiles/boundary-sbox-global01.lvt/.tlg`。
- 架构：[[../../architecture/xecjk-architecture]] 「命令钩子与专用适配器的选择边界（#1029）」一节。
- 相关决策与反思：[[992-command-boundary-capture-register]]（钩子的历史引入原因）、[[1010-boundary-register-public-api]]（用户可见注册入口的边界）、[[../reflections/1029-sbox-global-prefix]]。
