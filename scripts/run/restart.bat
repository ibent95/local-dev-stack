@echo off
REM Restart profile-scoped services in-place.
REM   lds restart                     restart all services in this compose project
REM   lds restart postgres valkey     restart only services in those profiles
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "PROFILES="
for %%a in (%*) do (
  if /I "%%a"=="--rebuild" (
    echo restart does not build images. Use: lds up --rebuild ^<profiles...^>
    popd
    endlocal
    exit /b 1
  ) else (
    set "PROFILES=!PROFILES! %%a"
  )
)
if defined PROFILES set "PROFILES=!PROFILES:~1!"

if "!PROFILES!"=="" (
  echo Restarting all services...
  docker compose --profile "*" restart
) else (
  set "PARGS="
  for %%p in (!PROFILES!) do set "PARGS=!PARGS! --profile %%p"
  set "SERVICES="
  for /f "usebackq delims=" %%s in (`docker compose !PARGS! config --services`) do (
    set "SERVICES=!SERVICES! %%s"
  )
  if defined SERVICES set "SERVICES=!SERVICES:~1!"
  if "!SERVICES!"=="" (
    echo No services found for profiles: !PROFILES!
    popd
    endlocal
    exit /b 1
  )
  echo Restarting profiles: !PROFILES!
  echo Matched services: !SERVICES!
  docker compose restart !SERVICES!
)

docker compose --profile "*" ps

popd
endlocal
