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
- Poppler、ImageMagick、Ghostscript、ShellCheck 和 actionlint。

工具必须在 Agent 所在 runner 内可用。由另一个前置 job 编译固定 MWE 或上传固定证据，只能覆盖
预先知道的检查，不能替代 Agent 根据 diff 自主选择 MWE、字体、字号和 PDF 检查方式。

## 共享缓存需要区分读取者和写入者

Agent 安装 Action 与可信 CI 使用相同的 TeX Live weekly key 和两组字体 key，但只调用
`actions/cache/restore`。缓存未命中时，Agent 可以临时安装本次运行所需内容，却不能在 job 结束
时保存。

这里的“不能回写”是安全策略，不是 GitHub Actions 的技术限制。Agent 会运行仓库代码；普通
`actions/cache` 的 post step 若在 Agent 之后保存目录，新的 weekly key、依赖清单变化或缓存清理
后都可能让 Agent 成为第一个共享缓存写入者。可信 `test.yml` 等 CI 负责预热，Agent 只读取，才能
避免不可信测试或构建污染后续可信任务。字体暂存目录在安装完成后还要从工作区删除，避免 Agent
修改恢复内容。

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

## 事件提交和发布权限必须分别固定

- PR Review 从 PR base SHA 稀疏检出审查规范、安装 Action、Agent 启动脚本和历史准备脚本；PR head
  只作为不可信审查对象。Agent job 只读，唯一拥有 `pull-requests: write` 的 publisher 不运行 Agent。
- Issue Dispatch 固定到事件 `github.sha`。两个分析 Agent 只读，独立发布 job 才能发表评论。
- llmdoc Updater 在准备 job 解析 master SHA；Agent 只生成候选，独立校验 job 从同一 SHA
  重建仓库并验证候选，publisher 才持有 `contents: write` 和 `pull-requests: write`。

固定提交解决“运行哪一版可信代码”，独立 publisher 解决“谁能产生外部写入”；两者不能互相替代。

## 合同测试必须检查失败反例

actionlint 只校验 workflow，不能把 `action.yml` 当作复合 Action metadata 校验。#1025 增加专用
Python 校验器，检查顶层字段、inputs、outputs、`runs.using` 和 composite step，并用预期失败的
错误样例（负向夹具）证明门禁会失败。

PR Review 的结构化结果也需要负向夹具。仅检查存在 jq 片段不足以证明三处语义一致；合同测试现在
提取 Codex、Claude 和 publisher 的实际 jq 过滤器，确认零 finding 的 `COMMENT` 被拒绝、至少有
一个小问题的 `COMMENT` 才能通过。

## 可复用经验

- reusable workflow 的调用方不能向被调用 job 注入新的 step；需要改变 Agent 所在 runner 的工具链时，
  要修改 reusable workflow 本身，或者把实现本地化。
- 执行不可信代码的 Agent 不能继承长期模型密钥。提示词、只读 GitHub token 和独立 publisher
  都不能替代进程级凭据隔离。
- 与可信 CI 共用 cache key 时，Agent 应只恢复；可信 CI 才能成为共享缓存写入者。
- 静态合同既要检查目标片段存在，也要用错误输入证明门禁确实拒绝错误状态。
- 上游来源提交属于可追溯的初始基线，不再是运行时依赖；吸收上游变化时必须选择性搬运并重新审查
  本仓库的权限、事件提交和缓存边界。

## 验证

- `python3 scripts/test-agentic-workflow-contract.py`
- `python3 scripts/validate-action-metadata.py .github/actions/*/action.yml`
- actionlint 检查四条相关 workflow
- ShellCheck 检查 Agent runtime 和历史准备脚本
- 固定提交、断网快照中的独立本地审查
