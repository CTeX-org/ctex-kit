---
name: 1068-selectfont-resets-ccglue
description: 记录 #1068 修复 \selectfont 经 \ctex_update_stretch: 的 auxiii 分支重置用户已设汉字间距的问题；核心教训是报告只提了 LuaTeX、实际 upTeX 同样受影响（缺陷按代码路径分布，不按报告者用的引擎分布），以及第一版分析把「auxiii 缺少守卫」误诊成「需要新写」，而 grep 全仓后发现守卫早已存在于 engine 层、只是被 docstrip 条件挡在两个引擎之外，真实修法是删两行守卫标记而非新增代码
metadata:
  type: feedback
---

# 反思：#1068 `\selectfont` 重置用户已设汉字间距，与「守卫存在但未被调用」

## 任务

Issue #1068：LuaLaTeX 下经 `ctex` 路由到 `luatexja` 时，用户设的
`\ltjsetparameter{kanjiskip={10pt plus 1pt minus 1pt}}` 会被随后的 `\selectfont` 重置成
`0.0pt plus 0.60931pt`；直接用 `luatexja`（不经 `ctex`）不会。任务是定位根因并修复。

## 结论与实现

修好了。根因在 `ctex/ctex-engine.dtx` 的一段 `\ctex_at_end:n`，它重定义
`\@@_update_stretch_auxii:` 并加上 `\ctex_if_ccglue_touched:` 守卫——但这段原先被
docstrip 守卫限定在 `%<*pdftex|xetex>` 里，LuaTeX 与 upTeX 都没有它。

调用链：`\selectfont` → `\ctex_update_size:` → `\ctex_update_stretch:`，后者按
`linestretch` 是否为 `\maxdimen` 二分：

- `linestretch = \maxdimen` 时走 `\@@_update_stretch_auxi:`，该支自带
  `\ctex_if_ccglue_touched:TF` 守卫；
- 否则走 `\@@_update_stretch_auxiii:`，无守卫、直接重设间距并调用
  `\ctex_update_ccglue:`。

默认 `linestretch` 是 `\ccwd`（实测 10.53937pt）而非 `\maxdimen`，所以实际走的是后一支
——那段被限定引擎的重定义正是给后一支补守卫的地方。LuaTeX 与 upTeX 因缺了它，用户的
`kanjiskip` 会在每次 `\selectfont` 时被无条件冲掉。

判据：解包产物里 `\@@_update_stretch_auxii:` 重定义的出现次数。修好前
`ctex-engine-xetex.def` 有 1 处，`ctex-engine-luatex.def` 与 `ctex-engine-uptex.def`
都是 0 处；修好后五个引擎（含 aptex）都是 1 处。

修法：去掉那段的 `%<*pdftex|xetex>` / `%</pdftex|xetex>` 守卫，让它对所有引擎生效。
`\ctex_if_ccglue_touched:` 本身三套引擎实现都已存在（pdftex/xetex 比较 `\CJKglue`
是否仍与 `\@@_ccglue:` 同义，LuaTeX 与 upTeX 比较 `\l_@@_ccglue_skip` 与引擎参数是否
相等），缺的只是调用它的位置。紧邻的上一行
`%<pdftex|xetex>\ctex_at_end:n { \cs_new_eq:NN \@@_ccglue: \CJKglue }` 未动——
`\@@_ccglue:` 只是 pdftex/xetex 那套守卫实现的比较对象，与 LuaTeX/upTeX 的实现无关。

效果：LuaTeX 与 upTeX 下用户设置保住；未设置时仍随字号更新（实测
0.60931 → 2.89365 → 0.60931）；xetex/pdftex 行为不变（实测）。

## 核心教训：报告只提了 LuaTeX，实际 upTeX 也坏

报告者只在 LuaLaTeX 下复现。按引擎逐个实测后发现 upTeX 同样受影响，pdftex/xetex 正常。

`llmdoc/memory/lessons-learned.md` 已有「测试结论不能超出实际执行的平台分支」
（Source：#994）这条规则，但那次说的是「测试通过不能声称覆盖了未执行的分支」；这次
是它的另一面——**缺陷本身也是按「代码路径」分布的，不是按报告者用的引擎分布**。这个
仓库里 docstrip 守卫（`%<*engine>`）划出的就是路径边界，看到守卫就要把它枚举的引擎
和没枚举的引擎都测一遍，不能只信报告者用的那一个。

