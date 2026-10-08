@echo off
REM Bring up one or more profiles.  up.bat mysql redis   |   up.bat all
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM --- --rebuild flag: add --build to docker compose up ---------------------
set "REBUILD=0"
set "PROFILES="
for %%a in (%*) do (
  if /I "%%a"=="--rebuild" (set "REBUILD=1") else (set "PROFILES=!PROFILES! %%a")
)
if defined PROFILES set "PROFILES=!PROFILES:~1!"

if not exist .env (
  echo No .env - creating from .env.example
  copy .env.example .env >nul
)

REM Keep .env in sync with .env.example (keeps your values; adds missing vars).
call "%~dp0env-sync.bat" --quiet

if "%NETWORK_NAME%"=="" (set NET=lds-network) else (set NET=%NETWORK_NAME%)
docker network inspect !NET! >nul 2>&1 || (
  echo Creating shared network '!NET!'
  docker network create !NET! >nul
)

REM Profiles to start: explicit args win. With no args, build the default run-set
REM from the per-service toggles in .env (LDS_ENABLE_<PROFILE>=true|false), else
REM "all". Canonical profile order; each maps to LDS_ENABLE_<NAME> (matched
REM case-insensitively).
if "%PROFILES%"=="" (
  set "PROFILES="
  for %%p in (proxy php mysql mariadb mssql oracle postgres mongo redis valkey memcached rabbitmq kafka phpcacheadmin dbx soketi centrifugo mqtt drawdb hop superset metabase hoppscotch plane semgrep zap trivy crg vaultwarden mail penpot instatic analytics tasks wiki openwa headlessx playwright erpnext rustfs duckdb trino snapotter imgcompress drawio lldap openldap monitoring) do (
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
set "HTTPS_ACTIVE=0"
echo %PROFILES% | findstr /I /C:"proxy" /C:"php" /C:"all" >nul && set "PROXY_SEL=1"
if /I "!HTTPS_ON!"=="true" if defined PROXY_SEL (
  if not exist "configs\proxy\certs\test.crt" call "%~dp0certs.bat"
  set "CFILES=-f docker-compose.yml -f docker-compose.https.yml"
  set "HTTPS_ACTIVE=1"
  echo HTTPS overlay enabled ^(proxy TLS on :443^)
)
if /I "!HTTPS_ON!"=="true" if not defined PROXY_SEL echo LDS_ENABLE_HTTPS=true but no proxy/php profile selected - HTTPS overlay skipped.

REM Keep public-facing Penpot URI in sync with the active edge scheme to avoid
REM mixed-content/CORS-looking browser failures when HTTPS is enabled.
set "PENPOT_SEL="
echo %PROFILES% | findstr /I /C:"penpot" /C:"all" >nul && set "PENPOT_SEL=1"
if defined PENPOT_SEL (
  set "SCHEME=http"
  if "!HTTPS_ACTIVE!"=="1" set "SCHEME=https"
  set "PENPOT_HOST_VAL="
  set "PENPOT_PUBLIC_URI_VAL="
  if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
    if /I "%%a"=="PENPOT_HOST" set "PENPOT_HOST_VAL=%%b"
    if /I "%%a"=="PENPOT_PUBLIC_URI" set "PENPOT_PUBLIC_URI_VAL=%%b"
  )
  set "PENPOT_HOST_VAL=!PENPOT_HOST_VAL: =!"
  if "!PENPOT_HOST_VAL!"=="" set "PENPOT_HOST_VAL=penpot.test"
  if "!PENPOT_PUBLIC_URI_VAL!"=="" set "PENPOT_PUBLIC_URI_VAL=http://!PENPOT_HOST_VAL!"
  if /I "!PENPOT_PUBLIC_URI_VAL:~0,8!"=="https://" (
    if /I "!SCHEME!"=="http" set "PENPOT_PUBLIC_URI_VAL=http://!PENPOT_PUBLIC_URI_VAL:~8!"
  ) else if /I "!PENPOT_PUBLIC_URI_VAL:~0,7!"=="http://" (
    if /I "!SCHEME!"=="https" set "PENPOT_PUBLIC_URI_VAL=https://!PENPOT_PUBLIC_URI_VAL:~7!"
  ) else (
    set "PENPOT_PUBLIC_URI_VAL=!SCHEME!://!PENPOT_HOST_VAL!"
  )
  set "PENPOT_PUBLIC_URI=!PENPOT_PUBLIC_URI_VAL!"
  echo Penpot public URI resolved to !PENPOT_PUBLIC_URI! ^(scheme: !SCHEME!^).
)

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

REM The Semgrep + Trivy + Playwright + CRG viewers use lds/nginx - build it once if missing.
if "%NGINX_VERSION%"=="" set "NGINX_VERSION=1.27"
echo %PROFILES% | findstr /I /C:"semgrep" /C:"trivy" /C:"playwright" /C:"crg" /C:"all" >nul
if not errorlevel 1 (
  docker image inspect "lds/nginx:%NGINX_VERSION%" >nul 2>&1 || (
    call :sub "build lds/nginx base - first run"
    docker buildx bake -f docker-bake.hcl --load nginx
    call :subdone
  )
)

REM DuckDB service uses lds/duckdev (DHI alpine-base + DuckDB CLI binary).
if "%DUCKDB_VERSION%"=="" set "DUCKDB_VERSION=1.2.0"
echo %PROFILES% | findstr /I /C:"duckdb" /C:"all" >nul
if not errorlevel 1 (
  docker image inspect "lds/duckdev:%DUCKDB_VERSION%" >nul 2>&1 || (
    call :sub "build lds/duckdev base (first run)"
    docker buildx bake -f docker-bake.hcl --load duckdev
    call :subdone
  )
)

REM The code-review-graph scanner image (configs/crg) - build it once so the
REM first `lds tools crg` run has no build delay (upstream ships no official image).
if "%CRG_VERSION%"=="" set "CRG_VERSION=2.3.7"
echo %PROFILES% | findstr /I /C:"crg" /C:"all" >nul
if not errorlevel 1 (
  docker image inspect "lds/crg:%CRG_VERSION%" >nul 2>&1 || (
    call :sub "build lds/crg scanner (first use)"
    docker build -q -t "lds/crg:%CRG_VERSION%" "%CD%\configs\crg"
    call :subdone
  )
)

REM Seed sample Parquet/CSV/JSON data for DuckDB and Trino.
echo %PROFILES% | findstr /I /C:"duckdb" /C:"trino" /C:"all" >nul
if not errorlevel 1 (
  call :sub "seed-data"
  call "%~dp0seed-data.bat"
  call :subdone
)

REM Ensure the HeadlessX source checkout exists (build context for the headlessx-*
REM services). Clones on first run, fast-forwards afterwards. Runs before compose
REM up so the build contexts are valid.
echo %PROFILES% | findstr /I /C:"headlessx" /C:"all" >nul
if not errorlevel 1 (
  call :sub "headlessx-init"
  call "%~dp0headlessx-init.bat"
  call :subdone
)



set "UP_FLAGS=-d --remove-orphans"
if !REBUILD!==1 (
  set "UP_FLAGS=!UP_FLAGS! --build"
  call :sub "compose up -d --build (rebuild + start containers): %PROFILES%"
) else (
  call :sub "compose up -d (pull + start containers): %PROFILES%"
)
REM --remove-orphans clears containers left behind by renamed/removed services.
REM If `up` fails (e.g. an image pull errored), STOP - don't fall through to
REM mongo-init/kafka-topics, which would wait on containers that never started.
docker compose !CFILES! !ARGS! up !UP_FLAGS!
if errorlevel 1 (
  echo compose up failed - aborting ^(check the pull/error above^).
  docker compose !CFILES! !ARGS! ps
  popd & endlocal & exit /b 1
)
docker compose !CFILES! !ARGS! ps
call :subdone

REM Seed DBX connections AFTER it is up (the seed goes through DBX's Web API, so
REM the container must be answering; fresh setups only - skips if you already
REM added connections). Keeps the stack DBs auto-listed.
echo %PROFILES% | findstr /I /C:"dbx" /C:"all" >nul
if not errorlevel 1 (
  call :sub "dbx-seed"
  call "%~dp0dbx-seed.bat"
  call :subdone
)

REM DB services now self-initialize on startup (see docker-compose.yml).
REM The mysql-init and postgres-init scripts are kept for manual use via `lds exec`.

REM Ensure the LDS Analytics DB/user spec exists.
echo %PROFILES% | findstr /I /C:"analytics" /C:"all" >nul
if not errorlevel 1 (
  call :sub "analytics-init"
  call "%~dp0analytics-init.bat"
  call :subdone
)

REM Ensure the LDS Tasks DB/user spec exists.
echo %PROFILES% | findstr /I /C:"tasks" /C:"all" >nul
if not errorlevel 1 (
  call :sub "tasks-init"
  call "%~dp0tasks-init.bat"
  call :subdone
)

REM Ensure the LDS Wiki DB/user spec exists.
echo %PROFILES% | findstr /I /C:"wiki" /C:"all" >nul
if not errorlevel 1 (
  call :sub "wiki-init"
  call "%~dp0wiki-init.bat"
  call :subdone
)

REM Ensure the HeadlessX DB/user exists (postgres may predate the spec addition).
echo %PROFILES% | findstr /I /C:"headlessx" /C:"all" >nul
if not errorlevel 1 (
  call :sub "headlessx-db-init"
  call "%~dp0headlessx-db-init.bat"
  call :subdone
)

REM Ensure the Hive Metastore DB/user exists. The metastore container's
REM schematool retries while waiting for this DB; without it schematool fails.
echo %PROFILES% | findstr /I /C:"trino" /C:"all" >nul
if not errorlevel 1 (
  call :sub "hive-metastore-init"
  call "%~dp0hive-metastore-init.bat"
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

REM Pre-pull the Trivy scanner (same rationale as semgrep-scan above).
echo %PROFILES% | findstr /I /C:"trivy" /C:"all" >nul
if not errorlevel 1 (
  call :sub "trivy-scan: pre-pull scanner image"
  docker compose !CFILES! --profile trivy-scan pull trivy-scan
  call :subdone
)

REM Register Hop projects (folder-per-project) into hop-config.json via hop-conf.
echo %PROFILES% | findstr /I /C:"hop" /C:"all" >nul
if not errorlevel 1 (
  call :sub "hop-register"
  call "%~dp0hop-register.bat"
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
