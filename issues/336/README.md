# Issue 336 reproduction

Tested with `ctex-kit` master `0aefee06`, XeTeX from TeX Live 2026, Biber
2.21, and Noto Serif CJK SC.

Both examples use `issue-336.bib` and the original `biblatex` `urlraw`
approach.

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

Run XeLaTeX, Biber, then XeLaTeX twice for each `.tex` file.  Ensure the local
xeCJK under test is selected through `TEXINPUTS`, and that `issue-336.bib` is
visible through `BIBINPUTS`.
