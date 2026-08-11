# Issue #1068 资产

`ctex` 路由到 `luatexja` 时，用户设的 `kanjiskip` 会被随后的 `\selectfont` 重置。
**已在 ctex v2.6.5 修复。**

报告只提到 LuaLaTeX，实测 **upTeX 同样受影响**；XeTeX 与 pdfTeX 正常。

## 成因

`ctex/ctex-engine.dtx` 里有一段 `\ctex_at_end:n` 重定义 `\@@_update_stretch_auxii:`，
给它加上 `\ctex_if_ccglue_touched:` 守卫。这段原先被 docstrip 守卫限定在
`pdftex|xetex`。

调用链是 `\selectfont` → `\ctex_update_size:` → `\ctex_update_stretch:`，后者分两支：

- `linestretch` 为 `\maxdimen` 时走 `\@@_update_stretch_auxi:`，该支自带守卫；
- 否则走 `\@@_update_stretch_auxiii:`，无守卫、直接重设间距。

默认 `linestretch` 是 `\ccwd`（实测 10.53937pt）而不是 `\maxdimen`，所以实际走的是后一支
——那段被限定引擎的重定义正是给后一支补守卫的地方，LuaTeX 与 upTeX 缺了它。

最直接的判据是解包产物里该重定义的出现次数：

| 文件 | 修复前 | 修复后 |
| --- | --- | --- |
| `ctex-engine-pdftex.def` | 1 | 1 |
| `ctex-engine-xetex.def` | 1 | 1 |
| `ctex-engine-luatex.def` | **0** | 1 |
| `ctex-engine-uptex.def` | **0** | 1 |
| `ctex-engine-aptex.def` | **0** | 1 |

修法就是去掉那段的引擎限制。`\ctex_if_ccglue_touched:` 本身三套引擎实现都已存在
（pdfTeX/XeTeX 比较 `\CJKglue` 是否仍与 `\@@_ccglue:` 同义，LuaTeX 与 upTeX 比较
`\l_@@_ccglue_skip` 与引擎参数是否相等），缺的只是调用它的位置。

## 文件

- `issue1068-reporter-mwe.tex` — 报告者原文的第二个 MWE（经 ctex 路由那个），
  加了 `\typeout` 读数。
- `issue1068-mwe.tex` / `issue1068-before-after.png` — 用于截图的精简版与对比图。
  上半是 ctex 2.6.4：第二行字距塌回默认；下半是本次修复后：两行一致。

## 实测数据

压 `\linespread{2}\selectfont` 前后的 `kanjiskip`（用户设的是
`10pt plus 1pt minus 1pt`）：

| 引擎 | 修复前（后） | 修复后（后） |
| --- | --- | --- |
| LuaTeX | **0.0pt plus 0.60931pt** | 10.0pt plus 1.0pt minus 1.0pt |
| upTeX | **0.0pt plus 0.60931pt** | 10.0pt plus 1.0pt minus 1.0pt |
| XeTeX | 用户定义保持 | 同（无变化） |
| pdfTeX | 用户定义保持 | 同（无变化） |

未设置 `kanjiskip` 时仍随字号更新，守卫没有拦住正常行为：
10pt 下 `0.60931pt`、`\zihao{1}` 下 `2.89365pt`、回到 `\zihao{5}` 又是 `0.60931pt`。

## 一处需要知道的连带变化

修好后 `\ccwd` 会把用户设的 `kanjiskip` 算进去（`\ccwd = kanjiskip + \zw`），于是
`\ccwd` 从 `10.53937pt` 变 `20.53937pt`、`\parindent` 从 `21.07874pt` 变
`41.07874pt`——设了较大 `kanjiskip` 的文档，首行缩进会随之变宽。

这是**既有语义而非本次引入**：`\ctexset{linestretch=\maxdimen}` 这条 ctex 既有的、
走 `auxi` 分支的配置下，读数完全相同（`\ccwd` 20.53937pt、`\parindent` 41.07874pt）。
本次只是让 LuaTeX 与 upTeX 与该设计保持一致。

## 一个现成的绕法（修复前可用）

`\ctexset{linestretch=\maxdimen}` 能让间距不被重置——它使 `\ctex_update_stretch:` 走
自带守卫的 `auxi` 分支。

注意**只能用 `\ctexset`，类选项无效**：`\documentclass[linestretch=\maxdimen]{ctexart}`
静默失效（实测值仍是 `\ccwd`）。因为 `linestretch` 注册在键空间 `ctex`（只认
`\ctexset`），而类选项走键空间 `ctex/option`；未知类选项会被转发给标准文档类（为了透传
`a4paper` 一类），`article` 不识别便丢弃。这一点本次未改动。
