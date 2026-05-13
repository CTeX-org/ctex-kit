---
name: update-llmdoc
description: >
  定时自动维护 llmdoc 项目文档的 Skill。支持两种模式：聚合仓库模式（遍历子模块）和
  单仓库模式（直接在当前仓库操作）。每天北京时间 5:00（UTC 21:00）由 GitHub Actions
  schedule 触发，也支持 workflow_dispatch 手动触发。收集指定时间范围内（默认过去 24 小时）
  合并到目标分支的提交记录和 PR 内容，分析代码变更是否涉及功能新增、接口变更或架构调整，
  如果需要则自动更新 llmdoc/ 下的对应文档并推送到目标分支。不改变外部行为的变更
  （bug 修复、重构、依赖升级等）会被跳过。更新完成后输出结构化 JSON 结果并通过飞书通知。
---

# update-llmdoc

根据目标分支最近的代码变更，自动更新 llmdoc 文档。

## 概览

- **作用**: 保持 `llmdoc/` 项目文档与代码实现同步，减少人工维护成本
- **触发方式**: GitHub Actions `schedule`（每天北京时间 5:00）或 `workflow_dispatch` 手动触发
- **时间窗口**: 默认检查过去 24 小时内的提交，手动触发时可自定义 `since_period` 参数
- **输出**: 结构化 JSON（包含 `description`、`total_files_updated`、`pr_url`），同时通过飞书 Webhook 通知结果，附带 PR 链接

## 仓库模式自动检测

执行前先检测当前仓库类型：

```bash
# 检查是否有 .gitmodules 文件（聚合仓库的标志）
if [ -f .gitmodules ]; then
  # 聚合仓库模式：遍历子模块
else
  # 单仓库模式：直接在当前仓库操作
fi
```

### 聚合仓库模式

适用于包含 git submodule 的仓库（如 tipsy-collect-repo）。遍历所有子模块，逐个检查变更并更新文档。

### 单仓库模式

适用于独立仓库（如 tipsy-backend）。直接在仓库根目录检查变更并更新 `llmdoc/` 文档。

## 执行流程

### 1. 收集变更

**聚合仓库模式** — 对每个子模块执行：

```bash
git submodule foreach 'echo $name'  # 获取子模块列表
cd {submodule}
git fetch origin {target_branch}
git log --since="{since_period}" origin/{target_branch} --oneline
```

**单仓库模式** — 直接在根目录执行：

```bash
git fetch origin {target_branch}
git log --since="{since_period}" origin/{target_branch} --oneline
```

> `{target_branch}` 从 prompt 中获取，默认为 `dev`。

### 2. 分析变更

对有新提交的仓库/子模块：

1. **读取提交记录**: `git log --since="{since_period}" origin/{target_branch} --pretty=format:"- %h %s (%an)"`
2. **读取合并 PR 信息**: `git log --since="{since_period}" origin/{target_branch} --merges --pretty=format:"%s"`
3. **读取变更统计**: `git diff {first_commit}^..{last_commit} --stat`
4. **读取代码 diff**: `git diff {first_commit}^..{last_commit}` (关注核心逻辑变更)
5. **读取当前 llmdoc**: 阅读 `llmdoc/index.md` 和所有相关文档

### 3. 判断是否需要更新

以下变更**需要更新文档**：
- 新增功能或模块
- 修改现有功能的行为或接口
- API 变更（新增/修改/删除端点）
- 架构调整
- 重要的配置变更

以下变更**不需要更新文档**：
- 纯 bug 修复（不改变接口或行为）
- 代码重构（不改变外部行为）
- 依赖版本升级
- 测试代码变更
- CI/CD 配置变更
- 注释或日志修改

### 4. 更新文档

- **只更新确实受影响的文档**，不做不必要的修改
- 保持与现有文档一致的风格和结构（中文）
- 新功能 → 在对应 architecture/ 或 guides/ 文档中添加说明
- 行为变更 → 更新对应文档的描述
- 重大变更 → 更新 index.md 导航

