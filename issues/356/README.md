# Issue #356 reproduction assets

Generated on 2026-07-14 from `ctex-kit` master `b0499aa3`, with CTeX 2.6.3
files unpacked from that source tree and TeX Live 2026.

## Bottom float and footnote

`float-footnote.tex` compiles unchanged with both LuaLaTeX and XeLaTeX.  Its
default is LaTeX's usual footnote-above-float order.  Uncomment
`\def\CTEXBelowFloat{}` to load `stfloats` and call `\fnbelowfloat`; the same
source then puts the footnote below the bottom float.  The companion
`float-footnote-order.png` shows the two LuaLaTeX renders side by side.

This is an ordinary LaTeX-level solution, not a LuaTeX-ja-specific one.
The MWE was also compiled with XeLaTeX, where it produces the same ordering.

## Footnote mark after full-width punctuation

`footnote-punctuation.tex` shows a normal CJK character and a full-width comma
followed by a footnote mark.  With current CTeX, the LuaLaTeX and XeLaTeX
defaults agree.  In a LuaLaTeX-only document, uncommenting
`\def\CTEXInhibitFootnoteGlue{}` prepends LuaTeX-ja's `\inhibitglue` to both
`\footnote` and `\footnotemark`.  This moves the mark after a full-width comma
left into the comma's side bearing; it leaves the ordinary-CJK case unchanged.

`footnote-punctuation.png` compares the LuaLaTeX default and that opt-in.  It
is a deliberate local stylistic choice, rather than a cross-engine CTeX
default.
