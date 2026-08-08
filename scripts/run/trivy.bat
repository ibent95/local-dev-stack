@echo off
REM Run a Trivy scan and write an HTML report for the viewer.  (lds tools trivy)
REM   lds tools trivy [path]        fs scan - directory/repo/dependency manifest (default: current dir)
REM   lds tools trivy image <name>  image scan (uses the local docker socket)
REM   lds tools trivy clear         remove the current report + metadata
REM Results -> data\trivy\reports\report.html, viewed at http://trivy.test.
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
if "%TRIVY_VERSION%"=="" set "TRIVY_VERSION=0.58.1"
if "%TRIVY_HOST%"==""    set "TRIVY_HOST=trivy.test"
if "%TRIVY_TIMEOUT%"=="" set "TRIVY_TIMEOUT=30m"
if "%TRIVY_SCANNERS%"=="" set "TRIVY_SCANNERS=vuln"
set "REPORTS=%CD%\data\trivy\reports"
set "CACHE=%CD%\data\trivy\cache"
if not exist "%REPORTS%" mkdir "%REPORTS%"
if not exist "%CACHE%" mkdir "%CACHE%"

REM Run the SAME pinned image as the `trivy-scan` compose service (declared there
REM + pre-pulled by `lds up trivy`). We use `docker run` rather than
REM `docker compose run`: Compose's -v parser splits on ':' and chokes on a
REM Windows drive-letter source (D:\...). The docker CLI handles D:\... correctly.
REM The vulnerability DB is cached in data\trivy\cache (shared with the compose
REM service), so it downloads once, not per scan.
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmssff"') do set "TS=%%i"
set "SCAN_NAME=lds-trivy-scan-!TS!"

if /I "%MODE%"=="image" (
  echo Scanning image %TARGET% with Trivy - container !SCAN_NAME!...
  docker run --rm --name !SCAN_NAME! ^
    -v /var/run/docker.sock:/var/run/docker.sock ^
    -v "%REPORTS%:/out" -v "%CACHE%:/root/.cache/trivy" ^
    %TRIVY_IMAGE%:%TRIVY_VERSION% image --scanners "%TRIVY_SCANNERS%" --timeout "%TRIVY_TIMEOUT%" --format template --template "@/contrib/html.tpl" --output /out/report.html "%TARGET%"
  if errorlevel 1 (
    popd
    endlocal & exit /b 1
  )
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
    %TRIVY_IMAGE%:%TRIVY_VERSION% fs --scanners "%TRIVY_SCANNERS%" --timeout "%TRIVY_TIMEOUT%" --format template --template "@/contrib/html.tpl" --output /out/report.html /src
  if errorlevel 1 (
    popd
    endlocal & exit /b 1
  )
  set "SCAN_TARGET=!TARGET!"
)

set "SCAN_META=%REPORTS%\scan-meta.json"
set "SCAN_MODE=%MODE%"
powershell -NoProfile -Command ^
  "$obj=[ordered]@{tool='trivy';mode=$env:SCAN_MODE;target=$env:SCAN_TARGET;scanners=$env:TRIVY_SCANNERS;timeout=$env:TRIVY_TIMEOUT;scanned_at=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')};" ^
  "$json=$obj | ConvertTo-Json -Compress;" ^
  "[System.IO.File]::WriteAllText($env:SCAN_META,$json,[System.Text.UTF8Encoding]::new($false))"

echo Wrote %REPORTS%\report.html
echo View at http://%TRIVY_HOST%  (run 'lds up trivy' if the viewer isn't running).
popd
endlocal
