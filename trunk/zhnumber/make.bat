@echo off

  if not "%1" == "" goto :init

:help

  echo.
  echo  make clean        - delete all generated files
  echo  make ctan         - create an archive ready for CTAN
  echo  make doc          - typesets documentation
  echo  make localinstall - extract packages
  echo  make tds          - create a TDS-ready archive
  echo  make unpack       - extract packages

  goto :EOF

:init

  setlocal
  set PACKAGE=zhnumber
  set PKGDIR=%PACKAGE%
  set FORMAT=latex
  set DTXTEX=xelatex
  set DTXTEXFLAG=-shell-escape
  set INSTEX=xetex
  set INSTEXFLAG=-shell-escape
  set SOURCE=%PACKAGE%.dtx
  set UNPACK=%SOURCE%
  set TXT=README
  set AUXFILES=aux bbl blg cmds dvi glo gls hd idx ilg ind ist log los out tmp toc xdv
  set CLEAN=bib bst cfg cls eps gz ins pdf sty tex txt tds.zip
  set CTANFILES=dtx pdf
  set TDSFILES=%CTANFILES% ins cfg sty
  set CTANROOT=ctan
  set CTANDIR=%CTANROOT%\%PKGDIR%
  set TDSROOT=tds

  cd /d "%~dp0"
  call :iconv

:main

  if /i "%1" == "clean"        goto :clean
  if /i "%1" == "ctan"         goto :ctan
  if /i "%1" == "doc"          goto :doc
  if /i "%1" == "help"         goto :help
  if /i "%1" == "localinstall"  goto :localinstall
  if /i "%1" == "tds"          goto :tds
  if /i "%1" == "unpack"       goto :unpack

  goto :help

:clean

  echo.
  echo Deleting files

  for %%I in (%CLEAN%) do (
    if exist *.%%I del /q *.%%I
  )

:clean-aux

  for %%I in (%AUXFILES%) do (
    if exist *.%%I del /q *.%%I
  )

  goto :end

:ctan

  call :tds
  if errorlevel 1 goto :EOF

  for %%I in (%SOURCE%) do (
    xcopy /q /y %%I "%CTANDIR%\" > nul
  )  
  for %%I in (%CTANFILES%) do (
    xcopy /q /y *.%%I "%CTANDIR%\" > nul
  )
  for %%I in (%TXT%) do (
    xcopy /q /y %%I.txt "%CTANDIR%\" > nul
    ren "%CTANDIR%\%%I.txt" %%I
  )

  xcopy /q /y %PKGDIR%.tds.zip "%CTANROOT%\" > nul

  pushd "%CTANROOT%"
  %ZIPEXE% %ZIPFLAG% %PKGDIR%.zip .
  popd
  copy /y "%CTANROOT%\%PKGDIR%.zip" > nul

  rmdir /s /q %CTANROOT%

  goto :end

:doc 

  if not [%SOURCE%] == [%UNPACK%] call :unpack

  echo Typesetting %SOURCE%

  %DTXTEX% %DTXTEXFLAG% -interaction=nonstopmode -no-pdf %SOURCE% > nul
  if ERRORLEVEL 1 (
    echo ! Compilation failed
  ) else (
    if exist %PACKAGE%.glo ( makeindex -q -s gglo.ist -o %PACKAGE%.gls %PACKAGE%.glo > nul )
    if exist %PACKAGE%.idx ( makeindex -q -s l3doc.ist -o %PACKAGE%.ind %PACKAGE%.idx > nul )
    echo   Re-typesetting for index generation
    %DTXTEX% %DTXTEXFLAG% -interaction=nonstopmode -no-pdf %SOURCE% > nul
    if exist %PACKAGE%.glo ( makeindex -q -s gglo.ist -o %PACKAGE%.gls %PACKAGE%.glo > nul )
    if exist %PACKAGE%.idx ( makeindex -q -s l3doc.ist -o %PACKAGE%.ind %PACKAGE%.idx > nul )
    echo   Re-typesetting to resolve cross-references
    %DTXTEX% %DTXTEXFLAG% -interaction=nonstopmode %SOURCE% > nul 
  )

  goto :clean-aux

