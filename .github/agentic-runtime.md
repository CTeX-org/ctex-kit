# Agentic runtime 来源

本仓库的 Agent 工作流最初展开自
`Lightspeed-Intelligence/agentic-workflow-template` 的提交
`2a0bb28e6583d869645e0a0522568df4a5d4d921`。相关 workflow、复合 Action、脚本和
`.claude/skills/` 此后都由本仓库自行维护；运行时不再检出或调用该上游仓库。

需要吸收上游更新时，应以这个提交为旧基线，明确选择要搬入的变化，并按本仓库的权限隔离、
事件固定提交，以及“Agent 启动前由可信安装阶段保存已经检查的缓存、启动后禁止保存”的规则
重新审查，不能直接把本地文件替换为新的上游版本。
