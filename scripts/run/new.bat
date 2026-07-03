@echo off
REM Scaffold a new project — cross-language equivalent of "drop a PHP folder".
REM   new.bat php myblog            -> %PHP_PROJECTS_PATH%\myblog (served instantly)
REM   new.bat go myapi              -> web template by default
REM   new.bat svc-python rates      -> templates\svc-template-python
REM   new.bat web-laravel shop shop.test   (optional custom host)
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env so the *_PROJECTS_PATH vars are available (shell env wins).
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"

set "TYPE=%~1"
set "NAME=%~2"
set "HOST=%~3"
if "%TYPE%"=="" goto usage
if "%NAME%"=="" goto usage
if "%HOST%"=="" set "HOST=%NAME%.test"

REM ---- plain PHP (shared mass-vhost; no compose) ----
if /I "%TYPE%"=="php" (
  if "%PHP_PROJECTS_PATH%"=="" set "PHP_PROJECTS_PATH=./www"
  set "DEST=!PHP_PROJECTS_PATH!\%NAME%"
  if exist "!DEST!" ( echo Already exists: !DEST! & goto end )
  mkdir "!DEST!\public" 2>nul
  > "!DEST!\public\index.php" echo ^<?php echo "^<h1^>%NAME%^</h1^>^<p^>Served by local-dev-stack at ^<code^>%HOST%^</code^> - PHP " . PHP_VERSION . "^</p^>";
  echo Created plain PHP project: !DEST!
  echo   -^> http://%HOST%    ^(start the php profile if needed: lds up php^)
  goto end
)

REM ---- resolve role / tech ----
set "ROLE=web"
set "TECH=%TYPE%"
if /I "%TYPE:~0,4%"=="svc-"  ( set "ROLE=svc"  & set "TECH=%TYPE:svc-=%" )
if /I "%TYPE:~0,4%"=="web-"  ( set "ROLE=web"  & set "TECH=%TYPE:web-=%" )
if /I "%TYPE:~0,5%"=="cron-" ( set "ROLE=cron" & set "TECH=%TYPE:cron-=%" )
if /I "%TYPE%"=="cron"       ( set "ROLE=cron" & set "TECH=shell" )
if /I "%TYPE%"=="hop"        ( set "ROLE=cron" & set "TECH=hop" )
if /I "%TYPE%"=="pdi"        ( set "ROLE=cron" & set "TECH=pdi" )
if /I "%TYPE%"=="superset"   ( set "ROLE=web"  & set "TECH=superset" )
if /I "%TYPE%"=="powerbi"    ( set "ROLE=web"  & set "TECH=powerbi" )
if /I "%TYPE%"=="metabase"   ( set "ROLE=web"  & set "TECH=metabase" )
if /I "%TYPE%"=="grafana"    ( set "ROLE=web"  & set "TECH=grafana" )
if /I not "%TYPE:~0,4%"=="svc-" if /I not "%TYPE:~0,4%"=="web-" if /I not "%TYPE:~0,5%"=="cron-" if /I not "%TYPE%"=="cron" if /I not "%TYPE%"=="hop" if /I not "%TYPE%"=="pdi" if /I not "%TYPE%"=="superset" if /I not "%TYPE%"=="powerbi" if /I not "%TYPE%"=="metabase" if /I not "%TYPE%"=="grafana" (
  if not exist "templates\web-template-%TECH%" set "ROLE=svc"
)

set "TPL=%ROLE%-template-%TECH%"
set "SRC=templates\%TPL%"
if not exist "%SRC%\" (
  echo No template "%SRC%".
  echo Available templates:
  dir /b templates
  goto end
)

