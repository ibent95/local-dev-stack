@echo off
REM Manage an app project (a svc-/web- template) via its own docker compose.
REM   lds app start   [dir]        ensure proxy/dns/network, then build and start
REM   lds app stop    [dir] [-v]   stop (docker compose down)
REM   lds app restart [dir]        rebuild and recreate
REM   lds app logs    [dir] [svc]  tail logs
REM   lds app ps      [dir]        status
setlocal enabledelayedexpansion

set "SUB=%~1"
if "%SUB%"=="" goto usage
if /I "%SUB%"=="-h" goto usage
if /I "%SUB%"=="--help" goto usage
if /I "%SUB%"=="help" goto usage

set "OK="
for %%c in (start stop restart logs ps) do if /I "%SUB%"=="%%c" set "OK=1"
if not defined OK goto badsub
shift

REM First remaining arg is the dir unless it looks like a flag (-v, ...).
set "DIR=."
set "NEXT=%~1"
set "ISDIR="
if not "%NEXT%"=="" if not "%NEXT:~0,1%"=="-" set "ISDIR=1"
if defined ISDIR set "DIR=%NEXT%"
if defined ISDIR shift

REM Collect remaining args to forward to compose.
set "REST="
:collect
if "%~1"=="" goto check
set "REST=!REST! %~1"
shift
goto collect

:check
set "HASCOMPOSE="
if exist "%DIR%\docker-compose.yml" set "HASCOMPOSE=1"
if exist "%DIR%\compose.yml" set "HASCOMPOSE=1"
if exist "%DIR%\compose.yaml" set "HASCOMPOSE=1"
if not defined HASCOMPOSE goto nocompose

if /I "%SUB%"=="start"   goto start
if /I "%SUB%"=="stop"    goto stop
if /I "%SUB%"=="restart" goto restart
if /I "%SUB%"=="logs"    goto logs
if /I "%SUB%"=="ps"      goto ps

:start
echo ==^> ensuring LDS proxy + dns + network are up
call "%~dp0up.bat" proxy
echo ==^> building + starting project in: %DIR%
pushd "%DIR%"
docker compose up --build -d %REST%
docker compose ps
popd
goto end

:stop
echo ==^> stopping project in: %DIR%
pushd "%DIR%"
docker compose down %REST%
popd
goto end

:restart
echo ==^> rebuilding + recreating project in: %DIR%
pushd "%DIR%"
docker compose up --build -d --force-recreate %REST%
docker compose ps
popd
goto end

:logs
pushd "%DIR%"
docker compose logs -f %REST%
popd
goto end

:ps
pushd "%DIR%"
docker compose ps %REST%
popd
goto end

:badsub
echo Unknown app command: '%SUB%'
echo.
goto usage

:nocompose
echo No compose file in "%DIR%" - run this from the project folder, or pass its path.
echo   e.g. lds app %SUB% ..\..\Go\orders
endlocal
exit /b 1

:usage
echo Usage: lds app ^<command^> [dir] [args]
echo   start   [dir]        ensure proxy + build and start
echo   stop    [dir] [-v]   stop (docker compose down)
echo   restart [dir]        rebuild and recreate
echo   logs    [dir] [svc]  tail logs
echo   ps      [dir]        status
goto end

:end
endlocal
