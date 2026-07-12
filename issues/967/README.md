# Issue #967 visual evidence

- `issue-967-before-after.png`: pre-fix and PR #968 output for all five changed commands, ordinary and subtract forms; `CJKunderanysymbol` and `CJKunderdot` are unchanged controls.
- `before-after-mwe.tex`: compile once at `4f4c07f6` and once at PR #968 commit `fd330541`, then compare the rendered pages.
- `leaders.png`, `cleaders.png`, `xleaders.png`: candidate leader behavior at 0/1/3/5pt offsets, subtract joins, punctuation, and line breaks.
- `leader-matrix.tex`: compile against pre-fix xeCJK, where the outer `\ULleaders` selection is not overridden locally, to generate the three candidate pages.
- `underwave-cleaders-vs-xleaders.png`: enlarged comparison of centered and expanded leaders for `\CJKunderwave`, covering normal/subtract forms and 0/1/3/5pt offsets. Centered leaders create double peaks at CJK fragment joins; expanded leaders keep the periodic mark continuous.
- `underwave-variants.tex`: focused MWE used to generate the ordinary/centered/expanded underwave pages. Compile it against the intermediate `cleaders` implementation, overriding its internal primitive through the aliases in the MWE.

The published screenshots use Adobe Source Han Sans SC Heavy 2.005R. The checked-in MWEs use `Noto Sans CJK SC Black` so they remain runnable without a bundled third-party font; replace that font declaration to reproduce the screenshots' exact glyphs.
