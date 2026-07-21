Always answer and write document in 简体中文.

## 语言约定

1. **沟通交流和编写文档(`llmdoc/`、`docs/design/`、`README.md`、Issue、PR 描述与评论等)默认用中文**。技术名词、API 名、文件路径、代码引用保留原文不翻译。
2. **中文要用正常的普通话**,不要夹杂日式汉语词或工程黑话堆砌。具体避免的写法:
   - 「实装」→ 用「实现 / 写好 / 做好」
   - 「真接入」→ 用「连上 / 接上」
   - 「真物理」→ 用「真机 / 实际硬件」
   - 「闸门 / 守门 / 翻闸门」→ 用「检查 / 校验 / 开关 / 打开开关」
   - 「同款」→ 用「一样的 / 同样的」
   - 「落地」→ 用「完成 / 做完 / 写完」
   - 「守住」→ 用「防住 / 保住」
   - 「拍板」→ 用「决定 / 定下来」
   - 「对拍」→ 用「比对测试 / 差分测试」(第一次出现时说全称)
   - 「形态」→ 用「形式 / 情况 / 写法」
   - 「当场」→ 用「立刻 / 马上」
   - 「真启用」→ 用「真的开启 / 真的打开」

   技术词该精确用就精确用,但不要堆砌成「日式汉语 + 工程八股」混合体。

## 工作流

Load the `llmdoc` skill before broad code exploration, planning, document updates, or non-trivial code edits.

The main assistant should align with the user before non-trivial plans or edits.

Use available `llmdoc` subagents when they fit the task. Prefer `investigator` for context exploration, current-state research, unfamiliar subsystems, and reusable scratch reports; use `recorder` for stable doc updates, `worker` for scoped implementation, and `reflector` for process lessons.

At the end of a non-trivial task, the main assistant should evaluate whether to ask the user to run `/llmdoc:update`.

Treat `.llmdoc-tmp/` as a local temporary context cache only. Validate scratch reports before reuse; tracked `llmdoc/` docs are the project knowledge source.

Keep detailed workflow rules, templates, hook behavior, and doc-structure guidance in the `llmdoc` skill.
