---
name: patrol
description: 定期巡查仓库，监控 CI 状态、扫描未处理 Issue，自动分发到对应 skill 处理。
---

# patrol

定期巡查 CTeX-kit 仓库，监控 CI 和 Issue。

> 遵循 `github-comment` 规范。

## 准确性要求（最高优先级）

**禁止凭训练知识推断技术细节。** 所有对外发布的内容必须基于源码验证。

- 涉及命令、选项、默认值、行为机制 → 先 grep/read `.dtx` 文件确认
- 引用其他 Issue → 先 `gh issue view` 读内容确认相关性
- 无法从源码确证 → 只说"我们会调查"，不给猜测性技术细节

## 禁止操作

- **禁止合并 PR**（`gh pr merge`）
- **禁止在 PR 上评论或 review**
- PR 由人工处理，巡查只关注 Issue 和 CI

## 执行流程

### 1. 检查 CI 状态

```bash
gh run list --workflow=test.yml --limit=5 --json status,conclusion,event,createdAt,url
```

关注：
- 最近是否有失败的 CI
- `schedule` 触发的周五定时构建是否正常

### 2. 扫描 Issue

```bash
gh issue list --state=open --limit=20 --json number,title,labels,comments,stateReason
```

**判断是否需要处理**：

对每个 Issue，用 `gh issue view <number> --json comments` 获取完整评论列表，检查最后一条评论的作者：

- **最后一条评论来自 `github-actions[bot]`** → 跳过（bot 已回复，无新用户活动）
- **最后一条评论来自用户**（非 bot）→ 需要处理（用户在 bot 回复后追问或补充了信息）
- **无评论** → 需要处理（新 Issue）
- **`stateReason` 为 `reopened`** → 需要处理（即使 bot 之前回复过，重新打开意味着问题未解决）

### 3. 分发处理

根据 Issue 标签和内容选择对应 skill：

| 类型 | Skill | 后续 |
|------|-------|------|
| `bug` 标签 | `bug-analyze` | 分析根因；简单 Bug 用 `implement` 修复 |
| `enhancement` / 功能需求 | `feature-review` | 评审可行性，等用户确认 |
| 提问 / 无标签 | `answer-question` | 直接回复 |

每个 Issue 处理完成后，用 `gh issue comment` 发布分析结果。

### 4. CI 失败处理

1. 用 `gh run view --log-failed` 读取失败日志
2. 用 `bug-analyze` 思路定位根因
3. 简单问题直接修复（本环境有完整 TeX Live）
4. 复杂问题开 Issue 说明

### 5. 修复环境

本环境已安装 TeX Live 和 Noto CJK 字体，可运行编译和测试：

```bash
cd <project> && l3build check -q -H
cd <project> && l3build save <test-name>
```

环境变量已配置：`diffext=.diff`，`diffexe="git diff --no-index --text --"`

修复分支命名：`fix/patrol/{desc}` 或 `feat/patrol/{desc}`

**修复后必须**：
- 运行 `l3build check` 确认测试通过
- 开 PR（绝不合并）
- 在 Issue 中评论修复进展
