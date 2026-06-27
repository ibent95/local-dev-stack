@echo off
REM Build the shared base images (lds/*) via docker buildx bake (parallel).
REM   build-bases.bat [--force] [--push]
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env (single source of truth for versions). A var already set in the
REM environment is left untouched; .env fills the rest; the lines below are the
REM final fallback. eol=# skips comment lines, delims== splits KEY=VALUE.
if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
    if not defined %%a set "%%a=%%b"
  )
)

if "%DHI_REGISTRY%"==""   set "DHI_REGISTRY=dhi.io"
if "%PHP_VERSION%"==""    set "PHP_VERSION=8.4"
if "%GO_VERSION%"==""     set "GO_VERSION=1.26"
if "%RUST_VERSION%"==""   set "RUST_VERSION=1.96"
if "%NODE_VERSION%"==""   set "NODE_VERSION=26.3"
if "%PYTHON_VERSION%"=="" set "PYTHON_VERSION=3.14"
if "%JAVA_VERSION%"==""   set "JAVA_VERSION=25"

set "FORCE="
set "PUSH="
for %%a in (%*) do (
  if /I "%%a"=="--force" set "FORCE=1"
  if /I "%%a"=="--push"  set "PUSH=1"
)

set "BAKE_ARGS=--load"
if defined FORCE set "BAKE_ARGS=!BAKE_ARGS! --no-cache"

echo.
echo ========================================================
echo   build-bases - building lds/* base images (buildx bake)
echo ========================================================
docker buildx bake -f docker-bake.hcl !BAKE_ARGS!

if defined PUSH if not "%REGISTRY%"=="" (
  for %%s in (php:%PHP_VERSION% go-dev:%GO_VERSION% rust-dev:%RUST_VERSION% node-dev:%NODE_VERSION% python-dev:%PYTHON_VERSION% java-dev:%JAVA_VERSION%) do (
    echo push %REGISTRY%/%%s
    docker tag lds/%%s %REGISTRY%/%%s
    docker push %REGISTRY%/%%s
  )
)

echo   ---- build-bases: done (lds/* ready) ----
popd
endlocal
