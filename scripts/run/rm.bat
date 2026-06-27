@echo off
REM Force-remove containers for the given profiles (default: everything).
REM   rm.bat              # all profiles
REM   rm.bat kafka mysql  # only those profiles
REM Uses `rm -fs`: -s stops running containers first, -f skips the confirm
REM prompt (the compose equivalent of `docker rm -f`). Named data volumes are
REM kept; pass -v yourself only if you also want anonymous volumes gone.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "PROFILES=%*"
if "%PROFILES%"=="" (
  set "ARGS=--profile *"
  set "WHICH=all"
) else (
  set "ARGS="
  for %%p in (%PROFILES%) do set "ARGS=!ARGS! --profile %%p"
  set "WHICH=%PROFILES%"
)

echo Force-removing containers for profiles: !WHICH!
docker compose !ARGS! rm -fs

popd
endlocal
