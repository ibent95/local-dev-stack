@echo off
REM Run a Trivy scan and write an HTML report for the viewer.  (lds tools trivy)
REM   lds tools trivy [path]        fs scan - directory/repo/dependency manifest (default: current dir)
REM   lds tools trivy image <name>  image scan (uses the local docker socket)
REM   lds tools trivy clear         remove the current report + metadata
REM Results -> data\trivy\reports\report.html, viewed at http://trivy.test.
REM
REM Tightening knobs (all optional, set in .env):
REM   TRIVY_SCANNERS=vuln,misconfig,secret,license   what to scan
REM   TRIVY_SEVERITY=MEDIUM,HIGH,CRITICAL            optional severity filter
REM   TRIVY_IGNORE_UNFIXED=1                         only vulns with a fix available
REM   TRIVY_DETECTION_PRIORITY=comprehensive         detect more (more false positives)
REM   TRIVY_EXIT_CODE=1                              exit non-zero on findings (CI gate)
setlocal enabledelayedexpansion
set "MODE=fs"
set "TARGET=%~1"
if /I "%TARGET%"=="clear" (
  pushd "%~dp0..\.."
  set "REPORTS=%CD%\data\trivy\reports"
  if exist "!REPORTS!\report.html" del /q "!REPORTS!\report.html"
  if exist "!REPORTS!\scan-meta.json" del /q "!REPORTS!\scan-meta.json"
  echo Cleared !REPORTS!\report.html and scan metadata.
  popd
  endlocal & exit /b 0
)
if /I "%TARGET%"=="image" (
  set "MODE=image"
  set "TARGET=%~2"
  if not defined TARGET (
    echo usage: lds tools trivy image ^<name^>
    endlocal & exit /b 1
  )
)
if not defined TARGET set "TARGET=%CD%"

pushd "%~dp0..\.."
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%TRIVY_IMAGE%"==""   set "TRIVY_IMAGE=aquasec/trivy"
if "%TRIVY_VERSION%"=="" set "TRIVY_VERSION=0.76.0"
if "%TRIVY_HOST%"==""    set "TRIVY_HOST=trivy.test"
if "%TRIVY_TIMEOUT%"=="" set "TRIVY_TIMEOUT=30m"
if "%TRIVY_SCANNERS%"=="" set "TRIVY_SCANNERS=vuln,misconfig,secret"
if "%TRIVY_IGNORE_UNFIXED%"=="" set "TRIVY_IGNORE_UNFIXED=0"
if "%TRIVY_EXIT_CODE%"=="" set "TRIVY_EXIT_CODE=0"
set "REPORTS=%CD%\data\trivy\reports"
set "CACHE=%CD%\data\trivy\cache"
if not exist "%REPORTS%" mkdir "%REPORTS%"
if not exist "%CACHE%" mkdir "%CACHE%"

REM Assemble the flag list: always-on base flags, then the optional tightening
REM flags (only passed when configured, so an empty .env var = upstream default).
set "FLAGS=--scanners "%TRIVY_SCANNERS%" --timeout "%TRIVY_TIMEOUT%" --exit-code %TRIVY_EXIT_CODE%"
if defined TRIVY_SEVERITY set "FLAGS=!FLAGS! --severity %TRIVY_SEVERITY%"
if defined TRIVY_DETECTION_PRIORITY set "FLAGS=!FLAGS! --detection-priority %TRIVY_DETECTION_PRIORITY%"
if /I "%TRIVY_IGNORE_UNFIXED%"=="1"    set "FLAGS=!FLAGS! --ignore-unfixed"
if /I "%TRIVY_IGNORE_UNFIXED%"=="true" set "FLAGS=!FLAGS! --ignore-unfixed"
if /I "%TRIVY_IGNORE_UNFIXED%"=="yes"  set "FLAGS=!FLAGS! --ignore-unfixed"

