---
name: 1104-microtype-mt-char-sync
description: 记录 #1104 修复 xeCJK 为 microtype 查回歧义字符槽位时只设置 \MT@char、不设置 \MT@char@；测试上三处判断失误（OpenType 字体的 \lpcode 要加 U 前缀才按码位查询、l3build 首个错误即停要把报错用例放最后、误以为要在 \START 前排一个字符）；制图时发现直接输入的歧义字符走 CJK 路径、行尾 marker kern 挡住右侧突出；本地独立审查的终审第一次因盲审报告缺少运行元数据而 FAIL
metadata:
  type: feedback
---

# 反思：#1104 microtype 的歧义字符槽位

## Task

现象：XeLaTeX 同时加载 xeCJK 与 microtype，NFSS 回退到 `TS1/cmr`（`tcrm1000`）时
`\textperiodcentered` 报 `Cannot use XeTeXglyph`；OpenType 字体的破折号、引号等突出量算错。

根因与修法：见 [[../../architecture/xecjk-architecture]]「与 microtype 的兼容（#1104）」。
`\__xeCJK_get_ambiguous_slot:` 同时设置 `\MT@char` 与 `\MT@char@`（报告者给出的建议，
提交 `d72662fc`，PR #1106）。测试 `microtype-slot01` 的要点见
[[../../reference/build-and-test]]「microtype 突出量回归」一节。

## 判断失误与纠正

1. **查询方式写错，误判为“microtype 还没设置突出量”。** 第一版测试写
   `\lpcode\font"2014`，修复前后都读到 0，我先以为是字体还没被 microtype 处理，在 `\START`
   前加了 `\setbox0=\hbox{x}` 预热，并写进了文档草稿。实际原因是 XeTeX 按字形序号保存
   OpenType 字体的 `\lpcode`，按码位查询要写 `\lpcode\font U"2014`。改对查询后删掉预热重跑，
   结果相同，于是撤回预热和那条文档说法。核对办法：`\XeTeXcharglyph"2013` 取字形序号，
   `\lpcode\font<序号>` 与 `\lpcode\font U"2013` 应相等。
2. **报错用例放在最前，修复前的日志只有报错。** l3build 遇到第一个错误就停止编译，
   修复前 TS1 一项报错后，后面 TU 字体的错误数值不会出现在 diff 里。把会报错的用例移到最后，
   修复前后的差异才同时包含数值和报错。
3. **Latin Modern 没有判别力。** 默认字体有专用 microtype 配置，修复前后 TU 数值相同；
   换成没有专用配置的 TeX Gyre Termes 才看得出差别（DejaVu Serif 修复前全为 0，也可用）。

## 制图时的发现

- 直接输入的“—”等歧义字符在 xeCJK 里默认按 CJK 字符排版（FandolSong），根本不经过这条路径；
  对比图必须用 `\textemdash`、`\textquotedblleft` 等文本命令。
- 西文字符后紧接 `\linebreak` 或段落结束时，xeCJK 留下一对 ±0.0002pt 的 Default marker kern，
  行尾不再突出。对比图改为在空格处自然断行；维护者决定作为已知限制保留，记在架构文档的同一小节。
- 判断“突出没有发生”时，先 `\showbox` 看行尾有没有 `\kern... (right margin)`，比看图可靠。

## 本地独立审查的过程

4 轮盲审（首轮、两轮增量、最终全范围）共提出 3 个小问题，都是 llmdoc 中测试计数和索引的
措辞，已全部修复；最终全范围结果为 0／0／0。第一次终审 FAIL，属于证据不完整：
审查包末尾要求在报告开头记录运行 ID、快照、HEAD/tree、隔离、输入和命令退出码，
但四位审查者都只按 code-review 模板写了 frontmatter，事后有两位还误以为任务消息没有这项要求。
定向修复是请审查者另写隔离声明；第二次终审对照 harness 保存的会话记录确认审查包逐字节一致、
盲审前没有读禁止的输入，判为 PASS（附已接受的证据缺口）。

可复用的做法：

- 把元数据要求放在审查包开头，并写明“报告正文第一节必须是这个元数据块”，不要只放在末尾一句。
- `offline.sh` 只包住了 git、l3build、xelatex；`ls`、`grep` 等只读命令审查者会直接运行。
  若要求全部命令在断网边界内执行，需要在审查包里明确说出来。
- 子代理启动时 harness 会注入协调者仓库的 memory 索引和 gitStatus，Bash 默认 cwd 也在协调者仓库；
  这不能靠审查包消除，只能在终审时核对注入内容与任务无关。
- 首次提交在调用 close-local-code-review 之前完成，缺少提交前冻结的 staged 摘要；
  想要完整证据，应在第一次 `git add` 之前就调用该 skill。
