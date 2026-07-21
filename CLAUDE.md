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