REM Run the SAME pinned image as the `trivy-scan` compose service (declared there
REM + pre-pulled by `lds up trivy`). We use `docker run` rather than
REM `docker compose run`: Compose's -v parser splits on ':' and chokes on a
REM Windows drive-letter source (D:\...). The docker CLI handles D:\... correctly.
REM The vulnerability DB is cached in data\trivy\cache (shared with the compose
REM service), so it downloads once, not per scan.
REM With TRIVY_EXIT_CODE set, trivy exits non-zero when findings match - we still
REM write the report + metadata, then decide below (RC is captured, not fatal).
REM Static, unique container name (timestamp + centiseconds) instead of Docker's
REM random name - recognizable in `docker ps` and unique across concurrent runs.
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmssff"') do set "TS=%%i"
set "SCAN_NAME=lds-trivy-scan-!TS!"

if /I "%MODE%"=="image" (
  echo Scanning image %TARGET% with Trivy - container !SCAN_NAME!...
  docker run --rm --name !SCAN_NAME! ^
    -v /var/run/docker.sock:/var/run/docker.sock ^
    -v "%REPORTS%:/out" -v "%CACHE%:/root/.cache/trivy" ^
    %TRIVY_IMAGE%:%TRIVY_VERSION% image !FLAGS! --format template --template "@/contrib/html.tpl" --output /out/report.html "%TARGET%"
  set "RC=!errorlevel!"
  set "SCAN_TARGET=%TARGET%"
) else (
  REM Resolve TARGET to an ABSOLUTE path against the caller's cwd BEFORE pushd
  REM (docker -v needs an absolute source; a relative path would otherwise
  REM resolve against the project root after pushd and mount an empty dir).
  for %%I in ("%TARGET%") do set "TARGET=%%~fI"
  if not exist "!TARGET!" (
    echo Target not found: !TARGET!
    echo Pass a path to scan, e.g.  lds tools trivy D:\projects\PHP\svc-setting-lumen
    popd
    endlocal & exit /b 1
  )
  echo Scanning !TARGET! with Trivy ^(fs^) - container !SCAN_NAME!...
  docker run --rm --name !SCAN_NAME! ^
    -v "!TARGET!:/src" -v "%REPORTS%:/out" -v "%CACHE%:/root/.cache/trivy" -w /src ^
    %TRIVY_IMAGE%:%TRIVY_VERSION% fs !FLAGS! --format template --template "@/contrib/html.tpl" --output /out/report.html /src
  set "RC=!errorlevel!"
  set "SCAN_TARGET=!TARGET!"
)

set "SCAN_META=%REPORTS%\scan-meta.json"
set "SCAN_MODE=%MODE%"
set "SCAN_SEVERITY=%TRIVY_SEVERITY%"
set "SCAN_PRIORITY=%TRIVY_DETECTION_PRIORITY%"
powershell -NoProfile -Command ^
  "$obj=[ordered]@{tool='trivy';mode=$env:SCAN_MODE;target=$env:SCAN_TARGET;scanners=$env:TRIVY_SCANNERS;severity=[string]$env:SCAN_SEVERITY;detection_priority=[string]$env:SCAN_PRIORITY;ignore_unfixed=$env:TRIVY_IGNORE_UNFIXED;exit_code=$env:TRIVY_EXIT_CODE;timeout=$env:TRIVY_TIMEOUT;scanned_at=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')};" ^
  "$json=$obj | ConvertTo-Json -Compress;" ^
  "[System.IO.File]::WriteAllText($env:SCAN_META,$json,[System.Text.UTF8Encoding]::new($false))"

if "!RC!"=="0" goto scanok
REM Non-zero: is this the configured gating exit code (findings) or a real error?
if not "%TRIVY_EXIT_CODE%"=="0" if "!RC!"=="%TRIVY_EXIT_CODE%" goto gate
echo note: trivy exited with code !RC! - report may be incomplete.
popd
endlocal & exit /b %RC%
:gate
echo Trivy found issues ^(gating enabled - TRIVY_EXIT_CODE=%TRIVY_EXIT_CODE%^) - exiting %TRIVY_EXIT_CODE%.
popd
endlocal & exit /b %TRIVY_EXIT_CODE%
:scanok

echo Wrote %REPORTS%\report.html
echo View at http://%TRIVY_HOST%  (run 'lds up trivy' if the viewer isn't running).
popd
endlocal
