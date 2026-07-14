# Issue #275 investigation assets

Generated on 2026-07-14 with XeTeX 0.999998 (TeX Live 2026), CTeX
v2.6.2 files generated from the local `ctex-kit` source tree, and
SJTUBeamer v3.2.0 (`72a76138446137c1090070ba0cf66cbe56b3bd80`).

## Files

- `custom-section-page.tex` / `.pdf`: demonstrates the current public-interface
  gap. `\CTEXthesection` still expands after `section/numbering=false`, while no
  public numbering predicate is available.
- `current-interface-gap.png`: the two pages of that MWE side by side.
- `sjtu-baseline.tex` / `.pdf`: SJTUBeamer using the current private CTeX
  heading macros.
- `sjtu-prototype.tex` / `.pdf`: the same document with an illustrative public
  API prototype.
- `sjtubeamer-private-vs-public.png`: section-page comparisons for the
  `maxplus`, `max`, and `min` layouts.

The two SJTUBeamer PDFs contain nine pages each. Rendering each page to PNG and
comparing with ImageMagick gives `AE = 0` for every corresponding page: the
private-macro baseline and public-API prototype are pixel-identical.

The commands defined in `sjtu-prototype.tex` are investigation prototypes, not
interfaces already shipped by CTeX.
