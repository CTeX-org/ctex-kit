# 决策：#1111 PR Review 不审查 fork PR

## 背景

#1109 是 `agentic-pr-review.yml` 投入使用后第一个 fork PR。两条审查链路的第一步都检出 PR head，被 `actions/checkout` 拒绝：GitHub 2026-06-18 起，`pull_request_target` 中检出 fork 代码必须显式设置 `allow-unsafe-pr-checkout: true`，否则 checkout 报错退出。本仓库在 #884 升级到 `actions/checkout@v7`，本工作流在 2026-07-23 前后才写成，所以 fork PR 这条路径从未跑通过。#1109 上三个 job 全部显示红叉。

这次失败本身挡住了一个真实风险。#1032 删除凭据隔离后，Agent 进程环境里有模型 API key，并以完整本地执行权限在 PR head 上运行 `l3build`、`make` 等命令；fork 作者改动 `build.lua`、`Makefile` 或 `.lvt` 就能读到密钥。#1032 已写明：开始接受 fork PR 自动审查时，必须恢复“Agent 进程不持有长期模型密钥”这条边界，或者改用不带 secrets 的触发方式。

## 决策

fork PR 一律不执行 PR 代码，PR Review 在 fork PR 上不运行。`claude_review`、`codex_review`、`publish` 三个 job 都以 `github.event.pull_request.head.repo.full_name == github.repository` 为条件，fork PR 上全部显示为 skipped，不在 PR 下发说明。fork PR 由维护者在本地审查。

三处都要写这个条件：`claude_review` 被跳过时 `outputs.status` 是空字符串，`codex_review` 的 `always() && ... != 'success'` 仍然成立；`publish` 带 `always()`，也会运行并报“均执行失败”。只守住主链路，fork PR 上仍是红叉。

## 被否决的方案

- **只加 `allow-unsafe-pr-checkout: true`**：直接让 fork 代码在持有模型密钥的进程里运行，正是 #1032 列出的前提失效情形。
- **按作者身份放行**（`author_association` 为 OWNER、MEMBER、COLLABORATOR 时审查）：#1109 的作者是 `FIRST_TIME_CONTRIBUTOR`，同样会被跳过；而放行的那部分 fork PR 仍在持有密钥的进程里执行 PR 代码，信任依据从“代码在本仓库分支上”换成了 GitHub 的作者分类。维护者选择 fork PR 一律不执行 PR 代码，不按作者身份区分。
- **只给 Agent diff、靠提示词约束它不运行构建**：Agent 带 `--dangerously-skip-permissions` 运行，PR 内容可以通过提示注入诱导它执行脚本；只要模型密钥还在 Agent 进程环境里，这不是可靠的隔离。
- **environment required reviewers 由维护者批准后运行**：批准之后的风险与按作者放行相同，批准者还要先读完构建脚本才算真正审过。

## 约束与后续

- `scripts/test-agentic-workflow-contract.py` 固定三处守卫的完整表达式，并要求 workflow 中不出现 `allow-unsafe-pr-checkout`；去掉任一守卫、改按 Draft 状态跳过、给 head 检出加上放行选项的反例都必须失败。
- PR Review 本身由 `pull_request_target` 触发，运行的是 base 分支的 workflow。修改守卫的 PR 自身不会用到新守卫，合并之后才对后续 PR 生效。
- 若将来要自动审查 fork PR，前提仍是把模型密钥移出 Agent 进程（例如由不运行 Agent 的进程代理模型调用），不能只放宽这里的条件。

## 相关

- 决策：[[1032-agent-runtime-simplification]]（已接受的风险与重新引入隔离的条件）
- Issue：#1111；首次暴露问题的 PR：#1109
