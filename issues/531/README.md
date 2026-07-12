# Issue #531 before/after evidence

The same `issue-531-mwe.tex` was compiled with XeTeX 0.999998 and LaTeX2e
2026-06-01 against these two source trees:

- before: tag `xeCJK-v3.10.2`, commit `dfac1a8a`
- after: PR #965 squash merge, commit `ed1e8400`

The MWE uses Adobe Source Han Sans SC Heavy 2.005R from
`09_SourceHanSansSC.zip`. Extract `SourceHanSansSC-Heavy.otf` into a local
`font/` directory beside the MWE before compiling. The font SHA-256 used for
these outputs is:

`6374b11bc4c2cd4bd7be1a1d64cf5047906c8a6a025c64e023c6792e50ba985e`

Both PDFs were rasterized at 600 dpi. The two screenshots use the same fixed
crop (`1545x607+1214+1040`) from identically sized pages, so their coordinates
are directly comparable. The glyph pixels are identical; 1297 pixels differ,
all in the underline rows.

For the first row, the common glyph-ink bounds are `x=43..1501`:

- v3.10.2 underline: `x=50..1544` (7 px inset left, 43 px overhang right)
- v3.10.3 underline: `x=0..1544` (43 px overhang on both sides)

Files:

- `issue-531-before-after.png`: labeled side-by-side comparison
- `before-v3.10.2.png`, `after-v3.10.3.png`: fixed-coordinate crops
- `before-v3.10.2.pdf`, `after-v3.10.3.pdf`: original compiled PDFs
- `issue-531-mwe.tex`: shared source
