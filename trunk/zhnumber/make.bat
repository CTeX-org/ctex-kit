@echo off

  if not "%1" == "" goto :init

:help

  echo.
  echo  make clean        - delete all generated files
  echo  make ctan         - create an archive ready for CTAN
  echo  make doc          - typesets documentation
  echo  make localinstall - install files in $TEXMFLOCAL
  echo  make tds          - create a TDS-ready archive
  echo  make unpack       - extract packages
  echo  make checksum     - Correction of "\CheckSum{...}" entry in .dtx

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
  set CTANFILES=ins dtx pdf
  set TDSFILES=%CTANFILES% cfg sty
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
  if /i "%1" == "checksum"     goto :checksum

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

  call :unpack
  
  call :checksum

  echo Typesetting %SOURCE%

  %DTXTEX% %DTXTEXFLAG% -interaction=batchmode -no-pdf %SOURCE% > nul
  if ERRORLEVEL 1 (
    echo ! Compilation failed
    goto :end
  ) else (
    if exist %PACKAGE%.glo ( makeindex -q -s gglo.ist -o %PACKAGE%.gls %PACKAGE%.glo > nul )
    if exist %PACKAGE%.idx ( makeindex -q -s gind.ist -o %PACKAGE%.ind %PACKAGE%.idx > nul )
    echo   Re-typesetting for index generation
    %DTXTEX% %DTXTEXFLAG% -interaction=batchmode -no-pdf %SOURCE% > nul
    if exist %PACKAGE%.glo ( makeindex -q -s gglo.ist -o %PACKAGE%.gls %PACKAGE%.glo > nul )
    if exist %PACKAGE%.idx ( makeindex -q -s gind.ist -o %PACKAGE%.ind %PACKAGE%.idx > nul )
    echo   Re-typesetting to resolve cross-references
    %DTXTEX% %DTXTEXFLAG% -interaction=batchmode %SOURCE% > nul 
	goto :clean-aux
  )

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

:checksum

  call :perl

  if [%PERLEXE%] == [""] goto :end
  
  %PERLEXE% adjust_checksum.pl %SOURCE%

  goto :end
 
:perl

  if defined PERLEXE (
    goto :EOF
  ) else (
    set PERLEXE =""
  )
  
  for %%I in (perl.exe) do (
    if exist %%I (
	  set PERLEXE="%~dp0%%I"
	) else (
	  set PERLEXE="%%~$PATH:I"
	)
  )
  
  if not [%PERLEXE%] == [""] goto :EOF
  
  for /f "delims=" %%I in ('kpsewhich --var-value=TEXMFROOT') do @set TEXMFROOT=%%I

  if exist "%TEXMFROOT%\tlpkg\tlperl\bin\perl.exe" (
	set PERLEXE="%TEXMFROOT%\tlpkg\tlperl\bin\perl.exe"
	goto :EOF
  )

  echo.
  echo This procedure requires a perl program,
  echo but one could not be found.
  echo.

:zip 

  if not defined ZIPFLAG set ZIPFLAG=-r -q -X -ll

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

  if not [%ZIPEXE%] == [""] goto :EOF
  
  echo.
  echo This procedure requires a zip program,
  echo but one could not be found.
  echo.

  exit /b 1

:iconv

  if defined ICONVEXE (
    goto :EOF
  ) else (
    set ICONVEXE=""
  )
  
  for %%I in (iconv.exe) do (
    if exist %%I (
	  set ICONVEXE="%~dp0%%I"
	) else (
	  set ICONVEXE="%%~$PATH:I"
	)
  )
  
  if not [%ICONVEXE%] == [""] goto :EOF
  
  echo.
  echo This procedure requires a iconv program,
  echo but one could not be found.
  echo.
  
  exit /b 1

:end

  shift
  if not "%1" == "" goto :main
 