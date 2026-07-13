---
name: 381-cjkfntef-backend-boundary
description: 反思: #381 通过真实包解析和嵌入字体区分 XeTeX 透明替换与 LuaTeX 不兼容边界
type: reflection
---

# #381 `CJKfntef` 后端边界反思

## 任务与结论

Issue #381 表现为 LuaTeX 下先载入 `CJKfntef` 后 `\setCJKmainfont` 失效。TeX Live 2026 仍可复现：请求 FandolHei 时 PDF 实际嵌入 FandolSong；交换加载顺序则嵌入 FandolHei。根因是传统 `CJKfntef` 载入 `CJK.sty`，覆盖 LuaTeX-ja 与 ctex 共用的字体族接口。

最终不移植 `xeCJKfntef` API，也不把请求静默替换成 API 不同的 `lua-ul`。ctex 在 LuaTeX 后端禁止后续载入 `CJKfntef`；若包已经先载入则 critical 中止。用户迁移到 `lua-ul`。

## 关键认知修正

“XeLaTeX 也应拒绝同名包”的直觉不成立。真实日志表明 xeCJK 会把 `CJKfntef` 请求替换为 `xeCJKfntef`，两种加载顺序都实际嵌入 FandolHei。包名只是用户输入，不能代替对最终解析文件和协议的检查。

功能相似也不足以支撑透明替换。`xeCJKfntef` 与传统包保持基本一致的用户接口，适合 XeTeX 透明替换；`lua-ul` 使用 `\underLine`、`\strikeThrough`、`\highLight` 等不同接口，只能作为明确迁移路径。

## 测试与证据

主路径测试同时断言包未载入和后续中文字体节点仍为 FandolHei。预加载路径不能让测试在截获 critical 后继续运行，否则 LuaTeX-ja 会因已经存在的 `\CJKfamily` 产生二次错误，掩盖目标分支；测试改为直接输入引擎定义文件，截获目标 `\msg_critical:nnn` 后立即结束。

可视证据不能只依赖字形观感。前后 MWE、`pdffonts` 的实际嵌入字体和并排渲染共同证明旧状态污染与推荐路径；诊断截图证明用户能看到清晰边界。

## 可复用规则

- 跨引擎兼容调查先检查实际载入文件，再检查 API 和内部协议，最后检查输出节点或嵌入字体。
- 已污染状态应尽早 hard stop；未来的不兼容请求可以在加载边界阻止并给出迁移说明。
- fatal 分支回归应在目标错误处结束，不应容许后续二次错误替代被测信号。
