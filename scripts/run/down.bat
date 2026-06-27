@echo off
REM Stop everything (all profiles). Pass -v to also delete data volumes.
setlocal
pushd "%~dp0..\.."
set "EXTRA="
if /I "%~1"=="-v" set "EXTRA=-v"
if /I "%~1"=="--volumes" set "EXTRA=-v"
if defined EXTRA echo Removing containers AND volumes (data will be lost)
docker compose --profile "*" down --remove-orphans %EXTRA%
popd
endlocal
