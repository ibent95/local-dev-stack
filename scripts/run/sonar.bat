@echo off
REM Scan a project with SonarQube and push the report to the server.
REM   lds tools sonar [path] [project-key]   scan a folder (default: current dir)
REM   lds tools sonar token                  (re)create the cached scanner token
REM The SERVER must be running: lds up sonarqube (UI at http://sonarqube.test /
REM http://localhost:4544). The scanner is the pinned sonarsource/sonar-scanner-cli
REM image (same tag as the sonar-scanner compose service), run against the server
REM as http://sonarqube:9000 over the shared lds-network.
REM
REM Token handling: a scanner token is REQUIRED (unauthenticated analysis was
REM removed in SonarQube 26.10). The wrapper resolves one in this order:
REM   1. SONAR_TOKEN (env / .env)  - used only if THIS server accepts it
REM   2. data\sonarqube\token      - the cached token, same check
REM   3. bootstrap via the Web API - admin form login (SONAR_ADMIN_USER /
REM      SONAR_ADMIN_PASSWORD, default admin/admin) + session cookie +
REM      X-XSRF-TOKEN header, then user_tokens/generate (newer SonarQube removed
REM      password basic auth; older servers fall back to it)
REM Stale/foreign values (e.g. a global SONAR_TOKEN pointing at another server)
REM are ignored with a warning. If the admin password was changed in the UI,
REM either set SONAR_ADMIN_PASSWORD in .env (12+ chars incl. an uppercase
REM letter), put a token from My Account -> Security into .env as
REM SONAR_TOKEN=..., save it to data\sonarqube\token, or restore admin/admin
REM with:  lds tools sonar reset.
REM Load .env with delayed expansion OFF so values containing `!` (passwords)
REM survive intact; re-enable it afterwards for the !VAR! loops below.
setlocal disabledelayedexpansion
set "SUB=%~1"
set "TARGET=%~1"
set "KEY=%~2"
REM Remember a SONAR_PROJECT_KEY inherited from the shell environment (it would
REM beat .env in the loader below), then clear it so ONLY .env can supply the
REM key: long-lived terminals keep a stale copy for days, and a stale global
REM value would silently retarget every scan. Flagged after the key is resolved.
set "AMBIENT_KEY="
if defined SONAR_PROJECT_KEY set "AMBIENT_KEY=%SONAR_PROJECT_KEY%"
set "SONAR_PROJECT_KEY="

pushd "%~dp0..\.."
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
setlocal enabledelayedexpansion
if "%SONARQUBE_HOST%"=="" set "SONARQUBE_HOST=sonarqube.test"
if "%SONARQUBE_HOST_PORT%"=="" set "SONARQUBE_HOST_PORT=4544"
if "%SONAR_ADMIN_USER%"=="" set "SONAR_ADMIN_USER=admin"
if "%SONAR_ADMIN_PASSWORD%"=="" set "SONAR_ADMIN_PASSWORD=admin"
if "%SONAR_TOKEN_NAME%"=="" set "SONAR_TOKEN_NAME=lds-scanner"
if "%SONARQUBE_POSTGRES_DB%"=="" set "SONARQUBE_POSTGRES_DB=lds_sonarqube"
if "%SONARQUBE_POSTGRES_USER%"=="" set "SONARQUBE_POSTGRES_USER=app"
if "%SONAR_SCANNER_IMAGE%"=="" set "SONAR_SCANNER_IMAGE=sonarsource/sonar-scanner-cli"
if "%SONAR_SCANNER_VERSION%"=="" set "SONAR_SCANNER_VERSION=12.2.0.4256_8.1.0"
if "%NETWORK_NAME%"=="" (set "NET=lds-network") else (set "NET=%NETWORK_NAME%")
set "BASE=http://127.0.0.1:%SONARQUBE_HOST_PORT%"
set "TOKEN_FILE=%CD%\data\sonarqube\token"

REM --- `reset` subcommand: restore admin/admin (documented recovery query).
REM Runs before the server wait loop - only the postgres container is needed.
if /I "%SUB%"=="reset" (
  echo Restoring the SonarQube admin password to 'admin' ^(documented recovery query^)...
  docker exec lds-postgres psql -U %SONARQUBE_POSTGRES_USER% -d %SONARQUBE_POSTGRES_DB% -c "update users set crypted_password='100000$t2h8AtNs1AlCHuLobDjHQTn9XppwTIx88UjqUm4s8RsfTuXQHSd/fpFexAnewwPsO6jGFQUv/24DnO55hY6Xew==', salt='k9x9eN127/3e/hf38iNiKwVfaVk=', hash_method='PBKDF2', reset_password='false', user_local='true', active='true' where login='admin';"
  if errorlevel 1 ( echo error: could not update the database - is the postgres container running? & popd & endlocal & exit /b 1 )
  if exist "%TOKEN_FILE%" del "%TOKEN_FILE%"
  echo Done. Admin login is 'admin' again and the cached scanner token was removed.
  echo ^(the next scan recreates it.^)
  if not "%SONAR_ADMIN_PASSWORD%"=="admin" echo note: .env sets SONAR_ADMIN_PASSWORD - run  lds up sonarqube  to apply it via the API.
  popd & endlocal & exit /b 0
)

REM --- wait for the server (up to ~2 min: first boot migrates the DB + starts ES)
set "UP="
for /l %%i in (1,1,60) do (
  if not defined UP (
    set "ST="
    for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri '%BASE%/api/system/status' -TimeoutSec 5).status } catch { 'DOWN' }"`) do set "ST=%%s"
    if /I "!ST!"=="UP" (set "UP=1") else (ping -n 3 127.0.0.1 >nul)
  )
)

