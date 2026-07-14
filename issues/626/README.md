# Issue #626 reproduction assets

Generated on 2026-07-14 from `ctex-kit` master `b0499aa3`, CTeX 2.6.3 files
unpacked from that source tree, Babel 26.9, and TeX Live 2026.

## Files

- `babel-ctex-default.tex`: loading Babel beside default `ctexbook` is not a
  heading-language bridge.  After `\selectlanguage{english}`, CTeX's Chinese
  scheme still typesets `第二部分` / `第二章`.
- `babel-ctex-bridge.tex`: a user-level bridge that uses only Babel's public
  `\extras<language>` hooks and CTeX's public `\ctexset` keys.  It switches
  Chinese/English heading labels, numbering, and captions.
- `babel-ctex-heading-switch.png`: XeLaTeX renders of the two MWEs.  The upper
  row shows the default mismatch; the lower row shows the public-key bridge.
- `babel-ctex-caption-portability.png`: pdfTeX/DVI renders.  Babel's current
  Chinese locale leaves `\figurename` unset in this route; explicit CTeX
  caption keys in the bridge avoid the `?figurename?` result.

## Verification

The bridge MWE was compiled with XeLaTeX, LuaLaTeX, upLaTeX, and pdfTeX in DVI
mode followed by `dvipdfmx`.  CTeX deliberately does not support the Fandol
fontset with direct PDF output from `pdflatex`, so its pdfTeX test route is the
DVI one.

Use `\selectlanguage` or an `otherlanguage` environment for a document-level
heading-language transition.  `\foreignlanguage` is intended for inline text
and does not consistently switch captions/date state.
