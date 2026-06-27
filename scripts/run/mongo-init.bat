@echo off
REM Initiate the single-node replica set (rs0) and ensure users exist. Handles
REM both a fresh DB (localhost exception) and one where users already exist
REM (authenticated). Idempotent; auto-run by `lds up` for the mongo/all profile.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%MONGO_ROOT_USERNAME%"=="" set "MONGO_ROOT_USERNAME=root"
if "%MONGO_ROOT_PASSWORD%"=="" set "MONGO_ROOT_PASSWORD=root"
if "%MONGO_USER%"=="" set "MONGO_USER=app"
if "%MONGO_PASSWORD%"=="" set "MONGO_PASSWORD=app"
if "%MONGO_DATABASE%"=="" set "MONGO_DATABASE=app"
set "C=lds-mongo"
set "U=%MONGO_ROOT_USERNAME%"
set "P=%MONGO_ROOT_PASSWORD%"
set "AU=%MONGO_USER%"
set "AP=%MONGO_PASSWORD%"
set "DB=%MONGO_DATABASE%"
set "RS={_id:'rs0', members:[{_id:0, host:'mongo:27017'}]}"
set "AUTHFLAGS=-u %U% -p %P% --authenticationDatabase admin"

REM Wait for mongod.
set "READY="
for /l %%i in (1,1,30) do (
  if not defined READY (
    docker exec %C% mongosh --quiet --eval "db.adminCommand('ping').ok" >nul 2>&1 && set "READY=1" || ping -n 3 127.0.0.1 >nul
  )
)
if not defined READY ( echo mongod not reachable - is the mongo profile up? & popd & endlocal & exit /b 1 )

REM Do valid root credentials already work?
set "RUN=noauth"
for /f %%o in ('docker exec %C% mongosh --quiet %AUTHFLAGS% --eval "db.runCommand({connectionStatus:1}).authInfo.authenticatedUsers.length" 2^>nul') do if "%%o"=="1" set "RUN=auth"

if "%RUN%"=="auth" ( set "FLAGS=%AUTHFLAGS%" & echo Root user present - configuring replica set ^(authenticated^)... ) else ( set "FLAGS=" & echo Fresh DB - configuring replica set + users ^(localhost exception^)... )

REM Initiate the replica set (tolerate an already-initiated set).
docker exec %C% mongosh --quiet !FLAGS! --eval "try { rs.initiate(%RS%) } catch (e) { if (!/already initialized/i.test(e.message)) throw e }"

REM Wait for PRIMARY.
set "PRIMARY="
for /l %%i in (1,1,60) do (
  if not defined PRIMARY (
    for /f %%p in ('docker exec %C% mongosh --quiet !FLAGS! --eval "db.hello().isWritablePrimary" 2^>nul') do if "%%p"=="true" set "PRIMARY=1"
    if not defined PRIMARY ping -n 2 127.0.0.1 >nul
  )
)

REM On a fresh DB, create the root user (localhost exception).
if "%RUN%"=="noauth" (
  echo Creating root user %U%...
  docker exec %C% mongosh --quiet --eval "db.getSiblingDB('admin').createUser({user:'%U%', pwd:'%P%', roles:['root']})"
)

echo Ensuring app user %AU% on %DB%...
docker exec %C% mongosh --quiet %AUTHFLAGS% --eval "if (!db.getSiblingDB('%DB%').getUser('%AU%')) { db.getSiblingDB('%DB%').createUser({user:'%AU%', pwd:'%AP%', roles:[{role:'readWrite', db:'%DB%'}]}) }" >nul 2>&1

REM Materialize the `app` database so it shows up by default (Mongo is lazy).
docker exec %C% mongosh --quiet %AUTHFLAGS% --eval "try { db.getSiblingDB('%DB%').createCollection('_init') } catch (e) {}" >nul 2>&1

echo Mongo replica set ready (rs0).
popd
endlocal
