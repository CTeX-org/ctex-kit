# Issue #1104 资产

xeCJK 为 microtype 找回歧义字符的槽位时，只设置了 `\MT@char`，没有同步 `\MT@char@`。

根因：xeCJK 在导言区结束时把 `\TS1\textperiodcentered`、`\TU\textendash`、`\TU\textquoteleft` 等歧义字符重定义为受保护的宏，并在 `\g__xeCJK_ambiguous_slot_prop` 里记下它们的槽位。microtype 不能再从这些宏解析出槽位，`\MT@get@slot` 留下 `\MT@char@ = -1`，再复制给 `\MT@char`。xeCJK 的补丁 `\xeCJK@microtype@get@slot` 随后调用 `\__xeCJK_get_ambiguous_slot:`，只把 `\MT@char` 改成记录的槽位。microtype 在 XeTeX 下测量字符宽度的 `\MT@get@charwd`（`microtype-xetex.def`）依据的是 `\MT@char@`：负值表示字形序号，于是测量 `\XeTeXglyph 1` 的宽度。

- TFM 字体（`\XeTeXfonttype = 0`）不允许 `\XeTeXglyph`，直接报错。microtype 自己在 `\MT@get@slot@` 里对 TFM 字体的检查依据的是 `\MT@char`，此时它已经是有效槽位，检查没有起作用。
- OpenType 字体按 1 号字形的宽度计算突出量，数值静默出错。

## 文件

- `issue1104-mwe-tfm.tex` — MWE 1：NFSS 回退到 `TS1/cmr`（`tcrm1000`）。修复前报 `Cannot use XeTeXglyph with tcrm1000; not a native platform font.`，随后 `Missing number`，183 号槽位得到 lp=100、rp=133；修复后与只加载 fontspec 时一样是 lp=83、rp=111。
- `issue1104-mwe-otf.tex` — MWE 2：TeX Gyre Termes 没有专用的 microtype 配置，突出量按字符宽度计算。10pt 下修复前 U+2013 为 67/67、U+2014 为 50/50、U+201C/U+201D 为 100/100；只加载 fontspec 时为 100/100、150/150、133/133。U+2018/U+2019 碰巧相同，逗号（不是歧义字符）始终相同。修复后与 fontspec 完全一致。
- `issue1104-nodes.tex` — 节点列表：第一行两端 microtype 插入的 margin kern。修复前 `\kern-1.0 (left margin)`、`\kern-0.5 (right margin)`；只加载 fontspec 与修复后都是 `\kern-1.33`、`\kern-1.5`。
- `issue1104-confirm.tex`／`issue1104-confirm.png` — 对比图，24pt。左：xeCJK master（修复前）；中：只加载 fontspec（参照）；右：修复后。红线是版心边界，字符越过红线的部分是突出量。小字一行是当前字体的 `\lpcode`/`\rpcode`，绿色与参照值一致，红色不同（括号里是参照值）。下方是第一行行首“和行尾—的 400 dpi 放大图：修复前破折号几乎不突出，左引号突出过多。
- `issue1104-compose.sh` — 拼接对比图的脚本。

对比图中的引号和破折号用 `\textquotedblleft`、`\textemdash` 等文本命令输入：直接输入的“—”等歧义字符在 xeCJK 中按 CJK 字符排版，不经过这条路径。每行之后接一个与版心等宽的空盒子，使段落在行尾的空格处自然断行。

测试环境：XeLaTeX，TeX Live 2026，microtype 2026/03/01 v3.2d；xeCJK 为仓库 master `8e02899c`（v3.10.7 开发版）。修复分支 `fix-1104-microtype-char` 在 `\__xeCJK_get_ambiguous_slot:` 里同时设置 `\MT@char@`。
