# xeCJK command-boundary matrix

Assets for [CTeX-org/ctex-kit#992](https://github.com/CTeX-org/ctex-kit/issues/992).
The audit was prepared against master commit
4628cb443978d5507de61eaa70e520e31f926707 on 2026-07-18.

## Visual MWE

- oracle-ref-mwe.tex compares direct-input oracles with kernel \ref output for
  all four source-space combinations, with Western/numeric output between CJK
  text and CJK output between both Western and CJK text. It deliberately uses
  CJKecglue=5pt and CJKglue=1pt so missing glue cannot be hidden by defaults.
- oracle-ref-matrix.png is the released-v3.10.3 baseline issue image;
  oracle-ref-matrix.pdf is the corresponding vector output.
- oracle-ref-before.png/pdf were compiled with the released xeCJK v3.10.3.
- oracle-ref-after.png/pdf were compiled with the proposed v3.10.4 fix for
  #991 at commit c4a6631d. Every displayed candidate then matches its
  direct-input oracle.
- oracle-ref-before-after.png stacks the two raster images for PR discussion.

## Log-producing audit matrices

- command-boundary-core-matrix.tex is the shared implementation for expansion,
  grouping, font switches, color, boxes, xeCJKfntef, and kernel \ref.
  Compile command-boundary-core-default.tex for package defaults or
  command-boundary-core-custom.tex for distinguishing glue values. Both
  wrappers supply resolved Western and CJK reference records without requiring
  an auxiliary-file pass.
- command-boundary-links-matrix.tex is the default-glue matrix for post-content
  null boxes, hyperlinks, references with hyperref, URLs, and hypdoc commands.
  command-boundary-links-custom.tex runs the same cases with distinguishing
  glue values.
- command-boundary-verb-matrix.tex is the default-glue matrix for
  delimiter-scanning \verb, which cannot be passed through the ordinary test
  macro. command-boundary-verb-custom.tex supplies distinguishing glue values.

Each MATRIX log line compares a command-wrapped candidate against its matching
direct-input oracle after subtracting the command's intrinsic width.

These files are investigation assets, not package regression tests. Stable
regressions should use node-level assertions in xeCJK/testfiles/.
