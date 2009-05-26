set texversion=
for /F "usebackq delims=" %%i in (`tex --version`) do set texversion=!texversion!%%i
set texversion=%texversion:~0,3%
goto %texversion%

:mik
echo set texversion=miktex>setversion.bat
goto end

:tex
echo set texversion=texlive>setversion.bat

:end
