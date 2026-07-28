---
name: 1025-agentic-local-runtime-toolchain
description: 记录 #1025 将三条远端 reusable Agent workflow 本地化、补齐排版工具链并收紧凭据和发布边界的过程
metadata:
  type: feedback
---

# 反思：本地维护 Agent runtime 与工具链

## 任务

PR Review、Issue Dispatch 和 llmdoc Updater 原先只是远端 reusable workflow 的薄调用层。
这使 Agent 实际运行在哪个 job、安装什么工具、怎样处理缓存，都由上游模板决定。#1012 的排版
问题需要 Agent 自主编译 MWE、检查 PDF 和比对图片时，这个边界变成了实际障碍：调用方可以在
自己的 workflow 增加前置 job，却不能把 TeX Live、字体和图像工具安装到 reusable workflow
内部那个已经分配好的 runner。

#1025 因而把三条 workflow 展开到本仓库。展开基线是
`Lightspeed-Intelligence/agentic-workflow-template` 的提交
`2a0bb28e6583d869645e0a0522568df4a5d4d921`；此后 workflow、复合 Action、脚本和
`.claude/skills/` 都由 ctex-kit 自行维护，运行时不再检出或调用上游仓库。

## 工具链要安装在真正运行 Agent 的 job 中

三条 workflow 各有 Codex 和 Claude 两条实际 Agent 链路，共六个 Agent job。六处都调用同一个
`setup-agent-tools` 复合 Action，安装或恢复：

- TeX Live 2026、XeLaTeX、`l3build`、`xdvipdfmx`、`pdfcrop`；
- Noto CJK、HanaMinB、Noto Sans Symbols 2，并把 TeX Live 字体目录注册给 fontconfig；
- Poppler、ImageMagick、Ghostscript、ShellCheck 和 actionlint；
- Bubblewrap、socat 和 C 编译器，用于 Agent 命令沙箱及其控制进程保护。

工具必须在 Agent 所在 runner 内可用。由另一个前置 job 编译固定 MWE 或上传固定证据，只能覆盖
预先知道的检查，不能替代 Agent 根据 diff 自主选择 MWE、字体、字号和 PDF 检查方式。

## 共享缓存需要按运行阶段划分写入权限

最初的实现只调用 `actions/cache/restore`，并把安全规则概括成“Agent job 不能回写共享缓存”。这个
说法混淆了可信安装阶段和随后的 Agent 进程。真正的风险来自普通 `actions/cache` 注册的 post step：
它到整个 job 结束时才保存目录，此时 Agent 或它运行的仓库代码已经有机会修改缓存来源。

修正后的安装 Action 继续复用可信 CI 的 TeX Live weekly key 和两组字体 key，但把 restore 和 save
分开。缓存未命中时，来自 PR base 或固定事件提交的可信 Action 先安装并检查内容，再在 Agent 启动
前用 `actions/cache/save` 立即保存。保存完成、字体暂存目录清理以后，workflow 才启动 Agent；此后
不再注册或执行任何缓存保存动作。也就是说，限制针对的是保存时机和保存前的写入者，不是“包含
Agent 的 job 一律没有缓存写权限”。

完整范围审查还发现，“只恢复”并不等于恢复目标天然可信。字体 cache 为了与现有 CI 保持相同的
cache version，仍恢复到 `$GITHUB_WORKSPACE/.font-cache` 和 `.xecjk-font-cache`；PR head 可以在
Action 运行前预置这两个路径。如果直接恢复并信任 `.done`，PR 便能跳过下载，再让 glob 把预置字体
复制到系统目录。修正后的 Action 在两次 restore 之前先删除并重建两个普通目录，再检查恢复内容只含
规定名称的普通字体文件和 `.done`，拒绝符号链接、子目录和其他文件。安装结束后仍删除暂存目录。

完整性检查还必须发生在系统安装和显式保存之前。CJK 缓存必须同时包含 Noto Sans CJK 和
Noto Serif CJK；xeCJK 文档字体缓存必须包含 HanaMinB、Noto Sans Symbols 2 和 `.done`。符号链接、
子目录和额外文件一律拒绝。完整顺序是“清理暂存目录 → restore 或可信下载 → 白名单和完整性检查
→ 安装进系统 → cache miss 时显式 save → 再次清理暂存目录 → 启动 Agent”。

这说明缓存写入时机与 restore 目标的文件所有权是两条独立边界：Agent 启动前完成显式保存，防止
不可信进程污染共享条目；restore 前清理工作区，防止 PR 文件混入可信缓存内容。两者缺一不可。

