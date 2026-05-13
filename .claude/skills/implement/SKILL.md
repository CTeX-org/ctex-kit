---
name: implement
description: 根据 Issue 的讨论和方案, 实现功能或修复 Bug, 并创建 PR。
---

# implement

用户确认后 (如 "ok", "/impl")，根据 Issue 实现代码并创建 PR。

> 遵循 `github-comment` 规范。

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
3. **提交**:
   - 只影响单个 submodule → 只在该 submodule 内提交和创建 PR
   - 影响多个 submodule → 每个 submodule 独立 PR，主仓库更新引用
4. **汇总**: 评论中列出所有创建的 PR 链接

## 特殊规则

- 功能分支: `feat/vast-github-bot/{short-description}`
- 修复分支: `fix/vast-github-bot/{short-description}`
- PR body 必须包含 `Closes #${issue_number}`

## 模板

```markdown
## ✨ 实现完成 #${issue_number}

| 项目 | 结果 |
|------|------|
| **状态** | ✅ 成功 / ❌ 失败 / ⏸️ 阻塞 |
| **PR** | #{pr_number} |

<details>
<summary><h3>📝 变更摘要</h3></summary>

**分支**: `{branch_name}`

**修改文件**:
- `path/to/file1` - {改动说明}
- `path/to/file2` - {改动说明}

**实现说明**: {简述实现方式}

</details>

{如有多个 submodule PR}
---
**关联 PR**:
- submodule-a: #{pr_number}
- submodule-b: #{pr_number}
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
