@echo off
REM Ensure the default MySQL database/user exist and optionally provision extra
REM tool databases/users from MYSQL_INIT_SPECS (db:user:password entries).
REM Idempotent; auto-run by `lds up` for the mysql/all profile.
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

call :ensure_mysql_db_user "%MYSQL_DATABASE%" "%MYSQL_USER%" "%MYSQL_PASSWORD%"

if defined MYSQL_INIT_SPECS (
  for %%s in (!MYSQL_INIT_SPECS:,= !) do call :ensure_mysql_spec "%%~s"
)

REM Apply seed/schema SQL into the default db only. DHI mysql ignores
REM /docker-entrypoint-initdb.d, so we feed configs\mysql\init\*.sql ourselves.
for %%f in ("configs\mysql\init\*.sql") do (
  echo   applying %%~nxf...
  docker exec -i %C% mysql -uroot -p%MYSQL_ROOT_PASSWORD% %MYSQL_DATABASE% < "%%f"
)

echo MySQL ready.
popd
endlocal
exit /b 0

:ensure_mysql_spec
set "SPEC=%~1"
set "DBX="
set "UX="
set "PX="
for /f "tokens=1,2,* delims=:" %%a in ("!SPEC!") do (
  set "DBX=%%~a"
  set "UX=%%~b"
  set "PX=%%~c"
)
if "!DBX!"=="" goto :invalid_mysql_spec
if "!UX!"=="" goto :invalid_mysql_spec
if "!PX!"=="" goto :invalid_mysql_spec
call :ensure_mysql_db_user "!DBX!" "!UX!" "!PX!"
goto :eof

:invalid_mysql_spec
echo Skipping invalid MYSQL_INIT_SPECS entry "!SPEC!" ^(expected db:user:password^).
goto :eof

:ensure_mysql_db_user
set "DBN=%~1"
set "UN=%~2"
set "PW=%~3"
echo Ensuring MySQL database !DBN! + user !UN!...
docker exec %C% mysql -uroot -p%MYSQL_ROOT_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS !DBN!; CREATE USER IF NOT EXISTS '!UN!'@'%%' IDENTIFIED BY '!PW!'; ALTER USER '!UN!'@'%%' IDENTIFIED BY '!PW!'; GRANT ALL PRIVILEGES ON !DBN!.* TO '!UN!'@'%%'; FLUSH PRIVILEGES;"
goto :eof
