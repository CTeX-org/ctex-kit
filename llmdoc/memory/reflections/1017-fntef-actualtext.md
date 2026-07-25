---
name: 1017-fntef-actualtext
description: 记录 #1017 隔离 xeCJKfntef 装饰内容的 PDF 文本语义时，对空 ActualText、tagging 暂停、文本与视觉双重验证及 CI 依赖闭环的认识
type: reflection
---

# [Task Reflection]

## Task

- 解决 Issue #1017：`xeCJKfntef` 的波浪线、删除线和用户自定义符号等装饰会混入
  PDF 的复制、搜索和文本提取结果。修复既要让普通 PDF 和 tagged PDF 只暴露正文，
  又不能改变页面上的装饰效果。
- 在共享的 `\xeCJK_fntef_sbox:n` 中为装饰盒赋予空的 `ActualText`，并在 LaTeX
  tagging 接口存在时暂停、随后恢复 tagging；补齐依赖、正式回归和
  `v3.10.5` 的 `\changes` 记录。
- 对实现和同一分支上的 reusable workflow 升级进行上下文隔离的增量审查，修复
  审查发现的问题后，再从原始基线审查最终结果。

## Expected vs Actual

- 预期：下划线、删除线和着重符号只是视觉装饰。用户复制或搜索
  `\CJKunderwave{正文}` 一类内容时，应当只得到“正文”。
- 实际：部分装饰不是 PDF 绘图指令，而是由字符或数学内容组成的小盒子，再由
  `ulem` 的 leaders 反复复制。波浪线、斜线、点和用户符号因此仍是 PDF 中可提取
  的文字，最终混入 `:`、`/`、`.`、`*` 等字符。
- 预期：给装饰内容标成 tagged PDF 的 Artifact，就能表达“这不是正文”。
- 实际：不同阅读器和 Poppler 对 Artifact 的复制与文本提取处理并不一致，单靠它
  不能形成可靠的跨工具契约。空 `ActualText` 更直接地说明这段内容的替代文本为空。
- 预期：在装饰盒外层加空 `ActualText` 后，普通 PDF 与 tagged PDF 会有相同行为。
- 实际：tagged PDF 会给盒子中的数学内容建立内层标记。这些内层标记可能穿过外层
  `ActualText`，使斜删除线等装饰字符再次出现在提取结果中；构造装饰盒时还必须
  暂停 tagging。
- 预期：本地完整 TeX Live 上测试通过后，CI 也具备同样的依赖。
- 实际：首轮独立审查发现 `.github/tl_packages` 没有安装新增的运行时和 tagged PDF
  测试依赖。若不补齐，开发机已有的宏包会掩盖 CI 精简环境中的失败。

## What Went Wrong

1. **最初把视觉装饰等同于没有文本语义。** 字符被放进盒子后仍是字符；`ulem`
   复制盒子时也会复制其文本内容。页面看起来正确，不能证明复制、搜索和文本提取
   结果正确。

2. **把 tagged PDF 的 Artifact 当成了通用的排除机制。** Artifact 的含义依赖消费
   工具如何解释标记结构。既然 Issue #1017 关心的是用户实际得到的文本，判断依据
   就应是普通与 tagged PDF 的提取结果，而不是只看结构标签是否存在。

3. **低估了嵌套 PDF 标记的影响。** 外层空 `ActualText` 并不必然压过装饰盒内部由
   数学 tagging 产生的标记。只有在盒子构造期间暂停 tagging，才能避免内层数学
   语义重新暴露装饰字符。

4. **新增依赖时只考虑了源码声明，没有同时检查 CI 安装清单。** `accsupp` 是
   `xeCJKfntef` 的运行时依赖，`latex-lab`、`pdfmanagement` 和 `tagpdf` 则用于
   tagged PDF 回归；这些包都需要在 `.github/tl_packages` 中明确列出。

5. **同一分支上的基础设施升级没有一次性同步全部合同。** 用户更新 reusable
   workflow 的固定提交后，本地 caller 已经改变，但合同测试脚本和稳定文档仍保留
   旧 SHA。增量审查分别指出这两个漂移点，才把调用文件、离线合同与说明重新统一。

## Root Cause

根因是页面绘制、PDF 文本语义和结构标记属于三个不同层次。`xeCJKfntef` 为了绘制
装饰，必须让 `ulem` 反复排出装饰盒；只要盒子由字符或数学内容构成，这些内容就会
自然进入 PDF 内容流。它们在页面上承担装饰作用，并不会自动失去文字身份。

空 `ActualText` 解决的是文本语义：它明确告诉提取工具，这段可见内容没有替代文本。
暂停 tagging 解决的是结构嵌套：它阻止装饰盒内部的数学标记建立一套更内层的文字
语义。两者缺一不可，且都应只包住共享的装饰盒构造过程，不能影响正文。

依赖和 workflow 漂移则来自另一个共同问题：一个行为的完整合同分散在源码、测试、
CI 安装清单、离线检查和稳定文档中。只修改最先看到的文件，很容易在完整 TeX Live
或已有本地缓存中得到虚假的“已经完成”。

## What Worked

- 把修复放进所有线条和符号装饰共用的 `\xeCJK_fntef_sbox:n`，没有逐个修改命令。
  这样八类装饰使用同一条 PDF 语义隔离路径，也保留了既有的 boundary capture
  suspend/resume。
- 用 `\BeginAccSupp{ActualText={}}` 和 `\EndAccSupp{}` 包住装饰盒，并以
  `\cs_if_exist:NT` 检查 `\tag_suspend:n`、`\tag_resume:n`。普通文档不依赖
  tagging 接口；tagged PDF 则在盒子内部不再产生会穿透外层 `ActualText` 的标记。
