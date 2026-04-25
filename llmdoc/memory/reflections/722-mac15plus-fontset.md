---
name: "722-mac15plus-fontset-reflection"
description: "反思: 实现 mac15plus 字体集过程中的发现、错误假设与文档教训"
type: reflection
---

## 错误假设

1. **PingFang SC 在 XeTeX/Core Text 下仍可访问**：初始方案设计基于"XeTeX 通过 Core Text 可访问全部系统字体"的假设。实测发现 macOS 26.4.1 上 PingFang SC 已被标记为系统 UI 专用字体，Core Text 拒绝暴露该字体名称。`\IfFontExistsTF{PingFang SC}` 返回 NO。

2. **PingFangUI.ttc 可通过文件路径加载**：该文件使用 Apple 私有字体格式（`hvgl` table），FreeType 完全无法解析。XeTeX 的 `[/path/font]` 语法依赖 FreeType，因此路径加载也不可行。otfinfo 报 "bad magic number"，fc-scan 无输出。

3. **expl3 中 Lua 代码的换行处理**：首次实现时未意识到 expl3 的 `\ExplSyntaxOn` 将换行符设为 catcode 9（ignored），导致 Lua 代码行尾关键字与下行关键字粘连（如 `dolocal`）。必须在每行末尾加 `~` 作为空格分隔符。

## 关键发现

- macOS 字体可用性矩阵需要区分三个层次：fontconfig、luaotfload (FreeType)、XeTeX (Core Text)。PingFang 在这三个层次上都不可用。
- `l3build unpack` 有缓存行为：修改 `.dtx` 后如果不清理 `build/unpacked/`，可能得到旧的生成文件。需要 `rm -rf build/unpacked` 后重新生成。

## 文档教训

- **package-architecture.md** 的字体集层列表缺少 `macold`，且需要补充 `mac15plus`。
- 字体集层的"运行期按变量选择文件"描述过于笼统，没有说明 `fontset=mac` 的多级检测机制。
- 缺少关于 Lua 代码嵌入 `.dtx` 的编码约定说明（expl3 下的空格处理）。

## 晋升候选

- expl3 中嵌入 Lua 代码的空格约定 → 可晋升到 `reference/coding-conventions.md`
- 字体集层的完整列表和检测逻辑 → 应更新 `architecture/package-architecture.md`
