默认使用简体中文回复；面向用户和维护者的文档也使用简体中文。

## 语言约定

- 日常交流、`llmdoc/`、README、Issue、PR 描述和评论默认使用简体中文。API 名、命令名、文件路径和代码引用保留原文。
- 使用自然、清楚的现代汉语。句子应说明谁做什么、为什么这样做以及有什么限制，不要连续堆放缩写、名词和内部术语。
- 中文句子使用全角中文标点。代码、命令、路径、参数和原样引用中的符号保持原样，不把其中的半角符号强行改成全角。
- 不为省字把完整名词压缩成生硬的单字。例如叙述 TeX box 时写“盒子”，不要写“盒”“父盒”“盒尾”；需要区分层次时写“外层盒子”“嵌套盒子”“盒子末尾”。
- 有普通说法时，不用生硬直译或流行套话。例如写“实现、连接、检查、决定、比对测试、形式”，不写“实装、真接入、闸门、拍板、对拍、形态”；也不要用“真……”一类说法强行强调。
- 技术词确有精确定义时可以保留。内部术语或不常见的英文词第一次出现时，应顺手说明它具体指什么，不能只换一个更抽象的词。
- 代码注释和技术文档优先描述可观察的行为与因果关系，少用比喻和口号式表述。

## 工作流

Load the `llmdoc` skill before broad code exploration, planning, document updates, or non-trivial code edits.

The main assistant should align with the user before non-trivial plans or edits.

Use available `llmdoc` subagents when they fit the task. Prefer `investigator` for context exploration, current-state research, unfamiliar subsystems, and reusable scratch reports; use `recorder` for stable doc updates, `worker` for scoped implementation, and `reflector` for process lessons.

At the end of a non-trivial task, the main assistant should evaluate whether to ask the user to run `/llmdoc:update`.

Treat `.llmdoc-tmp/` as a local temporary context cache only. Validate scratch reports before reuse; tracked `llmdoc/` docs are the project knowledge source.

Keep detailed workflow rules, templates, hook behavior, and doc-structure guidance in the `llmdoc` skill.

## 推送纪律

本项目的 `git push` 由 pre-push hook 包装，行为与普通仓库不同，必须按下面的方式处理。

- hook 用 `make hooks` 安装（实质是 `git config core.hooksPath .githooks`）。开始工作前先确认 `git config core.hooksPath` 有值，否则 push 会绕过全部检查。
- hook 是自包装的：它在内部自己再 push 一次，因此**外层 `git push` 总是以非零退出码结束**。不要把这个失败当成推送失败。实际是否推上去，要看 hook 输出的中间过程。
- hook 会找当前分支对应的 PR，检查 CI 状态，以及本次 push 之后评论区是否有新增评论。
- `git push` 必须写成 `git push 2>&1` 这类形态，**后面不接任何管道**（不要 `| tail`、`| grep`）。接了管道会丢掉真实退出码和完整输出。
- push 之后要通读输出，其中包含下一步的指示。特别注意 PR 评论里报告的问题，分为阻塞问题、重要建议、小问题三档。对每一条都要判断问题是否真实存在；确认存在的一律修掉，再 commit + push。目标是不留技术债，不要因为某条被归为"小问题"就跳过。
- 新分支首次 push 通常因为还没有对应 PR 而无法自动检查 CI 和评论。开完 PR 后应第一时间执行 `make check-pr-ci 2>&1` 接管跟踪，之后同样遵守上面关于读输出、修问题的要求。
- CI 全绿且三档问题全部解决后，启动 `/llmdoc:update` 记录这一轮值得留下的发现，并补齐文档落后于代码的部分；文档更新同样要 commit + push。
- 判定工作完成的标准：CI 全绿，且评论中提到的阻塞问题、重要建议、小问题全部解决。
