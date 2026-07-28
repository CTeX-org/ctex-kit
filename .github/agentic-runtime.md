# Agentic runtime 来源

本仓库的 Agent 工作流最初展开自
`Lightspeed-Intelligence/agentic-workflow-template` 的提交
`2a0bb28e6583d869645e0a0522568df4a5d4d921`。相关 workflow、复合 Action、脚本和
`.claude/skills/` 此后都由本仓库自行维护；运行时不再检出或调用该上游仓库。

需要吸收上游更新时，应以这个提交为旧基线，明确选择要搬入的变化，并按本仓库的权限隔离和
事件固定提交规则重新审查，不能直接把本地文件替换为新的上游版本。

## Agent 的执行权限

Agent 在一次性 runner 中以默认用户运行，并拥有完整本地执行权限：审查排版 PR 需要它自己跑
`l3build`、编译 MWE、把 PDF 转成图片比对。Codex 用
`--dangerously-bypass-approvals-and-sandbox`，Claude 用 `--dangerously-skip-permissions`。

约束 Agent 影响面的是权限边界，不是进程沙箱：

- Agent job 只持有只读 `GITHUB_TOKEN`，checkout 后立即移除 Git 凭据，Agent 步骤本身不接收
  GitHub 写凭据。
- 外部写入集中在不运行 Agent、也不接收模型 API key 的 publisher job。
- `pull_request_target` 的可信运行时来自 PR base 提交，被审查的 head checkout 只作为数据。
- Claude 保留 `--bare` 禁用 `CLAUDE.md` 自动发现，避免被审查的仓库向 Agent 注入项目指令。

这套边界不阻止仓库代码读取进程环境中的模型 API key。判断依据是当前贡献者都是仓库协作者。

注意 `pull_request_target` 与 `pull_request` 不同，它对 fork PR 同样提供 secrets，这正是该触发器
需要谨慎使用的原因。当前的保护来自可信运行时固定在 base 提交，而不是来自 fork 拿不到 secrets；
而 Agent 拥有完整本地执行权限，一旦它按审查需要运行 head checkout 中的测试或构建脚本，那些脚本
就能读到密钥。若将来开始接受 fork PR 的自动审查，必须重新引入凭据隔离，或改用不携带 secrets
的触发方式。
