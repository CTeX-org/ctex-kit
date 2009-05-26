@echo off
latex ctex-faq.tex
makeindex -o ctex-faq.ind ctex-faq.idx
latex ctex-faq.tex
makeindex -o ctex-faq.ind ctex-faq.idx
latex ctex-faq.tex
latex ctex-faq.tex
dvipdfmx ctex-faq.dvi
del *.aux
del *.toc
del *.lon
del *.lor
del *.ilg
del *.idx
del *.ind
del *.out
del *.log
del *.exa
@echo on
pause
