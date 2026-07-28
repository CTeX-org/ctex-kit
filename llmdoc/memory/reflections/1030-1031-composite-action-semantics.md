---
name: 1030-1031-composite-action-semantics
description: 记录 PR #1028 本地化 Agent runtime 后，复合 Action 与 job step 字段／默认 shell 语义差异导致六个 Agent job 全部无法启动，以及 pull_request_target 的 base.sha 是分叉点而非分支 HEAD 的诊断教训
metadata:
  type: feedback
---

> **状态说明（#1032）**：本文诊断的复合 Action `setup-agent-tools` 已被 #1032 删除，工具安装
> 改为单个脚本，由 job 以普通 step 调用，不再受复合 Action 的字段合法范围与 `pipefail` 默认值
> 影响。这两处缺陷是促成 #1032 否决三层隔离方案的直接原因，见决策
> [[1032-agent-runtime-simplification]]。复合 Action 与 job step 的字段/默认值语义差异规则本身
> 仍然有效，适用于仓库里仍在用复合 Action 的 `run-agent` 与 `feishu-notify`。`pull_request_target`
> 的 `base.sha` 分叉点语义不受本轮改动影响。以下正文保留原诊断过程，不代表当前工具安装实现。

# 反思：复合 Action 语义误用导致 Agent runtime 加载期连环失败

## 任务

PR #1028（`c0c6a29a` → 合并为 `2d08e9bd`）把三条 agentic workflow 从远端 reusable workflow
展开到本仓库，新增本地复合 Action `.github/actions/setup-agent-tools/`。合并进 master 后，
PR #977 的 Agentic PR Review 立刻失败，六个 Agent job 全部无法启动，需要定位并修复。

## 期望与实际

期望：`setup-agent-tools` 在托管 runner 上正常安装 TeX Live、字体和命令沙箱工具，六个 Agent job
恢复运行。

实际：连续暴露两处独立缺陷，逐个修好才让 Action 走到 Agent 启动前的最后一步；诊断过程中还
一度误判"合并修复后 close/reopen 旧 PR 即可恢复"，实测该判断错误。

## 出了什么问题

**缺陷一（PR #1030，`88c3c6a2`）**：`setup-agent-tools/action.yml` 的两个 TeX Live 安装 step 写了
`timeout-minutes: 15`。这个字段只在 job step 合法，复合 Action 的 step 不支持；runner 在加载
manifest 阶段直接抛 `TemplateValidationException: Unexpected value 'timeout-minutes'`，整个调用
step 失败，Agent 从未启动。同一 step 的 `continue-on-error` 未被拒绝，说明字段合法性是按具体
字段名判断的，不是"复合 Action 拒绝任何 job 字段"这种笼统规则。

更值得记录的是：本仓库自建的门禁本身复现了同一个错误认知。`scripts/validate-action-metadata.py`
把 `timeout-minutes` 列进了复合 Action step 的白名单 `STEP_KEYS`，还专门为它写了标量类型检查。
本地 `test-agentic-workflow-contract.py` 因此全绿，却放过了 GitHub 平台一定会拒绝的字段——校验器
的字段表是从 job step 的既有认知推断出来的，从未与复合 Action 的实际支持范围核对过。

**缺陷二（PR #1031，`e972467a`，PR 仍 OPEN）**：第一个缺陷修好、Action 能够加载以后才暴露。
复合 Action 的 `run` 默认 shell 是 `bash -e -o pipefail`，与 job step 的默认值不同。
`Register TeX Live fonts with fontconfig` step 里
`tl_root=$(tlmgr conf | awk -F= '/TEXMFDIST/{...;print $2;exit}')` 在 awk 匹配后立即 `exit`，
`tlmgr conf` 收到 SIGPIPE，管道以 141 结束，`pipefail` 让整条管道失败，`-e` 终止 step。日志证据是
`Unable to flush stdout: Broken pipe` 紧跟 `Process completed with exit code 1`。

本地精确复现：`bash -e -o pipefail -c 'tl_root=$(tlmgr conf | awk ... exit}')` 得到退出码 141；
改为读完全部输出、用 `!found` 守卫只输出首个匹配值后得到 0，取值结果不变。同一 Action 内其余
管道（`xelatex --version | head -n 1`、`pdftoppm -v 2>&1 | head -n 1`、`magick -version | head -n 1`）
实测在 pipefail 下均为 0，没有同类问题，说明问题特征是"管道右侧的命令提前退出"，不是管道本身。

`_check-doc-package.yml:142` 有字面相同的 awk 管道，但它是 job step，默认 shell 不带 pipefail，
实测安全，因此刻意保留未改。同一段代码在两种 step 类型里语义不同，这是本轮诊断的核心认知。

