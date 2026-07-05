@echo off
REM One full LDS lifecycle from scratch:
REM   init -> down -> rm -> build-bases (only if missing) -> up [profiles]
REM   start.bat            # full reset, then up all
REM   start.bat kafka php  # full reset, then up those profiles
REM Teardown (down/rm) always covers everything; profiles passed go to `up`.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "N=0"

call :banner "INIT - network + .env"
call "%~dp0init.bat"
call :doneb

call :banner "DOWN - stop/remove existing"
call "%~dp0down.bat"
call :doneb

call :banner "RM - force-remove containers"
call "%~dp0rm.bat"
call :doneb

REM Build the lds/* bases ONLY if required core images are missing - distinct
REM from the standalone `lds build-bases`, which always (re)builds them all.
call :banner "ENSURE BASE IMAGES - run build-bases only if lds/php or lds/nginx is missing"
if not exist .env copy .env.example .env >nul
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%PHP_VERSION%"=="" set "PHP_VERSION=8.4"
if "%NGINX_VERSION%"=="" set "NGINX_VERSION=1.27"
set "NEED_BASES="
docker image inspect "lds/php:%PHP_VERSION%" >nul 2>&1 || set "NEED_BASES=1"
docker image inspect "lds/nginx:%NGINX_VERSION%" >nul 2>&1 || set "NEED_BASES=1"
if defined NEED_BASES (
  echo   required base image missing - handing off to build-bases...
  call "%~dp0..\build\build-bases.bat"
) else (
  echo   lds/php + lds/nginx already present - skipping ^(run 'lds build-bases' to force a rebuild^).
)
call :doneb

call :banner "UP - %*"
call "%~dp0up.bat" %*
REM Propagate up's exit code so `lds start && lds hosts-sync` skips hosts-sync
REM when `up` fails (e.g. a pull error aborts it). Captured BEFORE the footer.
set "RC=!errorlevel!"
call :doneb

echo.
echo ========================================================
echo   lds start: COMPLETE
echo ========================================================
popd
endlocal & exit /b %RC%

REM --- step banner helpers ---------------------------------------------------
:banner
set /a N+=1
echo.
echo ========================================================
echo   [!N!/5] %~1
echo ========================================================
set "STEP=%~1"
goto :eof

:doneb
echo   ---- [!N!/5] !STEP!: done ----
goto :eof
