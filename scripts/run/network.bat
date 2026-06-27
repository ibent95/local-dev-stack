@echo off
REM Manage the shared lds-network.  network.bat [status|create|rm|reset]
setlocal enabledelayedexpansion
if "%NETWORK_NAME%"=="" (set "NET=lds-network") else (set "NET=%NETWORK_NAME%")
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=status"

if /I "%ACTION%"=="status" ( call :status & goto :end )
if /I "%ACTION%"=="create" ( call :create & goto :end )
if /I "%ACTION%"=="rm"     ( call :remove & goto :end )
if /I "%ACTION%"=="remove" ( call :remove & goto :end )
if /I "%ACTION%"=="reset"  ( call :remove && call :create & goto :end )
echo Usage: lds network [status^|create^|rm^|reset]
goto :end

:create
docker network inspect %NET% >nul 2>&1 && (echo Network '%NET%' already exists.) || (docker network create %NET% >nul & echo Created network '%NET%'.)
goto :eof

:remove
docker network inspect %NET% >nul 2>&1 || ( echo Network '%NET%' does not exist. & goto :eof )
set "ATTACHED="
for /f "delims=" %%a in ('docker network inspect %NET% --format "{{range .Containers}}{{.Name}} {{end}}"') do set "ATTACHED=%%a"
if defined ATTACHED if not "!ATTACHED!"=="" (
  echo Cannot remove '%NET%' - containers still attached: !ATTACHED!
  echo Run "lds.bat down" ^(and stop any standalone projects^) first.
  exit /b 1
)
docker network rm %NET% >nul & echo Removed network '%NET%'.
goto :eof

:status
docker network inspect %NET% >nul 2>&1 || ( echo Network '%NET%': MISSING - run "lds.bat network create". & goto :eof )
echo Network '%NET%': EXISTS
set "ATTACHED="
for /f "delims=" %%a in ('docker network inspect %NET% --format "{{range .Containers}}{{.Name}} {{end}}"') do set "ATTACHED=%%a"
if defined ATTACHED if not "!ATTACHED!"=="" (echo   attached: !ATTACHED!) else (echo   attached: ^(none^))
goto :eof

:end
endlocal
