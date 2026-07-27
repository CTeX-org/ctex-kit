---
name: implement
description: 根据 Issue 的讨论和方案，在本地工作树实现功能或修复 Bug并输出候选变更元数据。
---

# implement

用户确认后 (如 "ok", "/impl")，根据 Issue 在本地工作树实现代码。独立 publisher 会在
候选变更通过校验后创建或更新 PR。

> 遵循 `github-comment` 规范。

## 权限边界

- 可以读取、编辑本地工作树并运行本地测试。
- 不得提交、push、调用 `gh`、访问 GitHub API、创建 PR 或发表评论。
- 不得修改 workflow 提供的可信策略和输入目录。
- 最终只输出 workflow JSON Schema 要求的对象；完整评论写入 `comment_body`。

## 代码质量底线

**必须遵守**：
- 不引入安全漏洞 (SQL 注入、XSS、命令注入等)
- 遵循项目现有代码风格
- 不破坏现有功能（可通过现有测试）

**避免**：
- 过度工程化
- 添加未要求的功能
- 不必要的重构

## Submodule 处理流程

1. **识别**: 改动是否只影响 submodule
2. **定位**: 进入 submodule 目录，读取其 `llmdoc/`
3. **停止**: 当前自动发布链路不支持跨仓库 submodule 提交，将结果标记为 `BLOCKED`
4. **说明**: 在 `comment_body` 中列出需要人工处理的仓库和原因

## 特殊规则

- 不创建或切换分支；publisher 使用由 Issue 编号确定的稳定分支名。
- `pr_body` 不要包含 `Closes #${issue_number}`；publisher 会统一追加一次关闭语句。
- 已完整实现且存在本地变更时输出 `READY`。
- 任务已满足且无需变更时输出 `NO_CHANGES`。
- 缺少业务决策、权限或遇到 submodule 跨仓库变更时输出 `BLOCKED`。
- 核心输入不可访问或无法完成有意义的实现尝试时输出 `INCOMPLETE`。

## 模板

```markdown
## ✨ 实现完成 #${issue_number}

| 项目 | 结果 |
|------|------|
| **状态** | ✅ 成功 / ❌ 失败 / ⏸️ 阻塞 |
| **PR** | 通过校验后由 workflow 创建或更新 |

<details>
<summary><h3>📝 变更摘要</h3></summary>

**修改文件**:
- `path/to/file1` - {改动说明}
- `path/to/file2` - {改动说明}

**实现说明**: {简述实现方式}

</details>

```

失败/阻塞时：
```markdown
## ⚠️ 实现尝试 #${issue_number}

| 项目 | 结果 |
|------|------|
| **状态** | ❌ 失败 / ⏸️ 阻塞 |
| **原因** | {说明} |

<details>
<summary><h3>📋 已完成的工作</h3></summary>

{如有部分进展，列出}

</details>
```
