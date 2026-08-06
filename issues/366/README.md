# Issue #366 资产

给 `zhnumber` 增加**算筹**（counting rod）数字样式的可行性材料。算筹有纵横两式交替
使用，Unicode 把两套 1--9 分开编码在 U+1D360--U+1D371；`0` 无算筹符号，用缩小的
`〇`。

## 2026-07：横排原型与竖排探测

- `zhrod-prototype.tex` / `zhrod-prototype-{xetex,luatex}.pdf` / `-xetex.png` —
  独立 `\zhrod` 原型（当时用 Noto Sans Symbols 2），支持 `[hv]`／`[vh]` 两种交替、
  含零与负数的小数。相邻字距取 `\kern-.14em`，是验证机制的临时视觉参数。
- `vertical-native-probe.tex` / `-luatex.pdf` / `-luatex.png` — 在原生 LuaTeX-ja
  竖排类里用 `\hbox{\yoko ...}` 保持算筹横排，说明引擎层面可行。
- `vertical-probe.tex` — 在当前 `ctexart` 里直接 `\tate` 的**失败**用例（CTeX 的
  LuaTeX 后端刻意禁用 `ltj-latex`），一并保留作反证。

## 2026-08 追加：TeX Live 自带字体与码区朝向

- `issue366-lxgw-probe.tex` / `.pdf` / `issue366-lxgw-and-orientation.png` —
  用 TeX Live 的 `lxgw-fonts`（`LXGWWenKaiGBLite-Regular.ttf`）排算筹，正文与算筹
  同一字体；并列出两个码区的实测朝向。
- `issue366-charclass-probe.tex` — 探测 `\XeTeXcharclass`：算筹码位为 0（非 CJK），
  而 `〇`、`一` 为 1。这解释了为什么在 `ctexart` 里靠 `\CJKfamily` 切换取不到算筹字形。
