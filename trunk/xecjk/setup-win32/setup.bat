%systemroot%\system32\cmd.exe /V:ON /C getversion.bat
call setversion.bat

goto %texversion%

:texlive

set texmfhomename=TEXMFHOME
set tempa=
for /F "usebackq delims=" %%i in (`kpsewhich --expand-var=$TEXMFHOME`) do set tempa=%%i
if "%tempa%A" == "A" goto errortexmfhome

set tempb=%tempa:~1,1%
if not "%tempb%A" == ":A" goto errortexmfhome

set texmfhome=%tempa:/=\%
set localtexmf=%texmfhome%

if not exist "%localtexmf%" md "%localtexmf%"
if not exist "%localtexmf%" goto errortexmfhome
set texhashcmd=texhash "%localtexmf%"

goto copyfiles

:miktex
set texmfhomename=COMMON-DATA
set tempa=
For /F "usebackq delims=" %%i IN (`findtexmf psfonts_t1.map`) DO set tempa=%%i
if "%tempa%A" == "A" goto errortexmfhome

set localtexmf=%tempa:\dvips\config\psfonts_t1.map=%
set texhashcmd=initexmf --update-fndb="%localtexmf%"
:copyfiles
echo off

echo ***************************************************************
echo *
echo *
echo *
echo *
echo *     This will install the xeCJK package to "%localtexmf%"
echo *
echo *     texversion=%texversion%
echo *
echo *
echo *
echo *
echo ***************************************************************
echo on
pause
if not exist "%localtexmf%\source" md "%localtexmf%\source"
if not exist "%localtexmf%\tex" md "%localtexmf%\tex"
if not exist "%localtexmf%\tex\xelatex" md "%localtexmf%\tex\xelatex"
if not exist "%localtexmf%\tex\xelatex\xecjk" md "%localtexmf%\tex\xelatex\xecjk"
if not exist "%localtexmf%\doc" md "%localtexmf%\doc"

xcopy   ..\source\*.* "%localtexmf%\source" /s /y
copy    ..\tex\xelatex\xecjk\xeCJK.sty "%localtexmf%\tex\xelatex\xecjk\xeCJK.sty"   /y
copy    ..\tex\xelatex\xecjk\ctex4xetex.cfg "%localtexmf%\tex\xelatex\xecjk\ctex4xetex.cfg"   /y
if not exist "%localtexmf%\tex\xelatex\xecjk\xeCJKpunct.spa" copy ..\tex\xelatex\xecjk\xeCJKpunct.spa "%localtexmf%\tex\xelatex\xecjk\xeCJKpunct.spa"
xcopy   ..\doc\*.* "%localtexmf%\doc" /s /y
%texhashcmd%
goto end


:errortexmfhome
echo off
echo ***************************************************************
echo *
echo *
echo *
echo *
echo *  ERROR!
echo *
echo *
echo *      texversion=%texversion%
echo *
echo *      %texmfhomename%="%tempa%"
echo *
echo *
echo *
echo *
echo ***************************************************************

echo on

:end
pause
