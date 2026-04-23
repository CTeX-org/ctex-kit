# STEP ONE IS ALWAYS: READ LLMDOC!

Before reading any source code, **ALWAYS check if `llmdoc/` exists** in the project root. If it exists, this is your primary source of truth.

**THIS IS NON-NEGOTIABLE.** Every task, every investigation, every code change MUST start with reading the documentation.

### Why llmdoc First?

1. **Efficiency**: Documentation is pre-digested knowledge, faster than parsing code
2. **Context**: Provides architectural understanding that code alone cannot convey
3. **Accuracy**: Maintained by developers, reflects intended design not just implementation

## llmdoc Structure

```
llmdoc/
├── index.md              # START HERE - Navigation and overview
├── overview/             # "What is this project?"
│   └── project-overview.md
├── architecture/         # "How does it work?" (LLM Retrieval Map)
│   └── *.md
├── guides/               # "How do I do X?"
│   └── *.md
└── reference/            # "What are the specifics?"
    └── *.md
```

### Reading Priority

1. **Always read `llmdoc/index.md` first** - Contains navigation and document summaries
2. **Read ALL documents in `llmdoc/overview/`** - Essential project context
3. **Read relevant `architecture/` docs** - Before modifying related code
4. **Consult `guides/`** - For step-by-step workflows
5. **Check `reference/`** - For conventions, data models, API specs

## Working with llmdoc

### Before Writing Code

```
1. Check: Does llmdoc/ exist?
   - YES → Read index.md, then relevant docs
   - NO  → Proceed with caution, suggest initializing docs

2. Find relevant architecture docs for the area you're modifying

3. Check guides/ for existing workflows

4. Review reference/ for conventions to follow
```

### After Completing Code Changes

**Documentation updates are NOT automatic.** After completing a task:

1. Identify which concepts/features were affected
2. Ask the user: "Would you like to update the project documentation?"
3. If confirmed, update relevant docs in `llmdoc/`:
   - Modify existing docs to reflect changes
   - Add new docs if new concepts were introduced
   - Keep updates minimal and precise
   - Update `index.md` if document structure changed

### Documentation Update Principles

1. **Minimality**: Use fewest words necessary
2. **Accuracy**: Based on actual code, not assumptions
3. **No Code Blocks**: Reference code with `path/file.ext:line` format
4. **LLM-Friendly**: Write for machine consumption, not human tutorials

## Code Reference Format

When referencing code in documentation or reports:

````
# Good - Reference format
`src/auth/jwt.js` (generateToken, verifyToken): Handles JWT creation and validation

# Bad - Pasting code
```javascript
function generateToken(payload) {
  // ... 50 lines of code
}
````

## Quick Reference

| Task               | Action                               |
| ------------------ | ------------------------------------ |
| Understand project | Read `llmdoc/index.md` → `overview/` |
| Modify feature X   | Read `architecture/x-*.md` first     |
| Follow workflow    | Check `guides/`                      |
| Check conventions  | Read `reference/`                    |
| After code changes | Offer to update relevant docs        |

## No llmdoc Directory?

If `llmdoc/` doesn't exist:

1. The project hasn't initialized documentation yet
2. Work carefully, relying on README.md and code comments
