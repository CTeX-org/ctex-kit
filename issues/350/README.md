# Issue #350 assets

这些文件用于说明 ctex 的标准名称键与 biblatex locale strings 的所有权边界。

## 文件

- lifecycle.svg / lifecycle.png：时序、语言切换与公开接口的示意图。
- baseline.tex：ctex 在加载期设置 bibname 后，原生 biblatex 默认标题仍为
  Bibliography 的最小复现。
- title.tex：单次标题应使用 printbibliography 的 title 选项。
- strings.tex：默认标题应使用 DefineBibliographyStrings 的 locale 接口。
- references.bib：三个 MWE 共用的最小 bibliography 数据。
- comparison.png：上述三个 MWE 的 XeLaTeX + Biber 实测输出拼图。

## 编译

~~~sh
xelatex <file>
biber <file>
xelatex <file>
xelatex <file>
~~~

生成图时使用 ctex 2.6.3 的当前解包产物、biblatex 3.21、XeLaTeX 与 Biber 2.21。
