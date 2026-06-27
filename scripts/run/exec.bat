@echo off
REM Run a command in a service's container - or open a shell if none given.
REM   lds exec <service> [command...]
REM   lds exec mongo                          (interactive shell)
REM   lds exec mongo mongosh -u root -p root --authenticationDatabase admin
REM   lds exec mysql mysql -uroot -proot app
REM Uses `docker compose exec`, so pass the SERVICE name (mongo, kafka-broker,
REM connect-debezium, ...) - not the container name.
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "SVC=%~1"
if "%SVC%"=="" (
  echo Usage: lds exec ^<service^> [command...]
  echo   lds exec mongo                  ^(open a shell^)
  echo   lds exec mysql mysql -uroot -proot app
  echo   lds exec redis redis-cli
  echo Tip: `lds ps` lists running services.
  popd & endlocal & exit /b 1
)

REM Collect the remaining args into CMD.
set "CMD="
shift
:collect
if "%~1"=="" goto run
set "CMD=!CMD! %~1"
shift
goto collect

:run
if "!CMD!"=="" (
  docker compose --profile "*" exec %SVC% sh -c "command -v bash >/dev/null 2>&1 && exec bash || exec sh"
) else (
  docker compose --profile "*" exec %SVC% !CMD!
)
popd
endlocal
