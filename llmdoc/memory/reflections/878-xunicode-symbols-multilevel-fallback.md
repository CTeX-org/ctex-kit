---
name: 878-xunicode-symbols-multilevel-fallback
description: xeCJK xunicode-symbols.tex 驱动从“单层 if-else 字体回退”升级为“逐字符多级链式字体回退”的根因、实现要点与可复用模式
metadata:
  type: feedback
---

# 反思: xeCJK #878 xunicode-symbols.tex 多级字体回退

## 起因

#878 报告 Windows 11 用户运行 `l3build install --full` 编译 `xunicode-symbols.pdf`
时出现成片 `Missing character` 警告，缺失字符散布在多个 Unicode 区段
（符号、几何形状、CJK Stroke 等）。

此前驱动文件采用一次性的“if-else 字体选择”模式：检测到 `Segoe UI Symbol`
就整段使用它，否则整段切到 `Noto Sans Symbols 2`。这套逻辑在 #809/#810
和 [[809-810-hyperref-annot-ecglue]] 阶段已经是“能编”而不是“能覆盖全部字符”的策略。
Windows 11 下 `Segoe UI Symbol` 虽然存在，但其字符覆盖范围与 `xunicode-addon`
要展示的全部符号并不相交，于是字符缺失在“整段切单一字体”模式下无法被任何 fallback 接住。

## 错误的方向

最初容易往两个方向走：

1. 在 CI 的 Linux runner 上预装更全的字体，让发布产物自带完整 PDF。
   这只解决“CI 出 PDF”，不解决“用户 `l3build install --full` 在本地缺字”。
2. 把 `Segoe UI Symbol` 换成另一只单字体（例如直接换 `Symbola`）。
   这只是换一个角度的整段绑定，没有处理“没有任何单一字体覆盖全部目标字符”这一事实。

## 真正的根因

`xunicode-addon` 列出的符号集合是跨多个 Unicode 区段的“拼盘”，
不存在一只在主流 Windows / Linux / macOS 上都默认装且覆盖完整的字体。
所以驱动必须放弃“整段单字体”模型，转向**逐字符**回退：对每个字符，
依次询问候选字体是否含有该字符的 glyph，直到命中或耗尽链。

## 修复模式：XeTeX 逐字符多级 fallback 链

驱动文件中先用 fontspec 的 `\IfFontExistsTF` 条件声明候选 NFSS 字体家族：

```tex
\setmainfont{FreeSerif}
\IfFontExistsTF{Noto Sans Symbols 2}
  {\newfontfamily\xunsymNoto{Noto Sans Symbols 2}}{}
\IfFontExistsTF{Symbola}
  {\newfontfamily\xunsymSymbola{Symbola}}{}
\IfFontExistsTF{Segoe UI Symbol}
  {\newfontfamily\xunsymSegoe{Segoe UI Symbol}}{}
\IfFontExistsTF{DejaVu Sans}
  {\newfontfamily\xunsymDejaVu{DejaVu Sans}}{}
```

`\UnicodeTextSymbol` 在排出某个 codepoint 之前，使用 XeTeX 的
`\tex_iffontchar:D \tex_font:D #1` 测试**当前激活字体**是否含该字符，
不命中则用 `\cs_if_exist_use:N` 切换到下一级候选字体后再次测试，
形成 `FreeSerif → Noto Sans Symbols 2 → Symbola → Segoe UI Symbol → DejaVu Sans`
五级嵌套链。

关键技术细节：

1. **`\tex_iffontchar:D \tex_font:D #1`**：以当前 NFSS 选定字体（`\tex_font:D`）
   为对象判断是否包含 codepoint `#1`，必须在 `\exp_stop_f:` 结尾配合
   `\reverse_if:N` 把缺字符当作 true 分支走，进而进入下一级回退。
