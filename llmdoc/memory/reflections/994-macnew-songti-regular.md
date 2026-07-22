# Issue #994：macnew 宋体常规字重调整反思

## 任务

- 调整 `fontset=macnew` 的正文宋体：常规直立字形从 `Songti SC Light`
  （字重 300）改为 `Songti SC Regular`（字重 400），粗体仍使用
  `Songti SC Bold`。
- 选择以 `fontset=ubuntu` 使用的 Noto Serif CJK SC 常规字重为参照；从字重
  而言，`Songti SC Regular` 与该参照更接近。
- 同步所有会决定实际字形或依赖字形度量的路径，并增加能区分“配置写对了”和
  “平台上实际加载了目标字形”的回归测试。
- 本项变更登记在 ctex v2.6.4，而不是已经发布的 v2.6.3。

## 预期与实际

预期上，这项改动像是把字体名中的 `Light` 换成 `Regular`。实际维护范围比字体名
更广：同一个正文角色在不同引擎和输出路径下使用不同的字体标识，标点压缩还依赖
所选字形的实际边界数据。只改 XeTeX 或 LuaTeX 的具名字体会使其他路径继续使用
Light，沿用旧的标点边界数据（SPA）则会让标点压缩使用错误的度量。

最终同步范围包括：

- XeTeX 与 LuaTeX 的具名字体都改为 `Songti SC Regular`；
- LaTeX+DVI 与 upLaTeX 的 `Songti.ttc` 字形索引从 3 改为 6，其中 index 3
  是简体中文 Light，index 6 是简体中文 Regular；
- 生成的 `ctex-zhmap-mac.tex` 中六处常规宋体映射都改用 index 6；
- SPA 生成源中的 `maczhsong` 改为 `Songti SC Regular`；
- `ctexpunct.spa` 的 `maczhsong` 数据在 macOS 上加载 Regular 后重新测量；
- 用户手册、`CHANGELOG.md` 和 `llmdoc/reference/ctex-fontset-mac.md` 与实现保持
  一致。

这次任务还说明，“四引擎本地测试通过”与“Apple 字体已经实际加载”是两件事。
Linux 服务器没有 `Songti SC` 等 Apple 字体，因此本地测试只能检查解包后的字体集、
TTC 索引、zhmap 映射、SPA 生成源和跨平台 `.tlg` 基线。macOS 专属分支在 Linux
上按设计跳过，本地绿色结果不能用来声称实际字体加载已经通过。

## 测试证据如何收紧

### XeTeX

macOS XeTeX 测试不只调用字体设置命令。它用 `\font` 直接加载
`Songti SC Regular`，再对标点序列逐字调用 `\XeTeXcharglyph` 和
`\XeTeXglyphbounds`，现场生成 `maczhsong` 数据并与仓库跟踪的
`ctexpunct.spa` 比较。字体找不到、字形映射不同或边界数据不同都会使测试失败。

这样得到的是“这个 runner 上的 Regular 字形实际产生了跟踪数据”的证据，而不是
仅检查源文件中出现了正确的字体名。Regular 与 Light 的标点边界确实不同，因此
更换正文常规字形时，SPA 数据必须随字体一起更新。

### LuaTeX

LuaTeX 的第一版检查只执行 `\setCJKmainfont{Songti SC Regular}`。这只能说明字体族
声明阶段没有立即报错；字体可能按需加载，所以它不足以证明正文中文字形实际来自
Regular。

收紧后的测试先排出一个中文字形，再从字形（glyph）节点取得字体对象，核对 `fullname`
或 PostScript 字体名是否分别为 `Songti SC Regular` 或
`SongtiSC-Regular`。这项检查还遇到两个容易漏掉的实现细节：

- LuaTeX-ja 可能把中文字形放进嵌套的 `hlist`，而不是放在外层盒子的顶层节点
  列表中。只遍历顶层 glyph 会错误地报告“没有找到字形”，探针必须递归进入
  `hlist` 和 `vlist` 的内部列表。
- 在 `\ExplSyntaxOn` 下扫描宏定义时，源码中的普通空格会被忽略。函数执行时再改
  空格类别码，无法恢复定义阶段已经丢失的空格。嵌入 Lua 代码时应以 expl3 的
  `~` 明确生成所需空格，并用分号明确分隔 Lua 语句，防止 TeX 扫描后的记号粘连。

## 出现的问题

- 最初把平台专属字体测试写得过宽，直接输入完整 `macnew` 配置；这会同时触发与
  本项无关、需要另行下载的（downloadable）可选字体探测。macOS CI 的失败迫使
  测试收窄到本次改变的 `Songti SC Regular`，而生成配置仍由独立断言覆盖。
