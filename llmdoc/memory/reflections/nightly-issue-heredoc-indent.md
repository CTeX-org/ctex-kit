---
name: nightly-issue-heredoc-indent
description: 记 test.yml 定时失败自动开 issue 时 GitHub Actions run 块 heredoc 的两个缩进坑(YAML 剥基准缩进、sed 会误伤 diff 深缩进)，以及没实测就写反向注释两次
metadata:
  type: feedback
---

# 反思：给 test.yml 加定时失败自动开 issue 时的 heredoc 缩进两坑

## 任务

给 `.github/workflows/test.yml` 加 `file-issue-on-schedule-failure` job：定时任务失败时用
`gh issue create --body "$BODY"` 开 issue，`$BODY` 是含失败包清单、diff 正文、排查入口的多行
markdown，用 `cat <<EOF ... EOF` 构造。功能本身顺利实现（提交 `5f5591fb`），本反思只记录构造
heredoc 时踩的两个缩进陷阱，以及在没实测前把注释写成与实际相反的两次错误。

## 预期与实际

- 预期：`run: |` 里的 heredoc 写法与本地 shell 脚本一样直观，缩进只是排版问题。
- 实际：YAML 块标量的缩进语义与 shell heredoc 的缩进语义互相干扰，凡是「按 YAML 源码的视觉
  缩进去判断 shell 会收到什么」都会得出错误结论，必须解析出真实脚本文本才能确认。

## 出了什么问题

### 陷阱一：YAML 块标量 `run: |` 会剥掉公共基准缩进，heredoc 内容行必须顶着基准缩进写

workflow 里 `run:` 脚本整体在 YAML 源码中缩进 10 空格。YAML 的 `|` 块标量会把整个脚本的
**公共基准缩进剥掉**再交给 shell 执行。因此：

- heredoc 的结束标记 `EOF` 在 YAML 源里带 10 空格缩进，但 YAML 剥基准后它顶格，heredoc 能
  正常结束（普通 `<<EOF` 要求结束标记顶格，`<<-EOF` 才允许缩进）。
- 但内容行如果在 YAML 源里**相对基准多缩进**（比如 markdown 列表续行想多缩进 3 格来对齐），
  YAML 剥基准只剥公共部分，那多出的 3 格会**原样留在 body 里**，导致 markdown 渲染错误
  （≥4 空格缩进在 GFM 里会变成代码块）。

正确做法：heredoc 内容行（含列表续行）都顶着基准缩进写，与其他内容行同级，YAML 剥基准后正好
顶格进入 body。验证方法必须是`python3 -c "import yaml; ..."` 解析出 `run:` 脚本的真实文本，
逐行看 `repr()`，确认剥基准后的实际缩进——不能靠肉眼看 YAML 源，因为源里的缩进和 shell 实际
收到的文本不是一回事。

### 陷阱二：想用 sed 剥缩进会误伤 diff 正文里本就带深缩进的行

第一版误判成「heredoc 内容带 10 空格前缀需要剥」（这是基于陷阱一里错误的缩进模型，以为 YAML
不会剥基准），于是加了 `cat <<EOF | sed 's/^          //'`。

更糟的是，即便真的要剥，`sed 's/^ \{10\}//'` 会**无差别剥掉任何以 10 空格开头的行**——而贴进
body 的 `.diff` 正文里，LaTeX 节点 diff 行（如 `.....\special{pdf:...}`、`\hbox` 节点）本身就
带 ≥10 空格缩进，会被这条 sed 破坏。

正确做法：body 分三段拼接，`BODY="${HEAD}${DIFF_SECTION}${TAIL}"`。静态部分（`HEAD`/`TAIL`）
顶格写、不过任何缩进处理；diff 正文（`DIFF_SECTION`）单独构造、绝不过 sed，也不做任何缩进
变换，原样夹在中间。

### 两次「没实测就把注释写成具体结论，且与事实相反」

同一段代码的注释上连续犯了两次：

1. 第一次写「heredoc 内容带缩进前缀需要 sed 剥」——实际 YAML 已经剥了基准，sed 是多余的。
2. 更正陷阱一之后，又写「sed 不影响 diff 正文」——实际这条 sed 会误伤 diff 里本身带深缩进的
   行。

两次都是先写结论、后来实测才发现结论与事实相反，最终靠三步实测才定案：从 YAML 提取真实脚本
喂 bash 实跑、`cat -A` 看行尾与缩进、造一份带深缩进的假 diff 验证不会被破坏。

## 根因

