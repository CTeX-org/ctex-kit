# 仓库级 git 分支组织约定

## CODEOWNERS 审查归属

`.github/CODEOWNERS` 采用“后写路径规则整行覆盖先写规则”的 GitHub 语义：全仓库
默认由 `@CTeX-org/core-developers` 负责；`/zhlineskip/` 的专门规则同时列出
`@CTeX-org/core-developers` 与 `@CTeX-org/zhlineskip-maintainers`，任一团队批准即可。
新增更具体的包级规则时必须保留所有可批准 owner，不能误以为后写行会与默认行合并。

## Push 与 PR 状态判定

仓库通过 `make hooks` 安装 `.githooks/`，其中 pre-push 是 self-wrapper：外层 push 负责进入 hook，hook 发起内层 push 真正更新远端，再等待当前分支 PR 的 CI 并检查 push 后新增评论与未解决 review thread。外层 push 随后会报告失败，因此远端更新以 hook 中间输出的内层结果为准。

自动化或人工调用 push 时必须使用独立的 `git push 2>&1` 形态，不得附加管道；完整 stderr 包含内层 push verdict、CI 失败项、评论链接和下一步指示。rc 75 表示 CI 已通过但仍有新 review 活动或未解决 thread，必须继续处理，不能当成功退出。

共享分支必须先 fetch 并整合远端。pre-push 对非快进默认拒绝，只有 `CTEX_PREPUSH_ALLOW_FORCE=1 git push --force-with-lease 2>&1` 才允许内层 exact-lease force；这避免普通 push 在协作者同时提交时被错误升级为强推。

新分支第一次 push 尚无 PR 时无法完成状态检查；PR 建立后立即运行 `make check-pr-ci 2>&1`。完整闭环见 `llmdoc/guides/push-and-pr-review-workflow.md`，仓库决策见 `llmdoc/memory/decisions/repo-push-hook-discipline.md`。

## `gh-assets`：长期静态资源分支

### 性质与用途

`gh-assets` 是远端 `origin/gh-assets` 上的一个 **orphan 分支**——无 parent commit，与 `master` 及各包代码历史完全隔离。分支根目录有 `README.md` 说明用法。

用途：长期存放 issue / PR 讨论中引用的静态资源（对比截图、示意图、MWE `.tex` 等）。GitHub issue/PR 评论中若以仓库分支的 raw URL 引用图片，分支一旦被删除引用就会失效；因此这类资源必须落在一个**不会被删**的长期分支，而不是随事件建立、随手清理的临时分支。

### 目录组织与引用格式

- 目录组织：`issues/<issue 号>/<文件名>`，按关联 issue 归档。
- 引用格式：`https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/<issue 号>/<文件名>`。

现有内容包括：`issues/859/`（#859 标点测量对比图与 MWE）、`issues/456/`
（#456 禁则修复前后对比图）和 `issues/275/`（标题编号行为变化、SJTUBeamer
私有宏迁移的 MWE、PDF 与前后对比图），以及 `issues/402/`（`autoindent` 用户手册
前后对比和零缩进兼容语义 MWE/PDF）。前两批分别取代了此前的临时分支
`tmp-859-assets` / `tmp-456-assets`（均已删除）。

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
