@echo off
REM One-time: create the shared `lds-network` network (idempotent).
setlocal
if "%NETWORK_NAME%"=="" (set NET=lds-network) else (set NET=%NETWORK_NAME%)
docker network inspect %NET% >nul 2>&1
if %errorlevel%==0 (
  echo Network '%NET%' already exists.
) else (
  docker network create %NET% >nul
  echo Created shared network '%NET%'.
)
endlocal