## 只隔离 GitHub token 仍然不够

首个本地化提交已经把 Agent 与发布 job（publisher）分开，也没有给 Agent 可写 PAT；但独立审查指出，PR
Review 仍把长期模型 API key 放在执行不可信 PR 代码的 Agent 进程环境里。恶意测试入口即使只是
被 Agent 正常调用，也能继承并外传密钥。这个阻塞问题说明“没有 GitHub 写权限”不能推出“Agent
执行环境没有敏感凭据”。

修正后的边界是：

1. 可信 shell 把模型密钥交给以 root 身份运行的本地固定上游代理；代理只开放 Codex／Claude 实际使用的
   模型路径，删除客户端传来的认证头并注入真实密钥。
2. Agent CLI 以独立的 `ctex-agent` 用户运行。这个用户不属于特权组，运行前还实际验证它不能
   `sudo`、不能读取代理的 `/proc/<pid>/environ`。
3. Agent 用 `env -i` 启动，只看到 `ctex-local-proxy` 占位凭据；真实密钥文件在代理就绪后立即删除。
4. Agent 结束后杀死该用户遗留的后台进程，关闭代理，再恢复工作区所有权和 runner 可读写权限。

这样仍保留 Agent 对 TeX、PDF 和图像工具的本地执行能力，却不让它或仓库子进程取得长期模型密钥。
本地代理不能阻止恶意进程消耗模型调用额度；它解决的是凭据泄漏，不能被描述成完整的不可信代码
沙箱。

后续自检还发现，不能从即将交给 Agent 的工作区持续执行可信启动脚本。即使 Bash 通常会预读一部分
脚本，也不能假定 Agent 无法改写尚未读取的清理命令。复合 Action 因此先把启动脚本和代理复制到
runner 自己的临时目录并限制权限，再把工作区所有权交给 Agent；root 代理也通过 `env -i` 用最小
环境启动。可信控制程序与不可信工作区必须在文件所有权上分开，不能只在 Git 提交来源上分开。

## 最终结果通道也不能与仓库代码共用写权限

后续完整盲审发现，杀死后台进程仍不足以保护 PR Review 的结论。Agent CLI 和它执行的 PR 测试原先
使用同一个 UID、同一个 HOME 和固定结果文件；恶意测试可以留下后台进程，在 CLI 结束后、清理 trap
运行前，把结构合法的 `APPROVE` 写进结果文件。把 `pkill` 提前只能缩短竞态窗口，不能证明最后一次
写入来自 CLI。

修正后的结果通道同时使用三层边界：

1. Codex 使用 `workspace-write` 且不允许请求额外权限；Claude 启用文件系统沙箱、禁止 unsandboxed
   command，并在沙箱不可用时直接失败。模型生成的命令只能写 consumer 工作区，不能写控制目录。
2. CLI 把最终结果写到 `/run/ctex-agent-session.*/control/`，不再写 Agent HOME 或 `/tmp`。可信启动
   Action 编译一个很小的预加载库；CLI 每次 `exec` 后都设置 `PR_SET_DUMPABLE=0` 和
   `PR_SET_NO_NEW_PRIVS=1`，同 UID 子进程不能通过 `/proc/<pid>/fd` 或 ptrace 绕过路径沙箱。
3. CLI 返回后，可信脚本反复结束该 UID 的全部残留进程，确认没有进程存活以后才读取控制结果；
   session 目录最后由 `sudo rm -rf` 删除，不能依赖 runner 删除 Agent 所有的非空目录。

合同测试一方面用 Bubblewrap 把 consumer 设为唯一可写目录，让恶意脚本连续改写控制文件并确认内容
不变；另一方面实际编译预加载库，让同 UID 子进程尝试打开父进程的 `/proc/<pid>/fd`，确认访问被拒绝。
静态断言还固定两个 CLI 都不能恢复 bypass 选项。结果文件的 JSON Schema 校验仍然需要，但它只能
检查数据形式，不能替代来源隔离。

## Agent 返回后仍要保持信任边界

完整范围审查又发现了两个同类问题。Issue Dispatch 虽然从固定事件提交取得了结果整理脚本，却在
Agent 返回后从 Agent 可写的 `consumer` 工作区执行它。Agent 可以直接改写脚本，还可以用
`git update-index --assume-unchanged` 或本地提交让普通 `git status` 看起来没有变化。因此，“检出时
来自可信提交”和“Git 显示工作树干净”都不能证明随后执行的文件仍然可信。