**诊断误判**：修复合并进 master 后，最初判断"close/reopen PR #977 即可恢复"，实测错误。
`pull_request_target` 的 workflow 定义确实取自 master，但可信 checkout 用的是
`github.event.pull_request.base.sha`，它是 PR 的分叉点（merge base），不是 base 分支当前 HEAD。
日志确认 reopen 后仍检出旧提交 `2d08e9bd`。`xpinyin-265` 分支落后 master 163 个提交、分叉点在
两处修复之前，reopen 与重跑都不改变分叉点；最终把该分支 rebase 到 `origin/master` 并
`--force-with-lease` 锁定原 SHA 才让 Action 加载成功，也正因此才暴露缺陷二。

## 根因

- 复合 Action（`runs.using: composite`）和 job step 是 GitHub Actions 里两套独立的字段与默认值
  语义。前者只有一小部分 job step 字段合法，`run` 步骤的默认 shell 也不同（`bash -e -o pipefail`
  vs 无 pipefail）。把 job step 的经验直接套用到复合 Action，会同时在实现代码和自建门禁里写错。
- 自建校验器的允许表是靠人工推断平台行为写出来的，没有针对目标平台的实际拒绝行为做过验证；
  本地测试全绿只证明校验器内部自洽，不证明 GitHub 会接受。
- `pull_request_target` 用分叉点而不是分支 HEAD 做可信 checkout 的基准，是刻意的安全设计（保证
  运行时版本与被审查的 diff 有一致的基线），但代价是运行时改动对已存在、分叉点落后的 PR 不会
  自动生效，必须由该 PR 自己 rebase 或合并 master 才能看到修复。

## 缺失的文档或信号

- `llmdoc/reference/build-and-test.md` 的 Agent runtime 段落此前只描述了运行时的安全边界（凭据、
  沙箱、结果通道），没有一条关于"复合 Action 字段与默认 shell 和 job step 不同"的规则；直到
  本轮修复才补上。
- `scripts/validate-action-metadata.py` 补写字段表时没有交叉核对 GitHub Actions 官方文档中
  `runs.steps` 在 composite 与 job 两种上下文里的实际支持范围，这是流程缺口，不只是笔误。
- 没有文档说明 `pull_request_target` 的 `base.sha` 是分叉点、其含义和续发影响；诊断时完全靠
  临场重新推导，浪费了一次 close/reopen 的验证成本。

## 可能晋升的经验

- 应晋升到 `llmdoc/reference/build-and-test.md` 的 Agent runtime 段落（已在本轮由实现方补写，
  reflector 不改该文件，留给 recorder 核对是否完整）：
  1. 复合 Action 的 step 字段合法范围严格小于 job step，`timeout-minutes` 只在 job step 合法；
     复合 Action 内的超时职责应交给调用 job 已有的 `timeout-minutes`。
  2. 复合 Action 的 `run` 默认 shell 是 `bash -e -o pipefail`，管道右侧命令提前 `exit` 会因
     SIGPIPE 使整条管道以非零退出码终止该 step；同样写法在不带 pipefail 的 job step 里是安全的，
     不能凭字面相同的代码判断行为一致。
  3. `scripts/validate-action-metadata.py` 的字段白名单必须以 GitHub 实际拒绝行为为准，新增字段
     前应先确认它在复合 Action 里到底合不合法，不能照抄 job step 的字段列表。
- 值得考虑晋升到 `llmdoc/reference/repo-git-conventions.md` 或 push/PR 相关 guide：
  `pull_request_target` 的可信 checkout 固定在 `base.sha`（分叉点，非分支 HEAD）；Agent runtime
  发生改动后，所有分叉点早于该改动的存量 PR 会持续加载旧运行时直到自行 rebase 或合并 master，
  这是已知的可用性缺口，不是新出现的 bug；诊断类似"Agent 加载失败"问题时应先确认 PR 分叉点，
  不要用 close/reopen 代替 rebase 去验证 master 上的修复。
- 通用方法论，可考虑归入 `llmdoc/memory/lessons-learned.md`：一处加载期失败（manifest 校验、
  step 字段解析）会完全遮蔽同一 Action 内后续所有运行期缺陷；修好第一个失败点后，应预期还有
  第二批此前从未真正跑到的代码路径可能出错，不能认为"这次能加载了"就代表整体验证完成。

## 后续

- recorder 应在下一次 llmdoc:update 中确认 `llmdoc/reference/build-and-test.md` 第 355-400 行区间
  是否已经把上述三条复合 Action 语义规则写全（当前读取结果显示已经写入，待与实现方最终 diff
  核对是否有遗漏）。
- PR #1031 仍为 OPEN 状态，需要等 CI 通过、合并后再确认其余分叉点落后的存量 Agent 相关 PR
  （如是否还有其他长期分支需要 rebase 才能吃到本轮修复）。
- 文档缺口：目前没有一处专门写"`pull_request_target` 的 `base.sha` 语义与续发影响"，建议下次
  遇到类似 Agent workflow 触发异常时，把这条也补进 build-and-test.md 或专门的 troubleshooting
  记录，避免重复走一次 close/reopen 的验证弯路。
