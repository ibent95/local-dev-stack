@echo off
REM Run a Semgrep scan and write SARIF for the viewer.  (lds tools semgrep [path])
REM   default path = current directory. Results -> configs\semgrep\reports\report.sarif,
REM   viewed at http://semgrep.test (start the viewer: lds up semgrep).
setlocal enabledelayedexpansion
set "TARGET=%~1"
if not defined TARGET set "TARGET=%CD%"
REM Resolve TARGET to an ABSOLUTE path against the caller's cwd BEFORE we pushd to
REM the project root. docker -v needs an absolute source; a relative '.\x' would
REM otherwise resolve against the project root after pushd and mount an empty dir
REM (Semgrep: "Detected Docker environment without a code volume").
for %%I in ("%TARGET%") do set "TARGET=%%~fI"
if not exist "%TARGET%" (
  echo Target not found: %TARGET%
  echo Pass a path to scan, e.g.  lds tools semgrep D:\projects\PHP\svc-setting-lumen
  endlocal & exit /b 1
)
pushd "%~dp0..\.."
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%SEMGREP_IMAGE%"==""  set "SEMGREP_IMAGE=semgrep/semgrep"
if "%SEMGREP_VERSION%"=="" set "SEMGREP_VERSION=1.167.0"
if "%SEMGREP_RULES%"==""  set "SEMGREP_RULES=p/default"
REM `auto` REQUIRES telemetry (uploads project metadata to pick rules); other
REM configs work with metrics OFF (preferred — metrics-on's end-of-run upload
REM hangs on slow/offline links). Metrics off by default; on only for auto.
set "SEMGREP_METRICS=off"
if /I "%SEMGREP_RULES%"=="auto" set "SEMGREP_METRICS=on"
if "%SEMGREP_HOST%"==""   set "SEMGREP_HOST=semgrep.test"
set "REPORTS=%CD%\configs\semgrep\reports"
if not exist "%REPORTS%" mkdir "%REPORTS%"

REM Run the SAME pinned image as the `semgrep-scan` compose service (declared
REM there + pre-pulled by `lds up semgrep`). We use `docker run` rather than
REM `docker compose run`: Compose's -v parser splits on ':' and chokes on a
REM Windows drive-letter source (D:\...), leaving /src empty. The docker CLI
REM handles D:\... correctly.
REM Static, unique container name (timestamp + centiseconds) instead of Docker's
REM random name — recognizable in `docker ps` and unique across concurrent runs.
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmssff"') do set "TS=%%i"
set "SCAN_NAME=lds-semgrep-scan-!TS!"
echo Scanning %TARGET% with Semgrep (rules: %SEMGREP_RULES%, metrics: %SEMGREP_METRICS%) - container !SCAN_NAME!...
docker run --rm --name !SCAN_NAME! -v "%TARGET%:/src" -v "%REPORTS%:/out" -w /src ^
  %SEMGREP_IMAGE%:%SEMGREP_VERSION% ^
  semgrep scan --metrics %SEMGREP_METRICS% --config %SEMGREP_RULES% --sarif --output /out/report.sarif

echo Wrote %REPORTS%\report.sarif
echo View at http://%SEMGREP_HOST%  (run 'lds up semgrep' if the viewer isn't running).
popd
endlocal
