@echo off
REM Ensure Postgres has the Werkyn database/user by augmenting
REM POSTGRES_INIT_SPECS for this run, then delegating to postgres-init.bat.
REM Idempotent; auto-run by `lds up` for werkyn/all.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%WERKYN_POSTGRES_DB%"=="" set "WERKYN_POSTGRES_DB=werkyn"
if "%WERKYN_POSTGRES_USER%"=="" set "WERKYN_POSTGRES_USER=werkyn"
if "%WERKYN_POSTGRES_PASSWORD%"=="" set "WERKYN_POSTGRES_PASSWORD=werkyn"
set "SPEC=%WERKYN_POSTGRES_DB%:%WERKYN_POSTGRES_USER%:%WERKYN_POSTGRES_PASSWORD%"

if "%POSTGRES_INIT_SPECS%"=="" (
  set "POSTGRES_INIT_SPECS=%SPEC%"
) else (
  echo %POSTGRES_INIT_SPECS% | findstr /I /C:"%SPEC%" >nul || set "POSTGRES_INIT_SPECS=%POSTGRES_INIT_SPECS%,%SPEC%"
)

call "%~dp0postgres-init.bat"
popd
endlocal
