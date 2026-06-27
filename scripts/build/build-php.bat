@echo off
REM Build (and optionally push) the custom PHP image.
REM   build-php.bat            build
REM   build-php.bat --push     build + push
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

docker compose --profile php build php

if /I "%~1"=="--push" (
  for /f "delims=" %%i in ('docker compose --profile php config --images php') do set "IMG=%%i"
  echo Pushing !IMG!
  docker push !IMG!
)

popd
endlocal
