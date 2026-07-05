@echo off
REM Ensure Postgres has the InsightTrack database/user by augmenting
REM POSTGRES_INIT_SPECS for this run, then delegating to postgres-init.bat.
REM Idempotent; auto-run by `lds up` for insighttrack/all.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%INSIGHTTRACK_POSTGRES_DB%"=="" set "INSIGHTTRACK_POSTGRES_DB=app"
if "%INSIGHTTRACK_POSTGRES_USER%"=="" set "INSIGHTTRACK_POSTGRES_USER=app"
if "%INSIGHTTRACK_POSTGRES_PASSWORD%"=="" set "INSIGHTTRACK_POSTGRES_PASSWORD=app"
set "SPEC=%INSIGHTTRACK_POSTGRES_DB%:%INSIGHTTRACK_POSTGRES_USER%:%INSIGHTTRACK_POSTGRES_PASSWORD%"

if "%POSTGRES_INIT_SPECS%"=="" (
  set "POSTGRES_INIT_SPECS=%SPEC%"
) else (
  echo %POSTGRES_INIT_SPECS% | findstr /I /C:"%SPEC%" >nul || set "POSTGRES_INIT_SPECS=%POSTGRES_INIT_SPECS%,%SPEC%"
)

call "%~dp0postgres-init.bat"
popd
endlocal