两处失误的共同根因是同一件事：**把 YAML 源码的视觉缩进当成了 shell 实际收到的文本**。这个
假设在 heredoc 场景下是错的，因为中间多了一层 YAML 块标量剥基准缩进的转换；肉眼读 YAML 源码
看不出这层转换的结果，必须让转换真的发生一遍（解析 YAML）才能看到 shell 端的真实文本。第二次
错误（sed 误伤 diff）则是在第一个错误尚未纠正、模型本身就错的前提下，顺着错误模型继续设计
「补丁」，补丁本身又引入了新的无差别匹配问题。

## 缺失的文档或信号

`llmdoc/reference/build-and-test.md` 与仓库里其他 CI 相关文档此前没有记录「YAML 块标量剥
基准缩进」这条通用行为——此前的 workflow 改动大多是纯 shell 逻辑或简单字符串拼接，没有涉及
多行 heredoc，所以这条坑第一次在本仓的 CI 编写里现身。验证 workflow shell 逻辑此前的通用方法
（本仓已有：提取 `run:` 文本喂 bash 实跑）没有专门强调「YAML 解析」这一步对缩进语义的必要性，
容易被简化成「跑一下看报错」而漏掉缩进这种不报错、只在渲染时才显现的问题。

## 可提升为稳定文档的候选

以下几条是跨任务通用的 CI 编写规则，建议 recorder 评估是否收进
`llmdoc/reference/build-and-test.md` 或 `llmdoc/guides/`：

1. GitHub Actions `run: |` 块里用 heredoc 构造多行文本时，YAML 会剥公共基准缩进——内容行相对
   基准多出的缩进会原样漏进输出；验证要用 python 解析出真实脚本文本看 `repr()`，不能看 YAML
   源码的视觉缩进。
2. 不要用 sed 剥缩进来清理会嵌入「本身带缩进的数据」（如 diff、日志）的文本；把静态文本与数据
   分段拼接，数据段绝不过缩进变换。
3. 验证 workflow 的 shell 逻辑要提取真实脚本喂 bash 实跑，YAML lint 只保证语法、不保证 body
   渲染是否正确，二者不能互相替代。
4. 用 GitHub label 前先用 `gh api repos/.../labels/<name>` 或 `gh label list` 确认它在目标
   仓库存在；用不存在的 label 会让 `gh issue create` 失败（本次用的是仓库已有的 `upstream`，
   未使用不存在的 `ci` label）。

这与 [[1043-halign-alignment-tab-in-boundary-args]]、[[1057-fntef-nest-linebreak]] 记录过的
「没实测就把注释/结论写具体」是同一失效模式在 CI/shell 载体上的又一次发作：先写看起来合理的
结论，实测才发现方向相反。

## 后续

- 若之后还有 workflow 需要用 heredoc 拼多行 markdown/文本，先检查是否已引用本反思或
  `build-and-test.md` 里对应小节，避免重犯同一模型错误。
- 若 recorder 采纳促升，把第 1、2 条写进 `llmdoc/reference/build-and-test.md` 的 CI/CD 小节
  （紧邻 `file-issue-on-schedule-failure` 已有记载处），第 3、4 条可并入既有的「验证 workflow
  shell 逻辑」相关表述里，避免与已有内容重复表达。

## 相关

- 实现：`.github/workflows/test.yml` 的 `file-issue-on-schedule-failure` job（提交
  `5f5591fb`）。
- 文档：`llmdoc/reference/build-and-test.md` 「定时失败自动开 Issue 哨兵」一节。

## 追加：PR #1087 code review 阶段暴露的两个边界问题（离线验证只测了正常输入）

同一个 `file-issue-on-schedule-failure` job 提交为 PR #1087 后，`agentic-pr-review` bot
分两轮各提一个小问题，都是真实的、我最初漏掉的。两个问题都已修复并本地验证，且都源于同一件
事：离线验证 body 构造脚本时只用正常输入（几个包失败、小 diff）跑过，没有主动构造边界输入。

### 边界一：失败清单漏了 `warmup-tl`，诊断信息缺失

`test-result` 聚合 job 把 `warmup-tl`（TeX Live 预热）失败也计为整体失败。预热失败时各包
caller 因 `needs: warmup-tl` 全部 `skipped`，而我的失败清单只列了 7 个 test 包、不含
`warmup-tl`，于是 body 只显示"未能从 job 结果判定"，指不出真正的失败阶段。

修法：失败清单纳入 `warmup-tl`；并加兜底，清单为空时单独标出 `test-result` 聚合状态。

