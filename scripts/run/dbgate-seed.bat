@echo off
REM Seed DBGate's connection list (in its bind-mounted data directory) so the
REM stack databases are auto-listed on a FRESH setup — without DBGate's
REM CONNECTIONS env (which would disable "Add connection"). Idempotent: only
REM seeds when no connections exist.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "DBDIR=data\dbgate"
set "SEED=configs\dbgate\connections.seed.jsonl"
if not exist "%SEED%" ( echo No DBGate seed file - skipping. & popd & endlocal & exit /b 0 )

REM Ensure the bind-mount directory exists.
if not exist "%DBDIR%" mkdir "%DBDIR%"

REM Idempotent: skip if connections already exist.
if exist "%DBDIR%\connections.jsonl" ( echo DBGate already has connections - leaving as-is. & popd & endlocal & exit /b 0 )

copy /y "%SEED%" "%DBDIR%\connections.jsonl" >nul
echo Seeded DBGate with MySQL + Postgres + Mongo connections.

popd
endlocal