REM ---- resolve projects path var ----
call :pathvar "%TECH%"
if "%PVAR%"=="" ( echo Don't know where to put "%TECH%" projects. & goto end )
set "BASE=!%PVAR%!"
if "%BASE%"=="" set "BASE=.\projects\%TECH%"
set "DEST=%BASE%\%NAME%"
if exist "%DEST%\" ( echo Already exists: %DEST% & goto end )

xcopy /e /i /q "%SRC%" "%DEST%" >nul

REM Rewrite template identifier -> project name across all copied files.
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%DEST%' -Recurse -File | ForEach-Object { $c = Get-Content -LiteralPath $_.FullName -Raw; if ($c -match [regex]::Escape('%TPL%')) { ($c -replace [regex]::Escape('%TPL%'), '%NAME%') | Set-Content -LiteralPath $_.FullName -NoNewline } }"

REM Cron projects vendor the supercronic binary (no network at build/deploy).
REM Only for actual cron jobs (shell/python/node/go/php), NOT for ETL data projects.
if /I "%ROLE%"=="cron" if not "%TECH%"=="hop" if not "%TECH%"=="pdi" (
  if not exist "%DEST%\bin" mkdir "%DEST%\bin"
  copy /y "assets\supersonic\v0.2.46\supercronic-linux-amd64" "%DEST%\bin\supercronic" >nul
)

REM Custom host? compose auto-loads .env in the project dir.
if /I not "%HOST%"=="%NAME%.test" (
  if "%TZ%"=="" set "TZ=Asia/Jakarta"
  > "%DEST%\.env" echo APP_HOST=%HOST%
  >> "%DEST%\.env" echo TZ=!TZ!
)

echo Scaffolded %TPL% -^> %DEST%
echo Next:
echo   cd "%DEST%" ^&^& lds app start
findstr /c:"VIRTUAL_HOST" "%DEST%\docker-compose.yml" >nul 2>&1 && (echo   -^> http://%HOST%) || (echo   ^(no web URL - scheduled/worker service; watch it with: lds app logs^))
goto end

:pathvar
set "PVAR="
if /I "%~1"=="go" set "PVAR=GO_PROJECTS_PATH"
if /I "%~1"=="rust" set "PVAR=RUST_PROJECTS_PATH"
if /I "%~1"=="node" set "PVAR=NODE_PROJECTS_PATH"
if /I "%~1"=="express" set "PVAR=NODE_PROJECTS_PATH"
if /I "%~1"=="angular" set "PVAR=NODE_PROJECTS_PATH"
if /I "%~1"=="react" set "PVAR=NODE_PROJECTS_PATH"
if /I "%~1"=="python" set "PVAR=PYTHON_PROJECTS_PATH"
if /I "%~1"=="flask" set "PVAR=PYTHON_PROJECTS_PATH"
if /I "%~1"=="fastapi" set "PVAR=PYTHON_PROJECTS_PATH"
if /I "%~1"=="django" set "PVAR=PYTHON_PROJECTS_PATH"
if /I "%~1"=="java" set "PVAR=JAVA_PROJECTS_PATH"
if /I "%~1"=="springboot" set "PVAR=JAVA_PROJECTS_PATH"
if /I "%~1"=="micronaut" set "PVAR=JAVA_PROJECTS_PATH"
if /I "%~1"=="quarkus" set "PVAR=JAVA_PROJECTS_PATH"
if /I "%~1"=="vaadin" set "PVAR=JAVA_PROJECTS_PATH"
if /I "%~1"=="laravel" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="symfony" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="slim" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="webman" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="codeigniter" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="cakephp" set "PVAR=PHP_PROJECTS_PATH"
if /I "%~1"=="shell" set "PVAR=JOBS_PROJECTS_PATH"
if /I "%~1"=="hop" set "PVAR=HOP_PROJECTS_PATH"
if /I "%~1"=="pdi" set "PVAR=HOP_PROJECTS_PATH"
if /I "%~1"=="superset" set "PVAR=SUPERSET_PROJECTS_PATH"
if /I "%~1"=="powerbi" set "PVAR=SUPERSET_PROJECTS_PATH"
if /I "%~1"=="metabase" set "PVAR=SUPERSET_PROJECTS_PATH"
if /I "%~1"=="grafana" set "PVAR=SUPERSET_PROJECTS_PATH"
exit /b

:usage
echo Usage: lds new ^<type^> ^<name^> [host]
echo   type: php ^| ^<tech^> ^| ^<role^>-^<tech^>   (role = svc^|web^|cron; bare tech -^> web)
echo   tech: go rust node python java express flask fastapi django
echo         laravel symfony slim webman codeigniter cakephp
echo         springboot micronaut quarkus vaadin angular react
echo   cron (scheduled job): cron-shell cron-python cron-node cron-go cron-php
echo   cron-hop cron-pdi (ETL jobs)
echo   web-superset web-powerbi web-metabase web-grafana (BI dashboards)
echo Examples:
echo   lds new svc-python rates
echo   lds new web-laravel shop shop.test
echo   lds new cron-python nightly-report
echo   lds new cron-hop my-etl-project
echo   lds new web-superset my-bi-dashboard
goto end

:end
popd
endlocal