`ctex/build.lua` 固定 `checkengines = {"pdftex", "xetex", "luatex", "uptex"}`，四引擎
本就是这个包的常规回归范围；但常规回归范围管的是「新增测试要在哪些引擎上跑」，不会
主动提示「这个 issue 复现的缺陷有没有可能在其他引擎上以不同形式存在」——这是分析
阶段需要主动做的一步，工具不会替你做。

## 教训：守卫「存在」不等于守卫「被调用」

第一版分析（`tmp/i1068/findings.md`）的结论是「`auxiii` 那条路径上没有守卫，应当补一个」，
据此设计了方案 A（在 `auxiii` 内加守卫）与方案 C（把守卫提到 `\ctex_update_stretch:`
顶层）。这个结论方向对（那条路径确实缺一次守卫调用），但定位错：守卫早已存在于 engine
层（`ctex-engine.dtx` 里那段 `\ctex_at_end:n`），只是 docstrip 条件把它挡在两个引擎
之外。真实修法只需删两行守卫标记，而不是在 kernel 层新写一份等价逻辑。

方案 A／C 与最终修法在行为上完全等价（`tmp/i1068/findings.md` 里的实测表格显示两者
读数逐字节相同），如果真的采用 A 或 C，会在 kernel 层新增一份与 engine 层语义重复的
守卫，属于「发现『某处缺少检查』时没有先搜索该检查是否已在别处存在」的具体例子。

这与 `llmdoc/memory/lessons-learned.md` 的「排查上游问题前先查本仓库 `llmdoc/` 是否
已有根因记录」是同一条规则换了检索对象——那条说的是「先查文档」，这次是「先查代码」：
发现「某处缺少某个检查」时，先在全仓搜索该检查的实现是否已在别处存在（这次是
`grep -n "ctex_if_ccglue_touched" ctex/*.dtx` 就能看到 engine 层那份三引擎分支的完整
实现），再决定是调用既有实现还是新写一份。若照方案 A/C 动手，就会得到两份语义重复的
守卫，且日后两份实现分叉时无人能立刻看出它们本该同步。

## 教训：跳过某引擎的测试会让缺陷长期潜伏

既有 `ccglue01`／`ccglue02` 正是测这个主题的（`ccglue02.lvt` 第二项就叫
`linestretch does not override custom CJKglue`），但它们对 LuaTeX 与 upTeX 直接
early-exit 打印 `LuaTeX: not tested yet.`。也就是说测试**恰好跳过了唯一会坏的两个
引擎**——pdftex/xetex 侧本来就有守卫、从未受影响，而这两个测试文件的全部断言都只在
pdftex/xetex 上真正执行过。

`not tested yet` 这类占位不是中性的：它会让人在浏览测试文件列表时误以为该主题「已有
覆盖」，而实际覆盖面只是名义上的四引擎减去两个 early-exit。修法是新增
`ccglue03.lvt` 专测 LuaTeX 与 upTeX，并在文件头注释里写明与 `ccglue01`／`ccglue02`
的分工（pdftex/xetex 侧由那两个文件覆盖，本文件不重复）。

## 具体的坑

1. **测试里的间距要用绝对单位写死。** 起初想用 `em`／`\ccwd` 一类相对单位，但
   `\linespread` 改字号后期望值本身也会变，读数无法区分「被重置」与「随字号正常
   缩放」。改用 `10pt plus 1pt minus 1pt`。

2. **`\ccwd` 会随用户的 `kanjiskip` 变化，这是既有语义不是本次副作用。** 修好后
   `\ccwd` 从 10.53937pt 变 20.53937pt、`\parindent` 从 21.07874pt 变
   41.07874pt（因为 `\ccwd = kanjiskip + \zw`，见 `ctex-engine.dtx` 的
   `\ctex_update_ccwd:`）。一度怀疑这是修法引入的问题，用
   `\ctexset{linestretch=\maxdimen}`（ctex 既有的、走 `auxi` 分支、设计上早已支持的
   路径）对照后否证：那条路径下 `\ccwd` 同样是 20.53937pt、`\parindent` 同样
   41.07874pt（`tmp/i1068/indC.tex` 与 `indA.tex` 两份对照实测逐字节相同）。判断
   「连带变化是不是新引入的」要找一条既有的、走相同分支的配置来对照，而不是凭直觉
   判断「这个数字变了所以是我改坏的」。

