@echo off
REM ===========================================================================
REM Sync .env to .env.example - keep YOUR values, match the example's variables,
REM ordering AND comments. Thin wrapper: delegates to env-sync.ps1 (PowerShell,
REM always present on Windows), which implements the same rules as the canonical
REM bash version (scripts/run/env-sync.sh). Values and special characters are
REM handled by PowerShell, so nothing is re-parsed by cmd.
REM   lds env-sync             rewrite .env so it mirrors .env.example
REM   lds env-sync --dry-run   show what would change without writing anything
REM   lds env-sync --quiet     suppress the "no changes" message (used by up)
REM ===========================================================================
setlocal
REM %~dp0 must be captured BEFORE any shift - the shift command moves
REM the old %1 into %0, so %~dp0 after the parse loop would resolve
REM against the current directory (e.g. --quiet -> repo root) and the
REM ps1 lookup would fail. Capture once up front, reference absolutely.
set "SCRIPT_DIR=%~dp0"
set "PSARGS="
:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--dry-run" (set "PSARGS=%PSARGS% -DryRun" & shift & goto parse_args)
if /I "%~1"=="-n"        (set "PSARGS=%PSARGS% -DryRun" & shift & goto parse_args)
if /I "%~1"=="--quiet"   (set "PSARGS=%PSARGS% -Quiet" & shift & goto parse_args)
if /I "%~1"=="-q"        (set "PSARGS=%PSARGS% -Quiet" & shift & goto parse_args)
if /I "%~1"=="--help"    (echo usage: lds env-sync [--dry-run] [--quiet] & endlocal & exit /b 0)
if /I "%~1"=="-h"        (echo usage: lds env-sync [--dry-run] [--quiet] & endlocal & exit /b 0)
echo env-sync: unknown argument "%~1" ^(usage: lds env-sync [--dry-run] [--quiet]^)
endlocal & exit /b 1
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%env-sync.ps1" %PSARGS%
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
