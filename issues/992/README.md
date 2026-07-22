# xeCJK command-boundary matrix

Assets for [CTeX-org/ctex-kit#992](https://github.com/CTeX-org/ctex-kit/issues/992).

## `xCJKecglue` 双值矩阵（2026-07-21）

状态表现在分别记录 `xCJKecglue=false` 和 `true`。四个测试组
（core、links、verb、biblatex）各有默认间距与可区分间距两个入口，
合计 16 次编译。每个选项值包含 80 个场景、四种源码空格，共 320 个
单元；候选与直接输入始终使用相同的 `xCJKecglue` 设置。

- `false`：默认间距和可区分间距均为 320／320 通过；
- `true`：初次审计时默认间距为 318／320 通过，可区分间距为
  312／320 通过；PR #1005 合并后，两种设置均为 320／320 通过。

精确失败单元见 [`xecglue-matrix-summary.txt`](./xecglue-matrix-summary.txt)。
行内公式改用 #1002 决定的直接公式基准，不计入上述普通命令矩阵；
PR #1009 合并后，公式矩阵已迁入本目录并纳入 #992 活表。
The initial audit was prepared against master commit
4628cb443978d5507de61eaa70e520e31f926707 on 2026-07-18.

The unified boundary-recovery prototype was rerun at implementation commit
5338c5f99e4f3f34bb83e51131dc40a12e5ef134 on 2026-07-20. All 280 matrix
cells pass with package defaults, and the same 280 cells pass again with
CJKecglue=5pt and CJKglue=1pt. The living status-table showcases below were
regenerated from that prototype; matrix-verdicts.tsv remains the initial
v3.10.3 audit snapshot.

PR #999 was rebase-merged into master on 2026-07-20. The post-merge
reverification at master commit cb6b2f7371a86cf74d76a92bea6b9db01005e33c
reran all eight drivers (core/links/verb/biblatex, default and
distinguishing glue): 280/280 cells pass, 0 FAIL lines. Rows 27-29 of the
living table (#996/#998, assets under issues/996/ and issues/998/) were
reverified from the same commit and remain open.

## Visual MWE

- oracle-ref-mwe.tex compares direct-input oracles with kernel \ref output for
  all four source-space combinations, with Western/numeric output between CJK
  text and CJK output between both Western and CJK text. It deliberately uses
  CJKecglue=5pt and CJKglue=1pt so missing glue cannot be hidden by defaults.
  Its source column is scanned directly with \verb*, so visible source spaces
  are not reconstructed or widened by xeCJK itself.
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

## biblatex write-whatsit matrix

- command-boundary-biblatex-matrix.tex stubs biblatex's \blx@pagetracker
  with the same \protected@write whatsit shape biblatex emits (identical
  to xeCJK/testfiles/biblatex-ecglue01.lvt), so xeCJK installs its #931
  patch at begindocument. command-boundary-biblatex-custom.tex supplies
  distinguishing glue values. Only the tracker-before-entry position is
  audited: a control word gobbles following source spaces, so the
  after-content 01/11 cells are not expressible with this stub.

## Per-command showcase renders

- showcase-lib.tex is the shared rendering harness: same \MatrixReset
  isolation and intrinsic-width subtraction as the audit matrices, but
  each cell renders framed oracle/candidate boxes with a red delta.
  All showcase documents use the distinguishing glue values.
- showcase-core.tex, showcase-links.tex, showcase-verb.tex,
  showcase-biblatex.tex, and showcase-followups.tex produce one page per
  command row. The follow-up file covers the merged fixes for #996, #998,
  and #1000 with the same table layout as the original rows.
- showcase/<row>.png are the cropped per-command images embedded in the
  living status table (first comment of #992). Individual images are refreshed
  as fixes merge; the current set was regenerated from the unified prototype
  commit 5338c5f9 and shows all audited cells matching their direct-input
  oracle.
- matrix-verdicts.tsv is the initial-audit snapshot, not the living table. A
  cell passes only if it passed under BOTH default and distinguishing glue
  values when compiled with xeCJK unpacked from master
  4628cb443978d5507de61eaa70e520e31f926707.

## 行内公式矩阵（PR #1009 合并后）

以下四个文件都是可以直接编译的入口，不以目录或 README 代替 MWE：

- `command-boundary-math-matrix.tex`：`xCJKecglue=false`、默认间距；
- `command-boundary-math-false-custom.tex`：`xCJKecglue=false`、
  `CJKecglue=5pt` / `CJKglue=1pt`；
- `command-boundary-math-true-default.tex`：`xCJKecglue=true`、默认间距；
- `command-boundary-math-true-custom.tex`：`xCJKecglue=true`、
  `CJKecglue=5pt` / `CJKglue=1pt`。

每个入口覆盖 17 种候选、四种周边文字和四种源码空格，共 272 个单元。
2026-07-22 从 PR #1009 合并后的 `master` `1b77613b` 重新解包 xeCJK 并
分别编译四个入口，结果均为 272／272 通过。

`showcase-math.tex` 和 `showcase-math-true.tex` 是两种 `xCJKecglue`
设置下的具体 show-case 源文件；`showcase/*-math.png` 将同一候选的两页
上下合并，展示四种周边文字和 `00`、`10`、`01`、`11`。这些图片也从
`1b77613b` 重新生成，全部单元均与直接 `$x$` 相同。

#992 原编号 28 的 `\mbox{$x$}` 已并入编号 7 的四个公式列。编号 28
不再复用，以免旧讨论中的行号指向另一个场景。`\(x\)` 和
`\ensuremath{x}` 保留为独立候选行，因为它们没有可以填写普通内容三列的
对应项。

## Driver updates (2026-07-20, digit contexts)

- All eight drivers and showcase-lib now guard the v3.10.3-only
  `\g__xeCJK_reset_color_pending_bool` reset behind `\bool_if_exist:NT`,
  so the same driver sources run on both v3.10.3 and post-#999 masters.
- command-boundary-core-matrix.tex gains ten rows covering digit output
  between CJK and between Latin contexts (中数中 / 西数西: macro and
  \mbox with 3.14), plus \mbox{$x$}, \mbox{$1$} and \mbox{\vrule ...}
  rows for #998 in both contexts (52 rows, 208 cells per glue mode).
  On the fix branch for #996/#998/#1000 (commit a1df81ef) both glue
  modes report 208/208 PASS; the living-table refresh happens after the
  fix PR merges, per the preview/merged layering convention.

## Post-merge refresh for PR #1001 (2026-07-21)

- Master commit 10500b33 was unpacked and used for a fresh run of all eight
  core drivers: 320/320 cells pass with package defaults and 320/320 cells
  pass with CJKecglue=5pt and CJKglue=1pt.
- The #996 MWE reports FIRST=30.0pt, SECOND=30.0pt, and DELTA=0.0pt. The
  #998 matrix reports 32/32 PASS, and the #1000 matrix reports 36/36 PASS.
- showcase-followups.tex generates the four matching living-table images:
  showcase/crossbox-hskip.png, showcase/mbox-math.png,
  showcase/mbox-rule.png, and showcase/siunitx.png. These replace the wider
  PR before/after composites previously used in rows 27--30.

## Post-merge refresh for PR #1005 (2026-07-21)

- Rebase-merged master commit 8007e4df was unpacked before rerunning all 16
  drivers: core, links, verb, and biblatex, each with
  `xCJKecglue=false/true` and package-default/distinguishing glue values.
- Each of the four configurations reports 320/320 ordinary command cells
  passing, with no `MATRIX|...|FAIL|` lines. The four inline-math cells
  tracked by #1002 remain outside that ordinary-command total.
- The merged commit regenerated `mbox-xecglue-true.png`,
  `fbox-xecglue-true.png`, and `post-null-xecglue-true.png`; all cells shown
  in these living-table images now match their direct-input oracles.
