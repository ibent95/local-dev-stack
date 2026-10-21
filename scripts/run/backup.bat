@echo off
REM ===========================================================================
REM Dump every RUNNING LDS database into one timestamped folder.
REM   lds backup [--only mysql,postgres,...] [--out DIR] [--keep N] [--list]
REM
REM Windows counterpart of scripts/run/backup.sh. Dumps are written UNCOMPRESSED
REM here (cmd has no gzip); scripts/run/restore.* accept both plain and .gz
REM dumps, so a folder made by either platform restores on either platform.
REM
REM Layout (default root: data\backups):
REM   data\backups\20261021-153000\manifest.tsv + postgres\postgres.sql, ...
REM Oracle is not covered (Data Pump needs directory objects) - see docs.
REM ===========================================================================
setlocal EnableDelayedExpansion
set "ROOT=%~dp0..\.."
pushd "%ROOT%" >nul 2>&1
if errorlevel 1 ( echo Cannot enter project root & exit /b 1 )

set "BACKUP_ROOT=%ROOT%data\backups"
if not "%BACKUP_DIR%"=="" set "BACKUP_ROOT=%BACKUP_DIR%"
set "ONLY="
set "OUT="
set "KEEP="
set "LIST=0"

:parse
if "%~1"=="" goto parsed
if /I "%~1"=="--only"   ( set "ONLY=%~2" & shift & shift & goto parse )
if /I "%~1"=="--out"    ( set "OUT=%~2"  & shift & shift & goto parse )
if /I "%~1"=="--keep"   ( set "KEEP=%~2" & shift & shift & goto parse )
if /I "%~1"=="--list"   ( set "LIST=1" & shift & goto parse )
if /I "%~1"=="-h"       goto usage
if /I "%~1"=="--help"   goto usage
echo unknown option: %~1 & goto usage

:parsed
if "%LIST%"=="1" (
  if not exist "%BACKUP_ROOT%" ( echo no backups in %BACKUP_ROOT% & goto end )
  for /f "delims=" %%d in ('dir /b /ad /o-n "%BACKUP_ROOT%" 2^>nul') do echo %%d
  goto end
)

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%i"
if "%STAMP%"=="" set "STAMP=backup-%RANDOM%"
if "%OUT%"=="" set "OUT=%BACKUP_ROOT%\%STAMP%"

if not exist "%OUT%" mkdir "%OUT%" >nul 2>&1
set "MANIFEST=%OUT%\manifest.tsv"
echo # engine	file	bytes>"%MANIFEST%"
echo Backing up running LDS services to %OUT%
set "FAILED=0"
set "COUNT=0"

call :wants mysql    && call :dump_mysql
call :wants mariadb  && call :dump_mariadb
call :wants postgres && call :dump_postgres
call :wants mongo    && call :dump_mongo
call :wants redis    && call :dump_redis
call :wants valkey   && call :dump_valkey
call :wants mssql    && call :dump_mssql

if "%COUNT%"=="0" (
  echo   nothing to back up - is any data profile running? ^(lds ps^)
  goto fail
)

if not "%KEEP%"=="" (
  set /a SKIP=%KEEP%
  for /f "delims=" %%d in ('dir /b /ad /o-n "%BACKUP_ROOT%" 2^>nul') do (
    if !SKIP! GTR 0 ( set /a SKIP-=1 ) else (
      echo   pruning %%d
      rd /s /q "%BACKUP_ROOT%\%%d" >nul 2>&1
    )
  )
)

echo   done - restore with: lds restore
if not "%FAILED%"=="0" goto fail
goto end

REM ---------------------------------------------------------------------------
:wants
if "%ONLY%"=="" exit /b 0
echo ,%ONLY%, | findstr /I /C:",%~1," >nul && exit /b 0
exit /b 1

:is_running
docker inspect -f "{{.State.Running}}" "lds-%~1" 2>nul | findstr /I "true" >nul
exit /b %errorlevel%

:record
set "F=%~2"
if not exist "!F!" ( echo   fail   %~1 & set /a FAILED+=1 & exit /b 1 )
for %%s in ("!F!") do set "SZ=%%~zs"
echo   ok     %~1 (!SZ! bytes)
echo %~1	!F:%OUT%\=!	!SZ!>>"%MANIFEST%"
set /a COUNT+=1
exit /b 0

