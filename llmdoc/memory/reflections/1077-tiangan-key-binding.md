---
name: 1077-tiangan-key-binding
description: 记录 #1077 修复 zhnumber 里 Tn 键抄成绑定 GZn 目标变量的笔误（\zhnumsetup{T1=...} 改掉的是 \zhganzhi 而不是 \zhtiangan）；核心教训是这类复制粘贴笔误在逐组自查时完全自洽、只有把 Tn/Dn/GZn 三组键并排比对才能发现，以及 testfiles/ 此前对 \zhtiangan／\zhdizhi／\zhganzhi 与这三组键零覆盖，笔误才能长期潜伏
metadata:
  type: feedback
---

# 反思：#1077 `Tn` 键绑定到干支变量而非天干变量的笔误，与「组间对照才能发现的笔误」

## 任务

Issue #1077：`zhnumsetup{T1=我的甲}` 本应只改 `\zhtiangan{1}`（天干），实测却改掉了
`\zhganzhi{1}`（干支）的输出，`\zhtiangan{1}` 原样不变。报告者 MWE：

```
before: 甲     | 子     | 甲子
after:  甲     | 我的子 | 我的甲      <- T1 改错了目标, D1 正常
```

任务是定位根因、修复，并补上此前完全缺失的回归测试。已提交为 `7cd42cb4`。

## 根因

`zhnumber/zhnumber.dtx` 用 `\int_step_inline:nn` 循环生成 `Tn`／`Dn`／`GZn` 三组
l3keys 键，三组键的目标变量本应各自独立（`Tn` 写 `l_@@_tiangan_#1_tl`、`Dn` 写
`l_@@_dizhi_#1_tl`、`GZn` 写 `l_@@_ganzhi_#1_tl`），因为 `\zhganzhi` 的输出由天干与
地支两个变量组合而成，只有用户显式设置 `GZn` 时才直接取干支变量——三者不能共用同一个
目标。`Tn` 那组抄错了：

```latex
T#1  .tl_set:N = \exp_not:c { l_@@_ganzhi_ #1 _tl }   <- 错，抄成了 GZn 的目标
D#1  .tl_set:N = \exp_not:c { l_@@_dizhi_  #1 _tl }   <- 对
GZ#1 .tl_set:N = \exp_not:c { l_@@_ganzhi_ #1 _tl }   <- 对（GZn 本该写这个）
```

修法是把 `Tn` 那一行的目标改回 `l_@@_tiangan_ #1 _tl`，`Dn`／`GZn` 未动。

## 核心教训

### 第一层：复制粘贴产生的笔误，特征恰恰是「局部一切正常」，只能靠组间对照发现

单独审查 `Tn` 那两行代码时看不出任何问题：`\int_step_inline:nn { 10 }` 的步数
10 正好是天干的个数，`.groups:n = { user , pre , tiandi }` 里的分组名 `tiandi`
也完全对应——**只有目标变量名这一个字段错了，而这个字段恰好长得和 `GZn` 那组的目标
一模一样**。逐组检查「这一组自己有没有问题」（步数对不对、分组名对不对、参数签名对
不对）永远发现不了它，因为这组代码在自己内部是完全自洽的；必须把 `Tn`／`Dn`／`GZn`
三组键**并排放在一起**比对，才能看出 `Tn` 与 `GZn` 指向了同一个变量。

这与 [[1068-selectfont-resets-ccglue]] 记的「守卫『存在』不等于『被调用』」是同一类
「审查方式选错层次」的问题，但触发条件不同：那次是漏调用（该有的东西没接上），这次
是错绑定（接上了，但接到了错误的目标）；两次都不是「代码本身报错」，而是「代码能跑，
跑出的结果指向了错误的地方」。审查一批结构相同的成组定义（一批键、一批钩子、一批
引擎分支）时，正确的检查方式是「组间对照」——把同类项在视觉上排在一起逐字段比对——
而不是「组内自查」——逐组确认这组代码自身逻辑通不通。

### 第二层：没有测试覆盖的公开接口，笔误可以潜伏任意长的时间

`zhnumber/testfiles/` 在这次修复之前完全没有测试覆盖 `\zhtiangan`／`\zhdizhi`／
`\zhganzhi` 这三个命令，也没有覆盖 `Tn`／`Dn`／`GZn` 这三组公开选项——不是「测试写得
不够细」，是这一整块手册记载的公开功能没有任何回归保护。这正是这处笔误能从引入
一直潜伏到用户报告的直接原因。

判断这类覆盖缺口的可操作方法是：拿手册里列出的公开命令／选项清单，逐项去 `testfiles/`
里核对是否存在对应断言，而不是看测试文件的数量或规模——数量再多，缺的那一块也不会
显现出来。

### 第三层：8-bit 引擎需要单独的基线，且那份基线本身不可读

`zhnumber` 的 `checkengines` 含 `pdftex`（8-bit 引擎）。pdfTeX 把中文在日志里按字节
转义成 `^^e7^^94^^b2` 这类形式，而 xetex／luatex／uptex 直接记中文字符，所以新增的
`tiandi01.lvt` 需要一份独立的 `tiandi01.pdftex.tlg`。这份基线本身人眼读不出内容——
已在用例注释里写明字节与汉字的对照表（实测核对：甲=`^^e7^^94^^b2`、子=`^^e5^^ad^^90`、
我的=`^^e6^^88^^91^^e7^^9a^^84`），并提示「只有 pdftex 报红、其余三引擎通过时，先怀疑
是不是漏刷了那份基线」，而不是去怀疑实现——这与 `llmdoc/reference/build-and-test.md`
已记的 `counter-options01` 案例是同一条约束（pdfTeX 记汉字为字节形式与「pdfTeX 排 CJK
是硬错误」是两件不相关的事，这里同样只是日志编码差异，`\tl_log:x` 没有实际排版）。

