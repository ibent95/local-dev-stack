@echo off
REM Playwright End-To-End testing - scaffold projects, run tests, record tests.
REM   lds playwright init <name> [url]      scaffold a test project
REM   lds playwright run <name> [args...]   run its tests
REM   lds playwright codegen [url]          interactive test recorder (TTY)
REM   lds playwright shell                  open a shell in the runner container
REM   lds playwright report                 print the HTML report viewer URL
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%PLAYWRIGHT_VERSION%"=="" set "PLAYWRIGHT_VERSION=v1.62.1-noble"
if "%PLAYWRIGHT_PROJECTS_PATH%"=="" set "PLAYWRIGHT_PROJECTS_PATH=.\data\playwright\projects"
if "%PLAYWRIGHT_REPORT_HOST%"=="" set "PLAYWRIGHT_REPORT_HOST=playwright.test"
if "%PLAYWRIGHT_REPORT_HOST_PORT%"=="" set "PLAYWRIGHT_REPORT_HOST_PORT=4486"
if "%PLAYWRIGHT_UI_HOST_PORT%"=="" set "PLAYWRIGHT_UI_HOST_PORT=4487"

set "CMD=%~1"
if "%CMD%"=="" set "CMD=help"
shift

if /I "%CMD%"=="init"   goto init
if /I "%CMD%"=="run"    goto run
if /I "%CMD%"=="codegen" goto codegen
if /I "%CMD%"=="ui"     goto ui
if /I "%CMD%"=="shell"  goto shell
if /I "%CMD%"=="report" goto report
if /I "%CMD%"=="help"   goto help
if /I "%CMD%"=="-h"     goto help
if /I "%CMD%"=="--help" goto help
echo Unknown playwright command: %CMD%
goto help

:init
set "NAME=%~1"
set "URL=%~2"
if "%NAME%"=="" ( echo usage: lds playwright init ^<name^> [url] & goto end )
set "SRC=%CD%\templates\e2e-template-playwright"
set "BASE=%PLAYWRIGHT_PROJECTS_PATH:/=\%"
if not "%BASE:~0,1%"=="\" if not "%BASE:~1,1%"==":" set "BASE=%CD%\%BASE%"
set "DIR=%BASE%\%NAME%"
if exist "%DIR%" ( echo Already exists: %DIR% & goto end )
mkdir "%DIR%" 2>nul
xcopy /E /I /Q /Y "%SRC%" "%DIR%" >nul
if "%URL%"=="" set "URL=http://%NAME%.test"
REM Pin @playwright/test to the runner image's Playwright version (strip v + suffix).
set "VER=%PLAYWRIGHT_VERSION:~1%"
for /f "delims=- tokens=1" %%v in ("%VER%") do set "VER=%%v"
powershell -NoProfile -Command "$p='%DIR%\package.json'; $c=Get-Content -Raw $p; $c=$c -replace '\"@playwright/test\": \"[^\"]*\"', '\"@playwright/test\": \"%VER%\"'; Set-Content -NoNewline -Path $p -Value $c"
powershell -NoProfile -Command "Get-ChildItem -Recurse -File '%DIR%' | ForEach-Object { $c = Get-Content -Raw $_.FullName; $c = $c.Replace('<NAME>','%NAME%').Replace('<name>','%NAME%').Replace('<URL>','%URL%'); Set-Content -NoNewline -Path $_.FullName -Value $c }"
echo Scaffolded Playwright E2E project -^> %DIR%
echo   target: %URL%
echo   run:    lds playwright run %NAME%
goto end

:run
set "NAME=%~1"
if "%NAME%"=="" ( echo usage: lds playwright run ^<name^> [playwright args...] & goto end )
shift
set "EXTRA="
:collect
if "%~1"=="" goto :runit
set "EXTRA=!EXTRA! %~1"
shift
goto collect
:runit
call :ensureup
docker compose -f docker-compose.yml exec playwright bash -lc "cd /e2e/projects/%NAME% && { [ -d node_modules ] || npm install --no-audit --no-fund; } && npx playwright test!EXTRA!"
goto end

:codegen
call :ensureup
docker compose -f docker-compose.yml exec playwright npx playwright codegen %~1
goto end

:ui
set "UINAME=%~1"
if "%UINAME%"=="" ( echo usage: lds playwright ui ^<name^> & goto end )
call :ensureup
echo Playwright UI Mode: open http://localhost:%PLAYWRIGHT_UI_HOST_PORT% in your browser
echo   ^(UI server runs inside the container; Ctrl+C to stop^)
docker compose -f docker-compose.yml exec playwright bash -lc "cd /e2e/projects/%UINAME% && { [ -d node_modules ] || npm install --no-audit --no-fund; } && npx playwright test --ui --ui-host=0.0.0.0 --ui-port=8787"
goto end

:shell
call :ensureup
docker compose -f docker-compose.yml exec playwright bash
goto end

:report
call :ensureup
echo Playwright report viewer: http://%PLAYWRIGHT_REPORT_HOST%
echo   ^(direct: http://localhost:%PLAYWRIGHT_REPORT_HOST_PORT%^)
goto end

:help
echo usage: lds playwright ^<command^> [args]
echo.
echo   init ^<name^> [url]      scaffold a Playwright E2E projectecho   run ^<name^> [args...]   run its tests inside the runner container
  echo   codegen [url]          open the interactive test recorder ^(TTY^)
  echo   ui ^<name^>            open Playwright UI Mode in your browser
  echo   shell                  open a bash shell inside the runner container
echo   report                 show the HTML report viewer URL
goto end

:ensureup
docker ps -q -f name=^/lds-playwright$ >nul 2>&1 || (
  echo Starting playwright profile ^(first run pulls the image - be patient^)...
  docker compose -f docker-compose.yml --profile playwright up -d playwright playwright-report
)
goto :eof

:end
popd
endlocal
exit /b 0