3. **`linestretch` 不能作类选项。** `\documentclass[linestretch=\maxdimen]{ctexart}`
   静默失效（`tmp/i1068/q5.tex` 实测 `CLASSOPT_TL=[\ccwd]`，值仍是默认的
   `\ccwd`），而 `\ctexset{linestretch=\maxdimen}` 生效（`q4.tex` 实测
   `TL=[\maxdimen]`）。原因是 `linestretch` 用 `\ctex_define:n`（键空间 `ctex`），
   类选项走 `\ctex_define_option:n`（键空间 `ctex/option`）；未知类选项被转发给标准
   文档类（为了透传 `a4paper` 之类），`article` 不识别便丢弃，没有任何警告。**这一点
   本次未改动**，但它意味着用户无法从类选项禁用该功能且得不到提示，值得记为待改进项
   （见下方 Follow-up）。

4. **`.dtx` 文档注释里不能在 `\texttt{}` 参数里写 `|`。** 写
   `\texttt{pdftex\textbar{}xetex}` 之前先误写过 `\texttt{pdftex|xetex}`，导致
   `l3build doc` 报 `\verb illegal in argument`、手册构建失败（shortvrb 把 `|` 当
   界定符）。这与 #1067 里 `\texttt{#1}` 未转义是同一类问题：
   `llmdoc/reference/coding-conventions.md` 已有相关条目（写在「参数记号要转义这一条，
   适用于所有 `.dtx` 文档注释」附近），范围应理解为所有 `.dtx` 文档注释里的 shortvrb
   特殊字符，不只是 `#`。这类错误只在 `l3build doc` 暴露，`l3build check` 全绿说明
   不了什么。

## Promotion Candidates

以下两条建议提升到 `lessons-learned.md`：

- **缺陷按代码路径分布，不按报告者用的引擎分布。** 报告者只在一个引擎下复现，不能
  推出其他引擎不受影响；看到 docstrip 引擎守卫（`%<*engine>`）时，应把它枚举到的
  引擎和没枚举到的引擎都实测一遍。
- **发现「某处缺少某个检查」时，先在全仓搜索该检查是否已在别处存在。** 这是「排查
  上游问题前先查本仓库已有根因记录」在代码层面的推广：那条针对的是「查文档」，这条
  针对的是「查代码实现」。跳过这一步会把「调用位置缺失」误诊成「实现缺失」，进而在
  错误的层次新写一份语义重复的代码。

以下一条建议追加到既有的「白名单式 CI 校验默认放行，未覆盖的包无人察觉」（Source:
`llmdoc/memory/reflections/1041-xecjk-version-gate.md`）附近，作为它在测试文件层面的
同构实例，不新增条目：

- 测试文件里的 `not tested yet.` early-exit 与 CI workflow 里的 `::notice::...跳过`
  是同一类「静默放行」——前者按引擎跳过、后者按包跳过，都会让「已有测试文件」被误读
  成「已有覆盖」。

## Follow-up

- `linestretch` 不能作类选项这一点本次未处理，是否要注册为类选项或至少在文档里说明，
  留给后续 issue。
- recorder：`llmdoc/architecture/package-architecture.md` 的「引擎特化覆写」一节
  （原文「luatex/uptex 保持原始行为……需另行修复」）已经过时，需要更新为记录 #1068
  后五引擎统一生效的现状。
- recorder：`llmdoc/architecture/ctex-architecture.md` 的「这一模式的典型用例」一句
  （原文「pdftex/xetex 的 `.def` 覆写……」）同样需要同步更新为「全部引擎」。
- recorder：`llmdoc/memory/decisions/761-ccglue-override.md` 的「未关闭项」一节
  （luatex/uptex 的 `\ctex_if_ccglue_touched:` 预存缺陷）已被 #1068 关闭，需要补一条
  指向本次修复的说明。
- recorder：`llmdoc/reference/build-and-test.md` 的 `ccglue01`／`ccglue02` 相关描述
  需要补 `ccglue03` 的分工说明；ctex 测试计数需要同步更新。

## 相关

- Issue：#1068。
- 实现：`ctex/ctex-engine.dtx`（`\@@_update_stretch_auxii:` 重定义处，删去
  `%<*pdftex|xetex>` / `%</pdftex|xetex>` 守卫）。
- 测试：`ctex/test/testfiles/ccglue03.lvt`（新增，专测 LuaTeX／upTeX）；既有
  `ccglue01.lvt`／`ccglue02.lvt`（覆盖 pdftex/xetex，本次未改动）。
- 探索阶段记录（未清理，供交叉核对）：`tmp/i1068/findings.md`（第一版方案分析）、
  `tmp/i1068/*.tex`／`*.log`（各引擎、各方案的 MWE 实测）。
- 相关反思：[[1057-fntef-nest-linebreak]]、[[1041-xecjk-version-gate]]（白名单式
  静默放行的另外两个实例）。
