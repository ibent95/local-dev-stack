@echo off
REM OpenVAS / Greenbone Community Edition companion - OUTSIDE the main stack
REM (not a profile; managed by this command only).  (lds openvas <sub>)
REM   lds openvas start|up [svc...]    start (UI http://127.0.0.1:9392, admin/admin)
REM   lds openvas stop|down [svc...]   stop + remove containers (data kept in data\openvas)
REM   lds openvas restart [svc...]     restart services
REM   lds openvas logs [svc...]        logs (first boot syncs feeds: 20-60+ min)
REM   lds openvas ps [svc...]          status
REM   lds openvas pull [svc...]        pre-pull the 18 images
REM When the main stack's networks exist, an overlay is applied automatically:
REM the web container joins lds-network (served at openvas.test via the LDS proxy)
REM and the scanner joins lds-network + lds-dnsnet so *.test names resolve to the
REM proxy from inside. Heavy: ~4+ GB RAM, multi-GB images, long first feed sync.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."
set "CMD=%~1"
set "REST="
shift
:collect
if "%~1"=="" goto dispatch
set "REST=%REST% %~1"
shift
goto collect

:dispatch
set "FILES=-f configs\openvas\compose.yaml"
set "ENVF="
if exist ".env" set "ENVF=--env-file .env"
docker network inspect lds-network >nul 2>&1 && docker network inspect lds-dnsnet >nul 2>&1 && (
  set "FILES=!FILES! -f configs\openvas\compose.lds.yml"
  echo LDS overlay enabled ^(openvas.test via the proxy + *.test DNS for scans^).
)
if not "!FILES!"=="-f configs\openvas\compose.yaml" goto files_done
echo note: lds-network/lds-dnsnet not found - starting without the LDS overlay.
echo       ^(start the main stack first, e.g. 'lds up proxy', then 'lds openvas restart'^)
:files_done

if /I "%CMD%"=="start" (
  docker compose !FILES! !ENVF! up -d !REST!
  echo.
  echo OpenVAS UI:  http://localhost:9392  ^(login admin/admin^)
  echo              http://openvas.test    ^(via the LDS proxy, when the overlay is on^)
  echo First boot syncs the vulnerability feeds - watch: lds openvas logs
  goto end
)
if /I "%CMD%"=="up"      ( docker compose !FILES! !ENVF! up -d !REST! & goto end )
if /I "%CMD%"=="stop"    ( docker compose !FILES! !ENVF! down !REST! & goto end )
if /I "%CMD%"=="down"    ( docker compose !FILES! !ENVF! down !REST! & goto end )
if /I "%CMD%"=="restart" ( docker compose !FILES! !ENVF! restart !REST! & goto end )
if /I "%CMD%"=="logs"    ( docker compose !FILES! !ENVF! logs !REST! & goto end )
if /I "%CMD%"=="ps"      ( docker compose !FILES! !ENVF! ps !REST! & goto end )
if /I "%CMD%"=="pull"    ( docker compose !FILES! !ENVF! pull !REST! & goto end )

echo usage: lds openvas ^<start^|stop^|restart^|logs^|ps^|pull^> [service...]
goto end

:end
popd
endlocal