- 第一版 SPA 回归现场测出了 Regular 的数据，却仍与 Light 的旧跟踪数据比较。
  这个失败不是环境噪声，而是提醒我们：字体字形改变后，度量数据也是实现的一部分。
- 后来虽然给 LuaTeX 增加了字体元数据断言，但最初的探针仍存在两个阻塞问题：Lua
  代码在宏定义时丢失普通空格，以及只检查顶层节点、看不到 LuaTeX-ja 嵌套盒子里的
  glyph。两项问题都已分别通过显式空格与语句分隔、递归遍历节点列表修复。
- 首轮上下文隔离审查还发现专项 llmdoc 仍把正文宋体写成 Light。实现、测试和
  用户手册已经更新，不代表维护者参考会自动保持一致；该重要问题也已修复。

## 根因

- 对“测试通过”的证据范围描述得过宽。Linux 上执行同一个 `.lvt` 文件，并不表示
  其中由 macOS 条件保护的分支已经运行。
- 把字体族声明成功等同于目标字形已经参与排版，没有考虑 LuaTeX/fontspec 的按需
  加载行为。
- 把 TeX 盒子想成只有一层节点列表，没有先检查 LuaTeX-ja 的真实节点结构。
- 在 expl3 宏定义中嵌入 Lua 时，只考虑函数调用时的类别码，没有考虑宏定义被扫描
  时普通空格就已经消失。
- 把字体选择看成单一名称映射，没有在开始时列出具名字体、TTC index、zhmap 和
  SPA 数据这几类相互独立的事实源。

## 审查与修正过程

用户追问“服务器是否有这些字体、回归是否真的测得到”后，原来只写“实际加载”的
说法被拆成了可核对的两层证据：Linux 配置检查与 macOS 字体运行时检查。随后 macOS
CI 的连续失败暴露了平台专属路径中的问题，上下文隔离的独立审查又用同构 LuaTeX-ja
探针确认了空格丢失和嵌套节点这两项阻塞问题。两项阻塞发现都已修复，后续独立增量
审查也没有在修复范围内发现新的大、中、小问题。

这次过程的价值不只是多补了两个测试细节。独立审查没有接受“Linux 四引擎绿色”这
一间接证据，而是检查 macOS 条件分支是否真的能执行；也没有接受“声明了字体族”这
一较弱证据，而是要求实际排出字形并确认其字体身份。对于平台专属字体，这种证据
强度应当成为后续工作的起点。

## 缺失的文档或提示

- 稳定文档应明确区分生成配置检查、字体解析检查、实际字形检查和字形度量检查；
  不同层次的绿色结果不能互相替代。
- 字体集维护说明应给出正文角色的同步清单：具名字体、TTC index、zhmap、SPA
  生成源、跟踪的 SPA 数据、手册和变更记录。
- LuaTeX 测试说明应提醒维护者先检查真实节点结构；LuaTeX-ja 的 CJK glyph 可能
  位于嵌套盒子中。
- expl3 编码约定应覆盖“在 `\ExplSyntaxOn` 宏定义里嵌入 Lua”的情况，说明普通
  空格在定义扫描阶段丢失，以及 `~` 和明确语句分隔符的用途。

## 适合提升为稳定文档的候选

- `llmdoc/reference/ctex-fontset-mac.md`：补充 macOS 专属字体回归的证据分层，以及
  更换正文常规字形时必须同步的各后端映射和 SPA 数据清单。
- `llmdoc/reference/build-and-test.md`：记录平台条件测试的陈述边界；只有实际执行了
  对应条件分支，才能声称平台专属行为通过。对按需加载字体，应排出字形并核对
  字体元数据。
- `llmdoc/reference/coding-conventions.md`：记录 `\ExplSyntaxOn` 下嵌入 Lua 的空格
  与语句分隔规则。
- `llmdoc/memory/lessons-learned.md`：提炼“测试结果的结论不能超出实际执行分支”以及
  “字体变化需要同步选择、映射和度量数据”两条跨任务规则。

本反思只记录本轮经验，不替代上述稳定文档的正式更新。

## 后续动作

- 由 recorder 判断并落实上述稳定文档候选，再检查 `llmdoc/index.md` 的路由摘要
  是否需要同步。
- 以后修改平台专属字体时，先写出各引擎事实源和可执行环境，再分别安排静态配置
  检查、实际 glyph 检查和度量比较；最终说明中逐项写清每类证据在哪里运行。
