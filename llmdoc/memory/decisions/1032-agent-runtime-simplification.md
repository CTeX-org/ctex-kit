# 决策：#1032 Agent runtime 简化回上游形式

## 决策

删除 #1025 起为 Agent runtime 引入的三层进程隔离（`ctex-agent` 专用用户、`agent-control-hardening.c` 的 `LD_PRELOAD` 加固、以 root 身份运行的本地模型 API 代理），改回上游模板 `agentic-workflow-template` 的形式：Agent 以 runner 默认用户运行，拥有完整本地执行权限。Codex 用 `--dangerously-bypass-approvals-and-sandbox`，Claude 用 `--dangerously-skip-permissions`。

工具安装同时从复合 Action `.github/actions/setup-agent-tools/` 改为单个脚本 `.github/scripts/agentic/setup-agent-tools.sh`，由六个 Agent job 各自以普通 step 调用。

净减少 825 行。

## 被否决的方案：保留三层隔离

保留 #1025 建立的隔离（专用用户 + 沙箱外结果控制目录 + root 模型代理 + Codex 空指令根／Claude `--bare`）能防止仓库内可信协作者的代码窃取模型密钥或伪造审查结果。

否决理由：这套隔离的收益没有对应的威胁模型支撑，而它自身是本轮三次连环故障的唯一来源：

- `timeout-minutes` 写进复合 Action step 是非法字段，导致 runner 加载期直接拒绝（#1030）。
- 复合 Action `run` 默认 `pipefail`，管道右侧 `awk` 提前 `exit` 触发 SIGPIPE，使安装 step 以 141 终止（#1031）。
- 移交工作区所有权给专用用户后，Agent 进不去工作区，预加载库 `.so` 也无法生效，Agent 无法启动。

三次故障没有一次出自审查逻辑本身，全部出自隔离层的实现细节。

## 采纳方案

按风险与成本重新评估：

- **贡献者结构**：当前贡献者都是仓库协作者，近 40 个 PR 中跨仓库 PR 为 0。在“仓库内代码窃取模型密钥”这个威胁面前，攻击者本身就是已经拥有仓库写权限的协作者——隔离没有阻止他们用其他方式获取密钥的能力。
- **故障成本**：三层隔离在实践中三次让 Agent 完全无法启动，且每次修复都需要引入更复杂的机制（专用用户权限检查、预加载库、`env -i` 环境清空），复杂度本身持续制造新的失败面。
- **收益边界**：隔离能防的是“模型密钥泄漏给仓库子进程”，不能防“Agent 消耗模型调用额度”或“Agent 被恶意 PR 诱导做出错误审查结论”——这些风险在有隔离和无隔离下都同样存在，隔离只覆盖了威胁面的一小部分。

保留的边界改为纯权限隔离：只读 `GITHUB_TOKEN`、checkout 后移除凭据、publisher job 独占外部写权限、`pull_request_target` 的 base SHA 可信 checkout、Claude 的 `--bare`。这些边界成本低、故障历史干净，且已被本轮验证（Agent 环境损坏时 `review_status: INCOMPLETE` 被门禁正确拒收）。

## 已接受的风险

模型 API key 重新暴露给 Agent 进程能执行的仓库代码。任何被 Agent 调用的仓库脚本（包括 PR 中新增的测试或工具）都能读取到该密钥所在的进程环境。

## 将来需要重新引入隔离的条件

需要重新引入凭据隔离的条件，是贡献者结构变化到不能默认信任所有能触发 Agent job 的代码来源。

这里有一个必须说清的边界：`pull_request_target` 与 `pull_request` 不同，它对 fork PR **同样**提供 secrets，这正是该触发器需要谨慎使用的原因。当前的保护来自可信 checkout 固定在 base SHA——Agent 执行的运行时代码来自 base，PR head 只作为数据。但 Agent 拥有完整本地执行权限，一旦它按审查需要运行 head checkout 中的测试或构建脚本，那些脚本就能读到模型密钥。

因此若项目开始接受 fork PR 的自动审查，必须至少恢复“Agent 进程不持有长期模型密钥”这条边界（不必是完全相同的三层方案），或者改用不携带 secrets 的触发方式。

## 相关

- 反思：[[1025-agentic-local-runtime-toolchain]]（记录三层隔离的建立过程，已被本决策取代）
- 反思：[[1030-1031-composite-action-semantics]]（记录复合 Action 两处缺陷，是本决策否决三层隔离的直接触发原因）
- Stable：`llmdoc/reference/build-and-test.md` agentic 工作流小节
- PR：#1032（提交 bc2bacdb）
