@echo off
REM ===========================================================================
REM Restore an `lds backup` folder back into the running stack.
REM   lds restore [<folder>] [--only mysql,postgres,...] [--yes]
REM
REM Windows counterpart of scripts/run/restore.sh. Reads the folder's
REM manifest.tsv, so a folder made on EITHER platform works: .gz dumps are
REM unpacked with the bundled bsdtar (Windows 10 1803+) when needed.
REM THIS OVERWRITES CURRENT DATA.
REM ===========================================================================
setlocal EnableDelayedExpansion
set "ROOT=%~dp0..\.."
pushd "%ROOT%" >nul 2>&1
set "BACKUP_ROOT=%ROOT%data\backups"
if not "%BACKUP_DIR%"=="" set "BACKUP_ROOT=%BACKUP_DIR%"
set "SRC="
set "ONLY="
set "YES=0"

:parse
if "%~1"=="" goto parsed
if /I "%~1"=="--only" ( set "ONLY=%~2" & shift & shift & goto parse )
if /I "%~1"=="--yes"  ( set "YES=1" & shift & goto parse )
if /I "%~1"=="-y"     ( set "YES=1" & shift & goto parse )
if /I "%~1"=="-h"     goto usage
if /I "%~1"=="--help" goto usage
if "%~1"=="" goto parsed
set "SRC=%~1" & shift & goto parse

:parsed
if "%SRC%"=="" (
  for /f "delims=" %%d in ('dir /b /ad /o-n "%BACKUP_ROOT%" 2^>nul') do (
    if "!SRC!"=="" set "SRC=%BACKUP_ROOT%\%%d"
  )
)
if "%SRC%"=="" ( echo no backups in %BACKUP_ROOT% - run 'lds backup' first & goto fail )
if not exist "%SRC%" if exist "%BACKUP_ROOT%\%SRC%" set "SRC=%BACKUP_ROOT%\%SRC%"
if not exist "%SRC%\manifest.tsv" ( echo %SRC% has no manifest.tsv - not an lds backup & goto fail )

echo.
echo Restore source: %SRC%
type "%SRC%\manifest.tsv"
echo.
echo This overwrites data in the running stack.
if not "%YES%"=="1" (
  set /p "ANSWER=Type restore to continue: "
  if /I not "!ANSWER!"=="restore" ( echo aborted & goto fail )
)

set "FAILED=0"
call :wants postgres && call :restore_postgres
call :wants mysql    && call :restore_mysql
call :wants mariadb  && call :restore_mariadb
call :wants mongo    && call :restore_mongo
call :wants redis    && call :restore_rdb redis lds-redis
call :wants valkey   && call :restore_rdb valkey lds-valkey
call :wants mssql    && call :restore_mssql

echo.
if not "%FAILED%"=="0" ( echo   %FAILED% engine^(s^) failed & goto fail )
echo   restore complete. Restart the affected services: lds restart ^<profile^>
goto end

REM ---------------------------------------------------------------------------
:wants
if "%ONLY%"=="" exit /b 0
echo ,%ONLY%, | findstr /I /C:",%~1," >nul && exit /b 0
exit /b 1

:file_for
set "FF="
for /f "usebackq tokens=1,2 delims=	" %%a in ("%SRC%\manifest.tsv") do if /I "%%a"=="%~1" if "!FF!"=="" set "FF=%%b"
exit /b 0

:prep
REM Set DUMP to a host-readable uncompressed file (unpacks .gz via bsdtar).
set "DUMP=%SRC%\%~1"
if /I "%~x1"==".gz" (
  set "DUMP=%TEMP%\lds-restore-%~n1"
  tar -xOzf "%SRC%\%~1" >"!DUMP!" 2>nul || ( echo   fail   cannot unpack %~1 & set /a FAILED+=1 & exit /b 1 )
)
exit /b 0

