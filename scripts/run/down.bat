@echo off
REM Stop containers for the given profiles (default: everything).
REM   down.bat                # all profiles
REM   down.bat kafka mysql    # only those profiles
REM   down.bat -v             # + wipe volumes (all profiles)
REM   down.bat kafka -v       # + wipe volumes (specific profiles)
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "EXTRA="
set "PROFILES="
for %%a in (%*) do (
  if /I "%%a"=="-v" (set "EXTRA=-v") else if /I "%%a"=="--volumes" (set "EXTRA=-v") else (set "PROFILES=!PROFILES! %%a")
)
if defined PROFILES set "PROFILES=!PROFILES:~1!"

if "%PROFILES%"=="" (
  if defined EXTRA echo Removing containers AND volumes (data will be lost)
  docker compose --profile "*" down --remove-orphans %EXTRA%
) else (
  echo Stopping containers for profiles: %PROFILES%
  if defined EXTRA echo Removing volumes (data will be lost)
  set "ARGS="
  for %%p in (%PROFILES%) do set "ARGS=!ARGS! --profile %%p"
  docker compose !ARGS! down --remove-orphans %EXTRA%
)

popd
endlocal
