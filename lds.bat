@echo off
REM ===========================================================================
REM local-dev-stack — single entrypoint that unites every script.
REM   lds.bat <command> [args]
REM ===========================================================================
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "CMD=%~1"
if "%CMD%"=="" set "CMD=help"

REM collect all args after the command into REST
set "REST="
shift
:collect
if "%~1"=="" goto dispatch
set "REST=%REST% %~1"
shift
goto collect

:dispatch
if /I "%CMD%"=="kafka"               goto kafka
if /I "%CMD%"=="db"                  goto db
if /I "%CMD%"=="tools"               goto tools
if /I "%CMD%"=="init"                call "%ROOT%scripts\run\init.bat" %REST% & goto end
if /I "%CMD%"=="network"             call "%ROOT%scripts\run\network.bat" %REST% & goto end
if /I "%CMD%"=="new"                 call "%ROOT%scripts\run\new.bat" %REST% & goto end
if /I "%CMD%"=="app"                 call "%ROOT%scripts\run\app.bat" %REST% & goto end
if /I "%CMD%"=="build-bases"         call "%ROOT%scripts\build\build-bases.bat" %REST% & goto end
if /I "%CMD%"=="build-php"           call "%ROOT%scripts\build\build-php.bat" %REST% & goto end
if /I "%CMD%"=="up"                  call "%ROOT%scripts\run\up.bat" %REST% & goto end
if /I "%CMD%"=="down"                call "%ROOT%scripts\run\down.bat" %REST% & goto end
if /I "%CMD%"=="stop"                call "%ROOT%scripts\run\stop.bat" %REST% & goto end
if /I "%CMD%"=="rm"                  call "%ROOT%scripts\run\rm.bat" %REST% & goto end
if /I "%CMD%"=="start"               call "%ROOT%scripts\run\start.bat" %REST% & goto end
if /I "%CMD%"=="logs"                call "%ROOT%scripts\run\logs.bat" %REST% & goto end
if /I "%CMD%"=="kafka-topics"        call "%ROOT%scripts\run\kafka-topics.bat" %REST% & goto end
if /I "%CMD%"=="mysql-init"          call "%ROOT%scripts\run\mysql-init.bat" %REST% & goto end
if /I "%CMD%"=="mongo-init"          call "%ROOT%scripts\run\mongo-init.bat" %REST% & goto end
if /I "%CMD%"=="dbgate-seed"         call "%ROOT%scripts\run\dbgate-seed.bat" %REST% & goto end
if /I "%CMD%"=="certs"               call "%ROOT%scripts\run\certs.bat" %REST% & goto end
if /I "%CMD%"=="register-connectors" call "%ROOT%scripts\run\register-connectors.bat" %REST% & goto end
if /I "%CMD%"=="connect-plugin"      call "%ROOT%scripts\run\connect-plugin.bat" %REST% & goto end
if /I "%CMD%"=="hosts-sync"          call "%ROOT%scripts\run\hosts-sync.bat" %REST% & goto end
if /I "%CMD%"=="ps"                  ( pushd "%ROOT%" & docker compose --profile "*" ps & popd ) & goto end
if /I "%CMD%"=="exec"                call "%ROOT%scripts\run\exec.bat" %REST% & goto end
if /I "%CMD%"=="help"                goto help
if /I "%CMD%"=="-h"                  goto help
if /I "%CMD%"=="--help"              goto help
echo Unknown command: %CMD%
goto help

:kafka
for /f "tokens=1*" %%a in ("%REST%") do ( set "SUB=%%a" & set "SUBREST=%%b" )
if /I "!SUB!"=="topics"              ( call "%ROOT%scripts\run\kafka-topics.bat" !SUBREST! & goto end )
if /I "!SUB!"=="connect-plugin"      ( call "%ROOT%scripts\run\connect-plugin.bat" !SUBREST! & goto end )
if /I "!SUB!"=="register-connectors" ( call "%ROOT%scripts\run\register-connectors.bat" !SUBREST! & goto end )
if /I "!SUB!"=="init"                ( call "%ROOT%scripts\run\kafka-topics.bat" & call "%ROOT%scripts\run\register-connectors.bat" !SUBREST! & goto end )
echo usage: lds kafka ^<topics ^| connect-plugin [--generic^|--debezium] ^<name^> ^| register-connectors ^| init^>
goto end

:db
for /f "tokens=1*" %%a in ("%REST%") do ( set "SUB=%%a" & set "SUBREST=%%b" )
if /I "!SUB!"=="init" (
  set "WHICH=!SUBREST: =!"
  if /I "!WHICH!"=="mysql" ( call "%ROOT%scripts\run\mysql-init.bat" & goto end )
  if /I "!WHICH!"=="mongo" ( call "%ROOT%scripts\run\mongo-init.bat" & goto end )
  call "%ROOT%scripts\run\mysql-init.bat" & call "%ROOT%scripts\run\mongo-init.bat" & goto end
)
if /I "!SUB!"=="seed"                ( call "%ROOT%scripts\run\dbgate-seed.bat" & goto end )
echo usage: lds db ^<init [mysql^|mongo^|all] ^| seed^>
goto end

:tools
for /f "tokens=1*" %%a in ("%REST%") do ( set "SUB=%%a" & set "SUBREST=%%b" )
if /I "!SUB!"=="semgrep" ( call "%ROOT%scripts\run\semgrep.bat" !SUBREST! & goto end )
echo usage: lds tools ^<semgrep [path]^>
goto end

:help
echo local-dev-stack - usage: lds.bat ^<command^> [args]
echo.
echo   init                          create the shared lds-network network (run once)
echo   new ^<type^> ^<name^> [host]      scaffold a project (php ^| ^<tech^> ^| svc-/web-^<tech^>)
echo   app ^<start^|stop^|restart^|logs^|ps^> [dir]  manage an svc/web project (dir=.)
echo   network [status^|create^|rm^|reset]  manage the shared lds-network
echo   build-bases [--force^|--push]  build the lds/* base images
echo   up [profiles...]              start profiles (default: LDS_ENABLE_* toggles, else all)
echo   stop                          stop running containers but KEEP them (fast resume via up)
echo   down [-v]                     remove containers (-v also wipes data volumes)
echo   rm [profiles...]              force-remove containers (default: all)
echo   start [profiles...]           full lifecycle: init, down, rm, build-bases, up
echo   logs [service]                tail logs (all, or one service)
echo   ps                            status of all services
echo   exec ^<service^> [cmd...]       run a command (or open a shell) in a service container
echo.
echo  kafka ^<sub^>                    topics ^| connect-plugin [--generic^|--debezium] ^<name^> ^| register-connectors ^| init
echo  db ^<sub^>                       init [mysql^|mongo^|all] ^| seed (DBGate connections)
echo  tools ^<sub^>                    semgrep [path]  (scan; view at semgrep.test via up semgrep)
echo.
echo   certs [--force]               mint the wildcard *.test dev TLS cert (for LDS_ENABLE_HTTPS)
echo   hosts-sync                    write www/ projects into the hosts file
echo   build-php [--push]            rebuild just the PHP service image
echo   help                          show this message
echo   (old flat names still work as aliases: kafka-topics, mongo-init, mysql-init, etc.)
goto end

:end
endlocal