- 新增 `fntef-actualtext01`，覆盖下划线、双下划线、波浪线、删除线、交叉删除线、
  自定义线条、着重号和自定义符号八类命令。回归同时固定八次空 `ActualText` 和八组
  tagging 暂停／恢复调用，避免以后新增路径时只保留一半机制。
- 分别生成普通与 tagged PDF，并检查文本提取结果。修复前可稳定复现 `:`、`/`、
  `.`、`*` 等污染，修复后两种 PDF 均只剩正文。
- 把文本语义和页面视觉当作两项独立验收。文本提取证明复制／搜索结果正确；高分辨率
  栅格比对证明修复没有改变装饰位置和形状，最终像素差 `AE=0`。
- 独立审查使用不继承实现上下文的代理和固定提交快照。首轮发现 CI 依赖漏项；分支
  后续加入 workflow 升级后，再用隔离的增量审查发现合同脚本和稳定文档 SHA 漂移；
  修复后从原始基线进行最终全范围审查，没有让后续的全绿结论掩盖前面的发现。

## Missing Docs or Signals

- xeCJK 架构文档已经说明 `\xeCJK_fntef_sbox:n` 对命令边界状态的隔离，但此前没有
  说明装饰盒还必须与 PDF 文本语义隔离，也没有记录空 `ActualText` 与暂停 tagging
  分别解决什么问题。
- 构建与测试参考已经说明 leader 的节点与视觉验证，却没有把“普通 PDF 与 tagged
  PDF 都要检查文本提取”列为字符型装饰修复的必要证据，也没有说明文本语义测试和
  页面栅格比对不能互相替代。
- `.github/tl_packages` 的通用维护约束已经存在，但本轮缺少一个更直接的提交前信号：
  只要新增 `\RequirePackage` 或启用 `\DocumentMetadata{tagging=on}` 的测试，就应立即
  反查精简 CI 所需的运行时和测试依赖。
- reusable workflow 的固定 SHA 同时存在于 caller、合同脚本和稳定文档中。现有合同
  测试能发现 caller 与脚本不一致，但如果没有审查文档 diff，稳定文档仍可能单独
  漂移。

## Promotion Candidates

- **字符型装饰盒必须显式排除 PDF 文本语义。** 页面上的字符如果只承担绘图作用，
  应使用空 `ActualText`；不能从“它位于盒子或 leader 中”推断它不会被复制或提取。
- **tagged PDF 需要单独处理内层标记。** 外层 `ActualText` 不能替代对嵌套 tagging
  的检查。若装饰盒中可能出现数学内容，应在最小作用域内暂停并恢复 tagging。
- **PDF 文本语义与页面视觉要分别验收。** 普通和 tagged PDF 的文本提取用于验证
  复制／搜索；高分辨率栅格或坐标证据用于验证排版。任何一类结果都不能推出另一类
  结果正确。
- **新增测试能力时同步运行时依赖、测试依赖和 CI 白名单。** 本地完整 TeX Live 通过
  不能证明精简 CI 可运行，尤其要反查 `.github/tl_packages`。
- **升级固定 reusable workflow 提交时，把 caller、离线合同和稳定文档作为一个
  更新单元。** 三处必须使用同一个完整 SHA，并由合同测试和文档审查分别确认。
- **审查期间允许接收后续提交，但必须扩大审查范围。** 新提交先做隔离增量审查，
  最终再从原始基线审查完整结果，确保早期发现和后来变更都有连续证据。

## Follow-up

- recorder 应把装饰盒的空 `ActualText`、tagging 暂停范围及二者的职责区别写入
  `llmdoc/architecture/xecjk-architecture.md`。
- recorder 应在 `llmdoc/reference/build-and-test.md` 中补充
  `fntef-actualtext01` 的覆盖范围，以及普通／tagged PDF 文本提取与页面栅格比对的
  双重验收方法；同步确认 xeCJK 标准测试数量。
- recorder 应把可复用规则提炼到 `llmdoc/memory/lessons-learned.md`，并更新
  `llmdoc/index.md` 的相关摘要，使后续 fntef 或 PDF tagging 修改能发现这些约束。
- 本次行为变更必须保留在 `v3.10.5` 的 `\changes` 中；`v3.10.4` 已经发布，不能把
  新修复追记到旧版本。
- 后续若新增其他由字符、数学公式或用户内容绘制的装饰入口，应确认它是否经过
  `\xeCJK_fntef_sbox:n`。不经过时，需要补上等价的文本语义隔离和普通／tagged PDF
  提取回归。

## 相关引用

- Issue：#1017；相关 fntef 历史：#465、#826、#830、#992。
- 实现：`xeCJK/xeCJK.dtx` 中的 `\xeCJK_fntef_sbox:n`。
- 测试：`xeCJK/testfiles/fntef-actualtext01.lvt/.tlg`。
- 依赖：`xeCJK/DEPENDS.txt`、`.github/tl_packages`。
- 既有知识：[[../../architecture/xecjk-architecture.md]]、
  [[../../reference/build-and-test.md]]、[[465-fntef-font-state-and-underdot-space.md]]、
  [[826-fntef-boolean-flag-iteration.md]]。
- 审查范围：`b22206eee90b3181fce822d650f3976d2b643daa..db80727ddd3804ccc7db60c6febe315209cc39b8`；
  首轮、两次增量、最终全范围审查和终局收据保存在 `.code-review/`。
