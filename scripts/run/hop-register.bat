@echo off
REM Register all Hop projects under HOP_PROJECTS_PATH into hop-config.json.
REM Run by `lds up hop` (or manually). Idempotent: skips already-registered projects.
REM Requires the hop container to be running.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env for HOP_PROJECTS_PATH and HOP_PROJECTS_CONTAINER_PATH.
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"

if "%HOP_PROJECTS_PATH%"=="" set "HOP_PROJECTS_PATH=.\data\hop\projects"
if "%HOP_PROJECTS_CONTAINER_PATH%"=="" set "HOP_PROJECTS_CONTAINER_PATH=/usr/local/tomcat/projects"
set "CTR_NAME=lds-hop"

REM Ensure the host project directory exists.
if not exist "%HOP_PROJECTS_PATH%" mkdir "%HOP_PROJECTS_PATH%"

REM Check the hop container is running. Use findstr to check if "true" appears.
docker inspect --format="{{.State.Running}}" "%CTR_NAME%" 2>nul | findstr /C:"true" >nul
if errorlevel 1 (
  echo Hop container ^(%CTR_NAME%^) is not running - skipping project registration.
  goto end
)

REM Get list of already-registered projects from hop-config.json inside the container.
set "REGISTERED="
set "TMPREG=%TEMP%\lds-hop-reg-%RANDOM%.txt"
docker exec "%CTR_NAME%" sh -c "cfg=/usr/local/tomcat/webapps/ROOT/config/hop-config.json; [ -f \"\$cfg\" ] && cat \"\$cfg\" | tr ',' '\n' | grep -E '\"projectName\"[[:space:]]*:' | sed 's/.*\"//;s/\".*//' 2>nul" > "%TMPREG%"
if exist "%TMPREG%" (
  for /f "usebackq tokens=*" %%r in ("%TMPREG%") do set "REGISTERED=!REGISTERED! %%r"
  del "%TMPREG%" 2>nul
)

set COUNT=0
for /d %%D in ("%HOP_PROJECTS_PATH%\*") do (
  if exist "%%D\project-config.json" (
    set "PNAME=%%~nxD"
    echo !REGISTERED! | findstr /C:"!PNAME!" >nul
    if errorlevel 1 (
      echo Registering Hop project: !PNAME!
      docker exec "%CTR_NAME%" sh -c "cd /usr/local/tomcat/webapps/ROOT && ./hop-conf.sh --project-create --project '!PNAME!' --project-home '%HOP_PROJECTS_CONTAINER_PATH%/!PNAME!' 2>&1"
      if errorlevel 1 echo   Warning: hop-conf returned non-zero for '!PNAME!' ^(may already exist^).
      set /a COUNT+=1
    )
  )
)

if %COUNT% gtr 0 (
  echo Registered %COUNT% new Hop project^(s^).
) else (
  echo All Hop projects already registered ^(or none found in %HOP_PROJECTS_PATH%^).
)

:end
popd
endlocal