:dump_mysql
call :is_running mysql || ( echo   skip   mysql ^(not running^) & exit /b 0 )
mkdir "%OUT%\mysql" >nul 2>&1
docker exec lds-mysql sh -c "exec mysqldump -uroot -p\"$MYSQL_ROOT_PASSWORD\" --single-transaction --quick --routines --triggers --events --hex-blob --databases app" >"%OUT%\mysql\mysql.sql" 2>nul
call :record mysql "%OUT%\mysql\mysql.sql"
exit /b 0

:dump_mariadb
call :is_running mariadb || ( echo   skip   mariadb ^(not running^) & exit /b 0 )
mkdir "%OUT%\mariadb" >nul 2>&1
docker exec lds-mariadb sh -c "exec mariadb-dump -uroot -p\"$MARIADB_ROOT_PASSWORD\" --single-transaction --quick --routines --triggers --events --hex-blob --databases app" >"%OUT%\mariadb\mariadb.sql" 2>nul
call :record mariadb "%OUT%\mariadb\mariadb.sql"
exit /b 0

:dump_postgres
call :is_running postgres || ( echo   skip   postgres ^(not running^) & exit /b 0 )
mkdir "%OUT%\postgres" >nul 2>&1
docker exec lds-postgres pg_dumpall -U app --clean --if-exists --no-role-passwords >"%OUT%\postgres\postgres.sql" 2>nul
call :record postgres "%OUT%\postgres\postgres.sql"
exit /b 0

:dump_mongo
call :is_running mongo || ( echo   skip   mongo ^(not running^) & exit /b 0 )
mkdir "%OUT%\mongo" >nul 2>&1
docker exec lds-mongo sh -c "exec mongodump --uri=\"mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@localhost:27017/?authSource=admin\" --archive --gzip" >"%OUT%\mongo\mongo.archive.gz" 2>nul
call :record mongo "%OUT%\mongo\mongo.archive.gz"
exit /b 0

:dump_redis
call :is_running redis || ( echo   skip   redis ^(not running^) & exit /b 0 )
mkdir "%OUT%\redis" >nul 2>&1
docker exec lds-redis redis-cli SAVE >nul 2>&1
docker cp lds-redis:/data/dump.rdb "%OUT%\redis\dump.rdb" >nul 2>&1
call :record redis "%OUT%\redis\dump.rdb"
exit /b 0

:dump_valkey
call :is_running valkey || ( echo   skip   valkey ^(not running^) & exit /b 0 )
mkdir "%OUT%\valkey" >nul 2>&1
docker exec lds-valkey valkey-cli SAVE >nul 2>&1
docker cp lds-valkey:/data/dump.rdb "%OUT%\valkey\dump.rdb" >nul 2>&1
call :record valkey "%OUT%\valkey\dump.rdb"
exit /b 0

:dump_mssql
call :is_running mssql || ( echo   skip   mssql ^(not running^) & exit /b 0 )
mkdir "%OUT%\mssql" >nul 2>&1
docker exec lds-mssql sh -c "mkdir -p /var/opt/mssql/backup" >nul 2>&1
for /f "usebackq delims=" %%d in (`docker exec lds-mssql sh -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$MSSQL_SA_PASSWORD\" -C -h -1 -W -Q \"SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4\""`) do (
  set "DB=%%d"
  set "DB=!DB: =!"
  if not "!DB!"=="" (
    docker exec lds-mssql sh -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$MSSQL_SA_PASSWORD\" -C -Q \"BACKUP DATABASE [!DB!] TO DISK='/var/opt/mssql/backup/!DB!.bak' WITH INIT, COMPRESSION\"" >nul 2>&1
    docker cp "lds-mssql:/var/opt/mssql/backup/!DB!.bak" "%OUT%\mssql\!DB!.bak" >nul 2>&1
    call :record mssql/!DB! "%OUT%\mssql\!DB!.bak"
  )
)
exit /b 0

:usage
echo usage: lds backup [--only mysql,mariadb,postgres,mongo,redis,valkey,mssql]
echo                    [--out DIR] [--keep N] [--list]
goto end

:fail
popd >nul 2>&1
endlocal
exit /b 1

:end
popd >nul 2>&1
endlocal
exit /b 0
