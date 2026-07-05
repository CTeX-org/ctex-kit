# gh-assets

本分支是 **orphan 分支**，与代码历史完全隔离，专门长期存放 issue / PR 讨论中引用的静态资源（对比截图、示意图等）。

## 引用格式

```
https://raw.githubusercontent.com/CTeX-org/ctex-kit/gh-assets/issues/<issue 号>/<文件名>
```

## 目录组织

- `issues/<issue 号>/` — 按关联 issue 归档

## 添加资产

```bash
git fetch origin gh-assets
git worktree add /tmp/gh-assets gh-assets   # 或另 clone，避免污染主工作区
# 放入文件后 commit（type 用 chore，scope 用 assets）并 push
```

历史来源：本分支取代早期的 `tmp-859-assets` / `tmp-456-assets` 临时分支。
