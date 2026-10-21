@echo off
REM Ensure Postgres has the SonarQube database/user by augmenting
REM POSTGRES_INIT_SPECS for this run, then delegating to postgres-init.bat.
REM SonarQube creates its own schema on first boot - only the (empty) DB +
REM owner role are provisioned here.
REM Idempotent; auto-run by `lds up` for sonarqube/all.
REM Load .env with delayed expansion OFF so values containing `!` (passwords)
REM survive intact; re-enable it afterwards for the !VAR! loops below.
setlocal disabledelayedexpansion
pushd "%~dp0..\.."

if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
setlocal enabledelayedexpansion
if "%SONARQUBE_POSTGRES_DB%"=="" set "SONARQUBE_POSTGRES_DB=lds_sonarqube"
if "%SONARQUBE_POSTGRES_USER%"=="" set "SONARQUBE_POSTGRES_USER=app"
if "%SONARQUBE_POSTGRES_PASSWORD%"=="" set "SONARQUBE_POSTGRES_PASSWORD=app"
set "SPEC=%SONARQUBE_POSTGRES_DB%:%SONARQUBE_POSTGRES_USER%:%SONARQUBE_POSTGRES_PASSWORD%"

if "%POSTGRES_INIT_SPECS%"=="" (
  set "POSTGRES_INIT_SPECS=%SPEC%"
) else (
  echo %POSTGRES_INIT_SPECS% | findstr /I /C:"%SPEC%" >nul || set "POSTGRES_INIT_SPECS=%POSTGRES_INIT_SPECS%,%SPEC%"
)

call "%~dp0postgres-init.bat"

REM --- reconcile the admin password with .env --------------------------------
REM A scanner token needs an admin login, and 26.10 removed password basic auth
REM (form login + session cookie + X-XSRF-TOKEN header). If the DB still has
REM the default 'admin' and SONAR_ADMIN_PASSWORD says something else, apply it
REM now - that also skips the UI's forced first-login password change. The
REM password policy needs 12+ chars incl. an uppercase letter. Warn (never fail `up`) on drift.
if "%SONARQUBE_HOST_PORT%"=="" set "SONARQUBE_HOST_PORT=4544"
if "%SONAR_ADMIN_USER%"=="" set "SONAR_ADMIN_USER=admin"
if "%SONAR_ADMIN_PASSWORD%"=="" set "SONAR_ADMIN_PASSWORD=admin"
set "BASE=http://127.0.0.1:%SONARQUBE_HOST_PORT%"

set "ST="
for /l %%i in (1,1,90) do (
  if not "!ST!"=="UP" (
    set "ST="
    for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri '%BASE%/api/system/status' -TimeoutSec 5).status } catch { 'DOWN' }"`) do set "ST=%%s"
    if /I not "!ST!"=="UP" ping -n 3 127.0.0.1 >nul
  )
)
if /I not "!ST!"=="UP" (
  echo note: SonarQube is not answering yet - skipping the admin-password check ^(it runs again on the next:  lds up sonarqube^).
  popd & endlocal & exit /b 0
)

powershell -NoProfile -Command "$ErrorActionPreference='Stop'; function Try-Login([string]$pw){ try { $s=New-Object Microsoft.PowerShell.Commands.WebRequestSession; $r=Invoke-WebRequest -Uri '%BASE%/api/authentication/login' -Method Post -Body @{login=$env:SONAR_ADMIN_USER;password=$pw} -WebSession $s -UseBasicParsing -TimeoutSec 15; $script:x=[string]$r.Headers['X-XSRF-TOKEN']; return $s } catch { return $null } }; $s=Try-Login $env:SONAR_ADMIN_PASSWORD; if ($s) { exit 0 }; $s2=Try-Login 'admin'; if (-not $s2) { exit 2 }; try { Invoke-RestMethod -Uri '%BASE%/api/users/change_password' -Method Post -Body @{login=$env:SONAR_ADMIN_USER;previousPassword='admin';password=$env:SONAR_ADMIN_PASSWORD} -WebSession $s2 -Headers @{'X-XSRF-TOKEN'=$script:x} -TimeoutSec 15 | Out-Null; exit 3 } catch { exit 4 }"
set "RC=!errorlevel!"
if "!RC!"=="0" echo SonarQube: admin login '%SONAR_ADMIN_USER%' verified.
if "!RC!"=="3" echo SonarQube: admin password set from SONAR_ADMIN_PASSWORD ^(was the default 'admin'^).
if "!RC!"=="4" echo warning: SonarQube refused SONAR_ADMIN_PASSWORD ^(the password policy needs 12+ chars incl. an uppercase letter^) - adjust it in .env and re-run:  lds up sonarqube
if "!RC!"=="2" echo warning: could not log in as '%SONAR_ADMIN_USER%' with SONAR_ADMIN_PASSWORD nor with the default 'admin'.
if "!RC!"=="2" echo          update SONAR_ADMIN_PASSWORD in .env to the current password, or restore admin/admin:  lds tools sonar reset
if "!RC!"=="1" echo warning: SonarQube admin-password check errored unexpectedly.

popd
endlocal
