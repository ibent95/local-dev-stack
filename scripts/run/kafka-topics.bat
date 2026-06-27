@echo off
REM Create the topics listed in KAFKA_TOPICS (replaces the old one-shot
REM kafka-init service). Idempotent (--if-not-exists); safe to re-run any time.
REM   KAFKA_TOPICS=name:partitions:replication,...   (parts/repl default 1)
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env so KAFKA_TOPICS is available (shell env wins over .env).
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"

set "BROKER=lds-kafka-broker"
if "%KAFKA_TOPICS%"=="" (
  echo KAFKA_TOPICS is empty - nothing to create.
  popd & endlocal & exit /b 0
)

REM Wait until the broker answers.
set "READY="
for /l %%i in (1,1,20) do (
  if not defined READY (
    docker exec %BROKER% /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list >nul 2>&1 && set "READY=1" || ping -n 3 127.0.0.1 >nul
  )
)
if not defined READY (
  echo Broker '%BROKER%' not reachable - is the kafka profile up?
  popd & endlocal & exit /b 1
)

for %%t in (%KAFKA_TOPICS%) do (
  for /f "tokens=1,2,3 delims=:" %%a in ("%%t") do (
    set "NAME=%%a"
    set "PARTS=%%b"
    set "REPL=%%c"
    if "!PARTS!"=="" set "PARTS=1"
    if "!REPL!"=="" set "REPL=1"
    echo Creating topic '!NAME!' ^(partitions=!PARTS!, replication=!REPL!^)
    docker exec %BROKER% /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists --topic "!NAME!" --partitions !PARTS! --replication-factor !REPL! >nul && (echo   ok) || (echo   failed or already exists)
  )
)

echo Topics now on the broker:
docker exec %BROKER% /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

popd
endlocal
