@echo off
REM Register all Superset dashboard projects under SUPERSET_PROJECTS_PATH.
REM Run by `lds up superset` (or manually). Idempotent: skips already-imported projects.
REM Requires the superset container to be running.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env for SUPERSET_PROJECTS_PATH and SUPERSET_PROJECTS_CONTAINER_PATH.
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"

if "%SUPERSET_PROJECTS_PATH%"=="" set "SUPERSET_PROJECTS_PATH=.\data\superset\projects"
if "%SUPERSET_PROJECTS_CONTAINER_PATH%"=="" set "SUPERSET_PROJECTS_CONTAINER_PATH=/app/superset_projects"
set "CTR_NAME=lds-superset"
set "BIN=/app/.venv/bin"

REM Ensure the host project directory exists.
if not exist "%SUPERSET_PROJECTS_PATH%" mkdir "%SUPERSET_PROJECTS_PATH%"

REM Ensure the marker directory exists.
set "MARKER_DIR=%SUPERSET_PROJECTS_PATH%\.lds-imported"
if not exist "%MARKER_DIR%" mkdir "%MARKER_DIR%"

REM Check the superset container is running.
docker inspect --format="{{.State.Running}}" "%CTR_NAME%" 2>nul | findstr /C:"true" >nul
if errorlevel 1 (
  echo Superset container (%CTR_NAME%) is not running - skipping project registration.
  goto end
)

set COUNT=0
for /d %%D in ("%SUPERSET_PROJECTS_PATH%\*") do (
  set "PNAME=%%~nxD"
  REM Skip hidden directories (starting with .)
  set "FIRST_CHAR=!PNAME:~0,1!"
  if not "!FIRST_CHAR!"=="." (
    REM Check if the folder has any YAML files.
    set "HAS_YAML="
    for %%Y in ("%%D\*.yaml" "%%D\*.yml") do set "HAS_YAML=1"
    if defined HAS_YAML (
      REM Check if already imported (marker file exists).
      if not exist "%MARKER_DIR%\!PNAME!.imported" (
        echo Importing Superset project: !PNAME!
        docker exec "%CTR_NAME%" "%BIN%/superset" import-dashboards --path "%SUPERSET_PROJECTS_CONTAINER_PATH%/!PNAME!" --recursive --overwrite 2>&1
        if errorlevel 1 echo   Warning: import returned non-zero for '!PNAME!' ^(may have no dashboards^).
        echo. > "%MARKER_DIR%\!PNAME!.imported"
        set /a COUNT+=1
      )
    )
  )
)

if %COUNT% gtr 0 (
  echo Imported %COUNT% Superset project^(s^).
) else (
  echo All Superset projects already imported ^(or none found in %SUPERSET_PROJECTS_PATH%^).
)

:end
popd
endlocal
