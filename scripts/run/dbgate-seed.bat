@echo off
REM Seed DBGate's connection list (in its data volume) so the stack databases are
REM auto-listed on a FRESH setup — without DBGate's CONNECTIONS env (which would
REM disable "Add connection"). Idempotent: only seeds when no connections exist.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%DBGATE_VERSION%"=="" set "DBGATE_VERSION=7.2.0"

set "VOL=local-dev-stack_dbgate-data"
set "SEED=configs\dbgate\connections.seed.jsonl"
if not exist "%SEED%" ( echo No DBGate seed file - skipping. & popd & endlocal & exit /b 0 )

REM Create the volume with Compose's labels so `lds up` doesn't warn about an
REM externally-created volume.
docker volume inspect %VOL% >nul 2>&1 || docker volume create --label com.docker.compose.project=local-dev-stack --label com.docker.compose.volume=dbgate-data %VOL% >nul

docker run --rm -i -v %VOL%:/data dbgate/dbgate:%DBGATE_VERSION% sh -c "if [ -s /data/connections.jsonl ]; then echo 'DBGate already has connections - leaving as-is.'; exit 0; fi; cat > /data/connections.jsonl; echo 'Seeded DBGate with MySQL + Postgres + Mongo connections.'" < "%SEED%"

popd
endlocal
