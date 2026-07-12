# Decision: pre-push 与 PR 审查闭环纪律

## 决策

本仓库所有常规 push 必须经过 `.githooks/pre-push` 的 self-wrapper，并以 hook 的完整输出而非外层 git 结果判断远端更新和任务终态。

## 约束

- 用 `make hooks` 安装仓库 hooks。
- push 命令固定为 `git push 2>&1` 或其显式 remote/refspec 变体，后面不接管道。
- 内层 push 才实际更新远端；外层 push 的失败是 self-wrapper 的预期副作用，必须从中间输出确认内层结果。
- 有对应 PR 时，等待 hook 检查 CI、新评论和未解决 thread；不得在远端更新成功后提前中断，也不得只用 CI watcher 替代。
- 对评论中的阻塞问题、重要建议和小问题逐项核实；成立的全部修复、验证、commit、push，不保留已知技术债。
- CI 全绿且审查意见清零后运行 `llmdoc:update`；文档提交仍进入同一 push 闭环。
- 新分支首次 push 若无 PR，创建 PR 后立即运行 `make check-pr-ci 2>&1`，再按相同规则处理结果。

## 理由

pre-push 同时承担真实 push、CI 等待和 review 活动检测。只看外层 rc 会把成功的内层 push 误判为失败；只看 `gh pr checks` 又会漏掉 push 后新增的 Bot 评论或未解决 thread。把完整输出、问题修复和 llmdoc 收尾统一成闭环，才能避免静默漏审和已知技术债。

## 实现依据

`.githooks/pre-push` (`GIT_POSTPUSH` self-wrapper): 执行内层 push 并调用评论检查。

`.githooks/check-pr-ci.sh` (terminal status): 以 rc 0/1/2/75 区分成功、CI 失败、无 PR 与待处理 review 活动。

`Makefile` (`hooks`, `check-pr-ci`): 提供安装与首次 PR 后补跑入口。
