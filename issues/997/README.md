# Issue #997 资产

`xpinyin` 与 `xeCJK` 的 `AutoFallBack` 同时使用时，注音被压缩到错误宽度。

主字体 `lmroman10` 没有 CJK 字形，靠 `AutoFallBack` 切到 `FandolSong` 才排得出汉字。
`xpinyin` 量宽用的 `\l__xpinyin_tmpa_box` 里那次 `\__xpinyin_CJKsymbol_hook:` →
`\xeCJK_select_font:` → `\__xeCJK_select_font:Nn` 第一句就是
`\xeCJK_clear_fallback_font:`，把刚切好的后备字体状态清掉。量宽盒子于是退回主字体、
字形缺失，量出 2.8pt（该字体的 **notdef** 宽度，与标点无关；正确值 10.0pt），拼音随后被
`\box_resize_to_wd_and_ht:Nnn` 压缩到这个错误宽度。

**可见的汉字本身不受影响** —— 它由量宽盒子之外的 `\__xpinyin_save_CJKsymbol:n` 输出，
那时后备字体仍然有效。所以这是量宽缺陷而非渲染缺陷；issue 标题与终端两条
`Missing character` 给人的「汉字排不出来」印象，来源是那个只取尺寸、从不进页面的临时盒子。

- `issue997-mwe.tex` — 最小复现（issue 原 MWE）。
- `issue997-before-after.png` — 上：修复前，拼音 `zhōng guó` 挤成一团、几乎重叠；
  下：修复后，两组拼音各自对齐到「中」「国」下方。两版的**汉字完全相同**，
  差异只在拼音。
- `issue997-pinyin-detail.png` — 拼音区域放大 4 倍的左右对照，重叠现象更清楚。

`pdftotext -bbox` 精确读数：

| | `zhōng` 横向跨度 | 汉字「中」跨度 | `Missing character` |
|---|---|---|---|
| 修复前 | **2.79pt** | 9.96pt | 2 条 |
| 修复后 | **9.96pt** | 9.96pt | 0 |

## 修复

见 PR #1059（目标分支 `xpinyin/maintaining`）。`\__xpinyin_CJKsymbol_hook:` 改调新增的
`\__xpinyin_reselect_CJK_font:`，判据是 `\xeCJK_reset_fallback_font:` 是否等于
`\prg_do_nothing:`（xeCJK 表达「当前处于后备字体状态」的唯一状态量）：已在后备字体里
就不重选，否则保持原有行为。

一点值得记的：实测把那次重选**整个删掉**同样能修好本 issue（回归 5/5 全绿、产物与基线
逐字节相同）。保留 else 分支的理由是保守而非必需 —— 进入该 hook 时实际当前字体
（`\fontname\font`）已经是 CJK 字体，只有 NFSS 参数（`\f@family`）还停在西文族；
`xeCJK` 若改变字体切换的时点，重选会重新变得必要。最初判断「重选必需」是误读了
NFSS 参数，已由独立审查推翻。

## 判据选择

整体宽度对这个缺陷**零判别力**：拼音在 `\hbox_overlap_right:n` 零宽盒子里，不占外部
宽度，缺陷版与修复版的 `\hbox{\xpinyin*{中}}` 同为 10.0pt。必须读节点列表里量宽盒子
自身的宽度（`x2.8` vs `x10.0`），或用 PDF bbox 看最终产物。
