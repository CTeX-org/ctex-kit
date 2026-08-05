# #1054 反思：l3backend 防御的覆盖范围、kpse `!!` 树，与一次不具备前提的反证

## Task

起因是用户发现本地编出的 `xeCJK.pdf` 正文里散落 `0gray 0`、`1.0 0.0` 一类文本。排查确认
是 TeX Live 2026 stable 树里 expl3（2026-07-20）与 l3backend（2026-02-18）版本错配：
`\__color_select_aux:nnN` 调 `\__color_backend_select_<model>:nN`，而旧 backend 只定义
`:n` 变体，`\use:c` 拿到未定义控制序列后展开成 `\relax`，颜色参数掉进水平列表被当文字
排版。只影响把所有颜色模型 alias 到单个 `\__color_backend_select:n` 的后端（xetex、
dvipdfmx）；pdftex／luatex／dvips／dvisvgm 各模型独立定义，不受影响。

这是 #1048/#1050 的直接后续：那一轮已经把同类防御加进 `_test-package.yml`（regression
路径）。本轮用户接着问「test 加了防御，doc 和 release 有加吗」，核实发现 check-doc 与
release 这两条排版路径完全没有。于是把防御抽成 `scripts/sync-l3backend.sh` 并接入三处，
顺带处理 xeCJK 手册的一批文档订正。

## Expected vs Actual

- 预期：把已有的内联防御抽成脚本、在两条缺失的路径上各加一步，是一次结构清晰的低风险
  改动；文档订正是附带的。
- 实际：脚本本身的逻辑一次就对，但落地过程出了四类问题，且**三类都与「验证方式」有关
  而不是与「方案」有关**：把用户已写好的一处 makeindex 转义当成笔误改掉引入构建失败；
  第一次就猜对了 ls-R 根因，却因为在不具备复现前提的本地环境做反证而撤回，绕两条弯路
  后靠 CI 日志才重新确认；`curl` 退出码 0 但产物残缺，使失败延后到末尾并报出与真实
  原因无关的信息；共享脚本没纳入任何 CI 触发白名单，由两个 bot 独立指出。

## What Went Wrong

### 1. 把用户未提交 diff 里的 `\&!=6` 判成 typo 并「修掉」，引入构建失败

