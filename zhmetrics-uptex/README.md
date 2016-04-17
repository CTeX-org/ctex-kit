# zhmetrics-uptex: Chinese Font Metrics for upTeX

## Files

* `upzh*-{h,v}.tfm` are the JFM files used for upTeX.
* `upzh*-{h,v}.vf` are the virtual fonts used for output driver (dvipdfmx).
* `up*-{h,v}.tfm` are the PS TFM files used for output driver.
* `upzhwinfonts.tex` contains the font mappings for Simplified Chinese version of Windows 8+.
* `upzhwinfonts-test.tex` is a small LaTeX test file.

## Build

Run:

`texlua buld.lua`