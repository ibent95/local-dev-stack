@echo off
REM Run a code-review-graph scan and export the interactive graph for the viewer.
REM   lds tools crg <path> [<name>]   default path = current directory; name
REM                                   defaults to the folder's basename.
REM   lds tools crg clear             remove all reports.
REM Results -> data\crg\reports\<name>\index.html, viewed at http://crg.test/<name>/
setlocal enabledelayedexpansion
set "TARGET=%~1"
set "NAME=%~2"
if /I "%TARGET%"=="clear" (
  pushd "%~dp0..\.."
  set "REPORTS=%CD%\data\crg\reports"
  if exist "!REPORTS!" rmdir /s /q "!REPORTS!"
  echo Cleared !REPORTS!
  popd
  endlocal & exit /b 0
)
if not defined TARGET set "TARGET=%CD%"
REM Resolve TARGET to an ABSOLUTE path against the caller's cwd BEFORE we pushd
REM to the project root (docker -v needs an absolute source).
for %%I in ("%TARGET%") do set "TARGET=%%~fI"
if not exist "%TARGET%" (
  echo Target not found: %TARGET%
  echo Pass a path to scan, e.g.  lds tools crg D:\projects\PHP\svc-setting-lumen
  endlocal & exit /b 1
)
if not defined NAME for %%I in ("%TARGET%") do set "NAME=%%~nI"
set "NAME=%NAME: =_%"
pushd "%~dp0..\.."
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%CRG_VERSION%"=="" set "CRG_VERSION=2.3.7"
if "%CRG_HOST%"==""    set "CRG_HOST=crg.test"
set "IMAGE=lds/crg:%CRG_VERSION%"
set "REPORTS=%CD%\data\crg\reports"

REM Build the scanner image once (upstream ships no official image).
docker image inspect "%IMAGE%" >nul 2>&1 || (
  echo Building %IMAGE% ^(first use^)...
  docker build -q -t "%IMAGE%" "%CD%\configs\crg"
)

echo Building the code graph for %TARGET% (container %IMAGE%)...
docker run --rm -v "%TARGET%:/src" -w /src %IMAGE% build
docker run --rm -v "%TARGET%:/src" -w /src %IMAGE% visualize

set "OUTDIR=%REPORTS%\%NAME%"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
if exist "%TARGET%\.code-review-graph\graph.html" (
  copy /y "%TARGET%\.code-review-graph\graph.html" "%OUTDIR%\index.html" >nul
  echo Wrote %OUTDIR%\index.html
  echo View at http://%CRG_HOST%/%NAME%/  ^(run 'lds up crg' if the viewer isn't running^).
) else (
  echo No graph.html produced - the scan did not complete. Re-run against a valid git repo.
  popd
  endlocal & exit /b 1
)
popd
endlocal
