@echo off
REM Ensure the `app` database + `app` user exist. The DHI mysql image's entrypoint
REM (unlike the official image) does NOT honor MYSQL_DATABASE / MYSQL_USER /
REM /docker-entrypoint-initdb.d - only the datadir + root password - so we create
REM them here. Idempotent; auto-run by `lds up` for the mysql/all profile.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%MYSQL_ROOT_PASSWORD%"=="" set "MYSQL_ROOT_PASSWORD=root"
if "%MYSQL_DATABASE%"=="" set "MYSQL_DATABASE=app"
if "%MYSQL_USER%"=="" set "MYSQL_USER=app"
if "%MYSQL_PASSWORD%"=="" set "MYSQL_PASSWORD=app"
set "C=lds-mysql"

REM Wait for mysql to accept the root login.
set "READY="
for /l %%i in (1,1,30) do (
  if not defined READY (
    docker exec %C% mysql -uroot -p%MYSQL_ROOT_PASSWORD% -e "SELECT 1" >nul 2>&1 && set "READY=1" || ping -n 3 127.0.0.1 >nul
  )
)
if not defined READY ( echo mysql not reachable - is the mysql profile up? & popd & endlocal & exit /b 1 )

echo Ensuring MySQL database %MYSQL_DATABASE% + user %MYSQL_USER%...
docker exec %C% mysql -uroot -p%MYSQL_ROOT_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS %MYSQL_DATABASE%; CREATE USER IF NOT EXISTS '%MYSQL_USER%'@'%%' IDENTIFIED BY '%MYSQL_PASSWORD%'; GRANT ALL PRIVILEGES ON %MYSQL_DATABASE%.* TO '%MYSQL_USER%'@'%%'; FLUSH PRIVILEGES;"

REM Apply seed/schema SQL into the db. DHI mysql ignores /docker-entrypoint-initdb.d,
REM so we feed configs\mysql\init\*.sql ourselves (idempotent files - safe to re-run).
for %%f in ("configs\mysql\init\*.sql") do (
  echo   applying %%~nxf...
  docker exec -i %C% mysql -uroot -p%MYSQL_ROOT_PASSWORD% %MYSQL_DATABASE% < "%%f"
)

echo MySQL ready (database %MYSQL_DATABASE%, user %MYSQL_USER%).
popd
endlocal
