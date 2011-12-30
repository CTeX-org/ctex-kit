if exist texmf rmdir /s/q .\texmf
if exist ctex-tds.zip del ctex-tds.zip

mkdir texmf\tex\latex\ctex
for %%i in (..\ctex.sty ..\ctexart.cls ..\ctexbook.cls ..\ctexcap.sty ..\ctexrep.cls) do copy "%%i" texmf\tex\latex\ctex

mkdir texmf\tex\latex\ctex\back
for %%i in (..\back\ctexartutf8.cls ..\back\ctexbookutf8.cls ..\back\ctexcaputf8.sty ..\back\ctexreputf8.cls ..\back\ctexutf8.sty) do copy "%%i" texmf\tex\latex\ctex\back

mkdir texmf\tex\latex\ctex\cfg
for %%i in (..\cfg\ctex.cfg ..\cfg\ctexcap-gbk.cfg ..\cfg\ctexcap-utf8.cfg ..\cfg\ctexcap.cfg ..\cfg\ctexopts.cfg.template) do copy "%%i" texmf\tex\latex\ctex\cfg

mkdir texmf\tex\latex\ctex\def
for %%i in (..\def\ctex-article.def ..\def\ctex-book.def ..\def\ctex-caption.def ..\def\ctex-class.def ..\def\ctex-common.def ..\def\ctex-gbk.def ..\def\ctex-loadclass.def ..\def\ctex-report.def ..\def\ctex-utf8.def) do copy "%%i" texmf\tex\latex\ctex\def

mkdir texmf\tex\latex\ctex\engine
for %%i in (..\engine\ctex-cct-engine.def ..\engine\ctex-cjk-common.def ..\engine\ctex-cjk-engine.def ..\engine\ctex-xecjk-engine.def) do copy "%%i" texmf\tex\latex\ctex\engine

mkdir texmf\tex\latex\ctex\fd
for %%i in (..\fd\c19gbsn.fd ..\fd\c19gbsn.fdx ..\fd\c19gkai.fd ..\fd\c19gkai.fdx ..\fd\c19rm.fd ..\fd\c19sf.fd ..\fd\c19tt.fd ..\fd\c70rm.fd ..\fd\c70sf.fd ..\fd\c70tt.fd) do copy "%%i" texmf\tex\latex\ctex\fd

mkdir texmf\tex\latex\ctex\fontset
for %%i in (..\fontset\ctex-cjk-adobefonts.def ..\fontset\ctex-cjk-winfonts.def ..\fontset\ctex-xecjk-adobefonts.def ..\fontset\ctex-xecjk-winfonts.def ..\fontset\ctex-xecjk-macfonts.def) do copy "%%i" texmf\tex\latex\ctex\fontset

mkdir texmf\tex\latex\ctex\opt
for %%i in (..\opt\ctex-caption-opts.def ..\opt\ctex-class-opts.def ..\opt\ctex-common-opts.def) do copy "%%i" texmf\tex\latex\ctex\opt


mkdir texmf\doc\latex\ctex
for %%i in (..\doc\ctex.pdf ..\doc\ctex.tex ..\README) do copy "%%i" texmf\doc\latex\ctex

mkdir texmf\doc\latex\ctex\test
for %%i in (..\test\test-cjk.tex ..\test\test-cjkutf8.tex ..\test\test-xetex.tex ..\test\test-xetexgbk.tex) do copy "%%i" texmf\doc\latex\ctex\test

zip -r ctex-tds.zip texmf\*
