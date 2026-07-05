# 决策：建立长期 orphan 分支 `gh-assets` 取代按事件建临时分支

## 决策

新建远端长期 orphan 分支 `origin/gh-assets`，集中托管 issue/PR 讨论中引用的静态资源（截图、示意图、MWE 等），取代此前"每个 issue 一个临时分支"的做法（`tmp-859-assets` / `tmp-456-assets`，均已删除）。约定细节见 `llmdoc/reference/repo-git-conventions.md`。

## 背景

GitHub issue/PR 评论里若引用仓库某分支下文件的 raw URL（`https://raw.githubusercontent.com/.../<branch>/<path>`），一旦该分支被删除，历史评论中的图片/文件引用会立即失效——评论本身不会报错，但图片位置会变成 404。此前的做法是为每个 issue 单独建一个临时分支（如 `tmp-859-assets`）存图，讨论结束后连同分支一起清理，导致历史评论中的引用逐渐失效。

## 决策内容

1. **一个长期 orphan 分支，而非按 issue 建分支**：`gh-assets` 与主代码历史完全隔离（无 parent），只承载资源文件，永不删除。
2. **目录组织按 issue 号分区**：`issues/<n>/<file>`，保留可追溯性但不再依赖分支边界。
3. **迁移已有临时分支的内容**：把 `tmp-859-assets`、`tmp-456-assets` 中的文件迁移进 `gh-assets/issues/859/`、`gh-assets/issues/456/`，改完所有引用旧 URL 的评论后删除两个临时分支。
4. **添加资产必须用 worktree 或 plumbing，不直接在主工作区 `checkout --orphan`**：`--orphan` 切换分支后若配合 `git clean` 会清掉主工作区未跟踪文件——这在建立本分支时实际发生过一次险情（`git clean` 误删了 `.claude/` 下的文件，未造成不可恢复损失但足以作为前车之鉴）。安全替代方案：`git worktree add <tmp-dir> gh-assets` 隔离操作，或纯 plumbing 流（`hash-object` + `update-index --cacheinfo` + `write-tree` + `commit-tree` + `update-ref`，全程不触碰工作区/索引）。本次两个 commit（`ae0ab5fb` 建分支、`e84d0577` 补收遗漏文件）均用 plumbing 流构造。

## 影响范围

- 未来任何需要在 issue/PR 评论中贴图/贴 MWE 的场景，应放入 `gh-assets/issues/<n>/`，不再新建临时分支。
- 已有 `.claude/` 等本地开发目录属于未跟踪文件，任何涉及 orphan 分支切换/清理的操作都需要先确认不会波及主工作区。

## 相关

- Stable：`llmdoc/reference/repo-git-conventions.md`
- Commits：`ae0ab5fb`（建分支迁移 #859/#456 资源）、`e84d0577`（补收 #859 遗漏的 MWE `.tex`）