修正后，Issue Dispatch 在 Agent 启动前便把结果整理脚本复制到 runner 的私有临时目录；Agent 返回
后只把结果文件作为不可信数据交给这份副本处理，不再执行 `consumer` 中的脚本，也不再对该工作区
运行 Git 来判断文件是否可信。

llmdoc Updater 原先也会在 Agent 控制的仓库中以 runner 身份执行 Git。即使只打包 `llmdoc/`，Agent
仍可修改 `.git/config`，例如设置 `core.fsmonitor`，让后续 `git status` 间接执行任意程序。修正后的
打包阶段重新把固定 master 提交检出到 `package-base`，只从 Agent 工作区复制 `llmdoc/` 文件树；
所有 Git 比较和补丁生成都在这个新仓库中完成，不读取 Agent 控制的 `.git`。

这两个问题共同说明：结束 Agent 进程并恢复目录所有权，只能阻止它继续写入，不能使它已经控制过的
脚本、Git 配置或索引状态重新可信。后处理必须从 Agent 启动前保存的可信程序和 Agent 返回后新建的
可信仓库开始，只把 Agent 产物当作待校验的数据。

## 事件提交和发布权限必须分别固定

- PR Review 从 PR base SHA 稀疏检出审查规范、安装 Action、Agent 启动脚本和历史准备脚本；PR head
  只作为不可信审查对象。Agent job 只读，唯一拥有 `pull-requests: write` 的 publisher 不运行 Agent。
- Issue Dispatch 固定到事件 `github.sha`。两个分析 Agent 只读，独立发布 job 才能发表评论。
- llmdoc Updater 在准备 job 解析 master SHA；Agent 只生成候选，独立校验 job 从同一 SHA
  重建仓库并验证候选，publisher 才持有 `contents: write` 和 `pull-requests: write`。

这个规则也覆盖只负责通知的 Action。`workflow_dispatch` 可以从非 master ref 发起；若通知 job 用
`github.sha` 检出本地 Action，就会把长期 webhook secret 交给 dispatch ref 中的代码。通知现在优先
使用 prepare 解析的 master SHA；prepare 失败时明确回退到 `master`，不能回退到触发 ref。

准备 job 与 Agent 之间的数据通道也要给出实际路径。llmdoc 的 `task.json` 保存 `since_period`，
`recent-commits.txt` 保存精确提交集合；Agent 通过 `env -i` 启动后看到的 `RUNNER_TEMP` 已经改变，
提示词不能只写裸文件名。两个候选 prompt 现在都在生成时展开下载目录的绝对路径，并明确要求先读取
这两个文件。

固定提交解决“运行哪一版可信代码”，独立 publisher 解决“谁能产生外部写入”；两者不能互相替代。

## 合同测试必须检查失败反例

actionlint 只校验 workflow，不能把 `action.yml` 当作复合 Action metadata 校验。#1025 增加专用
Python 校验器，检查顶层字段、inputs、outputs、`runs.using` 和 composite step，并用预期失败的
错误样例（负向夹具）证明门禁会失败。

PR Review 的结构化结果也需要负向夹具。仅检查存在 jq 片段不足以证明三处语义一致；合同测试现在
提取 Codex、Claude 和 publisher 的实际 jq 过滤器，确认零 finding 的 `COMMENT` 被拒绝、至少有
一个小问题的 `COMMENT` 才能通过。

后续独立审查还发现，`run-agent` Action 新增 `agent-control-hardening.c` 后，PR Review 两处固定到
base 提交的 sparse checkout 没有同步取出这个文件。Action metadata 和 C 源码本身都能通过检查，
但 job 会在安装 Action 时因文件不存在而失败。只在 workflow 中搜索某几个已知脚本名，不能证明
可信 checkout 已包含 Action 的完整运行时依赖。

修正后的合同测试直接读取 `run-agent/action.yml`，从 `$GITHUB_ACTION_PATH` 引用推导仓库内文件
依赖，再逐一比对 Codex 和 Claude 的 sparse checkout 清单；测试还删除其中一条 C 文件路径，确认
门禁会拒绝缺失依赖。以后本地 Action 新增脚本、二进制源码或其他运行时文件时，应把“更新所有固定
提交 checkout”视为同一项修改，而不是等 job 启动失败后再补文件。

## 审查评论需要同时保留历史和重跑幂等性