教训：枚举"哪些 job 失败"时，枚举范围必须等于聚合判定的范围。`test-result` 判的是 8 个
job（含 `warmup-tl`），我只枚举了 7 个，漏的那一个恰好是"其他全部 `skipped`、只有它失败"
这一整类场景的唯一信息来源。

### 边界二：diff 按字节硬截断，且 `head -c` 会因 SIGPIPE 终止整个 step（两个 bug 叠在一处）

`DIFF_BODY` 用 `head -c 40000` 按字节硬截断。截断点可能落在某个未闭合的 ```diff 围栏中间，
把后续「排查入口」一段吞进代码块，body 渲染错乱。

更严重的是：`head -c` 读满目标字节数就关闭管道，上游 `printf` 收到 SIGPIPE；在
`set -o pipefail` 下这条管道整体返回非零退出码，配合 `set -e` 会**终止整个 step**——这比
渲染错乱更糟，因为本该在失败时报警的机制，自己先挂了、连 issue 都开不出来。

修法初版（截断后无条件补一个闭合围栏）本身也是错的，被 bot 第三轮 review 证伪：无条件补
闭合围栏**只在**截断点落在未闭合的 ```diff 围栏内（此时截断后 ``` 出现次数为**奇数**）才
正确；若截断点恰好落在两个完整围栏之间、或落在标题行上（此时 ``` 已配平、为**偶数**），
再补一个 ``` 反而会**打开**一个新代码块，同样吞掉后续「排查入口」——与不补时的 bug 方向
相反。最终修法：数截断后 `DIFF_BODY` 里 ``` 出现的次数，**奇数才补一行闭合围栏，偶数不
补**，随后再拼接截断提示；`head -c` 那一行加 `|| true` 容忍 SIGPIPE。三种截断位置（围栏
中间／围栏之间／正好在闭合处）本地单测均已验证配平。

教训两条：

1. 拼接"带结构定界符的分段内容"（如 fenced code block）之后再做长度截断，必须考虑截断点
   会破坏结构——不能无条件补齐闭合定界符，要按截断后定界符的奇偶（或更一般地，按结构是
   否已配平）判断是否需要补齐，或按完整单元累计截断。
2. `set -o pipefail` 下，任何"故意提前关闭管道"的命令（`head -c`、`head -n`、`grep -q`
   等）都会让上游进程收到的 SIGPIPE 传成该管道的非零退出码，配 `set -e` 会杀死整个脚本；
   这类管道要显式加 `|| true`。

### 元教训

这两个问题都是边界输入：一个是"只有预热失败、其他全部 skipped"，一个是"diff 超大"。我离线
用"提取真实脚本喂 bash 实跑"的方法验证过 body 构造逻辑，但只喂了正常输入，没有构造这两种
边界场景，所以自测没发现，靠 bot 两轮 review 才逐个暴露。

教训：离线验证 CI 脚本时，正常输入通过不算完——要主动构造边界输入（空集合、超大输入、只有
某一个维度处于非正常状态），尤其要警惕"本该在异常时报警的机制，在极端输入下自己先失效"这
类失败（`head -c` 触发 SIGPIPE 终止 step 就是一例：issue 自动化的价值就是失败时报警，而它
自己在大 diff 输入下不报警了）。这与本反思前面记录的"没实测就把注释写具体"是同一类问题的
另一种表现——都是验证覆盖不足，只是这次覆盖不足的维度是输入空间的边界，而不是注释所述事实
的真伪。

"diff 按字节截断"这一处前后改了三轮才对：硬截断（截断点破坏结构）→ 无条件补闭合围栏（偶数
时反而打开新块）→ 按奇偶补。每一轮我都以为修好了、也本地测过，但每轮只测了"上一个反例"，
没有穷举截断点相对定界符结构的全部落点（围栏内部／围栏之间／正好在闭合处）。bot 每轮构造一
个新落点就又证伪一次。教训：处理"在任意字节位置截断带配对定界符的文本"这类问题，要一次性
枚举截断点相对结构的所有相对位置，而不是每次只补上被指出的那一个反例。

## 追加部分的可提升为稳定文档的候选

1. 枚举"哪些子任务失败"时，枚举范围必须等于上游聚合判定的范围，否则漏枚举的那一类失败会
   显示成"无法判定"。
2. 拼接带结构定界符的分段文本后做长度截断，必须防止截断点破坏结构；判断是否需要补闭合
   定界符要按截断后结构是否已配平（如定界符出现次数的奇偶）来定，不能无条件补，否则在
   截断点恰好落在两个完整单元之间时会反而打开新块；更一般地，处理"在任意字节位置截断带
   配对定界符的文本"这类问题时，要一次性枚举截断点相对定界符结构的所有相对位置（定界符
   对内／对外／正好在边界上），而不是每次只补上被指出的那一个反例。
