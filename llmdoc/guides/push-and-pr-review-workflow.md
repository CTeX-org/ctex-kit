# Push 与 PR 审查闭环

## 安装 hook

首次进入仓库后运行 `make hooks`，它会把 `core.hooksPath` 设置为 `.githooks`。除紧急情况外，不使用 `git push --no-verify` 绕过 pre-push。

## 推送命令

始终单独执行 `git push 2>&1`，或带显式 remote/refspec 的等价形式；命令后不得连接管道。调用方必须同时取得完整 stdout/stderr 和真实 rc，不能用 `tail`、`tee`、`grep` 等管道截断或改写结果。

pre-push 是 self-wrapper：外层 push 进入 hook 后，hook 用 `GIT_POSTPUSH=1` 发起真正更新远端的内层 push；控制流返回后，外层 push 会因远端引用已更新或连接关闭而报告失败。这是预期现象。实际是否推送成功，以输出中的内层 push 结果和 `post-push: ✔ push succeeded` 为准，不能只看外层 rc 或最后一行。

共享分支 push 前先 fetch 并整合远端最新提交。若 refspec 已非快进，hook 默认拒绝，不能把普通 push 自动升级成 force；先合并或 rebase 协作者改动。只有明确需要覆写历史时才运行 `CTEX_PREPUSH_ALLOW_FORCE=1 git push --force-with-lease 2>&1`，内层 push 会使用从 pre-push stdin 取得的远端 SHA 作为精确 lease。

## 等待 CI 与评论

内层 push 成功后，hook 调用 `.githooks/check-pr-ci.sh`：等待当前分支对应 PR 的 CI 进入终态，按 workflow 名只保留最新 run，并检查 push 后的新 formal review、Bot issue comment 与未解决 review thread。

必须让 hook 自己运行到终止报告，不得在看到远端更新成功后提前中断。单独运行 `gh pr checks --watch` 只能看 CI，不能替代 hook 的评论和 thread 检查。

终止结果按输出理解：rc 0 表示 CI 全绿且 push 后无新 review 活动或未解决 thread；rc 1 表示 CI 失败；rc 75 表示 CI 已过但出现新 review 活动或未解决 thread；rc 2 表示未找到 PR 或 `gh` 不可用，pre-push 将其视为非致命，但操作者仍需完成后续检查。

## 处理审查意见

push 输出会给出下一步指示和相关链接，必须完整阅读。PR 评论可能列出阻塞问题、重要建议和小问题；逐项回到代码、测试或官方接口证据核实，不因评论来自 Bot 而直接接受，也不因标为“小问题”而跳过。

审查范围包括代码、测试、文档和 PR 描述等元数据；实现参数变化后，PR 描述仍保留旧值也必须修正。确认存在的问题全部修复，不遗留已知技术债；判定问题不成立时则记录具体不变量、接口文档或最小实验，不能只写“不会发生”。随后运行相称的验证，commit，再次执行无管道的 `git push 2>&1`，并重新等待 hook 完成。循环直到 CI 全绿、push 后无新评论、无未解决 thread，且所有大中小问题均已处理或以证据判定不成立。

本地代码审查报告是独立于 GitHub review 活动的另一条输入。若本轮运行过本地 code-review 工作流，在完成审计和 merge 前必须用 `rg --files --hidden --no-ignore .code-review` 盘点报告并逐份阅读；`.code-review/.gitignore` 的 `/*` 会让这些文件不进入 git，普通 `rg --files`、PR 评论检查和 pre-push hook 都看不到它们。报告中的 commit hash 或行号若因 rebase 失效，应把每条发现重新映射到当前树并核实，不能因报告未出现在 PR 上或结论为 APPROVE 就跳过其中的小问题。最终审计必须同时覆盖 GitHub comment/review/thread 与本地 `.code-review` 报告。

hook 等待期间也可能有协作者推进同一分支。若外层输出显示 forced update、远端 SHA 异常变化或 cannot-lock-ref 的 actual 值不是内层刚推送的提交，立即恢复被覆盖提交、保留其作者历史并重新整合；不得把“外层失败属预期”泛化成忽略所有远端引用变化。

## 首次推送新分支

新分支第一次 push 时通常还没有 PR，hook 会以 rc 2 跳过 CI 与评论检查。创建 PR 后立即执行 `make check-pr-ci 2>&1`，同样不得接管道；按上述规则读取 rc、完整输出、评论和未解决 thread，并进入相同的修复、commit、push 循环。

## 文档收尾

代码 CI 全绿且全部审查意见处理完成后，运行 `llmdoc:update`，记录本轮新增的架构事实、工作流教训及落后于代码的文档。文档更新也必须 commit 并通过 `git push 2>&1` 推送，继续遵守同一 CI/评论闭环；只有文档提交的 hook 也给出终止成功报告，任务才算完成。