### 5. 创建 PR

文档更新完成后，**不直接推送到 `{target_branch}`**，而是创建新分支并提 PR：

**分支命名规则**：

```
docs/llmdoc-update-{YYYYMMDD}
```

例如：`docs/llmdoc-update-20240315`

**聚合仓库模式** — 对每个有文档更新的子模块：

```bash
cd {submodule}
DATE=$(date +%Y%m%d)
BRANCH="docs/llmdoc-update-${DATE}"

# 基于 target_branch 创建新分支
git checkout -b "${BRANCH}" "origin/{target_branch}"

git add llmdoc/
git commit -m "docs: 自动更新 llmdoc 文档

基于过去 {since_period} {target_branch} 分支的代码变更自动生成
Auto-updated by GitHub Actions"
git push origin "${BRANCH}"

# 创建 PR（目标分支为 target_branch）
gh pr create \
  --title "docs: 自动更新 llmdoc 文档 ($(date +%Y-%m-%d))" \
  --body "## llmdoc 文档自动更新

由 GitHub Actions 定时任务自动生成，基于过去 {since_period} 合并到 \`{target_branch}\` 分支的代码变更。

**请检查文档内容是否准确后合并。**" \
  --base "{target_branch}" \
  --head "${BRANCH}"
```

**单仓库模式** — 直接在根目录：

```bash
DATE=$(date +%Y%m%d)
BRANCH="docs/llmdoc-update-${DATE}"

git checkout -b "${BRANCH}" "origin/{target_branch}"

git add llmdoc/
git commit -m "docs: 自动更新 llmdoc 文档

基于过去 {since_period} {target_branch} 分支的代码变更自动生成
Auto-updated by GitHub Actions"
git push origin "${BRANCH}"

# 创建 PR（目标分支为 target_branch）
PR_URL=$(gh pr create \
  --title "docs: 自动更新 llmdoc 文档 ($(date +%Y-%m-%d))" \
  --body "## llmdoc 文档自动更新

由 GitHub Actions 定时任务自动生成，基于过去 {since_period} 合并到 \`{target_branch}\` 分支的代码变更。

**请检查文档内容是否准确后合并。**" \
  --base "{target_branch}" \
  --head "${BRANCH}")
echo "PR created: ${PR_URL}"
```

**如果当天已存在同名分支**（重复触发时），先尝试复用：

```bash
git checkout "${BRANCH}" 2>/dev/null || git checkout -b "${BRANCH}" "origin/{target_branch}"
# 如果 PR 已存在则跳过创建，直接追加提交推送
git push origin "${BRANCH}"
```

输出的结构化 JSON 中，`pr_url` 字段填入 `gh pr create` 返回的 PR 链接。若无文档更新，`pr_url` 为空字符串。

### 6. 输出报告

用 `echo` 输出处理结果（不需要发 GitHub 评论）。结构化输出中必须包含 `pr_url` 字段，飞书通知将自动附带 PR 跳转链接。

## 特殊规则

- **聚合仓库**: 每个子模块在自己的 git 仓库内操作，不修改父仓库
- **无 llmdoc 跳过**: 如果仓库/子模块没有 `llmdoc/` 目录，跳过
- **无变更跳过**: 如果无提交或变更不需要更新文档，跳过
- **diff 过大截断**: 如果 diff 超过 500 行，聚焦于 `--stat` 和提交信息来理解变更
- **保守更新**: 宁可少更新，也不要错误更新。不确定时不更新
- **必须创建 PR**: 更新文档后必须创建新分支并通过 `gh pr create` 提 PR，不直接推送到 `{target_branch}`
- **PR URL 必须输出**: 结构化 JSON 的 `pr_url` 字段必须填入实际 PR 链接，以便飞书通知附带跳转