:restore_postgres
call :file_for postgres
if "%FF%"=="" ( echo   skip   postgres ^(not in this backup^) & exit /b 0 )
call :prep "%FF%" || exit /b 0
docker exec lds-postgres sh -c "exit 0" >nul 2>&1 || ( echo   fail   postgres not running & set /a FAILED+=1 & exit /b 0 )
echo   postgres ^<- %FF%
type "!DUMP!" | docker exec -i lds-postgres psql -U app -d postgres -v ON_ERROR_STOP=0 -q >nul 2>&1
if errorlevel 1 ( echo   fail   postgres & set /a FAILED+=1 ) else ( echo   ok     postgres )
exit /b 0

:restore_mysql
call :file_for mysql
if "%FF%"=="" ( echo   skip   mysql ^(not in this backup^) & exit /b 0 )
call :prep "%FF%" || exit /b 0
echo   mysql ^<- %FF%
type "!DUMP!" | docker exec -i lds-mysql sh -c "exec mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\"" >nul 2>&1
if errorlevel 1 ( echo   fail   mysql & set /a FAILED+=1 ) else ( echo   ok     mysql )
exit /b 0

:restore_mariadb
call :file_for mariadb
if "%FF%"=="" ( echo   skip   mariadb ^(not in this backup^) & exit /b 0 )
call :prep "%FF%" || exit /b 0
echo   mariadb ^<- %FF%
type "!DUMP!" | docker exec -i lds-mariadb sh -c "exec mysql -uroot -p\"$MARIADB_ROOT_PASSWORD\"" >nul 2>&1
if errorlevel 1 ( echo   fail   mariadb & set /a FAILED+=1 ) else ( echo   ok     mariadb )
exit /b 0

:restore_mongo
call :file_for mongo
if "%FF%"=="" ( echo   skip   mongo ^(not in this backup^) & exit /b 0 )
echo   mongo ^<- %FF%
type "%SRC%\%FF%" | docker exec -i lds-mongo sh -c "exec mongorestore --drop --archive --gzip --uri=\"mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@localhost:27017/?authSource=admin\"" >nul 2>&1
if errorlevel 1 ( echo   fail   mongo & set /a FAILED+=1 ) else ( echo   ok     mongo )
exit /b 0

:restore_rdb
call :file_for %~1
if "%FF%"=="" ( echo   skip   %~1 ^(not in this backup^) & exit /b 0 )
echo   %~1 ^<- %FF% ^(stopping %~2 to swap dump.rdb^)
docker stop %~2 >nul 2>&1
docker cp "%SRC%\%FF%" "%~2:/data/dump.rdb" >nul 2>&1
if errorlevel 1 ( set /a FAILED+=1 & echo   fail   %~1 ) else ( echo   ok     %~1 )
docker start %~2 >nul 2>&1
exit /b 0

:restore_mssql
for /f "usebackq tokens=1,2 delims=	" %%a in ("%SRC%\manifest.tsv") do (
  if /I "%%a"=="mssql/%%~na" set "_X=1"
)
set "FOUND=0"
for /f "usebackq tokens=1,2 delims=	" %%a in ("%SRC%\manifest.tsv") do (
  echo %%a | findstr /I /B "mssql/" >nul && (
    set "FOUND=1"
    set "DB=%%~nb"
    set "BAK=%%b"
    echo   mssql/!DB! ^<- !BAK!
    docker cp "%SRC%\!BAK!" "lds-mssql:/var/opt/mssql/backup/!DB!.bak" >nul 2>&1
    docker exec lds-mssql sh -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"$MSSQL_SA_PASSWORD\" -C -Q \"RESTORE DATABASE [!DB!] FROM DISK='/var/opt/mssql/backup/!DB!.bak' WITH REPLACE\"" >nul 2>&1
    if errorlevel 1 ( echo   fail   mssql/!DB! & set /a FAILED+=1 ) else ( echo   ok     mssql/!DB! )
  )
)
if "%FOUND%"=="0" echo   skip   mssql ^(not in this backup^)
exit /b 0

:usage
echo usage: lds restore [^<folder^>] [--only mysql,mariadb,postgres,mongo,redis,valkey,mssql] [--yes]
goto end

:fail
popd >nul 2>&1
endlocal
exit /b 1

:end
popd >nul 2>&1
endlocal
exit /b 0
