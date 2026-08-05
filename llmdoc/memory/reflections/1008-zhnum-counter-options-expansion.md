# #1008 反思：带选项 `\zhnum`/`\zhdig` 写辅助文件时把计数器名当值写进去

任务：Issue #1008 报告按层级混搭中文数字样式做不到——用户想让 `\section` 用
`\zhnum[style=Normal]{section}`、`\subsection` 用 `\zhnum[style=Financial]{subsection}`，
实测目录编号与正文不一致。手册当时只写「带了选项的命令是不可展开的，在某些场合使用时要
小心」，报告者据此认为这是设计限制。

## 缺陷本身

### 根因一：带选项形式把计数器**名**写进辅助文件

原实现 `\zhnum[opts]{section}` 展开成 `\zhnumwithoptions{opts}{section}`；后者用
`\NewDocumentCommand`（不可展开，因为要用 `\group_begin:`/`\group_end:` 局部改样式）。
于是 `.toc` 里留下的是 `\zhnumwithoptions{style=...}{section}`——**计数器名**，而不是
当时的计数器值。该文件在下次编译的 `\tableofcontents` 处读回时计数器已归零，实测正文
「一／一.壹」而目录「零／零.零」。

修法：在 `\zhnum` 这一层先用 `e` 展开把计数器取成数值，再交给处理**数值**的
`\zhnumberwithoptions`；写进辅助文件的成为 `\zhnumberwithoptions{style=...}{7}`，数值
已固定，样式留待读回时套用。`\zhdig` 同理（走 `\zhdigitswithoptions`，注意要传
`\c_false_bool` 作为它的 N 型首参）。

**没有改成完全可展开，这是有意取舍**：样式靠 `\tl_set_eq:NN` 一类**赋值**实现（见
`\zhnum_reset_style:`），赋值无法在 `\edef` 的展开中生效，硬做只会把「不可展开」换成
「静默用错样式」。

### 根因二：排查中发现的独立 bug

`\zhdigwithoptions` 原写的是 `\zhnum_digits_counter:n #1 {#2}`——多传了一个 `#1`
（选项本身）。`\zhnum_digits_counter:n` 只取一个参数，于是选项被当成计数器名、真正的
计数器名溢出到后面。实测 `\zhdig[style=Financial]{section}` 直接报
`Use of \??? doesn't match its definition` 并把 `tyle=Financialsection` 印到页面上——
带选项的 `\zhdig` 此前**完全不可用**，与根因一无关，单独记 `\changes`、单独测。

### 兼容性

`\zhnumwithoptions`/`\zhdigwithoptions` 保留为转发：v3.1 及以前写下的 `.toc` 里还留着
这两个名字，删掉会让旧文件读回时报 undefined。

## What Went Wrong：测试设计上走的弯路

补测试时在「怎么观察不可展开命令的行为」上反复试错，四次都是死路：

1. **`\typeout{\zhnumwithoptions{...}{...}}` 不行**——这两个命令不可展开，`\typeout`
   只记下它们的**名字**，内部坏掉也看不出来。实测恢复根因二的笔误后，只用 `\typeout`
   的版本仍然全绿。
2. **`\tl_set:Nx` 也不行**——同样只拿到名字。
3. **在 `\TEST` 的参数里切 `\ExplSyntaxOn` 不生效**——参数已被读入，catcode 定死了。
   实测报 `Undefined control sequence` 指向 `\tl_log:N`。同理 `\protected@edef` 含
   `@`，在 `\ExplSyntaxOn` 下直接写会报 `You can't use a prefix with the character @`。
4. **让它们真的排版，但放在主 `testfiles/` 里也不行**——排 CJK 需要中文字体：XeTeX 下
   只是 `Missing character` 警告，pdfTeX 下是**硬错误** `Unicode character ... not
   set up for use with LaTeX` 并中止编译。同一个 `.lvt` 的两个引擎基线会分化成
   「报错」与「警告」两种形态，且后者让其后用例静默不执行。

最终解法是**按引擎需求分目录**：

- `testfiles/counter-options01`（三引擎）用记号层面的断言固定「值有没有被冻结」——
  判据是展开结果里出现 `{7}` 而非 `{section}`；
- `testfiles-cjk/legacy-entry01` + `test/config-cjk.lua`（仅 xetex）让兼容入口真的排出
  汉字再量盒子，做法仿 `xpinyin/test/config-cjk.lua`。

另外盒子度量的判别力也踩过一次：一开始想用**宽度**，但缺字时宽度会 collapse 成同一个
值（实测两者都是 2.8pt），分辨不出内容；改用**高度**才区分开（`ht=7.33` 的「七」vs
`ht=7.75` 的「柒」）。

## Root Cause

上述四条弯路的共同根源是同一件事：**观察不可展开命令的行为，只有「让它执行」一条路**。
`\typeout`/`\tl_set:Nx`/`\protected@edef` 这类手段面对一个不可展开的宏时，只能拿到它的
**控制序列名**本身（因为宏未被展开），无法看到宏体内部逐步展开、赋值、报错的中间过程；
若内部有笔误（如根因二），这些手段一律看不出来。要观察内部是否正确，必须让宏真正
**执行**（这里是排版出可见节点），再从执行结果（节点、盒子尺寸）反推内部逻辑是否正确。

