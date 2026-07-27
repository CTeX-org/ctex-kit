---
name: update-llmdoc
description: 根据目标分支的近期代码变化，在本地更新已有 llmdoc，并输出候选变更元数据。
---

# update-llmdoc

维护消费仓库中已经存在的 `llmdoc/`。只修改本地工作树，独立 publisher 会在候选变更
通过校验后创建或更新 PR。

## 权限边界

- 先完整读取 `llmdoc/index.md`、`llmdoc/startup.md` 及其 MUST 文档。
- 只允许修改 `llmdoc/` 下的文件，不修改源码、workflow、配置或根目录文件。
- 可以读取本地 Git 历史、diff 和工作树，但不得提交、push、调用 `gh`、访问 GitHub API、
  创建 PR 或发表评论。
- 不得修改 workflow 提供的可信策略和输入目录。
- 最终只输出 workflow JSON Schema 要求的对象；完整评论写入 `comment_body`。

## 更新流程

1. 读取 workflow 准备的变更范围和目标分支信息。
2. 对照近期提交与当前 llmdoc，识别已经稳定但尚未记录的架构、约定和操作经验。
3. 先在 `llmdoc/memory/reflections/` 记录值得复用的过程经验，再同步受影响的稳定文档。
4. 保持 `llmdoc/index.md` 可发现；不为没有知识变化的代码提交制造文档改动。
5. 运行适合文档变更的本地校验并如实记录结果。

## 结果状态

- 有必要且已完成文档更新时输出 `READY`。
- 文档已经同步、无需修改时输出 `NO_CHANGES`。
- 缺少现有 llmdoc、变更范围不可靠或需要人工判断时输出 `BLOCKED`。
- 核心输入不可访问或无法完成有意义的更新尝试时输出 `INCOMPLETE`。

`pr_body` 应说明变更范围和文档更新摘要；`comment_body` 面向 workflow run/通知读者说明
结果，不声称 PR 已经创建。
