# Push 与 PR 审查闭环

## 安装 hook

首次进入仓库后运行 `make hooks`，它会把 `core.hooksPath` 设置为 `.githooks`。除紧急情况外，不使用 `git push --no-verify` 绕过 pre-push。

## 推送命令

始终单独执行 `git push 2>&1`，或带显式 remote/refspec 的等价形式；命令后不得连接管道。调用方必须同时取得完整 stdout/stderr 和真实 rc，不能用 `tail`、`tee`、`grep` 等管道截断或改写结果。

pre-push 是 self-wrapper：外层 push 进入 hook 后，hook 用 `GIT_POSTPUSH=1` 发起真正更新远端的内层 push；控制流返回后，外层 push 会因远端引用已更新或连接关闭而报告失败。这是预期现象。实际是否推送成功，以输出中的内层 push 结果和 `post-push: ✔ push succeeded` 为准，不能只看外层 rc 或最后一行。

## 等待 CI 与评论

内层 push 成功后，hook 调用 `.githooks/check-pr-ci.sh`：等待当前分支对应 PR 的 CI 进入终态，按 workflow 名只保留最新 run，并检查 push 后的新 formal review、Bot issue comment 与未解决 review thread。

必须让 hook 自己运行到终止报告，不得在看到远端更新成功后提前中断。单独运行 `gh pr checks --watch` 只能看 CI，不能替代 hook 的评论和 thread 检查。

终止结果按输出理解：rc 0 表示 CI 全绿且 push 后无新 review 活动或未解决 thread；rc 1 表示 CI 失败；rc 75 表示 CI 已过但出现新 review 活动或未解决 thread；rc 2 表示未找到 PR 或 `gh` 不可用，pre-push 将其视为非致命，但操作者仍需完成后续检查。

## 处理审查意见

push 输出会给出下一步指示和相关链接，必须完整阅读。PR 评论可能列出阻塞问题、重要建议和小问题；逐项回到代码、测试或官方接口证据核实，不因评论来自 Bot 而直接接受，也不因标为“小问题”而跳过。

确认存在的问题全部修复，不遗留已知技术债；随后运行相称的验证，commit，再次执行无管道的 `git push 2>&1`，并重新等待 hook 完成。循环直到 CI 全绿、push 后无新评论、无未解决 thread，且所有大中小问题均已处理或以证据判定不成立。

## 首次推送新分支

新分支第一次 push 时通常还没有 PR，hook 会以 rc 2 跳过 CI 与评论检查。创建 PR 后立即执行 `make check-pr-ci 2>&1`，同样不得接管道；按上述规则读取 rc、完整输出、评论和未解决 thread，并进入相同的修复、commit、push 循环。

## 文档收尾

代码 CI 全绿且全部审查意见处理完成后，运行 `llmdoc:update`，记录本轮新增的架构事实、工作流教训及落后于代码的文档。文档更新也必须 commit 并通过 `git push 2>&1` 推送，继续遵守同一 CI/评论闭环；只有文档提交的 hook 也给出终止成功报告，任务才算完成。
