@echo off
REM Bring up one or more profiles.  up.bat mysql redis   |   up.bat all
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if not exist .env (
  echo No .env - creating from .env.example
  copy .env.example .env >nul
)

if "%NETWORK_NAME%"=="" (set NET=lds-network) else (set NET=%NETWORK_NAME%)
docker network inspect !NET! >nul 2>&1 || (
  echo Creating shared network '!NET!'
  docker network create !NET! >nul
)

REM Profiles to start: explicit args win. With no args, build the default run-set
REM from the per-service toggles in .env (LDS_ENABLE_<PROFILE>=true|false), else
REM "all". Canonical profile order; each maps to LDS_ENABLE_<NAME> (matched
REM case-insensitively).
set "PROFILES=%*"
if "%PROFILES%"=="" (
  set "PROFILES="
  for %%p in (proxy php mysql postgres mongo redis memcached kafka phpcacheadmin dbgate soketi centrifugo mqtt drawdb hop superset semgrep) do (
    set "VAL="
    if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if /I "%%a"=="LDS_ENABLE_%%p" set "VAL=%%b"
    set "VAL=!VAL: =!"
    if /I "!VAL!"=="true" set "PROFILES=!PROFILES! %%p"
  )
  if "!PROFILES!"=="" (
    set "PROFILES=all"
  ) else (
    echo No profiles given - using enabled toggles ^(LDS_ENABLE_*^):!PROFILES!
  )
)
set "ARGS="
for %%p in (%PROFILES%) do set "ARGS=!ARGS! --profile %%p"

REM HTTPS opt-in: when LDS_ENABLE_HTTPS=true AND a proxy/php profile is selected,
REM layer the TLS overlay onto the base file and ensure a dev cert exists.
set "CFILES=-f docker-compose.yml"
set "HTTPS_ON="
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if /I "%%a"=="LDS_ENABLE_HTTPS" set "HTTPS_ON=%%b"
set "HTTPS_ON=!HTTPS_ON: =!"
set "PROXY_SEL="
echo %PROFILES% | findstr /I /C:"proxy" /C:"php" /C:"all" >nul && set "PROXY_SEL=1"
if /I "!HTTPS_ON!"=="true" if defined PROXY_SEL (
  if not exist "configs\proxy\certs\test.crt" call "%~dp0certs.bat"
  set "CFILES=-f docker-compose.yml -f docker-compose.https.yml"
  echo HTTPS overlay enabled ^(proxy TLS on :443^)
)
if /I "!HTTPS_ON!"=="true" if not defined PROXY_SEL echo LDS_ENABLE_HTTPS=true but no proxy/php profile selected - HTTPS overlay skipped.

REM The php/all profile needs the lds/php base image - build it once if missing.
if "%PHP_VERSION%"=="" set "PHP_VERSION=8.4"
echo %PROFILES% | findstr /I /C:"php" /C:"all" >nul
if not errorlevel 1 (
  docker image inspect "lds/php:%PHP_VERSION%" >nul 2>&1 || (
    call :sub "build lds/php base - first run"
    docker buildx bake -f docker-bake.hcl --load php
    call :subdone
  )
)

REM Seed DBGate connections into its volume BEFORE it starts (fresh setups only).
echo %PROFILES% | findstr /I /C:"dbgate" /C:"all" >nul
if not errorlevel 1 (
  call :sub "dbgate-seed"
  call "%~dp0dbgate-seed.bat"
  call :subdone
)

call :sub "compose up -d - start containers: %PROFILES%"
REM --remove-orphans clears containers left behind by renamed/removed services.
REM If `up` fails (e.g. an image pull errored), STOP - don't fall through to
REM mongo-init/kafka-topics, which would wait on containers that never started.
docker compose !CFILES! !ARGS! up -d --remove-orphans
if errorlevel 1 (
  echo compose up failed - aborting ^(check the pull/error above^).
  docker compose !CFILES! !ARGS! ps
  popd & endlocal & exit /b 1
)
docker compose !CFILES! !ARGS! ps
call :subdone

REM Ensure the MySQL app database + user (DHI mysql doesn't auto-create them).
echo %PROFILES% | findstr /I /C:"mysql" /C:"all" >nul
if not errorlevel 1 (
  call :sub "mysql-init"
  call "%~dp0mysql-init.bat"
  call :subdone
)

REM Initiate the Mongo replica set + users (single-node RS for CDC).
echo %PROFILES% | findstr /I /C:"mongo" /C:"all" >nul
if not errorlevel 1 (
  call :sub "mongo-init"
  call "%~dp0mongo-init.bat"
  call :subdone
)

REM Provision Kafka topics (replaces the old one-shot kafka-init service).
echo %PROFILES% | findstr /I /C:"kafka" /C:"all" >nul
if not errorlevel 1 (
  call :sub "kafka-topics"
  call "%~dp0kafka-topics.bat"
  call :subdone
)

REM Pre-pull the Semgrep scanner so it ships with the profile. The scanner is a
REM one-shot in its OWN `semgrep-scan` profile (so `up` never starts it / leaves an
REM Exited container), but we fetch its pinned image here so the first
REM `lds tools semgrep` runs without a surprise pull. Best-effort.
echo %PROFILES% | findstr /I /C:"semgrep" /C:"all" >nul
if not errorlevel 1 (
  call :sub "semgrep-scan: pre-pull scanner image"
  docker compose !CFILES! --profile semgrep-scan pull semgrep-scan
  call :subdone
)

popd
endlocal
exit /b 0

REM --- up sub-step banner helpers --------------------------------------------
:sub
echo.
echo -------- up: %~1 --------
set "SUB=%~1"
goto :eof

:subdone
echo -------- up: !SUB!: done --------
goto :eof
