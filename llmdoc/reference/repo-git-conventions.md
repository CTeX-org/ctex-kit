# 仓库级 git 分支组织约定

## `gh-assets`：长期静态资源分支

### 性质与用途

`gh-assets` 是远端 `origin/gh-assets` 上的一个 **orphan 分支**——无 parent commit，与 `master` 及各包代码历史完全隔离。分支根目录有 `README.md` 说明用法。

用途：长期存放 issue / PR 讨论中引用的静态资源（对比截图、示意图、MWE `.tex` 等）。GitHub issue/PR 评论中若以仓库分支的 raw URL 引用图片，分支一旦被删除引用就会失效；因此这类资源必须落在一个**不会被删**的长期分支，而不是随事件建立、随手清理的临时分支。

### 目录组织与引用格式

- 目录组织：`issues/<issue 号>/<文件名>`，按关联 issue 归档。
- 引用格式：`https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/<issue 号>/<文件名>`。

现有内容：`issues/859/`（#859 标点测量对比图 5 张 + 1 个 MWE `.tex`）、`issues/456/`（#456 禁则修复前后对比图）。这两批分别取代了此前的临时分支 `tmp-859-assets` / `tmp-456-assets`（均已删除）。

### 添加新资产的安全操作方式

**不要**在主工作区直接 `git checkout --orphan gh-assets`——`--orphan` 切换后若配合 `git clean` 清理，会波及主工作区当前未跟踪的文件（实际发生过一次险情：`git clean` 误删了 `.claude/` 下的文件）。orphan 分支操作必须与主工作区隔离，安全做法二选一：

1. **`git worktree`**：`git worktree add /tmp/gh-assets gh-assets`，在独立目录中操作、commit、push，用完 `git worktree remove /tmp/gh-assets`。
2. **纯 plumbing 流**：全程不 checkout、不触碰工作区索引，用底层命令直接构造 commit：
   - `git hash-object -w <file>` 写 blob
   - `GIT_INDEX_FILE=<tmpfile> git update-index --add --cacheinfo 100644,<blob-sha>,<path>` 在临时索引里挂载
   - `git write-tree`（在该临时 `GIT_INDEX_FILE` 下）生成 tree
   - `git commit-tree <tree-sha> -p <parent-sha> -m "..."` 生成 commit
   - `git update-ref refs/heads/gh-assets <commit-sha>`，再 `git push origin gh-assets`

两种方式均不影响主工作区当前分支的索引与未跟踪文件。

### commit message 约定

仓库 commit-msg hook 要求 `type(scope): subject` 格式；assets 类提交固定用 `chore(assets): ...`。

### 迁移已有资源时的收尾步骤

若把资源从临时分支迁移到 `gh-assets`（或未来任何一次分支重命名/迁移），必须同步完成：

1. 编辑所有引用旧 URL 的 issue/PR 评论：`gh api repos/<owner>/<repo>/issues/comments/<comment-id> -X PATCH -F body=@<file>`。
2. 用 `curl -w '%{http_code}'` 抽查新 URL 返回 200 后，才能删除旧分支。

顺序不可颠倒——旧分支删除后旧评论若还未改完，图片链接会立即失效。
