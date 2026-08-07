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

## 2026-08 追加：实现完成后的 MWE 与截图

这一组对应实际实现（`\zhrod` 可展开、`\zhrodbox` 负责排版效果，加一组 `\zhrodsetup`
选项），用的是 PR 分支现场 unpack 出来的 `zhnumber.sty`，引擎为 XeTeX。

- `issue366-mwe.tex` / `issue366-overview.png` — 五组行为的总览：基本用法、`units`
  的纵横、`zero` 的填与省、`minus` 的独立＼与组合字符叠加、`\zhrodbox` 的字距。
  `minus=overlay` 那一行换用 JuliaMono，因为两种负号记法所依赖的字符恰好互补：
  `lxgw-fonts` 的 5 款只有 U+FF3C，`juliamono` 的 14 款只有 U+20E5，没有一款同时具备。
- `issue366-kern.tex` / `issue366-kern-compare.png` — `\zhrodbox` 的字距效果，两个盒子
  都加了框便于比较宽度：`\zhrod{12345}` 宽 50.0pt，`\zhrodbox{12345}` 宽 44.4pt，
  五位筹码之间四处字距，每处 −1.4pt。
- `issue366-verify.tex` / `issue366-verify-output.txt` — 逐条核对手册里那些具体数字的
  脚本与它的原始输出。除上面两个宽度外还核了：默认设置下 `\zhrod{12030.405}` 的字符
  序列、默认负号是 U+FF3C、`zero=omit` 下 `\zhrod{0}` 为空串而 `\zhrod{0.0}` 只剩一个
  小数点、`\zhrod{1.2.3}` 只排出 `1.2` 那部分、以及 `minus=overlay` 在末位为 0 时
  组合字符落在 U+3007（〇）上而不是落在一个筹码上。