第一次读用户未提交的 `xeCJK.dtx` diff 时，看到 `\changes` 条目里
`\texttt{\textbackslash catcode`\textbackslash\&!=6}`，我判定那个 `!` 是误敲的多余
字符，直接改成 `\&=6`，并在提交前重新生成了 CHANGELOG。随后 `l3build doc` 报
`Extra }` 失败（exit 1）。

`!` 是 makeindex 的 quote 字符，起实际作用。`gglo.ist` 定义 `actual '='`、`quote '!'`、
`level '>'`，doc 的 encap 是 `|`。未转义的 `=` 被当成 actual 分隔符，条目在该处截断，
只剩 `6}）时…` 进 `.gls`，排版时 `Extra }`。用户原来的写法是对的。

我用单条目 makeindex 对照实测确认了机制：`t.glo` 写 `\&=6`、`t2.glo` 写 `\&!=6`，跑
`makeindex -s gglo.ist`，前者 `.gls` 只剩 `6}）时…`，后者完整。

最终解法既不是恢复 `!=`（`!` 会漏进 `scripts/extract-changes.py` 生成的
`CHANGELOG.md`），也不是 `|&|`（撞 encap），而是改写句子绕开 `=` 与 `|`，让 `.gls` 与
CHANGELOG 同时干净。

### 2. 第一次就猜对 ls-R 根因，却因不具备复现前提的本地反证而撤回

`doc-zhmetrics` 在 CI 上稳定失败，同批其他 7 个 doc job 全绿。我第一次的判断就是对的：
zhmetrics 的第 14 步跑了 `mktexlsr "$TEXMFHOME"`（为了让 kpse 认识它生成的
`zhmCJK.tfm/map`），之后 kpse 只查 ls-R，我随后拷进去的 `.def` 不在索引里。我据此加了
`mktexlsr`。

然后我做本地反证（去掉 `mktexlsr` 看是否失败），反证没能复现失败，于是判断「根因判断
错了」并 `git checkout` 撤掉了那个改动。

反证失败的真实原因是**本地环境根本不具备复现该问题的前提**：我本地的 `TEXMFHOME`
（`/home/liam/texmf`）与 `TEXMFLOCAL`（`/home/liam/texlive/texmf-local`）是两个不同
目录，而 `texmf.cnf` 的
`TEXMFDBS = {!!$TEXMFLOCAL,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFDIST}` 只给
`TEXMFLOCAL` 等带 `!!` 前缀，不含 `TEXMFHOME`；`TEXMF` 列表里 `$TEXMFHOME` 也无 `!!`。
所以本地 `TEXMFHOME` 走磁盘搜索，不受 ls-R 约束。CI 上 setup-texlive-action 让
`TEXMFHOME` 解析到 `.../setup-texlive-action/texmf-local`，即带 `!!` 的那棵树，才会
出问题。

撤回之后我又走了两条弯路：

- 先加了「只在 ls-R 已存在时才刷新」的条件版，理由是担心给其他 job 新建 ls-R 引入副
  作用。实测确认 `mktexlsr` 在没有 ls-R 的树上会新建一个，但真正的结论是：`TEXMFHOME`
  指向 `!!` 树时没有 ls-R 等于什么都找不到，所以应该无条件刷新，条件版反而是错的。
- 中间两次用 `sed`／`perl` 删脚本片段做反证，把脚本结构删坏——一次语法错误 exit 2、
  一次把末尾生效校验整段删掉——得到的都是无效反证结果。

最终靠对比 CI 日志定位：成功的 doc-ctex 的 `resolved:` 落在 `.../texmf-local/...`
（新版），失败的 doc-zhmetrics 落在 `.../texmf-dist/...`（旧版）。然后用最小方式单独
验证 kpse 行为本身（在 `!!` 树上放文件，不刷新→找不到、刷新→找到），才拿到干净反证。

反直觉的一点值得单独记：其他 doc job 能成功，靠的是 kpse「ls-R 比目录旧就回退扫盘」
这个宽容行为；zhmetrics 因为刚刷过索引，回退被关掉，所以**偏偏是「刷过索引」的那个
job 失败**。

### 3. `curl` 退出码 0 但产物残缺，使失败延后到末尾并报出错误原因

第一版失败的 doc-zhmetrics 日志里，`mirrors.ctan.org` 重定向到
`ctan.math.illinois.edu` 后三次 `curl: (28) Timeout`，但 curl 最终返回 0，`-o` 只写出
空文件。脚本因此走进成功分支并 `break`，`unzip -oq` 静音失败，docstrip 在空目录无输出，
`cp` 收到未匹配的 glob 字面量——一路静默到末尾，被 kpsewhich 生效校验拦下，但报出的是
「注入未生效」，与真实原因（网络）无关，误导排查方向。

修法：每个 mirror 下载后验 `-s` 非空加 `unzip -tq` 完整性，并加 `--max-time 300`；
docstrip 输出不再丢 `/dev/null`；`nullglob` 加显式计数替代裸 glob。末尾的 kpsewhich
校验保留——它确实挡住了坏产物，只是不该是唯一防线。

### 4. 漏了「共享脚本要纳入 CI 触发路径」，靠 bot review 指出

两个 bot（Codex 主链路与 Claude fallback）都独立指出 `scripts/sync-l3backend.sh` 不在
任何触发白名单里。核实成立，且有两种不同的失效机制：`check-doc.yml` 用 `on.paths`
白名单，改脚本连 workflow 都不会触发；`test.yml` 用 `paths-ignore`，workflow 会触发，
但各包 job 的 `if` 取自 `_all` filter，全为 false 导致整体跳过。已补三处
（`check-doc.yml` 的 `on.paths` 与 `_all` filter、`test.yml` 的 `_all` filter）。

值得记的是 bot 的复现方式比我干净：它直接按 workflow 步骤原样重放（先跑
`Generate zhmCJK tfm/map`，含末尾的 `mktexlsr`，紧接着跑 `sync-l3backend.sh`），一次
就复现了 ls-R 问题。而我在本地一个不具备前提条件的环境里反复试。

### 5. 推送纪律：接了管道、hook 未安装；写记忆前没查 llmdoc 已有内容

本轮我一直用 `git push 2>&1 | tail -2`，接了管道，丢掉真实退出码和完整输出。而且
`core.hooksPath` 当时为空（hook 未安装），所有 push 都绕过了 sanity 检查、CI 跟踪与
评论抓取，导致我得手动查 CI 与 bot 评论。用户在本轮末尾要求把推送纪律写入 `CLAUDE.md`
并跑了 `make hooks`。时序上纪律是在这些 push 之后才写下的，但问题本身值得记。

另有一处同类复发：该纪律在 llmdoc 里**已有三份记录**
（`guides/push-and-pr-review-workflow.md`、`memory/decisions/repo-push-hook-discipline.md`、
`reference/repo-git-conventions.md`），而我写进 `CLAUDE.md` 的版本在两处比 guide 弱：
缺 `post-push: ✔ push succeeded` 这个明确判据，缺 rc 75 的语义（CI 已过但存在未确认
review 活动或未解决 thread）。说明我在写记忆前没有先查 llmdoc 是否已有该内容——与
#1048/#1050 反思里「排查上游问题前先查本仓库文档」是同一类错误的复发，只是这次的对象
从「排查」换成了「写文档」。

## Root Cause

- **看起来像笔误的字符，可能在工具链里有语义。** `!` 在正文里确实像误敲，但它是
  makeindex 的 quote 字符。我改它的依据只是「读起来不像句子的一部分」，没有查 `.ist`
  文件里的 quote／actual／level／encap 四个指令。这处内容还是用户已经写好、且我并未
  被要求修改的部分。
- **「反证失败」不等于「假设错误」。** 反证是一次实验，实验有前提条件。本地
  `TEXMFHOME` 不在 `TEXMFDBS` 里、不带 `!!`，因此走磁盘搜索，不受 ls-R 约束——这个
  环境无论改不改 `mktexlsr` 都不会失败。我把「实验没复现」直接读成「假设是错的」，
  跳过了「这个环境具备复现该问题的前提吗」这一步。这是 #1048/#1050「注入类实验必须有
  可核实的生效判据」的否命题形态：那条管的是「实验做成了吗」，这条管的是「实验环境
  有能力区分两种结论吗」。
- **用 `sed`／`perl` 删真实脚本的片段做对照实验，破坏了脚本结构。** 对照实验要改的是
  一个变量，而删片段同时改了脚本的语法完整性；两次都得到无效结果。正确做法是写一个
  最小独立复现，直接测被怀疑的那个机制本身（在 `!!` 树上放文件，刷新／不刷新各查一次
  kpsewhich），而不是阉割真实脚本。
- **退出码不是产物合格的判据。** `curl -fsSL --retry` 在重定向后连接超时、重试耗尽的
  情况下仍可能返回 0 且只写出空文件。脚本把退出码当成唯一判据，后续每一步（unzip、
  docstrip、`cp` 裸 glob）又各自静默容忍空输入，失败因此被推迟到末尾，报出的原因与
  真实原因无关。
- **共享代码的触发面没有随共享动作一起更新。** 把逻辑从 `_test-package.yml` 抽成
  `scripts/sync-l3backend.sh` 时，我更新了三处调用点，但没更新「哪些文件改动会触发这
  三条路径」。两个 workflow 的失效机制还不同（白名单不含 vs 触发了但 job filter 全
  false），只查一个也不够。

## Missing Docs or Signals

- kpse 的 `!!` 前缀与 `TEXMFDBS` 语义在本仓库文档里完全没有记录。`reference/build-and-test.md`
  的「本地 TeX Live usertree 同步」一节讲的是往 usertree 装文件，但没讲装进去之后
  kpse 能不能看见，以及这一点在本地与 CI 上有结构性差异（本地 `TEXMFHOME` 通常是普通
  树，CI 上 setup-texlive-action 让它落到 `!!` 树）。这正是本轮反证失败的根源。
- 「本地环境是否具备复现某个 CI 问题的前提」没有一份可查的检查清单。#1048/#1050 已经
  在 `build-and-test.md` 建了「本地测试失败的环境指纹检查表」，但那张表回答的是「失败
  是不是环境造成的」，不回答「我这个环境能不能用来做这次反证」。
- makeindex 特殊字符（`actual '='`、`quote '!'`、`level '>'`、doc 的 encap `|`）对
  `\changes` 条目的约束，以及 `.gls` 与 `extract-changes.py` 生成的 `CHANGELOG.md`
  是两个下游、需要同时干净这一约束，`reference/coding-conventions.md` 里没有。#879 的
  反思讲的是 catcode 6 的实现，没有覆盖它的 `\changes` 条目怎么写。
- 「新增或抽出被多个 workflow 共用的脚本时，必须同步更新触发白名单与各包 job filter」
  没有形成显式步骤。`check-doc.yml` 的注释已经列举了该白名单覆盖什么，但没有反向的
  「加了共享脚本要回来改这里」的指引。
- doc 路径存在检测盲区且尚无自动内容哨兵：错配下 `l3build doc` exit 0、PDF 页数与体积
  正常、`scripts/verify-doc-output.sh` 的三条判据（文件存在、`%PDF` 魔数、>=1024 字节）
  全过，只有版面上能看出泄漏。本轮已给 check-doc 在成功时也上传 PDF artifact 供目视，
  但这是人工环节，不是自动判据。属于已知技术债。

## Promotion Candidates

**应进 `memory/lessons-learned.md`（跨任务判断规则）：**

- **「反证失败」不等于「假设错误」：先确认实验环境具备复现该问题的前提条件。** 建议
  写在现有「注入类实验必须有可核实的生效判据」（第 518 行）之下，作为同一主题的否命题
  形态，而不是新增一条独立条目——那条问「实验做成了吗」，这条问「这个环境有能力区分
  两种结论吗」。Why 用本轮事实：本地 `TEXMFHOME` 不在 `TEXMFDBS` 中、不带 `!!`，走磁盘
  搜索，去掉 `mktexlsr` 也不会失败；据此撤回了一个正确的修复，绕两条弯路后靠 CI 日志
  重新确认。
- **命令退出码为 0 不等于产物合格；每一步都要在发生处校验产物。** `curl -fsSL --retry`
  在重定向后超时、重试耗尽时仍可能返回 0 且只写空文件。下载后验非空加格式完整性
  （`unzip -tq`），中间步骤不要把输出丢 `/dev/null`，裸 glob 换成 `nullglob` 加显式
  计数。否则失败被推迟到末尾的总校验，报出的原因与真实原因无关，误导排查方向。
- **对照实验不要用 `sed`／`perl` 删真实脚本的片段，改用最小独立复现直接测被怀疑的机制。**
  删片段同时改了脚本的语法完整性，等于一次改了两个变量；本轮两次这样做，一次语法错误
  exit 2、一次把末尾生效校验整段删掉，两次结果都无效。
- **看起来像笔误的转义字符，先查它在工具链里是否有语义，尤其是用户已写好、自己并未被
  要求修改的内容。** Why 用 `\&!=6` 这个例子：`!` 是 makeindex 的 quote 字符，改掉后
  `l3build doc` 报 `Extra }`。
- **抽出被多个调用点共用的脚本时，触发白名单与 job filter 属于「调用点」的一部分。**
  只更新三处 `run:` 不够；两个 workflow 的失效机制还不同（`on.paths` 白名单不含该文件
  → workflow 不触发；`paths-ignore` 会触发但各包 job 的 `if` 取自 `_all` filter，全为
  false → 整体跳过）。这与已有的「复合 Action 与 job step 是两套字段与默认值语义」同
  属 CI 结构类，落在同一节。
- **写入个人／项目记忆之前，先查 llmdoc 是否已有该内容。** 本轮把推送纪律写进
  `CLAUDE.md` 时，llmdoc 已有三份记录，而我写的版本缺 `post-push: ✔ push succeeded`
  判据与 rc 75 语义。这是 #1048/#1050「排查上游问题前先查本仓库已有根因记录」的同一
  条规则换了对象（从「排查」到「写文档」），建议直接扩写那一条的适用范围，而不是新增
  条目。

**应进 `reference/build-and-test.md`：**

- 在「本地 TeX Live usertree 同步」一节新增「kpse 的 `!!` 树与 ls-R」小节，记录：
  `texmf.cnf` 的 `TEXMFDBS = {!!$TEXMFLOCAL,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFDIST}`，
  `TEXMF` 列表里 `$TEXMFHOME` 无 `!!` 前缀；`!!` 语义是只查 ls-R、绝不扫磁盘（实测
  `!!` 树下磁盘上真实存在的文件，无 ls-R 条目时 `kpsewhich` 完全找不到）；kpse 对无
  `!!` 的树有「ls-R 比目录旧就回退扫盘」的宽容行为，刷过索引反而关掉这个回退；
  `mktexlsr` 在没有 ls-R 的树上会新建一个。
- 记录本地与 CI 的结构性差异：CI 上 setup-texlive-action 让 `TEXMFHOME` 解析到
  `.../setup-texlive-action/texmf-local`（带 `!!` 的那棵树），本地 `TEXMFHOME` 通常是
  普通树。**因此涉及 usertree 可见性的问题，本地默认无法复现**，这是「本地测试失败的
  环境指纹检查表」之外的另一类差异：不是失败原因不同，而是本地不具备失败的前提。
- 记录 `scripts/sync-l3backend.sh` 的存在、三处接入点（`_test-package.yml`、
  `_check-doc-package.yml`、`release.yml`）、必须在 `l3build ctan` 之前、以及撤除判据
  （脚本打印的两个日期一致时它输出 `::notice::` 并 exit 0，即为空操作）。#1048/#1050
  已记录 `_test-package.yml` 里的内联版本，需要更新为「已抽成脚本并接入三处」。
- 记录 doc 路径的检测盲区：l3backend 错配下 `l3build doc` exit 0、PDF 页数与体积正常、
  `verify-doc-output.sh` 三条判据全过，只有版面上能看出泄漏；check-doc 成功时也上传
  PDF artifact 供目视，属人工环节。验收方式可参考本轮的做法：下载 artifact 后
  `pdftotext` 再检索泄漏模式，本轮 `xeCJK.pdf`（249 页）与 `xunicode-symbols.pdf` 计数
  均为 0。

**应进 `reference/coding-conventions.md`：**

- 新增一条 `\changes` 条目里 makeindex 特殊字符的约束：`gglo.ist` 定义 `actual '='`、
  `quote '!'`、`level '>'`，doc 的 encap 是 `|`；条目正文里出现这四个字符必须用 `!`
  转义，否则条目在该处截断并在排版时报 `Extra }`。同时记录两个下游的联合约束：`.gls`
  与 `scripts/extract-changes.py` 生成的 `CHANGELOG.md` 都要干净，所以 `!` 转义会漏进
  CHANGELOG、`|&|` 会撞 encap，**优先改写句子绕开这些字符**。

**应进 `memory/doc-gaps.md`：**

- 登记「doc／ctan 排版路径缺自动内容哨兵」：l3backend 错配这类缺陷在 doc 路径上不触发
  任何退出码，现有 `verify-doc-output.sh` 的三条判据对它零判别力，只能靠目视 artifact。
  可行方向是 `pdftotext` 后按已知泄漏模式（`gray 0`、`1.0 0.0` 等）检索并断言计数为 0，
  但需要先确认该模式不会与正常正文冲突。本轮未做。

## Follow-up

- recorder 按上面四个落点执行；`reference/build-and-test.md` 里 #1048/#1050 关于
  `_test-package.yml` 内联 workaround 的描述需要改为「已抽成 `scripts/sync-l3backend.sh`
  并接入三处」，撤除判据不变（脚本打印的两个日期一致时输出 `::notice::` 并 exit 0）。
- `CLAUDE.md` 的「推送纪律」一节应与 `guides/push-and-pr-review-workflow.md` 对齐，补上
  `post-push: ✔ push succeeded` 这个明确判据与 rc 75 的语义（CI 已过但存在未确认 review
  活动或未解决 thread）。这一节由用户要求写入，改动前应与用户确认。
- tlnet 的 l3backend 追上 l3kernel 后，删掉 `scripts/sync-l3backend.sh` 及其三处调用；
  判据是脚本打印的 `::notice::`。
- doc 路径的自动内容哨兵作为独立议题跟踪，先在 `doc-gaps.md` 留档。
- 下次做反证之前，先问一句「这个环境具备让两种结论表现不同的条件吗」；答案不确定时，
  用最小独立复现直接测被怀疑的机制，而不是改真实脚本。

## 相关

- 上游根因：expl3 2026-07-20 的 `\__color_select_aux:nnN` 调
  `\__color_backend_select_<model>:nN`，l3backend 2026-02-18 只有 `:n`；受影响后端为
  xetex、dvipdfmx。
- 实现：`scripts/sync-l3backend.sh`；接入点
  `.github/workflows/_test-package.yml`、`_check-doc-package.yml`、`release.yml`；
  触发路径 `check-doc.yml`（`on.paths` 与 `_all` filter）、`test.yml`（`_all` filter）。
- 相关反思：[[1048-1050-upstream-l3backend-pgf-baseline-drift]]（同一上游漂移的前一轮，
  确立「注入类实验必须有可核实的生效判据」与「排查上游问题前先查本仓库已有根因记录」，
  本轮两条都有后续）、[[1046-1047-meta-anchor-font-context]]（同一 l3backend 错配的最早
  症状记录，以及「为真实现象编一个未验证的成因」这一失效模式）、
  [[935-check-doc-zhspacing-blockers]]（`check-doc.yml` 的由来与 zhmetrics 顶层 tfm/map
  的特殊处理，本轮 ls-R 问题正出在那一步之后）。
- 相关决策：[[repo-push-hook-discipline]]（推送纪律的既有记录）。
