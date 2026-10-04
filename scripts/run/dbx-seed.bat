@echo off
REM Seed DBX's connection list through its Web API so the stack databases are
REM auto-listed on a FRESH setup, and make sure the JDBC + LDAP Studio plugins
REM are installed. Runs AFTER compose up (up.bat calls it as a post-up hook).
REM Three idempotent stages: 1) plugins (JDBC + LDAP Studio, only when missing,
REM failures are warnings - the next run retries), 2) DB connections (only when
REM the list is empty, never clobbers), 3) LDAP connections (LLDAP + OpenLDAP,
REM skipped per entry when that name already exists).
REM Note: the API returns single-line JSON that can exceed cmd's 8191-char
REM set/findstr limits, so the plugin and name checks go through PowerShell.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "SEED=configs\dbx\connections.seed.json"
if not exist "%SEED%" ( echo No DBX seed file - skipping. & popd & endlocal & exit /b 0 )

REM Container must be running (manual `lds db seed` skips when the profile is off).
set "RUNNING="
for /f "delims=" %%r in ('docker inspect -f "{{.State.Running}}" lds-dbx 2^>nul') do set "RUNNING=%%r"
if /I not "!RUNNING!"=="true" (
  echo DBX container is not running - skipping connection seed. ^(Start it: lds up dbx^)
  popd & endlocal & exit /b 0
)

REM Host port comes from .env (DB_ADMIN_HOST_PORT, default 4501).
set "DBPORT=4501"
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if /I "%%a"=="DB_ADMIN_HOST_PORT" set "DBPORT=%%b"
set "DBPORT=!DBPORT: =!"
if "!DBPORT!"=="" set "DBPORT=4501"
set "URL=http://localhost:!DBPORT!"

REM compose up -d returns as soon as the container starts - wait for the listener.
set "READY="
for /l %%i in (1,1,30) do (
  if not defined READY (
    curl -sf "!URL!/api/auth/check" >nul 2>&1 && set "READY=1"
    if not defined READY timeout /t 1 /nobreak >nul
  )
)
if not defined READY (
  echo DBX did not answer on :!DBPORT! within 30s - skipping connection seed.
  popd & endlocal & exit /b 0
)

REM --- Stage 1: plugins (JDBC + LDAP Studio), only when missing -------------
call :ensure_jdbc_plugin

powershell -NoProfile -Command "try { $p = Invoke-RestMethod -Uri '!URL!/api/plugins' -TimeoutSec 15 } catch { exit 1 }; if (@($p.manifest.id) -contains 'io.dbx.ldap') { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
  echo DBX: installing LDAP Studio plugin ^(first run downloads it^)...
  curl -sf --max-time 300 -X POST -H "Content-Type: application/json" -d "{\"repositoryId\":\"dbx-official\",\"pluginId\":\"io.dbx.ldap\"}" "!URL!/api/plugins/marketplace/install" >nul 2>&1
  if errorlevel 1 (
    echo DBX: LDAP Studio install FAILED - will retry on the next 'lds up dbx' or from dbx.test.
  ) else (
    echo DBX: LDAP Studio plugin installed.
  )
)

REM --- Stage 2: DB connections, only when the list is empty -----------------
REM exit codes: 0 = has connections, 1 = empty, 2 = list unreadable.
powershell -NoProfile -Command "try { $l = Invoke-RestMethod -Uri '!URL!/api/connection/list' -TimeoutSec 15 } catch { exit 2 }; if ($null -eq $l -or @($l).Count -eq 0) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 2 (
  echo Could not read DBX's connection list - skipping seed.
  popd & endlocal & exit /b 0
)
if errorlevel 1 (
  curl -sf -X POST -H "Content-Type: application/json" --data @"%SEED%" "!URL!/api/connection/save" >nul
  if errorlevel 1 (
    echo DBX connection seed FAILED - add them manually at !URL!
    popd & endlocal & exit /b 1
  )
  echo Seeded DBX with MySQL + MariaDB + Postgres + Mongo + SQL Server + Oracle connections.
) else (
  echo DBX already has connections - skipping DB seed.
)

REM --- Stage 3: LDAP connections, one seed file per directory ---------------
set "LDAP_FAILED=0"
call :seed_ldap "LLDAP (LDS)" "configs\dbx\connections.ldap-lldap.seed.json"
if errorlevel 1 set "LDAP_FAILED=1"
call :seed_ldap "OpenLDAP (LDS)" "configs\dbx\connections.ldap-openldap.seed.json"
if errorlevel 1 set "LDAP_FAILED=1"

popd
if "!LDAP_FAILED!"=="1" ( endlocal & exit /b 1 )
endlocal
exit /b 0

:ensure_jdbc_plugin
set "PST="
for /f "usebackq delims=" %%p in (`curl -sf --max-time 15 "!URL!/api/jdbc/plugin/status" 2^>nul`) do set "PST=%%p"
set "PSTF=!PST:"=!"
set "P2=!PSTF:installed:true=!"
if "!P2!"=="!PSTF!" (
  echo DBX: installing JDBC plugin ^(first run downloads it^)...
  curl -sf --max-time 300 -X POST "!URL!/api/jdbc/plugin/install" >nul 2>&1
  if errorlevel 1 (
    echo DBX: JDBC plugin install FAILED - will retry on the next 'lds up dbx' or from dbx.test.
  ) else (
    echo DBX: JDBC plugin installed.
  )
)
exit /b 0

:seed_ldap
set "NAME=%~1"
set "LF=%~2"
if not exist "!LF!" exit /b 0
powershell -NoProfile -Command "try { $l = Invoke-RestMethod -Uri '!URL!/api/connection/list' -TimeoutSec 15 } catch { exit 1 }; if (@($l.name) -contains '%~1') { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 (
  echo DBX: !NAME! already present - skipping.
  exit /b 0
)
curl -sf -X POST -H "Content-Type: application/json" --data @"!LF!" "!URL!/api/connection/save" >nul 2>&1
if errorlevel 1 (
  echo DBX: seed FAILED for !NAME! - add it manually at !URL!
  exit /b 1
)
echo DBX: seeded !NAME! connection.
exit /b 0