PR Review publisher 不能每次运行都新建评论，否则同一个 head 重跑会产生重复噪音；也不能用一条
PR 级评论覆盖所有运行，否则新 head 会继承旧评论的 `created_at`，不同 head 的独立审查记录也会
消失。当前 marker 绑定具体 head：同一 head 重跑时更新原评论，不同 head 则新建评论。合同测试连续
发布两个 head，并让每个 head 各重跑一次，固定“创建两次、更新两次”的行为。

同一 head 的评论还可能在维护者回复以后再次更新。若 pre-push 只比较 Bot 评论的 `created_at`，旧
回复会被误认为已经确认了更新后的 finding。hook 因而以 `updated_at` 为准，缺失时才回退
`created_at`；只有 OWNER、MEMBER 或 COLLABORATOR 在 Bot 最后更新之后的回复，才算确认了当前
正文。finding 不成立时，维护者应在最新正文后回复证据，再运行 `make check-pr-ci`，不必用空提交
触发又一轮相同审查。

按 head 保留评论后，长 PR 的 Issue 评论会持续累积。只请求 `per_page=100` 的第一页，可能漏掉
当前 head 新建在后续页的审查评论。pre-push 因而必须使用 `gh api --paginate --slurp` 取得全部页，
展平成一个评论集合后再同时查找 Bot 评论和维护者回复；合同测试把当前 head 的 Bot 评论放在第二页，
固定这一取数边界。

## 门禁的触发文件与实际检查必须相互覆盖

最终完整范围审查发现，合同测试已经直接读取 `.githooks/check-pr-ci.sh`，但合同 workflow 的
`pull_request.paths` 没有包含该文件。这样只修改评论分页或回复时间判断时，恰好用于保护这些行为的
合同测试不会运行。门禁读取或执行的每个仓库文件都必须能触发门禁；新增测试输入时，应同时更新
workflow 的触发路径，并让合同测试反过来固定这项依赖。

同一轮审查还发现，“Agent job 安装 ShellCheck”不等于“合同门禁检查独立 shell 文件”。actionlint
只把 ShellCheck 用于 workflow 内嵌的 `run:` 代码，不会自动读取 `.github/scripts/agentic/*.sh` 或
历史准备脚本。文档声称远端执行某项检查时，workflow 必须有明确的安装和调用步骤，合同测试还要
固定实际文件集合；不能用工具出现在另一类 job 的环境中代替执行证据。

这里还有一层容易漏掉的关系：`.githooks/pre-push` 是 Git 实际调用的 self-wrapper，负责镜像原始
refspec、执行 inner push，再调用 `.githooks/check-pr-ci.sh` 等待远端结果；后者只是完成 CI 与评论
审计的辅助脚本。合同测试会直接或间接依赖两个文件，因此触发路径和 ShellCheck 文件集合都必须同时
包含二者。不能因为辅助脚本承载了主要审计逻辑，就把真正决定调用时机和退出状态的 hook 排除在门禁
之外。

合同测试本身也要区分“原始文件里出现过某段文字”和“这段配置实际生效”。直接在 YAML 文本中搜索
路径，会把注释掉的 `pull_request.paths` 条目当成有效触发条件；直接搜索 `run: |` 的正文，也会把
shell 注释中的参数当成实际命令。触发路径应从 YAML 解析结果中取值，shell 参数应按忽略注释的词法
规则解析，并用注释掉单个条目的负向夹具证明门禁会失败。

解析成 YAML 或 shell token 仍不等于已经检查了行为。job 的 `if` 必须核对完整表达式，否则在预期
条件后追加恒假表达式仍会通过子串检查；`run:` 中出现 `shellcheck` 和某个路径，也不能证明该路径
属于 ShellCheck 的参数。当前合同要求 lint step 只包含一条反斜线续行的 `shellcheck` 命令，再检查
这条命令自己的参数；同时用三个 job 恒定跳过和“路径只交给 `echo`”的负向夹具固定命令边界。

workflow 的完整控制流不只由 job 的 `if` 决定。fallback 是否等待主链、publisher 是否等待两条审查链，
由 `needs` 决定；publisher 真正下载哪个 artifact、何时发表评论、两条链都失败时是否让门禁失败，则由
内部 step 的 `if` 决定。因此，Draft PR 合同还要按解析后的 job 和 step 名精确检查两处依赖与四个
条件，并用删除依赖、逐项禁用 step 的反例证明整条审查结果一定能到达发布或失败出口。

step 的显示名称和条件也不是完整的动作合同。把多个同名 step 放进字典会静默覆盖其中一项；下载
step 即使条件正确，也可能取错 artifact；双失败 step 即使条件正确，也可能只执行 `true`。当前合同
先拒绝重名 step，再把两个下载条件与固定 Action、artifact 名和目标路径绑定；评论幂等行为测试直接
从实际命名的发布 step 取脚本；双失败 step 则由合同测试直接执行，并要求退出状态非零。