if /I "%SUB%"=="token" (
  if not defined UP (
    echo SonarQube is not answering at %BASE% - start it with:  lds up sonarqube
    popd & endlocal & exit /b 1
  )
  echo Re-creating scanner token '%SONAR_TOKEN_NAME%' ^(cached in data\sonarqube\token^)...
  call :gentoken
  if errorlevel 1 ( popd & endlocal & exit /b 1 )
  echo Token stored in data\sonarqube\token.
  popd & endlocal & exit /b 0
)

REM Resolve TARGET to an ABSOLUTE path against the caller's cwd BEFORE pushd
REM (docker -v needs an absolute source).
for %%I in ("%TARGET%") do set "TARGET=%%~fI"
if not exist "%TARGET%" (
  echo Target not found: %TARGET%
  echo Pass a path to scan, e.g.  lds tools sonar D:\projects\PHP\svc-setting-lumen
  popd & endlocal & exit /b 1
)

REM Project key: [key] arg > SONAR_PROJECT_KEY (from .env only) > sanitized
REM folder name. A value inherited from the shell environment was cleared above
REM and is only reported below - old terminals keep a stale copy for days and
REM would otherwise silently retarget every scan.
if not defined KEY if defined SONAR_PROJECT_KEY set "KEY=%SONAR_PROJECT_KEY%"
if not defined KEY for /f "usebackq delims=" %%k in (`powershell -NoProfile -Command "$n=(Split-Path -Leaf '%TARGET%').ToLower() -replace '[^a-z0-9_.:-]','-' -replace '^[^a-z0-9]*',''; if(-not $n){$n='lds-scan-'+(Get-Date -Format yyyyMMddHHmmss)}; $n"`) do set "KEY=%%k"
if "%~2"=="" if not "%AMBIENT_KEY%"=="" if /I not "%AMBIENT_KEY%"=="%KEY%" (
  echo note: ignoring SONAR_PROJECT_KEY inherited from the shell environment ^("%AMBIENT_KEY%"^).
  echo       using "%KEY%" as the project key ^(pass [project-key] or set SONAR_PROJECT_KEY in .env to pin it^).
  echo       old terminals keep a stale environment block - reopen them or reboot to clear it.
)

REM Token resolution: a value the server actually accepts - SONAR_TOKEN (env /
REM .env) > cached file > created via the API. Stale/foreign values (a global
REM SONAR_TOKEN for another server, an old cached token) are ignored with a
REM warning instead of failing the scan.
set "TOKEN="
if defined SONAR_TOKEN (
  set "CAND=%SONAR_TOKEN%"
  call :validatetoken
  if "!VALID!"=="yes" set "TOKEN=!SONAR_TOKEN!"
  if "!VALID!"=="no" echo warning: the SONAR_TOKEN in the environment is not accepted by this SonarQube server - ignoring it.
)
if not defined TOKEN if exist "%TOKEN_FILE%" (
  set /p CAND=<"%TOKEN_FILE%"
  call :validatetoken
  if "!VALID!"=="yes" set "TOKEN=!CAND!"
  if "!VALID!"=="no" echo warning: the cached token in data\sonarqube\token is stale - recreating it.
)
if not defined TOKEN (
  if not defined UP (
    echo SonarQube is not answering at %BASE% - start it with:  lds up sonarqube
    popd & endlocal & exit /b 1
  )
  echo No valid scanner token - creating '%SONAR_TOKEN_NAME%' via the Web API ^(admin login^)...
  call :gentoken
  if errorlevel 1 ( popd & endlocal & exit /b 1 )
)

REM Scanner args: sonar.sources is passed exactly once (the scanner rejects
REM duplicated properties).
if "%SONAR_SOURCES%"=="" set "SONAR_SOURCES=."
set "ARGS=-Dsonar.projectKey=%KEY% -Dsonar.projectName=%KEY% -Dsonar.sources=%SONAR_SOURCES%"
if defined SONAR_EXCLUSIONS set "ARGS=!ARGS! -Dsonar.exclusions=%SONAR_EXCLUSIONS%"
if /I "%SONAR_QUALITYGATE_WAIT%"=="1" set "ARGS=!ARGS! -Dsonar.qualitygate.wait=true"

