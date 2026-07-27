---
name: bug-analyze
description: 分析 Bug 类型 Issue，定位根因并评估后续修复条件，不修改代码或创建 PR。
---

# bug-analyze

分析 `bug` 标签的 Issue，定位根因并评估修复条件。本 Skill 只分析，不修改代码。

> 遵循 `github-comment` 规范。

不得编辑文件、提交、push、调用 `gh` 或创建 PR。将完整待发布 Markdown 放入结构化
输出的 `comment_body`。`auto_fix_eligible` 只表示后续 `implement` workflow 是否适合尝试，
绝不授权当前 workflow 自动修复。

## 严重程度标准

| 级别 | 定义 | 示例 |
|------|------|------|
| **critical** | 系统崩溃、数据丢失、安全漏洞 | 生产环境宕机、用户数据泄露 |
| **high** | 核心功能不可用、无 workaround | 登录失败、支付无法完成 |
| **medium** | 功能受损但有 workaround | 导出功能异常但可手动处理 |
| **low** | 体验问题、边缘场景 | 样式错位、罕见输入报错 |

## 后续自动实现适用性

**适合后续自动实现**：
- 改动 ≤ 20 行
- 改动范围明确（单文件或紧密相关文件）
- 修复逻辑清晰，无歧义
- 不涉及架构变更

**不适合后续自动实现**：
- 需要澄清需求
- 涉及多个模块协调
- 可能有多种修复方案
- 影响范围不确定

## 模板

```markdown
## 🐛 Bug 分析 #${issue_number}

| 项目 | 结果 |
|------|------|
| **根因** | {一句话概括} |
| **严重程度** | 🔴 critical / 🟠 high / 🟡 medium / 🟢 low |
| **适合后续自动实现** | ✅ 是 / ❌ 否 |

<details>
<summary><h3>📋 详细分析</h3></summary>

**复现路径**:
1. {步骤}

**代码定位**: [{文件}:{行号}]({github_link})

**问题原因**: {技术分析}

</details>

```