:file2tdsdir

  set TDSDIR=

  if /i "%~x1" == ".cfg" set TDSDIR=tex\%FORMAT%\%PKGDIR%\config
  if /i "%~x1" == ".dtx" set TDSDIR=source\%FORMAT%\%PKGDIR%
  if /i "%~x1" == ".ins" set TDSDIR=source\%FORMAT%\%PKGDIR%
  if /i "%~x1" == ".pdf" set TDSDIR=doc\%FORMAT%\%PKGDIR%
  if /i "%~x1" == ".sty" set TDSDIR=tex\%FORMAT%\%PKGDIR%
  if /i "%~x1" == ".tex" set TDSDIR=doc\%FORMAT%\%PKGDIR%\example  
  if /i "%~x1" == ".txt" set TDSDIR=doc\%FORMAT%\%PKGDIR%

  goto :EOF

:localinstall

  if not exist %PACKAGE%.pdf call :doc
  echo.
  echo Installing %PACKAGE%

  if not defined TEXMFLOCAL (
    for /f "delims=" %%I in ('kpsewhich --var-value=TEXMFLOCAL') do @set TEXMFLOCAL=%%I
  )
  if [%TEXMFLOCAL%] == [] (
    echo ! Install failed
  ) else (
	for %%I in (%TDSFILES%) do ( call :localinstall-int *.%%I )
  )

  goto :end

:localinstall-int

  call :file2tdsdir %1

  if defined TDSDIR (
    xcopy /q /y %1 "%TEXMFLOCAL%\%TDSDIR%\" > nul
  ) else (
    echo Unknown file type "%~x1"
  )

  goto :EOF

:tds

  call :zip
  if errorlevel 1 goto :EOF

  call :doc
  if errorlevel 1 goto :EOF

  echo.
  echo Creating archive

  for %%I in (%SOURCE%) do (
    call :tds-int %%I
  )
  for %%I in (%TDSFILES%) do (
    call :tds-int *.%%I
  )
  for %%I in (%TXT%) do (
    xcopy /q /y %%I.txt "%TDSROOT%\doc\%FORMAT%\%PKGDIR%\" > nul
    ren "%TDSROOT%\doc\%FORMAT%\%PKGDIR%\%%I.txt" %%I
  )

  pushd "%TDSROOT%"
  %ZIPEXE% %ZIPFLAG% %PKGDIR%.tds.zip .
  popd
  copy /y "%TDSROOT%\%PKGDIR%.tds.zip" > nul

  rmdir /s /q "%TDSROOT%"

  goto :end

:tds-int

  call :file2tdsdir %1

  if defined TDSDIR (
    xcopy /q /y %1 "%TDSROOT%\%TDSDIR%\" > nul
  ) else (
    echo Unknown file type "%~x1"
  )

  goto :EOF

:unpack

  echo.
  echo Unpacking files

  for %%I in (%UNPACK%) do (
    %INSTEX% %INSTEXFLAG% %%I > nul
  )

  goto :end

:zip 

  if not defined ZIPFLAG set ZIPFLAG=-r -q -X

  if defined ZIPEXE (
    goto :EOF
  ) else (
    set ZIPEXE =""
  )
  
  for %%I in (zip.exe) do (
    if exist %%I (
	  set ZIPEXE="%~dp0%%I"
	) else (
	  set ZIPEXE="%%~$PATH:I"
	)
  )

  if [%ZIPEXE%] == [""] (
    echo.
    echo This procedure requires a zip program,
    echo but one could not be found.
    echo.
  )

  goto :EOF

:iconv

  if defined ICONVEXE set ICONVEXE=""
  
  for %%I in (iconv.exe) do (
    if exist %%I (
	  set ICONVEXE="%~dp0%%I"
	) else (
	  set ICONVEXE="%%~$PATH:I"
	)
  )
  
  if [%ICONVEXE%] == [""] (
    echo.
    echo This procedure requires a iconv program,
    echo but one could not be found.
    echo.
  )
  
  goto :EOF

:end

  shift
  if not "%1" == "" goto :main