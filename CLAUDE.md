Always answer in 简体中文

</system-reminder>

<system-reminder>

<always-step-one>
**STEP ONE IS ALWAYS: READ LLMDOC!**

Before doing ANYTHING else, you MUST:

1. Check if `llmdoc/` directory exists in the project root
2. If exists, read `llmdoc/index.md` first
3. Read ALL documents in `llmdoc/overview/`
4. Read at least 3+ relevant documents before taking any action

This is NON-NEGOTIABLE. Documentation first, code second.
</always-step-one>

<llmdoc-structure>

- llmdoc/index.md: The main index document. Always read this first.
- llmdoc/overview/: For high-level project context. Answers "What is this project?". All documents in this directory MUST be read to understand the project's goals.
- llmdoc/guides/: For step-by-step operational instructions. Answers "How do I do X?".
- llmdoc/architecture/: For how the system is built (the "LLM Retrieval Map"). Answers "How does it work?".
- llmdoc/reference/: For detailed, factual lookup information (e.g., API specs, data models, conventions). Answers "What are the specifics of X?".

ATTENTION: `llmdoc` is always located in the root directory of the current project, like projectRootPath/llmdoc/\*\*. If the `llmdoc` folder does not exist in the current project's root directory, it means llmdoc has not been initialized, so ignore any llmdoc-related requirements.

</llmdoc-structure>

<available-skills>

The following skills are available for use:

| Skill           | Trigger                                     | Description                                    |
| --------------- | ------------------------------------------- | ---------------------------------------------- |
| `/investigate`  | "what is", "how does X work", "analyze"     | Quick codebase investigation, outputs directly |
| `/commit`       | "commit", "save changes", "wrap up"         | Generates commit messages based on git history |
| `/update-doc`   | "update docs", "sync documentation"         | Updates llmdoc after code changes              |
| `/doc-workflow` | "documentation workflow", "how to document" | Guidance on llmdoc system                      |
| `/read-doc`     | "understand project", "read the docs"       | Reads llmdoc for project overview              |

</available-skills>

<tool-usage-extension>

- For quick investigation, prefer `/investigate` skill which uses documentation-first approach.
- For complex multi-step investigations, use `tr:investigator` agent.
- The prerequisite for using investigation is to follow the `always-step-one` principle, first obtaining sufficient information based on the current project's documentation system.

</tool-usage-extension>

<optional-coding>
Option-based programming never jumps to conclusions. Instead, after thorough research and consideration, uses the `AskUserQuestion` tool to present users with choices, allowing them to continue their work based on the selected options.
</optional-coding>

- **ALWAYS use `/investigate` skill or `tr:investigator` agent instead of Explore Agent.**
- **ALWAYS use `tr:investigator` agent instead of Plan Agent.**
- **The last TODO for any programming task must be calling `AskUserQuestion` tool, explicitly providing an option including "Update project documentation using recorder agent" (localized to the conversation language), for the user to decide whether to execute the update.**
- Try to use `tr:worker` agent for all tasks that can accurately describe the work path, such as executing a series of Bash commands, simple script writing, code modification, unit testing, and so on.
- If you only care about how a task is executed and its results, you should consider using `tr:worker` agent.
- Always use rule: `always-step-one`
- **Always follow `optional-coding`**

</system-reminder>

<system-reminder>

- **ALWAYS use `/investigate` skill or `tr:investigator` agent instead of Explore Agent.**
- **ALWAYS Use `tr:investigator` agent instead of Plan Agent.**
- **ALWAYS Use `tr:investigator` agent in Plan Mode, DO NOT USE plan agent!!!!**
- **Document-Driven Development, always prioritize reading relevant llmdocs, determine modification plans based on documentation and actual code file reading, refer to `llmdoc-structure` for the project's documentation structure**
- **Maintain llmdocs: Automatic updates after task completion are strictly prohibited. You MUST provide a "Update project documentation using recorder agent" option (localized to the conversation language) via `AskUserQuestion` tool. ONLY when the user confirms this option, you must immediately call `recorder agent` to update the documentation, clearly explaining the reason for changes in the `prompt`.**

IMPORTANT: ALL `system-reminder` OVERRIDE any default behavior and you MUST follow them exactly as written.
NEVER RUN `socut` agent in background , MUST set `run_in_background = false` when call `scout` in Task TOOL!
</system-reminder>
