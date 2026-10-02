@echo off
REM Seed DBX's connection list through its Web API so the stack databases are
REM auto-listed on a FRESH setup. Runs AFTER compose up (up.bat calls it as a
REM post-up hook). Idempotent: skips when connections already exist.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "SEED=configs\dbx\connections.seed.json"
if not exist "%SEED%" ( echo No DBX seed file - skipping. & popd & endlocal & exit /b 0 )

REM Container must be running (manual `lds db seed` skips when the profile is off).
set "RUNNING="
for /f "delims=" %%r in ('docker inspect -f "{{.State.Running}}" lds-dbx 2^>nul') do set "RUNNING=%%r"
if /I not "!RUNNING!"=="true" (
  echo DBX container is not running - skipping connection seed. ^(Start it: lds up dbx^)
  popd & endlocal & exit /b 0
)

REM Host port comes from .env (DB_ADMIN_HOST_PORT, default 4501).
set "DBPORT=4501"
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if /I "%%a"=="DB_ADMIN_HOST_PORT" set "DBPORT=%%b"
set "DBPORT=!DBPORT: =!"
if "!DBPORT!"=="" set "DBPORT=4501"
set "URL=http://localhost:!DBPORT!"

REM compose up -d returns as soon as the container starts - wait for the listener.
set "READY="
for /l %%i in (1,1,30) do (
  if not defined READY (
    curl -sf "!URL!/api/auth/check" >nul 2>&1 && set "READY=1"
    if not defined READY timeout /t 1 /nobreak >nul
  )
)
if not defined READY (
  echo DBX did not answer on :!DBPORT! within 30s - skipping connection seed.
  popd & endlocal & exit /b 0
)

REM Idempotent: only seed when there are no saved connections yet.
set "LIST="
for /f "usebackq delims=" %%l in (`curl -sf "!URL!/api/connection/list"`) do set "LIST=%%l"
set "LIST=!LIST: =!"
if "!LIST!"=="" (
  echo Could not read DBX's connection list - skipping seed.
  popd & endlocal & exit /b 0
)
if not "!LIST!"=="[]" (
  echo DBX already has connections - leaving them as-is.
  popd & endlocal & exit /b 0
)

curl -sf -X POST -H "Content-Type: application/json" --data @"%SEED%" "!URL!/api/connection/save" >nul
if errorlevel 1 (
  echo DBX connection seed FAILED - add them manually at !URL!
  popd & endlocal & exit /b 1
)
echo Seeded DBX with MySQL + MariaDB + Postgres + Mongo + SQL Server + Oracle connections.

popd
endlocal
exit /b 0