盒子度量选宽度还是高度也是同一类问题的缩影：缺字时字体会用同一个占位字形，宽度往往
被 collapse 成同一个值，必须先验证候选维度真的会随内容变化，再拿来做判据。

## Missing Docs or Signals

- 手册原文「带了选项的命令是不可展开的，在某些场合使用时要小心」这句措辞本身塑造了
  报告者「这是设计限制」的判断。「不可展开」和「不能写进辅助文件」是两件不同的事，手册
  没有把这层区分说清楚，直到 42cb1be8 补上「不可展开不妨碍写入辅助文件」一段后，这个
  用法才变得可发现。这是文档缺口而非代码缺口，但直接导致了报告者卡在错误结论上。
- `l3build check` 没有「按 `.lvt` 文件指定引擎」的机制，`build-and-test.md` 里已记过
  这条约束（#1038／xpinyin 系列），本次是第三次撞上同一约束、第二次靠分 testfiledir
  解决，说明这条规则已经足够稳定，值得作为通用判据反复引用而不必每次重新论证。

## 另一个如实记录的既有问题（未修）

`\@@_counter_error:n` 用 `\msg_expandable_error:nnn`，它在展开中报错的方式是留下一个
`\???` 控制序列，于是日志里同时出现 `Use of \??? doesn't match its definition` 和真正
的 zhnumber 报错。实测系统安装的 v3.1（未含本次改动）对**不带选项**的
`\zhnum{nosuchcounter}` 同样如此，属 expl3 可展开报错的既有形态，与 #1008 无关。所以
没把它固定进基线（那会把一个无关的既有粗糙点冻结成预期值），测试里只用
`\int_if_exist:cTF` 确认两条路进的是同一个判断分支。

## 判别力实测结果

三个方向的变异都能让相应用例变红：

- zhnum 退回写计数器名 → `counter-options01` 红；
- zhdig 退回写计数器名 → `counter-options01` 红；
- 恢复 `\zhdigwithoptions` 的笔误 → `legacy-entry01` 的 `legacy zhdig` 度量变化。

**第三条曾长期抓不到**，正是上面 what-went-wrong 那四条弯路的后果——主目录里无论用
`\typeout` 还是 `\tl_set:Nx` 都只能记下名字。这是补 CJK 那一组的真正理由。

## 版本管理

加了 `\changes` 条目就必须 bump `build.lua` 的 `version`（3.1 → 3.2），否则会被
PR #1055 补的 `check-tag` 拒绝。CHANGELOG 由 `make changelog-zhnumber` 生成。

## Promotion Candidates

以下几条具有跨包复用价值，建议提升到 `lessons-learned.md` 或 `reference/`：

1. **观察不可展开命令的行为，只有「让它执行」一条路**：`\typeout`/`\tl_set:Nx`/
   `\protected@edef` 都只能拿到名字。若测试判据只依赖这些手段，对该命令内部的缺陷
   完全没有判别力。这条与 #1043 反思里「探针先自证有效」同属一类——先确认观察手段本身
   有没有能力看到你要断言的东西。
2. **测试文件的 catcode régime 要一次定好**，不能在 `\TEST` 参数里临时切换
   `\ExplSyntaxOn`/`\ExplSyntaxOff`（参数已被读入，catcode 已冻结）。这条与 #1043
   「字面模式的类别在 tokenise 那一刻冻结」是同一机制在不同场景的重现，值得在
   `coding-conventions.md` 里合并成一条通用规则。
3. **引擎需求不同的测试必须分目录**，`l3build check` 没有按文件指定引擎的机制；这是
   本仓库第三次撞上同一约束（此前见 #1038、xpinyin 系列），应作为稳定判据在
   `build-and-test.md` 里保持醒目位置，不必每次重新论证。
4. **盒子度量选哪一维要先验证它真的会变**：缺字时宽度可能 collapse 到同一个值，高度
   往往才有判别力；一般化为「用度量做判据前，先用已知的两个不同输入分别测一次候选维度，
   确认它们不同」。
5. **手册措辞会塑造用户对「这是不是限制」的判断**：本次报告者正是被「不可展开」这句话
   引导到「这是设计限制」的结论上。修复代码缺陷之外，若手册的既有措辞会让同类误读复现，
   应当同时补一段说明用法边界，而不只是改代码。
6. **修一个问题时发现的独立 bug（根因二）要单独记 `\changes`、单独设计测试用例**，不要
   混进主问题的叙述和判据里，否则后续想单独复核某个 bug 是否修复时会难以拆分证据。

## Follow-up

- recorder 视情况把「测试文件 catcode régime 一次定好，不能在 `\TEST` 参数里切换」补进
  `reference/coding-conventions.md`（可与 #1043 已有的相邻小节合并，避免重复）。
- recorder 把「引擎需求不同必须分 testfiledir」在 `build-and-test.md` 里补上 zhnumber
  这第三个实例（`counter-options01` 三引擎 / `legacy-entry01` 仅 xetex），巩固这条已
  反复验证的规则。
- 若后续再有宏包遇到「不可展开命令是否需要真排版才能验证」的场景，可直接引用本反思
  的四条死路，避免重走弯路。
