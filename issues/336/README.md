# Issue 336 reproduction

Tested with `ctex-kit` master `0aefee06`, XeTeX from TeX Live 2026, Biber
2.21, and Noto Serif CJK SC.

The examples use the original `biblatex` `urlraw` approach.

## General Unicode route

Source: `unicode-urlraw.tex`, with the original Cyrillic URL in
`unicode-urlraw.bib`.  Biber emits a percent-encoded `url` for the clickable
target and an unencoded `urlraw` for the printed label.  The screenshot shows
the readable Cyrillic label produced by XeLaTeX.  `pdfinfo -url` confirms that
the PDF annotation still contains the percent-encoded target; the log has no
overfull/underfull box or missing-character diagnostic.

## Route A: `CJKmath` and `\nolinkurl`

Source: `cjkmath-urlraw.tex`.  The decoded CJK URL is displayed without any
custom character class.  Its deliberately long continuous CJK portion cannot
break; the log reports `Overfull \hbox (192.2829pt too wide)`.  This is the
known limitation accepted in the 2018 discussion.

## Route B: external slash class

Source: `external-class-urlraw.tex`.  The example allocates an external class
and defines only `slash -> Default` as `\URLBreakAction`; it does not call any
xeCJK internal command.  In the document body, `/学` exercises only the
automatically derived `slash -> CJK` transition.  The green `PASS` proves that
the user action propagated through xeCJK's existing `Others` compatibility
layer.  The long URL then breaks normally inside its CJK portion, with no
overfull/underfull box or missing-character diagnostic.

## Build

Run XeLaTeX, Biber, then XeLaTeX twice for each `.tex` file.  For the CJK
examples, ensure the local xeCJK under test is selected through `TEXINPUTS`,
and that `issue-336.bib` is visible through `BIBINPUTS`.
