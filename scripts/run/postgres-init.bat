@echo off
REM Ensure the default Postgres database/user exist and optionally provision extra
REM tool databases/users from POSTGRES_INIT_SPECS (db:user:password entries).
REM Idempotent; auto-run by `lds up` for the postgres/all profile.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%POSTGRES_USER%"=="" set "POSTGRES_USER=app"
if "%POSTGRES_PASSWORD%"=="" set "POSTGRES_PASSWORD=app"
if "%POSTGRES_DB%"=="" set "POSTGRES_DB=app"
set "C=lds-postgres"

REM Wait for postgres to accept the bootstrap login.
set "READY="
for /l %%i in (1,1,30) do (
  if not defined READY (
    docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -U %POSTGRES_USER% -d postgres -tAc "SELECT 1" >nul 2>&1 && set "READY=1" || ping -n 3 127.0.0.1 >nul
  )
)
if not defined READY ( echo postgres not reachable - is the postgres profile up? & popd & endlocal & exit /b 1 )

call :ensure_postgres_db_user "%POSTGRES_DB%" "%POSTGRES_USER%" "%POSTGRES_PASSWORD%"

if defined POSTGRES_INIT_SPECS (
  for %%s in (!POSTGRES_INIT_SPECS:,= !) do call :ensure_postgres_spec "%%~s"
)

echo Postgres ready.
popd
endlocal
exit /b 0

:ensure_postgres_spec
set "SPEC=%~1"
set "DBX="
set "UX="
set "PX="
for /f "tokens=1,2,* delims=:" %%a in ("!SPEC!") do (
  set "DBX=%%~a"
  set "UX=%%~b"
  set "PX=%%~c"
)
if "!DBX!"=="" goto :invalid_pg_spec
if "!UX!"=="" goto :invalid_pg_spec
if "!PX!"=="" goto :invalid_pg_spec
call :ensure_postgres_db_user "!DBX!" "!UX!" "!PX!"
goto :eof

:invalid_pg_spec
echo Skipping invalid POSTGRES_INIT_SPECS entry "!SPEC!" ^(expected db:user:password^).
goto :eof

:ensure_postgres_db_user
set "DBN=%~1"
set "UN=%~2"
set "PW=%~3"
set "PESC=!PW:'=''!"

echo Ensuring Postgres role !UN!...
docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -v ON_ERROR_STOP=1 -U %POSTGRES_USER% -d postgres -c "CREATE ROLE !UN! LOGIN PASSWORD '!PESC!';" >nul 2>&1
docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -v ON_ERROR_STOP=1 -U %POSTGRES_USER% -d postgres -c "ALTER ROLE !UN! WITH LOGIN PASSWORD '!PESC!';" >nul
if errorlevel 1 ( echo Failed ensuring Postgres role !UN!. & exit /b 1 )

echo Ensuring Postgres database !DBN! ^(owner !UN!^)...
docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -v ON_ERROR_STOP=1 -U %POSTGRES_USER% -d postgres -c "CREATE DATABASE !DBN! OWNER !UN!;" >nul 2>&1
docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -v ON_ERROR_STOP=1 -U %POSTGRES_USER% -d postgres -c "GRANT CONNECT ON DATABASE !DBN! TO !UN!;" >nul
if errorlevel 1 ( echo Failed ensuring Postgres database !DBN!. & exit /b 1 )
docker exec -e PGPASSWORD=%POSTGRES_PASSWORD% %C% psql -v ON_ERROR_STOP=1 -U %POSTGRES_USER% -d !DBN! -c "GRANT USAGE, CREATE ON SCHEMA public TO !UN!; ALTER SCHEMA public OWNER TO !UN!; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO !UN!; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO !UN!; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO !UN!; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO !UN!;" >nul
if errorlevel 1 ( echo Failed applying schema grants for Postgres database !DBN!. & exit /b 1 )
echo Postgres database !DBN! + user !UN! ready.
goto :eof
