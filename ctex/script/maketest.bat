if exist flat rmdir /s/q flat

mkdir flat

for %%i in (..\ctex.sty ..\ctexart.cls ..\ctexbook.cls ..\ctexrep.cls) do copy "%%i" flat

for %%i in (..\back\ctexcap.sty ..\back\ctexartutf8.cls ..\back\ctexbookutf8.cls ..\back\ctexcaputf8.sty ..\back\ctexreputf8.cls ..\back\ctexutf8.sty) do copy "%%i" flat

for %%i in (..\cfg\ctex.cfg ..\cfg\ctexcap-gbk.cfg ..\cfg\ctexcap-utf8.cfg ..\cfg\ctexcap.cfg ..\cfg\ctexopts.cfg.template) do copy "%%i" flat

for %%i in (..\def\ctex-article.def ..\def\ctex-book.def ..\def\ctex-caption.def ..\def\ctex-common.def ..\def\ctex-fontsize.def ..\def\ctex-report.def ..\def\ctex-options.def) do copy "%%i" flat

for %%i in (..\engine\ctex-cct-engine.def ..\engine\ctex-cjk-common.def ..\engine\ctex-cjk-engine.def ..\engine\ctex-xecjk-engine.def ..\engine\ctex-luacjk-engine.def ..\engine\jfm-banjiao.lua ..\engine\jfm-CCT.lua ..\engine\jfm-kaiming.lua ..\engine\jfm-plain.lua ..\engine\jfm-quanjiao.lua) do copy "%%i" flat

for %%i in (..\fd\c19gbsn.fd ..\fd\c19gbsn.fdx ..\fd\c19gkai.fd ..\fd\c19gkai.fdx ..\fd\c19rm.fd ..\fd\c19sf.fd ..\fd\c19tt.fd ..\fd\c70rm.fd ..\fd\c70sf.fd ..\fd\c70tt.fd) do copy "%%i" flat

for %%i in (..\fontset\ctex-fontset-adobe.def ..\fontset\ctex-fontset-mac.def ..\fontset\ctex-fontset-windows.def) do copy "%%i" flat

for %%i in (..\doc\ctex.pdf ..\doc\ctex.tex ..\README) do copy "%%i" flat

for %%i in (..\test\test-cjk.tex ..\test\test-cjkutf8.tex ..\test\test-xetex.tex ..\test\test-xetexgbk.tex) do copy "%%i" flat

cd flat
xelatex test-xetex
xelatex test-xetexgbk
pdflatex test-cjkutf8
latex test-cjk
dvipdfmx test-cjk
