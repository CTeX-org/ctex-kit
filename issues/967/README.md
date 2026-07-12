# Issue #967 visual evidence

- `issue-967-before-after.png`: pre-fix and PR #968 output for all five changed commands, ordinary and subtract forms; `CJKunderanysymbol` and `CJKunderdot` are unchanged controls.
- `before-after-mwe.tex`: compile once at `4f4c07f6` and once at PR #968 commit `fd330541`, then compare the rendered pages.
- `leaders.png`, `cleaders.png`, `xleaders.png`: candidate leader behavior at 0/1/3/5pt offsets, subtract joins, punctuation, and line breaks.
- `leader-matrix.tex`: compile against pre-fix xeCJK, where the outer `\ULleaders` selection is not overridden locally, to generate the three candidate pages.

The published screenshots use Adobe Source Han Sans SC Heavy 2.005R. The checked-in MWEs use `Noto Sans CJK SC Black` so they remain runnable without a bundled third-party font; replace that font declaration to reproduce the screenshots' exact glyphs.