3. `set -o pipefail` 配 `set -e` 时，故意提前关闭管道的命令（`head -c`、`head -n`、
   `grep -q`）要加 `|| true`，否则上游 SIGPIPE 会杀死整个脚本。
4. 离线验证 CI／shell 逻辑要主动构造边界输入（空集合、超大输入、单一维度异常），不能只测
   正常路径；尤其要警惕"报警机制在极端输入下自己先失效"这类场景。

## 追加二：PR #1087 review 阶段暴露的一个设计级缺陷——宣称的"自动接入 agentic"从未发生

### 事实（已确认）

给 `test.yml` 加的定时失败哨兵 `file-issue-on-schedule-failure`，一直宣称"issue 开出后
`agentic-issue-dispatch.yml` 自动接手分析"（比照 #1085 的路径）。bot 在 review 中指出这是
**错的**：

- issue 用默认 `GITHUB_TOKEN`（`${{ github.token }}`）创建。GitHub 刻意不为 `GITHUB_TOKEN`
  产生的事件（包括 `issues.opened`）再触发任何 workflow，这是平台级的防递归机制（防止
  workflow 互相无限触发）。所以 `agentic-issue-dispatch.yml`（监听 `issues.opened`）根本不会
  被触发——宣称的自动联动从来不会发生。
- 想补救（给 dispatch 加 `workflow_dispatch`／`repository_dispatch` 入口显式触发）会撞上另一
  个约束：合同测试 `scripts/test-agentic-workflow-contract.py` 刻意断言
  `assert "workflow_dispatch:" not in issue`（与 `assert "schedule:" not in issue` 成对），
  即 agentic 体系有意规定"issue dispatch 只被动响应真实 opened 事件、不给任何主动触发入口"
  （对比 llmdoc-updater 明确允许 `workflow_dispatch:`，是有意的差别设计）。推翻这条约束触及
  #874／#1032 反复强调的 agentic runtime 稳定性红线，不该顺手做。
- 处置：当前 PR 降级——把"自动接入 agentic"从功能和文档里如实拿掉，issue 仍用
  `GITHUB_TOKEN` 正常开（开 issue 本身完全不受影响），只作"提醒＋诊断"，分析需人工或另行接
  入；agentic 显式触发留作独立议题（先搞清那条 `workflow_dispatch` 禁令的完整原意再做）。

### 教训（重点）

1. `GITHUB_TOKEN` 产生的事件不会触发下游 workflow，是设计"由 CI 自动创建
   issue／PR／comment 再联动下一个 workflow"时必须先确认的平台约束。设计阶段把"issue 一开
   agentic 就接手"当成了理所当然（因为 #1085 是真人开 issue 触发的，那条路径真实存在），
   没意识到"真人开"和"`GITHUB_TOKEN` 开"在触发下游上有本质区别。要联动必须用 App／PAT 等能
   产生事件的身份，或显式 dispatch。
2. 这个假设本可以在设计阶段被证伪：只要查一下"`GITHUB_TOKEN` 创建的 issue 能否触发 issues
   workflow"就知道。却把它写进了功能卖点、注释、PR 描述和 llmdoc 三处，直到 bot 指出——是
   "没实测就把结论写具体"在**设计假设**层面的又一次发作（前面几次是注释真伪、输入边界，这次
   是平台行为假设）。跨 workflow 联动的触发条件属于"必须先验证再写进设计"的一类。
3. 改一个功能前先看它会不会推翻某条被测试固定的现有约束：`workflow_dispatch not in issue`
   是合同测试明写的断言，加触发入口前必须先理解这条断言的原意（为什么 issue dispatch 刻意
   不给主动入口），而不是直接改断言让测试过。测试里成对出现的否定断言（`schedule` 加
   `workflow_dispatch` 都禁）往往是刻意的安全边界。

### Promotion 候选

1. 设计"CI 自动创建 issue／PR／comment 触发下游 workflow"前，先确认创建身份：默认
   `GITHUB_TOKEN` 产生的事件不会触发任何 workflow（防递归），要联动需 App／PAT 或显式
   dispatch。
2. 跨 workflow 联动的触发条件属于"写进设计前必须先验证"的平台行为，不能想当然（尤其"真人
   操作触发"与"token 自动操作触发"的区别）。
3. 改动前先检查是否推翻了某条被测试固定的现有约束；测试里成对的否定断言常是刻意安全边界，
   要先懂原意再动。