## 可复用经验

- reusable workflow 的调用方不能向被调用 job 注入新的 step；需要改变 Agent 所在 runner 的工具链时，
  要修改 reusable workflow 本身，或者把实现本地化。
- 执行不可信代码的 Agent 不能继承长期模型密钥。提示词、只读 GitHub token 和独立 publisher
  都不能替代进程级凭据隔离。
- Agent CLI 的最终结果不能放在仓库命令可写的 HOME 或临时目录。命令沙箱、沙箱外控制目录、
  不可转储的 CLI 进程和读取前进程清理共同保护结果来源；JSON 结构校验本身不能认证写入者。
- runner 后续还会执行的控制脚本必须放在 Agent 无法写入的目录；“脚本来自可信 base SHA”只证明
  初始内容可信，不能防止运行期间被重新取得工作区所有权的 Agent 改写。
- Agent 返回后，不能执行它可写路径中的脚本，也不能用该仓库的 Git 状态证明内容没有被修改；
  `assume-unchanged`、本地提交和 Git 配置都可能破坏这种判断。
- 需要对 Agent 候选执行 Git 比较或打包时，应重新检出固定基线，只复制允许的文件树，并在新仓库中
  完成所有 Git 操作。
- 与可信 CI 共用 cache key 时，可信安装阶段可以在 Agent 启动前显式保存已经检查的内容；Agent
  启动后不得再由 post step 保存共享缓存。
- cache 恢复到不可信 checkout 内的路径时，必须先删除并重建目标，再验证恢复内容；restore 本身
  不能自动清除工作区原有文件。
- 审查评论以 PR head 为幂等键：同 head 更新，不同 head 新建；维护者回复以 Bot 评论最后一次
  `updated_at` 为时间边界，并且审计必须覆盖全部 Issue 评论页。
- 静态合同既要检查目标片段存在，也要用错误输入证明门禁确实拒绝错误状态。
- 合同门禁的触发路径必须覆盖测试读取和执行的全部仓库文件；文档列出的远端检查必须在门禁中有
  明确命令和文件集合，不能把“工具已安装”当成“检查已执行”。
- self-wrapper hook 与它调用的审计辅助脚本是两个独立的门禁输入；触发路径和 ShellCheck 文件集合
  必须分别覆盖二者。
- 检查 workflow 配置时，应断言解析后实际生效的 YAML 字段和 shell 参数；原始文本中的注释不能
  作为配置存在的证据。
- 对 job 条件要比较完整的生效表达式；对 shell step 要先确定命令边界，再检查目标命令自己的参数，
  不能用整个脚本中的 token 集合代替调用关系。
- 检查多 job workflow 时，要同时固定 `needs` 和关键 step 的条件；只检查 job 级 `if` 不能证明结果
  会沿预期依赖链到达发布或失败出口。
- 关键 step 的名称必须唯一，条件还要与实际 Action 输入或 shell 行为绑定；必要时直接执行安全的
  失败出口，不能把“名称和条件还在”当成动作仍然有效。
- 固定提交的 sparse checkout 必须覆盖本地 Action 的完整运行时文件闭包；合同测试应从 Action
  的实际引用推导依赖，并用删除依赖的反例验证门禁。
- workflow 准备的 artifact 必须通过实际绝对路径交给 `env -i` 启动的 Agent；持有长期 secret 的
  辅助 Action 也必须固定到可信提交，不能因为它“只负责通知”而使用触发 ref。
- 上游来源提交属于可追溯的初始基线，不再是运行时依赖；吸收上游变化时必须选择性搬运并重新审查
  本仓库的权限、事件提交和缓存边界。

## 验证

- `python3 scripts/test-agentic-workflow-contract.py`
  - 包含 `assume-unchanged` 隐藏脚本改写、恶意 `core.fsmonitor` 被 Git 执行、字体暂存内容不完整、
    同／异 head 评论发布、第二页 Bot 评论、维护者回复早于 Bot `updated_at`、工作区进程持续改写
    控制结果，以及同 UID 子进程访问父 CLI `/proc/<pid>/fd` 的反例；
- `python3 scripts/validate-action-metadata.py .github/actions/*/action.yml`
- actionlint 检查四条相关 workflow
- ShellCheck 检查 Agent runtime 和历史准备脚本
- 固定提交、断网快照中的独立本地审查
