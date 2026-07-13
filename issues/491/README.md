# Issue 491 visual regression evidence

These assets accompany the long-running xeCJK command-boundary tracking issue.
Each `*-mwe.tex` file is a standalone visual diagnostic: it frames the natural
width of a reference and a command-boundary case and prints the measured delta.

The images were produced by compiling the same source against unpacked tagged
versions of xeCJK, selected through `TEXINPUTS`:

    git worktree add /tmp/xeCJK-v3.9.1 xeCJK-v3.9.1
    (cd /tmp/xeCJK-v3.9.1/xeCJK && l3build unpack)
    TEXINPUTS=/tmp/xeCJK-v3.9.1/xeCJK/build/unpacked: xelatex font-color-mwe.tex

Comparisons:

- `font-color-mwe.tex`: xeCJK v3.9.1 → v3.10.0
- `boundary-hyperref-mwe.tex`: xeCJK v3.9.1 → v3.10.0
- `fntef-mwe.tex`: xeCJK v3.9.1 → v3.10.0
- `doc-url-verb-mwe.tex`: xeCJK v3.9.1 → v3.10.2
- `biblatex-write-mwe.tex`: xeCJK v3.10.0 → v3.10.1

The standalone MWE and screenshots are discussion evidence. The corresponding
`.lvt` files on the main branch remain the authoritative automated regression
tests.
