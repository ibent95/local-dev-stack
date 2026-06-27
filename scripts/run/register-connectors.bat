@echo off
REM Register Debezium connectors.  register-connectors.bat [match]
setlocal enabledelayedexpansion
pushd "%~dp0..\.."
if "%CONNECT_URL%"=="" set "CONNECT_URL=http://localhost:4413"
set "MATCH=%~1"

set "FOUND="
for %%f in (configs\kafka\connect-debezium\*%MATCH%*connector.json) do (
  set "FOUND=1"
  echo Registering %%~nxf -^> %CONNECT_URL%/connectors
  curl -sf -X POST -H "Content-Type: application/json" --data @"%%f" %CONNECT_URL%/connectors >nul && (echo   OK) || (echo   failed or already exists)
)
if not defined FOUND echo No connector configs matched "%MATCH%".

echo Active connectors:
curl -s %CONNECT_URL%/connectors
echo.
popd
endlocal
