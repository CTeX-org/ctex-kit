---
name: agentic-template-reuse
description: 记录 ctex-kit 将定时巡检改为事件驱动 Issue 分派，并把 Agent 工作流收敛为上游 reusable workflow 薄调用层的取舍
metadata:
  type: feedback
---

# 反思：复用 Agent 工作流模板

## 任务

`ctex-kit` 已经通过 `.github/workflows/agentic-pr-review.yml` 调用
`Lightspeed-Intelligence/agentic-workflow-template` 的 PR Review reusable workflow。
本轮沿用同一模式：用模板的 `issue-dispatch.yml` 代替本仓库原有的定时 patrol，
并让 llmdoc 定时任务直接调用模板的 `update-llmdoc.yml`。参考仓库只作为 reusable
workflow 的提供方；本轮不修改参考仓库，也不向其上游提交 PR。

## 最终形式

- `.github/workflows/agentic-issue-dispatch.yml` 只监听 Issue `opened` 事件。它不再定时
  扫描 CI 或积压 Issue，而是在新 Issue 出现时立即调用模板的 `issue-dispatch.yml`。
- `.github/workflows/agentic-llmdoc-updater.yml` 保留每天北京时间 05:00 和手动触发，
  但本地只负责触发、输入、权限和 secret 映射；实际更新交给模板的
  `update-llmdoc.yml`。
- `.github/workflows/agentic-pr-review.yml` 保持原有 `pull_request_target` 入口，不把模板
  `ci.yml` 整体复制进来。整体复制会同时启用 `implement` 和 `question`，并与现有 PR
  Review 重复触发。
- 三个 caller 都固定到模板仓库经过审查的完整提交
  `00a5244ea6150ef6a4c43b680d15d73dafabd343`。本仓库的离线合同测试除验证本地触发和调用
  参数外，也禁止调用点退回分支或标签等可变引用；后续升级模板应由显式 PR 完成。

## 主要取舍

事件驱动 Issue 分派与定时巡检不是同一种能力。改用 `issue-dispatch` 后，新 Issue 会按
`bug-analyze`、`feature-review` 或 `answer-question` 处理，但系统不再主动检查 CI、重新
扫描旧 Issue，也不再为巡检安装 TeX Live 和 Noto 字体。这是本轮有意接受的行为变化，
不是遗漏。

llmdoc caller 删除了“先关闭旧 PR，再扩展检查窗口”的本地步骤。这样调用层与 PR Review
一样保持简单，也避免在新的替代 PR 尚未成立时先关闭旧 PR；相应地，跨日遗留 PR 的合并
与清理由模板工作流及维护者处理，本仓库不再额外改写上游语义。

Issue 分派和 llmdoc 更新都是具有写权限的 Agent 工作流。它们与 PR Review 的权限模型
不同：PR Review 把 Agent 和评论发布分开，而模板的 Issue／llmdoc 工作流允许 Agent 直接
使用 GitHub 写操作。调用层因此只授予 reusable workflow 声明所需的权限，并保留主仓库
job 级门控。门控不能防止第三方可变引用在本仓库没有变更时取得这些能力，因此调用点必须
固定到完整提交 SHA。这样，模板升级会表现为本仓库可审查的代码变更，而不是运行时静默
变化。

## 可复用经验

- 模板的 `ci.yml` 适合说明事件路由，不一定适合整份复制。调用方应只选择需要的事件和
  reusable workflow，避免顺带启用无关自动化。
- 用远端 reusable workflow 取代本地实现时，本地仍应保留最小合同测试，固定触发类型、
  权限、secret 映射、远端入口和完整提交 SHA，防止后续维护时无意恢复已删除的本地实现
  或退回可变引用。
- `issues: opened` 不需要 `workflow_dispatch`；手动触发没有 `github.event.issue` 上下文。
- 对会产生外部写入的工作流，`cancel-in-progress: false` 比中途取消更安全。取消已经开始
  评论或创建 PR 的 run，可能留下难以判断的部分结果。

## 验证

- `python3 scripts/test-agentic-workflow-contract.py`
- `actionlint` 检查四个 agentic caller／合同 workflow
- `git diff --check`
