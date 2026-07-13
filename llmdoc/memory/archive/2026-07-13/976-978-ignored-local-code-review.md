---
name: 976-978-ignored-local-code-review
description: 反思：PR #976 完成审计漏读被 git 忽略的本地 code-review 报告，导致两项小问题合并后由 #978 补修
type: reflection
---

# 976/978: 本地审查报告不在 PR 闭环内

## 失败

PR #976 合并前，`.code-review/from-257714a/from-257714a-to-0441cd0.md` 已记录两个有效小问题：`quanjiao` 用户手册描述落后于新行为，以及 punctuation template 两张键表未统一对齐。完成审计只检查了 GitHub comment、formal review、thread、CI 和分支状态，错误地声明所有问题均已解决。

根因不是 hook 漏检，而是输入集合不完整。`.code-review/.gitignore` 用 `/*` 忽略全部本地报告；它们不会进入提交和 PR，普通 `rg --files` 也因遵守 ignore 规则而看不到。pre-push hook 只检查 GitHub 上的 review 活动，没有办法推断本地报告存在。

## 修正

PR #978 单独修复两项遗漏。今后只要运行过本地 code-review，完成审计和 merge 前都要用 `rg --files --hidden --no-ignore .code-review` 显式盘点并阅读报告，把它当成与 GitHub review 并列的独立输入。报告结论为 APPROVE 也不表示其中没有重要建议或小问题。

rebase 会使报告中的 commit hash 和行号过时，但不会使发现自动失效；每条发现都要重新映射到当前树并验证。完整审计的证明责任是覆盖所有已知审查渠道，而不是只证明某一渠道没有未解决活动。
