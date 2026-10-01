# Agentic runtime 来源

本仓库的 Agent 工作流最初展开自
`Lightspeed-Intelligence/agentic-workflow-template` 的提交
`2a0bb28e6583d869645e0a0522568df4a5d4d921`。相关 workflow、复合 Action、脚本和
`.claude/skills/` 此后都由本仓库自行维护；运行时不再检出或调用该上游仓库。

需要吸收上游更新时，应以最近一次吸收的上游提交为旧基线，明确选择要搬入的变化，并按本仓库的
权限隔离和事件固定提交规则重新审查，不能直接把本地文件替换为新的上游版本。

## 已吸收的上游变化

- 2026-10，上游 `4f9cc66127bb48fdfd9495d40a5fab08bd6d2cfc`：搬入主备对调（Claude Code
  `claude-opus-5-5` 为主链路，Codex `gpt-6.1-sol` 为 fallback）、CLI 版本（Claude Code
  2.1.282、Codex 0.159.3）、Claude 调用失败时打印一行转义后的错误原因，以及模型 ID 一致性和
  失败诊断两项契约测试。保留本仓库自己的做法：主链路 `continue-on-error` 加 `outputs.status`
  汇总、Codex 的 `priority` 通道与 `high` 推理强度（上游锁为 `medium`）、TeX 工具链与缓存。
  未搬入上游的环境准备脚本扩展点（`setup_script` / `run-setup-hook.sh`），本仓库由
  `setup-agent-tools.sh` 完成同样的准备。

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