REM Static, unique container name (timestamp + centiseconds).
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmssff"') do set "TS=%%i"
set "SCAN_NAME=lds-sonar-scan-!TS!"
echo Scanning %TARGET% with SonarQube ^(project key: %KEY%^) - container !SCAN_NAME!...
docker run --rm --name !SCAN_NAME! --network %NET% ^
  -e SONAR_HOST_URL=http://sonarqube:9000 ^
  -e SONAR_TOKEN=%TOKEN% ^
  -v "%TARGET%:/usr/src" -w /usr/src ^
  %SONAR_SCANNER_IMAGE%:%SONAR_SCANNER_VERSION% ^
  !ARGS!
set "RC=!errorlevel!"

if "!RC!"=="0" goto scanok
echo note: scanner exited with code !RC! ^(3 = quality gate failed when SONAR_QUALITYGATE_WAIT=1^).
echo       the analysis may still be on the server - check the project URL below.
popd
endlocal & exit /b %RC%
:scanok

echo Done. View the project at http://%SONARQUBE_HOST%/dashboard?id=%KEY%
echo ^(direct fallback: http://localhost:%SONARQUBE_HOST_PORT%/dashboard?id=%KEY%^)
popd
endlocal
exit /b 0

REM --- does this server accept the token in CAND? sets VALID=yes|no|unknown --
:validatetoken
set "VALID=unknown"
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "try { if ((Invoke-RestMethod -Uri '%BASE%/api/authentication/validate' -Headers @{Authorization=('Bearer '+$env:CAND)} -TimeoutSec 8).valid) { 'yes' } else { 'no' } } catch { 'unknown' }"`) do set "VALID=%%v"
exit /b 0

REM --- create the scanner token via the Web API ------------------------------
REM Newer SonarQube removed password basic auth: log in (form), keep the session
REM cookie + X-XSRF-TOKEN header, then call user_tokens/generate. Falls back to
REM basic auth for older servers. Always revokes the existing token first.
:gentoken
set "TOKEN="
  for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "try { $s=New-Object Microsoft.PowerShell.Commands.WebRequestSession; $r=Invoke-WebRequest -Uri '%BASE%/api/authentication/login' -Method Post -Body @{login=$env:SONAR_ADMIN_USER;password=$env:SONAR_ADMIN_PASSWORD} -WebSession $s -UseBasicParsing -TimeoutSec 15; $x=[string]$r.Headers['X-XSRF-TOKEN']; try { Invoke-RestMethod -Uri '%BASE%/api/user_tokens/revoke?name=%SONAR_TOKEN_NAME%' -Method Post -WebSession $s -Headers @{'X-XSRF-TOKEN'=$x} -TimeoutSec 15 | Out-Null } catch { }; $g=Invoke-RestMethod -Uri '%BASE%/api/user_tokens/generate?name=%SONAR_TOKEN_NAME%' -Method Post -WebSession $s -Headers @{'X-XSRF-TOKEN'=$x} -TimeoutSec 30; $g.token } catch { exit 1 }"`) do set "TOKEN=%%t"
if not defined TOKEN for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "try { $b=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($env:SONAR_ADMIN_USER+':'+$env:SONAR_ADMIN_PASSWORD)); Invoke-RestMethod -Uri '%BASE%/api/user_tokens/revoke?name=%SONAR_TOKEN_NAME%' -Method Post -Headers @{Authorization=('Basic '+$b)} -TimeoutSec 15 | Out-Null } catch { }; try { $b=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($env:SONAR_ADMIN_USER+':'+$env:SONAR_ADMIN_PASSWORD)); (Invoke-RestMethod -Uri '%BASE%/api/user_tokens/generate?name=%SONAR_TOKEN_NAME%' -Method Post -Headers @{Authorization=('Basic '+$b)} -TimeoutSec 30).token } catch { exit 1 }"`) do set "TOKEN=%%t"
if not defined TOKEN (
  echo error: could not create the scanner token ^(admin login failed or the name is taken^).
  echo        - check SONAR_ADMIN_USER/SONAR_ADMIN_PASSWORD in .env ^(custom passwords need 12+ chars incl. an uppercase letter^)
  echo        - or create a token in the UI ^(My Account -^> Security^) and either set
  echo          SONAR_TOKEN=... in .env or save it to data\sonarqube\token
  echo        - if you are locked out, restore the default with:  lds tools sonar reset
  exit /b 1
)
if not exist "%CD%\data\sonarqube" mkdir "%CD%\data\sonarqube"
> "%TOKEN_FILE%" ( <nul set /p "=%TOKEN%" )
exit /b 0
