---
name: github-comment
description: 定义 GitHub 评论的格式规范, 强调使用折叠 `<details>` 保持简洁。
---

# GitHub 评论规范 (所有 Skill 的基础)

此规范适用于所有在 GitHub Action 中运行的 Skill。

## 核心规则

1. **简体中文**: 所有输出必须使用简体中文。
2. **单条评论**: 在无头 (headless) 环境运行，所有输出合并为一条评论。
3. **折叠长内容**: 使用 `<details>` 折叠代码、日志、技术细节。`<details>` 前后需空行。
4. **先读 llmdoc**: 操作前必须阅读项目的 `llmdoc/` 文档。
5. **不重复评论**: 执行前检查是否已评论过 (`gh pr view --comments` / `gh issue view --comments`)，避免重复。

## 链接格式

引用代码时使用完整格式，否则 Markdown 无法正确渲染：

```
https://github.com/{owner}/{repo}/blob/{full_sha}/{path}#L{start}-L{end}
```

- 必须使用完整 commit SHA，不能用 `$(git rev-parse HEAD)`
- 行号格式：`#L10-L15`，提供前后至少 1 行上下文

## 模板

```markdown
### 标题

简明扼要的核心信息。

<details>
<summary>详情</summary>

长篇内容、代码、日志等。

</details>
```