2. **`\cs_if_exist_use:N`**：候选字体家族在 `\IfFontExistsTF` 缺字体时根本没有
   被 `\newfontfamily` 定义；如果直接展开未定义控制序列会立刻报错。
   `\cs_if_exist_use:N` 在该家族未定义时静默跳过、自动让外层 `\reverse_if:N`
   继续看下一层，组合起来等价于“候选不存在 ⇒ 视同当前字体仍未命中 ⇒ 进入再下一级”。
3. **嵌套顺序**：链应从“最稳定可装且覆盖最强”排到“仅当系统恰好有时才用”。
   `FreeSerif` 由 `fonts-freefont-ttf` 提供，是 Linux 上最易装、字符覆盖较广的备选；
   `Noto Sans Symbols 2` 是符号字体里的高覆盖现代版本；`Symbola` 历史悠久但许可证不稳定；
   `Segoe UI Symbol` 仅 Windows 默认提供；`DejaVu Sans` 是 Linux 桌面发行版的普遍选择。

## 适用范围与不适用范围

**Why:** 这个模式适合“一段拼盘字符 + 没有单一字体能完整覆盖”的文档驱动场景，
比如 `xunicode-symbols.tex` 这种符号目录式输出。

**How to apply:**
- 文档驱动 / 演示性 PDF：用该模式，让 `l3build install --full` 在常见平台都能出图。
- 用户产出 / 正文排版：**不要**自动套用该模式。正文字体回退应通过 fontspec
  的 `Fallback` 选项、`\setmainfont` `Fallback` 子句或 LuaTeX 的 `node.fontfallback`
  做声明式配置，而不是为每个 `\UnicodeTextSymbol` 都展开 5 层 `\iffontchar`。
- xeCJK 的 CJK 字体回退（如 `\CJKfamily` / `\setCJKmainfont`）也不属于这套模型；
  它们是字符分类驱动的字体切换，与 codepoint 级 glyph 缺失不同层。

## 教训

1. **不要用 CI 端预装字体作为“用户也能复现”的兜底**。仓库产物是 dtx + driver，
   用户安装时只能依赖目标系统字体清单；CI 端策略最多让发布资产里的 PDF 完整，
   但 `l3build install --full` 在用户机上仍会触发 driver 重新排版。
2. **当某个字符集合“没有任一字体能完全覆盖”时，整段单字体策略必然漏字符**，
   再换一只单字体只是把漏掉的字符换一批。结构上必须切到 codepoint 级回退。
3. **`\IfFontExistsTF` + `\cs_if_exist_use:N` 是 XeTeX 安全多级链的最小组合**：
   前者决定“是否定义这个家族”，后者决定“运行时遇到未定义家族时跳过”，
   两者缺一会导致 `! Undefined control sequence`（缺前者）
   或在缺字体的机器上**链断**而非**跳级**（缺后者）。
4. CI Linux runner 的字体列表（参见 `.github/workflows/release.yml`
   的 `Install CJK fonts` 步骤）是驱动 fallback 链的**最低保证**，而不是设计依据：
   即便 CI 总有 `FreeSerif + Noto Sans Symbols 2`，驱动也仍要为
   `Symbola / Segoe UI Symbol / DejaVu Sans` 缺席的机器留路径。

## 相关引用

- 实现位置：`xeCJK/xeCJK.dtx` 中 `xunicode-symbols.tex` driver 段附近的
  `\UnicodeTextSymbol` 定义与字体家族声明（约 line 15013 起、`\UnicodeTextSymbol` 在 15131 附近）。
- 文档章节：`xeCJK/xeCJK.dtx` xunicode-symbols 介绍段（带 `\changes` v3.10.0 2026/06/23）。
- CI 字体策略：`.github/workflows/release.yml` `Install CJK fonts` 步骤，
  `[[reference/build-and-test]]` 中 “CI 字体策略” 小节。
- 前一代单层回退：参见 [[809-810-hyperref-annot-ecglue]] 与 #809/#810 的 Segoe→Noto 切换。
