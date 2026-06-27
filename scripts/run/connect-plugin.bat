@echo off
REM Install a Kafka Connect plugin into a worker's host-mounted plugin dir.
REM Optional leading flag picks the worker (default --generic):
REM   --generic   -> configs\kafka\connect-generic\plugins
REM   --debezium  -> configs\kafka\connect-debezium\plugins (alongside CDC connectors)
REM   connect-plugin.bat [--generic|--debezium] jdbc|s3|http|opensearch
REM   connect-plugin.bat [--generic|--debezium] <URL> [name]
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Target worker (optional leading flag; default generic).
set "TARGET=generic"
if /I "%~1"=="--generic"  ( set "TARGET=generic"  & shift )
if /I "%~1"=="--debezium" ( set "TARGET=debezium" & shift )
if /I "!TARGET!"=="debezium" (
  set "PLUGINS=%CD%\configs\kafka\connect-debezium\plugins" & set "CTR=lds-kafka-connect-debezium"
) else (
  set "PLUGINS=%CD%\configs\kafka\connect-generic\plugins" & set "CTR=lds-kafka-connect-generic"
)

set "ARG=%~1"
set "NAME=%~2"
if "%ARG%"=="" ( echo usage: lds connect-plugin ^<jdbc^|s3^|http^|opensearch^|URL^> [name] & popd & endlocal & exit /b 1 )

set "REPO="
if /I "%ARG%"=="jdbc"       set "REPO=Aiven-Open/jdbc-connector-for-apache-kafka"
if /I "%ARG%"=="s3"         set "REPO=Aiven-Open/s3-connector-for-apache-kafka"
if /I "%ARG%"=="http"       set "REPO=Aiven-Open/http-connector-for-apache-kafka"
if /I "%ARG%"=="opensearch" set "REPO=Aiven-Open/opensearch-connector-for-apache-kafka"

set "URL="
echo %ARG%| findstr /R "^http.*://" >nul && set "URL=%ARG%"

if defined URL (
  if "%NAME%"=="" for %%F in ("%ARG%") do set "NAME=%%~nF"
) else (
  if not defined REPO ( echo unknown connector '%ARG%' - or pass a release URL. & popd & endlocal & exit /b 1 )
  if "%NAME%"=="" set "NAME=%ARG%"
  echo Resolving latest release asset of !REPO!...
  REM NOT /releases/latest: some releases ship no built artifact (only the auto
  REM source tarball), so scan recent releases (newest first) for the first real asset.
  for /f "usebackq delims=" %%U in (`powershell -NoProfile -Command "(Invoke-RestMethod 'https://api.github.com/repos/!REPO!/releases?per_page=30').assets.browser_download_url | Where-Object { $_ -match '\.(tar\.gz|tgz|tar|zip)$' -and $_ -notmatch '\.(asc|sha\d+|md5|sig)$' } | Select-Object -First 1"`) do set "URL=%%U"
  if not defined URL ( echo no built release asset for !REPO! - pass a release URL directly:  lds kafka connect-plugin --generic ^<URL^> [name] & popd & endlocal & exit /b 1 )
)

set "DEST=%PLUGINS%\!NAME!"
if exist "!DEST!" rmdir /s /q "!DEST!"
mkdir "!DEST!" 2>nul
echo Downloading !URL!
curl -fSL "!URL!" -o "%TEMP%\lds-conn.pkg" || ( echo download failed. & popd & endlocal & exit /b 1 )
REM tar.exe (built into Win10+) auto-detects + extracts .zip and .tar(.gz)
tar -xf "%TEMP%\lds-conn.pkg" -C "!DEST!"
del "%TEMP%\lds-conn.pkg" 2>nul

echo Installed '!NAME!' into !DEST!  (target: !TARGET! worker)
echo Load it into the worker:  docker restart !CTR!
popd
endlocal
