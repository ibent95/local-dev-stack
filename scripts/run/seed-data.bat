@echo off
REM Seed sample Parquet/CSV/JSON data into data/duckdb/ and data/trino/.
REM Idempotent -- only generates files that don't exist yet.
REM Uses the existing lds/python-dev base image (zero new pulls).
REM   seed-data.bat          seed if empty
REM   seed-data.bat --force  regenerate everything
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load PYTHON_VERSION from .env (default 3.14)
set "PYTHON_VERSION=3.14"
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if /I "%%a"=="PYTHON_VERSION" set "PYTHON_VERSION=%%b"
set "IMAGE=lds/python-dev:%PYTHON_VERSION%"

set "FORCE="
if /I "%~1"=="--force" set "FORCE=--force"
if /I "%~1"=="-f" set "FORCE=--force"

REM Ensure target directories exist
if not exist data\duckdb mkdir data\duckdb
if not exist data\trino mkdir data\trino

REM Quick check: skip if not --force and files already exist
if not defined FORCE (
  dir /b data\duckdb\*.parquet data\duckdb\*.csv data\duckdb\*.jsonl data\trino\*.parquet data\trino\*.csv 2>nul | findstr /R ".*" >nul
  if not errorlevel 1 (
    echo Sample data already exists - skipping ^(use --force to regenerate^).
    popd & endlocal & exit /b 0
  )
)

REM Build the base image if missing
docker image inspect !IMAGE! >nul 2>&1 || (
  echo Building !IMAGE! ^(first run^)...
  docker buildx bake -f docker-bake.hcl --load python-dev
)

echo Seeding sample data into data/duckdb/ and data/trino/...

docker run --rm ^
  -v "%cd%/data:/data" ^
  -v "%cd%/configs/seed-data/generate.py:/generate.py:ro" ^
  !IMAGE! ^
  sh -c "pip install -q pandas pyarrow && python /generate.py !FORCE!"

popd
endlocal