## 具体的坑

1. **`.dtx` 注释里 `\cs{}` 参数中的 `#1` 要写成 `\#1`。** 在新增的实现说明里写
   `\cs{l_@@_tiangan_#1_tl}`，`l3doc` 报 `You can't use 'macro parameter character #'
   in horizontal mode`，手册构建失败；转义 4 处（`\cs{l_@@_tiangan_\#1_tl}`／
   `\cs{l_@@_dizhi_\#1_tl}`／`\cs{l_@@_ganzhi_\#1_tl}` 各一处，另一处在
   `\changes` 条目里引用 `\opt{Tn}` 时同类写法）后才通过。这与 #1067（`\texttt{#1}`
   未转义）、#1068（`\texttt{pdftex|xetex}` 里的 shortvrb 竖线）是同一家族问题：
   **`.dtx` 文档注释里的特殊字符只在 `l3build doc` 暴露，`l3build check` 全绿说明
   不了什么。** `llmdoc/reference/coding-conventions.md` 已有「参数记号要转义这一条，
   适用于所有 `.dtx` 文档注释」小节记录前两次；本次是第三次发作，同一坑在三个不同
   issue 里各踩了一次，值得留意它的发生频率而不只是记录「有这条约束」。

2. **插入实现说明时打断了 `macrocode` 环境。** 为在既有代码中间插一段解释三组键目标
   变量为何必须独立的说明，需要先 `\end{macrocode}`、写注释、再 `\begin{macrocode}`。
   这类插入操作本身容易在边界上出错（比如 `\end{macrocode}` 前多留或少留字符），
   写完后必须跑 `l3build unpack` 确认嵌套正确——`support/ctxdoc.cls` 对
   `%    \end{macrocode}` 的四空格终止行做逐字匹配，错一格会在远处表现为难以定位的
   quark 错误（`llmdoc/memory/reflections/xecjk-dtx-documentation-boundaries.md`
   已记过这条通用约束）；否则 docstrip 会在与实际错误位置相距很远的地方失败。

## Promotion Candidates

- **「组间对照，而不是组内自查」**：审查一批结构相同的成组定义（本例是三组 l3keys
  键，[[1068-selectfont-resets-ccglue]] 是三套引擎判断分支）时，逐组检查内部自洽性
  发现不了跨组抄错目标／漏调用这类问题，必须把同类项并排比对。这条与既有的「否定性
  结论要说明搜索了什么模式」「根因是代码事实，把它写成可 grep 的模式并穷举全部出现
  位置」同属一类，但视角更进一步：那两条讲的是穷举候选位置的手段，这条讲的是**审查
  单个候选位置时该用组内视角还是组间视角**——组内视角对本例这类笔误零判别力。
- **测试覆盖缺口的判断方法**：用手册公开接口清单逐项核对 `testfiles/`，而不是凭测试
  文件数量或规模判断「这块功能有没有回归保护」。

## Follow-up

- recorder：`llmdoc/index.md` 补一行 zhnumber 天干地支相关反思索引。
- recorder：`llmdoc/reference/build-and-test.md` 补记 `tiandi01` 测试布局与其需要
  pdftex 专用基线的通用事实。
- recorder：核对 `llmdoc/memory/lessons-learned.md` 里「缺陷按代码路径分布，不按
  报告者用的引擎分布」（#1068）与「白名单式 CI 校验默认放行」两组既有规则，判断
  「组间对照而非组内自查」应新开条目还是并入其中之一。
- recorder：检查 llmdoc 里是否有关于 zhnumber 天干地支、或 `Tn`/`Dn`/`GZn` 的过时
  描述需要同步（目前搜索未发现——`llmdoc/architecture/package-architecture.md` 与
  `llmdoc/reference/build-and-test.md` 此前均未提及这三组键或 `\zhtiangan` 等命令）。

## 相关

- Issue：#1077。
- 实现：`zhnumber/zhnumber.dtx`（`Tn` 键的 `.tl_set:N` 目标，改 `l_@@_ganzhi_ #1 _tl`
  为 `l_@@_tiangan_ #1 _tl`；另新增一段实现说明与 4 处 `\#1` 转义）。
- 测试：`zhnumber/testfiles/tiandi01.lvt`（新增，7 个 TEST）、
  `zhnumber/testfiles/tiandi01.tlg`、`zhnumber/testfiles/tiandi01.pdftex.tlg`
  （pdfTeX 专用基线）。
- 提交：`7cd42cb4`。
- 相关反思：[[1068-selectfont-resets-ccglue]]（同属「守卫/绑定看似完整实则未生效或
  接错目标」一类，本次的镜面是「接上了但接错了目标」而非「没接上」）、
  [[1008-zhnum-counter-options-expansion]]（同一包，pdftex 需要独立基线、可展开报错
  在本仓库致命错误的约束同样适用，虽然本次未触发该约束——`tiandi01.lvt` 没有断言
  报错）。
