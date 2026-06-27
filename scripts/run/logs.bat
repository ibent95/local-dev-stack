@echo off
REM Tail logs for a service (or all).  logs.bat kafka-broker
setlocal
pushd "%~dp0..\.."
docker compose --profile "*" logs -f --tail=100 %*
popd
endlocal
