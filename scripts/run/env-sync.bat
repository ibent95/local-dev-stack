@echo off
REM ===========================================================================
REM Sync .env to .env.example - keep YOUR values, match the example's variables
REM and ordering.
REM   lds env-sync             rewrite .env so it mirrors .env.example
REM   lds env-sync --dry-run   show what would change without writing anything
REM   lds env-sync --quiet     suppress the "no changes" message (used by up)
REM
REM Rules:
REM   * Every variable in .env.example must exist in .env at the same position.
REM   * YOUR value wins: if .env defines a variable, that full line (value + any
REM     inline comment) is kept verbatim.
REM   * Variables missing from .env are added with the example's default value.
REM   * Variables that only exist in .env (dropped from the example) are kept,
REM     appended at the end under a marker comment - nothing is ever deleted.
REM   * Structure (comments / blank lines / order) follows .env.example.
REM   * Lines are read via `for /f` over `findstr /n` (blank lines survive)
REM     and values are written by :writeval with delayed expansion disabled
REM     (so cmd never re-parses them) - special chars (& ^ | < > " ! %% etc.)
REM     in values are preserved verbatim. The bash version (lds env-sync via
REM     Git Bash) remains the canonical implementation.
REM
REM :writeval "KEY" - append the FIRST .env line matching KEY= to OUT. Sets
REM errorlevel 0 if found, 1 if not. Delayed expansion is disabled inside so
REM the raw line is echoed without cmd touching any special character.
REM ===========================================================================
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

set "DRY=0"
set "QUIET=0"
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--dry-run" (set "DRY=1" & shift & goto parse_args)
if /I "%~1"=="-n"        (set "DRY=1" & shift & goto parse_args)
if /I "%~1"=="--quiet"   (set "QUIET=1" & shift & goto parse_args)
if /I "%~1"=="-q"        (set "QUIET=1" & shift & goto parse_args)
if /I "%~1"=="--help"   goto usage
if /I "%~1"=="-h"        goto usage
echo env-sync: unknown argument "%~1" ^(usage: lds env-sync [--dry-run] [--quiet]^)
popd & endlocal & exit /b 1
:args_done
goto main
:usage
echo usage: lds env-sync [--dry-run] [--quiet]
popd & endlocal & exit /b 0
:main

if not exist ".env.example" (
  echo env-sync: .env.example not found
  popd & endlocal & exit /b 1
)
if not exist ".env" (
  if "!DRY!"=="1" (
    echo env-sync: .env missing - dry run: would create it from .env.example
  ) else (
    copy /y ".env.example" ".env" >nul
    echo env-sync: no .env found - created from .env.example.
  )
  popd & endlocal & exit /b 0
)

set "OUT=%TEMP%\lds-env-sync.out"
type nul > "%OUT%"
set "ADDED="
set "EXTRA="
set "EXHDR="
set "SEEN="

REM --- pass 1: rebuild .env from .env.example, substituting your values ------
REM findstr /n keeps blank lines (numbered); for /f tokens=1,* splits off the
REM line number. Detection is structural: in this repo's example every
REM non-comment, non-blank line is a variable line, so no regex pipe is needed.
for /f "tokens=1,* delims=:" %%a in ('findstr /n "^" ".env.example"') do (
  set "LN=%%b"
  if "!LN!"=="" (
    >> "!OUT!" echo.
  ) else if "!LN:~0,1!"=="#" (
    >> "!OUT!" echo !LN!
  ) else (
    for /f "tokens=1 delims==" %%k in ("!LN!") do set "KEY=%%k"
    call :writeval "!KEY!"
    if errorlevel 1 (
      >> "!OUT!" echo !LN!
      set "ADDED=!ADDED! !KEY!"
    )
  )
)

REM --- pass 2: .env-only variables -> append so nothing is lost --------------
for /f "tokens=1,* delims=:" %%a in ('findstr /n "^" ".env"') do (
  set "LN=%%b"
  if not "!LN!"=="" if not "!LN:~0,1!"=="#" (
    for /f "tokens=1 delims==" %%x in ("!LN!") do set "KEY2=%%x"
    findstr /b /c:"!KEY2!=" ".env.example" >nul
    if errorlevel 1 (
      echo(!SEEN! | findstr /c:"!KEY2! " >nul
      if errorlevel 1 (
        if not defined EXHDR (
          >> "!OUT!" echo.
          >> "!OUT!" echo # --- kept from .env ^(not in .env.example^) ---
          set "EXHDR=1"
        )
        call :writeval "!KEY2!"
        if errorlevel 1 (
          >> "!OUT!" echo !LN!
        )
        set "SEEN=!SEEN!!KEY2! "
        set "EXTRA=!EXTRA! !KEY2!"
      )
    )
  )
)

REM --- compare / apply -------------------------------------------------------
fc /b "%OUT%" ".env" >nul 2>&1
if not errorlevel 1 (
  if "!QUIET!"=="0" echo env-sync: no changes - .env already matches .env.example ^(values untouched^).
  del "%OUT%" >nul 2>&1
  popd & endlocal & exit /b 0
)

if "!DRY!"=="1" (
  echo env-sync: DRY RUN - .env would be rewritten to match .env.example:
) else (
  copy /y "%OUT%" ".env" >nul
  echo env-sync: synced .env to .env.example ^(values kept^).
)
if defined ADDED echo   + added from example:!ADDED!
if defined EXTRA echo   = kept ^(in .env only, appended at end^):!EXTRA!
del "%OUT%" >nul 2>&1
popd
endlocal
exit /b 0

REM --- helper: append the FIRST .env line matching KEY= to OUT -------------
REM Delayed expansion is disabled in here so the raw line is echoed without
REM cmd touching special characters (^& ^| ^< ^> " ! %% etc. all survive).
REM Sets errorlevel 0 if found, 1 if not.
:writeval
setlocal DisableDelayedExpansion
set "GOTVAL="
for /f "usebackq delims=" %%L in (`findstr /b /c:"%~1=" ".env"`) do if not defined GOTVAL (
  >> "%OUT%" echo %%L
  set "GOTVAL=1"
)
if defined GOTVAL (endlocal & exit /b 0) else (endlocal & exit /b 1)
